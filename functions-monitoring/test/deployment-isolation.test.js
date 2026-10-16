import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
const root=new URL('../',import.meta.url);
function load(project,emulator){return spawnSync(process.execPath,['--input-type=module','-e',"import('./src/index.js').then(m=>console.log(JSON.stringify(m.forwardClassOperation.__endpoint)))"],{cwd:root,encoding:'utf8',env:{...process.env,GCLOUD_PROJECT:project,FUNCTIONS_EMULATOR:emulator?'true':'false'}});}
test('real development project is rejected even with emulator flag',()=>{
 for(const emulator of [false,true]) assert.notEqual(load('cloud-board-development',emulator).status,0);
});
test('production trigger is exact, create-only, bounded and separate from ordinary deploy',()=>{
 const result=load('cloud-board-stationd',false);assert.equal(result.status,0,result.stderr);
 const endpoint=JSON.parse(result.stdout);
 assert.equal(endpoint.eventTrigger.eventType,'google.firebase.database.ref.v1.created');
 assert.equal(endpoint.eventTrigger.eventFilters.instance,'cloud-board-stationd-default-rtdb');
 assert.equal(endpoint.eventTrigger.eventFilterPathPatterns.ref,'users/{ownerId}/operations/events/{eventId}');
 assert.equal(endpoint.maxInstances,2);
 const normal=JSON.parse(readFileSync(new URL('../firebase.json',root),'utf8'));
 assert.ok(normal.functions.every(x=>x.codebase!=='class-monitoring'));
});
