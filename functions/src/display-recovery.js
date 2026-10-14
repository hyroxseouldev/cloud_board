import {createHash} from 'node:crypto';
import {HttpsError} from 'firebase-functions/v2/https';

export const recoveryLifetimeMs = 60_000;
const terminal = new Set(['succeeded', 'failed', 'expired']);
const keyPattern = /^[A-Za-z0-9_-]{1,128}$/;
const errorCodes = new Set(['connection_unavailable', 'permission_denied', 'connection_conflict',
  'connection_missing', 'device_unpaired', 'account_unavailable', 'request_expired',
  'request_superseded', 'latest_session_changed', 'recovery_failed', 'request_read_failed',
  'media_failed', 'response_write_failed', 'heartbeat_failed', 'cancelled', 'timeout',
  'subscription_recovery_failed', 'recovery_verification_failed']);
const fail = (code, message = 'TV 연결 상태를 확인해 주세요.', status = 'failed-precondition') => {
  throw new HttpsError(status, message, {code});
};
const key = value => typeof value === 'string' && keyPattern.test(value);
const object = value => value && typeof value === 'object' && !Array.isArray(value);
const version = value => typeof value === 'string' && /^[A-Za-z0-9.+_-]{0,64}$/.test(value) ? value : 'unknown';
const anonymous = auth => auth?.token?.firebase?.sign_in_provider === 'anonymous';
function requireActor(auth, display) {
  if (!key(auth?.uid)) fail('permission_denied', '로그인 상태를 확인해 주세요.', 'unauthenticated');
  if (anonymous(auth) !== display) fail('permission_denied', '연결된 TV 또는 매장 계정으로 실행해 주세요.', 'permission-denied');
}
function input(data, fields = ['deviceId', 'operationId']) {
  if (!object(data) || fields.some(field => !key(data[field]))) {
    fail('invalid_request', '요청 정보를 확인해 주세요.', 'invalid-argument');
  }
  return data;
}
function available(root, actorId, ownerId) {
  if (root.accountDeletions?.[actorId] || root.accountDeletions?.[ownerId]) fail('account_unavailable');
}
const fingerprint = value => typeof value === 'string' ? createHash('sha256').update(value).digest('hex') : null;
const binding = device => device ? {...Object.fromEntries(
  ['id', 'displayUid', 'paired', 'pairedAtMs'].filter(k => device[k] !== undefined)
    .map(k => [k, device[k]])), pairingCodeFingerprint: fingerprint(device.pairingCode)} : null;
const accessBinding = access => access ? {...Object.fromEntries(
  ['ownerId', 'deviceId', 'pairedAtMs'].filter(k => access[k] !== undefined)
    .map(k => [k, access[k]])), pairingCodeFingerprint: fingerprint(access.pairingCode)} : null;
function audit(root, {ownerId, deviceId, displayUid, operationId, path, before, after, data, now, status}) {
  root.displayConnectionAudit ??= {};
  const id = createHash('sha256').update(`${ownerId}:${deviceId}:${operationId}:${path}:${status || ''}`).digest('hex');
  root.displayConnectionAudit[id] ??= {schemaVersion: 1, ownerId, deviceId,
    ...(displayUid ? {displayUid} : {}), operationId, path, serverAtMs: now,
    appVersion: version(data?.appVersion), appBuild: version(data?.appBuild), before, after,
    ...(status ? {status} : {})};
}

