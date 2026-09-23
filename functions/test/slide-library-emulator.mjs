import assert from 'node:assert/strict';
import fs from 'node:fs';
import {initializeApp, deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc} from 'firebase/firestore';
import {mutateSlideLibrary, reconcileSlideLibraryFavorites} from '../src/slide-library.js';
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
  await write([patch('new')]);
  // Migration keeps all content, demotes excess favorites, skips existing IDs.
  const imported=await write([patch('old1'),patch('old2')],{migration:true});
  assert.equal(imported.demoted,2); assert.equal((await get('old1')).value.favorite,false);
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
  assert.equal((await db.doc('users/owner/libraryState/index').get()).data().favoriteCount,7);
  // Downgrade keeps the first three favorites and all slide content.
  await db.doc('subscriptionEntitlements/owner').set({plan:'plus'});
  await assert.rejects(write([patch('too-many')]),{code:'resource-exhausted'});
  assert.equal(await reconcileSlideLibraryFavorites(db,'owner'),4);
  assert.equal((await db.doc('users/owner/libraryState/index').get()).data().favoriteCount,3);
  assert.equal((await get('p4')).value.text,'운동 설명');
  assert.equal(await reconcileSlideLibraryFavorites(db,'owner'),0);
  // A delayed downgrade handler reads the latest premium plan and does nothing.
  await db.doc('subscriptionEntitlements/owner').set({plan:'premium',favoritesUnlimited:true});
  await write([patch('extra')]);
  assert.equal(await reconcileSlideLibraryFavorites(db,'owner'),0);
  // Exercise cleanup beyond one transaction, with only favorite flags changed.
  const batch=db.batch();
  for(let i=0;i<405;i++) batch.set(db.doc(`users/bulk/slideTemplates/z${String(i).padStart(3,'0')}`),{value:item(`z${String(i).padStart(3,'0')}`),deleted:false});
  batch.set(db.doc('users/bulk/libraryState/index'),{favoriteCount:405});
  batch.set(db.doc('subscriptionEntitlements/bulk'),{plan:'plus'});
  await batch.commit();
  assert.equal(await reconcileSlideLibraryFavorites(db,'bulk'),402);
  assert.equal((await db.doc('users/bulk/libraryState/index').get()).data().favoriteCount,3);
  assert.equal((await db.collection('users/bulk/slideTemplates').get()).size,405);
  await write([patch('plain',null,item('plain',false))]);
  await write([patch('style',null,item('style',false))],{kind:'styles'});
  const owner=env.authenticatedContext('owner').firestore(), other=env.authenticatedContext('other').firestore();
  await assertSucceeds(getDoc(doc(owner,'users/owner/slideTemplates/plain')));
  await assertFails(getDoc(doc(other,'users/owner/slideTemplates/plain')));
  await assertFails(setDoc(doc(owner,'users/owner/slideTemplates/bypass'),{value:item('bypass')}));
  await assertFails(setDoc(doc(owner,'users/owner/libraryState/index'),{favoriteCount:0}));
  await db.doc('accountDeletions/owner').set({status:'pending'});
  await assert.rejects(write([patch('locked')]),{code:'permission-denied'});
  await assertFails(getDoc(doc(owner,'users/owner/slideTemplates/plain')));
  console.log('PASS: concurrent cap, migration, tombstones, conflicts, retries, premium/downgrade, ownership and deletion lock');
} finally { await env.cleanup(); await db.terminate(); await deleteApp(app); }
