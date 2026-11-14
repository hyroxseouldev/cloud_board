import assert from 'node:assert/strict';
import {canonical, hash} from '../firebase/common.mjs';

const flags = ['APPLE_IAP_SECRETS_ENABLED', 'AI_TIMER_SECRETS_ENABLED', 'APP_STORE_RECONCILIATION_ENABLED',
  'GOOGLE_PLAY_RECONCILIATION_ENABLED', 'SUPPORT_EMAIL_DELIVERY_ENABLED', 'SUPPORT_EMAIL_SECRETS_ENABLED'];
const allowed = [...flags, 'SOLAPI_FROM', 'CLOUDBOARD_MEDIA_ALLOWED_ORIGINS'];
const reserved = /^(FIREBASE_|GCLOUD_PROJECT$|GOOGLE_CLOUD_PROJECT$|FUNCTION_|EVENTARC_|K_|PORT$|LOG_EXECUTION_ID$)/;
export function runtimeConfiguration(inventory, {environment, origins} = {}) {
  assert.equal(inventory.status, 'success', 'Cannot inspect live function configuration');
  assert(Array.isArray(inventory.result));
  const functions = inventory.result.filter(f => f.codebase === 'account-deletion');
  const maps = functions.map(f => Object.fromEntries(Object.entries(f.environmentVariables || {}).filter(([key]) => !reserved.test(key))));
  // Never copy unrecognized (possibly secret) values into a dotenv file.
  for (const map of maps) for (const key of Object.keys(map)) assert(allowed.includes(key), 'Unrecognized runtime configuration: review it separately; no value was printed or copied');
  const value = maps[0] || {};
  for (const map of maps) assert.equal(hash(canonical(map)), hash(canonical(value)), 'Per-function runtime configuration differs; a shared dotenv would change it');
  for (const flag of flags) if (value[flag] !== undefined) assert(['true', 'false'].includes(value[flag]), 'Invalid live runtime flag');
  if (value.SOLAPI_FROM) assert(/^\+?\d{8,16}$/.test(value.SOLAPI_FROM), 'Invalid SMS sender');
  if (environment === 'development' && origins !== undefined) value.CLOUDBOARD_MEDIA_ALLOWED_ORIGINS = origins;
  if (value.CLOUDBOARD_MEDIA_ALLOWED_ORIGINS) for (const origin of value.CLOUDBOARD_MEDIA_ALLOWED_ORIGINS.split(',')) {
    const url = new URL(origin); assert.equal(url.origin, origin, 'Use exact media origins');
    assert(url.protocol === 'https:' || (environment === 'development' && ['localhost', '127.0.0.1'].includes(url.hostname)), 'Unsafe media origin');
  }
  return {variables: value, digest: hash(canonical(value)), dotenv: Object.entries(value).map(([key, value]) => `${key}=${JSON.stringify(value)}`).join('\n') + '\n'};
}
export function verifySecretBindings(inventory, exports, targets) {
  for (const target of targets.split(',')) {
    const [, codebase, name] = target.split(':');
    if (codebase !== 'account-deletion') continue;
    const current = inventory.result.find(f => f.codebase === codebase && f.id === name);
    if (!current) continue;
    const live = (current.secretEnvironmentVariables || []).map(s => s.key).sort();
    const candidate = (exports[name].__endpoint.secretEnvironmentVariables || []).map(s => s.key).sort();
    assert.deepEqual(candidate, live, `Secret bindings would change for ${name}; use a separately reviewed configuration migration`);
  }
}
