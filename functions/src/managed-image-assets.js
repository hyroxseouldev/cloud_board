import {createHash} from 'node:crypto';
import {HttpsError} from 'firebase-functions/v2/https';

export const IMAGE_MAX_BYTES = 10 * 1024 * 1024;
export const PROFILE_MAX_BYTES = 5 * 1024 * 1024;
export const POLICY_REVISION = 'image-usage-2.1.5-v1';
export const hashBytes = bytes => createHash('sha256').update(bytes).digest('hex');
export const validId = value => typeof value === 'string' && /^[A-Za-z0-9_-]{1,120}$/.test(value);
export const validRequestId = value => typeof value === 'string' && /^[A-Za-z0-9_-]{8,80}$/.test(value);
export const validSha = value => typeof value === 'string' && /^[a-f0-9]{64}$/.test(value);
export function usageFailure(reason, code = 'failed-precondition') {
  return new HttpsError(code, '이미지 사용 권한과 사용량을 확인해 주세요.', {
    schemaVersion: 1, policyRevision: POLICY_REVISION, reason,
    retryable: code === 'unavailable', usage: null, requiredBytes: null, nextEligibleAtMs: null,
  });
}
export const ledgerFor = async ctx => ctx.ledger ?? import('./image-usage-ledger.js');
export const accountPath = (ownerId, child, id) => `imageUsageAccounts/${ownerId}/${child}/${id}`;
export function publicAsset(asset) {
  const {assetId, source, generation, sizeBytes, contentType, sha256} = asset;
  return {assetId, source, generation, sizeBytes, contentType, sha256};
}
export function mediaBaseUrl(ctx) {
  // Origins and emulator URLs are explicit deployment/fixture inputs, never inferred.
  let url;
  try { url = new URL(ctx.mediaBaseUrl); } catch { throw usageFailure('service_unavailable', 'unavailable'); }
  const expected = `https://asia-northeast3-${ctx.projectId}.cloudfunctions.net/cloudboardMedia`;
  const local = ctx.projectId?.startsWith('demo-') && ctx.emulator === true &&
    url.protocol === 'http:' && ['127.0.0.1', 'localhost', '[::1]'].includes(url.hostname);
  if ((!local && url.href !== expected) || url.username || url.password || url.search || url.hash) {
    throw usageFailure('service_unavailable', 'unavailable');
  }
  if (ctx.projectId !== 'cloud-board-development' && !ctx.projectId?.startsWith('demo-')) {
    throw usageFailure('policy_or_client_upgrade_required');
  }
  return url;
}
export function assetSource(ctx, assetId, generation) {
  const url = mediaBaseUrl(ctx);
  url.searchParams.set('assetId', assetId); url.searchParams.set('v', generation);
  return url.href;
}
export function parseManagedSource(source, ctx) {
  let url, base;
  try { url = new URL(source); base = mediaBaseUrl(ctx); } catch { return null; }
  if (url.origin !== base.origin || url.pathname !== base.pathname || url.username || url.password || url.hash ||
      [...url.searchParams.keys()].some(k => !['assetId', 'v'].includes(k)) ||
      url.searchParams.getAll('assetId').length !== 1 || url.searchParams.getAll('v').length !== 1) return null;
  const assetId = url.searchParams.get('assetId'), generation = url.searchParams.get('v');
  return validId(assetId) && /^[0-9]+$/.test(generation ?? '') ? {assetId, generation} : null;
}
export async function readManagedAsset(ctx, ownerId, assetId, generation = null) {
  if (!validId(ownerId) || !validId(assetId)) throw usageFailure('media_lease_invalid', 'permission-denied');
  const asset = (await ctx.db.doc(accountPath(ownerId, 'assets', assetId)).get()).data();
  if (!asset || asset.ownerId !== ownerId || asset.assetId !== assetId || asset.tokenFree !== true ||
      asset.bucket !== ctx.bucket.name || !asset.path?.startsWith(`users/${ownerId}/managed-images/`) ||
      asset.path.split('/').some(p=>!p||p==='.'||p==='..') ||
      !/^[0-9]+$/.test(asset.generation ?? '') || generation !== null && asset.generation !== generation ||
      !Number.isSafeInteger(asset.sizeBytes) || asset.sizeBytes < 1 || asset.sizeBytes >= IMAGE_MAX_BYTES ||
      !validSha(asset.sha256) || asset.source !== assetSource(ctx, assetId, asset.generation)) {
    throw usageFailure('media_lease_invalid', 'permission-denied');
  }
  return asset;
}
export async function managedMetadata(ctx, asset) {
  const file = ctx.bucket.file(asset.path, {generation: asset.generation});
  const [metadata] = await file.getMetadata();
  if (String(metadata.generation) !== asset.generation || Number(metadata.size) !== asset.sizeBytes ||
      metadata.contentType !== asset.contentType || metadata.contentEncoding && metadata.contentEncoding !== 'identity' ||
      metadata.metadata?.firebaseStorageDownloadTokens ||
      metadata.metadata?.sha256 !== asset.sha256) throw usageFailure('media_lease_invalid', 'permission-denied');
  return {file, metadata};
}
export function validateImage(bytes, contentType, purpose = 'workout') {
  const max = purpose === 'profile' ? PROFILE_MAX_BYTES : IMAGE_MAX_BYTES;
  if (!Buffer.isBuffer(bytes) || !bytes.length || bytes.length >= max) throw usageFailure('upload_mismatch', 'invalid-argument');
  const png = bytes.length >= 24 && bytes.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10])) && bytes.toString('ascii', 12, 16) === 'IHDR' && bytes.readUInt32BE(16) > 0 && bytes.readUInt32BE(20) > 0;
  const jpeg = bytes.length >= 4 && bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255 && bytes[bytes.length - 2] === 255 && bytes[bytes.length - 1] === 217;
  const webp = bytes.length >= 20 && bytes.toString('ascii', 0, 4) === 'RIFF' && bytes.toString('ascii', 8, 12) === 'WEBP' && bytes.readUInt32LE(4) + 8 === bytes.length;
  const gif = bytes.length >= 14 && ['GIF87a','GIF89a'].includes(bytes.toString('ascii',0,6)) && bytes.readUInt16LE(6) > 0 && bytes.readUInt16LE(8) > 0 && bytes[bytes.length - 1] === 59;
  if (!({'image/png': png, 'image/jpeg': jpeg, 'image/webp': webp, 'image/gif': gif})[contentType]) {
    throw usageFailure('upload_mismatch', 'invalid-argument');
  }
}
export async function authenticateRequest(ctx, req) {
  const authorization = req?.get?.('Authorization') ?? req?.headers?.authorization;
  const match = /^Bearer ([^\s]+)$/.exec(authorization ?? '');
  if (!match) throw usageFailure('media_lease_invalid', 'unauthenticated');
  let token;
  try { token = await ctx.auth.verifyIdToken(match[1], true); }
  catch { throw usageFailure('media_lease_invalid', 'unauthenticated'); }
  if (!validId(token.uid)) throw usageFailure('media_lease_invalid', 'unauthenticated');
  return token.uid;
}
export function cors(ctx, req, res, methods) {
  const origin = req.get?.('Origin') ?? req.headers?.origin;
  res.setHeader('Vary', 'Origin');
  if (origin) {
    if (origin === '*' || origin === 'null' || !Array.isArray(ctx.allowedOrigins) || !ctx.allowedOrigins.includes(origin)) throw usageFailure('media_lease_invalid', 'permission-denied');
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Access-Control-Allow-Methods', methods.join(', '));
    res.setHeader('Access-Control-Allow-Headers', 'Authorization, X-CloudBoard-Media-Lease, X-CloudBoard-Upload-Id, Content-Type');
    res.setHeader('Access-Control-Expose-Headers', 'Content-Length, Content-Type, ETag');
  }
  if (req.method === 'OPTIONS') { res.statusCode = 204; res.end(); return true; }
  return false;
}
export function httpFailure(res, error) {
  if (res.headersSent || res.destroyed) return;
  const codes = {'invalid-argument':400, unauthenticated:401, 'permission-denied':403,
    'failed-precondition':409, 'resource-exhausted':429, unavailable:503};
  res.statusCode = codes[error?.code] ?? 503;
  res.setHeader('Cache-Control', 'private,no-store');
  res.setHeader('Content-Type', 'application/json');
  res.end(JSON.stringify({error: error?.details?.schemaVersion === 1 ? error.details : usageFailure('service_unavailable','unavailable').details}));
}
