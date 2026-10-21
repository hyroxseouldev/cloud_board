import test from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdtempSync, mkdirSync, writeFileSync, readFileSync, existsSync, rmSync, cpSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {fileURLToPath} from 'node:url';
import {compatibilityContext, prepareBackendSandbox, runCompatibilityChecks, verifySandboxFingerprint} from './verify_mobile_backend.mjs';
import {mobileClientFingerprint} from './mobile_backend_compatibility.mjs';
import {backendFingerprint} from '../firebase/release.mjs';

const sha = 'a'.repeat(40), old = 'b'.repeat(40), fingerprint = 'c'.repeat(64);
const contextOptions = {sha, releaseTag: 'v1.2.3', candidateFingerprint: 'd'.repeat(64), clientFingerprint: 'e'.repeat(64),
  backend: {status: 'success', run: {id: 9, run_attempt: 1}, receipt: {sha: old, manifest: {backendFingerprint: fingerprint}}},
  runId: '10', runAttempt: '1'};
test('an old deployed backend selects real contract verification; matching sources reuse existing evidence', () => {
  assert.equal(compatibilityContext(contextOptions).method, 'deployed-backend-contracts');
  assert.equal(compatibilityContext({...contextOptions, candidateFingerprint: fingerprint}).method, 'identical-backend');
  for (const backend of [
    {...contextOptions.backend, status: 'pending'},
    {...contextOptions.backend, receipt: {sha: old, manifest: {}}},
  ]) assert.throws(() => compatibilityContext({...contextOptions, backend}));
});

function fixture(check) {
  const root = mkdtempSync(join(tmpdir(), 'mobile-backend-test-'));
  try {
    const sandbox = join(root, 'sandbox');
    for (const path of ['build/contracts', 'build/release/mobile-backend-compatibility', 'sandbox/tool/firebase', 'sandbox/functions/test']) {
      mkdirSync(join(root, path), {recursive: true});
    }
    for (const name of ['app-current.json', 'workout-save-current.json']) writeFileSync(join(root, 'build/contracts', name), '{"candidate":true}');
    writeFileSync(join(sandbox, 'tool/firebase/contract-suites.json'), '{"firebaseTools":"15.29.0"}');
    const plan = {clientTests: ['test/current_backend_test.dart', 'test/deferred_test.dart'],
      emulatorSuites: ['functions/test/mobile-api-emulator.mjs'], planHash: 'f'.repeat(64), files: {}, deferredFeatures: []};
    check({root, sandbox, plan, context: compatibilityContext(contextOptions)});
  } finally { rmSync(root, {recursive: true, force: true}); }
}

test('candidate DTOs and fallback tests run against the deployed sandbox without release credentials', () => {
  fixture(options => {
    const calls = [];
    const report = runCompatibilityChecks({...options, executeCommand: (command, args, settings) => {
      calls.push({command, args, ...settings});
      assert.equal(settings.env.GCLOUD_PROJECT, 'demo-cloudboard');
      for (const key of ['GITHUB_TOKEN', 'GOOGLE_APPLICATION_CREDENTIALS', 'FIREBASE_TOKEN']) assert.equal(settings.env[key], undefined);
    }});
    assert.equal(report.status, 'success');
    assert.equal(report.backendSourceSha, old);
    assert.equal(readFileSync(join(options.sandbox, 'build/contracts/app-current.json'), 'utf8'), '{"candidate":true}');
    assert.deepEqual(calls[1].args, ['test', ...options.plan.clientTests]);
    assert.equal(calls.at(-1).cwd, options.sandbox);
    assert(calls.at(-1).args.includes('demo-cloudboard'));
    assert.equal(calls.at(-1).args.at(-1), 'node functions/test/mobile-compatibility-suites.mjs');
    execFileSync(process.execPath, ['--check', join(options.sandbox, 'functions/test/mobile-compatibility-suites.mjs')]);
    assert(!existsSync(join(options.root, 'build/release/mobile-backend-compatibility/release.json')),
      'Only the CLI writes a successful report after checking server inputs again');
  });
});

