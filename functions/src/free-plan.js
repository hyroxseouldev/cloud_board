import {HttpsError} from 'firebase-functions/v2/https';
import {billingAccount, refreshEntitlements} from './billing.js';

export async function startFreePlan(db, realtime, uid, now = Date.now()) {
  await db.runTransaction(async tx => {
    const ref = db.doc(`onboardingFree/${uid}`);
    const [lock, progress, existing, policy] = await tx.getAll(
      db.doc(`accountDeletions/${uid}`), db.doc(`users/${uid}/onboarding/progress`),
      ref, db.doc('appConfig/freePlan'));
    if (lock.exists || !progress.data()?.phoneVerified) {
      throw new HttpsError('permission-denied', '문자 인증을 먼저 완료해 주세요.');
    }
    const center = await tx.get(db.doc(`centers/${progress.data().storeId}`));
    if (center.data()?.ownerUid !== uid) {
      throw new HttpsError('permission-denied', '센터 정보를 확인할 수 없습니다.');
    }
    if (existing.data()?.enabled === true) return;
    if (policy.data()?.enrollmentEnabled === false) {
      throw new HttpsError('failed-precondition', 'Free 신규 시작을 잠시 준비하고 있어요. 잠시 후 다시 시도해 주세요.');
    }
    tx.set(ref, {enabled: true, startedAtMs: now, policyVersion: 'free-tv1-v1'});
  });
  // Preserve paid/trial/legacy grants and their independent expiry. Free is
  // only the lowest-priority fallback, never a replacement for those grants.
  await billingAccount(db, realtime, uid);
  await refreshEntitlements(db, realtime, uid, now);
}
