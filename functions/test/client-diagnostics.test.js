import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {validateDiagnostic, redactDiagnostic, recordClientDiagnostic} from '../src/client-diagnostics.js';
const now=Date.parse('2026-09-30T00:00:00Z');
const event=(id='event-12345')=>({accountId:'u',eventId:id,occurredAt:new Date(now).toISOString(),severity:'error',type:'StateError',code:'revision_conflict',message:'private@example.invalid +82 10 1234 5678 token=SECRET',stack:'at https://host.invalid/main.dart.js:12:56\nat users/private/activeSession',context:{action:'playback.pause',sessionId:'s',password:'secret',expectedRevision:1,observedRevision:2},breadcrumbs:[{action:'playback.pause',email:'secret'}]});
function db() { const docs=new Map(); return {docs,doc:p=>p,runTransaction:async fn=>fn({get:async p=>({data:()=>docs.get(p),exists:docs.has(p)}),set:(p,v)=>docs.set(p,v)})}; }
test('validation redacts private strings, preserves source-map location and allowlisted context',()=>{
 const clean=validateDiagnostic(event(),now);
 assert.equal(clean.stack,'at main.dart.js:12:56\nat [database-path]');
 assert.doesNotMatch(JSON.stringify(clean),/SECRET|private@|1234 5678|password|accountId/);
 assert.equal(clean.context.expectedRevision,1); assert.deepEqual(clean.breadcrumbs,[{action:'playback.pause'}]);
 for(const bad of [null,[],{...event(),stack:'x'.repeat(17000)},{...event(),eventId:'\nforged'},{...event(),occurredAt:'2020-01-01'},{...event(),breadcrumbs:Array(16).fill({})}]) assert.throws(()=>validateDiagnostic(bad,now),{code:'invalid-argument'});
 assert.equal(redactDiagnostic('Bearer abc.xyz /Users/name/private/file.dart'), '[token] [local-path]');
});
test('authenticated, account-bound diagnostics deduplicate and throttle without publishing private UID',async()=>{
 const database=db(), entries=[];
 const record=(payload,auth={uid:'u',token:{}})=>recordClientDiagnostic({db:database,auth,payload,now,emit:(...args)=>entries.push(args)});
 await assert.rejects(record(event(),null),{code:'unauthenticated'});
 await assert.rejects(record({...event(),accountId:'other'}),{code:'permission-denied'});
 assert.equal((await record(event())).accepted,true);
 assert.equal((await record(event())).accepted,false);
 for(let i=1;i<20;i++) await record(event(`event-${String(i).padStart(5,'0')}`));
 await assert.rejects(record(event('event-over-limit')),{code:'resource-exhausted'});
 assert.equal(entries.length,20);assert.equal(entries[0][0],'client_diagnostic');
 assert.equal(entries[0][1].accountHash.length,16);assert.equal(entries[0][1].accountId,undefined);
 assert.equal(database.docs.size,1);
});
test('anonymous diagnostics require a paired display',async()=>{
 for(const paired of [false,true]) {
 const task=recordClientDiagnostic({db:db(),realtime:{ref:()=>({get:async()=>({exists:()=>paired})})},auth:{uid:'u',token:{firebase:{sign_in_provider:'anonymous'}}},payload:event(),now,emit:()=>{}});
 if(paired) assert.equal((await task).accepted,true);else await assert.rejects(task,{code:'permission-denied'});
 }
});
test('real Functions logger preserves the exact marker used by the save alert', () => {
 const script = `
   import * as logger from 'firebase-functions/logger';
   import {clientDiagnosticLogEntry} from './src/client-diagnostics.js';
   const event = ${JSON.stringify(validateDiagnostic(event(), now))};
   logger.error('client_diagnostic', event);
   logger.write(clientDiagnosticLogEntry(event));
 `;
 const result = spawnSync(process.execPath, ['--input-type=module', '-e', script], {cwd: fileURLToPath(new URL('../', import.meta.url)), encoding: 'utf8'});
 assert.equal(result.status, 0, result.stderr);
 const [legacy, current] = result.stderr.trim().split('\n').map(line => JSON.parse(line));
 assert.match(legacy.message, /^Error: client_diagnostic\n/);
 assert.equal(current.message, 'client_diagnostic'); assert.equal(current.severity, 'ERROR');
 assert.equal(current.eventId, 'event-12345'); assert.equal(current.context.action, 'playback.pause');
 assert.doesNotMatch(JSON.stringify(current), /SECRET|private@|accountId/);
});
