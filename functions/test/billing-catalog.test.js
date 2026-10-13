import {test} from 'node:test';
import assert from 'node:assert/strict';
import {planSalesReady, billingCatalogVersion} from '../src/billing-catalog.js';
const proof = () => ({version: billingCatalogVersion, policyVersion: 'plan-entitlements-v2',
  sandboxVerified: true, taxInclusive: true, currency: 'KRW', period: 'P1M', verifiedAtMs: 100,
  evidenceUrl: 'https://example.com/private-release-evidence', products: {
    plus: {id: 'com.sunmkim.cloudboard.plus.monthly', amount: 49000, active: true},
    premium: {id: 'com.sunmkim.cloudboard.premium.monthly', amount: 99000, active: true}}});
test('new plan sales require verified store prices, period, tax and sandbox proof for that store', () => {
  assert.equal(planSalesReady(undefined), false);
  const config = {planCatalog: {app_store: proof()}};
  assert.equal(planSalesReady(config, 'app_store', 101), true);
  assert.equal(planSalesReady(config, 'google_play', 101), false);
  assert.equal(planSalesReady(config, 'app_store', 99), false);
  for (const change of [{period: 'P1Y'}, {currency: 'USD'}, {taxInclusive: false},
    {sandboxVerified: false}, {evidenceUrl: ''}, {policyVersion: 'old'}, {verifiedAtMs: 0}]) {
    assert.equal(planSalesReady({planCatalog: {app_store: {...proof(), ...change}}}), false);
  }
  for (const change of [{amount: 39000}, {active: false}, {id: 'new-unverified-product'}]) {
    const value = proof(); Object.assign(value.products.plus, change);
    assert.equal(planSalesReady({planCatalog: {app_store: value}}), false);
  }
});
test('sandbox attestation can be completed only through explicit tester mode with verified catalog', () => {
  const value = {...proof(), sandboxVerified: false, sandboxSalesEnabled: true};
  const config = {planCatalog: {google_play: value}};
  assert.equal(planSalesReady(config, 'google_play', 101), false);
  assert.equal(planSalesReady(config, 'google_play', 101, true), true);
  value.products.plus.amount = 1;
  assert.equal(planSalesReady(config, 'google_play', 101, true), false);
});
