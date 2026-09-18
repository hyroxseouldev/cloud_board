import test from 'node:test';
import assert from 'node:assert/strict';
import {legacySettings, planSettings, normalizeSettings} from '../src/workout-settings-migration.js';

test('mixed legacy settings require explicit selection; countdown defaults cannot override them', () => {
  assert.equal(planSettings({countdownDefaults: {seconds: 30}}, [{countdownSeconds: 3}, {countdownSeconds: 5}]).status, 'needs-selection');
});
test('uniform legacy values retain the old sound defaults', () => {
  const plan = planSettings({}, [{}, {}]);
  assert.equal(plan.status, 'uniform-legacy');
  assert.equal(plan.preferences.workStartSound, 'sharpBeep');
  assert.equal(plan.preferences.countdownSound, 'classicBeep');
});
test('explicit common settings win over different legacy settings', () => {
  const plan = planSettings({workoutSettings: {brandL: 'New'}}, [{brandL: 'A'}, {brandL: 'B'}]);
  assert.equal(plan.preferences.brandL, 'New');
  assert.equal(plan.status, 'common');
});
test('canonical settings are idempotent and win over compatibility mirror', () => {
  const preferences = normalizeSettings({brandL: 'Canonical'});
  const plan = planSettings({workoutSettings: {brandL: 'Stale'}}, [{}], {schemaVersion: 1, revision: 2, preferences});
  assert.equal(plan.status, 'already-canonical');
  assert.deepEqual(plan.preferences, preferences);
});
test('empty accounts inherit only their old countdown defaults', () => {
  const plan = planSettings({countdownDefaults: {seconds: 11}}, []);
  assert.equal(plan.preferences.countdown.seconds, 11);
  assert.equal(plan.preferences.workStartSound, 'videoBeep');
});
test('corrupted/unknown values block automatic migration', () => {
  assert.throws(() => legacySettings({soundVolume: 'bad'}));
  assert.throws(() => legacySettings({countdownSound: 'unknown'}));
  assert.throws(() => legacySettings({schemaVersion: 2}));
});
