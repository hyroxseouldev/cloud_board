import test from 'node:test';
import assert from 'node:assert/strict';
import {playSnapshot, purchaseKey} from '../src/google-play-policy.js';
import {purchasesAllowed, resolveGrants} from '../src/billing-policy.js';

const token = '12345678-1234-1234-1234-123456789abc';
const productId = 'com.sunmkim.cloudboard.plus.monthly';
const now = Date.parse('2026-09-28T00:00:00Z'), end = now + 3600000;
const purchase = (changes = {}) => ({subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
  acknowledgementState: 'ACKNOWLEDGEMENT_STATE_PENDING',
  externalAccountIdentifiers: {obfuscatedExternalAccountId: token},
  lineItems: [{productId, latestSuccessfulOrderId: 'GPA.example', expiryTime: new Date(end).toISOString(),
    autoRenewingPlan: {autoRenewEnabled: true}, offerDetails: {basePlanId: 'monthly'}}], ...changes});

test('Play grants active, canceled paid period and grace; revokes held, paused, expired and pending', () => {
  for (const state of ['ACTIVE', 'CANCELED', 'IN_GRACE_PERIOD']) {
    const {grant} = playSnapshot(purchase({subscriptionState: `SUBSCRIPTION_STATE_${state}`}), now);
    assert.equal(grant.validUntilMs, end);
    assert.equal(grant.source, 'google_play');
    if (state === 'CANCELED') assert.equal(grant.autoRenew, false);
  }
  for (const state of ['ON_HOLD', 'PAUSED', 'EXPIRED', 'PENDING', 'PENDING_PURCHASE_CANCELED']) {
    const result = playSnapshot(purchase({subscriptionState: `SUBSCRIPTION_STATE_${state}`}), now);
    assert.equal(result.grant.validUntilMs, 0);
    assert.equal(result.needsAcknowledgement, false);
  }
  assert.equal(playSnapshot(purchase(), end).grant.validUntilMs, 0);
});
test('deferred unowned item never upgrades access and canceled pending purchase needs no expiry', () => {
  const current = purchase().lineItems[0];
  const future = {...current, productId: 'com.sunmkim.cloudboard.premium.monthly', latestSuccessfulOrderId: undefined};
  const result = playSnapshot(purchase({lineItems: [future, current]}), now);
  assert.equal(result.grant.plan, 'plus');
  assert.equal(result.grant.validUntilMs, end);
  for (const state of ['PENDING', 'PENDING_PURCHASE_CANCELED']) {
    const result = playSnapshot(purchase({subscriptionState: `SUBSCRIPTION_STATE_${state}`,
      lineItems: [{...future, expiryTime: undefined}]}), now);
    assert.equal(result.grant.validUntilMs, 0);
    assert.equal(result.grant.autoRenew, false);
    assert.equal(result.needsAcknowledgement, false);
  }
});
test('Play only accepts configured monthly subscriptions and a server-minted account identity', () => {
  for (const value of [purchase({externalAccountIdentifiers: {}}), purchase({subscriptionState: 'future'}),
    purchase({acknowledgementState: 'invalid'}), purchase({lineItems: []}),
    purchase({lineItems: [{...purchase().lineItems[0], productId: 'unknown'}]}),
    purchase({lineItems: [{...purchase().lineItems[0], offerDetails: {basePlanId: 'annual'}}]}),
    purchase({lineItems: [{...purchase().lineItems[0], expiryTime: 'invalid'}]}),
    purchase({lineItems: [{...purchase().lineItems[0], autoRenewingPlan: null, prepaidPlan: {}}]})]) {
    assert.throws(() => playSnapshot(value, now));
  }
});
test('testPurchase is determined by Google, never a client platform flag', () => {
  assert.equal(playSnapshot(purchase(), now).grant.environment, 'Production');
  assert.equal(playSnapshot(purchase({testPurchase: {}}), now).grant.environment, 'Sandbox');
  assert.equal(playSnapshot(purchase({acknowledgementState: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED'}), now).needsAcknowledgement, false);
});
test('out-of-app resubscribe resolves expired identity; stored identity survives acknowledgment', () => {
  const result = playSnapshot(purchase({externalAccountIdentifiers: null,
    outOfAppPurchaseContext: {expiredExternalAccountIdentifiers: {obfuscatedExternalAccountId: token}, expiredPurchaseToken: 'old'}}), now);
  assert.equal(result.accountToken, token); assert.equal(result.linkedToken, 'old'); assert.equal(result.outOfApp, true);
  assert.equal(playSnapshot(purchase({externalAccountIdentifiers: null}), now, token).accountToken, token);
  assert.notEqual(playSnapshot(purchase(), now, 'another').accountToken, 'another');
});
test('purchase tokens use opaque bounded hashed keys and reject missing/huge values', () => {
  assert.match(purchaseKey('long/credential:with-special.characters'), /^[0-9a-f]{64}$/);
  assert.notEqual(purchaseKey('one'), purchaseKey('two'));
  for (const token of ['', null, {}, 'a b', 'x'.repeat(4097)]) assert.throws(() => purchaseKey(token));
});
test('Google and Apple enablement are independent and both fail closed', () => {
  const apple = {legalReady: true, productsReady: true, purchasesEnabled: true, sandboxPurchasesEnabled: true};
  assert.equal(purchasesAllowed(apple, true, 'google_play'), false);
  const play = {legalReady: true, googlePlayProductsReady: true, googlePlaySandboxPurchasesEnabled: true};
  assert.equal(purchasesAllowed(play, false, 'google_play'), false);
  assert.equal(purchasesAllowed(play, true, 'google_play'), true);
  assert.equal(purchasesAllowed(play, true, 'app_store'), false);
  assert.equal(purchasesAllowed({...play, googlePlayPurchasesEnabled: true}, false, 'google_play'), true);
  assert.equal(purchasesAllowed({...play, legalReady: false}, true, 'google_play'), false);
});
test('cross-store and trial resolution uses each plan own expiry and standard limits', () => {
  const plus = playSnapshot(purchase(), now).grant;
  const premium = {...plus, source: 'app_store', plan: 'premium', validUntilMs: now + 1000};
  assert.equal(resolveGrants([plus, premium], now).validUntilMs, now + 1000);
  const fallback = resolveGrants([plus, premium], now + 1000);
  assert.equal(fallback.plan, 'plus'); assert.equal(fallback.maxActiveDisplays, 1);
  assert.equal(fallback.maxFavorites, 3);
  assert.equal(resolveGrants([plus], end).canStartClass, false);
});
