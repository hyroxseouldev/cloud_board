import assert from 'node:assert/strict';
import fs from 'node:fs';
import {initializeApp,deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {doc,setDoc,deleteDoc,updateDoc} from 'firebase/firestore';
import {planAccess} from '../src/plan-policy.js';
import {saveWorkout} from '../src/workout-save.js';
import {mutateSlideLibrary} from '../src/slide-library.js';
import {reconcilePlanUsage} from '../src/plan-usage.js';
import {legacySettingKeys, normalizeSettings} from '../src/workout-settings-migration.js';
assert.match(process.env.FIRESTORE_EMULATOR_HOST ?? '',/^(127\.0\.0\.1|localhost):\d+$/);
const projectId='demo-cloudboard-plan-quotas',app=initializeApp({projectId}),db=getFirestore(app);
const [host,port]=process.env.FIRESTORE_EMULATOR_HOST.split(':');
const env=await initializeTestEnvironment({projectId,firestore:{host,port:Number(port),rules:fs.readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8')}});
const entitlement=plan=>({...planAccess(plan),plan,status:'active',validUntilMs:Date.now()+86400000});
const workout=(id,updatedAt=1000)=>({id,ownerId:'owner',author:{id:'owner',displayName:'Coach',photoUrl:null},name:id,folder:'',modules:[],createdAt:1000,updatedAt,brandL:'Keep brand',brandR:''});
// The released Flutter repository sends the draft revision on first save too.
const save=(id,extra={})=>saveWorkout(db,'owner',{ownerId:'owner',workout:workout(id),expectedUpdatedAt:1000,...extra});
const item=id=>({id,name:id,text:'Workout text',category:'',imageUrl:'',workSeconds:60,restSeconds:0,sets:1,showTimer:true,beep:true,coverImage:false,favorite:true,appearance:{},intervalBlocks:[]});
const patch=(id,base=null,value=item(id))=>({id,base,value});
const library=(changes,extra={})=>mutateSlideLibrary(db,'owner',{ownerId:'owner',kind:'templates',changes,...extra});
const grant=plan=>db.doc('subscriptionEntitlements/owner').set(entitlement(plan));
try {
  await env.clearFirestore();
  await grant('free');
  const first={workout:workout('first-save',2000),expectedUpdatedAt:1000,requireExisting:false};
  assert.equal((await save('first-save',first)).created,true);
  assert.equal((await db.doc('users/owner/workouts/first-save').get()).data().updatedAt.toMillis(),2000);
  assert.equal((await db.doc('users/owner/workoutSummaries/first-save').get()).exists,true);
  assert.equal((await db.doc('users/owner/planUsage/current').get()).data().workoutCount,1);
  assert.equal((await save('first-save',first)).created,false); // Lost response, same payload.
  await save('first-save',{workout:{...workout('first-save',3000),name:'Edited'},expectedUpdatedAt:2000,requireExisting:true});
  assert.equal((await db.doc('users/owner/planUsage/current').get()).data().workoutCount,1);
  const latest={...workout('first-save',4000),name:'Latest save',createdAt:999};
  await save('first-save',{workout:latest,expectedUpdatedAt:2000,requireExisting:true});
  const overwritten=(await db.doc('users/owner/workouts/first-save').get()).data();
  assert.equal(overwritten.name,'Latest save');
  assert.equal(overwritten.createdAt.toMillis(),1000);
  await db.doc('users/owner/workouts/first-save').update({futureMetadata:{retained:true},modules:[{...item('m1'),imageSource:'removed-image'},{...item('m2')}]});
  const modules=[{...item('m1'),text:'Last slide content',imageUrl:''}];
  const cleared=await save('first-save',{workout:{...latest,modules,futureMetadata:{retained:true}},expectedUpdatedAt:null});
  assert.deepEqual(cleared.workout.modules,modules); // No removed slide/known field resurrection.
  assert.deepEqual(cleared.workout.futureMetadata,{retained:true});
  const imported=await save('first-save',{workout:{...latest,name:'Starter import'},ifAbsent:true});
  assert.equal(imported.workout.name,'Latest save');
  assert.equal(imported.created,false);
  await db.doc('users/owner/workouts/first-save').delete();
  assert.equal((await save('first-save',{...first,requireExisting:true})).created,true);
  assert.equal((await db.doc('users/owner/planUsage/current').get()).data().workoutCount,1);
  const firstRace=await Promise.allSettled(['A','B'].map(name=>save('same-new-id',{
    workout:{...workout('same-new-id',2000),name},expectedUpdatedAt:1000,requireExisting:false,
  })));
  assert.equal(firstRace.filter(result=>result.status==='fulfilled').length,2);
  assert(['A','B'].includes((await db.doc('users/owner/workouts/same-new-id').get()).data().name));
  assert.equal((await db.doc('users/owner/planUsage/current').get()).data().workoutCount,2);
  const preferences=normalizeSettings({brandL:'Current canonical brand',countdown:{seconds:17}});
  const settingsRef=db.doc('users/owner/settings/workout');
  await settingsRef.set({schemaVersion:1,revision:1,contentOnly:true,preferences});
  const contentOnly=(await save('settings-migration',{settingsContentOnly:false})).workout;
  assert.equal(contentOnly.schemaVersion,2);
  assert(legacySettingKeys.every(key=>!Object.hasOwn(contentOnly,key)));
  await settingsRef.update({contentOnly:false,revision:2});
  const restored=(await save('settings-migration',{workout:{...contentOnly,name:'After restore'},settingsContentOnly:true})).workout;
  assert.equal(restored.schemaVersion,undefined);
  assert.equal(restored.brandL,'Current canonical brand');
  assert.equal(restored.countdownSeconds,17);
  await settingsRef.update({contentOnly:true,revision:3});
  await save('settings-migration',{workout:restored,settingsContentOnly:false});
  await settingsRef.delete();
  await assert.rejects(save('settings-migration',{workout:contentOnly,settingsContentOnly:true}),{code:'failed-precondition'});
  assert.equal((await db.doc('users/owner/workouts/settings-migration').get()).data().schemaVersion,2);
  await assert.rejects(saveWorkout(db,null,{ownerId:'owner',workout:workout('no-auth')}),{code:'unauthenticated'});
  await assert.rejects(save('other-owner',{ownerId:'other'}),{code:'permission-denied'});
  await assert.rejects(save('other-author',{workout:{...workout('other-author'),author:{id:'other'}}}),{code:'invalid-argument'});
  console.log('PASS: first-save/retry, last-write-wins, immutable creation, deliberate module removal, prepared future fields, ifAbsent import, restore quota, same-ID races, settings normalization and owner guards');
  await env.clearFirestore();
  await assert.rejects(save('missing'),{code:'failed-precondition'});
  await grant('free');
  for(let i=0;i<6;i++) await save(`w${i}`);
  const race=await Promise.allSettled([save('seventh-a'),save('seventh-b')]);
  assert.equal(race.filter(x=>x.status==='fulfilled').length,1);
  assert.equal(race.find(x=>x.status==='rejected').reason.code,'resource-exhausted');
  assert.equal((await db.collection('users/owner/workouts').get()).size,7);
  const won=race[0].status==='fulfilled'?'seventh-a':'seventh-b';
  await save(won); // Lost-response retry creates no duplicate slot.
  await assert.rejects(save('copy'),e=>e.details?.resource==='workouts'&&e.details.limit===7&&e.details.used===7);
  const owner=env.authenticatedContext('owner').firestore();
  await assertFails(setDoc(doc(owner,'users/owner/workouts/legacy-bypass'),workout('legacy-bypass')));
  await assertFails(setDoc(doc(owner,'users/owner/planUsage/current'),{workoutCount:0}));
  await assertFails(updateDoc(doc(owner,'subscriptionEntitlements/owner'),{policyVersion:'old'}));
  // Direct legacy edits and deletes remain permitted; recount sees deletion
  // immediately without waiting for the asynchronous usage trigger.
  await assertSucceeds(updateDoc(doc(owner,'users/owner/workouts/w0'),{name:'Legacy edit'}));
  await assertSucceeds(deleteDoc(doc(owner,'users/owner/workouts/w1')));
  await save('after-delete');
  await assert.rejects(save('w1',{requireExisting:true}),{code:'resource-exhausted'}); // Restore consumes a new slot.
  await save('w0',{workout:{...workout('w0',2000),name:'Latest owner save'},expectedUpdatedAt:500});
  assert.equal((await db.doc('users/owner/workouts/w0').get()).data().name,'Latest owner save');
  // Upgrade permits growth; downgrade preserves all content and existing edits.
  await grant('plus');
  for(let i=0;i<3;i++) await save(`paid${i}`);
  const withMetadata={...workout('paid1',2000),futureMetadata:{timestamp:{__timestampMillis:1234},retained:true}};
  await save('paid1',{workout:withMetadata,expectedUpdatedAt:1000,requireExisting:true});
  assert.equal((await db.doc('users/owner/workouts/paid1').get()).data().futureMetadata.timestamp.toMillis(),1234);
  assert.deepEqual((await save('paid1',{workout:withMetadata,expectedUpdatedAt:1000,requireExisting:true})).workout,withMetadata);
  await grant('free');
  await save('paid0',{workout:{...workout('paid0',2000),name:'Kept edit'},expectedUpdatedAt:1000,requireExisting:true});
  await assert.rejects(save('new-overage'),{code:'resource-exhausted'});
  assert.equal((await db.collection('users/owner/workouts').get()).size,10);
  await db.doc('subscriptionEntitlements/owner').delete();
  await save('paid0',{workout:{...workout('paid0',3000),name:'Available edit'},expectedUpdatedAt:2000,requireExisting:true});
  await assert.rejects(save('missing-access'),{code:'failed-precondition'});
  await grant('free');
  const slides=await Promise.allSettled(['a','b','c','d'].map(id=>library([patch(id)])));
  assert.equal(slides.filter(x=>x.status==='fulfilled').length,3);
  assert.equal(slides.find(x=>x.status==='rejected').reason.details.resource,'savedSlides');
  await assert.rejects(library([patch('fake-migration')],{migration:true}),{code:'resource-exhausted'});
  const existing=(await db.collection('users/owner/slideTemplates').get()).docs[0].data().value;
  await library([patch(existing.id,existing,null)]);
  await library([patch('free-slot')]);
  await library([patch(existing.id)],{migration:true}); // Tombstone is not resurrected.
  assert.equal((await db.doc(`users/owner/slideTemplates/${existing.id}`).get()).data().deleted,true);
  await grant('plus');
  for(let i=0;i<26;i++) await library([patch(`plus${i}`)]);
  const plusRace=await Promise.allSettled(['last-a','last-b'].map(id=>library([patch(id)])));
  assert.equal(plusRace.filter(x=>x.status==='fulfilled').length,1);
  assert.equal(plusRace.find(x=>x.status==='rejected').reason.details.limit,30);
  await grant('premium');
  await library(Array.from({length:40},(_,i)=>patch(`premium${i}`)));
  assert.equal((await db.doc('users/owner/libraryState/index').get()).data().savedCount,70);
  await grant('free');
  await library([patch('premium0',item('premium0'),{...item('premium0'),name:'Preserved'})]);
  await assert.rejects(library([patch('overage')]),{code:'resource-exhausted'});
  await assertFails(setDoc(doc(owner,'users/owner/slideTemplates/bypass'),{value:item('bypass')}));
  const usage=await reconcilePlanUsage(db,'owner');
  assert.deepEqual([usage.workoutCount,usage.savedSlideCount],[10,70]);
  assert.deepEqual([...(await db.doc('users/owner/planUsage/current').get()).data().policyVersion], [...'plan-entitlements-v2']);
  // Rollout gate preserves old account direct creates until deliberate v2
  // activation; migration records do not get deleted or arbitrarily demoted.
  await db.doc('subscriptionEntitlements/owner').set({...entitlement('free'),policyVersion:'old'});
  const old=workout('pre-activation');
  await assertSucceeds(setDoc(doc(owner,'users/owner/workouts/pre-activation'),{...old,createdAt:new Date(1000),updatedAt:new Date(1000)}));
  await grant('free');
  await assertFails(setDoc(doc(owner,'users/owner/workouts/offline-replay'),workout('offline-replay')));
  await db.doc('accountDeletions/owner').set({status:'pending'});
  await assert.rejects(save('locked'),{code:'permission-denied'});
  console.log('PASS: Free 7, Free slides3/Plus30/Premium unlimited; final-slot races; legacy and migration bypass; duplicate/import/restore/retry; missing grant; downgrade and atomic preservation; rollout gate');
} finally {await env.cleanup();await db.terminate();await deleteApp(app);}
