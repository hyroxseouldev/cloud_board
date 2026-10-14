import {planAccess, planPolicyVersion} from './plan-policy.js';
export {planAccess} from './plan-policy.js';

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

// Use the selected grant's OWN expiry. A longer Plus grant cannot extend Premium.
export function resolveGrants(grants, now = Date.now()) {
  const active = grants.filter(g => g && Number.isSafeInteger(g.validUntilMs) && g.validUntilMs > now &&
    (g.status == null || ['active', 'trialing', 'grace_period', 'canceling', 'past_due'].includes(g.status) ||
      (g.source === 'pilot' && g.status === 'pilot' && g.plan !== 'free') ||
      (!['free', 'plus', 'premium'].includes(g.plan) && g.status === 'legacy')));
  const rank = g => g.plan === 'premium' ? 3 : g.plan === 'free' ? 0 : g.plan === 'plus' ? 1 : 2;
  active.sort((a, b) => rank(b) - rank(a) || b.validUntilMs - a.validUntilMs);
  const winner = active[0];
  if (!winner) return {managed: true, source: billingSource, plan: 'free', status: 'expired',
    validUntilMs: 0, canPrepare: true, canPairDisplay: false, canStartClass: false,
    displaysUnlimited: false, maxActiveDisplays: 0, displayLimit: 0,
    favoritesUnlimited: false, maxFavorites: 3, idleScreenCustomization: 'basic',
    policyVersion: planPolicyVersion, workoutsUnlimited: false, maxWorkouts: 7,
    savedSlidesUnlimited: false, maxSavedSlides: 3, canHideCloudBoardLogo: false, canUseCenterLogo: false,
    aiSlidesMonthlyLimit: 0, aiTimerMonthlyLimit: 0};
  const legacyDefaults = {...planAccess('plus'), displayLimit: 3, maxActiveDisplays: 3,
    maxFavorites: 3, maxSavedSlides: 3, idleScreenCustomization: 'basic',
    canHideCloudBoardLogo: false, canUseCenterLogo: false, aiSlidesMonthlyLimit: 0, aiTimerMonthlyLimit: 0};
  const capabilities = ['free', 'plus', 'premium'].includes(winner.plan)
    ? planAccess(winner.plan) : Object.fromEntries(Object.keys(legacyDefaults).map(k => [k, Object.hasOwn(winner, k) ? winner[k] : legacyDefaults[k]]));
  if (!['free', 'plus', 'premium'].includes(winner.plan)) {
    capabilities.maxSavedSlides = Object.hasOwn(winner, 'maxSavedSlides') ? winner.maxSavedSlides : capabilities.maxFavorites;
    capabilities.savedSlidesUnlimited = capabilities.maxSavedSlides === null;
    capabilities.maxWorkouts = Object.hasOwn(winner, 'maxWorkouts') ? winner.maxWorkouts : null;
    capabilities.workoutsUnlimited = capabilities.maxWorkouts === null;
    capabilities.policyVersion = planPolicyVersion;
  }
  // Only a recognized modern Plus grant receives the new three-TV policy.
  // Unknown legacy grants keep their independently assigned capabilities.
  if (winner.plan === 'plus' && winner.displaysUnlimited === false &&
      [1, 3].includes(winner.maxActiveDisplays)) {
    capabilities.maxActiveDisplays = 3;
    capabilities.displayLimit = 3;
  }
  return {...capabilities, managed: true, source: billingSource, grantSource: winner.source ?? 'legacy',
    plan: winner.plan ?? 'cloudboard_pro', status: winner.status ?? 'active', validUntilMs: winner.validUntilMs};
}

export function purchasesAllowed(config, tester = false, store = 'app_store') {
  if (store === 'google_play') return config?.legalReady === true && config?.googlePlayProductsReady === true &&
    (config?.googlePlayPurchasesEnabled === true || (tester && config?.googlePlaySandboxPurchasesEnabled === true));
  return config?.legalReady === true && config?.productsReady === true &&
    (config?.purchasesEnabled === true || (tester && config?.sandboxPurchasesEnabled === true));
}

// A finite wire value preserves installed clients' timestamp contract. The
// product has no expiry; current clients render the explicit Free plan label.
export const freeValidUntilMs = 253402300799999;
export function freeGrant(enrollment) {
  return enrollment?.enabled === true
    ? {source: 'app_free', plan: 'free', status: 'active', validUntilMs: freeValidUntilMs}
    : null;
}

// A fallback plan must not erase previously consumed trial or paid history.
// These values only come from server-owned grant documents, never client input.
export function hasPaidOrTrialHistory(grant) {
  if (!grant) return false;
  if (grant.trialUsed === true || grant.paidHistory === true) return true;
  if (['app_free', 'firebase_billing'].includes(grant.source) || grant.plan === 'free') return false;
  if (['live', 'trial', 'app_trial', 'app_store', 'google_play'].includes(grant.source)) return true;
  return grant.managed === true &&
    !['pending_connection', 'awaiting_web'].includes(grant.status) &&
    (grant.validUntilMs > 0 || ['active', 'trialing', 'trial_expired', 'past_due', 'expired', 'canceling', 'canceled'].includes(grant.status));
}