test('export, client fallback, dependency or emulator failure never produces passing evidence', () => {
  for (let failing = 0; failing < 4; failing++) fixture(options => {
    let index = 0;
    assert.throws(() => runCompatibilityChecks({...options, executeCommand: () => {
      if (index++ === failing) throw new Error('contract failed');
    }}), /contract failed/);
    assert.equal(index, failing + 1);
  });
});

test('sandbox uses candidate tests and old server inputs without checking out a different source', () => {
  const root = mkdtempSync(join(tmpdir(), 'mobile-backend-archive-'));
  const cwd = process.cwd();
  try {
    process.chdir(root);
    const put = (path, content) => {
      mkdirSync(join(root, path, '..'), {recursive: true});
      writeFileSync(path, content);
    };
    const git = (...args) => execFileSync('git', args, {encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe']}).trim();
    git('init', '-q');
    for (const path of ['functions/src/server.js', 'functions/certificates/cert.pem', 'functions/package.json',
      'functions/package-lock.json', 'firebase.json', 'firestore.rules', 'firestore.indexes.json',
      'database.rules.json', 'storage.rules', 'functions/test/mobile-api-emulator.mjs',
      'firebase.security-test.json', 'lib/app.dart', 'pubspec.yaml', 'test/fallback_test.dart']) put(path, path.endsWith('.json') ? '{}' : 'old');
    cpSync(fileURLToPath(new URL('../firebase', import.meta.url)), join(root, 'tool/firebase'), {recursive: true});
    const commit = () => {
      git('add', '.');
      git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'fixture');
      return git('rev-parse', 'HEAD');
    };
    // Isolated test-fixture commits, never the CloudBoard worktree.
    const backendSourceSha = commit(), clientBefore = mobileClientFingerprint(backendSourceSha);
    const deployedFingerprint = backendFingerprint(backendSourceSha);
    put('functions/src/server.js', 'new server');
    put('functions/src/undeployed.js', 'must not enter old backend tests');
    put('functions/test/mobile-api-emulator.mjs', 'candidate contract');
    const candidate = commit();
    assert.equal(mobileClientFingerprint(candidate), clientBefore, 'Server-only changes do not stale the app declaration');
    put('lib/app.dart', 'new app');
    const source = commit();
    assert.notEqual(mobileClientFingerprint(source), clientBefore);
    const sandbox = join(root, 'build/sandbox');
    prepareBackendSandbox({sha: source, backendSourceSha, sandbox});
    assert.equal(readFileSync(join(sandbox, 'functions/src/server.js'), 'utf8'), 'old');
    assert.equal(existsSync(join(sandbox, 'functions/src/undeployed.js')), false);
    assert.equal(readFileSync(join(sandbox, 'functions/test/mobile-api-emulator.mjs'), 'utf8'), 'candidate contract');
    verifySandboxFingerprint(sandbox, deployedFingerprint);
    writeFileSync(join(sandbox, 'functions/src/server.js'), 'mutated during testing');
    assert.throws(() => verifySandboxFingerprint(sandbox, deployedFingerprint), /unchanged deployed server/);
    assert.equal(git('rev-parse', 'HEAD'), source);
    assert.equal(readFileSync('functions/src/server.js', 'utf8'), 'new server');
    const output = 'build/release/mobile-backend-compatibility/release.json';
    put(output, 'existing evidence');
    const cli = fileURLToPath(new URL('./verify_mobile_backend.mjs', import.meta.url));
    const description = JSON.parse(execFileSync(process.execPath, [cli, 'fingerprints', backendSourceSha], {encoding: 'utf8'}));
    assert.equal(description.backendFingerprint, deployedFingerprint);
    assert.equal(description.clientFingerprint, mobileClientFingerprint(source));
    assert.throws(() => execFileSync(process.execPath, [cli, 'fingerprints', 'invalid'], {stdio: 'pipe'}));
    assert.equal(readFileSync(output, 'utf8'), 'existing evidence', 'Offline fingerprint inspection must not erase evidence');
  } finally { process.chdir(cwd); rmSync(root, {recursive: true, force: true}); }
});
