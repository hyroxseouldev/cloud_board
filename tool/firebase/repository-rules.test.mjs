import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {releaseRuleset, validateActiveRules} from './repository-rules.mjs';
import {directRulesPayload} from './migrate-direct-rules.mjs';
const old = JSON.parse(readFileSync('docs/operations/direct-release/ruleset-24924061-restore.json'));
test('direct release observer requires branch protection and rejects a dead CI context', () => {
  validateActiveRules(releaseRuleset.rules);
  assert.throws(() => validateActiveRules([]));
  for (const type of ['deletion', 'non_fast_forward', 'pull_request']) assert.throws(() => validateActiveRules(releaseRuleset.rules.filter(r => r.type !== type)));
  const noThreads = structuredClone(releaseRuleset.rules);
  noThreads.find(r => r.type === 'pull_request').parameters.required_review_thread_resolution = false;
  assert.throws(() => validateActiveRules(noThreads));
  assert.throws(() => validateActiveRules(old.rules), /Retired/);
  assert.deepEqual(releaseRuleset.bypass_actors, []);
});
test('migration removes only firebase-required and preserves every other protection parameter', () => {
  const expected = JSON.parse(readFileSync('docs/operations/direct-release/ruleset-24924061-direct.json'));
  assert.deepEqual(directRulesPayload({...old, id: 24924061}), expected);
  assert.deepEqual(expected.rules, old.rules.filter(r => r.type !== 'required_status_checks'));
  for (const key of ['name', 'target', 'enforcement', 'bypass_actors', 'conditions']) assert.deepEqual(expected[key], old[key]);
  const extra = structuredClone(old);
  extra.rules.at(-1).parameters.required_status_checks.push({context: 'unrelated-check', integration_id: 99});
  const result = directRulesPayload({...extra, id: 24924061});
  assert.deepEqual(result.rules.at(-1).parameters, {...extra.rules.at(-1).parameters, required_status_checks: [{context: 'unrelated-check', integration_id: 99}]});
  assert.throws(() => directRulesPayload({...old, id: 1}));
});
