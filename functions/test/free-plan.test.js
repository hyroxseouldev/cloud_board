import test from 'node:test';
import assert from 'node:assert/strict';
import {freeGrant, freeValidUntilMs, hasPaidOrTrialHistory, planAccess, resolveGrants} from '../src/billing-policy.js';

test('only explicit server enrollment creates Free access; missing access remains denied', () => {
  assert.equal(freeGrant(null), null);
  assert.equal(freeGrant({enabled: false}), null);
  assert.equal(resolveGrants([], 1000).canStartClass, false);
  const free = resolveGrants([freeGrant({enabled: true})], 1000);
  assert.equal(free.plan, 'free');
  assert.equal(free.status, 'active');
  assert.equal(free.canStartClass, true);
  assert.equal(free.maxActiveDisplays, 1);
  assert.equal(free.validUntilMs, freeValidUntilMs);
});

test('Plus expands to three without changing product identity or Premium', () => {
  assert.equal(planAccess('plus').maxActiveDisplays, 3);
  assert.equal(planAccess('plus').maxFavorites, 30);
  assert.equal(planAccess('premium').displaysUnlimited, true);
});

test('Free never outranks trial, paid or legacy; expiry falls back without extending paid time', () => {
  const grants = [freeGrant({enabled: true}),
    {source: 'app_trial', plan: 'premium', status: 'trialing', validUntilMs: 2000},
    {source: 'google_play', plan: 'plus', validUntilMs: 3000}];
  assert.equal(resolveGrants(grants, 1000).validUntilMs, 2000);
  assert.equal(resolveGrants(grants, 2000).plan, 'plus');
  assert.equal(resolveGrants(grants, 2000).validUntilMs, 3000);
  assert.equal(resolveGrants(grants, 3000).plan, 'free');
  assert.equal(resolveGrants([grants[0], {source: 'legacy', plan: 'legacy', validUntilMs: 4000}], 1000).plan, 'legacy');
});

test('recognized legacy Plus expands to three while unknown limits remain unchanged', () => {
  const plus = {source: 'live', managed: true, plan: 'plus', validUntilMs: 2000,
    displaysUnlimited: false, maxActiveDisplays: 1, displayLimit: 1};
  assert.equal(resolveGrants([plus], 1000).maxActiveDisplays, 3);
  assert.equal(resolveGrants([plus], 1000).displayLimit, 3);
  assert.equal(resolveGrants([{...plus, plan: 'legacy', maxActiveDisplays: 7, displayLimit: 7}], 1000).maxActiveDisplays, 7);
});

test('Free fallback retains explicit and pre-migration server billing history', () => {
  for (const grant of [{trialUsed: true}, {paidHistory: true}, {source: 'live'},
    {source: 'trial'}, {source: 'app_trial'},
    {managed: true, source: 'free', plan: 'legacy', status: 'trial_expired'}]) {
    assert.equal(hasPaidOrTrialHistory(grant), true);
  }
  for (const grant of [null, {}, freeGrant({enabled: true}),
    {managed: true, status: 'pending_connection'},
    {source: 'firebase_billing', plan: 'free', status: 'active', validUntilMs: freeValidUntilMs}]) {
    assert.equal(hasPaidOrTrialHistory(grant), false);
  }
});
