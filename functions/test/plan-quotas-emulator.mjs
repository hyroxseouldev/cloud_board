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
assert.match(process.env.FIRESTORE_EMULATOR_HOST ?? '',/^(127\.0\.0\.1|localhost):\d+$/);
const projectId='demo-cloudboard-plan-quotas',app=initializeApp({projectId}),db=getFirestore(app);
const [host,port]=process.env.FIRESTORE_EMULATOR_HOST.split(':');
const env=await initializeTestEnvironment({projectId,firestore:{host,port:Number(port),rules:fs.readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8')}});
const entitlement=plan=>({...planAccess(plan),plan,status:'active',validUntilMs:Date.now()+86400000});
const workout=(id,updatedAt=1000)=>({id,ownerId:'owner',author:{id:'owner',displayName:'Coach',photoUrl:null},name:id,folder:'',modules:[],createdAt:1000,updatedAt,brandL:'Keep brand',brandR:''});
const save=(id,extra={})=>saveWorkout(db,'owner',{ownerId:'owner',workout:workout(id),...extra});
const item=id=>({id,name:id,text:'Workout text',category:'',imageUrl:'',workSeconds:60,restSeconds:0,sets:1,showTimer:true,beep:true,coverImage:false,favorite:true,appearance:{},intervalBlocks:[]});
const patch=(id,base=null,value=item(id))=>({id,base,value});
const library=(changes,extra={})=>mutateSlideLibrary(db,'owner',{ownerId:'owner',kind:'templates',changes,...extra});
const grant=plan=>db.doc('subscriptionEntitlements/owner').set(entitlement(plan));
try {
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
  await assert.rejects(save('w1'),{code:'resource-exhausted'}); // Restore consumes a new slot.
  await assert.rejects(save('w0',{workout:{...workout('w0',2000),name:'Stale'},expectedUpdatedAt:500}),{code:'aborted'});
  assert.equal((await db.doc('users/owner/workouts/w0').get()).data().name,'Legacy edit');
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
