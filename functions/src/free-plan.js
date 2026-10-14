import {randomUUID} from 'node:crypto';
import {Timestamp} from 'firebase-admin/firestore';
import {HttpsError} from 'firebase-functions/v2/https';
import {billingAccount, refreshEntitlements} from './billing.js';
import {hasVerifiedPhone, verifiedFreePolicyVersion} from './verified-free-policy.js';

export async function startFreePlan(db, realtime, uid, now = Date.now()) {
  await db.runTransaction(async tx => {
    const ref = db.doc(`onboardingFree/${uid}`);
    const progressRef = db.doc(`users/${uid}/onboarding/progress`);
    const [lock, progress, existing, account, access] = await tx.getAll(
      db.doc(`accountDeletions/${uid}`), progressRef, ref,
      db.doc(`billingAccounts/${uid}`), db.doc(`subscriptionEntitlements/${uid}`));
    if (lock.exists || account.data()?.deleted) {
      throw new HttpsError('permission-denied', '삭제 처리 중인 계정입니다.');
    }
    const prior = progress.data();
    if (!hasVerifiedPhone(prior, access.data()?.webGrant, account.data()?.baseline)) {
      throw new HttpsError('permission-denied', '문자 인증을 먼저 완료해 주세요.');
    }
    // Center metadata is optional. Repair a missing server-owned shell without
    // making users verify their phone again or requiring a completed profile.
    const previousStoreId = typeof prior?.storeId === 'string' && prior.storeId
      ? prior.storeId : null;
    const center = previousStoreId ? await tx.get(db.doc(`centers/${previousStoreId}`)) : null;
    const ownsCenter = center?.data()?.ownerUid === uid;
    if (!ownsCenter || prior?.phoneVerified !== true) {
      const storeId = ownsCenter ? previousStoreId : randomUUID();
      if (!ownsCenter) tx.create(db.doc(`centers/${storeId}`), {
        ownerUid: uid, profile: {}, revision: 0,
        createdAt: Timestamp.fromMillis(now), updatedAt: Timestamp.fromMillis(now),
      });
      tx.set(progressRef, {step: 0, completed: false, deferred: false, ...prior,
        storeId, phoneVerified: true, updatedAt: Timestamp.fromMillis(now)}, {merge: true});
    }
    if (existing.data()?.enabled !== true) tx.set(ref, {
      enabled: true, startedAtMs: now, policyVersion: verifiedFreePolicyVersion,
    });
  });
  // The marker is an idempotent recovery checkpoint, not a separate user action.
  // Every retry completes both projections; higher paid/trial grants keep expiry.
  await billingAccount(db, realtime, uid);
  await refreshEntitlements(db, realtime, uid, now);
}

export async function syncVerifiedFree(db, realtime, uid) {
  const [lock, progress, account] = await db.getAll(db.doc(`accountDeletions/${uid}`),
    db.doc(`users/${uid}/onboarding/progress`), db.doc(`billingAccounts/${uid}`));
  if (lock.exists || account.data()?.deleted || progress.data()?.phoneVerified !== true) return;
  try { await startFreePlan(db, realtime, uid); }
  catch (error) {
    if (error.code === 'permission-denied') {
      const [latestLock, latestAccount] = await db.getAll(db.doc(`accountDeletions/${uid}`),
        db.doc(`billingAccounts/${uid}`));
      if (latestLock.exists || latestAccount.data()?.deleted) return;
    }
    throw error;
  }
}
