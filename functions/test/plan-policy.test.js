import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {planAccess, planPolicyVersion, projectPlanPolicy, requirePlanEntitlement, assertPlanCapacity} from '../src/plan-policy.js';
import {resolveGrants, freeGrant} from '../src/billing-policy.js';

const active = (plan, extra = {}) => ({...planAccess(plan), plan, status:'active', validUntilMs:2000, ...extra});
test('single versioned plan matrix retains installed-client aliases', () => {
  const fixture = JSON.parse(fs.readFileSync(new URL('./fixtures/plan-entitlements-v2.json',import.meta.url),'utf8'));
  assert.equal(fixture.policyVersion,planPolicyVersion);
  for (const [plan, displays, workouts, slides, ai, timer] of [
    ['free',1,7,3,0,0],['plus',3,null,30,10,0],['premium',null,null,null,30,100],
  ]) {
    const value = planAccess(plan);
    assert.deepEqual(value,fixture.plans[plan]);
    assert.equal(value.policyVersion, planPolicyVersion);
    assert.deepEqual([value.maxActiveDisplays,value.maxWorkouts,value.maxSavedSlides,value.aiSlidesMonthlyLimit,value.aiTimerMonthlyLimit],
      [displays,workouts,slides,ai,timer]);
    assert.equal(value.maxFavorites, slides);
    assert.equal(value.favoritesUnlimited, slides === null);
    assert.equal(value.canUseCenterLogo, plan !== 'free');
    assert.equal(value.canHideCloudBoardLogo, plan !== 'free');
  }
  assert.throws(()=>planAccess('unknown'));
});
test('unavailable, expired and unknown grants never become normal Free access', () => {
  for (const value of [null,{},active('free',{validUntilMs:1000}),active('plus',{plan:'future'}),
    ...['revoked','refunded','paused','expired','pending_connection','unknown',undefined].map(status=>active('premium',{status}))]) {
    assert.throws(()=>requirePlanEntitlement(value,1000), {code:'failed-precondition'});
  }
  for (const status of ['active','trialing','grace_period','canceling','past_due']) {
    assert.equal(requirePlanEntitlement(active('premium',{status}),1000).aiTimerMonthlyLimit,100);
  }
});
test('function deployment alone keeps v1 behavior until explicit policy activation', () => {
  const next = active('free');
  const old = projectPlanPolicy(next,null,{});
  assert.equal(old.maxWorkouts,null);
  assert.equal(old.policyVersion,'plan-entitlements-v1');
  assert.equal(projectPlanPolicy(next,null,{enabled:true,version:planPolicyVersion}).maxWorkouts,7);
  assert.equal(projectPlanPolicy(next,next,{enabled:false}).maxWorkouts,7);
  assert.equal(projectPlanPolicy(next,{policyVersion:'plan-entitlements-v1',webGrant:next},{enabled:false}).maxWorkouts,7,
    'a confirmed web v2 grant survives enrollment being paused before native projection');
  const plus = projectPlanPolicy(active('plus'),null,{});
  assert.equal(plus.maxFavorites,3);
  assert.equal(plus.aiSlidesMonthlyLimit,0);
  assert.equal(requirePlanEntitlement(plus,1000).aiSlidesMonthlyLimit,0);
  const expired = projectPlanPolicy(resolveGrants([],1000),null,{});
  assert.equal(expired.canStartClass,false);
  assert.equal(expired.validUntilMs,0);
});
test('Free boundaries and Plus 30 use the same structured error contract', () => {
  assert.doesNotThrow(()=>assertPlanCapacity(active('free'),'workouts',6,1,1000));
  assert.throws(()=>assertPlanCapacity(active('free'),'workouts',7,1,1000), e =>
    e.code === 'resource-exhausted' && e.details.resource === 'workouts' && e.details.used === 7 && e.details.limit === 7);
  assert.doesNotThrow(()=>assertPlanCapacity(active('plus'),'savedSlides',29,1,1000));
  assert.throws(()=>assertPlanCapacity(active('plus'),'savedSlides',30,1,1000), {code:'resource-exhausted'});
  assert.doesNotThrow(()=>assertPlanCapacity(active('premium'),'savedSlides',100000,1,1000));
});
test('grant precedence and each own expiry survive upgrade, trial, downgrade and refund', () => {
  const grants = [freeGrant({enabled:true}),{source:'app_store',plan:'plus',validUntilMs:5000},
    {source:'app_trial',plan:'premium',status:'trialing',validUntilMs:2000}];
  assert.equal(resolveGrants(grants,1000).maxSavedSlides,null);
  assert.equal(resolveGrants(grants,1000).validUntilMs,2000);
  assert.equal(resolveGrants(grants,2000).maxSavedSlides,30);
  assert.equal(resolveGrants(grants,5000).maxWorkouts,7);
  assert.equal(resolveGrants([grants[0],{source:'app_store',plan:'premium',status:'revoked',validUntilMs:0}],1000).plan,'free');
  const legacy = resolveGrants([{plan:'legacy',source:'live',validUntilMs:3000,
    maxFavorites:null,favoritesUnlimited:true,maxActiveDisplays:7}],1000);
  assert.equal(legacy.maxSavedSlides,null);
  assert.equal(legacy.maxActiveDisplays,7);
  assert.equal(legacy.aiSlidesMonthlyLimit,0);
});
