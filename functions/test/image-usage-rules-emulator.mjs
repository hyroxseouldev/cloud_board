import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc, setDoc, getDoc, serverTimestamp, updateDoc} from 'firebase/firestore';
import {ref as dbRef, set, get, update} from 'firebase/database';
import {ref as objectRef, uploadBytes, getBytes, deleteObject, updateMetadata, listAll} from 'firebase/storage';

const local = value => {
  assert.match(value ?? '', /^(localhost|127\.0\.0\.1):\d+$/);
  const [host, port] = value.split(':'); return {host, port:Number(port)};
};
const projectId = process.env.GCLOUD_PROJECT;
assert.match(projectId ?? '', /^demo-/);
const env = await initializeTestEnvironment({projectId,
  firestore:{...local(process.env.FIRESTORE_EMULATOR_HOST),rules:readFileSync('firestore.rules','utf8')},
  database:{...local(process.env.FIREBASE_DATABASE_EMULATOR_HOST),rules:readFileSync('database.rules.json','utf8')},
  storage:{...local(process.env.FIREBASE_STORAGE_EMULATOR_HOST),rules:readFileSync('storage.rules','utf8')},
});
const bucket = `gs://${projectId}.firebasestorage.app`;
const owner = uid => env.authenticatedContext(uid,{auth_time:Math.floor(Date.now()/1000),firebase:{sign_in_provider:'password'}});
const contexts = Object.fromEntries(['legacy','observe','enrolled'].map(mode=>[mode,owner(mode)]));
const tv = env.authenticatedContext('tv',{auth_time:Math.floor(Date.now()/1000),firebase:{sign_in_provider:'anonymous'}});
const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII=','base64');
const workout = {id:'w',ownerId:'enrolled',name:'Class',createdAt:1,updatedAt:1};
const state = {schemaVersion:2,id:'session-one',ownerId:'enrolled',zoneId:'main',status:'playing',stepIndex:0,
  remainingMs:30000,anchorServerMs:Date.now(),revision:1,updatedByDeviceId:'controller',workoutId:'w',snapshotId:'session-one',
  targetDeviceIds:['tv-one'],admissionId:'admission-one',epoch:1,manifestHash:'a'.repeat(64),briefing:false};
