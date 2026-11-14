import {randomUUID} from 'node:crypto';
import {assertUsage, imageUsagePolicies, imageUsagePolicyRevision, nowOf, usagePeriods, usageHash,
  validUsageId, validBytes, requireUsageProject, usageConfigEnabled, usageFailure} from './image-usage-policy.js';

export const usageAccountRef = (db, uid) => db.doc(`imageUsageAccounts/${uid}`);
export const usageChildRef = (db, uid, kind, id) => usageAccountRef(db, uid).collection(kind).doc(id);
const copy = value => structuredClone(value);
const emptyPeriod = (kind, key, resetsAtMs) => ({kind, key, resetsAtMs, usedBytes: 0,
  reservedBytes: 0, unknownBytes: 0, protectedOverageBytes: 0, allocations: {}});
const fields = ['usedBytes', 'reservedBytes', 'unknownBytes'];
const count = value => fields.reduce((n, k) => n + (value?.[k] ?? 0), 0);
const activeStatuses = ['active', 'trialing', 'grace_period', 'canceling', 'past_due'];
export const usagePeriodId = (kind, key) => `${kind}_${key}`;

// All reads finish before flush(). Deferred writes let admission/grants compose
// the same account transaction without Firestore read-after-write hazards.
export async function loadUsageLedger(ctx, tx, ownerId, extraPeriodIds = []) {
  assertUsage(validUsageId(ownerId), 'media_lease_invalid', 'permission-denied');
  const now = nowOf(ctx), periods = usagePeriods(now), base = usageAccountRef(ctx.db, ownerId);
  const ids = [...new Set([usagePeriodId('uploadDay', periods.dayKey),
    usagePeriodId('downloadDay', periods.dayKey), usagePeriodId('downloadMonth', periods.monthKey), ...extraPeriodIds])];
  const refs = [base, ctx.db.doc('appConfig/imageUsage'), ctx.db.doc(`subscriptionEntitlements/${ownerId}`),
    ctx.db.doc(`accountDeletions/${ownerId}`), ...ids.map(id => base.collection('periods').doc(id))];
  const snapshots = await tx.getAll(...refs);
  assertUsage(!snapshots[3].exists, 'media_lease_invalid', 'permission-denied');
  const account = snapshots[0].data() ?? {mode: 'legacy', policyPlan: null, revision: 0,
    storageUsedBytes: 0, storageReservedBytes: 0, storageUnknownBytes: 0, inventoryComplete: false};
  const config = snapshots[1].data(), entitlement = snapshots[2].data();
  const grantSnapshot = await tx.get(base.collection('grants').where('status', '==', 'active').limit(201));
  assertUsage(grantSnapshot.size <= 200, 'usage_reconciliation_pending');
  const grants = grantSnapshot.docs.map(d => ({...d.data(), grantId: d.id}))
    .filter(g => g.validFromMs <= now && now < g.validUntilMs)
    .sort((a, b) => a.validUntilMs - b.validUntilMs || a.grantId.localeCompare(b.grantId));
  const map = new Map(ids.map((id, i) => {
    const kind = id.slice(0, id.indexOf('_')), key = id.slice(id.indexOf('_') + 1);
    const resets = kind === 'downloadMonth' ? periods.monthReset : periods.dayReset;
    const value = snapshots[i + 4].data() ?? emptyPeriod(kind, key, resets);
    for (const field of fields) assertUsage(validBytes(value[field] ?? 0), 'usage_reconciliation_pending');
    return [id, value];
  }));
  for (const f of ['storageUsedBytes', 'storageReservedBytes', 'storageUnknownBytes']) {
    assertUsage(validBytes(account[f] ?? 0), 'usage_reconciliation_pending');
  }
  const writes = new Map();
  const ledger = {ctx, tx, ownerId, base, now, periods, account, config, entitlement, grants, map,
    policy: imageUsagePolicies[account.policyPlan] ?? null,
    put(ref, value) { writes.set(ref.path, {ref, value}); },
    flush() {
      for (const [id, value] of map) tx.set(base.collection('periods').doc(id), value);
      tx.set(base, {...account, revision: (account.revision ?? 0) + 1, updatedAtMs: now});
      for (const {ref, value} of writes.values()) tx.set(ref, value);
    },
  };
  return ledger;
}
export function requireLedgerEnabled(l, {protectedSession = false, requireInventory = true} = {}) {
  requireUsageProject(l.ctx.projectId);
  if (l.account.mode === 'enrolled' && !protectedSession) {
    assertUsage(usageConfigEnabled(l.config, l.ctx.projectId) && l.account.policyRevision === imageUsagePolicyRevision &&
      l.account.enrollmentPending !== true, 'policy_or_client_upgrade_required');
    assertUsage(l.policy && (!requireInventory || l.account.inventoryComplete === true), 'usage_reconciliation_pending');
    assertUsage(l.entitlement && l.entitlement.plan === l.account.policyPlan &&
      l.entitlement.canStartClass === true && activeStatuses.includes(l.entitlement.status) &&
      Number.isSafeInteger(l.entitlement.validUntilMs) && l.entitlement.validUntilMs > l.now,
    'entitlement_unverified');
  }
}
export function periodLimit(l, kind) {
  return l.policy?.[`${kind}LimitBytes`] ?? null;
}
function grantAmount(g, p) {
  return p.kind === 'downloadDay' && g.targetDayKey === p.key ? g.additionalDayBytes :
    p.kind === 'downloadMonth' && g.targetMonthKey === p.key ? g.additionalMonthBytes : 0;
}
export function usageView(l) {
  const period = kind => {
    if (!l.policy) return null;
    const id = usagePeriodId(kind, kind === 'downloadMonth' ? l.periods.monthKey : l.periods.dayKey), p = l.map.get(id);
    const limitBytes = periodLimit(l, kind), grantedBytes = l.grants.reduce((n, g) => n + grantAmount(g, p), 0);
    return {key: p.key, resetsAtMs: p.resetsAtMs, limitBytes, grantedBytes,
      usedBytes: p.usedBytes ?? 0, reservedBytes: p.reservedBytes ?? 0, unknownBytes: p.unknownBytes ?? 0,
      remainingBytes: Math.max(0, limitBytes + grantedBytes - count(p)), protectedOverageBytes: p.protectedOverageBytes ?? 0};
  };
  const day = period('downloadDay'), month = period('downloadMonth');
  let nextEligibleAtMs = null;
  if (l.account.mode === 'enrolled' && !l.account.activeAdmissionId && day && month &&
      day.reservedBytes + month.reservedBytes + day.unknownBytes + month.unknownBytes === 0 &&
      usageConfigEnabled(l.config, l.ctx.projectId)) {
    const candidate = month.remainingBytes === 0 ? month.resetsAtMs : day.remainingBytes === 0 ? day.resetsAtMs : null;
    if (candidate && l.entitlement?.canStartClass === true && l.entitlement.validUntilMs > candidate) nextEligibleAtMs = candidate;
  }
  return {schemaVersion: 1, policyRevision: imageUsagePolicyRevision, mode: l.account.mode ?? 'legacy',
    policyPlan: l.account.policyPlan ?? null, measuredAtMs: l.now, revision: l.account.revision ?? 0,
    storage: {limitBytes: l.policy?.storageLimitBytes ?? null, usedBytes: l.account.storageUsedBytes ?? 0,
      reservedBytes: l.account.storageReservedBytes ?? 0, unknownBytes: l.account.storageUnknownBytes ?? 0,
      complete: l.account.inventoryComplete === true}, uploadDay: period('uploadDay'),
    downloadDay: day, downloadMonth: month,
    attribution: l.account.mode === 'enrolled' && l.account.inventoryComplete === true ? 'gateway' :
      l.account.mode === 'observe' ? 'partial_legacy' : 'unknown', nextEligibleAtMs};
}
export async function readUsage(ctx, {ownerId}) {
  if (ctx.projectId === 'cloud-board-development' || /^demo-[a-z0-9-]+$/.test(ctx.projectId ?? '')) {
    await reconcileAbandonedUsage(ctx, {ownerId});
  }
  return ctx.db.runTransaction(async tx => usageView(await loadUsageLedger(ctx, tx, ownerId)));
}
// Function death cannot execute a close callback. Bounded reconciliation moves
// abandoned claims to unknown, retaining the full conservative upper bound.
// A late successful finish may still resolve unknown -> served, never the reverse.
export async function reconcileAbandonedUsage(ctx, {ownerId}) {
  requireUsageProject(ctx.projectId);
  return ctx.db.runTransaction(async tx => {
    const base = usageAccountRef(ctx.db, ownerId), now = nowOf(ctx);
    const [attempts, writing, reserved] = await Promise.all([
      tx.get(base.collection('attempts').where('status', '==', 'reserved').limit(100)),
      tx.get(base.collection('uploads').where('status', '==', 'writing').limit(100)),
      tx.get(base.collection('uploads').where('status', '==', 'reserved').limit(100)),
    ]);
    const staleAttempts = attempts.docs.filter(d => d.data().createdAtMs + 600000 < now);
    const staleWriting = writing.docs.filter(d => d.data().writingAtMs + 600000 < now);
    const expiredPermits = reserved.docs.filter(d => d.data().expiresAtMs <= now);
    if (![...staleAttempts, ...staleWriting, ...expiredPermits].length) return;
    const ids = [...staleAttempts.flatMap(d => d.data().allocations.map(a => a.periodId)),
      ...[...staleWriting, ...expiredPermits].map(d => d.data().allocation.periodId)];
    const l = await loadUsageLedger(ctx, tx, ownerId, ids);
    for (const d of staleAttempts) {
      const r = d.data();
      for (const a of r.allocations) moveAllocation(l, a, 'reservedBytes', 'unknownBytes');
      l.put(d.ref, {...r, status: 'unknown', bodyBytes: null, reconciledAtMs: now});
    }
    for (const d of [...staleWriting, ...expiredPermits]) {
      const r = d.data(), unknown = r.status === 'writing';
      moveAllocation(l, r.allocation, 'reservedBytes', unknown ? 'unknownBytes' : null);
      l.account.storageReservedBytes -= r.sizeBytes;
      if (unknown) l.account.storageUnknownBytes = (l.account.storageUnknownBytes ?? 0) + r.sizeBytes;
      l.put(d.ref, {...r, status: unknown ? 'unknown' : 'expired', reconciledAtMs: now});
    }
    l.flush();
  });
}
export function checkTransferCapacity(l, sizeBytes, {preparing = false} = {}) {
  if (l.account.mode !== 'enrolled') return;
  const view = usageView(l), d = view.downloadDay, m = view.downloadMonth;
  assertUsage(d && m, 'usage_reconciliation_pending');
  if (d.remainingBytes >= sizeBytes && m.remainingBytes >= sizeBytes && d.remainingBytes > 0 && m.remainingBytes > 0) return;
  const reason = d.remainingBytes === 0 && m.remainingBytes === 0 ? 'both_transfer_limits' :
    d.remainingBytes === 0 ? 'daily_transfer_limit' : m.remainingBytes === 0 ? 'monthly_transfer_limit' : 'insufficient_start_budget';
  throw usageFailure(reason, 'resource-exhausted', {usage: view, requiredBytes: preparing ? sizeBytes : null,
    nextEligibleAtMs: view.nextEligibleAtMs});
}
export function reservePeriod(l, kind, sizeBytes, {protectedSession = false, check = true} = {}) {
  const key = kind === 'downloadMonth' ? l.periods.monthKey : l.periods.dayKey;
  const periodId = usagePeriodId(kind, key), p = l.map.get(periodId), limit = periodLimit(l, kind);
  const before = count(p), activeGrants = l.grants.filter(g => grantAmount(g, p) > 0);
  const granted = activeGrants.reduce((n, g) => n + grantAmount(g, p), 0);
  if (check && l.account.mode === 'enrolled' && !protectedSession && limit !== null) {
    assertUsage(before + sizeBytes <= limit + granted,
      kind === 'uploadDay' ? 'daily_upload_limit' : 'insufficient_start_budget', 'resource-exhausted', {requiredBytes: sizeBytes});
  }
  const previousGrantUsage = Object.values(p.allocations ?? {}).reduce((n, a) => n + count(a), 0);
  let remaining = sizeBytes, baseBytes = limit === null ? sizeBytes : Math.min(sizeBytes, Math.max(0, limit - (before - previousGrantUsage)));
  remaining -= baseBytes;
  const allocation = {periodId, sizeBytes, baseBytes, grants: {}};
  p.allocations ??= {};
  for (const g of activeGrants) {
    const a = p.allocations[g.grantId] ??= {usedBytes: 0, reservedBytes: 0, unknownBytes: 0};
    const bytes = Math.min(remaining, Math.max(0, grantAmount(g, p) - count(a)));
    if (bytes > 0) { a.reservedBytes += bytes; allocation.grants[g.grantId] = bytes; remaining -= bytes; }
  }
  // Protected overage is reserved without pretending it was an additional grant.
  allocation.baseBytes += remaining;
  p.reservedBytes = (p.reservedBytes ?? 0) + sizeBytes;
  allocation.protectedOverageBytes = protectedSession && limit !== null ?
    Math.max(0, before + sizeBytes - limit - granted) - Math.max(0, before - limit - granted) : 0;
  return allocation;
}
export function moveAllocation(l, allocation, from, to, amount = allocation.sizeBytes) {
  const p = l.map.get(allocation.periodId);
  assertUsage(p && validBytes(amount) && amount <= allocation.sizeBytes, 'usage_reconciliation_pending');
  assertUsage((p[from] ?? 0) >= allocation.sizeBytes, 'usage_reconciliation_pending');
  p[from] -= allocation.sizeBytes;
  if (to) p[to] = (p[to] ?? 0) + amount;
  let remaining = Math.max(0, amount - allocation.baseBytes);
  for (const [id, bytes] of Object.entries(allocation.grants ?? {})) {
    const a = p.allocations[id];
    assertUsage(a && (a[from] ?? 0) >= bytes, 'usage_reconciliation_pending');
    a[from] -= bytes;
    const selected = Math.min(remaining, bytes); remaining -= selected;
    if (to) a[to] = (a[to] ?? 0) + selected;
  }
  if (to === 'usedBytes') p.protectedOverageBytes = (p.protectedOverageBytes ?? 0) +
    Math.min(amount, allocation.protectedOverageBytes ?? 0);
}
export const operationRef = (l, endpoint, action, requestId) => l.base.collection('operations')
  .doc(usageHash([endpoint, action, requestId]));