// Called only inside the shared RTDB transaction. It never creates a deleted
// device or overwrites a different UID/owner. An authenticated TV is required
// for the sole automatic repair: a missing reverse displayUid on an existing TV.
export function resolveDisplayBinding(root, ownerId, deviceId, displayUid, {repair = false} = {}) {
  const device = root.users?.[ownerId]?.devices?.[deviceId];
  if (!device || device.paired !== true) fail('device_unpaired');
  const candidates = Object.entries(root.displayAccess || {}).filter(([, access]) =>
    access?.ownerId === ownerId && access.deviceId === deviceId);
  if (!candidates.length) fail('connection_missing');
  if (candidates.length !== 1) fail('connection_conflict');
  const [actualUid, access] = candidates[0];
  if (root.displayConnectionRevocations?.[actualUid]?.[access.pairingCode]) fail('device_unpaired');
  if (!key(actualUid) || (displayUid && actualUid !== displayUid) ||
      (device.displayUid && device.displayUid !== actualUid) || device.id !== deviceId ||
      (device.pairingCode && access.pairingCode !== device.pairingCode) ||
      (device.pairedAtMs && access.pairedAtMs && device.pairedAtMs !== access.pairedAtMs)) fail('connection_conflict');
  // Detect an old/corrupt reverse record for the same authenticated display.
  for (const [otherOwner, user] of Object.entries(root.users || {})) {
    for (const [otherDevice, value] of Object.entries(user?.devices || {})) {
      if (value?.paired === true && value.displayUid === actualUid &&
          (otherOwner !== ownerId || otherDevice !== deviceId)) fail('connection_conflict');
    }
  }
  const repaired = !device.displayUid;
  if (repaired && repair) {
    // Pairing evidence must survive on both records. A leftover access pointer
    // by itself is not permission to reconstruct identity or a removed device.
    if (!displayUid || typeof device.pairingCode !== 'string' || !/^\d{6}$/.test(device.pairingCode) ||
        device.pairingCode !== access.pairingCode) fail('connection_conflict');
    device.displayUid = actualUid;
  }
  return {device, access, displayUid: actualUid, repaired};
}

function latestSession(user) {
  const session = user.activeSession;
  if (session && (typeof session.id !== 'string' || !session.id ||
      !Number.isSafeInteger(session.revision) || session.revision < 0 ||
      !['playing', 'paused', 'completed'].includes(session.status))) fail('latest_session_changed');
  return session ? {sessionId: session.id, revision: session.revision, sessionStatus: session.status}
    : {sessionId: null, revision: 0, sessionStatus: 'idle'};
}
function operationArchive(root, ownerId, deviceId) {
  root.displayRecoveryOperations ??= {};
  root.displayRecoveryOperations[ownerId] ??= {};
  root.displayRecoveryOperations[ownerId][deviceId] ??= {};
  return root.displayRecoveryOperations[ownerId][deviceId];
}
function storeOperation(root, ownerId, deviceId, operation) {
  const user = root.users[ownerId];
  user.displayRecovery ??= {};
  user.displayRecovery[deviceId] = {current: operation};
  operationArchive(root, ownerId, deviceId)[operation.operationId] = {...operation};
}

function verifyConnection(root, auth, ownerId, deviceId, device, data, now, requestStartedAtMs, result) {
  if (!key(data.connectionId)) fail('invalid_request');
  root.displayConnectionOperations ??= {}; root.displayConnectionOperations[ownerId] ??= {};
  const operations = root.displayConnectionOperations[ownerId], previous = operations[data.operationId];
  if (previous) {
    if (previous.action !== 'verify' || previous.actorUid !== auth.uid || previous.deviceId !== deviceId || previous.connectionId !== data.connectionId) fail('invalid_request');
    if (device.connectionVerification?.connectionId !== data.connectionId) fail('request_superseded');
    return {root, result: previous.result};
  }
  // Callable timeout does not cancel its server execution. An older invocation
  // completing after a newer connection must not replace that connection's proof.
  if ((device.connectionVerification?.requestStartedAtMs || 0) > requestStartedAtMs) fail('request_superseded');
  device.connectionVerification = {connectionId: data.connectionId, operationId: data.operationId,
    verifiedAtMs: now, requestStartedAtMs, protocol: 1};
  operations[data.operationId] = {action: 'verify', actorUid: auth.uid, deviceId,
    connectionId: data.connectionId, result, serverAtMs: now};
  return {root, result};
}

