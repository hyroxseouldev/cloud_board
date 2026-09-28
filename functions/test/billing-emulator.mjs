import assert from 'node:assert/strict';
import fs from 'node:fs';
import {initializeApp,deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {getDatabase} from 'firebase-admin/database';
import {initializeTestEnvironment,assertFails,assertSucceeds} from '@firebase/rules-unit-testing';
import {doc,getDoc,setDoc} from 'firebase/firestore';
import {billingAccount,claimSubscription,refreshSubscription,refreshEntitlements,deleteBillingData,handleBilling} from '../src/billing.js';
import {reconcileSlideLibraryFavorites} from '../src/slide-library.js';
assert.match(process.env.FIRESTORE_EMULATOR_HOST||'',/^(127\.0\.0\.1|localhost):\d+$/);
assert.match(process.env.FIREBASE_DATABASE_EMULATOR_HOST||'',/^(127\.0\.0\.1|localhost):\d+$/);
const projectId='demo-cloudboard-billing';
const app=initializeApp({projectId,databaseURL:`http://${process.env.FIREBASE_DATABASE_EMULATOR_HOST}?ns=${projectId}`});
const db=getFirestore(app),realtime=getDatabase(app);
const [host,port]=process.env.FIRESTORE_EMULATOR_HOST.split(':');
const env=await initializeTestEnvironment({projectId,firestore:{host,port:Number(port),rules:fs.readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8')}});
try {
  await env.clearFirestore(); await realtime.ref().remove();
  const fresh=await handleBilling(db,realtime,'fresh',{});
  assert.equal(fresh.purchasesEnabled,false);
  assert.equal((await db.doc('subscriptionEntitlements/fresh').get()).exists,false,'viewing billing must not consume trial eligibility');
  // Even a mistakenly enabled Firestore switch cannot open checkout without keys.
  await db.doc('appConfig/billing').set({legalReady:true,productsReady:true,purchasesEnabled:true});
  await db.doc('users/fresh/onboarding/progress').set({phoneVerified:true});
  const freeTrialEnd=Date.now()+3600000;
  await db.doc('onboardingTrials/fresh').set({endsAtMs:freeTrialEnd});
  for (const action of ['load','refresh']) {
    const status=await handleBilling(db,realtime,'fresh',{action});
    assert.equal(status.purchasesEnabled,false);
    assert.equal(status.status,'trialing');
    assert.equal(status.validUntilMs,freeTrialEnd);
  }
  await assert.rejects(handleBilling(db,realtime,'fresh',{action:'prepare',productId:'com.sunmkim.cloudboard.plus.monthly'}),{code:'failed-precondition'});
  await assert.rejects(handleBilling(db,realtime,'fresh',{action:'verify',signedTransaction:'not-verified'}),{code:'failed-precondition'});
  assert.equal((await db.collection('appStoreSubscriptions').get()).empty,true);
  await db.doc('appConfig/billing').delete();
  const [a,b]=await Promise.all([billingAccount(db,realtime,'owner'),billingAccount(db,realtime,'owner')]);
  assert.equal(a.appAccountToken,b.appAccountToken);
  await billingAccount(db,realtime,'other');
  const t={environment:'Sandbox',originalTransactionId:'100',transactionId:'101',
    productId:'com.sunmkim.cloudboard.plus.monthly',appAccountToken:a.appAccountToken,expiresDate:Date.now()+3600000};
  await assert.rejects(claimSubscription(db,'owner',t),{code:'permission-denied'});
  await db.doc('billingTesters/owner').set({enabled:true});
  await assert.rejects(claimSubscription(db,'other',t),{code:'permission-denied'});
  const sub=await claimSubscription(db,'owner',t);
  const fetch=async()=>({transaction:t,renewal:{autoRenewStatus:1},status:1});
  await refreshSubscription(db,realtime,sub,fetch);
  assert.equal((await db.doc('subscriptionEntitlements/owner').get()).data().plan,'plus');
  assert.equal((await realtime.ref('subscriptionAccess/owner').get()).val().plan,'plus');
  const revision=(await db.doc('subscriptionEntitlements/owner').get()).data().revision;
  await refreshSubscription(db,realtime,sub,fetch);
  assert.equal((await db.doc('subscriptionEntitlements/owner').get()).data().revision,revision,'idempotent duplicate');
  assert.equal((await db.collection('appStoreTransactions').get()).size,1);
  const trialEnd=Date.now()+600000;
  await db.doc('onboardingTrials/owner').set({endsAtMs:trialEnd});
  await refreshEntitlements(db,realtime,'owner');
  assert.equal((await db.doc('subscriptionEntitlements/owner').get()).data().validUntilMs,trialEnd);
  await refreshEntitlements(db,realtime,'owner',trialEnd);
  assert.equal((await db.doc('subscriptionEntitlements/owner').get()).data().plan,'plus');
  await db.doc('onboardingTrials/owner').delete();
  await refreshSubscription(db,realtime,sub,async()=>({transaction:{...t,revocationDate:Date.now()},renewal:{autoRenewStatus:0},status:5}));
  assert.equal((await realtime.ref('subscriptionAccess/owner').get()).val().canStartClass,false);
  await db.doc('users/owner/slideTemplates/saved').set({value:{favorite:true}});
  await db.doc('users/owner/libraryState/index').set({favoriteCount:7});
  assert.equal(await reconcileSlideLibraryFavorites(db,'owner'),0);
  assert.equal((await db.doc('users/owner/slideTemplates/saved').get()).data().value.favorite,true);
  // Lock prevents a second, out-of-order worker from fetching/storing a stale state.
  await sub.update({leaseUntilMs:Date.now()+60000});
  await assert.rejects(refreshSubscription(db,realtime,sub,fetch),{code:'aborted'});
  await sub.update({leaseUntilMs:0});
  const owner=env.authenticatedContext('owner').firestore(),other=env.authenticatedContext('other').firestore();
  await assertSucceeds(getDoc(doc(owner,'users/owner/billing/summary')));
  await assertFails(getDoc(doc(other,'users/owner/billing/summary')));
  for(const path of ['users/owner/billing/summary','billingAccounts/owner','billingTesters/owner','appConfig/billing','appStoreSubscriptions/Sandbox_100']) {
    await assertFails(setDoc(doc(owner,path),{purchasesEnabled:true,enabled:true}));
  }
  await assertFails(getDoc(doc(owner,'billingAccounts/owner')));
  await db.doc('appReleases/ios').set({enabled:false});
  await assertSucceeds(getDoc(doc(env.unauthenticatedContext().firestore(),'appReleases/ios')));
  await assertFails(setDoc(doc(owner,'appReleases/ios'),{enabled:true,minimumBuild:999999}));
  await db.doc('accountDeletions/owner').set({status:'pending'});
  await deleteBillingData(db,'owner'); await deleteBillingData(db,'owner');
  assert.equal((await db.doc(`billingTokenOwners/${a.appAccountToken}`).get()).data().deleted,true);
  await assert.rejects(billingAccount(db,realtime,'owner'),{code:'permission-denied'});
  await assert.rejects(claimSubscription(db,'other',t),{code:'permission-denied'});
  await refreshEntitlements(db,realtime,'owner');
  assert.equal((await db.doc('users/owner/billing/summary').get()).exists,false);
  console.log('PASS billing: token ownership, Sandbox restriction, idempotency, trial fallback, refund, lease, security rules, deletion');
} finally {await env.cleanup();await deleteApp(app);}
