import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {mkdtempSync, readFileSync, existsSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));
function select(t, configuration, bundle, target = 'lib/main.dart') {
  const output = mkdtempSync(join(tmpdir(), 'cloudboard-ios-environment-'));
  t.after(() => rmSync(output, {recursive: true, force: true}));
  const result = spawnSync('/bin/sh', [join(root, 'tool/select_ios_firebase.sh')], {
    encoding: 'utf8', env: {...process.env, CONFIGURATION: configuration,
      SRCROOT: join(root, 'ios'), PRODUCT_BUNDLE_IDENTIFIER: bundle,
      TARGET_BUILD_DIR: output, UNLOCALIZED_RESOURCES_FOLDER_PATH: 'Runner.app',
      FLUTTER_TARGET: target},
  });
  return {...result, file: join(output, 'Runner.app/GoogleService-Info.plist')};
}
test('old unflavored Runner scheme cannot silently select production credentials', t => {
  for (const configuration of ['Debug', 'Profile', 'Release', 'Unknown-developmentish']) {
    const result = select(t, configuration, 'com.sunmkim.cloudboard');
    assert.equal(result.status, 1);
    assert.match(result.stderr, /Unflavored Runner builds are disabled/);
    assert.equal(existsSync(result.file), false);
  }
});
test('development and production copy only matching native Firebase configs', {skip: process.platform !== 'darwin'}, t => {
  for (const flavor of ['development', 'production']) {
    const bundle = `com.sunmkim.cloudboard${flavor === 'development' ? '.dev' : ''}`;
    for (const mode of ['Debug', 'Profile', 'Release']) {
      const result = select(t, `${mode}-${flavor}`, bundle);
      assert.equal(result.status, 0, result.stderr);
      const source = flavor === 'development'
        ? 'config/firebase/development/GoogleService-Info.plist' : 'ios/Runner/GoogleService-Info.plist';
      assert.equal(readFileSync(result.file, 'utf8'), readFileSync(join(root, source), 'utf8'));
    }
  }
});
test('mismatched native bundle aborts before copying either Firebase configuration', t => {
  const result = select(t, 'Debug-development', 'com.sunmkim.cloudboard');
  assert.equal(result.status, 1);
  assert.match(result.stderr, /does not match/);
  assert.equal(existsSync(result.file), false);
});
test('studio preview changes only the built development app to the demo project', {skip: process.platform !== 'darwin'}, t => {
  const paths = ['config/firebase/development/GoogleService-Info.plist', 'ios/Runner/GoogleService-Info.plist'];
  const originals = paths.map(path => readFileSync(join(root, path), 'utf8'));
  for (const target of ['lib/main_studio_preview.dart', join(root, 'lib/main_studio_preview.dart')]) {
    const result = select(t, 'Debug-development', 'com.sunmkim.cloudboard.dev', target);
    assert.equal(result.status, 0, result.stderr);
    const plist = readFileSync(result.file, 'utf8');
    assert.match(plist, /<key>PROJECT_ID<\/key>\s*<string>demo-cloudboard-studio<\/string>/);
    assert.match(plist, /<key>DATABASE_URL<\/key>\s*<string>https:\/\/demo-cloudboard-studio-default-rtdb\.asia-southeast1\.firebasedatabase\.app<\/string>/);
    assert.match(plist, /<key>BUNDLE_ID<\/key>\s*<string>com\.sunmkim\.cloudboard\.dev<\/string>/);
  }
  paths.forEach((path, index) => assert.equal(readFileSync(join(root, path), 'utf8'), originals[index]));
});
test('studio preview rejects production and non-debug development builds before copying', t => {
  for (const configuration of ['Debug-production', 'Release-production', 'Profile-development', 'Release-development']) {
    const bundle = configuration.endsWith('development') ? 'com.sunmkim.cloudboard.dev' : 'com.sunmkim.cloudboard';
    const result = select(t, configuration, bundle, 'lib/main_studio_preview.dart');
    assert.equal(result.status, 1);
    assert.match(result.stderr, /requires the development Debug scheme/);
    assert.equal(existsSync(result.file), false);
  }
});
