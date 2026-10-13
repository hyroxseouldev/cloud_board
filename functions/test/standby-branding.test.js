import test from 'node:test';
import assert from 'node:assert/strict';
import {applyBrandEntitlement, defaultStandbyBrand, validateBrandConfig, projectStandbyBranding, saveBrandConfig} from '../src/standby-branding.js';
import {planAccess} from '../src/plan-policy.js';
const now = 10000;
const entitlement = plan => ({...planAccess(plan), plan, status: 'active', validUntilMs: now+10000, revision: 3});
const custom = {...defaultStandbyBrand, storeName: 'My center', standbyMessage: 'Coach note', logoUrl: 'https://example.org/logo.png', promotionImageUrls: ['https://example.org/background.png'], showCloudBoardLogo: false};
function fake(e, initial = {brand: custom}) {
  let operations = structuredClone(initial);
  const snap = (data, exists = data != null) => ({exists, data: () => data});
  const db = {doc: path => ({path, get: async () => snap(path.startsWith('accountDeletions') ? null : e)}), getAll: async (...refs) => Promise.all(refs.map(r => r.get()))};
  const realtime = {ref: path => ({transaction: async update => {const next=update(operations); if(next!==undefined) operations=next;return {committed: next!==undefined};}, set: async value=>{ operations[path.split('/').at(-1)] = value; }, remove: async()=>{operations=null;}})};
  return {db,realtime, read:()=>operations};
}
test('Free projection ignores stored custom but never mutates source; Plus and Premium restore',()=>{
  const preserved=structuredClone(custom);
  assert.deepEqual(applyBrandEntitlement(custom,entitlement('free'),now),defaultStandbyBrand);
  for(const plan of ['plus','premium']) assert.deepEqual(applyBrandEntitlement(custom,entitlement(plan),now),custom);
  assert.deepEqual(custom,preserved);
});
test('missing or expired entitlement is unknown, not Free',()=>{
  for(const e of [null, {...entitlement('premium'), validUntilMs: now}]) assert.throws(()=>applyBrandEntitlement(custom,e,now),{code:'failed-precondition'});
});
test('first downgrade snapshots legacy original; repeated projection and upgrade restore',async()=>{
  const e=entitlement('free'),f=fake(e);
  assert.equal(await projectStandbyBranding(f.db,f.realtime,'owner',now),true);
  assert.deepEqual(f.read().brandConfig,custom); assert.deepEqual(f.read().brand,defaultStandbyBrand);
  await projectStandbyBranding(f.db,f.realtime,'owner',now+1);
  assert.deepEqual(f.read().brandConfig,custom);
  Object.assign(e,entitlement('plus'),{revision:4});
  await projectStandbyBranding(f.db,f.realtime,'owner',now+2);
  assert.deepEqual(f.read().brand,custom);
});
test('inactive policy, expired lookup and stale revision preserve applied payload',async()=>{
  for(const e of [{...entitlement('free'),policyVersion:'old'},{...entitlement('free'),validUntilMs:now}]){
    const f=fake(e);assert.equal(await projectStandbyBranding(f.db,f.realtime,'owner',now),false);assert.deepEqual(f.read(),{brand:custom});
  }
  const f=fake(entitlement('free'),{brand:custom,brandProjection:{revision:9}});
  assert.equal(await projectStandbyBranding(f.db,f.realtime,'owner',now),false);assert.deepEqual(f.read().brand,custom);
});
test('Free callable rejects direct custom changes, Plus saves and projects, v1 stays compatible',async()=>{
  const request={auth:{uid:'owner'},data:{brand:custom}};
  const free=fake(entitlement('free'));await assert.rejects(saveBrandConfig(free.db,free.realtime,request,now),{code:'permission-denied'});assert.deepEqual(free.read(),{brand:custom});
  const plus=fake(entitlement('plus'));await saveBrandConfig(plus.db,plus.realtime,request,now);assert.deepEqual(plus.read().brandConfig,custom);assert.deepEqual(plus.read().brand,custom);
  const old=fake({...entitlement('plus'),policyVersion:'plan-entitlements-v1'});await saveBrandConfig(old.db,old.realtime,request,now);assert.deepEqual(old.read().brand,custom);assert.equal(old.read().brandConfig,undefined);
});
test('brand inputs reject invalid URLs, fields and dimensions without removing old defaults',()=>{
  const old = {...custom}; delete old.showCloudBoardLogo;
  assert.equal(validateBrandConfig(old).showCloudBoardLogo,true);
  for (const patch of [{logoUrl:'file:///bad'}, {extra:true}, {primaryColorValue:-1}, {promotionDurationMinutes:[0]}, {showCloudBoardLogo:'false'}]) assert.throws(()=>validateBrandConfig({...custom,...patch}),{code:'invalid-argument'});
});

test('callable fails closed for missing/expired access or migrated account with v1 regression',async()=>{
  const request={auth:{uid:'owner'},data:{brand:custom}};
  for(const e of [null,{...entitlement('plus'),validUntilMs:now}]){
    const f=fake(e);await assert.rejects(saveBrandConfig(f.db,f.realtime,request,now),{code:'failed-precondition'});assert.deepEqual(f.read(),{brand:custom});
  }
  const initial={brand:defaultStandbyBrand,brandConfig:custom,brandProjection:{policyVersion:'plan-entitlements-v2'}};
  const f=fake({...entitlement('plus'),policyVersion:'plan-entitlements-v1'},initial);
  await assert.rejects(saveBrandConfig(f.db,f.realtime,request,now),{code:'failed-precondition'});assert.deepEqual(f.read(),initial);
});
