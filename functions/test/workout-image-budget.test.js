import assert from 'node:assert/strict';
import test from 'node:test';
import {ownedWorkoutImage, workoutImageBudgetChecker} from '../src/workout-image-budget.js';
const name = 'demo-budget.appspot.com', uid = 'coach';
const path = id => `users/${uid}/workouts/lesson/images/${id}`;
const url = (id, token = 'one') => `https://firebasestorage.googleapis.com/v0/b/${name}/o/${encodeURIComponent(path(id))}?alt=media&token=${token}`;
const workout = (sources, countdownImageSource = '') => ({modules: sources.map(imageUrl => ({imageUrl})), countdownImageSource});
function fixture(sizes) {
  const reads = [];
  return {reads, bucket: {name, file: path => ({getMetadata: async () => {
    reads.push(path);
    const size = sizes[path.split('/').at(-1)];
    if (size instanceof Error) throw size;
    return [{size: String(size), contentType: 'image/png'}];
  }})}};
}
test('exact 100 MB accepted; token variants, copied asset and countdown count once', async () => {
  const f = fixture({a: 60000000, b: 40000000});
  const check = workoutImageBudgetChecker(f.bucket, uid);
  assert.deepEqual(await check(workout([url('a'), url('a', 'two'), url('b')], url('b'))),
    {totalBytes: 100000000, unknownCount: 0});
  assert.equal(f.reads.length, 2);
  await check(workout([url('a')]));
  assert.equal(f.reads.length, 2, 'transaction retry reuses metadata');
});
test('100 MB plus one byte fails with safe reason and exact total', async () => {
  const f = fixture({a: 100000001});
  await assert.rejects(workoutImageBudgetChecker(f.bucket, uid)(workout([url('a')])),
    error => error.code === 'resource-exhausted' &&
      error.details.reason === 'workout-image-budget-exceeded' && error.details.totalBytes === 100000001);
});
test('unchanged historical external sources remain unknown, new external rejected', async () => {
  const f = fixture({a: 12});
  const old = workout(['https://legacy.example/image.png']);
  const check = workoutImageBudgetChecker(f.bucket, uid);
  assert.deepEqual(await check(workout([...old.modules.map(m => m.imageUrl), url('a')]), old),
    {totalBytes: 12, unknownCount: 1});
  await assert.rejects(check(old), error => error.details.reason === 'workout-image-unverifiable');
  assert.equal(f.reads.length, 1);
});
test('foreign bucket/owner, arbitrary hosts and malformed paths cannot trigger metadata reads', async () => {
  const f = fixture({});
  for (const source of [url('a').replace(name, 'foreign.appspot.com'),
    url('a').replace('coach', 'other'), url('a').replace('firebasestorage.googleapis.com', '127.0.0.1'),
    url('a').replace('images%2Fa', 'images%2F..%2Fa')]) {
    assert.equal(ownedWorkoutImage(source, uid, name), null);
    await assert.rejects(workoutImageBudgetChecker(f.bucket, uid)(workout([source])));
  }
  assert.equal(f.reads.length, 0);
});
test('missing metadata and invalid sizes fail closed; never accepted as zero', async () => {
  for (const size of [new Error('missing'), undefined, -1, 1.5]) {
    const f = fixture({a: size});
    await assert.rejects(workoutImageBudgetChecker(f.bucket, uid)(workout([url('a')])),
      error => error.details.reason === 'workout-image-metadata-unavailable');
  }
});
test('metadata concurrency is capped and stalled requests have a bounded failure', async () => {
  let active = 0, peak = 0;
  const bucket = {name, file: () => ({getMetadata: async () => {
    peak = Math.max(peak, ++active);
    await new Promise(resolve => setTimeout(resolve, 4)); active--;
    return [{size: '1', contentType: 'image/png'}];
  }})};
  await workoutImageBudgetChecker(bucket, uid)(workout(Array.from({length: 9}, (_, i) => url(i))));
  assert.equal(peak, 3);
  const stalled = {name, file: () => ({getMetadata: () => new Promise(() => {})})};
  await assert.rejects(workoutImageBudgetChecker(stalled, uid, {metadataTimeoutMs: 5})(workout([url('a')])),
    error => error.details.reason === 'workout-image-metadata-unavailable');
});
test('emulator URLs are allowed only with explicit matching emulator configuration', () => {
  const local = url('a').replace('https://firebasestorage.googleapis.com', 'http://127.0.0.1:19499');
  assert.equal(ownedWorkoutImage(local, uid, name), null);
  assert.equal(ownedWorkoutImage(local, uid, name, '127.0.0.1:19499'), path('a'));
});
