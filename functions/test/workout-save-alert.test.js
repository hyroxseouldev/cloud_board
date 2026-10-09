import test from 'node:test';
import assert from 'node:assert/strict';
import {configureWorkoutSaveAlert, workoutSavePolicy} from '../tools/workout-save-alert.mjs';

test('save alert covers native and web authenticated diagnostics with bounded notifications', () => {
  const policy = workoutSavePolicy('demo-cloudboard', 'channel');
  assert.match(policy.conditions[0].conditionMatchedLog.filter, /workout.save/);
  assert.match(policy.conditions[0].conditionMatchedLog.filter, /workout.duplicate/);
  assert.match(policy.conditions[0].conditionMatchedLog.filter, /client_diagnostic/);
  assert.equal(policy.alertStrategy.notificationRateLimit.period, '1800s');
  assert.deepEqual(policy.notificationChannels, ['channel']);
});
test('configuration reuses the recipient and managed policy instead of duplicating alerts', async () => {
  const writes = [];
  const result = await configureWorkoutSaveAlert({project: 'demo-cloudboard', email: 'owner@example.com', request: async (method, path, body) => {
    if (method === 'GET' && path.endsWith('notificationChannels')) return {notificationChannels: [{name: 'channel', type: 'email', enabled: true, labels: {email_address: 'owner@example.com'}}]};
    if (method === 'GET') return {alertPolicies: [{name: 'policy', userLabels: {managed_by: 'cloudboard', purpose: 'workout-save'}, conditions: [{name: 'condition'}]}]};
    writes.push({method, path, body});
    return {name: 'policy', enabled: true};
  }});
  assert.equal(writes.length, 1);
  assert.equal(writes[0].method, 'PATCH');
  assert.equal(writes[0].body.conditions[0].name, 'condition');
  assert.equal(result.enabled, true);
});
