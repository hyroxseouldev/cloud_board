import assert from 'node:assert/strict';
import test from 'node:test';
import {readerPlans} from './released_readers.mjs';
import {readJson} from './common.mjs';

const registry = readJson('tool/firebase/supported-clients.json');
const policy = readJson('tool/firebase/compatibility-policy.json');
test('all installed source versions are exercised once even when multiple platforms share one', () => {
  const plans = readerPlans(registry, policy);
  assert.equal(plans.length, 2);
  assert.deepEqual(plans.flatMap(p => p.clients).sort(), registry.clients.map(c => c.client).sort());
  assert(plans.every(p => p.sourceCommit.length === 40));
});
test('unknown sources, broad object omissions and unexplained exceptions fail closed', () => {
  for (const mutate of [
    p => p.nonSemanticFieldsBySource['a'.repeat(40)] = [],
    p => p.nonSemanticFieldsBySource[registry.clients[0].sourceCommit][0].path = 'workout/modules/*',
    p => p.nonSemanticFieldsBySource[registry.clients[0].sourceCommit][0].reason = '',
  ]) {
    const changed = structuredClone(policy);
    mutate(changed);
    assert.throws(() => readerPlans(registry, changed));
  }
});
