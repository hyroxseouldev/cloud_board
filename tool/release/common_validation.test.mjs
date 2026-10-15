import test from 'node:test';
import assert from 'node:assert/strict';
import {requireCommonValidation} from './common_validation.mjs';
const sha = 'a'.repeat(40), repository = 'owner/repo';
const run = (id, extra = {}) => ({id, head_sha: sha, head_branch: 'main', head_repository: {full_name: repository},
  event: 'push', run_attempt: 1, run_started_at: `2026-10-15T00:0${id}:00Z`, ...extra});
const successfulJobs = [
  {name: 'app-validation', conclusion: 'success', steps: ['Analyze', 'Test'].map(name => ({name, conclusion: 'success'}))},
  {name: 'class_start_regressions / Class start lifecycle and TV preparation', conclusion: 'success',
    steps: ['Required native logic regressions', 'Required web regressions'].map(name => ({name, conclusion: 'success'}))},
];
test('release reuses exact app validation while independent deployment can still be running', async () => {
  const selected = await requireCommonValidation({repository, sha, request: async path => path.includes('/workflows/')
    ? {workflow_runs: [run(1, {status: 'in_progress'})]} : {jobs: successfulJobs}});
  assert.equal(selected.id, 1);
});
test('latest retry must pass; no fallback to older green runs or lightweight handoff checks', async () => {
  for (const state of ['failure', 'skipped', null]) {
    await assert.rejects(requireCommonValidation({repository, sha, request: async path => path.includes('/workflows/')
      ? {workflow_runs: [run(2), run(1)]}
      : {jobs: path.includes('/runs/2/') ? [{name: 'app-validation', conclusion: state}, {name: 'firebase-required', conclusion: 'success'}] : successfulJobs}}), /Latest main validation/);
  }
  await assert.rejects(requireCommonValidation({repository, sha, request: async path => path.includes('/workflows/')
    ? {workflow_runs: [run(1, {run_attempt: 2})]} : {jobs: successfulJobs.map(j => ({...j, steps: []}))}}), /Latest main validation/);
});
test('foreign, PR and different source validations cannot approve a release', async () => {
  for (const extra of [{event: 'pull_request'}, {head_branch: 'develop'}, {head_sha: 'b'.repeat(40)}, {head_repository: {full_name: 'fork/repo'}}]) {
    await assert.rejects(requireCommonValidation({repository, sha, request: async () => ({workflow_runs: [run(1, extra)]})}), /No main integration/);
  }
});

const plannedSkipJobs = [
  {name: 'Verify deployment target', conclusion: 'success'},
  ...successfulJobs.map(job => ({name: job.name, conclusion: 'skipped'})),
];
test('later planned backend-only and no-op runs preserve earlier common validation for the same SHA', async () => {
  for (const conclusion of ['success', 'failure', null]) {
    for (const skippedName of [successfulJobs[1].name, 'class_start_regressions']) {
      const skippedJobs = plannedSkipJobs.map(job => job.name === successfulJobs[1].name ? {...job, name: skippedName} : job);
      const selected = await requireCommonValidation({repository, sha, request: async path => path.includes('/workflows/')
        ? {workflow_runs: [run(2, {event: 'workflow_dispatch', conclusion}), run(1)]}
        : {jobs: path.includes('/runs/2/') ? skippedJobs : successfulJobs}});
      assert.equal(selected.id, 1);
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
      ? {workflow_runs: [run(2, {conclusion: candidate.conclusion}), run(1)]}
      : {jobs: path.includes('/runs/2/') ? candidate.jobs : successfulJobs}}), /Latest main validation/);
  }
});
test('planned non-validation runs cannot authorize release when no actual common validation exists', async () => {
  await assert.rejects(requireCommonValidation({repository, sha, request: async path => path.includes('/workflows/')
    ? {workflow_runs: [run(1)]} : {jobs: plannedSkipJobs}}), /No main integration/);
});
