import {HttpsError} from 'firebase-functions/v2/https';

// Server-owned contract. null is unlimited, never an unavailable entitlement.
export const planPolicyVersion = 'plan-entitlements-v2';
export const planNames = Object.freeze(['free', 'plus', 'premium']);
export function planAccess(plan) {
  if (!planNames.includes(plan)) throw new Error('unknown-plan');
  const free = plan === 'free', premium = plan === 'premium';
  return {
    policyVersion: planPolicyVersion,
    canPrepare: true, canPairDisplay: true, canStartClass: true,
    displaysUnlimited: premium, maxActiveDisplays: premium ? null : free ? 1 : 3,
    displayLimit: premium ? 2147483647 : free ? 1 : 3,
    workoutsUnlimited: !free, maxWorkouts: free ? 7 : null,
    savedSlidesUnlimited: premium, maxSavedSlides: premium ? null : free ? 3 : 30,
    // Installed clients use these names for the same saved-slide resource.
    favoritesUnlimited: premium, maxFavorites: premium ? null : free ? 3 : 30,
    idleScreenCustomization: free ? 'basic' : 'custom',
    canHideCloudBoardLogo: !free, canUseCenterLogo: !free,
    aiSlidesMonthlyLimit: free ? 0 : premium ? 30 : 10,
    aiTimerMonthlyLimit: premium ? 100 : 0,
  };
}

export function unavailableEntitlement() {
  return new HttpsError('failed-precondition', '이용 권한을 확인하지 못했어요. 잠시 후 다시 시도해 주세요.',
    {reason: 'entitlement-unavailable', policyVersion: planPolicyVersion});
}

export function legacyPlanAccess(plan) {
  const premium = plan === 'premium';
  return {...planAccess(plan), policyVersion: 'plan-entitlements-v1',
    maxWorkouts: null, workoutsUnlimited: true,
    maxSavedSlides: premium ? null : 3, savedSlidesUnlimited: premium,
    maxFavorites: premium ? null : 3, favoritesUnlimited: premium,
    idleScreenCustomization: premium ? 'custom' : 'basic',
    canHideCloudBoardLogo: premium, canUseCenterLogo: premium,
    aiSlidesMonthlyLimit: premium ? 30 : 0, aiTimerMonthlyLimit: premium ? 100 : 0};
}

// Deploying code does not enroll the whole population in changed quotas. The
// operator activates v2 explicitly after supporting clients/companion are ready.
// Disabling enrollment does not flap already-migrated accounts back and forth.
export function projectPlanPolicy(result, previous, config) {
  if (previous?.policyVersion === planPolicyVersion ||
      previous?.webGrant?.policyVersion === planPolicyVersion ||
      (config?.enabled === true && config.version === planPolicyVersion)) return result;
  if (!planNames.includes(result.plan)) return {...result, policyVersion: previous?.policyVersion ?? 'plan-entitlements-v1'};
  // Keep expired/pending access denied; this helper only chooses quota fields.
  const legacy = legacyPlanAccess(result.plan);
  for (const key of ['canPrepare', 'canPairDisplay', 'canStartClass', 'validUntilMs', 'status',
    'maxActiveDisplays', 'displaysUnlimited', 'displayLimit']) delete legacy[key];
  return {...result, ...legacy};
}

// Missing/expired grants never become Free. Only explicit enrolled Free has
// a verified active grant; old server-owned plans keep independently assigned
// capabilities instead of being silently promoted to Premium or Free.
export function requirePlanEntitlement(entitlement, now = Date.now()) {
  const e = entitlement;
  if (!e || !Number.isSafeInteger(e.validUntilMs) || e.validUntilMs <= now ||
      !['active', 'trialing', 'grace_period', 'canceling', 'past_due'].includes(e.status)) {
    throw unavailableEntitlement();
  }
  if (planNames.includes(e.plan)) return {...e, ...(e.policyVersion === planPolicyVersion
    ? planAccess(e.plan) : legacyPlanAccess(e.plan))};
  if (!['legacy', 'cloudboard_pro'].includes(e.plan)) throw unavailableEntitlement();
  const savedLimit = Object.hasOwn(e, 'maxSavedSlides') ? e.maxSavedSlides : e.maxFavorites;
  if (savedLimit !== null && (!Number.isSafeInteger(savedLimit) || savedLimit < 0)) throw unavailableEntitlement();
  const workoutLimit = Object.hasOwn(e, 'maxWorkouts') ? e.maxWorkouts : null;
  if (workoutLimit !== null && (!Number.isSafeInteger(workoutLimit) || workoutLimit < 0)) throw unavailableEntitlement();
  return {...e, maxWorkouts: workoutLimit,
    workoutsUnlimited: workoutLimit === null, maxSavedSlides: savedLimit,
    savedSlidesUnlimited: savedLimit === null, maxFavorites: savedLimit,
    favoritesUnlimited: savedLimit === null};
}

export function assertPlanCapacity(entitlement, resource, used, additions = 1, now = Date.now()) {
  const access = requirePlanEntitlement(entitlement, now);
  const limit = resource === 'workouts' ? access.maxWorkouts : access.maxSavedSlides;
  if (limit !== null && additions > 0 && used + additions > limit) {
    throw new HttpsError('resource-exhausted', resource === 'workouts'
      ? `수업은 ${limit}개까지 보관할 수 있어요. 기존 수업과 초안은 유지됩니다.`
      : `슬라이드는 ${limit}개까지 저장할 수 있어요. 기존 자료는 유지됩니다.`,
    {reason: 'plan-limit', resource, limit, used, policyVersion: planPolicyVersion});
  }
  return access;
}
