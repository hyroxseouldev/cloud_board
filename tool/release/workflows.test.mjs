import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const load = name => readFileSync(new URL(`../../.github/workflows/${name}-main.yml`, import.meta.url), 'utf8');
const job = (source, name) => source.split(`\n  ${name}:\n`)[1]?.split(/\n  \w+:\n/)[0];
const jobIf = block => block.match(/    if: >-\n((?:      .*\n)+)/)?.[1].trim();
function evaluate(expression, {manual, upload, backend, verify = 'success', regressions = 'success', bootstrapped = true} = {}) {
  let code = expression.replace(/github\.event_name/g, JSON.stringify(manual ? 'workflow_dispatch' : 'push'))
    .replace(/inputs\.upload_to_(?:play|testflight)/g, String(upload))
    .replace(/needs\.backend_ready\.result/g, JSON.stringify(backend))
    .replace(/needs\.verify\.result/g, JSON.stringify(verify))
    .replace(/needs\.class_start_regressions\.result/g, JSON.stringify(regressions))
    .replace(/vars\.GOOGLE_PLAY_BOOTSTRAPPED/g, JSON.stringify(String(bootstrapped)))
    .replace(/github\.event\.head_commit\.message/g, "''");
  return Function('contains', 'always', 'cancelled', `return (${code})`)((text, match) => text.includes(match), () => true, () => false);
}
for (const [workflow, option, uploader] of [['google-play', 'play', 'Upload mobile and TV bundle'], ['testflight', 'testflight', 'Upload to TestFlight']]) {
  test(`${workflow}: signed preparation skips only backend/upload, actual publishing remains gated`, () => {
    const source = load(workflow);
    const backend = jobIf(job(source, 'backend_ready'));
    const build = jobIf(job(source, 'upload'));
    assert.equal(evaluate(backend, {manual: true, upload: false}), false);
    assert.equal(evaluate(backend, {manual: true, upload: true}), true);
    assert.equal(evaluate(build, {manual: true, upload: false, backend: 'skipped'}), true);
    assert.equal(evaluate(build, {manual: true, upload: true, backend: 'failure'}), false);
    assert.equal(evaluate(build, {manual: false, upload: false, backend: 'failure'}), false);
    assert.equal(evaluate(build, {manual: false, upload: false, backend: 'success'}), true);
    for (const regressions of ['failure', 'skipped', 'cancelled', null]) {
      assert.equal(evaluate(build, {manual: true, upload: false, backend: 'skipped', regressions}), false);
      assert.equal(evaluate(build, {manual: true, upload: true, backend: 'success', regressions}), false);
    }
    if (workflow === 'testflight') assert.equal(evaluate(build, {manual: true, upload: false, backend: 'skipped', verify: 'failure'}), false);
    const step = source.slice(source.indexOf(`      - name: ${uploader}`)).split('\n      - name:')[0];
    const condition = step.match(/        if: (?:>-\n)?([\s\S]*?)\n        (?:uses|env):/)[1].trim();
    assert.equal(evaluate(condition, {manual: true, upload: false}), false);
    assert.equal(evaluate(condition, {manual: true, upload: true}), true);
    assert(source.indexOf('Verify actual ') < source.indexOf(`      - name: ${uploader}`));
    assert(source.includes('--dart-define=FIREBASE_ENV=production'));
    assert(source.includes('--build-name "$RELEASE_VERSION_NAME"'));
    assert(source.includes('refs/heads/main|refs/heads/release/*'));
    assert(source.includes(`upload_to_${option}:`));
    assert(source.includes('default: false'));
  });
}
test('build-only iOS never uploads production crash symbols', () => {
  const source = load('testflight');
  const step = source.slice(source.indexOf('      - name: Upload dSYMs to Firebase Crashlytics')).split('\n      - name:')[0];
  assert.equal(evaluate(step.match(/        if: (.*)/)[1], {manual: true, upload: false}), false);
});
