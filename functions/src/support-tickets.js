import {createHash, randomUUID} from 'node:crypto';
import {HttpsError} from 'firebase-functions/v2/https';
import {redactDiagnostic} from './client-diagnostics.js';
import {AppBrand} from './config/app-brand.js';

const HOUR = 3600000, DAY = 24 * HOUR, NEVER = Number.MAX_SAFE_INTEGER;
const idPattern = /^[A-Za-z0-9_-]{8,80}$/;
const emailPattern = /^[^\s<>@\r\n]+@[^\s<>@\r\n]+\.[^\s<>@\r\n]+$/;
const imageTypes = new Set(['image/png', 'image/jpeg', 'image/webp']);
export const supportLimits = Object.freeze({message: 4000, attachmentBytes: 5 * 1024 * 1024, hourly: 5, daily: 20});
export const approvedSupportRecipient = 'vividxxxxx@gmail.com';
const keys = new Set(['errorId', 'occurredAtMs', 'action', 'role', 'platform', 'version', 'build', 'workoutId', 'sessionId', 'commandId', 'operationId', 'startStage', 'preparationStage', 'expectedRevision', 'observedRevision', 'stepIndex', 'stepCount', 'moduleIndex', 'moduleCount', 'status', 'remainingMs', 'countdownMs', 'connected', 'recovering', 'retryCount', 'elapsedMs', 'lastReceiptMs', 'ackRevision', 'firebaseCode', 'firebasePlugin', 'code']);
const tvKeys = new Set(['deviceId', 'appVersion', 'appBuild', 'appPlatform', 'online', 'paired', 'preparationStatus', 'preparationRevision', 'checkedAtMs', 'imageCount', 'audioReady']);
const hash = value => createHash('sha256').update(value).digest('hex');
const stable = value => JSON.stringify(value, (_, item) => item && typeof item === 'object' && !Array.isArray(item) ? Object.fromEntries(Object.entries(item).sort(([a], [b]) => a.localeCompare(b))) : item);
const fail = (code, message) => { throw new HttpsError(code, message); };
const ticketRef = (db, uid, id) => db.doc(`users/${uid}/supportTickets/${id}`);
const permitRef = (db, uid, id) => db.doc(`users/${uid}/supportUploads/${id}`);
const outboxId = (uid, id) => hash(`${uid}/${id}`);
const response = (ticket, duplicate) => ({ticketId: ticket.requestId, ticketNumber: ticket.ticketNumber, receivedAtMs: ticket.receivedAtMs, notificationStatus: ticket.notificationStatus, duplicate});
function identity(auth, payload) {
  if (!auth?.uid) fail('unauthenticated', 'Authentication required');
  if (auth.token?.firebase?.sign_in_provider === 'anonymous' || payload?.accountId !== auth.uid) fail('permission-denied', 'Account changed or owner sign-in required');
  if (typeof auth.uid !== 'string' || auth.uid.includes('/') || typeof payload?.requestId !== 'string' || !idPattern.test(payload.requestId)) fail('invalid-argument', 'Invalid request identifier');
  return auth.uid;
}
async function checkDeletion(tx, db, uid) {
  const [lock, billing] = await Promise.all([tx.get(db.doc(`accountDeletions/${uid}`)), tx.get(db.doc(`billingAccounts/${uid}`))]);
  if (lock.exists || billing.data()?.deleted === true) fail('permission-denied', 'Account is being deleted');
}
function quota(previous, now) {
  const recent = Array.isArray(previous) ? previous.filter(at => Number.isSafeInteger(at) && at > now - DAY) : [];
  if (recent.length >= supportLimits.daily || recent.filter(at => at > now - HOUR).length >= supportLimits.hourly) fail('resource-exhausted', 'Support request limit reached');
  return [...recent, now];
}
function fields(value, allowed) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  return Object.fromEntries(Object.entries(value).filter(([key, item]) => allowed.has(key) && (typeof item === 'boolean' || typeof item === 'string' || (typeof item === 'number' && Number.isFinite(item))))
    .map(([key, item]) => [key, typeof item === 'string' ? redactDiagnostic(item, 160) : item]));
}
export function supportDiagnostics(value) {
  const result = fields(value, keys);
  if (result.errorId != null && (typeof result.errorId !== 'string' || !idPattern.test(result.errorId))) delete result.errorId;
  if (Array.isArray(value?.tvs)) {
    if (value.tvs.length > 10) fail('invalid-argument', 'Too many displays');
    result.tvs = value.tvs.map(tv => fields(tv, tvKeys));
    if (result.tvs.some(tv => typeof tv.deviceId !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(tv.deviceId))) fail('invalid-argument', 'Invalid display identifier');
  }
  return result;
}

