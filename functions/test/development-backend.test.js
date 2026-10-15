import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync, readdirSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {Timestamp} from 'firebase-admin/firestore';
import {developmentProject, developmentFunctionNames, developmentFunctionCodebase, developmentDeployTargets,
  developmentLegacyFunctionNames, developmentLegacyFunctionCodebase,
  developmentOnboardingSecret, onboardingSecretBindings} from '../src/development-backend-config.js';
import {assertDevelopmentSmsTester, sendDevelopmentOnboardingSms} from '../src/development-onboarding.js';
import {parseDevelopmentAction, runDevelopmentAction} from '../scripts/development-onboarding.mjs';

const tester = {uid: 'tester', token: {developmentTester: true, firebase: {sign_in_provider: 'google.com'}}};
test('development binds its isolated secret; production and emulator keep the existing delivery bindings', () => {
  assert.deepEqual(onboardingSecretBindings(developmentProject), [developmentOnboardingSecret]);
  for (const project of ['cloud-board-stationd', 'demo-contracts']) {
    assert.deepEqual(onboardingSecretBindings(project), ['CLOUDBOARD_ONBOARDING_SECRET', 'SOLAPI_API_KEY', 'SOLAPI_API_SECRET']);
  }
});

test('dev target list contains actual core exports with no provider billing/AI endpoints', () => {
  const source = readFileSync(new URL('../src/index.js', import.meta.url), 'utf8');
  assert.equal(new Set(developmentFunctionNames).size, developmentFunctionNames.length);
  for (const name of developmentFunctionNames) assert(source.includes(`export const ${name}`));
  assert(!developmentFunctionNames.some(name => /Ai|Billing|appStore|GooglePlay|googlePlay|AppStore/.test(name)));
  assert.equal(developmentDeployTargets(developmentProject).split(',').length,
    developmentFunctionNames.length + developmentLegacyFunctionNames.length);
  const config = JSON.parse(readFileSync(new URL('../../firebase.development.json', import.meta.url)));
  assert.equal(config.functions[0].codebase, developmentFunctionCodebase);
  assert.deepEqual(developmentDeployTargets(developmentProject).split(','), [
    ...developmentFunctionNames.map(name => `functions:${config.functions[0].codebase}:${name}`),
    ...developmentLegacyFunctionNames.map(name => `functions:${developmentLegacyFunctionCodebase}:${name}`),
  ]);
  assert.throws(() => developmentDeployTargets('cloud-board-stationd'));
  // The tester check must occur before any challenge/rate-limit writes.
  assert(source.indexOf('assertDevelopmentSmsTester(projectId, request.auth') < source.indexOf('return handleOnboarding'));
});

test('development includes the app output switch and excludes unrelated legacy services', () => {
  const source = readFileSync(new URL('../../functions-legacy/src/index.ts', import.meta.url), 'utf8');
  const client = readFileSync(new URL('../../lib/src/app/feature/device/data/datasources/device_pairing_realtime_data_source.dart', import.meta.url), 'utf8');
  const config = JSON.parse(readFileSync(new URL('../../firebase.development.json', import.meta.url)));
  assert.deepEqual(developmentLegacyFunctionNames, ['cloudboardSetDisplayState']);
  assert(source.includes('export const cloudboardSetDisplayState'));
  assert(client.includes("'cloudboardSetDisplayState'"));
  assert.equal(config.functions.filter(entry => entry.codebase === developmentLegacyFunctionCodebase).length, 1);
  const targets = developmentDeployTargets(developmentProject).split(',');
  assert.deepEqual(targets.filter(target => target.startsWith(`functions:${developmentLegacyFunctionCodebase}:`)),
    ['functions:cloudboard-auth:cloudboardSetDisplayState']);
  for (const excluded of ['cloudboardAuth', 'cloudboardLinkAccount', 'cloudboardPairDisplay']) {
    assert(!targets.some(target => target.endsWith(`:${excluded}`)), excluded);
  }
});

