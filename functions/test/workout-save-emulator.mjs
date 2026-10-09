import assert from 'node:assert/strict';
import fs from 'node:fs';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc, getDoc, runTransaction, setDoc, Timestamp} from 'firebase/firestore';
import {summarizeWorkout} from '../src/workout-catalog.js';

assert.match(process.env.FIRESTORE_EMULATOR_HOST || '', /^(127\.0\.0\.1|localhost):\d+$/);
const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
const rulesFile = process.env.FIRESTORE_RULES_FILE || new URL('../../firestore.rules', import.meta.url);
const env = await initializeTestEnvironment({
  projectId: 'demo-cloudboard-workouts',
  firestore: {host, port: Number(port), rules: fs.readFileSync(rulesFile, 'utf8')},
});

const workout = (id, timerMode = 'custom', workSeconds = 60) => ({
  id, ownerId: 'owner', author: {id: 'owner', displayName: 'Coach', photoUrl: null},
  name: 'Workout', folder: '',
  modules: [{id: 'slide', timerMode, workSeconds, restSeconds: 0, sets: 1, rounds: 1, imageUrl: ''}],
  createdAt: Timestamp.fromMillis(1000), updatedAt: Timestamp.fromMillis(2000),
});

// Match WorkoutFirestoreDataSource.save: read settings and the previous workout,
// then atomically write its content and list projection with the same owner.
function save(db, value, {summaryPatch = {}, legacySummary = false} = {}) {
  return runTransaction(db, async transaction => {
    const settings = await transaction.get(doc(db, 'users/owner/settings/workout'));
    const reference = doc(db, `users/owner/workouts/${value.id}`);
    await transaction.get(reference);
    const content = settings.data()?.contentOnly ? {...value, schemaVersion: 2} : {...value, brandL: '', brandR: ''};
    const summary = {...summarizeWorkout(value), ...summaryPatch};
    if (legacySummary) delete summary.durationKind;
    transaction.set(reference, content);
    transaction.set(doc(db, `users/owner/workoutSummaries/${value.id}`), summary);
  });
}

try {
  await env.clearFirestore();
  const owner = env.authenticatedContext('owner').firestore();
  const other = env.authenticatedContext('other').firestore();
  const guest = env.unauthenticatedContext().firestore();

  for (const contentOnly of [false, true]) {
    if (contentOnly) {
      await env.withSecurityRulesDisabled(context =>
        setDoc(doc(context.firestore(), 'users/owner/settings/workout'), {contentOnly: true}));
    }
    for (const [kind, timerMode, seconds] of [
      ['fixed', 'custom', 60], ['maximum', 'forTime', 600], ['open', 'forTime', 0],
    ]) {
      const value = workout(`${contentOnly}-${kind}`, timerMode, seconds);
      await assertSucceeds(save(owner, value));
      const saved = (await getDoc(doc(owner, `users/owner/workoutSummaries/${value.id}`))).data();
      assert.equal(saved.durationKind, kind);
      assert.equal(saved.moduleCount, 1);
      await assertSucceeds(save(owner, {...value, name: 'Edited workout', updatedAt: Timestamp.fromMillis(3000)}));
      assert.equal((await getDoc(doc(owner, `users/owner/workouts/${value.id}`))).data().name, 'Edited workout');
    }
    await assertSucceeds(save(owner, workout(`${contentOnly}-legacy`), {legacySummary: true}));
  }
  console.log('PASS: create/update workout and summary together for fixed, maximum and open timers; legacy and content-only schemas');

  const value = workout('protected');
  await assertSucceeds(save(owner, value));
  for (const summaryPatch of [
    {durationKind: 'invalid'}, {durationKind: null}, {durationKind: 1},
    {unexpected: true}, {id: 'wrong-id'}, {moduleCount: -1},
  ]) {
    await assertFails(save(owner, {...value, name: 'Must not persist'}, {summaryPatch}));
    assert.equal((await getDoc(doc(owner, 'users/owner/workouts/protected'))).data().name, value.name);
  }
  await assertFails(save(owner, {...value, ownerId: 'other'}));
  await assertFails(save(owner, {...value, author: {id: 'other'}}));
  await assertFails(save(owner, {...value, createdAt: Timestamp.fromMillis(5000)}));
  await assertFails(setDoc(doc(owner, 'users/owner/workoutSummaries/orphan'), summarizeWorkout(workout('orphan'))));
  for (const db of [other, guest]) {
    await assertFails(save(db, value));
    await assertFails(setDoc(doc(db, 'users/owner/workoutSummaries/protected'), summarizeWorkout(value)));
    await assertFails(getDoc(doc(db, 'users/owner/workouts/protected')));
  }
  await env.withSecurityRulesDisabled(context =>
    setDoc(doc(context.firestore(), 'accountDeletions/owner'), {status: 'pending'}));
  await assertFails(save(owner, value));
  console.log('PASS: invalid summaries roll back workout writes; ownership, immutable creation time and deletion locks remain enforced');
} finally {
  await env.cleanup();
}
