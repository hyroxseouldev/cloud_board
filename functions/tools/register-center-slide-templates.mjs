import {spawnSync, execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {mkdtempSync, readFileSync, rmSync, writeFileSync, statSync} from 'node:fs';
import {createRequire} from 'node:module';
import {tmpdir} from 'node:os';
import {dirname, isAbsolute, resolve} from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {isDeepStrictEqual} from 'node:util';

export const developmentProject = 'cloud-board-development';
const maxBytes = 768 * 1024;
const maxPngBytes = 10 * 1024 * 1024;
const idPattern = /^[A-Za-z0-9_-]{1,120}$/;
const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
export class OperatorError extends Error {}
const requireValue = (condition, message) => {if (!condition) throw new OperatorError(message);};
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
const usage = 'Usage: register-center-slide-templates.mjs --project cloud-board-development --email <existing account> (--file <catalog.json> | --seed-stationd --center-id <verified center> --revision <n> [--center-name <name>]) [--image <PNG> | --images <ID-to-PNG JSON>] [--replace] [--auth adc|firebase-cli] [--flutter <path>] [--output <new JSON file>] [--apply]';

export function parseArgs(args) {
  const value = {apply: false, replace: false, seed: false, auth: 'adc'};
  const seen = new Set();
  for (let i = 0; i < args.length; i++) {
    const flag = args[i];
    requireValue(!seen.has(flag), `Repeated option: ${flag}`);
    seen.add(flag);
    if (['--apply', '--replace', '--seed-stationd'].includes(flag)) {
      value[flag === '--seed-stationd' ? 'seed' : flag.slice(2)] = true;
    } else {
      requireValue(['--project', '--email', '--file', '--image', '--images', '--center-id', '--center-name', '--revision', '--auth', '--flutter', '--output'].includes(flag), usage);
      const next = args[++i];
      requireValue(next !== undefined && !next.startsWith('--'), `Missing value for ${flag}`);
      value[flag.slice(2)] = next;
    }
  }
  requireValue(value.project === developmentProject, 'This tool is restricted to the explicitly selected development project.');
  requireValue(typeof value.email === 'string' && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value.email), 'An explicit existing account email is required.');
  requireValue(Number(value.seed) + Number(Boolean(value.file)) === 1, usage);
  requireValue(['adc', 'firebase-cli'].includes(value.auth), 'Unsupported authentication method.');
  requireValue(!value.image || !value.images, '--image and --images are mutually exclusive.');
  if (value['center-id'] !== undefined) requireValue(idPattern.test(value['center-id']), 'Invalid expected center ID.');
  if (value.seed) {
    requireValue(value['center-id'], '--seed-stationd requires an explicitly verified target center ID.');
    requireValue(!value.image && !value.images, '--image/--images are only supported with a recipe catalog file.');
    requireValue(/^[1-9]\d*$/.test(value.revision || '') && Number.isSafeInteger(Number(value.revision)), 'Seed revision must be a positive safe integer.');
    value.revision = Number(value.revision);
  } else {
    requireValue(value.revision === undefined && value['center-name'] === undefined, 'Set revision and centerName in the catalog JSON.');
  }
  return value;
}

export function readCatalogFile(path) {
  requireValue(statSync(path).size <= maxBytes, 'Catalog JSON exceeds 768 KiB.');
  try {return JSON.parse(readFileSync(path, 'utf8'));}
  catch {throw new OperatorError('Catalog file is not valid JSON.');}
}

