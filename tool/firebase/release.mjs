import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {copyFileSync, mkdirSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import {readJson, writeJson, hashFile, hash, canonical, filesIn} from './common.mjs';

export const targets = Object.freeze({project: 'cloud-board-stationd', firestore: '(default)',
  database: 'cloud-board-stationd-default-rtdb', databaseURL: 'https://cloud-board-stationd-default-rtdb.asia-southeast1.firebasedatabase.app',
  storage: 'cloud-board-stationd.firebasestorage.app'});
export const ruleFiles = ['firestore.rules', 'database.rules.json', 'storage.rules'];
export function identity(env = process.env) {
  const sha = env.GITHUB_SHA || execFileSync('git', ['rev-parse', 'HEAD'], {encoding: 'utf8'}).trim();
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
export function makeManifest() {
  const id = identity();
  validateReport(readJson('build/firebase-contracts/report.json'), id);
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
    'tool/firebase/supported-clients.json', 'tool/firebase/contract-suites.json',
    ...filesIn('functions/src'), ...filesIn('functions/tools'), ...filesIn('functions/certificates'), ...filesIn('functions/test/fixtures'), ...filesIn('build/contracts'),
    ...filesIn('build/web'), ...filesIn('build/firebase-contracts')];
  assert(paths.some(p => p === 'build/web/index.html'), 'Missing release web build');
  assert(!paths.some(p => p.startsWith('build/web/') && p.endsWith('.map')), 'Public source map');
  return {format: 1, ...id, targets, databaseSemanticHash: hash(canonical(readJson('database.rules.json'))), createdAt: new Date().toISOString(),
    files: Object.fromEntries(paths.sort().map(path => [path, hashFile(path)]))};
}
export function verifyManifest(manifest, id = identity()) {
  assert.equal(manifest.format, 1);
  for (const key of ['sha', 'runId', 'attempt']) assert.equal(manifest[key], id[key], `Manifest ${key} mismatch`);
  assert.deepEqual(manifest.targets, targets, 'Wrong Firebase target');
  assert.equal(manifest.databaseSemanticHash, hash(canonical(readJson('database.rules.json'))));
  for (const path of ruleFiles) assert(manifest.files[path], `Missing ${path}`);
  for (const [path, digest] of Object.entries(manifest.files)) {
    assert(!path.includes('..') && !path.startsWith('/') && /^[a-zA-Z0-9_./-]+$/.test(path), 'Unsafe manifest path');
    assert.equal(hashFile(path), digest, `Artifact changed: ${path}`);
  }
  for (const directory of ['build/web', 'functions/src', 'functions/tools', 'functions/certificates']) {
    assert.deepEqual(filesIn(directory), Object.keys(manifest.files).filter(p => p.startsWith(`${directory}/`)).sort(), `Files added/removed after verification: ${directory}`);
  }
  validateReport(readJson('build/firebase-contracts/report.json'), id);
}
export const manifestHash = manifest => hash(canonical(manifest));
export function validateReceipt(receipt, id) {
  assert.equal(receipt.format, 1);
  assert.equal(receipt.status, 'success');
  assert(Number.isFinite(Date.parse(receipt.completedAt)), 'Missing release completion time');
  for (const key of ['sha', 'runId', 'attempt']) assert.equal(String(receipt[key]), String(id[key]), `Receipt ${key} mismatch`);
  assert.deepEqual(receipt.manifest.targets, targets);
  assert.equal(receipt.manifestHash, manifestHash(receipt.manifest));
  assert.match(receipt.manifest.databaseSemanticHash || '', /^[a-f0-9]{64}$/);
  for (const key of ['sha', 'runId', 'attempt']) assert.equal(receipt.manifest[key], String(id[key]));
  for (const path of ruleFiles) assert.match(receipt.manifest.files[path] || '', /^[a-f0-9]{64}$/);
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
export async function requireCurrentMain({sha, ref, repository, request}) {
  assert.equal(ref, 'refs/heads/main', 'Production requires main');
  assert.match(sha || '', /^[a-f0-9]{40}$/);
  const current = await request(`/repos/${repository}/git/ref/heads/main`);
  assert.equal(current.object?.sha, sha, 'Superseded main commit: production change blocked');
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
    requireSuccess(JSON.parse(process.env.REQUIRED_JOBS || '{}'), ['app_validation', 'firebase_contracts']);
    mkdirSync('build/release/rules', {recursive: true});
    for (const file of ruleFiles) copyFileSync(file, `build/release/rules/${file}`);
    writeJson('build/release/manifest.json', makeManifest());
  } else if (command === 'verify') verifyManifest(readJson('build/release/manifest.json'));
  else if (command === 'current') await requireCurrentMain({sha: process.env.GITHUB_SHA, ref: process.env.GITHUB_REF, repository: process.env.GITHUB_REPOSITORY, request: github});
  else if (command === 'ready') {
    await requireCurrentMain({sha: process.env.GITHUB_SHA, ref: process.env.GITHUB_REF, repository: process.env.GITHUB_REPOSITORY, request: github});
    const manifest = readJson('build/release/manifest.json'); verifyManifest(manifest);
    const receipt = {format: 1, ...identity(), status: 'success', completedAt: new Date().toISOString(), manifest, manifestHash: manifestHash(manifest),
      rules: readJson('build/release/live-rules.json'), smoke: readJson('build/release/smoke.json')};
    validateReceipt(receipt, identity());
    writeJson('build/release/release.json', receipt);
  } else throw new Error('Expected aggregate, verify, current or ready');
}
