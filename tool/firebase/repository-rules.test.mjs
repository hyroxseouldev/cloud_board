import test from 'node:test';
import assert from 'node:assert/strict';
import {releaseRuleset, validateActiveRules} from './repository-rules.mjs';

test('read-only observer detects disabled/missing/forged release requirements', () => {
  validateActiveRules(releaseRuleset.rules);
  assert.throws(() => validateActiveRules([]));
  for (const type of ['deletion', 'non_fast_forward', 'pull_request', 'required_status_checks']) {
    assert.throws(() => validateActiveRules(releaseRuleset.rules.filter(r => r.type !== type)));
  }
  const forged = structuredClone(releaseRuleset.rules);
  forged.find(r => r.type === 'required_status_checks').parameters.required_status_checks[0].integration_id = 1;
  assert.throws(() => validateActiveRules(forged));
  assert.deepEqual(releaseRuleset.bypass_actors, []);
});
