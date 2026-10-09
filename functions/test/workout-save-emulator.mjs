import assert from 'node:assert/strict';
import fs from 'node:fs';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc, getDoc, runTransaction, setDoc, Timestamp} from 'firebase/firestore';

assert.match(process.env.FIRESTORE_EMULATOR_HOST || '', /^(127\.0\.0\.1|localhost):\d+$/);
const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
const rulesFile = process.env.FIRESTORE_RULES_FILE || new URL('../../firestore.rules', import.meta.url);
const currentFile = new URL('../../build/contracts/workout-save-current.json', import.meta.url);
assert.ok(fs.existsSync(currentFile), 'Export current Flutter payloads first: flutter test tool/export_workout_save_fixtures_test.dart');
const fixtureDir = new URL('./fixtures/workout-save/', import.meta.url);
const files = [currentFile, ...fs.readdirSync(fixtureDir).filter(f => f.endsWith('.json')).map(f => new URL(f, fixtureDir))];
const read = file => JSON.parse(fs.readFileSync(file, 'utf8'), (_, value) =>
  value && typeof value === 'object' && Object.hasOwn(value, '__timestampMillis')
    ? Timestamp.fromMillis(value.__timestampMillis) : value);
const env = await initializeTestEnvironment({
  projectId: 'demo-cloudboard-workouts',
  firestore: {host, port: Number(port), rules: fs.readFileSync(rulesFile, 'utf8')},
});

// Replay the exact maps serialized by WorkoutSaveDocuments in Flutter. No JS
// summary generator or hand-maintained allowlist may mask new client fields.
function save(db, {workout, summary}) {
  return runTransaction(db, async transaction => {
    await transaction.get(doc(db, 'users/owner/settings/workout'));
    const reference = doc(db, `users/owner/workouts/${workout.id}`);
    await transaction.get(reference);
    transaction.set(reference, workout);
    transaction.set(doc(db, `users/owner/workoutSummaries/${workout.id}`), summary);
  });
}
const setMode = contentOnly => env.withSecurityRulesDisabled(context =>
  setDoc(doc(context.firestore(), 'users/owner/settings/workout'), {contentOnly}));

try {
  const owner = env.authenticatedContext('owner').firestore();
  const other = env.authenticatedContext('other').firestore();
  const guest = env.unauthenticatedContext().firestore();
  for (const file of files) {
    const contract = read(file);
    assert.equal(contract.format, 1);
    assert.equal(contract.scenarios.length, 6);
    for (const scenario of contract.scenarios) {
      await env.clearFirestore();
      await setMode(scenario.contentOnly);
      assert.deepEqual(scenario.writes.map(w => w.operation), ['create', 'update', 'duplicate']);
      for (const write of scenario.writes) {
        await assertSucceeds(save(owner, write));
        assert.deepEqual((await getDoc(doc(owner, `users/owner/workouts/${write.workout.id}`))).data(), write.workout);
        const summary = (await getDoc(doc(owner, `users/owner/workoutSummaries/${write.workout.id}`))).data();
        assert.deepEqual(summary, write.summary);
        assert.equal(summary.durationKind, scenario.durationKind);
      }
      const legacy = {...scenario.writes[1], summary: {...scenario.writes[1].summary}};
      delete legacy.summary.durationKind;
      await assertSucceeds(save(owner, legacy));
    }
    console.log(`PASS: ${contract.client || 'current Flutter'} create/update/duplicate, all duration kinds and both schemas; pre-durationKind summary compatibility`);
  }

  await env.clearFirestore();
  await setMode(true);
  const value = read(currentFile).scenarios.find(s => s.contentOnly).writes[0];
  const id = value.workout.id;
  const workoutRef = doc(owner, `users/owner/workouts/${id}`);
  await assertSucceeds(save(owner, value));
  for (const patch of [
    {durationKind: 'invalid'}, {durationKind: null}, {durationKind: 1},
    {unexpected: true}, {id: 'wrong-id'}, {moduleCount: -1},
  ]) {
    await assertFails(save(owner, {...value, workout: {...value.workout, name: 'Must not persist'}, summary: {...value.summary, ...patch}}));
    assert.deepEqual((await getDoc(workoutRef)).data(), value.workout);
  }
  for (const patch of [{ownerId: 'other'}, {author: {id: 'other'}}, {createdAt: Timestamp.fromMillis(5000)}]) {
    await assertFails(save(owner, {...value, workout: {...value.workout, ...patch}}));
  }
  await assertFails(setDoc(doc(owner, 'users/owner/workoutSummaries/orphan'), {...value.summary, id: 'orphan'}));
  for (const db of [other, guest]) {
    await assertFails(save(db, value));
    await assertFails(setDoc(doc(db, `users/owner/workoutSummaries/${id}`), value.summary));
    await assertFails(getDoc(doc(db, `users/owner/workouts/${id}`)));
  }
  await env.withSecurityRulesDisabled(context =>
    setDoc(doc(context.firestore(), 'accountDeletions/owner'), {status: 'pending'}));
  await assertFails(save(owner, value));
  console.log('PASS: failed transactions roll back; ownership, immutable creation time, orphan summaries and deletion locks remain enforced');
} finally {
  await env.cleanup();
}
