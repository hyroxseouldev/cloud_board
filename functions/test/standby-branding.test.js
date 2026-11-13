import test from 'node:test';
import assert from 'node:assert/strict';
import {applyBrandEntitlement, defaultStandbyBrand, validateBrandConfig, projectStandbyBranding, saveBrandConfig} from '../src/standby-branding.js';
import {planAccess} from '../src/plan-policy.js';
import {historicalPlanAccess} from '../src/legacy-plan-adapter.js';
const now = 10000;
const entitlement = plan => ({...(plan === 'plus' ? historicalPlanAccess({plan}) : planAccess(plan)), plan, status: 'active', validUntilMs: now+10000, revision: 3});
const custom = {...defaultStandbyBrand, storeName: 'My center', standbyMessage: 'Coach note', logoUrl: 'https://example.org/logo.png', promotionImageUrls: ['https://example.org/background.png'], showCloudBoardLogo: false};
function fake(e, initial = {brand: custom}, account = null, gate = null) {
  let user = {operations:structuredClone(initial), ...(gate ? {usageGate:gate} : {})};
  const values = {'subscriptionEntitlements/owner':e, 'imageUsageAccounts/owner':account};
  const snap = data => ({exists:data != null,data:() => data});
  const db = {doc:path => ({path,get:async () => snap(values[path])}),getAll:async (...refs) => refs.map(r => snap(values[r.path]))};
  let hook;
  const realtime = {ref:path => ({get:async () => ({exists:() => user !== null,val:() => structuredClone(user)}),
    transaction:async update => {
      if (hook) { const fn=hook; hook=null; fn(user); }
      const next=update(user); if (next !== undefined) user=next;
      return {committed:next !== undefined,snapshot:{val:() => structuredClone(user)}};
    }, remove:async () => { if (path.endsWith('/operations')) delete user.operations; else user=null; }})};
  return {db,realtime,values,read:() => user?.operations ?? null,readUser:() => structuredClone(user),beforeTransaction:fn => {hook=fn;}};
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

function managedFixture({mode='enrolled',gateMode=mode,policyVersion='plan-entitlements-v2',metadataPatch={},assetPatch={}}={}) {
  const projectId='demo-brand-unit',generation='7',sha256='a'.repeat(64),assetId='brand_asset';
  const source=`https://asia-northeast3-${projectId}.cloudfunctions.net/cloudboardMedia?assetId=${assetId}&v=${generation}`;
  const value={...custom,logoUrl:source,promotionImageUrls:[source]};
  const f=fake({...entitlement('premium'),policyVersion},{brand:custom},{mode},{mode:gateMode});
  const path=`users/owner/managed-images/brand/${assetId}/${sha256}`;
  f.values[`imageUsageAccounts/owner/assets/${assetId}`]={assetId,source,generation,sizeBytes:64,contentType:'image/png',
    sha256,bucket:`${projectId}.appspot.com`,path,ownerId:'owner',tokenFree:true,...assetPatch};
  let reads=0;
  const bucket={name:`${projectId}.appspot.com`,file:(requested,{generation:pinned})=>{
    assert.equal(requested,path);assert.equal(pinned,generation);reads++;
    return {getMetadata:async()=>[{generation,size:'64',contentType:'image/png',metadata:{sha256},...metadataPatch}],
      download:async()=>{throw new Error('brand validation must not download bodies');}};
  }};
  return {...f,value,source,context:{db:f.db,bucket,projectId,mediaBaseUrl:source.split('?')[0]},metadataReads:()=>reads};
}

test('enrolled and RTDB-first enrolling states reject external/token sources before any brand mutation',async()=>{
  const token='https://firebasestorage.googleapis.com/v0/b/old/o/users%2Fowner%2Fbrand%2Fold.png?alt=media&token=old';
  for(const mode of ['enrolled','enrolling']) for(const policyVersion of ['plan-entitlements-v1','plan-entitlements-v2']) {
    const f=managedFixture({mode:mode==='enrolling'?'legacy':mode,gateMode:mode,policyVersion});
    for(const bad of ['https://external.example/image.png',token,`${f.source}&token=extra`]) {
      const before=f.readUser();
      await assert.rejects(saveBrandConfig(f.db,f.realtime,{auth:{uid:'owner'},data:{brand:{...f.value,logoUrl:bad}}},now,{usageContext:f.context}));
      assert.deepEqual(f.readUser(),before);
    }
    assert.equal(f.metadataReads(),0);
  }
});
test('wrong owner, token-bearing generation, metadata mismatch and missing context fail before persisting',async()=>{
  for(const patch of [{assetPatch:{ownerId:'foreign'}},{assetPatch:{bucket:'foreign-bucket'}},
    {metadataPatch:{metadata:{sha256:'a'.repeat(64),firebaseStorageDownloadTokens:'forbidden'}}},
    {metadataPatch:{generation:'8'}},{metadataPatch:{contentEncoding:'gzip'}},{metadataPatch:{metadata:{sha256:'b'.repeat(64)}}}]) {
    const f=managedFixture(patch),before=f.readUser();
    await assert.rejects(saveBrandConfig(f.db,f.realtime,{auth:{uid:'owner'},data:{brand:f.value}},now,{usageContext:f.context}));
    assert.deepEqual(f.readUser(),before);
  }
  const f=managedFixture(),before=f.readUser();
  await assert.rejects(saveBrandConfig(f.db,f.realtime,{auth:{uid:'owner'},data:{brand:f.value}},now),{code:'unavailable'});
  assert.deepEqual(f.readUser(),before);
});
test('verified managed sources save and project on v1/v2 protected accounts without rewriting entitlements',async()=>{
  for(const policyVersion of ['plan-entitlements-v1','plan-entitlements-v2']) {
    const f=managedFixture({policyVersion}),beforeEntitlement=structuredClone(f.values['subscriptionEntitlements/owner']);
    await saveBrandConfig(f.db,f.realtime,{auth:{uid:'owner'},data:{brand:f.value}},now,{usageContext:f.context});
    assert.deepEqual(f.read().brandConfig,f.value);assert.deepEqual(f.read().brand,f.value);
    assert.deepEqual(f.values['subscriptionEntitlements/owner'],beforeEntitlement);
    assert.ok(f.metadataReads()>=2);
  }
});
test('projection rejects invalid legacy config and concurrent unverified source changes, retaining applied brand',async()=>{
  const invalid=managedFixture();invalid.values['imageUsageAccounts/owner'].mode='enrolled';
  const before=invalid.readUser();
  await assert.rejects(projectStandbyBranding(invalid.db,invalid.realtime,'owner',now,{usageContext:invalid.context}));
  assert.deepEqual(invalid.readUser(),before);
  const f=managedFixture();
  await saveBrandConfig(f.db,f.realtime,{auth:{uid:'owner'},data:{brand:f.value}},now,{usageContext:f.context});
  const applied=structuredClone(f.read().brand);
  f.beforeTransaction(user=>{user.operations.brandConfig.logoUrl='https://external.example/raced.png';});
  await assert.rejects(projectStandbyBranding(f.db,f.realtime,'owner',now,{usageContext:f.context}));
  assert.deepEqual(f.read().brand,applied);
  const sparse=managedFixture();
  await saveBrandConfig(sparse.db,sparse.realtime,{auth:{uid:'owner'},data:{brand:sparse.value}},now,{usageContext:sparse.context});
  const sparseApplied=structuredClone(sparse.read().brand);
  sparse.beforeTransaction(user=>{user.operations.brandConfig={...sparse.value,promotionImageUrls:{'2':'https://external.example/sparse.png'}};});
  await assert.rejects(projectStandbyBranding(sparse.db,sparse.realtime,'owner',now,{usageContext:sparse.context}));
  assert.deepEqual(sparse.read().brand,sparseApplied);
});
test('legacy-to-enrolling race closes v1 direct save branch while observe/legacy source behavior stays intact',async()=>{
  const raced=managedFixture({mode:'legacy',gateMode:'legacy',policyVersion:'plan-entitlements-v1'}),before=raced.read();
  raced.beforeTransaction(user=>{user.usageGate.mode='enrolling';});
  await assert.rejects(saveBrandConfig(raced.db,raced.realtime,{auth:{uid:'owner'},data:{brand:custom}},now,{usageContext:raced.context}));
  assert.deepEqual(raced.read(),before);assert.equal(raced.metadataReads(),0);
  for(const mode of ['legacy','observe']) {
    const f=managedFixture({mode,gateMode:mode});
    await saveBrandConfig(f.db,f.realtime,{auth:{uid:'owner'},data:{brand:custom}},now,{usageContext:f.context});
    assert.deepEqual(f.read().brand,custom);assert.equal(f.metadataReads(),0);
  }
});
test('explicit demo HTTP gateway accepted only with trusted local context and Premium error has no Plus wording',async()=>{
  const local={projectId:'demo-brand-unit',emulator:true,mediaBaseUrl:'http://127.0.0.1:5008/demo-brand-unit/asia-northeast3/cloudboardMedia'};
  const value={...custom,logoUrl:`${local.mediaBaseUrl}?assetId=asset&v=1`,promotionImageUrls:[]};
  assert.equal(validateBrandConfig(value,{usageContext:local}).logoUrl,value.logoUrl);
  assert.throws(()=>validateBrandConfig(value),{code:'invalid-argument'});
  const f=fake(entitlement('free'));
  await assert.rejects(saveBrandConfig(f.db,f.realtime,{auth:{uid:'owner'},data:{brand:custom}},now),
    error=>error.code==='permission-denied' && error.message.includes('Premium') && !error.message.includes('Plus'));
});
