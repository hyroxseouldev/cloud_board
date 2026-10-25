import test from 'node:test';
import assert from 'node:assert/strict';
import {authorizeDisplayResume, reduceDisplayRecovery} from '../src/display-recovery.js';
import {revokeAccountSessions} from '../src/auth-access.js';
const now = 1800000000000;
const records = Object.fromEntries(['owner','tv'].map(uid => [uid, {uid, disabled: false, tokensValidAfterTime: new Date(now - 60000).toISOString()}]));
function seed() { return {displayResumePolicy:{authoritativeAuthMirror:true},users: {owner: {devices: {screen: {id:'screen', mode:'display',displayUid:'tv',paired:true,pairingCode:'123456',pairedAtMs:1,online:false,lastSeenAtMs:now,displayState:'black'}}}}, displayAccess:{tv:{ownerId:'owner',deviceId:'screen',pairingCode:'123456',pairedAtMs:1}}}; }
test('audited registration grant preserves black screen, creates no connection proof', () => {
  const root = authorizeDisplayResume(seed(),'tv',records,now);
  assert.equal(root.displayResumeGrants.tv.ownerId,'owner');
  assert.equal(root.authAccess.tv.disabled,false);
  assert.equal(root.users.owner.devices.screen.displayState,'black');
  assert.equal(root.users.owner.devices.screen.connectionVerification,undefined);
});
for (const [name, mutate] of Object.entries({
  'duplicate reverse membership':r=>r.users.other={devices:{duplicate:{paired:true,displayUid:'tv'}}},
  'duplicate forward membership':r=>r.displayAccess.imposter={...r.displayAccess.tv},
  'unpaired':r=>r.users.owner.devices.screen.paired=false,
  'missing reverse UID':r=>delete r.users.owner.devices.screen.displayUid,
  'different generation':r=>r.displayAccess.tv.pairedAtMs=2,
  'revoked code':r=>r.displayConnectionRevocations={tv:{'123456':{revokedAtMs:now}}},
  'deleted account':r=>r.accountDeletions={owner:true},
  'administrative block':r=>r.authAccess={tv:{disabled:true,validAfterSeconds:0}},
})) test(`audit refuses ${name}`,()=>{const r=seed();mutate(r);assert.throws(()=>authorizeDisplayResume(r,'tv',records,now));});
test('missing, disabled and wrong Auth identity never issue a grant',()=>{
  for (const bad of [undefined,{}, {...records,tv:{...records.tv,disabled:true}}, {...records,owner:{...records.owner,uid:'foreign'}}]) {
    const root=seed();assert.throws(()=>authorizeDisplayResume(root,'tv',bad,now));assert.equal(root.displayResumeGrants,undefined);
  }
});
test('unpair atomically removes the reusable grant and records revocation',()=>{
  const root=authorizeDisplayResume(seed(),'tv',records,now);
  const result=reduceDisplayRecovery(root,{uid:'owner',token:{firebase:{sign_in_provider:'password'}}},'unpair',
    {deviceId:'screen',operationId:'unpair',expectedPairingCode:'123456'},now).root;
  assert.equal(result.displayResumeGrants.tv,undefined);assert.ok(result.displayConnectionRevocations.tv['123456']);
});
test('revocation blocks RTDB before changing Auth and a failed Auth call stays blocked',async()=>{
  let state={disabled:false,validAfterSeconds:0};const order=[];
  const database={ref:()=>({transaction:async fn=>{const next=fn(state);if(next!==undefined)state=next;order.push('db');}})};
  const auth={revokeRefreshTokens:async()=>{assert.equal(state.disabled,true);order.push('auth');throw Error('Auth unavailable');}};
  await assert.rejects(revokeAccountSessions({database,auth,uid:'tv',now:()=>now}),/Auth unavailable/);
  assert.equal(state.disabled,true);assert.deepEqual(order,['db','auth']);
});
test('revocation preserves the cutoff and never undoes a concurrent block',async()=>{
  let state={disabled:false,validAfterSeconds:0};const database={ref:()=>({transaction:async fn=>{const v=fn(state);if(v!==undefined)state=v;}})};
  const auth={revokeRefreshTokens:async()=>{state={...state,operationId:'new-admin-operation'};},getUser:async()=>records.tv};
  await revokeAccountSessions({database,auth,uid:'tv',now:()=>now});assert.equal(state.disabled,true);
});

test('an earlier Auth lookup cannot lower a newer token cutoff',()=>{const r=seed();r.authAccess={tv:{disabled:false,validAfterSeconds:now/1000}};authorizeDisplayResume(r,'tv',records,now);assert.equal(r.authAccess.tv.validAfterSeconds,now/1000);});

test('no enrollment is issued before the authoritative Auth mirror is explicitly enabled',()=>{const r=seed();delete r.displayResumePolicy;authorizeDisplayResume(r,'tv',records,now);assert.equal(r.displayResumeGrants,undefined);assert.equal(r.authAccess,undefined);});

test('a verified Auth record with no revocation timestamp matches Admin SDK semantics',()=>{const r=seed();const fresh=structuredClone(records);delete fresh.tv.tokensValidAfterTime;authorizeDisplayResume(r,'tv',fresh,now);assert.equal(r.authAccess.tv.validAfterSeconds,0);});
