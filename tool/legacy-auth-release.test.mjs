import assert from 'node:assert/strict';
import { test } from 'node:test';
import { baseline, sanitizeInventory, validateLive, verifyAfter, checkSource, validateReleaseEvidence, validateSecretVersions, sourceChanges, validateSourceChanges } from './legacy-auth-release.mjs';

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

test('server regression evidence must match the candidate without requiring native QA', () => {
  const evidence = { candidateDigest: 'abc', sourceSha: 'a'.repeat(40), appVersions: { released: '1.1.0', candidate: '1.1.1' }, tvVersion: '1.1.1', infrastructureReview: 'passed',
    pairingBackend: { project: baseline.project, region: 'asia-northeast3', function: 'pairDisplayConnection', sourceSha: 'b'.repeat(40), smoke: 'passed' },
    checks: Object.fromEntries(['legacyPairingBridge', 'googleAppleLogin', 'phoneFreeActivation', 'legacyAccountEntitlement', 'pairDisplay', 'setDisplayState', 'threeTvClassLifecycle'].map(key => [key, 'passed'])) };
  assert.doesNotThrow(() => validateReleaseEvidence(evidence, 'abc'));
  assert.throws(() => validateReleaseEvidence(evidence, 'different'));
  evidence.checks.threeTvClassLifecycle = 'pending'; assert.doesNotThrow(() => validateReleaseEvidence(evidence, 'abc'));
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

test('reviewed bridge delta preserves the migration baseline and rejects unrelated overrides', () => {
  assert.doesNotThrow(() => validateSourceChanges(sourceChanges));
  for (const mutate of [
    s => { s.baselineSha256 = '0'.repeat(64); },
    s => { s.exportDeclarationSha256.cloudboardAuth = '0'.repeat(64); },
    s => { s.supportingModuleSha256['lib/auth.js'] = '0'.repeat(64); },
    s => { s.migratedIndexSha256 = baseline.migratedIndexSha256; },
    s => { s.exportDeclarationSha256.cloudboardPairDisplay = baseline.exportDeclarationSha256.cloudboardPairDisplay; },
    s => { s.supportingModuleSha256['lib/services/pairing.js'] = baseline.supportingModuleSha256['lib/services/pairing.js']; },
    s => { s.supportingModuleSha256 = {}; },
    s => { s.exportDeclarationSha256.cloudboardPairDisplay = 'unreviewed'; },
    s => { s.ignoreOtherModules = true; },
  ]) { const changed = structuredClone(sourceChanges); mutate(changed); assert.throws(() => validateSourceChanges(changed)); }
});

test('bridge release requires the deployed canonical backend and released-app bridge evidence', () => {
  const evidence = { candidateDigest: 'abc', sourceSha: 'a'.repeat(40), appVersions: { released: 'old', candidate: 'new' }, tvVersion: 'three-tvs', infrastructureReview: 'passed',
    pairingBackend: { project: baseline.project, region: 'asia-northeast3', function: 'pairDisplayConnection', sourceSha: 'b'.repeat(40), smoke: 'passed' },
    checks: Object.fromEntries(['googleAppleLogin', 'phoneFreeActivation', 'legacyAccountEntitlement', 'pairDisplay', 'setDisplayState', 'threeTvClassLifecycle', 'legacyPairingBridge'].map(key => [key, 'passed'])) };
  assert.doesNotThrow(() => validateReleaseEvidence(evidence, 'abc'));
  for (const mutate of [
    s => { delete s.pairingBackend; },
    s => { s.pairingBackend.project = 'other-project'; },
    s => { s.pairingBackend.region = 'asia-southeast1'; },
    s => { s.pairingBackend.function = 'cloudboardPairDisplay'; },
    s => { s.pairingBackend.sourceSha = 'missing'; },
    s => { s.pairingBackend.smoke = 'pending'; },
    s => { s.checks.legacyPairingBridge = 'pending'; },
  ]) { const changed = structuredClone(evidence); mutate(changed); assert.throws(() => validateReleaseEvidence(changed, 'abc')); }
});

function serverEvidence() {
  return {
    candidateDigest: 'abc', sourceSha: 'a'.repeat(40),
    appVersions: {released: '1.1.1', candidate: '1.2.1'}, tvVersion: '1.1.0/1.1.1',
    infrastructureReview: 'passed',
    pairingBackend: {project: baseline.project, region: 'asia-northeast3', function: 'pairDisplayConnection', sourceSha: 'b'.repeat(40), smoke: 'passed'},
    checks: {legacyPairingBridge: 'passed'},
  };
}

test('automated server evidence permits release without physical QA or a waiver', () => {
  const evidence = serverEvidence();
  const original = structuredClone(evidence);
  assert.doesNotThrow(() => validateReleaseEvidence(evidence, 'abc'));
  assert.deepEqual(evidence, original, 'Do not manufacture passing physical QA evidence');
  evidence.checks.threeTvClassLifecycle = 'pending';
  assert.doesNotThrow(() => validateReleaseEvidence(evidence, 'abc'));
  assert.equal(evidence.checks.threeTvClassLifecycle, 'pending');
});

test('server, identity, version and infrastructure checks remain required without physical QA', () => {
  for (const mutate of [
    s => { s.candidateDigest = 'different'; },
    s => { s.sourceSha = 'invalid'; },
    s => { delete s.appVersions; },
    s => { delete s.appVersions.released; },
    s => { delete s.appVersions.candidate; },
    s => { delete s.tvVersion; },
    s => { s.infrastructureReview = 'pending'; },
    s => { s.pairingBackend.smoke = 'pending'; },
    s => { delete s.pairingBackend; },
    s => { s.pairingBackend.project = 'different'; },
    s => { s.checks.legacyPairingBridge = 'pending'; },
    s => { delete s.checks; },
  ]) {
    const changed = serverEvidence(); mutate(changed);
    assert.throws(() => validateReleaseEvidence(changed, 'abc'));
  }
});
