import assert from 'node:assert/strict';
import fs from 'node:fs';
import {initializeApp, deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {initializeTestEnvironment, assertFails} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc} from 'firebase/firestore';
import {handleAiSlides, readSlidePrompt} from '../src/ai-slides.js';
import {handleAiTimer, AI_TIMER_BUDGET, AI_TIMER_RESERVE} from '../src/ai-timer.js';
assert.match(process.env.FIRESTORE_EMULATOR_HOST||'', /^(127\.0\.0\.1|localhost):\d+$/);
const projectId='demo-cloudboard-ai';
const app=initializeApp({projectId}), db=getFirestore(app);
const [host,port]=process.env.FIRESTORE_EMULATOR_HOST.split(':');
const env=await initializeTestEnvironment({projectId,firestore:{host,port:Number(port),rules:fs.readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8')}});
const now=Date.parse('2026-10-03T00:00:00Z');
const result={complete:true,slides:[{title:'WARM UP',layout:'numbered',sourceTitleLineIds:[1],
  sections:[{heading:'',lines:['Squat 10 reps'],sourceLineIds:[1]}],workSeconds:300,restSeconds:0,sets:1}],warnings:[]};
let calls=0;
const recognize=async()=>{calls++;return {result,costMicros:500};};
const input={action:'generate',prompt:'WARM UP: Squat 10 reps, 5 minutes, no rest, 1 set'};
const call=(uid,extra={})=>handleAiSlides({db,uid,input,apiKey:'fake',now,recognize,...extra});
const grant=uid=>db.doc(`subscriptionEntitlements/${uid}`).set({plan:'premium',status:'active',validUntilMs:now+3600000});
try {
  await env.clearFirestore();
  await assert.rejects(call('free'),{code:'permission-denied'}); assert.equal(calls,0);
  await grant('owner');
  const status=await call('owner',{input:{action:'status'}}); assert.equal(status.limit,30); assert.equal(calls,0);
  await Promise.allSettled([call('owner'),call('owner')]);
  assert.equal(calls,1); assert.equal((await call('owner')).cached,true);
  assert.equal((await db.doc('aiTimerBudgets/2026-10').get()).data().spentMicros,500);
  await db.doc('users/owner/aiSlidesUsage/2026-10').update({used:30});
  assert.equal((await call('owner')).cached,true);
  await assert.rejects(call('owner',{now:now+10000,input:{...input,prompt:'other lesson'}}),{code:'resource-exhausted'});
  await db.doc('subscriptionEntitlements/owner').update({plan:'free'});
  await assert.rejects(call('owner'),{code:'permission-denied'});
  await grant('failure');
  await assert.rejects(call('failure',{recognize:async()=>{throw new Error('private');}}),{code:'internal'});
  assert.equal((await db.doc('users/failure/aiSlidesUsage/2026-10').get()).data().used,0);
  assert.equal((await db.doc('aiTimerBudgets/2026-10').get()).data().spentMicros,500+AI_TIMER_RESERVE);
  await grant('invalid-input');
  await assert.rejects(call('invalid-input',{input:{...input,prompt:'x'.repeat(6001)}}),{code:'invalid-argument'});
  assert.equal((await db.doc('users/invalid-input/aiSlidesUsage/2026-10').get()).exists,false,
    'invalid input must not reserve successful-use quota or contact the provider');
  await grant('missing-quantity');
  await assert.rejects(call('missing-quantity',{recognize:async()=>({result:{...result,slides:[{...result.slides[0],
    sections:[{heading:'',lines:['Squat'],sourceLineIds:[1]}]}]},costMicros:500})}),
  error=>error.details.reason==='changed-source-quantity');
  assert.equal((await db.doc('users/missing-quantity/aiSlidesUsage/2026-10').get()).data().used,0,
    'a source-preservation rejection must refund successful-use quota');
  await grant('deleting');
  await call('deleting',{recognize:async()=>{
    await db.doc('accountDeletions/deleting').set({status:'pending'});
    await db.recursiveDelete(db.doc('users/deleting'));
    return {result,costMicros:500};
  }});
  assert.equal((await db.doc('users/deleting').listCollections()).length,0,'API completion must not recreate a deleted account');
  await grant('slides'); await grant('timer');
  await db.doc('aiTimerBudgets/2026-10').set({spentMicros:AI_TIMER_BUDGET-AI_TIMER_RESERVE,calls:10});
  let resolve; const pending=new Promise(r=>{resolve=r;});
  const first=call('slides',{recognize:async()=>{await pending;return {result,costMicros:500};}});
  for(let i=0;i<80;i++) {if((await db.doc('aiTimerBudgets/2026-10').get()).data().spentMicros===AI_TIMER_BUDGET)break;await new Promise(r=>setTimeout(r,20));}
  const image=Buffer.alloc(24); Buffer.from([137,80,78,71,13,10,26,10]).copy(image); image.write('IHDR',12); image.writeUInt32BE(1024,16); image.writeUInt32BE(768,20);
  await assert.rejects(handleAiTimer({db,uid:'timer',input:{action:'analyze',imageBase64:image.toString('base64')},apiKey:'fake',now,
    recognize:async()=>{throw new Error('must not call');}}),{code:'resource-exhausted'});
  resolve(); await first;
  await db.doc('appConfig/aiSlides').set({enabled:false});
  await assert.rejects(call('slides'),{code:'failed-precondition'});
  const client=env.authenticatedContext('owner').firestore();
  for(const path of ['appConfig/aiSlides','users/owner/aiSlidesUsage/2026-10',`users/owner/aiSlidesJobs/${readSlidePrompt(input).key}`]) {
    await assertFails(getDoc(doc(client,path))); await assertFails(setDoc(doc(client,path),{used:0,enabled:true}));
  }
  console.log('PASS AI slides: premium, explicit requests, deduplication, quota/cache, failure refund, shared timer budget, deletion, kill switch, rules');
} finally {await env.cleanup();await deleteApp(app);}
