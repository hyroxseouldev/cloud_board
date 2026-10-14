import type pg from 'pg';
import { firebaseServices } from './firebase.js';
import { effectiveStatus, DAY } from './core.js';
import { applyPlanPolicy, planEntitlements } from './plan-entitlements.js';
export async function syncAfterChange(pool: pg.Pool, storeId?: string) {
  try {
    await syncEntitlements(pool, storeId);
  } catch {
    console.error('Entitlement sync pending; scheduled reconciliation will retry.');
  }
}
export async function stopBillingForFirebaseUser(pool: pg.Pool, uid: string) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const rows = (
      await client.query(
        'SELECT t.id FROM cb_stores t JOIN cb_identities i ON i.user_id=t.owner_id WHERE i.firebase_uid=$1 FOR UPDATE OF t',
        [uid],
      )
    ).rows;
    for (const r of rows) {
      await client.query(
        'UPDATE cb_subscriptions SET cancel_at_period_end=true,billing_key_encrypted=NULL,revision=revision+1 WHERE store_id=$1',
        [r.id],
      );
      await client.query(
        'UPDATE cb_stores SET deletion_requested_at=COALESCE(deletion_requested_at,now()) WHERE id=$1',
        [r.id],
      );
    }
    await client.query('COMMIT');
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
}
export function entitlementFor(s: any, now = new Date()) {
  const state = effectiveStatus(s, now);
  const paid = ['active', 'canceling', 'past_due'].includes(state);
  const testPaid = paid && s.billing_mode !== 'live';
  const until =
    s.deletion_requested_at || testPaid
      ? 0
      : state === 'trialing'
        ? new Date(s.trial_ends_at).getTime()
        : state === 'past_due'
          ? s.grace_ends_at
            ? new Date(s.grace_ends_at).getTime()
            : new Date(s.current_period_end).getTime() + 7 * DAY
          : paid
            ? new Date(s.current_period_end).getTime() + (s.cancel_at_period_end ? 0 : 7 * DAY)
            : 0;
  return {
    storeId: s.store_id,
    managed: true,
    phoneVerified: s.phone_number_verified === true || s.phone_verified_at != null,
    validUntilMs: until,
    ...planEntitlements(s.display_limit),
    revision: s.revision,
    status: s.deletion_requested_at ? 'deleted' : testPaid ? 'test_payment' : state,
    source: paid ? s.billing_mode : state === 'trialing' ? 'trial' : 'free',
    canPrepare: !s.deletion_requested_at,
    canPairDisplay: !s.deletion_requested_at && (state === 'pending_connection' || until > +now),
    canStartClass: until > +now,
    policyVersion: '2026-09-23-v3',
  };
}
export async function writeEntitlement(s: any) {
  const { realtime, firestore } = firebaseServices();
  const deleted = (await firestore.doc(`accountDeletions/${s.firebase_uid}`).get()).exists;
  if (s.synced_revision < 0) {
    const current = (await realtime.ref(`users/${s.firebase_uid}/activeSession`).get()).val();
    if (current && current.status !== 'completed' && current.schemaVersion !== 2)
      throw new Error('LEGACY_CLASS_RUNNING');
  }
  let access = entitlementFor({
    ...s,
    deletion_requested_at: s.deletion_requested_at || deleted,
  });
  const pilot = (await realtime.ref(`legacyPilotAccess/${s.firebase_uid}`).get()).val();
  if (
    !deleted &&
    !s.deletion_requested_at &&
    pilot?.validUntilMs > Math.max(Date.now(), access.validUntilMs)
  ) {
    access = {
      ...access,
      source: 'pilot',
      status: 'pilot',
      validUntilMs: pilot.validUntilMs,
      canStartClass: true,
      canPairDisplay: true,
    };
  }
  await publishWebEntitlement({ firestore, realtime }, s.firebase_uid, {
    ...access,
    trialUsed: s.trial_ends_at != null,
    paidHistory: s.current_period_end != null,
  });
}

