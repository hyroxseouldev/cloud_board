import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {appendFileSync, copyFileSync, mkdirSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import {readJson, writeJson, hashFile, hash, canonical, filesIn} from './common.mjs';
import {retirementPolicyFile, validateRetirements} from './support_retirements.mjs';
import {releaseValidationFile, validateReleaseValidation} from './release-validation.mjs';
// A dynamic import here deadlocks when this module's CLI awaits the caller:
// latest-release imports these shared guards back from this module.
import {latestRelease} from './latest-release.mjs';
import {verifySmokeInputs} from './smoke-inputs.mjs';

export const targets = Object.freeze({project: 'cloud-board-stationd', firestore: '(default)',
  database: 'cloud-board-stationd-default-rtdb', databaseURL: 'https://cloud-board-stationd-default-rtdb.asia-southeast1.firebasedatabase.app',
  storage: 'cloud-board-stationd.firebasestorage.app'});
export const ruleFiles = ['firestore.rules', 'database.rules.json', 'storage.rules'];
export function deploymentScope(value = process.env.FIREBASE_DEPLOY_SCOPE || 'full') {
  assert(['full', 'backend', 'rules', 'web', 'none', 'verify'].includes(value), 'Invalid deployment scope');
  return value;
}
// Receipts created before scoped repairs represented full backend + Hosting
// publication. New receipts must bind their scope in both signed metadata maps.
export function receiptScope(receipt) {
  const scope = deploymentScope(receipt.manifest.scope === undefined ? 'full' : receipt.manifest.scope);
  assert.equal(receipt.scope === undefined ? 'full' : receipt.scope, scope, 'Receipt deployment scope mismatch');
  return scope;
}
export function identity(env = process.env) {
  const sha = env.RELEASE_SOURCE_SHA || env.GITHUB_SHA || execFileSync('git', ['rev-parse', 'HEAD'], {encoding: 'utf8'}).trim();
  assert.match(sha, /^[a-f0-9]{40}$/);
  return {sha, runId: env.GITHUB_RUN_ID || 'local', attempt: env.GITHUB_RUN_ATTEMPT || '1'};
}
export function validateReport(report, expected, suites = readJson('tool/firebase/contract-suites.json')) {
  assert.equal(report.format, 1);
  for (const key of ['sha', 'runId', 'attempt']) assert.equal(report[key], expected[key], `Report ${key} mismatch`);
  assert.equal(report.status, 'success', 'Rules contracts did not pass');
  assert.equal(report.manifestHash, hashFile('tool/firebase/contract-suites.json'));
  assert.deepEqual(report.suites.map(s => s.id).sort(), suites.suites.map(s => s.id).sort(), 'Missing/duplicate suite');
  for (const suite of suites.suites) {
    const result = report.suites.find(s => s.id === suite.id);
    assert.equal(result.status, 'success', `Suite did not succeed: ${suite.id}`);
    assert.equal(result.file, suite.file);
    assert.equal(result.project, suite.project);
    const expectedCoverage = suite.coverage.flatMap(service => ['json', 'html'].map(ext => `build/firebase-contracts/${suite.id}-${service}.${ext}.gz`)).sort();
    assert.deepEqual(result.coverage.map(c => c.file).sort(), expectedCoverage, `Missing coverage: ${suite.id}`);
    for (const file of [...result.coverage, result.log]) {
      assert(file && /^build\/firebase-contracts\/[a-z0-9.-]+$/.test(file.file));
      assert.equal(hashFile(file.file), file.sha256, `Test evidence changed: ${file.file}`);
    }
  }
}
export function requireSuccess(needs, required) {
  assert.deepEqual(Object.keys(needs).sort(), [...required].sort());
  for (const name of required) assert.equal(needs[name]?.result, 'success', `Required job ${name} did not succeed`);
}
export function requireReleaseJobs(needs, scope = deploymentScope(), releaseTag = process.env.RELEASE_TAG,
  validationMode = process.env.RELEASE_VALIDATION_MODE || 'required') {
  assert(['required', 'skipped'].includes(validationMode), 'Unknown release validation mode');
  if (validationMode === 'skipped') {
    assert(isReleaseTag(releaseTag), 'CI skip requires a release tag');
    assert(['web', 'rules', 'backend', 'full'].includes(scope), 'Validation-only runs cannot skip CI');
    for (const name of ['app_validation', 'class_start_regressions', 'firebase_contracts']) {
      assert.equal(needs[name]?.result, 'skipped', `Skipped CI requires an explicit skipped result: ${name}`);
    }
  }
  const required = ['deployment_plan', ...(['web', 'full', 'verify'].includes(scope) ? ['web_build'] : []),
    ...(validationMode === 'skipped' && includesBackend(scope) ? ['smoke_inputs'] : []),
    ...(validationMode === 'required' && (releaseTag || ['web', 'full', 'verify'].includes(scope)) ? ['app_validation', 'class_start_regressions'] : []),
    ...(validationMode === 'required' && ['backend', 'rules', 'full', 'verify'].includes(scope) ? ['firebase_contracts'] : [])];
  for (const name of required) assert.equal(needs[name]?.result, 'success', `Required job ${name} did not succeed`);
  for (const [name, job] of Object.entries(needs)) assert(required.includes(name) || job.result === 'skipped', `Unexpected job result: ${name}`);
}
function currentValidation(id = identity()) {
  const mode = process.env.RELEASE_VALIDATION_MODE;
  if (mode === undefined) return null; // Existing receipts and local legacy verification retain required CI.
  const validation = validateReleaseValidation(readJson(releaseValidationFile), {sourceSha: id.sha,
    releaseTag: process.env.RELEASE_TAG || '', runId: id.runId, runAttempt: id.attempt, validationMode: mode});
  if (mode === 'skipped') {
    assert.equal(process.env.GITHUB_EVENT_NAME, 'workflow_dispatch', 'CI skip requires an explicit manual dispatch');
    assert.equal(process.env.GITHUB_REF, `refs/tags/${validation.releaseTag}`, 'CI skip requires its release tag ref');
    assert(['web', 'rules', 'backend', 'full'].includes(deploymentScope()), 'Validation-only runs cannot skip CI');
  }
  return validation;
}
function validateManifestValidation(manifest) {
  if (manifest.validation === undefined) return 'required';
  const validation = validateReleaseValidation(manifest.validation, {sourceSha: manifest.sha,
    releaseTag: manifest.releaseTag || '', runId: manifest.runId, runAttempt: manifest.attempt});
  assert.equal(manifest.files[releaseValidationFile], hash(`${JSON.stringify(validation, null, 2)}\n`), 'Release validation audit hash mismatch');
  if (validation.validationMode === 'skipped') {
    assert(!Object.keys(manifest.files).some(path => /^(build\/contracts\/|build\/firebase-contracts\/)/.test(path)),
      'Skipped CI must not claim contract test evidence');
  }
  return validation.validationMode;
}
function backendInputs(sourceSha) {
  const read = path => sourceSha ? execFileSync('git', ['show', `${sourceSha}:${path}`]) : null;
  const config = sourceSha ? JSON.parse(read('firebase.json')) : readJson('firebase.json');
  const sources = sourceSha ? execFileSync('git', ['ls-tree', '-r', '--name-only', sourceSha, '--', 'functions/src', 'functions/certificates'], {encoding: 'utf8'}).trim().split('\n').filter(Boolean)
    : [...filesIn('functions/src'), ...filesIn('functions/certificates')];
  const files = [...ruleFiles, 'firestore.indexes.json', 'functions/package.json', 'functions/package-lock.json', ...sources].sort();
  return {config: {functions: config.functions, firestore: config.firestore, database: config.database, storage: config.storage},
    files: Object.fromEntries(files.map(path => [path, sourceSha ? hash(read(path)) : hashFile(path)]))};
}
export const backendFingerprint = sourceSha => hash(canonical(backendInputs(sourceSha)));
export function functionsFingerprint(sourceSha) {
  const inputs = backendInputs(sourceSha);
  return hash(canonical({config: inputs.config.functions,
    files: Object.fromEntries(Object.entries(inputs.files).filter(([path]) => path.startsWith('functions/')))}));
}
export const includesBackend = scope => ['full', 'backend', 'rules'].includes(scope);
export const includesWeb = scope => ['full', 'web'].includes(scope);
export function validateReaderReport(report) {
  assert.equal(report.format, 1);
  assert.equal(report.status, 'success', 'Released readers did not pass');
  assert.equal(report.harnessSha256, hashFile('tool/firebase/released_reader_contract_test.dart'), 'Released reader harness changed');
  assert.equal(report.policySha256, hashFile('tool/firebase/compatibility-policy.json'), 'Compatibility exception policy changed');
  assert.equal(report.retirementPolicySha256, hashFile(retirementPolicyFile), 'Support retirement policy changed');
  const registry = readJson('tool/firebase/supported-clients.json');
  const retired = validateRetirements(registry, readJson(retirementPolicyFile));
  const expected = new Map();
  for (const client of registry.clients) {
    expected.set(client.sourceCommit, [...(expected.get(client.sourceCommit) || []), client.client]);
  }
  assert.deepEqual(report.sources.map(source => source.sourceCommit).sort(), [...expected.keys()].sort(), 'Missing released source reader');
  for (const source of report.sources) {
    const retirement = retired.get(source.sourceCommit) || null;
    assert.equal(source.status, retirement ? 'retired' : 'success', `Released reader did not pass: ${source.sourceCommit}`);
    assert.deepEqual(source.retirement, retirement, 'Released source retirement evidence mismatch');
    assert.deepEqual([...source.clients].sort(), expected.get(source.sourceCommit).sort(), 'Missing released client reader');
  }
  assert.deepEqual(Object.keys(report.candidateFiles).sort(), ['build/contracts/app-current.json', 'build/contracts/workout-save-current.json']);
  for (const [file, digest] of Object.entries(report.candidateFiles)) assert.equal(hashFile(file), digest, `Released-reader input changed: ${file}`);
}
export function makeManifest() {
  const id = identity();
  const scope = deploymentScope();
  assert.notEqual(scope, 'none', 'No deployment candidate for unchanged components');
  const validation = currentValidation(id);
  const contractsRequired = validation?.validationMode !== 'skipped';
  const smokeInputsRequired = includesBackend(scope) && !contractsRequired;
  if (smokeInputsRequired) verifySmokeInputs({sourceSha: id.sha});
  if (includesBackend(scope) && contractsRequired) {
    validateReport(readJson('build/firebase-contracts/report.json'), id);
    validateReaderReport(readJson('build/contracts/released-readers/report.json'));
  }
  const config = readJson('firebase.json');
  assert.equal(config.firestore.rules, 'firestore.rules');
  assert.equal(config.firestore.database || '(default)', targets.firestore);
  assert.equal(config.database.rules, 'database.rules.json');
  assert.equal(config.hosting.public, 'build/web');
  assert.equal(config.functions.length, 1);
  assert.equal(config.functions[0].source, 'functions');
  assert.equal(config.functions[0].codebase, 'account-deletion');
  assert.deepEqual(config.storage, [{bucket: targets.storage, rules: 'storage.rules'}]);
  const paths = [...ruleFiles, 'firestore.indexes.json', 'firebase.json', 'functions/package.json', 'functions/package-lock.json',
    'tool/firebase/supported-clients.json', 'tool/firebase/contract-suites.json', 'tool/firebase/compatibility-policy.json', retirementPolicyFile, 'tool/firebase/support_retirements.mjs', 'tool/firebase/released_reader_contract_test.dart',
    ...filesIn('functions/src'), ...filesIn('functions/tools'), ...filesIn('functions/certificates'), ...filesIn('functions/test/fixtures'),
    ...(validation ? [releaseValidationFile] : []),
    ...(smokeInputsRequired ? filesIn('build/release/smoke-inputs') : []),
    ...(includesBackend(scope) && contractsRequired ? [...filesIn('build/contracts'), ...filesIn('build/firebase-contracts')] : []),
    ...(includesWeb(scope) ? filesIn('build/web') : [])];
  if (includesWeb(scope)) assert(paths.some(p => p === 'build/web/index.html'), 'Missing release web build');
  assert(!paths.some(p => p.startsWith('build/web/') && p.endsWith('.map')), 'Public source map');
  return {format: 1, ...id, scope, ...(validation ? {validation} : {}), ...(process.env.RELEASE_TAG ? {releaseTag: process.env.RELEASE_TAG} : {}), backendFingerprint: backendFingerprint(), functionsFingerprint: functionsFingerprint(), targets, databaseSemanticHash: hash(canonical(readJson('database.rules.json'))), createdAt: new Date().toISOString(),
    files: Object.fromEntries(paths.sort().map(path => [path, hashFile(path)]))};
}
export function verifyManifest(manifest, id = identity()) {
  assert.equal(manifest.format, 1);
  if (process.env.RELEASE_TAG) assert.equal(manifest.releaseTag, process.env.RELEASE_TAG, 'Candidate release tag mismatch');
  assert.equal(deploymentScope(manifest.scope === undefined ? 'full' : manifest.scope), deploymentScope(), 'Candidate deployment scope mismatch');
  for (const key of ['sha', 'runId', 'attempt']) assert.equal(manifest[key], id[key], `Manifest ${key} mismatch`);
  const validationMode = validateManifestValidation(manifest);
  assert.equal(validationMode, process.env.RELEASE_VALIDATION_MODE || 'required', 'Candidate validation mode mismatch');
  const validation = currentValidation(id);
  if (validation) assert.deepEqual(manifest.validation, validation, 'Candidate validation audit mismatch');
  const smokeInputsRequired = includesBackend(manifest.scope || 'full') && validationMode === 'skipped';
  if (smokeInputsRequired) verifySmokeInputs({sourceSha: id.sha});
  assert.deepEqual(manifest.targets, targets, 'Wrong Firebase target');
  assert.equal(manifest.databaseSemanticHash, hash(canonical(readJson('database.rules.json'))));
  for (const path of ruleFiles) assert(manifest.files[path], `Missing ${path}`);
  for (const path of [retirementPolicyFile, 'tool/firebase/support_retirements.mjs']) assert(manifest.files[path], `Missing ${path}`);
  for (const [path, digest] of Object.entries(manifest.files)) {
    assert(!path.includes('..') && !path.startsWith('/') && /^[a-zA-Z0-9_./-]+$/.test(path), 'Unsafe manifest path');
    assert.equal(hashFile(path), digest, `Artifact changed: ${path}`);
  }
  for (const directory of [...(includesWeb(manifest.scope || 'full') ? ['build/web'] : []),
    ...(smokeInputsRequired ? ['build/release/smoke-inputs'] : []), 'functions/src', 'functions/tools', 'functions/certificates']) {
    assert.deepEqual(filesIn(directory), Object.keys(manifest.files).filter(p => p.startsWith(`${directory}/`)).sort(), `Files added/removed after verification: ${directory}`);
  }
  if (includesBackend(manifest.scope || 'full') && validationMode === 'required') {
    validateReport(readJson('build/firebase-contracts/report.json'), id);
    validateReaderReport(readJson('build/contracts/released-readers/report.json'));
  }
  if (manifest.backendFingerprint) assert.equal(manifest.backendFingerprint, backendFingerprint(), 'Backend inputs changed');
}
export const manifestHash = manifest => hash(canonical(manifest));
export function validateReceipt(receipt, id) {
  assert.equal(receipt.format, 1);
  const scope = receiptScope(receipt);
  assert(['full', 'backend', 'rules', 'web'].includes(scope), 'Receipt must represent a deployment');
  if (id.scope) assert.equal(scope, id.scope, 'Wrong release scope');
  assert.equal(receipt.status, 'success');
  assert(Number.isFinite(Date.parse(receipt.completedAt)), 'Missing release completion time');
  for (const key of ['sha', 'runId', 'attempt']) assert.equal(String(receipt[key]), String(id[key]), `Receipt ${key} mismatch`);
  assert.deepEqual(receipt.manifest.targets, targets);
  assert.equal(receipt.manifestHash, manifestHash(receipt.manifest));
  validateManifestValidation(receipt.manifest);
  if (receipt.manifest.releaseTag !== undefined) assert(isReleaseTag(receipt.manifest.releaseTag), 'Invalid receipt release tag');
  assert.match(receipt.manifest.databaseSemanticHash || '', /^[a-f0-9]{64}$/);
  for (const key of ['sha', 'runId', 'attempt']) assert.equal(receipt.manifest[key], String(id[key]));
  for (const path of ruleFiles) assert.match(receipt.manifest.files[path] || '', /^[a-f0-9]{64}$/);
  if (scope === 'web') {
    assert(receipt.backend?.runId && receipt.backend?.fingerprint === receipt.manifest.backendFingerprint, 'Web receipt requires compatible deployed backend');
    return;
  }
  assert.equal(receipt.smoke.status, 'success');
  assert.equal(receipt.smoke.cleanup, 'success');
  assert.equal(receipt.smoke.runId, `${id.runId}-${id.attempt}`);
  assert.deepEqual(receipt.smoke.checks, ['workout', 'storage', 'tv', 'isolation']);
  assert.equal(receipt.rules.status, 'success');
  assert.deepEqual(Object.keys(receipt.rules.services).sort(), ['database', 'firestore', 'storage']);
  assert.equal(receipt.rules.services.database.semanticHash, receipt.manifest.databaseSemanticHash);
  for (const [service, file] of [['firestore', 'firestore.rules'], ['storage', 'storage.rules'], ['database', 'database.rules.json']]) {
    assert.equal(receipt.rules.services[service].sourceHash, receipt.manifest.files[file]);
    assert(receipt.rules.services[service].version);
  }
}
export const isReleaseTag = value => /^v(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)$/.test(value || '');
export async function resolveReleaseTag({tag, repository, request}) {
  assert(isReleaseTag(tag), 'Production requires an immutable vX.Y.Z release tag');
  let object = (await request(`/repos/${repository}/git/ref/tags/${tag}`)).object;
  for (let depth = 0; object?.type === 'tag' && depth < 5; depth++) {
    object = (await request(`/repos/${repository}/git/tags/${object.sha}`)).object;
  }
  assert.equal(object?.type, 'commit', 'Release tag must resolve to one commit');
  assert.match(object.sha || '', /^[a-f0-9]{40}$/);
  return object.sha;
}
export async function requireCurrentMain({sha, ref, tag = process.env.RELEASE_TAG, repository, request}) {
  assert.match(sha || '', /^[a-f0-9]{40}$/);
  tag ||= ref?.startsWith('refs/tags/') ? ref.slice('refs/tags/'.length) : '';
  assert(isReleaseTag(tag), 'Production requires an immutable vX.Y.Z release tag');
  assert.equal(ref, `refs/tags/${tag}`, 'Production retry must run on its release tag ref');
  assert.equal(await resolveReleaseTag({tag, repository, request}), sha, 'Release tag moved; production change blocked');
  const main = await request(`/repos/${repository}/compare/${sha}...main`);
  assert(['ahead', 'identical'].includes(main.status) && main.merge_base_commit?.sha === sha, 'Release source must be included in main');
  const previous = await request(`/repos/${repository}/actions/workflows/firebase-hosting-merge.yml/runs?branch=${tag}&per_page=100`);
  assert((previous.total_count ?? previous.workflow_runs?.length ?? 0) <= 100, 'Release tag history is too large to verify immutability');
  for (const run of previous.workflow_runs || []) {
    if (run.head_branch === tag && run.head_repository?.full_name === repository && ['push', 'workflow_dispatch'].includes(run.event)) {
      assert.equal(run.head_sha, sha, 'Release tag was reused for a different commit; create a new version tag');
    }
  }
}
export async function requireNoRollback({repository, sha, ref, tag, request, readArtifact, scope, ignoreRunId}) {
  await requireCurrentMain({repository, sha, ref, tag, request});
  for (const component of [...(includesBackend(scope) ? ['backend'] : []), ...(includesWeb(scope) ? ['web'] : [])]) {
    const previous = await latestRelease({repository, request, readArtifact, ignoreRunId, component, attemptOnly: true});
    const comparison = await request(`/repos/${repository}/compare/${previous.run.head_sha}...${sha}`);
    assert(['ahead', 'identical'].includes(comparison.status) && comparison.merge_base_commit?.sha === previous.run.head_sha,
      `A newer ${component} production attempt exists; refusing to deploy an older source`);
  }
}
export async function github(path, {method = 'GET', body} = {}) {
  assert(process.env.GITHUB_TOKEN, 'GitHub token required');
  const response = await fetch(`https://api.github.com${path}`, {method,
    headers: {Authorization: `Bearer ${process.env.GITHUB_TOKEN}`, Accept: 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28'},
    body: body ? JSON.stringify(body) : undefined, signal: AbortSignal.timeout(30_000)});
  if (!response.ok) throw new Error(`GitHub request failed (${response.status})`);
  return response.json();
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const command = process.argv[2];
  if (command === 'aggregate') {
    requireReleaseJobs(JSON.parse(process.env.REQUIRED_JOBS || '{}'));
    mkdirSync('build/release/rules', {recursive: true});
    for (const file of ruleFiles) copyFileSync(file, `build/release/rules/${file}`);
    const manifest = makeManifest();
    writeJson('build/release/manifest.json', manifest);
    if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY,
      manifest.validation?.validationMode === 'skipped'
        ? `CI **SKIPPED** by explicit manual request; test success is not claimed. Deployment prerequisites and artifact integrity passed.\n\nReason (JSON): ${JSON.stringify(manifest.validation.reason)}\n`
        : 'Required CI jobs and deployment artifact checks passed.\n');
  } else if (command === 'verify') verifyManifest(readJson('build/release/manifest.json'));
  else if (command === 'current') await requireNoRollback({sha: identity().sha, ref: process.env.GITHUB_REF, tag: process.env.RELEASE_TAG, repository: process.env.GITHUB_REPOSITORY, request: github, scope: deploymentScope(), ignoreRunId: process.env.GITHUB_RUN_ID});
  else if (command === 'ready') {
    await requireNoRollback({sha: identity().sha, ref: process.env.GITHUB_REF, tag: process.env.RELEASE_TAG, repository: process.env.GITHUB_REPOSITORY, request: github, scope: deploymentScope(), ignoreRunId: process.env.GITHUB_RUN_ID});
    const manifest = readJson('build/release/manifest.json'); verifyManifest(manifest);
    const receipt = {format: 1, ...identity(), scope: manifest.scope, status: 'success', completedAt: new Date().toISOString(), manifest, manifestHash: manifestHash(manifest),
      ...(manifest.scope === 'web' ? {backend: readJson('build/release/backend-reference.json')}
        : {rules: readJson('build/release/live-rules.json'), smoke: readJson('build/release/smoke.json')})};
    validateReceipt(receipt, identity());
    writeJson('build/release/release.json', receipt);
  } else throw new Error('Expected aggregate, verify, current or ready');
}
