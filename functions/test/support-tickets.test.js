import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {submitSupportTicket, supportDiagnostics, supportSecretBindings, supportEmailEnvelope, sendResendEmail, deliverSupportNotification, approvedSupportRecipient} from '../src/support-tickets.js';
const now = Date.parse('2026-10-14T10:00:00Z');
const auth = {uid: 'support-owner', token: {firebase: {sign_in_provider: 'password'}}};
const payload = (id = 'request-0001') => ({accountId: auth.uid, requestId: id, message: '재생 중 문제가 발생했습니다.', replyEmail: 'reply@example.test', diagnostics: {errorId: 'event-123456', action: 'playback.start', operationId: 'operation-123', startStage: 'prepare', preparationStage: 'image'}, attachments: []});
const config = {enabled: true, provider: 'resend', recipientEmail: approvedSupportRecipient, fromEmail: 'support@example.test'};
function database() {
  const docs = new Map(); let tail = Promise.resolve();
  const snap = ref => ({ref, exists: docs.has(ref.path), data: () => structuredClone(docs.get(ref.path))});
  const db = {docs, doc: path => ({path, get: async () => snap(db.doc(path))}), runTransaction: action => {
    const task = tail.then(async () => {
      const writes = []; let writing = false;
      const tx = {get: async ref => {assert.equal(writing, false, 'read after write'); return snap(ref);},
        set: (ref, value, options) => {writing = true; writes.push(() => docs.set(ref.path, options?.merge ? {...docs.get(ref.path), ...value} : value));},
        create: (ref, value) => {writing = true; assert(!docs.has(ref.path)); writes.push(() => docs.set(ref.path, value));},
        update: (ref, value) => {writing = true; assert(docs.has(ref.path)); writes.push(() => docs.set(ref.path, {...docs.get(ref.path), ...value}));}};
      const result = await action(tx); writes.forEach(write => write()); return result;
    }); tail = task.catch(() => {}); return task;
  }};
  return db;
}
async function fixture() {
  const db = database(); const result = await submitSupportTicket({db, auth, payload: payload(), now});
  const id = [...db.docs.keys()].find(key => key.startsWith('supportNotificationOutbox/')).split('/')[1];
  return {db, result, id, options: {db, id, config, projectId: 'demo-support', now}};
}
test('diagnostics retain correlation/stages and redact private data without raw error stacks', () => {
  const clean = supportDiagnostics({...payload().diagnostics, token: 'secret', stack: 'raw', code: 'Bearer private TOKEN=secret user@example.test users/private/data', tvs: [{deviceId: 'tv-1', appVersion: '1.2.3', preparationStatus: 'failed', password: 'secret'}]});
  assert.equal(clean.operationId, 'operation-123'); assert.equal(clean.preparationStage, 'image');
  assert.doesNotMatch(JSON.stringify(clean), /private|secret|example.test|password|raw/);
  assert.equal(clean.tvs[0].preparationStatus, 'failed');
  assert.throws(() => supportDiagnostics({tvs: Array(11).fill({deviceId: 'tv'})}), {code: 'invalid-argument'});
});
test('ticket persistence atomically deduplicates owner request and outbox, preserves response on retry', async () => {
  const db = database();
  const results = await Promise.all(Array.from({length: 5}, () => submitSupportTicket({db, auth, payload: payload(), now})));
  assert.equal(results.filter(item => !item.duplicate).length, 1);
  assert.equal(db.docs.size, 3);
  assert.equal(db.docs.get(`supportRateLimits/${auth.uid}`).tickets.length, 1);
  await assert.rejects(submitSupportTicket({db, auth, payload: {...payload(), message: 'changed'}, now}), {code: 'already-exists'});
  assert.equal(db.docs.size, 3);
});
test('submission checks account/anonymous/deletion/size and hourly quota without consuming retry', async () => {
  const db = database();
  for (const [change, code] of [[{accountId: 'other'}, 'permission-denied'], [{message: 'a'.repeat(4001)}, 'invalid-argument'], [{replyEmail: 'bad\nTo: attacker@invalid.test'}, 'invalid-argument']]) await assert.rejects(submitSupportTicket({db, auth, payload: {...payload(), ...change}, now}), {code});
  await assert.rejects(submitSupportTicket({db, auth: {...auth, token: {firebase: {sign_in_provider: 'anonymous'}}}, payload: payload(), now}), {code: 'permission-denied'});
  for (let i = 0; i < 5; i++) await submitSupportTicket({db, auth, payload: payload(`request-${i}0000`), now});
  await assert.rejects(submitSupportTicket({db, auth, payload: payload('request-overflow'), now}), {code: 'resource-exhausted'});
  assert.equal((await submitSupportTicket({db, auth, payload: payload('request-00000'), now})).duplicate, true);
  db.docs.set(`accountDeletions/${auth.uid}`, {});
  await assert.rejects(submitSupportTicket({db, auth, payload: payload('request-00000'), now}), {code: 'permission-denied'});
});
test('missing email config keeps persisted ticket and retries without requiring secret deployment', async () => {
  assert.deepEqual(supportSecretBindings({}), []);
  assert.deepEqual(supportSecretBindings({SUPPORT_EMAIL_SECRETS_ENABLED: 'true'}), ['SUPPORT_EMAIL_API_KEY']);
  const {db, options} = await fixture();
  let sends = 0;
  assert.equal((await deliverSupportNotification({...options, config: {}, send: async () => {sends++;}})).claimed, false);
  const ticket = db.docs.get(`users/${auth.uid}/supportTickets/request-0001`);
  assert.equal(ticket.notificationStatus, 'retrying'); assert.equal(sends, 0);
  assert.equal(ticket.message, payload().message);
});
test('lease blocks parallel sends and retry freezes provider key/body after uncertain acceptance', async () => {
  const {db, options, id} = await fixture(); const calls = [];
  const send = async (envelope, key) => {calls.push({envelope, key}); throw new Error('response lost');};
  await Promise.all(Array.from({length: 5}, () => deliverSupportNotification({...options, send})));
  assert.equal(calls.length, 1);
  assert.equal(db.docs.get(`supportNotificationOutbox/${id}`).status, 'retrying');
  await deliverSupportNotification({...options, now: now + 60001, config: {...config, fromEmail: 'new@example.test'}, send: async (envelope, key) => {calls.push({envelope, key}); return 'provider-message-1';}});
  assert.deepEqual(calls[0], calls[1]);
  assert.equal(db.docs.get(`users/${auth.uid}/supportTickets/request-0001`).notificationStatus, 'sent');
  assert.equal((await submitSupportTicket({db, auth, payload: payload(), now})).notificationStatus, 'sent');
  await deliverSupportNotification({...options, now: now + 120000, send});
  assert.equal(calls.length, 2);
});
test('provider idempotency boundary and deletion stop further notification attempts', async () => {
  for (const deleted of [false, true]) {
    const {db, options, id} = await fixture();
    if (deleted) db.docs.set(`accountDeletions/${auth.uid}`, {});
    else Object.assign(db.docs.get(`supportNotificationOutbox/${id}`), {firstAttemptAtMs: now - 23 * 3600000, attempts: 1});
    await deliverSupportNotification({...options, send: async () => assert.fail('must not send')});
    assert.equal(db.docs.get(`supportNotificationOutbox/${id}`).status, deleted ? 'cancelled' : 'needsReview');
  }
});
test('operator email binds approved recipient, authenticates detail/log links and uses plain text', async () => {
  const {db} = await fixture();
  const ticket = db.docs.get(`users/${auth.uid}/supportTickets/request-0001`);
  const envelope = supportEmailEnvelope(ticket, config, 'demo-support');
  assert.deepEqual(envelope.to, [approvedSupportRecipient]); assert.equal(envelope.reply_to, payload().replyEmail);
  assert.equal(envelope.html, undefined); assert.match(envelope.text, /event-123456/);
  assert.match(decodeURIComponent(envelope.text), new RegExp(createHash('sha256').update(auth.uid).digest('hex').slice(0, 16)));
  for (const bad of [{enabled: false}, {recipientEmail: 'attacker@example.test'}, {fromEmail: 'x\nBcc: x@test.org'}]) assert.equal(supportEmailEnvelope(ticket, {...config, ...bad}, 'demo-support'), null);
});
test('Resend adapter sends same idempotency key, classifies uncertain responses, never leaks provider body', async () => {
  let request;
  assert.equal(await sendResendEmail({text: 'test'}, 'key', {apiKey: 'private', fetchImpl: async (url, options) => {request = {url, options}; return {ok: true, json: async () => ({id: 'mail-1'})};}}), 'mail-1');
  assert.equal(request.url, 'https://api.resend.com/emails'); assert.equal(request.options.headers['Idempotency-Key'], 'key');
  for (const response of [{ok: false, status: 503}, {ok: true, json: async () => ({})}]) await assert.rejects(sendResendEmail({}, 'key', {apiKey: 'private', fetchImpl: async () => response}), {code: 'provider-unavailable'});
  await assert.rejects(sendResendEmail({}, 'key'), {code: 'configuration-unavailable'});
});
test('crash after provider acceptance retries the frozen envelope/key after lease expiry', async () => {
  const {db, options, id} = await fixture(); const transaction = db.runTransaction; let count = 0;
  db.runTransaction = fn => ++count === 2 ? Promise.reject(new Error('Firestore response lost')) : transaction(fn);
  const calls = []; const send = async (body, key) => {calls.push({body, key}); return 'accepted-once';};
  await assert.rejects(deliverSupportNotification({...options, send}), /Firestore response lost/);
  assert.equal(db.docs.get(`supportNotificationOutbox/${id}`).status, 'processing');
  await deliverSupportNotification({...options, now: now + 120001, send});
  assert.deepEqual(calls[0], calls[1]);
  assert.equal(db.docs.get(`users/${auth.uid}/supportTickets/request-0001`).notificationStatus, 'sent');
});
test('late obsolete lease cannot replace the successful current delivery state', async () => {
  const {db, options} = await fixture(); let entered, finish;
  const started = new Promise(resolve => {entered = resolve;});
  const old = deliverSupportNotification({...options, leaseId: 'old', send: async () => {entered(); await new Promise(resolve => {finish = resolve;}); throw new Error('old failed late');}});
  await started;
  await deliverSupportNotification({...options, now: now + 120001, leaseId: 'new', send: async () => 'same-provider-id'});
  finish(); await old;
  assert.equal(db.docs.get(`users/${auth.uid}/supportTickets/request-0001`).notificationStatus, 'sent');
});
