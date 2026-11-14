import assert from 'node:assert/strict';
import {environments} from '../firebase/environments.mjs';

export function directPlan({sourceSha, environment, scope, version, tag = '', functions = [], upload = false}) {
  assert.match(sourceSha || '', /^[a-f0-9]{40}$/, 'Pass the full fixed source commit');
  assert(Object.hasOwn(environments, environment), 'Choose development or production');
  assert(['web', 'rules', 'backend', 'functions', 'ios', 'android'].includes(scope), 'Choose one explicit target scope');
  assert.match(version || '', /^\d+\.\d+\.\d+$/);
  if (environment === 'production') assert.equal(tag, `v${version}`, 'Production requires the version-matched immutable release tag');
  assert.equal(typeof upload, 'boolean');
  assert(!upload || ['ios', 'android'].includes(scope), 'Upload is a mobile option');
  assert(scope === 'functions' ? functions.length > 0 : functions.length === 0, 'Function selection requires functions scope');
  assert(functions.every(name => /^(account-deletion|cloudboard-auth):[A-Za-z][A-Za-z0-9]*$/.test(name)));
  const env = environments[environment];
  const steps = ['verify-source', 'verify-environment'];
  if (['ios', 'android'].includes(scope)) {
    if (environment === 'development') steps.push('development-store-readiness');
    if (environment === 'production') steps.push('backend-compatibility');
    steps.push('toolchain', 'signing-preflight', 'allocate-build', 'build', 'inspect-artifact');
    if (upload) steps.push('recheck-source', ...(environment === 'production' ? ['recheck-backend'] : []), 'recheck-build', 'upload');
  } else {
    steps.push('toolchain', 'firebase-access');
    if (environment === 'production') steps.push('no-rollback', ...(['web', 'rules'].includes(scope) ? ['backend-compatibility'] : []));
    if (scope === 'web') steps.push('build');
    if (['backend', 'functions'].includes(scope)) steps.push('function-targets');
    if (environment === 'production' && scope !== 'web') steps.push('smoke-inputs');
    steps.push('recheck-source', 'deploy');
    if (environment === 'production') steps.push(...(scope !== 'web' ? ['verify-rules', 'live-smoke'] : []), 'verify-receipt');
  }
  return {schemaVersion: 1, kind: 'direct-deployment-plan', sourceSha, environment, scope, version, tag,
    project: env.project, bundle: env.bundle, config: env.config, functions, upload,
    validation: {status: 'not-run', reason: 'Direct CLI: no GitHub Actions integration CI is requested'}, steps};
}
