import type pg from 'pg';
import { firebaseServices, resolveAppUser } from './firebase.js';
import { ensureAccountStore } from './account.js';
import { linkFromWeb } from './onboarding.js';
import { syncAfterChange } from './sync.js';

// Only server SQL verification or the native server-owned onboarding record is
// proof. Client profiles, emails and paid/trial history are not verification.
export async function verifiedWebUser(
  pool: pg.Pool,
  owner: string,
  lookup = async (subject: string) => {
    const uid = await resolveAppUser(subject);
    const { firestore } = firebaseServices();
    const [progress, deletion, billing] = await firestore.getAll(
      firestore.doc(`users/${uid}/onboarding/progress`),
      firestore.doc(`accountDeletions/${uid}`),
      firestore.doc(`billingAccounts/${uid}`),
    );
    return (
      !deletion?.exists &&
      billing?.data()?.deleted !== true &&
      progress?.data()?.phoneVerified === true
    );
  },
) {
  const user = (
    await pool.query(
      'SELECT u.phone_number_verified,i.phone_verified_at FROM "user" u LEFT JOIN cb_identities i ON i.user_id=u.id WHERE u.id=$1',
      [owner],
    )
  ).rows[0];
  if (user?.phone_number_verified === true) return { verified: true, available: true };
  if (user?.phone_verified_at != null) {
    await pool.query('UPDATE "user" SET phone_number_verified=true,updated_at=now() WHERE id=$1', [
      owner,
    ]);
    return { verified: true, available: true };
  }
  const google = (
    await pool.query("SELECT account_id FROM account WHERE user_id=$1 AND provider_id='google'", [
      owner,
    ])
  ).rows;
  if (google.length !== 1) return { verified: false, available: true };
  try {
    if (await lookup(google[0].account_id)) {
      await pool.query(
        'UPDATE "user" SET phone_number_verified=true,updated_at=now() WHERE id=$1',
        [owner],
      );
      return { verified: true, available: true };
    }
    return { verified: false, available: true };
  } catch (error) {
    if ((error as { code?: string }).code === 'APP_ACCOUNT_REQUIRED')
      return { verified: false, available: true };
    return { verified: false, available: false };
  }
}

export async function recoverVerifiedAccount(
  pool: pg.Pool,
  owner: string,
  mode: string,
  name = 'CloudBoard',
) {
  const store = await ensureAccountStore(pool, owner, name, mode);
  const link = await linkFromWeb(pool, owner).catch((error) => {
    if (error.code === 'GOOGLE_REQUIRED') return { status: 'awaiting_app', linked: false };
    throw error;
  });
  if ('storeId' in link) await syncAfterChange(pool, link.storeId);
  return { storeId: store.id, ...link };
}

export function matchingAppAccess(
  access: any,
  mirror: any,
  now = Date.now(),
  phoneVerified = false,
) {
  return (
    access?.managed === true &&
    access.canStartClass === true &&
    ['free', 'plus', 'premium', 'legacy', 'cloudboard_pro'].includes(access.plan) &&
    (['active', 'trialing', 'grace_period', 'canceling', 'past_due', 'pilot'].includes(
      access.status,
    ) ||
      (['legacy', 'cloudboard_pro'].includes(access.plan) && access.status === 'legacy')) &&
    (access.plan !== 'free' || phoneVerified) &&
    Number.isSafeInteger(access.validUntilMs) &&
    access.validUntilMs > now &&
    mirror?.managed === true &&
    mirror.canStartClass === true &&
    mirror.validUntilMs === access.validUntilMs &&
    mirror.plan === access.plan &&
    mirror.status === access.status &&
    mirror.revision === access.revision &&
    mirror.policyVersion === access.policyVersion &&
    [
      'maxActiveDisplays',
      'maxWorkouts',
      'maxSavedSlides',
      'displaysUnlimited',
      'aiSlidesMonthlyLimit',
      'aiTimerMonthlyLimit',
      'canUseCenterLogo',
      'canHideCloudBoardLogo',
    ].every((key) => mirror[key] === access[key])
  );
}

export async function readAppAccess(uid?: string, services = firebaseServices, now = Date.now()) {
  if (!uid) return { status: 'awaiting_app' as const };
  try {
    const { firestore, realtime } = services();
    const [access, mirror, deletion, billing, progress] = await Promise.all([
      firestore.doc(`subscriptionEntitlements/${uid}`).get(),
      realtime.ref(`subscriptionAccess/${uid}`).get(),
      firestore.doc(`accountDeletions/${uid}`).get(),
      firestore.doc(`billingAccounts/${uid}`).get(),
      firestore.doc(`users/${uid}/onboarding/progress`).get(),
    ]);
    if (deletion.exists || billing.data()?.deleted === true)
      return { status: 'unavailable' as const };
    const data = access.data();
    if (
      !matchingAppAccess(
        data,
        mirror.val(),
        now,
        progress.data()?.phoneVerified === true || data?.webGrant?.phoneVerified === true,
      )
    )
      return { status: 'pending' as const };
    const fields = [
      'plan',
      'policyVersion',
      'validUntilMs',
      'maxActiveDisplays',
      'displaysUnlimited',
      'maxWorkouts',
      'maxSavedSlides',
      'aiSlidesMonthlyLimit',
      'aiTimerMonthlyLimit',
      'canUseCenterLogo',
      'canHideCloudBoardLogo',
    ];
    return {
      status: 'ready' as const,
      ...Object.fromEntries(
        fields.filter((key) => data?.[key] !== undefined).map((key) => [key, data![key]]),
      ),
    };
  } catch {
    return { status: 'unavailable' as const };
  }
}
