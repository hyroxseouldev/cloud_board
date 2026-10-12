import assert from 'node:assert/strict';
import test from 'node:test';
import {requireBackend} from './release_backend_gate.mjs';
import {receiptFor} from './firebase/test-fixtures.mjs';
import {manifestHash} from './firebase/release.mjs';

const sha = 'a'.repeat(40), repository = 'owner/cloud_board';
const successful = {id: 12, run_attempt: 2, head_sha: sha, head_branch: 'main', head_repository: {full_name: repository}, event: 'push', status: 'completed', conclusion: 'success'};
const jobs = {jobs: [{name: 'firebase-required', conclusion: 'success'}, {name: 'firebase-production', conclusion: 'success', steps: ['Deploy account deletion functions and data rules', 'Verify deployed rules', 'Verify client save, image and TV permissions', 'Deploy to Firebase Hosting', 'Publish verified release receipt', 'Retain verified release receipt'].map(name => ({name, conclusion: 'success'}))}]};
const artifacts = {artifacts: [{id: 1, name: 'firebase-release-12-2', expired: false}]};
function options(runs, extras = {}) {
  return {repository, sha, ref: 'refs/heads/main', timeoutMs: 0,
    request: async path => path.includes('/git/ref/') ? {object: {sha}} : path.includes('/jobs?') ? jobs : path.includes('/artifacts?') ? artifacts : {workflow_runs: runs},
    readArtifact: async () => receiptFor(),
    sleep: async () => {}, ...extras};
}
test('exact commit and successful deployment attempt unlock upload', async () => {
  assert.equal(await requireBackend(options([successful])), successful);
});
test('a manually completed full deployment can unlock the exact same main SHA', async () => {
  const run = {...successful, event: 'workflow_dispatch'};
  assert.equal(await requireBackend(options([run])), run);
});
test('a newer manual failure blocks a prior full deployment permit', async () => {
  await assert.rejects(requireBackend(options([successful, {...successful, id: 13, event: 'workflow_dispatch', conclusion: 'failure'}])), /blocked/);
});
test('backend-only receipt cannot authorize mobile uploads even if jobs appear green', async () => {
  const base = options([{...successful, event: 'workflow_dispatch'}]);
  for (const scope of ['rules', 'backend']) {
    await assert.rejects(requireBackend({...base, readArtifact: async () => {
      const receipt = receiptFor(); receipt.scope = scope; receipt.manifest.scope = scope;
      receipt.manifestHash = manifestHash(receipt.manifest); return receipt;
    }}), /Wrong release scope/);
  }
  const missingHosting = structuredClone(jobs);
  missingHosting.jobs[1].steps.find(s => s.name === 'Deploy to Firebase Hosting').conclusion = 'skipped';
  // Forging only the scope still cannot replace the required concrete Hosting step.
  await assert.rejects(requireBackend({...base, request: async path => path.includes('/jobs?') ? missingHosting : base.request(path)}), /No successful backend/);
});
test('failure, cancellation and skipped runs block even if an older run passed', async () => {
  for (const conclusion of ['failure', 'cancelled', 'skipped', 'timed_out']) {
    await assert.rejects(requireBackend(options([successful, {...successful, id: 13, conclusion}])), /blocked/);
  }
});
test('wrong commit, PR, fork and absent or running backend never unlock upload', async () => {
  for (const run of [{...successful, head_sha: 'b'.repeat(40)}, {...successful, event: 'pull_request'}, {...successful, head_repository: {full_name: 'fork/cloud_board'}}, {...successful, status: 'in_progress'}]) {
    await assert.rejects(requireBackend(options([run])), /Timed out/);
  }
  await assert.rejects(requireBackend(options([])), /Timed out/);
});
test('manual branch upload and stale main commits are rejected', async () => {
  await assert.rejects(requireBackend(options([successful], {ref: 'refs/heads/develop'})), /main commit/);
  await assert.rejects(requireBackend(options([successful], {request: async () => ({object: {sha: 'b'.repeat(40)}})})), /no longer main/);
});
test('a green run with skipped deploy and GitHub API failure fail closed', async () => {
  const base = options([successful]);
  await assert.rejects(requireBackend({...base, request: async path => path.includes('/jobs?') ? {jobs: []} : base.request(path)}), /No successful backend/);
  await assert.rejects(requireBackend({...base, request: async () => {throw new Error('API unavailable');}}), /API unavailable/);
});
test('pending run waits and only succeeds after deployment finishes', async () => {
  let time = 0;
  const base = options([successful]);
  const result = await requireBackend({...base, timeoutMs: 30_000, now: () => time, sleep: async ms => {time += ms;},
    request: async path => path.includes('/runs?') && time === 0 ? {workflow_runs: [{...successful, status: 'queued'}]} : base.request(path)});
  assert.equal(result.id, successful.id);
  assert.equal(time, 15_000);
});

test('missing/expired receipt, wrong attempt and failed smoke block uploads', async () => {
  const base = options([successful]);
  await assert.rejects(requireBackend({...base, request: async path => path.includes('/artifacts?') ? {artifacts: []} : base.request(path)}));
  await assert.rejects(requireBackend({...base, readArtifact: async () => receiptFor({sha, runId: '12', attempt: '1'})}));
  await assert.rejects(requireBackend({...base, readArtifact: async () => {const r=receiptFor();r.smoke.cleanup='failure';return r;}}));
});
