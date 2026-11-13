// Focused local Admin SDK integration. No production, callable/Auth, or image
// body delivery claim: real Firestore/RTDB persistence and pinned Storage metadata.
import assert from 'node:assert/strict';
import {initializeApp,deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {getDatabase} from 'firebase-admin/database';
import {getStorage} from 'firebase-admin/storage';
import {createHash} from 'node:crypto';
import {saveBrandConfig,projectStandbyBranding,defaultStandbyBrand} from '../src/standby-branding.js';
import {planAccess} from '../src/plan-policy.js';
import {requireUsageContext} from '../src/image-usage-ledger.js';
for(const name of ['FIRESTORE_EMULATOR_HOST','FIREBASE_DATABASE_EMULATOR_HOST','FIREBASE_STORAGE_EMULATOR_HOST']) {
  assert.match(process.env[name]??'',/^(127\.0\.0\.1|localhost):\d+$/);
}
const projectId='demo-cloudboard-brand-a';assert.equal(process.env.GCLOUD_PROJECT,projectId);
const app=initializeApp({projectId,databaseURL:`https://${projectId}-default-rtdb.firebaseio.com`,storageBucket:`${projectId}.appspot.com`});
const db=getFirestore(app),realtime=getDatabase(app),bucket=getStorage(app).bucket(),now=Date.now();
const usageContext={db,realtime,bucket,projectId,emulator:true,
  mediaBaseUrl:`http://127.0.0.1:19501/${projectId}/asia-northeast3/cloudboardMedia`};
const bytes=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6N1sAAAAASUVORK5CYII=','base64');
const sha256=createHash('sha256').update(bytes).digest('hex');
const cases=[];const report=name=>{cases.push(name);console.log(`PASS ${name}`);};
const legacyBrand={...defaultStandbyBrand,storeName:'Keep working',logoUrl:'https://example.org/existing.png',promotionImageUrls:[]};
const account=(uid)=>db.doc(`imageUsageAccounts/${uid}`);
const state=async uid=>(await realtime.ref(`users/${uid}`).get()).val();
async function seed(uid,{mode='enrolled',gateMode=mode,policyVersion='plan-entitlements-v2',active=true}={}) {
  await account(uid).set({mode,policyPlan:'premium'});
  await db.doc(`subscriptionEntitlements/${uid}`).set({...planAccess('premium'),plan:'premium',policyVersion,status:'active',validUntilMs:now+3600000,revision:3});
  await realtime.ref(`users/${uid}`).set({usageGate:{mode:gateMode},operations:{brand:legacyBrand},
    ...(active?{activeSession:{id:'existing-class',status:'paused',revision:7}}:{})});
}
async function asset(uid,id,{token=false,wrongOwner=false}={}) {
  const path=`users/${uid}/managed-images/brand/${id}/${sha256}`,file=bucket.file(path);
  await file.save(bytes,{resumable:false,preconditionOpts:{ifGenerationMatch:0},metadata:{contentType:'image/png',
    metadata:{sha256,...(token?{firebaseStorageDownloadTokens:'local-test-token'}:{})}}});
  const [metadata]=await file.getMetadata(),generation=String(metadata.generation);
  const source=`${usageContext.mediaBaseUrl}?assetId=${id}&v=${generation}`;
  const value={assetId:id,source,generation,sizeBytes:bytes.length,contentType:'image/png',sha256,
    ownerId:wrongOwner?'other-owner':uid,bucket:bucket.name,path,tokenFree:true};
  await db.doc(`imageUsageAccounts/${uid}/assets/${id}`).set(value);return value;
}
const request=(uid,value)=>({auth:{uid},data:{brand:value}});
const rejectUnchanged=async(uid,value,context=usageContext)=>{
  const before=await state(uid);
  await assert.rejects(saveBrandConfig(db,realtime,request(uid,value),now,{usageContext:context}));
  assert.deepEqual(await state(uid),before);
};
try {
  const uid='managed-owner';await seed(uid);const valid=await asset(uid,'valid_asset');
  const value={...legacyBrand,logoUrl:valid.source,promotionImageUrls:[valid.source]};
  for(const bad of ['https://external.example/new.png',
    'https://firebasestorage.googleapis.com/v0/b/old/o/users%2Fmanaged-owner%2Fbrand%2Fold.png?alt=media&token=old',
    `${valid.source}&token=extra`]) await rejectUnchanged(uid,{...value,logoUrl:bad});
  report('enrolled external/token/extra-query sources rejected before any RTDB mutation');
  const foreign=await asset(uid,'foreign_asset',{wrongOwner:true}),token=await asset(uid,'token_asset',{token:true});
  await rejectUnchanged(uid,{...value,logoUrl:foreign.source});await rejectUnchanged(uid,{...value,logoUrl:token.source});
  report('real owner registry and token-bearing pinned Storage metadata reject before persistence');
  await saveBrandConfig(db,realtime,request(uid,value),now,{usageContext});
  const saved=await state(uid);
  assert.equal(saved.operations.brandConfig.logoUrl,valid.source);assert.equal(saved.operations.brand.logoUrl,valid.source);
  assert.deepEqual(saved.activeSession,{id:'existing-class',status:'paused',revision:7});
  assert.equal(saved.usageGate.mode,'enrolled');
  report('real private generation metadata verified, save/readback projects source and preserves existing class/fence');

  const v1='v1-managed';await seed(v1,{policyVersion:'plan-entitlements-v1'});const v1asset=await asset(v1,'v1_asset');
  await rejectUnchanged(v1,{...legacyBrand,logoUrl:'https://external.example/v1.png'});
  const beforeEnt=(await db.doc(`subscriptionEntitlements/${v1}`).get()).data();
  await saveBrandConfig(db,realtime,request(v1,{...legacyBrand,logoUrl:v1asset.source}),now,{usageContext});
  assert.equal((await state(v1)).operations.brand.logoUrl,v1asset.source);
  assert.deepEqual((await db.doc(`subscriptionEntitlements/${v1}`).get()).data(),beforeEnt);
  report('enrolled plan-v1 cannot use direct branch and accepts verified source without entitlement migration');

  const enrolling='enrolling-owner';await seed(enrolling,{mode:'legacy',gateMode:'enrolling',active:false});
  await rejectUnchanged(enrolling,{...legacyBrand,logoUrl:'https://external.example/enrolling.png'});
  report('RTDB-first enrolling claim guards even while Firestore usage mode remains legacy');

  const previousBrand=structuredClone((await state(uid)).operations.brand);
  await realtime.ref(`users/${uid}/operations/brandConfig`).set({...value,logoUrl:'https://external.example/stored-legacy.png'});
  const beforeProjection=await state(uid);
  await assert.rejects(projectStandbyBranding(db,realtime,uid,now,{usageContext}));
  assert.deepEqual(await state(uid),beforeProjection);assert.deepEqual((await state(uid)).operations.brand,previousBrand);
  report('invalid stored source refuses projection without deleting/replacing prior working brand');

  const race='race-v1';await seed(race,{mode:'legacy',gateMode:'legacy',policyVersion:'plan-entitlements-v1',active:false});
  let once=true;
  const raceRealtime={ref:path=>{
    const r=realtime.ref(path);if(path!==`users/${race}`)return r;
    return {get:()=>r.get(),transaction:async fn=>{
      if(once){once=false;await r.child('usageGate').set({mode:'enrolling',phase:'enrolling',enrollmentRequestId:'race_claim_01',enrollmentRevision:1});}
      return r.transaction(fn);
    }};
  }};
  const oldOps=structuredClone((await state(race)).operations);
  await assert.rejects(saveBrandConfig(db,raceRealtime,request(race,legacyBrand),now,{usageContext}));
  assert.deepEqual((await state(race)).operations,oldOps);assert.equal((await state(race)).usageGate.mode,'enrolling');
  report('real concurrent enrolling fence defeats legacy-v1 Admin write path before config persistence');

  for(const mode of ['legacy','observe']) {
    const owner=`${mode}-owner`;await seed(owner,{mode,gateMode:mode});
    await saveBrandConfig(db,realtime,request(owner,legacyBrand),now);
    assert.equal((await state(owner)).operations.brand.logoUrl,legacyBrand.logoUrl);
  }
  report('unconverted legacy/observe HTTPS behavior remains compatible without media context');
  await realtime.ref(`users/${uid}/operations/brandConfig`).set({...value,logoUrl:null,promotionImageUrls:{'2':valid.source}});
  await projectStandbyBranding(db,realtime,uid,now,{usageContext});
  assert.equal((await state(uid)).operations.brand.promotionImageUrls['2'],valid.source);
  await realtime.ref(`users/${uid}/devices/brand-display`).set({id:'brand-display',paired:true,displayUid:'brand-tv',pairingCode:'123456',pairedAtMs:now});
  await realtime.ref('displayAccess/brand-tv').set({ownerId:uid,deviceId:'brand-display',pairingCode:'123456',pairedAtMs:now});
  const sparseAccess=await requireUsageContext(usageContext,{actorUid:'brand-tv',ownerId:uid,purpose:'preview'});
  assert.deepEqual(sparseAccess.allowedAssetSources,[valid.source]);
  await realtime.ref(`users/${uid}/operations/brandConfig/promotionImageUrls`).set({'2':'https://external.example/sparse.png'});
  const sparseBefore=await state(uid);
  await assert.rejects(projectStandbyBranding(db,realtime,uid,now,{usageContext}));
  assert.deepEqual(await state(uid),sparseBefore);
  report('Firebase sparse promotion lists retain representation and enforce source validation plus paired whitelist');
  console.log(JSON.stringify({passed:cases.length,cases,projectId,
    evidence:'local Firestore+RTDB+Storage Admin SDK; request auth injected, no actual callable/Auth/Flutter/body delivery'},null,2));
} finally {await deleteApp(app);}
