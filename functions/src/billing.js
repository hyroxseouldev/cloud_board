import {randomUUID} from 'node:crypto';
import {isDeepStrictEqual} from 'node:util';
import {HttpsError} from 'firebase-functions/v2/https';
import {appleGrant, billingSource, products, purchasesAllowed, resolveGrants, tokenPattern} from './billing-policy.js';
import {latestAppleSubscription, verifyApplePayload} from './apple-store.js';

const fail = (code, message) => new HttpsError(code, message);
const accountRef = (db, uid) => db.doc(`billingAccounts/${uid}`);
const summaryRef = (db, uid) => db.doc(`users/${uid}/billing/summary`);
const clean = value => JSON.parse(JSON.stringify(value ?? {}));
const refFor = (db, environment, originalId) => db.doc(`appStoreSubscriptions/${environment}_${originalId}`);

export async function billingAccount(db, realtime, uid) {
  const legacy = (await realtime.ref(`subscriptionAccess/${uid}`).get()).val();
  const pilot = (await realtime.ref(`legacyPilotAccess/${uid}`).get()).val();
  return db.runTransaction(async tx => {
    const ref = accountRef(db, uid);
    const [lock, account, current] = await tx.getAll(db.doc(`accountDeletions/${uid}`), ref, db.doc(`subscriptionEntitlements/${uid}`));
    if (lock.exists || account.data()?.deleted) throw fail('permission-denied', '삭제된 계정입니다.');
    if (account.exists) return account.data();
    const appAccountToken = randomUUID();
    const baseline = current.data()?.source !== billingSource ? clean(current.data()) : {};
    // Snapshot existing server grants before switching to the billing projection.
    const oldRealtime = legacy?.source !== billingSource ? clean(legacy) : {};
    const value = {appAccountToken, deleted: false, createdAtMs: Date.now(), baseline,
      oldRealtime, pilot: clean(pilot), nextCheckAtMs: Date.now()};
    tx.create(ref, value);
    tx.create(db.doc(`billingTokenOwners/${appAccountToken}`), {uid, deleted: false});
    return value;
  });
}

export async function refreshEntitlements(db, realtime, uid, now = Date.now()) {
  const livePilot = (await realtime.ref(`legacyPilotAccess/${uid}`).get()).val();
  await db.runTransaction(async tx => {
    const accessRef = db.doc(`subscriptionEntitlements/${uid}`), aRef = accountRef(db, uid);
    const [lock, account, access, trial, tester, subscriptions, progress, playSubscriptions] = await Promise.all([
      tx.get(db.doc(`accountDeletions/${uid}`)), tx.get(aRef), tx.get(accessRef),
      tx.get(db.doc(`onboardingTrials/${uid}`)), tx.get(db.doc(`billingTesters/${uid}`)),
      tx.get(db.collection('appStoreSubscriptions').where('uid', '==', uid)),
      tx.get(db.doc(`users/${uid}/onboarding/progress`)),
      tx.get(db.collection('googlePlaySubscriptions').where('uid', '==', uid)),
    ]);
    if (lock.exists || !account.exists || account.data().deleted) return;
    const data = account.data(), previous = access.data();
    const baseline = previous && previous.source !== billingSource ? clean(previous) : data.baseline;
    const apple = subscriptions.docs.map(d => d.data()).filter(d => d.environment === 'Production' || tester.data()?.enabled === true);
    const play = playSubscriptions.docs.map(d => d.data()).filter(d => !d.deleted && !d.replacedBy &&
      (d.environment === 'Production' || tester.data()?.enabled === true));
    const grants = [baseline, baseline?.managed ? null : data.oldRealtime, livePilot,
      trial.exists ? {source: 'app_trial', plan: 'premium', status: 'trialing', validUntilMs: trial.data().endsAtMs} : null,
      ...apple.map(d => d.grant), ...play.map(d => d.grant)];
    const result = {...resolveGrants(grants, now),
      storeId: progress.data()?.storeId ?? previous?.storeId ?? baseline?.storeId ?? null};
    const comparable = previous ? Object.fromEntries(Object.keys(result).map(k => [k, previous[k]])) : null;
    // Merely opening the page must not turn a new user's pending trial into a
    // historical expired grant, or migrate any legacy account before a purchase.
    if ((subscriptions.size > 0 || playSubscriptions.size > 0 || previous?.source === billingSource) && !isDeepStrictEqual(comparable, result)) {
      tx.set(accessRef, {...result, revision: (previous?.revision ?? 0) + 1});
    }
    const futureEnds = grants.filter(g => g?.validUntilMs > now).map(g => g.validUntilMs);
    tx.update(aRef, {baseline, nextCheckAtMs: Math.min(now + 3600000, ...futureEnds)});
    // Billing status is distinct from effective access (for example an active trial).
    const paidGrants = [...apple, ...play].map(d => d.grant).filter(Boolean);
    const renewable = g => g.validUntilMs > now || g.autoRenew || ['billing_retry', 'paused', 'pending'].includes(g.status);
    paidGrants.sort((a, b) => Number(renewable(b)) - Number(renewable(a)) || b.expiresAtMs - a.expiresAtMs);
    const paid = paidGrants[0];
    tx.set(summaryRef(db, uid), {plan: result.plan, status: result.status,
      validUntilMs: result.validUntilMs, grantSource: result.grantSource ?? null,
      paid: paid ?? null, paidStores: [...new Set(paidGrants.map(g => g.source))], updatedAtMs: now});
  });
  await projectBillingAccess(db, realtime, uid);
}

