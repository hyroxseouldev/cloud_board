// Receipt/installed-client compatibility only. Never a new sales catalog or quotaPlan.
export const historicalProducts = Object.freeze({
  'com.sunmkim.cloudboard.plus.monthly': 'plus',
});
export const isHistoricalPlan = plan => plan === 'plus';
export function receiptPlan(productId) {
  return productId === 'com.sunmkim.cloudboard.premium.monthly' ? 'premium' : historicalProducts[productId] ?? null;
}
export function historicalPlanAccess(grant) {
  if (!isHistoricalPlan(grant.plan)) throw new Error('unknown-historical-plan');
  const v1 = grant.policyVersion === 'plan-entitlements-v1';
  const defaults = {
    policyVersion: v1 ? 'plan-entitlements-v1' : 'plan-entitlements-v2',
    canPrepare: true, canPairDisplay: true, canStartClass: true,
    displaysUnlimited: false, maxActiveDisplays: 3, displayLimit: 3,
    workoutsUnlimited: true, maxWorkouts: null,
    savedSlidesUnlimited: false, maxSavedSlides: v1 ? 3 : 30,
    favoritesUnlimited: false, maxFavorites: v1 ? 3 : 30,
    idleScreenCustomization: v1 ? 'basic' : 'custom',
    canHideCloudBoardLogo: !v1, canUseCenterLogo: !v1,
    aiSlidesMonthlyLimit: v1 ? 0 : 10, aiTimerMonthlyLimit: 0,
  };
  // Existing explicitly assigned rights and their revision/expiry are retained.
  return {...defaults, ...grant};
}
export function legacyGrantRank(grant) {
  return grant.plan === 'premium' ? 3 : grant.plan === 'free' ? 0 : isHistoricalPlan(grant.plan) ? 1 : 2;
}

export function projectHistoricalPlan(result, previous) {
  const policyVersion = previous?.policyVersion ?? 'plan-entitlements-v1';
  const baseline = historicalPlanAccess({plan: result.plan, policyVersion});
  const capabilities = Object.fromEntries(Object.keys(baseline).filter(key => key !== 'plan')
    .map(key => [key, previous && Object.hasOwn(previous, key) ? previous[key] : baseline[key]]));
  // Expiry/status/source belong to the selected verified grant, not old projection.
  for (const key of ['canPrepare', 'canPairDisplay', 'canStartClass']) delete capabilities[key];
  return {...result, ...capabilities};
}