export function reduceDisplayRecovery(state, auth, action, raw, now, {requestStartedAtMs = now} = {}) {
  const display = action === 'verify' || action === 'report';
  const legacyDisplay = action === 'verify' && !anonymous(auth);
  requireActor(auth, display && !legacyDisplay);
  const data = input(raw, action === 'pair' ? ['operationId'] : ['deviceId', 'operationId']);
  const root = structuredClone(state || {});
  const ownerId = display && !legacyDisplay ? root.displayAccess?.[auth.uid]?.ownerId : auth.uid;
  if (!key(ownerId)) fail('connection_missing');
  available(root, auth.uid, ownerId);
  if (action === 'pair') return pair(root, auth, data, now);
  const deviceId = data.deviceId;
  if (legacyDisplay) {
    const device = root.users?.[ownerId]?.devices?.[deviceId];
    if (!device || !(device.paired === true || (device.paired === undefined && device.pairedAtMs > 0))) fail('device_unpaired');
    if (device.displayUid || Object.values(root.displayAccess || {}).some(a => a?.ownerId === ownerId && a.deviceId === deviceId)) fail('connection_conflict');
    if (!key(data.connectionId)) fail('invalid_request');
    // Owner-authenticated installed TVs have no distinct TV identity. Preserve
    // scoped presence, but never advertise anonymous-TV manual recovery support.
    return verifyConnection(root, auth, ownerId, deviceId, device, data, now, requestStartedAtMs,
      {ownerId, deviceId, status: 'verified', verifiedAtMs: now, recoveryProtocol: 0});
  }
  if (display && root.displayAccess[auth.uid]?.deviceId !== deviceId) fail('connection_conflict');
  if (action === 'unpair') return unpair(root, ownerId, data, now);
  const original = binding(root.users?.[ownerId]?.devices?.[deviceId]);
  const resolved = resolveDisplayBinding(root, ownerId, deviceId, display ? auth.uid : null, {repair: display});
  const {device, displayUid} = resolved;
  if (resolved.repaired && display) audit(root, {ownerId, deviceId, displayUid,
    operationId: data.operationId, path: 'verified_display_repair', before: original,
    after: binding(device), data, now});
  const user = root.users[ownerId];

  if (action === 'verify') {
    if (!key(data.connectionId)) fail('invalid_request', '연결 식별자를 확인해 주세요.', 'invalid-argument');
    device.recoveryProtocol = 1;
    return verifyConnection(root, auth, ownerId, deviceId, device, data, now, requestStartedAtMs,
      {ownerId, deviceId, status: resolved.repaired ? 'repaired' : 'verified', verifiedAtMs: now, recoveryProtocol: 1});
  }
  if (action === 'request') {
    if (device.recoveryProtocol !== 1) fail('update_required', 'TV 앱을 업데이트한 뒤 다시 시도해 주세요.');
    const previous = user.displayRecovery?.[deviceId]?.current;
    const archived = operationArchive(root, ownerId, deviceId)[data.operationId];
    if (archived) return {root, result: operationArchive(root, ownerId, deviceId)[archived.operationId] || archived};
    if (previous && !terminal.has(previous.status) && previous.expiresAtMs > now && previous.displayUid === displayUid) {
      operationArchive(root, ownerId, deviceId)[data.operationId] = {...previous};
      return {root, result: previous}; // Two controllers/taps join the same operation, including later retries.
    }
    if (previous && !terminal.has(previous.status)) {
      operationArchive(root, ownerId, deviceId)[previous.operationId] = {...previous,
        status: 'expired', errorCode: 'request_expired', completedAtMs: now};
    }
    const operation = {schemaVersion: 1, deviceId, displayUid, operationId: data.operationId,
      requestedAtMs: now, expiresAtMs: now + recoveryLifetimeMs, status: 'requested'};
    storeOperation(root, ownerId, deviceId, operation);
    audit(root, {ownerId, deviceId, displayUid, operationId: data.operationId,
      path: 'owner_recovery_request', before: binding(device), after: binding(device), data, now});
    return {root, result: operation};
  }
  if (action !== 'report') fail('invalid_request');
  const operation = user.displayRecovery?.[deviceId]?.current;
  if (!operation || operation.operationId !== data.operationId || operation.displayUid !== auth.uid) fail('request_superseded');
  if (operation.expiresAtMs <= now) fail('request_expired');
  if (!['received', 'recovering', 'succeeded', 'failed'].includes(data.status)) fail('invalid_request');
  if (terminal.has(operation.status)) return {root, result: operation};
  if (data.status === 'recovering' && operation.status !== 'received' && operation.status !== 'recovering') fail('invalid_request');
  if (data.status === 'succeeded' && operation.status !== 'recovering') fail('invalid_request');
  if (data.status === 'received' && operation.status !== 'requested') return {root, result: operation};
  const latest = data.status === 'succeeded' ? latestSession(user) : null;
  const reportedSessionId = latest?.sessionStatus === 'idle' ? data.sessionId ?? null : data.sessionId;
  const reportedRevision = latest?.sessionStatus === 'idle' ? data.revision ?? 0 : data.revision;
  if (data.status === 'succeeded' && (reportedSessionId !== latest.sessionId || reportedRevision !== latest.revision)) {
    fail('latest_session_changed', '수업 상태가 바뀌었습니다. 최신 상태로 다시 연결해 주세요.');
  }
  const next = {...operation, status: data.status, updatedAtMs: now};
  if (data.status === 'received') next.receivedAtMs = now;
  if (data.status === 'succeeded') Object.assign(next, latest, {verifiedAtMs: now, completedAtMs: now});
  if (data.status === 'failed') Object.assign(next, {completedAtMs: now,
    errorCode: errorCodes.has(data.errorCode) ? data.errorCode : 'recovery_failed', errorId: data.operationId});
  storeOperation(root, ownerId, deviceId, next);
  audit(root, {ownerId, deviceId, displayUid, operationId: data.operationId,
    path: 'display_recovery_report', before: {status: operation.status}, after: {status: next.status,
      ...(next.errorCode ? {errorCode: next.errorCode} : {})}, data, now, status: data.status});
  return {root, result: next};
}

