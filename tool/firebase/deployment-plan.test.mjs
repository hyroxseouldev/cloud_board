import assert from 'node:assert/strict';
import test from 'node:test';
import {deploymentPlan, pendingScope, configChanges, changedScope, taggedScope, pubspecContentChanged, withReleaseBaseline, releaseValidation} from './deployment-plan.mjs';
import {validateReleaseValidation, releaseValidationFile} from './release-validation.mjs';
import {hash} from './common.mjs';
import {validateReceipt, receiptScope, manifestHash, requireReleaseJobs} from './release.mjs';
import {receiptFor} from './test-fixtures.mjs';

const sha = 'a'.repeat(40);
const manual = {eventName: 'workflow_dispatch', ref: 'refs/tags/v1.2.3', sha, event: {inputs: {scope: 'rules', confirm_sha: sha}}};
test('manual repair requires release tag, exact confirmed SHA and an explicit allowed scope', () => {
  for (const scope of ['rules', 'backend', 'full', 'web', 'verify']) assert.equal(deploymentPlan({...manual, event: {inputs: {scope, confirm_sha: sha}}}).scope, scope);
  for (const change of [
    {ref: 'refs/heads/develop'},
    {event: {inputs: {scope: 'rules', confirm_sha: 'b'.repeat(40)}}},
    {event: {inputs: {scope: 'hosting', confirm_sha: sha}}},
    {event: {inputs: {scope: 'rules'}}},
  ]) assert.throws(() => deploymentPlan({...manual, ...change}));
});
test('main never promotes production and a semver tag explicitly requests release planning', () => {
  const push = {eventName: 'push', ref: 'refs/heads/main', sha, event: {}};
  assert.equal(deploymentPlan(push).scope, 'none');
  assert.equal(deploymentPlan(push).production, false);
  assert.deepEqual(deploymentPlan({...push, ref: 'refs/tags/v1.2.3'}), {scope: 'auto', production: true, sha, releaseTag: 'v1.2.3', validationMode: 'required', reason: ''});
  for (const tag of ['test', 'v1.2', 'v01.2.3', 'v1.2.3-qa']) assert.throws(() => deploymentPlan({...push, ref: `refs/tags/${tag}`}));
  assert.throws(() => deploymentPlan({...manual, ref: 'refs/heads/main'}), /release tag/);
  assert.equal(deploymentPlan({...manual, ref: 'refs/heads/main', event: {inputs: {scope: 'verify', confirm_sha: sha}}}).production, false);
});
test('release tag scope uses deployed baselines even when its last commit only changed docs', () => {
  assert.equal(taggedScope(['functions/src/new.js'], ['functions/src/new.js', 'lib/app.dart']), 'full');
  assert.equal(taggedScope(['functions/src/new.js'], ['functions/src/new.js']), 'backend');
  assert.equal(taggedScope(['lib/app.dart'], ['lib/app.dart']), 'web');
  assert.equal(taggedScope(['firestore.rules'], ['firestore.rules']), 'rules');
  assert.equal(taggedScope(['ios/Runner/file.swift'], ['ios/Runner/file.swift']), 'verify');
  assert.equal(taggedScope([], []), 'verify');
});
test('new tags and manual validation use the verified backend receipt as contract baseline', async () => {
  const baseline = 'b'.repeat(40), webBaseline = 'c'.repeat(40);
  for (const scope of ['auto', 'verify', 'rules']) {
    const lookups = [], diffs = [];
    const plan = await withReleaseBaseline({scope, sha, production: scope !== 'verify'}, {ignoreRunId: 'current'}, {
      lookup: async options => {
        lookups.push(options);
        return {receipt: {sha: options.component === 'web' ? webBaseline : baseline}};
      },
      diff: (base, candidate) => {diffs.push([base, candidate]); return [];},
    });
    assert.equal(plan.contractBaseSha, baseline);
    assert.equal(lookups.length, scope === 'auto' ? 2 : 1);
    assert(lookups.every(options => options.allowFailed && options.ignoreRunId === 'current'));
    assert.deepEqual(diffs, scope === 'auto' ? [[baseline, sha], [webBaseline, sha]] : []);
    if (scope === 'auto') assert.equal(plan.production, false);
  }
  await assert.rejects(withReleaseBaseline({scope: 'verify', sha}, {}, {
    lookup: async () => ({receipt: {sha: undefined}}),
  }), /Verified backend contract baseline/);
});
test('scope is bound to receipt and manifest, and backend repair cannot authorize a full upload', () => {
  const legacy = receiptFor();
  assert.equal(receiptScope(legacy), 'full');
  for (const scope of ['', null, 'unknown']) {
    const malformed = receiptFor(); malformed.scope = scope; malformed.manifest.scope = scope;
    assert.throws(() => receiptScope(malformed));
  }
  for (const scope of ['rules', 'backend', 'full']) {
    const receipt = receiptFor();
    receipt.scope = scope;
    receipt.manifest.scope = scope;
    receipt.manifestHash = manifestHash(receipt.manifest);
    validateReceipt(receipt, receipt);
    if (scope !== 'full') assert.throws(() => validateReceipt(receipt, {...receipt, scope: 'full'}), /Wrong release scope/);
    receipt.scope = 'forged';
    assert.throws(() => validateReceipt(receipt, receipt), /scope mismatch/);
  }
});

