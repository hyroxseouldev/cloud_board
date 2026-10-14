import assert from 'node:assert/strict';
import { test } from 'node:test';
import { planEntitlements, modernPlan } from '../src/services/plan-entitlements.js';
import { applyDisplayState } from '../src/services/display-activation.js';
import { entitlementFor } from '../src/services/sync.js';

test('Premium must be explicit; legacy limits and missing values stay bounded', () => {
  assert.equal(planEntitlements(-1).displaysUnlimited, true);
  assert.equal(planEntitlements(-1).maxActiveDisplays, null);
  assert.equal(planEntitlements(-1).maxFavorites, null);
  assert.equal(planEntitlements(1).maxActiveDisplays, 3);
  assert.equal(planEntitlements(1).maxFavorites, 3);
  assert.equal(planEntitlements(3).plan, 'legacy');
  for (const value of [undefined, null, 0, -2, '-1']) {
    assert.equal(planEntitlements(value).displaysUnlimited, false);
    assert.equal(planEntitlements(value).maxActiveDisplays, 0);
  }
  assert.equal(modernPlan({ plan: 'premium' }), null);
});

test('subscription sync retains exact grant expiry and never upgrades legacy accounts', () => {
  const s = {
    store_id: 'test',
    status: 'trialing',
    trial_ends_at: '2999-12-31T15:00:00.000Z',
    display_limit: -1,
    revision: 3,
  };
  const access = entitlementFor(s);
  assert.equal(access.plan, 'premium');
  assert.equal(access.validUntilMs, Date.parse(s.trial_ends_at));
  assert.equal(access.canStartClass, true);
  assert.equal(entitlementFor({ ...s, display_limit: 3 }).plan, 'legacy');
  assert.equal(entitlementFor({ ...s, deletion_requested_at: new Date() }).canStartClass, false);
});

test('Free switches only explicitly selected screen without restarting or resuming class', () => {
  const current = {
    devices: {
      a: { paired: true, displayState: 'auto' },
      b: { paired: true, displayState: 'black' },
    },
    activeSession: {
      status: 'paused',
      targetDeviceIds: ['a'],
      revision: 8,
      stepIndex: 2,
      remainingMs: 1234,
      anchorServerMs: 900,
    },
  };
  const next = applyDisplayState(current, 'b', 'auto', 'free', 1000, 1, ['a']);
  assert.equal(next.devices.a.displayState, 'black');
  assert.equal(next.devices.b.displayState, 'auto');
  assert.deepEqual(next.activeSession, {
    ...current.activeSession,
    targetDeviceIds: ['b'],
    revision: 9,
  });
  assert.equal(current.devices.a.displayState, 'auto');
  assert.equal(applyDisplayState(current, 'unknown', 'auto', 'plus', 1000), undefined);
  const premium = applyDisplayState(current, 'b', 'auto', 'premium', 1000);
  assert.equal(premium.devices.a.displayState, 'auto');
  assert.equal(premium.devices.b.displayState, 'auto');
});

test('Plus permits three, rejects fourth, and preserves unselected screens on replacement', () => {
  const current = {
    devices: {
      a: { paired: true, displayState: 'auto' },
      b: { paired: true, displayState: 'auto' },
      c: { paired: true, displayState: 'black' },
      d: { paired: true, displayState: 'black' },
    },
  };
  const three = applyDisplayState(current, 'c', 'auto', 'plus', 1000);
  assert.equal(three.devices.a.displayState, 'auto');
  assert.throws(() => applyDisplayState(three, 'd', 'auto', 'plus', 1001), {
    code: 'resource-exhausted',
  });
  const replaced = applyDisplayState(three, 'd', 'auto', 'plus', 1002, 3, ['b']);
  assert.equal(replaced.devices.a.displayState, 'auto');
  assert.equal(replaced.devices.b.displayState, 'black');
  assert.equal(replaced.devices.c.displayState, 'auto');
  assert.equal(replaced.devices.d.displayState, 'auto');
  assert.throws(() => applyDisplayState(replaced, 'b', 'auto', 'plus', 1003, 3, ['missing']), {
    code: 'aborted',
  });
});

test('Free has explicit capabilities and never masquerades as legacy or Premium', () => {
  assert.equal(
    modernPlan({
      plan: 'free',
      maxActiveDisplays: 1,
      displaysUnlimited: false,
      canStartClass: true,
    }),
    'free',
  );
  assert.equal(modernPlan({ plan: 'free', maxActiveDisplays: 1, displaysUnlimited: false }), null);
  assert.equal(
    modernPlan({ plan: 'plus', maxActiveDisplays: 3, displaysUnlimited: false }),
    'plus',
  );
});
