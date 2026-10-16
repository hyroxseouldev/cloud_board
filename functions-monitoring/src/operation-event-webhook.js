import {createHash} from 'node:crypto';

export const productionProjectId = 'cloud-board-stationd';
const unknown = '알 수 없음';
const eventKinds = new Map([
  ['playback_started', ['수업 시작 서버 승인', '서버가 수업 시작을 승인했습니다. 실제 TV 재생 여부는 이 기록만으로 확인되지 않습니다.']],
  ['playback_completed', ['수업 종료 기록', '수업 종료 상태가 기록되었습니다. 정상 완주 여부는 이 기록만으로 확인되지 않습니다.']],
  ['command_failed', ['수업 명령 처리 실패', '수업 명령 처리 실패가 기록되었습니다.']],
  ['command_receipt_failed', ['TV 명령 수신 확인 실패', 'TV 명령 수신 확인에 실패했습니다. 실제 재생 중단 여부는 별도 확인이 필요합니다.']],
  ['playback_interrupted', ['재생 중단 기록', '디스플레이의 재생 중단이 기록되었습니다.']],
  ['playback_restored', ['재생 복구 기록', '디스플레이의 재생 복구가 기록되었습니다.']],
  ['connection_failed', ['서버 연결 이상', '서버 연결 이상이 기록되었습니다. 실제 재생 중단 여부는 별도 확인이 필요합니다.']],
  ['connection_recovered', ['서버 연결 복구', '서버 연결 복구가 기록되었습니다.']],
  ['device_online', ['TV 서버 연결 기록', 'TV의 서버 연결이 기록되었습니다. 실제 TV 재생 여부는 이 기록만으로 확인되지 않습니다.']],
  ['device_offline', ['TV 서버 연결 끊김 기록', 'TV의 서버 연결 끊김이 기록되었습니다. 실제 재생 중단 여부는 별도 확인이 필요합니다.']],
  ['device_shutdown', ['앱 종료 신호 기록', '앱 종료 신호가 기록되었습니다. 전체 수업 종료 여부는 이 기록만으로 확인되지 않습니다.']],
]);
const plainObject = (value) => value !== null && typeof value === 'object' && !Array.isArray(value);
const pathPart = (value) => typeof value === 'string' && value.length > 0 &&
  Buffer.byteLength(value, 'utf8') <= 768 && !/[.#$\[\]/\x00-\x1f\x7f]/u.test(value);
const token = (value, limit = 160) => typeof value === 'string' &&
  value.length <= limit && /^[A-Za-z0-9_.:+-]+$/u.test(value) ? value : unknown;
function label(value) {
  if (typeof value !== 'string' || !value.trim()) return unknown;
  return value.slice(0, 1000)
    .replace(/[A-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Z0-9.-]+\.[A-Z]{2,}/giu, '[이메일 제외]')
    .replace(/\bBearer\s+\S+/giu, '[인증정보 제외]')
    .replace(/[\x00-\x1f\x7f\u202a-\u202e\u2066-\u2069]/gu, ' ')
    .trim().slice(0, 160) || unknown;
}
function time(value) {
  if (!Number.isSafeInteger(value) || value <= 0 || value > 8640000000000000) return unknown;
  return new Date(value).toISOString();
}
function targets(value) {
  if (!Array.isArray(value)) return unknown;
  if (value.length === 0) return '개별 대상 ID 기록 없음 (전체/구역 대상 여부 미확인)';
  const ids = value.slice(0, 20).map((item) => token(item));
  const count = value.length > 9999 ? '9999대 초과' : `${value.length}대`;
  return `${count}: ${ids.join(', ')}${value.length > 20 ? ' (최대 20개 표시)' : ''}`;
}

// The database path, not the event's client-supplied id, is the retry identity.
// receivedAtMs intentionally does not replace an unknown occurrence time.
export function buildWebhookPayload({projectId, ownerId, eventId, event, receivedAtMs} = {}) {
  if (projectId !== productionProjectId || !pathPart(ownerId) ||
      token(ownerId) === unknown || !pathPart(eventId) || !plainObject(event)) return null;
  const kind = eventKinds.get(event.type);
  if (!kind) return null;
  const event_id = createHash('sha256').update(JSON.stringify([
    projectId, `users/${ownerId}/operations/events/${eventId}`,
  ])).digest('hex');
  const role = new Map([['controller', '컨트롤러'], ['display', '디스플레이'], ['tv', 'TV']]).get(event.deviceRole) ?? unknown;
  const impact = new Map([['interrupted', '재생 중단 기록 있음'], ['none', '영향 없음으로 기록됨']]).get(event.playbackImpact) ?? unknown;
  const message = [
    kind[1],
    '환경: production',
    `원본 유형: ${event.type}`,
    `발생 시각 (UTC): ${time(event.occurredAtMs)}`,
    `서버 이벤트 시각 (UTC): ${time(receivedAtMs)}`,
    `센터명: ${unknown}`,
    `센터 계정 ID: ${ownerId}`,
    `수업 이름: ${label(event.workoutName)}`,
    `수업 ID: ${token(event.workoutId)}`,
    `세션 ID: ${token(event.sessionId)}`,
    `기기 이름: ${label(event.deviceName)}`,
    `기기 ID: ${token(event.deviceId)}`,
    `기기 역할: ${role}`,
    `앱 버전: ${token(event.appVersion, 40)}`,
    `단계: ${token(event.phase, 80)}`,
    `오류 코드: ${token(event.errorCode, 80)}`,
    `장애 ID: ${token(event.incidentId)}`,
    `복구 대상 이벤트 ID: ${token(event.recoveryOfEventId)}`,
    `재생 영향: ${impact}`,
    `대상 기기: ${targets(event.targetDeviceIds)}`,
  ].join('\n');
  return {event_id, title: kind[0], message};
}

function deliveryError(code, status) {
  const error = new Error(code);
  error.name = 'WebhookDeliveryError';
  error.code = code;
  if (status !== undefined) error.status = status;
  return error;
}
function validPayload(payload) {
  return plainObject(payload) && Object.keys(payload).sort().join(',') === 'event_id,message,title' &&
    /^[a-f0-9]{64}$/u.test(payload.event_id) &&
    typeof payload.title === 'string' && payload.title.length > 0 && payload.title.length <= 200 &&
    typeof payload.message === 'string' && payload.message.length > 0 && payload.message.length <= 6000;
}

export async function deliverWebhook({payload, key, url, fetchImpl = fetch, timeoutMs = 8000, allowLocalEmulator = false} = {}) {
  let endpoint;
  try { endpoint = new URL(url); } catch { throw deliveryError('webhook_invalid_configuration'); }
  const localEmulator = allowLocalEmulator === true && endpoint.protocol === 'http:' &&
    endpoint.hostname === '127.0.0.1' && endpoint.port === '19404' &&
    endpoint.pathname === '/events' && !endpoint.search && !endpoint.hash;
  if ((!localEmulator && endpoint.protocol !== 'https:') || endpoint.username || endpoint.password ||
      typeof key !== 'string' || !key.trim() || /[\r\n]/u.test(key) ||
      !Number.isSafeInteger(timeoutMs) || timeoutMs <= 0 || timeoutMs > 60000 ||
      typeof fetchImpl !== 'function' || !validPayload(payload)) {
    throw deliveryError('webhook_invalid_configuration');
  }
  const controller = new AbortController();
  let timedOut = false;
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => {
      timedOut = true;
      controller.abort();
      reject(deliveryError('webhook_timeout'));
    }, timeoutMs);
  });
  try {
    const response = await Promise.race([
      Promise.resolve().then(() => fetchImpl(endpoint.href, {
        method: 'POST',
        headers: {'Content-Type': 'application/json', Authorization: `Bearer ${key}`},
        body: JSON.stringify(payload),
        redirect: 'error',
        signal: controller.signal,
      })), timeout,
    ]);
    const status = response?.status;
    // Never read or log the receiver body; even a 2xx response must be released.
    try { await Promise.race([response?.body?.cancel(), timeout]); } catch (_) { /* Status is authoritative. */ }
    if (!Number.isInteger(status) || status < 200 || status > 599) throw deliveryError('webhook_invalid_response');
    if (status >= 200 && status < 300) return {outcome: 'delivered', status};
    if (status === 408 || status === 429 || status >= 500) throw deliveryError('webhook_retryable_http', status);
    return {outcome: 'dropped', status};
  } catch (error) {
    if (error?.name === 'WebhookDeliveryError' && ['webhook_timeout', 'webhook_retryable_http', 'webhook_invalid_response'].includes(error.code)) {
      throw deliveryError(error.code, Number.isInteger(error.status) ? error.status : undefined);
    }
    throw deliveryError(timedOut ? 'webhook_timeout' : 'webhook_network_error');
  } finally {
    clearTimeout(timer);
  }
}
