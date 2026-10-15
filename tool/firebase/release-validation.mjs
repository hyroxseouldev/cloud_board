import assert from 'node:assert/strict';

// This records the selected validation policy, not a claim that tests passed.
export const releaseValidationFile = 'build/release/validation/release.json';
export function validateReleaseValidation(value, expected = {}) {
  assert.equal(value?.schemaVersion, 1, 'Unsupported release validation schema');
  assert.equal(value.kind, 'release-validation');
  assert.match(value.sourceSha || '', /^[a-f0-9]{40}$/, 'Invalid validation source SHA');
  assert.equal(typeof value.releaseTag, 'string');
  assert(value.releaseTag === '' || /^v(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)$/.test(value.releaseTag), 'Invalid validation release tag');
  for (const field of ['runId', 'runAttempt']) {
    assert.equal(typeof value[field], 'string');
    assert.match(value[field], /^[1-9]\d*$/, `Invalid validation ${field}`);
  }
  assert(['required', 'skipped'].includes(value.validationMode), 'Unknown release validation mode');
  assert.equal(typeof value.reason, 'string');
  assert.equal(typeof value.actor, 'string');
  assert(value.actor.trim() && !/[\r\n]/.test(value.actor), 'Validation actor is required');
  if (value.validationMode === 'skipped') {
    assert(value.releaseTag, 'CI skip requires a release tag');
    assert(value.reason.trim(), 'CI skip reason is required');
    assert(value.reason.length <= 2000, 'CI skip reason must be at most 2000 characters');
  } else assert.equal(value.reason, '', 'Required validation must not contain a skip reason');
  for (const [field, wanted] of Object.entries(expected)) {
    assert.equal(value[field], wanted, `Release validation ${field} mismatch`);
  }
  return value;
}
