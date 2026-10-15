import test from 'node:test';
import assert from 'node:assert/strict';
import {sourceReference, resolveSource, recheckSource, validateMobileReceipt, mobileRunReceipt} from './source.mjs';

const sourceSha = 'a'.repeat(40), workflowSha = 'b'.repeat(40);
const input = {sourceRef: 'dev/v1.2.2-1', mode: 'qa', workflowRef: 'refs/heads/main', workflowSha, eventName: 'workflow_dispatch'};
const fakeGit = allowed => (...args) => {
  if (args[0] === 'rev-parse') return sourceSha;
  if (args[0] === 'show') return 'version: 1.2.2+1\n';
  if (!allowed.includes(args.at(-1))) throw new Error('not ancestor');
  return '';
};
test('source selection accepts only development and release tags without shell evaluation', () => {
  assert.equal(sourceReference('dev/v1.2.2-1'), 'refs/tags/dev/v1.2.2-1');
  assert.equal(sourceReference('refs/tags/dev/v1.2.2-20'), 'refs/tags/dev/v1.2.2-20');
  assert.equal(sourceReference('refs/tags/v1.2.2'), 'refs/tags/v1.2.2');
  for (const value of ['main', 'develop', 'release/1.2.2', sourceSha, 'dev/v1.2.2', 'dev/v1.2.2-0',
    'dev/v1.2.2-01', 'dev/v01.2.2-1', 'v1.2.2-qa.1', 'dev/v1.2.2-1/other',
    'https://github.com/fork/repo', '../main', 'main~1', '--help', 'main\nSECRET=x', 'main$(id)', 'main`id`']) {
    assert.throws(() => sourceReference(value));
  }
});
test('both deployment modes require a matching tag and main ancestry; branches and raw SHAs cannot bypass them', () => {
  for (const [mode, sourceRef] of [['qa', 'dev/v1.2.2-1'], ['release', 'v1.2.2']]) {
    const args = {...input, mode, sourceRef};
    assert.equal(resolveSource({...args, runGit: fakeGit(['refs/remotes/origin/main'])}).sourceSha, sourceSha);
    assert.throws(() => resolveSource({...args, runGit: fakeGit(['refs/remotes/origin/develop'])}), /main/);
    assert.throws(() => resolveSource({...args, runGit: fakeGit([])}), /Merge/);
    for (const invalid of ['main', 'develop', 'release/candidate', sourceSha]) {
      assert.throws(() => resolveSource({...args, sourceRef: invalid, runGit: fakeGit(['refs/remotes/origin/main'])}), /deployment tag/);
    }
  }
  assert.throws(() => resolveSource({...input, sourceRef: 'v1.2.2', runGit: fakeGit(['refs/remotes/origin/main'])}), /dev\/vX.Y.Z-N/);
  assert.throws(() => resolveSource({...input, mode: 'release', runGit: fakeGit(['refs/remotes/origin/main'])}), /vX.Y.Z tag/);
  assert.throws(() => resolveSource({...input, workflowRef: 'refs/heads/develop', runGit: fakeGit([])}), /trusted workflow/);
  assert.throws(() => resolveSource({...input, sourceRef: 'dev/v1.2.3-1', runGit: fakeGit(['refs/remotes/origin/main'])}), /app version/);
  assert.throws(() => resolveSource({...input, expectedSourceSha: workflowSha, runGit: fakeGit(['refs/remotes/origin/main'])}), /after preflight/);
});
test('only a development tag push can start automatic QA and its original SHA cannot move', () => {
  const args = {...input, eventName: 'push', workflowRef: 'refs/tags/dev/v1.2.2-1', workflowSha: sourceSha,
    runGit: fakeGit(['refs/remotes/origin/main'])};
  const result = resolveSource(args);
  assert.equal(result.deploymentTag, 'dev/v1.2.2-1');
  assert.equal(result.sourceSha, sourceSha);
  assert.equal(result.environment, 'development');
  assert.equal(result.releaseTag, undefined);
  for (const workflowRef of ['refs/heads/main', 'refs/heads/develop', 'refs/tags/v1.2.2']) {
    assert.throws(() => resolveSource({...args, workflowRef}), /development tag/);
  }
  assert.throws(() => resolveSource({...args, workflowSha}), /moved/);
  assert.throws(() => resolveSource({...args, mode: 'release'}), /only build/);
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

test('tagged QA uses development Firebase and release requires production with successful exact tag CI', () => {
  const qa = resolveSource({...input, runGit: fakeGit(['refs/remotes/origin/main'])});
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
    {head_repository: {full_name: 'fork/repo'}}, {head_sha: workflowSha}, {head_sha: undefined}, {head_branch: 'v9.9.9'},
    {path: '.github/workflows/other.yml'}]) {
    assert.throws(() => resolveSource({...args, event: {workflow_run: {...ci, ...change}}}));
  }
  for (const sourceRef of ['main', sourceSha, 'release/1.2.2']) {
    assert.throws(() => resolveSource({...input, mode: 'release', sourceRef,
      runGit: fakeGit(['refs/remotes/origin/main'])}), /deployment tag/);
  }
});

