import test from 'node:test';
import assert from 'node:assert/strict';
import {Timestamp} from 'firebase-admin/firestore';
import {summarizeWorkout, syncWorkoutSummary} from '../src/workout-catalog.js';
import {repairWorkoutThumbnail} from '../src/workout-thumbnail-repair.js';

const url = 'https://example.invalid/first-slide.jpg';
const workout = (modules = [{imageUrl: url}]) => ({id: 'w', name: 'Workout', folder: '',
  updatedAt: Timestamp.fromMillis(1000), modules: modules.map(m => ({workSeconds: 30, sets: 2, restSeconds: 10, ...m}))});
function database(source = workout(), summary = {...summarizeWorkout(source), imageSource: ''}, locked = false) {
  const values = new Map([['users/u/workouts/w', source], ['users/u/workoutSummaries/w', summary]]);
  if (locked) values.set('accountDeletions/u', {status: 'pending'});
  const writes = [];
  return {values, writes, doc: path => path, runTransaction: async callback => callback({
    get: async path => ({exists: values.has(path), data: () => values.get(path)}),
    set: (path, value) => { writes.push(path); values.set(path, value); },
    update: (path, value) => { writes.push(path); values.set(path, {...values.get(path), ...value}); },
    delete: path => { writes.push(path); values.delete(path); },
  })};
}

test('stored imageUrl survives projection and server sync of an app-written summary', async () => {
  const source = workout();
  const summary = {...summarizeWorkout(source), imageSource: url};
  assert.equal(summarizeWorkout(source).imageSource, url);
  const db = database(source, summary);
  assert.equal(await syncWorkoutSummary(db, 'u', 'w'), false);
  assert.deepEqual(db.writes, []);
  assert.equal(summary.durationSeconds, 70);
});

test('legacy alias is supported, but an explicitly removed first image stays empty', () => {
  assert.equal(summarizeWorkout(workout([{imageSource: url}])).imageSource, url);
  assert.equal(summarizeWorkout(workout([{imageUrl: '', imageSource: url}])).imageSource, '');
  assert.equal(summarizeWorkout(workout([{}, {imageUrl: url}])).imageSource, '');
  assert.equal(summarizeWorkout(workout([])).imageSource, '');
});

test('server sync repairs old blank projections without changing the original', async () => {
  const source = workout();
  const db = database(source);
  assert.equal(await syncWorkoutSummary(db, 'u', 'w'), true);
  assert.equal(db.values.get('users/u/workoutSummaries/w').imageSource, url);
  assert.equal(db.values.get('users/u/workouts/w'), source);
  assert.equal(await syncWorkoutSummary(db, 'u', 'w'), false);
});

test('targeted repair defaults to read-only, backs up first and changes only thumbnail', async () => {
  const db = database();
  const before = {...db.values.get('users/u/workoutSummaries/w'), customField: 'preserved'};
  db.values.set('users/u/workoutSummaries/w', before);
  assert.equal(await repairWorkoutThumbnail(db, 'u', 'w'), 'candidate');
  assert.deepEqual(db.writes, []);
  const backup = async value => {
    assert.deepEqual(db.writes, []);
    assert.deepEqual(value.summary, before);
    assert.equal(value.expected, url);
  };
  assert.equal(await repairWorkoutThumbnail(db, 'u', 'w', {apply: true, backup}), 'repaired');
  assert.deepEqual(db.values.get('users/u/workoutSummaries/w'), {...before, imageSource: url});
  assert.equal(await repairWorkoutThumbnail(db, 'u', 'w', {apply: true, backup}), 'unchanged');
});

test('failed backup prevents mutation and deleting or missing data is skipped', async () => {
  const db = database();
  await assert.rejects(repairWorkoutThumbnail(db, 'u', 'w', {apply: true}), /backup/);
  await assert.rejects(repairWorkoutThumbnail(db, 'u', 'w', {apply: true, backup: async () => {throw Error('disk full');}}), /disk full/);
  assert.deepEqual(db.writes, []);
  assert.equal(await repairWorkoutThumbnail(database(workout(), {}, true), 'u', 'w'), 'skipped');
  db.values.delete('users/u/workouts/w');
  assert.equal(await repairWorkoutThumbnail(db, 'u', 'w'), 'skipped');
});
