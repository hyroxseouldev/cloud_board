import {createHash} from 'node:crypto';
import {HttpsError} from 'firebase-functions/v2/https';
import {Timestamp} from 'firebase-admin/firestore';

const keys = new Set(['action', 'role', 'platform', 'version', 'build', 'workoutId', 'sessionId', 'commandId', 'expectedRevision', 'observedRevision', 'stepIndex', 'stepCount', 'moduleIndex', 'moduleCount', 'status', 'remainingMs', 'countdownMs', 'connected', 'recovering', 'retryCount', 'elapsedMs', 'lastReceiptMs', 'ackRevision', 'firebaseCode', 'firebasePlugin']);
export function redactDiagnostic(value, max = 3000) {
  return String(value ?? '').replace(/https?:\/\/[^\s)]+/g, value => value.match(/(main\.dart\.js|dart_sdk\.js|flutter_bootstrap\.js)(:\d+(?::\d+)?)/)?.[0] ?? '[url]')
    .replace(/[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}/g, '[email]')
    .replace(/(?:(?:\+82|0)[ -]?)1[016789](?:[ -]?\d){7,8}/g, '[phone]')
    .replace(/(?:\/Users\/|\/home\/|[A-Za-z]:\\Users\\)[^\s:)]+/g, '[local-path]')
    .replace(/(?:users|displayAccess|pairingCodes)\/[^\s\]"']+/g, '[database-path]')
    .replace(/bearer\s+[A-Za-z0-9._-]+/gi, '[token]')
    .replace(/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g, '[token]')
    .replace(/(?:token|password|secret|authorization|api[_-]?key)\s*[=:]\s*[^\s,;]+/gi, '[credential]')
    .replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g, '').slice(0, max);
}
function safeContext(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  return Object.fromEntries(Object.entries(value).filter(([key, item]) => keys.has(key) && (item === null || ['string', 'number', 'boolean'].includes(typeof item)))
    .map(([key, item]) => [key, typeof item === 'string' ? redactDiagnostic(item, 160) : Number.isFinite(item) || typeof item !== 'number' ? item : null]));
}
export function validateDiagnostic(payload, now = Date.now()) {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload) || Buffer.byteLength(JSON.stringify(payload)) > 16000 ||
      typeof payload.eventId !== 'string' || !/^[a-z0-9-]{8,80}$/i.test(payload.eventId) ||
      !['error', 'fatal'].includes(payload.severity) || typeof payload.message !== 'string' ||
      typeof payload.type !== 'string' || typeof payload.code !== 'string' || typeof payload.stack !== 'string' ||
      !Array.isArray(payload.breadcrumbs) || payload.breadcrumbs.length > 15) {
    throw new HttpsError('invalid-argument', 'Invalid diagnostic payload');
  }
  const time = Date.parse(payload.occurredAt);
  if (!Number.isFinite(time) || time < now - 86400000 || time > now + 300000) throw new HttpsError('invalid-argument', 'Expired diagnostic');
  return {eventId: payload.eventId, occurredAt: new Date(time).toISOString(), severity: payload.severity,
    type: redactDiagnostic(payload.type, 100), code: redactDiagnostic(payload.code, 100),
    message: redactDiagnostic(payload.message), stack: redactDiagnostic(payload.stack, 6000),
    context: safeContext(payload.context), breadcrumbs: payload.breadcrumbs.map(safeContext)};
}

export async function recordClientDiagnostic({db, realtime, auth, payload, emit, now = Date.now()}) {
  if (!auth?.uid) throw new HttpsError('unauthenticated', 'Authentication required');
  if (payload?.accountId !== auth.uid) throw new HttpsError('permission-denied', 'Diagnostic account changed');
  const event = validateDiagnostic(payload, now);
  const anonymous = auth.token?.firebase?.sign_in_provider === 'anonymous';
  if (anonymous && !(await realtime.ref(`displayAccess/${auth.uid}/ownerId`).get()).exists()) {
    throw new HttpsError('permission-denied', 'Paired display required');
  }
  // Single bounded document per account: no unlimited event-ID document creation.
  const ref = db.doc(`clientDiagnosticLimits/${auth.uid}`);
  const accepted = await db.runTransaction(async tx => {
    const [limit, deletion] = await Promise.all([tx.get(ref), tx.get(db.doc(`accountDeletions/${auth.uid}`))]);
    if (deletion.exists) throw new HttpsError('permission-denied', 'Account is being deleted');
    const previous = limit.data() ?? {};
    const recent = Array.isArray(previous.events) ? previous.events.filter(e => e.at > now - 86400000).slice(-100) : [];
    if (recent.some(e => e.id === event.eventId)) return false;
    const sameWindow = previous.window === Math.floor(now / 60000);
    const count = sameWindow ? previous.count ?? 0 : 0;
    if (count >= 20) throw new HttpsError('resource-exhausted', 'Diagnostic rate limit');
    tx.set(ref, {window: Math.floor(now / 60000), count: count + 1,
      events: [...recent, {id: event.eventId, at: now}].slice(-100), expiresAt: Timestamp.fromMillis(now + 86400000)});
    return true;
  });
  if (accepted) emit('client_diagnostic', {...event, accountHash: createHash('sha256').update(auth.uid).digest('hex').slice(0, 16), role: anonymous ? 'display' : 'account'});
  return {accepted, eventId: event.eventId};
}

// Bound request-dedup metadata to 24–48h; logs follow the project's Logging retention.
export async function cleanupDiagnosticLimits(db, now = Date.now()) {
  let removed = 0;
  for (let page = 0; page < 4; page++) {
    const expired = await db.collection('clientDiagnosticLimits').where('expiresAt', '<=', Timestamp.fromMillis(now)).limit(250).get();
    if (expired.empty) break;
    // Re-read under transaction: a new event can renew a document during cleanup.
    for (const doc of expired.docs) {
      removed += await db.runTransaction(async tx => {
        const current = await tx.get(doc.ref);
        if (!current.exists || current.data().expiresAt?.toMillis() > now) return 0;
        tx.delete(doc.ref);
        return 1;
      });
    }
    if (expired.size < 250) break;
  }
  return removed;
}
