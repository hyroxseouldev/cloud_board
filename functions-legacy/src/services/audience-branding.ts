import { firebaseServices } from './firebase.js';

export const AUDIENCE_LOGO_VERSION = 'audience-logo-v1';
export function accountAudienceBranding(
  uid: string,
  entitlement: any,
  projection: any,
  now = Date.now(),
) {
  const statusValid =
    ['active', 'trialing', 'grace_period', 'canceling', 'past_due'].includes(entitlement?.status) ||
    (['legacy', 'cloudboard_pro'].includes(entitlement?.plan) &&
      entitlement?.status === 'legacy') ||
    (entitlement?.plan !== 'free' &&
      entitlement?.status === 'pilot' &&
      [entitlement?.source, entitlement?.grantSource].includes('pilot'));
  if (
    !uid ||
    !statusValid ||
    entitlement?.managed !== true ||
    entitlement.canStartClass !== true ||
    !['free', 'plus', 'premium', 'legacy', 'cloudboard_pro'].includes(entitlement.plan) ||
    entitlement.policyVersion !== 'plan-entitlements-v2' ||
    !Number.isSafeInteger(entitlement.validUntilMs) ||
    entitlement.validUntilMs <= now ||
    !Number.isSafeInteger(entitlement.revision) ||
    projection?.ownerId !== uid ||
    projection.policyVersion !== entitlement.policyVersion ||
    projection.plan !== entitlement.plan ||
    projection.revision !== entitlement.revision ||
    projection.validUntilMs !== entitlement.validUntilMs ||
    projection.audienceLogoVersion !== AUDIENCE_LOGO_VERSION ||
    !['standby', 'all-audience'].includes(projection.audienceLogoScope) ||
    typeof projection.showCloudBoardLogo !== 'boolean' ||
    typeof entitlement.canHideCloudBoardLogo !== 'boolean'
  )
    return publicAudienceBranding(undefined);
  return {
    version: AUDIENCE_LOGO_VERSION,
    scope: projection.audienceLogoScope as 'standby' | 'all-audience',
    validUntilMs: entitlement.validUntilMs,
    canHideCloudBoardLogo: entitlement.canHideCloudBoardLogo,
  };
}

export async function readBrandProjection(uid: string, services = firebaseServices) {
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    return await Promise.race([
      services()
        .realtime.ref(`users/${uid}/operations/brandProjection`)
        .get()
        .then((snapshot) => snapshot.val()),
      new Promise<never>((_, reject) => {
        timer = setTimeout(() => reject(new Error('Brand projection timeout')), 1500);
      }),
    ]);
  } catch {
    return undefined;
  } finally {
    clearTimeout(timer);
  }
}

export function publicAudienceBranding(config: any) {
  return {
    version: AUDIENCE_LOGO_VERSION,
    // Pilot owner IDs are never a public feature launch or exposed by this API.
    scope:
      config?.version === AUDIENCE_LOGO_VERSION &&
      config.enabled === true &&
      config.allAccounts === true
        ? ('all-audience' as const)
        : ('standby' as const),
  };
}

export async function readPublicAudienceBranding(
  read = async () =>
    (await firebaseServices().firestore.doc('appConfig/audienceBranding').get()).data(),
) {
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    const config = await Promise.race([
      read(),
      new Promise<never>((_, reject) => {
        timer = setTimeout(() => reject(new Error('Audience branding lookup timeout')), 1500);
      }),
    ]);
    return publicAudienceBranding(config);
  } catch {
    return publicAudienceBranding(undefined);
  } finally {
    clearTimeout(timer);
  }
}
