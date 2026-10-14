import test from 'node:test';
import assert from 'node:assert/strict';
import {validateOperation, recordOperation, summarizeOperations} from '../src/operation-telemetry.js';
const now = Date.parse('2026-10-12T00:00:00Z');
const event = (id = 'a'.repeat(32), outcome = 'attempt') => ({accountId: 'user', operationId: id,
  action: 'workout.save', outcome, startedAt: new Date(now).toISOString(), occurredAt: new Date(now).toISOString(),
  durationMs: 0, platform: 'ios', version: '1.0.0', build: '553'});
const database = () => {const docs = new Map(); return {docs, doc: path => path,
  runTransaction: fn => fn({get: async path => ({exists: docs.has(path), data: () => docs.get(path)}), set: (path, data) => docs.set(path, data)})};};
test('operation metadata has bounded dimensions and never accepts content or private strings', () => {
  assert.equal(validateOperation(event(), now).accountId, undefined);
  assert.equal(validateOperation({...event(), platform: 'web', build: '142.1'}, now).build, '142.1');
  for (const payload of [null, {...event(), workoutText: 'private'}, {...event(), role: 'display'}, {...event(), build: '123456789012345678901'}, {...event(), operationId: 'email@example.com'},
    {...event(), version: 'private@example.com'}, {...event(), build: 'private'}, {...event(), platform: 'custom'},
    {...event(), code: 'token=secret'}, {...event(), durationMs: 86400001}, {...event(), durationMs: 1},
    {...event(), startedAt: '2020-01-01'}, {...event(), occurredAt: '2030-01-01'}]) {
    assert.throws(() => validateOperation(payload, now), {code: 'invalid-argument'});
  }
});
test('operation recording binds account, deduplicates attempts/terminal retries and rejects rewritten metadata', async () => {
  const db = database(), logs = [];
  const record = (payload, auth = {uid: 'user', token: {}}) => recordOperation({db, auth, payload, emit: e => logs.push(e), now});
  await assert.rejects(record(event(), null), {code: 'unauthenticated'});
  await assert.rejects(record({...event(), accountId: 'other'}), {code: 'permission-denied'});
  assert.equal((await record(event())).accepted, true);
  assert.equal((await record(event())).accepted, false);
  assert.equal((await record(event('a'.repeat(32), 'success'))).accepted, true);
  assert.equal((await record(event('a'.repeat(32), 'failure'))).accepted, false);
  await assert.rejects(record({...event(), action: 'playback.control.submit'}), {code: 'invalid-argument'});
  assert.equal(logs.length, 2); assert.equal(logs[0].operationKey, logs[1].operationKey);
  assert.equal(logs[0].accountId, undefined); assert.equal(logs[0].accountHash, undefined); assert.equal(logs[0].role, 'account');
  assert.equal(db.docs.size, 1);
  db.docs.set('accountDeletions/user', {});
  await assert.rejects(record(event('b'.repeat(32))), {code: 'permission-denied'});
});
test('paired display requirement and per-minute/daily limits apply before logging', async () => {
  const auth = {uid: 'user', token: {firebase: {sign_in_provider: 'anonymous'}}};
  for (const paired of [false, true]) {
    const task = recordOperation({db: database(), realtime: {ref: () => ({get: async () => ({exists: () => paired})})},
      auth, payload: event(), emit: () => {}, now});
    if (paired) await task; else await assert.rejects(task, {code: 'permission-denied'});
  }
  for (const previous of [{minute: Math.floor(now / 60000), count: 120}, {day: Math.floor(now / 86400000), daily: 4096}]) {
    const db = database(); db.docs.set('operationTelemetryLimits/user', previous);
    await assert.rejects(recordOperation({db, auth: {uid: 'user'}, payload: event(), emit: () => assert.fail('rate limited event emitted'), now}), {code: 'resource-exhausted'});
  }
});
test('aggregation never infers success from a pending attempt and survives missing/reordered/duplicate events', () => {
  const log = (id, outcome) => ({...event(id.repeat(32), outcome), message: 'operation_telemetry', operationKey: id.repeat(64), receivedAt: new Date(now).toISOString()});
  const success = log('a', 'success'), failure = log('b', 'failure'), pending = log('c', 'attempt'), cancelled = log('d', 'cancelled');
  const [result] = summarizeOperations([success, success, log('a', 'attempt'), failure, pending, cancelled]);
  assert.equal(result.attempts, 4); assert.equal(result.observedAttempts, 2);
  assert.equal(result.outcomeWithoutAttempt, 2); assert.equal(result.success, 1);
  assert.equal(result.failure, 1); assert.equal(result.pending, 1); assert.equal(result.cancelled, 1);
  assert.equal(result.failurePerAttemptRate, .25); assert.equal(result.completedFailureRate, .5);
  assert.equal(summarizeOperations([pending])[0].completedFailureRate, null);
  assert.equal(summarizeOperations([pending])[0].success, 0);
  assert.deepEqual(summarizeOperations([{...pending, message: 'client_diagnostic'}]), []);
  const other = {...log('e', 'success'), platform: 'android', build: '65'};
  assert.equal(summarizeOperations([success, other]).length, 2);
  assert.equal(summarizeOperations([{...success, role: 'account'}, {...other, platform: 'ios', build: '553', role: 'display'}]).length, 2);
});

test('quota funnel and purchase actions retain privacy and dedupe contract',()=>{
  for(const action of ['slides.save','workout.import','plan.upgrade.purchase', ...['workouts','savedSlides'].flatMap(r=>['usage','limit','manage','upgrade'].map(s=>`plan.${r}.${s}`))]) {
    assert.equal(validateOperation({...event(),action},now).action,action);
    assert.throws(()=>validateOperation({...event(),action,email:'private@example.com'},now),{code:'invalid-argument'});
  }
});

test('preparation stages have bounded failure codes and reject private payload dimensions', () => {
  for (const [action, code] of [
    ['tv.prepare.request', 'prepare_request'],
    ['tv.prepare.receipts', 'prepare_receipts'],
    ['tv.prepare.listen', 'prepare_listen'],
    ...['prepare_images', 'prepare_audio', 'prepare_response'].map(code => ['tv.prepare', code]),
  ]) {
    const payload = {...event(), action, outcome: 'failure', code};
    assert.equal(validateOperation(payload, now).code, code);
    assert.throws(() => validateOperation({...payload, deviceId: 'private-device'}, now), {code: 'invalid-argument'});
    assert.throws(() => validateOperation({...payload, code: 'database/private-user/secret'}, now), {code: 'invalid-argument'});
  }
});
