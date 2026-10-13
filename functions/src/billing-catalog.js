// Approved STA-158 offer, not a substitute for a localized store price.
export const billingCatalogVersion = 'monthly-krw-2026-10';
export const monthlyKrwPrices = Object.freeze({plus: 49000, premium: 99000});

// This server-owned attestation is populated only after reading the actual
// store catalog and verifying sandbox purchase/restore against this release.
export function planSalesReady(config, store = 'app_store', now = Date.now(), sandboxTester = false) {
  const proof = config?.planCatalog?.[store];
  return proof?.version === billingCatalogVersion &&
    proof.policyVersion === 'plan-entitlements-v2' &&
    (proof.sandboxVerified === true || (sandboxTester && proof.sandboxSalesEnabled === true)) &&
    proof.taxInclusive === true &&
    proof.currency === 'KRW' && proof.period === 'P1M' &&
    Number.isSafeInteger(proof.verifiedAtMs) && proof.verifiedAtMs > 0 && proof.verifiedAtMs <= now &&
    typeof proof.evidenceUrl === 'string' && /^https:\/\//.test(proof.evidenceUrl) &&
    Object.entries(monthlyKrwPrices).every(([plan, amount]) =>
      proof.products?.[plan]?.id === `com.sunmkim.cloudboard.${plan}.monthly` &&
      proof.products[plan].amount === amount && proof.products[plan].active === true);
}
