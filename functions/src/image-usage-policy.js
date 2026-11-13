import {createHash} from 'node:crypto';
import {HttpsError} from 'firebase-functions/v2/https';

export const imageUsagePolicyRevision = 'image-usage-2.1.5-v1';
export const imageUsagePolicies = Object.freeze({
  free: Object.freeze({storageLimitBytes: 100000000, uploadDayLimitBytes: 30000000,
    imageLimitBytes: 100000000, downloadDayLimitBytes: 50000000, downloadMonthLimitBytes: 500000000}),
  premium: Object.freeze({storageLimitBytes: 1000000000, uploadDayLimitBytes: 500000000,
    imageLimitBytes: 100000000, downloadDayLimitBytes: 1000000000, downloadMonthLimitBytes: 20000000000}),
});
export const prepareLifetimeMs = 90000;
export const mediaLeaseLifetimeMs = 300000;
export const validUsageId = value => typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value);
export const validUsageRequestId = value => typeof value === 'string' && /^[A-Za-z0-9_-]{8,80}$/.test(value);
export const validBytes = value => Number.isSafeInteger(value) && value >= 0;
export const nowOf = ctx => (ctx.clock ?? Date.now)();
export function usageFailure(reason, code = 'failed-precondition', extra = {}) {
  const messages = {
    daily_transfer_limit: '오늘 이미지 전송 한도에 도달해 새 수업을 시작할 수 없어요.',
    monthly_transfer_limit: '이번 달 이미지 전송 한도에 도달해 새 수업을 시작할 수 없어요.',
    both_transfer_limits: '일일·월간 이미지 전송 한도에 도달했어요.',
    insufficient_start_budget: '수업 자료를 준비할 이미지 전송 잔여량이 부족해요.',
    storage_limit: '이미지 보관 한도에 도달했어요. 초안과 기존 자료는 유지됩니다.',
    daily_upload_limit: '오늘 새로 올릴 수 있는 이미지 용량을 초과했어요.',
    workout_image_limit: '수업 이미지는 합계 100MB까지 사용할 수 있어요.',
    usage_reconciliation_pending: '사용량 확인 중이에요. 진행 중인 수업은 계속할 수 있어요.',
    policy_or_client_upgrade_required: '이미지 사용 정책과 연결된 앱 버전을 확인해 주세요.',
    legacy_asset_transition_required: '기존 이미지의 전환이 필요해요. 진행 중인 수업은 유지됩니다.',
    entitlement_unverified: '이용 권한을 확인하지 못했어요.',
    idempotency_conflict: '같은 요청의 내용이 변경됐어요.',
    admission_expired: '수업 준비 승인이 만료됐어요. 다시 준비해 주세요.',
    session_changed: '수업 상태가 변경됐어요. 현재 수업을 확인해 주세요.',
    media_lease_invalid: '이미지 접근 권한을 다시 확인해 주세요.',
    upload_mismatch: '이미지 업로드 요청과 파일이 일치하지 않아요.',
    grant_configuration_required: '운영자 증액 설정을 확인해야 합니다.',
    service_unavailable: '연결을 확인하고 다시 시도해 주세요.',
  };
  return new HttpsError(code, messages[reason] ?? messages.service_unavailable, {
    schemaVersion: 1, policyRevision: imageUsagePolicyRevision, reason,
    retryable: ['usage_reconciliation_pending', 'service_unavailable'].includes(reason),
    usage: null, requiredBytes: null, nextEligibleAtMs: null, ...extra,
  });
}
export function assertUsage(condition, reason = 'upload_mismatch', code = 'invalid-argument', extra) {
  if (!condition) throw usageFailure(reason, code, extra);
}
export function usagePeriods(now) {
  const shifted = new Date(now + 9 * 3600000);
  const dayKey = shifted.toISOString().slice(0, 10), monthKey = dayKey.slice(0, 7);
  const dayReset = Date.UTC(shifted.getUTCFullYear(), shifted.getUTCMonth(), shifted.getUTCDate() + 1) - 9 * 3600000;
  const monthReset = Date.UTC(shifted.getUTCFullYear(), shifted.getUTCMonth() + 1, 1) - 9 * 3600000;
  return {dayKey, monthKey, dayReset, monthReset};
}
export function canonicalJson(value) {
  if (value === null || typeof value !== 'object') return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(',')}]`;
  return `{${Object.keys(value).sort().filter(k => value[k] !== undefined)
    .map(k => `${JSON.stringify(k)}:${canonicalJson(value[k])}`).join(',')}}`;
}
export const usageHash = value => createHash('sha256').update(canonicalJson(value)).digest('hex');
export function requireUsageProject(projectId) {
  assertUsage(projectId === 'cloud-board-development' || /^demo-[a-z0-9-]+$/.test(projectId ?? ''),
    'policy_or_client_upgrade_required', 'failed-precondition');
}
export function usageConfigEnabled(config, projectId) {
  return config?.enabled === true && config.schemaVersion === 1 &&
    config.policyRevision === imageUsagePolicyRevision && Array.isArray(config.allowedProjectIds) &&
    config.allowedProjectIds.includes(projectId);
}
export function requireUsageMutation(input) {
  assertUsage(input?.schemaVersion === 1 && validUsageRequestId(input.requestId));
}
