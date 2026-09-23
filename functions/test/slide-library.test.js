import {test} from 'node:test';
import assert from 'node:assert/strict';
import {favoriteLimit, mutateSlideLibrary} from '../src/slide-library.js';
test('plus caps favorite registration and only trusted premium removes limit', () => {
  assert.equal(favoriteLimit({plan:'plus', maxFavorites:999}),3);
  assert.equal(favoriteLimit({plan:'premium', favoritesUnlimited:true}),null);
  assert.equal(favoriteLimit({plan:'premium'}),3);
  assert.equal(favoriteLimit({plan:'legacy'}),null);
  assert.equal(favoriteLimit(null),3);
});
test('unauthenticated, mismatched account and invalid payload rejected before accessing database', async () => {
  await assert.rejects(mutateSlideLibrary(null,null,{}), {code:'unauthenticated'});
  await assert.rejects(mutateSlideLibrary(null,'a',{ownerId:'b'}), {code:'permission-denied'});
  await assert.rejects(mutateSlideLibrary(null,'a',{ownerId:'a', kind:'templates',changes:[]}), {code:'invalid-argument'});
});
