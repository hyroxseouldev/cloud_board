import assert from 'node:assert/strict';
import {initializeApp,deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {getDatabase} from 'firebase-admin/database';
import {handleOnboarding,readOnboarding,sendOnboardingCode,verifyOnboardingCode,startOnboardingTrial} from '../src/onboarding.js';
import {billingAccount,refreshEntitlements,syncBillingEntitlement,handleBilling} from '../src/billing.js';
import {startFreePlan,syncVerifiedFree} from '../src/free-plan.js';
import {freeValidUntilMs} from '../src/billing-policy.js';
for(const key of ['FIRESTORE_EMULATOR_HOST','FIREBASE_DATABASE_EMULATOR_HOST'])
  assert.match(process.env[key]??'',/^(127\.0\.0\.1|localhost):\d+$/);
const projectId='demo-cloudboard-verified-free';
const app=initializeApp({projectId,databaseURL:`http://${process.env.FIREBASE_DATABASE_EMULATOR_HOST}?ns=${projectId}`});
const db=getFirestore(app),realtime=getDatabase(app),secret='isolated-test-only-secret';
const now=Date.now(),codes=new Map();
const send=async(phone,code)=>codes.set(phone,code);
const auth=uid=>({uid,token:{firebase:{sign_in_provider:'google.com'}}});
const call=(uid,input,database=db,rt=realtime)=>handleOnboarding({db:database,realtime:rt,auth:auth(uid),input,secret,send});
const access=async uid=>(await db.doc(`subscriptionEntitlements/${uid}`).get()).data();
const wire=async uid=>(await realtime.ref(`subscriptionAccess/${uid}`).get()).val();
async function proof(uid) { await db.doc(`users/${uid}/onboarding/progress`).set({phoneVerified:true}); }
async function free(uid) {
  const a=await access(uid),r=await wire(uid);
  assert.equal(a.plan,'free');assert.equal(a.canStartClass,true);
  assert.equal(a.validUntilMs,freeValidUntilMs);assert.equal(a.policyVersion,'plan-entitlements-v2');
  assert.equal(a.maxWorkouts,7);assert.equal(a.maxSavedSlides,3);assert.equal(a.maxActiveDisplays,1);
  assert.deepEqual(r,a);assert.equal((await db.doc(`onboardingTrials/${uid}`).get()).exists,false);
}
function transactionFailure(onCall) {
  let calls=0;
  return new Proxy(db,{get(target,key){
    if(key==='runTransaction') return (...args)=>{
      if(++calls===onCall) throw new Error('injected-firestore-unavailable');
      return target.runTransaction(...args);
    };
    const value=Reflect.get(target,key);return typeof value==='function'?value.bind(target):value;
  }});
}
function realtimeFailure(uid,operation='transaction') {
  return new Proxy(realtime,{get(target,key){
    if(key==='ref') return path=>{
      const ref=target.ref(path);
      return path===`subscriptionAccess/${uid}` ? new Proxy(ref,{get(object,method){
        if(method===operation) return async()=>{throw new Error('injected-realtime-unavailable');};
        const value=Reflect.get(object,method);return typeof value==='function'?value.bind(object):value;
      }}) : ref;
    };
    const value=Reflect.get(target,key);return typeof value==='function'?value.bind(target):value;
  }});
}
try {
  // Empty and forged/leftover Free never authorize an unverified account.
  for(const uid of ['new','stale-free','truthy']) {
    if(uid==='truthy') await db.doc(`users/${uid}/onboarding/progress`).set({phoneVerified:'true'});
    if(uid==='stale-free') {
      await db.doc(`onboardingFree/${uid}`).set({enabled:true});
      const stale={source:'legacy',plan:'free',status:'active',validUntilMs:freeValidUntilMs,canStartClass:true};
      await db.doc(`subscriptionEntitlements/${uid}`).set({...stale,webGrant:stale});
      await realtime.ref(`subscriptionAccess/${uid}`).set(stale);
    }
    const state=await call(uid,{action:'load'});
    assert.equal(state.phoneRequired,true);assert.equal(state.hasAccess,false);assert.equal(state.activationReady,false);
    assert.equal((await access(uid)).canStartClass,false);assert.equal((await wire(uid)).canStartClass,false);
    for(const action of ['startFree','startTrial']) await assert.rejects(call(uid,{action}),{code:'permission-denied'});
  }
  await call('verified',{action:'sendCode',phone:'+821011223344'});
  const response=await call('verified',{action:'verifyCode',code:codes.get('+821011223344')});
  assert.equal(response.activationReady,true);assert.equal(response.freeActive,true);
  assert.equal(response.trialEligible,false);assert.equal(response.suggestedTrialEndsAtMs,0);
  assert.deepEqual(response.profile,{}); // Center questions never gate activation.
  await free('verified');
  const initialMarker=(await db.doc('onboardingFree/verified').get()).data();
  const initialStore=response.storeId;
  await Promise.all(Array.from({length:8},(_,i)=>call('verified',{action:i%2?'startTrial':'load'})));
  assert.deepEqual((await db.doc('onboardingFree/verified').get()).data(),initialMarker);
  assert.equal((await call('verified',{action:'load'})).storeId,initialStore);
  await free('verified');
  assert.equal((await handleBilling(db,realtime,'verified',{}, {store:'google_play'})).phoneRequired,false);
  assert.equal((await handleBilling(db,realtime,'new',{}, {store:'google_play'})).phoneRequired,true);
  // Obsolete manual-enrollment and paid rollout flags cannot alter approved Free.
  await db.doc('appConfig/freePlan').set({enrollmentEnabled:false});
  await db.doc('appConfig/planPolicy').set({enabled:false,version:'plan-entitlements-v2'});
  await proof('old-verified');
  await call('old-verified',{action:'load'});await free('old-verified');
  assert.equal((await db.collection('centers').where('ownerUid','==','old-verified').get()).size,1);
  // Verification persisted, but each later write can fail. A load repairs all
  // checkpoints without another SMS request and without a second enrollment.
  for(const [uid,stage] of [['fail-enrollment',1],['fail-account',2],['fail-projection',3]]) {
    await proof(uid);
    await assert.rejects(call(uid,{action:'load'},transactionFailure(stage)),/injected-firestore/);
    assert.equal((await db.doc(`users/${uid}/onboarding/progress`).get()).data().phoneVerified,true);
    await call(uid,{action:'load'});await free(uid);
  }
  await proof('fail-account-read');
  await assert.rejects(call('fail-account-read',{action:'load'},db,realtimeFailure('fail-account-read','get')),/injected-realtime/);
  await call('fail-account-read',{action:'load'});await free('fail-account-read');
  await proof('fail-wire');
  await assert.rejects(call('fail-wire',{action:'load'},db,realtimeFailure('fail-wire')),/injected-realtime/);
  assert.equal((await access('fail-wire')).plan,'free');assert.equal(await wire('fail-wire'),null);
  await Promise.all([call('fail-wire',{action:'load'}),syncVerifiedFree(db,realtime,'fail-wire')]);
  await free('fail-wire');
  // The actual SMS verification transaction is a durable checkpoint too.
  await sendOnboardingCode(db,'sms-interrupted','+821022334455',secret,send);
  await verifyOnboardingCode(db,'sms-interrupted',codes.get('+821022334455'),secret);
  assert.equal((await db.doc('onboardingFree/sms-interrupted').get()).exists,false);
  await syncVerifiedFree(db,realtime,'sms-interrupted');await free('sms-interrupted');
  // Server-issued existing trials, paid and pilot rights retain their own expiry,
  // even if a historical account lacks a migrated phone proof.
  for(const [uid,grant] of [
    ['paid',{source:'app_store',plan:'plus',status:'active',validUntilMs:now+600000}],
    ['trial',{source:'app_trial',plan:'premium',status:'trialing',validUntilMs:now+500000}],
    ['pilot',{source:'pilot',plan:'legacy',status:'pilot',validUntilMs:now+400000,maxActiveDisplays:4}],
  ]) {
    await db.doc(`subscriptionEntitlements/${uid}`).set(grant);
    if(uid==='trial') await db.doc(`onboardingTrials/${uid}`).set({startedAtMs:now-1000,endsAtMs:grant.validUntilMs});
    const before=await call(uid,{action:'load'});
    assert.equal(before.phoneRequired,true);assert.equal(before.activationReady,true);assert.equal(before.freeActive,false);
    assert.equal((await access(uid)).validUntilMs,grant.validUntilMs);assert.equal((await wire(uid)).plan,grant.plan);
    assert.equal((await db.doc(`onboardingFree/${uid}`).get()).exists,false);
    await proof(uid);await startOnboardingTrial(db,realtime,uid);
    assert.equal((await access(uid)).validUntilMs,grant.validUntilMs);
    const after=await readOnboarding(db,uid,grant.validUntilMs,realtime);
    assert.equal(after.freeActive,true);assert.equal((await access(uid)).validUntilMs,freeValidUntilMs);
    if(uid==='trial') assert.equal((await db.doc(`onboardingTrials/${uid}`).get()).data().endsAtMs,grant.validUntilMs);
  }
  // A proof-only linked bridge preserves a paid baseline; expiry remains Free.
  await db.doc('subscriptionEntitlements/web-proof-only').set({source:'pilot',plan:'legacy',status:'pilot',
    validUntilMs:now+600000,webGrant:{phoneVerified:true,revision:1}});
  await syncBillingEntitlement(db,realtime,'web-proof-only');
  assert.equal((await access('web-proof-only')).plan,'legacy');
  assert.equal((await db.doc('users/web-proof-only/onboarding/progress').get()).data().phoneVerified,true);
  await db.doc('subscriptionEntitlements/web-proof-only').update({webGrant:{revision:2}});
  await readOnboarding(db,'web-proof-only',now+600000,realtime);
  assert.equal((await access('web-proof-only')).plan,'free');
  const expiredWeb={source:'free',plan:'legacy',status:'expired',validUntilMs:0,phoneVerified:true,revision:1};
  await db.doc('subscriptionEntitlements/web-verified-expired').set({webGrant:expiredWeb});
  await syncBillingEntitlement(db,realtime,'web-verified-expired');
  assert.equal((await access('web-verified-expired')).plan,'free');
  // History without verified proof is never an enrollment credential.
  await db.doc('subscriptionEntitlements/web-history-only').set({webGrant:{...expiredWeb,phoneVerified:false,paidHistory:true,trialUsed:true}});
  await syncBillingEntitlement(db,realtime,'web-history-only');
  assert.equal((await access('web-history-only')).canStartClass,false);
  assert.equal((await db.doc('onboardingFree/web-history-only').get()).exists,false);
  for(const uid of ['deleting','deleted']) {
    await proof(uid);
    if(uid==='deleting') await db.doc(`accountDeletions/${uid}`).set({status:'pending'});
    else await db.doc(`billingAccounts/${uid}`).set({deleted:true});
    await syncVerifiedFree(db,realtime,uid);
    await assert.rejects(call(uid,{action:'load'}),{code:'permission-denied'});
    assert.equal((await db.doc(`onboardingFree/${uid}`).get()).exists,false);assert.equal(await wire(uid),null);
  }
  console.log('PASS verified Free: automatic SMS, old-client no-trial, lazy recovery, strict proof, partial FS/RTDB failure, concurrency, existing paid/trial/pilot, web bridge, deletion');
} finally {await db.terminate();await deleteApp(app);}