export async function projectBillingAccess(db, realtime, uid) {
  if ((await db.doc(`accountDeletions/${uid}`).get()).exists) return;
  const current = (await db.doc(`subscriptionEntitlements/${uid}`).get()).data();
  if (current?.source !== billingSource) return;
  await realtime.ref(`subscriptionAccess/${uid}`).transaction(old => {
    if (old?.source === billingSource && old.revision > current.revision) return undefined;
    return current;
  });
  // Cover deletion racing a cross-database projection.
  if ((await db.doc(`accountDeletions/${uid}`).get()).exists) await realtime.ref(`subscriptionAccess/${uid}`).remove();
}

export async function claimSubscription(db, uid, transaction) {
  const token = transaction.appAccountToken.toLowerCase();
  return db.runTransaction(async tx => {
    const ref = refFor(db, transaction.environment, transaction.originalTransactionId);
    const [lock, account, owner, existing, tester] = await tx.getAll(db.doc(`accountDeletions/${uid}`),
      accountRef(db, uid), db.doc(`billingTokenOwners/${token}`), ref, db.doc(`billingTesters/${uid}`));
    if (lock.exists || account.data()?.deleted || owner.data()?.deleted) throw fail('permission-denied', '삭제된 계정의 구독입니다.');
    if (account.data()?.appAccountToken !== token || owner.data()?.uid !== uid || (existing.exists && existing.data().uid !== uid)) {
      throw fail('permission-denied', '처음 구독한 CloudBoard 계정으로 로그인해 복원해 주세요.');
    }
    if (transaction.environment === 'Sandbox' && tester.data()?.enabled !== true) throw fail('permission-denied', '테스트 계정으로만 테스트 결제를 사용할 수 있습니다.');
    if (!existing.exists) tx.create(ref, {uid, appAccountToken: token, environment: transaction.environment,
      originalId: transaction.originalTransactionId, nextCheckAtMs: 0});
    return ref;
  });
}

