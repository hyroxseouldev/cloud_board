import {test} from 'node:test';
import assert from 'node:assert/strict';
import {favoriteLimit, mutateSlideLibrary, normalizeLibraryValue} from '../src/slide-library.js';
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
test('legacy slide design defaults compare equally after a current-client round trip', () => {
  const legacy = {id:'saved-slide',name:'MAIN',showTimer:true,appearance:{}};
  const defaults = {designLayout:'auto',designFontWeight:900,designItalic:true,designSpacing:1.0};
  assert.deepEqual(normalizeLibraryValue(legacy), normalizeLibraryValue({...legacy,...defaults}));
  assert.deepEqual(normalizeLibraryValue(legacy), normalizeLibraryValue({...legacy,
    designLayout:null,designFontWeight:null,designItalic:null,designSpacing:null}));
  assert.equal(normalizeLibraryValue(null),null);
  for (const change of [{designLayout:'columns'},{designFontWeight:700},{designItalic:false},{designSpacing:1.2}]) {
    assert.notDeepEqual(normalizeLibraryValue(legacy), normalizeLibraryValue({...legacy,...change}),
      'real appearance edits must remain distinguishable for conflict detection');
  }
});
