// One-time, explicit development provisioning. Never invoked by app startup.
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {authorizeDisplayResume,authorizeOwnerDisplayResume} from '../../functions/src/display-recovery.js';
const require=createRequire(new URL('../../functions/package.json',import.meta.url));
const {initializeApp,deleteApp}=require('firebase-admin/app');
const {getAuth}=require('firebase-admin/auth');
const {getDatabase}=require('firebase-admin/database');
const args=process.argv.slice(2);const arg=name=>args[args.indexOf(name)+1];
const projectId=args.includes('--project')?arg('--project'):'';
assert(projectId==='cloud-board-development'||/^demo-[a-z0-9-]+$/.test(projectId),'Development/demo only');
if(projectId.startsWith('demo-')) for(const name of ['FIREBASE_AUTH_EMULATOR_HOST','FIREBASE_DATABASE_EMULATOR_HOST']) assert.match(process.env[name]||'',/^(127\.0\.0\.1|localhost):\d+$/);
else for(const name of ['FIREBASE_AUTH_EMULATOR_HOST','FIREBASE_DATABASE_EMULATOR_HOST']) assert(!process.env[name],'Do not mix development and emulator endpoints');
const displayUid=args.includes('--display-uid')?arg('--display-uid'):null;
const ownerId=args.includes('--owner')?arg('--owner'):null,deviceId=args.includes('--device')?arg('--device'):null;
assert(displayUid||ownerId&&deviceId,'Provide --display-uid or --owner AND --device');
const app=initializeApp({projectId,databaseURL:`https://${projectId}-default-rtdb.asia-southeast1.firebasedatabase.app`});
const database=getDatabase(app),auth=getAuth(app);
try {
 const root=(await database.ref().get()).val()||{};
 assert.equal(root.displayResumePolicy?.authoritativeAuthMirror,true,'Enable only after the Auth revocation/disable mirror workflow is approved; this script never enables it');
 const owner=displayUid?root.displayAccess?.[displayUid]?.ownerId:ownerId;assert(owner,'Missing owner');
 const records=Object.fromEntries(await Promise.all([...new Set([owner,displayUid].filter(Boolean))].map(async uid=>[uid,await auth.getUser(uid)])));
 const authorize=value=>displayUid?authorizeDisplayResume(value,displayUid,records,Date.now()):authorizeOwnerDisplayResume(value,owner,deviceId,records[owner],Date.now());
 authorize(structuredClone(root));
 if(!args.includes('--apply')) console.log(`DRY RUN: registration and Auth audit passed in ${projectId}; no writes`);
 else {let failure;const result=await database.ref().transaction(current=>{if(current===null)return null;try{return authorize(current);}catch(e){failure=e;return;}});if(failure)throw failure;assert(result.committed);console.log(`Provisioned audited resume grant in ${projectId}`);}
} finally {await deleteApp(app);}
