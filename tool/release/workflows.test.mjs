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
  test(`${workflow}: an unselected mobile target cannot resolve app source or authorize the upload job`, () => {
    const source = load(workflow);
    const selection = step(source, 'Check selected mobile release target');
    assert(selection.includes('id: followup'));
    assert(selection.includes('node tool/release/mobile_followup.mjs'));
    assert(source.indexOf(selection) < source.indexOf('      - name: Resolve and pin trusted app source'));
    for (const name of ['Resolve and pin trusted app source', 'Report blocked development store setup']) {
      const expression = step(source, name).match(/        if: ([^\n]+)/)?.[1];
      assert(expression, `Missing selection condition on ${name}`);
      for (const requested of ['true', 'false', undefined]) {
        assert.equal(runInNewContext(`(${expression})`, {steps: {followup: {outputs: {requested}}}}, {timeout: 100}),
          requested === 'true');
      }
    }
    assert(source.includes('ready: ${{ steps.readiness.outputs.ready }}'));
    assert(source.includes("if: needs.preflight.outputs.ready == 'true'"));
  });
  test(`${workflow}: development-tag QA and completed release-tag runs are separate from build-only`, () => {
    const source = load(workflow);
    assert(!source.includes('backend_ready:'));
    assert(!source.includes('class_start_regressions:'));
    assert(!source.includes('flutter test'));
    assert(!source.includes('flutter analyze'));
    const pushTrigger = source.split('  push:\n')[1].split('  workflow_run:')[0];
    assert(pushTrigger.includes("tags: ['dev/v*']"));
    assert(!pushTrigger.includes('branches:'));
    assert(!pushTrigger.includes('paths:'));
    assert(!source.includes('default: main'));
    assert(source.includes('workflows: [Deploy Flutter Web to Firebase Hosting]'));
    assert(source.includes('types: [completed]'));
    assert(source.includes('source_ref:'));
    assert(source.includes('options: [qa, release]'));
    assert(source.includes('ref: ${{ env.SOURCE_SHA }}'));
    assert(source.includes('path: control'));
    assert(source.includes('path: app'));
    assert(source.includes('persist-credentials: false'));
    assert(source.includes('preflight:'));
    assert(source.includes("ref: ${{ github.event_name == 'push' && 'main' || github.sha }}"));
    assert(source.includes('ref: ${{ needs.preflight.outputs.control_sha }}'));
    assert(source.includes('PINNED_SOURCE_SHA: ${{ needs.preflight.outputs.source_sha }}'));
    assert(source.indexOf('      - name: Resolve and pin trusted app source') < source.indexOf('      - name: Report blocked development store setup'));
    assert(source.includes("if: needs.preflight.outputs.ready == 'true'"));
    assert(source.includes('MOBILE_DEVELOPMENT_READY'));
    assert(source.includes('com.sunmkim.cloudboard.dev'));
    assert(source.includes(`'${workflow}-main' || '${workflow}-development'`));
    const common = condition(step(source, 'Reuse tag integration validation for release upload'));
    assert.equal(evaluate(common, {mode: 'qa'}), false);
    assert.equal(evaluate(common, {mode: 'release'}), true);
    assert.equal(evaluate(common, {mode: 'release', upload: false}), false);
    const earlyBackend = step(source, 'Check backend compatibility before native build');
    assert.equal(evaluate(condition(earlyBackend), {upload: false}), false);
    assert.equal(evaluate(condition(earlyBackend), {mode: 'qa'}), false);
    assert.equal(evaluate(condition(earlyBackend), {mode: 'release'}), true);
    assert(earlyBackend.includes('--mode "$RELEASE_MODE" --source-sha "$SOURCE_SHA" --check-only --mobile'));
    const earlyPosition = source.indexOf('      - name: Check backend compatibility before native build');
    assert(source.indexOf('      - name: Checkout selected app commit') < earlyPosition);
    assert(earlyPosition < source.indexOf('      - name: Set up Flutter'));
    assert(earlyPosition < source.indexOf(workflow === 'google-play'
      ? '      - name: Derive marketing version and reserve' : '      - name: Set marketing version and next iOS build'));
    if (workflow === 'google-play') assert(earlyPosition < source.indexOf('      - name: Set up Java'));
    const backendStep = step(source, 'Recheck backend compatibility and build number before publishing');
    assert.equal(evaluate(condition(backendStep), {upload: false}), false);
    assert.equal(evaluate(condition(backendStep)), true);
    assert(backendStep.includes('if [[ "$RELEASE_MODE" == release ]]'));
    assert(backendStep.includes('--mode release --source-sha "$SOURCE_SHA" --check-only --mobile'));
    const backendAudit = step(source, 'Retain checked production backend');
    assert.equal(evaluate(condition(backendAudit), {mode: 'release'}), true);
    assert.equal(evaluate(condition(backendAudit), {mode: 'qa'}), false);
    assert.equal(evaluate(condition(backendAudit), {mode: 'release', upload: false}), false);
    assert(backendAudit.includes('mobile-backend-reference.json'));
    assert(source.indexOf(backendStep) < source.indexOf(backendAudit));
    assert(source.indexOf(backendAudit) < source.indexOf(`      - name: ${uploader}`));
    const upload = condition(step(source, uploader));
    assert.equal(evaluate(upload, {upload: false}), false);
    assert.equal(evaluate(upload), true);
    assert(source.indexOf('Verify actual ') < source.indexOf(`      - name: ${uploader}`));
    assert(source.indexOf('Retain mobile source receipt') < source.indexOf(`      - name: ${uploader}`));
    const sourceRecheck = step(source, 'Recheck deployment tag before upload');
    assert.equal(evaluate(condition(sourceRecheck), {upload: false}), false);
    assert.equal(evaluate(condition(sourceRecheck)), true);
    assert(sourceRecheck.includes('control/tool/release/source.mjs" recheck'));
    assert(source.indexOf('      - name: Recheck deployment tag before upload') < source.indexOf(`      - name: ${uploader}`));
    assert(source.includes('--dart-define=FIREBASE_ENV="$APP_ENVIRONMENT"'));
    assert(source.includes('--flavor "$APP_ENVIRONMENT"'));
    assert(source.includes('--environment "$APP_ENVIRONMENT"'));
    assert.match(source, /(?:IOS_BUNDLE_ID|ANDROID_PACKAGE_NAME): .*'com\.sunmkim\.cloudboard' \|\| 'com\.sunmkim\.cloudboard\.dev'/);
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

test('manual release skip is explicit, audited before receipt, and retains upload safety gates', () => {
  for (const workflow of ['testflight', 'google-play']) {
    const source = load(workflow);
    assert.match(source, /skip_ci:\n[\s\S]*?type: boolean\n\s+default: false/);
    assert(source.includes('skip_ci_reason:'));
    assert(source.includes('SKIP_CI: ${{ inputs.skip_ci || false }}'));
    assert(source.includes("CI_SKIP_REASON: ${{ inputs.skip_ci_reason || '' }}"));
    assert(source.includes('if [[ "$SKIP_CI" == true && "$RELEASE_MODE" != release ]]'));
    const common = step(source, 'Reuse tag integration validation for release upload');
    assert(common.includes('--release-tag "$RELEASE_TAG"'));
    assert(source.indexOf('      - name: Reuse tag integration validation for release upload') <
      source.indexOf('      - name: Record app source and signed artifact identity'));
    assert(!condition(common).includes('SKIP_CI'));
    assert(!condition(step(source, 'Check backend compatibility before native build')).includes('SKIP_CI'));
    assert(!condition(step(source, 'Recheck backend compatibility and build number before publishing')).includes('SKIP_CI'));
  }
});
