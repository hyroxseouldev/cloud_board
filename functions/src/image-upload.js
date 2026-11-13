import {accountPath, assetSource, authenticateRequest, cors, hashBytes, httpFailure, IMAGE_MAX_BYTES,
  ledgerFor, mediaBaseUrl, PROFILE_MAX_BYTES, publicAsset, readManagedAsset, usageFailure, validId, validRequestId,
  validSha, validateImage} from './managed-image-assets.js';

export function uploadPermit(ctx, record) {
  return {schemaVersion:1,uploadId:record.uploadId,expiresAtMs:record.expiresAtMs,status:record.status,
    uploadUrl:['reserved','writing'].includes(record.status) ? mediaBaseUrl(ctx).href.replace(/cloudboardMedia$/, 'cloudboardImageUploadBody') : null,
    asset:record.asset ? publicAsset(record.asset) : null};
}
function validateReserve(input) {
  const max = input.purpose === 'profile' ? PROFILE_MAX_BYTES : IMAGE_MAX_BYTES;
  if (!['workout','brand','profile'].includes(input.purpose) || !validSha(input.sha256) ||
      !Number.isSafeInteger(input.sizeBytes) || input.sizeBytes < 1 || input.sizeBytes >= max ||
      !['image/png','image/jpeg','image/webp','image/gif'].includes(input.contentType) ||
      !(input.workoutId === null || validId(input.workoutId)) || input.purpose !== 'workout' && input.workoutId !== null) {
    throw usageFailure('upload_mismatch','invalid-argument');
  }
}
async function readUpload(ctx,ownerId,uploadId) {
  if (!validId(uploadId)) throw usageFailure('upload_mismatch','invalid-argument');
  const record = (await ctx.db.doc(accountPath(ownerId,'uploads',uploadId)).get()).data();
  if (!record || record.ownerId !== ownerId || record.uploadId !== uploadId) throw usageFailure('upload_mismatch','permission-denied');
  return record;
}
async function objectAsset(ctx, record) {
  const [metadata] = await ctx.bucket.file(record.path).getMetadata();
  const sizeBytes = Number(metadata.size), generation = String(metadata.generation);
  const generated = record.purpose === 'generated';
  const expected = generated ? record.boundOutput : record;
  if (!expected || !validSha(expected.sha256) || sizeBytes !== expected.sizeBytes ||
      generated && sizeBytes > record.sizeBytes || metadata.contentType !== record.contentType ||
      metadata.metadata?.sha256 !== expected.sha256 || metadata.metadata?.uploadId !== record.uploadId ||
      metadata.metadata?.ownerId !== record.ownerId || metadata.metadata?.firebaseStorageDownloadTokens ||
      !/^[0-9]+$/.test(generation)) throw usageFailure('upload_mismatch');
  return {assetId:record.uploadId,source:assetSource(ctx,record.uploadId,generation),generation,sizeBytes,
    contentType:record.contentType,sha256:metadata.metadata.sha256,bucket:ctx.bucket.name,path:record.path,
    ownerId:record.ownerId,tokenFree:true,provenance:metadata.metadata.provenance ?? (generated ? 'server_generated' : 'raw_upload')};
}
export async function reconcileUpload(ctx, record) {
  if (!['writing','unknown'].includes(record.status)) return record;
  try {
    const asset = await objectAsset(ctx,record);
    return await (await ledgerFor(ctx)).settleUpload(ctx,{ownerId:record.ownerId,uploadId:record.uploadId,outcome:'stored',asset});
  } catch (error) {
    // Even a 404 cannot rule out a late writer. Never refund a claimed upload.
    if (error?.details?.reason === 'upload_mismatch') throw error;
    return record;
  }
}
export async function handleImageUpload(ctx,input = ctx.input,actorUid = ctx.actor?.uid) {
  if (input?.schemaVersion !== 1 || !['reserve','get','cancel'].includes(input.action) ||
      input.action !== 'get' && !validRequestId(input.requestId)) throw usageFailure('upload_mismatch','invalid-argument');
  const ledger = await ledgerFor(ctx), access = await ledger.requireUsageContext(ctx,{actorUid,purpose:'upload'});
  if (access.ownerId !== actorUid) throw usageFailure('upload_mismatch','permission-denied');
  if (input.action === 'reserve') {
    validateReserve(input); mediaBaseUrl(ctx);
    const {purpose,workoutId,sha256,sizeBytes,contentType} = input;
    // A owns the uploadId and canonical final path; this input is only a namespace hint.
    const path = `users/${actorUid}/managed-images/${purpose}/pending/${sha256}`;
    const payloadHash = hashBytes(JSON.stringify({purpose,workoutId,sha256,sizeBytes,contentType}));
    const record = await ledger.reserveUpload(ctx,{ownerId:actorUid,requestId:input.requestId,payloadHash,
      purpose,workoutId,sha256,sizeBytes,contentType,path});
    return uploadPermit(ctx,record);
  }
  let operation;
  if (input.action === 'cancel') {
    operation = ctx.db.doc(accountPath(actorUid,'operations',hashBytes(`imageUpload/cancel/${input.requestId}`)));
    const payloadHash = hashBytes(JSON.stringify({uploadId:input.uploadId}));
    const cached = await ctx.db.runTransaction(async tx => {
      const old = (await tx.get(operation)).data();
      if (old && old.payloadHash !== payloadHash) throw usageFailure('idempotency_conflict');
      if (old?.result) return old.result;
      if (!old) tx.set(operation,{endpoint:'cloudboardImageUpload',action:'cancel',payloadHash,result:null});
      return null;
    });
    if (cached) return cached;
  }
  let record = await reconcileUpload(ctx,await readUpload(ctx,actorUid,input.uploadId));
  if (input.action === 'cancel' && record.status === 'reserved') {
    // Ledger fences reserved->cancelled against an atomic beginUpload claim.
    record = await ledger.settleUpload(ctx,{ownerId:actorUid,uploadId:record.uploadId,outcome:'not_written',asset:null});
  }
  const result = uploadPermit(ctx,record);
  if (operation) await ctx.db.runTransaction(async tx => {
    const old = (await tx.get(operation)).data();
    if (!old.result) tx.set(operation,{...old,result});
  });
  return result;
}
async function savePrivate(ctx, record, bytes, provenance = 'raw_upload') {
  const file = ctx.bucket.file(record.path);
  try {
    await file.save(bytes,{resumable:false,preconditionOpts:{ifGenerationMatch:0},
      metadata:{contentType:record.contentType,cacheControl:'private, no-store',
        metadata:{sha256:record.boundOutput?.sha256 ?? record.sha256,ownerId:record.ownerId,uploadId:record.uploadId,provenance}}});
  } catch (error) {
    // A create may have committed despite a lost response (including 412 retry).
    try { return {...await objectAsset(ctx,record),provenance}; }
    catch {
      await (await ledgerFor(ctx)).settleUpload(ctx,{ownerId:record.ownerId,uploadId:record.uploadId,outcome:'unknown',asset:null});
      throw usageFailure('usage_reconciliation_pending','unavailable');
    }
  }
  try { return {...await objectAsset(ctx,record),provenance}; }
  catch {
    await (await ledgerFor(ctx)).settleUpload(ctx,{ownerId:record.ownerId,uploadId:record.uploadId,outcome:'unknown',asset:null});
    throw usageFailure('usage_reconciliation_pending','unavailable');
  }
}
export async function handleImageUploadBody(ctx,req,res) {
  try {
    if (cors(ctx,req,res,['POST','OPTIONS'])) return;
    if (req.method !== 'POST') { res.statusCode=405;res.end();return; }
    const actorUid = await authenticateRequest(ctx,req), ledger = await ledgerFor(ctx);
    const access = await ledger.requireUsageContext(ctx,{actorUid,purpose:'upload'});
    if (access.ownerId !== actorUid) throw usageFailure('upload_mismatch','permission-denied');
    const uploadId = req.get?.('X-CloudBoard-Upload-Id') ?? req.headers?.['x-cloudboard-upload-id'];
    let record = await reconcileUpload(ctx,await readUpload(ctx,actorUid,uploadId));
    if (record.purpose === 'generated') throw usageFailure('upload_mismatch','permission-denied');
    if (['writing','unknown'].includes(record.status)) throw usageFailure('usage_reconciliation_pending','unavailable');
    const bytes = req.rawBody;
    const contentType = req.get?.('Content-Type') ?? req.headers?.['content-type'];
    validateImage(bytes,contentType,record.purpose);
    if (bytes.length !== record.sizeBytes || hashBytes(bytes) !== record.sha256 || contentType !== record.contentType) throw usageFailure('upload_mismatch','invalid-argument');
    if (record.status !== 'stored') {
      record = await ledger.beginUpload(ctx,{ownerId:actorUid,uploadId,actorUid});
      if (record.status !== 'stored') {
        if (record.status !== 'writing') throw usageFailure('usage_reconciliation_pending','unavailable');
        const asset = await savePrivate(ctx,record,bytes);
        record = await ledger.settleUpload(ctx,{ownerId:actorUid,uploadId,outcome:'stored',asset});
      }
    }
    res.statusCode=201;res.setHeader('Content-Type','application/json');res.setHeader('Cache-Control','private,no-store');
    res.end(JSON.stringify({schemaVersion:1,upload:uploadPermit(ctx,record)}));
  } catch (error) { httpFailure(res,error); }
}

