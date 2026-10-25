import {createRequire} from 'node:module';
import {mkdirSync,writeFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const require=createRequire(new URL('../../functions/package.json',import.meta.url));
const {initializeApp,deleteApp}=require('firebase-admin/app');const {getDatabase}=require('firebase-admin/database');
process.env.FIREBASE_DATABASE_EMULATOR_HOST??='127.0.0.1:9000';assert.match(process.env.FIREBASE_DATABASE_EMULATOR_HOST,/^(localhost|127\.0\.0\.1):\d+$/);
const app=initializeApp({projectId:'demo-cloudboard-studio',databaseURL:'https://demo-cloudboard-studio-default-rtdb.asia-southeast1.firebasedatabase.app'});
try {
 const user=(await getDatabase(app).ref('users/sta209-owner').get()).val();const session=user.activeSession;
 const result={observedAt:new Date().toISOString(),session:session?Object.fromEntries(['id','revision','status','stepIndex','remainingMs','anchorServerMs'].map(k=>[k,session[k]])):null,
  devices:Object.fromEntries(['tv1','tv2','tv3'].map(id=>{const d=user.devices[id],p=d.presence?.[d.currentConnectionId];return[id,{connectionId:d.currentConnectionId,presenceProtocol:d.presenceProtocol,online:p?.online,authorizedAtMs:p?.authorizedAtMs,readyAtMs:p?.readyAtMs,lastSeenAtMs:p?.lastSeenAtMs,currentSessionId:d.currentSessionId,acknowledgedRevision:d.acknowledgedRevision,displayState:d.displayState}];}))};
 const label=process.argv[2]||'snapshot';assert(/^[a-z0-9-]+$/.test(label));
 mkdirSync('output/sta209/e2e',{recursive:true});writeFileSync(`output/sta209/e2e/${label}.json`,JSON.stringify(result,null,2)+'\n');
 console.log(JSON.stringify(result,null,2));
}finally{await deleteApp(app);}
