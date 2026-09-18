import assert from 'node:assert/strict';
import {initializeApp, deleteApp} from 'firebase-admin/app';
import {getFirestore, Timestamp} from 'firebase-admin/firestore';
import {syncWorkoutSummary} from '../src/workout-catalog.js';
import {repairWorkoutThumbnail} from '../src/workout-thumbnail-repair.js';
assert.match(process.env.FIRESTORE_EMULATOR_HOST || '', /^(127\.0\.0\.1|localhost):\d+$/);
const app = initializeApp({projectId: 'demo-cloudboard'});
const db = getFirestore(app);
try {
  const root = 'users/thumbnail-test';
  const original = {id: 'w', name: '수업', updatedAt: Timestamp.fromMillis(1234),
    modules: [{imageUrl: 'https://example.invalid/first.jpg', workSeconds: 60, restSeconds: 0, sets: 1}]};
  const source = db.doc(`${root}/workouts/w`);
  const summary = db.doc(`${root}/workoutSummaries/w`);
  const stale = {id: 'w', name: '수업', imageSource: '', updatedAt: original.updatedAt, custom: 'keep'};
  await source.set(original);
  await summary.set(stale);
  assert.equal(await repairWorkoutThumbnail(db, 'thumbnail-test', 'w'), 'candidate');
  assert.deepEqual((await summary.get()).data(), stale);
  const backups = [];
  assert.equal(await repairWorkoutThumbnail(db, 'thumbnail-test', 'w', {apply: true, backup: async data => {backups.push(data);}}), 'repaired');
  assert.deepEqual(backups[0].summary, stale);
  assert.deepEqual((await summary.get()).data(), {...stale, imageSource: original.modules[0].imageUrl});
  assert.deepEqual((await source.get()).data(), original);
  assert.equal(await repairWorkoutThumbnail(db, 'thumbnail-test', 'w'), 'unchanged');
  await syncWorkoutSummary(db, 'thumbnail-test', 'w');
  assert.equal((await summary.get()).data().imageSource, original.modules[0].imageUrl);
  assert.equal(await syncWorkoutSummary(db, 'thumbnail-test', 'w'), false);
  await source.update({modules: [{...original.modules[0], imageUrl: ''}]});
  await syncWorkoutSummary(db, 'thumbnail-test', 'w');
  assert.equal((await summary.get()).data().imageSource, '');
  await source.set(original);
  await db.doc('accountDeletions/thumbnail-test').set({status: 'pending'});
  assert.equal(await repairWorkoutThumbnail(db, 'thumbnail-test', 'w', {apply: true, backup: async () => {throw Error('must not back up locked account');}}), 'skipped');
  console.log('PASS: Firestore thumbnail repair, preservation, idempotence, sync, removal, deletion lock');
} finally {await db.terminate(); await deleteApp(app);}
