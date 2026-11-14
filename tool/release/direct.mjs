import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {existsSync, readFileSync, writeFileSync, mkdirSync, readdirSync, rmSync} from 'node:fs';
import {resolve, dirname, basename} from 'node:path';
import {pathToFileURL} from 'node:url';
import {directPlan} from './direct-plan.mjs';
import {runtimeConfiguration, verifySecretBindings} from './direct-runtime.mjs';
import {functionTargets} from './direct-targets.mjs';
import {beginAttempt, updateAttempt, repository} from './direct-receipts.mjs';
import {github, backendFingerprint, makeManifest, manifestHash, validateReceipt, requireNoRollback} from '../firebase/release.mjs';
import {verifyEnvironments, versionDevelopmentEntrypoint} from '../firebase/environments.mjs';
import {prepareDevelopmentDisplayPackage} from '../firebase/prepare-development-display.mjs';
import {requireBackend} from '../release_backend_gate.mjs';
import {readReleaseArtifact} from '../firebase/github-artifact.mjs';
import {validateMobileReceipt, recheckSource} from './source.mjs';
import {validateMobileCompatibilityReport} from './mobile_backend_compatibility.mjs';
import {prepareSmokeInputs} from '../firebase/smoke-inputs.mjs';
import {writeJson, root} from '../firebase/common.mjs';

