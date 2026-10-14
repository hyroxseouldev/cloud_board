import assert from 'node:assert/strict';
import { test } from 'node:test';
import { baseline, sanitizeInventory, validateLive, verifyAfter, checkSource, validateReleaseEvidence, validateSecretVersions } from './legacy-auth-release.mjs';

function fixture() {
  return sanitizeInventory({ status: 'success', result: baseline.functions.map(f => ({
    ...f, id: f.name, project: baseline.project, codebase: baseline.codebase,
    platform: 'gcfv2', secretEnvironmentVariables: f.secretNames.map(key => ({ key, secret: key, version: '1', projectId: baseline.project })),
    environmentVariables: Object.fromEntries(f.environmentVariableNames.map(key => [key, 'DO_NOT_LOG_CONFIG'])),
    labels: f.name === 'cloudboardAuth' ? {} : { 'deployment-callable': 'true' },
  })) });
}

test('compiled migration preserves deployed contracts and exports only ACTIVE functions', async () => {
  assert.match(await checkSource(), /^[a-f0-9]{64}$/);
});

test('inventory keeps secret references and removes every runtime value', () => {
  const snapshot = fixture(); validateLive(snapshot);
  assert(!JSON.stringify(snapshot).includes('DO_NOT_LOG_CONFIG'));
  assert(snapshot.functions.some(f => f.secretBindings.some(s => s.key === 'DATABASE_URL')));
});

for (const [description, mutate] of [
  ['unexpected scheduler revival', s => s.functions.push({ ...s.functions[0], id: 'cloudboardMaintenance' })],
  ['missing account link', s => { s.functions = s.functions.filter(f => f.id !== 'cloudboardLinkAccount'); }],
  ['wrong region', s => { s.functions[0].region = 'asia-northeast3'; }],
  ['non-active function', s => { s.functions[0].state = 'FAILED'; }],
  ['changed shared account', s => { s.functions[0].serviceAccount = 'new-account'; }],
  ['new event trigger', s => { s.functions[0].trigger = { document: 'users/{uid}' }; }],
  ['secret removed', s => { s.functions[0].secretBindings = []; }],
]) test(`release stops on ${description}`, () => {
  const snapshot = fixture(); mutate(snapshot); assert.throws(() => validateLive(snapshot));
});

test('post-deploy comparison allows source updates only for the four migrated functions', () => {
  const before = fixture();
  before.functions.push({ id: 'deleteAccount', region: 'asia-northeast3', codebase: 'account-deletion', hash: 'old' });
  const after = structuredClone(before);
  after.functions[0].hash = 'migration'; after.functions[0].source = { storageSource: { generation: 'new' } };
  assert.doesNotThrow(() => verifyAfter(before, after));
  after.functions.at(-1).hash = 'unexpected'; assert.throws(() => verifyAfter(before, after));
});

test('post-deploy comparison rejects config drift, secret rotation and unrelated deletion', () => {
  const before = fixture();
  for (const mutate of [
    s => { s.functions[0].runtimeConfigSha256 = 'changed'; },
    s => { s.functions[0].secretBindings[0].version = '2'; },
    s => { s.functions.pop(); },
  ]) { const after = structuredClone(before); mutate(after); assert.throws(() => verifyAfter(before, after)); }
});

test('native regression evidence must match the candidate and every required journey', () => {
  const evidence = { candidateDigest: 'abc', sourceSha: 'a'.repeat(40), appVersions: { released: '1.1.0', candidate: '1.1.1' }, tvVersion: '1.1.1', infrastructureReview: 'passed',
    checks: Object.fromEntries(['googleAppleLogin', 'phoneFreeActivation', 'legacyAccountEntitlement', 'pairDisplay', 'setDisplayState', 'threeTvClassLifecycle'].map(key => [key, 'passed'])) };
  assert.doesNotThrow(() => validateReleaseEvidence(evidence, 'abc'));
  assert.throws(() => validateReleaseEvidence(evidence, 'different'));
  evidence.checks.threeTvClassLifecycle = 'pending'; assert.throws(() => validateReleaseEvidence(evidence, 'abc'));
});

test('migration cannot implicitly rotate a secret to a newer or disabled version', () => {
  const inventory = fixture();
  inventory.secretVersions = Object.fromEntries([...new Set(baseline.functions.flatMap(f => f.secretNames))]
    .map(name => [name, [{ version: '1', state: 'ENABLED' }]]));
  assert.doesNotThrow(() => validateSecretVersions(inventory));
  inventory.secretVersions.DATABASE_URL.unshift({ version: '2', state: 'ENABLED' });
  assert.throws(() => validateSecretVersions(inventory));
  inventory.secretVersions.DATABASE_URL = [{ version: '1', state: 'DISABLED' }];
  assert.throws(() => validateSecretVersions(inventory));
});
