import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';

// Offline transformer only. There is deliberately no remote write mode.
export function directRulesPayload(original) {
  assert.equal(original.id, 24924061, 'Unexpected ruleset');
  assert.equal(original.target, 'branch');
  assert.equal(original.enforcement, 'active');
  assert(original.conditions.ref_name.include.includes('refs/heads/main'));
  assert(original.conditions.ref_name.include.includes('refs/heads/develop'));
  assert(original.rules.some(rule => rule.type === 'pull_request'));
  const payload = structuredClone(Object.fromEntries(['name', 'target', 'enforcement', 'bypass_actors', 'conditions', 'rules'].map(k => [k, original[k]])));
  let removed = 0;
  payload.rules = payload.rules.flatMap(rule => {
    if (rule.type !== 'required_status_checks') return [rule];
    const checks = rule.parameters.required_status_checks.filter(check => {
      if (check.context !== 'firebase-required') return true;
      assert.equal(check.integration_id, 15368, 'Unexpected required-check integration'); removed++; return false;
    });
    return checks.length ? [{...rule, parameters: {...rule.parameters, required_status_checks: checks}}] : [];
  });
  assert.equal(removed, 1, 'Expected exactly one retired Firebase context');
  return payload;
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  assert.equal(process.argv.length, 3, 'Pass the freshly read ruleset JSON file');
  console.log(JSON.stringify(directRulesPayload(JSON.parse(readFileSync(process.argv[2], 'utf8'))), null, 2));
}
