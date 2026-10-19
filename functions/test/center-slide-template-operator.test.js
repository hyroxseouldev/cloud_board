import assert from 'node:assert/strict';
import {mkdtempSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import test from 'node:test';
import {developmentProject, parseArgs, mergeCatalog, preparePng, resolveTarget, publishCatalog, verifyExistingAsset, ensureImmutableAsset, run} from '../tools/register-center-slide-templates.mjs';

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
    seed.filter((_, index) => ![5, 6].includes(index)), [...seed, '--image', 'private.png'],
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
