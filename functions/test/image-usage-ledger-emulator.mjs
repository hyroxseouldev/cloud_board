// Local Admin SDK integration, not a callable/app/production success claim.
import assert from 'node:assert/strict';
import {initializeApp,deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {getDatabase} from 'firebase-admin/database';
import {getStorage} from 'firebase-admin/storage';
import {readUsage,reserveUpload,beginUpload,bindGeneratedUpload,settleUpload} from '../src/image-usage-ledger.js';
import {imageUsagePolicyRevision,usagePeriods} from '../src/image-usage-policy.js';
import {handleUsageGrant} from '../src/usage-grants.js';
import {classAdmissionScenarios} from './class-admission-emulator.mjs';
for (const key of ['FIRESTORE_EMULATOR_HOST','FIREBASE_DATABASE_EMULATOR_HOST','FIREBASE_STORAGE_EMULATOR_HOST']) {
  assert.match(process.env[key]??'',/^(127\.0\.0\.1|localhost):\d+$/);
}
const projectId='demo-cloudboard-usage-a';
assert.equal(process.env.GCLOUD_PROJECT,projectId);
const app=initializeApp({projectId,databaseURL:`https://${projectId}-default-rtdb.firebaseio.com`,storageBucket:`${projectId}.appspot.com`});
const db=getFirestore(app),realtime=getDatabase(app),bucket=getStorage(app).bucket();
let now=Date.parse('2026-11-14T03:00:00Z');const ctx={db,realtime,bucket,projectId,clock:()=>now};
const cases=[];const report=name=>{cases.push(name);console.log(`PASS ${name}`);};
const expectReason=async(promise,reason)=>assert.rejects(promise,e=>e.details?.reason===reason);
const seed=async(uid,plan)=>{
  await db.doc(`imageUsageAccounts/${uid}`).set({mode:'enrolled',policyPlan:plan,policyRevision:imageUsagePolicyRevision,
    revision:0,inventoryComplete:true,eligibility:{tokenFree:true,rulesReady:true},storageUsedBytes:0,storageReservedBytes:0,storageUnknownBytes:0});
  await db.doc(`subscriptionEntitlements/${uid}`).set({plan,canStartClass:true,status:'active',validUntilMs:Date.parse('2027-01-01T00:00:00Z')});
};
try {
  await db.doc('appConfig/imageUsage').set({schemaVersion:1,policyRevision:imageUsagePolicyRevision,enabled:true,
    allowedProjectIds:[projectId],grantLimits:{maxAdditionalDayBytes:1000000000,maxAdditionalMonthBytes:20000000000,maxValidityMs:86400000}});
  await seed('upload-owner','free');
  const upload=n=>({ownerId:'upload-owner',requestId:`upload_req_${n}`,payloadHash:`hash_${n}`,purpose:'workout',workoutId:'workout',
    sha256:'a'.repeat(64),sizeBytes:8000000,contentType:'image/png',path:`users/upload-owner/managed-images/workout/${n}/image`});
  const results=await Promise.allSettled([1,2,3,4].map(n=>reserveUpload(ctx,upload(n))));
  assert.equal(results.filter(r=>r.status==='fulfilled').length,3);
  assert.equal(results.find(r=>r.status==='rejected').reason.details.reason,'daily_upload_limit');
  let usage=await readUsage(ctx,{ownerId:'upload-owner'});assert.equal(usage.uploadDay.reservedBytes,24000000);assert.equal(usage.storage.reservedBytes,24000000);
  report('concurrent final upload capacity serializes on actual Firestore transaction');
  const fulfilled=results.findIndex(r=>r.status==='fulfilled'), record=results[fulfilled].value;
  assert.equal(record.path,`users/upload-owner/managed-images/workout/${record.uploadId}/${record.sha256}`);
  const replay=await reserveUpload(ctx,upload(fulfilled+1));assert.equal(replay.uploadId,record.uploadId);
  await expectReason(reserveUpload(ctx,{...upload(fulfilled+1),payloadHash:'different'}),'idempotency_conflict');
  await beginUpload(ctx,{ownerId:'upload-owner',actorUid:'upload-owner',uploadId:record.uploadId});
  assert.equal((await settleUpload(ctx,{ownerId:'upload-owner',uploadId:record.uploadId,outcome:'not_written'})).status,'writing');
  await assert.rejects(beginUpload(ctx,{ownerId:'upload-owner',actorUid:'upload-owner',uploadId:record.uploadId}));
  await settleUpload(ctx,{ownerId:'upload-owner',uploadId:record.uploadId,outcome:'unknown'});
  usage=await readUsage(ctx,{ownerId:'upload-owner'});assert.equal(usage.storage.unknownBytes,8000000);assert.equal(usage.storage.usedBytes,0);
  const asset={assetId:'uploaded_asset',ownerId:'upload-owner',path:record.path,bucket:bucket.name,generation:'1',sizeBytes:record.sizeBytes,
    sha256:record.sha256,contentType:record.contentType,tokenFree:true,source:'https://example.invalid/test',provenance:'emulator-injected-server-proof'};
  await settleUpload(ctx,{ownerId:'upload-owner',uploadId:record.uploadId,outcome:'stored',asset});
  await settleUpload(ctx,{ownerId:'upload-owner',uploadId:record.uploadId,outcome:'stored',asset});
  usage=await readUsage(ctx,{ownerId:'upload-owner'});assert.equal(usage.storage.usedBytes,8000000);assert.equal(usage.uploadDay.usedBytes,8000000);assert.equal(usage.storage.unknownBytes,0);
  assert.equal((await db.doc('imageUsageAccounts/upload-owner/assets/uploaded_asset').get()).data().generation,'1');
  report('upload unknown reservation, idempotent conflict, unique writer and generation settlement readback');

  await seed('generated-owner','premium');
  const generated=await reserveUpload(ctx,{...upload(8),ownerId:'generated-owner',purpose:'generated',requestId:'generated_output_01',
    sha256:null,generatedOutput:{hashStatus:'pending',provenance:'emulator_generation'},sizeBytes:10485759});
  assert.equal(generated.sha256,null);assert.equal(generated.path,`users/generated-owner/managed-images/generated/${generated.uploadId}/pending`);
  await beginUpload(ctx,{ownerId:'generated-owner',actorUid:'generated-owner',uploadId:generated.uploadId});
  const bound=await bindGeneratedUpload(ctx,{ownerId:'generated-owner',actorUid:'generated-owner',uploadId:generated.uploadId,sha256:'b'.repeat(64),sizeBytes:123});
  assert.equal(bound.path,`users/generated-owner/managed-images/generated/${generated.uploadId}/${'b'.repeat(64)}`);
  await expectReason(bindGeneratedUpload(ctx,{ownerId:'generated-owner',actorUid:'generated-owner',uploadId:generated.uploadId,sha256:'c'.repeat(64),sizeBytes:123}),'idempotency_conflict');
  await settleUpload(ctx,{ownerId:'generated-owner',uploadId:generated.uploadId,outcome:'stored',asset:{...asset,
    assetId:'generated_asset',ownerId:'generated-owner',path:bound.path,sizeBytes:123,sha256:'b'.repeat(64)}});
  const generatedUsage=await readUsage(ctx,{ownerId:'generated-owner'});
  assert.equal(generatedUsage.storage.usedBytes,123);assert.equal(generatedUsage.storage.reservedBytes,0);
  assert.equal(generatedUsage.uploadDay.usedBytes,123);assert.equal(generatedUsage.uploadDay.reservedBytes,0);
  report('generated images reserve a finite upper bound then settle verified actual bytes/hash');

  const abandoned=await reserveUpload(ctx,{...upload(9),ownerId:'generated-owner',requestId:'abandoned_output_01',
    path:'users/generated-owner/managed-images/workout/abandoned/image'});
  await beginUpload(ctx,{ownerId:'generated-owner',actorUid:'generated-owner',uploadId:abandoned.uploadId});
  const unused=await reserveUpload(ctx,{...upload(10),ownerId:'generated-owner',requestId:'unused_upload_01',
    path:'users/generated-owner/managed-images/workout/unused/image'});
  now+=600001;
  const abandonedUsage=await readUsage(ctx,{ownerId:'generated-owner'});
  assert.equal(abandonedUsage.storage.unknownBytes,8000000);assert.equal(abandonedUsage.storage.reservedBytes,0);
  assert.equal((await db.doc(`imageUsageAccounts/generated-owner/uploads/${unused.uploadId}`).get()).data().status,'expired');
  report('abandoned writer remains unknown while never-claimed expired upload is safely released');

  await seed('grant-owner','free');const period=usagePeriods(now);
  const operator={uid:'operator',token:{quotaOperator:true,auth_time:Math.floor(now/1000)}};
  const grant={schemaVersion:1,action:'grant',requestId:'grant_request_01',accountId:'grant-owner',targetDayKey:period.dayKey,
    targetMonthKey:period.monthKey,additionalDayBytes:100,additionalMonthBytes:200,validFromMs:now-1000,validUntilMs:now+10000,reason:'Emergency class support'};
  await expectReason(handleUsageGrant({...ctx,actor:{uid:'owner',token:{}},input:grant}),'media_lease_invalid');
  const g=await handleUsageGrant({...ctx,actor:operator,input:grant});
  assert.equal((await handleUsageGrant({...ctx,actor:operator,input:grant})).grantId,g.grantId);
  await expectReason(handleUsageGrant({...ctx,actor:operator,input:{...grant,additionalDayBytes:101}}),'idempotency_conflict');
  usage=await readUsage(ctx,{ownerId:'grant-owner'});assert.equal(usage.downloadDay.grantedBytes,100);assert.equal(usage.downloadMonth.grantedBytes,200);
  assert.equal((await db.collection('imageUsageAccounts/grant-owner/audit').get()).size,1);
  await handleUsageGrant({...ctx,actor:operator,input:{schemaVersion:1,action:'revoke',requestId:'grant_revoke_01',accountId:'grant-owner',grantId:g.grantId,reason:'Emergency allocation ended'}});
  assert.equal((await readUsage(ctx,{ownerId:'grant-owner'})).downloadDay.grantedBytes,0);
  report('finite authorized grants and revocation are idempotent, transactional, audited and period-scoped');

  await classAdmissionScenarios({ctx,seed,expectReason,report});
  console.log(JSON.stringify({passed:cases.length,cases,projectId,services:'local Firestore+RTDB+Storage Admin SDK; actor and upload proof fixtures injected; no callable or real backend'},null,2));
} finally {await deleteApp(app);}
