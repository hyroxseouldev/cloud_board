import test from 'node:test';
import assert from 'node:assert/strict';
import {eraseAccount, requireDeletionIdentity} from '../src/delete-account.js';
const steps=['lock','stopAndDetach','disableAuth','deleteFiles','deleteDocuments','deleteRealtime','verifyEmpty','deleteAuth','complete'];
test('requires Google reauthentication and ignores caller-selected identity',()=>{
 const value={uid:'actual-owner',token:{auth_time:1000,firebase:{sign_in_provider:'google.com'}}};
 assert.equal(requireDeletionIdentity(value,1100),'actual-owner');
 for(const bad of [null,{...value,uid:'../other'},{...value,token:{auth_time:1000,firebase:{sign_in_provider:'anonymous'}}}, {...value,token:{...value.token,auth_time:1}}]) assert.throws(()=>requireDeletionIdentity(bad,1100));
});
test('locks first and verifies application data before removing Auth',async()=>{
 const calls=[];
 await eraseAccount('owner',Object.fromEntries(steps.map(name=>[name,async uid=>{assert.equal(uid,'owner');calls.push(name);}])));
 assert.deepEqual(calls,steps);
});
for(const failure of steps.slice(0,-1)) test(`failure at ${failure} never reports completion`,async()=>{
 const calls=[];
 await assert.rejects(eraseAccount('owner',Object.fromEntries(steps.map(name=>[name,async()=>{calls.push(name);if(name===failure)throw Error('injected');}]))));
 assert.equal(calls.at(-1),failure);
 assert.ok(!calls.includes('complete'));
 if(steps.indexOf(failure)<steps.indexOf('deleteAuth')) assert.ok(!calls.includes('deleteAuth'));
});
test('retry starts with locks again and reaches completion only after all cleanup',async()=>{
 let once=true;const calls=[];
 const services=Object.fromEntries(steps.map(name=>[name,async()=>{calls.push(name);if(name==='deleteFiles'&&once){once=false;throw Error('offline');}}]));
 await assert.rejects(eraseAccount('owner',services));
 await eraseAccount('owner',services);
 assert.deepEqual(calls.slice(-steps.length),steps);
});
