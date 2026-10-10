import assert from 'node:assert/strict';
import test from 'node:test';
import {summarizeDiagnostics, validateSaveAlert, inspectHealth} from '../../functions/tools/release-health.mjs';
import {receiptFor} from './test-fixtures.mjs';
import {workoutSavePolicy} from '../../functions/tools/workout-save-alert.mjs';
test('late offline reports do not blame a newer rules release and raw data is excluded', () => {
  const receipt = {...receiptFor(), completedAt: '2026-10-10T03:00:00Z'};
  const sample = occurredAt => ({jsonPayload: {message: 'client_diagnostic', occurredAt, stack: 'private', accountHash: 'private', context: {action: 'workout.save', firebaseCode: 'permission-denied', platform: 'ios', version: '1.0.0', build: '2'}}});
  const result = summarizeDiagnostics([sample('2026-10-10T02:59:00Z'), sample('2026-10-10T03:01:00Z')], receipt);
  assert.equal(result.delayedBeforeRelease, 1); assert.equal(result.groups[0].count, 1);
  assert(!JSON.stringify(result).includes('private'));
  assert.equal(summarizeDiagnostics([], receipt).status, 'no-errors-observed');
  assert.match(summarizeDiagnostics([], receipt).dataMeaning, /not evidence/);
  const legacy = sample('2026-10-10T03:01:00Z'); legacy.jsonPayload.message = 'Error: client_diagnostic\n    at logger.error';
  assert.equal(summarizeDiagnostics([legacy], receipt).groups[0].count, 1);
});
test('existing save policy must be enabled, unique and have an enabled receiver', () => {
  const policy = {...workoutSavePolicy('cloud-board-stationd', 'channel'), name: 'policy'};
  const channels = [{name: 'channel', enabled: true, verificationStatus: 'VERIFIED'}];
  assert.equal(validateSaveAlert([policy], channels).status, 'configured');
  for (const policies of [[], [policy, policy], [{...policy, enabled: false}], [{...policy, notificationChannels: []}]]) assert.throws(() => validateSaveAlert(policies, channels));
  assert.throws(() => validateSaveAlert([policy], [{...channels[0], verificationStatus: 'UNVERIFIED'}]));
});
test('missing telemetry permission fails; it cannot be reported as zero errors', async () => {
  await assert.rejects(inspectHealth(receiptFor(), async () => {throw new Error('403');}));
});
test('hourly observations bound received logs and surface truncated collection', async () => {
  const requests = [];
  const result = await inspectHealth(receiptFor(), async (method, url, body) => {
    if (url.endsWith('/alertPolicies')) return {alertPolicies: [workoutSavePolicy('cloud-board-stationd', 'channel')]};
    if (url.endsWith('/notificationChannels')) return {notificationChannels: [{name: 'channel', enabled: true, verificationStatus: 'VERIFIED'}]};
    requests.push(body); return {entries: [], nextPageToken: 'more'};
  }, Date.parse('2026-10-11T10:00:00Z'));
  assert.equal(requests.length, 10); assert.equal(result.diagnostics.truncated, true);
  assert.equal(result.diagnostics.status, 'incomplete');
  assert.match(requests[0].filter, /2026-10-11T08:00:00.000Z/);
});
