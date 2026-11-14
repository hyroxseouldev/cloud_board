import assert from 'node:assert/strict';
import {developmentFunctionNames, developmentLegacyFunctionNames} from '../../functions/src/development-backend-config.js';

export const developmentOnly = ['cloudboardImageUsage', 'cloudboardClassAdmission', 'cloudboardUsageGrant',
  'cloudboardMediaLease', 'cloudboardImageUpload', 'cloudboardMedia', 'cloudboardImageUploadBody',
  'retryImageUsageOutbox', 'retryImageUsageEnrollment', 'reconcileImageUsageSession'];
// Explicit selectors never delete omitted/externally managed endpoints. The legacy
// production codebase stays on its existing guarded migration command.
export function functionTargets({environment, exports, selected = []}) {
  assert(['development', 'production'].includes(environment));
  const available = Object.entries(exports).filter(([, value]) => value?.__endpoint && value.__endpoint.omit !== true)
    .map(([name]) => name).filter(name => environment === 'development'
      ? developmentFunctionNames.includes(name) : !developmentOnly.includes(name));
  const allowed = available.map(name => `account-deletion:${name}`);
  if (environment === 'development') allowed.push(...developmentLegacyFunctionNames.map(name => `cloudboard-auth:${name}`));
  assert(allowed.length, 'No eligible function targets');
  for (const name of selected) {
    assert(/^(account-deletion|cloudboard-auth):[A-Za-z][A-Za-z0-9]*$/.test(name), 'Use explicit codebase:function names');
    assert(allowed.includes(name), 'Unknown, omitted, managed or environment-forbidden function');
  }
  assert.equal(new Set(selected).size, selected.length, 'Duplicate function selector');
  return (selected.length ? selected : allowed).sort().map(name => `functions:${name}`).join(',');
}
