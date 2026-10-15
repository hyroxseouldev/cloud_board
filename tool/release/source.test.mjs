import test from 'node:test';
import assert from 'node:assert/strict';
import {sourceReference, resolveSource, validateMobileReceipt, mobileRunReceipt} from './source.mjs';

const sourceSha = 'a'.repeat(40), workflowSha = 'b'.repeat(40);
const input = {sourceRef: 'develop', mode: 'qa', workflowRef: 'refs/heads/main', workflowSha, eventName: 'workflow_dispatch'};
const fakeGit = allowed => (...args) => {
  if (args[0] === 'rev-parse') return sourceSha;
  if (args[0] === 'show') return 'version: 1.2.2+1\n';
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
  assert.throws(() => resolveSource({...input, sourceRef: 'v1.2.2', mode: 'release', runGit: fakeGit(['refs/remotes/origin/develop'])}), /main/);
  assert.equal(resolveSource({...input, sourceRef: 'v1.2.2', mode: 'release', runGit: fakeGit(['refs/remotes/origin/main'])}).sourceSha, sourceSha);
  assert.throws(() => resolveSource({...input, workflowRef: 'refs/heads/develop', runGit: fakeGit([])}), /trusted workflow/);
  assert.throws(() => resolveSource({...input, eventName: 'push', mode: 'release', runGit: fakeGit([])}), /only build/);
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

test('main QA uses development Firebase and release requires production with successful exact tag CI', () => {
  const qa = resolveSource({...input, eventName: 'push', runGit: fakeGit(['refs/remotes/origin/main'])});
  assert.equal(qa.environment, 'development');
  assert.equal(qa.releaseMode, 'qa');
  assert.equal(qa.releaseTag, undefined);
  const ci = {status: 'completed', conclusion: 'success', head_branch: 'v1.2.2', head_sha: sourceSha,
    head_repository: {full_name: 'owner/repo'}, event: 'push', path: '.github/workflows/firebase-hosting-merge.yml'};
  const args = {...input, mode: 'release', eventName: 'workflow_run', repository: 'owner/repo',
    event: {workflow_run: ci}, runGit: fakeGit(['refs/remotes/origin/main'])};
  assert.equal(resolveSource(args).environment, 'production');
  assert.equal(resolveSource(args).releaseTag, 'v1.2.2');
  for (const change of [{conclusion: 'failure'}, {status: 'in_progress'}, {head_branch: 'main'},
    {head_repository: {full_name: 'fork/repo'}}, {head_sha: workflowSha}, {head_branch: 'v9.9.9'},
    {path: '.github/workflows/other.yml'}]) {
    assert.throws(() => resolveSource({...args, event: {workflow_run: {...ci, ...change}}}));
  }
  for (const sourceRef of ['main', sourceSha, 'release/1.2.2']) {
    assert.throws(() => resolveSource({...input, mode: 'release', sourceRef,
      runGit: fakeGit(['refs/remotes/origin/main'])}), /vX.Y.Z tag/);
  }
});
test('new development receipts cannot represent production bindings or authorize release', () => {
  const receipt = {schemaVersion: 2, kind: 'mobile-source', sourceSha, workflowSha, releaseMode: 'qa', platform: 'ios',
    environment: 'development', firebaseProject: 'cloud-board-development', package: 'com.sunmkim.cloudboard.dev',
    environmentBindingVerified: true, version: '1.2.2', build: '1', artifactSha256: 'c'.repeat(64), runId: '1', runAttempt: '1'};
  assert.equal(validateMobileReceipt(receipt).environment, 'development');
  for (const change of [{releaseMode: 'release'}, {firebaseProject: 'cloud-board-stationd'},
    {package: 'com.sunmkim.cloudboard'}, {environment: 'production'}, {environmentBindingVerified: false}]) {
    assert.throws(() => validateMobileReceipt({...receipt, ...change}));
  }
});

test('historical production-connected QA receipts remain valid without authorizing release', () => {
  const receipt = {schemaVersion: 2, kind: 'mobile-source', sourceSha, workflowSha, releaseMode: 'qa', platform: 'ios',
    environment: 'production', firebaseProject: 'cloud-board-stationd', package: 'com.sunmkim.cloudboard',
    environmentBindingVerified: true, version: '1.2.2', build: '558', artifactSha256: 'c'.repeat(64), runId: '1', runAttempt: '1'};
  assert.equal(validateMobileReceipt(receipt).releaseMode, 'qa');
  assert.throws(() => validateMobileReceipt({...receipt, releaseMode: 'release'}), /versioned release tag/);
  assert.throws(() => validateMobileReceipt({...receipt, package: 'com.sunmkim.cloudboard.dev'}), /Unexpected mobile app/);
  assert.throws(() => validateMobileReceipt({...receipt, firebaseProject: 'cloud-board-development'}), /Unexpected backend environment/);
  assert.equal(validateMobileReceipt({...receipt, releaseMode: 'release', releaseTag: 'v1.2.2'}).releaseMode, 'release');
});

test('current separate-app QA and release receipts cannot exchange app IDs or Firebase environments', () => {
  const receipt = {schemaVersion: 3, kind: 'mobile-source', sourceSha, workflowSha, releaseMode: 'qa', platform: 'ios',
    environment: 'development', firebaseProject: 'cloud-board-development', package: 'com.sunmkim.cloudboard.dev',
    environmentBindingVerified: true, version: '1.2.2', build: '559', artifactSha256: 'c'.repeat(64), runId: '1', runAttempt: '1'};
  assert.equal(validateMobileReceipt(receipt).environment, 'development');
  for (const change of [{package: 'com.sunmkim.cloudboard'}, {environmentBindingVerified: false},
    {environment: 'production', firebaseProject: 'cloud-board-stationd'}, {releaseMode: 'release', releaseTag: 'v1.2.2'}]) {
    assert.throws(() => validateMobileReceipt({...receipt, ...change}));
  }
  const release = {...receipt, package: 'com.sunmkim.cloudboard', releaseMode: 'release', environment: 'production', firebaseProject: 'cloud-board-stationd', releaseTag: 'v1.2.2'};
  assert.equal(validateMobileReceipt(release).releaseMode, 'release');
  assert.throws(() => validateMobileReceipt({...release, releaseTag: undefined}));
});

test('native CI skipping needs a manual release, exact versioned tag, reason and actor', () => {
  const args = {...input, sourceRef: 'v1.2.2', mode: 'release', skipCi: true,
    skipReason: 'Emergency center fix', actor: 'release-operator', runGit: fakeGit(['refs/remotes/origin/main'])};
  const result = resolveSource(args);
  assert.deepEqual(result.validation, {validationMode: 'skipped', skipReason: 'Emergency center fix', validationActor: 'release-operator'});
  for (const change of [{mode: 'qa'}, {sourceRef: 'main'}, {skipReason: ''}, {skipReason: '   '},
    {actor: ''}, {eventName: 'push'}, {skipReason: 'x'.repeat(2001)}]) {
    assert.throws(() => resolveSource({...args, ...change}));
  }
  assert.equal(resolveSource({...args, skipCi: false}).validation, undefined);
});

test('mobile validation audit distinguishes required, explicitly skipped and not requested', () => {
  const receipt = {schemaVersion: 3, kind: 'mobile-source', sourceSha, workflowSha, releaseMode: 'release', platform: 'ios',
    environment: 'production', firebaseProject: 'cloud-board-stationd', package: 'com.sunmkim.cloudboard',
    environmentBindingVerified: true, version: '1.2.2', releaseTag: 'v1.2.2', build: '560',
    artifactSha256: 'c'.repeat(64), runId: '1', runAttempt: '1', validationMode: 'skipped',
    skipReason: 'On-site verification completed', validationActor: 'operator'};
  assert.equal(validateMobileReceipt(receipt).validationMode, 'skipped');
  for (const change of [{skipReason: ''}, {validationActor: ''}, {releaseTag: undefined}, {validationMode: 'passed'}]) {
    assert.throws(() => validateMobileReceipt({...receipt, ...change}));
  }
  assert.equal(validateMobileReceipt({...receipt, validationMode: 'required'}).validationMode, 'required');
  const qa = {...receipt, releaseMode: 'qa', environment: 'development', firebaseProject: 'cloud-board-development',
    package: 'com.sunmkim.cloudboard.dev', validationMode: 'not_requested'};
  assert.equal(validateMobileReceipt(qa).validationMode, 'not_requested');
  assert.throws(() => validateMobileReceipt({...qa, validationMode: 'skipped'}));
});
