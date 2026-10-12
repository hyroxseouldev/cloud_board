import assert from 'node:assert/strict';
import test from 'node:test';
import {latestRelease} from './latest-release.mjs';
import {productionRuns} from './release-runs.mjs';
import {receiptFor} from './test-fixtures.mjs';
import {manifestHash} from './release.mjs';

const repository = 'owner/cloud_board', sha = 'a'.repeat(40);
const successful = {id: 12, run_attempt: 2, head_sha: sha, head_branch: 'main', head_repository: {full_name: repository}, event: 'push', status: 'completed', conclusion: 'success'};
const options = (runs, scope = 'full') => ({repository,
  request: async path => path.includes('/artifacts?') ? {artifacts: [{id: 1, name: 'firebase-release-12-2', expired: false}]} : {workflow_runs: runs},
  readArtifact: async () => {
    const receipt = receiptFor(); receipt.scope = scope; receipt.manifest.scope = scope;
    receipt.manifestHash = manifestHash(receipt.manifest); return receipt;
  },
});
test('monitor follows a verified rules/backend manual receipt without requiring Hosting', async () => {
  for (const scope of ['rules', 'backend', 'full']) {
    const result = await latestRelease(options([{...successful, event: 'workflow_dispatch'}], scope));
    assert.equal(result.receipt.scope, scope);
  }
});
test('monitor never hides failed or partial manual repairs behind an older successful push', async () => {
  for (const conclusion of ['failure', 'cancelled', 'skipped']) {
    await assert.rejects(latestRelease(options([successful, {...successful, id: 13, event: 'workflow_dispatch', conclusion}])), /refusing an older receipt/);
  }
});
test('any in-progress production attempt defers drift checks, including dispatch', async () => {
  assert.equal((await latestRelease(options([successful, {...successful, id: 13, event: 'workflow_dispatch', status: 'in_progress'}]))).status, 'deferred');
});
test('a later retry of an older workflow ID takes precedence and forks/PRs are excluded', () => {
  const retry = {...successful, id: 10, run_started_at: '2026-10-12T13:00:00Z', conclusion: 'failure'};
  const runs = productionRuns([{...successful, run_started_at: '2026-10-12T12:00:00Z'}, retry,
    {...successful, id: 90, event: 'pull_request'}, {...successful, id: 99, head_repository: {full_name: 'fork/repo'}}], repository);
  assert.equal(runs[0], retry);
  assert.equal(runs.length, 2);
});
