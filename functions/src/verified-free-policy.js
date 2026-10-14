// Proof comes only from server-owned SMS progress or the linked web server's
// verified-phone grant. Billing history and client profile fields are not proof.
export function hasVerifiedPhone(progress, webGrant, baseline) {
  return progress?.phoneVerified === true || webGrant?.phoneVerified === true ||
    baseline?.phoneVerified === true;
}

export function isFreeGrant(grant) {
  return grant?.plan === 'free' || grant?.source === 'app_free';
}

export const verifiedFreePolicyVersion = 'verified-free-v2';

// A proof-only bridge must not replace a paid/legacy entitlement snapshot.
export function hasWebEntitlement(grant) {
  return typeof grant?.source === 'string' && typeof grant?.plan === 'string' &&
    Number.isSafeInteger(grant?.validUntilMs);
}
