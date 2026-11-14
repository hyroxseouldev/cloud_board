import test from 'node:test';
import assert from 'node:assert/strict';
import {repository, ledgerBranch} from '../release/direct-receipts.mjs';
import {receiptFor} from './test-fixtures.mjs';
import {manifestHash} from './release.mjs';
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


test('direct production uploads require exact frozen identities and exclude newer QA', async () => {
  const artifactSha256 = 'c'.repeat(64);
  const attempt = (scope, id, environment = 'production') => {
    const production = environment === 'production';
    const value = {schemaVersion: 1, kind: 'direct-deployment', id, sourceSha: sha, environment,
      project: production ? 'cloud-board-stationd' : 'cloud-board-development', scope, version: '2.1.0',
      ...(production ? {tag: 'v2.1.0'} : {}), status: 'success', startedAt: '2026-11-14T00:00:00Z',
      completedAt: '2026-11-14T00:01:00Z', steps: []};
    if (scope === 'web') {
      const release = receiptFor({sha, runId: id, attempt: '1'});
      release.scope = release.manifest.scope = 'web'; release.manifest.releaseTag = 'v2.1.0';
      release.backend = {runId: '100', fingerprint: release.manifest.backendFingerprint};
      release.manifestHash = manifestHash(release.manifest);
      value.release = release; value.steps = ['deploy', 'verify-receipt'].map(id => ({id, status: 'success'}));
    } else {
      value.mobile = {schemaVersion: 5, kind: 'mobile-source', origin: 'direct-cli', sourceSha: sha,
        workflowSha: sha, controlSha: sha, sourceRef: production ? 'v2.1.0' : sha,
        ...(production ? {deploymentTag: 'v2.1.0', releaseTag: 'v2.1.0'} : {}),
        releaseMode: production ? 'release' : 'qa', platform: scope === 'ios' ? 'ios' : 'android-tv',
        environment, firebaseProject: value.project, package: `com.sunmkim.cloudboard${production ? '' : '.dev'}`,
        environmentBindingVerified: true, version: value.version, build: '1', artifactSha256, runId: id, runAttempt: '1'};
      value.steps = ['inspect-artifact', 'upload'].map(id => ({id, status: 'success'}));
    }
    return value;
  };
  const ledger = {schemaVersion: 1, kind: 'direct-deployment-ledger', attempts: [
    attempt('ios', '11'), attempt('android', '12'), attempt('web', '13'), attempt('ios', '14', 'development')]};
  const request = async path => {
    assert(!path.includes('/actions/'), 'Direct history must not fall back to an older workflow upload');
    return path.includes('matching-refs') ? [{ref: `refs/heads/${ledgerBranch}`}] :
      {encoding: 'base64', sha: 'ledger-revision', content: Buffer.from(JSON.stringify(ledger)).toString('base64')};
  };
  const registered = [{sourceCommit: sha, platforms: ['ios', 'android', 'tv', 'web'], releases:
    [['ios', '11'], ['android', '12'], ['tv', '12'], ['web', '13']].map(([platform, directDeploymentId]) =>
      ({platform, directDeploymentId, ...(platform !== 'web' ? {artifactSha256} : {})}))}];
  const result = await verifyInstalledClients({clients: registered, repository, request});
  assert.deepEqual(result.map(row => row.runId), ['11', '12', '13']);
  for (const change of [
    rows => rows[0].releases[0].directDeploymentId = '14',
    rows => rows[0].releases[0].artifactSha256 = 'd'.repeat(64),
    rows => rows[0].sourceCommit = 'b'.repeat(40),
    rows => rows[0].platforms = ['ios', 'android', 'web'],
  ]) {
    const changed = structuredClone(registered); change(changed);
    await assert.rejects(verifyInstalledClients({clients: changed, repository, request}), /no frozen contract/);
  }
});