export function checkOperation(snapshot, payloadHash) {
  if (!snapshot.exists) return null;
  assertUsage(snapshot.data().payloadHash === payloadHash, 'idempotency_conflict', 'already-exists');
  return snapshot.data().result;
}
// Preparation authorizes the cohort; after commit acceptance only the frozen
// playback selection may use its media budget/protected session. Old records
// have no selection field and retain their existing whole-cohort behavior.
function admissionIncludesDevice(a, deviceId) {
  const targets = a?.status === 'preparing' ? a.targetDeviceIds : a?.selectedTargetDeviceIds ?? a?.targetDeviceIds;
  return deviceId == null || targets?.includes(deviceId) === true;
}

export async function requireUsageContext(ctx, input) {
  const {actorUid, purpose, sessionId = null, admissionId = null} = input;
  assertUsage(validUsageId(actorUid), 'media_lease_invalid', 'unauthenticated');
  const access = (await ctx.realtime.ref(`displayAccess/${actorUid}`).get()).val();
  const ownerId = input.ownerId ?? access?.ownerId ?? actorUid;
  assertUsage(validUsageId(ownerId) && (ownerId === actorUid || access?.ownerId === ownerId), 'media_lease_invalid', 'permission-denied');
  const [owner, actorAccess, ownerAccess] = await Promise.all([
    ctx.realtime.ref(`users/${ownerId}`).get(), ctx.realtime.ref(`authAccess/${actorUid}`).get(),
    ctx.realtime.ref(`authAccess/${ownerId}`).get(),
  ]);
  assertUsage(actorAccess.val()?.disabled !== true && ownerAccess.val()?.disabled !== true, 'media_lease_invalid', 'permission-denied');
  const deviceId = ownerId === actorUid ? null : access?.deviceId;
  let deviceBinding = null;
  if (ownerId !== actorUid) {
    const device = owner.val()?.devices?.[deviceId];
    const revoked = (await ctx.realtime.ref(`displayConnectionRevocations/${actorUid}`).get()).val();
    assertUsage(validUsageId(deviceId) && device?.paired === true && device.id === deviceId && device.displayUid === actorUid &&
      access?.deviceId === deviceId && device.pairingCode === access.pairingCode &&
      (device.pairedAtMs ?? null) === (access.pairedAtMs ?? null) &&
      (!revoked || (access.pairingCode && !revoked[access.pairingCode])), 'media_lease_invalid', 'permission-denied');
    deviceBinding = {displayUid: actorUid, pairingCode: device.pairingCode, pairedAtMs: device.pairedAtMs ?? null};
  }
  const [account, lock, admission] = await ctx.db.getAll(usageAccountRef(ctx.db, ownerId),
    ctx.db.doc(`accountDeletions/${ownerId}`),
    usageChildRef(ctx.db, ownerId, 'admissions', admissionId ?? '_none'));
  assertUsage(!lock.exists, 'media_lease_invalid', 'permission-denied');
  const a = admission.data(), gate = owner.val()?.usageGate, active = owner.val()?.activeSession;
  let protectedSession = false;
  if (admissionId || sessionId) {
    assertUsage(a && a.sessionId === sessionId && ['preparing', 'committing', 'active'].includes(a.status) &&
      admissionIncludesDevice(a, deviceId), 'media_lease_invalid', 'permission-denied');
    if (deviceId !== null) {
      const frozen = a.targetBindings?.[deviceId], currentDevice = owner.val()?.devices?.[deviceId];
      assertUsage(frozen?.displayUid === actorUid && frozen.pairingCode === access.pairingCode &&
        frozen.pairedAtMs === (currentDevice?.pairedAtMs ?? null), 'media_lease_invalid', 'permission-denied');
    }
    protectedSession = ['committing', 'active'].includes(a.status) && active?.id === a.sessionId &&
      active?.epoch === a.epoch && active?.manifestHash === a.manifestHash && active.status !== 'completed' &&
      gate?.epoch === a.epoch && gate?.sessionId === a.sessionId;
    if (purpose === 'preparation' && !protectedSession) {
      assertUsage(a.status === 'preparing' && a.prepareExpiresAtMs > nowOf(ctx), 'admission_expired');
    } else if (purpose === 'playback') assertUsage(protectedSession, 'media_lease_invalid', 'permission-denied');
  } else assertUsage(purpose === 'preview' || deviceId === null && purpose === 'upload', 'media_lease_invalid', 'permission-denied');
  const brand = owner.val()?.operations?.brand;
  const allowedAssetSources = deviceId !== null && purpose === 'preview' ? [...new Set([
    brand?.logoUrl, brand?.backgroundImageUrl, ...(Array.isArray(brand?.promotionImageUrls) ? brand.promotionImageUrls :
      brand?.promotionImageUrls && typeof brand.promotionImageUrls === 'object' ? Object.values(brand.promotionImageUrls) : []),
  ].filter(s => typeof s === 'string' && s.length > 0))] : null;
  return {ownerId, actorUid, deviceId, mode: account.data()?.mode ?? 'legacy',
    policyPlan: account.data()?.policyPlan ?? null, protected: protectedSession,
    admissionId, sessionId, epoch: a?.epoch ?? null, manifestHash: a?.manifestHash ?? null,
    deviceBinding, allowedAssetSources};
}

