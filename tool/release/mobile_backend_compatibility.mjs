import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {hash, canonical} from '../firebase/common.mjs';
import {isReleaseTag} from '../firebase/release.mjs';
import {productionRuns} from '../firebase/release-runs.mjs';

export const mobileCompatibilityPlan = 'release-notes/mobile-compatibility.json';
export const compatibilityJob = 'mobile-backend-compatibility';
export const compatibilityStep = 'Test mobile against deployed backend';
export const baselineSuites = [
  'functions/test/workout-save-emulator.mjs',
  'functions/test/app-contracts-emulator.mjs',
  'functions/test/storage-rules-emulator.mjs',
];
const shaPattern = /^[a-f0-9]{40}$/;
const hashPattern = /^[a-f0-9]{64}$/;
const git = (...args) => execFileSync('git', args, {encoding: 'utf8', maxBuffer: 16 * 1024 * 1024}).trim();

// Excludes the plan itself so it can be committed with the reviewed inputs.
// Include tests and native configuration: stale declarations cannot authorize a
// changed app, even when its marketing version did not change.
export function mobileClientFingerprint(sha) {
  assert.match(sha || '', shaPattern);
  const entries = git('ls-tree', '-r', sha, '--', 'lib', 'ios', 'android', 'assets', 'config',
    'test', 'pubspec.yaml', 'pubspec.lock', '.fvmrc',
    'tool/export_workout_save_fixtures_test.dart', 'tool/export_app_contracts_test.dart');
  assert(entries.includes('\tpubspec.yaml') && entries.includes('\tlib/'), 'Missing mobile source inventory');
  return hash(entries);
}

export function validateMobileCompatibilityPlan(plan, {clientFingerprint, backendFingerprint, readSource}) {
  assert.equal(plan?.schemaVersion, 1, 'Missing reviewed mobile compatibility plan');
  assert.equal(plan.clientFingerprint, clientFingerprint, 'Mobile compatibility plan is stale for this app');
  assert.equal(plan.backendFingerprint, backendFingerprint, 'Mobile compatibility plan targets another backend');
  assert.match(plan.clientFingerprint, hashPattern);
  assert.match(plan.backendFingerprint, hashPattern);
  assert(typeof plan.reviewedBy === 'string' && plan.reviewedBy.trim(), 'Compatibility reviewer is required');
  assert(typeof plan.summary === 'string' && plan.summary.trim(), 'Explain the compatible and deferred behavior');
  const files = new Map();
  const file = (path, pattern) => {
    assert(typeof path === 'string' && pattern.test(path) && !path.split('/').includes('..'), 'Invalid compatibility test or guard path');
    const content = readSource(path);
    assert(content.length > 0, `Missing compatibility source: ${path}`);
    files.set(path, hash(content));
  };
  assert(Array.isArray(plan.emulatorSuites) && plan.emulatorSuites.length > 0, 'Add focused callable/backend contract tests');
  assert(Array.isArray(plan.clientTests) && plan.clientTests.length > 0, 'Add current-server client behavior tests');
  assert(Array.isArray(plan.deferredFeatures), 'Declare deferred features, or an explicit empty array');
  const emulatorSuites = [...new Set([...baselineSuites, ...plan.emulatorSuites])];
  for (const path of emulatorSuites) file(path, /^functions\/test\/[a-zA-Z0-9_/-]+-emulator\.mjs$/);
  // Baseline DTO/rules replays do not cover callable contracts.
  assert(plan.emulatorSuites.some(path => !baselineSuites.includes(path)), 'A focused callable/backend suite is required in addition to baseline rules');
  const clientTests = new Set(plan.clientTests), ids = new Set();
  for (const feature of plan.deferredFeatures) {
    assert(/^[a-zA-Z][a-zA-Z0-9_-]*$/.test(feature.id || '') && !ids.has(feature.id), 'Invalid or duplicate deferred feature');
    ids.add(feature.id);
    assert(['disabled', 'waiting'].includes(feature.beforeServer), 'New server features must be disabled or waiting');
    file(feature.guard, /^lib\/[a-zA-Z0-9_/-]+\.dart$/);
    assert(typeof feature.test === 'string', 'Deferred feature requires an executable client test');
    clientTests.add(feature.test);
  }
  for (const path of clientTests) file(path, /^test\/[a-zA-Z0-9_/-]+_test\.dart$/);
  return {emulatorSuites, clientTests: [...clientTests], deferredFeatures: plan.deferredFeatures,
    planHash: hash(canonical(plan)), files: Object.fromEntries(files)};
}

