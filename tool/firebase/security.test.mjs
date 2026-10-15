import assert from 'node:assert/strict';
import test from 'node:test';
import {mkdtempSync, readFileSync, writeFileSync, rmSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {validateFixtures} from './fixtures.mjs';
import {emulatorAddress, requireDemo, requireStorageRulesProject, hash, readJson} from './common.mjs';
import {requireSuccess, validateReceipt, requireCurrentMain} from './release.mjs';
import {validateProtection, manageProtection, actionsAppId} from './branch-protection.mjs';
import {prepareRecovery} from './recovery.mjs';
import {receiptFor} from './test-fixtures.mjs';
import {preflight} from '../../functions/tools/release-smoke.mjs';
import {checkRunId} from '../../functions/tools/release-canary.mjs';

test('emulator and canary boundaries reject production, URL and path overrides', () => {
  for (const host of ['', 'firebase.google.com:443', '127.0.0.1:19380/../../', 'localhost:99999']) assert.throws(() => emulatorAddress(host));
  assert.deepEqual(emulatorAddress('127.0.0.1:19380'), {host: '127.0.0.1', port: 19380});
  assert.throws(() => requireDemo('cloud-board-stationd'));
  for (const id of ['../customer', 'a-1', '123', '1-0/other']) assert.throws(() => checkRunId(id));
  const valid = {FIREBASE_RELEASE_CANARY_ENABLED: 'true', FIREBASE_WEB_API_KEY: 'AIzaexample', GITHUB_REF: 'refs/tags/v1.2.3', RELEASE_TAG: 'v1.2.3'};
  preflight(valid);
  for (const patch of [{FIREBASE_RELEASE_CANARY_ENABLED: ''}, {FIREBASE_WEB_API_KEY: ''}, {GITHUB_REF: 'refs/heads/main'}, {GITHUB_REF: 'refs/heads/develop'}, {RELEASE_TAG: ''}, {RELEASE_TAG: 'v1.2.4'}, {FIRESTORE_EMULATOR_HOST: 'localhost:1'}]) assert.throws(() => preflight({...valid, ...patch}));
});
test('Storage cross-service rules use the emulator project rather than a suite-only Firestore namespace', () => {
  const support = {id: 'support-tickets', project: 'demo-cloudboard', coverage: ['firestore'], requires: ['firestore', 'storage']};
  requireStorageRulesProject(support, 'demo-cloudboard');
  assert.throws(() => requireStorageRulesProject({...support, project: 'demo-cloudboard-support'}, 'demo-cloudboard'), /Storage suite support-tickets/);
  assert.throws(() => requireStorageRulesProject(support, 'demo-cloudboard-ci'), /must use emulator project/);
  assert.throws(() => requireStorageRulesProject(support, 'cloud-board-stationd'), /Demo project required/);
  requireStorageRulesProject({id: 'isolated-firestore', project: 'demo-isolated', coverage: ['firestore']}, 'demo-cloudboard');
  const suites = readJson('tool/firebase/contract-suites.json').suites;
  for (const id of ['storage', 'support-tickets']) {
    assert(suites.find(suite => suite.id === id)?.requires.includes('storage'), `${id} must declare Storage`);
  }
  for (const suite of suites) requireStorageRulesProject(suite, 'demo-cloudboard');
});
test('released fixture changes cannot be hidden by regenerating registry hashes', () => {
  const client = readJson('tool/firebase/supported-clients.json').clients[0], registry = {format: 1, clients: [client]}, content = readFileSync(client.file);
  const baseline = {[client.file]: hash(content)};
  validateFixtures(registry, [client.file], () => content, baseline);
  assert.throws(() => validateFixtures({...registry, clients: []}, [], () => content, baseline));
  const changed = Buffer.from(content.toString().replace('Workout', 'Different'));
  const updated = {...registry, clients: [{...client, sha256: hash(changed)}]};
  assert.throws(() => validateFixtures(updated, [client.file], () => changed, baseline), /overwritten/);
  assert.throws(() => validateFixtures(registry, [client.file, 'unexpected.json'], () => content, baseline), /inventory/);
});
test('required aggregate fails closed for every non-success and missing job', () => {
  const good = {app_validation: {result: 'success'}, firebase_contracts: {result: 'success'}};
  const required = Object.keys(good); requireSuccess(good, required);
  for (const result of ['failure', 'cancelled', 'skipped', 'neutral', 'timed_out', undefined]) {
    assert.throws(() => requireSuccess({...good, firebase_contracts: {result}}, required));
  }
  assert.throws(() => requireSuccess({app_validation: good.app_validation}, required));
});
test('receipt binds exact attempt, rules and actual smoke including cleanup', () => {
  const valid = receiptFor(); validateReceipt(valid, valid);
  for (const change of [r => r.attempt = '1', r => r.manifest.targets = {...r.manifest.targets, project: 'other'},
    r => r.smoke.status = 'skipped', r => r.smoke.cleanup = 'failure', r => r.smoke.checks.pop(),
    r => r.rules.services.storage.sourceHash = 'b'.repeat(64), r => delete r.rules.services.database,
    r => r.manifest.files['firestore.rules'] = 'b'.repeat(64)]) {
    const copy = structuredClone(valid); change(copy); assert.throws(() => validateReceipt(copy, valid));
  }
});
test('only an unchanged release tag included in main may mutate production', async () => {
  const sha = 'a'.repeat(40), tag = 'v1.2.3';
  const id = {sha, tag, ref: `refs/tags/${tag}`, repository: 'hyroxseouldev/cloud_board',
    request: async path => path.includes('/git/ref/') ? {object: {type: 'commit', sha}}
      : path.includes('/compare/') ? {status: 'ahead', merge_base_commit: {sha}} : {workflow_runs: []}};
  await requireCurrentMain(id);
  await assert.rejects(requireCurrentMain({...id, ref: 'refs/heads/main'}));
  await assert.rejects(requireCurrentMain({...id, request: async () => ({object: {type: 'commit', sha: 'b'.repeat(40)}})}));
});
test('branch protection requires trusted source, fresh base and no bypass; plan is offline', async () => {
  const good = {required_status_checks: {strict: true, checks: [{context: 'firebase-required', app_id: actionsAppId}]},
    required_pull_request_reviews: {}, enforce_admins: {enabled: true}, allow_force_pushes: {enabled: false}, allow_deletions: {enabled: false}, required_conversation_resolution: {enabled: true}};
  validateProtection(good);
  for (const patch of [{required_status_checks: {strict: false}}, {enforce_admins: {enabled: false}}, {required_pull_request_reviews: null},
    {required_status_checks: {strict: true, checks: [{context: 'firebase-required', app_id: -1}]}}]) assert.throws(() => validateProtection({...good, ...patch}));
  await manageProtection({mode: 'plan', repository: 'hyroxseouldev/cloud_board', request: () => {throw new Error('Plan must not call network');}});
  const writes = [];
  await assert.rejects(manageProtection({mode: 'apply', repository: 'hyroxseouldev/cloud_board', request: async (path, options) => {
    if (options?.method) writes.push(path);
    if (path.includes('/git/ref/')) return {object: {sha: path.endsWith('main') ? 'a'.repeat(40) : 'b'.repeat(40)}};
    if (path.includes(`/commits/${'a'.repeat(40)}/`)) return {check_runs: [{name: 'firebase-required', conclusion: 'success', app: {id: actionsAppId}}]};
    return {check_runs: []};
  }}), /develop/);
  assert.deepEqual(writes, [], 'A missing develop check must not leave main partially configured');
});
test('recovery refuses tampered bundles and only stages a candidate for current tests', () => {
  const dir = mkdtempSync(join(tmpdir(), 'sta104-recovery-'));
  try {
    const receipt = receiptFor(), files = ['firestore.rules', 'database.rules.json', 'storage.rules'];
    for (const file of files) writeFileSync(join(dir, file), readFileSync(file));
    const plan = prepareRecovery({receipt, bundle: dir, output: join(dir, 'build', 'candidate')});
    assert.equal(plan.status, 'requires-current-contracts');
    writeFileSync(join(dir, 'firestore.rules'), 'allow write: if true;');
    assert.throws(() => prepareRecovery({receipt, bundle: dir, output: join(dir, 'build', 'candidate')}), /changed/);
  } finally { rmSync(dir, {recursive: true, force: true}); }
});