function pair(root, auth, data, now) {
  if (typeof data.code !== 'string' || !/^\d{6}$/.test(data.code) ||
      [data.name, data.zoneName].some(v => v !== undefined && (typeof v !== 'string' || v.trim().length > 60))) fail('invalid_request');
  const ownerId = auth.uid;
  root.displayConnectionOperations ??= {}; root.displayConnectionOperations[ownerId] ??= {};
  const previousOperation = root.displayConnectionOperations[ownerId][data.operationId];
  if (previousOperation) {
    if (previousOperation.action !== 'pair' || previousOperation.codeFingerprint !== fingerprint(data.code)) fail('invalid_request');
    return {root, result: previousOperation.result};
  }
  const code = root.pairingCodes?.[data.code];
  if (!code || !key(code.deviceId) || !key(code.displayUid)) fail('connection_missing');
  if ((code.claimed && code.ownerId !== ownerId) || (!code.claimed && code.expiresAtMs <= now)) fail('connection_conflict');
  const access = root.displayAccess?.[code.displayUid];
  if (!access || access.deviceId !== code.deviceId || access.pairingCode !== data.code ||
      (access.ownerId && access.ownerId !== ownerId)) fail('connection_conflict');
  if (root.displayConnectionRevocations?.[code.displayUid]?.[data.code]) fail('device_unpaired');
  available(root, code.displayUid, ownerId);
  const plan = root.subscriptionAccess?.[ownerId];
  const pilot = root.legacyPilotAccess?.[ownerId]?.validUntilMs > now;
  if (!pilot && (!plan?.managed || (plan.status !== 'pending_connection' && !(plan.validUntilMs > now)))) fail('account_unavailable');
  const modern = (plan?.plan === 'premium' && plan.displaysUnlimited === true) ||
    (plan?.plan === 'plus' && plan.displaysUnlimited === false && [1, 3].includes(plan.maxActiveDisplays)) ||
    (plan?.plan === 'free' && plan.displaysUnlimited === false && plan.maxActiveDisplays === 1 && plan.canStartClass === true);
  const limit = pilot || modern ? null : Math.min(3, Number(plan.displayLimit) || 0);
  root.users ??= {}; root.users[ownerId] ??= {}; root.users[ownerId].devices ??= {};
  const devices = root.users[ownerId].devices, previous = devices[code.deviceId];
  if (previous) {
    if (previous.displayUid !== code.displayUid || previous.paired !== true) fail('connection_conflict');
  } else {
    if (limit !== null && Object.keys(devices).length >= limit) fail('display_limit', '등록 가능한 TV 수를 확인해 주세요.', 'resource-exhausted');
    // No other device or owner may already use this UID.
    for (const [uid, user] of Object.entries(root.users)) for (const [id, item] of Object.entries(user.devices || {})) {
      if (item?.displayUid === code.displayUid && (uid !== ownerId || id !== code.deviceId)) fail('connection_conflict');
    }
    const active = Object.values(devices).filter(d => d.paired === true && (d.displayState || 'auto') === 'auto').length;
    devices[code.deviceId] = {id: code.deviceId, displayUid: code.displayUid, mode: 'display',
      name: data.name?.trim() || '매장 디스플레이', zoneId: 'main', zoneName: data.zoneName?.trim() || '메인 구역',
      paired: true, pairedAtMs: now, pairingCode: data.code, online: false, lastSeenAtMs: now,
      displayState: ['free', 'plus'].includes(plan?.plan) && active >= plan.maxActiveDisplays ? 'black' : 'auto'};
  }
  const device = devices[code.deviceId];
  root.pairingCodes[data.code] = {...code, claimed: true, ownerId, claimedAtMs: code.claimedAtMs || now};
  root.displayAccess[code.displayUid] = {...access, ownerId, pairedAtMs: device.pairedAtMs};
  audit(root, {ownerId, deviceId: code.deviceId, displayUid: code.displayUid, operationId: data.operationId,
    path: 'owner_pair', before: {device: binding(previous), access: accessBinding(access)},
    after: {device: binding(device), access: accessBinding(root.displayAccess[code.displayUid])}, data, now});
  const result = {paired: true, deviceId: code.deviceId};
  root.displayConnectionOperations[ownerId][data.operationId] = {action: 'pair',
    deviceId: code.deviceId, codeFingerprint: fingerprint(data.code), result, serverAtMs: now};
  return {root, result};
}

