import assert from 'node:assert/strict';
import fs from 'node:fs';
import {initializeApp, deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {getDatabase} from 'firebase-admin/database';
import {initializeTestEnvironment, assertFails} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc} from 'firebase/firestore';
import {billingAccount, refreshEntitlements, deleteBillingData, handleBilling} from '../src/billing.js';
import {claimPlaySubscription, refreshPlaySubscription, handlePlayBilling, acceptPlayNotification, processPlayEvent} from '../src/google-play-billing.js';
import {playSnapshot, playPackageName, purchaseKey} from '../src/google-play-policy.js';

assert.match(process.env.FIRESTORE_EMULATOR_HOST ?? '', /^(127\.0\.0\.1|localhost):\d+$/);
assert.match(process.env.FIREBASE_DATABASE_EMULATOR_HOST ?? '', /^(127\.0\.0\.1|localhost):\d+$/);
const projectId = 'demo-cloudboard-billing';
const app = initializeApp({projectId, databaseURL: `http://${process.env.FIREBASE_DATABASE_EMULATOR_HOST}?ns=${projectId}`});
const db = getFirestore(app), realtime = getDatabase(app);
const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
const env = await initializeTestEnvironment({projectId, firestore: {host, port: Number(port),
  rules: fs.readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8')}});
try {
  await env.clearFirestore(); await realtime.ref().remove();
  const a = await billingAccount(db, realtime, 'owner');
  await billingAccount(db, realtime, 'other');
  await db.doc('users/owner/onboarding/progress').set({phoneVerified: true, storeId: 'studio'});
  const item = {productId: 'com.sunmkim.cloudboard.plus.monthly', latestSuccessfulOrderId: 'GPA.example', expiryTime: new Date(Date.now() + 3600000).toISOString(),
    autoRenewingPlan: {autoRenewEnabled: true}, offerDetails: {basePlanId: 'monthly'}};
  let google = {subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE', acknowledgementState: 'ACKNOWLEDGEMENT_STATE_PENDING',
    externalAccountIdentifiers: {obfuscatedExternalAccountId: a.appAccountToken}, lineItems: [item], testPurchase: {}};
  let acknowledgements = 0, brokenAck = false;
  const api = {fetch: async () => google, acknowledge: async () => {
    assert.equal((await realtime.ref('subscriptionAccess/owner').get()).val().canStartClass, true, 'grant before acknowledgment');
    if (brokenAck) throw Error('temporary');
    acknowledgements++;
    google = {...google, acknowledgementState: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED'};
  }};
  const verify = (uid = 'owner', token = 'purchase-one') => handlePlayBilling(db, realtime, uid, {action: 'verify', purchaseToken: token}, api);
  assert.equal((await handlePlayBilling(db, realtime, 'owner', {}, api)).purchasesEnabled, false);
  assert.equal((await db.doc('subscriptionEntitlements/owner').get()).exists, false);
  await assert.rejects(verify(), {code: 'permission-denied'});
  await db.doc('billingTesters/owner').set({enabled: true});
  await assert.rejects(verify('other'), {code: 'permission-denied'});
  assert.equal((await verify()).verified, true);
  assert.equal(acknowledgements, 1);
  const sub = db.doc(`googlePlaySubscriptions/${purchaseKey('purchase-one')}`);
  const access = () => db.doc('subscriptionEntitlements/owner').get().then(s => s.data());
  assert.equal((await access()).plan, 'plus'); assert.equal((await access()).storeId, 'studio');
  const revision = (await access()).revision;
  await verify(); assert.equal((await access()).revision, revision); assert.equal(acknowledgements, 1);
  await db.doc('appConfig/billing').set({legalReady: true, productsReady: true, purchasesEnabled: true,
    googlePlayProductsReady: true, googlePlayPurchasesEnabled: true});
  assert.equal((await handleBilling(db, realtime, 'owner', {})).purchasesEnabled, false, 'Google subscriber cannot double-buy Apple');
  assert.equal((await handlePlayBilling(db, realtime, 'owner', {}, api)).purchasesEnabled, false, 'no duplicate Google subscription');

  // Expiry/revocation and failed renewals never inherit the device expiry.
  google = {...google, subscriptionState: 'SUBSCRIPTION_STATE_ON_HOLD'};
  await verify(); assert.equal((await access()).canStartClass, false);
  google = {...google, subscriptionState: 'SUBSCRIPTION_STATE_CANCELED',
    lineItems: [{...item, autoRenewingPlan: {autoRenewEnabled: false}}]};
  await verify(); assert.equal((await access()).canStartClass, true);
  assert.equal((await db.doc('users/owner/billing/summary').get()).data().paid.autoRenew, false);
  google = {...google, subscriptionState: 'SUBSCRIPTION_STATE_EXPIRED'};
  await verify(); assert.equal((await access()).canStartClass, false);
  google = {...google, subscriptionState: 'SUBSCRIPTION_STATE_PENDING', acknowledgementState: 'ACKNOWLEDGEMENT_STATE_PENDING'};
  await assert.rejects(verify(), {code: 'failed-precondition'});
  assert.equal(acknowledgements, 1); assert.equal((await access()).canStartClass, false);

  // Ack failure remains retryable even though a genuine paid entitlement committed.
  google = {...google, subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE', lineItems: [item]};
  brokenAck = true;
  await assert.rejects(verify(), {code: 'unavailable'});
  assert.equal((await access()).canStartClass, true);
  brokenAck = false; await verify(); assert.equal(acknowledgements, 2);
  await sub.update({leaseUntilMs: Date.now() + 60000});
  await assert.rejects(verify(), {code: 'aborted'});
  await sub.update({leaseUntilMs: 0});

  // An invalid replacement cannot hijack another Firebase account's subscription.
  await db.doc(`googlePlaySubscriptions/${purchaseKey('foreign')}`).set({uid: 'other'});
  google = {...google, linkedPurchaseToken: 'foreign'};
  await assert.rejects(verify('owner', 'invalid-link'), {code: 'permission-denied'});
  google = {...google, linkedPurchaseToken: 'purchase-one'};
  await verify('owner', 'purchase-two');
  assert.equal((await sub.get()).data().grant, null);
  assert.equal((await sub.get()).data().replacedBy, purchaseKey('purchase-two'));
  const oldRevision = (await access()).revision;
  await refreshPlaySubscription(db, realtime, sub, {fetch: () => {throw Error('must not refetch replaced');}});
  assert.equal((await access()).revision, oldRevision);

  // RTDN delivery is durable and idempotent; use API state, never event order.
  const payload = {packageName: playPackageName, subscriptionNotification: {notificationType: 13, purchaseToken: 'purchase-two'}};
  await acceptPlayNotification(db, 'message-1', {...payload, packageName: 'foreign.app'});
  assert.equal((await db.collection('googlePlayEvents').get()).size, 0);
  await acceptPlayNotification(db, 'test-message', {packageName: playPackageName, testNotification: {}});
  assert.equal((await db.collection('googlePlayEvents').get()).size, 0);
  await acceptPlayNotification(db, 'message-1', payload); await acceptPlayNotification(db, 'message-1', payload);
  assert.equal((await db.collection('googlePlayEvents').get()).size, 1);
  const eventRef = db.doc('googlePlayEvents/message-1');
  await processPlayEvent(db, realtime, eventRef, {fetch: async () => {throw Error('offline');}});
  assert.equal((await eventRef.get()).data().status, 'pending');
  // Stale "expired" notification cannot revoke a freshly renewed API subscription.
  await processPlayEvent(db, realtime, eventRef, api);
  assert.equal((await access()).canStartClass, true);
  assert.equal((await eventRef.get()).data().status, 'done');
  assert.equal((await eventRef.get()).data().purchaseToken, undefined);

  await acceptPlayNotification(db, 'duplicate-race', payload);
  const raced = db.doc('googlePlayEvents/duplicate-race');
  await processPlayEvent(db, realtime, raced, {fetch: async () => {
    await raced.set({status: 'done', nextAttemptAtMs: null, processedAtMs: Date.now()});
    throw Error('another worker completed');
  }});
  assert.equal((await raced.get()).data().nextAttemptAtMs, null, 'failed duplicate never requeues a completed event');
  await acceptPlayNotification(db, 'retired-unknown', {...payload,
    subscriptionNotification: {purchaseToken: 'unclaimed-expired-token'}});
  const retiredEvent = db.doc('googlePlayEvents/retired-unknown');
  await processPlayEvent(db, realtime, retiredEvent, {fetch: async () => {
    throw Object.assign(Error('gone'), {httpStatus: 410});
  }});
  assert.equal((await retiredEvent.get()).data().status, 'done');
  assert.equal((await retiredEvent.get()).data().purchaseToken, undefined);

  await db.doc('billingTesters/owner').set({enabled: false});
  await refreshEntitlements(db, realtime, 'owner'); assert.equal((await access()).canStartClass, false);
  await db.doc('billingTesters/owner').set({enabled: true});
  await refreshEntitlements(db, realtime, 'owner'); assert.equal((await access()).canStartClass, true);
  const second = db.doc(`googlePlaySubscriptions/${purchaseKey('purchase-two')}`);
  await refreshPlaySubscription(db, realtime, second, {fetch: async () => {throw Object.assign(Error('gone'), {httpStatus: 410});}});
  assert.equal((await access()).canStartClass, false);
  assert.equal((await second.get()).data().nextCheckAtMs, null);

  const client = env.authenticatedContext('owner').firestore();
  for (const path of [second.path, eventRef.path, 'billingTesters/owner', 'appConfig/billing']) {
    await assertFails(getDoc(doc(client, path)));
    await assertFails(setDoc(doc(client, path), {uid: 'owner', enabled: true}));
  }
  await db.doc('accountDeletions/owner').set({status: 'pending'});
  await deleteBillingData(db, 'owner');
  assert.deepEqual((await second.get()).data(), {deleted: true});
  assert.equal((await db.doc(`billingTokenOwners/${a.appAccountToken}`).get()).data().deleted, true);
  assert.equal((await verify('other', 'purchase-two')).retired, true);
  await acceptPlayNotification(db, 'after-delete', payload);
  await processPlayEvent(db, realtime, db.doc('googlePlayEvents/after-delete'), api);
  assert.equal((await db.doc('users/owner/billing/summary').get()).exists, false);
  assert.equal((await db.doc('subscriptionEntitlements/other').get()).exists, false);
  console.log('PASS Google Play: account ownership, test restriction, grant/ack order, expiry, holds, pending, retries, replacement, RTDN, 410, rules, deletion');
} finally {await env.cleanup(); await deleteApp(app);}
