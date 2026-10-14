import {createHash} from 'node:crypto';
import {Timestamp} from 'firebase-admin/firestore';
import {HttpsError} from 'firebase-functions/v2/https';

export const operationActions = ['slides.save', 'workout.import', 'plan.upgrade.purchase', 'plan.workouts.usage', 'plan.workouts.limit', 'plan.workouts.manage', 'plan.workouts.upgrade', 'plan.savedSlides.usage', 'plan.savedSlides.limit', 'plan.savedSlides.manage', 'plan.savedSlides.upgrade', 'workout.save', 'tv.prepare', 'tv.prepare.request', 'tv.prepare.receipts', 'tv.prepare.listen', 'playback.control.submit', 'playback.control.ack'];
const outcomes = ['attempt', 'success', 'failure', 'cancelled'];
const allowed = new Set(['accountId', 'operationId', 'action', 'outcome', 'startedAt', 'occurredAt', 'durationMs', 'platform', 'version', 'build', 'code']);
const codes = new Set(['permission-denied', 'unauthenticated', 'unavailable', 'deadline-exceeded', 'resource-exhausted', 'aborted', 'not-found', 'failed-precondition', 'revision_conflict', 'session_changed', 'prepare_request', 'prepare_receipts', 'prepare_listen', 'prepare_images', 'prepare_audio', 'prepare_response', 'start_access', 'start_device', 'start_preferences', 'start_preparation', 'start_session', 'start_cancelled', 'timeout', 'cancelled', 'unexpected']);
const fail = message => new HttpsError('invalid-argument', message);
export function validateOperation(payload, now = Date.now()) {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload) ||
      Buffer.byteLength(JSON.stringify(payload)) > 1500 || Object.keys(payload).some(key => !allowed.has(key)) ||
      !/^[a-f0-9]{32}$/.test(payload.operationId ?? '') || !operationActions.includes(payload.action) ||
      !outcomes.includes(payload.outcome) || !['ios', 'android', 'web', 'macos', 'windows', 'linux', 'fuchsia'].includes(payload.platform) ||
      typeof payload.version !== 'string' || !/^(unknown|\d+(?:[.\-+][a-zA-Z0-9]+){0,8})$/.test(payload.version) || payload.version.length > 40 ||
      typeof payload.build !== 'string' || !/^(unknown|\d+(?:\.\d+){0,4})$/.test(payload.build) || payload.build.length > 20 ||
      !Number.isInteger(payload.durationMs) || payload.durationMs < 0 || payload.durationMs > 86400000 ||
      (payload.code !== undefined && !codes.has(payload.code)) ||
      (payload.outcome === 'attempt' && payload.durationMs !== 0)) throw fail('Invalid operation metadata');
  const started = Date.parse(payload.startedAt), occurred = Date.parse(payload.occurredAt);
  if (!Number.isFinite(started) || !Number.isFinite(occurred) || started < now - 86400000 ||
      occurred < started || occurred > now + 300000 || started > now + 300000) throw fail('Expired operation metadata');
  return {operationId: payload.operationId, action: payload.action, outcome: payload.outcome,
    startedAt: new Date(started).toISOString(), occurredAt: new Date(occurred).toISOString(),
    durationMs: payload.durationMs, platform: payload.platform, version: payload.version, build: payload.build,
    ...(payload.outcome === 'failure' ? {code: payload.code ?? 'unexpected'} : {})};
}