// SQL revisions are independent of the Firebase billing projection. Publish a
// source-specific grant; the app's existing entitlement trigger resolves it
// alongside native purchases, native trial and explicit Free enrollment.
export async function publishWebEntitlement(
  { firestore, realtime }: Pick<ReturnType<typeof firebaseServices>, 'firestore' | 'realtime'>,
  uid: string,
  grant: any,
) {
  const mode = await firestore.runTransaction(async (tx) => {
    const ref = firestore.doc(`subscriptionEntitlements/${uid}`);
    const [current, account, lock, policy] = await Promise.all([
      tx.get(ref),
      tx.get(firestore.doc(`billingAccounts/${uid}`)),
      tx.get(firestore.doc(`accountDeletions/${uid}`)),
      tx.get(firestore.doc('appConfig/planPolicy')),
    ]);
    if (lock.exists || account.data()?.deleted) return 'deleted';
    const previous = current.data();
    grant = {
      ...applyPlanPolicy(grant, previous, policy.data()),
      phoneVerified: grant.phoneVerified === true || previous?.webGrant?.phoneVerified === true,
    };
    const webRevision =
      previous?.webGrant?.revision ??
      (previous?.source !== 'firebase_billing' ? previous?.revision : undefined) ??
      -1;
    if (webRevision > grant.revision) return 'stale';
    if (account.exists || previous?.source === 'firebase_billing') {
      tx.set(ref, { webGrant: grant }, { merge: true });
      return 'native';
    }
    // Before an app billing account exists retain the existing web-only path.
    // Persist the grant here too so first Free enrollment captures its history.
    tx.set(ref, { ...grant, webGrant: grant, updatedAt: new Date() });
    tx.set(
      firestore.doc(`users/${uid}`),
      {
        partnerTier:
          grant.source === 'pilot'
            ? 'pilot'
            : grant.canStartClass
              ? grant.source === 'trial'
                ? 'trial'
                : 'pro'
              : 'free',
        subscriptionPlan: grant.canStartClass
          ? grant.plan === 'legacy'
            ? 'cloudboard_pro'
            : grant.plan
          : 'free',
        subscriptionStatus: !grant.canStartClass
          ? 'free'
          : grant.source === 'trial'
            ? 'trialing'
            : grant.status === 'past_due'
              ? 'pastDue'
              : 'active',
        pilotEndsAt: grant.validUntilMs > 0 ? new Date(grant.validUntilMs) : null,
        displayLimit: grant.displayLimit,
      },
      { merge: true },
    );
    return 'web';
  });
  if (mode !== 'web') return;
  // A native projection may appear after the Firestore transaction. It always
  // wins here, regardless of the unrelated SQL revision counter.
  await realtime
    .ref(`subscriptionAccess/${uid}`)
    .transaction((current) =>
      current?.source === 'firebase_billing' || (current?.revision ?? -1) > grant.revision
        ? undefined
        : grant,
    );
  if ((await firestore.doc(`accountDeletions/${uid}`).get()).exists)
    await realtime.ref(`subscriptionAccess/${uid}`).remove();
}

export async function syncEntitlements(pool: pg.Pool, storeId?: string, write = writeEntitlement) {
  if (process.env.ENTITLEMENT_SYNC_ENABLED !== 'true') return;
  const rows = (
    await pool.query(
      `SELECT s.*,i.firebase_uid,i.phone_verified_at,u.phone_number_verified,t.deletion_requested_at FROM cb_subscriptions s
     JOIN cb_stores t ON t.id=s.store_id JOIN cb_identities i ON i.user_id=t.owner_id
     JOIN "user" u ON u.id=t.owner_id
     WHERE (s.revision>s.synced_revision OR $1::uuid IS NOT NULL) AND ($1::uuid IS NULL OR s.store_id=$1)
       AND ($1::uuid IS NOT NULL OR s.sync_next_attempt_at IS NULL OR s.sync_next_attempt_at<=now())
     ORDER BY s.updated_at LIMIT 50`,
      [storeId || null],
    )
  ).rows;
  for (const s of rows) {
    try {
      await write(s);
      await pool.query(
        `UPDATE cb_subscriptions SET synced_revision=$2,sync_attempts=0,sync_error=NULL,sync_next_attempt_at=NULL WHERE store_id=$1 AND revision=$2`,
        [s.store_id, s.revision],
      );
    } catch {
      // One broken destination cannot starve other stores. Both writes must succeed.
      await pool.query(
        `UPDATE cb_subscriptions SET sync_attempts=sync_attempts+1,sync_error='FIREBASE_SYNC_PENDING',sync_next_attempt_at=now()+interval '1 minute' WHERE store_id=$1 AND revision=$2`,
        [s.store_id, s.revision],
      );
    }
  }
}
export async function stopDeletedAccounts(pool: pg.Pool) {
  if (process.env.ENTITLEMENT_SYNC_ENABLED !== 'true') return;
  const rows = (
    await pool.query(
      `SELECT t.id,i.firebase_uid FROM cb_stores t JOIN cb_identities i ON i.user_id=t.owner_id WHERE t.deletion_requested_at IS NULL`,
    )
  ).rows;
  for (const r of rows) {
    if (
      (await firebaseServices().firestore.doc(`accountDeletions/${r.firebase_uid}`).get()).exists
    ) {
      await stopBillingForFirebaseUser(pool, r.firebase_uid);
    }
  }
}