test('pending deploy changes survive later pushes, but docs never publish', () => {
  assert.equal(pendingScope(['lib/fix.dart'], ['functions/src/failed.js', 'lib/fix.dart'], ['lib/fix.dart']), 'full');
  assert.equal(pendingScope(['functions/src/fix.js'], ['functions/src/fix.js'], ['lib/pending.dart', 'functions/src/fix.js']), 'full');
  assert.equal(pendingScope(['docs/readme.md'], ['functions/src/failed.js'], ['lib/pending.dart']), 'none');
  assert.equal(pendingScope(['lib/app.dart'], ['lib/app.dart'], ['lib/app.dart']), 'web');
});

test('verify runs require all checks while backend does not require web jobs', () => {
  const all = Object.fromEntries(['deployment_plan', 'app_validation', 'firebase_contracts', 'class_start_regressions', 'web_build'].map(name => [name, {result: 'success'}]));
  requireReleaseJobs(all, 'verify');
  assert.throws(() => requireReleaseJobs({...all, app_validation: {result: 'skipped'}}, 'verify'));
  const backend = {...all, web_build: {result: 'skipped'}};
  requireReleaseJobs({...backend, app_validation: {result: 'skipped'}, class_start_regressions: {result: 'skipped'}}, 'backend', '');
  for (const scope of ['backend', 'rules']) {
    requireReleaseJobs(backend, scope, 'v1.2.3');
    assert.throws(() => requireReleaseJobs({...backend, app_validation: {result: 'failure'}}, scope, 'v1.2.3'));
    assert.throws(() => requireReleaseJobs({...backend, class_start_regressions: {result: 'skipped'}}, scope, 'v1.2.3'));
  }
});

test('CI skip requires an explicit manual release tag deployment and a reason', () => {
  const skip = {...manual, event: {inputs: {...manual.event.inputs, skip_ci: true, skip_ci_reason: '  Incident recovery\nReviewed source  '}}};
  const plan = deploymentPlan(skip);
  assert.equal(plan.validationMode, 'skipped');
  assert.equal(plan.reason, 'Incident recovery\nReviewed source');
  assert.equal(deploymentPlan({...skip, event: {inputs: {...skip.event.inputs, skip_ci: 'true'}}}).validationMode, 'skipped');
  for (const change of [
    {eventName: 'push'}, {ref: 'refs/heads/main'}, {ref: 'refs/heads/develop'}, {ref: 'refs/tags/v1.2'},
    {event: {inputs: {...skip.event.inputs, scope: 'verify'}}},
    {event: {inputs: {...skip.event.inputs, confirm_sha: 'b'.repeat(40)}}},
    ...['', ' \n ', undefined, 'x'.repeat(2001), `${'x'.repeat(2000)} `].map(skip_ci_reason => ({event: {inputs: {...skip.event.inputs, skip_ci_reason}}})),
    {event: {inputs: {...skip.event.inputs, skip_ci: 'yes'}}},
  ]) assert.throws(() => deploymentPlan({...skip, ...change}));
  assert.equal(deploymentPlan({...skip, event: {inputs: {...skip.event.inputs, skip_ci_reason: 'x'.repeat(2000)}}}).reason.length, 2000);
  for (const skip_ci of [false, 'false', undefined]) {
    assert.equal(deploymentPlan({...skip, event: {inputs: {...skip.event.inputs, skip_ci}}}).validationMode, 'required');
    assert.equal(deploymentPlan({...skip, event: {inputs: {...skip.event.inputs, skip_ci}}}).reason, '');
  }
});