export async function recordOperation({db, realtime, auth, payload, emit, now = Date.now()}) {
  if (!auth?.uid) throw new HttpsError('unauthenticated', 'Authentication required');
  if (payload?.accountId !== auth.uid) throw new HttpsError('permission-denied', 'Account changed');
  const event = validateOperation(payload, now);
  if (auth.token?.firebase?.sign_in_provider === 'anonymous' &&
      !(await realtime.ref(`displayAccess/${auth.uid}/ownerId`).get()).exists()) {
    throw new HttpsError('permission-denied', 'Paired display required');
  }
  const ref = db.doc(`operationTelemetryLimits/${auth.uid}`);
  const signature = createHash('sha256').update(JSON.stringify([event.action, event.startedAt, event.platform, event.version, event.build])).digest('hex');
  const accepted = await db.runTransaction(async tx => {
    const [snapshot, deletion] = await Promise.all([tx.get(ref), tx.get(db.doc(`accountDeletions/${auth.uid}`))]);
    if (deletion.exists) throw new HttpsError('permission-denied', 'Account is being deleted');
    const previous = snapshot.data() ?? {};
    const recent = (previous.events ?? []).filter(item => item.at > now - 86400000).slice(-255);
    const same = recent.filter(item => item.id === event.operationId);
    if (same.some(item => item.signature !== signature)) throw fail('Operation metadata changed');
    if (same.some(item => item.outcome === event.outcome || (item.outcome !== 'attempt' && event.outcome !== 'attempt'))) return false;
    const minute = Math.floor(now / 60000), day = Math.floor(now / 86400000);
    const count = previous.minute === minute ? previous.count ?? 0 : 0;
    const daily = previous.day === day ? previous.daily ?? 0 : 0;
    if (count >= 120 || daily >= 4096) throw new HttpsError('resource-exhausted', 'Telemetry rate limit');
    tx.set(ref, {minute, count: count + 1, day, daily: daily + 1,
      events: [...recent, {id: event.operationId, outcome: event.outcome, signature, at: now}],
      expiresAt: Timestamp.fromMillis(now + 86400000)});
    return true;
  });
  if (accepted) emit({severity: 'INFO', message: 'operation_telemetry', ...event,
    operationKey: createHash('sha256').update(`${auth.uid}:${event.operationId}`).digest('hex'),
    role: auth.token?.firebase?.sign_in_provider === 'anonymous' ? 'display' : 'account',
    receivedAt: new Date(now).toISOString()});
  return {accepted};
}

export async function cleanupOperationLimits(db, now = Date.now()) {
  let removed = 0;
  for (let page = 0; page < 4; page++) {
    const expired = await db.collection('operationTelemetryLimits').where('expiresAt', '<=', Timestamp.fromMillis(now)).limit(250).get();
    if (expired.empty) break;
    for (const item of expired.docs) removed += await db.runTransaction(async tx => {
      const current = await tx.get(item.ref);
      if (!current.exists || current.data().expiresAt?.toMillis() > now) return 0;
      tx.delete(item.ref); return 1;
    });
    if (expired.size < 250) break;
  }
  return removed;
}

// Deduplicate again at analysis time, including retries beyond the bounded server
// history. A terminal event implies an attempt; silence never implies success.
export function summarizeOperations(entries) {
  const operations = new Map();
  for (const entry of entries) {
    const event = entry.jsonPayload ?? entry;
    if (event.message !== 'operation_telemetry' || !/^[a-f0-9]{64}$/.test(event.operationKey ?? '') ||
        !operationActions.includes(event.action) || !outcomes.includes(event.outcome)) continue;
    const existing = operations.get(event.operationKey) ?? {event, attempted: false, terminal: null};
    if (event.outcome === 'attempt') existing.attempted = true;
    else if (!existing.terminal || event.receivedAt < existing.terminal.receivedAt) existing.terminal = event;
    operations.set(event.operationKey, existing);
  }
  const groups = new Map();
  for (const operation of operations.values()) {
    const {event, terminal} = operation;
    const key = JSON.stringify([event.action, event.platform, event.version, event.build, event.role ?? 'unknown']);
    const group = groups.get(key) ?? {action: event.action, role: event.role ?? 'unknown', platform: event.platform, version: event.version, build: event.build,
      attempts: 0, observedAttempts: 0, outcomeWithoutAttempt: 0, success: 0, failure: 0, cancelled: 0, pending: 0};
    group.attempts++;
    if (operation.attempted) group.observedAttempts++;
    else group.outcomeWithoutAttempt++;
    group[terminal?.outcome ?? 'pending']++;
    groups.set(key, group);
  }
  return [...groups.values()].map(group => ({...group,
    failurePerAttemptRate: group.failure / group.attempts,
    completedFailureRate: group.success + group.failure ? group.failure / (group.success + group.failure) : null}));
}
