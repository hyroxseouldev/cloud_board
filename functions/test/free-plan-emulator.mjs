import assert from 'node:assert/strict';
import fs from 'node:fs';
import {initializeApp, deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {getDatabase} from 'firebase-admin/database';
import {initializeTestEnvironment, assertFails} from '@firebase/rules-unit-testing';
import {doc, setDoc} from 'firebase/firestore';
import {startFreePlan} from '../src/free-plan.js';
import {handleBilling, refreshEntitlements, syncBillingEntitlement} from '../src/billing.js';
import {readOnboarding, startOnboardingTrial} from '../src/onboarding.js';
assert.match(process.env.FIRESTORE_EMULATOR_HOST ?? '', /^(127\.0\.0\.1|localhost):\d+$/);
assert.match(process.env.FIREBASE_DATABASE_EMULATOR_HOST ?? '', /^(127\.0\.0\.1|localhost):\d+$/);
const projectId = 'demo-cloudboard-free';
const app = initializeApp({projectId, databaseURL: `http://${process.env.FIREBASE_DATABASE_EMULATOR_HOST}?ns=${projectId}`});
const db = getFirestore(app), realtime = getDatabase(app);
const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
const env = await initializeTestEnvironment({projectId, firestore: {host, port: Number(port), rules: fs.readFileSync('firestore.rules', 'utf8')}});
async function account(uid) {
  await db.doc(`users/${uid}/onboarding/progress`).set({phoneVerified: true, storeId: uid});
  await db.doc(`centers/${uid}`).set({ownerUid: uid, revision: 0, profile: {
    purpose: 'operating', role: 'owner', centerName: '센터', centerTypes: ['gym'], province: '서울', district: '강남구',
  }});
}
const access = async uid => (await realtime.ref(`subscriptionAccess/${uid}`).get()).val();
try {
  await env.clearFirestore(); await realtime.ref().remove();
  await assert.rejects(startFreePlan(db, realtime, 'unknown'), {code: 'permission-denied'});
  await account('owner');
  await Promise.all([startFreePlan(db, realtime, 'owner'), startFreePlan(db, realtime, 'owner')]);
  assert.equal((await access('owner')).maxActiveDisplays, 1);
  assert.equal((await db.doc('onboardingTrials/owner').get()).exists, false);
  assert.equal((await readOnboarding(db, 'owner')).trialEligible, true);
  // Free access must not be mistaken for an active legacy paid grant. Preparing
  // a purchase respects the store kill switch without replacing Free access.
  const prepare = () => handleBilling(db, realtime, 'owner', {
    action: 'prepare', productId: 'com.sunmkim.cloudboard.plus.monthly',
  }, {store: 'google_play'});
  await assert.rejects(prepare(), {code: 'failed-precondition'});
  await db.doc('appConfig/billing').set({legalReady: true,
    googlePlayProductsReady: true, googlePlayPurchasesEnabled: true});
  const purchase = await prepare();
  assert.equal(purchase.purchasesEnabled, true);
  assert.equal(purchase.grantSource, 'app_free');
  assert.equal((await access('owner')).plan, 'free');
  assert.equal((await db.doc('onboardingTrials/owner').get()).exists, false);
  const first = (await db.doc('onboardingFree/owner').get()).data();
  await startOnboardingTrial(db, realtime, 'owner');
  const trial = (await db.doc('onboardingTrials/owner').get()).data();
  assert.equal((await access('owner')).plan, 'premium');
  await startFreePlan(db, realtime, 'owner');
  assert.equal((await access('owner')).plan, 'premium');
  assert.deepEqual((await db.doc('onboardingFree/owner').get()).data(), first);
  await refreshEntitlements(db, realtime, 'owner', trial.endsAtMs);
  assert.equal((await access('owner')).plan, 'free');
  assert.equal((await readOnboarding(db, 'owner', trial.endsAtMs)).trialEligible, false);
  await assert.rejects(startOnboardingTrial(db, realtime, 'owner', trial.endsAtMs), {code: 'failed-precondition'});
  await account('paid');
  const until = Date.now() + 100000;
  await db.doc('subscriptionEntitlements/paid').set({source: 'legacy', managed: true, plan: 'legacy', validUntilMs: until, maxActiveDisplays: 4, displayLimit: 4});
  await startFreePlan(db, realtime, 'paid');
  assert.equal((await access('paid')).validUntilMs, until);
  assert.equal((await access('paid')).maxActiveDisplays, 4);
  await refreshEntitlements(db, realtime, 'paid', until);
  assert.equal((await access('paid')).plan, 'free');
  assert.equal((await readOnboarding(db, 'paid', until)).trialEligible, false);
  await assert.rejects(startOnboardingTrial(db, realtime, 'paid', until), {code: 'failed-precondition'});

  // SQL grant revisions are source-local. A newer projection must still consume
  // a low-numbered web grant, retain it, and honor its later cancellation.
  const web = {source: 'live', managed: true, plan: 'plus', status: 'active',
    validUntilMs: until, revision: 2, storeId: 'web-store', displaysUnlimited: false,
    maxActiveDisplays: 1, displayLimit: 1, canStartClass: true, canPairDisplay: true,
    trialUsed: true, paidHistory: true};
  await db.doc('subscriptionEntitlements/web-only').set({...web, revision: 40, webGrant: web});
  await realtime.ref('subscriptionAccess/web-only').set({...web, revision: 40});
  await syncBillingEntitlement(db, realtime, 'web-only');
  assert.equal((await db.doc('billingAccounts/web-only').get()).exists, true, 'web sync initializes reconciliation without a native billing visit');
  assert.equal((await access('web-only')).maxActiveDisplays, 3);
  assert.equal((await access('web-only')).validUntilMs, until);
  assert.equal((await db.doc('onboardingFree/web-only').get()).exists, true, 'verified web history does not require native progress');
  const canceledWeb = {...web, source: 'free', revision: 3, status: 'expired',
    validUntilMs: 0, canStartClass: false, canPairDisplay: false};
  await db.doc('subscriptionEntitlements/web-only').update({webGrant: canceledWeb});
  await refreshEntitlements(db, realtime, 'web-only');
  assert.equal((await access('web-only')).plan, 'free', 'old RTDB snapshot cannot resurrect canceled web access');
  assert.equal((await access('web-only')).maxActiveDisplays, 1);
  assert.equal((await access('web-only')).webGrant, undefined, 'server grant ledger stays in Firestore');
  const projectedWeb = (await db.doc('subscriptionEntitlements/web-only').get()).data();
  assert.deepEqual(projectedWeb.webGrant, canceledWeb);
  await refreshEntitlements(db, realtime, 'web-only');
  assert.equal((await db.doc('subscriptionEntitlements/web-only').get()).data().revision, projectedWeb.revision);
  await account('web-only');
  assert.equal((await readOnboarding(db, 'web-only')).trialEligible, false);
  await assert.rejects(startOnboardingTrial(db, realtime, 'web-only'), {code: 'failed-precondition'});

  // A delayed web expiry cannot replace a native paid entitlement. Its own
  // expiry still falls back to Free and neither source's history is erased.
  await account('mixed');
  await startFreePlan(db, realtime, 'mixed');
  await db.doc('appStoreSubscriptions/Production_mixed').set({uid: 'mixed', environment: 'Production', grant: {
    source: 'app_store', plan: 'premium', status: 'active', validUntilMs: until,
    expiresAtMs: until, autoRenew: false,
  }});
  await db.doc('subscriptionEntitlements/mixed').update({webGrant: {...canceledWeb, revision: 100}});
  await refreshEntitlements(db, realtime, 'mixed');
  assert.equal((await access('mixed')).plan, 'premium');
  assert.equal((await access('mixed')).validUntilMs, until);
  await refreshEntitlements(db, realtime, 'mixed', until);
  assert.equal((await access('mixed')).plan, 'free');
  assert.equal((await readOnboarding(db, 'mixed', until)).trialEligible, false);

  const pending = {source: 'free', managed: true, plan: 'legacy', status: 'pending_connection',
    validUntilMs: 0, revision: 1, canStartClass: false, canPairDisplay: true,
    trialUsed: false, paidHistory: false};
  await db.doc('subscriptionEntitlements/web-pending').set({...pending, webGrant: pending});
  await realtime.ref('subscriptionAccess/web-pending').set(pending);
  await syncBillingEntitlement(db, realtime, 'web-pending');
  assert.equal((await db.doc('onboardingFree/web-pending').get()).exists, false);
  assert.equal((await access('web-pending')).status, 'pending_connection');
  for (const uid of ['web-deleting', 'web-deleted']) {
    await db.doc(`subscriptionEntitlements/${uid}`).set({webGrant: canceledWeb});
    if (uid === 'web-deleting') await db.doc(`accountDeletions/${uid}`).set({status: 'pending'});
    else await db.doc(`billingAccounts/${uid}`).set({deleted: true});
    await syncBillingEntitlement(db, realtime, uid);
    assert.equal((await db.doc(`onboardingFree/${uid}`).get()).exists, false);
    assert.equal((await access(uid)), null);
  }
  assert.equal((await db.doc('billingAccounts/web-deleting').get()).exists, false);
  await db.doc('appConfig/freePlan').set({enrollmentEnabled: false});
  await account('blocked');
  await assert.rejects(startFreePlan(db, realtime, 'blocked'), {code: 'failed-precondition'});
  await startFreePlan(db, realtime, 'owner'); // Enrollment switch never revokes existing users.
  assert.equal((await access('owner')).canStartClass, true);
  const client = env.authenticatedContext('owner').firestore();
  for (const path of ['onboardingFree/owner', 'subscriptionEntitlements/owner', 'appConfig/freePlan']) {
    await assertFails(setDoc(doc(client, path), {enabled: true, maxActiveDisplays: 99}));
  }
  await db.doc('accountDeletions/owner').set({status: 'pending'});
  await assert.rejects(startFreePlan(db, realtime, 'owner'), {code: 'permission-denied'});
  console.log('PASS Free: verified enrollment, concurrency, Free purchase preparation, paid/trial priority, web/native expiry fallback, source-local revisions, no retrial, enrollment switch, server-only grants');
} finally {await env.cleanup(); await db.terminate(); await deleteApp(app);}
