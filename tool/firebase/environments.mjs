import assert from 'node:assert/strict';
import {readFileSync, writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {pathToFileURL} from 'node:url';
import {developmentDeployTargets} from '../../functions/src/development-backend-config.js';
import {developmentDisplaySource, prepareDevelopmentDisplayPackage} from './prepare-development-display.mjs';

export const environments = Object.freeze({
  development: {project: 'cloud-board-development', number: '1339501332', bundle: 'com.sunmkim.cloudboard.dev',
    config: 'firebase.development.json', android: 'android/app/src/development/google-services.json',
    ios: 'config/firebase/development/GoogleService-Info.plist'},
  production: {project: 'cloud-board-stationd', number: '428540903054', bundle: 'com.sunmkim.cloudboard',
    config: 'firebase.json', android: 'android/app/google-services.json', ios: 'ios/Runner/GoogleService-Info.plist'},
});
const read = path => readFileSync(path, 'utf8');
const json = path => JSON.parse(read(path));
const plist = (text, key) => text.match(new RegExp(`<key>${key}</key>\\s*<string>([^<]+)</string>`))?.[1];
export function validateSdk(env, android, ios) {
  assert.equal(android.project_info.project_id, env.project, 'Android Firebase project mismatch');
  assert.equal(android.project_info.project_number, env.number, 'Android Firebase project number mismatch');
  assert(android.client.some(client => client.client_info.android_client_info.package_name === env.bundle), 'Android package mismatch');
  assert.equal(plist(ios, 'PROJECT_ID'), env.project, 'iOS Firebase project mismatch');
  assert.equal(plist(ios, 'GCM_SENDER_ID'), env.number, 'iOS Firebase project number mismatch');
  assert.equal(plist(ios, 'BUNDLE_ID'), env.bundle, 'iOS bundle mismatch');
  assert(plist(ios, 'CLIENT_ID'), 'iOS Google login client is missing');
  assert(plist(ios, 'REVERSED_CLIENT_ID'), 'iOS Google login callback is missing');
}
export function verifyEnvironments() {
  for (const env of Object.values(environments)) validateSdk(env, json(env.android), read(env.ios));
  const dev = json(environments.development.config), prod = json(environments.production.config);
  assert.equal(dev.hosting.site, environments.development.project);
  assert.equal(dev.database.instance, `${environments.development.project}-default-rtdb`);
  assert.deepEqual(dev.storage, [{bucket: `${environments.development.project}.firebasestorage.app`, rules: 'storage.rules'}]);
  assert.deepEqual(dev.functions.filter(entry => entry.codebase !== 'cloudboard-auth'), prod.functions,
    'Development uses the tested core server source');
  const displayFunctions = dev.functions.filter(entry => entry.codebase === 'cloudboard-auth');
  assert.equal(displayFunctions.length, 1, 'Development includes exactly one isolated display codebase');
  assert.equal(displayFunctions[0].source, developmentDisplaySource);
  assert(!JSON.stringify(dev).includes(environments.production.project));
  assert.equal(prod.storage[0].bucket, `${environments.production.project}.firebasestorage.app`);
  const nativeInfo = read('ios/Runner/Info-Development.plist');
  const devPlist = read(environments.development.ios);
  assert.equal(plist(nativeInfo, 'GIDClientID'), plist(devPlist, 'CLIENT_ID'));
  assert(nativeInfo.includes(plist(devPlist, 'REVERSED_CLIENT_ID')), 'Development callback scheme missing');
  assert.match(read('pubspec.yaml'), /default-flavor: development/);
  assert.match(read('lib/firebase_options_development.dart'), /projectId: ['"]cloud-board-development['"]/);
  assert(!read('lib/firebase_options_development.dart').includes(environments.production.project));
}
export function developmentDeployArgs(environment, scope) {
  assert.equal(environment, 'development', 'Production deploys must use the verified release workflow');
  const only = {rules: 'firestore:rules,firestore:indexes,database,storage', web: 'hosting', backend: developmentDeployTargets(environments.development.project)}[scope];
  assert(only, 'Development deploy scope must be rules, backend or web');
  return ['--yes', 'firebase-tools@15.29.0', 'deploy', '--project', environments.development.project,
    '--config', environments.development.config, '--only', only, '--non-interactive', ...(scope === 'backend' ? ['--force'] : [])];
}

const digest = content => createHash('sha256').update(content).digest('hex');
export function versionDevelopmentEntrypoint(index, bootstrap, bundle) {
  const mainJsSha256 = digest(bundle);
  assert(index.includes('src="flutter_bootstrap.js"'), 'Flutter bootstrap script missing');
  assert(bootstrap.includes('"mainJsPath":"main.dart.js"'), 'Flutter JavaScript entrypoint missing');
  return {
    mainJsSha256,
    index: index.replace('src="flutter_bootstrap.js"', `src="flutter_bootstrap.js?build=${mainJsSha256}"`),
    bootstrap: bootstrap.replace('"mainJsPath":"main.dart.js"', `"mainJsPath":"main.dart.js?build=${mainJsSha256}"`),
  };
}
export function validateDevelopmentWeb(stamp, bundle) {
  assert.equal(stamp.environment, 'development', 'Web build is not development');
  assert.equal(stamp.project, environments.development.project, 'Wrong web Firebase project');
  assert.equal(stamp.mainJsSha256, digest(bundle), 'Web build changed; rebuild development before deployment');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  verifyEnvironments();
  if (process.argv[2] === 'build') {
    assert.equal(process.argv[3], 'development', 'Use production release workflow for production builds');
    assert.equal(process.argv.length, 4, 'Unexpected build arguments');
    const result = spawnSync(process.env.FLUTTER_BIN || 'flutter', ['build', 'web', '--release', '--dart-define=FIREBASE_ENV=development'], {stdio: 'inherit'});
    if (result.error) throw result.error;
    if (result.status !== 0) process.exitCode = result.status ?? 1;
    else {
      const versioned = versionDevelopmentEntrypoint(read('build/web/index.html'),
        read('build/web/flutter_bootstrap.js'), readFileSync('build/web/main.dart.js'));
      writeFileSync('build/web/index.html', versioned.index);
      writeFileSync('build/web/flutter_bootstrap.js', versioned.bootstrap);
      writeFileSync('build/web/firebase-environment.json', JSON.stringify({environment: 'development',
        project: environments.development.project, mainJsSha256: versioned.mainJsSha256}));
    }
  } else if (process.argv[2] === 'deploy') {
    assert.equal(process.argv.length, 5, 'Unexpected deploy arguments');
    const args = developmentDeployArgs(process.argv[3], process.argv[4]);
    if (process.argv[4] === 'backend') {
      const build = spawnSync('npm', ['run', 'build', '--prefix', 'functions-legacy'], {stdio: 'inherit'});
      if (build.error) throw build.error;
      assert.equal(build.status, 0, 'The existing display callable must compile before deployment');
      await prepareDevelopmentDisplayPackage(environments.development.project);
    }
    if (process.argv[4] === 'web') validateDevelopmentWeb(json('build/web/firebase-environment.json'), readFileSync('build/web/main.dart.js'));
    const result = spawnSync('npx', args, {stdio: 'inherit'});
    if (result.error) throw result.error;
    process.exitCode = result.status ?? 1;
  } else {
    assert.equal(process.argv[2], 'check');
    console.log('Development and production SDK/project identities verified.');
  }
}