const git = (...args) => execFileSync('git', args, {encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe']}).trim();
const json = path => JSON.parse(readFileSync(path, 'utf8'));
export function assertCleanSource(sourceSha, runGit = git) {
  assert.equal(runGit('rev-parse', 'HEAD'), sourceSha, 'Run from a checkout of the exact selected commit');
  assert.equal(runGit('status', '--porcelain', '--untracked-files=all'), '', 'A clean source checkout is required; commit changes in a separate worktree');
}
export function parseArgs(args) {
  const options = {upload: false, execute: false, functions: []};
  const names = {'--source': 'sourceSha', '--environment': 'environment', '--scope': 'scope', '--tag': 'tag', '--functions': 'functions'};
  const seen = new Set();
  for (let i = 0; i < args.length; i++) {
    const flag = args[i];
    assert(!seen.has(flag), `Duplicate option: ${flag}`); seen.add(flag);
    if (flag === '--execute' || flag === '--upload') options[flag.slice(2)] = true;
    else {
      assert(names[flag] && args[i + 1] && !args[i + 1].startsWith('--'), `Unknown or incomplete option: ${flag}`);
      const value = args[++i]; options[names[flag]] = flag === '--functions' ? value.split(',') : value;
    }
  }
  return options;
}
function command(name, args, env = process.env) {
  try { return execFileSync(name, args, {env, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], maxBuffer: 64 * 1024 * 1024}); }
  catch (error) { throw new Error(`${basename(name)} failed (${Number.isInteger(error.status) ? `exit ${error.status}` : /^[A-Z_]+$/.test(error.code || '') ? error.code : 'unknown'}); stage is not confirmed (child output withheld to protect local credentials)`); }
}
function required(...keys) {
  for (const key of keys) assert(process.env[key]?.trim(), `Missing local ${key}; no credentials are created by this command`);
}
async function sourceCheck(plan) {
  assertCleanSource(plan.sourceSha);
  if (plan.environment === 'production') await recheckSource({sourceSha: plan.sourceSha, deploymentTag: plan.tag, mode: 'release', repository});
  else {
    const compare = await github(`/repos/${repository}/compare/${plan.sourceSha}...develop`);
    assert(['ahead', 'identical'].includes(compare.status) && compare.merge_base_commit?.sha === plan.sourceSha,
      'Development source must be included in origin/develop');
  }
}
function importBuildNumber(path, key) {
  const entries = readFileSync(path, 'utf8').split('\n').filter(line => line.startsWith(`${key}=`));
  assert.equal(entries.length, 1, 'Allocator did not issue exactly one build number');
  const value = entries[0].slice(key.length + 1); assert.match(value, /^[1-9]\d*$/); return value;
}
async function backendGate(plan, directory, id) {
  return requireBackend({repository, sha: plan.sourceSha, request: github, mode: 'release',
    functionsOnly: plan.scope === 'rules', mobile: ['ios', 'android'].includes(plan.scope), releaseTag: plan.tag,
    ignoreRunId: id, readArtifact: a => readReleaseArtifact(a, repository, process.env.GITHUB_TOKEN),
    checkMobileCompatibility: async ({sha, releaseTag, backendFingerprint: fingerprint}) => {
      const report = json(`${directory}/mobile-compatibility.json`);
      validateMobileCompatibilityReport(report, {sourceSha: sha, releaseTag, backendFingerprint: fingerprint,
        run: {id, run_attempt: 1}});
      return {method: report.method, validationRunId: id, validationRunAttempt: '1',
        clientFingerprint: report.clientFingerprint, planHash: report.planHash, deferredFeatures: report.deferredFeatures};
    }});
}
export async function runRecordedStage({id, attempt, save, work, log = console.log}) {
  log(`Starting ${id}`);
  const record = {id, status: 'running', startedAt: new Date().toISOString()};
  attempt.steps.push(record); await save();
  try {
    await work(); record.status = 'success'; record.completedAt = new Date().toISOString();
    await save(); log(`Completed ${id}`);
  } catch (error) { record.status = 'failed'; record.completedAt = new Date().toISOString(); throw error; }
}
export async function executePlan(plan) {
  // Source and access checks precede the receipt lock; no deployment occurs here.
  assert.equal(resolve(process.cwd()), resolve(root), 'Execute control tools from their own fixed source checkout');
  await sourceCheck(plan);
  verifyEnvironments();
  assert.equal(Number(process.versions.node.split('.')[0]), 22, 'Execute with the repository Node 22 toolchain');
  process.env.PATH = `${dirname(process.execPath)}:${process.env.PATH}`;
  const actor = (await github('/user')).login;
  assert(actor, 'Cannot identify the authenticated deployment actor');
  const id = `${Date.now()}${Math.floor(Math.random() * 1000).toString().padStart(3, '0')}`;
  const directory = resolve('build/direct-release', id); mkdirSync(directory, {recursive: true});
  const env = process.env;
  Object.assign(env, {CLOUDBOARD_DIRECT_RECEIPTS: 'true', CLOUDBOARD_DIRECT_RELEASE: 'true',
    GITHUB_REPOSITORY: repository, GITHUB_SHA: plan.sourceSha, SOURCE_SHA: plan.sourceSha,
    RELEASE_SOURCE_SHA: plan.sourceSha, GITHUB_RUN_ID: id, GITHUB_RUN_ATTEMPT: '1',
    GITHUB_EVENT_NAME: 'direct_cli', GITHUB_REF: plan.tag ? `refs/tags/${plan.tag}` : 'refs/heads/develop',
    RELEASE_TAG: plan.tag, RUNNER_TEMP: directory, GITHUB_ENV: `${directory}/build-number.env`,
    GITHUB_OUTPUT: `${directory}/outputs`, IOS_BUNDLE_ID: plan.bundle, ANDROID_PACKAGE_NAME: plan.bundle});
  // Existing store allocator and old artifact readers need a token. Resolve the
  // existing gh login in memory only; never persist or print it.
  if (!env.GITHUB_TOKEN) env.GITHUB_TOKEN = command('gh', ['auth', 'token']).trim();
  let attempt = {schemaVersion: 1, kind: 'direct-deployment', id, sourceSha: plan.sourceSha,
    environment: plan.environment, project: plan.project, scope: plan.scope, tag: plan.tag,
    version: plan.version, actor, status: 'running', startedAt: new Date().toISOString(),
    validation: plan.validation, steps: [], targets: [], storeReview: 'not-submitted'};
  let state = await beginAttempt(github, attempt);
  const save = async () => {
    writeFileSync(`${directory}/attempt.json`, JSON.stringify(attempt, null, 2) + '\n');
    state = await updateAttempt(github, state, attempt);
  };
  let target, manifest, backend, buildNumber, artifact, runtime;
  const dependencies = dir => {
    const digest = createHash('sha256').update(readFileSync(`${dir}/package.json`)).update(readFileSync(`${dir}/package-lock.json`)).digest('hex');
    const stamp = `${dir}/node_modules/.cloudboard-direct-lock`;
    if (existsSync(`${dir}/node_modules/.package-lock.json`) && existsSync(stamp) && readFileSync(stamp, 'utf8') === digest) {
      attempt.dependencyCache = {...attempt.dependencyCache, [dir]: 'reused'}; return;
    }
    command('npm', ['ci', '--prefix', dir]); writeFileSync(stamp, digest);
    attempt.dependencyCache = {...attempt.dependencyCache, [dir]: 'installed'};
  };
  const node = (...args) => command(process.execPath, args);
  const flutter = (...args) => command(env.FLUTTER_BIN || 'flutter', args);
  const firebase = (...args) => command('npx', ['--yes', 'firebase-tools@15.29.0', ...args]);
  const stage = (id, work) => runRecordedStage({id, attempt, save, work});
  const compatibility = async () => {
    if (['ios', 'android'].includes(plan.scope)) {
      node('tool/release/verify_mobile_backend.mjs', 'prepare');
      const context = json('build/release/mobile-backend-compatibility/context.json');
      if (context.method === 'deployed-backend-contracts') node('tool/release/verify_mobile_backend.mjs', 'test');
      writeFileSync(`${directory}/mobile-compatibility.json`, readFileSync('build/release/mobile-backend-compatibility/release.json'));
    }
    backend = await backendGate(plan, directory, id); attempt.backend = backend.backendReference;
  };
  try {
    for (const step of plan.steps) await stage(step, async () => {
      switch (step) {
        case 'verify-source': case 'recheck-source': await sourceCheck(plan); break;
        case 'verify-environment': verifyEnvironments(); break;
        case 'toolchain': {
          attempt.toolchain = {node: process.versions.node};
          if (['web', 'ios', 'android'].includes(plan.scope) || plan.environment === 'production') {
            const installed = JSON.parse(flutter('--version', '--machine'));
            assert.equal(installed.frameworkVersion, json('.fvmrc').flutter, 'Use the Flutter version pinned by this source');
            attempt.toolchain.flutter = installed.frameworkVersion;
          }
          if (plan.scope === 'ios') attempt.toolchain.xcode = command('xcodebuild', ['-version']).trim();
          break;
        }
        case 'development-store-readiness':
          assert.equal(env.MOBILE_DEVELOPMENT_READY, 'true', 'Development store registration/signing is unverified');
          {
            const report = JSON.parse(node('tool/release/development_readiness.mjs', plan.scope));
            if (plan.scope === 'ios') assert(report.storeAppRegistered && report.bundles.every(b => b.registered && b.activeAppStoreProfileCount > 0) && report.bundles[0].appleSignInCapability, 'Development app/profile/capability readiness is incomplete');
            else assert(report.storeAppAccessible, 'Development Play application is unavailable');
          } break;
        case 'signing-preflight':
          if (plan.scope === 'ios') {
            required('APP_STORE_CONNECT_API_KEY_PATH', 'APP_STORE_CONNECT_KEY_ID', 'APP_STORE_CONNECT_ISSUER_ID', 'IOS_TEAM_ID', 'IOS_EXPORT_OPTIONS_PATH');
            assert(existsSync(env.APP_STORE_CONNECT_API_KEY_PATH) && existsSync(env.IOS_EXPORT_OPTIONS_PATH));
            assert(command('security', ['find-identity', '-v', '-p', 'codesigning']).includes('Apple Distribution'), 'No local Apple Distribution identity');
            assert.equal(basename(env.APP_STORE_CONNECT_API_KEY_PATH), `AuthKey_${env.APP_STORE_CONNECT_KEY_ID}.p8`, 'Use the existing AuthKey_<key ID>.p8 path');
          } else {
            required('ANDROID_KEYSTORE_PATH', 'ANDROID_KEYSTORE_PASSWORD', 'ANDROID_KEY_ALIAS', 'ANDROID_KEY_PASSWORD', 'BUNDLETOOL_PATH', 'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON');
            assert(existsSync(env.ANDROID_KEYSTORE_PATH) && existsSync(env.BUNDLETOOL_PATH));
          }
          break;
        case 'allocate-build':
          if (plan.scope === 'ios') { node('tool/release/ios_build_number.mjs', '--next'); buildNumber = importBuildNumber(env.GITHUB_ENV, 'TESTFLIGHT_BUILD_NUMBER'); env.TESTFLIGHT_BUILD_NUMBER = buildNumber; }
          else { node('tool/release/play_version_code.mjs', '--reserve', `${directory}/play-reservation.json`); buildNumber = importBuildNumber(env.GITHUB_ENV, 'PLAY_BUILD_NUMBER'); }
          attempt.buildNumber = buildNumber; break;
        case 'firebase-access': {
          const result = JSON.parse(firebase('projects:list', '--json'));
          assert.equal(result.status, 'success'); assert(result.result.some(p => p.projectId === plan.project), 'Local Firebase account lacks project access');
          for (const dir of ['functions', 'functions-legacy']) assert(!readdirSync(dir).some(name => name.startsWith('.env') || name.startsWith('.secret')), 'Source env/secret overrides are forbidden; use local authentication and reviewed runtime configuration');
          break;
        }
        case 'no-rollback': await requireNoRollback({repository, sha: plan.sourceSha, ref: env.GITHUB_REF,
          tag: plan.tag, request: github, scope: plan.scope === 'functions' ? 'backend' : plan.scope, ignoreRunId: id}); break;
        case 'backend-compatibility': await compatibility(); break;
        case 'recheck-backend': backend = await backendGate(plan, directory, id); break;
        case 'function-targets': {
          dependencies('functions');
          Object.assign(env, {GCLOUD_PROJECT: plan.project, GOOGLE_CLOUD_PROJECT: plan.project, FIREBASE_CONFIG: JSON.stringify({projectId: plan.project})});
          const inventory = JSON.parse(firebase('functions:list', '--project', plan.project, '--json'));
          runtime = runtimeConfiguration(inventory, {environment: plan.environment, origins: env.CLOUDBOARD_MEDIA_ALLOWED_ORIGINS});
          for (const key of ['APPLE_IAP_SECRETS_ENABLED', 'AI_TIMER_SECRETS_ENABLED', 'APP_STORE_RECONCILIATION_ENABLED', 'GOOGLE_PLAY_RECONCILIATION_ENABLED', 'SUPPORT_EMAIL_DELIVERY_ENABLED', 'SUPPORT_EMAIL_SECRETS_ENABLED']) delete env[key];
          Object.assign(env, runtime.variables);
          const exports = await import('../../functions/src/index.js');
          target = functionTargets({environment: plan.environment, exports, selected: plan.functions});
          attempt.targets = target.split(',');
          verifySecretBindings(inventory, exports, target);
          attempt.runtimeConfigurationHash = runtime.digest;
          if (target.includes('functions:cloudboard-auth:')) {
            dependencies('functions-legacy'); command('npm', ['run', 'build', '--prefix', 'functions-legacy']);
            await prepareDevelopmentDisplayPackage(plan.project);
          }
          break;
        }
        case 'smoke-inputs':
          env.RELEASE_VALIDATION_MODE = 'skipped';
          dependencies('functions');
          flutter('pub', 'get');
          flutter('test', 'tool/export_workout_save_fixtures_test.dart', 'tool/export_app_contracts_test.dart');
          prepareSmokeInputs({sourceSha: plan.sourceSha});
          node('functions/tools/release-smoke.mjs', 'preflight'); break;
        case 'build': {
          flutter('pub', 'get');
          if (plan.scope === 'web') {
            buildNumber = `${id}.1`; attempt.buildNumber = buildNumber;
            flutter('build', 'web', '--release', `--dart-define=FIREBASE_ENV=${plan.environment}`, '--build-name', plan.version,
              '--build-number', buildNumber, `--dart-define=APP_BUILD_NAME=${plan.version}`, `--dart-define=APP_BUILD_NUMBER=${buildNumber}`);
            const versioned = versionDevelopmentEntrypoint(readFileSync('build/web/index.html', 'utf8'), readFileSync('build/web/flutter_bootstrap.js', 'utf8'), readFileSync('build/web/main.dart.js'));
            writeFileSync('build/web/index.html', versioned.index); writeFileSync('build/web/flutter_bootstrap.js', versioned.bootstrap);
            assert.equal(json('build/web/version.json').build_number, buildNumber);
          } else if (plan.scope === 'android') {
            flutter('build', 'appbundle', '--flavor', plan.environment, '--release', `--dart-define=FIREBASE_ENV=${plan.environment}`,
              '--build-name', plan.version, '--build-number', buildNumber);
            artifact = `build/app/outputs/bundle/${plan.environment}Release/app-${plan.environment}-release.aab`;
          } else {
            flutter('build', 'ipa', '--flavor', plan.environment, '--release', `--dart-define=FIREBASE_ENV=${plan.environment}`,
              '--build-name', plan.version, '--build-number', buildNumber, '--no-codesign');
            command('python3', ['tool/prepare_ios_entitlements.py', 'build/ios/archive/Runner.xcarchive', 'ios/Runner/Runner.entitlements', '--team-id', env.IOS_TEAM_ID, '--bundle-id', plan.bundle]);
            command('xcodebuild', ['-exportArchive', '-archivePath', 'build/ios/archive/Runner.xcarchive', '-exportPath', `${directory}/ipa`,
              '-exportOptionsPlist', env.IOS_EXPORT_OPTIONS_PATH, '-allowProvisioningUpdates', '-authenticationKeyPath', env.APP_STORE_CONNECT_API_KEY_PATH,
              '-authenticationKeyID', env.APP_STORE_CONNECT_KEY_ID, '-authenticationKeyIssuerID', env.APP_STORE_CONNECT_ISSUER_ID]);
            const names = readdirSync(`${directory}/ipa`).filter(name => name.endsWith('.ipa')); assert.equal(names.length, 1);
            artifact = `${directory}/ipa/${names[0]}`;
          }
          break;
        }
        case 'inspect-artifact': {
          if (plan.scope === 'ios') command('python3', ['tool/inspect_ios_signing.py', artifact, `${directory}/signing.json`, '--team-id', env.IOS_TEAM_ID, '--bundle-id', plan.bundle]);
          command('python3', ['tool/release/inspect_native.py', plan.scope, artifact, '--version', plan.version, '--build', buildNumber,
            '--environment', plan.environment, ...(plan.scope === 'android' ? ['--bundletool', env.BUNDLETOOL_PATH] : []), '--output', `${directory}/metadata.json`]);
          attempt.mobile = validateMobileReceipt({...json(`${directory}/metadata.json`), schemaVersion: 5, kind: 'mobile-source',
            sourceSha: plan.sourceSha, workflowSha: plan.sourceSha, controlSha: plan.sourceSha, sourceRef: plan.tag || plan.sourceSha,
            ...(plan.tag ? {deploymentTag: plan.tag, releaseTag: plan.tag} : {}), releaseMode: plan.environment === 'production' ? 'release' : 'qa',
            environment: plan.environment, runId: id, runAttempt: '1', origin: 'direct-cli', validationMode: plan.environment === 'production' ? 'skipped' : 'not_requested',
            ...(plan.environment === 'production' ? {skipReason: 'Direct CLI; integration CI was not run', validationActor: actor} : {})});
          break;
        }
        case 'recheck-build':
          if (plan.scope === 'ios') node('tool/release/ios_build_number.mjs', '--recheck');
          else node('tool/release/play_version_code.mjs', '--recheck', `${directory}/play-reservation.json`);
          break;
        case 'upload':
          assert.equal(createHash('sha256').update(readFileSync(artifact)).digest('hex'), attempt.mobile.artifactSha256, 'Artifact changed after inspection');
          if (plan.scope === 'ios') command('xcrun', ['altool', '--upload-app', '--file', artifact, '--type', 'ios', '--apiKey', env.APP_STORE_CONNECT_KEY_ID,
            '--apiIssuer', env.APP_STORE_CONNECT_ISSUER_ID], {...env, API_PRIVATE_KEYS_DIR: dirname(env.APP_STORE_CONNECT_API_KEY_PATH)});
          else node('tool/release/direct-play-upload.mjs', artifact, buildNumber);
          attempt.uploadStatus = 'uploaded'; attempt.storeReview = 'processing-or-review-unverified'; break;
        case 'deploy': {
          if (plan.environment === 'production') {
            env.RELEASE_VALIDATION_MODE = 'skipped'; env.FIREBASE_DEPLOY_SCOPE = plan.scope === 'functions' ? 'backend' : plan.scope;
            writeJson('build/release/validation/release.json', {schemaVersion: 1, kind: 'release-validation', sourceSha: plan.sourceSha,
              releaseTag: plan.tag, runId: id, runAttempt: '1', validationMode: 'skipped', reason: 'Direct CLI; integration CI was not run', actor});
            manifest = makeManifest(); writeJson('build/release/manifest.json', manifest);
          }
          target ||= plan.scope === 'web' ? 'hosting' : 'firestore:rules,firestore:indexes,database,storage';
          if (plan.scope === 'backend' && plan.environment === 'production') target += ',firestore:rules,firestore:indexes,database,storage';
          attempt.targets = target.split(',');
          // Explicit function selectors retain the reviewed retry policy without codebase-wide deletion.
          const runtimePath = `functions/.env.${plan.project}`;
          let createdRuntime = false;
          try {
            if (runtime) { writeFileSync(runtimePath, runtime.dotenv, {mode: 0o600, flag: 'wx'}); createdRuntime = true; }
            firebase('deploy', '--project', plan.project, '--config', plan.config, '--only', target, '--non-interactive', ...(runtime ? ['--force'] : []));
          } finally { if (createdRuntime) rmSync(runtimePath, {force: true}); }
          break;
        }
        case 'verify-rules': node('functions/tools/live-rules.mjs', 'build/release/manifest.json', '--wait'); break;
        case 'live-smoke': node('functions/tools/release-smoke.mjs'); break;
        case 'verify-receipt': {
          if (plan.scope === 'functions') { attempt.compatibility = 'unverified-partial-functions'; break; }
          if (plan.scope !== 'web') node('functions/tools/live-rules.mjs');
          const receipt = {format: 1, sha: plan.sourceSha, runId: id, attempt: '1', scope: plan.scope, status: 'success',
            completedAt: new Date().toISOString(), manifest, manifestHash: manifestHash(manifest),
            ...(plan.scope === 'web' ? {backend: backend.backendReference} : {rules: json('build/release/live-rules.json'), smoke: json('build/release/smoke.json')})};
          validateReceipt(receipt, {sha: plan.sourceSha, runId: id, attempt: '1'}); attempt.release = receipt; break;
        }
        default: throw new Error(`Unknown stage ${step}`);
      }
    });
    attempt.status = 'success'; attempt.completedAt = new Date().toISOString(); await save();
    console.log(`Direct ${plan.scope} completed; receipt ${directory}/attempt.json. Store review/public availability is not implied.`);
    return attempt;
  } catch (error) {
    attempt.status = 'failed'; attempt.completedAt = new Date().toISOString();
    try { await save(); } catch { console.error('Receipt update failed; remote pending state must be reconciled before another deployment.'); }
    throw error;
  }
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const options = parseArgs(process.argv.slice(2));
    const version = git('show', `${options.sourceSha}:pubspec.yaml`).match(/^version:\s*(\d+\.\d+\.\d+)\+\d+\s*$/m)?.[1];
    const plan = directPlan({...options, version});
    if (options.execute) await executePlan(plan);
    else console.log(JSON.stringify({...plan, operation: 'dry-run', note: 'No remote reads/writes, builds, reservations, signing or uploads performed'}, null, 2));
  } catch (error) { console.error(error.message.split('\n')[0]); process.exitCode = 1; }
}