// Serialize live status queries for an original transaction, so a delayed worker
// cannot overwrite a newer refund/renewal result. A crashed worker's lease expires.
export async function refreshSubscription(db, realtime, ref, fetchLatest = latestAppleSubscription) {
  const lease = randomUUID(), startedAt = Date.now();
  const identity = await db.runTransaction(async tx => {
    const snapshot = await tx.get(ref), value = snapshot.data();
    if (!value || value.deleted) return null;
    if (value.leaseUntilMs > startedAt) throw fail('aborted', '구독을 확인하고 있습니다. 잠시 후 다시 확인해 주세요.');
    tx.update(ref, {lease, leaseUntilMs: startedAt + 180000});
    return value;
  });
  if (!identity) return;
  try {
    const {transaction: t, renewal, status} = await fetchLatest(identity.originalId, identity.environment);
    if (t.appAccountToken.toLowerCase() !== identity.appAccountToken) throw fail('permission-denied', '구독 계정 정보가 일치하지 않습니다.');
    const grant = appleGrant(t, renewal, status);
    await db.runTransaction(async tx => {
      const [current, account, lock] = await tx.getAll(ref, accountRef(db, identity.uid), db.doc(`accountDeletions/${identity.uid}`));
      if (current.data()?.lease !== lease) throw fail('aborted', '구독 확인을 다시 시도해 주세요.');
      if (lock.exists || account.data()?.deleted || !account.exists) {
        tx.update(ref, {deleted: true, leaseUntilMs: 0});
        return;
      }
      tx.update(ref, {grant, transactionId: t.transactionId, checkedAtMs: Date.now(),
        nextCheckAtMs: Math.min(Date.now() + 3600000, grant.validUntilMs > Date.now() ? grant.validUntilMs : Infinity),
        leaseUntilMs: 0});
      tx.set(db.doc(`appStoreTransactions/${identity.environment}_${t.transactionId}`), {
        uid: identity.uid, originalId: identity.originalId, productId: t.productId,
        environment: identity.environment, expiresAtMs: t.expiresDate,
        revokedAtMs: t.revocationDate ?? null, verifiedAtMs: Date.now(),
      });
    });
    await refreshEntitlements(db, realtime, identity.uid);
  } catch (error) {
    await db.runTransaction(async tx => {
      if ((await tx.get(ref)).data()?.lease === lease) tx.update(ref, {leaseUntilMs: 0, nextCheckAtMs: Date.now() + 60000});
    });
    throw error;
  }
}

export async function handleBilling(db, realtime, uid, input, adapter = {}) {
  if (!uid) throw fail('unauthenticated', '로그인이 필요합니다.');
  const account = await billingAccount(db, realtime, uid);
  const action = input?.action ?? 'load';
  if (action === 'verify') {
    if (adapter.verify) return adapter.verify();
    let verified;
    try { verified = await verifyApplePayload(input.signedTransaction); }
    catch { throw fail('invalid-argument', 'App Store 결제 정보를 확인하지 못했습니다. 구매 복원을 다시 시도해 주세요.'); }
    const retired = (await db.doc(`billingTokenOwners/${verified.decoded.appAccountToken.toLowerCase()}`).get()).data()?.deleted;
    // Drain a verified unfinished purchase belonging to a deleted account. This
    // acknowledges delivery WITHOUT granting or transferring access to this uid.
    if (retired === true) return {verified: true, retired: true};
    const ref = await claimSubscription(db, uid, verified.decoded);
    await refreshSubscription(db, realtime, ref);
    return {verified: true};
  }
  if (action === 'refresh') {
    if (adapter.refresh) await adapter.refresh();
    else {
      const rows = await db.collection('appStoreSubscriptions').where('uid', '==', uid).get();
      for (const row of rows.docs) await refreshSubscription(db, realtime, row.ref);
    }
  } else if (!['load', 'prepare'].includes(action)) throw fail('invalid-argument', '지원하지 않는 요청입니다.');
  await refreshEntitlements(db, realtime, uid);
  const [config, tester, summary, progress] = await Promise.all([
    db.doc('appConfig/billing').get(), db.doc(`billingTesters/${uid}`).get(),
    summaryRef(db, uid).get(), db.doc(`users/${uid}/onboarding/progress`).get(),
  ]);
  const paid = summary.data()?.paid;
  const existingPaid = paid && (paid.validUntilMs > Date.now() || paid.autoRenew || ['billing_retry', 'paused', 'pending'].includes(paid.status));
  const legacyActive = summary.data()?.validUntilMs > Date.now() &&
    !['app_trial', 'app_store', 'google_play'].includes(summary.data()?.grantSource);
  const eligible = progress.data()?.phoneVerified === true && !existingPaid && !legacyActive;
  const enabled = purchasesAllowed(config.data(), tester.data()?.enabled === true, adapter.store) && eligible;
  if (action === 'prepare' && (!enabled || !products[input.productId])) throw fail('failed-precondition', '지금은 새 구독을 시작할 수 없습니다. 이용 상태를 확인해 주세요.');
  return {appAccountToken: account.appAccountToken, purchasesEnabled: enabled,
    productIds: Object.keys(products), ...summary.data()};
}

