import test from 'node:test';
import assert from 'node:assert/strict';
import {baselineSuites, validateMobileCompatibilityPlan, validateMobileCompatibilityReport,
  requireMobileCompatibility, compatibilityJob, compatibilityStep} from './mobile_backend_compatibility.mjs';

const sha = 'a'.repeat(40), server = 'b'.repeat(40), fingerprint = 'c'.repeat(64);
const repository = 'owner/repo', tag = 'v1.2.3';
const plan = {schemaVersion: 1, clientFingerprint: 'd'.repeat(64), backendFingerprint: fingerprint,
  reviewedBy: 'fixture-reviewer', summary: 'Old API remains usable; new optional feature waits.',
  emulatorSuites: ['functions/test/mobile-api-emulator.mjs'], clientTests: ['test/current_backend_test.dart'],
  deferredFeatures: [{id: 'nextFeature', beforeServer: 'waiting', guard: 'lib/next_feature.dart', test: 'test/next_feature_test.dart'}]};
const planOptions = {clientFingerprint: plan.clientFingerprint, backendFingerprint: fingerprint, readSource: path => Buffer.from(path)};
const run = {id: 100, run_attempt: 2, head_sha: sha, head_branch: tag, status: 'completed', conclusion: 'success',
  head_repository: {full_name: repository}, path: '.github/workflows/firebase-hosting-merge.yml', event: 'workflow_dispatch'};
const report = {schemaVersion: 1, kind: 'mobile-backend-compatibility', status: 'success', sourceSha: sha,
  releaseTag: tag, backendSourceSha: server, backendFingerprint: fingerprint, clientFingerprint: plan.clientFingerprint,
  runId: '100', runAttempt: '2', method: 'deployed-backend-contracts', planHash: 'e'.repeat(64),
  clientTests: ['test/current_backend_test.dart', 'test/next_feature_test.dart'],
  testedFiles: Object.fromEntries([...baselineSuites, ...plan.emulatorSuites,
    'test/current_backend_test.dart', 'test/next_feature_test.dart', 'lib/next_feature.dart'].map(path => [path, 'f'.repeat(64)])),
  deferredFeatures: plan.deferredFeatures,
  checks: ['candidate-exports', 'client-behavior', ...baselineSuites, ...plan.emulatorSuites].map(id => ({id, status: 'success'}))};
const expected = {sourceSha: sha, releaseTag: tag, backendFingerprint: fingerprint, run};

test('reviewed plan includes baseline rules, real callable checks and deferred-feature client tests', () => {
  const checked = validateMobileCompatibilityPlan(plan, planOptions);
  assert.deepEqual(checked.emulatorSuites, [...baselineSuites, ...plan.emulatorSuites]);
  assert.deepEqual(checked.clientTests, ['test/current_backend_test.dart', 'test/next_feature_test.dart']);
  assert(checked.files['lib/next_feature.dart']);
  assert.match(checked.planHash, /^[a-f0-9]{64}$/);
});

test('stale, empty and incomplete plans cannot replace server fingerprint equality', () => {
  for (const patch of [
    {clientFingerprint: 'f'.repeat(64)}, {backendFingerprint: 'f'.repeat(64)}, {reviewedBy: ''}, {summary: ''},
    {emulatorSuites: []}, {emulatorSuites: baselineSuites}, {clientTests: []}, {deferredFeatures: undefined},
    {emulatorSuites: ['functions/test/../../escape-emulator.mjs']},
    {clientTests: ['test/test.dart; touch bad']},
    {deferredFeatures: [{...plan.deferredFeatures[0], beforeServer: 'enabled'}]},
    {deferredFeatures: [{...plan.deferredFeatures[0], test: undefined}]},
    {deferredFeatures: [plan.deferredFeatures[0], plan.deferredFeatures[0]]},
  ]) assert.throws(() => validateMobileCompatibilityPlan({...plan, ...patch}, planOptions));
  assert.throws(() => validateMobileCompatibilityPlan(plan, {...planOptions, readSource: () => Buffer.from('')}));
});

