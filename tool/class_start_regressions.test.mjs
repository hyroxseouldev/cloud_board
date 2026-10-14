import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {requiredSuites, validateTestEvents} from './class_start_regressions.mjs';
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
test('all release and development deploys require the class-start job', () => {
  for (const name of ['firebase-hosting-merge', 'firebase-development', 'google-play-main', 'testflight-main']) {
    const workflow = readFileSync(`.github/workflows/${name}.yml`, 'utf8');
    assert.match(workflow, /uses: \.\/\.github\/workflows\/class-start-regressions.yml/);
    assert.match(workflow, /needs: \[[^\n]*class_start_regressions/);
  }
  const required = readFileSync('.github/workflows/firebase-hosting-merge.yml', 'utf8');
  assert.match(required, /requireSuccess[^\n]*'class_start_regressions'/);
});
