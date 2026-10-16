import test from 'node:test';
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {once} from 'node:events';
import {buildWebhookPayload, deliverWebhook, productionProjectId} from '../src/operation-event-webhook.js';

const input = {
  projectId: productionProjectId, ownerId: 'owner-1', eventId: 'event-path-1',
  receivedAtMs: 1792200000000,
  event: {type: 'playback_started', occurredAtMs: 1792199999000,
    workoutId: 'workout-1', workoutName: '테스트 수업', sessionId: 'session-1',
    deviceId: 'display-1', deviceName: '메인 TV', deviceRole: 'display',
    appVersion: '1.3.2+7', phase: 'server_approval', targetDeviceIds: ['display-1']},
};
const payload = buildWebhookPayload(input);
const connection = {payload, key: 'fake-secret-key', url: 'https://receiver.example/hooks'};

test('four-field contract, accurate start/end semantics and stable path identity', () => {
  assert.deepEqual(Object.keys(payload).sort(), ['event_id', 'message', 'status', 'title']);
  assert.match(payload.event_id, /^[0-9a-f]{64}$/u);
  assert.match(payload.title, /서버 승인/u);
  assert.match(payload.message, /실제 TV 재생 여부는 이 기록만으로 확인되지 않습니다/u);
  assert.match(payload.message, /환경: production/u);
  assert.match(payload.message, /원본 유형: playback_started/u);
  assert.match(payload.message, /센터명: 알 수 없음/u);
  assert.match(payload.message, /서버 이벤트 시각 \(UTC\): 2026-/u);
  assert.equal(buildWebhookPayload({...input, receivedAtMs: 123,
    event: {...input.event, eventId: 'client-spoof', id: 'other', occurredAtMs: 123}}).event_id, payload.event_id);
  assert.notEqual(buildWebhookPayload({...input, ownerId: 'owner-2'}).event_id, payload.event_id);
  assert.notEqual(buildWebhookPayload({...input, eventId: 'event-path-2'}).event_id, payload.event_id);
  const completed = buildWebhookPayload({...input, event: {type: 'playback_completed'}});
  assert.equal(completed.title, '수업 종료 기록');
  assert.match(completed.message, /정상 완주 여부는 이 기록만으로 확인되지 않습니다/u);
});

test('all supported production event types have titles; malformed/unsupported events are ignored', () => {
  for (const type of ['playback_started', 'playback_completed', 'command_failed',
    'command_receipt_failed', 'playback_interrupted', 'playback_restored',
    'connection_failed', 'connection_recovered', 'device_online', 'device_offline', 'device_shutdown']) {
    assert.ok(buildWebhookPayload({...input, event: {type}})?.title);
  }
  for (const override of [{projectId: 'cloud-board-development'}, {projectId: 'other-project'},
    {ownerId: ''}, {ownerId: 'person@example.com'}, {eventId: 'wrong/path'},
    {eventId: ''}, {event: null}, {event: []}, {event: {}}, {event: {type: 'briefing_opened'}}]) {
    assert.equal(buildWebhookPayload({...input, ...override}), null);
  }
  assert.equal(buildWebhookPayload(), null);
});

test('only allowlisted metadata survives; email/raw errors/secrets are not forwarded', () => {
  const result = buildWebhookPayload({...input, event: {...input.event,
    email: 'private@example.com', phone: '010-9876-5432', rawPayload: {token: 'RAW_SECRET'},
    error: 'FULL_ERROR_SECRET', stack: 'STACK_SECRET', authorization: 'SECRET_HEADER',
    ownerId: 'spoofed-owner', workoutName: '수업 person@example.com',
    deviceName: 'TV\nBearer LEAKED_TOKEN', errorCode: 'error with private@example.com',
    targetDeviceNames: {arbitrary: 'private@example.com'},
  }});
  const text = JSON.stringify(result);
  for (const secret of ['private@example.com', 'person@example.com', '010-9876-5432',
    'RAW_SECRET', 'FULL_ERROR_SECRET', 'STACK_SECRET', 'SECRET_HEADER', 'LEAKED_TOKEN', 'spoofed-owner']) {
    assert.ok(!text.includes(secret));
  }
  assert.match(result.message, /센터 계정 ID: owner-1/u);
  assert.match(result.message, /이메일 제외/u);
  assert.match(result.message, /인증정보 제외/u);
});

test('unknown fields are explicit and size is bounded without coercing object values', () => {
  const unknown = buildWebhookPayload({...input, event: {
    type: 'connection_failed', occurredAtMs: 'yesterday', workoutName: {private: 'SECRET'},
    deviceRole: '__proto__', playbackImpact: 'constructor',
  }});
  assert.match(unknown.message, /발생 시각 \(UTC\): 알 수 없음/u);
  assert.match(unknown.message, /기기 역할: 알 수 없음/u);
  assert.match(unknown.message, /재생 영향: 알 수 없음/u);
  assert.ok(!unknown.message.includes('SECRET'));
  const bounded = buildWebhookPayload({...input, event: {...input.event,
    workoutName: '가'.repeat(10000), deviceName: '나'.repeat(10000),
    targetDeviceIds: Array.from({length: 100}, (_, i) => `device-${i}`),
  }});
  assert.match(bounded.message, /100대/u);
  assert.match(bounded.message, /최대 20개 표시/u);
  assert.ok(!bounded.message.includes('device-20'));
  assert.ok(bounded.message.length <= 6000);
});

