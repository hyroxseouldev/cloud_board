// Actual LOCAL Firebase emulator HTTP/client-SDK integration. No ledger/Auth/GCS
// doubles; Admin-only fixture enrollment, pairing, TV ready receipt and quota
// exhaustion are declared below. This is not Flutter/native TV or cloud proof.
import assert from 'node:assert/strict';
import {createHash,randomUUID} from 'node:crypto';
import {writeFile} from 'node:fs/promises';
import {initializeApp as initializeAdmin,deleteApp as deleteAdmin} from 'firebase-admin/app';
import {getAuth as adminAuth} from 'firebase-admin/auth';
import {getFirestore as adminFirestore} from 'firebase-admin/firestore';
import {getDatabase as adminDatabase} from 'firebase-admin/database';
import {getStorage} from 'firebase-admin/storage';
import {initializeApp,deleteApp} from 'firebase/app';
import {getAuth,connectAuthEmulator,createUserWithEmailAndPassword,signInAnonymously} from 'firebase/auth';
import {getFirestore,connectFirestoreEmulator,doc,getDoc,terminate} from 'firebase/firestore';
import {getDatabase,connectDatabaseEmulator,ref,get as getRealtime,runTransaction,goOffline} from 'firebase/database';
import {setUsageEnrollment} from '../src/class-admission.js';
import {readUsage} from '../src/image-usage-ledger.js';
import {reserveGeneratedImage,storeGeneratedImage} from '../src/image-upload.js';
import {imageUsagePolicyRevision} from '../src/image-usage-policy.js';

const projectId='demo-cloudboard-usage-integration';
assert.equal(process.env.GCLOUD_PROJECT,projectId);
const hosts={FIRESTORE_EMULATOR_HOST:'127.0.0.1:8188',FIREBASE_DATABASE_EMULATOR_HOST:'127.0.0.1:9188',
  FIREBASE_STORAGE_EMULATOR_HOST:'127.0.0.1:9288',FIREBASE_AUTH_EMULATOR_HOST:'127.0.0.1:9098'};
