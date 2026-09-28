import {createHash} from 'node:crypto';
import {products, tokenPattern} from './billing-policy.js';

export const playPackageName = 'com.sunmkim.cloudboard';
export const playBasePlanId = 'monthly';
export function purchaseKey(token) {
  if (typeof token !== 'string' || !token.length || token.length > 4096 || /\s/.test(token)) {
    throw new Error('invalid-play-token');
  }
  return createHash('sha256').update(token).digest('hex');
}

// Only call with a response fetched from the fixed Google Publisher API package.
export function playSnapshot(value, now = Date.now(), knownAccountToken = null) {
  const accountToken = value?.externalAccountIdentifiers?.obfuscatedExternalAccountId ??
    value?.outOfAppPurchaseContext?.expiredExternalAccountIdentifiers?.obfuscatedExternalAccountId ?? knownAccountToken;
  if (!tokenPattern.test(accountToken ?? '')) throw new Error('play-account-missing');
  const states = {
    SUBSCRIPTION_STATE_ACTIVE: 'active', SUBSCRIPTION_STATE_CANCELED: 'canceled',
    SUBSCRIPTION_STATE_IN_GRACE_PERIOD: 'grace_period', SUBSCRIPTION_STATE_ON_HOLD: 'billing_retry',
    SUBSCRIPTION_STATE_PAUSED: 'paused', SUBSCRIPTION_STATE_EXPIRED: 'expired',
    SUBSCRIPTION_STATE_PENDING: 'pending', SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED: 'expired',
  };
  const status = states[value.subscriptionState];
  if (!status || !['ACKNOWLEDGEMENT_STATE_PENDING', 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED'].includes(value.acknowledgementState)) {
    throw new Error('unsupported-play-state');
  }
  const items = value.lineItems ?? [];
  if (!items.length || items.some(i => !products[i.productId] || i.offerDetails?.basePlanId !== playBasePlanId ||
      !i.autoRenewingPlan || i.autoRenewingPlan.installmentDetails || i.prepaidPlan)) throw new Error('unsupported-play-product');
  const grants = items.map(item => {
    const expiry = Date.parse(item.expiryTime);
    const owned = typeof item.latestSuccessfulOrderId === 'string' && item.latestSuccessfulOrderId.length > 0;
    if (owned && !Number.isSafeInteger(expiry)) throw new Error('invalid-play-expiry');
    // The deferred replacement line has no purchased entitlement until it starts.
    const active = owned && ['active', 'canceled', 'grace_period'].includes(status) && expiry > now;
    return {source: 'google_play', plan: products[item.productId], productId: item.productId,
      validUntilMs: active ? expiry : 0, expiresAtMs: owned ? expiry : 0,
      status: active && status === 'canceled' ? 'active' : status,
      autoRenew: owned && !['expired', 'canceled'].includes(status) && item.autoRenewingPlan.autoRenewEnabled === true,
      nextProductId: products[item.deferredItemReplacement?.productId] ? item.deferredItemReplacement.productId : null,
      environment: value.testPurchase != null ? 'Sandbox' : 'Production'};
  });
  // Select active entitlement first, then its own expiry; never mix plan and dates.
  grants.sort((a, b) => Number(b.validUntilMs > now) - Number(a.validUntilMs > now) ||
    (b.validUntilMs > now ? Number(b.plan === 'premium') - Number(a.plan === 'premium') : 0) || b.expiresAtMs - a.expiresAtMs);
  const grant = grants[0];
  const linkedToken = value.linkedPurchaseToken ?? value.outOfAppPurchaseContext?.expiredPurchaseToken ?? null;
  if (linkedToken) purchaseKey(linkedToken);
  return {accountToken: accountToken.toLowerCase(), grant, linkedToken,
    outOfApp: value.outOfAppPurchaseContext != null,
    pending: status === 'pending',
    needsAcknowledgement: value.acknowledgementState === 'ACKNOWLEDGEMENT_STATE_PENDING' && grant.validUntilMs > now};
}
