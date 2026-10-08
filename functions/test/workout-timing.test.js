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
