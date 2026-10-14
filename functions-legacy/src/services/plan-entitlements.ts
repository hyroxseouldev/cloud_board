export const PLAN_POLICY_VERSION = 'plan-entitlements-v2';
export function capabilitiesForPlan(plan: 'free' | 'plus' | 'premium') {
  const free = plan === 'free',
    premium = plan === 'premium';
  return {
    policyVersion: PLAN_POLICY_VERSION,
    canPrepare: true,
    canPairDisplay: true,
    canStartClass: true,
    displaysUnlimited: premium,
    maxActiveDisplays: premium ? null : free ? 1 : 3,
    displayLimit: premium ? 2147483647 : free ? 1 : 3,
    workoutsUnlimited: !free,
    maxWorkouts: free ? 7 : null,
    savedSlidesUnlimited: premium,
    maxSavedSlides: premium ? null : free ? 3 : 30,
    favoritesUnlimited: premium,
    maxFavorites: premium ? null : free ? 3 : 30,
    idleScreenCustomization: free ? 'basic' : 'custom',
    canHideCloudBoardLogo: !free,
    canUseCenterLogo: !free,
    aiSlidesMonthlyLimit: free ? 0 : premium ? 30 : 10,
    aiTimerMonthlyLimit: premium ? 100 : 0,
  };
}

export function applyPlanPolicy(grant: any, previous: any, config: any) {
  if (!['free', 'plus', 'premium'].includes(grant.plan)) return grant;
  const v2 =
    previous?.policyVersion === PLAN_POLICY_VERSION ||
    previous?.webGrant?.policyVersion === PLAN_POLICY_VERSION ||
    (config?.enabled === true && config.version === PLAN_POLICY_VERSION);
  const capabilities = capabilitiesForPlan(grant.plan);
  const legacy = {
    ...capabilities,
    policyVersion: 'plan-entitlements-v1',
    maxWorkouts: null,
    workoutsUnlimited: true,
    maxSavedSlides: grant.plan === 'premium' ? null : 3,
    savedSlidesUnlimited: grant.plan === 'premium',
    maxFavorites: grant.plan === 'premium' ? null : 3,
    favoritesUnlimited: grant.plan === 'premium',
    idleScreenCustomization: grant.plan === 'premium' ? 'custom' : 'basic',
    canHideCloudBoardLogo: grant.plan === 'premium',
    canUseCenterLogo: grant.plan === 'premium',
    aiSlidesMonthlyLimit: grant.plan === 'premium' ? 30 : 0,
  };
  const {
    canPrepare: _prepare,
    canPairDisplay: _pair,
    canStartClass: _start,
    ...policy
  } = v2 ? capabilities : legacy;
  // Capabilities never turn expired, pending, test or deleted grants active.
  const result = { ...grant, ...policy };
  if (grant.canStartClass === false) {
    for (const key of ['maxActiveDisplays', 'displaysUnlimited', 'displayLimit'])
      if (Object.hasOwn(grant, key)) result[key] = grant[key];
  }
  return result;
}

// Persisted compatibility encoding: existing subscriptions keep their positive
// legacy limit; 1 opts into Plus, -1 explicitly opts into Premium. No missing,
// zero or malformed value grants unlimited access. Billing prices are separate.
export function planEntitlements(displayLimit: unknown) {
  if (displayLimit === -1)
    return {
      plan: 'premium',
      displaysUnlimited: true,
      maxActiveDisplays: null,
      favoritesUnlimited: true,
      maxFavorites: null,
      idleScreenCustomization: 'custom',
      // Read compatibility for installed apps. Current server enforcement never
      // uses this finite legacy field for Premium.
      displayLimit: 2147483647,
    };
  if (displayLimit === 1)
    return {
      plan: 'plus',
      displaysUnlimited: false,
      maxActiveDisplays: 3,
      favoritesUnlimited: false,
      maxFavorites: 3,
      idleScreenCustomization: 'basic',
      displayLimit: 3,
    };
  const limit =
    typeof displayLimit === 'number' && Number.isInteger(displayLimit) && displayLimit > 0
      ? displayLimit
      : 0;
  return {
    plan: 'legacy',
    displaysUnlimited: false,
    maxActiveDisplays: limit,
    favoritesUnlimited: false,
    maxFavorites: null,
    idleScreenCustomization: 'legacy',
    displayLimit: limit,
  };
}

export function modernPlan(access: any) {
  return access?.plan === 'plus' &&
    (access.maxActiveDisplays === 1 || access.maxActiveDisplays === 3) &&
    access.displaysUnlimited === false
    ? 'plus'
    : access?.plan === 'premium' && access.displaysUnlimited === true
      ? 'premium'
      : access?.plan === 'free' &&
          access.maxActiveDisplays === 1 &&
          access.displaysUnlimited === false &&
          access.canStartClass === true
        ? 'free'
        : null;
}