let assertions = 0;
async function yes(promise) { assertions++; return assertSucceeds(promise); }
async function no(promise) { assertions++; return assertFails(promise); }
try {
  await env.clearFirestore(); await env.clearDatabase(); await env.clearStorage();
  await env.withSecurityRulesDisabled(async admin=>{
    for (const mode of Object.keys(contexts)) {
      await setDoc(doc(admin.firestore(),`imageUsageAccounts/${mode}`),{mode,inventoryComplete:true});
      await setDoc(doc(admin.firestore(),`users/${mode}`),{uid:mode,photoUrl:null,displayName:'Coach'});
      await setDoc(doc(admin.firestore(),`users/${mode}/workouts/w`),{id:'w',ownerId:mode,author:{id:mode},createdAt:1,name:'Existing'});
      for (const purpose of ['profile','brand','workouts/w/images']) {
        await uploadBytes(objectRef(admin.storage(bucket),`users/${mode}/${purpose}/old.png`),png,{contentType:'image/png'});
      }
      await uploadBytes(objectRef(admin.storage(bucket),`users/${mode}/managed-images/workout/asset/hash`),png,{contentType:'image/png'});
      await set(dbRef(admin.database(),`users/${mode}/usageGate`),{mode,policyRevision:'image-usage-2.1.5-v1',
        epoch:1,phase:'active',admissionId:'admission-one',sessionId:'session-one',manifestHash:'a'.repeat(64),preparedSnapshotId:'session-one'});
    }
    await set(dbRef(admin.database(),'subscriptionAccess/enrolled'),{plan:'free',validUntilMs:Date.now()-1000});
    await set(dbRef(admin.database(),'users/enrolled/playbackSnapshots/session-one'),workout);
    await set(dbRef(admin.database(),'users/enrolled/activeSession'),state);
    await set(dbRef(admin.database(),'users/enrolled/devices/tv-one'),{id:'tv-one',mode:'display',online:true,lastSeenAtMs:Date.now(),
      displayUid:'tv',paired:true,pairingCode:'123456',pairedAtMs:1,preparationProtocol:1});
    await set(dbRef(admin.database(),'displayAccess/tv'),{ownerId:'enrolled',deviceId:'tv-one',pairingCode:'123456',pairedAtMs:1});
  });
  for (const [mode,context] of Object.entries(contexts)) {
    const storage = context.storage(bucket); storage.setMaxUploadRetryTime(1000); storage.setMaxOperationRetryTime(1000);
    const profile=doc(context.firestore(),`users/${mode}`);
    const remote='https://external.invalid/unmetered.png';
    const mutateProfile=setDoc(profile,{uid:mode,photoUrl:remote},{merge:true});
    if (mode==='enrolled') await no(mutateProfile); else await yes(mutateProfile);
    const mutateWorkout=updateDoc(doc(context.firestore(),`users/${mode}/workouts/w`),{name:'Updated',newImage:remote});
    if (mode==='enrolled') await no(mutateWorkout); else await yes(mutateWorkout);
    const mutateBrand=set(dbRef(context.database(),`users/${mode}/operations/brand`),{logoUrl:remote});
    if (mode==='enrolled') await no(mutateBrand); else await yes(mutateBrand);
    for (const purpose of ['profile','brand','workouts/w/images']) {
      const path = `users/${mode}/${purpose}`;
      if (mode === 'enrolled') {
        await no(getBytes(objectRef(storage,`${path}/old.png`)));
        await no(listAll(objectRef(storage,path)));
        await no(uploadBytes(objectRef(storage,`${path}/new.png`),png,{contentType:'image/png'}));
        await no(updateMetadata(objectRef(storage,`${path}/old.png`),{customMetadata:{firebaseStorageDownloadTokens:'bypass'}}));
      } else {
        assert.equal((await yes(getBytes(objectRef(storage,`${path}/old.png`)))).byteLength,png.length);
        await yes(uploadBytes(objectRef(storage,`${path}/new.png`),png,{contentType:'image/png'}));
      }
      await yes(deleteObject(objectRef(storage,`${path}/old.png`)));
    }
    const managed = objectRef(storage,`users/${mode}/managed-images/workout/asset/hash`);
    await no(getBytes(managed)); await no(deleteObject(managed));
    await no(uploadBytes(objectRef(storage,`users/${mode}/managed-images/workout/new/hash`),png,{contentType:'image/png'}));
    await no(getDoc(doc(context.firestore(),`imageUsageAccounts/${mode}`)));
    await no(setDoc(doc(context.firestore(),`imageUsageAccounts/${mode}/grants/forged`),{additionalDayBytes:1000000}));
    await no(set(dbRef(context.database(),`users/${mode}/usageGate`),{mode:'legacy'}));
    await no(set(dbRef(context.database(),`users/${mode}`),{activeSession:null,usageGate:{mode:'legacy'}}));
  }

  const managedSource=`https://asia-northeast3-${projectId}.cloudfunctions.net/cloudboardMedia?assetId=registry-one&v=1`;
  await env.withSecurityRulesDisabled(admin=>setDoc(doc(admin.firestore(),'imageUsageAccounts/enrolled/assets/registry-one'),
    {ownerId:'enrolled',tokenFree:true,source:managedSource}));
  const profile=doc(contexts.enrolled.firestore(),'users/enrolled');
  await yes(setDoc(profile,{uid:'enrolled',photoUrl:managedSource},{merge:true}));
  const localSource=`http://127.0.0.1:5001/${projectId}/asia-northeast3/cloudboardMedia?assetId=local-registry&v=1`;
  await env.withSecurityRulesDisabled(admin=>setDoc(doc(admin.firestore(),'imageUsageAccounts/enrolled/assets/local-registry'),{ownerId:'enrolled',tokenFree:true,source:localSource}));
  await yes(setDoc(profile,{uid:'enrolled',photoUrl:localSource},{merge:true}));
  await no(setDoc(profile,{uid:'enrolled',photoUrl:managedSource.replace('registry-one','forged')},{merge:true}));
  await no(setDoc(profile,{uid:'enrolled',photoUrl:managedSource+'&token=bypass'},{merge:true}));
  await yes(setDoc(profile,{uid:'enrolled',photoUrl:null},{merge:true}));
  await yes(setDoc(profile,{uid:'enrolled',photoUrl:`data:image/png;base64,${png.toString('base64')}`},{merge:true}));
  await yes(setDoc(profile,{uid:'enrolled',photoUrl:png.toString('base64')},{merge:true}));
  await yes(setDoc(profile,{uid:'enrolled',photoUrl:png.toString('base64').replace(/=/g,'')},{merge:true}));
  await yes(setDoc(profile,{uid:'enrolled',photoUrl:png.toString('base64').replaceAll('+','-').replaceAll('/','_')},{merge:true}));
  await yes(setDoc(profile,{uid:'enrolled',photoUrl:'data:image/png;base64,%69'+png.toString('base64').slice(1)},{merge:true}));
  await no(setDoc(profile,{uid:'enrolled',photoUrl:'data:text/html;base64,PGh0bWw+PC9odG1sPg=='},{merge:true}));
  await no(setDoc(profile,{uid:'enrolled',photoUrl:'data:image/png;base64,not-base64'},{merge:true}));
  await no(setDoc(profile,{uid:'enrolled',photoUrl:'a'.repeat(900004)},{merge:true}));
  await yes(setDoc(profile,{uid:'enrolled',photoUrl:null},{merge:true}));
  const appearance={showReady:true,showTitle:true,numberScale:1,numberFormat:'seconds',numberColor:null,numberShadow:true,overlayEnabled:false,overlayOpacity:null,overlayColor:null};
  const countdown={seconds:3,backgroundColor:4278190080,imageSource:managedSource,appearance};
  await yes(setDoc(profile,{uid:'enrolled',countdownDefaults:countdown},{merge:true}));
  await no(setDoc(profile,{uid:'enrolled',countdownDefaults:{...countdown,imageSource:'https://external.invalid/unmetered.png'}},{merge:true}));
  const preferences={brandL:'',brandR:'',soundTheme:'videoBeep',countdownSound:'videoBeep',workStartSound:'videoBeep',restStartSound:'videoBeep',workoutEndSound:'videoBeep',soundVolume:1,countdown};
  const settings=doc(contexts.enrolled.firestore(),'users/enrolled/settings/workout');
  await yes(setDoc(settings,{schemaVersion:1,revision:1,updatedAt:serverTimestamp(),contentOnly:false,preferences}));
  await no(setDoc(settings,{schemaVersion:1,revision:2,updatedAt:serverTimestamp(),contentOnly:false,preferences:{...preferences,countdown:{...countdown,imageSource:'https://external.invalid/unmetered.png'}}}));
  const enrolling=owner('enrolling');
  const enrollingState={...state,ownerId:'enrolling',targetDeviceIds:[]};
  const enrollingWorkout={...workout,ownerId:'enrolling'};
  await env.withSecurityRulesDisabled(async admin=>{
    await set(dbRef(admin.database(),'users/enrolling/usageGate'),{mode:'enrolling',phase:'enrolling',enrollmentRequestId:'enroll-request',enrollmentPayloadHash:'f'.repeat(64),enrollmentRevision:2,epoch:0});
    await set(dbRef(admin.database(),'legacyPilotAccess/enrolling'),{validUntilMs:Date.now()+600000});
    await set(dbRef(admin.database(),'users/enrolling/playbackSnapshots/session-one'),enrollingWorkout);
    await set(dbRef(admin.database(),'users/enrolling/devices/tv-one'),{id:'tv-one',mode:'display',paired:true,online:true,lastSeenAtMs:Date.now()});
  });
  await no(set(dbRef(enrolling.database(),'users/enrolling/activeSession'),enrollingState));
  await no(set(dbRef(enrolling.database(),'users/enrolling/playbackSnapshots/new-snapshot'),enrollingWorkout));
  await no(set(dbRef(enrolling.database(),'users/enrolling/displayPreparation/request'),{schemaVersion:1,sessionId:'prepare-enrolling-01',revision:1,manifestHash:'a'.repeat(64),workoutId:'w',expiresAtMs:Date.now()+60000,requiredProtocol:1,targets:{'tv-one':true},images:[],sounds:[],imageCount:0}));
  await no(set(dbRef(enrolling.database(),'users/enrolling/operations/brand'),{logoUrl:'https://external.invalid/unmetered.png'}));
  await no(update(dbRef(enrolling.database(),'users/enrolling'),{'usageGate/mode':'legacy',activeSession:enrollingState}));
  await no(set(dbRef(enrolling.database(),'users/enrolling'),{usageGate:{mode:'legacy'},activeSession:enrollingState}));
  await yes(update(dbRef(enrolling.database(),'users/enrolling/devices/tv-one'),{online:false,lastSeenAtMs:Date.now()}));
  const database = contexts.enrolled.database();
  await no(set(dbRef(database,'users/enrolled/activeSession'),{...state,id:'replacement'}));
  await no(set(dbRef(database,'users/enrolled/activeSession'),null));
  for (const change of [{targetDeviceIds:[]},{manifestHash:'b'.repeat(64)},{epoch:2},{admissionId:'forged'},
    {snapshotId:'replacement'},{workoutId:'replacement'},{workoutSnapshot:workout},{unexpectedBinding:'forged'}]) {
    await no(set(dbRef(database,'users/enrolled/activeSession'),{...state,...change,revision:2}));
  }
  await no(set(dbRef(database,'users/enrolled/playbackSnapshots/forged'),workout));
  await no(set(dbRef(database,'users/enrolled/displayPreparation/request'),{schemaVersion:1}));
  await no(update(dbRef(database,'users/enrolled'),{'usageGate/mode':'legacy','activeSession':{...state,id:'replacement'}}));
  // Expired entitlement does not cut off the same immutable active binding.
  await yes(set(dbRef(database,'users/enrolled/activeSession'),{...state,status:'paused',revision:2}));
  await yes(set(dbRef(database,'users/enrolled/activeSession'),{...state,status:'playing',revision:3}));
  assert.equal((await yes(get(dbRef(tv.database(),'users/enrolled/activeSession')))).val().id,state.id);
  // Anonymous pairing creation remains independent of image quota enrollment.
  await yes(set(dbRef(tv.database(),'pairingCodes/654321'),{code:'654321',deviceId:'new-tv',displayUid:'tv',
    expiresAtMs:Date.now()+60000,claimed:false}));
  await env.withSecurityRulesDisabled(admin=>set(dbRef(admin.database(),'displayConnectionRevocations/tv/123456'),true));
  await no(get(dbRef(tv.database(),'users/enrolled/activeSession')));
  console.log(`PASS image usage rules: ${assertions} actual emulator assertions; legacy/observe image access, enrolled private bytes, bounded local pointers, enrolling new-start/snapshot/preparation/brand/ancestor denial, heartbeat compatibility, server-only ledgers/fence, protected pause/resume, anonymous pairing and revocation`);
} finally { await env.cleanup(); }
