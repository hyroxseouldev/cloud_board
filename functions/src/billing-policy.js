// Only verified App Store data reaches these policies. No prices are hard-coded.
export const bundleId = 'com.sunmkim.cloudboard';
export const appAppleId = 6809105126;
export const products = Object.freeze({
  'com.sunmkim.cloudboard.plus.monthly': 'plus',
  'com.sunmkim.cloudboard.premium.monthly': 'premium',
});
export const billingSource = 'firebase_billing';
export const idPattern = /^\d{1,40}$/;
export const tokenPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function validateTransaction(t, environment) {
  if (!t || t.bundleId !== bundleId || t.environment !== environment ||
      !['Production', 'Sandbox'].includes(environment) || !products[t.productId] ||
      t.type !== 'Auto-Renewable Subscription' || t.inAppOwnershipType !== 'PURCHASED' ||
      !idPattern.test(t.transactionId ?? '') || !idPattern.test(t.originalTransactionId ?? '') ||
      !tokenPattern.test(t.appAccountToken ?? '') || !Number.isSafeInteger(t.expiresDate)) {
    throw new Error('unsupported-transaction');
  }
  return t;
}

export function appleGrant(t, renewal, status, now = Date.now()) {
  const revoked = t.revocationDate != null || status === 5 || t.isUpgraded === true;
  const grace = status === 4 && Number.isSafeInteger(renewal.gracePeriodExpiresDate);
  const until = revoked ? 0 : grace ? renewal.gracePeriodExpiresDate : t.expiresDate;
  const active = !revoked && [1, 4].includes(status) && until > now;
  return {
    source: 'app_store', plan: products[t.productId], productId: t.productId,
    validUntilMs: active ? until : 0, expiresAtMs: t.expiresDate,
    status: revoked ? 'revoked' : grace && active ? 'grace_period' :
      renewal.isInBillingRetryPeriod ? 'billing_retry' : active ? 'active' : 'expired',
    autoRenew: renewal.autoRenewStatus === 1,
    nextProductId: products[renewal.autoRenewProductId] ? renewal.autoRenewProductId : null,
    environment: t.environment,
  };
}

export function planAccess(plan) {
  const premium = plan === 'premium';
  return {canPrepare: true, canPairDisplay: true, canStartClass: true,
    displaysUnlimited: premium, maxActiveDisplays: premium ? null : 1,
    favoritesUnlimited: premium, maxFavorites: premium ? null : 3,
    idleScreenCustomization: premium ? 'custom' : 'basic', displayLimit: premium ? 2147483647 : 1};
}

// Use the selected grant's OWN expiry. A longer Plus grant cannot extend Premium.
export function resolveGrants(grants, now = Date.now()) {
  const active = grants.filter(g => g && Number.isSafeInteger(g.validUntilMs) && g.validUntilMs > now);
  const rank = g => g.plan === 'premium' ? 3 : g.plan === 'plus' ? 1 : 2;
  active.sort((a, b) => rank(b) - rank(a) || b.validUntilMs - a.validUntilMs);
  const winner = active[0];
  if (!winner) return {managed: true, source: billingSource, plan: 'free', status: 'expired',
    validUntilMs: 0, canPrepare: true, canPairDisplay: false, canStartClass: false,
    displaysUnlimited: false, maxActiveDisplays: 0, displayLimit: 0,
    favoritesUnlimited: false, maxFavorites: 3, idleScreenCustomization: 'basic'};
  const legacyDefaults = {...planAccess('plus'), displayLimit: 3, maxActiveDisplays: 3};
  const capabilities = winner.source === 'app_store' || winner.source === 'app_trial'
    ? planAccess(winner.plan) : Object.fromEntries(Object.keys(legacyDefaults).map(k => [k, Object.hasOwn(winner, k) ? winner[k] : legacyDefaults[k]]));
  return {...capabilities, managed: true, source: billingSource, grantSource: winner.source ?? 'legacy',
    plan: winner.plan ?? 'cloudboard_pro', status: winner.status ?? 'active', validUntilMs: winner.validUntilMs};
}

export function purchasesAllowed(config, tester = false) {
  return config?.legalReady === true && config?.productsReady === true &&
    (config?.purchasesEnabled === true || (tester && config?.sandboxPurchasesEnabled === true));
}
