import test from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {readFileSync, readdirSync, mkdtempSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {directPlan} from './direct-plan.mjs';
import {assertCleanSource, parseArgs, runRecordedStage} from './direct.mjs';
import {functionTargets, developmentOnly} from './direct-targets.mjs';
import {runtimeConfiguration, verifySecretBindings} from './direct-runtime.mjs';
import {beginAttempt, updateAttempt, latestDirect, validateAttempt, ledgerBranch, repository} from './direct-receipts.mjs';
import {manifestHash} from '../firebase/release.mjs';
import {receiptFor} from '../firebase/test-fixtures.mjs';
import {uploadInternal} from './direct-play-upload.mjs';
import {directNewsForAttempt} from '../update-news/publish.mjs';
import {latestRelease} from '../firebase/latest-release.mjs';
import {validateMobileReceipt} from './source.mjs';

const sha = 'a'.repeat(40);
const plan = overrides => directPlan({sourceSha: sha, environment: 'development', scope: 'web', version: '2.1.6', ...overrides});
const attempt = overrides => ({schemaVersion: 1, kind: 'direct-deployment', id: '123', sourceSha: sha, environment: 'production',
  project: 'cloud-board-stationd', scope: 'backend', version: '2.1.6', tag: 'v2.1.6', status: 'running', startedAt: '2026-11-14T00:00:00Z', steps: [], ...overrides});
const ledger = attempts => ({schemaVersion: 1, kind: 'direct-deployment-ledger', attempts});
const success = overrides => {
  const release = receiptFor({sha, runId: '123', attempt: '1'});
  release.scope = 'backend'; release.manifest.scope = 'backend'; release.manifest.releaseTag = 'v2.1.6';
  release.manifestHash = manifestHash(release.manifest);
  return attempt({status: 'success', completedAt: '2026-11-14T00:01:00Z',
    steps: [{id: 'deploy', status: 'success'}, {id: 'verify-receipt', status: 'success'}], release, ...overrides});
};

test('scopes remain independent: web does not deploy backend, mobile never deploys Firebase', () => {
  for (const environment of ['development', 'production']) for (const scope of ['web', 'rules', 'backend', 'functions', 'ios', 'android']) {
    const p = plan({environment, scope, tag: environment === 'production' ? 'v2.1.6' : '', functions: scope === 'functions' ? ['account-deletion:saveWorkout'] : []});
    assert.equal(p.scope, scope);
    assert.equal(p.steps.includes('function-targets'), ['backend', 'functions'].includes(scope));
    assert.equal(p.steps.includes('deploy'), !['ios', 'android'].includes(scope));
    assert.equal(p.steps.includes('build'), ['web', 'ios', 'android'].includes(scope));
    assert.equal(p.steps.includes('installed-clients'), environment === 'production' && ['rules', 'backend', 'functions'].includes(scope));
    if (p.steps.includes('installed-clients')) assert(p.steps.indexOf('installed-clients') < p.steps.indexOf('deploy'));
    assert(!p.steps.includes('upload'));
    assert.equal(p.project, environment === 'development' ? 'cloud-board-development' : 'cloud-board-stationd');
  }
});
test('production tag/version, precise function names and CLI options fail closed', () => {
  for (const options of [{environment: 'production'}, {scope: 'full'}, {sourceSha: 'HEAD'}, {scope: 'functions'},
    {scope: 'functions', functions: ['saveWorkout']}, {scope: 'web', upload: true}]) assert.throws(() => plan(options));
  assert.throws(() => parseArgs(['--execute', '--execute'])); assert.throws(() => parseArgs(['--scope', '--execute']));
  assert.throws(() => parseArgs(['--skip-ci']));
  assert.equal(parseArgs(['--scope', 'ios', '--upload']).execute, false);
});
test('native guards run before building and immediately before uploading', () => {
  for (const scope of ['ios', 'android']) {
    const qa = plan({scope, upload: true});
    assert(qa.steps.indexOf('development-store-readiness') < qa.steps.indexOf('build'));
    assert(!qa.steps.includes('backend-compatibility')); assert(!qa.steps.includes('recheck-backend'));
    const prod = plan({scope, environment: 'production', tag: 'v2.1.6', upload: true});
    assert(prod.steps.indexOf('backend-compatibility') < prod.steps.indexOf('build'));
    for (const stage of ['inspect-artifact', 'recheck-source', 'recheck-backend', 'recheck-build']) assert(prod.steps.indexOf(stage) < prod.steps.indexOf('upload'));
  }
});
test('dirty and wrong source never pass execution preflight', () => {
  assertCleanSource(sha, (...args) => args[0] === 'rev-parse' ? sha : '');
  assert.throws(() => assertCleanSource(sha, (...args) => args[0] === 'rev-parse' ? sha : ' M lib/app.dart'));
  assert.throws(() => assertCleanSource(sha, () => 'b'.repeat(40)));
});
test('explicit function targets preserve omitted, development-only and legacy boundaries', () => {
  const exports = Object.fromEntries(['saveWorkout', 'cloudboardBilling', 'omitted', ...developmentOnly].map(name => [name, {__endpoint: {omit: name === 'omitted'}}]));
  const prod = functionTargets({environment: 'production', exports});
  assert.equal(prod, 'functions:account-deletion:cloudboardBilling,functions:account-deletion:saveWorkout');
  const dev = functionTargets({environment: 'development', exports});
  assert(dev.includes('functions:cloudboard-auth:cloudboardSetDisplayState'));
  assert(!dev.includes('cloudboardBilling')); assert(!dev.includes('cloudboardAuth,'));
  for (const selected of [['account-deletion:omitted'], ['cloudboard-auth:cloudboardAuth'], ['account-deletion:cloudboardMedia']]) {
    assert.throws(() => functionTargets({environment: 'production', exports, selected}));
  }
  assert.equal(functionTargets({environment: 'development', exports, selected: ['account-deletion:cloudboardMedia']}), 'functions:account-deletion:cloudboardMedia');
});
test('runtime values preserve nonsecret configuration and never copy unknown credentials', () => {
  const inventory = vars => ({status: 'success', result: [{codebase: 'account-deletion', id: 'saveWorkout', environmentVariables: vars}]});
  const runtime = runtimeConfiguration(inventory({FIREBASE_CONFIG: 'ignored', AI_TIMER_SECRETS_ENABLED: 'true', SOLAPI_FROM: '0212345678'}), {environment: 'production'});
  assert(!runtime.dotenv.includes('FIREBASE_CONFIG')); assert(runtime.dotenv.includes('AI_TIMER_SECRETS_ENABLED="true"'));
  assert.throws(() => runtimeConfiguration(inventory({API_KEY: 'never-copy-this'}), {environment: 'production'}), error => !error.message.includes('never-copy-this'));
  assert.throws(() => runtimeConfiguration(inventory({}), {environment: 'development', origins: '*'}));
  const existing = inventory({}); existing.result[0].secretEnvironmentVariables = [{key: 'SECRET'}];
  assert.throws(() => verifySecretBindings(existing, {saveWorkout: {__endpoint: {}}}, 'functions:account-deletion:saveWorkout'));
});
test('a stage writes pending before work and never reports failed work as successful', async () => {
  const a = attempt(), observed = [];
  const save = async () => observed.push(structuredClone(a.steps));
  await assert.rejects(runRecordedStage({id: 'deploy', attempt: a, save, log: () => {}, work: async () => {
    assert.equal(observed[0][0].status, 'running'); throw new Error('fixture failure');
  }}), /fixture failure/);
  assert.equal(a.steps[0].status, 'failed'); assert(!observed.some(steps => steps.some(s => s.status === 'success')));
  const b = attempt(); let calls = 0;
  await assert.rejects(runRecordedStage({id: 'upload', attempt: b, save: async () => {throw new Error('receipt unavailable');}, log: () => {}, work: async () => calls++}));
  assert.equal(calls, 0);
});
test('ledger initialization is atomic, updates use CAS and a pending deployment blocks the next', async () => {
  const requests = [];
  const request = async (path, options) => {
    requests.push({path, options});
    if (path.includes('matching-refs')) return [];
    if (options.method === 'POST') return {};
    return {content: {sha: 'file-revision'}};
  };
  const state = await beginAttempt(request, attempt());
  assert.equal(requests[1].options.body.ref, `refs/heads/${ledgerBranch}`);
  assert.equal(requests[2].options.method, 'PUT');
  await updateAttempt(request, state, success());
  assert.equal(requests.at(-1).options.body.sha, 'file-revision');
  await assert.rejects(beginAttempt(async path => path.includes('matching-refs') ? [{ref: `refs/heads/${ledgerBranch}`}] :
    {encoding: 'base64', sha: 'rev', content: Buffer.from(JSON.stringify(ledger([attempt()]))).toString('base64')}, attempt({id: '124'})), /pending/);
});
test('new failed/partial receipt never silently falls back to old success', () => {
  const old = success(); assert.equal(latestDirect(ledger([old])).status, 'success');
  assert.equal(latestDirect(ledger([old, attempt({id: '124'})])).status, 'deferred');
  assert.throws(() => latestDirect(ledger([old, attempt({id: '124', status: 'failed', completedAt: old.completedAt})])), /partial/);
  assert.throws(() => latestDirect(ledger([success({scope: 'functions', release: undefined})])), /verification is unavailable/);
  assert.throws(() => validateAttempt(success({project: 'cloud-board-development'})));
  assert.throws(() => validateAttempt(success({release: receiptFor({sha: 'b'.repeat(40), runId: '123', attempt: '1'})})));
});
test('latestRelease uses direct receipts and avoids Actions when a direct component exists', async () => {
  const result = await latestRelease({repository, direct: true, request: async path => {
    assert(!path.includes('/actions/'));
    return path.includes('matching-refs') ? [{ref: `refs/heads/${ledgerBranch}`}] : {encoding: 'base64', sha: 'file', content: Buffer.from(JSON.stringify(ledger([success()]))).toString('base64')};
  }});
  assert.equal(result.run.direct, true); assert.equal(result.receipt.sha, sha);
});
test('direct development mobile source is a fixed commit; production remains version tagged', () => {
  const mobile = {schemaVersion: 5, kind: 'mobile-source', origin: 'direct-cli', sourceSha: sha, workflowSha: sha, controlSha: sha,
    sourceRef: sha, releaseMode: 'qa', platform: 'ios', environment: 'development', firebaseProject: 'cloud-board-development',
    package: 'com.sunmkim.cloudboard.dev', environmentBindingVerified: true, version: '2.1.6', build: '1', artifactSha256: 'a'.repeat(64), runId: '123', runAttempt: '1', validationMode: 'not_requested'};
  validateMobileReceipt(mobile);
  assert.throws(() => validateMobileReceipt({...mobile, sourceRef: 'develop'}));
  assert.throws(() => validateMobileReceipt({...mobile, environment: 'production'}));
  assert.throws(() => validateMobileReceipt({...mobile, releaseTag: 'v2.1.6'}));
});
test('Play uploads only internal after exact bundle code and does not claim store approval', async () => {
  const paths = [];
  const request = async (url, options) => { paths.push({url, options}); return {ok: true, status: 200,
    json: async () => url.endsWith('/edits') ? {id: 'edit1'} : url.includes('/bundles?') ? {versionCode: 77} : {}}; };
  const result = await uploadInternal({artifact: Buffer.from('fixture'), versionCode: '77', token: 'fixture', request});
  assert.equal(result.review, 'unverified'); assert(paths.some(p => p.url.endsWith('/tracks/internal')));
  assert(!paths.some(p => /tracks\/(production|alpha|beta)/.test(p.url)));
  await assert.rejects(uploadInternal({artifact: Buffer.from('fixture'), versionCode: '78', token: 'fixture', request}), /differs/);
});
test('news requires real production deploy/upload evidence and ignores development', () => {
  const note = {id: 'version-216', title: 'Update', summary: 'Changes', date: '2026-11-14', version: '2.1.6', items: [{title: 'Change', body: 'Description'}]};
  const receipt = receiptFor({sha, runId: '123', attempt: '1'}); receipt.scope = 'web'; receipt.manifest.scope = 'web';
  const valid = success(); valid.scope = 'web'; valid.buildNumber = '123.1';
  valid.release.scope = 'web'; valid.release.manifest.scope = 'web';
  valid.release.backend = {runId: '100', fingerprint: valid.release.manifest.backendFingerprint};
  valid.release.manifestHash = manifestHash(valid.release.manifest);
  const payload = directNewsForAttempt(ledger([valid]), '123', note);
  assert.equal(payload.builds.web, '123.1');
  // Scope metadata is integrity protected; a hand-edited receipt must fail.
  assert.throws(() => directNewsForAttempt(ledger([success({scope: 'web', release: receipt, buildNumber: '123.1'})]), '123', note));
  assert.throws(() => directNewsForAttempt(ledger([attempt()]), '123', note), /no successful/);
  assert.throws(() => directNewsForAttempt(ledger([attempt({environment: 'development', project: 'cloud-board-development'})]), '123', note), /production/);
});
test('active workflows contain only operational observers and historical inputs are retained', () => {
  assert.deepEqual(readdirSync('.github/workflows').sort(), ['app-update-news.yml', 'firebase-release-monitor.yml', 'native-development-readiness.yml']);
  assert.equal(readdirSync('tool/release/fixtures/retired-workflows').length, 7);
  for (const file of readdirSync('.github/workflows')) assert(!readFileSync(`.github/workflows/${file}`, 'utf8').includes('uses: ./.github/workflows/'));
});
test('real CLI dry-run reads fixed source only and does not request any deploy/build', () => {
  const head = execFileSync('git', ['rev-parse', 'HEAD'], {encoding: 'utf8'}).trim();
  for (const scope of ['web', 'rules', 'backend', 'functions', 'ios', 'android']) {
    const args = ['tool/release/direct.mjs', '--source', head, '--environment', 'development', '--scope', scope,
      ...(scope === 'functions' ? ['--functions', 'account-deletion:saveWorkout'] : [])];
    const result = JSON.parse(execFileSync(process.execPath, args, {encoding: 'utf8'}));
    assert.equal(result.operation, 'dry-run'); assert.equal(result.sourceSha, head);
  }
});

test('development readback rejects wrong project, missing/non-active functions and drifted rules', async () => {
  const {verifyFunctionInventory, readbackRules} = await import('../firebase/direct-readback.mjs');
  const project = 'cloud-board-development';
  const inventory = {status: 'success', result: [{id: 'saveWorkout', codebase: 'account-deletion', project, state: 'ACTIVE', region: 'asia-northeast3'}]};
  assert.equal(verifyFunctionInventory(inventory, ['functions:account-deletion:saveWorkout'], project)[0].state, 'ACTIVE');
  assert.throws(() => verifyFunctionInventory(inventory, ['functions:account-deletion:missing'], project));
  assert.throws(() => verifyFunctionInventory(inventory, ['functions:account-deletion:saveWorkout'], 'cloud-board-stationd'));
  inventory.result[0].state = 'DEPLOYING';
  assert.throws(() => verifyFunctionInventory(inventory, ['functions:account-deletion:saveWorkout'], project));
  const files = {'firestore.rules': 'allow no;', 'storage.rules': 'allow no;', 'database.rules.json': '{"rules":{}}'};
  const request = async url => url.includes('/releases/') ? {rulesetName: `projects/${project}/rulesets/rule1`} : url.includes('/rulesets/') ? {source: {files: [{content: 'allow no;'}]}} : {rules: {}};
  assert.equal((await readbackRules({project, files, request})).status, 'success');
  await assert.rejects(readbackRules({project, files: {...files, 'storage.rules': 'drift'}, request}), /differ/);
});

test('runtime comparison follows selected development targets and preserves excluded managed endpoints', () => {
  const core = {AI_TIMER_SECRETS_ENABLED: 'false', APPLE_IAP_SECRETS_ENABLED: 'false'};
  const inventory = {status: 'success', result: [
    {codebase: 'account-deletion', id: 'saveWorkout', environmentVariables: core},
    {codebase: 'account-deletion', id: 'syncWorkoutCatalog', environmentVariables: {...core}},
    {codebase: 'account-deletion', id: 'cloudboardAiSlideRaster', environmentVariables: {AI_TIMER_SECRETS_ENABLED: 'true'}, secretEnvironmentVariables: [{key: 'OPENAI_API_KEY'}]},
    {codebase: 'cloudboard-auth', id: 'cloudboardSetDisplayState', environmentVariables: {UNRELATED_LEGACY_SETTING: 'not-copied'}},
  ]};
  const untouched = structuredClone(inventory);
  const runtime = runtimeConfiguration(inventory, {environment: 'development'});
  assert.deepEqual(runtime.variables, core);
  assert(!runtime.dotenv.includes('true') && !runtime.dotenv.includes('UNRELATED_LEGACY_SETTING'));
  assert.deepEqual(inventory, untouched, 'Inspection must not mutate excluded function configuration');
  inventory.result[1].environmentVariables.AI_TIMER_SECRETS_ENABLED = 'true';
  assert.throws(() => runtimeConfiguration(inventory, {environment: 'development'}), /Per-function runtime configuration differs/);
  const narrow = runtimeConfiguration(inventory, {environment: 'development', selected: ['account-deletion:saveWorkout']});
  assert.deepEqual(narrow.variables, core);
  assert.throws(() => runtimeConfiguration(inventory, {environment: 'production'}), /Per-function runtime configuration differs/);
  inventory.result[0].environmentVariables.API_KEY = 'never-copy';
  assert.throws(() => runtimeConfiguration(inventory, {environment: 'development', selected: ['account-deletion:saveWorkout']}), /Unrecognized runtime configuration/);
});

test('successful external operation survives a later receipt failure without replay', async () => {
  const a = attempt(); let saves = 0, work = 0;
  await assert.rejects(runRecordedStage({id: 'deploy', attempt: a, log: () => {},
    save: async () => {if (++saves === 2) throw Error('lost response');}, work: async () => {work++;}}), /lost response/);
  assert.equal(work, 1); assert.equal(a.steps[0].status, 'success');
  assert.equal(a.steps[0].receiptPersistence, 'unconfirmed');
  assert(a.steps[0].completedAt);
});

test('ambiguous receipt PUT reads exact applied content once and never replays CAS', async () => {
  const state = {sha: 'old', ledger: ledger([attempt()])};
  let puts = 0, applied;
  const request = async (path, options) => {
    if (options?.method === 'PUT') {puts++; applied = JSON.parse(Buffer.from(options.body.content, 'base64')); throw Error('response lost');}
    if (path.includes('matching-refs')) return [{ref: `refs/heads/${ledgerBranch}`}];
    return {sha: 'new', encoding: 'base64', content: Buffer.from(JSON.stringify(applied)).toString('base64')};
  };
  const result = await updateAttempt(request, state, success());
  assert.equal(result.sha, 'new'); assert.equal(puts, 1);
  assert.equal(state.ledger.attempts[0].status, 'running');
  await assert.rejects(updateAttempt(request, result, attempt()), /terminal history/);
});

test('receipt conflict preserves concurrent attempts and immutable terminal history', async () => {
  const state = {sha: 'old', ledger: ledger([attempt()])};
  let puts = 0;
  const concurrent = ledger([success(), attempt({id: '456'})]);
  const request = async (path, options) => {
    if (options?.method === 'PUT') {puts++; throw Error('conflict');}
    return path.includes('matching-refs') ? [{ref: `refs/heads/${ledgerBranch}`}] :
      {sha: 'new', encoding: 'base64', content: Buffer.from(JSON.stringify(concurrent)).toString('base64')};
  };
  await assert.rejects(updateAttempt(request, state, success()), /unconfirmed or conflicted/);
  assert.equal(puts, 1); assert.equal(concurrent.attempts[1].status, 'running');
  await assert.rejects(updateAttempt(request, {sha: 'new', ledger: concurrent}, success()), /pending owner/);
});


test('direct GitHub receipt transport survives parent fetch failure and preserves CAS body', () => {
  const directory = mkdtempSync(join(tmpdir(), 'direct-gh-'));
  try {
    writeFileSync(join(directory, 'gh'), `#!${process.execPath}
const fs=require('node:fs');const body=JSON.parse(fs.readFileSync(0,'utf8'));if(body.sha!=='expected-revision'||process.argv[5]!=='PUT')process.exit(2);console.log(JSON.stringify({content:{sha:'saved'}}));
`, {mode: 0o700});
    const code = `import {github} from './tool/firebase/release.mjs';globalThis.fetch=()=>{throw Error('stale connection')};console.log(JSON.stringify(await github('/repos/fixture/contents/receipt',{method:'PUT',body:{sha:'expected-revision',content:'fixture'}})));`;
    const result = JSON.parse(execFileSync(process.execPath, ['--input-type=module', '-e', code], {encoding: 'utf8',
      env: {...process.env, PATH: directory + ':' + process.env.PATH, GITHUB_TOKEN: 'fixture-only', CLOUDBOARD_DIRECT_RELEASE: 'true'}}));
    assert.equal(result.content.sha, 'saved');
  } finally {rmSync(directory, {recursive: true, force: true});}
});

test('existing Firebase login refresh uses granted Firebase scope for rules readback', async () => {
  const {firebaseLoginToken} = await import('../firebase/direct-readback.mjs');
  const token = await firebaseLoginToken({getProjectDefaultAccount: cwd => {
    assert.equal(cwd, '/fixture'); return {tokens: {refresh_token: 'fixture-refresh'}};
  }, getAccessToken: async (refresh, scopes) => {
    assert.equal(refresh, 'fixture-refresh');
    if (scopes.includes('https://www.googleapis.com/auth/firebase.database')) throw Error('invalid_scope');
    assert(scopes.includes('https://www.googleapis.com/auth/firebase'));
    return {access_token: 'fixture-access'};
  }}, '/fixture');
  assert.equal(token, 'fixture-access');
});