// JSON objects normally discard duplicate keys. Read this deliberately flat
// string-to-string manifest without allowing a repeated template ID to vanish.
export function readImageManifest(path) {
  requireValue(statSync(path).size <= maxBytes, 'Image manifest exceeds 768 KiB.');
  const source = readFileSync(path, 'utf8');
  let parsed;
  try {parsed = JSON.parse(source);} catch {throw new OperatorError('Image manifest is not valid JSON.');}
  requireValue(parsed !== null && typeof parsed === 'object' && !Array.isArray(parsed),
    'Image manifest must be a JSON object mapping template IDs to local PNG paths.');
  const entries = [];
  const seen = new Set();
  let position = 0;
  const whitespace = () => {while (/\s/.test(source[position] || '') && position < source.length) position++;};
  const string = () => {
    whitespace();
    requireValue(source[position] === '"', 'Image manifest IDs and paths must be strings.');
    const start = position++;
    while (position < source.length) {
      if (source[position] === '\\') {position += 2; continue;}
      if (source[position++] === '"') return JSON.parse(source.slice(start, position));
    }
    throw new OperatorError('Invalid image manifest string.');
  };
  whitespace(); position++; // JSON.parse and the object check established '{'.
  whitespace();
  while (source[position] !== '}') {
    const id = string();
    requireValue(idPattern.test(id) && !seen.has(id), 'Invalid or duplicate image template ID.');
    seen.add(id);
    whitespace();
    requireValue(source[position++] === ':', 'Invalid image manifest mapping.');
    const file = string();
    requireValue(file.length > 0 && !file.includes('\0') && !/^[A-Za-z][A-Za-z0-9+.-]*:/.test(file),
      'Image paths must be local file paths, not URLs.');
    entries.push([id, resolve(dirname(resolve(path)), file)]);
    whitespace();
    if (source[position] === '}') break;
    requireValue(source[position++] === ',', 'Invalid image manifest mapping.');
  }
  requireValue(entries.length > 0 && entries.length <= 100, 'Image manifest requires 1 to 100 PNG paths.');
  return Object.fromEntries(entries);
}

function header(value) {
  requireValue(value && value.schemaVersion === 1 && Number.isSafeInteger(value.revision) && value.revision > 0 &&
    typeof value.centerName === 'string' && Array.isArray(value.templates) && value.templates.length <= 100,
  'Unsupported catalog header; inspect schemaVersion, revision, centerName, and templates.');
}

export function mergeCatalog(current, incoming, replace = false) {
  header(incoming);
  if (current) header(current);
  const items = new Map(replace ? [] : (current?.templates || []).filter(item => item.published).map(item => [item.id, item]));
  const seen = new Set();
  for (const item of incoming.templates) {
    requireValue(item && idPattern.test(item.id) && !seen.has(item.id) && typeof item.published === 'boolean', 'Invalid or duplicate template ID/visibility.');
    seen.add(item.id);
    // Drafts remain local. Marking an existing ID unpublished removes its public
    // entry without deleting unrelated templates or the immutable original PNG.
    if (item.published) items.set(item.id, item);
    else items.delete(item.id);
  }
  return {...incoming, templates: [...items.values()].sort((a, b) => a.sortOrder - b.sortOrder || a.id.localeCompare(b.id))};
}

export function preparePng(catalog, bytes, centerId, templateId) {
  const candidates = catalog.templates.filter(item => item.published && item.recipe &&
    (templateId === undefined || item.id === templateId));
  requireValue(candidates.length === 1, 'Image requires exactly one matching published recipe in the input file.');
  requireValue(bytes.length >= 33 && bytes.length <= maxPngBytes &&
    bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])) &&
    bytes.readUInt32BE(8) === 13 && bytes.toString('ascii', 12, 16) === 'IHDR', 'Image must be a PNG no larger than 10 MiB.');
  const item = candidates[0], recipe = item.recipe;
  requireValue(recipe.centerId === centerId && recipe.templateId === item.id && idPattern.test(item.id), 'Image recipe target does not match the verified center/template.');
  requireValue(bytes.readUInt32BE(16) === recipe.width && bytes.readUInt32BE(20) === recipe.height, 'PNG dimensions do not match the recipe.');
  const digest = sha256(bytes), path = `center-templates/${centerId}/${item.id}/${digest}.png`;
  requireValue(!recipe.backgroundPath || recipe.backgroundPath === path, 'Recipe backgroundPath does not match the PNG hash.');
  requireValue(!recipe.backgroundSha256 || recipe.backgroundSha256 === digest, 'Recipe backgroundSha256 does not match the PNG.');
  const prepared = structuredClone(catalog);
  Object.assign(prepared.templates.find(value => value.id === item.id).recipe, {backgroundPath: path, backgroundSha256: digest});
  return {catalog: prepared, asset: {path, sha256: digest, bytes}};
}