test('successful POST uses Bearer, strict redirect policy, exact contract and cancels response', async () => {
  let cancelled = 0;
  const result = await deliverWebhook({...connection, fetchImpl: async (url, options) => {
    assert.equal(url, connection.url);
    assert.equal(options.method, 'POST');
    assert.equal(options.redirect, 'error');
    assert.equal(options.headers.Authorization, 'Bearer fake-secret-key');
    assert.equal(options.headers['Content-Type'], 'application/json');
    assert.deepEqual(JSON.parse(options.body), payload);
    assert.ok(options.signal instanceof AbortSignal);
    return {status: 202, body: {cancel: async () => { cancelled++; }},
      text() { throw new Error('must never read receiver response'); }};
  }});
  assert.deepEqual(result, {outcome: 'delivered', status: 202});
  assert.equal(cancelled, 1);
});

test('all 2xx accepted, permanent 4xx and redirect status dropped without body reads', async () => {
  for (const status of [200, 204, 299, 301, 400, 401, 403, 404, 409, 422, 499]) {
    let cancelled = false;
    assert.deepEqual(await deliverWebhook({...connection, fetchImpl: async () => ({status,
      body: {cancel: async () => { cancelled = true; }}})}),
    {outcome: status < 300 ? 'delivered' : 'dropped', status});
    assert.equal(cancelled, true);
  }
});

test('retryable HTTP codes throw only sanitized status/code', async () => {
  for (const status of [408, 429, 500, 503, 599]) {
    await assert.rejects(deliverWebhook({...connection, fetchImpl: async () => ({status,
      body: {cancel: async () => {}}, text: async () => 'fake-secret-key RAW_SERVER_ERROR'})}), (error) => {
      assert.equal(error.code, 'webhook_retryable_http');
      assert.equal(error.status, status);
      assert.ok(!error.stack.includes('fake-secret-key'));
      assert.ok(!JSON.stringify(error).includes('RAW_SERVER_ERROR'));
      return true;
    });
  }
});

test('network and redirect errors do not expose key, payload, URL or original cause', async () => {
  await assert.rejects(deliverWebhook({...connection, fetchImpl: async () => {
    throw new Error(`fake-secret-key ${JSON.stringify(payload)} https://private.example`);
  }}), (error) => {
    assert.equal(error.message, 'webhook_network_error');
    assert.equal(error.cause, undefined);
    assert.ok(!error.stack.includes('fake-secret-key'));
    assert.ok(!error.stack.includes(payload.message));
    assert.ok(!error.stack.includes('private.example'));
    return true;
  });
});

test('timeout aborts request even if injected fetch does not settle', async () => {
  let signal;
  await assert.rejects(deliverWebhook({...connection, timeoutMs: 10,
    fetchImpl: (_, options) => { signal = options.signal; return new Promise(() => {}); }}),
  {message: 'webhook_timeout'});
  assert.equal(signal.aborted, true);
});

test('configuration validation prevents HTTP or expanded payload from reaching fetch', async () => {
  for (const override of [{url: 'http://receiver.example'}, {url: 'https://user:secret@receiver.example'},
    {url: 'not-url'}, {key: ''}, {key: 'secret\nInjected: x'}, {timeoutMs: -1},
    {payload: {...payload, rawPayload: 'SECRET'}}, {payload: {...payload, status: 'warning'}},
    {payload: {...payload, status: undefined}}]) {
    let called = false;
    await assert.rejects(deliverWebhook({...connection, ...override,
      fetchImpl: async () => { called = true; }}), {message: 'webhook_invalid_configuration'});
    assert.equal(called, false);
  }
});

test('explicit local emulator exception accepts only the exact loopback endpoint', async () => {
  for (const url of ['http://127.0.0.1:19404/events', 'http://localhost:19404/events',
    'http://127.0.0.1:19405/events', 'http://127.0.0.1:19404/other',
    'http://127.0.0.1:19404/events?extra=1', 'http://127.0.0.1:19404/events#fragment']) {
    const exact = url === 'http://127.0.0.1:19404/events';
    const attempt = deliverWebhook({...connection, url, allowLocalEmulator: !exact,
      fetchImpl: async () => { assert.fail('HTTP exception must not match'); }});
    await assert.rejects(attempt, {message: 'webhook_invalid_configuration'});
  }
});

test('real loopback mock receives the exact contract with a fake key', async () => {
  let received;
  const server = createServer(async (request, response) => {
    const chunks = [];
    for await (const chunk of request) chunks.push(chunk);
    received = {url: request.url, authorization: request.headers.authorization,
      body: JSON.parse(Buffer.concat(chunks).toString('utf8'))};
    response.writeHead(202, {'Content-Type': 'text/plain'});
    response.end('accepted');
  });
  server.listen(19404, '127.0.0.1');
  await once(server, 'listening');
  try {
    assert.deepEqual(await deliverWebhook({...connection,
      url: 'http://127.0.0.1:19404/events', allowLocalEmulator: true}),
    {outcome: 'delivered', status: 202});
    assert.deepEqual(received, {url: '/events', authorization: 'Bearer fake-secret-key', body: payload});
  } finally {
    server.closeAllConnections();
    await new Promise((resolve) => server.close(resolve));
  }
});

test('status classifies the recorded event without inferring playback or trusting input status', () => {
  const groups = {
    success: ['playback_started', 'playback_restored', 'connection_recovered'],
    failure: ['command_failed', 'command_receipt_failed', 'playback_interrupted', 'connection_failed'],
    info: ['playback_completed', 'device_online', 'device_offline', 'device_shutdown'],
  };
  for (const [status, types] of Object.entries(groups)) {
    for (const type of types) {
      const result = buildWebhookPayload({...input, event: {type, status: 'spoofed'}});
      assert.equal(result.status, status, type);
      assert.equal(result.event_id, payload.event_id, 'Classification must not alter retry identity');
    }
  }
  const receiptFailure = buildWebhookPayload({...input, event: {type: 'command_receipt_failed'}});
  assert.match(receiptFailure.message, /실제 재생 중단 여부는 별도 확인/u);
});
