import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {environments, validateSdk, developmentDeployArgs, verifyEnvironments, validateDevelopmentWeb} from './environments.mjs';
test('development deploy cannot target production or accept arbitrary scope', () => {
  assert.throws(() => developmentDeployArgs('production', 'rules'));
  assert.throws(() => developmentDeployArgs('development', 'functions'));
  assert.throws(() => developmentDeployArgs('development', 'rules,hosting'));
  const backend = developmentDeployArgs('development', 'backend');
  const targets = backend[backend.indexOf('--only') + 1];
  assert(targets.includes('functions:account-deletion:cloudboardAppOnboarding'));
  assert(targets.includes('functions:account-deletion:syncVerifiedFreeAccess'));
  assert(!targets.includes('Billing') && !targets.includes('Ai') && !targets.includes('processAppStore'));
  const args = developmentDeployArgs('development', 'rules');
  assert.equal(args[args.indexOf('--project') + 1], environments.development.project);
  assert.equal(args[args.indexOf('--config') + 1], environments.development.config);
});
test('mixed native project credentials fail before any deployment', () => {
  const dev = environments.development, prod = environments.production;
  const android = JSON.parse(readFileSync(prod.android));
  assert.throws(() => validateSdk(dev, android, readFileSync(dev.ios, 'utf8')));
  verifyEnvironments();
});

test('development Hosting rejects an unstamped, production or overwritten web bundle', () => {
  const bundle = Buffer.from('development bundle');
  const stamp = {environment: 'development', project: 'cloud-board-development',
    mainJsSha256: createHash('sha256').update(bundle).digest('hex')};
  validateDevelopmentWeb(stamp, bundle);
  assert.throws(() => validateDevelopmentWeb({...stamp, environment: 'production'}, bundle));
  assert.throws(() => validateDevelopmentWeb({...stamp, project: 'cloud-board-stationd'}, bundle));
  assert.throws(() => validateDevelopmentWeb(stamp, Buffer.from('production bundle')));
  assert.throws(() => validateDevelopmentWeb({}, bundle));
});
