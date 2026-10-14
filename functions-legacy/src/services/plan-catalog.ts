import { HttpError } from './core.js';
import { firebaseServices } from './firebase.js';
import { PLAN_POLICY_VERSION, capabilitiesForPlan } from './plan-entitlements.js';

export const CATALOG_VERSION = 'monthly-krw-2026-10';
export const paidPlanIds = ['plus', 'premium'] as const;
export type PaidPlan = (typeof paidPlanIds)[number];
export const monthlyPrices = { plus: 49000, premium: 99000 } as const;
export function paidPlan(value: unknown): PaidPlan {
  if (value !== 'plus' && value !== 'premium')
    throw new HttpError(400, 'PLAN_REQUIRED', 'Plus 또는 Premium 요금제를 선택해 주세요.');
  return value;
}
export const catalogPlans = paidPlanIds.map((id) => ({
  id,
  name: id === 'plus' ? 'Plus' : 'Premium',
  amount: monthlyPrices[id],
  currency: 'KRW',
  period: 'P1M',
  taxInclusive: true,
  ...capabilitiesForPlan(id),
}));
export function webSalesReady(policy: any, billing: any, now = Date.now(), billingMode = 'live') {
  const proof = billing?.planCatalog?.toss;
  return (
    ['test', 'live'].includes(billingMode) &&
    policy?.enabled === true &&
    policy.version === PLAN_POLICY_VERSION &&
    proof?.version === CATALOG_VERSION &&
    proof.policyVersion === PLAN_POLICY_VERSION &&
    (proof.sandboxVerified === true ||
      (billingMode === 'test' && proof.sandboxSalesEnabled === true)) &&
    proof.taxInclusive === true &&
    proof.currency === 'KRW' &&
    proof.period === 'P1M' &&
    Number.isSafeInteger(proof.verifiedAtMs) &&
    proof.verifiedAtMs > 0 &&
    proof.verifiedAtMs <= now &&
    typeof proof.evidenceUrl === 'string' &&
    /^https:\/\//.test(proof.evidenceUrl) &&
    paidPlanIds.every(
      (plan) =>
        proof.products?.[plan]?.id === plan &&
        proof.products[plan].amount === monthlyPrices[plan] &&
        proof.products[plan].active === true,
    )
  );
}
export async function readWebSalesReady() {
  try {
    const { firestore } = firebaseServices();
    const [policy, billing] = await Promise.all([
      firestore.doc('appConfig/planPolicy').get(),
      firestore.doc('appConfig/billing').get(),
    ]);
    return webSalesReady(
      policy.data(),
      billing.data(),
      Date.now(),
      process.env.BILLING_MODE || 'disabled',
    );
  } catch {
    return false;
  }
}
export async function requireWebSalesReady() {
  if (!(await readWebSalesReady()))
    throw new HttpError(
      503,
      'PLAN_SALES_UNAVAILABLE',
      '새 요금제 결제를 준비 중입니다. 기존 구독과 결제 내역은 유지됩니다.',
    );
}