function unpair(root, ownerId, data, now) {
  root.displayConnectionOperations ??= {}; root.displayConnectionOperations[ownerId] ??= {};
  const previousOperation = root.displayConnectionOperations[ownerId][data.operationId];
  if (previousOperation) {
    if (previousOperation.action !== 'unpair' || previousOperation.deviceId !== data.deviceId) fail('invalid_request');
    return {root, result: previousOperation.result};
  }
  const device = root.users?.[ownerId]?.devices?.[data.deviceId];
  const result = {unpaired: true, deviceId: data.deviceId};
  root.displayConnectionOperations[ownerId][data.operationId] = {action: 'unpair', deviceId: data.deviceId, result, serverAtMs: now};
  if (!device) return {root, result};
  if (typeof data.expectedPairingCode !== 'string' || !/^\d{6}$/.test(data.expectedPairingCode)) fail('invalid_request');
  if (data.expectedPairingCode !== device.pairingCode) fail('connection_conflict');
  const mappings = Object.entries(root.displayAccess || {}).filter(([, a]) => a?.ownerId === ownerId && a.deviceId === data.deviceId);
  if (mappings.length > 1 || (mappings[0] && device.displayUid && mappings[0][0] !== device.displayUid)) fail('connection_conflict');
  // Clear only references still belonging to this exact owner/device. A code
  // reused by another screen or a transferred mapping is never removed.
  // An already-running installed server's two-step pairing can arrive after
  // this transaction. A revoked code generation must stay unauthorized even if
  // that legacy Admin write recreates both pointers. A genuinely new code is
  // still compatible with installed clients and never inherits this revocation.
  for (const [uid, access] of mappings) {
    if (typeof access.pairingCode === 'string' && /^\d{6}$/.test(access.pairingCode)) {
      root.displayConnectionRevocations ??= {}; root.displayConnectionRevocations[uid] ??= {};
      root.displayConnectionRevocations[uid][access.pairingCode] = {
        ownerId, deviceId: data.deviceId, revokedAtMs: now, operationId: data.operationId};
    }
    delete root.displayAccess[uid];
  }
  const code = root.pairingCodes?.[device.pairingCode];
  if (code?.ownerId === ownerId && code.deviceId === data.deviceId) delete root.pairingCodes[device.pairingCode];
  const legacyCode = root.users[ownerId].pairingCodes?.[device.pairingCode];
  if (legacyCode?.deviceId === data.deviceId) delete root.users[ownerId].pairingCodes[device.pairingCode];
  delete root.users[ownerId].devices[data.deviceId];
  const recovery = root.users[ownerId].displayRecovery?.[data.deviceId]?.current;
  if (recovery && !terminal.has(recovery.status)) storeOperation(root, ownerId, data.deviceId,
    {...recovery, status: 'failed', errorCode: 'device_unpaired', errorId: data.operationId, completedAtMs: now});
  audit(root, {ownerId, deviceId: data.deviceId, operationId: data.operationId, path: 'owner_unpair',
    before: binding(device), after: null, data, now});
  return {root, result};
}

