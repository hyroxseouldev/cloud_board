import test from 'node:test';
import assert from 'node:assert/strict';
import {booleanInput, deploymentTargets} from './deployment_targets.mjs';

test('unchecked GitHub dispatch input never becomes truthy through string coercion', () => {
  for (const value of [undefined, false, 'false']) assert.equal(booleanInput(value, 'target'), false);
  for (const value of [true, 'true']) assert.equal(booleanInput(value, 'target'), true);
  assert.equal(booleanInput(undefined, 'target', true), true);
  assert.equal(booleanInput('false', 'target', true), false);
  for (const value of [null, '', 'yes', 'TRUE', 0, 1, [], {}]) {
    assert.throws(() => booleanInput(value, 'target'), /must be a boolean/);
  }
});

test('an empty selection cannot implicitly release all components', () => {
  assert.throws(() => deploymentTargets(), /Select at least one/);
  assert.throws(() => deploymentTargets({server: false, web: false, mobile: false}), /Select at least one/);
});