export async function reserveUpload(ctx, input) {
  requireUsageProject(ctx.projectId);
  const {ownerId, requestId, payloadHash, purpose, workoutId = null, sha256, sizeBytes, contentType, generatedOutput = null} = input;
  const generated = purpose === 'generated';
  assertUsage(validBytes(sizeBytes) && sizeBytes > 0 && sizeBytes < (purpose === 'profile' ? 5242880 : 10485760) &&
    ['workout', 'brand', 'profile', 'generated'].includes(purpose) &&
    (generated ? sha256 === null && generatedOutput?.hashStatus === 'pending' &&
      typeof generatedOutput.provenance === 'string' && generatedOutput.provenance.length > 0 && generatedOutput.provenance.length <= 120 :
      /^[a-f0-9]{64}$/.test(sha256 ?? '') && generatedOutput === null) &&
    ['image/png', 'image/jpeg', 'image/webp', 'image/gif'].includes(contentType));
  assertUsage(typeof requestId === 'string' && requestId.length >= 8 && typeof payloadHash === 'string');
  const uploadId = randomUUID();
  return ctx.db.runTransaction(async tx => {
    const l = await loadUsageLedger(ctx, tx, ownerId), op = operationRef(l, 'upload', 'reserve', requestId);
    const previous = checkOperation(await tx.get(op), payloadHash);
    if (previous) return (await tx.get(l.base.collection('uploads').doc(previous.uploadId))).data();
    requireLedgerEnabled(l);
    if (l.account.mode === 'enrolled') assertUsage((l.account.storageUsedBytes ?? 0) +
      (l.account.storageReservedBytes ?? 0) + (l.account.storageUnknownBytes ?? 0) + sizeBytes <= l.policy.storageLimitBytes,
    'storage_limit', 'resource-exhausted', {requiredBytes: sizeBytes, usage: usageView(l)});
    const allocation = reservePeriod(l, 'uploadDay', sizeBytes);
    l.account.storageReservedBytes = (l.account.storageReservedBytes ?? 0) + sizeBytes;
    const path = `users/${ownerId}/managed-images/${purpose}/${uploadId}/${generated ? 'pending' : sha256}`;
    const value = {schemaVersion: 1, uploadId, reservationId: uploadId, ownerId, path, sha256, sizeBytes,
      generatedOutput, boundOutput: null,
      contentType, purpose, workoutId, expiresAtMs: l.now + 300000, status: 'reserved', asset: null,
      uploadUrl: `https://asia-northeast3-${ctx.projectId}.cloudfunctions.net/cloudboardImageUploadBody`,
      allocation, createdAtMs: l.now};
    l.put(l.base.collection('uploads').doc(uploadId), value);
    l.put(op, {payloadHash, result: {uploadId}, createdAtMs: l.now}); l.flush(); return value;
  });
}
export async function beginUpload(ctx, {ownerId, uploadId, actorUid}) {
  assertUsage(ownerId === actorUid, 'media_lease_invalid', 'permission-denied');
  return ctx.db.runTransaction(async tx => {
    const l = await loadUsageLedger(ctx, tx, ownerId), ref = l.base.collection('uploads').doc(uploadId);
    const record = (await tx.get(ref)).data();
    assertUsage(record, 'upload_mismatch');
    if (record.status === 'stored') return record;
    requireLedgerEnabled(l);
    assertUsage(record.status === 'reserved' && record.expiresAtMs > l.now, 'upload_mismatch', 'failed-precondition');
    const value = {...record, status: 'writing', writingAtMs: l.now}; l.put(ref, value); l.flush(); return value;
  });
}
// Server-only output binding. Public raw upload never accepts purpose generated
// or this API. The reserved maximum remains the settlement upper bound.
export async function bindGeneratedUpload(ctx, {ownerId, uploadId, actorUid, sha256, sizeBytes}) {
  requireUsageProject(ctx.projectId);
  assertUsage(ownerId === actorUid && /^[a-f0-9]{64}$/.test(sha256 ?? '') && validBytes(sizeBytes) && sizeBytes > 0,
    'upload_mismatch', 'permission-denied');
  return ctx.db.runTransaction(async tx => {
    const ref = usageChildRef(ctx.db, ownerId, 'uploads', uploadId), r = (await tx.get(ref)).data();
    assertUsage(r && r.purpose === 'generated' && r.generatedOutput &&
      ['writing', 'unknown', 'stored'].includes(r.status) && sizeBytes <= r.sizeBytes, 'upload_mismatch');
    if (r.boundOutput) {
      assertUsage(r.boundOutput.sha256 === sha256 && r.boundOutput.sizeBytes === sizeBytes, 'idempotency_conflict', 'already-exists');
      return r;
    }
    assertUsage(r.status === 'writing' && r.generatedOutput.hashStatus === 'pending', 'upload_mismatch');
    const value = {...r, path: `users/${ownerId}/managed-images/generated/${uploadId}/${sha256}`, sha256,
      generatedOutput: {...r.generatedOutput, hashStatus: 'bound'}, boundOutput: {sha256, sizeBytes}, boundAtMs: nowOf(ctx)};
    tx.set(ref, value); return value;
  });
}
export async function settleUpload(ctx, {ownerId, uploadId, outcome, asset = null}) {
  return ctx.db.runTransaction(async tx => {
    const ref = usageChildRef(ctx.db, ownerId, 'uploads', uploadId), snapshot = await tx.get(ref), r = snapshot.data();
    assertUsage(r && ['stored', 'not_written', 'unknown'].includes(outcome));
    const l = await loadUsageLedger(ctx, tx, ownerId, [r.allocation.periodId]);
    if (r.status === 'stored' || ['cancelled', 'expired'].includes(r.status)) return r;
    // A client cancel may have read 'reserved' before beginUpload claimed it.
    // Never refund a writing/unknown permit on that stale cancellation.
    if (outcome === 'not_written' && r.status !== 'reserved') return r;
    if (outcome === 'unknown' && r.status === 'unknown') return r;
    const from = r.status === 'unknown' ? 'unknownBytes' : 'reservedBytes';
    if (outcome === 'stored') {
      const actualBytes = asset?.sizeBytes;
      assertUsage(asset?.ownerId === ownerId && asset.path === r.path && validBytes(actualBytes) && actualBytes > 0 &&
        (r.purpose === 'generated' ? r.generatedOutput?.hashStatus === 'bound' &&
          actualBytes <= r.sizeBytes && actualBytes === r.boundOutput?.sizeBytes && asset.sha256 === r.boundOutput?.sha256 :
          actualBytes === r.sizeBytes && asset.sha256 === r.sha256) && asset.contentType === r.contentType && asset.tokenFree === true &&
        /^[0-9]+$/.test(asset.generation ?? '') && validUsageId(asset.assetId), 'upload_mismatch');
      const existing = await tx.get(l.base.collection('assets').doc(asset.assetId));
      assertUsage(!existing.exists || (existing.data().path === asset.path && existing.data().generation === asset.generation), 'upload_mismatch');
      assertUsage(r.status === 'writing' || r.status === 'unknown', 'upload_mismatch');
      const alreadyAccounted = existing.data()?.accounted === true;
      moveAllocation(l, r.allocation, from, alreadyAccounted ? null : 'usedBytes', actualBytes);
      l.account[from === 'unknownBytes' ? 'storageUnknownBytes' : 'storageReservedBytes'] -= r.sizeBytes;
      l.account.storageUsedBytes = (l.account.storageUsedBytes ?? 0) + (alreadyAccounted ? 0 : actualBytes);
      l.put(l.base.collection('assets').doc(asset.assetId), {...asset, accounted: true, createdAtMs: l.now});
    } else {
      moveAllocation(l, r.allocation, from, outcome === 'unknown' ? 'unknownBytes' : null);
      l.account[from === 'unknownBytes' ? 'storageUnknownBytes' : 'storageReservedBytes'] -= r.sizeBytes;
      if (outcome === 'unknown') l.account.storageUnknownBytes = (l.account.storageUnknownBytes ?? 0) + r.sizeBytes;
    }
    const value = {...r, status: outcome === 'stored' ? 'stored' : outcome === 'unknown' ? 'unknown' : 'cancelled',
      asset: outcome === 'stored' ? asset : null, settledAtMs: l.now};
    l.put(ref, value); l.flush(); return value;
  });
}
export async function reserveTransfer(ctx, input) {
  requireUsageProject(ctx.projectId);
  const {ownerId, actorUid, deviceId, leaseId, assetId, generation, sizeBytes, admissionId = null,
    sessionId = null, purpose} = input;
  assertUsage(validBytes(sizeBytes) && sizeBytes > 0, 'media_lease_invalid');
  const identity = await requireUsageContext(ctx, {ownerId, actorUid, purpose, sessionId, admissionId});
  assertUsage(identity.deviceId === (deviceId ?? null), 'media_lease_invalid', 'permission-denied');
  const attemptId = randomUUID();
  return ctx.db.runTransaction(async tx => {
    const ar = admissionId ? await tx.get(usageChildRef(ctx.db, ownerId, 'admissions', admissionId)) : null;
    const admission = ar?.data(), oldIds = admission?.preparationAllocations?.map(a => a.periodId) ?? [];
    // Recheck after the context read: commit may have frozen a smaller selection
    // while this transfer was waiting for its Firestore transaction.
    if (admissionId) assertUsage(admissionIncludesDevice(admission, deviceId), 'media_lease_invalid', 'permission-denied');
    const l = await loadUsageLedger(ctx, tx, ownerId, oldIds);
    const asset = (await tx.get(l.base.collection('assets').doc(assetId))).data();
    assertUsage(asset?.ownerId === ownerId && asset.tokenFree === true && asset.generation === generation &&
      asset.sizeBytes === sizeBytes && (!admission || admission.assets.some(a => a.assetId === assetId && a.generation === generation)),
    'media_lease_invalid', 'permission-denied');
    if (identity.allowedAssetSources !== null) assertUsage(identity.allowedAssetSources.includes(asset.source),
      'media_lease_invalid', 'permission-denied');
    // An RTDB-active admission remains protected even if FS finalization failed.
    const protectedSession = identity.protected && ['active', 'committing'].includes(admission?.status);
    if (admissionId) assertUsage(admission && !['cancelled', 'expired', 'completed'].includes(admission.status) &&
      (protectedSession || admission.prepareExpiresAtMs > l.now), 'admission_expired');
    requireLedgerEnabled(l, {protectedSession});
    let preparationAvailable = admission?.preparationRemainingBytes ?? 0;
    const usingPreparation = purpose !== 'preview' && admission && preparationAvailable >= sizeBytes;
    if (usingPreparation) {
      // Release only the slice assigned to this request, keeping other attempts
      // and unused preparation reservations intact across midnight.
      const ratioAllocations = [];
      for (const allocation of admission.preparationAllocations) {
        const slice = splitAllocation(allocation, sizeBytes);
        moveAllocation(l, slice, 'reservedBytes', null); ratioAllocations.push(slice);
      }
      admission.preparationRemainingBytes -= sizeBytes;
      admission.preparationAllocations = admission.preparationAllocations.map((a, i) => subtractAllocation(a, ratioAllocations[i]));
    }
    if (!protectedSession) checkTransferCapacity(l, sizeBytes);
    const allocations = ['downloadDay', 'downloadMonth'].map(kind => reservePeriod(l, kind, sizeBytes, {protectedSession}));
    l.put(l.base.collection('attempts').doc(attemptId), {attemptId, reservationId: attemptId, leaseId,
      assetId, generation, sizeBytes, actorUid, deviceId: deviceId ?? null, admissionId, sessionId,
      protected: protectedSession, status: 'reserved', allocations, createdAtMs: l.now});
    if (usingPreparation) l.put(ar.ref, admission);
    l.flush(); return {attemptId, reservationId: attemptId, protected: protectedSession};
  });
}
function splitAllocation(allocation, bytes) {
  let left = bytes;
  const baseBytes = Math.min(left, allocation.baseBytes); left -= baseBytes;
  const grants = {};
  for (const [id, available] of Object.entries(allocation.grants)) {
    grants[id] = Math.min(left, available); left -= grants[id];
  }
  assertUsage(left === 0, 'usage_reconciliation_pending');
  return {...allocation, sizeBytes: bytes, baseBytes, grants};
}
function subtractAllocation(allocation, slice) {
  return {...allocation, sizeBytes: allocation.sizeBytes - slice.sizeBytes, baseBytes: allocation.baseBytes - slice.baseBytes,
    grants: Object.fromEntries(Object.entries(allocation.grants).map(([id, value]) => [id, value - (slice.grants[id] ?? 0)]))};
}
export async function settleTransfer(ctx, {ownerId, attemptId, outcome, bodyBytes}) {
  assertUsage(['served', 'not_sent', 'unknown'].includes(outcome) && validBytes(bodyBytes));
  assertUsage(outcome !== 'not_sent' || bodyBytes === 0, 'usage_reconciliation_pending');
  return ctx.db.runTransaction(async tx => {
    const ref = usageChildRef(ctx.db, ownerId, 'attempts', attemptId), r = (await tx.get(ref)).data();
    assertUsage(r && bodyBytes <= r.sizeBytes, 'usage_reconciliation_pending');
    if (r.status === 'served' || r.status === 'not_sent' || (r.status === 'unknown' && outcome !== 'served')) return;
    const l = await loadUsageLedger(ctx, tx, ownerId, r.allocations.map(a => a.periodId));
    const from = r.status === 'unknown' ? 'unknownBytes' : 'reservedBytes';
    for (const a of r.allocations) moveAllocation(l, a, from, outcome === 'served' ? 'usedBytes' : outcome === 'unknown' ? 'unknownBytes' : null,
      outcome === 'served' ? bodyBytes : a.sizeBytes);
    l.put(ref, {...r, status: outcome, bodyBytes: outcome === 'served' ? bodyBytes : null, settledAtMs: l.now});
    l.flush();
  });
}
export async function handleImageUsage(ctx) {
  assertUsage(ctx.actor?.uid && ctx.input?.schemaVersion === 1 && ctx.input.action === 'get', 'media_lease_invalid', 'unauthenticated');
  const access = (await ctx.realtime.ref(`displayAccess/${ctx.actor.uid}`).get()).val();
  assertUsage(!access?.ownerId && ctx.actor.token?.firebase?.sign_in_provider !== 'anonymous', 'media_lease_invalid', 'permission-denied');
  if (ctx.projectId === 'cloud-board-development' || /^demo-[a-z0-9-]+$/.test(ctx.projectId ?? '')) {
    const {reconcileUsageEnrollment} = await import('./class-admission.js');
    await reconcileUsageEnrollment(ctx, {ownerId: ctx.actor.uid});
  }
  return readUsage(ctx, {ownerId: ctx.actor.uid});
}
