import {randomUUID} from 'node:crypto';
import {HttpsError} from 'firebase-functions/v2/https';
import {billingAccount, handleBilling, refreshEntitlements} from './billing.js';
import {playPackageName, playSnapshot, purchaseKey} from './google-play-policy.js';
import {latestPlaySubscription, acknowledgePlaySubscription} from './google-play-store.js';

const store = {fetch: latestPlaySubscription, acknowledge: acknowledgePlaySubscription};
const refFor = (db, token) => db.doc(`googlePlaySubscriptions/${purchaseKey(token)}`);
const fail = (code, message) => new HttpsError(code, message);

export async function claimPlaySubscription(db, uid, token, snapshot) {
  const ref = refFor(db, token);
  return db.runTransaction(async tx => {
    const [lock, account, owner, existing, tester] = await tx.getAll(db.doc(`accountDeletions/${uid}`),
      db.doc(`billingAccounts/${uid}`), db.doc(`billingTokenOwners/${snapshot.accountToken}`), ref, db.doc(`billingTesters/${uid}`));
    if (lock.exists || account.data()?.deleted || owner.data()?.deleted || existing.data()?.deleted) {
      throw fail('permission-denied', '삭제된 계정의 구독입니다.');
    }
    if (account.data()?.appAccountToken !== snapshot.accountToken || owner.data()?.uid !== uid ||
        (existing.exists && existing.data().uid !== uid)) {
      throw fail('permission-denied', '처음 구독한 CloudBoard 계정으로 로그인해 복원해 주세요.');
    }
    if (snapshot.grant.environment === 'Sandbox' && tester.data()?.enabled !== true) {
      throw fail('permission-denied', '테스트 계정으로만 테스트 결제를 사용할 수 있습니다.');
    }
    if (!existing.exists) tx.create(ref, {uid, accountToken: snapshot.accountToken,
      purchaseToken: token, environment: snapshot.grant.environment, nextCheckAtMs: 0});
    return ref;
  });
}

export async function refreshPlaySubscription(db, realtime, ref, api = store) {
  const lease = randomUUID(), startedAt = Date.now();
  const identity = await db.runTransaction(async tx => {
    const value = (await tx.get(ref)).data();
    if (!value || value.deleted || value.replacedBy) return null;
    if (value.leaseUntilMs > startedAt) throw fail('aborted', '구독을 확인하고 있습니다. 잠시 후 다시 확인해 주세요.');
    tx.update(ref, {lease, leaseUntilMs: startedAt + 180000});
    return value;
  });
  if (!identity) return;
  try {
    let snapshot;
    try {
      snapshot = playSnapshot(await api.fetch(identity.purchaseToken), Date.now(), identity.accountToken);
    } catch (error) {
      if (error.httpStatus !== 410) throw error;
      // Google retires tokens 60 days after expiry; no more polling or entitlement.
      snapshot = {accountToken: identity.accountToken, grant: {...identity.grant,
        validUntilMs: 0, status: 'expired', autoRenew: false}, terminal: true};
    }
    if (snapshot.accountToken !== identity.accountToken || snapshot.grant.environment !== identity.environment) {
      throw fail('permission-denied', '구독 계정 정보가 일치하지 않습니다.');
    }
    const linkedRef = snapshot.linkedToken ? refFor(db, snapshot.linkedToken) : null;
    if (linkedRef?.path === ref.path) throw new Error('invalid-play-link');
    const committed = await db.runTransaction(async tx => {
      const [current, account, lock, linked, tester] = await Promise.all([
        tx.get(ref), tx.get(db.doc(`billingAccounts/${identity.uid}`)), tx.get(db.doc(`accountDeletions/${identity.uid}`)),
        linkedRef ? tx.get(linkedRef) : null, tx.get(db.doc(`billingTesters/${identity.uid}`)),
      ]);
      if (current.data()?.lease !== lease || current.data()?.replacedBy) throw fail('aborted', '구독 확인을 다시 시도해 주세요.');
      if (lock.exists || account.data()?.deleted || !account.exists) {
        tx.set(ref, {deleted: true});
        return false;
      }
      if (snapshot.grant.environment === 'Sandbox' && tester.data()?.enabled !== true) {
        throw fail('permission-denied', '테스트 계정 권한이 필요합니다.');
      }
      if (linked?.exists && (linked.data().deleted || linked.data().uid !== identity.uid)) {
        throw fail('permission-denied', '이전 구독의 계정 정보가 일치하지 않습니다.');
      }
      // A pending replacement must leave the previous paid period usable.
      if (linkedRef && snapshot.grant.validUntilMs > Date.now()) {
        tx.set(linkedRef, {uid: identity.uid, replacedBy: ref.id, nextCheckAtMs: null,
          leaseUntilMs: 0, grant: null}, {merge: true});
      }
      tx.update(ref, {grant: snapshot.grant, checkedAtMs: Date.now(),
        nextCheckAtMs: snapshot.terminal ? null : Math.min(Date.now() + 3600000,
          snapshot.grant.validUntilMs > Date.now() ? snapshot.grant.validUntilMs : Infinity)});
      return true;
    });
    if (!committed) return;
    await refreshEntitlements(db, realtime, identity.uid);
    // Server acknowledgment survives the user closing the app after payment.
    if (snapshot.needsAcknowledgement) await api.acknowledge(identity.purchaseToken, snapshot.grant.productId,
      snapshot.outOfApp ? identity.accountToken : undefined);
    await db.runTransaction(async tx => {
      if ((await tx.get(ref)).data()?.lease === lease) tx.update(ref, {leaseUntilMs: 0});
    });
    return snapshot;
  } catch (error) {
    await db.runTransaction(async tx => {
      const value = (await tx.get(ref)).data();
      if (value?.lease === lease && !value.replacedBy) tx.update(ref, {leaseUntilMs: 0, nextCheckAtMs: Date.now() + 60000});
    });
    throw error;
  }
}

