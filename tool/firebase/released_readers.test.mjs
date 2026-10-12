import assert from 'node:assert/strict';
import test from 'node:test';
import {readerPlans} from './released_readers.mjs';
import {readJson} from './common.mjs';
import {validateRetirements} from './support_retirements.mjs';

const registry = readJson('tool/firebase/supported-clients.json');
const policy = readJson('tool/firebase/compatibility-policy.json');
const retirements = readJson('tool/firebase/support-retirements.json');
const registeredSources = [...new Set(registry.clients.map(client => client.sourceCommit))].sort();
const retiredSources = ['c54588cc7733ac8577d11c036c21635d1f283f2a', 'c85167e863ee5e8e9212722572ab57df65801eeb'];
const establishedActiveSources = ['1b64643860d2385d797dafba3db954063d28384f', 'a8653077314c5e5bf2f14e1a8495e4c9ab1f1b6b'];
test('owner-authorized retirement skips only exact old forward readers and retains the full ledger', () => {
  const plans = readerPlans(registry, policy, retirements);
  assert.deepEqual(plans.map(p => p.sourceCommit).sort(), registeredSources);
  assert.deepEqual(plans.filter(p => p.retirement).map(p => p.sourceCommit).sort(), retiredSources);
  assert.deepEqual(plans.filter(p => !p.retirement).map(p => p.sourceCommit).sort(),
    registeredSources.filter(source => !retiredSources.includes(source)));
  for (const source of establishedActiveSources) {
    assert(plans.some(plan => plan.sourceCommit === source && !plan.retirement), 'Existing active source must remain covered');
  }
  assert.deepEqual(plans.flatMap(p => p.clients).sort(), registry.clients.map(c => c.client).sort());
  for (const plan of plans.filter(p => p.retirement)) {
    assert.equal(plan.retirement.authorization.remotelyVerified, false);
    assert.deepEqual(plan.exceptions, []);
  }
});
test('retirement rejects wildcards, unknown/latest sources, missing clients and invented telemetry', () => {
  for (const mutate of [
    p => p.retirements[0].sourceCommit = '*',
    p => p.retirements[0].sourceCommit = 'a'.repeat(40),
    p => p.retirements[0].sourceCommit = 'a8653077314c5e5bf2f14e1a8495e4c9ab1f1b6b',
    p => p.retirements[0].clients = [],
    p => p.retirements[0].authorization.remotelyVerified = true,
    p => p.retirements[0].retainedCoverage.pop(),
    p => p.retirements.push(structuredClone(p.retirements[0])),
  ]) {
    const changed = structuredClone(retirements); mutate(changed);
    assert.throws(() => readerPlans(registry, policy, changed));
  }
});
test('retirement evidence is append-only and cannot be erased or silently rewritten', () => {
  validateRetirements(registry, retirements, retirements);
  const removed = structuredClone(retirements); removed.retirements.pop();
  assert.throws(() => validateRetirements(registry, removed, retirements), /changed or removed/);
  const renamed = structuredClone(retirements); renamed.retirements[0].id += '-rewritten';
  assert.throws(() => validateRetirements(registry, renamed, retirements), /changed or removed/);
});
test('all installed source versions are exercised once even when multiple platforms share one', () => {
  const plans = readerPlans(registry, policy);
  assert.deepEqual(plans.map(p => p.sourceCommit).sort(), registeredSources);
  assert.deepEqual(plans.flatMap(p => p.clients).sort(), registry.clients.map(c => c.client).sort());
  assert(plans.every(p => p.sourceCommit.length === 40));
});
test('a newly registered source is active by default and shared platforms run its reader once', () => {
  const sourceCommit = 'c'.repeat(40);
  const expanded = {...registry, clients: [...registry.clients,
    {client: 'future-ios-test-only', sourceCommit, platforms: ['ios']},
    {client: 'future-android-test-only', sourceCommit, platforms: ['android']},
  ]};
  const plans = readerPlans(expanded, policy, retirements);
  assert.equal(plans.length, registeredSources.length + 1);
  const added = plans.filter(plan => plan.sourceCommit === sourceCommit);
  assert.equal(added.length, 1);
  assert.deepEqual(added[0].clients, ['future-ios-test-only', 'future-android-test-only']);
  assert.equal(added[0].retirement, null);
  assert.deepEqual(added[0].exceptions, []);
  assert.deepEqual(plans.filter(plan => plan.retirement).map(plan => plan.sourceCommit).sort(), retiredSources);
});
test('actual public and review builds retain their limited historical capabilities', () => {
  const plans = readerPlans(registry, policy);
  for (const source of ['c85167e863ee5e8e9212722572ab57df65801eeb', 'c54588cc7733ac8577d11c036c21635d1f283f2a']) {
    const plan = plans.find(p => p.sourceCommit === source);
    assert.deepEqual(plan.exceptions, [], 'Semantic timer/design omissions must not be excepted');
    assert.equal(plan.capabilities[0].extendedTiming, false);
    assert.equal(plan.capabilities[0].summaryDurationKind, false);
    assert.deepEqual(plan.capabilities[0].playbackWireProtocols, [1, 2]);
  }
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
