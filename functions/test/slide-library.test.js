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

test('legacy snapshots equal new DTO defaults while studio snapshots remain distinct', () => {
  const stored = {id: 'slide', name: 'MAIN', showTimer: false, appearance: {}};
  const client = {...stored, designHeaderLabel: '', designSubtitle: ''};
  assert.deepEqual(normalizeLibraryValue(stored), normalizeLibraryValue(client));
  assert.deepEqual(normalizeLibraryValue(stored), normalizeLibraryValue({...client, designStyle: null}));
  assert.deepEqual(normalizeLibraryValue(stored), normalizeLibraryValue({...stored,
    designStyle: null, designHeaderLabel: null, designSubtitle: null}));
  const designStyle = {version: 1, family: 'editorial', fontFamily: 'serif',
    titleWeight: 700, titleColor: 0xFFFF0048, motif: '突破'};
  const studio = {...client, designTemplate: 'studio-v1-list', designStyle,
    designHeaderLabel: 'MY CLASS', designSubtitle: '6mins On / 90s Off'};
  assert.deepEqual(normalizeLibraryValue(studio).designStyle, {...designStyle, originalTemplate: null});
  for (const change of [{designStyle}, {designHeaderLabel: 'MY CLASS'}, {designSubtitle: '6mins On / 90s Off'}]) {
    assert.notDeepEqual(normalizeLibraryValue(stored), normalizeLibraryValue({...client, ...change}));
  }
});

test('studio style comparison matches all nested DTO defaults without hiding real changes', () => {
  const defaults = {version: 1, family: 'banner', fontFamily: 'sans',
    titleColor: null, titleWeight: 900, motif: '', originalTemplate: null};
  for (const style of [{}, Object.fromEntries(Object.keys(defaults).map(key => [key, null]))]) {
    assert.deepEqual(normalizeLibraryValue({designStyle: style}),
      normalizeLibraryValue({designStyle: defaults}));
  }
  const stored = {designStyle: {version: 1, family: 'editorial', fontFamily: 'serif',
    titleWeight: 700, titleColor: 0xFFD91F50, motif: '突破'}};
  const currentDto = {...stored, designStyle: {...stored.designStyle, originalTemplate: null}};
  assert.deepEqual(normalizeLibraryValue(stored), normalizeLibraryValue(currentDto));
  for (const change of [{originalTemplate: 'dolpa-brick-v1'}, {titleColor: null},
    {motif: ''}, {titleWeight: 900}, {version: 2}, {futureField: 'preserve'}]) {
    assert.notDeepEqual(normalizeLibraryValue(stored),
      normalizeLibraryValue({...stored, designStyle: {...stored.designStyle, ...change}}));
  }
  assert.notDeepEqual(normalizeLibraryValue({designStyle: null}),
    normalizeLibraryValue({designStyle: defaults}), 'no studio style remains distinct from a default studio style');
});

test('legacy library edit after DTO roundtrip saves complete studio style and detects later conflicts', async () => {
  const id = 'slide';
  const stored = {id, name: 'MAIN', text: 'Run 200m', imageUrl: '',
    workSeconds: 60, restSeconds: 0, sets: 1, showTimer: false,
    beep: true, coverImage: false, favorite: false, category: '', appearance: {}, intervalBlocks: []};
  const path = `users/owner/slideTemplates/${id}`;
  const documents = new Map([[path, {value: stored}], ['users/owner/libraryState/index', {savedCount: 1, favoriteCount: 0}]]);
  const db = {
    doc: path => ({path}),
    collection: path => ({doc: id => ({path: `${path}/${id}`})}),
    runTransaction: async run => run({
      getAll: async (...refs) => refs.map(ref => ({exists: documents.has(ref.path), data: () => documents.get(ref.path)})),
      set: (ref, value, options) => documents.set(ref.path, options?.merge ? {...documents.get(ref.path), ...value} : value),
    }),
  };
  const base = {...stored, designHeaderLabel: '', designSubtitle: ''};
  const designStyle = {version: 1, family: 'editorial', fontFamily: 'serif', titleColor: 0xFFFF0048, titleWeight: 700, motif: '突破'};
  const next = {...base, designTemplate: 'studio-v1-list', designStyle,
    designHeaderLabel: 'DOLPA', designSubtitle: '6mins On / 90s Off'};
  const request = {ownerId: 'owner', kind: 'templates', changes: [{id, base, value: next}]};
  assert.equal((await mutateSlideLibrary(db, 'owner', request)).changed, 1);
  assert.deepEqual(documents.get(path).value, next);
  assert.equal((await mutateSlideLibrary(db, 'owner', request)).changed, 0, 'lost-response retry stays idempotent');
  // A later client adds originalTemplate:null when it decodes this older style.
  // It must still be able to edit the lesson and preserve the complete style.
  const currentBase = {...next, designStyle: {...designStyle, originalTemplate: null}};
  const originalValue = {...currentBase, designStyle: {...currentBase.designStyle, originalTemplate: 'dolpa-brick-v1'}};
  const originalRequest = {...request, changes: [{id, base: currentBase, value: originalValue}]};
  assert.equal((await mutateSlideLibrary(db, 'owner', originalRequest)).changed, 1);
  assert.deepEqual(documents.get(path).value, originalValue);
  assert.equal((await mutateSlideLibrary(db, 'owner', originalRequest)).changed, 0);
  await assert.rejects(mutateSlideLibrary(db, 'owner', {...request,
    changes: [{id, base: currentBase, value: {...currentBase, designSubtitle: 'Stale lesson'}}]}), {code: 'aborted'});
  await assert.rejects(mutateSlideLibrary(db, 'owner', {...request,
    changes: [{id, base, value: {...next, designSubtitle: 'Another lesson'}}]}), {code: 'aborted'});
});

