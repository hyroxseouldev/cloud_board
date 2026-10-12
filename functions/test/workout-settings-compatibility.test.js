import test from 'node:test';
import assert from 'node:assert/strict';
import {legacyPreferencesChange} from '../src/workout-settings-compatibility.js';
import {normalizeSettings} from '../src/workout-settings-migration.js';

const preferences = normalizeSettings({brandL: 'Current'});
const canonical = {schemaVersion: 1, revision: 3, contentOnly: false, preferences};
test('legacy setting edit is applied but unrelated profile edits and mirrored writes are ignored', () => {
  const previous = {workoutSettings: preferences};
  const changed = {...preferences, brandL: 'Old installed app'};
  assert.deepEqual(legacyPreferencesChange(previous, {workoutSettings: changed}, canonical), changed);
  assert.equal(legacyPreferencesChange(previous, {...previous, displayName: 'Renamed'}, canonical), null);
  assert.equal(legacyPreferencesChange({}, previous, canonical), null);
  assert.equal(legacyPreferencesChange(previous, null, canonical), null);
});
test('countdown-only installed client changes preserve all unrelated canonical values', () => {
  const countdown = {...preferences.countdown, seconds: 12};
  assert.deepEqual(legacyPreferencesChange({}, {countdownDefaults: countdown}, canonical), {...preferences, countdown});
});
test('a valid legacy edit restores compatibility mode on accidentally finalized accounts', () => {
  assert.deepEqual(legacyPreferencesChange({}, {workoutSettings: preferences}, {...canonical, contentOnly: true}), preferences);
});
test('unknown canonical versions and absent settings are never rewritten', () => {
  assert.equal(legacyPreferencesChange({}, {workoutSettings: preferences}, null), null);
  assert.equal(legacyPreferencesChange({}, {workoutSettings: preferences}, {...canonical, schemaVersion: 2}), null);
});