export function prepareImages(catalog, images, centerId) {
  header(catalog);
  const ids = new Set();
  for (const item of catalog.templates) {
    requireValue(item && idPattern.test(item.id) && !ids.has(item.id) && typeof item.published === 'boolean',
      'Invalid or duplicate catalog template ID/visibility.');
    ids.add(item.id);
  }
  const recipes = catalog.templates.filter(item => item.published && item.recipe);
  const mapped = Object.entries(images);
  requireValue(mapped.length === recipes.length && mapped.length > 0 && mapped.every(([id]) =>
    recipes.some(item => item.id === id)),
  'Image manifest must map exactly the published recipes in the input catalog; no missing or extra IDs.');
  let prepared = catalog;
  const assets = [];
  for (const item of recipes) {
    const path = images[item.id];
    const info = statSync(path);
    requireValue(info.isFile() && info.size <= maxPngBytes, 'Each image must be a local PNG no larger than 10 MiB.');
    const result = preparePng(prepared, readFileSync(path), centerId, item.id);
    prepared = result.catalog;
    assets.push(result.asset);
  }
  return {catalog: prepared, assets};
}

// Catalog and recipe validation belongs to the same Dart models as the app.
// The renderer also decodes/validates an input PNG before any upload is allowed.
export function validateWithApp(catalog, {centerId, flutter: executable, image, images, seed, revision, centerName = ''} = {}) {
  const temporary = mkdtempSync(resolve(tmpdir(), 'center-slide-template-'));
  try {
    const input = resolve(temporary, 'input.json'), output = resolve(temporary, 'canonical.json');
    if (!seed) writeFileSync(input, JSON.stringify(catalog));
    requireValue(!image || !images, 'Cannot validate single and batch images together.');
    const imageManifest = images ? resolve(temporary, 'images.json') : '';
    if (images) writeFileSync(imageManifest, JSON.stringify(images));
    let flutter = executable || process.env.CLOUDBOARD_FLUTTER || 'flutter';
    if (flutter.includes('/') && !isAbsolute(flutter)) flutter = resolve(flutter);
    const result = spawnSync(flutter, ['test', 'tool/center_slide_template_export_test.dart', '--no-pub', '--reporter', 'compact'], {
      cwd: repoRoot, encoding: 'utf8', timeout: 180000, maxBuffer: 4 * 1024 * 1024,
      env: {...process.env, CENTER_CATALOG_INPUT: seed ? '' : input, CENTER_CATALOG_OUTPUT: output,
        CENTER_CATALOG_CENTER_ID: centerId, CENTER_CATALOG_SEED: seed ? 'stationd' : '',
        CENTER_CATALOG_REVISION: String(revision || ''), CENTER_CATALOG_CENTER_NAME: centerName,
        CENTER_CATALOG_IMAGE: image ? resolve(image) : '', CENTER_CATALOG_IMAGES: imageManifest},
    });
    requireValue(!result.error && result.status === 0, `App catalog/PNG validation failed; nothing was uploaded.\n${result.error?.message || `${result.stdout || ''}\n${result.stderr || ''}`.slice(-4000)}`);
    return JSON.parse(readFileSync(output, 'utf8'));
  } finally {rmSync(temporary, {recursive: true, force: true});}
}

export async function resolveTarget(auth, db, email, expectedCenterId) {
  const user = await auth.getUserByEmail(email);
  requireValue(!user.disabled && typeof user.uid === 'string' && user.providerData?.length > 0, 'Target must be an active, non-anonymous existing account.');
  const [lock, progress] = await db.getAll(db.doc(`accountDeletions/${user.uid}`), db.doc(`users/${user.uid}/onboarding/progress`));
  requireValue(!lock.exists, 'Account deletion is pending.');
  const centerId = progress.data()?.storeId;
  requireValue(typeof centerId === 'string' && idPattern.test(centerId), 'Existing onboarding center was not found; no account or center will be created.');
  requireValue(!expectedCenterId || centerId === expectedCenterId, 'Resolved center differs from the explicitly verified center.');
  const center = await db.doc(`centers/${centerId}`).get();
  requireValue(center.data()?.ownerUid === user.uid, 'Center ownership does not match the requested account.');
  return {uid: user.uid, centerId};
}

function verifyAssetMetadata(metadata, asset) {
  requireValue(metadata.contentType === 'image/png' && Number(metadata.size) > 0 && Number(metadata.size) <= maxPngBytes &&
    metadata.metadata?.sha256 === asset.sha256 && !metadata.metadata?.firebaseStorageDownloadTokens,
  'Existing template PNG has invalid metadata or a public download token.');
}

