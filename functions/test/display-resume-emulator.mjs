import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {ref,get,set,update,serverTimestamp,onDisconnect} from 'firebase/database';
import {initializeApp,deleteApp} from 'firebase-admin/app';
import {getDatabase} from 'firebase-admin/database';
import {authorizeDisplayResume,authorizeOwnerDisplayResume} from '../src/display-recovery.js';
import {emulatorAddress,requireDemo} from '../../tool/firebase/common.mjs';
const projectId=requireDemo('demo-cloudboard-resume');
const env=await initializeTestEnvironment({projectId,database:{...emulatorAddress(process.env.FIREBASE_DATABASE_EMULATOR_HOST),rules:readFileSync(new URL('../../database.rules.json',import.meta.url),'utf8')}});
const app=initializeApp({projectId,databaseURL:`https://${projectId}.firebaseio.com`},'resume-contracts');
const admin=getDatabase(app);
const seconds=Math.floor(Date.now()/1000);
const claims={auth_time:seconds,firebase:{sign_in_provider:'anonymous'}};
const tv=env.authenticatedContext('tv',claims).database();
const owner=env.authenticatedContext('owner',{auth_time:seconds,firebase:{sign_in_provider:'password'}}).database();
const foreign=env.authenticatedContext('foreign',claims).database();
const path='users/owner/devices/screen';
const records=Object.fromEntries(['owner','tv'].map(uid=>[uid,{uid,disabled:false,tokensValidAfterTime:new Date((seconds-10)*1000).toISOString()}]));
function seed(){return authorizeDisplayResume({displayResumePolicy:{authoritativeAuthMirror:true},users:{owner:{devices:{screen:{id:'screen',mode:'display',displayUid:'tv',paired:true,pairingCode:'123456',pairedAtMs:1,online:false,lastSeenAtMs:Date.now(),displayState:'black',preferences:{cover:true}},other:{id:'other',mode:'display',displayUid:'other-tv',paired:true,online:true,lastSeenAtMs:Date.now()}},activeSession:{id:'session',revision:4,status:'paused'}}},displayAccess:{tv:{ownerId:'owner',deviceId:'screen',pairingCode:'123456',pairedAtMs:1}},legacyPilotAccess:{owner:{validUntilMs:Date.now()+60000}}},'tv',records,Date.now());}
async function connect(id){return update(ref(tv,path),{presenceProtocol:2,currentConnectionId:id,online:true,lastSeenAtMs:serverTimestamp(),[`presence/${id}`]:{online:true,lastSeenAtMs:serverTimestamp(),authorizedAtMs:serverTimestamp()}});}
let checks=0;
async function allowed(p){await assertSucceeds(p);checks++;}
async function denied(p){await assertFails(p);checks++;}
try {
  console.log('seed'); await admin.ref().set(seed());
  console.log('grant read'); await allowed(get(ref(tv,'displayResumeGrants/tv')));
  // No Functions emulator exists. Every connect is authorized by real RTDB rules.
  console.log('disconnect registration'); const disconnected=onDisconnect(ref(tv,`${path}/presence/first`));
  await allowed(disconnected.set({online:false,lastSeenAtMs:serverTimestamp()}));
  console.log('first');await allowed(connect('first'));console.log('second');await allowed(connect('second'));
  await allowed(update(ref(tv,`${path}/presence/first`),{online:false,lastSeenAtMs:serverTimestamp()}));
  assert.equal((await admin.ref(`${path}/currentConnectionId`).get()).val(),'second');checks++;
  assert.equal((await admin.ref(`${path}/presence/second/online`).get()).val(),true);checks++;
  await denied(update(ref(tv,path),{currentConnectionId:'first'}));
  await allowed(update(ref(tv,`${path}/presence/second`),{readyAtMs:serverTimestamp(),lastSeenAtMs:serverTimestamp()}));
  await allowed(update(ref(tv,path),{currentSessionId:'session',acknowledgedRevision:4}));
  await allowed(update(ref(owner,path),{name:'Renamed'}));
  for(const [field,value] of Object.entries({displayUid:'foreign',paired:false,pairingCode:'654321',pairedAtMs:2,displayState:'auto',name:'TV overwrite',preferences:{cover:false},recoveryProtocol:1,connectionVerification:{connectionId:'second',verifiedAtMs:Date.now()},unknownAuthority:true,presenceProtocol:1})) await denied(update(ref(tv,path),{[field]:value}));
  await denied(update(ref(owner,path),{currentConnectionId:'forged'}));
  await denied(update(ref(foreign,path),{online:true}));
  await denied(update(ref(tv,'users/owner/devices/other'),{online:false}));
  await denied(set(ref(tv,'displayResumeGrants/tv'),seed().displayResumeGrants.tv));
  await denied(set(ref(owner,'authAccess/tv'),{disabled:false,validAfterSeconds:0}));
  await denied(set(ref(tv,'subscriptionAccess/owner'),{canStartClass:true,validUntilMs:Date.now()+60000}));
  await disconnected.cancel();
  for(const [label,mutate] of Object.entries({
    'revoked generation':r=>r.displayConnectionRevocations={tv:{'123456':{revokedAtMs:Date.now()}}},
    'unpaired':r=>r.users.owner.devices.screen.paired=false,
    'different owner':r=>r.displayAccess.tv.ownerId='foreign',
    'different UID':r=>r.users.owner.devices.screen.displayUid='foreign',
    'different registration':r=>r.displayAccess.tv.pairedAtMs=2,
    'owner deletion':r=>r.accountDeletions={owner:true},
    'TV deletion':r=>r.accountDeletions={tv:true},
    'disabled TV':r=>r.authAccess.tv.disabled=true,
    'disabled owner':r=>r.authAccess.owner.disabled=true,
    'revoked token':r=>r.authAccess.tv.validAfterSeconds=seconds+1,
    'missing audit':r=>delete r.displayResumeGrants.tv,
  })) {
    const r=seed();mutate(r);await admin.ref().set(r);await denied(connect('blocked'));
    console.log(`DENIED: ${label}`);
  }
  await admin.ref().set(seed());await allowed(connect('healthy'));
  assert.equal((await admin.ref(`${path}/displayState`).get()).val(),'black');checks++;
  assert.equal((await admin.ref('users/owner/devices/other/online').get()).val(),true);checks++;
  const legacy=seed();delete legacy.users.owner.devices.screen.displayUid;delete legacy.displayAccess;delete legacy.displayResumeGrants;
  authorizeOwnerDisplayResume(legacy,'owner','screen',records.owner,Date.now());
  await admin.ref().set(legacy);
  await allowed(update(ref(owner,path),{presenceProtocol:2,currentConnectionId:'owner-reconnect',online:true,lastSeenAtMs:serverTimestamp(),
    'presence/owner-reconnect':{online:true,lastSeenAtMs:serverTimestamp(),authorizedAtMs:serverTimestamp()}}));
  await denied(set(ref(owner,'ownerDisplayResumeGrants/owner/screen'),legacy.ownerDisplayResumeGrants.owner.screen));
  await admin.ref('displayResumePolicy/authoritativeAuthMirror').set(false);
  await denied(update(ref(owner,path),{'presence/owner-reconnect/lastSeenAtMs':serverTimestamp()}));
  console.log(`PASS ${checks} RTDB resume/security assertions; Functions absent; project=${projectId}`);
} finally {await env.cleanup();await deleteApp(app);}