test('development deploy includes app-called core functions and plan projection triggers', () => {
  const source = readFileSync(new URL('../src/index.js', import.meta.url), 'utf8');
  const localExports = new Set([...source.matchAll(/export const (\w+)\s*=/g)].map(match => match[1]));
  const excludedProviders = new Set(['cloudboardAiTimer', 'cloudboardAiSlides',
    'cloudboardAiSlideDesigns', 'cloudboardBilling', 'cloudboardGooglePlayBilling']);
  const lib = new URL('../../lib/', import.meta.url);
  const appCalls = new Set();
  for (const file of readdirSync(lib, {recursive: true}).filter(file => file.endsWith('.dart'))) {
    const dart = readFileSync(new URL(file, lib), 'utf8');
    for (const [, name] of dart.matchAll(/\.httpsCallable\(\s*['"]([^'"]+)['"]/g)) {
      if (localExports.has(name) && !excludedProviders.has(name)) appCalls.add(name);
    }
  }
  assert(appCalls.has('saveWorkout'), 'The actual app save path must be covered');
  for (const name of [...appCalls, 'syncWorkoutPlanUsage', 'syncSlidePlanUsage', 'syncStandbyBranding', 'syncVerifiedFreeAccess']) {
    assert(developmentFunctionNames.includes(name), `Development deployment is missing ${name}`);
  }
});

test('actual deployed dev metadata has zero idle instances, dedicated identity and no provider secrets', () => {
  const script = `const m=await import('./src/index.js');
    const {developmentFunctionNames}=await import('./src/development-backend-config.js');
    process.stdout.write(JSON.stringify(Object.fromEntries(developmentFunctionNames.map(name=>[name,m[name].__endpoint]))));`;
  const entries = JSON.parse(execFileSync(process.execPath, ['--input-type=module', '-e', script], {
    cwd: new URL('..', import.meta.url), encoding: 'utf8',
    env: {PATH: process.env.PATH, GCLOUD_PROJECT: developmentProject},
  }));
  for (const [name, endpoint] of Object.entries(entries)) {
    assert.equal(endpoint.minInstances, 0, name);
    assert.equal(endpoint.serviceAccountEmail, 'development-runtime@cloud-board-development.iam.gserviceaccount.com', name);
    assert.deepEqual(endpoint.secretEnvironmentVariables?.map(secret => secret.key) ?? [],
      name === 'cloudboardAppOnboarding' ? [developmentOnboardingSecret] : [], name);
  }
});

test('only Admin-marked, nonanonymous dev testers can send or verify; no production simulation', async () => {
  let writes = 0;
  const db = {doc: () => ({set: async () => { writes++; }})};
  for (const auth of [undefined, {uid: 'tester', token: {}}, {...tester, token: {...tester.token, firebase: {sign_in_provider: 'anonymous'}}}]) {
    for (const action of ['sendCode', 'verifyCode']) {
      assert.throws(() => assertDevelopmentSmsTester(developmentProject, auth, action), {code: 'permission-denied'});
    }
    await assert.rejects(sendDevelopmentOnboardingSms({projectId: developmentProject, db, auth, code: '123456'}));
  }
  await assert.rejects(sendDevelopmentOnboardingSms({projectId: 'cloud-board-stationd', db, auth: tester, code: '123456'}));
  assert.equal(writes, 0);
  assert.doesNotThrow(() => assertDevelopmentSmsTester('cloud-board-stationd', undefined, 'sendCode'));
  assert.doesNotThrow(() => assertDevelopmentSmsTester(developmentProject, {token: {}}, 'load'));
});

test('a dev simulation writes only the random generated code and expiry to a server-only outbox', async () => {
  let written;
  const db = {doc: path => ({set: async value => { written = {path, value}; }})};
  await sendDevelopmentOnboardingSms({projectId: developmentProject, db, auth: tester, code: '734810', now: 1000});
  assert.equal(written.path, 'developmentSmsOutbox/tester');
  assert.deepEqual(Object.keys(written.value).sort(), ['code', 'expiresAt']);
  assert.equal(written.value.code, '734810');
  assert.equal(written.value.expiresAt.toMillis(), 301000);
});

test('operator commands require exact dev project and explicit UID; preserve unrelated custom claims', async () => {
  for (const args of [[], ['grant-tester'], ['grant-tester', '--project', 'cloud-board-stationd', '--uid', 'tester'],
    ['grant-tester', '--project', developmentProject, '--uid', '../other'],
    ['grant-tester', '--project', developmentProject, '--uid', 'tester', '--uid', 'other']]) {
    assert.throws(() => parseDevelopmentAction(args));
  }
  const command = parseDevelopmentAction(['grant-tester', '--project', developmentProject, '--uid', 'tester']);
  const calls = [];
  const auth = {getUser: async uid => { calls.push(uid); return {customClaims: {existing: 'keep'}}; },
    setCustomUserClaims: async (uid, claims) => calls.push({uid, claims})};
  assert.equal((await runDevelopmentAction(command, {auth})).status, 'tester-granted');
  assert.deepEqual(calls, ['tester', {uid: 'tester', claims: {existing: 'keep', developmentTester: true}}]);
  await assert.rejects(runDevelopmentAction({...command, projectId: 'cloud-board-stationd'}, {auth}));
});

test('operator reads only current tester code and revocation removes code and revokes tokens', async () => {
  let removed = false, revoked = false;
  let value = {code: '734810', expiresAt: Timestamp.fromMillis(2000)};
  const db = {doc: path => {
    assert.equal(path, 'developmentSmsOutbox/tester');
    return {get: async () => ({data: () => value}), delete: async () => { removed = true; }};
  }};
  const auth = {getUser: async () => ({customClaims: {developmentTester: true, existing: 'keep'}}),
    setCustomUserClaims: async (_, claims) => assert.deepEqual(claims, {existing: 'keep'}),
    revokeRefreshTokens: async () => { revoked = true; }};
  const command = {action: 'read-code', uid: 'tester', projectId: developmentProject};
  assert.equal((await runDevelopmentAction(command, {auth, db, now: 1000})).code, '734810');
  await assert.rejects(runDevelopmentAction(command, {auth, db, now: 2000}));
  value = {code: '734810'};
  await assert.rejects(runDevelopmentAction(command, {auth, db, now: 1000}));
  await runDevelopmentAction({...command, action: 'revoke-tester'}, {auth, db});
  assert(removed && revoked);
});
