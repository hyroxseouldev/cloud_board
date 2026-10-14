import assert from 'node:assert/strict';
import {mkdirSync, writeFileSync, existsSync} from 'node:fs';
import {spawn} from 'node:child_process';
import {pathToFileURL} from 'node:url';

export const requiredSuites = [
  'test/playback_start_lifecycle_test.dart',
  'test/playback_start_commit_test.dart',
  'test/playback_metadata_test.dart',
  'test/schedule_runner_initialization_test.dart',
  'test/display_preparation_test.dart',
  'test/device_pairing_recovery_test.dart',
  'test/display_preparation_recovery_test.dart',
  'test/display_mode_flow_test.dart',
  'test/workout_preflight_dialog_test.dart',
  'test/playback_ack_test.dart',
  'test/playback_recovery_test.dart',
  'test/playback_recovery_view_test.dart',
  'test/playback_split_protocol_test.dart',
  'test/playback_partial_disconnect_test.dart',
];

// A green command with no tests, ignored failures or skipped cases is not proof.
export function validateTestEvents(events, suites = requiredSuites) {
  const observed = new Map(), tests = new Map(), finished = new Set();
  let done = false;
  for (const event of events) {
    if (event.type === 'suite') observed.set(event.suite.id, event.suite.path.replaceAll('\\', '/'));
    if (event.type === 'testStart') tests.set(event.test.id, event.test);
    if (event.type === 'error') throw new Error('Regression runner reported an error');
    if (event.type === 'testDone') {
      assert.equal(event.skipped, false, 'Skipped class-start regression');
      assert.equal(event.result, 'success', 'Failed class-start regression');
      if (!event.hidden) finished.add(event.testID);
    }
    if (event.type === 'done') { assert.equal(event.success, true); done = true; }
  }
  assert(done, 'Missing successful runner completion');
  for (const suite of suites) {
    const ids = [...observed].filter(([, path]) => path.endsWith(suite)).map(([id]) => id);
    assert(ids.length > 0, `Missing suite: ${suite}`);
    assert([...finished].some(id => ids.includes(tests.get(id)?.suiteID)), `No executed tests: ${suite}`);
  }
  return {suites, tests: finished.size};
}

async function run(platform) {
  for (const suite of requiredSuites) assert(existsSync(suite), `Missing required suite ${suite}`);
  const args = ['test', '--machine', ...(platform === 'chrome' ? ['--platform', 'chrome'] : []), ...requiredSuites];
  const child = spawn(process.env.FLUTTER_BIN || 'flutter', args, {stdio: ['ignore', 'pipe', 'inherit']});
  let output = '';
  child.stdout.on('data', data => { output += data; });
  const code = await new Promise((resolve, reject) => { child.on('error', reject); child.on('exit', resolve); });
  mkdirSync('build/class-start', {recursive: true});
  writeFileSync(`build/class-start/${platform}.jsonl`, output);
  assert.equal(code, 0, `Flutter ${platform} failed; see build/class-start/${platform}.jsonl`);
  const events = output.split('\n').filter(line => line.trim().startsWith('{')).map(line => JSON.parse(line));
  const result = validateTestEvents(events);
  writeFileSync(`build/class-start/${platform}.json`, JSON.stringify({sha: process.env.GITHUB_SHA || 'local', platform, ...result}, null, 2));
  console.log(`${platform}: ${result.tests} required regressions passed without skips`);
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const platform = process.argv[2];
  assert(['vm', 'chrome'].includes(platform), 'Choose vm or chrome');
  await run(platform);
}
