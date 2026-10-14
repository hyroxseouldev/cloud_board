import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {ref as databaseRef, set, get} from 'firebase/database';
import {ref, uploadBytes, getBytes, deleteObject} from 'firebase/storage';
import {doc, setDoc} from 'firebase/firestore';
import {emulatorAddress, requireDemo} from '../../tool/firebase/common.mjs';
import {planAccess} from '../src/plan-policy.js';
import {initializeApp as initializeAdminApp} from 'firebase-admin/app';
import {getFirestore as adminFirestore} from 'firebase-admin/firestore';
import {getDatabase as adminDatabase} from 'firebase-admin/database';
import {projectStandbyBranding, saveBrandConfig, defaultStandbyBrand, audienceLogoVersion} from '../src/standby-branding.js';
const projectId=requireDemo(process.env.GCLOUD_PROJECT);
const env=await initializeTestEnvironment({projectId,
 firestore:{...emulatorAddress(process.env.FIRESTORE_EMULATOR_HOST),rules:readFileSync('firestore.rules','utf8')},
 database:{...emulatorAddress(process.env.FIREBASE_DATABASE_EMULATOR_HOST),rules:readFileSync('database.rules.json','utf8')},
 storage:{...emulatorAddress(process.env.FIREBASE_STORAGE_EMULATOR_HOST),rules:readFileSync('storage.rules','utf8')},
});
const uid='branding-owner', owner=env.authenticatedContext(uid),tv=env.authenticatedContext('branding-tv',{firebase:{sign_in_provider:'anonymous'}}),other=env.authenticatedContext('branding-other');
const base=`users/${uid}/operations`, bucket=`gs://${projectId}.firebasestorage.app`;
async function seed(plan,expired=false,status='active'){await env.withSecurityRulesDisabled(async c=>{
 const entitlement={...planAccess(plan),plan,status,validUntilMs:expired?1:Date.now()+3600000};
 await setDoc(doc(c.firestore(),`subscriptionEntitlements/${uid}`),entitlement);
 await set(databaseRef(c.database(),`subscriptionAccess/${uid}`),entitlement);
});}
try {
 await env.withSecurityRulesDisabled(async c=>{
  await set(databaseRef(c.database(),base),{brand:{storeName:'CloudBoard'},brandConfig:{storeName:'Original center',logoUrl:'https://example.org/old.png'},brandProjection:{policyVersion:'plan-entitlements-v2'}});
  await set(databaseRef(c.database(),'displayAccess/branding-tv'),{ownerId:uid,deviceId:'display'});
  await set(databaseRef(c.database(),`users/${uid}/devices/display`),{id:'display',mode:'display',paired:true,
    displayUid:'branding-tv',online:true,lastSeenAtMs:Date.now()});
 });
 for(const plan of ['free','plus','premium']){
  await seed(plan);
  for(const context of [owner,tv,other]) {
   await assertFails(set(databaseRef(context.database(),`${base}/brand`),{storeName:'Injected custom'}));
   await assertFails(set(databaseRef(context.database(),`${base}/brandConfig`),{storeName:'Injected custom'}));
   await assertFails(set(databaseRef(context.database(),`${base}/brandProjection`),null));
  }
  await assertSucceeds(get(databaseRef(owner.database(),`${base}/brandConfig`)));
  await assertSucceeds(get(databaseRef(tv.database(),`${base}/brand`)));
  await assertFails(get(databaseRef(tv.database(),`${base}/brandConfig`)));
  await assertFails(get(databaseRef(other.database(),`${base}/brand`)));
  const image=ref(owner.storage(bucket),`users/${uid}/brand/${plan}.png`);
  if(plan==='free') await assertFails(uploadBytes(image,new Uint8Array([1]),{contentType:'image/png'}));
  else {await assertSucceeds(uploadBytes(image,new Uint8Array([1]),{contentType:'image/png'}));await assertSucceeds(deleteObject(image));}
 }
 await seed('plus');const retained=ref(owner.storage(bucket),`users/${uid}/brand/retained.png`);await uploadBytes(retained,new Uint8Array([7]),{contentType:'image/png'});
 await seed('free');assert.equal((await assertSucceeds(getBytes(retained))).byteLength,1);await assertFails(deleteObject(retained));
 assert.equal((await get(databaseRef(owner.database(),`${base}/brandConfig`))).val().storeName,'Original center');
 await seed('plus',true);await assertFails(uploadBytes(retained,new Uint8Array([2]),{contentType:'image/png'}));
 await seed('plus',false,'past_due');await assertSucceeds(uploadBytes(retained,new Uint8Array([3]),{contentType:'image/png'}));
 await seed('plus',false,'revoked');await assertFails(uploadBytes(retained,new Uint8Array([4]),{contentType:'image/png'}));
 // Match rules-unit-testing's project namespace, not a separate default-rtdb namespace.
 const app=initializeAdminApp({projectId,databaseURL:`https://${projectId}.firebaseio.com`},'audience-branding');
 try {
  const db=adminFirestore(app),realtime=adminDatabase(app),now=Date.now();
  const original={...defaultStandbyBrand,storeName:'Preserved center',showCloudBoardLogo:false,standbyShowText:false,standbyFullscreen:true,promotionImageUrls:['https://example.org/background.png']};
  await realtime.ref(base).set({brand:original});
  const persistedOriginal=(await realtime.ref(`${base}/brand`).get()).val();
  await db.doc('appConfig/audienceBranding').set({version:audienceLogoVersion,enabled:true,ownerIds:[uid]});
  await db.doc(`subscriptionEntitlements/${uid}`).set({...planAccess('free'),plan:'free',status:'active',validUntilMs:now+60000,revision:10});
  await projectStandbyBranding(db,realtime,uid,now);
  const projection=databaseRef(tv.database(),`${base}/brandProjection`);
  const freePolicy=(await assertSucceeds(get(projection))).val();
  assert.equal(freePolicy.ownerId,uid);assert.equal(freePolicy.audienceLogoScope,'all-audience');
  assert.equal(freePolicy.showCloudBoardLogo,true);assert.equal(freePolicy.projectionRevision,1);
  for(const context of [owner,tv,other]) {
   for(const [field,value] of [['showCloudBoardLogo',false],['audienceLogoScope','all-audience'],['projectionRevision',999]])
    await assertFails(set(databaseRef(context.database(),`${base}/brandProjection/${field}`),value));
  }
  await assertFails(get(databaseRef(other.database(),`${base}/brandProjection`)));
  await assertFails(get(databaseRef(tv.database(),`subscriptionAccess/${uid}`)));
  assert.deepEqual((await realtime.ref(`${base}/brandConfig`).get()).val(),persistedOriginal, 'first projection preserves source');
  await assert.rejects(saveBrandConfig(db,realtime,{auth:{uid},data:{brand:original}},now),{code:'permission-denied'});
  await db.doc(`subscriptionEntitlements/${uid}`).set({...planAccess('plus'),plan:'plus',status:'active',validUntilMs:now+60000,revision:11});
  await Promise.all(Array.from({length:4},()=>projectStandbyBranding(db,realtime,uid,now+1)));
  const plusPolicy=(await get(projection)).val();
  assert.equal(plusPolicy.showCloudBoardLogo,false);assert.equal(plusPolicy.projectionRevision,5);
  await saveBrandConfig(db,realtime,{auth:{uid},data:{brand:{...original,showCloudBoardLogo:true}}},now+2);
  const savedPolicy=(await get(projection)).val();
  assert.equal(savedPolicy.revision,11);assert.equal(savedPolicy.projectionRevision,6);assert.equal(savedPolicy.showCloudBoardLogo,true);
  await db.doc(`subscriptionEntitlements/${uid}`).update({status:'unrecognized',revision:12});
  assert.equal(await projectStandbyBranding(db,realtime,uid,now+3),false);
  assert.deepEqual((await get(projection)).val(),savedPolicy,'unknown does not become a new Free policy');
  await db.doc(`subscriptionEntitlements/${uid}`).update({status:'active',revision:11});
  await db.doc('appConfig/audienceBranding').update({enabled:false});
  await projectStandbyBranding(db,realtime,uid,now+4);
  assert.equal((await get(projection)).val().audienceLogoScope,'standby');
 } finally {await app.delete();}
 console.log('PASS standby + audience branding: callable-only payload, owner/TV separation, original preservation, paid upload, atomic visibility, concurrent revision, forged scope/visibility denial, unknown preservation, rollout disable');
}finally{await env.cleanup();}
