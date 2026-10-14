import assert from 'node:assert/strict';
import { beforeEach, test } from 'node:test';
import { cloudboardPairDisplay } from '../src/index.js';
import { pairDisplay } from '../src/services/pairing.js';
import { firebaseServices } from '../src/services/firebase.js';

const localBearer = 'local-test-only-bearer';
const input = { code: '123456', name: ' TV ', zoneName: ' Center ' };
const success = () => Response.json({ result: { paired: true, deviceId: 'display_1', ignored: 'extra' } });
const request = () => ({
  auth: { uid: 'owner', token: { firebase: { sign_in_provider: 'google.com' } } },
  rawRequest: { headers: { authorization: `Bearer ${localBearer}` } }, data: input,
});

beforeEach(t => {
  const project = process.env.GCLOUD_PROJECT, enabled = process.env.FIREBASE_APP_LINK_ENABLED;
  process.env.GCLOUD_PROJECT = 'cloud-board-stationd';
  process.env.FIREBASE_APP_LINK_ENABLED = 'true';
  // No test, including a regression in auth guards, can make a real request.
  t.mock.method(globalThis, 'fetch', async () => { throw new Error('Network disabled in tests'); });
  t.after(() => {
    if (project === undefined) delete process.env.GCLOUD_PROJECT; else process.env.GCLOUD_PROJECT = project;
    if (enabled === undefined) delete process.env.FIREBASE_APP_LINK_ENABLED; else process.env.FIREBASE_APP_LINK_ENABLED = enabled;
  });
});

