import assert from 'node:assert/strict';
import { test } from 'node:test';
import { readFile } from 'node:fs/promises';
import { capabilitiesForPlan, applyPlanPolicy } from '../src/services/plan-entitlements.js';
import { CATALOG_VERSION, monthlyPrices, webSalesReady } from '../src/services/plan-catalog.js';
import { signCheckoutQuote, readCheckoutQuote } from '../src/services/core.js';

test('web capabilities exactly match the app server versioned fixture', async () => {
  const fixture = JSON.parse(
    await readFile(new URL('./fixtures/plan-entitlements-v2.json', import.meta.url), 'utf8'),
  );
  for (const plan of ['free', 'plus', 'premium'] as const)
    assert.deepEqual(capabilitiesForPlan(plan), fixture.plans[plan]);
  const grant = {
    plan: 'plus',
    canPrepare: true,
    canPairDisplay: false,
    canStartClass: false,
    validUntilMs: 0,
  };
  assert.equal(applyPlanPolicy(grant, null, null).aiSlidesMonthlyLimit, 0);
  const activated = applyPlanPolicy(grant, null, { enabled: true, version: fixture.policyVersion });
  assert.equal(activated.maxSavedSlides, 30);
  assert.equal(activated.aiSlidesMonthlyLimit, 10);
  assert.equal(activated.canStartClass, false);
  assert.equal(activated.validUntilMs, 0);
  for (const state of ['expired', 'pending_connection', 'revoked']) {
    const denied = applyPlanPolicy(
      { ...grant, status: state, maxActiveDisplays: 0, displaysUnlimited: false, displayLimit: 0 },
      null,
      { enabled: true, version: fixture.policyVersion },
    );
    assert.equal(denied.maxActiveDisplays, 0);
    assert.equal(denied.displayLimit, 0);
    assert.equal(denied.displaysUnlimited, false);
  }
  assert.equal(applyPlanPolicy(grant, activated, { enabled: false }).aiSlidesMonthlyLimit, 10);
  assert.equal(
    applyPlanPolicy(grant, { webGrant: activated }, { enabled: false }).policyVersion,
    fixture.policyVersion,
  );
  assert.deepEqual(
    applyPlanPolicy({ ...grant, plan: 'legacy', maxFavorites: 8 }, null, {
      enabled: true,
      version: fixture.policyVersion,
    }),
    { ...grant, plan: 'legacy', maxFavorites: 8 },
  );
});

test('new catalog cannot sell before rollout, exact price and sandbox evidence agree', () => {
  const policy = { enabled: true, version: 'plan-entitlements-v2' };
  const proof = {
    version: CATALOG_VERSION,
    policyVersion: policy.version,
    sandboxVerified: true,
    taxInclusive: true,
    currency: 'KRW',
    period: 'P1M',
    verifiedAtMs: 1,
    evidenceUrl: 'https://example.invalid/sandbox-evidence',
    products: {
      plus: { id: 'plus', amount: 49000, active: true },
      premium: { id: 'premium', amount: 99000, active: true },
    },
  };
  const config = { planCatalog: { toss: proof } };
  assert.equal(webSalesReady(policy, config), true);
  assert.equal(webSalesReady(null, config), false);
  for (const patch of [
    { sandboxVerified: false },
    { taxInclusive: false },
    { currency: 'USD' },
    { period: 'P1Y' },
    { version: 'old' },
    { verifiedAtMs: Date.now() + 100000 },
    { products: { ...proof.products, plus: { ...proof.products.plus, amount: 99000 } } },
  ]) {
    assert.equal(webSalesReady(policy, { planCatalog: { toss: { ...proof, ...patch } } }), false);
  }
  const sandbox = {
    planCatalog: { toss: { ...proof, sandboxVerified: false, sandboxSalesEnabled: true } },
  };
  assert.equal(webSalesReady(policy, sandbox, Date.now(), 'test'), true);
  assert.equal(webSalesReady(policy, sandbox, Date.now(), 'live'), false);
  assert.equal(webSalesReady(policy, sandbox, Date.now(), 'disabled'), false);
  assert.equal(
    webSalesReady(
      policy,
      { planCatalog: { toss: { ...sandbox.planCatalog.toss, currency: 'USD' } } },
      Date.now(),
      'test',
    ),
    false,
  );
  const quote = signCheckoutQuote(
    'owner',
    new Date(),
    'test',
    'test-secret',
    monthlyPrices.plus,
    'plus',
  );
  assert(readCheckoutQuote(quote, 'owner', 'test', 'test-secret', 49000, 'plus') instanceof Date);
  assert.throws(() => readCheckoutQuote(quote, 'owner', 'test', 'test-secret', 49000, 'premium'));
  assert.throws(() => readCheckoutQuote(quote, 'owner', 'test', 'test-secret', 99000, 'premium'));
  assert.throws(() => readCheckoutQuote(quote, 'other', 'test', 'test-secret', 49000, 'plus'));
});