export async function verifyPlayPurchase(db, realtime, uid, token, api = store) {
  const existing = (await refFor(db, token).get()).data();
  const snapshot = playSnapshot(await api.fetch(token), Date.now(), existing?.accountToken);
  const owner = (await db.doc(`billingTokenOwners/${snapshot.accountToken}`).get()).data();
  if (owner?.deleted || existing?.deleted) return {verified: true, retired: true};
  const ref = await claimPlaySubscription(db, uid, token, snapshot);
  const result = await refreshPlaySubscription(db, realtime, ref, api);
  if (result?.pending) throw fail('failed-precondition', 'Google Play 결제 승인을 기다리고 있어요. 승인 후 다시 확인해 주세요.');
  return {verified: true};
}

export async function handlePlayBilling(db, realtime, uid, input, api = store) {
  try {
    return await handleBilling(db, realtime, uid, input, {
      store: 'google_play',
      verify: () => verifyPlayPurchase(db, realtime, uid, input?.purchaseToken, api),
      refresh: async () => {
        const rows = await db.collection('googlePlaySubscriptions').where('uid', '==', uid).get();
        for (const row of rows.docs) await refreshPlaySubscription(db, realtime, row.ref, api);
      },
    });
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    throw fail('unavailable', 'Google Play 구매 정보를 확인하지 못했습니다. 다시 결제하지 말고 구매 복원을 시도해 주세요.');
  }
}

// Called ONLY by an IAM-protected Pub/Sub trigger, never a public HTTP endpoint.
export async function acceptPlayNotification(db, messageId, value) {
  if (value?.packageName !== playPackageName || !/^[\w-]{1,128}$/.test(messageId ?? '')) return;
  if (value.testNotification) return;
  const token = value.subscriptionNotification?.purchaseToken ??
    (value.voidedPurchaseNotification?.productType === 1 ? value.voidedPurchaseNotification.purchaseToken : null);
  if (!token) return;
  purchaseKey(token);
  const ref = db.doc(`googlePlayEvents/${messageId}`);
  await db.runTransaction(async tx => {
    if (!(await tx.get(ref)).exists) tx.create(ref, {purchaseToken: token, status: 'pending',
      nextAttemptAtMs: Date.now(), attempts: 0, createdAtMs: Date.now()});
  });
}

export async function processPlayEvent(db, realtime, ref, api = store) {
  const event = (await ref.get()).data();
  if (!event || event.status === 'done') return;
  try {
    const subRef = refFor(db, event.purchaseToken), sub = (await subRef.get()).data();
    if (!sub?.deleted && !sub?.replacedBy) {
      if (sub?.uid) {
        await refreshPlaySubscription(db, realtime, subRef, api);
      } else {
        const snapshot = playSnapshot(await api.fetch(event.purchaseToken));
        const owner = (await db.doc(`billingTokenOwners/${snapshot.accountToken}`).get()).data();
        if (!owner?.deleted) {
          if (!owner?.uid) throw new Error('play-owner-unavailable');
          await billingAccount(db, realtime, owner.uid);
          const claimed = await claimPlaySubscription(db, owner.uid, event.purchaseToken, snapshot);
          await refreshPlaySubscription(db, realtime, claimed, api);
        }
      }
    }
    // Keep just delivery metadata after success, not the purchase credential.
    await ref.set({status: 'done', nextAttemptAtMs: null, processedAtMs: Date.now()});
  } catch (error) {
    await db.runTransaction(async tx => {
      const current = (await tx.get(ref)).data();
      // Another delivery may have completed while this worker lost the lease.
      if (!current || current.status === 'done') return;
      if (error.httpStatus === 410) {
        tx.set(ref, {status: 'done', nextAttemptAtMs: null, processedAtMs: Date.now()});
        return;
      }
      const attempts = (current.attempts ?? 0) + 1;
      tx.update(ref, {attempts, nextAttemptAtMs: Date.now() + Math.min(3600000, 60000 * 2 ** Math.min(attempts, 6))});
    });
  }
}