export async function verifyExistingAsset(bucket, asset) {
  const file = bucket.file(asset.path);
  const [metadata] = await file.getMetadata();
  verifyAssetMetadata(metadata, asset);
  if (asset.bytes) requireValue(Number(metadata.size) === asset.bytes.length,
    'Existing immutable PNG has a different byte length.');
  const [bytes] = await file.download();
  requireValue(bytes.length === Number(metadata.size) && bytes.length <= maxPngBytes && sha256(bytes) === asset.sha256,
    'Existing immutable PNG contents do not match its hash.');
}

export async function ensureImmutableAsset(bucket, asset) {
  const file = bucket.file(asset.path);
  try {
    await file.save(asset.bytes, {resumable: false, preconditionOpts: {ifGenerationMatch: 0},
      metadata: {contentType: 'image/png', cacheControl: 'private, max-age=0', metadata: {sha256: asset.sha256}}});
  } catch (error) {
    // A lost upload response is retry-safe only if the actual stored bytes match.
    if (Number(error.code) !== 412) throw error;
  }
  await verifyExistingAsset(bucket, asset);
}

export async function publishCatalog(db, target, expected, candidate) {
  header(candidate);
  const ref = db.doc(`centers/${target.centerId}/slideTemplateCatalog/current`);
  return db.runTransaction(async tx => {
    const [lock, progress, center, snapshot] = await tx.getAll(db.doc(`accountDeletions/${target.uid}`),
      db.doc(`users/${target.uid}/onboarding/progress`), db.doc(`centers/${target.centerId}`), ref);
    requireValue(!lock.exists && progress.data()?.storeId === target.centerId && center.data()?.ownerUid === target.uid,
      'Account/center ownership changed before publication.');
    const current = snapshot.exists ? snapshot.data() : null;
    if (current) header(current);
    if (isDeepStrictEqual(current, candidate)) return 'unchanged';
    requireValue(isDeepStrictEqual(current, expected), 'Catalog changed after validation; rerun to merge the current version.');
    requireValue(!current || candidate.revision > current.revision, 'Catalog revision must increase; increment it for edits or rollback.');
    tx.set(ref, candidate);
    return 'published';
  });
}

// Each client uses the Google Auth major bundled with its own transport.
// firebase-admin Auth accepts a refreshable CLI credential, while its Firestore
// and Storage wrappers only accept ADC/service-account credentials.
async function bridgeCliCredential(moduleName, credential, projectId) {
  const require = createRequire(import.meta.resolve(moduleName));
  const {OAuth2Client, GoogleAuth} = require('google-auth-library');
  const authClient = new OAuth2Client();
  authClient.refreshHandler = async () => {
    const token = await credential.getAccessToken();
    return {access_token: token.access_token, expiry_date: Date.now() + token.expires_in * 1000};
  };
  authClient.setCredentials(await authClient.refreshHandler());
  return new GoogleAuth({projectId, authClient});
}

export async function openServices(options) {
  requireValue(!process.env.FIRESTORE_EMULATOR_HOST && !process.env.FIREBASE_AUTH_EMULATOR_HOST &&
    !process.env.FIREBASE_STORAGE_EMULATOR_HOST && !process.env.STORAGE_EMULATOR_HOST,
    'Unset emulator endpoints before using the explicit development project.');
  const {initializeApp, applicationDefault, deleteApp} = await import('firebase-admin/app');
  const {getAuth} = await import('firebase-admin/auth');
  let credential;
  if (options.auth === 'firebase-cli') {
    const globalRoot = execFileSync('npm', ['root', '-g'], {encoding: 'utf8'}).trim();
    const require = createRequire(resolve(globalRoot, 'firebase-tools/package.json'));
    const auth = require('./lib/auth');
    credential = {getAccessToken: async () => {
      const account = auth.getGlobalDefaultAccount();
      requireValue(account?.tokens?.refresh_token, 'Run firebase login or use Application Default Credentials.');
      const token = await auth.getAccessToken(account.tokens.refresh_token, ['https://www.googleapis.com/auth/cloud-platform']);
      return {access_token: token.access_token, expires_in: token.expires_at ?
        Math.max(1, Math.floor((token.expires_at - Date.now()) / 1000)) : 3600};
    }};
  } else credential = applicationDefault();
  const bucketName = `${options.project}.firebasestorage.app`;
  const app = initializeApp({projectId: options.project, storageBucket: bucketName, credential});
  try {
    if (options.auth === 'firebase-cli') {
      const [{Firestore}, {Storage}, firestoreAuth, storageAuth] = await Promise.all([
        import('@google-cloud/firestore'), import('@google-cloud/storage'),
        bridgeCliCredential('google-gax', credential, options.project),
        bridgeCliCredential('@google-cloud/storage', credential, options.project),
      ]);
      const db = new Firestore({projectId: options.project, preferRest: true, auth: firestoreAuth});
      const bucket = new Storage({projectId: options.project, authClient: storageAuth}).bucket(bucketName);
      return {auth: getAuth(app), db, bucket, close: async () => {try {await db.terminate();} finally {await deleteApp(app);}}};
    }
    const [{getFirestore}, {getStorage}] = await Promise.all([import('firebase-admin/firestore'), import('firebase-admin/storage')]);
    return {auth: getAuth(app), db: getFirestore(app), bucket: getStorage(app).bucket(), close: () => deleteApp(app)};
  } catch (error) {await deleteApp(app); throw error;}
}

