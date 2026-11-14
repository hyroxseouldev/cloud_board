import {HOME_RENDITION, ensureHomeThumbnail, homeThumbnailRef, readHomeThumbnail, validHomeThumbnail} from './home-image-thumbnail.js';
import {assertLegacyHomeCurrent, legacyHomeMetadata, legacyHomeRequest, resolveLegacyHomeAsset} from './legacy-home-image.js';
import {randomUUID} from 'node:crypto';
import {accountPath, authenticateRequest, cors, hashBytes, httpFailure, ledgerFor,
  managedMetadata, mediaBaseUrl, publicAsset, readManagedAsset, usageFailure, validId, validRequestId} from './managed-image-assets.js';

const now = ctx => (ctx.clock ?? Date.now)();
const leaseRef = (ctx, id) => ctx.db.doc(`imageUsageMediaLeases/${id}`);
function validateInput(input) {
  if (input?.schemaVersion !== 1 || input.action !== 'issue' || !validRequestId(input.requestId) ||
      !['preview','preparation','playback'].includes(input.purpose) || !Array.isArray(input.assetIds) ||
      input.assetIds.length < 1 || input.assetIds.length > 64 || !input.assetIds.every(validId) ||
      ![input.admissionId,input.sessionId].every(v => v === null || validId(v)) ||
      input.purpose !== 'preview' && (!input.admissionId || !input.sessionId) ||
      input.purpose === 'preview' && (input.admissionId !== null || input.sessionId !== null)) throw usageFailure('media_lease_invalid', 'invalid-argument');
}
async function binding(ctx, ledger, actorUid, value) {
  const access = await ledger.requireUsageContext(ctx, {actorUid, ownerId: value.ownerId,
    purpose: value.purpose, admissionId: value.admissionId, sessionId: value.sessionId});
  if (value.ownerId && value.ownerId !== access.ownerId || value.actorUid && value.actorUid !== actorUid ||
      value.deviceId !== undefined && value.deviceId !== access.deviceId) throw usageFailure('media_lease_invalid','permission-denied');
  if (value.deviceBinding !== undefined) {
    const frozen=value.deviceBinding,current=access.deviceBinding;
    const same=!frozen&&!current || frozen&&current && frozen.displayUid===current.displayUid &&
      frozen.pairingCode===current.pairingCode && (frozen.pairedAtMs??null)===(current.pairedAtMs??null);
    if (!same) throw usageFailure('media_lease_invalid','permission-denied');
  }
  if (value.purpose === 'preview') {
    if (access.ownerId !== actorUid && (!access.deviceId || !Array.isArray(access.allowedAssetSources))) throw usageFailure('media_lease_invalid', 'permission-denied');
    return {access, admission: null};
  }
  const admission = (await ctx.db.doc(accountPath(access.ownerId, 'admissions', value.admissionId)).get()).data();
  if (!admission || admission.sessionId !== value.sessionId || !['preparing','committing','active'].includes(admission.status) ||
      admission.status === 'preparing' && admission.prepareExpiresAtMs <= now(ctx) ||
      value.epoch !== undefined && value.epoch !== admission.epoch ||
      value.manifestHash !== undefined && value.manifestHash !== admission.manifestHash) throw usageFailure('media_lease_invalid', 'permission-denied');
  // requireUsageContext rechecks owner/device/displayAccess/revocation and the
  // fixed participant binding on every issue and body, including HEAD.
  return {access, admission};
}
function allowedAsset(admission, asset, access) {
  if (!admission) return access.ownerId === access.actorUid || access.allowedAssetSources?.includes(asset.source) === true;
  const assets = admission.assets;
  return Array.isArray(assets) && assets.some(a => a.assetId === asset.assetId && a.generation === asset.generation);
}
export async function handleMediaLease(ctx, input = ctx.input, actorUid = ctx.actor?.uid) {
  validateInput(input);
  const ledger = await ledgerFor(ctx);
  const {access, admission} = await binding(ctx, ledger, actorUid, input);
  const assets = await Promise.all([...new Set(input.assetIds)].sort().map(id => readManagedAsset(ctx, access.ownerId, id)));
  if (assets.some(asset => !allowedAsset(admission, asset, access))) throw usageFailure('media_lease_invalid','permission-denied');
  const canonical = JSON.stringify({assetIds:assets.map(a=>a.assetId), admissionId:input.admissionId, sessionId:input.sessionId, purpose:input.purpose});
  const payloadHash = hashBytes(canonical), operation = ctx.db.doc(accountPath(access.ownerId, 'operations', hashBytes(`mediaLease/issue/${actorUid}/${input.requestId}`)));
  return ctx.db.runTransaction(async tx => {
    const old = (await tx.get(operation)).data();
    if (old) {
      if (old.payloadHash !== payloadHash) throw usageFailure('idempotency_conflict');
      return old.result;
    }
    const leaseId = randomUUID(), expiresAtMs = now(ctx) + 300000;
    const result = {schemaVersion:1,leaseId,expiresAtMs,assets:assets.map(publicAsset),sessionId:input.sessionId,epoch:admission?.epoch ?? null};
    tx.set(leaseRef(ctx, leaseId), {leaseId,ownerId:access.ownerId,actorUid,deviceId:access.deviceId,deviceBinding:access.deviceBinding ?? null,
      purpose:input.purpose,admissionId:input.admissionId,sessionId:input.sessionId,
      epoch:admission?.epoch ?? null,manifestHash:admission?.manifestHash ?? null,expiresAtMs,assets:result.assets});
    tx.set(operation, {endpoint:'cloudboardMediaLease',action:'issue',payloadHash,result});
    return result;
  });
}
export async function handleMedia(ctx, req, res) {
  let attempt, ledger, ownerId, handedOff = false, terminal, settlement = Promise.resolve();
  const settle = outcome => {
    if (!attempt || terminal) return settlement;
    terminal = outcome;
    settlement = ledger.settleTransfer(ctx, {ownerId,attemptId:attempt.attemptId,outcome,
      bodyBytes:outcome === 'served' ? attempt.sizeBytes : 0});
    // A failed settlement deliberately leaves the durable reservation unresolved.
    settlement.catch(() => {});
    return settlement;
  };
  try {
    if (cors(ctx, req, res, ['GET','HEAD','OPTIONS'])) return;
    if (!['GET','HEAD'].includes(req.method)) { res.statusCode = 405; res.end(); return; }
    if (req.headers?.range) { res.statusCode = 416; res.end(); return; }
    const query = req.query ?? {}, legacy = query.workoutId !== undefined;
    const actorUid = await authenticateRequest(ctx, req, {nonAnonymous:legacy});
    ledger = await ledgerFor(ctx);
    let access, admission, asset, file, leaseId=null, lease;
    if (legacy) {
      mediaBaseUrl(ctx); // Preserve the existing development/demo service gate.
      const input=legacyHomeRequest(query);
      access=await legacyHomeAccess(ctx,ledger,actorUid);
      asset=await resolveLegacyHomeAsset(ctx,access.ownerId,input);
      if (!asset) { res.statusCode=404; res.setHeader('Cache-Control','private,no-store'); res.end(); return; }
      admission=null; lease={purpose:'preview',admissionId:null,sessionId:null};
    } else {
      if (Object.keys(query).some(k=>!['assetId','v','rendition'].includes(k)) || !validId(query.assetId) || !/^[0-9]+$/.test(query.v ?? '')) throw usageFailure('media_lease_invalid','invalid-argument');
      if (query.rendition !== undefined && query.rendition !== HOME_RENDITION) throw usageFailure('media_lease_invalid','invalid-argument');
      leaseId = req.get?.('X-CloudBoard-Media-Lease') ?? req.headers?.['x-cloudboard-media-lease'];
      if (!validId(leaseId)) throw usageFailure('media_lease_invalid','permission-denied');
      lease = (await leaseRef(ctx, leaseId).get()).data();
      if (!lease || lease.actorUid !== actorUid || lease.expiresAtMs <= now(ctx) ||
          !lease.assets.some(a=>a.assetId===query.assetId && a.generation===query.v)) throw usageFailure('media_lease_invalid','permission-denied');
      ({access, admission}=await binding(ctx,ledger,actorUid,lease));
      asset=await readManagedAsset(ctx,access.ownerId,query.assetId,query.v);
      if (!allowedAsset(admission,asset,access)) throw usageFailure('media_lease_invalid','permission-denied');
      ({file}=await managedMetadata(ctx,asset));
    }
    ownerId = access.ownerId;
    let rendition=null;
    if (query.rendition === HOME_RENDITION) {
      // Home never borrows class preparation/playback reservations or TV access.
      if (lease.purpose !== 'preview' || ownerId !== actorUid || access.deviceId) throw usageFailure('media_lease_invalid','permission-denied');
      rendition=req.method==='HEAD' ? (await homeThumbnailRef(ctx,asset).get()).data() : await ensureHomeThumbnail(ctx,asset);
      if (!validHomeThumbnail(rendition,asset)) {
        res.statusCode=404; res.setHeader('Cache-Control','private,no-store'); res.end(); return;
      }
    }
    const served=rendition ?? asset;
    if (req.method === 'GET') {
      attempt = {...await ledger.reserveTransfer(ctx, {ownerId,actorUid,deviceId:access.deviceId,leaseId,
        assetId:asset.assetId,generation:asset.generation,sizeBytes:served.sizeBytes,
        ...(rendition ? {rendition:HOME_RENDITION} : {}), ...(legacy ? {legacyHome:asset} : {}),
        admissionId:lease.admissionId,sessionId:lease.sessionId,purpose:lease.purpose}),sizeBytes:served.sizeBytes};
    }
    let bytes;
    if (req.method === 'GET') {
      if (rendition) bytes=await readHomeThumbnail(ctx,asset,rendition);
      else [bytes] = await file.download({decompress:false});
      if (!Buffer.isBuffer(bytes) || bytes.length !== served.sizeBytes || hashBytes(bytes) !== served.sha256) throw usageFailure('media_lease_invalid','permission-denied');
      // Recheck revocation and session after Storage I/O, before handing body off.
      if (!legacy) {
        const fresh = await binding(ctx,ledger,actorUid,lease);
        if (!allowedAsset(fresh.admission,asset,fresh.access)) throw usageFailure('media_lease_invalid','permission-denied');
      }
    }
    if (legacy) {
      // Check both stores and revoked auth after generation/body I/O, also HEAD.
      if (await authenticateRequest(ctx,req,{nonAnonymous:true}) !== actorUid) throw usageFailure('media_lease_invalid','permission-denied');
      await legacyHomeAccess(ctx,ledger,actorUid);
      await assertLegacyHomeCurrent(ctx,asset);
      await legacyHomeMetadata(ctx,asset);
    }
    if (res.destroyed) { if (attempt) await settle('not_sent'); return; }
    res.statusCode = 200;
    res.setHeader('Cache-Control','private,no-store'); res.setHeader('Content-Type',served.contentType);
    res.setHeader('Content-Length',String(served.sizeBytes)); res.setHeader('X-Content-Type-Options','nosniff');
    res.setHeader('ETag',`"${rendition ? `${HOME_RENDITION}-${served.sha256}` : asset.generation}"`);
    if (req.method === 'HEAD') { res.end(); return; }
    await new Promise(resolve => {
      const done = outcome => { settle(outcome).finally(resolve).catch(()=>{}); };
      res.once('finish',()=>done('served'));
      res.once('close',()=>done('unknown'));
      res.once('error',()=>done('unknown'));
      handedOff = true;
      // A single buffered end: never pipe, write, flushHeaders or redirect.
      try { res.end(bytes); } catch { done('unknown'); }
    });
  } catch (error) {
    if (attempt) { try { await settle(handedOff ? 'unknown' : 'not_sent'); } catch { /* durable attempt remains */ } }
    httpFailure(res,error);
  }
}

async function legacyHomeAccess(ctx,ledger,actorUid) {
  const access=await ledger.requireUsageContext(ctx,{actorUid,purpose:'preview'});
  if (access.ownerId!==actorUid || access.deviceId) throw usageFailure('media_lease_invalid','permission-denied');
  return access;
}

// Public onRequest contract; root supplies the v2 request and response in ctx.
export function handleMediaRequest(ctx) {
  return handleMedia(ctx,ctx.request,ctx.response);
}
