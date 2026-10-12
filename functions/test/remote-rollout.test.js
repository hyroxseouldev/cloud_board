import test from 'node:test';
import assert from 'node:assert/strict';
import {parameter, rolloutTemplate} from '../tools/remote-rollout.mjs';
const policy = {schemaVersion: 1, revision: 2, features: {splitPlayback: {enabled: true, rolloutPercent: 10}}};
const actor = {actor: 'operator', reason: 'Start verified center pilot'};
test('rollout preserves unrelated config and records operator reason', () => {
  const current = {etag: 'current', parameters: {unrelated: {defaultValue: {value: 'keep'}}}};
  const next = rolloutTemplate(current, policy, actor);
  assert.deepEqual(next.parameters.unrelated, current.parameters.unrelated);
  assert.equal(next.etag, 'current'); assert.equal(next.version.description, 'operator: Start verified center pilot');
  assert.equal(JSON.parse(next.parameters[parameter].defaultValue.value).revision, 2);
  assert.equal(current.parameters[parameter], undefined);
});
test('stale revision, per-device conditions and version-policy fields are rejected', () => {
  const current = {parameters: {[parameter]: {defaultValue: {value: JSON.stringify(policy)}}}};
  assert.throws(() => rolloutTemplate(current, policy, actor), /Revision/);
  current.parameters[parameter].conditionalValues = {randomDevice: {value: '{}'}};
  assert.throws(() => rolloutTemplate(current, {...policy, revision: 3}, actor), /per-device/);
  assert.throws(() => rolloutTemplate({parameters: {}}, {...policy, minimumBuild: 65}, actor));
});
