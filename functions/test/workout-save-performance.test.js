import assert from 'node:assert/strict';
import test from 'node:test';
import {Timestamp} from 'firebase-admin/firestore';
import {saveWorkout} from '../src/workout-save.js';
import {planAccess} from '../src/plan-policy.js';
import {reconcileWorkoutPlanUsage} from '../src/plan-usage.js';

const workout = {id: 'lesson', ownerId: 'owner',
  author: {id: 'owner'}, name: 'Edited lesson', folder: '', modules: [],
  createdAt: 1000, updatedAt: 2000};
const usagePath = 'users/owner/planUsage/current';
function fixture({existing = true, count = 1, deleting = false} = {}) {
  const values = new Map([
    ['subscriptionEntitlements/owner', {...planAccess('free'), plan: 'free',
      status: 'active', validUntilMs: Date.now() + 86400000}],
  ]);
  if (existing) values.set('users/owner/workouts/lesson', {...workout, name: 'Previous',
    createdAt: Timestamp.fromMillis(500), updatedAt: Timestamp.fromMillis(1000)});
  if (deleting) values.set('accountDeletions/owner', {});
  const reads = [], writes = [], queries = [];
  const snapshot = ref => ({exists: values.has(ref.path), data: () => values.get(ref.path)});
  const tx = {
    async getAll(...refs) { reads.push(...refs.map(ref => ref.path)); return refs.map(snapshot); },
    async get(ref) {
      if (ref.projection) {
        queries.push(ref.path);
        return ref.path.endsWith('/workouts')
          ? {size: count, docs: []} : {size: 0, docs: []};
      }
      reads.push(ref.path);
      return snapshot(ref);
    },
    set(ref, value) { writes.push({path: ref.path, value}); },
  };
  const db = {
    doc: path => ({path}),
    collection: path => ({select: () => ({path, projection: true})}),
    runTransaction: callback => callback(tx),
  };
  return {db, reads, writes, queries, values};
}

test('existing edit writes content and summary without any usage read/write or collection query', async () => {
  const f = fixture();
  const result = await saveWorkout(f.db, 'owner', {ownerId: 'owner', workout,
    expectedUpdatedAt: 1, requireExisting: true});
  assert.equal(result.created, false);
  assert.equal(result.workout.name, 'Edited lesson');
  assert.equal(result.workout.createdAt, 500);
  assert.deepEqual(f.queries, []);
  assert(!f.reads.includes(usagePath));
  assert.deepEqual(f.writes.map(write => write.path), [
    'users/owner/workouts/lesson', 'users/owner/workoutSummaries/lesson',
  ]);
  assert.equal(f.writes[1].value.name, 'Edited lesson');
});

for (const requireExisting of [false, true]) {
  test(`new/restore save retains usage lock and projected recount (requireExisting=${requireExisting})`, async () => {
    const f = fixture({existing: false, count: 6});
    const result = await saveWorkout(f.db, 'owner', {ownerId: 'owner', workout, requireExisting});
    assert.equal(result.created, true);
    assert(f.reads.includes(usagePath));
    assert.deepEqual(f.queries.sort(), ['users/owner/slideTemplates', 'users/owner/workouts']);
    assert.equal(f.writes.find(write => write.path === usagePath).value.workoutCount, 7);
  });
}
test('restoration still fails at capacity without writing', async () => {
  const f = fixture({existing: false, count: 7});
  await assert.rejects(saveWorkout(f.db, 'owner', {
    ownerId: 'owner', workout, requireExisting: true,
  }), {code: 'resource-exhausted'});
  assert.deepEqual(f.writes, []);
});
test('existing edit still respects account deletion lock', async () => {
  const f = fixture({deleting: true});
  await assert.rejects(saveWorkout(f.db, 'owner', {ownerId: 'owner', workout}),
    {code: 'permission-denied'});
  assert.deepEqual(f.writes, []);
});
test('workout update trigger performs no database work', async () => {
  const db = {runTransaction() { assert.fail('content update must not recount'); }};
  assert.equal(await reconcileWorkoutPlanUsage(db, 'owner',
    {before: {exists: true}, after: {exists: true}}), null);
});
for (const [label, change] of [
  ['create', {before: {exists: false}, after: {exists: true}}],
  ['legacy direct delete', {before: {exists: true}, after: {exists: false}}],
  ['missing snapshot', undefined],
]) {
  test(`${label} trigger reads current collections and writes reconciled usage`, async () => {
    const f = fixture({count: 4});
    const result = await reconcileWorkoutPlanUsage(f.db, 'owner', change);
    assert.equal(result.workoutCount, 4);
    assert(f.reads.includes(usagePath));
    assert.equal(f.queries.length, 2);
    assert.equal(f.writes.find(write => write.path === usagePath).value.workoutCount, 4);
  });
}
