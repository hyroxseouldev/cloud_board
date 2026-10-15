import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {runInNewContext} from 'node:vm';
const load = name => readFileSync(new URL(`../../.github/workflows/${name}-main.yml`, import.meta.url), 'utf8');
const step = (source, name) => source.slice(source.indexOf(`      - name: ${name}`)).split('\n      - name:')[0];
const condition = block => block.match(/        if: (?:>-\n)?([\s\S]*?)\n        (?:uses|env|run):/)?.[1].trim();
const evaluate = (expression, {upload = true, mode = 'qa'} = {}) =>
  runInNewContext(`(${expression})`, {env: {RELEASE_MODE: mode, UPLOAD_REQUESTED: String(upload)}}, {timeout: 100});

for (const [workflow, option, uploader] of [['google-play', 'play', 'Upload mobile and TV bundle'], ['testflight', 'testflight', 'Upload to TestFlight']]) {
  test(`${workflow}: main existing-app QA and completed tag release are separate from build-only`, () => {
    const source = load(workflow);
    assert(!source.includes('backend_ready:'));
    assert(!source.includes('class_start_regressions:'));
    assert(!source.includes('flutter test'));
    assert(!source.includes('flutter analyze'));
    assert(source.includes('branches: [main]'));
    assert(source.includes('workflows: [Deploy Flutter Web to Firebase Hosting]'));
    assert(source.includes('types: [completed]'));
    assert(source.includes('source_ref:'));
    assert(source.includes('options: [qa, release]'));
    assert(source.includes('ref: ${{ env.SOURCE_SHA }}'));
    assert(source.includes('path: control'));
    assert(source.includes('path: app'));
    assert(source.includes('persist-credentials: false'));
    assert(!source.includes('preflight:'));
    assert(!source.includes('MOBILE_DEVELOPMENT_READY'));
    assert(!source.includes('com.sunmkim.cloudboard.dev'));
    assert(source.includes(`group: ${workflow}-main`));
    const common = condition(step(source, 'Reuse tag integration validation for release upload'));
    assert.equal(evaluate(common, {mode: 'qa'}), false);
    assert.equal(evaluate(common, {mode: 'release'}), true);
    assert.equal(evaluate(common, {mode: 'release', upload: false}), false);
    const earlyBackend = step(source, 'Check backend compatibility before native build');
    assert.equal(evaluate(condition(earlyBackend), {upload: false}), false);
    for (const mode of ['qa', 'release']) assert.equal(evaluate(condition(earlyBackend), {mode}), true);
    assert(earlyBackend.includes('--mode "$RELEASE_MODE" --source-sha "$SOURCE_SHA" --check-only'));
    const earlyPosition = source.indexOf('      - name: Check backend compatibility before native build');
    assert(source.indexOf('      - name: Checkout selected app commit') < earlyPosition);
    assert(earlyPosition < source.indexOf('      - name: Set up Flutter'));
    assert(earlyPosition < source.indexOf(workflow === 'google-play'
      ? '      - name: Derive marketing version and reserve' : '      - name: Set marketing version and next iOS build'));
    if (workflow === 'google-play') assert(earlyPosition < source.indexOf('      - name: Set up Java'));
    const backendStep = step(source, 'Recheck backend compatibility and build number before publishing');
    assert.equal(evaluate(condition(backendStep), {upload: false}), false);
    assert.equal(evaluate(condition(backendStep)), true);
    assert(!backendStep.includes('if [['));
    assert(backendStep.includes('--mode "$RELEASE_MODE" --source-sha "$SOURCE_SHA" --check-only'));
    const upload = condition(step(source, uploader));
    assert.equal(evaluate(upload, {upload: false}), false);
    assert.equal(evaluate(upload), true);
    assert(source.indexOf('Verify actual ') < source.indexOf(`      - name: ${uploader}`));
    assert(source.indexOf('Retain mobile source receipt') < source.indexOf(`      - name: ${uploader}`));
    assert(source.includes('--dart-define=FIREBASE_ENV="$APP_ENVIRONMENT"'));
    assert(source.includes('--flavor "$APP_ENVIRONMENT"'));
    assert(source.includes('--environment "$APP_ENVIRONMENT"'));
    assert.match(source, /(?:IOS_BUNDLE_ID|ANDROID_PACKAGE_NAME): com\.sunmkim\.cloudboard\n/);
    assert(source.includes('--build-name "$RELEASE_VERSION_NAME"'));
    assert(source.includes(`upload_to_${option}:`));
    assert.equal(evaluate(condition(step(source, 'QA build does not publish app update news')), {mode: 'qa'}), true);
    assert.equal(evaluate(condition(step(source, 'QA build does not publish app update news')), {mode: 'release'}), false);
  });
}
test('build-only iOS does not upload crash symbols; signature and version collision guards remain', () => {
  const source = load('testflight');
  assert.equal(evaluate(condition(step(source, 'Upload dSYMs to Firebase Crashlytics')), {upload: false}), false);
  assert(source.includes('control/tool/inspect_ios_signing.py'));
  assert(source.includes('control/tool/prepare_ios_entitlements.py'));
  assert(source.includes('control/tool/release/ios_build_number.mjs" --recheck'));
  assert(source.includes('$GITHUB_WORKSPACE/app/build/ios/archive/Runner.xcarchive'));
  const play = load('google-play');
  for (const name of ['ANDROID_UPLOAD_KEY_ALIAS', 'ANDROID_UPLOAD_KEY_PASSWORD', 'ANDROID_UPLOAD_KEYSTORE_PASSWORD']) {
    assert(play.includes(`secrets.${name}`));
  }
  assert(play.includes('track: internal'));
});
