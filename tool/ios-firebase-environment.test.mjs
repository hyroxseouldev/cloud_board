import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {mkdtempSync, readFileSync, existsSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));
function select(t, configuration, bundle) {
  const output = mkdtempSync(join(tmpdir(), 'cloudboard-ios-environment-'));
  t.after(() => rmSync(output, {recursive: true, force: true}));
  const result = spawnSync('/bin/sh', [join(root, 'tool/select_ios_firebase.sh')], {
    encoding: 'utf8', env: {...process.env, CONFIGURATION: configuration,
      SRCROOT: join(root, 'ios'), PRODUCT_BUNDLE_IDENTIFIER: bundle,
      TARGET_BUILD_DIR: output, UNLOCALIZED_RESOURCES_FOLDER_PATH: 'Runner.app'},
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
