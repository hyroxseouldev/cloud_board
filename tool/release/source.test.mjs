import test from 'node:test';
import assert from 'node:assert/strict';
import {sourceReference, resolveSource, validateMobileReceipt, mobileRunReceipt} from './source.mjs';

const sourceSha = 'a'.repeat(40), workflowSha = 'b'.repeat(40);
const input = {sourceRef: 'develop', mode: 'qa', workflowRef: 'refs/heads/main', workflowSha, eventName: 'workflow_dispatch'};
const fakeGit = allowed => (...args) => {
  if (args[0] === 'rev-parse') return sourceSha;
  if (!allowed.includes(args.at(-1))) throw new Error('not ancestor');
  return '';
};
test('source selection accepts repository branches, annotated tags and full SHAs without shell evaluation', () => {
  assert.equal(sourceReference('develop'), 'refs/remotes/origin/develop');
  assert.equal(sourceReference('release/1.2.2'), 'refs/remotes/origin/release/1.2.2');
  assert.equal(sourceReference('v1.2.2-qa.1'), 'refs/tags/v1.2.2-qa.1');
  assert.equal(sourceReference('refs/tags/v1.2.2'), 'refs/tags/v1.2.2');
  assert.equal(sourceReference(sourceSha), sourceSha);
  for (const value of ['https://github.com/fork/repo', '../main', 'main~1', '--help', 'main\nSECRET=x', 'main$(id)', 'main`id`']) {
    assert.throws(() => sourceReference(value));
  }
});
test('tags and SHAs cannot bypass trusted ancestry or select an unmerged release branch', () => {
  for (const sourceRef of ['develop', 'release/candidate', 'v1.2.2', sourceSha]) {
    assert.equal(resolveSource({...input, sourceRef, runGit: fakeGit(['refs/remotes/origin/develop'])}).sourceSha, sourceSha);
    assert.throws(() => resolveSource({...input, sourceRef, runGit: fakeGit([])}), /Merge/);
  }
  assert.throws(() => resolveSource({...input, mode: 'release', runGit: fakeGit(['refs/remotes/origin/develop'])}), /main/);
  assert.equal(resolveSource({...input, mode: 'release', runGit: fakeGit(['refs/remotes/origin/main'])}).sourceSha, sourceSha);
  assert.throws(() => resolveSource({...input, workflowRef: 'refs/heads/develop', runGit: fakeGit([])}), /trusted workflow/);
  assert.throws(() => resolveSource({...input, eventName: 'push', runGit: fakeGit([])}), /manual/);
});
test('mobile provenance separates app and workflow commits and validates the exact run and artifact', () => {
  const receipt = {schemaVersion: 1, kind: 'mobile-source', sourceSha, workflowSha, releaseMode: 'qa', platform: 'ios',
    firebaseProject: 'cloud-board-stationd', package: 'com.sunmkim.cloudboard', productionBindingVerified: true,
    version: '1.2.2', build: '558', artifactSha256: 'c'.repeat(64), runId: '1', runAttempt: '2'};
  const run = {id: 1, run_attempt: 2, head_sha: workflowSha};
  assert.equal(validateMobileReceipt(receipt, {run, platform: 'ios'}).sourceSha, sourceSha);
  for (const change of [{workflowSha: sourceSha}, {runAttempt: '1'}, {firebaseProject: 'development'}, {artifactSha256: ''}, {releaseMode: 'unknown'}]) {
    assert.throws(() => validateMobileReceipt({...receipt, ...change}, {run}));
  }
});
test('pinned source uploads cannot fall back to workflow SHA when their receipt is missing or expired', async () => {
  const run = {id: 1, run_attempt: 2};
  const jobs = [{steps: [{name: 'Resolve and pin trusted app source', conclusion: 'success'}]}];
  await assert.rejects(mobileRunReceipt({run, jobs, artifacts: []}), /receipt/);
  await assert.rejects(mobileRunReceipt({run, jobs, artifacts: [{name: 'mobile-source-1-2', expired: true}]}), /receipt/);
  assert.equal(await mobileRunReceipt({run, jobs: [], artifacts: []}), null);
});
