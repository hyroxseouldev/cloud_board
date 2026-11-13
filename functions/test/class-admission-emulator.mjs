import assert from 'node:assert/strict';
import {handleClassAdmission, setUsageEnrollment, processUsageOutbox, reconcileUsageSession, reconcileUsageEnrollment} from '../src/class-admission.js';
import {readUsage, reserveTransfer, settleTransfer, requireUsageContext} from '../src/image-usage-ledger.js';
import {imageUsagePolicyRevision, usagePeriods} from '../src/image-usage-policy.js';

export async function classAdmissionScenarios({ctx, seed, expectReason, report}) {
  const ownerId='class-owner', tvUid='class-tv', deviceId='tv1';
  let now=Date.parse('2026-11-30T14:59:50Z'); ctx={...ctx,clock:()=>now};
  await seed(ownerId,'premium');
  await ctx.realtime.ref(`users/${ownerId}`).set({devices:{[deviceId]:{id:deviceId,paired:true,displayUid:tvUid,
    pairingCode:'123456',pairedAtMs:now-1000,imageUsageProtocol:1,preparationProtocol:2,playbackProtocol:5}}});
  await ctx.realtime.ref(`displayAccess/${tvUid}`).set({ownerId,deviceId,pairingCode:'123456',pairedAtMs:now-1000});
  await setUsageEnrollment(ctx,{ownerId,mode:'enrolled',policyPlan:'premium',consentRevision:'image-usage-2.1.5-v1',requestId:'enroll_class_01'});
  const file=ctx.bucket.file(`users/${ownerId}/managed-images/workout/test/image`);
  await file.save(Buffer.from('test-image'),{resumable:false,metadata:{contentType:'image/png'}});
  const [m]=await file.getMetadata(), asset={assetId:'asset_class',ownerId,path:file.name,bucket:ctx.bucket.name,
    generation:String(m.generation),sizeBytes:10,sha256:'a'.repeat(64),contentType:'image/png',tokenFree:true,
    source:`https://asia-northeast3-${ctx.projectId}.cloudfunctions.net/cloudboardMedia?assetId=asset_class&v=${m.generation}`};
  await ctx.db.doc(`imageUsageAccounts/${ownerId}/assets/${asset.assetId}`).set(asset);
  const actor={uid:ownerId,token:{firebase:{sign_in_provider:'password'}}};
  const workout={id:'workout1',ownerId,author:{id:ownerId,displayName:'Coach',photoUrl:null},name:'Class',folder:'',
    createdAt:now-1000,updatedAt:now,brandL:'',brandR:'',soundVolume:0,countdownSeconds:3,
    modules:[{id:'m1',name:'Work',text:'',beep:true,coverImage:false,workSeconds:10,restSeconds:0,sets:1,imageUrl:asset.source}]};
  const prepare={schemaVersion:1,action:'prepare',requestId:'prepare_class_01',workout,targetDeviceIds:[deviceId],controllerDeviceId:'controller',clientFingerprint:'local1'};
  let failOnce=true;
  const before={...ctx,realtime:{ref:path=>{
    const ref=ctx.realtime.ref(path); if(path!==`users/${ownerId}`) return ref;
    return {get:()=>ref.get(),transaction:async fn=>{if(failOnce){failOnce=false;throw new Error('injected before RTDB publish');}return ref.transaction(fn);}};
  }}};
  await assert.rejects(handleClassAdmission({...before,actor,input:prepare}),/injected before/);
  let usage=await readUsage(ctx,{ownerId}); assert.equal(usage.downloadDay.reservedBytes,20);
  const admission=await handleClassAdmission({...ctx,actor,input:prepare});
  assert.equal(admission.reservedDownloadBytes,20); assert.equal(admission.status,'preparing');
  const retry=await handleClassAdmission({...ctx,actor,input:prepare}); assert.equal(retry.admissionId,admission.admissionId);
  assert.equal((await readUsage(ctx,{ownerId})).downloadDay.reservedBytes,20);
  await expectReason(handleClassAdmission({...ctx,actor,input:{...prepare,workout:{...workout,name:'changed'}}}),'idempotency_conflict');
  report('prepare failure before publication is retried idempotently without double reservation');

  // Move one request over both a KST day and month boundary. Metadata and real
  // source live in Storage emulator; gateway transport is B/root validation.
  now+=20000;
  const body={ownerId,actorUid:ownerId,deviceId:null,leaseId:'lease1',assetId:asset.assetId,generation:asset.generation,
    sizeBytes:10,admissionId:admission.admissionId,sessionId:admission.sessionId,purpose:'preparation'};
  const attempt=await reserveTransfer(ctx,body);
  await settleTransfer(ctx,{ownerId,attemptId:attempt.attemptId,outcome:'served',bodyBytes:10});
  const oldDay=(await ctx.db.doc(`imageUsageAccounts/${ownerId}/periods/downloadDay_2026-11-30`).get()).data();
  assert.equal(oldDay.reservedBytes,10); assert.equal(oldDay.usedBytes,0);
  usage=await readUsage(ctx,{ownerId}); assert.equal(usage.downloadDay.key,'2026-12-01');
  assert.equal(usage.downloadDay.usedBytes,10);assert.equal(usage.downloadMonth.key,'2026-12');
  const uncertain=await reserveTransfer(ctx,body);
  await settleTransfer(ctx,{ownerId,attemptId:uncertain.attemptId,outcome:'unknown',bodyBytes:0});
  await settleTransfer(ctx,{ownerId,attemptId:uncertain.attemptId,outcome:'unknown',bodyBytes:0});
  assert.equal((await readUsage(ctx,{ownerId})).downloadDay.unknownBytes,10);
  await settleTransfer(ctx,{ownerId,attemptId:uncertain.attemptId,outcome:'served',bodyBytes:10});
  await settleTransfer(ctx,{ownerId,attemptId:uncertain.attemptId,outcome:'not_sent',bodyBytes:0});
  usage=await readUsage(ctx,{ownerId});assert.equal(usage.downloadDay.usedBytes,20);assert.equal(usage.downloadDay.unknownBytes,0);
  report('real Firestore day/month reallocation and monotonic unknown/served settlement');

  await ctx.realtime.ref(`users/${ownerId}/displayPreparation/responses/${deviceId}`).set({sessionId:admission.sessionId,
    revision:admission.epoch,manifestHash:admission.manifestHash,status:'ready',checkedAtMs:now,imageCount:1,audioReady:true});
  const commit={schemaVersion:1,action:'commit',requestId:'commit_class_01',admissionId:admission.admissionId,
    sessionId:admission.sessionId,epoch:admission.epoch,manifestHash:admission.manifestHash,
    start:{stepIndex:0,durationMs:10000,briefing:false,scheduled:false,scheduledAtMs:null,updatedByDeviceId:'controller'}};
  failOnce=true;
  const after={...ctx,realtime:{ref:path=>{
    const ref=ctx.realtime.ref(path);if(path!==`users/${ownerId}`)return ref;
    return {get:()=>ref.get(),transaction:async fn=>{const result=await ref.transaction(fn);
      if(failOnce){failOnce=false;throw new Error('injected after RTDB publish');}return result;}};
  }}};
  await assert.rejects(handleClassAdmission({...after,actor,input:commit}),/injected after/);
  assert.equal((await ctx.db.doc(`imageUsageAccounts/${ownerId}/admissions/${admission.admissionId}`).get()).data().status,'committing');
  const binding=await requireUsageContext(ctx,{ownerId,actorUid:tvUid,purpose:'playback',sessionId:admission.sessionId,admissionId:admission.admissionId});
  assert.equal(binding.protected,true);
  const restored=await handleClassAdmission({...ctx,actor,input:{schemaVersion:1,action:'get',admissionId:admission.admissionId}});
  assert.equal(restored.status,'active');assert.equal(restored.session.id,admission.sessionId);assert.equal(restored.session.workoutSnapshot.id,workout.id);
  const committed=await handleClassAdmission({...ctx,actor,input:commit});assert.equal(committed.session.id,admission.sessionId);
  report('actual RTDB publication uncertainty remains protected and converges through get/commit replay');

  const p=usagePeriods(now);
  await ctx.db.doc(`imageUsageAccounts/${ownerId}/periods/downloadDay_${p.dayKey}`).update({usedBytes:1000000001});
  await ctx.db.doc(`imageUsageAccounts/${ownerId}/periods/downloadMonth_${p.monthKey}`).update({usedBytes:20000000001});
  now+=3600000; // preparation/lease TTL and entitlement expiry must not terminate active
  await ctx.db.doc(`subscriptionEntitlements/${ownerId}`).update({validUntilMs:now-1});
  await ctx.realtime.ref(`users/${ownerId}/activeSession`).update({status:'paused'});
  const protectedAttempt=await reserveTransfer(ctx,{...body,actorUid:tvUid,deviceId,purpose:'playback'});
  assert.equal(protectedAttempt.protected,true);
  await settleTransfer(ctx,{ownerId,attemptId:protectedAttempt.attemptId,outcome:'served',bodyBytes:10});
  assert.equal((await readUsage(ctx,{ownerId})).downloadDay.protectedOverageBytes,10);
  await ctx.realtime.ref(`users/${ownerId}/activeSession`).update({status:'playing',revision:2});
  assert.equal((await requireUsageContext(ctx,{ownerId,actorUid:tvUid,purpose:'playback',sessionId:admission.sessionId,admissionId:admission.admissionId})).protected,true);
  await expectReason(requireUsageContext(ctx,{ownerId,actorUid:'unrelated-tv',purpose:'playback',sessionId:admission.sessionId,admissionId:admission.admissionId}),'media_lease_invalid');
  await ctx.realtime.ref(`displayAccess/replacement-tv`).set({ownerId,deviceId,pairingCode:'123456',pairedAtMs:now});
  await ctx.realtime.ref(`users/${ownerId}/devices/${deviceId}`).update({displayUid:'replacement-tv'});
  await expectReason(requireUsageContext(ctx,{ownerId,actorUid:'replacement-tv',purpose:'playback',sessionId:admission.sessionId,admissionId:admission.admissionId}),'media_lease_invalid');
  await ctx.realtime.ref(`users/${ownerId}/devices/${deviceId}`).update({displayUid:tvUid});
  report('active paused/resumed/reconnected class remains downloadable after quota and entitlement/lease TTL');

  await ctx.realtime.ref(`users/${ownerId}/activeSession`).update({status:'completed',revision:3});
  await reconcileUsageSession(ctx,{ownerId});
  assert.equal((await ctx.db.doc(`imageUsageAccounts/${ownerId}`).get()).data().activeAdmissionId,null);
  await ctx.db.doc(`subscriptionEntitlements/${ownerId}`).update({validUntilMs:now+86400000});
  await expectReason(handleClassAdmission({...ctx,actor,input:{...prepare,requestId:'prepare_class_02'}}),'both_transfer_limits');
  report('completed evidence releases active slot, but quota denies the next independent class');

  await ctx.db.doc(`imageUsageAccounts/${ownerId}/periods/downloadDay_${p.dayKey}`).update({usedBytes:0});
  await ctx.db.doc(`imageUsageAccounts/${ownerId}/periods/downloadMonth_${p.monthKey}`).update({usedBytes:0});
  const concurrent=await Promise.allSettled(['prepare_race_01','prepare_race_02'].map(requestId=>
    handleClassAdmission({...ctx,actor,input:{...prepare,requestId}})));
  assert.equal(concurrent.filter(r=>r.status==='fulfilled').length,1);
  assert.equal(concurrent.find(r=>r.status==='rejected').reason.details.reason,'session_changed');
  const raced=concurrent.find(r=>r.status==='fulfilled').value;
  assert.equal((await readUsage(ctx,{ownerId})).downloadDay.reservedBytes,20);
  const allocated=await reserveTransfer(ctx,{...body,admissionId:raced.admissionId,sessionId:raced.sessionId});
  await handleClassAdmission({...ctx,actor,input:{schemaVersion:1,action:'cancel',requestId:'cancel_raced_01',admissionId:raced.admissionId}});
  assert.equal((await readUsage(ctx,{ownerId})).downloadDay.reservedBytes,10);
  await settleTransfer(ctx,{ownerId,attemptId:allocated.attemptId,outcome:'unknown',bodyBytes:0});
  assert.equal((await readUsage(ctx,{ownerId})).downloadDay.unknownBytes,10);
  report('concurrent class admission has one slot and cancellation preserves an already assigned body reservation');

  now=Date.parse('2026-12-01T14:59:50Z');
  const midnight=await handleClassAdmission({...ctx,actor,input:{...prepare,requestId:'prepare_midnight_01'}});
  await ctx.realtime.ref(`users/${ownerId}/displayPreparation/responses/${deviceId}`).set({sessionId:midnight.sessionId,
    revision:midnight.epoch,manifestHash:midnight.manifestHash,status:'ready',checkedAtMs:now,imageCount:1,audioReady:true});
  now+=20000;
  await ctx.db.doc(`imageUsageAccounts/${ownerId}/periods/downloadDay_2026-12-02`).set({kind:'downloadDay',key:'2026-12-02',
    resetsAtMs:usagePeriods(now).dayReset,usedBytes:1000000000,reservedBytes:0,unknownBytes:0,protectedOverageBytes:0,allocations:{}});
  await expectReason(handleClassAdmission({...ctx,actor,input:{...commit,requestId:'commit_midnight_01',admissionId:midnight.admissionId,
    sessionId:midnight.sessionId,epoch:midnight.epoch,manifestHash:midnight.manifestHash}}),'daily_transfer_limit');
  assert.equal((await ctx.realtime.ref(`users/${ownerId}/activeSession`).get()).val().status,'completed');
  report('commit rebudgets unused preparation across midnight before admitting a new active class');

  await seed('local-owner','free');
  await setUsageEnrollment(ctx,{ownerId:'local-owner',mode:'enrolled',policyPlan:'free',consentRevision:'yes',requestId:'enroll_local_01'});
  const localActor={uid:'local-owner',token:{firebase:{sign_in_provider:'password'}}};
  const local=await handleClassAdmission({...ctx,actor:localActor,input:{...prepare,requestId:'prepare_local_01',targetDeviceIds:[],
    workout:{...workout,ownerId:'local-owner',author:{...workout.author,id:'local-owner'},modules:[{...workout.modules[0],imageUrl:''}]}}});
  assert.deepEqual(local.targetDeviceIds,[]);assert.equal(local.reservedDownloadBytes,0);
  const localStarted=await handleClassAdmission({...ctx,actor:localActor,input:{...commit,requestId:'commit_local_01',admissionId:local.admissionId,
    sessionId:local.sessionId,epoch:local.epoch,manifestHash:local.manifestHash}});
  assert.equal(localStarted.status,'active');
  report('existing controller-only playback remains usable without inventing a paired TV');

  await ctx.realtime.ref(`users/${ownerId}/operations/brand`).set({logoUrl:asset.source,promotionImageUrls:[asset.source]});
  const standby=await requireUsageContext(ctx,{ownerId,actorUid:tvUid,purpose:'preview'});
  assert.deepEqual(standby.allowedAssetSources,[asset.source]);assert.equal(standby.protected,false);
  assert.equal(standby.deviceBinding.displayUid,tvUid);
  await ctx.db.doc(`imageUsageAccounts/${ownerId}/periods/downloadDay_2026-12-02`).update({usedBytes:0});
  const standbyBody={...body,actorUid:tvUid,deviceId,admissionId:null,sessionId:null,purpose:'preview'};
  const standbyAttempt=await reserveTransfer(ctx,standbyBody);assert.equal(standbyAttempt.protected,false);
  await settleTransfer(ctx,{ownerId,attemptId:standbyAttempt.attemptId,outcome:'served',bodyBytes:10});
  await ctx.realtime.ref(`users/${ownerId}/operations/brand`).set({logoUrl:null});
  await expectReason(reserveTransfer(ctx,standbyBody),'media_lease_invalid');
  await expectReason(requireUsageContext(ctx,{ownerId,actorUid:tvUid,purpose:'upload'}),'media_lease_invalid');
  report('paired standby preview is restricted to current server brand sources and charged ordinary quota');

  const embedded='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6N1sAAAAASUVORK5CYII=';
  await ctx.realtime.ref('users/local-owner/activeSession').update({status:'completed'});
  await reconcileUsageSession(ctx,{ownerId:'local-owner'});
  const localImage=await handleClassAdmission({...ctx,actor:localActor,input:{...prepare,requestId:'prepare_embedded_01',targetDeviceIds:[],
    workout:{...workout,ownerId:'local-owner',author:{...workout.author,id:'local-owner'},modules:[{...workout.modules[0],imageUrl:embedded}]}}});
  assert.equal(localImage.reservedDownloadBytes,0);
  const localStored=(await ctx.db.doc(`imageUsageAccounts/local-owner/admissions/${localImage.admissionId}`).get()).data();
  assert.equal(localStored.manifest.imageBytes,Buffer.from(embedded.split(',')[1],'base64').length);
  assert.equal(localStored.manifest.localAssets.length,1);assert.equal(localStored.assets.length,0);
  assert.equal((await ctx.realtime.ref('users/local-owner/displayPreparation/request').get()).val().imageCount,1);
  report('verified embedded images retain immutable content size/hash and preparation while reserving zero remote bytes');

  // A genuinely legacy active class is neither force-ended nor silently enrolled.
  await seed('legacy-active','free');
  await ctx.db.doc('imageUsageAccounts/legacy-active').update({mode:'legacy'});
  await ctx.realtime.ref('users/legacy-active').set({activeSession:{id:'old',status:'paused'}});
  await expectReason(setUsageEnrollment(ctx,{ownerId:'legacy-active',mode:'enrolled',policyPlan:'free',consentRevision:'yes',requestId:'enroll_legacy_01'}),'session_changed');
  assert.equal((await ctx.realtime.ref('users/legacy-active/activeSession').get()).val().id,'old');
  assert.equal((await ctx.db.doc('imageUsageAccounts/legacy-active').get()).data().mode,'legacy');
  report('unmigrated active legacy class is preserved and explicit enrollment refused');

  await seed('enroll-race','free');await ctx.db.doc('imageUsageAccounts/enroll-race').update({mode:'legacy'});
  await ctx.realtime.ref('users/enroll-race').set({legacyHint:true});
  const raceCtx={...ctx,realtime:{ref:path=>{
    const r=ctx.realtime.ref(path);if(path!=='users/enroll-race')return r;
    return {get:()=>r.get(),transaction:async fn=>{
      await r.update({activeSession:{id:'legacy-race',status:'paused'}});return r.transaction(fn);}};
  }}};
  const enrollInput={ownerId:'enroll-race',mode:'enrolled',policyPlan:'free',consentRevision:'yes',requestId:'enroll_race_01'};
  await expectReason(setUsageEnrollment(raceCtx,enrollInput),'usage_reconciliation_pending');
  assert.equal((await ctx.db.doc('imageUsageAccounts/enroll-race').get()).data().mode,'legacy');
  assert.equal((await ctx.realtime.ref('users/enroll-race/activeSession').get()).val().id,'legacy-race');
  assert.equal((await ctx.realtime.ref('users/enroll-race/usageGate').get()).exists(),false);
  report('actual legacy start wins enrollment race without any FS quota mode or Storage-denial transition');

  await seed('enroll-crash','free');await ctx.db.doc('imageUsageAccounts/enroll-crash').update({mode:'legacy'});
  const crashCtx={...ctx,db:{doc:ctx.db.doc.bind(ctx.db),getAll:ctx.db.getAll.bind(ctx.db),runTransaction:async()=>{throw new Error('injected FS after RTDB claim');}}};
  const crashInput={...enrollInput,ownerId:'enroll-crash',requestId:'enroll_crash_01'};
  await assert.rejects(setUsageEnrollment(crashCtx,crashInput),/injected FS after/);
  const held=(await ctx.realtime.ref('users/enroll-crash/usageGate').get()).val();
  assert.equal(held.mode,'enrolling');assert.equal(held.enrollmentRequestId,crashInput.requestId);
  assert.equal((await ctx.db.doc('imageUsageAccounts/enroll-crash').get()).data().mode,'legacy');
  await expectReason(setUsageEnrollment(ctx,{...crashInput,consentRevision:'different'}),'idempotency_conflict');
  await expectReason(setUsageEnrollment(ctx,{...crashInput,requestId:'enroll_other_01'}),'usage_reconciliation_pending');
  await reconcileUsageEnrollment(ctx,{ownerId:'enroll-crash'});
  assert.equal((await ctx.realtime.ref('users/enroll-crash/usageGate').get()).val().mode,'enrolled');
  assert.equal((await ctx.db.doc('imageUsageAccounts/enroll-crash').get()).data().enrollmentPending,false);
  await ctx.realtime.ref('users/enroll-crash/activeSession').set({id:'later-active',status:'playing'});
  await setUsageEnrollment(ctx,crashInput); // acknowledged replay cannot touch a later class
  assert.equal((await ctx.realtime.ref('users/enroll-crash/activeSession').get()).val().id,'later-active');
  report('crash after RTDB claim retains fail-closed durable fence and only the same payload recovers');

  await seed('enroll-finalize','free');await ctx.db.doc('imageUsageAccounts/enroll-finalize').update({mode:'legacy'});
  let enrollWrites=0;
  const finalizeCtx={...ctx,realtime:{ref:path=>{
    const r=ctx.realtime.ref(path);if(path!=='users/enroll-finalize')return r;
    return {get:()=>r.get(),transaction:async fn=>{const result=await r.transaction(fn);enrollWrites++;
      if(enrollWrites===2)throw new Error('injected finalize response lost');return result;}};
  }}};
  await assert.rejects(setUsageEnrollment(finalizeCtx,{...enrollInput,ownerId:'enroll-finalize',requestId:'enroll_finalize_01'}),/finalize response lost/);
  assert.equal((await ctx.db.doc('imageUsageAccounts/enroll-finalize').get()).data().enrollmentPending,true);
  assert.equal((await ctx.realtime.ref('users/enroll-finalize/usageGate').get()).val().mode,'enrolled');
  await reconcileUsageEnrollment(ctx,{ownerId:'enroll-finalize'});
  assert.equal((await ctx.db.doc('imageUsageAccounts/enroll-finalize').get()).data().enrollmentPending,false);
  assert.equal((await ctx.db.collection('imageUsageAccounts/enroll-finalize/audit').get()).size,1);
  report('lost RTDB finalize response resumes pending FS acknowledgment without duplicate enrollment audit');
}