export function validateMobileCompatibilityReport(report, {sourceSha, releaseTag, backendFingerprint, run}) {
  assert.equal(report?.schemaVersion, 1);
  assert.equal(report.kind, 'mobile-backend-compatibility');
  assert.equal(report.status, 'success', 'Mobile/backend contracts did not pass');
  assert.equal(report.sourceSha, sourceSha, 'Compatibility proof belongs to another app');
  assert.equal(report.releaseTag, releaseTag, 'Compatibility proof belongs to another tag');
  assert.equal(report.backendFingerprint, backendFingerprint, 'Production backend changed after compatibility testing');
  assert.equal(report.runId, String(run.id), 'Compatibility proof belongs to another run');
  assert.equal(report.runAttempt, String(run.run_attempt), 'Compatibility proof belongs to another attempt');
  assert.match(report.backendSourceSha || '', shaPattern);
  assert.match(report.clientFingerprint || '', hashPattern);
  assert.match(report.planHash || '', hashPattern);
  assert.equal(report.method, 'deployed-backend-contracts', 'A source match alone cannot approve a different backend');
  assert(Array.isArray(report.checks) && report.checks.length >= 6, 'Incomplete mobile/backend checks');
  assert(report.checks.every(check => check.status === 'success'), 'Failed compatibility check');
  assert.equal(new Set(report.checks.map(check => check.id)).size, report.checks.length, 'Duplicate compatibility checks');
  for (const id of ['candidate-exports', 'client-behavior', ...baselineSuites]) {
    assert(report.checks.some(check => check.id === id), `Missing compatibility check: ${id}`);
  }
  assert(report.checks.some(check => check.id.startsWith('functions/test/') && !baselineSuites.includes(check.id)),
    'Missing callable/backend contract check');
  assert(Array.isArray(report.deferredFeatures), 'Missing deferred feature evidence');
  assert(Array.isArray(report.clientTests) && report.clientTests.length > 0, 'Missing executed client tests');
  for (const path of [...report.clientTests, ...report.checks.map(check => check.id).filter(id => id.startsWith('functions/test/'))]) {
    assert.match(report.testedFiles?.[path] || '', hashPattern, 'Missing tested source hash');
  }
  for (const feature of report.deferredFeatures) {
    assert(['disabled', 'waiting'].includes(feature.beforeServer) && report.clientTests.includes(feature.test),
      'Deferred feature behavior was not tested');
    assert.match(report.testedFiles?.[feature.guard] || '', hashPattern, 'Missing deferred feature guard evidence');
  }
  return report;
}

function inventory(response, field) {
  assert(Number.isInteger(response.total_count) && response.total_count >= 0 && response.total_count <= 100 &&
    Array.isArray(response[field]) && response[field].length === response.total_count,
  `Cannot verify complete compatibility ${field} inventory`);
  return response[field];
}

export async function requireMobileCompatibility({repository, sha, releaseTag, backendFingerprint, request, readArtifact}) {
  assert.match(repository || '', /^[\w.-]+\/[\w.-]+$/);
  assert.match(sha || '', shaPattern);
  assert(isReleaseTag(releaseTag), 'Mobile-first upload requires a fixed release tag');
  const response = await request(`/repos/${repository}/actions/workflows/firebase-hosting-merge.yml/runs?head_sha=${sha}&per_page=100`);
  const run = productionRuns(inventory(response, 'workflow_runs'), repository, sha).find(value => value.head_branch === releaseTag);
  assert(run?.status === 'completed' && run.conclusion === 'success' &&
    run.path === '.github/workflows/firebase-hosting-merge.yml' &&
    Number.isSafeInteger(run.run_attempt) && run.run_attempt > 0 && Number.isSafeInteger(run.id) && run.id > 0,
  'No successful current mobile compatibility run. Run release-tag verify with deploy_mobile=true; do not skip this check.');
  const jobs = await request(`/repos/${repository}/actions/runs/${run.id}/attempts/${run.run_attempt}/jobs?per_page=100`);
  assert(inventory(jobs, 'jobs').filter(job => job.name === compatibilityJob &&
    job.conclusion === 'success' && job.steps?.some(step => step.name === compatibilityStep &&
      step.conclusion === 'success')).length === 1, 'Mobile compatibility test job did not pass');
  const artifacts = await request(`/repos/${repository}/actions/runs/${run.id}/artifacts?per_page=100`);
  const matches = inventory(artifacts, 'artifacts').filter(artifact => artifact.name === `mobile-backend-compatibility-${run.id}-${run.run_attempt}`);
  assert(matches.length === 1 && !matches[0].expired, 'Missing, expired or ambiguous mobile compatibility artifact');
  const report = validateMobileCompatibilityReport(await readArtifact(matches[0]),
    {sourceSha: sha, releaseTag, backendFingerprint, run});
  return {method: report.method, validationRunId: String(run.id), validationRunAttempt: String(run.run_attempt),
    clientFingerprint: report.clientFingerprint, planHash: report.planHash, deferredFeatures: report.deferredFeatures};
}