test('upload recheck accepts pinned annotated tags and main advancement but rejects tag movement or missing ancestry', async () => {
  const args = {sourceSha, deploymentTag: 'dev/v1.2.2-1', mode: 'qa', repository: 'owner/repo',
    runGit: fakeGit(['refs/remotes/origin/main'])};
  const request = async path => {
    if (path.includes('/git/ref/tags/')) return {object: {type: 'tag', sha: workflowSha}};
    if (path.includes('/git/tags/')) return {object: {type: 'commit', sha: sourceSha}};
    if (path.endsWith(`${sourceSha}...main`)) return {status: 'ahead', merge_base_commit: {sha: sourceSha}};
    throw new Error(`Unexpected request: ${path}`);
  };
  await recheckSource({...args, request});
  await recheckSource({...args, deploymentTag: 'v1.2.2', mode: 'release', request});
  await assert.rejects(recheckSource({...args, request: async () => ({object: {type: 'commit', sha: workflowSha}})}), /moved/);
  await assert.rejects(recheckSource({...args, request: async () => { throw new Error('HTTP 404'); }}), /HTTP 404/);
  for (const main of [{status: 'behind', merge_base_commit: {sha: sourceSha}},
    {status: 'ahead', merge_base_commit: {sha: workflowSha}}, {status: 'diverged'}]) {
    await assert.rejects(recheckSource({...args, request: path => path.includes('/compare/') ? main : request(path)}), /included in main/);
  }
  await assert.rejects(recheckSource({...args, deploymentTag: 'dev/v1.2.3-1', request}), /app version/);
  await assert.rejects(recheckSource({...args, request: async () => ({object: {type: 'tag', sha: workflowSha}})}), /one commit/);
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

test('tagged mobile receipts retain deployment identity and trusted tools without breaking historical schemas', () => {
  const receipt = {schemaVersion: 4, kind: 'mobile-source', sourceSha, workflowSha, controlSha: workflowSha,
    sourceRef: 'dev/v1.2.2-1', deploymentTag: 'dev/v1.2.2-1', releaseMode: 'qa', platform: 'ios',
    environment: 'development', firebaseProject: 'cloud-board-development', package: 'com.sunmkim.cloudboard.dev',
    environmentBindingVerified: true, version: '1.2.2', build: '559', artifactSha256: 'c'.repeat(64),
    runId: '1', runAttempt: '1', validationMode: 'not_requested'};
  assert.equal(validateMobileReceipt(receipt).deploymentTag, 'dev/v1.2.2-1');
  for (const change of [{deploymentTag: undefined}, {sourceRef: 'main'}, {controlSha: ''},
    {deploymentTag: 'dev/v1.2.3-1', sourceRef: 'dev/v1.2.3-1'}, {releaseTag: 'v1.2.2'},
    {environment: 'production', firebaseProject: 'cloud-board-stationd', package: 'com.sunmkim.cloudboard'}]) {
    assert.throws(() => validateMobileReceipt({...receipt, ...change}));
  }
  const release = {...receipt, package: 'com.sunmkim.cloudboard', releaseMode: 'release', environment: 'production',
    firebaseProject: 'cloud-board-stationd', releaseTag: 'v1.2.2', deploymentTag: 'v1.2.2', sourceRef: 'v1.2.2', validationMode: 'required'};
  assert.equal(validateMobileReceipt(release).releaseTag, 'v1.2.2');
  assert.throws(() => validateMobileReceipt({...release, deploymentTag: 'dev/v1.2.2-1'}));
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