// Separate quota/permit prevents abandoned uploads from bypassing ticket limits.
export async function prepareSupportAttachment({db, auth, payload, now = Date.now()}) {
  const uid = identity(auth, payload);
  const {requestId, fileId, contentType, sizeBytes, sha256} = payload;
  if (typeof fileId !== 'string' || !idPattern.test(fileId) || !imageTypes.has(contentType) || !Number.isSafeInteger(sizeBytes) || sizeBytes < 1 || sizeBytes > supportLimits.attachmentBytes || !/^[a-f0-9]{64}$/.test(sha256 ?? '')) fail('invalid-argument', 'Invalid screenshot');
  const path = `users/${uid}/support/${requestId}/${fileId}`;
  const fingerprint = hash(stable({path, contentType, sizeBytes, sha256}));
  const ref = permitRef(db, uid, requestId), rate = db.doc(`supportRateLimits/${uid}`);
  await db.runTransaction(async tx => {
    const [existing, limit, ticket] = await Promise.all([tx.get(ref), tx.get(rate), tx.get(ticketRef(db, uid, requestId))]);
    await checkDeletion(tx, db, uid);
    if (existing.exists) {
      if (existing.data().fingerprint !== fingerprint) fail('already-exists', 'Screenshot request changed');
      if (existing.data().status !== 'ready') fail('failed-precondition', 'Screenshot expired; start a new request');
      if (!ticket.exists) tx.update(ref, {expiresAtMs: now + 15 * 60000, cleanupAtMs: now + DAY});
      return;
    }
    if (ticket.exists) fail('already-exists', 'Ticket already received');
    tx.set(rate, {uploads: quota(limit.data()?.uploads, now)}, {merge: true});
    tx.create(ref, {ownerId: uid, requestId, path, contentType, sizeBytes, sha256, fingerprint, status: 'ready', createdAtMs: now, expiresAtMs: now + 15 * 60000, cleanupAtMs: now + DAY});
  });
  return {path};
}
function imageSignature(bytes, type) {
  if (type === 'image/png') return bytes.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10]));
  if (type === 'image/jpeg') return bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255;
  return bytes.toString('ascii', 0, 4) === 'RIFF' && bytes.toString('ascii', 8, 12) === 'WEBP';
}
async function attachmentInfo({db, bucket, uid, requestId, path}) {
  const prefix = `users/${uid}/support/${requestId}/`;
  if (typeof path !== 'string' || !path.startsWith(prefix) || !idPattern.test(path.slice(prefix.length))) fail('permission-denied', 'Screenshot ownership mismatch');
  const permit = (await permitRef(db, uid, requestId).get()).data();
  if (!permit || permit.status !== 'ready' || permit.path !== path) fail('failed-precondition', 'Screenshot upload not prepared');
  const file = bucket.file(path);
  let metadata;
  try { [metadata] = await file.getMetadata(); } catch (error) {
    if (Number(error.code) === 404) fail('failed-precondition', 'Screenshot upload not complete');
    throw error;
  }
  if (Number(metadata.size) !== permit.sizeBytes || metadata.contentType !== permit.contentType || metadata.metadata?.sha256 !== permit.sha256 || Number(metadata.size) > supportLimits.attachmentBytes) fail('invalid-argument', 'Screenshot metadata mismatch');
  // Bounded download validates bytes, not just client-controlled MIME/metadata.
  const [bytes] = await file.download();
  if (bytes.length !== permit.sizeBytes || hash(bytes) !== permit.sha256 || !imageSignature(bytes, permit.contentType)) fail('invalid-argument', 'Invalid screenshot bytes');
  if (metadata.metadata?.firebaseStorageDownloadTokens) await file.setMetadata({metadata: {...metadata.metadata, firebaseStorageDownloadTokens: null}});
  return {path, contentType: permit.contentType, sizeBytes: permit.sizeBytes, sha256: permit.sha256};
}
export async function submitSupportTicket({db, realtime, bucket, auth, payload, now = Date.now()}) {
  const uid = identity(auth, payload), requestId = payload.requestId;
  if (Buffer.byteLength(JSON.stringify(payload)) > 24000 || typeof payload.message !== 'string' || !payload.message.trim() || payload.message.length > supportLimits.message || typeof payload.replyEmail !== 'string' || payload.replyEmail.length > 254 || !emailPattern.test(payload.replyEmail.trim()) || !Array.isArray(payload.attachments) || payload.attachments.length > 1) fail('invalid-argument', 'Invalid support request');
  const normalized = {message: payload.message.trim(), replyEmail: payload.replyEmail.trim(), diagnostics: supportDiagnostics(payload.diagnostics), attachments: payload.attachments.map(item => ({path: typeof item?.path === 'string' ? item.path : ''}))};
  const fingerprint = hash(stable(normalized)), ref = ticketRef(db, uid, requestId);
  const existing = await db.runTransaction(async tx => {
    const current = await tx.get(ref);
    await checkDeletion(tx, db, uid);
    if (!current.exists) return null;
    if (current.data().fingerprint !== fingerprint) fail('already-exists', 'Support request changed; use a new request identifier');
    return response(current.data(), true);
  });
  if (existing) return existing;
  // Retry of an acknowledged request must not depend on a TV still being paired.
  for (const tv of normalized.diagnostics.tvs ?? []) {
    if (!(await realtime.ref(`users/${uid}/devices/${tv.deviceId}`).get()).exists()) fail('permission-denied', 'Display ownership mismatch');
  }
  const attachments = [];
  for (const item of normalized.attachments) attachments.push(await attachmentInfo({db, bucket, uid, requestId, path: item.path}));
  return db.runTransaction(async tx => {
    const rate = db.doc(`supportRateLimits/${uid}`);
    const [current, limit, permit] = await Promise.all([tx.get(ref), tx.get(rate), tx.get(permitRef(db, uid, requestId))]);
    await checkDeletion(tx, db, uid);
    if (current.exists) {
      if (current.data().fingerprint !== fingerprint) fail('already-exists', 'Support request changed');
      return response(current.data(), true);
    }
    if (attachments.length && (permit.data()?.status !== 'ready' || permit.data()?.path !== attachments[0].path)) fail('failed-precondition', 'Screenshot expired');
    const ticket = {schemaVersion: 1, ownerId: uid, requestId, fingerprint, ticketNumber: `CB-${outboxId(uid, requestId).slice(0, 12).toUpperCase()}`, receivedAtMs: now, notificationStatus: 'queued', ...normalized, attachments};
    tx.set(rate, {tickets: quota(limit.data()?.tickets, now)}, {merge: true});
    tx.create(ref, ticket);
    tx.create(db.doc(`supportNotificationOutbox/${outboxId(uid, requestId)}`), {ownerId: uid, requestId, ticketPath: ref.path, status: 'queued', attempts: 0, createdAtMs: now, nextAttemptAtMs: now, leaseUntilMs: 0, providerKey: `support/${outboxId(uid, requestId)}`});
    if (attachments.length) tx.update(permitRef(db, uid, requestId), {submitted: true, cleanupAtMs: NEVER});
    return response(ticket, false);
  });
}

