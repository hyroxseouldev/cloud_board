// Resolve an existing first-slide image from authoritative documents, never a
// client URL. This is a rendition source, NOT an enrolled/original media asset.
import {hashBytes, IMAGE_MAX_BYTES, usageFailure, validId, validSha} from './managed-image-assets.js';
import {ownedWorkoutImage} from './workout-image-budget.js';

const deny = () => { throw usageFailure('media_lease_invalid', 'permission-denied'); };
const millis = value => Math.floor(typeof value?.toMillis === 'function' ? value.toMillis() : value);
const documentRevision = value => Number.isInteger(value?.seconds) && Number.isInteger(value?.nanoseconds)
  ? `${value.seconds}:${value.nanoseconds}` : `ms:${value}`;
const validWorkoutId = value => typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value);
export function legacyHomeRequest(query) {
  if (Object.keys(query).some(k => !['rendition','workoutId','sourceHash','updatedAtMs'].includes(k)) ||
      query.rendition !== 'home-v1' || !validWorkoutId(query.workoutId) || !validSha(query.sourceHash) ||
      typeof query.updatedAtMs !== 'string' || !/^(0|[1-9][0-9]{0,14})$/.test(query.updatedAtMs) ||
      Number(query.updatedAtMs) > 253402300799999) throw usageFailure('media_lease_invalid', 'invalid-argument');
  return {workoutId:query.workoutId, sourceHash:query.sourceHash, updatedAtMs:Number(query.updatedAtMs)};
}

export function legacyHomePath(ctx, ownerId, source) {
  if (!validId(ownerId) || typeof source !== 'string' || source.length > 4096) return null;
  let url;
  try { url = new URL(source); } catch { return null; }
  // Standard Firebase download URLs, or explicitly configured demo Storage.
  // Download tokens are only part of source identity; they grant no permission.
  const host = ctx.emulator === true && /^demo-/.test(ctx.projectId ?? '')
    ? process.env.FIREBASE_STORAGE_EMULATOR_HOST : null;
  const emulatorHost = /^(127\.0\.0\.1|localhost):[0-9]+$/.test(host ?? '') ? host : null;
  if (url.hash || url.username || url.password ||
      [...url.searchParams.keys()].some(k => !['alt','token'].includes(k)) ||
      ['alt','token'].some(k => url.searchParams.getAll(k).length > 1) ||
      url.searchParams.has('alt') && url.searchParams.get('alt') !== 'media') return null;
  const path = ownedWorkoutImage(source, ownerId, ctx.bucket.name, emulatorHost);
  if (!path) return null;
  const parts = path.split('/');
  if (!validWorkoutId(parts[3])) return null;
  const contentAddressed = parts.length === 6 && parts[4] === 'images' && /^[a-f0-9]{64}$/.test(parts[5]);
  const historical = parts.length === 7 && parts[4] === 'modules' && validWorkoutId(parts[5]) && parts[6] === 'background';
  return contentAddressed || historical ? path : null;
}

export function legacyHomeAllowed(account) {
  // Only this private home rendition may use enrolled legacy sources. The
  // gateway/transfer ledger still require enrolled policy, entitlement and quota.
  return account?.mode !== 'enrolling' && account?.enrollmentPending !== true;
}