test('compatibility evidence binds app, tag, server, run and attempt without claiming device validation', () => {
  assert.equal(validateMobileCompatibilityReport(report, expected), report);
  for (const patch of [
    {status: 'failure'}, {sourceSha: server}, {releaseTag: 'v1.2.4'}, {backendFingerprint: '0'.repeat(64)},
    {runId: '101'}, {runAttempt: '1'}, {planHash: ''}, {method: 'identical-backend'}, {checks: []},
    {checks: report.checks.map((check, i) => i === 0 ? {...check, status: 'skipped'} : check)},
    {checks: report.checks.filter(check => check.id !== 'client-behavior')},
    {deferredFeatures: undefined}, {clientTests: []}, {testedFiles: {}},
    {clientTests: ['test/current_backend_test.dart']},
    {checks: [...report.checks, report.checks[0]]},
  ]) assert.throws(() => validateMobileCompatibilityReport({...report, ...patch}, expected));
});

function lookup(overrides = {}) {
  const paths = [];
  return {paths, args: {repository, sha, releaseTag: tag, backendFingerprint: fingerprint,
    request: async path => {
      paths.push(path);
      if (path.includes('/runs?')) return overrides.runs ?? {total_count: 1, workflow_runs: [run]};
      if (path.includes('/jobs?')) return overrides.jobs ?? {total_count: 1, jobs: [{name: compatibilityJob, conclusion: 'success',
        steps: [{name: compatibilityStep, conclusion: 'success'}]}]};
      if (path.includes('/artifacts?')) return overrides.artifacts ?? {total_count: 1,
        artifacts: [{id: 55, name: 'mobile-backend-compatibility-100-2', expired: false}]};
      throw new Error('unexpected request');
    }, readArtifact: async artifact => {assert.equal(artifact.id, 55); return overrides.report ?? report;}}};
}

test('successful exact-run contract proof authorizes mobile against the older deployed backend', async () => {
  const f = lookup();
  const evidence = await requireMobileCompatibility(f.args);
  assert.equal(evidence.method, 'deployed-backend-contracts');
  assert.equal(evidence.validationRunId, '100');
  assert.equal(f.paths.length, 3);
});

test('newer failed or pending checks cannot fall back to an older passing compatibility proof', async () => {
  for (const patch of [{conclusion: 'failure'}, {conclusion: 'cancelled'}, {status: 'in_progress'}, {run_attempt: undefined}]) {
    const f = lookup({runs: {total_count: 2, workflow_runs: [run, {...run, id: 101, ...patch}]}});
    await assert.rejects(requireMobileCompatibility(f.args));
    assert.equal(f.paths.length, 1);
  }
});

test('foreign, wrong-tag, skipped, expired and tampered compatibility evidence fails closed', async () => {
  for (const overrides of [
    {runs: {total_count: 0, workflow_runs: []}},
    {runs: {total_count: 101, workflow_runs: [run]}},
    {runs: {total_count: 1, workflow_runs: [{...run, head_repository: {full_name: 'other/repo'}}]}},
    {runs: {total_count: 1, workflow_runs: [{...run, head_branch: 'v1.2.4'}]}},
    {runs: {total_count: 1, workflow_runs: [{...run, path: '.github/workflows/untrusted.yml'}]}},
    {jobs: {total_count: 1, jobs: [{name: compatibilityJob, conclusion: 'skipped'}]}},
    {jobs: {total_count: 1, jobs: [{name: compatibilityJob, conclusion: 'success',
      steps: [{name: compatibilityStep, conclusion: 'skipped'}]}]}},
    {artifacts: {total_count: 0, artifacts: []}},
    {artifacts: {total_count: 2, artifacts: []}},
    {artifacts: {total_count: 1, artifacts: [{id: 55, name: 'mobile-backend-compatibility-100-2', expired: true}]}},
    {artifacts: {total_count: 1, artifacts: [{id: 55, name: 'mobile-backend-compatibility-100-1', expired: false}]}},
    {report: {...report, backendFingerprint: 'f'.repeat(64)}},
    {report: {...report, sourceSha: server}},
  ]) await assert.rejects(requireMobileCompatibility(lookup(overrides).args));
  await assert.rejects(requireMobileCompatibility({...lookup().args, readArtifact: async () => {throw new Error('digest mismatch');}}),
    /digest mismatch/);
});
