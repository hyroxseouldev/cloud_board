import {createRequire} from 'node:module';
import assert from 'node:assert/strict';
import {planAccess} from '../../functions/src/plan-policy.js';
import {authorizeDisplayResume} from '../../functions/src/display-recovery.js';
const require=createRequire(new URL('../../functions/package.json',import.meta.url));
const {initializeApp,deleteApp}=require('firebase-admin/app');
const {getAuth}=require('firebase-admin/auth');
const {getFirestore,Timestamp}=require('firebase-admin/firestore');
const {getDatabase}=require('firebase-admin/database');
for(const [name,port] of Object.entries({FIREBASE_AUTH_EMULATOR_HOST:9099,FIRESTORE_EMULATOR_HOST:8080,FIREBASE_DATABASE_EMULATOR_HOST:9000})) {
 process.env[name]??=`127.0.0.1:${port}`;assert.match(process.env[name],/^(127\.0\.0\.1|localhost):\d+$/);
}
const projectId='demo-cloudboard-studio';
const app=initializeApp({projectId,databaseURL:`https://${projectId}-default-rtdb.asia-southeast1.firebasedatabase.app`});
const auth=getAuth(app),db=getFirestore(app),database=getDatabase(app),owner='sta209-owner';
try {
 try{await auth.createUser({uid:owner,email:'sta209@example.test',password:'local-sta209-only',emailVerified:true});}catch(e){if(e.code!=='auth/uid-already-exists'&&e.code!=='auth/email-already-exists')throw e;}
 const now=Timestamp.now(),grant={...planAccess('premium'),plan:'premium',status:'active',managed:true,canStartClass:true,validUntilMs:Date.now()+86400000,revision:1,source:'billing'};
 await db.doc(`subscriptionEntitlements/${owner}`).set(grant);
 await db.doc(`users/${owner}/onboarding/progress`).set({storeId:'sta209-center',completed:true,phoneVerified:true,step:3});
 await db.doc('centers/sta209-center').set({ownerUid:owner,profile:{centerName:'STA209 로컬 센터'},revision:1});
 await db.doc(`users/${owner}`).set({uid:owner,displayName:'STA209 로컬 테스트',email:'sta209@example.test'});
 const modules=[1,2].map(i=>({id:`slide-${i}`,name:`STA209 동작 ${i}`,text:'저장된 수업 · Functions 장애 테스트',imageUrl:'',workSeconds:120,sets:2,restSeconds:15,timingVersion:2,showTimer:true,showSets:true,beep:true,coverImage:false}));
 await db.doc(`users/${owner}/workouts/sta209-class`).set({id:'sta209-class',ownerId:owner,author:{id:owner,displayName:'STA209 테스트',photoUrl:null},name:'STA209 장애 수업',folder:'',brandL:'STA209',brandR:'LOCAL ONLY',modules,createdAt:now,updatedAt:now});
 await database.ref(`subscriptionAccess/${owner}`).set(grant);
 await database.ref('displayResumePolicy').set({authoritativeAuthMirror:true});
 // Optional registered identities come from each isolated browser's prepare pass.
 const pairs=process.argv.slice(2).map(arg=>arg.split('='));
 for(const [deviceId,uid] of pairs) {
  assert(/^tv[123]$/.test(deviceId)&&/^[A-Za-z0-9_-]+$/.test(uid));
  const code=`20900${deviceId.slice(-1)}`,pairedAtMs=Date.now();
  await database.ref().update({[`displayAccess/${uid}`]:{ownerId:owner,deviceId,pairingCode:code,pairedAtMs},
   [`users/${owner}/devices/${deviceId}`]:{id:deviceId,mode:'display',displayUid:uid,paired:true,pairingCode:code,pairedAtMs,name:deviceId,zoneId:'main',zoneName:'메인',online:false,lastSeenAtMs:pairedAtMs,displayState:'auto',recoveryProtocol:1}});
  const records=Object.fromEntries(await Promise.all([owner,uid].map(async id=>[id,await auth.getUser(id)])));
  let failure;const result=await database.ref().transaction(root=>{if(!root)return null;try{return authorizeDisplayResume(root,uid,records,Date.now());}catch(e){failure=e;return;}});if(failure)throw failure;assert(result.committed);
 }
 console.log(`Seeded ${projectId}; owner + saved class + ${pairs.length} registered TVs; no Functions or external writes`);
} finally{await deleteApp(app);}