export async function readLegacyHomeBinding(ctx, ownerId, input, reader = ctx.db) {
  if (!validId(ownerId) || !validWorkoutId(input?.workoutId) || !validSha(input?.sourceHash) ||
      !Number.isSafeInteger(input?.updatedAtMs) || input.updatedAtMs < 0 || input.updatedAtMs > 253402300799999) deny();
  const [workout, summary, deleting, account] = await reader.getAll(
    ctx.db.doc(`users/${ownerId}/workouts/${input.workoutId}`),
    ctx.db.doc(`users/${ownerId}/workoutSummaries/${input.workoutId}`),
    ctx.db.doc(`accountDeletions/${ownerId}`), ctx.db.doc(`imageUsageAccounts/${ownerId}`));
  const w = workout.data(), s = summary.data(), source = s?.imageSource;
  const revision=documentRevision(s?.updatedAt);
  if (deleting.exists || !legacyHomeAllowed(account.data()) || !w || !s ||
      w.id !== input.workoutId || w.ownerId !== ownerId || w.author?.id !== ownerId || s.id !== input.workoutId ||
      millis(w.updatedAt) !== input.updatedAtMs || millis(s.updatedAt) !== input.updatedAtMs ||
      documentRevision(w.updatedAt) !== revision || input.documentRevision !== undefined && input.documentRevision !== revision ||
      typeof source !== 'string' || source.length > 4096 || hashBytes(source) !== input.sourceHash ||
      (w.modules?.[0]?.imageUrl ?? w.modules?.[0]?.imageSource ?? '') !== source) deny();
  const path = legacyHomePath(ctx, ownerId, source);
  if (!path) deny();
  return {source, path, documentRevision:revision};
}

const revisionOf = asset => hashBytes(JSON.stringify([
  asset.bucket, asset.path, asset.generation, asset.sizeBytes, asset.contentType,
]));
export const legacyHomeAssetId = (bucket, path) => `legacy-${hashBytes(`${bucket}/${path}`)}`;

function sourceAsset(ctx, ownerId, input, binding, metadata) {
  const generation = String(metadata.generation), sizeBytes = Number(metadata.size);
  if (!/^[0-9]{1,30}$/.test(generation) || !Number.isSafeInteger(sizeBytes) || sizeBytes < 1 ||
      sizeBytes >= IMAGE_MAX_BYTES || !['image/png','image/jpeg'].includes(metadata.contentType) ||
      metadata.contentEncoding && metadata.contentEncoding !== 'identity') return null;
  const asset = {kind:'legacy-home', ownerId, bucket:ctx.bucket.name, path:binding.path,
    assetId:legacyHomeAssetId(ctx.bucket.name, binding.path), generation, sizeBytes,
    contentType:metadata.contentType, source:binding.source,
    homeBinding:{...input,documentRevision:binding.documentRevision??input.documentRevision}};
  return {...asset, sourceRevision:revisionOf(asset)};
}

export async function resolveLegacyHomeAsset(ctx, ownerId, input) {
  const binding = await readLegacyHomeBinding(ctx, ownerId, input);
  const [metadata] = await ctx.bucket.file(binding.path).getMetadata();
  return sourceAsset(ctx, ownerId, input, binding, metadata);
}

// Also used inside the transfer/claim transaction: a copied/deleted/edited
// summary cannot authorize a stale manifest or a client-supplied storage path.
export async function assertLegacyHomeCurrent(ctx, asset, reader = ctx.db) {
  const binding = await readLegacyHomeBinding(ctx, asset.ownerId, asset.homeBinding, reader);
  if (asset.kind !== 'legacy-home' || asset.bucket !== ctx.bucket.name || asset.path !== binding.path ||
      asset.source !== binding.source || asset.assetId !== legacyHomeAssetId(ctx.bucket.name, binding.path) ||
      !/^[0-9]{1,30}$/.test(asset.generation) || !Number.isSafeInteger(asset.sizeBytes) ||
      asset.sizeBytes < 1 || asset.sizeBytes >= IMAGE_MAX_BYTES ||
      !['image/png','image/jpeg'].includes(asset.contentType) || asset.sourceRevision !== revisionOf(asset)) deny();
}

export async function legacyHomeMetadata(ctx, asset) {
  // Read the live name, not an archived generation: overwrite/deletion revokes
  // the old derivative even if bucket versioning retained the original bytes.
  const [metadata] = await ctx.bucket.file(asset.path).getMetadata();
  const current = sourceAsset(ctx, asset.ownerId, asset.homeBinding, asset, metadata);
  if (!current || current.sourceRevision !== asset.sourceRevision) deny();
  return {file:ctx.bucket.file(asset.path, {generation:asset.generation}), metadata};
}
