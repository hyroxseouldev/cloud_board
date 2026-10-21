import test from 'node:test';
import assert from 'node:assert/strict';
import {mobileFollowupDecision} from './mobile_followup.mjs';
import {deploymentPlan, releaseValidation} from '../firebase/deployment-plan.mjs';

const sha = 'a'.repeat(40), repository = 'owner/repo';
const run = {id: 123, run_attempt: 2, status: 'completed', conclusion: 'success',
  head_repository: {full_name: repository}, path: '.github/workflows/firebase-hosting-merge.yml',
  event: 'workflow_dispatch', head_branch: 'v1.2.3', head_sha: sha};
const artifact = {id: 456, name: 'release-validation-123-2', expired: false};
const audit = {schemaVersion: 1, kind: 'release-validation', sourceSha: sha, releaseTag: 'v1.2.3',
  runId: '123', runAttempt: '2', validationMode: 'required', reason: '', actor: 'operator'};

function fixture(receipt = audit, inventory = {total_count: 1, artifacts: [artifact]}) {
  const reads = [];
  return {reads, options: {
    eventName: 'workflow_run', event: {workflow_run: structuredClone(run)}, repository,
    request: async path => {
      reads.push(path);
      assert.equal(path, `/repos/${repository}/actions/runs/123/artifacts?per_page=100`);
      return inventory;
    },
    readArtifact: async selected => {reads.push(selected); return receipt;},
  }};
}

test('only an explicit true in the exact parent run receipt starts mobile follow-up', async () => {
  for (const mobileUploadRequested of [undefined, false, true]) {
    const receipt = mobileUploadRequested === undefined ? audit : {...audit, mobileUploadRequested};
    const f = fixture(receipt);
    const decision = await mobileFollowupDecision(f.options);
    assert.equal(decision.requested, mobileUploadRequested === true);
    assert.deepEqual(f.reads[1], artifact);
  }
});

test('Firebase scope and CI policy cannot implicitly authorize mobile uploads', async () => {
  for (const scope of ['backend', 'rules', 'web', 'full', 'verify']) {
    for (const mobile of [false, true]) {
      for (const skip of scope === 'verify' ? [false] : [false, true]) {
        const plan = deploymentPlan({eventName: 'workflow_dispatch', ref: 'refs/tags/v1.2.3', sha,
          event: {inputs: {scope, confirm_sha: sha, deploy_mobile: String(mobile),
            skip_ci: String(skip), skip_ci_reason: skip ? 'Incident recovery' : ''}}});
        const receipt = releaseValidation(plan, {GITHUB_RUN_ID: '123', GITHUB_RUN_ATTEMPT: '2', GITHUB_ACTOR: 'operator'});
        assert.equal((await mobileFollowupDecision(fixture(receipt).options)).requested, mobile);
      }
    }
  }
});

test('explicit mobile dispatch and development push keep their existing gates without requiring a parent receipt', async () => {
  for (const eventName of ['workflow_dispatch', 'push']) {
    const f = fixture();
    assert.equal((await mobileFollowupDecision({...f.options, eventName})).requested, true);
    assert.deepEqual(f.reads, []);
  }
});

test('failed, untrusted or unpinned release events stop before reading artifacts', async () => {
  for (const patch of [
    {status: 'in_progress'}, {conclusion: 'failure'}, {conclusion: 'cancelled'},
    {head_repository: {full_name: 'other/repo'}}, {path: '.github/workflows/untrusted.yml'},
    {event: 'pull_request'}, {head_branch: 'main'}, {head_branch: 'dev/v1.2.3-1'},
    {head_sha: ''}, {id: 0}, {run_attempt: undefined},
  ]) {
    const f = fixture();
    await assert.rejects(mobileFollowupDecision({...f.options, event: {workflow_run: {...run, ...patch}}}));
    assert.deepEqual(f.reads, []);
  }
});

test('missing, expired, ambiguous and incomplete receipt inventories fail closed', async () => {
  for (const inventory of [
    {total_count: 0, artifacts: []},
    {total_count: 1, artifacts: [{...artifact, expired: true}]},
    {total_count: 2, artifacts: [artifact, artifact]},
    {total_count: 1, artifacts: [{...artifact, name: 'release-validation-123-1'}]},
    {total_count: 101, artifacts: [artifact]},
    {total_count: 2, artifacts: [artifact]},
    {artifacts: [artifact]},
  ]) {
    const f = fixture({...audit, mobileUploadRequested: true}, inventory);
    await assert.rejects(mobileFollowupDecision(f.options));
    assert.equal(f.reads.length, 1);
  }
});

test('another source, tag, run or attempt and malformed mobile choice cannot authorize upload', async () => {
  for (const patch of [
    {sourceSha: 'b'.repeat(40)}, {releaseTag: 'v1.2.4'}, {runId: '124'}, {runAttempt: '1'},
    {mobileUploadRequested: 'true'}, {mobileUploadRequested: 'false'}, {mobileUploadRequested: 1},
  ]) {
    await assert.rejects(mobileFollowupDecision(fixture({...audit, mobileUploadRequested: true, ...patch}).options));
  }
});

test('API and artifact verification failures never become a successful upload decision', async () => {
  for (const dependency of ['request', 'readArtifact']) {
    const f = fixture({...audit, mobileUploadRequested: true});
    await assert.rejects(mobileFollowupDecision({...f.options, [dependency]: async () => {throw new Error('unavailable');}}),
      /unavailable/);
  }
});
