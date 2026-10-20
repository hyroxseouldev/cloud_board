// Run only against local Auth + Firestore + Functions emulators. The Functions
// fixture re-exports saveWorkout from the real src/index.js (no mock callable).
import assert from 'node:assert/strict';
import {initializeApp, deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {planAccess} from '../src/plan-policy.js';

for (const name of ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST',
  'STA189_FUNCTIONS_EMULATOR_HOST']) {
  assert.match(process.env[name] ?? '', /^127\.0\.0\.1:\d+$/, `${name} must be local`);
}
const projectId = process.env.GCLOUD_PROJECT;
assert.match(projectId ?? '', /^demo-[a-z0-9-]+$/);
const app = initializeApp({projectId}), db = getFirestore(app);
const authResponse = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-key`, {
  method: 'POST', headers: {'content-type': 'application/json'},
  body: JSON.stringify({returnSecureToken: true}),
});
assert.equal(authResponse.status, 200);
const {localId: uid, idToken} = await authResponse.json();
assert(uid && idToken);
const url = `http://${process.env.STA189_FUNCTIONS_EMULATOR_HOST}/${projectId}/asia-northeast3/saveWorkout`;
const workout = (id, name = id, updatedAt = Date.now()) => ({
  id, ownerId: uid, author: {id: uid, displayName: 'Local test'},
  name, folder: '', modules: [], createdAt: 1000, updatedAt,
  futureMetadata: {retained: true},
});
async function call(value, extra = {}, authenticated = true) {
  const response = await fetch(url, {method: 'POST',
    headers: {'content-type': 'application/json',
      ...(authenticated ? {authorization: `Bearer ${idToken}`} : {})},
    body: JSON.stringify({data: {ownerId: uid, workout: value, ...extra}})});
  const body = await response.json();
  if (body.error) throw Object.assign(new Error(body.error.message), {status: body.error.status});
  assert.equal(response.status, 200);
  return body.result;
}
try {
  await db.doc(`subscriptionEntitlements/${uid}`).set({
    ...planAccess('free'), plan: 'free', status: 'active',
    validUntilMs: Date.now() + 86400000,
  });
  const first = workout('lesson', 'First', 2000);
  assert.equal((await call(first)).created, true);
  assert.equal((await call(first)).created, false);
  const usage = db.doc(`users/${uid}/planUsage/current`);
  const before = await usage.get();
  const edited = {...first, name: 'Edited through HTTP callable', createdAt: 99, updatedAt: 3000,
    modules: [{id: 'slide', name: 'Image slide', text: '', imageUrl: 'https://example.invalid/local-fixture.png',
      workSeconds: 60, restSeconds: 0, sets: 1, showTimer: true, beep: true,
      designTemplate: null, designStyle: null, designFingerprint: null}]};
  const result = await call(edited, {expectedUpdatedAt: 1, requireExisting: true});
  assert.equal(result.created, false);
  assert.equal(result.workout.createdAt, 1000);
  const saved = (await db.doc(`users/${uid}/workouts/lesson`).get()).data();
  assert.equal(saved.name, edited.name);
  assert.deepEqual(saved.futureMetadata, {retained: true});
  assert.deepEqual(saved.modules, edited.modules);
  const summary = (await db.doc(`users/${uid}/workoutSummaries/lesson`).get()).data();
  assert.equal(summary.name, edited.name);
  assert.equal(summary.moduleCount, 1);
  assert.equal(summary.durationSeconds, 60);
  assert((await usage.get()).updateTime.isEqual(before.updateTime));
  for (let i = 0; i < 5; i++) await call(workout(`slot-${i}`));
  const race = await Promise.allSettled([call(workout('last-a')), call(workout('last-b'))]);
  assert.equal(race.filter(result => result.status === 'fulfilled').length, 1);
  assert.equal(race.find(result => result.status === 'rejected').reason.status, 'RESOURCE_EXHAUSTED');
  assert.equal((await db.collection(`users/${uid}/workouts`).get()).size, 7);
  await db.doc(`users/${uid}/workouts/lesson`).delete();
  assert.equal((await call(edited, {requireExisting: true})).created, true);
  assert.equal((await usage.get()).data().workoutCount, 7);
  await assert.rejects(call(workout('anonymous'), {}, false), {status: 'UNAUTHENTICATED'});
  await assert.rejects(call(workout('wrong-owner'), {ownerId: 'other'}), {status: 'PERMISSION_DENIED'});
  console.log('PASS: real saveWorkout HTTP callable + Auth/Firestore emulators; create/retry/edit readback, plain image/unknown fields, immutable creation, summary, unchanged edit usage, concurrent final slot, restore and auth guards');
} finally {
  await deleteApp(app);
}
