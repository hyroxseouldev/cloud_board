import assert from 'node:assert/strict';
import fs from 'node:fs';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {ref, set, get, update, runTransaction, onValue} from 'firebase/database';
import {doc, writeBatch, Timestamp as ClientTimestamp} from 'firebase/firestore';
import {initializeApp, deleteApp} from 'firebase-admin/app';
import {getDatabase} from 'firebase-admin/database';
import {prunePlaybackSnapshots} from '../src/playback-snapshots.js';
import {getFirestore, Timestamp} from 'firebase-admin/firestore';
import {backfillCatalog, syncWorkoutSummary, summarizeWorkout} from '../src/workout-catalog.js';
assert.match(process.env.FIRESTORE_EMULATOR_HOST || '', /^(127\.0\.0\.1|localhost):\d+$/);
assert.match(process.env.FIREBASE_DATABASE_EMULATOR_HOST || '', /^(127\.0\.0\.1|localhost):\d+$/);
const projectId = 'demo-cloudboard';
const app = initializeApp({projectId, databaseURL: 'https://demo-cloudboard.firebaseio.com'});
const db = getFirestore(app);
const env = await initializeTestEnvironment({projectId,
  firestore: {host: '127.0.0.1', port: 19080, rules: fs.readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8')},
  database: {host: '127.0.0.1', port: 19000, rules: fs.readFileSync(new URL('../../database.rules.json', import.meta.url), 'utf8')},
});
const workout = {id: 'w', ownerId: 'owner', author: {id: 'owner'}, name: '한국어 운동', folder: '전체 검색',
  createdAt: Timestamp.fromMillis(1000), updatedAt: Timestamp.fromMillis(2000),
  modules: [{id: 'm', name: 'work', imageSource: 'https://example.invalid/image', text: 'a'.repeat(100000),
    workSeconds: 30, restSeconds: 10, sets: 3,
    intervalBlocks: [{workSeconds: 40, restSeconds: 15, sets: 2}]}]};
try {
  await env.clearFirestore(); await env.clearDatabase();
  await db.doc('users/owner').set({uid: 'owner'});
  await db.doc('users/owner/workouts/w').set(workout);
  await db.doc('users/other/workouts/untouched').set({...workout, id: 'untouched', ownerId: 'other'});
  assert.equal(await backfillCatalog(db, 'owner'), 1);
  const summary = (await db.doc('users/owner/workoutSummaries/w').get()).data();
  assert.deepEqual(summary, summarizeWorkout(workout));
  assert.equal(summary.durationSeconds, 95);
  assert.equal((await db.doc('users/owner/catalog/schema').get()).data().version, 2);
  assert.deepEqual((await db.doc('users/owner/workouts/w').get()).data(), workout);
  assert.equal((await db.doc('users/other/workoutSummaries/untouched').get()).exists, false);
  assert.equal(await syncWorkoutSummary(db, 'owner', 'w'), false);
  await db.doc('users/owner/workouts/w').update({name: '수정', updatedAt: Timestamp.fromMillis(3000)});
  await syncWorkoutSummary(db, 'owner', 'w');
  assert.equal((await db.doc('users/owner/workoutSummaries/w').get()).data().name, '수정');
  await db.doc('users/owner/workouts/w').delete();
  await syncWorkoutSummary(db, 'owner', 'w');
  assert.equal((await db.doc('users/owner/workoutSummaries/w').get()).exists, false);
  await db.doc('users/locked/workouts/w').set(workout);
  await db.doc('accountDeletions/locked').set({status: 'pending'});
  await backfillCatalog(db, 'locked');
  assert.equal((await db.doc('users/locked/catalog/schema').get()).exists, false);
  assert.equal((await db.doc('users/locked/workoutSummaries/w').get()).exists, false);

  const owner = env.authenticatedContext('owner', {firebase: {sign_in_provider: 'password'}});
  const other = env.authenticatedContext('other');
  const clientWorkout = {...workout, createdAt: ClientTimestamp.fromMillis(1000), updatedAt: ClientTimestamp.fromMillis(2000)};
  const batch = writeBatch(owner.firestore());
  batch.set(doc(owner.firestore(), 'users/owner/workouts/w'), clientWorkout);
  batch.set(doc(owner.firestore(), 'users/owner/workoutSummaries/w'), summarizeWorkout(clientWorkout));
  await assertSucceeds(batch.commit());
  const denied = writeBatch(other.firestore());
  denied.set(doc(other.firestore(), 'users/owner/workoutSummaries/w'), summarizeWorkout(clientWorkout));
  await assertFails(denied.commit());
  const markerBatch = writeBatch(owner.firestore());
  markerBatch.set(doc(owner.firestore(), 'users/owner/catalog/schema'), {version: 2});
  await assertFails(markerBatch.commit());

  const rtdb = owner.database();
  const snapshot = {...workout, createdAt: '2026-09-01', updatedAt: '2026-09-18'};
  const state = {schemaVersion: 2, snapshotId: 's', id: 's', ownerId: 'owner', zoneId: 'main',
    workoutId: 'w', workoutName: workout.name, status: 'playing', stepIndex: 0, remainingMs: 10000,
    anchorServerMs: Date.now(), revision: 1, updatedByDeviceId: 'phone'};
  const stateRef = ref(rtdb, 'users/owner/activeSession');
  await assertFails(set(stateRef, state)); // Cannot point at absent content.
  await assertSucceeds(update(ref(rtdb, 'users/owner'), {
    activeSession: state, 'playbackSnapshots/s': snapshot,
  }));
  await assertFails(set(ref(rtdb, 'users/owner/playbackSnapshots/s'), {...snapshot, name: 'mutated'}));
  await assertFails(set(ref(rtdb, 'users/owner/playbackSnapshots/s'), null));
  const unsubscribe = onValue(stateRef, () => {});
  await get(stateRef);
  const result = await assertSucceeds(runTransaction(stateRef, current => {
    if (!current) return; // Seeded client state is already available.
    return {...current, status: 'paused', revision: 2,
      notificationCommand: {id: 'pause', expiresAtMs: Date.now() + 5000}};
  }, {applyLocally: false}));
  unsubscribe();
  assert.equal(result.committed, true);
  assert.equal(result.snapshot.val().workoutSnapshot, undefined);
  assert.equal((await get(ref(rtdb, 'users/owner/playbackSnapshots/s'))).val().name, workout.name);
  await assertFails(set(stateRef, {...state, revision: 3, notificationCommand: {id: 'expired', expiresAtMs: Date.now() - 10000}}));
  await assertFails(set(ref(other.database(), 'users/owner/activeSession'), state));
  // A following old-client session remains valid; live v2 cannot downgrade in-place.
  await assertFails(set(stateRef, {...state, schemaVersion: null, snapshotId: null, workoutSnapshot: snapshot}));
  await assertSucceeds(set(stateRef, {...state, id: 'legacy', schemaVersion: null, snapshotId: null, workoutSnapshot: snapshot}));
  await assertSucceeds(set(ref(rtdb, 'users/owner/playbackSnapshots/s'), null));
  const base = getDatabase(app).ref('users/owner');
  await base.child('playbackSnapshots').set({
    obsolete: {...snapshot, _storedAtMs: 100},
    legacy: {...snapshot, _storedAtMs: 100},
    recent: {...snapshot, _storedAtMs: Date.now()},
  });
  assert.equal(await prunePlaybackSnapshots(base, 200), 1);
  assert.equal((await base.child('playbackSnapshots/obsolete').get()).exists(), false);
  assert.equal((await base.child('playbackSnapshots/legacy').get()).exists(), true);
  assert.equal((await base.child('playbackSnapshots/recent').get()).exists(), true);
  assert.equal(await prunePlaybackSnapshots(base, 200), 0);
  const ratio = Buffer.byteLength(JSON.stringify(summary)) / Buffer.byteLength(JSON.stringify(workout));
  const commandRatio = Buffer.byteLength(JSON.stringify(state)) / Buffer.byteLength(JSON.stringify({...state, workoutSnapshot: snapshot}));
  console.log(JSON.stringify({result: 'PASS', syntheticSummaryReduction: 1-ratio, syntheticCommandReduction: 1-commandRatio}));
} finally { await env.cleanup(); await deleteApp(app); }
