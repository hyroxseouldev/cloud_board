import assert from 'node:assert/strict';
import test from 'node:test';
import {approvedTestflightBackend} from './approved_testflight_backend.mjs';

function fixture() {
  const sha = 'dc86f8aa023352c06998fae7f989aa47abbffad7';
  const repository = 'hyroxseouldev/cloud_board';
  const fingerprint = '072b0ab70606271d1f44b6700b90f4e1e36ccea0757e86f80d778c4338903ee7';
  const run = {id: 41475618259, run_attempt: 1, head_sha: sha, head_branch: 'v2.0.7',
    head_repository: {full_name: repository}, event: 'workflow_dispatch', status: 'completed', conclusion: 'failure'};
  const job = {name: 'firebase-production', status: 'completed', conclusion: 'failure', steps: [
    {name: 'Deploy account deletion functions and data rules', conclusion: 'success'},
    {name: 'Verify deployed rules', conclusion: 'success'},
    {name: 'Verify client save, image and TV permissions', conclusion: 'failure'},
  ]};
  const artifact = {id: 13157528051, expired: false, name: 'firebase-attempt-41475618259-1',
    digest: 'sha256:7ed4c4b035bd3c66128967803eb1d9102c5ecf0c28d42799f0e52fce4afca4ae'};
  const evidence = {
    'manifest.json': {sha, runId: '41475618259', attempt: '1', scope: 'backend', backendFingerprint: fingerprint},
    'smoke.json': {status: 'failure', phase: 'tv', error: 'PERMISSION_DENIED', cleanup: 'success', checks: ['workout', 'storage']},
    'live-rules.json': {status: 'success'},
  };
  const input = {repository, sha, mobile: true, fingerprint, now: Date.parse('2026-11-02T16:10:00Z'),
    env: {BACKEND_EXCEPTION_RUN: '41475618259', GITHUB_EVENT_NAME: 'workflow_dispatch', RELEASE_MODE: 'release',
      RELEASE_TAG: 'v2.0.7', IOS_BUNDLE_ID: 'com.sunmkim.cloudboard', SKIP_CI: 'true'},
    request: async path => path.includes('/compare/') ? {status: 'ahead', merge_base_commit: {sha}}
      : path.includes('/jobs?') ? {jobs: [job]}
      : path.includes('/artifacts?') ? {artifacts: [artifact]} : {workflow_runs: [run]},
    readMember: async (_, member) => evidence[member],
  };
  return {input, run, job, artifact, evidence};
}

test('approved exact iOS upload retains failed smoke and explicit approval in audit', async () => {
  const {input} = fixture();
  const result = await approvedTestflightBackend(input);
  assert.equal(result.conclusion, 'failure');
  assert.equal(result.backendReference.approval.smokeStatus, 'failure');
  assert.equal(result.backendReference.approval.kind, 'user-approved-testflight-exception');
});
test('approval cannot authorize another app, backend, attempt, artifact or unexpected failure', async () => {
  const changes = [
    f => f.input.sha = 'a'.repeat(40), f => f.input.fingerprint = 'a'.repeat(64),
    f => f.input.mobile = false, f => f.input.env.IOS_BUNDLE_ID += '.dev',
    f => f.input.env.SKIP_CI = 'false', f => f.input.env.GITHUB_EVENT_NAME = 'workflow_run',
    f => f.input.now = Date.parse('2026-11-04T00:00:00Z'), f => f.run.id++, f => f.run.run_attempt++,
    f => f.job.steps[0].conclusion = 'failure', f => f.job.steps[1].conclusion = 'failure',
    f => f.artifact.digest = 'sha256:' + 'a'.repeat(64), f => f.artifact.expired = true,
    f => f.evidence['smoke.json'].cleanup = 'failure', f => f.evidence['smoke.json'].phase = 'workout',
  ];
  for (const change of changes) {
    const f = fixture(); change(f);
    await assert.rejects(approvedTestflightBackend(f.input));
  }
});
