import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import test from 'node:test';
import {verifyRecoveryTests} from './tv-recovery-check.mjs';
const manifest = {format: 1, files: ['test/tv.dart'], requiredCases: ['test/tv.dart::wake retries']};
const events = () => [
  {type: 'suite', suite: {id: 1, path: '/checkout/test/tv.dart'}},
  {type: 'testStart', test: {id: 2, suiteID: 1, name: 'wake retries', metadata: {skip: false}}},
  {type: 'testDone', testID: 2, result: 'success', skipped: false, hidden: false},
  {type: 'done', success: true},
];
test('a complete recovery run passes with its exact required scenario', () => {
  assert.equal(verifyRecoveryTests(events(), manifest).passed, 1);
});
test('skip and a filtered-away scenario cannot produce a green release', () => {
  const skipped = events(); skipped[2].skipped = true;
  assert.throws(() => verifyRecoveryTests(skipped, manifest), /Skipped/);
  const renamed = events(); renamed[1].test.name = 'different test';
  assert.throws(() => verifyRecoveryTests(renamed, manifest), /Missing required case/);
});
test('missing, failed, incomplete and duplicate runs fail closed', () => {
  assert.throws(() => verifyRecoveryTests([{type: 'done', success: true}], manifest), /Missing recovery suite/);
  const failed = events(); failed[2].result = 'error';
  assert.throws(() => verifyRecoveryTests(failed, manifest), /Failed required test/);
  assert.throws(() => verifyRecoveryTests(events().slice(0, -1), manifest), /did not report completion/);
  const duplicate = events(); duplicate.splice(3, 0, duplicate[2]);
  assert.throws(() => verifyRecoveryTests(duplicate, manifest), /Duplicate/);
});
test('a failed CLI invocation removes a previous green report and replaces its machine output', () => {
  const fixture = realpathSync(mkdtempSync(join(tmpdir(), 'tv-recovery-gate-')));
  try {
    for (const dir of ['tool', 'test', 'build/sta176']) mkdirSync(join(fixture, dir), {recursive: true});
    const runner = join(fixture, 'tool/tv-recovery-check.mjs');
    copyFileSync(new URL('./tv-recovery-check.mjs', import.meta.url), runner);
    writeFileSync(join(fixture, 'tool/tv-recovery-tests.json'), JSON.stringify(manifest));
    writeFileSync(join(fixture, 'test/tv.dart'), '// Isolated fake Flutter input.\n');
    const report = join(fixture, 'build/sta176/flutter-results.json');
    const machine = join(fixture, 'build/sta176/flutter-machine.ndjson');
    writeFileSync(report, JSON.stringify({passed: 65, skipped: 0, previousRun: true}));
    writeFileSync(machine, 'previous-green-machine-output\n');
    const flutter = join(fixture, 'fake-flutter');
    const argsPath = join(fixture, 'flutter-args.json');
    writeFileSync(flutter, `#!/usr/bin/env node
require('node:fs').writeFileSync(process.env.RECOVERY_GATE_ARGS, JSON.stringify(process.argv.slice(2)));
process.stdout.write(JSON.stringify({type: 'done', success: false}) + '\\n');
process.exitCode = 17;
`, {mode: 0o755});
    const run = spawnSync(process.execPath, [runner], {cwd: fixture, encoding: 'utf8', timeout: 10_000,
      env: {...process.env, FLUTTER_BIN: flutter, RECOVERY_GATE_ARGS: argsPath}});
    assert.ifError(run.error);
    assert.equal(run.status, 1);
    assert.match(run.stderr, /Recovery tests exited 17/);
    assert.equal(existsSync(report), false, 'A failed run must not retain an earlier successful result');
    assert.deepEqual(JSON.parse(readFileSync(argsPath, 'utf8')), ['test', '--no-pub', '--machine', 'test/tv.dart']);
    assert.deepEqual(JSON.parse(readFileSync(machine, 'utf8')), {type: 'done', success: false});
  } finally { rmSync(fixture, {recursive: true, force: true}); }
});
