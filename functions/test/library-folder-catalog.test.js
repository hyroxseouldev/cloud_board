import test from 'node:test';
import assert from 'node:assert/strict';
import {listLibraryFolders} from '../src/library-folders.js';

function fixture(count) {
  const queries = [];
  const workouts = Array.from({length: count}, (_, i) => ({
    folder: i === count - 1 ? '오래된 폴더' : `폴더 ${i % 3}`,
    modules: [{imageSource: 'x'.repeat(50000)}],
  }));
  const db = {collection(path) {
    assert.ok(path.startsWith('users/owner/'));
    return {select(field) {
      queries.push({path, field});
      return {async get() {
        const values = path.endsWith('/workouts') ? workouts : [{name: '빈 폴더'}];
        return {docs: values.map(value => ({data: () => ({[field]: value[field]})}))};
      }};
    }};
  }};
  return {db, queries};
}

for (const count of [10, 100, 500]) {
  test(`legacy folder discovery projects only names for ${count} workouts`, async () => {
    const {db, queries} = fixture(count);
    const start = performance.now();
    const result = await listLibraryFolders(db, 'owner', {owner: 'owner'});
    const elapsedMs = performance.now() - start;
    assert.deepEqual(result.folders, ['빈 폴더', '오래된 폴더', '폴더 0', '폴더 1', '폴더 2']);
    assert.deepEqual(queries.map(query => query.field), ['name', 'folder']);
    assert.ok(JSON.stringify(result).length < 100);
    console.log(JSON.stringify({scenario: 'STA-126 projected folder fixture', workouts: count,
      baselineClientWorkoutDocuments: count, afterClientWorkoutDocuments: 0,
      projectedBackendWorkoutDocuments: count, queries: queries.length, elapsedMs}));
  });
}

test('folder lookup rejects unauthenticated and account-switch requests before reading', async () => {
  const {db, queries} = fixture(10);
  await assert.rejects(listLibraryFolders(db, null, {owner: 'owner'}), {code: 'unauthenticated'});
  await assert.rejects(listLibraryFolders(db, 'other', {owner: 'owner'}), {code: 'permission-denied'});
  assert.equal(queries.length, 0);
});
