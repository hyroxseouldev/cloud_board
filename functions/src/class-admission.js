import {randomUUID} from 'node:crypto';
import {assertUsage, imageUsagePolicies, imageUsagePolicyRevision, nowOf, usageHash, requireUsageMutation,
  requireUsageProject, usageConfigEnabled, validUsageId, validBytes, prepareLifetimeMs, usageFailure} from './image-usage-policy.js';
import {usageAccountRef, usageChildRef, loadUsageLedger, requireLedgerEnabled, usageView,
  checkTransferCapacity, reservePeriod, moveAllocation, operationRef, checkOperation, readUsage} from './image-usage-ledger.js';
import {validateWorkoutTiming, expandWorkoutTiming} from './workout-timing.js';
import {parseManagedSource, validateImage, hashBytes} from './managed-image-assets.js';

const terminal = ['cancelled', 'expired', 'completed'];
const clone = value => structuredClone(value);
const publicAdmission = async (ctx, ownerId, a, session) => ({schemaVersion: 1, admissionId: a.admissionId,
  sessionId: a.sessionId, epoch: a.epoch, manifestHash: a.manifestHash, clientFingerprint: a.clientFingerprint,
  policyRevision: a.policyRevision, status: a.status, prepareExpiresAtMs: a.prepareExpiresAtMs,
  targetDeviceIds: a.targetDeviceIds, reservedDownloadBytes: a.reservedDownloadBytes,
  supportsTargetSubset: true,
  ...(a.selectedTargetDeviceIds ? {selectedTargetDeviceIds: a.selectedTargetDeviceIds} : {}),
  usage: await readUsage(ctx, {ownerId}), ...(session !== undefined ? {session} : {})});
const wireSnapshot = workout => ({...workout,
  createdAt: new Date(workout.createdAt).toISOString(), updatedAt: new Date(workout.updatedAt).toISOString()});