for(const [key,value]of Object.entries(hosts))assert.equal(process.env[key],value,`Unsafe emulator target: ${key}`);
const origin='http://127.0.0.1:5008',base=`${origin}/${projectId}/asia-northeast3`,mediaUrl=`${base}/cloudboardMedia`;
const databaseURL=`https://${projectId}-default-rtdb.asia-southeast1.firebasedatabase.app`;
const admin=initializeAdmin({projectId,databaseURL,storageBucket:`${projectId}.firebasestorage.app`},`B-runtime-${randomUUID()}`);
const db=adminFirestore(admin),realtime=adminDatabase(admin),auth=adminAuth(admin),bucket=getStorage(admin).bucket();
const ctx={db,realtime,auth,bucket,projectId,clock:Date.now,emulator:true,mediaBaseUrl:mediaUrl,allowedOrigins:[]};
const clients=[],cases=[],startedAt=Date.now(),runId=randomUUID().slice(0,8);
let ownerId,sessionId,admissionId,sourceGeneration;
const report=name=>{cases.push(name);console.log(`PASS ${name}`);};
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
function png(size=64){const bytes=Buffer.alloc(size,11);Buffer.from([137,80,78,71,13,10,26,10]).copy(bytes);bytes.write('IHDR',12);bytes.writeUInt32BE(100,16);bytes.writeUInt32BE(100,20);return bytes;}
function client(label){const app=initializeApp({apiKey:'local-emulator-only',authDomain:`${projectId}.firebaseapp.com`,projectId,databaseURL},`${label}-${runId}`);const auth=getAuth(app);connectAuthEmulator(auth,'http://127.0.0.1:9098',{disableWarnings:true});const firestore=getFirestore(app);connectFirestoreEmulator(firestore,'127.0.0.1',8188);const database=getDatabase(app);connectDatabaseEmulator(database,'127.0.0.1',9188);const c={app,auth,firestore,database};clients.push(c);return c;}
async function call(name,data,token,{reason=null,status=null}={}){
  const response=await fetch(`${base}/${name}`,{method:'POST',headers:{'Content-Type':'application/json',...(token?{Authorization:`Bearer ${token}`}:{})},body:JSON.stringify({data}),signal:AbortSignal.timeout(65000)});
  const text=await response.text();let json;
  try{json=JSON.parse(text);}catch{throw new Error(`${name} HTTP ${response.status}: ${text.slice(0,300)}`);}
  if(reason){assert.equal(json.error?.details?.reason,reason,`${name}: ${JSON.stringify(json)}`);return json;}
  if(status){assert.equal(response.status,status,`${name}: ${JSON.stringify(json)}`);return json;}
  assert.equal(response.status,200,`${name}: ${JSON.stringify(json)}`);assert.ok(!json.error,`${name}: ${JSON.stringify(json.error)}`);return json.result??json.data;
}
const usage=token=>call('cloudboardImageUsage',{schemaVersion:1,action:'get'},token);
async function settledUsage(token,predicate){
  let current;
  for(let n=0;n<20;n++){current=await usage(token);if(predicate(current))return current;await new Promise(resolve=>setTimeout(resolve,100));}
  assert.fail(`Usage settlement did not converge: ${JSON.stringify(current)}`);
}
const mutation=(action,extra={})=>({schemaVersion:1,action,requestId:`B_${action}_${randomUUID()}`,...extra});
const lease=(token,asset,purpose='preview',binding={})=>call('cloudboardMediaLease',mutation('issue',{assetIds:[asset.assetId],purpose,admissionId:null,sessionId:null,...binding}),token);
async function body(token,asset,permit,{method='GET',status=200}={}){
  const url=new URL(asset.source);assert.equal(url.origin,origin);assert.equal(url.pathname,`/${projectId}/asia-northeast3/cloudboardMedia`);
  const response=await fetch(url,{method,headers:{Authorization:`Bearer ${token}`,'X-CloudBoard-Media-Lease':permit.leaseId},signal:AbortSignal.timeout(65000)});
  assert.equal(response.status,status,`Media response: ${response.status}`);return response;
}
try{
  const owner=client('owner'),tv=client('tv'),other=client('other');
  const ownerUser=(await createUserWithEmailAndPassword(owner.auth,`b-${runId}@example.test`,'Local-fixture-Password42!')).user;
  const tvUser=(await signInAnonymously(tv.auth)).user,otherUser=(await signInAnonymously(other.auth)).user;
  ownerId=ownerUser.uid;const tvId=tvUser.uid,token=await ownerUser.getIdToken(),tvToken=await tvUser.getIdToken(),otherToken=await otherUser.getIdToken();
  const now=Date.now(),deviceId='tv-one',pairingCode=`pair-${runId}`;
  await db.doc('appConfig/imageUsage').set({schemaVersion:1,policyRevision:imageUsagePolicyRevision,enabled:true,allowedProjectIds:[projectId]},{merge:true});
  const [emptyFiles]=await bucket.getFiles({prefix:`users/${ownerId}/managed-images/`,maxResults:1});assert.equal(emptyFiles.length,0);
  await db.doc(`imageUsageAccounts/${ownerId}`).set({mode:'legacy',policyPlan:null,revision:0,inventoryComplete:true,
    eligibility:{tokenFree:true,rulesReady:true},storageUsedBytes:0,storageReservedBytes:0,storageUnknownBytes:0});
  await db.doc(`subscriptionEntitlements/${ownerId}`).set({plan:'free',status:'active',policyVersion:'plan-entitlements-v2',canStartClass:true,validUntilMs:now+86400000});
  await realtime.ref(`users/${ownerId}`).set({devices:{[deviceId]:{id:deviceId,paired:true,displayUid:tvId,pairingCode,pairedAtMs:now,imageUsageProtocol:1,preparationProtocol:2,playbackProtocol:5}}});
  await realtime.ref(`displayAccess/${tvId}`).set({ownerId,deviceId,pairingCode,pairedAtMs:now});
  await setUsageEnrollment(ctx,{ownerId,mode:'enrolled',policyPlan:'free',consentRevision:imageUsagePolicyRevision,requestId:`B_enroll_${runId}`});
  assert.equal((await usage(token)).mode,'enrolled');report('real Auth owner/anonymous TV tokens and callable enrolled usage');

  const bytes=png(10485759),digest=sha(bytes);
  const upload=await call('cloudboardImageUpload',mutation('reserve',{purpose:'workout',workoutId:null,sha256:digest,sizeBytes:bytes.length,contentType:'image/png'}),token);
  assert.equal(upload.status,'reserved');assert.equal(upload.uploadUrl,`${base}/cloudboardImageUploadBody`);
  const uploadResponse=await fetch(upload.uploadUrl,{method:'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'image/png','X-CloudBoard-Upload-Id':upload.uploadId},body:bytes,signal:AbortSignal.timeout(65000)});
  const uploadJson=await uploadResponse.json();assert.equal(uploadResponse.status,201,JSON.stringify(uploadJson));
  const stored=await call('cloudboardImageUpload',{schemaVersion:1,action:'get',uploadId:upload.uploadId},token);
  assert.equal(stored.status,'stored');const asset=stored.asset;sourceGeneration=asset.generation;
  const record=(await db.doc(`imageUsageAccounts/${ownerId}/uploads/${upload.uploadId}`).get()).data();
  assert.equal(record.path,`users/${ownerId}/managed-images/workout/${upload.uploadId}/${digest}`);
  const [metadata]=await bucket.file(record.path,{generation:asset.generation}).getMetadata();assert.ok(!metadata.metadata?.firebaseStorageDownloadTokens);
  assert.equal((await usage(token)).storage.usedBytes,bytes.length);report('real callable reserve/raw POST/create-only generation/get readback for 10485759 bytes');

  const workout={id:`workout-${runId}`,ownerId,author:{id:ownerId,displayName:'Local Coach',photoUrl:null},name:'B emulator class',folder:'',createdAt:now,updatedAt:now,brandL:'',brandR:'',soundVolume:0,countdownSeconds:3,
    modules:[{id:'module-one',name:'Work',text:'',beep:true,coverImage:false,workSeconds:10,restSeconds:0,sets:1,imageUrl:asset.source}]};
  const saved=await call('saveWorkout',{ownerId,workout},token);assert.equal(saved.workout.modules[0].imageUrl,asset.source);
  const readback=await getDoc(doc(owner.firestore,`users/${ownerId}/workouts/${workout.id}`));assert.equal(readback.data().modules[0].imageUrl,asset.source);
  report('actual saveWorkout callable and authenticated Firestore client readback preserve stable managed source');

  const generated=await reserveGeneratedImage({db,bucket,uid:ownerId,usageContext:ctx},`B_generated_${runId}`,'template_job',4096);
  assert.equal(generated.record.sha256,null);assert.equal(generated.record.generatedOutput.hashStatus,'pending');
  const generatedBytes=png(128),generatedAsset=await storeGeneratedImage(generated,generatedBytes);
  assert.equal(generatedAsset.sha256,sha(generatedBytes));assert.equal(generatedAsset.sizeBytes,generatedBytes.length);
  const generatedRecord=(await db.doc(`imageUsageAccounts/${ownerId}/uploads/${generated.record.uploadId}`).get()).data();
  assert.equal(generatedRecord.path,`users/${ownerId}/managed-images/generated/${generated.record.uploadId}/${sha(generatedBytes)}`);
  assert.equal(generatedRecord.boundOutput.sha256,sha(generatedBytes));
  assert.equal((await usage(token)).storage.reservedBytes,0);assert.equal((await usage(token)).uploadDay.usedBytes,bytes.length+generatedBytes.length);
  report('real A generated pending hash/bind/private GCS/actual-size settlement releases unused bound');

  await realtime.ref(`users/${ownerId}/operations/brand`).set({logoUrl:asset.source,backgroundImageUrl:'',promotionImageUrls:[]});
  const standby=await lease(tvToken,asset);await(await body(tvToken,asset,standby)).arrayBuffer();
  await call('cloudboardMediaLease',mutation('issue',{assetIds:[generatedAsset.assetId],purpose:'preview',admissionId:null,sessionId:null}),tvToken,{reason:'media_lease_invalid'});
  await realtime.ref(`users/${ownerId}/operations/brand/logoUrl`).set(generatedAsset.source);
  await body(tvToken,asset,standby,{status:403});
  await realtime.ref(`users/${ownerId}/operations/brand/logoUrl`).set(asset.source);
  report('real paired-TV standby accepts only current brand source and rechecks old lease after brand change');

  const prepared=await call('cloudboardClassAdmission',mutation('prepare',{workout,targetDeviceIds:[deviceId],controllerDeviceId:'controller',clientFingerprint:`fixture-${runId}`}),token);
  assert.equal(prepared.status,'preparing');sessionId=prepared.sessionId;admissionId=prepared.admissionId;
  const binding={sessionId,admissionId};
  const ownerLease=await lease(token,asset,'preparation',binding),tvLease=await lease(tvToken,asset,'preparation',binding);
  const beforeHead=await usage(token);assert.equal((await body(token,asset,ownerLease,{method:'HEAD'})).status,200);assert.equal((await usage(token)).downloadDay.usedBytes,beforeHead.downloadDay.usedBytes);
  assert.deepEqual(Buffer.from(await(await body(token,asset,ownerLease)).arrayBuffer()),bytes);
  assert.deepEqual(Buffer.from(await(await body(tvToken,asset,tvLease)).arrayBuffer()),bytes);
  await body(otherToken,asset,ownerLease,{status:403});
  assert.equal((await settledUsage(token,u=>u.downloadDay.usedBytes===bytes.length*3)).downloadDay.usedBytes,bytes.length*3); // standby + controller + TV
  report('real prepare -> owner/TV leases -> authenticated generation-pinned near10MiB bodies; HEAD zero charge and wrong actor denied');

  // The TV receipt is an explicit Admin fixture, not a claim of real TV readiness.
  await realtime.ref(`users/${ownerId}/displayPreparation/responses/${deviceId}`).set({sessionId,revision:prepared.epoch,manifestHash:prepared.manifestHash,status:'ready',checkedAtMs:Date.now(),imageCount:1,audioReady:true});
  const commitInput=mutation('commit',{admissionId,sessionId,epoch:prepared.epoch,manifestHash:prepared.manifestHash,start:{stepIndex:0,durationMs:10000,briefing:false,scheduled:false,scheduledAtMs:null,updatedByDeviceId:'controller'}});
  const committed=await call('cloudboardClassAdmission',commitInput,token);assert.equal(committed.status,'active');assert.equal(committed.session.id,sessionId);
  const same=await call('cloudboardClassAdmission',{schemaVersion:1,action:'get',admissionId},token);assert.equal(same.session.id,sessionId);
  report('actual ready-fixture commit/get publishes and returns the same immutable active session');

  const current=await usage(token);
  await db.doc(`imageUsageAccounts/${ownerId}/periods/downloadDay_${current.downloadDay.key}`).update({usedBytes:50000001});
  await db.doc(`imageUsageAccounts/${ownerId}/periods/downloadMonth_${current.downloadMonth.key}`).update({usedBytes:500000001});
  await db.doc(`subscriptionEntitlements/${ownerId}`).update({validUntilMs:Date.now()-1});
  await getRealtime(ref(owner.database,`users/${ownerId}/activeSession`));
  const pause=await runTransaction(ref(owner.database,`users/${ownerId}/activeSession`),value=>value?{...value,status:'paused',revision:(value.revision??0)+1}:null);assert.equal(pause.committed,true);
  const playbackLease=await lease(tvToken,asset,'playback',binding);
  assert.deepEqual(Buffer.from(await(await body(tvToken,asset,playbackLease)).arrayBuffer()),bytes);
  const resume=await runTransaction(ref(owner.database,`users/${ownerId}/activeSession`),value=>value?{...value,status:'playing',revision:(value.revision??0)+1}:null);assert.equal(resume.committed,true);
  assert.equal((await call('cloudboardClassAdmission',{schemaVersion:1,action:'get',admissionId},token)).session.id,sessionId);
  assert.equal((await settledUsage(token,u=>u.downloadDay.protectedOverageBytes===bytes.length)).downloadDay.protectedOverageBytes,bytes.length);
  report('actual owner client pause/resume plus protected same-session TV body survive quota and entitlement expiry');

  // Pairing changes are server fixtures. They must not inherit old session rights.
  await realtime.ref(`users/${ownerId}/devices/${deviceId}`).update({pairingCode:`new-${pairingCode}`,pairedAtMs:now+1});
  await realtime.ref(`displayAccess/${tvId}`).update({pairingCode:`new-${pairingCode}`,pairedAtMs:now+1});
  await body(tvToken,asset,playbackLease,{status:403});
  await body(tvToken,asset,standby,{status:403});
  await realtime.ref(`users/${ownerId}/devices/${deviceId}`).update({pairingCode,pairedAtMs:now});await realtime.ref(`displayAccess/${tvId}`).update({pairingCode,pairedAtMs:now});
  report('same actor/device re-pair cannot reuse frozen playback or standby lease');

  const complete=await runTransaction(ref(owner.database,`users/${ownerId}/activeSession`),value=>value?{...value,status:'completed',revision:(value.revision??0)+1}:null);assert.equal(complete.committed,true);
  assert.equal((await call('cloudboardClassAdmission',{schemaVersion:1,action:'get',admissionId},token)).status,'completed');
  await db.doc(`subscriptionEntitlements/${ownerId}`).update({validUntilMs:Date.now()+86400000});
  await call('cloudboardClassAdmission',mutation('prepare',{workout,targetDeviceIds:[deviceId],controllerDeviceId:'controller',clientFingerprint:`new-${runId}`}),token,{reason:'both_transfer_limits'});
  report('actual client completion reconciles slot and quota denies next independent class');

  // Real Auth disabled and revoke verification happens before any ledger/GCS body.
  await auth.updateUser(tvId,{disabled:true});await body(tvToken,asset,playbackLease,{status:401});
  const ownerPreview=await lease(token,asset).catch(()=>null); // quota is spent, so issue may still succeed; body denies later.
  await new Promise(resolve=>setTimeout(resolve,1100));await auth.revokeRefreshTokens(ownerId);
  await call('cloudboardImageUsage',{schemaVersion:1,action:'get'},token,{status:401});
  if(ownerPreview)await body(token,asset,ownerPreview,{status:401});
  report('real Auth disabled TV and revoked owner ID tokens are rejected');

  const result={schemaVersion:1,status:'passed',projectId,runId,ownerId,sessionId,admissionId,sourceGeneration,
    passed:cases.length,cases,startedAtMs:startedAt,completedAtMs:Date.now(),services:['Auth','Functions callable and raw HTTP','Firestore','RTDB','Storage'],
    mocks:false,adminFixtures:['empty new owner namespace inventory/enrollment and policy config','entitlement','TV pairing/capabilities','TV ready receipt','day/month quota exhaustion and entitlement expiry','pairing-change verification'],
    actualClientSdk:['Auth email owner/anonymous TV','Firestore workout readback under rules','RTDB same-session pause/resume/completion under rules'],
    unverified:['Flutter/native app','real physical TV readiness','deployed v2 cloud buffering','external provider/store/production'],productionQueries:false,deployment:false};
  await writeFile('/tmp/cloudboard-2-1-5-usage/B-runtime-e2e.json',JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result,null,2));
}catch(error){
  await writeFile('/tmp/cloudboard-2-1-5-usage/B-runtime-e2e.json',JSON.stringify({schemaVersion:1,status:'failed',projectId,runId,ownerId,sessionId,admissionId,passed:cases.length,cases,error:{name:error.name,message:error.message,stack:error.stack},productionQueries:false},null,2)+'\n');
  throw error;
}finally{
  for(const c of clients){goOffline(c.database);await terminate(c.firestore);await deleteApp(c.app);}
  await db.terminate();
  await deleteAdmin(admin);
}

// All assertions, result writes and explicit SDK cleanup have completed here.
// Firebase Web SDK background timers can retain Node despite closed sockets.
// A thrown failure bypasses this line and retains its nonzero exit status.
console.log('PASS explicit SDK cleanup completed');
process.exit(0);
