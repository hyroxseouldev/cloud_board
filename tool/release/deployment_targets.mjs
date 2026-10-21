import assert from 'node:assert/strict';

export function booleanInput(value, name, fallback = false) {
  assert([undefined, true, false, 'true', 'false'].includes(value), `${name} must be a boolean`);
  return value === undefined ? fallback : value === true || value === 'true';
}

export function deploymentTargets({server = false, web = false, mobile = false} = {}) {
  for (const [name, value] of Object.entries({server, web, mobile})) {
    assert.equal(typeof value, 'boolean', `${name} must be a boolean`);
  }
  assert(server || web || mobile, 'Select at least one deployment target: server, web or mobile');
  return {server, web, mobile, scope: server ? (web ? 'full' : 'backend') : web ? 'web' : 'verify'};
}
