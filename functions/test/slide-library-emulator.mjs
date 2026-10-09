import {recordClientDiagnostic, cleanupDiagnosticLimits} from '../src/client-diagnostics.js';
import {manageLibraryFolder} from '../src/library-folders.js';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {initializeApp, deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc} from 'firebase/firestore';
import {mutateSlideLibrary, reconcileSlideLibraryFavorites, normalizeLibraryValue} from '../src/slide-library.js';
assert.match(process.env.FIRESTORE_EMULATOR_HOST || '', /^(127\.0\.0\.1|localhost):\d+$/);
const projectId='demo-cloudboard-library', app=initializeApp({projectId}), db=getFirestore(app);
const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
const env=await initializeTestEnvironment({projectId,firestore:{host,port:Number(port),rules:fs.readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8')}});
const item=(id,favorite=true)=>({id,name:id,text:'운동 설명',category:'',imageUrl:'',workSeconds:60,restSeconds:0,sets:1,showTimer:true,beep:true,coverImage:false,favorite,appearance:{},intervalBlocks:[]});
const patch=(id,base=null,value=item(id))=>({id,base,value});
const write=(changes,options={})=>mutateSlideLibrary(db,'owner',{ownerId:'owner',kind:'templates',changes,...options});
const get=async id=>(await db.doc(`users/owner/slideTemplates/${id}`).get()).data();
try {
  await env.clearFirestore();
  await db.doc('subscriptionEntitlements/owner').set({plan:'plus',maxFavorites:3});
  // Four simultaneous favorites, only three may commit.
  const results=await Promise.allSettled(['a','b','c','d'].map(id=>write([patch(id)])));
  assert.equal(results.filter(r=>r.status==='fulfilled').length,3);
  assert.equal(results.find(r=>r.status==='rejected').reason.code,'resource-exhausted');
  assert.equal((await db.doc('users/owner/libraryState/index').get()).data().favoriteCount,3);
  const existing=(await db.collection('users/owner/slideTemplates').get()).docs[0].data().value;
  await write([patch(existing.id,existing,{...existing,favorite:false})]);
  await assert.rejects(write([patch('new')]),{code:'resource-exhausted'});
  await write([patch(existing.id,{...existing,favorite:false},null)]);
  await write([patch('new')]);
  // Migration keeps every saved slide and favorite flag, skips existing IDs.
  const imported=await write([patch('old1'),patch('old2')],{migration:true});
  assert.equal(imported.demoted,0); assert.equal((await get('old1')).value.favorite,true);
  assert.equal((await get('old1')).value.text,'운동 설명');
  const old=(await get('old1')).value;
  await write([patch('old1',old,null)]);
  await write([patch('old1')],{migration:true});
  assert.equal((await get('old1')).deleted,true);
  // Independent rows survive stale client lists; same row conflicts fail.
  const base=(await get('old2')).value, edited={...base,name:'changed elsewhere'};
  await write([patch('old2',base,edited)]);
  await assert.rejects(write([patch('old2',base,{...base,name:'stale'})]),{code:'aborted'});
  assert.equal((await get('old2')).value.name,'changed elsewhere');
  assert.equal((await write([patch('old2',base,edited)])).changed,0); // idempotent retry
  await db.doc('subscriptionEntitlements/owner').set({plan:'premium',favoritesUnlimited:true});
  await write(['p1','p2','p3','p4'].map(id=>patch(id)));
  assert.equal((await db.doc('users/owner/libraryState/index').get()).data().favoriteCount,8);
  // Downgrade preserves all existing content; quota applies to new saves.
  await db.doc('subscriptionEntitlements/owner').set({plan:'plus'});
  await assert.rejects(write([patch('too-many')]),{code:'resource-exhausted'});
  assert.equal(await reconcileSlideLibraryFavorites(db,'owner'),0);
  assert.equal((await db.doc('users/owner/libraryState/index').get()).data().favoriteCount,8);
  assert.equal((await get('p4')).value.text,'운동 설명');
  assert.equal(await reconcileSlideLibraryFavorites(db,'owner'),0);
  // A delayed downgrade handler reads the latest premium plan and does nothing.
  await db.doc('subscriptionEntitlements/owner').set({plan:'premium',favoritesUnlimited:true});
  await write([patch('extra')]);
  assert.equal(await reconcileSlideLibraryFavorites(db,'owner'),0);
  // A downgrade does not destroy a large pre-existing library.
  const batch=db.batch();
  for(let i=0;i<405;i++) batch.set(db.doc(`users/bulk/slideTemplates/z${String(i).padStart(3,'0')}`),{value:item(`z${String(i).padStart(3,'0')}`),deleted:false});
  batch.set(db.doc('users/bulk/libraryState/index'),{favoriteCount:405});
  batch.set(db.doc('subscriptionEntitlements/bulk'),{plan:'plus'});
  await batch.commit();
  assert.equal(await reconcileSlideLibraryFavorites(db,'bulk'),0);
  assert.equal((await db.doc('users/bulk/libraryState/index').get()).data().favoriteCount,405);
  assert.equal((await db.collection('users/bulk/slideTemplates').get()).size,405);
  await write([patch('plain',null,item('plain',false))]);
  await write([patch('style',null,item('style',false))],{kind:'styles'});
  // New timing survives storage and rejects zero-length/oversized schedules.
  const timed = {...item('emom', false), timingVersion: 2, rounds: 6, roundRestSeconds: 30,
    includeFinalRoundRest: false, intervalBlocks: [
      {id:'a', workSeconds:120, restSeconds:0, sets:3}]};
  await write([patch('emom', null, timed)]);
  assert.equal((await get('emom')).value.rounds, 6);
  assert.equal((await get('emom')).value.includeFinalRoundRest, false);
  await assert.rejects(write([patch('emom', timed, {...timed,
    intervalBlocks:[{id:'zero',workSeconds:0,restSeconds:0,sets:1}]})]), {code:'invalid-argument'});
  await assert.rejects(write([patch('emom', timed, {...timed, rounds:999,
    intervalBlocks:[{id:'huge',workSeconds:120,restSeconds:0,sets:999}]})]), {code:'invalid-argument'});
  const restOnly = {...timed, rounds:1, roundRestSeconds:0, workSeconds:0, restSeconds:30,
    includeFinalRest:false, intervalBlocks:[]};
  await write([patch('emom', timed, restOnly)]);
  assert.equal((await get('emom')).value.workSeconds, 0);
  await write([patch('emom', restOnly, null)]);
  const forTime = {...item('fortime', false), timingVersion:3, timerMode:'forTime', timerDirection:'up', workSeconds:0};
  await write([patch('fortime', null, forTime)]);
  assert.equal((await get('fortime')).value.timerMode, 'forTime');
  assert.equal((await get('fortime')).value.workSeconds, 0);
  await assert.rejects(write([patch('fortime', forTime, {...forTime, timerMode:'amrap'})]), {code:'invalid-argument'});
  await assert.rejects(write([patch('fortime', forTime, {...forTime, timingVersion:2})]), {code:'invalid-argument'});
  await write([patch('fortime', forTime, null)]);
  const owner=env.authenticatedContext('owner').firestore(), other=env.authenticatedContext('other').firestore();
  await assertSucceeds(getDoc(doc(owner,'users/owner/slideTemplates/plain')));
  await assertFails(getDoc(doc(other,'users/owner/slideTemplates/plain')));
  await assertFails(setDoc(doc(owner,'users/owner/slideTemplates/bypass'),{value:item('bypass')}));
  await assertFails(setDoc(doc(owner,'users/owner/libraryState/index'),{favoriteCount:0}));
  // Empty folders persist; rename/remove updates both content and summaries atomically.
  await manageLibraryFolder(db,'owner',{action:'create',name:'운동'});
  await assert.rejects(manageLibraryFolder(db,'owner',{action:'create',name:'운동'}),{code:'already-exists'});
  await db.doc('users/owner/workouts/w').set({id:'w',name:'수업',folder:'운동',updatedAt:new Date(),modules:[{workSeconds:10,restSeconds:5,sets:2}]});
  const originalSlide=(await get('plain')).value;
  await write([patch('plain',originalSlide,{...originalSlide,category:'운동'})]);
  const beforeRename=(await get('plain')).value;
  await manageLibraryFolder(db,'owner',{action:'rename',name:'운동',newName:'준비'});
  assert.equal((await db.doc('users/owner/workouts/w').get()).data().folder,'준비');
  assert.equal((await db.doc('users/owner/workoutSummaries/w').get()).data().durationSeconds,30);
  assert.equal((await get('plain')).value.category,'준비');
  await assert.rejects(write([patch('plain',beforeRename,{...beforeRename,name:'stale'})]),{code:'aborted'});
  // Missing DTO defaults in old data do not cause a false revision conflict.
  const before=(await get('plain')).value;
  await write([patch('plain',normalizeLibraryValue(before),{...normalizeLibraryValue(before),name:'새 이름'})]);
  await manageLibraryFolder(db,'owner',{action:'remove',name:'준비'});
  assert.equal((await get('plain')).value.category,'');
  assert.equal((await get('plain')).value.name,'새 이름');
  assert.equal((await db.doc('users/owner/workouts/w').get()).data().folder,'');
  assert.equal((await db.collection('users/owner/libraryFolders').get()).size,0);
  await assertFails(setDoc(doc(owner,'users/owner/libraryFolders/bypass'),{name:'bypass'}));
  await assertFails(getDoc(doc(other,'users/owner/libraryFolders/bypass')));
  // New clients serialize these defaults even when the old document omitted
  // them. Both library kinds must accept that base without hiding real edits.
  for (const kind of ['templates','styles']) {
    const id=`design-${kind}`, legacy=item(id,false);
    await write([patch(id,null,legacy)],{kind});
    const clientBase={...legacy,designLayout:'auto',designFontWeight:900,designItalic:true,designSpacing:1.0};
    let current={...clientBase,name:'새 디자인 이름'};
    assert.equal((await write([patch(id,clientBase,current)],{kind})).changed,1);
    for (const change of [{designLayout:'columns'},{designFontWeight:700},{designItalic:false},{designSpacing:1.2}]) {
      const base=current, remote={...current,...change};
      await write([patch(id,base,remote)],{kind});
      await assert.rejects(write([patch(id,base,{...base,name:'stale design name'})],{kind}),{code:'aborted'});
      assert.equal((await write([patch(id,base,remote)],{kind})).changed,0);
      const collection=kind==='templates'?'slideTemplates':'slideStyles';
      assert.deepEqual((await db.doc(`users/owner/${collection}/${id}`).get()).data().value,remote);
      current=remote;
    }
  }
  await db.doc('accountDeletions/owner').set({status:'pending'});
  await assert.rejects(write([patch('locked')]),{code:'permission-denied'});
  await assertFails(getDoc(doc(owner,'users/owner/slideTemplates/plain')));
  // Diagnostics run against real Firestore transactions; test events never enter live Logging.
  const diagnosticNow=Date.now(), logged=[];
  const diagnosticPayload={accountId:'diagnostic-test',eventId:'qa-event-0001',occurredAt:new Date(diagnosticNow).toISOString(),severity:'error',type:'StateError',code:'revision_conflict',message:'test only',stack:'test:1',context:{action:'qa.playback.pause'},breadcrumbs:[]};
  const diagnosticArgs={db,auth:{uid:'diagnostic-test',token:{}},payload:diagnosticPayload,emit:(...args)=>logged.push(args),now:diagnosticNow};
  const duplicated=await Promise.all([recordClientDiagnostic(diagnosticArgs),recordClientDiagnostic(diagnosticArgs)]);
  assert.equal(duplicated.filter(r=>r.accepted).length,1);
  assert.equal(logged.length,1);
  await assertFails(getDoc(doc(owner,'clientDiagnosticLimits/diagnostic-test')));
  await db.doc('accountDeletions/diagnostic-test').set({status:'pending'});
  await assert.rejects(recordClientDiagnostic({...diagnosticArgs,payload:{...diagnosticPayload,eventId:'qa-event-0002'}}),{code:'permission-denied'});
  assert.equal(await cleanupDiagnosticLimits(db,diagnosticNow+86400001),1);
  assert.equal((await db.doc('clientDiagnosticLimits/diagnostic-test').get()).exists,false);
  console.log('PASS: concurrent quota, lossless migration, tombstones, conflicts, folders, diagnostic auth/dedup/retention, ownership and deletion lock');
} finally { await env.cleanup(); await db.terminate(); await deleteApp(app); }
