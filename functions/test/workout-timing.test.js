import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {expandWorkoutTiming, validateWorkoutTiming, workoutTimingDuration} from '../src/workout-timing.js';
import {summarizeWorkout} from '../src/workout-catalog.js';

const fixtures = JSON.parse(readFileSync(new URL('../../test/fixtures/emom_timing.json', import.meta.url)));
for (const f of fixtures) {
  test(`shared Dart/JS fixture ${f.name}`, () => {
    assert.equal(validateWorkoutTiming(f.module), true);
    assert.deepEqual(expandWorkoutTiming(f.module), f.phases);
    assert.equal(workoutTimingDuration(f.module), f.duration);
    assert.equal(summarizeWorkout({id: 'w', updatedAt: 1, modules: [f.module]}).durationSeconds, f.duration);
  });
}
test('v2 rejects invalid values and unbounded expansion', () => {
  const base = {timingVersion: 2, workSeconds: 60, restSeconds: 0, sets: 1};
  for (const delta of [{workSeconds: 0}, {restSeconds: -1}, {roundRestSeconds: -1},
    {rounds: 0}, {rounds: 1000}, {sets: 0}, {sets: 1.5}, {sets: '3'},
    {timingVersion: 99}, {includeFinalRoundRest: 1}, {sets: 999, rounds: 999}]) {
    const m = {...base, ...delta};
    assert.equal(validateWorkoutTiming(m), false);
    assert.throws(() => expandWorkoutTiming(m), /invalid-workout-timing/);
  }
});

test('v3 AMRAP, For Time and interval presets validate and project honest totals', () => {
  const base = {timingVersion: 3, timerMode: 'forTime', timerDirection: 'up', workSeconds: 0,
    restSeconds: 0, sets: 1, rounds: 1, roundRestSeconds: 0, intervalBlocks: []};
  for (const [m, seconds, kind] of [
    [base, 0, 'open'],
    [{...base, workSeconds: 600}, 600, 'maximum'],
    [{...base, timerMode: 'amrap', workSeconds: 720}, 720, 'fixed'],
    [{...base, timerMode: 'tabata', timerDirection: 'down', workSeconds: 20, restSeconds: 10, sets: 8}, 240, 'fixed'],
    [{...base, timerMode: 'interval', timerDirection: 'down', workSeconds: 45, restSeconds: 15, sets: 10, includeFinalRest: false}, 585, 'fixed'],
  ]) {
    assert.equal(validateWorkoutTiming(m), true);
    assert.equal(workoutTimingDuration(m), seconds);
    assert.equal(expandWorkoutTiming(m).reduce((sum, p) => sum + p.seconds, 0), seconds);
    const summary = summarizeWorkout({id: 'w', updatedAt: 1, modules: [m]});
    assert.equal(summary.durationSeconds, seconds);
    assert.equal(summary.durationKind, kind);
  }
  for (const delta of [{timingVersion: 2}, {timerMode: 'unknown'}, {timerMode: 'amrap'},
    {timerDirection: 'down'}, {rounds: 2}, {sets: 2}, {roundRestSeconds: 30},
    {restSeconds: 30}, {workSeconds: -1}, {timerDirection: 'unknown'},
    {intervalBlocks: [{workSeconds: 20, restSeconds: 0, sets: 1}]}]) {
    assert.equal(validateWorkoutTiming({...base, ...delta}), false, JSON.stringify(delta));
  }
});