export async function acceptAppleNotification(db, payload) {
  const {decoded, environment} = await verifyApplePayload(payload, true);
  if (!tokenPattern.test(decoded.notificationUUID ?? '')) throw new Error('invalid-notification-id');
  if (decoded.notificationType === 'TEST') return; // Apple's connection test grants no access.
  const signed = decoded.data?.signedTransactionInfo;
  const verified = await verifyApplePayload(signed);
  if (verified.environment !== environment) throw new Error('environment-mismatch');
  const t = verified.decoded, ref = db.doc(`appStoreEvents/${environment}_${decoded.notificationUUID}`);
  await db.runTransaction(async tx => {
    if ((await tx.get(ref)).exists) return;
    tx.create(ref, {environment, originalId: t.originalTransactionId,
      appAccountToken: t.appAccountToken.toLowerCase(), productId: t.productId,
      // Retain only verified routing metadata, never raw receipts or PII.
      status: 'pending', nextAttemptAtMs: Date.now(), attempts: 0, createdAtMs: Date.now()});
  });
}

export async function processAppleEvent(db, realtime, ref) {
  const event = (await ref.get()).data();
  if (!event || event.status === 'done') return;
  try {
    const owner = (await db.doc(`billingTokenOwners/${event.appAccountToken}`).get()).data();
    if (owner?.deleted) { await ref.update({status: 'done', nextAttemptAtMs: null, processedAtMs: Date.now()}); return; }
    if (!owner?.uid) throw new Error('owner-unavailable');
    // Refresh/claim using fresh Apple data; notification order never determines access.
    const latest = await latestAppleSubscription(event.originalId, event.environment);
    const sub = await claimSubscription(db, owner.uid, latest.transaction);
    await refreshSubscription(db, realtime, sub);
    await ref.update({status: 'done', nextAttemptAtMs: null, processedAtMs: Date.now()});
  } catch (_) {
    const attempts = (event.attempts ?? 0) + 1;
    await ref.update({attempts, nextAttemptAtMs: Date.now() + Math.min(3600000, 60000 * 2 ** Math.min(attempts, 6)), status: 'pending'});
  }
}

export async function deleteBillingData(db, uid) {
  const ref = accountRef(db, uid), account = (await ref.get()).data();
  if (!account) return;
  // Tombstones reserve original purchases against reuse. No email/name/phone/receipt.
  // Token tombstones intentionally outlive the short-lived account-deletion job.
  const batch = db.batch();
  batch.set(ref, {deleted: true, deletedAtMs: Date.now()});
  if (account.appAccountToken) batch.set(db.doc(`billingTokenOwners/${account.appAccountToken}`), {deleted: true});
  batch.delete(summaryRef(db, uid));
  batch.delete(db.doc(`subscriptionEntitlements/${uid}`));
  await batch.commit();
  const subscriptions = await db.collection('appStoreSubscriptions').where('uid', '==', uid).get();
  for (const sub of subscriptions.docs) await sub.ref.set({deleted: true});
  const playSubscriptions = await db.collection('googlePlaySubscriptions').where('uid', '==', uid).get();
  for (const sub of playSubscriptions.docs) await sub.ref.set({deleted: true});
  const transactions = await db.collection('appStoreTransactions').where('uid', '==', uid).get();
  for (const transaction of transactions.docs) await transaction.ref.delete();
  await db.doc(`billingTesters/${uid}`).delete();
}
