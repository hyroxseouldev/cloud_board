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
test('production-connected QA is tracked by actual app source and artifact, not uploader source', async () => {
  const workflowSha = 'b'.repeat(40), artifactSha256 = 'c'.repeat(64);
  const registry = [{...clients[0], releases: clients[0].releases.map(r => ({...r, artifactSha256}))}];
  const request = async path => {
    const workflow = installedWorkflows.find(w => path.includes(`/workflows/${w.file}/`));
    if (workflow) {
      return {workflow_runs: [{id: 1, run_attempt: 1, head_sha: workflow.platforms[0] === 'web' ? sha : workflowSha,
        head_branch: 'main', event: 'workflow_dispatch', status: 'completed'}]};
    }
    if (path.endsWith('/artifacts?per_page=100')) return {artifacts: [{name: 'mobile-source-1-1'}]};
    return {jobs: [{steps: [...installedWorkflows.map(w => ({name: w.step, conclusion: 'success'})),
      {name: 'Resolve and pin trusted app source', conclusion: 'success'}]}]};
  };
  let index = 0;
  const result = await verifyInstalledClients({clients: registry, repository: 'owner/repo', request,
    readArtifact: async () => ({schemaVersion: 2, kind: 'mobile-source', sourceSha: sha, workflowSha,
      environment: 'production', environmentBindingVerified: true, releaseMode: 'qa', platform: index++ === 0 ? 'ios' : 'android-tv', firebaseProject: 'cloud-board-stationd',
      package: 'com.sunmkim.cloudboard', productionBindingVerified: true, version: '1.2.2', build: '558',
      artifactSha256, runId: '1', runAttempt: '1'})});
  assert(result.every(row => row.sha === sha));
  assert.equal(result[0].workflowSha, workflowSha);
  assert.equal(result[0].releaseMode, 'qa');
  assert.throws(() => requireRegisteredUpload(clients, {id: 1, head_sha: workflowSha, sourceSha: sha, artifactSha256}, ['ios']));
});
test('verified development uploads do not replace the latest production client contract', async () => {
  let platform;
  const request = async path => {
    const workflow = installedWorkflows.find(w => path.includes(`/workflows/${w.file}/`));
    if (workflow) {
      platform = workflow.platforms[0];
      const old = {id: 1, head_sha: sha, head_branch: 'v1.2.2', event: 'push', status: 'completed', run_attempt: 1};
      return {workflow_runs: platform === 'web' ? [old] : [
        {...old, id: 2, head_sha: 'b'.repeat(40), head_branch: 'main'}, old]};
    }
    if (path.includes('/artifacts?')) return {artifacts: [{name: 'mobile-source-2-1'}]};
    return {jobs: [{steps: [...installedWorkflows.map(w => ({name: w.step, conclusion: 'success'})),
      ...(path.includes('/runs/2/') ? [{name: 'Resolve and pin trusted app source', conclusion: 'success'}] : [])]}]};
  };
  const result = await verifyInstalledClients({clients, repository: 'owner/repo', request, readArtifact: async () => ({
    schemaVersion: 3, kind: 'mobile-source', sourceSha: 'c'.repeat(40), workflowSha: 'b'.repeat(40),
    releaseMode: 'qa', environment: 'development', platform: platform === 'ios' ? 'ios' : 'android-tv',
    firebaseProject: 'cloud-board-development', package: 'com.sunmkim.cloudboard.dev', environmentBindingVerified: true,
    version: '1.2.2', build: '1', artifactSha256: 'd'.repeat(64), runId: '2', runAttempt: '1',
  })});
  assert(result.every(row => row.runId === '1' && row.sha === sha));
});