test('legacy callable forwards only a revocation-verified matching owner to the fixed canonical endpoint', async t => {
  let verified = false, calls = 0;
  t.mock.method(firebaseServices().auth, 'verifyIdToken', async (bearer, revoked) => {
    assert(bearer === localBearer); assert.equal(revoked, true);
    verified = true; return { uid: 'owner' };
  });
  t.mock.method(globalThis, 'fetch', async (url, options) => {
    assert(verified); calls++;
    assert.equal(url, 'https://asia-northeast3-cloud-board-stationd.cloudfunctions.net/pairDisplayConnection');
    assert.equal(options?.method, 'POST'); assert.equal(options?.redirect, 'error');
    const headers = new Headers(options?.headers);
    assert(headers.get('authorization') === `Bearer ${localBearer}`);
    assert.equal(headers.get('content-type'), 'application/json');
    assert(options?.signal instanceof AbortSignal);
    const body = JSON.parse(String(options?.body));
    assert.deepEqual(Object.keys(body), ['data']);
    assert.deepEqual(Object.keys(body.data).sort(), ['code', 'name', 'operationId', 'zoneName']);
    assert.equal(body.data.name, 'TV'); assert.equal(body.data.zoneName, 'Center');
    assert.match(body.data.operationId, /^legacy-[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
    return success();
  });
  assert.deepEqual(await cloudboardPairDisplay.run(request() as any), { paired: true, deviceId: 'display_1' });
  assert.equal(calls, 1);
});

for (const reason of ['anonymous', 'missing-token', 'revoked', 'uid-mismatch']) {
  test(`legacy callable rejects ${reason} before forwarding`, async t => {
    let forwarded = false, verified = 0;
    t.mock.method(globalThis, 'fetch', async () => { forwarded = true; return success(); });
    t.mock.method(firebaseServices().auth, 'verifyIdToken', async () => {
      verified++;
      if (reason === 'revoked') throw new Error('Do not propagate verification details');
      return { uid: 'different-owner' };
    });
    const value = request();
    if (reason === 'anonymous') value.auth.token.firebase.sign_in_provider = 'anonymous';
    if (reason === 'missing-token') value.rawRequest.headers.authorization = '';
    await assert.rejects(cloudboardPairDisplay.run(value as any), { code: 'unauthenticated' });
    assert.equal(forwarded, false);
    assert.equal(verified, reason === 'anonymous' || reason === 'missing-token' ? 0 : 1);
  });
}

test('each invocation gets its own UUID and caller operation/target fields cannot replace it', async () => {
  const ids: string[] = [];
  const transport: typeof fetch = async (_url, options) => {
    const data = JSON.parse(String(options?.body)).data;
    ids.push(data.operationId); assert.equal(data.target, undefined); return success();
  };
  const value = { ...input, operationId: 'caller-operation', target: 'https://untrusted.invalid' };
  await pairDisplay(localBearer, value, transport); await pairDisplay(localBearer, value, transport);
  assert.notEqual(ids[0], ids[1]); assert(!ids.includes('caller-operation'));
});

test('invalid input and wrong runtime project fail without forwarding', async () => {
  let calls = 0;
  const transport: typeof fetch = async () => { calls++; return success(); };
  for (const value of [null, {}, { code: '../x' }, { ...input, name: 'x'.repeat(61) }, { ...input, zoneName: 'x'.repeat(61) }])
    await assert.rejects(pairDisplay(localBearer, value, transport), { code: 'invalid-argument' });
  process.env.GCLOUD_PROJECT = 'demo-cloudboard-legacy';
  await assert.rejects(pairDisplay(localBearer, input, transport), { code: 'unavailable' });
  assert.equal(calls, 0);
});

for (const [status, code] of Object.entries({
  INVALID_ARGUMENT: 'invalid-argument', UNAUTHENTICATED: 'unauthenticated', PERMISSION_DENIED: 'permission-denied',
  FAILED_PRECONDITION: 'failed-precondition', RESOURCE_EXHAUSTED: 'resource-exhausted',
  ALREADY_EXISTS: 'already-exists', NOT_FOUND: 'not-found', ABORTED: 'aborted',
  INTERNAL: 'unavailable', UNAVAILABLE: 'unavailable', DEADLINE_EXCEEDED: 'unavailable',
  UNKNOWN: 'unavailable', constructor: 'unavailable',
})) {
  test(`upstream ${status} produces only a sanitized ${code} error even on HTTP 200`, async () => {
    const marker = 'private-upstream-data';
    const transport: typeof fetch = async () => Response.json({ error: { status, message: marker, details: { token: marker } }, result: { paired: true, deviceId: 'tv' } });
    await assert.rejects(pairDisplay(localBearer, input, transport), (error: any) => {
      assert.equal(error.code, code); assert.equal(error.details, undefined);
      assert(!JSON.stringify(error).includes(marker)); assert(!error.message.includes(marker)); return true;
    });
  });
}

test('malformed, oversized, unsuccessful and invalid success responses never claim pairing succeeded', async () => {
  const responses = [
    new Response('not-json'), new Response('x'.repeat(16 * 1024 + 1)),
    new Response('{}', { headers: { 'Content-Length': String(16 * 1024 + 1) } }),
    Response.json({ result: { paired: true, deviceId: 'tv' } }, { status: 503 }),
    Response.json({ data: { paired: true, deviceId: 'tv' } }),
    Response.json({ result: { paired: false, deviceId: 'tv' } }),
    Response.json({ result: { paired: true, deviceId: 'invalid/path' } }),
    Response.json({ result: { paired: true, deviceId: '' } }),
    Response.json({ error: null, result: { paired: true, deviceId: 'tv' } }),
  ];
  for (const response of responses)
    await assert.rejects(pairDisplay(localBearer, input, async () => response), { code: 'unavailable' });
});

test('network failure does not retry or use an Admin fallback', async () => {
  let calls = 0;
  await assert.rejects(pairDisplay(localBearer, input, async () => {
    calls++; throw new Error('Do not expose transport internals');
  }), { code: 'unavailable', message: '기기 연결을 잠시 후 다시 시도해 주세요.' });
  assert.equal(calls, 1);
});

test('20 second abort deadline covers an offline upstream and never returns late success', async t => {
  const controller = new AbortController();
  t.mock.method(AbortSignal, 'timeout', milliseconds => {
    assert.equal(milliseconds, 20_000); return controller.signal;
  });
  const operation = pairDisplay(localBearer, input, async (_url, options) => {
    return await new Promise<Response>((_resolve, reject) => {
      options!.signal!.addEventListener('abort', () => reject(new DOMException('Aborted', 'AbortError')), { once: true });
      queueMicrotask(() => controller.abort());
    });
  });
  await assert.rejects(operation, { code: 'unavailable' });
  assert.equal(controller.signal.aborted, true);
});

test('20 second deadline also cancels a stalled response body', async t => {
  const controller = new AbortController();
  t.mock.method(AbortSignal, 'timeout', milliseconds => { assert.equal(milliseconds, 20_000); return controller.signal; });
  const transport: typeof fetch = async (_url, options) => new Response(new ReadableStream({
    start(stream) {
      options!.signal!.addEventListener('abort', () => stream.error(new Error('Private transport failure')), { once: true });
      queueMicrotask(() => controller.abort());
    },
  }));
  await assert.rejects(pairDisplay(localBearer, input, transport), { code: 'unavailable' });
});
