import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {runInNewContext} from 'node:vm';
const load = name => readFileSync(new URL(`../../.github/workflows/${name}-main.yml`, import.meta.url), 'utf8');
const step = (source, name) => source.slice(source.indexOf(`      - name: ${name}`)).split('\n      - name:')[0];
const condition = block => block.match(/        if: (?:>-\n)?([\s\S]*?)\n        (?:uses|env|run):/)?.[1].trim();
const evaluate = (expression, {event = 'workflow_dispatch', upload = true, mode = 'qa', bootstrapped = true} = {}) =>
  runInNewContext(`(${expression})`, {github: {event_name: event},
    inputs: {release_mode: mode, upload_to_testflight: upload, upload_to_play: upload},
    vars: {GOOGLE_PLAY_BOOTSTRAPPED: String(bootstrapped)}}, {timeout: 100});

for (const [workflow, option, uploader] of [['google-play', 'play', 'Upload mobile and TV bundle'], ['testflight', 'testflight', 'Upload to TestFlight']]) {
  test(`${workflow}: QA and build-only do not wait for deployment or repeat whole-app validation`, () => {
    const source = load(workflow);
    assert(!source.includes('backend_ready:'));
    assert(!source.includes('class_start_regressions:'));
    assert(!source.includes('flutter test'));
    assert(!source.includes('flutter analyze'));
    assert(source.includes('source_ref:'));
    assert(source.includes('options: [qa, release]'));
    assert(source.includes('ref: ${{ env.SOURCE_SHA }}'));
    assert(source.includes('path: control'));
    assert(source.includes('path: app'));
    assert(source.includes('persist-credentials: false'));
    const common = condition(step(source, 'Reuse main integration validation for release upload'));
    assert.equal(evaluate(common, {mode: 'qa'}), false);
    assert.equal(evaluate(common, {mode: 'release'}), true);
    assert.equal(evaluate(common, {mode: 'release', upload: false}), false);
    const backend = condition(step(source, 'Recheck backend compatibility and build number before publishing'));
    assert.equal(evaluate(backend, {upload: false}), false);
    assert.equal(evaluate(backend, {upload: true}), true);
    assert(source.includes('--mode "$RELEASE_MODE" --source-sha "$SOURCE_SHA" --check-only'));
    const upload = condition(step(source, uploader));
    assert.equal(evaluate(upload, {upload: false}), false);
    assert.equal(evaluate(upload), true);
    assert.equal(evaluate(upload, {event: 'push'}), false);
    if (workflow === 'google-play') assert.equal(evaluate(upload, {bootstrapped: false}), false);
    assert(source.indexOf('Verify actual ') < source.indexOf(`      - name: ${uploader}`));
    assert(source.indexOf('Retain mobile source receipt') < source.indexOf(`      - name: ${uploader}`));
    assert(source.includes('--dart-define=FIREBASE_ENV=production'));
    assert(source.includes('--build-name "$RELEASE_VERSION_NAME"'));
    assert(source.includes(`upload_to_${option}:`));
    assert(!source.includes('release-policy.mjs'));
    assert.equal(evaluate(condition(step(source, 'QA build does not publish app update news')), {mode: 'qa'}), true);
    assert.equal(evaluate(condition(step(source, 'QA build does not publish app update news')), {mode: 'release'}), false);
  });
}
test('build-only iOS never uploads production crash symbols; signing and archive guards remain', () => {
  const source = load('testflight');
  const symbols = condition(step(source, 'Upload dSYMs to Firebase Crashlytics'));
  assert.equal(evaluate(symbols, {upload: false}), false);
  assert.equal(evaluate(symbols, {event: 'push'}), false);
  assert(source.includes('control/tool/inspect_ios_signing.py'));
  assert(source.includes('control/tool/prepare_ios_entitlements.py'));
  assert(source.includes('control/tool/release/ios_build_number.mjs" --recheck'));
  assert(source.includes('$GITHUB_WORKSPACE/app/build/ios/archive/Runner.xcarchive'));
});
