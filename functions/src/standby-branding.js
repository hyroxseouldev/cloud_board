import {HttpsError} from 'firebase-functions/v2/https';
import {requirePlanEntitlement, planPolicyVersion} from './plan-policy.js';
import {AppBrand} from './config/app-brand.js';

export const defaultStandbyBrand = Object.freeze({
  storeName: AppBrand.name, standbyMessage: '다음 수업을 준비하고 있습니다',
  logoUrl: null, promotionImageUrls: [], primaryColorValue: 0xFF526B60,
  blackScreenStartMinutes: 0, blackScreenEndMinutes: 0,
  standbyFullscreen: false, standbyShowText: true, standbyTextColor: 0xFF2B332E,
  standbyTextPosition: 'bottomLeft', standbyBackgroundColor: 0xFFF7F5EF,
  promotionDurationMinutes: [], standbyTransition: 'fade', standbyImageFit: 'contain',
  showCloudBoardLogo: true,
});

const stringFields = {storeName: 60, standbyMessage: 500};
const colors = ['primaryColorValue', 'standbyTextColor', 'standbyBackgroundColor'];
const booleans = ['standbyFullscreen', 'standbyShowText', 'showCloudBoardLogo'];
const minuteFields = ['blackScreenStartMinutes', 'blackScreenEndMinutes'];
const allowed = new Set(Object.keys(defaultStandbyBrand));
function invalid() { return new HttpsError('invalid-argument', '대기 화면 설정을 확인해 주세요.'); }
function imageUrl(value) { return typeof value === 'string' && value.length <= 4096 && /^https:\/\//.test(value); }
export function validateBrandConfig(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input) || Object.keys(input).some(k => !allowed.has(k))) throw invalid();
  const v = {...defaultStandbyBrand, ...input};
  for (const [key, max] of Object.entries(stringFields)) if (typeof v[key] !== 'string' || v[key].length > max) throw invalid();
  for (const key of colors) if (!Number.isInteger(v[key]) || v[key] < 0 || v[key] > 0xFFFFFFFF) throw invalid();
  for (const key of booleans) if (typeof v[key] !== 'boolean') throw invalid();
  for (const key of minuteFields) if (!Number.isInteger(v[key]) || v[key] < 0 || v[key] >= 1440) throw invalid();
  if (v.logoUrl !== null && !imageUrl(v.logoUrl)) throw invalid();
  if (!Array.isArray(v.promotionImageUrls) || v.promotionImageUrls.length > 100 || !v.promotionImageUrls.every(imageUrl)) throw invalid();
  if (!Array.isArray(v.promotionDurationMinutes) || v.promotionDurationMinutes.length > 100 || !v.promotionDurationMinutes.every(n => Number.isInteger(n) && n >= 1 && n <= 1440)) throw invalid();
  if (!['topLeft', 'center', 'bottomLeft'].includes(v.standbyTextPosition) ||
      !['none', 'fade', 'slide'].includes(v.standbyTransition) || !['contain', 'cover'].includes(v.standbyImageFit)) throw invalid();
  return v;
}

export function applyBrandEntitlement(config, entitlement, now = Date.now()) {
  const access = requirePlanEntitlement(entitlement, now);
  if (access.idleScreenCustomization === 'basic') return {...defaultStandbyBrand};
  if (access.idleScreenCustomization !== 'custom') throw new HttpsError('failed-precondition', '브랜드 권한을 확인하지 못했습니다.', {reason: 'entitlement-unavailable'});
  // Existing config remains untouched, including old clients' missing fields.
  return {...defaultStandbyBrand, ...config,
    logoUrl: access.canUseCenterLogo === true ? config?.logoUrl ?? null : null,
    showCloudBoardLogo: access.canHideCloudBoardLogo !== true || config?.showCloudBoardLogo !== false};
}

// Projection never destroys custom settings. Unknown/expired access leaves the
// last confirmed payload intact until the entitlement writer resolves a grant.
export async function projectStandbyBranding(db, realtime, uid, now = Date.now()) {
  const [lock, snapshot] = await db.getAll(db.doc(`accountDeletions/${uid}`), db.doc(`subscriptionEntitlements/${uid}`));
  if (lock.exists) return false;
  const entitlement = snapshot.data();
  if (entitlement?.policyVersion !== planPolicyVersion) return false;
  try { applyBrandEntitlement({}, entitlement, now); } catch (e) {
    if (e.code === 'failed-precondition') return false;
    throw e;
  }
  const revision = entitlement.revision ?? 0;
  const result = await realtime.ref(`users/${uid}/operations`).transaction(current => {
    const previous = current ?? {};
    if ((previous.brandProjection?.revision ?? -1) > revision) return undefined;
    // The first projection snapshots the old payload before applying Free.
    const config = previous.brandConfig ?? previous.brand ?? {...defaultStandbyBrand};
    return {...previous, brandConfig: config,
      brand: applyBrandEntitlement(config, entitlement, now),
      brandProjection: {revision, policyVersion: planPolicyVersion, plan: entitlement.plan, appliedAtMs: now}};
  });
  if ((await db.doc(`accountDeletions/${uid}`).get()).exists) {
    await realtime.ref(`users/${uid}/operations`).remove();
    return false;
  }
  return result.committed;
}

export async function saveBrandConfig(db, realtime, request, now = Date.now()) {
  const uid = request.auth?.uid;
  if (!uid || request.auth?.token?.firebase?.sign_in_provider === 'anonymous') throw new HttpsError('unauthenticated', '로그인이 필요합니다.');
  const value = validateBrandConfig(request.data?.brand);
  const [lock, snapshot] = await db.getAll(db.doc(`accountDeletions/${uid}`), db.doc(`subscriptionEntitlements/${uid}`));
  if (lock.exists) throw new HttpsError('permission-denied', '계정 삭제 중입니다.');
  // The v2 rollout is per account. Unmigrated accounts keep their installed
  // brand writer behavior; this callable is not an implicit plan migration.
  const access = requirePlanEntitlement(snapshot.data(), now);
  if (snapshot.data()?.policyVersion !== planPolicyVersion) {
    const result = await realtime.ref(`users/${uid}/operations`).transaction(current => {
      // A missing/regressed mirror must never reopen a migrated account.
      if (current?.brandProjection?.policyVersion === planPolicyVersion) return undefined;
      return {...(current ?? {}), brand: value};
    });
    if (!result.committed) throw new HttpsError('failed-precondition', '브랜드 권한을 확인하지 못했습니다.', {reason: 'entitlement-unavailable'});
    return {saved: true};
  }
  if (access.idleScreenCustomization !== 'custom' ||
      (value.logoUrl && access.canUseCenterLogo !== true) ||
      (!value.showCloudBoardLogo && access.canHideCloudBoardLogo !== true)) {
    throw new HttpsError('permission-denied', '센터 브랜딩은 Plus부터 사용할 수 있어요.', {reason: 'branding-plan-required'});
  }
  await realtime.ref(`users/${uid}/operations/brandConfig`).set(value);
  await projectStandbyBranding(db, realtime, uid, now);
  return {saved: true};
}
