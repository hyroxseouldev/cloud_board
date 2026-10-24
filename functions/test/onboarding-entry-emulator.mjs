import {readFileSync} from 'node:fs';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {doc,getDoc,setDoc,collection,getDocs} from 'firebase/firestore';
import {emulatorAddress,requireDemo} from '../../tool/firebase/common.mjs';
const projectId=requireDemo('demo-cloudboard-entry');
const env=await initializeTestEnvironment({projectId,firestore:{...emulatorAddress(process.env.FIRESTORE_EMULATOR_HOST),rules:readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8')}});
try {
 await env.withSecurityRulesDisabled(async ctx=>{
  const db=ctx.firestore();await setDoc(doc(db,'users/owner/onboarding/progress'),{storeId:'center',completed:true,phoneVerified:true});
  await setDoc(doc(db,'users/owner/onboarding/challenge'),{codeHash:'server-only'});
 });
 const db=env.authenticatedContext('owner').firestore(),foreign=env.authenticatedContext('foreign').firestore();
 await assertSucceeds(getDoc(doc(db,'users/owner/onboarding/progress')));
 await assertFails(setDoc(doc(db,'users/owner/onboarding/progress'),{storeId:'forged',phoneVerified:true}));
 await assertFails(getDoc(doc(foreign,'users/owner/onboarding/progress')));
 await assertFails(getDoc(doc(db,'users/owner/onboarding/challenge')));
 await assertFails(getDocs(collection(db,'users/owner/onboarding')));
 await env.withSecurityRulesDisabled(ctx=>setDoc(doc(ctx.firestore(),'accountDeletions/owner'),{status:'processing'}));
 await assertFails(getDoc(doc(db,'users/owner/onboarding/progress')));
 console.log(`PASS 6 onboarding metadata allow/deny assertions; project=${projectId}; Functions absent`);
} finally {await env.cleanup();}
