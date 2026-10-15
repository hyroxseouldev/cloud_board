import assert from 'node:assert/strict';
import test from 'node:test';
import {deploymentPlan, pendingScope, configChanges} from './deployment-plan.mjs';
import {validateReceipt, receiptScope, manifestHash, requireReleaseJobs} from './release.mjs';
import {receiptFor} from './test-fixtures.mjs';

const sha = 'a'.repeat(40);
const manual = {eventName: 'workflow_dispatch', ref: 'refs/heads/main', sha, event: {inputs: {scope: 'rules', confirm_sha: sha}}};
test('manual repair requires main, exact confirmed SHA and an explicit allowed scope', () => {
  for (const scope of ['rules', 'backend', 'full', 'web', 'verify']) assert.equal(deploymentPlan({...manual, event: {inputs: {scope, confirm_sha: sha}}}).scope, scope);
  for (const change of [
    {ref: 'refs/heads/develop'},
    {event: {inputs: {scope: 'rules', confirm_sha: 'b'.repeat(40)}}},
    {event: {inputs: {scope: 'hosting', confirm_sha: sha}}},
    {event: {inputs: {scope: 'rules'}}},
  ]) assert.throws(() => deploymentPlan({...manual, ...change}));
});
test('path-based main deployment separates web, backend, rules and no-op work', () => {
  const push = {eventName: 'push', ref: 'refs/heads/main', sha, event: {head_commit: {message: 'Release'}}};
  for (const [changedFiles, scope] of [
    [['lib/screen.dart'], 'web'], [['web/index.html'], 'web'], [['functions/src/save.js'], 'backend'],
    [['firestore.rules'], 'rules'], [['functions/src/save.js', 'lib/screen.dart'], 'full'],
    [['docs/readme.md', '.github/workflows/testflight-main.yml'], 'none'], [['test/screen_test.dart'], 'none'],
    [['ios/Runner/AppDelegate.swift'], 'none'], [['functions/package-lock.json'], 'backend'],
  ]) assert.equal(deploymentPlan({...push, changedFiles}).scope, scope);
  assert.equal(deploymentPlan({...push, event: {head_commit: {message: '[backend only]'}}, changedFiles: ['lib/app.dart']}).scope, 'web');
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
  const all = Object.fromEntries(['deployment_plan', 'app_validation', 'firebase_contracts', 'class_start_regressions'].map(name => [name, {result: 'success'}]));
  requireReleaseJobs(all, 'verify');
  assert.throws(() => requireReleaseJobs({...all, app_validation: {result: 'skipped'}}, 'verify'));
  requireReleaseJobs({...all, app_validation: {result: 'skipped'}, class_start_regressions: {result: 'skipped'}}, 'backend');
});

test('Hosting configuration changes alone never select Functions deployment', () => {
  const before = {hosting: {public: 'build/web'}, functions: [{source: 'functions'}], firestore: {rules: 'firestore.rules'}};
  const changedFiles = configChanges(before, {...before, hosting: {...before.hosting, headers: []}});
  assert.equal(deploymentPlan({eventName: 'push', ref: 'refs/heads/main', sha, event: {}, changedFiles}).scope, 'web');
  assert.deepEqual(configChanges(before, structuredClone(before)), []);
});