export function validateAdmissionWorkout(workout, ownerId) {
  assertUsage(workout && validUsageId(workout.id) && workout.ownerId === ownerId && workout.author?.id === ownerId &&
    typeof workout.author.displayName === 'string' &&
    (workout.author.photoUrl == null || typeof workout.author.photoUrl === 'string') &&
    typeof workout.name === 'string' && typeof workout.folder === 'string' &&
    typeof workout.brandL === 'string' && typeof workout.brandR === 'string' &&
    Number.isSafeInteger(workout.createdAt) && Number.isSafeInteger(workout.updatedAt) &&
    workout.createdAt >= 0 && workout.updatedAt >= 0 && workout.createdAt <= 253402300799999 && workout.updatedAt <= 253402300799999 &&
    Array.isArray(workout.modules) && workout.modules.length > 0 && workout.modules.length <= 1000 &&
    Buffer.byteLength(JSON.stringify(workout)) <= 900000, 'upload_mismatch');
  assertUsage(workout.modules.every(m => m && typeof m === 'object' && validateWorkoutTiming(m) &&
    validUsageId(m.id) && typeof m.name === 'string' && typeof m.text === 'string' &&
    typeof m.beep === 'boolean' && typeof m.coverImage === 'boolean' &&
    typeof m.imageUrl === 'string' && m.imageUrl.length <= 10000000), 'upload_mismatch');
  const steps = workout.modules.flatMap(expandWorkoutTiming);
  assertUsage(steps.length <= 10000 && Number.isFinite(workout.soundVolume ?? 1) &&
    (workout.soundVolume ?? 1) >= 0 && (workout.soundVolume ?? 1) <= 1 &&
    Number.isSafeInteger(workout.countdownSeconds ?? 3) && (workout.countdownSeconds ?? 3) >= 0 &&
    (workout.countdownSeconds ?? 3) <= 60, 'upload_mismatch');
  return steps;
}
function requiredProtocol(workout) {
  if (workout.modules.some(m => m.timingVersion >= 3)) return 5;
  if (workout.modules.some(m => (m.rounds ?? 1) > 1 || (m.intervalBlocks?.length ?? 0) > 0 || m.workSeconds === 0)) return 4;
  return workout.modules.some(m => m.includeFinalRest && m.restSeconds > 0) ? 3 : 1;
}
function imageSources(workout, brand) {
  const sources = [workout.countdownImageSource,
    ...workout.modules.map(m => m.imageUrl), brand?.logoUrl, brand?.backgroundImageUrl,
    ...(brand?.promotionImageUrls ?? [])];
  return [...new Set(sources.filter(s => typeof s === 'string' && s.length > 0))];
}
export function sourceAssetId(ctx, source) {
  const parsed = parseManagedSource(source, {...ctx,
    mediaBaseUrl: ctx.mediaBaseUrl ?? `https://asia-northeast3-${ctx.projectId}.cloudfunctions.net/cloudboardMedia`});
  return parsed ? {id: parsed.assetId, generation: parsed.generation} : null;
}
// The existing Dart WorkoutImageSource accepts data:<mime>;base64,... and bare
// base64 with detected PNG/JPEG/WebP/GIF bytes. It has no asset:/file: loader.
export function decodeAdmissionLocalImage(source) {
  const fail = () => { throw usageFailure('legacy_asset_transition_required'); };
  if (typeof source !== 'string' || !source.length || source.length > 14000000) return fail();
  const uri = /^data:([^;,]+);base64,(.*)$/is.exec(source);
  let encoded = uri ? uri[2] : source;
  try { encoded = decodeURIComponent(encoded).replaceAll('-', '+').replaceAll('_', '/'); } catch { return fail(); }
  if (!/^[A-Za-z0-9+/]*={0,2}$/.test(encoded) || encoded.length % 4 === 1 ||
      encoded.includes('=') && encoded.length % 4 !== 0) return fail();
  const bytes = Buffer.from(encoded, 'base64');
  if (!bytes.length || bytes.length >= 10485760 || bytes.toString('base64').replace(/=+$/, '') !== encoded.replace(/=+$/, '')) return fail();
  let type = null;
  if (bytes.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]))) type = 'image/png';
  else if (bytes.length >= 3 && bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255) type = 'image/jpeg';
  else if (bytes.length >= 12 && bytes.toString('ascii',0,4) === 'RIFF' && bytes.toString('ascii',8,12) === 'WEBP') type = 'image/webp';
  else if (['GIF87a','GIF89a'].includes(bytes.toString('ascii',0,6))) type = 'image/gif';
  if (!type) return fail();
  try { validateImage(bytes, type); } catch { return fail(); }
  return {kind:'embedded', sha256:hashBytes(bytes), sizeBytes:bytes.length, contentType:type, sourceHash:usageHash(source)};
}
async function resolveManifest(ctx, ownerId, input, owner) {
  const workout = clone(input.workout); validateAdmissionWorkout(workout, ownerId);
  const all = owner?.devices ?? {}, targetIds = input.targetDeviceIds;
  assertUsage(Array.isArray(targetIds) && targetIds.length <= 32 && targetIds.every(validUsageId) &&
    new Set(targetIds).size === targetIds.length && validUsageId(input.controllerDeviceId) &&
    typeof input.clientFingerprint === 'string' && input.clientFingerprint.length <= 256);
  const targets = (targetIds.length ? targetIds : Object.keys(all).filter(id => all[id]?.paired === true)).sort();
  assertUsage(targets.length <= 32, 'policy_or_client_upgrade_required');
  const protocol = requiredProtocol(workout);
  const targetBindings = {};
  for (const id of targets) {
    const d = all[id];
    assertUsage(d?.paired === true && d.id === id && validUsageId(d.displayUid) &&
      d.imageUsageProtocol === 1 && d.preparationProtocol >= 2 && d.playbackProtocol >= Math.max(2, protocol),
    'policy_or_client_upgrade_required');
    const [access, revocations, authAccess] = await Promise.all([
      ctx.realtime.ref(`displayAccess/${d.displayUid}`).get(),
      ctx.realtime.ref(`displayConnectionRevocations/${d.displayUid}`).get(),
      ctx.realtime.ref(`authAccess/${d.displayUid}`).get(),
    ]);
    const a = access.val(), r = revocations.val();
    assertUsage(a?.ownerId === ownerId && a.deviceId === id && a.pairingCode === d.pairingCode &&
      (!r || (a.pairingCode && !r[a.pairingCode])) && authAccess.val()?.disabled !== true,
    'media_lease_invalid', 'permission-denied');
    targetBindings[id] = {displayUid: d.displayUid, pairingCode: d.pairingCode, pairedAtMs: d.pairedAtMs ?? null};
  }
  const brand = owner?.operations?.brand ?? null;
  const sources = imageSources(workout, brand);
  assertUsage(sources.length <= 64, 'workout_image_limit');
  const assets = [], localAssets = [];
  for (const source of sources) {
    const parsed = sourceAssetId(ctx, source);
    if (!parsed) {
      assertUsage(!/^https?:\/\//i.test(source), 'legacy_asset_transition_required');
      localAssets.push(decodeAdmissionLocalImage(source)); continue;
    }
    const asset = (await usageChildRef(ctx.db, ownerId, 'assets', parsed.id).get()).data();
    assertUsage(asset && asset.tokenFree === true && asset.ownerId === ownerId && asset.generation === parsed.generation &&
      asset.source === source && validBytes(asset.sizeBytes) && asset.sizeBytes > 0 && asset.path.startsWith(`users/${ownerId}/`),
    'legacy_asset_transition_required');
    const [metadata] = await ctx.bucket.file(asset.path, {generation: asset.generation}).getMetadata();
    assertUsage(String(metadata.generation) === asset.generation && Number(metadata.size) === asset.sizeBytes &&
      metadata.contentType === asset.contentType && !metadata.metadata?.firebaseStorageDownloadTokens,
    'legacy_asset_transition_required');
    assets.push(asset);
  }
  const bytes = assets.reduce((n, a) => n + a.sizeBytes, 0), imageBytes = bytes + localAssets.reduce((n, a) => n + a.sizeBytes, 0);
  assertUsage(imageBytes <= 100000000, 'workout_image_limit', 'resource-exhausted', {requiredBytes: imageBytes});
  const sounds = (workout.soundVolume ?? 1) <= 0 ? [] : [...new Set([
    workout.countdownSound ?? 'classicBeep', workout.workStartSound ?? 'sharpBeep',
    workout.restStartSound ?? 'lowPulse', workout.workoutEndSound ?? 'longFinish',
  ].filter(s => s !== 'silent'))];
  assertUsage(sounds.every(s => ['gentleBeep','classicBeep','sharpBeep','lowPulse','boxingBell','softBell','doubleBeep','longFinish','videoBeep'].includes(s)));
  const manifest = {workout, brand, targetDeviceIds: targets, targetBindings, localAssets, imageBytes, assets: assets.map(a => ({assetId: a.assetId,
    generation: a.generation, sizeBytes: a.sizeBytes, source: a.source, contentType: a.contentType, sha256: a.sha256}))};
  return {manifest, targetBindings, images:sources, assets: manifest.assets, manifestHash: usageHash(manifest), sounds, requiredProtocol: protocol,
    reservedDownloadBytes: bytes * (targets.length + 1)};
}
async function ownerState(ctx, ownerId) {
  const [root, access] = await Promise.all([ctx.realtime.ref(`users/${ownerId}`).get(), ctx.realtime.ref(`authAccess/${ownerId}`).get()]);
  assertUsage(access.val()?.disabled !== true, 'media_lease_invalid', 'permission-denied');
  return root.val() ?? {};
}
export async function handleClassAdmission(ctx) {
  requireUsageProject(ctx.projectId);
  const {actor, input} = ctx, ownerId = actor?.uid;
  assertUsage(validUsageId(ownerId) && actor?.token?.firebase?.sign_in_provider !== 'anonymous', 'media_lease_invalid', 'permission-denied');
  assertUsage(input?.schemaVersion === 1 && ['prepare', 'commit', 'commitSelected', 'get', 'cancel'].includes(input.action));
  if (input.action !== 'get') requireUsageMutation(input);
  if (input.action === 'prepare') return prepareAdmission(ctx, ownerId, input);
  assertUsage(validUsageId(input.admissionId));
  if (input.action === 'get') {
    await processUsageOutbox(ctx, {ownerId, admissionId: input.admissionId});
    await reconcileUsageSession(ctx, {ownerId});
  } else if (['commit', 'commitSelected'].includes(input.action)) await commitAdmission(ctx, ownerId, input);
  else await cancelAdmission(ctx, ownerId, input);
  const a = (await usageChildRef(ctx.db, ownerId, 'admissions', input.admissionId).get()).data();
  assertUsage(a, 'media_lease_invalid', 'permission-denied');
  const state = await ownerState(ctx, ownerId), active = state.activeSession;
  return publicAdmission(ctx, ownerId, a, active?.id === a.sessionId ? {...active,
    workoutSnapshot: state.playbackSnapshots?.[a.sessionId] ?? active.workoutSnapshot} : null);
}
async function prepareAdmission(ctx, ownerId, input) {
  const hash = usageHash(input), admissionId = randomUUID(), sessionId = randomUUID();
  // Check idempotency before metadata reads or eligibility checks: a committed
  // request must remain recoverable after its preparation expiry or disconnect.
  const key = usageHash(['admission', 'prepare', input.requestId]);
  const old = (await usageChildRef(ctx.db, ownerId, 'operations', key).get());
  const oldResult = checkOperation(old, hash);
  if (oldResult) {
    await processUsageOutbox(ctx, {ownerId, admissionId: oldResult.admissionId});
    await reconcileUsageSession(ctx, {ownerId});
    const oldAdmission = (await usageChildRef(ctx.db, ownerId, 'admissions', oldResult.admissionId).get()).data();
    return publicAdmission(ctx, ownerId, oldAdmission);
  }
  await reconcileUsageSession(ctx, {ownerId});
  const owner = await ownerState(ctx, ownerId), resolved = await resolveManifest(ctx, ownerId, input, owner);
  const a = await ctx.db.runTransaction(async tx => {
    const l = await loadUsageLedger(ctx, tx, ownerId), op = operationRef(l, 'admission', 'prepare', input.requestId);
    const replay = checkOperation(await tx.get(op), hash);
    if (replay) return (await tx.get(l.base.collection('admissions').doc(replay.admissionId))).data();
    requireLedgerEnabled(l);
    assertUsage(l.account.mode === 'enrolled', 'policy_or_client_upgrade_required');
    assertUsage(!l.account.activeAdmissionId && (!owner.activeSession || owner.activeSession.status === 'completed'), 'session_changed');
    const gate = owner.usageGate;
    assertUsage(gate?.mode === 'enrolled' && gate.enrollmentRevision === l.account.enrollmentRevision,
      'policy_or_client_upgrade_required');
    checkTransferCapacity(l, resolved.reservedDownloadBytes, {preparing: true});
    const preparationAllocations = ['downloadDay','downloadMonth'].map(kind => reservePeriod(l, kind, resolved.reservedDownloadBytes));
    const epoch = (l.account.nextEpoch ?? 0) + 1;
    const value = {schemaVersion: 1, admissionId, sessionId, ownerId, epoch, policyRevision: imageUsagePolicyRevision,
      status: 'preparing', prepareExpiresAtMs: l.now + prepareLifetimeMs, createdAtMs: l.now,
      enrollmentRevision: l.account.enrollmentRevision, clientFingerprint: input.clientFingerprint,
      controllerDeviceId: input.controllerDeviceId, targetDeviceIds: resolved.manifest.targetDeviceIds,
      ...resolved, preparationAllocations, preparationRemainingBytes: resolved.reservedDownloadBytes};
    l.account.activeAdmissionId = admissionId; l.account.nextEpoch = epoch;
    l.put(l.base.collection('admissions').doc(admissionId), value);
    l.put(l.base.collection('outbox').doc(admissionId), {admissionId, epoch, phase: 'prepare', status: 'pending', createdAtMs: l.now});
    l.put(op, {payloadHash: hash, result: {admissionId}, createdAtMs: l.now}); l.flush(); return value;
  });
  await processUsageOutbox(ctx, {ownerId, admissionId: a.admissionId});
  return publicAdmission(ctx, ownerId, a);
}
function validReceipts(owner, a, now, targets = a.targetDeviceIds) {
  const request = owner.displayPreparation?.request, receipts = owner.displayPreparation?.responses ?? {};
  return request?.admissionId === a.admissionId && request.sessionId === a.sessionId && request.epoch === a.epoch &&
    request.manifestHash === a.manifestHash && targets.every(id => {
      const r = receipts[id];
      return r?.sessionId === a.sessionId && r.manifestHash === a.manifestHash && r.revision === a.epoch &&
        r.status === 'ready' && r.imageCount === a.images.length && r.audioReady === true &&
        Number.isSafeInteger(r.checkedAtMs) && r.checkedAtMs >= a.createdAtMs && r.checkedAtMs <= now + 5000;
    });
}
function sameTargets(owner, a, targets = a.targetDeviceIds) {
  return targets.every(id => {
    const expected = a.targetBindings?.[id], current = owner.devices?.[id];
    return expected && current?.paired === true && current.id === id &&
      current.displayUid === expected.displayUid && current.pairingCode === expected.pairingCode &&
      (current.pairedAtMs ?? null) === expected.pairedAtMs;
  });
}
function commitTargets(a, input) {
  assertUsage(a, 'session_changed');
  if (input.action !== 'commitSelected') return a.targetDeviceIds;
  const ids = input.selectedTargetDeviceIds;
  assertUsage(Array.isArray(ids) && ids.length > 0 && ids.length <= 32 &&
    ids.every(validUsageId) && new Set(ids).size === ids.length);
  assertUsage(ids.every(id => a.targetDeviceIds.includes(id)), 'session_changed');
  return [...ids].sort();
}
const sameIds = (left, right) => left.length === right.length && left.every(id => right.includes(id));
// Same connection-scoped freshness policy as DisplayDevice.recentlySeen. This
// is only a new-start check; an admitted active class never expires on presence.
function selectedReady(owner, a, targets, now) {
  return targets.every(id => {
    const d = owner.devices?.[id], p = d?.heartbeatPolicy;
    const policyValid = d?.currentConnectionId && p?.connectionId === d.currentConnectionId &&
      p.schemaVersion === 1 && Number.isSafeInteger(p.revision) && p.revision >= 0 &&
      Number.isSafeInteger(p.heartbeatIntervalSeconds) && p.heartbeatIntervalSeconds >= 10 && p.heartbeatIntervalSeconds <= 120 &&
      Number.isSafeInteger(p.noResponseTimeoutSeconds) && p.noResponseTimeoutSeconds >= p.heartbeatIntervalSeconds * 3 &&
      p.noResponseTimeoutSeconds <= 600;
    const health = d?.preparationHealth;
    return d?.displayState === 'auto' && d.online === true && Number.isSafeInteger(d.lastSeenAtMs) &&
      d.lastSeenAtMs > 0 && d.lastSeenAtMs <= now + 5000 &&
      now - d.lastSeenAtMs < (policyValid ? p.noResponseTimeoutSeconds : 75) * 1000 &&
      !(health?.code && (health.requestId == null || health.requestId === a.sessionId));
  });
}
async function commitAdmission(ctx, ownerId, input) {
  const owner = await ownerState(ctx, ownerId);
  const recorded = (await usageChildRef(ctx.db, ownerId, 'admissions', input.admissionId).get()).data();
  const targets = commitTargets(recorded, input), selected = input.action === 'commitSelected';
  const hash = usageHash(selected ? {...input, selectedTargetDeviceIds: targets} : input);
  if (recorded?.status === 'preparing') {
    const verified = await resolveManifest(ctx, ownerId, {workout: recorded.manifest.workout,
      targetDeviceIds: targets, controllerDeviceId: recorded.controllerDeviceId,
      clientFingerprint: recorded.clientFingerprint}, owner);
    assertUsage(sameTargets(owner, recorded, targets), 'session_changed');
    // The preparation hash binds the immutable cohort. Verify current selected
    // bindings first, then restore that cohort only for the media/brand hash
    // comparison. A removed or failed UNselected display cannot veto a start.
    const manifest = selected ? {...verified.manifest,
      targetDeviceIds: recorded.manifest.targetDeviceIds, targetBindings: recorded.manifest.targetBindings} : verified.manifest;
    assertUsage(usageHash(manifest) === recorded.manifestHash, 'session_changed');
  }
  await ctx.db.runTransaction(async tx => {
    const ref = usageChildRef(ctx.db, ownerId, 'admissions', input.admissionId), a = (await tx.get(ref)).data();
    const l = await loadUsageLedger(ctx, tx, ownerId, a?.preparationAllocations?.map(x => x.periodId) ?? []);
    const op = operationRef(l, 'admission', 'commit', input.requestId);
    const prior = checkOperation(await tx.get(op), hash); if (prior) return;
    assertUsage(a && a.sessionId === input.sessionId && a.epoch === input.epoch && a.manifestHash === input.manifestHash, 'session_changed');
    assertUsage(sameIds(targets, commitTargets(a, input)), 'session_changed');
    if (['committing', 'active'].includes(a.status)) {
      assertUsage(a.startHash === usageHash(input.start) && sameIds(targets, a.selectedTargetDeviceIds ?? a.targetDeviceIds),
        'idempotency_conflict', 'already-exists');
      l.put(op, {payloadHash: hash, result: {admissionId: a.admissionId}}); l.flush(); return;
    }
    requireLedgerEnabled(l);
    assertUsage(a.status === 'preparing' && a.prepareExpiresAtMs > l.now, 'admission_expired');
    assertUsage(validReceipts(owner, a, l.now, targets), 'session_changed');
    if (selected) assertUsage(l.account.activeAdmissionId === a.admissionId &&
      sameTargets(owner, a, targets) && selectedReady(owner, a, targets, l.now), 'session_changed');
    // Recheck devices/revocation metadata on every start, without trusting the
    // preparation ACK as evidence of the actual account binding.
    const steps = validateAdmissionWorkout(a.manifest.workout, ownerId), s = input.start;
    assertUsage(s && Number.isSafeInteger(s.stepIndex) && s.stepIndex >= 0 && s.stepIndex < steps.length &&
      validBytes(s.durationMs) && s.durationMs === steps[s.stepIndex].seconds * 1000 &&
      typeof s.briefing === 'boolean' && typeof s.scheduled === 'boolean' &&
      (s.scheduledAtMs === null || validBytes(s.scheduledAtMs)) && s.updatedByDeviceId === a.controllerDeviceId);
    // Rebind every unused preparation byte at commit as well as body time:
    // yesterday's reservation cannot admit a class against today's spent quota.
    for (const allocation of a.preparationAllocations) moveAllocation(l, allocation, 'reservedBytes', null);
    if (a.preparationRemainingBytes > 0) checkTransferCapacity(l, a.preparationRemainingBytes, {preparing: true});
    a.preparationAllocations = ['downloadDay','downloadMonth'].map(kind =>
      reservePeriod(l, kind, a.preparationRemainingBytes));
    // A grant may expire after preparation. Already served bytes are retained;
    // starting at the exact limit is allowed when this admitted preparation
    // consumed its whole approved cold budget and has no remaining body cost.
    const view = usageView(l);
    for (const p of [view.downloadDay, view.downloadMonth]) assertUsage(p && p.usedBytes + p.reservedBytes + p.unknownBytes <= p.limitBytes + p.grantedBytes,
      'insufficient_start_budget', 'resource-exhausted');
    const value = {...a, status: 'committing', start: s, startHash: usageHash(s), committingAtMs: l.now,
      ...(selected ? {selectedTargetDeviceIds: targets} : {})};
    l.put(ref, value); l.put(l.base.collection('outbox').doc(a.admissionId), {
      // Old outbox workers reject this unknown phase instead of publishing C.
      admissionId: a.admissionId, epoch: a.epoch, phase: selected ? 'commitSelected' : 'commit', status: 'pending', createdAtMs: l.now});
    l.put(op, {payloadHash: hash, result: {admissionId: a.admissionId}}); l.flush();
  });
  await processUsageOutbox(ctx, {ownerId, admissionId: input.admissionId});
}
async function cancelAdmission(ctx, ownerId, input) {
  const hash = usageHash(input);
  await ctx.db.runTransaction(async tx => {
    const r = usageChildRef(ctx.db, ownerId, 'admissions', input.admissionId), a = (await tx.get(r)).data();
    assertUsage(a, 'session_changed');
    const l = await loadUsageLedger(ctx, tx, ownerId, a.preparationAllocations.map(x => x.periodId));
    const op = operationRef(l, 'admission', 'cancel', input.requestId);
    if (checkOperation(await tx.get(op), hash)) return;
    if (a.status === 'preparing') {
      a.status = a.prepareExpiresAtMs <= l.now ? 'expired' : 'cancelled';
      l.put(r, a); l.put(l.base.collection('outbox').doc(a.admissionId), {
        admissionId: a.admissionId, epoch: a.epoch, phase: 'cancel', status: 'pending', createdAtMs: l.now});
    }
    l.put(op, {payloadHash: hash, result: {admissionId: a.admissionId}}); l.flush();
  });
  await processUsageOutbox(ctx, {ownerId, admissionId: input.admissionId});
}

export async function processUsageOutbox(ctx, {ownerId, admissionId}) {
  requireUsageProject(ctx.projectId);
  const ref = usageChildRef(ctx.db, ownerId, 'admissions', admissionId), a = (await ref.get()).data();
  if (!a) throw usageFailure('session_changed');
  const ob = usageChildRef(ctx.db, ownerId, 'outbox', admissionId), outbox = (await ob.get()).data();
  if (!outbox || outbox.status === 'done') return;
  const now = nowOf(ctx);
  const isCommit = ['commit', 'commitSelected'].includes(outbox.phase);
  const targets = a.selectedTargetDeviceIds ?? a.targetDeviceIds;
  let published = false;
  const result = await ctx.realtime.ref(`users/${ownerId}`).transaction(current => {
    // RTDB can invoke a transaction first with an empty local cache. Returning
    // null performs a compare-and-set retry against the server; aborting here
    // would reject a valid server fence before fetching its real value.
    if (current === null) return null;
    if (current.usageGate?.enrollmentRevision !== a.enrollmentRevision ||
        current.usageGate?.mode !== 'enrolled' || (current.usageGate?.epoch ?? 0) > a.epoch) return undefined;
    const v = clone(current), active = v.activeSession, gate = v.usageGate;
    if (active && active.status !== 'completed' && active.id !== a.sessionId) return undefined;
    if (outbox.phase === 'prepare') {
      if (a.status !== 'preparing' || a.prepareExpiresAtMs <= now) return undefined;
      if (gate.epoch === a.epoch && gate.phase !== 'preparing') return undefined;
      if (!sameTargets(v, a)) return undefined;
      v.usageGate = {...gate, epoch: a.epoch, admissionId, sessionId: a.sessionId,
        manifestHash: a.manifestHash, phase: 'preparing', preparedSnapshotId: a.sessionId};
      v.displayPreparation = {request: {schemaVersion: 2, admissionId, sessionId: a.sessionId, epoch: a.epoch,
        revision: a.epoch, manifestHash: a.manifestHash, workoutId: a.manifest.workout.id,
        expiresAtMs: a.prepareExpiresAtMs, requiredProtocol: a.requiredProtocol,
        targets: Object.fromEntries(a.targetDeviceIds.map(id => [id, true])),
        images: a.images, sounds: a.sounds, imageCount: a.images.length}};
    } else if (isCommit) {
      if (!['committing','active'].includes(a.status) || gate.epoch !== a.epoch || gate.admissionId !== admissionId) return undefined;
      if (active?.id === a.sessionId) {
        if (active.epoch !== a.epoch || active.manifestHash !== a.manifestHash ||
            a.selectedTargetDeviceIds && !sameIds(active.targetDeviceIds ?? [], targets)) return undefined;
        published = true; return v;
      }
      if (gate.phase !== 'preparing' || !validReceipts(v, a, now, targets)) return undefined;
      if (!sameTargets(v, a, targets) || a.selectedTargetDeviceIds && !selectedReady(v, a, targets, now)) return undefined;
      const s = a.start, w = a.manifest.workout;
      v.playbackSnapshots ??= {}; v.playbackSnapshots[a.sessionId] = {...wireSnapshot(w), _storedAtMs: now};
      v.activeSession = {id: a.sessionId, ownerId, zoneId: 'main', targetDeviceIds: targets,
        schemaVersion: 2, snapshotId: a.sessionId, workoutId: w.id, workoutName: w.name,
        status: s.briefing ? 'paused' : 'playing', briefing: s.briefing, timerCompleted: false,
        startDelayMs: s.briefing ? 0 : (w.countdownSeconds ?? 3) * 1000, stepIndex: s.stepIndex,
        remainingMs: s.durationMs, anchorServerMs: now, revision: 1, updatedByDeviceId: s.updatedByDeviceId,
        admissionId, epoch: a.epoch, manifestHash: a.manifestHash,
        notificationCommand: {id: a.sessionId, expiresAtMs: now + 6000}};
      v.usageGate = {...gate, phase: 'active'}; published = true;
    } else if (outbox.phase === 'cancel') {
      if (active?.id === a.sessionId || gate.epoch > a.epoch) return undefined;
      if (v.displayPreparation?.request?.admissionId === admissionId) v.displayPreparation = null;
      v.usageGate = {...gate, phase: 'cancelled'};
    } else return undefined;
    return v;
  });
  if (!result.committed) {
    // An expired unstarted prepare can be cancelled with a fresh cancel outbox.
    // Committing is deliberately not refunded: publication may be ambiguous.
    if (a.status === 'preparing' && a.prepareExpiresAtMs <= now) {
      await cancelAdmission(ctx, ownerId, {schemaVersion: 1, requestId: `expire_${admissionId}`, admissionId});
      return;
    }
    throw usageFailure('usage_reconciliation_pending', 'unavailable');
  }
  const snapshot = result.snapshot.val();
  assertUsage(snapshot?.usageGate?.epoch === a.epoch && snapshot.usageGate.admissionId === admissionId,
    'usage_reconciliation_pending', 'unavailable');
  if (isCommit) assertUsage(published && snapshot?.activeSession?.id === a.sessionId &&
    snapshot.activeSession.epoch === a.epoch, 'usage_reconciliation_pending', 'unavailable');
  await ctx.db.runTransaction(async tx => {
    const latest = (await tx.get(ref)).data(), latestOutbox = (await tx.get(ob)).data();
    if (!latest || latest.epoch !== a.epoch || latestOutbox?.phase !== outbox.phase) return;
    const l = await loadUsageLedger(ctx, tx, ownerId, latest.preparationAllocations.map(x => x.periodId));
    if (isCommit && !terminal.includes(latest.status)) {
      latest.status = 'active';
      latest.publishedAtMs = now;
    }
    if (outbox.phase === 'cancel') {
      // RTDB fence acknowledged before unused preparation budget/slot release.
      for (const allocation of latest.preparationAllocations) moveAllocation(l, allocation, 'reservedBytes', null);
      latest.preparationAllocations = []; latest.preparationRemainingBytes = 0;
      if (l.account.activeAdmissionId === admissionId) l.account.activeAdmissionId = null;
    }
    l.put(ref, latest); l.put(ob, {...latestOutbox, status: 'done', acknowledgedAtMs: now}); l.flush();
  });
}
export async function reconcileUsageSession(ctx, {ownerId}) {
  requireUsageProject(ctx.projectId);
  const account = (await usageAccountRef(ctx.db, ownerId).get()).data();
  if (!account?.activeAdmissionId) return;
  const state = await ownerState(ctx, ownerId), active = state.activeSession, id = account.activeAdmissionId;
  const existing = (await usageChildRef(ctx.db, ownerId, 'admissions', id).get()).data();
  if (existing?.status === 'preparing' && existing.prepareExpiresAtMs <= nowOf(ctx)) {
    await cancelAdmission(ctx, ownerId, {schemaVersion: 1, requestId: `expire_${id}`, admissionId: id});
    return;
  }
  await ctx.db.runTransaction(async tx => {
    const ref = usageChildRef(ctx.db, ownerId, 'admissions', id), a = (await tx.get(ref)).data();
    if (!a || terminal.includes(a.status)) return;
    const matches = active?.id === a.sessionId && active.epoch === a.epoch && active.manifestHash === a.manifestHash;
    if (!matches) return; // absence/TTL is never completion evidence
    const l = await loadUsageLedger(ctx, tx, ownerId, a.preparationAllocations.map(x => x.periodId));
    if (active.status === 'completed') {
      a.status = 'completed'; a.completedAtMs = l.now;
      for (const allocation of a.preparationAllocations) moveAllocation(l, allocation, 'reservedBytes', null);
      a.preparationAllocations = []; a.preparationRemainingBytes = 0;
      if (l.account.activeAdmissionId === id) l.account.activeAdmissionId = null;
    } else if (a.status === 'committing') a.status = 'active';
    else return;
    l.put(ref, a); l.flush();
  });
}
// Enrollment is an RTDB-first claim, never a cross-store transaction. The
// enrolling fence remains durable on any failure and only the same payload
// may resume it; no timeout automatically reopens legacy direct writers.
export async function setUsageEnrollment(ctx, input) {
  requireUsageProject(ctx.projectId);
  const {ownerId, mode, policyPlan, consentRevision, requestId} = input;
  assertUsage(validUsageId(ownerId) && ['observe', 'enrolled'].includes(mode) && imageUsagePolicies[policyPlan] &&
    typeof consentRevision === 'string' && consentRevision.length > 0 && consentRevision.length <= 256);
  requireUsageMutation({schemaVersion: 1, requestId});
  const hash = usageHash({ownerId, mode, policyPlan, consentRevision, requestId}), base = usageAccountRef(ctx.db, ownerId);
  const opRef = base.collection('operations').doc(usageHash(['enrollment', mode, requestId]));
  const [accountSnap, configSnap, entitlementSnap, lock, priorOp] = await ctx.db.getAll(base,
    ctx.db.doc('appConfig/imageUsage'), ctx.db.doc(`subscriptionEntitlements/${ownerId}`),
    ctx.db.doc(`accountDeletions/${ownerId}`), opRef);
  assertUsage(!lock.exists, 'media_lease_invalid', 'permission-denied');
  const prior = checkOperation(priorOp, hash), account = accountSnap.data() ?? {};
  if (prior && priorOp.data().status === 'done') return prior;
  const eligible = (a, config, entitlement, now) => {
    assertUsage(usageConfigEnabled(config, ctx.projectId), 'policy_or_client_upgrade_required');
    if (mode === 'enrolled') assertUsage(a.inventoryComplete === true && a.eligibility?.tokenFree === true &&
      a.eligibility?.rulesReady === true && entitlement?.plan === policyPlan && entitlement.canStartClass === true &&
      ['active','trialing','grace_period','canceling','past_due'].includes(entitlement.status) && entitlement.validUntilMs > now,
    'policy_or_client_upgrade_required');
    assertUsage(!a.activeAdmissionId, 'session_changed');
  };
  const owner = await ownerState(ctx, ownerId);
  if (owner.usageGate?.enrollmentRequestId === requestId) assertUsage(owner.usageGate.enrollmentPayloadHash === hash,
    'idempotency_conflict', 'already-exists');
  if (!prior) eligible(account, configSnap.data(), entitlementSnap.data(), nowOf(ctx));
  assertUsage(!owner.activeSession || owner.activeSession.status === 'completed', 'session_changed');
  const claimed = await ctx.realtime.ref(`users/${ownerId}`).transaction(current => {
    if (current === null && prior) return null; // fetch the authoritative existing claim on an empty SDK cache
    const v = clone(current ?? {}), previous = v.usageGate ?? {};
    if (v.activeSession && v.activeSession.status !== 'completed') return undefined;
    if (previous.enrollmentRequestId === requestId) {
      if (previous.enrollmentPayloadHash !== hash || previous.targetMode !== mode || previous.targetPolicyPlan !== policyPlan) return undefined;
      if (!['enrolling', mode].includes(previous.mode)) return undefined;
      return v; // includes response loss after the RTDB finalize phase
    }
    if (previous.mode === 'enrolling') return undefined;
    if (prior) return undefined; // a different/newer claim must not be overwritten
    v.usageGate = {...previous, mode: 'enrolling', phase: 'enrolling', policyRevision: imageUsagePolicyRevision,
      epoch: previous.epoch ?? 0, enrollmentRevision: Math.max(previous.enrollmentRevision ?? 0, account.enrollmentRevision ?? 0) + 1,
      enrollmentRequestId: requestId, enrollmentPayloadHash: hash, targetMode: mode, targetPolicyPlan: policyPlan,
      enrollmentConsentRevision: consentRevision, enrollmentClaimedAtMs: nowOf(ctx)};
    return v;
  });
  assertUsage(claimed.committed && claimed.snapshot.val()?.usageGate?.enrollmentRequestId === requestId &&
    claimed.snapshot.val().usageGate.enrollmentPayloadHash === hash, 'usage_reconciliation_pending', 'unavailable');
  const claim = claimed.snapshot.val().usageGate;
  const value = await ctx.db.runTransaction(async tx => {
    const l = await loadUsageLedger(ctx, tx, ownerId), op = await tx.get(opRef);
    const old = checkOperation(op, hash);
    if (old) {
      assertUsage(old.enrollmentRevision === claim.enrollmentRevision, 'usage_reconciliation_pending');
      return old;
    }
    eligible(l.account, l.config, l.entitlement, l.now);
    Object.assign(l.account, {mode, policyPlan, policyRevision: imageUsagePolicyRevision, consentRevision,
      enrollmentPending: true, enrollmentRevision: claim.enrollmentRevision,
      enrollmentRequestId: requestId, enrollmentPayloadHash: hash});
    const result = {ownerId, mode, policyPlan, enrollmentRevision: claim.enrollmentRevision};
    l.put(opRef, {payloadHash: hash, result, status: 'pending', createdAtMs: l.now});
    l.put(l.base.collection('audit').doc(usageHash(['enrollment', requestId])), {
      type: 'enrollment_claimed', requestId, payloadHash: hash, ownerId, targetMode: mode,
      policyPlan, enrollmentRevision: claim.enrollmentRevision, createdAtMs: l.now});
    l.flush(); return result;
  });
  const finalized = await ctx.realtime.ref(`users/${ownerId}`).transaction(current => {
    if (current === null) return null;
    const v = clone(current), gate = v.usageGate;
    if (!gate || gate.enrollmentRequestId !== requestId || gate.enrollmentPayloadHash !== hash ||
        gate.enrollmentRevision !== value.enrollmentRevision || !['enrolling', mode].includes(gate.mode)) return undefined;
    // A retry trigger may have completed this exact claim while the original
    // setter was waiting on Firestore. A later legitimate class can now own the
    // phase/epoch/slot: acknowledge enrollment without regressing its fence.
    if (gate.mode === mode) return v;
    if (v.activeSession && v.activeSession.status !== 'completed') return undefined;
    v.usageGate = {...gate, mode, phase: 'idle', enrollmentFinalizedAtMs: nowOf(ctx)};
    return v;
  });
  assertUsage(finalized.committed && finalized.snapshot.val()?.usageGate?.mode === mode &&
    finalized.snapshot.val().usageGate.enrollmentRevision === value.enrollmentRevision,
  'usage_reconciliation_pending', 'unavailable');
  await ctx.db.runTransaction(async tx => {
    const [aSnap, op] = await tx.getAll(base, opRef), a = aSnap.data();
    assertUsage(a?.enrollmentRevision === value.enrollmentRevision && a.enrollmentPayloadHash === hash,
      'usage_reconciliation_pending', 'unavailable');
    if (op.data()?.status === 'done' && a.enrollmentPending === false) return;
    tx.set(base, {...a, enrollmentPending: false, revision: (a.revision ?? 0) + 1});
    tx.set(opRef, {...op.data(), status: 'done', acknowledgedAtMs: nowOf(ctx)});
  });
  return value;
}
export async function reconcileUsageEnrollment(ctx, {ownerId}) {
  requireUsageProject(ctx.projectId);
  const gate = (await ctx.realtime.ref(`users/${ownerId}/usageGate`).get()).val();
  if (!gate?.enrollmentRequestId || !gate.enrollmentPayloadHash) return null;
  const account = (await usageAccountRef(ctx.db, ownerId).get()).data();
  if (gate.mode !== 'enrolling' && account?.enrollmentPending !== true) return null;
  return setUsageEnrollment(ctx, {ownerId, mode: gate.targetMode, policyPlan: gate.targetPolicyPlan,
    consentRevision: gate.enrollmentConsentRevision, requestId: gate.enrollmentRequestId});
}