/** Reserve the maximum output BEFORE the provider/render step. Legacy jobs keep
 * their existing storage path; enrolled jobs cannot bypass ledger accounting. */
export async function reserveGeneratedImage({db,bucket,uid,usageContext},requestId,provenance,maxOutputBytes = IMAGE_MAX_BYTES-1) {
  const account = (await db.doc(`imageUsageAccounts/${uid}`).get()).data();
  if (account?.mode !== 'enrolled') return null;
  if (!usageContext) throw usageFailure('service_unavailable','unavailable');
  const ctx = {...usageContext,db,bucket}, ledger = await ledgerFor(ctx);
  await ledger.requireUsageContext(ctx,{actorUid:uid,ownerId:uid,purpose:'upload'});
  mediaBaseUrl(ctx);
  const requestKey = hashBytes(`${provenance}/${requestId}`);
  const payloadHash = hashBytes(JSON.stringify({provenance,requestId,maxOutputBytes}));
  const record = await ledger.reserveUpload(ctx,{ownerId:uid,requestId:requestKey,
    payloadHash,purpose:'generated',workoutId:null,sha256:null,sizeBytes:maxOutputBytes,
    generatedOutput:{hashStatus:'pending',provenance},
    contentType:'image/png',path:`users/${uid}/managed-images/generated/pending/output`});
  return {ctx,ledger,record,provenance};
}
export async function storeGeneratedImage(reservation,bytes) {
  const {ctx,ledger,provenance} = reservation;
  let record = await reconcileUpload(ctx,reservation.record);
  reservation.record = record;
  if (record.status === 'stored') return {...record.asset};
  validateImage(bytes,'image/png');
  if (bytes.length > record.sizeBytes) throw usageFailure('upload_mismatch','invalid-argument');
  if (['writing','unknown'].includes(record.status)) throw usageFailure('usage_reconciliation_pending','unavailable');
  record = await ledger.beginUpload(ctx,{ownerId:record.ownerId,uploadId:record.uploadId,actorUid:record.ownerId});
  reservation.record = record;
  if (record.status === 'stored') return {...record.asset};
  if (record.status !== 'writing') throw usageFailure('usage_reconciliation_pending','unavailable');
  // A pins the actual output hash/path before any Storage write. The original
  // maximum reservation remains intact until generation evidence is settled.
  record = await ledger.bindGeneratedUpload(ctx,{ownerId:record.ownerId,uploadId:record.uploadId,
    actorUid:record.ownerId,sha256:hashBytes(bytes),sizeBytes:bytes.length});
  reservation.record = record;
  const asset = await savePrivate(ctx,record,bytes,provenance);
  const settled = await ledger.settleUpload(ctx,{ownerId:record.ownerId,uploadId:record.uploadId,outcome:'stored',asset});
  return {...settled.asset};
}
export async function enrolledAssetResponse({db,uid,usageContext},artifact) {
  const account = (await db.doc(`imageUsageAccounts/${uid}`).get()).data();
  if (account?.mode !== 'enrolled') return null;
  if (!usageContext || !artifact?.source || !artifact?.assetId) throw usageFailure('legacy_asset_transition_required');
  const ledger = await ledgerFor(usageContext);
  await ledger.requireUsageContext(usageContext,{actorUid:uid,ownerId:uid,purpose:'preview'});
  const asset = await readManagedAsset(usageContext,uid,artifact.assetId,artifact.generation);
  if (asset.source !== artifact.source || asset.sha256 !== artifact.sha256) throw usageFailure('media_lease_invalid','permission-denied');
  // No callable base64 bypass: consumer obtains a lease and authenticated body.
  return {schemaVersion:1,asset:publicAsset(asset),sha256:artifact.sha256,width:artifact.width,height:artifact.height};
}

export async function cancelUnwrittenGeneratedImage(reservation) {
  if (!reservation || reservation.record.status !== 'reserved') return;
  const {ctx,ledger,record} = reservation;
  await ledger.settleUpload(ctx,{ownerId:record.ownerId,uploadId:record.uploadId,outcome:'not_written',asset:null});
}

// Public onRequest contract; rawBody is supplied by the Functions HTTP runtime.
export function handleImageUploadRequest(ctx) {
  return handleImageUploadBody(ctx,ctx.request,ctx.response);
}