test('validation audit binds the policy to the exact source, tag, attempt and actor without claiming test success', () => {
  const plan = deploymentPlan({...manual, event: {inputs: {...manual.event.inputs, skip_ci: true, skip_ci_reason: 'Incident recovery'}}});
  const audit = releaseValidation(plan, {GITHUB_RUN_ID: '123', GITHUB_RUN_ATTEMPT: '2', GITHUB_ACTOR: 'release-owner'});
  assert.deepEqual(audit, {schemaVersion: 1, kind: 'release-validation', sourceSha: sha, releaseTag: 'v1.2.3', runId: '123', runAttempt: '2', validationMode: 'skipped', reason: 'Incident recovery', actor: 'release-owner'});
  assert.equal(audit.status, undefined);
  for (const patch of [{sourceSha: ''}, {releaseTag: ''}, {runId: 123}, {runAttempt: '0'}, {actor: ''}, {reason: ''}, {reason: 'x'.repeat(2001)}, {reason: `${'x'.repeat(2000)} `}, {validationMode: 'success'}]) {
    assert.throws(() => validateReleaseValidation({...audit, ...patch}));
  }
  assert.equal(validateReleaseValidation({...audit, reason: 'x'.repeat(2000)}).reason.length, 2000);
  assert.throws(() => validateReleaseValidation(audit, {sourceSha: 'b'.repeat(40)}));
  assert.throws(() => validateReleaseValidation(audit, {runAttempt: '1'}));
  const receipt = receiptFor();
  receipt.manifest.releaseTag = audit.releaseTag;
  receipt.manifest.validation = {...audit, sourceSha: receipt.sha, runId: receipt.runId, runAttempt: receipt.attempt};
  receipt.manifest.files[releaseValidationFile] = hash(`${JSON.stringify(receipt.manifest.validation, null, 2)}\n`);
  receipt.manifestHash = manifestHash(receipt.manifest);
  validateReceipt(receipt, receipt);
  const forged = structuredClone(receipt); forged.manifest.validation.runAttempt = '99'; forged.manifestHash = manifestHash(forged.manifest);
  assert.throws(() => validateReceipt(forged, forged), /runAttempt mismatch/);
});

test('skipped CI keeps build prerequisites and rejects failed or fabricated heavy job results', () => {
  const jobs = {deployment_plan: {result: 'success'}, web_build: {result: 'success'},
    app_validation: {result: 'skipped'}, firebase_contracts: {result: 'skipped'}, class_start_regressions: {result: 'skipped'}};
  requireReleaseJobs(jobs, 'full', 'v1.2.3', 'skipped');
  requireReleaseJobs({...jobs, web_build: {result: 'skipped'}}, 'backend', 'v1.2.3', 'skipped');
  for (const scope of ['none', 'verify']) assert.throws(() => requireReleaseJobs(jobs, scope, 'v1.2.3', 'skipped'));
  assert.throws(() => requireReleaseJobs(jobs, 'full', '', 'skipped'));
  assert.throws(() => requireReleaseJobs(jobs, 'full', 'v1.2.3', 'required'));
  for (const name of Object.keys(jobs)) {
    for (const result of ['failure', 'cancelled', undefined]) assert.throws(() => requireReleaseJobs({...jobs, [name]: {result}}, 'full', 'v1.2.3', 'skipped'));
  }
  for (const name of ['app_validation', 'firebase_contracts', 'class_start_regressions']) {
    assert.throws(() => requireReleaseJobs({...jobs, [name]: {result: 'success'}}, 'full', 'v1.2.3', 'skipped'));
  }
  assert.throws(() => requireReleaseJobs({...jobs, web_build: {result: 'skipped'}}, 'web', 'v1.2.3', 'skipped'));
});

test('a native release version bump alone does not publish Hosting, but dependency changes do', () => {
  const before = 'name: cloud_board\nversion: 1.2.2+40\ndependencies:\n  flutter: any\n';
  assert.equal(pubspecContentChanged(before, before.replace('1.2.2+40', '1.2.3+41')), false);
  assert.equal(pubspecContentChanged(before, before.replace('flutter: any', 'flutter: pinned')), true);
});

test('Hosting configuration changes alone never select Functions deployment', () => {
  const before = {hosting: {public: 'build/web'}, functions: [{source: 'functions'}], firestore: {rules: 'firestore.rules'}};
  const changedFiles = configChanges(before, {...before, hosting: {...before.hosting, headers: []}});
  assert.equal(changedScope(changedFiles), 'web');
  assert.deepEqual(configChanges(before, structuredClone(before)), []);
});
