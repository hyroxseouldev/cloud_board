// Firestore transaction/authorization contract only. Fake provider and Storage;
// never an actual UI, OpenAI, Storage-rules or deployed callable E2E claim.
import assert from 'node:assert/strict';
import {initializeApp,deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {handleAiSlideRaster,loadRasterBrand} from '../src/ai-slide-raster.js';
import {rasterHash,rasterFail,RASTER_RESERVE} from '../src/ai-slide-raster-provider.js';
import {aiTimerMonth,AI_TIMER_BUDGET} from '../src/ai-timer.js';

assert.equal(process.env.FIRESTORE_EMULATOR_HOST,'127.0.0.1:19480');
assert.ok(!process.env.GOOGLE_APPLICATION_CREDENTIALS,'No external credentials in fixture contract');
const projectId='demo-cloudboard-raster-contract';
const app=initializeApp({projectId}),db=getFirestore(app);
const prefix=`raster-${Date.now()}`,created=[];
let now=Date.parse('2026-10-21T01:00:00Z');
const month=aiTimerMonth(now).id;
function png(w,h) {
  const bytes=Buffer.alloc(33); Buffer.from([137,80,78,71,13,10,26,10]).copy(bytes);
  bytes.write('IHDR',12);bytes.writeUInt32BE(w,16);bytes.writeUInt32BE(h,20);return bytes;
}
const source=png(1672,941),art=png(1536,864),hash=rasterHash(source),artHash=rasterHash(art);
const files=new Map(),deleted=[];
let onSave=async()=>{};
const bucket={file:path=>({
  getMetadata:async()=>[{size:files.get(path)?.length,contentType:'image/png'}],
  download:async()=>[files.get(path)],
  save:async bytes=>{assert.ok(!files.has(path));files.set(path,bytes);await onSave(path);},
  delete:async()=>{deleted.push(path);files.delete(path);},
})};
const draft={rawWod:'Row 1,000 m\nSquat 22.5 kg × 12',title:'오늘의 수업',brief:'',
  groups:[{heading:'A',lines:['Row 1,000 m','Squat 22.5 kg × 12']}]};
async function setup(suffix) {
  const uid=`${prefix}-${suffix}`,centerId=uid;
  const templateId='approved',reference={path:`center-templates/${centerId}/${templateId}/${hash}.png`,sha256:hash,width:1672,height:941};
  const logo={path:`users/${uid}/brand/official.png`,sha256:hash,width:1672,height:941,sourceRect:[535,300,615,265]};
  const brand={schemaVersion:1,enabled:true,revision:1,catalogRevision:1,recipeRevision:1,templateId,name:'Local',reference,logo,
    backgroundColor:'#fff8ee',textColor:'#202020',accentColor:'#d45a30'};
  const entries={
    [`users/${uid}/onboarding/progress`]:{storeId:centerId},[`centers/${centerId}`]:{ownerUid:uid},
    [`centers/${centerId}/slideTemplateCatalog/current`]:{revision:1,templates:[{id:templateId,published:true,recipe:{revision:1,backgroundPath:reference.path,backgroundSha256:hash}}]},
    [`centers/${centerId}/aiSlideBrand/current`]:brand,
    [`subscriptionEntitlements/${uid}`]:{plan:'premium',status:'active',validUntilMs:now+86400000},
  };
  for(const [path,value] of Object.entries(entries)) {await db.doc(path).set(value);created.push(path);}
  files.set(reference.path,source);files.set(logo.path,source);
  const key=(await loadRasterBrand(db,uid,centerId)).key;
  let calls=0;
  const success=async()=>{calls++;return {bytes:art,sha256:artHash,width:1536,height:864,costMicros:10000,costBasis:'provider-usage',usage:{textInput:0,imageInput:0,imageOutput:0}};};
  const invoke=(extra={},generate=success)=>handleAiSlideRaster({db,bucket,uid,apiKey:'fake-local',clock:()=>now,
    generate,input:{centerId,action:'generate',requestId:'first',brandKey:key,draft,...extra}});
  return {uid,centerId,brand,key,invoke,success,get calls(){return calls;}};
}
async function resetBudget() {
  // The project is dedicated to this test, not the UI fixture project.
  await db.doc(`aiTimerBudgets/${month}`).set({spentMicros:0,calls:0});
  await db.doc(`aiSlideRasterBudgets/${month}`).set({spentMicros:0,calls:0});
}
try {
  await resetBudget();
  const owner=await setup('owner');
  await assert.rejects(handleAiSlideRaster({db,bucket,uid:'foreign',input:{centerId:owner.centerId,action:'context'},apiKey:'fake-local',clock:()=>now}),{code:'permission-denied'});
  const [first,duplicate]=await Promise.all([owner.invoke(),owner.invoke()]);
  assert.equal(owner.calls,1);assert.ok([first.job.status,duplicate.job.status].includes('completed'));
  const done=await owner.invoke({action:'status'});assert.equal(done.job.status,'completed');
  assert.equal(done.remaining,29);assert.equal(done.job.artifact.path,undefined);
  await owner.invoke();assert.equal(owner.calls,1);
  await assert.rejects(owner.invoke({draft:{...draft,title:'changed'}}),e=>e.details.reason==='request-conflict');
  assert.equal((await db.doc(`aiSlideRasterBudgets/${month}`).get()).data().spentMicros,10000);
  assert.equal((await db.doc(`aiTimerBudgets/${month}`).get()).data().spentMicros,10000);
  now+=6000;
  const uncertain=await owner.invoke({requestId:'second'},async()=>{throw rasterFail('unavailable','private','provider-uncertain');});
  assert.equal(uncertain.job.status,'uncertain');assert.equal(uncertain.remaining,28);
  await owner.invoke({requestId:'second',action:'status'});assert.equal(owner.calls,1);
  const context=await owner.invoke({action:'context'});
  assert.equal(context.previous.requestId,'first');assert.equal(context.recent.requestId,'second');
  assert.equal((await db.doc(`aiSlideRasterBudgets/${month}`).get()).data().spentMicros,10000+RASTER_RESERVE);
  now+=6000;
  const reject=await owner.invoke({requestId:'third'},async()=>{throw rasterFail('unavailable','private','provider-rejected');});
  assert.equal(reject.job.status,'failed');assert.equal(reject.remaining,28);
  assert.equal((await db.doc(`aiSlideRasterBudgets/${month}`).get()).data().spentMicros,10000+RASTER_RESERVE);
  await db.doc(`centers/${owner.centerId}/aiSlideBrand/current`).update({'logo.path':'https://untrusted.example/logo.png'});
  await assert.rejects(owner.invoke({action:'asset',kind:'logo'}),{code:'failed-precondition'});
  await db.doc(`centers/${owner.centerId}/aiSlideBrand/current`).set(owner.brand);
  await db.doc(`centers/${owner.centerId}/slideTemplateCatalog/current`).update({revision:2});
  await assert.rejects(owner.invoke({action:'confirm'}),e=>e.details.reason==='brand-stale');

  await resetBudget();
  const deleting=await setup('deleting');
  onSave=async path=>{if(path.includes('/ai-slide-raster/')) {
    await db.doc(`accountDeletions/${deleting.uid}`).set({status:'pending'});created.push(`accountDeletions/${deleting.uid}`);
    await db.recursiveDelete(db.doc(`users/${deleting.uid}`));
  }};
  await assert.rejects(deleting.invoke(),e=>e.details.reason==='account-changed');
  assert.equal([...files.keys()].some(path=>path.startsWith(`users/${deleting.uid}/ai-slide-raster/`)),false);
  assert.equal((await db.doc(`users/${deleting.uid}`).listCollections()).length,0);
  assert.ok(deleted.every(path=>path.startsWith(`users/${deleting.uid}/ai-slide-raster/`)));
  onSave=async()=>{};
  await resetBudget();
  const exhausted=await setup('budget');
  await db.doc(`aiTimerBudgets/${month}`).set({spentMicros:AI_TIMER_BUDGET-RASTER_RESERVE+1,calls:1});
  await assert.rejects(exhausted.invoke(),e=>e.details.reason==='service-limit');assert.equal(exhausted.calls,0);
  assert.equal((await db.doc(`users/${exhausted.uid}/aiSlidesUsage/${month}`).get()).exists,false);
  console.log('PASS raster Firestore contract: authorization, exact reference, duplicate request, usage, previous result, late-upload compensation, shared cap (fake provider/storage)');
} finally {
  // Only this invocation's isolated fixtures; never clear a shared project.
  for(const path of created.reverse()) await db.doc(path).delete();
  for(const path of [`users/${prefix}-owner`,`users/${prefix}-deleting`,`users/${prefix}-budget`]) await db.recursiveDelete(db.doc(path));
  await deleteApp(app);
}
