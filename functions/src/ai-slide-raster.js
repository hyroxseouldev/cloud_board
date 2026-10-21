import {requirePlanEntitlement} from './plan-policy.js';
import {aiTimerMonth, AI_TIMER_BUDGET, AI_TIMER_GLOBAL_LIMIT, handleMeteredAi} from './ai-timer.js';
import {RASTER_MODEL, RASTER_RESERVE, RASTER_MAX_BYTES, rasterHash, rasterFail, rasterPng,
  sourceLines, validateRasterDraft, requestRasterGroups, requestRasterArtwork} from './ai-slide-raster-provider.js';

const id = /^[A-Za-z0-9_-]{1,120}$/;
const sha = /^[a-f0-9]{64}$/;
const lifetime = 30 * 86400000;
function assert(condition, message = '센터 이미지 설정을 확인해 주세요.', reason = 'brand-unavailable') {
  if (!condition) throw rasterFail('failed-precondition', message, reason);
}
function descriptor(value) {
  assert(value && typeof value.path === 'string' && sha.test(value.sha256) &&
    [value.width, value.height].every(n => Number.isSafeInteger(n) && n > 0 && n <= 4096));
  return {path: value.path, sha256: value.sha256, width: value.width, height: value.height};
}

export async function loadRasterBrand(db, uid, centerId, reader = db) {
  if (!uid) throw rasterFail('unauthenticated', '로그인 후 이용해 주세요.', 'signed-out');
  if (!id.test(centerId ?? '')) throw rasterFail('invalid-argument', '센터를 다시 선택해 주세요.', 'invalid-center');
  const refs = [`accountDeletions/${uid}`, `users/${uid}/onboarding/progress`, `centers/${centerId}`,
    `centers/${centerId}/slideTemplateCatalog/current`, `centers/${centerId}/aiSlideBrand/current`].map(p => db.doc(p));
  const [lock, onboarding, center, catalog, configured] = await reader.getAll(...refs);
  if (lock.exists || onboarding.data()?.storeId !== centerId || center.data()?.ownerUid !== uid) {
    throw rasterFail('permission-denied', '현재 센터의 편집 권한을 확인해 주세요.', 'center-permission');
  }
  const config = configured.data();
  assert(config?.schemaVersion === 1 && config.enabled === true && Number.isSafeInteger(config.revision) && config.revision > 0);
  const active = catalog.data();
  const template = active?.templates?.find(t => t.id === config.templateId && t.published === true);
  assert(active?.revision === config.catalogRevision && template?.recipe?.revision === config.recipeRevision,
    '승인된 참고 디자인의 버전이 변경되었어요. 센터 설정 갱신 후 다시 열어 주세요.', 'brand-stale');
  const reference = descriptor(config.reference), logo = descriptor(config.logo);
  assert(reference.path === template.recipe.backgroundPath && reference.sha256 === template.recipe.backgroundSha256 &&
    reference.path === `center-templates/${centerId}/${config.templateId}/${reference.sha256}.png`);
  assert(logo.path.startsWith(`users/${uid}/brand/`) && /^users\/[A-Za-z0-9_-]+\/brand\/[A-Za-z0-9_.-]+\.png$/.test(logo.path));
  const crop = config.logo.sourceRect;
  assert(Array.isArray(crop) && crop.length === 4 && crop.every(n => Number.isFinite(n) && n >= 0) &&
    crop[2] > 0 && crop[3] > 0 && crop[0] + crop[2] <= logo.width && crop[1] + crop[3] <= logo.height);
  assert(['backgroundColor','textColor','accentColor'].every(k => /^#[a-fA-F0-9]{6}$/.test(config[k])));
  const brand = {revision: config.revision, catalogRevision: config.catalogRevision, recipeRevision: config.recipeRevision,
    templateId: config.templateId, name: typeof config.name === 'string' ? config.name.slice(0,80) : '우리 센터',
    reference, logo: {...logo, sourceRect: crop}, backgroundColor: config.backgroundColor,
    textColor: config.textColor, accentColor: config.accentColor};
  return {...brand, key: rasterHash(JSON.stringify(brand))};
}
function publicBrand(brand) {
  const {path: _referencePath, ...reference} = brand.reference;
  const {path: _logoPath, ...logo} = brand.logo;
  return {...brand, reference, logo};
}
async function assetBytes(bucket, item) {
  const file = bucket.file(item.path);
  const [metadata] = await file.getMetadata();
  assert(Number(metadata.size) <= RASTER_MAX_BYTES && metadata.contentType === 'image/png', '이미지를 확인하지 못했어요.', 'invalid-asset');
  const [bytes] = await file.download();
  rasterPng(bytes, item);
  return bytes;
}
function userStatus(entitlement, used, enabled, now) {
  assert(Number.isSafeInteger(used) && used >= 0, '사용량을 확인하지 못했어요.', 'usage-unavailable');
  const limit = entitlement.aiSlidesMonthlyLimit ?? 0;
  return {allowed: limit > 0, enabled, limit, used, remaining: Math.max(0, limit - used), resetsAtMs: aiTimerMonth(now).resetsAtMs};
}
async function access(db, uid, apiKey, now) {
  const [ent, config, usage] = await db.getAll(db.doc(`subscriptionEntitlements/${uid}`), db.doc('appConfig/aiSlides'),
    db.doc(`users/${uid}/aiSlidesUsage/${aiTimerMonth(now).id}`));
  return userStatus(requirePlanEntitlement(ent.data(), now), usage.data()?.used ?? 0, Boolean(apiKey) && config.data()?.enabled !== false, now);
}
function publicJob(job, requestId, now) {
  const stale = job.status === 'processing' && job.startedAtMs + 10 * 60000 < now;
  const {path: _path, ...artifact} = job.artifact ?? {};
  return {requestId, status: stale ? 'uncertain' : job.status, draft: job.draft,
    brandKey: job.brandKey, artifact: job.artifact ? artifact : null,
    expiresAtMs: job.expiresAtMs ?? null, message: job.message ?? null};
}
function requireJob(job, brand, now) {
  if (!job) throw rasterFail('not-found', '접수된 요청을 아직 찾지 못했어요. 상태를 다시 확인해 주세요. 입력과 이전 시안은 유지됩니다.', 'request-not-found');
  assert(job.brandKey === brand.key, '참고 디자인/로고가 변경되었어요. 새 버전으로 다시 만들어 주세요.', 'brand-stale');
  assert(!job.expiresAtMs || job.expiresAtMs > now, '생성 시안 보관 기간이 지났어요.', 'result-expired');
}

export async function handleAiSlideRaster({db, bucket, uid, input, apiKey, clock = Date.now,
  generate = requestRasterArtwork, organize = requestRasterGroups}) {
  const centerId = input?.centerId;
  const brand = await loadRasterBrand(db, uid, centerId);
  const now = clock();
  const status = await access(db, uid, apiKey, now);
  const session = db.doc(`users/${uid}/aiSlideRasterCenters/${centerId}`);
  const requestId = input.requestId;
  const jobRef = requestId && id.test(requestId) ? session.collection('jobs').doc(requestId) : null;
  const checkFresh = async () => {
    const fresh = await loadRasterBrand(db, uid, centerId);
    assert(fresh.key === brand.key, '센터 참고 이미지가 변경되었어요. 다시 열어 주세요.', 'brand-stale');
    return fresh;
  };
  if (input.action === 'context') {
    const saved = (await session.get()).data();
    const recentId = saved?.latestRequestId;
    const recent = recentId && id.test(recentId) ? (await session.collection('jobs').doc(recentId).get()).data() : null;
    const previousId = saved?.latestCompletedRequestId;
    const previous = previousId && id.test(previousId) ? (await session.collection('jobs').doc(previousId).get()).data() : null;
    return {...status, brand: publicBrand(brand), recent: recent?.brandKey === brand.key && (!recent.expiresAtMs || recent.expiresAtMs > now)
      ? publicJob(recent, recentId, now) : null, previous: previous?.brandKey === brand.key && previous.expiresAtMs > now
      ? publicJob(previous, previousId, now) : null};
  }
  if (!status.allowed) throw rasterFail('permission-denied', 'AI 슬라이드 도우미는 Plus와 Premium에서 사용할 수 있어요.', 'plan-required');
  if (input.action === 'organize') {
    const lines = sourceLines(input.rawWod);
    assert(typeof input.brief === 'string' && input.brief.length <= 1000, '요청은 1,000자 이내로 적어 주세요.', 'invalid-brief');
    const validate = result => {
      validateRasterDraft({rawWod: input.rawWod, title: '오늘의 수업', brief: input.brief, groups: result.groups});
      return result;
    };
    const result = await handleMeteredAi({db, uid, apiKey, now, feature: 'aiSlides', operation: 'content', action: 'organize', input,
      parse: () => ({rawWod: input.rawWod, brief: input.brief, lines, key: rasterHash(`raster-groups-v1/${centerId}/${brand.key}/${input.rawWod}/${input.brief}`)}),
      validate, recognize: organize});
    await checkFresh();
    return {groups: result.result.groups, remaining: result.remaining, limit: result.limit};
  }
  if (input.action === 'asset' && ['logo','reference'].includes(input.kind)) {
    const item = input.kind === 'logo' ? brand.logo : brand.reference;
    const bytes = await assetBytes(bucket, item);
    await checkFresh();
    return {base64: bytes.toString('base64'), ...publicBrand(brand)[input.kind], brandKey: brand.key};
  }
  if (['status', 'asset', 'confirm'].includes(input.action)) {
    if (!jobRef) throw rasterFail('invalid-argument', '생성 요청을 확인해 주세요.', 'invalid-request');
    const job = (await jobRef.get()).data();
    requireJob(job, brand, now);
    if (input.action === 'status') return {...status, job: publicJob(job, requestId, now)};
    assert(job.status === 'completed' && job.artifact, '아직 이미지 생성이 완료되지 않았어요.', 'result-pending');
    if (input.action === 'confirm') return {job: publicJob(job, requestId, now), brand: publicBrand(brand)};
    assert(input.kind === 'artwork', '이미지를 확인해 주세요.', 'invalid-asset');
    const bytes = await assetBytes(bucket, job.artifact);
    await checkFresh();
    return {base64: bytes.toString('base64'), ...publicJob(job, requestId, now).artifact, brandKey: brand.key};
  }
  if (input.action !== 'generate' || !jobRef) throw rasterFail('invalid-argument', '생성 요청을 확인해 주세요.', 'invalid-action');
  const draft = validateRasterDraft(input.draft);
  assert(input.brandKey === brand.key, '센터 참고 이미지가 변경되었어요.', 'brand-stale');
  assert(input.previousRequestId == null || id.test(input.previousRequestId), '이전 시안을 확인해 주세요.', 'invalid-previous');
  const requestHash = rasterHash(JSON.stringify({draft, brandKey: brand.key, previous: input.previousRequestId ?? null, model: RASTER_MODEL}));
  // Fetch bounded, server-owned assets before reserving. No URL from the client
  // is ever fetched; official logo is never sent to the generation model.
  const reference = await assetBytes(bucket, brand.reference);
  let previous;
  if (input.previousRequestId) {
    const old = (await session.collection('jobs').doc(input.previousRequestId).get()).data();
    requireJob(old, brand, now);
    assert(old.status === 'completed', '이전 시안이 완성되지 않았어요.', 'invalid-previous');
    previous = await assetBytes(bucket, old.artifact);
  }
  const month = aiTimerMonth(now).id;
  const usageRef = db.doc(`users/${uid}/aiSlidesUsage/${month}`);
  const budgetRef = db.doc(`aiTimerBudgets/${month}`); // Existing shared service cap, unchanged.
  const imageBudgetRef = db.doc(`aiSlideRasterBudgets/${month}`); // Separate operation accounting.
  const claim = await db.runTransaction(async tx => {
    const fresh = await loadRasterBrand(db, uid, centerId, tx);
    assert(fresh.key === brand.key, '센터 참고 이미지가 변경되었어요.', 'brand-stale');
    const [ent, config, usage, budget, imageBudget, job] = await tx.getAll(db.doc(`subscriptionEntitlements/${uid}`),
      db.doc('appConfig/aiSlides'), usageRef, budgetRef, imageBudgetRef, jobRef);
    const availability = userStatus(requirePlanEntitlement(ent.data(), clock()), usage.data()?.used ?? 0, Boolean(apiKey) && config.data()?.enabled !== false, now);
    assert(availability.allowed, '이 요금제에서는 AI 생성을 사용할 수 없어요.', 'plan-required');
    if (job.exists) {
      assert(job.data().requestHash === requestHash, '동일 요청의 입력이 바뀌었어요. 새 요청으로 생성해 주세요.', 'request-conflict');
      requireJob(job.data(), fresh, clock());
      return {cached: true, status: availability, job: job.data()}; // No stale lease can call the provider again.
    }
    assert(availability.enabled, 'AI 이미지 기능을 준비 중이에요. 기존 템플릿은 계속 사용할 수 있어요.', 'not-configured');
    if (availability.remaining < 1) throw rasterFail('resource-exhausted', '이번 달 AI 사용량을 모두 사용했어요.', 'user-limit');
    const attempts = usage.data()?.attempts ?? 0;
    if (attempts >= availability.limit * 2 || (usage.data()?.lastAttemptMs ?? 0) + 5000 > now) throw rasterFail('resource-exhausted', '잠시 후 다시 요청해 주세요.', 'attempt-limit');
    const spent = budget.data()?.spentMicros ?? 0, calls = budget.data()?.calls ?? 0;
    assert([spent,calls,attempts,imageBudget.data()?.spentMicros ?? 0].every(n => Number.isSafeInteger(n) && n >= 0), '사용량을 확인하지 못했어요.', 'usage-unavailable');
    if (spent + RASTER_RESERVE > AI_TIMER_BUDGET || calls >= AI_TIMER_GLOBAL_LIMIT) throw rasterFail('resource-exhausted', '서비스 AI 제공 한도에 도달했어요. 개인 사용량은 차감되지 않았어요.', 'service-limit');
    const jobValue = {status: 'processing', requestHash, brandKey: brand.key, draft, centerId,
      startedAtMs: now, month, model: RASTER_MODEL, reservedMicros: RASTER_RESERVE, quotaCharged: true};
    tx.set(jobRef, jobValue);
    tx.set(session, {latestRequestId: requestId, updatedAtMs: now}, {merge: true});
    tx.set(usageRef, {used: availability.used + 1, attempts: attempts + 1, lastAttemptMs: now}, {merge: true});
    tx.set(budgetRef, {spentMicros: spent + RASTER_RESERVE, calls: calls + 1}, {merge: true});
    tx.set(imageBudgetRef, {spentMicros: (imageBudget.data()?.spentMicros ?? 0) + RASTER_RESERVE,
      calls: (imageBudget.data()?.calls ?? 0) + 1}, {merge: true});
    return {status: {...availability, used: availability.used + 1, remaining: availability.remaining - 1}, job: jobValue};
  });
  if (claim.cached) return {...claim.status, job: publicJob(claim.job, requestId, clock())};
  let answer, failure;
  try {
    answer = await generate({reference, previous, draft, brand, uid}, apiKey);
    await checkFresh();
    const artifact = {path: `users/${uid}/ai-slide-raster/${centerId}/${requestId}/${answer.sha256}.png`,
      sha256: answer.sha256, width: answer.width, height: answer.height};
    rasterPng(answer.bytes, artifact);
    await bucket.file(artifact.path).save(answer.bytes, {resumable: false, preconditionOpts: {ifGenerationMatch: 0},
      metadata: {contentType: 'image/png', cacheControl: 'private, no-store', metadata: {sha256: answer.sha256}}});
    answer.artifact = artifact;
  } catch (error) {
    failure = error;
  }
  let settled;
  try { settled = await db.runTransaction(async tx => {
    const [job, usage, budget, images, lock] = await tx.getAll(jobRef, usageRef, budgetRef, imageBudgetRef, db.doc(`accountDeletions/${uid}`));
    if (lock.exists || job.data()?.status !== 'processing' || job.data()?.requestHash !== requestHash) return null;
    let fresh;
    try { fresh = await loadRasterBrand(db, uid, centerId, tx); } catch { failure ??= rasterFail('permission-denied', '센터 연결이 변경되어 생성 결과를 표시할 수 없어요.', 'center-permission'); }
    if (fresh?.key !== brand.key) failure ??= rasterFail('failed-precondition', '센터 참고 이미지가 변경되었어요.', 'brand-stale');
    const definiteRejection = failure?.details?.reason === 'provider-rejected';
    const completed = !failure;
    const cost = definiteRejection ? 0 : answer?.costMicros ?? RASTER_RESERVE;
    const finalJob = {...job.data(), status: completed ? 'completed' : definiteRejection ? 'failed' : 'uncertain',
      expiresAtMs: clock() + lifetime, costMicros: cost, costBasis: definiteRejection ? 'provider-rejected' : answer?.costBasis ?? 'reservation-retained',
      usage: answer?.usage ?? null, quotaCharged: !definiteRejection,
      ...(completed ? {artifact: answer.artifact} : {message: definiteRejection
        ? '이미지 생성이 거절되어 사용량 1회를 돌려드렸어요. 입력과 이전 결과는 남아 있어요.'
        : '요청 결과를 확인하지 못했어요. 상태 확인에는 추가 차감이 없으며 같은 요청을 다시 생성하지 않아요.'})};
    tx.set(jobRef, finalJob);
    if (completed) tx.set(session, {latestCompletedRequestId: requestId}, {merge: true});
    if (definiteRejection) tx.set(usageRef, {used: Math.max(0, (usage.data()?.used ?? 1) - 1)}, {merge: true});
    tx.set(budgetRef, {spentMicros: Math.max(0, (budget.data()?.spentMicros ?? RASTER_RESERVE) - RASTER_RESERVE + cost)}, {merge: true});
    tx.set(imageBudgetRef, {spentMicros: Math.max(0, (images.data()?.spentMicros ?? RASTER_RESERVE) - RASTER_RESERVE + cost)}, {merge: true});
    return finalJob;
  }); } catch (error) {
    // A transaction acknowledgement may itself be lost. Never delete a valid
    // completed result on that uncertainty; query its durable commit first.
    if (answer?.artifact) {
      try {
        const persisted = (await jobRef.get()).data();
        if (persisted?.status !== 'completed' || persisted.artifact?.path !== answer.artifact.path) {
          await bucket.file(answer.artifact.path).delete({ignoreNotFound: true});
        }
      } catch { /* Unreadable state stays private; reservation remains held. */ }
    }
    throw error;
  }
  if ((!settled || settled.status !== 'completed') && answer?.artifact) {
    try { await bucket.file(answer.artifact.path).delete({ignoreNotFound: true}); } catch { /* Private orphan is never returned. */ }
  }
  if (!settled) throw rasterFail('permission-denied', '계정 상태가 변경되어 결과를 표시하지 않습니다.', 'account-changed');
  await checkFresh();
  return {...claim.status, ...(settled.quotaCharged ? {} : {used: claim.status.used - 1, remaining: claim.status.remaining + 1}),
    job: publicJob(settled, requestId, clock())};
}