export async function run(args, {open = openServices, validate = validateWithApp, log = console.log} = {}) {
  const options = parseArgs(args);
  let incoming = options.file ? readCatalogFile(options.file) : null;
  if (incoming) header(incoming);
  const images = options.images ? readImageManifest(options.images) : null;
  const services = await open(options);
  try {
    const {auth, db, bucket} = services;
    const target = await resolveTarget(auth, db, options.email, options['center-id']);
    const validation = {centerId: target.centerId, flutter: options.flutter};
    if (options.seed) incoming = validate(null, {...validation, seed: true, revision: options.revision, centerName: options['center-name'] || ''});
    let assets = [];
    if (images) {
      ({catalog: incoming, assets} = prepareImages(incoming, images, target.centerId));
    } else if (options.image) {
      requireValue(statSync(options.image).size <= maxPngBytes, 'Image exceeds 10 MiB.');
      const prepared = preparePng(incoming, readFileSync(options.image), target.centerId);
      incoming = prepared.catalog;
      assets = [prepared.asset];
    }
    incoming = validate(incoming, {...validation, image: options.image, images});
    const ref = db.doc(`centers/${target.centerId}/slideTemplateCatalog/current`);
    const snapshot = await ref.get(), current = snapshot.exists ? snapshot.data() : null;
    if (current) header(current);
    const validatedCurrent = current ? validate(current, validation) : null;
    const candidate = validate(mergeCatalog(validatedCurrent, incoming, options.replace), validation);
    requireValue(!current || isDeepStrictEqual(candidate, current) || candidate.revision > current.revision,
      'Catalog revision must increase before publication.');
    const preparedPaths = new Set(assets.map(asset => asset.path));
    for (const entry of incoming.templates.filter(item => item.published)) {
      const recipe = entry.recipe;
      if (recipe?.backgroundPath && !preparedPaths.has(recipe.backgroundPath)) {
        await verifyExistingAsset(bucket, {path: recipe.backgroundPath, sha256: recipe.backgroundSha256});
      }
    }
    if (options.output) writeFileSync(resolve(options.output), `${JSON.stringify(candidate, null, 2)}\n`, {flag: 'wx'});
    if (!options.apply) {
      const result = {status: 'dry-run', project: options.project, centerId: target.centerId, revision: candidate.revision,
        templates: candidate.templates.length, imageUpload: assets.length > 0, imageCount: assets.length, replaced: options.replace, writes: 0};
      log(JSON.stringify(result));
      return result;
    }
    // Reconfirm the same account-center binding before touching the new asset.
    const confirmed = await resolveTarget(auth, db, options.email, target.centerId);
    requireValue(confirmed.uid === target.uid, 'Target account changed before publication.');
    // Every mapping, PNG, sample render, merge and revision check has succeeded.
    // An interrupted batch may leave private objects, but never a partial catalog.
    for (const asset of assets) await ensureImmutableAsset(bucket, asset);
    const status = await publishCatalog(db, target, current, candidate);
    const result = {status, project: options.project, centerId: target.centerId, revision: candidate.revision, templates: candidate.templates.length, imageCount: assets.length};
    log(JSON.stringify(result));
    return result;
  } finally {await services.close();}
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  run(process.argv.slice(2)).catch(error => {
    // Third-party auth/HTTP diagnostics can contain credential material.
    console.error(error instanceof OperatorError ? error.message : `Operator failed (${String(error.code || error.name || 'unknown').replace(/[^A-Za-z0-9/_-]/g, '')}). No credential details were printed.`);
    process.exitCode = 1;
  });
}