function fingerprintedLibrary(kind) {
  const id = 'slide';
  // This is the exact content an old DTO can retain after loading the current
  // record. It intentionally has no knowledge of designFingerprint.
  const legacyBase = {id, name: 'MAIN', text: 'Run 200m', imageUrl: 'https://example.com/slide.png',
    workSeconds: 60, restSeconds: 0, sets: 1, showTimer: false,
    beep: true, coverImage: false, favorite: false, category: '', appearance: {}, intervalBlocks: [],
    designTemplate: 'studio-v1-list'};
  const current = {...legacyBase, designFingerprint: 'v1:visual-hash:asset-hash'};
  const path = `users/owner/slide${kind === 'templates' ? 'Templates' : 'Styles'}/${id}`;
  const indexPath = 'users/owner/libraryState/index';
  const documents = new Map([[path, {value: current}], [indexPath, {savedCount: 1, favoriteCount: 0}]]);
  const db = {
    doc: path => ({path}),
    collection: path => ({doc: id => ({path: `${path}/${id}`})}),
    runTransaction: async run => run({
      getAll: async (...refs) => refs.map(ref => ({exists: documents.has(ref.path), data: () => documents.get(ref.path)})),
      set: (ref, value, options) => documents.set(ref.path, options?.merge ? {...documents.get(ref.path), ...value} : value),
    }),
  };
  return {id, legacyBase, current, path, indexPath, documents, db};
}

for (const kind of ['templates', 'styles']) {
  for (const operation of ['update', 'delete']) {
    test(`old client can ${operation} fingerprinted ${kind} and retry a lost response`, async () => {
      const {id, legacyBase, current, path, indexPath, documents, db} = fingerprintedLibrary(kind);
      const value = operation === 'delete' ? null : {...legacyBase, name: 'UPDATED'};
      const request = {ownerId: 'owner', kind, changes: [{id, base: legacyBase, value}]};
      assert.deepEqual(normalizeLibraryValue(current), normalizeLibraryValue(legacyBase));
      assert.equal(current.designFingerprint, 'v1:visual-hash:asset-hash', 'comparison never mutates stored input');
      assert.equal((await mutateSlideLibrary(db, 'owner', request)).changed, 1);
      assert.deepEqual(documents.get(path).value, value);
      assert.equal(documents.get(path).deleted, operation === 'delete');
      if (kind === 'templates') {
        assert.equal(documents.get(indexPath).savedCount, operation === 'delete' ? 0 : 1);
      }
      assert.equal((await mutateSlideLibrary(db, 'owner', request)).changed, 0);
    });

    test(`old client ${operation} still rejects real content conflicts in ${kind}`, async () => {
      for (const change of [{name: 'Concurrent name'}, {imageUrl: 'https://example.com/new.png'}, {futureField: 'preserved'}]) {
        const {id, legacyBase, current, path, documents, db} = fingerprintedLibrary(kind);
        const concurrent = {...current, ...change};
        documents.set(path, {value: concurrent});
        const value = operation === 'delete' ? null : {...legacyBase, text: 'Run 400m'};
        await assert.rejects(mutateSlideLibrary(db, 'owner', {
          ownerId: 'owner', kind, changes: [{id, base: legacyBase, value}],
        }), {code: 'aborted'});
        assert.deepEqual(documents.get(path), {value: concurrent});
      }
    });
  }
}
