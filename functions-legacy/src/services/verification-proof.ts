import type pg from 'pg';
import { firebaseServices } from './firebase.js';
import { HttpError } from './core.js';

// Proof-only bridge is independent of the paid billing sync rollout. It never
// creates a plan, trial dates or a user profile, nor replaces a prior paid grant.
export async function publishPhoneVerification(
  pool: pg.Pool,
  owner: string,
  uid: string,
  services = firebaseServices,
) {
  const proof = (
    await pool.query(
      'SELECT u.phone_number_verified,i.phone_verified_at,s.deletion_requested_at FROM "user" u JOIN cb_identities i ON i.user_id=u.id JOIN cb_stores s ON s.owner_id=u.id WHERE u.id=$1 AND i.firebase_uid=$2',
      [owner, uid],
    )
  ).rows[0];
  if (proof?.deletion_requested_at != null)
    throw new HttpError(403, 'ACCOUNT_DELETING', '삭제 처리 중인 계정입니다.');
  if (proof?.phone_number_verified !== true && proof?.phone_verified_at == null)
    throw new HttpError(403, 'PHONE_REQUIRED', '휴대폰 인증이 필요합니다.');
  const { firestore } = services();
  await firestore.runTransaction(async (tx) => {
    const ref = firestore.doc(`subscriptionEntitlements/${uid}`);
    const [current, deletion, billing] = await Promise.all([
      tx.get(ref),
      tx.get(firestore.doc(`accountDeletions/${uid}`)),
      tx.get(firestore.doc(`billingAccounts/${uid}`)),
    ]);
    if (deletion.exists || billing.data()?.deleted === true)
      throw new HttpError(403, 'ACCOUNT_DELETING', '삭제 처리 중인 계정입니다.');
    if (current.data()?.webGrant?.phoneVerified === true) return;
    tx.set(ref, { webGrant: { phoneVerified: true } }, { merge: true });
  });
}
