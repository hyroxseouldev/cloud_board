import assert from 'node:assert/strict';
import {mkdtempSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import test from 'node:test';
import {developmentProject, parseArgs, mergeCatalog, preparePng, readImageManifest, prepareImages, resolveTarget, publishCatalog, verifyExistingAsset, ensureImmutableAsset, run} from '../tools/register-center-slide-templates.mjs';

const args = ['--project', developmentProject, '--email', 'owner@example.test', '--file', 'catalog.json'];
const entry = (id, extra = {}) => ({id, name: id, description: '', sortOrder: 0, published: true, originalTemplateId: 'stationd-mon-v1', ...extra});
const catalog = (revision = 1, templates = [entry('one')]) => ({schemaVersion: 1, revision, centerName: '', templates});
function services(current = null) {
  const state = {current, uid: 'owner', centerId: 'center-one', owner: 'owner', deleting: false, writes: 0, uploads: 0, closed: 0};
  const snapshot = path => {
    const value = path.startsWith('accountDeletions/') ? (state.deleting ? {} : null) :
      path.endsWith('/onboarding/progress') ? (state.centerId ? {storeId: state.centerId} : null) :
        path.endsWith('/slideTemplateCatalog/current') ? state.current : {ownerUid: state.owner};
    return {exists: value !== null, data: () => value};
  };
  const db = {
    doc: path => ({path, get: async () => snapshot(path)}),
    getAll: async (...refs) => refs.map(ref => snapshot(ref.path)),
    runTransaction: async work => work({
      getAll: async (...refs) => refs.map(ref => snapshot(ref.path)),
      set: (ref, value) => {assert.equal(ref.path, 'centers/center-one/slideTemplateCatalog/current'); state.writes++; state.current = value;},
    }),
  };
  const auth = {getUserByEmail: async () => ({uid: state.uid, disabled: false, providerData: [{providerId: 'password'}]})};
  const bucket = {file: () => ({save: async () => {state.uploads++;}, getMetadata: async () => {throw new Error('Unexpected asset read');}})};
  return {state, auth, db, bucket, close: async () => {state.closed++;}};
}
const target = {uid: 'owner', centerId: 'center-one'};

test('CLI is development-only, dry-run by default, and requires explicit seed mapping', () => {
  assert.equal(parseArgs(args).apply, false);
  assert.equal(parseArgs(args).auth, 'adc');
  const seed = ['--project', developmentProject, '--email', 'owner@example.test', '--seed-stationd', '--center-id', 'center-one', '--revision', '1'];
  assert.equal(parseArgs(seed).seed, true);
  for (const values of [[], [...args, '--apply', '--apply'], [...args, '--unknown'],
    [...args, '--seed-stationd'], [...args, '--revision', '2'], [...args, '--auth', 'unsafe'],
    ['--project', 'cloud-board-stationd', '--email', 'owner@example.test', '--file', 'file.json'],
    seed.filter((_, index) => ![5, 6].includes(index)), [...seed, '--image', 'private.png'], [...seed, '--images', 'images.json'],
    [...args, '--image', 'one.png', '--images', 'images.json'],
    [...seed.slice(0, -1), '0'], [...seed.slice(0, -1), '9007199254740992'],
  ]) assert.throws(() => parseArgs(values));
});

test('merge preserves other templates, hides drafts, and replaces only explicitly', () => {
  const before = catalog(1, [entry('one'), entry('two'), entry('three')]);
  const input = catalog(2, [entry('one', {name: 'Changed'}), entry('two', {published: false})]);
  assert.deepEqual(mergeCatalog(before, input).templates.map(item => item.id), ['one', 'three']);
  assert.equal(mergeCatalog(before, input).templates[0].name, 'Changed');
  assert.deepEqual(mergeCatalog(before, input, true).templates.map(item => item.id), ['one']);
  assert.throws(() => mergeCatalog(before, catalog(2, [entry('one'), entry('one')])));
  assert.throws(() => mergeCatalog({...before, schemaVersion: 2}, input));
});

test('target resolution requires existing account center ownership without provisioning', async () => {
  const s = services();
  assert.deepEqual(await resolveTarget(s.auth, s.db, 'owner@example.test'), target);
  await assert.rejects(resolveTarget(s.auth, s.db, 'owner@example.test', 'other-center'), /differs/);
  s.state.owner = 'stranger';
  await assert.rejects(resolveTarget(s.auth, s.db, 'owner@example.test'), /ownership/);
  s.state.owner = 'owner'; s.state.deleting = true;
  await assert.rejects(resolveTarget(s.auth, s.db, 'owner@example.test'), /deletion/);
  s.state.deleting = false; s.state.centerId = null;
  await assert.rejects(resolveTarget(s.auth, s.db, 'owner@example.test'), /not found/);
  assert.equal(s.state.writes, 0);
});

test('PNG preparation binds actual bytes and dimensions to the verified center', () => {
  const bytes = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII=', 'base64');
  const input = catalog(1, [entry('custom', {originalTemplateId: undefined, recipe: {centerId: 'center-one', templateId: 'custom', width: 1, height: 1}})]);
  const prepared = preparePng(input, bytes, 'center-one');
  const hash = createHash('sha256').update(bytes).digest('hex');
  assert.equal(prepared.asset.path, `center-templates/center-one/custom/${hash}.png`);
  assert.equal(prepared.catalog.templates[0].recipe.backgroundSha256, hash);
  assert.equal(input.templates[0].recipe.backgroundPath, undefined);
  assert.throws(() => preparePng(input, bytes, 'stranger-center'), /target/);
  assert.throws(() => preparePng(input, Buffer.from('not PNG'), 'center-one'), /PNG/);
  const mismatch = structuredClone(input); mismatch.templates[0].recipe.width = 2;
  assert.throws(() => preparePng(mismatch, bytes, 'center-one'), /dimensions/);
  const pathMismatch = structuredClone(input); pathMismatch.templates[0].recipe.backgroundPath = 'outside/source.png';
  assert.throws(() => preparePng(pathMismatch, bytes, 'center-one'), /backgroundPath/);
});

test('publication is monotonic, retry-safe, and rejects concurrent catalog changes', async () => {
  const s = services();
  assert.equal(await publishCatalog(s.db, target, null, catalog()), 'published');
  assert.equal(await publishCatalog(s.db, target, null, catalog()), 'unchanged');
  assert.equal(s.state.writes, 1);
  await assert.rejects(publishCatalog(s.db, target, catalog(), catalog(1, [entry('two')])), /increase/);
  await assert.rejects(publishCatalog(s.db, target, null, catalog(2)), /changed after/);
  assert.equal(await publishCatalog(s.db, target, catalog(), catalog(2)), 'published');
  assert.equal(s.state.writes, 2);
});

test('publication rechecks ownership/deletion and rejects unknown existing schema', async () => {
  for (const mutate of [s => {s.owner = 'stranger';}, s => {s.deleting = true;}, s => {s.centerId = 'elsewhere';}]) {
    const s = services(catalog()); mutate(s.state);
    await assert.rejects(publishCatalog(s.db, target, catalog(), catalog(2)), /ownership changed/);
    assert.equal(s.state.writes, 0);
  }
  const s = services({...catalog(), schemaVersion: 2});
  await assert.rejects(publishCatalog(s.db, target, s.state.current, catalog(2)), /Unsupported/);
  assert.equal(s.state.writes, 0);
});

test('dry-run resolves and validates but never uploads or publishes', async () => {
  const directory = mkdtempSync(join(tmpdir(), 'center-template-test-'));
  const file = join(directory, 'catalog.json');
  writeFileSync(file, JSON.stringify(catalog()));
  const s = services();
  let validations = 0;
  try {
    const result = await run([...args.slice(0, -1), file], {open: async () => s, validate: value => {validations++; return value;}, log: () => {}});
    assert.equal(result.status, 'dry-run');
    assert.equal(validations, 2);
    assert.equal(s.state.writes, 0); assert.equal(s.state.uploads, 0); assert.equal(s.state.closed, 1);
    await assert.rejects(run([...args.slice(0, -1), file, '--apply'], {open: async () => s,
      validate: () => {throw new Error('invalid recipe');}, log: () => {}}), /invalid recipe/);
    assert.equal(s.state.writes, 0); assert.equal(s.state.uploads, 0);
  } finally {rmSync(directory, {recursive: true, force: true});}
});

test('immutable uploads never overwrite and reject public tokens or forged contents', async () => {
  const bytes = Buffer.from('validated PNG bytes'), hash = createHash('sha256').update(bytes).digest('hex');
  const asset = {path: `center-templates/center-one/custom/${hash}.png`, sha256: hash, bytes};
  let exists = false, stored = bytes, publicToken;
  const bucket = {file: path => {
    assert.equal(path, asset.path);
    return {
      save: async (_, options) => {
        assert.equal(options.preconditionOpts.ifGenerationMatch, 0);
        assert.equal(options.metadata.metadata.firebaseStorageDownloadTokens, undefined);
        if (exists) throw Object.assign(new Error('exists'), {code: 412});
        exists = true;
      },
      getMetadata: async () => [{contentType: 'image/png', size: bytes.length, metadata: {sha256: hash, firebaseStorageDownloadTokens: publicToken}}],
      download: async () => [stored],
    };
  }};
  await ensureImmutableAsset(bucket, asset);
  await ensureImmutableAsset(bucket, asset);
  publicToken = 'shared-token';
  await assert.rejects(ensureImmutableAsset(bucket, asset), /public download token/);
  publicToken = undefined; stored = Buffer.from('forged PNG contents');
  await assert.rejects(ensureImmutableAsset(bucket, asset), /contents/);
});

// Metadata alone cannot make an existing object safe to reference in a new catalog.
test('existing asset references validate stored bytes, not a claimed metadata hash', async () => {
  const bytes = Buffer.from('approved PNG contents'), hash = createHash('sha256').update(bytes).digest('hex');
  const asset = {path: `center-templates/center-one/custom/${hash}.png`, sha256: hash};
  let stored = bytes;
  const bucket = {file: () => ({
    getMetadata: async () => [{contentType: 'image/png', size: stored.length, metadata: {sha256: hash}}],
    download: async () => [stored],
  })};
  await verifyExistingAsset(bucket, asset);
  stored = Buffer.from('tampered PNG contents');
  await assert.rejects(verifyExistingAsset(bucket, asset), /contents/);
});


const smallPng = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII=', 'base64');
const recipeEntry = id => entry(id, {originalTemplateId: undefined,
  recipe: {schemaVersion: 2, revision: 1, centerId: 'center-one', templateId: id, width: 1, height: 1}});
function batchFixture() {
  const directory = mkdtempSync(join(tmpdir(), 'center-template-batch-'));
  const file = join(directory, 'catalog.json'), manifest = join(directory, 'images.json');
  const input = catalog(3, [recipeEntry('one'), recipeEntry('two')]);
  const images = {one: join(directory, 'one.png'), two: join(directory, 'two.png')};
  writeFileSync(file, JSON.stringify(input));
  writeFileSync(manifest, JSON.stringify({one: 'one.png', two: 'two.png'}));
  for (const image of Object.values(images)) writeFileSync(image, smallPng);
  return {directory, file, manifest, input, images,
    args: [...args.slice(0, -1), file, '--images', manifest],
    close: () => rmSync(directory, {recursive: true, force: true})};
}
function memoryAssets(s, beforeSave = () => {}) {
  const stored = new Map();
  let attempts = 0;
  s.bucket = {file: path => ({
    save: async (bytes, options) => {
      beforeSave({path, attempt: ++attempts});
      assert.equal(options.preconditionOpts.ifGenerationMatch, 0);
      assert.equal(options.metadata.metadata.firebaseStorageDownloadTokens, undefined);
      if (stored.has(path)) throw Object.assign(new Error('exists'), {code: 412});
      stored.set(path, {bytes: Buffer.from(bytes), metadata: {...options.metadata, size: bytes.length}});
      s.state.uploads++;
    },
    getMetadata: async () => [stored.get(path)?.metadata || assert.fail('Unexpected missing object read')],
    download: async () => [stored.get(path)?.bytes || assert.fail('Unexpected missing object read')],
  })};
  return stored;
}

test('image manifests preserve local paths and reject duplicate, malformed, or remote mappings', () => {
  const f = batchFixture();
  try {
    assert.equal(parseArgs(f.args).images, f.manifest);
    assert.deepEqual(readImageManifest(f.manifest), f.images);
    // Escaped JSON IDs must not bypass duplicate-key detection.
    for (const raw of ['{}', '[]', 'null', '{"one":true}', '{"one":null}',
      '{"one":"a.png","one":"b.png"}', '{"one":"a.png","\\u006fne":"b.png"}',
      '{"one":"https://example.test/one.png"}', '{"one":"file:///one.png"}',
      '{"one":""}', '{"bad/id":"one.png"}', '{"one":"one.png",}',
    ]) {
      writeFileSync(f.manifest, raw);
      assert.throws(() => readImageManifest(f.manifest), undefined, raw);
    }
    writeFileSync(f.manifest, JSON.stringify({one: 'folder/quoted"name.png', two: 'space name.png'}));
    assert.deepEqual(readImageManifest(f.manifest), {one: join(f.directory, 'folder/quoted"name.png'), two: join(f.directory, 'space name.png')});
  } finally {f.close();}
});

test('batch preparation binds each PNG to its recipe and requires complete visible-recipe mappings', () => {
  const f = batchFixture();
  try {
    const prepared = prepareImages(f.input, f.images, 'center-one');
    assert.equal(prepared.assets.length, 2);
    for (const item of prepared.catalog.templates) {
      assert.match(item.recipe.backgroundPath, new RegExp(`^center-templates/center-one/${item.id}/[a-f0-9]{64}\\.png$`));
    }
    assert.equal(f.input.templates[0].recipe.backgroundPath, undefined);
    for (const mapping of [{one: f.images.one}, {...f.images, extra: f.images.one}, {one: f.images.one, missing: f.images.two}]) {
      assert.throws(() => prepareImages(f.input, mapping, 'center-one'), /exactly/);
    }
    const hidden = structuredClone(f.input); hidden.templates[1].published = false;
    assert.throws(() => prepareImages(hidden, f.images, 'center-one'), /exactly/);
    const duplicate = catalog(3, [recipeEntry('one'), recipeEntry('one')]);
    assert.throws(() => prepareImages(duplicate, {one: f.images.one}, 'center-one'), /duplicate/);
  } finally {f.close();}
});

test('batch dry-run shares all image mappings with the app validator and never writes', async () => {
  const f = batchFixture(), s = services(catalog(2, [entry('untouched')]));
  let imagesValidated = false;
  try {
    const result = await run(f.args, {open: async () => s, log: () => {}, validate: (value, options) => {
      if (options.images) {
        assert.deepEqual(options.images, f.images);
        assert.equal(value.templates.filter(item => item.recipe?.backgroundSha256).length, 2);
        imagesValidated = true;
      }
      return value;
    }});
    assert.equal(imagesValidated, true);
    assert.equal(result.status, 'dry-run');
    assert.equal(result.imageCount, 2);
    assert.equal(result.templates, 3);
    assert.equal(s.state.uploads, 0); assert.equal(s.state.writes, 0);
  } finally {f.close();}
});

test('all mapping, PNG, shared-renderer and revision failures precede the first upload', async () => {
  const cases = ['missing', 'extra', 'invalid-last-png', 'wrong-center', 'renderer', 'old-revision'];
  for (const failure of cases) {
    const f = batchFixture(), s = services(catalog(2, [entry('untouched')]));
    memoryAssets(s);
    if (failure === 'missing') writeFileSync(f.manifest, JSON.stringify({one: 'one.png'}));
    if (failure === 'extra') writeFileSync(f.manifest, JSON.stringify({...f.images, extra: f.images.one}));
    if (failure === 'invalid-last-png') writeFileSync(f.images.two, 'not a PNG');
    if (failure === 'wrong-center') {
      f.input.templates[1].recipe.centerId = 'another-center';
      writeFileSync(f.file, JSON.stringify(f.input));
    }
    if (failure === 'old-revision') {
      f.input.revision = 2;
      writeFileSync(f.file, JSON.stringify(f.input));
    }
    try {
      await assert.rejects(run([...f.args, '--apply'], {open: async () => s, log: () => {}, validate: (value, options) => {
        if (failure === 'renderer' && options.images) throw new Error('second image sample does not fit');
        return value;
      }}));
      assert.equal(s.state.uploads, 0, failure);
      assert.equal(s.state.writes, 0, failure);
      assert.equal(s.state.current.revision, 2, failure);
    } finally {f.close();}
  }
});

test('one batch publishes once, preserves other templates, and exact retries remain unchanged', async () => {
  const f = batchFixture(), s = services(catalog(2, [entry('one'), entry('two'), entry('untouched')]));
  let allImagesValidated = false;
  const stored = memoryAssets(s, () => assert.equal(allImagesValidated, true));
  const dependencies = {open: async () => s, log: () => {}, validate: (value, options) => {
    if (options.images) allImagesValidated = true;
    return value;
  }};
  try {
    const first = await run([...f.args, '--apply'], dependencies);
    assert.equal(first.status, 'published');
    assert.equal(first.imageCount, 2);
    assert.equal(s.state.uploads, 2); assert.equal(s.state.writes, 1);
    assert.equal(s.state.current.revision, 3);
    assert.equal(s.state.current.templates.length, 3);
    assert.ok(s.state.current.templates.find(item => item.id === 'untouched').originalTemplateId);
    assert.equal(s.state.current.templates.filter(item => item.recipe).length, 2);
    const second = await run([...f.args, '--apply'], dependencies);
    assert.equal(second.status, 'unchanged');
    assert.equal(s.state.uploads, 2); assert.equal(s.state.writes, 1);
    assert.equal(stored.size, 2);
  } finally {f.close();}
});

test('a failed later upload leaves the old catalog intact and retry completes atomically', async () => {
  const f = batchFixture(), s = services(catalog(2, [entry('untouched')]));
  let fail = true;
  memoryAssets(s, ({attempt}) => {if (fail && attempt === 2) throw new Error('temporary second upload failure');});
  const dependencies = {open: async () => s, log: () => {}, validate: value => value};
  try {
    await assert.rejects(run([...f.args, '--apply'], dependencies), /second upload/);
    assert.equal(s.state.uploads, 1); assert.equal(s.state.writes, 0);
    assert.equal(s.state.current.revision, 2);
    fail = false;
    assert.equal((await run([...f.args, '--apply'], dependencies)).status, 'published');
    assert.equal(s.state.uploads, 2); assert.equal(s.state.writes, 1);
    assert.equal(s.state.current.templates.length, 3);
  } finally {f.close();}
});

test('batch rechecks ownership before uploads and rejects a concurrent catalog publication', async () => {
  const f = batchFixture();
  try {
    const changedOwner = services(catalog(2, [entry('untouched')]));
    memoryAssets(changedOwner);
    await assert.rejects(run([...f.args, '--apply'], {open: async () => changedOwner, log: () => {}, validate: (value, options) => {
      if (options.images) changedOwner.state.owner = 'stranger';
      return value;
    }}), /ownership/);
    assert.equal(changedOwner.state.uploads, 0); assert.equal(changedOwner.state.writes, 0);
    const changedCatalog = services(catalog(2, [entry('untouched')]));
    memoryAssets(changedCatalog, ({attempt}) => {if (attempt === 2) changedCatalog.state.current = catalog(4, [entry('newer')]);});
    await assert.rejects(run([...f.args, '--apply'], {open: async () => changedCatalog, log: () => {}, validate: value => value}), /changed after/);
    assert.equal(changedCatalog.state.writes, 0);
    assert.equal(changedCatalog.state.current.revision, 4);
  } finally {f.close();}
});

test('legacy single-image and explicit seed invocations keep their validation paths', async () => {
  const f = batchFixture();
  try {
    writeFileSync(f.file, JSON.stringify(catalog(1, [recipeEntry('one')])));
    const single = services();
    memoryAssets(single);
    let singleValidated = false;
    const result = await run([...args.slice(0, -1), f.file, '--image', f.images.one, '--apply'], {
      open: async () => single, log: () => {}, validate: (value, options) => {
        if (options.image) {assert.equal(options.image, f.images.one); assert.equal(options.images, null); singleValidated = true;}
        return value;
      },
    });
    assert.equal(singleValidated, true); assert.equal(result.status, 'published');
    assert.equal(single.state.uploads, 1); assert.equal(single.state.writes, 1);
    const seed = services();
    let seedValidated = false;
    await run(['--project', developmentProject, '--email', 'owner@example.test', '--seed-stationd',
      '--center-id', 'center-one', '--revision', '1'], {open: async () => seed, log: () => {}, validate: (value, options) => {
      if (options.seed) {seedValidated = true; return catalog(options.revision);}
      return value;
    }});
    assert.equal(seedValidated, true); assert.equal(seed.state.uploads, 0); assert.equal(seed.state.writes, 0);
  } finally {f.close();}
});

test('local-only catalog preparation never opens credentials or services', async () => {
  const directory = mkdtempSync(join(tmpdir(), 'center-local-only-'));
  try {
    const input = join(directory, 'input.json'), output = join(directory, 'output.json');
    writeFileSync(input, JSON.stringify(catalog()));
    const result = await run(['--local-only', '--file', input, '--center-id', 'center-one', '--output', output], {
      open: () => { throw new Error('Local-only must not open external services'); },
      validate: value => value, log: () => {},
    });
    assert.equal(result.status, 'local-only');
    assert.equal(result.network, false);
    assert.equal(result.writes, 0);
    assert.throws(() => parseArgs(['--local-only', '--apply', '--file', input, '--center-id', 'center-one', '--output', output]));
  } finally { rmSync(directory, {recursive: true, force: true}); }
});

test('thumbnail preparation binds dimensions, revision and exact content hash', async () => {
  const {prepareThumbnails} = await import('../tools/register-center-slide-templates.mjs');
  const directory = mkdtempSync(join(tmpdir(), 'center-thumbnail-'));
  try {
    // Header contract is checked here; the app validator additionally decodes PNG.
    const bytes = Buffer.alloc(33);
    Buffer.from([137,80,78,71,13,10,26,10]).copy(bytes);
    bytes.writeUInt32BE(13, 8); bytes.write('IHDR', 12);
    bytes.writeUInt32BE(640, 16); bytes.writeUInt32BE(360, 20);
    const digest = createHash('sha256').update(bytes).digest('hex');
    const path = join(directory, 'thumbnail.png'); writeFileSync(path, bytes);
    const thumbnail = {path: `center-templates/center-one/custom/${digest}.png`, sha256: digest, revision: 2, width: 640, height: 360};
    const input = catalog(2, [entry('custom', {originalTemplateId: undefined,
      recipe: {centerId: 'center-one', templateId: 'custom', revision: 2, thumbnail}})]);
    const assets = prepareThumbnails(input, {custom: path}, 'center-one');
    assert.equal(assets.length, 1);
    assert.equal(assets[0].path, thumbnail.path);
    assert.throws(() => prepareThumbnails(input, {custom: path}, 'other-center'));
    input.templates[0].recipe.thumbnail.revision = 1;
    assert.throws(() => prepareThumbnails(input, {custom: path}, 'center-one'));
  } finally { rmSync(directory, {recursive: true, force: true}); }
});