// An opt-in deploy setting avoids requiring a not-yet-created Secret Manager key.
export function supportSecretBindings(env = process.env) {
  return env.SUPPORT_EMAIL_SECRETS_ENABLED === 'true' ? ['SUPPORT_EMAIL_API_KEY'] : [];
}
export function supportEmailConfigured(config, projectId) {
  return config?.enabled === true && config?.provider === 'resend' &&
    config?.recipientEmail === approvedSupportRecipient && emailPattern.test(config?.fromEmail ?? '') &&
    /^[a-z0-9-]+$/.test(projectId ?? '');
}
export function supportEmailEnvelope(ticket, config, projectId) {
  if (!supportEmailConfigured(config, projectId)) return null;
  const detail = `https://console.firebase.google.com/project/${projectId}/firestore/databases/-default-/data/~2F${ticketPathForConsole(ticket)}`;
  const query = `jsonPayload.message="client_diagnostic" AND jsonPayload.accountHash="${hash(ticket.ownerId).slice(0, 16)}"${ticket.diagnostics.errorId ? ` AND jsonPayload.eventId="${ticket.diagnostics.errorId}"` : ''}`;
  const logs = `https://console.cloud.google.com/logs/query;query=${encodeURIComponent(query)}?project=${projectId}`;
  return {from: `${AppBrand.name} <${config.fromEmail}>`, to: [approvedSupportRecipient], reply_to: ticket.replyEmail,
    subject: `[${AppBrand.name}] 문의 ${ticket.ticketNumber}`,
    text: [`접수 번호: ${ticket.ticketNumber}`, `접수 시각: ${new Date(ticket.receivedAtMs).toISOString()}`, `답장 주소: ${ticket.replyEmail}`, '', ticket.message, '', '진단 정보 (클라이언트가 제공한 당시 상태):', JSON.stringify(ticket.diagnostics, null, 2), '', `인증된 운영자 상세: ${detail}`, `서버 진단 로그 검색 (로그가 수집된 경우): ${logs}`, ...ticket.attachments.map(item => `첨부 (운영자 인증 필요, 공개 링크 없음): ${item.path}`)].join('\n')};
}
function ticketPathForConsole(ticket) { return ['users', ticket.ownerId, 'supportTickets', ticket.requestId].map(encodeURIComponent).join('~2F'); }
export async function sendResendEmail(envelope, idempotencyKey, {apiKey, fetchImpl = fetch} = {}) {
  if (!apiKey) throw Object.assign(new Error('Email is not configured'), {code: 'configuration-unavailable'});
  let response;
  try {
    response = await fetchImpl('https://api.resend.com/emails', {method: 'POST', headers: {Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json', 'Idempotency-Key': idempotencyKey}, body: JSON.stringify(envelope), signal: AbortSignal.timeout(20000)});
  } catch { throw Object.assign(new Error('Email provider unavailable'), {code: 'provider-unavailable'}); }
  if (!response.ok) throw Object.assign(new Error('Email provider rejected request'), {code: response.status >= 500 || response.status === 429 ? 'provider-unavailable' : 'provider-rejected'});
  let body;
  try { body = await response.json(); } catch { /* An uncertain response retries the same key/envelope. */ }
  if (typeof body?.id !== 'string' || !body.id) throw Object.assign(new Error('Email provider response uncertain'), {code: 'provider-unavailable'});
  return body.id;
}

// The transaction persists the immutable envelope before the external call. A
// lease serializes callbacks; the provider key covers a crash after acceptance.
export async function deliverSupportNotification({db, id, send, config, projectId, now = Date.now(), leaseId = randomUUID()}) {
  const ref = db.doc(`supportNotificationOutbox/${id}`);
  const claim = await db.runTransaction(async tx => {
    const snapshot = await tx.get(ref), data = snapshot.data();
    if (!data || ['sent', 'cancelled', 'needsReview'].includes(data.status) || data.nextAttemptAtMs > now || data.leaseUntilMs > now) return null;
    const ticket = await tx.get(db.doc(data.ticketPath));
    const [deletion, billing] = await Promise.all([tx.get(db.doc(`accountDeletions/${data.ownerId}`)), tx.get(db.doc(`billingAccounts/${data.ownerId}`))]);
    if (!ticket.exists || deletion.exists || billing.data()?.deleted) { tx.update(ref, {status: 'cancelled', nextAttemptAtMs: NEVER}); return null; }
    if (data.attempts >= 8 || (data.firstAttemptAtMs != null && now - data.firstAttemptAtMs >= 23 * HOUR)) {
      tx.update(ref, {status: 'needsReview', leaseUntilMs: 0, nextAttemptAtMs: NEVER});
      tx.update(ticket.ref, {notificationStatus: 'retrying'});
      return null;
    }
    // Config is checked on every attempt: disabling mail also stops old envelopes.
    const enabledEnvelope = supportEmailEnvelope(ticket.data(), config, projectId);
    if (!enabledEnvelope || !send) {
      tx.update(ref, {status: 'retrying', leaseUntilMs: 0, nextAttemptAtMs: now + 15 * 60000, lastErrorCode: 'configuration-unavailable'});
      tx.update(ticket.ref, {notificationStatus: 'retrying'});
      return null;
    }
    const envelope = data.envelope ?? enabledEnvelope;
    tx.update(ref, {status: 'processing', envelope, leaseId, leaseUntilMs: now + 120000, nextAttemptAtMs: now + 120000, attempts: data.attempts + 1, firstAttemptAtMs: data.firstAttemptAtMs ?? now});
    return {...data, envelope, attempts: data.attempts + 1};
  });
  if (!claim) return {claimed: false};
  // Close the common deletion race before making an irreversible external call.
  if ((await db.doc(`accountDeletions/${claim.ownerId}`).get()).exists) return {claimed: true, cancelled: true};
  let providerId = null, errorCode = null;
  try { providerId = await send(claim.envelope, claim.providerKey); if (typeof providerId !== 'string' || !providerId) errorCode = 'provider-unavailable'; }
  catch (error) { errorCode = ['configuration-unavailable', 'provider-rejected'].includes(error.code) ? error.code : 'provider-unavailable'; }
  const sent = !errorCode;
  await db.runTransaction(async tx => {
    const [current, ticket] = await Promise.all([tx.get(ref), tx.get(db.doc(claim.ticketPath))]);
    if (!current.exists || current.data().leaseId !== leaseId || !ticket.exists) return;
    tx.update(ref, {status: sent ? 'sent' : 'retrying', leaseUntilMs: 0, nextAttemptAtMs: sent ? NEVER : now + Math.min(6 * HOUR, 60000 * 2 ** (claim.attempts - 1)), ...(sent ? {providerId, sentAtMs: now} : {lastErrorCode: errorCode})});
    tx.update(ticket.ref, {notificationStatus: sent ? 'sent' : 'retrying'});
  });
  return {claimed: true, sent};
}
export async function retrySupportNotifications(options) {
  // Keep queued tickets intact until delivery is configured. No polling or
  // status writes while mail is disabled, including manual invocations.
  if (typeof options.send !== 'function' || !supportEmailConfigured(options.config, options.projectId)) return 0;
  const now = options.now ?? Date.now();
  const due = await options.db.collection('supportNotificationOutbox').where('nextAttemptAtMs', '<=', now).limit(20).get();
  for (const doc of due.docs) await deliverSupportNotification({...options, id: doc.id, now});
  return due.size;
}
export async function deleteSupportData(db, uid) {
  for (;;) {
    const docs = await db.collection('supportNotificationOutbox').where('ownerId', '==', uid).limit(200).get();
    if (docs.empty) break;
    const batch = db.batch();
    for (const doc of docs.docs) batch.delete(doc.ref);
    await batch.commit();
  }
  await db.doc(`supportRateLimits/${uid}`).delete();
}
export async function cleanupSupportUploads({db, bucket, now = Date.now()}) {
  const due = await db.collectionGroup('supportUploads').where('cleanupAtMs', '<=', now).limit(100).get();
  let count = 0;
  for (const doc of due.docs) {
    const path = await db.runTransaction(async tx => {
      const current = await tx.get(doc.ref), value = current.data();
      if (!value || value.submitted || value.cleanupAtMs > now) return null;
      tx.update(doc.ref, {status: 'deleting'});
      return value.path;
    });
    if (!path) continue;
    await bucket.file(path).delete({ignoreNotFound: true});
    await doc.ref.delete();
    count++;
  }
  return count;
}