export async function mutateDisplayConnection(database, auth, action, data, {now = Date.now, requestStartedAtMs = now()} = {}) {
  // Infrequent pairing/reconnection/manual operations only. A root CAS is
  // necessary because authorization and device identity live in separate trees;
  // never use this path for heartbeat or media/preparation updates.
  let result, failure;
  const transaction = await database.ref().transaction(current => {
    if (current === null) return null; // Cold admin cache: force comparison/retry.
    try {
      const reduced = reduceDisplayRecovery(current, auth, action, data, now(), {requestStartedAtMs});
      result = reduced.result; failure = null; return reduced.root;
    } catch (error) { failure = error; return undefined; }
  }, undefined, false);
  if (failure) throw failure;
  if (!transaction.committed || !result) fail('connection_missing');
  return result;
}

// Also audit identity changes from supported old clients/server functions. The
// event ID makes retries idempotent; a trigger cannot assert an unknown actor.
export async function auditDisplayBindingChange(database, event, kind) {
  const before = kind === 'device' ? binding(event.data.before.val()) : accessBinding(event.data.before.val());
  const after = kind === 'device' ? binding(event.data.after.val()) : accessBinding(event.data.after.val());
  if (JSON.stringify(before) === JSON.stringify(after)) return;
  const id = createHash('sha256').update(event.id).digest('hex');
  const data = event.data.after.val() || event.data.before.val() || {};
  await database.ref(`displayConnectionAudit/${id}`).transaction(previous => previous || {
    schemaVersion: 1, path: `database_${kind}_change`, operationId: id,
    ownerId: event.params.ownerId || after?.ownerId || before?.ownerId || 'unassigned',
    deviceId: event.params.deviceId || after?.deviceId || before?.deviceId || 'unknown',
    ...(event.params.displayUid ? {displayUid: event.params.displayUid} : {}),
    before, after, serverAtMs: Date.parse(event.time) || Date.now(),
    appVersion: version(data.appVersion), appBuild: version(data.appBuild), actor: 'unavailable_in_database_event',
  });
}
