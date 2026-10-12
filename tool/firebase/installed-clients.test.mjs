import test from 'node:test';
import assert from 'node:assert/strict';
import {installedWorkflows, requireRegisteredUpload, verifyInstalledClients} from './installed-clients.mjs';
const sha = 'a'.repeat(40);
const clients = [{sourceCommit: sha, platforms: ['ios','android','tv','web'], releases:
  ['ios','android','tv','web'].map(platform => ({platform, workflowRunId:'1'}))}];
test('new upload source/run cannot silently omit its immutable support contract', () => {
  requireRegisteredUpload(clients,{head_sha:sha,id:1},['android','tv']);
  assert.throws(() => requireRegisteredUpload(clients,{head_sha:'b'.repeat(40),id:1},['ios']));
  assert.throws(() => requireRegisteredUpload(clients,{head_sha:sha,id:2},['ios']));
  assert.throws(() => requireRegisteredUpload([{...clients[0],platforms:['android']}],{head_sha:sha,id:1},['android','tv']));
});
test('checks upload steps even when subsequent cleanup failed; skips current and backend-only runs', async () => {
  const run = id => ({id, head_sha:sha, head_branch:'main', event:'push', status:'completed', conclusion:'failure', run_attempt:1});
  const request = async path => path.includes('/workflows/')
    ? {workflow_runs:[run(3), run(2), run(1)]}
    : {jobs:[{steps: path.includes('/runs/1/') ? installedWorkflows.map(w => ({name:w.step,conclusion:'success'})) : []}]};
  const result = await verifyInstalledClients({clients,repository:'owner/repo',request,currentRunId:'3'});
  assert.equal(result.length,3); assert(result.every(row => row.runId === '1'));
});
test('missing remote deployment evidence fails closed', async () => {
  await assert.rejects(verifyInstalledClients({clients, repository:'owner/repo',request:async () => ({workflow_runs:[]})}), /Cannot verify/);
});
