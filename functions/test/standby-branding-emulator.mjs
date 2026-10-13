import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {ref as databaseRef, set, get} from 'firebase/database';
import {ref, uploadBytes, getBytes, deleteObject} from 'firebase/storage';
import {doc, setDoc} from 'firebase/firestore';
import {emulatorAddress, requireDemo} from '../../tool/firebase/common.mjs';
import {planAccess} from '../src/plan-policy.js';
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
 console.log('PASS standby branding: callable-only payload, owner/TV separation, Free upload denial, paid upload/delete, downgrade originals retained, expiry denied');
}finally{await env.cleanup();}
