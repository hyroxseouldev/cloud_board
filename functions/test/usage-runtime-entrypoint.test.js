import test from 'node:test';
import assert from 'node:assert/strict';
import {invokeUsageCallable} from '../src/image-usage-runtime.js';

const request = {auth: {uid: 'owner'}, rawRequest: {headers: {authorization: 'Bearer valid-token'}}, data: {action: 'get'}};
test('usage callable uses revoked-token verification and verified claims', async () => {
  const token = {uid: 'owner', quotaOperator: true, auth_time: 123};
  const ctx = {projectId: 'demo-usage', auth: {async verifyIdToken(raw, revoked) {
    assert.equal(raw, 'valid-token'); assert.equal(revoked, true); return token;
  }}};
  const result = await invokeUsageCallable(ctx, request, async input => input);
  assert.equal(result.projectId, ctx.projectId);
  assert.deepEqual(result.actor, {uid: 'owner', token});
  assert.equal(result.input, request.data);
});
test('missing identity and revoked or mismatched token cannot reach mutation', async () => {
  let calls = 0;
  const handler = () => { calls++; };
  for (const verifyIdToken of [async () => { throw new Error('revoked'); }, async () => ({uid: 'other'})]) {
    await assert.rejects(invokeUsageCallable({auth: {verifyIdToken}}, request, handler), error => error.code === 'unauthenticated');
  }
  await assert.rejects(invokeUsageCallable({}, {...request, auth: null}, handler), error => error.code === 'unauthenticated');
  assert.equal(calls, 0);
});
