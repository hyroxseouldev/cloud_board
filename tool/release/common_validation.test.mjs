import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {mkdtempSync, readFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {requireCommonValidation} from './common_validation.mjs';
const sha = 'a'.repeat(40), repository = 'owner/repo';
const run = (id, extra = {}) => ({id, head_sha: sha, head_branch: 'v1.2.3', head_repository: {full_name: repository},
  event: 'push', status: 'completed', conclusion: 'success', run_attempt: 1, run_started_at: `2026-10-15T00:0${id}:00Z`, ...extra});
const successfulJobs = [
  {name: 'app-validation', conclusion: 'success', steps: ['Analyze', 'Test'].map(name => ({name, conclusion: 'success'}))},
  {name: 'class_start_regressions / Class start lifecycle and TV preparation', conclusion: 'success',
    steps: ['Required native logic regressions', 'Required web regressions'].map(name => ({name, conclusion: 'success'}))},
];
test('release reuses completed successful tag CI with concrete app validation', async () => {
  const selected = await requireCommonValidation({repository, sha, request: async path => path.includes('/workflows/')
    ? {workflow_runs: [run(1)]} : {jobs: successfulJobs}});
  assert.equal(selected.id, 1);
});
test('manual release cannot bypass failed Firebase contracts or incomplete tag CI despite green app checks', async () => {
  for (const extra of [
    {status: 'queued', conclusion: null}, {status: 'in_progress', conclusion: null},
    ...['failure', 'cancelled', 'timed_out', 'skipped', 'neutral', null].map(conclusion => ({conclusion})),
  ]) {
    await assert.rejects(requireCommonValidation({repository, sha, request: async path => path.includes('/workflows/')
      ? {workflow_runs: [run(2, extra), run(1)]}
      : {jobs: [...successfulJobs, {name: 'firebase-contracts', conclusion: 'failure'}]}}),
    /Latest release validation workflow has not completed successfully/);
  }
});
test('latest retry must pass; no fallback to older green runs or lightweight handoff checks', async () => {
  for (const state of ['failure', 'skipped', null]) {
    await assert.rejects(requireCommonValidation({repository, sha, request: async path => path.includes('/workflows/')
      ? {workflow_runs: [run(2), run(1)]}
      : {jobs: path.includes('/runs/2/') ? [{name: 'app-validation', conclusion: state}, {name: 'firebase-required', conclusion: 'success'}] : successfulJobs}}), /Latest release validation/);
  }
  await assert.rejects(requireCommonValidation({repository, sha, request: async path => path.includes('/workflows/')
    ? {workflow_runs: [run(1, {run_attempt: 2})]} : {jobs: successfulJobs.map(j => ({...j, steps: []}))}}), /Latest release validation/);
});
test('foreign, PR and different source validations cannot approve a release', async () => {
  for (const extra of [{event: 'pull_request'}, {head_branch: 'develop'}, {head_branch: 'main'}, {head_sha: 'b'.repeat(40)}, {head_repository: {full_name: 'fork/repo'}}]) {
    await assert.rejects(requireCommonValidation({repository, sha, request: async () => ({workflow_runs: [run(1, extra)]})}), /No release integration/);
  }
});

const plannedSkipJobs = [
  {name: 'Verify deployment target', conclusion: 'success'},
  ...successfulJobs.map(job => ({name: job.name, conclusion: 'skipped'})),
];
test('tag retries must run common checks even when deployment planning succeeds', async () => {
  for (const conclusion of ['success', 'failure', null]) {
    for (const skippedName of [successfulJobs[1].name, 'class_start_regressions']) {
      const skippedJobs = plannedSkipJobs.map(job => job.name === successfulJobs[1].name ? {...job, name: skippedName} : job);
      await assert.rejects(requireCommonValidation({repository, sha, request: async path => path.includes('/workflows/')
        ? {workflow_runs: [run(2, {event: 'workflow_dispatch', conclusion}), run(1)]}
        : {jobs: path.includes('/runs/2/') ? skippedJobs : successfulJobs}}), /Latest release validation/);
    }
  }
});
test('cancelled, unplanned, partial, pending, failed or missing common validation still blocks older success', async () => {
  const cases = [
    {conclusion: 'cancelled', jobs: plannedSkipJobs},
    {jobs: plannedSkipJobs.slice(1)},
    {jobs: plannedSkipJobs.map(job => job.name === 'Verify deployment target' ? {...job, conclusion: 'failure'} : job)},
    ...['success', 'failure', null].map(conclusion => ({jobs: plannedSkipJobs.map(job =>
      job.name === 'app-validation' ? {...job, conclusion} : job)})),
    {jobs: plannedSkipJobs.filter(job => job.name !== 'app-validation')},
  ];
  for (const candidate of cases) {
    await assert.rejects(requireCommonValidation({repository, sha, request: async path => path.includes('/workflows/')
      ? {workflow_runs: [run(2, {conclusion: candidate.conclusion ?? 'success'}), run(1)]}
      : {jobs: path.includes('/runs/2/') ? candidate.jobs : successfulJobs}}), /Latest release validation/);
  }
});
test('planned non-validation runs cannot authorize release when no actual common validation exists', async () => {
  await assert.rejects(requireCommonValidation({repository, sha, request: async path => path.includes('/workflows/')
    ? {workflow_runs: [run(1)]} : {jobs: plannedSkipJobs}}), /Latest release validation/);
});

function skipFixture({runChange = {}, receiptChange = {}, jobs = plannedSkipJobs, artifacts} = {}) {
  const selected = run(2, {event: 'workflow_dispatch', ...runChange});
  const receipt = {schemaVersion: 1, kind: 'release-validation', sourceSha: sha, releaseTag: 'v1.2.3',
    runId: '2', runAttempt: '1', validationMode: 'skipped', reason: 'Incident recovery', actor: 'operator', ...receiptChange};
  return {repository, sha, releaseTag: 'v1.2.3', request: async path => {
    if (path.includes('/workflows/')) return {workflow_runs: [selected, run(1)]};
    if (path.includes('/artifacts?')) return {artifacts: artifacts ?? [{name: 'release-validation-2-1', expired: false}]};
    return {jobs};
  }, readArtifact: async () => receipt};
}
test('successful manual tag run may explicitly skip CI with exact artifact and skipped job evidence', async () => {
  const selected = await requireCommonValidation(skipFixture());
  assert.equal(selected.id, 2);
  assert.equal(selected.validationMode, 'skipped');
  assert.equal(selected.skipReason, 'Incident recovery');
  assert.equal(selected.validationActor, 'operator');
  const placeholderJobs = plannedSkipJobs.map(job => job.name.startsWith('class_start_regressions /')
    ? {...job, name: 'class_start_regressions'} : job);
  assert.equal((await requireCommonValidation(skipFixture({jobs: placeholderJobs}))).validationMode, 'skipped');
});
test('skip audit cannot cross sources tags runs attempts or automatic events', async () => {
  for (const receiptChange of [{sourceSha: 'b'.repeat(40)}, {releaseTag: 'v1.2.4'}, {runId: '1'},
    {runAttempt: '2'}, {schemaVersion: 2}, {kind: 'mobile-source'}, {reason: ''}, {actor: ''}]) {
    await assert.rejects(requireCommonValidation(skipFixture({receiptChange})));
  }
  for (const runChange of [{event: 'push'}, {status: 'in_progress'}, {conclusion: 'failure'}, {conclusion: 'cancelled'}]) {
    await assert.rejects(requireCommonValidation(skipFixture({runChange})));
  }
});
test('missing expired ambiguous and partial skip proofs cannot bypass latest failed or skipped checks', async () => {
  for (const artifacts of [[], [{name: 'release-validation-2-1', expired: true}],
    [{name: 'release-validation-2-1'}, {name: 'release-validation-2-1'}]]) {
    await assert.rejects(requireCommonValidation(skipFixture({artifacts})));
  }
  for (const jobs of [plannedSkipJobs.slice(1), plannedSkipJobs.filter(job => job.name !== 'app-validation'),
    plannedSkipJobs.map(job => job.name === 'app-validation' ? {...job, conclusion: 'failure'} : job)]) {
    await assert.rejects(requireCommonValidation(skipFixture({jobs})));
  }
  await assert.rejects(requireCommonValidation(skipFixture({receiptChange: {validationMode: 'required'}})));
});


test('direct native manual skip writes audit evidence without querying CI and rejects QA', t => {
  const directory = mkdtempSync(join(tmpdir(), 'native-ci-skip-'));
  t.after(() => rmSync(directory, {recursive: true, force: true}));
  const evidence = join(directory, 'validation.json'), summary = join(directory, 'summary.md');
  const env = {...process.env, SKIP_CI: 'true', CI_SKIP_REASON: 'Center recovery\nVerified manually',
    GITHUB_ACTOR: 'operator', RELEASE_MODE: 'release', GITHUB_EVENT_NAME: 'workflow_dispatch',
    SOURCE_SHA: sha, RELEASE_TAG: 'v1.2.3', MOBILE_VALIDATION_PATH: evidence, GITHUB_STEP_SUMMARY: summary,
    GITHUB_TOKEN: ''};
  const args = [fileURLToPath(new URL('./common_validation.mjs', import.meta.url)), '--source-sha', sha, '--release-tag', 'v1.2.3'];
  const result = spawnSync(process.execPath, args, {env, encoding: 'utf8', timeout: 3000});
  assert.equal(result.status, 0, result.stderr);
  const record = JSON.parse(readFileSync(evidence, 'utf8'));
  assert.equal(record.validationMode, 'skipped');
  assert.equal(record.skipReason, env.CI_SKIP_REASON);
  assert.match(readFileSync(summary, 'utf8'), /not a passing test result/);
  assert.notEqual(spawnSync(process.execPath, args, {env: {...env, RELEASE_MODE: 'qa'}, encoding: 'utf8', timeout: 3000}).status, 0);
});
