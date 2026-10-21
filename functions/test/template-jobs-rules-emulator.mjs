import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {collection, doc, getDoc, getDocs, setDoc, deleteDoc, updateDoc, setLogLevel} from 'firebase/firestore';

// Deliberately separate from the running app's demo project. Never clear app data.
const projectId = process.env.GCLOUD_PROJECT;
assert.equal(projectId, 'demo-cloudboard-template-jobs-rules');
assert.match(process.env.FIRESTORE_EMULATOR_HOST ?? '', /^(127\.0\.0\.1|localhost):\d+$/);
const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
setLogLevel('silent');
const env = await initializeTestEnvironment({projectId, firestore: {host, port: Number(port), rules: readFileSync('firestore.rules', 'utf8')}});
const path = 'users/owner/templateGenerationCenters/center/jobs/job-one';
const signedIn = {firebase:{sign_in_provider:'password'}};
const owner = env.authenticatedContext('owner',signedIn);
try {
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await setDoc(doc(db,'centers/center'),{ownerUid:'owner'});
    await setDoc(doc(db,'users/owner/onboarding/progress'),{storeId:'center'});
    await setDoc(doc(db,path),{status:'pending',createdAtMs:1});
  });
  await assertSucceeds(getDoc(doc(owner.firestore(),path)));
  await assertSucceeds(getDocs(collection(owner.firestore(),'users/owner/templateGenerationCenters/center/jobs')));
  for (const context of [owner,env.authenticatedContext('stranger',signedIn),
    env.authenticatedContext('owner',{firebase:{sign_in_provider:'anonymous'}}),env.unauthenticatedContext()]) {
    if (context !== owner) await assertFails(getDoc(doc(context.firestore(),path)));
    await assertFails(setDoc(doc(context.firestore(),path),{status:'complete'}));
    await assertFails(updateDoc(doc(context.firestore(),path),{status:'complete'}));
    await assertFails(deleteDoc(doc(context.firestore(),path)));
    await assertFails(setDoc(doc(context.firestore(),'templateGenerationQueue/forged'),{dueAtMs:0}));
  }
  await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'users/owner/onboarding/progress'),{storeId:'different'}));
  await assertFails(getDoc(doc(owner.firestore(),path)));
  await env.withSecurityRulesDisabled(async c=>{
    await updateDoc(doc(c.firestore(),'users/owner/onboarding/progress'),{storeId:'center'});
    await setDoc(doc(c.firestore(),'accountDeletions/owner'),{status:'pending'});
  });
  await assertFails(getDoc(doc(owner.firestore(),path)));
  console.log('PASS template jobs rules: owner/active center read, no client mutation, no anonymous/foreign read, deletion lock, private queue');
} finally {await env.cleanup();}
