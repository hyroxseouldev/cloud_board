// Focused real local Firestore/RTDB enrollment overlap regression. Opt-in so
// ordinary unit runs never connect to any backend implicitly.
import test from 'node:test';
import assert from 'node:assert/strict';
import {initializeApp, deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {getDatabase} from 'firebase-admin/database';
import {setUsageEnrollment, reconcileUsageEnrollment, handleClassAdmission} from '../src/class-admission.js';
import {imageUsagePolicyRevision} from '../src/image-usage-policy.js';

const enabled = process.env.USAGE_ENROLLMENT_OVERLAP_TEST === '1';
const projectId = 'demo-cloudboard-usage-overlap';
const deferred = () => {
  let resolve;
  const promise = new Promise(done => { resolve = done; });
  return {promise, resolve};
};
test('actual local enrollment original-setter and automatic-retry overlap', {skip: !enabled}, async t => {
  assert.equal(process.env.GCLOUD_PROJECT, projectId);
  for (const key of ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_DATABASE_EMULATOR_HOST']) {
    assert.match(process.env[key] ?? '', /^(127\.0\.0\.1|localhost):\d+$/);
  }
  const app = initializeApp({projectId, databaseURL:`https://${projectId}-default-rtdb.firebaseio.com`}, 'usage-overlap');
  const db = getFirestore(app), realtime = getDatabase(app), now = Date.parse('2026-11-14T03:00:00Z');
  const ctx = {db, realtime, projectId, clock: () => now};
  const seed = async ownerId => {
    await db.doc(`imageUsageAccounts/${ownerId}`).set({mode:'legacy',revision:0,inventoryComplete:true,
      eligibility:{tokenFree:true,rulesReady:true},storageUsedBytes:0,storageReservedBytes:0,storageUnknownBytes:0});
    await db.doc(`subscriptionEntitlements/${ownerId}`).set({plan:'free',canStartClass:true,status:'active',validUntilMs:now+86400000});
  };
  const input = ownerId => ({ownerId,mode:'enrolled',policyPlan:'free',consentRevision:'explicit-v1',requestId:`enrollment_${ownerId}_01`});
  const heldSetter = ownerId => {
    const reached = deferred(), release = deferred();
    let first = true;
    const paused = {...ctx, db:{doc:db.doc.bind(db),getAll:db.getAll.bind(db),runTransaction:async (...args) => {
      if (first) { first = false; reached.resolve(); await release.promise; }
      return db.runTransaction(...args);
    }}};
    const pending = setUsageEnrollment(paused,input(ownerId));
    pending.catch(() => {});
    return {reached:reached.promise,release:release.resolve,pending};
  };
  try {
    await db.doc('appConfig/imageUsage').set({schemaVersion:1,policyRevision:imageUsagePolicyRevision,
      enabled:true,allowedProjectIds:[projectId]});
    await t.test('simultaneous setters share one claim, operation, audit, revision', async () => {
      const ownerId='simultaneous'; await seed(ownerId);
      const values = await Promise.all(Array.from({length:12},() => setUsageEnrollment(ctx,input(ownerId))));
      for (const value of values) assert.deepEqual(value,values[0]);
      assert.equal(values[0].enrollmentRevision,1);
      const account = (await db.doc(`imageUsageAccounts/${ownerId}`).get()).data();
      assert.equal(account.enrollmentPending,false); assert.equal(account.revision,2);
      assert.equal((await db.collection(`imageUsageAccounts/${ownerId}/operations`).get()).size,1);
      assert.equal((await db.collection(`imageUsageAccounts/${ownerId}/audit`).get()).size,1);
      assert.equal((await realtime.ref(`users/${ownerId}/usageGate`).get()).val().enrollmentRevision,1);
    });
    await t.test('automatic retry overlaps held original and cannot replace another claim', async () => {
      const ownerId='retry_overlap'; await seed(ownerId);
      const held = heldSetter(ownerId);
      try {
        await held.reached;
        const gate = (await realtime.ref(`users/${ownerId}/usageGate`).get()).val();
        assert.equal(gate.mode,'enrolling');
        await assert.rejects(setUsageEnrollment(ctx,{...input(ownerId),requestId:'different_enrollment_01'}),
          error => error.details?.reason === 'usage_reconciliation_pending');
        assert.deepEqual((await realtime.ref(`users/${ownerId}/usageGate`).get()).val(),gate);
        const recovered = await reconcileUsageEnrollment(ctx,{ownerId});
        held.release();
        assert.deepEqual(await held.pending,recovered);
        assert.equal((await db.doc(`imageUsageAccounts/${ownerId}`).get()).data().revision,2);
        assert.equal((await db.collection(`imageUsageAccounts/${ownerId}/audit`).get()).size,1);
      } finally { held.release(); await Promise.allSettled([held.pending]); }
    });
    await t.test('late original acknowledgment preserves a class started after automatic recovery', async () => {
      const ownerId='class_overlap'; await seed(ownerId);
      const held = heldSetter(ownerId);
      try {
        await held.reached;
        const recovered = await reconcileUsageEnrollment(ctx,{ownerId});
        const actor = {uid:ownerId,token:{firebase:{sign_in_provider:'password'}}};
        const workout = {id:'local_workout',ownerId,author:{id:ownerId,displayName:'Coach'},name:'Local',folder:'',
          brandL:'',brandR:'',createdAt:now,updatedAt:now,soundVolume:0,countdownSeconds:0,
          modules:[{id:'module1',name:'Work',text:'',imageUrl:'',workSeconds:1,restSeconds:0,sets:1,beep:false,coverImage:false}]};
        const prepared = await handleClassAdmission({...ctx,actor,input:{schemaVersion:1,action:'prepare',
          requestId:'prepare_overlap_01',workout,targetDeviceIds:[],controllerDeviceId:'controller',clientFingerprint:'local'}});
        const started = await handleClassAdmission({...ctx,actor,input:{schemaVersion:1,action:'commit',requestId:'commit_overlap_01',
          admissionId:prepared.admissionId,sessionId:prepared.sessionId,epoch:prepared.epoch,manifestHash:prepared.manifestHash,
          start:{stepIndex:0,durationMs:1000,briefing:false,scheduled:false,scheduledAtMs:null,updatedByDeviceId:'controller'}}});
        assert.equal(started.status,'active');
        const before = (await realtime.ref(`users/${ownerId}`).get()).val();
        const accountBefore = (await db.doc(`imageUsageAccounts/${ownerId}`).get()).data();
        assert.equal(before.usageGate.phase,'active');
        held.release();
        assert.deepEqual(await held.pending,recovered);
        assert.deepEqual((await realtime.ref(`users/${ownerId}`).get()).val(),before);
        assert.deepEqual((await db.doc(`imageUsageAccounts/${ownerId}`).get()).data(),accountBefore);
        assert.equal(accountBefore.activeAdmissionId,prepared.admissionId);
        assert.equal((await db.collection(`imageUsageAccounts/${ownerId}/audit`).get()).size,1);
      } finally { held.release(); await Promise.allSettled([held.pending]); }
    });
    await t.test('a late older claim cannot overwrite a newer acknowledged enrollment', async () => {
      const ownerId='newer_claim'; await seed(ownerId);
      const held = heldSetter(ownerId);
      try {
        await held.reached;
        await reconcileUsageEnrollment(ctx,{ownerId});
        const newer = await setUsageEnrollment(ctx,{...input(ownerId),mode:'observe',requestId:'newer_observe_claim_01'});
        assert.equal(newer.enrollmentRevision,2);
        const before = (await realtime.ref(`users/${ownerId}`).get()).val();
        const accountBefore = (await db.doc(`imageUsageAccounts/${ownerId}`).get()).data();
        held.release();
        await assert.rejects(held.pending,error => error.details?.reason === 'usage_reconciliation_pending');
        assert.deepEqual((await realtime.ref(`users/${ownerId}`).get()).val(),before);
        assert.deepEqual((await db.doc(`imageUsageAccounts/${ownerId}`).get()).data(),accountBefore);
        assert.equal((await setUsageEnrollment(ctx,input(ownerId))).enrollmentRevision,1);
        assert.deepEqual((await realtime.ref(`users/${ownerId}`).get()).val(),before);
        assert.equal((await db.collection(`imageUsageAccounts/${ownerId}/audit`).get()).size,2);
      } finally { held.release(); await Promise.allSettled([held.pending]); }
    });
  } finally { await deleteApp(app); }
});
