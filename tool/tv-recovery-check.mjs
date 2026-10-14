import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {existsSync, mkdirSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import {dirname, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const normalized = value => value.replaceAll('\\', '/');

export function verifyRecoveryTests(events, manifest) {
  assert.equal(manifest.format, 1);
  assert(manifest.files.length > 0, 'Recovery test manifest is empty');
  assert.equal(new Set(manifest.files).size, manifest.files.length);
  const suites = new Map(), tests = new Map(), completed = new Set();
  const counts = new Map(manifest.files.map(file => [file, 0]));
  const cases = new Set();
  let finished = false;
  for (const event of events) {
    if (event.type === 'suite') suites.set(event.suite.id, normalized(event.suite.path));
    if (event.type === 'testStart') tests.set(event.test.id, event.test);
    if (event.type === 'testDone') {
      const test = tests.get(event.testID);
      assert(test, 'Test completion has no matching start');
      if (event.hidden) continue;
      const path = suites.get(test.suiteID);
      const file = manifest.files.find(value => path === value || path?.endsWith(`/${value}`));
      assert(file, `Unregistered recovery suite: ${path}`);
      assert(!completed.has(test.id), 'Duplicate test completion');
      completed.add(test.id);
      assert(!event.skipped && !test.metadata?.skip, `Skipped required test: ${test.name}`);
      assert.equal(event.result, 'success', `Failed required test: ${test.name}`);
      counts.set(file, counts.get(file) + 1);
      cases.add(`${file}::${test.name}`);
    }
    if (event.type === 'done') {
      assert.equal(event.success, true, 'Recovery test process did not succeed');
      finished = true;
    }
  }
  assert(finished, 'Recovery tests did not report completion');
  for (const [file, count] of counts) assert(count > 0, `Missing recovery suite: ${file}`);
  for (const name of manifest.requiredCases) assert(cases.has(name), `Missing required case: ${name}`);
  return {passed: completed.size, skipped: 0, suites: Object.fromEntries(counts), cases: [...cases].sort()};
}

async function main() {
  const out = resolve(root, 'build/sta176');
  mkdirSync(out, {recursive: true});
  // A failed invocation must never leave a previous successful result behind.
  rmSync(resolve(out, 'flutter-results.json'), {force: true});
  rmSync(resolve(out, 'flutter-machine.ndjson'), {force: true});
  const manifest = JSON.parse(readFileSync(resolve(root, 'tool/tv-recovery-tests.json'), 'utf8'));
  for (const file of manifest.files) assert(existsSync(resolve(root, file)), `Missing test file: ${file}`);
  const localFlutter = resolve(root, '.fvm/flutter_sdk/bin/flutter');
  const flutter = process.env.FLUTTER_BIN || (existsSync(localFlutter) ? localFlutter : 'flutter');
  const events = [];
  let pending = '', raw = '';
  const child = spawn(flutter, ['test', '--no-pub', '--machine', ...manifest.files], {cwd: root, stdio: ['ignore', 'pipe', 'inherit'], timeout: 600_000});
  child.stdout.on('data', chunk => {
    const value = chunk.toString(); raw += value; pending += value;
    const lines = pending.split('\n'); pending = lines.pop();
    for (const line of lines) {
      try {
        const event = JSON.parse(line);
        events.push(event);
        if (event.type === 'error') process.stderr.write(`${event.error}\n`);
      } catch { /* Flutter may print non-JSON setup notices before its reporter. */ }
    }
  });
  const code = await new Promise((resolveExit, reject) => {
    child.once('error', reject);
    child.once('close', resolveExit);
  });
  writeFileSync(resolve(out, 'flutter-machine.ndjson'), raw);
  assert.equal(code, 0, `Recovery tests exited ${code}`);
  const report = verifyRecoveryTests(events, manifest);
  writeFileSync(resolve(out, 'flutter-results.json'), `${JSON.stringify(report, null, 2)}\n`);
  console.log(`TV recovery: ${report.passed} passed, 0 skipped; ${manifest.files.length} required suites verified.`);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  await main();
}
