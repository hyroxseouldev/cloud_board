import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {dirname, join} from 'node:path';
import {requiredSuites, validateTestEvents} from './class_start_regressions.mjs';
import {requireReleaseJobs} from './firebase/release.mjs';
const fixture = () => [...requiredSuites.flatMap((path, id) => [
  {type: 'suite', suite: {id, path: `/repo/${path}`}},
  {type: 'testStart', test: {id, suiteID: id}},
  {type: 'testDone', testID: id, result: 'success', skipped: false, hidden: false},
]), {type: 'done', success: true}];
test('accepts only completed required suites with real executed cases', () => {
  assert.equal(validateTestEvents(fixture()).tests, requiredSuites.length);
});
for (const kind of ['failed', 'skipped', 'missing-suite', 'zero-tests', 'missing-done', 'error']) {
  test(`blocks ${kind} regression evidence`, () => {
    let events = fixture();
    if (kind === 'failed') events[2].result = 'error';
    if (kind === 'skipped') events[2].skipped = true;
    if (kind === 'missing-suite') events = events.filter(e => e.type !== 'suite');
    if (kind === 'zero-tests') events = events.filter(e => e.type !== 'testDone');
    if (kind === 'missing-done') events.pop();
    if (kind === 'error') events.push({type: 'error'});
    assert.throws(() => validateTestEvents(events));
  });
}
function cliFixture(t, platform = 'vm') {
  const root = realpathSync(mkdtempSync(join(tmpdir(), 'class-start-gate-')));
  t.after(() => rmSync(root, {recursive: true, force: true}));
  const runner = join(root, 'class_start_regressions.mjs');
  copyFileSync(new URL('./class_start_regressions.mjs', import.meta.url), runner);
  for (const suite of requiredSuites) {
    mkdirSync(dirname(join(root, suite)), {recursive: true});
    writeFileSync(join(root, suite), '// Isolated fake Flutter input.\n');
  }
  mkdirSync(join(root, 'build/class-start'), {recursive: true});
  const report = join(root, `build/class-start/${platform}.json`);
  const machine = join(root, `build/class-start/${platform}.jsonl`);
  const flutter = join(root, 'fake-flutter');
  const argsPath = join(root, 'flutter-args.json');
  writeFileSync(report, JSON.stringify({previousRun: true, tests: 100}));
  writeFileSync(machine, 'previous-green-machine-output\n');
  return {root, report, machine, flutter, argsPath, run: () => {
    const result = spawnSync(process.execPath, [runner, platform], {cwd: root, encoding: 'utf8', timeout: 10_000,
      env: {...process.env, FLUTTER_BIN: flutter, CLASS_START_GATE_ARGS: argsPath}});
    assert.ifError(result.error);
    assert.equal(result.status, 1);
    assert.equal(existsSync(report), false, 'A failed run must not retain an earlier successful result');
    return result;
  }};
}
for (const platform of ['vm', 'chrome']) {
  test(`failed ${platform} CLI clears old success and preserves new machine evidence`, t => {
    const f = cliFixture(t, platform);
    const output = `${JSON.stringify({type: 'done', success: false})}\n`;
    writeFileSync(f.flutter, `#!/usr/bin/env node
require('node:fs').writeFileSync(process.env.CLASS_START_GATE_ARGS, JSON.stringify(process.argv.slice(2)));
process.stdout.write(${JSON.stringify(output)});
process.exitCode = 17;
`, {mode: 0o755});
    assert.match(f.run().stderr, new RegExp(`Flutter ${platform} failed`));
    assert.equal(readFileSync(f.machine, 'utf8'), output);
    assert.deepEqual(JSON.parse(readFileSync(f.argsPath, 'utf8')),
      ['test', '--machine', ...(platform === 'chrome' ? ['--platform', 'chrome'] : []), ...requiredSuites]);
  });
}
test('invalid machine evidence from a successful CLI cannot retain a previous green report', t => {
  const f = cliFixture(t);
  const events = fixture();
  events[2].skipped = true;
  const output = `${events.map(event => JSON.stringify(event)).join('\n')}\n`;
  writeFileSync(f.flutter, `#!/usr/bin/env node\nprocess.stdout.write(${JSON.stringify(output)});\n`, {mode: 0o755});
  assert.match(f.run().stderr, /Skipped class-start regression/);
  assert.equal(readFileSync(f.machine, 'utf8'), output);
});
test('a missing required suite clears previous CLI evidence before Flutter starts', t => {
  const f = cliFixture(t);
  rmSync(join(f.root, requiredSuites[0]));
  assert.match(f.run().stderr, /Missing required suite/);
  assert.equal(existsSync(f.machine), false);
});
test('a Flutter launch failure clears the old report and saves only new machine output', t => {
  const f = cliFixture(t);
  assert.match(f.run().stderr, /ENOENT/);
  assert.equal(readFileSync(f.machine, 'utf8'), '');
});
test('shared web release and development validation retain the class-start job', () => {
  for (const name of ['firebase-hosting-merge', 'firebase-development']) {
    const workflow = readFileSync(`.github/workflows/${name}.yml`, 'utf8');
    assert.match(workflow, /uses: \.\/\.github\/workflows\/class-start-regressions.yml/);
    assert.match(workflow, /needs: \[[^\n]*class_start_regressions/);
  }
  const required = readFileSync('.github/workflows/firebase-hosting-merge.yml', 'utf8');
  assert.match(required, /requireReleaseJobs\(JSON.parse\(process.env.REQUIRED_JOBS\)\)/);
});
test('workflow and manifest aggregation accept the same four jobs and reject unverified class starts', () => {
  const jobs = Object.fromEntries(['app_validation', 'firebase_contracts', 'deployment_plan', 'class_start_regressions'].map(name => [name, {result: 'success'}]));
  requireReleaseJobs(jobs);
  for (const result of ['failure', 'skipped', 'cancelled', undefined]) {
    assert.throws(() => requireReleaseJobs({...jobs, class_start_regressions: {result}}));
  }
  const {class_start_regressions: omitted, ...missing} = jobs;
  assert.throws(() => requireReleaseJobs(missing));
  const release = readFileSync('tool/firebase/release.mjs', 'utf8');
  assert.match(release, /if \(command === 'aggregate'\) \{\s+requireReleaseJobs\(/);
});

test('production deploy uses automated evidence without a physical QA approval or waiver', () => {
  const workflow = readFileSync('.github/workflows/firebase-hosting-merge.yml', 'utf8');
  assert.doesNotMatch(workflow, /CLASS_START_PHYSICAL_|class_start_physical_gate|physical-qa-decision/);
  for (const command of ['node tool/firebase/release.mjs current', 'node tool/firebase/release.mjs verify',
    'node functions/tools/release-smoke.mjs preflight']) {
    assert(workflow.includes(command), `Missing automated release check: ${command}`);
    assert(workflow.indexOf(command) < workflow.indexOf('name: Authenticate Firebase rule deployment'));
  }
  for (const name of ['google-play-main', 'testflight-main']) {
    const native = readFileSync(`.github/workflows/${name}.yml`, 'utf8');
    assert.doesNotMatch(native, /needs: \[[^\n]*backend_ready/);
    assert.match(native, /release_backend_gate\.mjs/);
    assert.match(native, /--check-only/);
    assert.match(native, /common_validation\.mjs/);
  }
});
