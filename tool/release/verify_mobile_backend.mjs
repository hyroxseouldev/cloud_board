import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {appendFileSync, mkdirSync, readFileSync, rmSync, writeFileSync, copyFileSync} from 'node:fs';
import {resolve, join} from 'node:path';
import {pathToFileURL} from 'node:url';
import {backendFingerprint, github, isReleaseTag} from '../firebase/release.mjs';
import {latestRelease} from '../firebase/latest-release.mjs';
import {readReleaseArtifact} from '../firebase/github-artifact.mjs';
import {mobileClientFingerprint, mobileCompatibilityPlan, validateMobileCompatibilityPlan} from './mobile_backend_compatibility.mjs';

const output = 'build/release/mobile-backend-compatibility';
const sandboxPath = 'build/release/mobile-backend-sandbox';
const git = (...args) => execFileSync('git', args, {maxBuffer: 32 * 1024 * 1024});
const readSource = (sha, path) => {
  assert.match(git('ls-tree', sha, '--', path).toString(), /^100(?:644|755) blob /, `Expected tracked regular file: ${path}`);
  return git('show', `${sha}:${path}`);
};
const save = (path, value) => writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`);

export function compatibilityContext({sha, releaseTag, backend, candidateFingerprint, clientFingerprint, runId, runAttempt}) {
  assert.match(sha || '', /^[a-f0-9]{40}$/);
  assert(isReleaseTag(releaseTag), 'Mobile compatibility verification requires a release tag');
  assert.equal(backend.status, 'success', 'Wait for the current backend deployment to finish');
  assert.match(backend.receipt.sha || '', /^[a-f0-9]{40}$/);
  assert.match(backend.receipt.manifest.backendFingerprint || '', /^[a-f0-9]{64}$/,
    'Mobile-first verification needs a backend receipt with a recorded fingerprint');
  assert.match(runId || '', /^[1-9]\d*$/);
  assert.match(runAttempt || '', /^[1-9]\d*$/);
  return {schemaVersion: 1, kind: 'mobile-backend-compatibility', sourceSha: sha, releaseTag,
    backendSourceSha: backend.receipt.sha, backendFingerprint: backend.receipt.manifest.backendFingerprint,
    backendRunId: String(backend.run.id), backendRunAttempt: String(backend.run.run_attempt),
    clientFingerprint, runId, runAttempt,
    method: candidateFingerprint === backend.receipt.manifest.backendFingerprint ? 'identical-backend' : 'deployed-backend-contracts'};
}

function cleanTestEnvironment(sandbox) {
  const env = {};
  for (const key of ['PATH', 'HOME', 'JAVA_HOME', 'LANG', 'TMPDIR', 'PUB_CACHE', 'FLUTTER_ROOT', 'FLUTTER_BIN']) {
    if (process.env[key]) env[key] = process.env[key];
  }
  return {...env, CI: 'true', GCLOUD_PROJECT: 'demo-cloudboard', GOOGLE_CLOUD_PROJECT: 'demo-cloudboard',
    FIREBASE_CONFIG: JSON.stringify({projectId: 'demo-cloudboard'}),
    CLOUDSDK_CONFIG: join(sandbox, '.cloudsdk'), MOBILE_BACKEND_FIXTURE_DIR: sandbox};
}

function execute(command, args, {cwd, env, log, timeout = 300_000}) {
  // No shell expansion, store credentials or production DB access.
  try {
    const bytes = execFileSync(command, args, {cwd, env, timeout, maxBuffer: 16 * 1024 * 1024,
      stdio: ['ignore', 'pipe', 'pipe']});
    if (log) appendFileSync(log, bytes);
  } catch (error) {
    if (log) {
      if (error.stdout) appendFileSync(log, error.stdout);
      if (error.stderr) appendFileSync(log, error.stderr);
    }
    throw new Error(`Mobile compatibility command failed: ${command} ${args.join(' ')}; see retained log`, {cause: error});
  }
}

export function archiveSource(sha, paths, destination) {
  assert.match(sha, /^[a-f0-9]{40}$/);
  const entries = git('ls-tree', '-r', sha, '--', ...paths).toString();
  assert(entries && entries.split('\n').filter(Boolean).every(line => /^100(?:644|755) blob /.test(line)),
    'Compatibility sandbox accepts only regular source files');
  const bytes = git('archive', '--format=tar', sha, '--', ...paths);
  execFileSync('tar', ['-xf', '-', '-C', destination], {input: bytes, stdio: ['pipe', 'pipe', 'pipe']});
}

export function prepareBackendSandbox({sha, backendSourceSha, sandbox}) {
  mkdirSync(sandbox, {recursive: true});
  // Tests come from the candidate; all deployed inputs come from the actual
  // backend receipt. No checkout/worktree or source-branch switch is needed.
  archiveSource(sha, ['functions', 'tool/firebase', 'firebase.security-test.json'], sandbox);
  for (const path of ['functions/src', 'functions/certificates']) {
    rmSync(join(sandbox, path), {recursive: true, force: true});
  }
  archiveSource(backendSourceSha, ['functions/src', 'functions/certificates', 'functions/package.json',
    'functions/package-lock.json', 'firebase.json', 'firestore.rules', 'firestore.indexes.json',
    'database.rules.json', 'storage.rules'], sandbox);
}

// Factored so failure/ordering can be tested without starting SDKs or emulators.
export function runCompatibilityChecks({context, plan, root, sandbox, executeCommand = execute}) {
  const env = cleanTestEnvironment(sandbox), checks = [], log = resolve(root, output, 'checks.log');
  const run = (id, command, args, cwd = root, timeout) => {
    executeCommand(command, args, {cwd, env, log, timeout});
    checks.push({id, status: 'success'});
  };
  const flutter = process.env.FLUTTER_BIN || 'flutter';
  run('candidate-exports', flutter, ['test', 'tool/export_workout_save_fixtures_test.dart', 'tool/export_app_contracts_test.dart']);
  mkdirSync(join(sandbox, 'build/contracts'), {recursive: true});
  for (const name of ['workout-save-current.json', 'app-current.json']) {
    copyFileSync(join(root, 'build/contracts', name), join(sandbox, 'build/contracts', name));
  }
  run('client-behavior', flutter, ['test', ...plan.clientTests]);
  run('backend-dependencies', 'npm', ['ci', '--prefix', 'functions', '--ignore-scripts'], sandbox);
  const runner = join(sandbox, 'functions/test/mobile-compatibility-suites.mjs');
  writeFileSync(runner, `import {execFileSync} from 'node:child_process';\n` +
    `import {readFileSync} from 'node:fs';\n` +
    `import {initializeTestEnvironment} from '@firebase/rules-unit-testing';\n` +
    `import {emulatorAddress, requireDemo} from '../../tool/firebase/common.mjs';\n` +
    `for (const path of ${JSON.stringify(plan.emulatorSuites)}) {\n` +
    `  const env = await initializeTestEnvironment({projectId: requireDemo(process.env.GCLOUD_PROJECT),\n` +
    `    firestore: {...emulatorAddress(process.env.FIRESTORE_EMULATOR_HOST), rules: readFileSync('firestore.rules', 'utf8')},\n` +
    `    database: {...emulatorAddress(process.env.FIREBASE_DATABASE_EMULATOR_HOST), rules: readFileSync('database.rules.json', 'utf8')},\n` +
    `    storage: {...emulatorAddress(process.env.FIREBASE_STORAGE_EMULATOR_HOST), rules: readFileSync('storage.rules', 'utf8')}});\n` +
    `  try { await env.clearFirestore(); await env.clearDatabase(); await env.clearStorage(); }\n` +
    `  finally { await env.cleanup(); }\n` +
    `  const auth = emulatorAddress(process.env.FIREBASE_AUTH_EMULATOR_HOST);\n` +
    `  const reset = await fetch('http://' + auth.host + ':' + auth.port + '/emulator/v1/projects/demo-cloudboard/accounts', {method: 'DELETE', signal: AbortSignal.timeout(15000)});\n` +
    `  if (!reset.ok) throw new Error('Local Auth reset failed');\n` +
    `  console.log('Checking deployed backend:', path);\n` +
    `  execFileSync(process.execPath, [path], {stdio: 'inherit', timeout: 240000});\n}\n`);
  const config = JSON.parse(readFileSync(join(sandbox, 'tool/firebase/contract-suites.json'), 'utf8'));
  assert(/^\d+\.\d+\.\d+$/.test(config.firebaseTools), 'Firebase CLI must be pinned');
  run('deployed-backend-emulators', 'npx', ['--yes', `firebase-tools@${config.firebaseTools}`, 'emulators:exec',
    '--config', 'firebase.security-test.json', '--project', 'demo-cloudboard',
    '--only', 'auth,firestore,database,storage', 'node functions/test/mobile-compatibility-suites.mjs'], sandbox, 20 * 60_000);
  for (const id of plan.emulatorSuites) checks.push({id, status: 'success'});
  return {...context, status: 'success', planHash: plan.planHash, testedFiles: plan.files, clientTests: plan.clientTests,
    deferredFeatures: plan.deferredFeatures, checks, finishedAt: new Date().toISOString()};
}

export function verifySandboxFingerprint(sandbox, wanted) {
  const actual = execFileSync(process.execPath, ['--input-type=module', '-e',
    "import {backendFingerprint} from './tool/firebase/release.mjs'; process.stdout.write(backendFingerprint());"],
  {cwd: sandbox, encoding: 'utf8'}).trim();
  assert.equal(actual, wanted, 'Tests must use unchanged deployed server inputs, not candidate server code');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const env = process.env, root = process.cwd(), directory = resolve(output);
  const command = process.argv[2];
  if (command !== 'fingerprints') mkdirSync(directory, {recursive: true});
  try {
    const sha = git('rev-parse', 'HEAD').toString().trim();
    if (command === 'fingerprints') {
      // Offline preparation only. The CI and upload checks still re-read the
      // actual deployment receipt; this command does not claim live status.
      const baseline = process.argv[3];
      assert.match(baseline || '', /^[a-f0-9]{40}$/, 'Supply the source SHA from a verified backend deployment receipt');
      console.log(JSON.stringify({sourceSha: sha, clientFingerprint: mobileClientFingerprint(sha),
        backendSourceSha: baseline, backendFingerprint: backendFingerprint(baseline)}, null, 2));
    } else if (command === 'prepare') {
      assert.equal(sha, env.GITHUB_SHA, 'Compatibility source differs from the workflow source');
      rmSync(join(directory, 'release.json'), {force: true});
      const backend = await latestRelease({repository: env.GITHUB_REPOSITORY, request: github,
        ignoreRunId: env.GITHUB_RUN_ID,
        readArtifact: artifact => readReleaseArtifact(artifact, env.GITHUB_REPOSITORY, env.GITHUB_TOKEN)});
      const context = compatibilityContext({sha, releaseTag: env.GITHUB_REF?.replace(/^refs\/tags\//, ''),
        backend, candidateFingerprint: backendFingerprint(sha), clientFingerprint: mobileClientFingerprint(sha),
        runId: env.GITHUB_RUN_ID, runAttempt: env.GITHUB_RUN_ATTEMPT});
      if (context.method === 'deployed-backend-contracts') {
        let plan;
        try { plan = JSON.parse(readSource(sha, mobileCompatibilityPlan)); }
        catch { throw new Error(`Add ${mobileCompatibilityPlan} with focused current-server and deferred-feature tests. App fingerprint: ${context.clientFingerprint}; deployed backend fingerprint: ${context.backendFingerprint}`); }
        validateMobileCompatibilityPlan(plan, {...context, readSource: path => readSource(sha, path)});
      } else save(join(directory, 'release.json'), {...context, status: 'success'});
      save(join(directory, 'context.json'), context);
      assert(env.GITHUB_OUTPUT);
      appendFileSync(env.GITHUB_OUTPUT, `needs_tests=${context.method === 'deployed-backend-contracts'}\n`);
      console.log(`Mobile compatibility: ${context.method}; actual backend ${context.backendSourceSha}`);
    } else if (command === 'test') {
      assert.equal(sha, env.GITHUB_SHA, 'Compatibility source differs from the workflow source');
      rmSync(join(directory, 'release.json'), {force: true});
      const context = JSON.parse(readFileSync(join(directory, 'context.json'), 'utf8'));
      assert.equal(context.sourceSha, sha);
      assert.equal(context.runId, env.GITHUB_RUN_ID);
      assert.equal(context.runAttempt, env.GITHUB_RUN_ATTEMPT);
      assert.equal(context.method, 'deployed-backend-contracts');
      assert.equal(context.clientFingerprint, mobileClientFingerprint(sha));
      const plan = validateMobileCompatibilityPlan(JSON.parse(readSource(sha, mobileCompatibilityPlan)),
        {...context, readSource: path => readSource(sha, path)});
      const unchangedClient = () => git('diff', '--exit-code', sha, '--', 'lib', 'ios', 'android', 'assets',
        'config', 'test', 'pubspec.yaml', 'pubspec.lock', '.fvmrc',
        'tool/export_workout_save_fixtures_test.dart', 'tool/export_app_contracts_test.dart');
      unchangedClient();
      const sandbox = resolve(sandboxPath);
      rmSync(sandbox, {recursive: true, force: true});
      prepareBackendSandbox({sha, backendSourceSha: context.backendSourceSha, sandbox});
      verifySandboxFingerprint(sandbox, context.backendFingerprint);
      const report = runCompatibilityChecks({context, plan, root, sandbox});
      verifySandboxFingerprint(sandbox, context.backendFingerprint);
      unchangedClient();
      save(join(directory, 'release.json'), report);
      console.log('Mobile contracts passed against the deployed backend copy; no production changes were made.');
    } else throw new Error('Use fingerprints <backend SHA>, prepare or test');
  } catch (error) {
    if (command !== 'fingerprints') rmSync(join(directory, 'release.json'), {force: true});
    console.error(error.message);
    process.exitCode = 1;
  }
}
