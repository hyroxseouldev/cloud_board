import assert from 'node:assert/strict';
import test from 'node:test';
import {deploymentPlan} from './deployment-plan.mjs';
import {validateReceipt, receiptScope, manifestHash} from './release.mjs';
import {receiptFor} from './test-fixtures.mjs';

const sha = 'a'.repeat(40);
const manual = {eventName: 'workflow_dispatch', ref: 'refs/heads/main', sha, event: {inputs: {scope: 'rules', confirm_sha: sha}}};
test('manual repair requires main, exact confirmed SHA and an explicit allowed scope', () => {
  for (const scope of ['rules', 'backend', 'full']) assert.equal(deploymentPlan({...manual, event: {inputs: {scope, confirm_sha: sha}}}).scope, scope);
  for (const change of [
    {ref: 'refs/heads/develop'},
    {event: {inputs: {scope: 'rules', confirm_sha: 'b'.repeat(40)}}},
    {event: {inputs: {scope: 'hosting', confirm_sha: sha}}},
    {event: {inputs: {scope: 'rules'}}},
  ]) assert.throws(() => deploymentPlan({...manual, ...change}));
});
test('normal main push remains full; only explicit main marker selects backend-only', () => {
  const push = {eventName: 'push', ref: 'refs/heads/main', sha, event: {head_commit: {message: 'Release'}}};
  assert.equal(deploymentPlan(push).scope, 'full');
  const marked = {...push, event: {head_commit: {message: '[backend only] Repair rules'}}};
  assert.equal(deploymentPlan(marked).scope, 'backend');
  assert.deepEqual(deploymentPlan({...marked, ref: 'refs/heads/develop'}), {scope: 'full', production: false, sha});
  assert.equal(deploymentPlan({...marked, eventName: 'pull_request'}).production, false);
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
