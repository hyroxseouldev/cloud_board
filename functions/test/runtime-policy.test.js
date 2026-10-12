import assert from 'node:assert/strict';
import test from 'node:test';
import {applyRuntimePolicy, validateRuntimePolicy} from '../tools/runtime-policy.mjs';

const policy = (revision, enabled = false) => ({schemaVersion: 1, revision,
  features: {splitPlayback: {enabled, rolloutPercent: 100}}});

test('runtime controls reject malformed values and typoed feature names', () => {
  assert.deepEqual(validateRuntimePolicy(policy(1)), policy(1));
  for (const malformed of [
    {...policy(1), schemaVersion: 2}, {...policy(1), revision: '1'},
    {...policy(1), features: {splitPlaybak: {enabled: false, rolloutPercent: 100}}},
    {...policy(1), features: {splitPlayback: {enabled: 'false', rolloutPercent: 100}}},
    {...policy(1), features: {splitPlayback: {enabled: false, rolloutPercent: 101}}},
  ]) assert.throws(() => validateRuntimePolicy(malformed));
});

test('operator compare-and-set prevents races and restoration must use a new revision', async () => {
  let current;
  const database = {doc(path) { assert.equal(path, 'runtimePolicy/current'); return path; },
    async runTransaction(action) { await action({
      async get() { return {exists: current !== undefined, data: () => current}; },
      set(_, next) { current = next; },
    }); },
  };
  await applyRuntimePolicy(database, policy(1), -1);
  await assert.rejects(applyRuntimePolicy(database, policy(2, true), -1), /Policy changed/);
  await assert.rejects(applyRuntimePolicy(database, policy(1, true), 1), /Revision must increase/);
  assert.deepEqual(current, policy(1));
  await applyRuntimePolicy(database, policy(2, true), 1);
  assert.deepEqual(current, policy(2, true));
});
