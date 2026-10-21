import {randomUUID} from 'node:crypto';
import {requirePlanEntitlement} from './plan-policy.js';
import {aiTimerMonth, AI_TIMER_BUDGET, AI_TIMER_GLOBAL_LIMIT, AI_TIMER_RESERVE} from './ai-timer.js';
import {rasterFail as fail, rasterHash, sourceLines} from './ai-slide-raster-provider.js';

const validId = x => typeof x === 'string' && /^[A-Za-z0-9_-]{1,120}$/.test(x);
const leaseMs = 180000;
const jobPath = (uid, centerId, requestId) => `users/${uid}/templateGenerationCenters/${centerId}/jobs/${requestId}`;
const queueRef = (db, path) => db.doc(`templateGenerationQueue/${rasterHash(path)}`);
const check = (yes, message, reason, code = 'failed-precondition') => { if (!yes) throw fail(code, message, reason); };

async function requireCenter(db, uid, centerId, reader = db) {
  check(validId(uid), '로그인 후 이용해 주세요.', 'signed-out', 'unauthenticated');
  check(validId(centerId), '센터를 다시 선택해 주세요.', 'invalid-center', 'invalid-argument');
  const [lock, profile, center] = await reader.getAll(db.doc(`accountDeletions/${uid}`),
    db.doc(`users/${uid}/onboarding/progress`), db.doc(`centers/${centerId}`));
  check(!lock.exists && profile.data()?.storeId === centerId && center.data()?.ownerUid === uid,
    '현재 센터의 편집 권한을 확인해 주세요.', 'center-permission', 'permission-denied');
}

function usageValue(ent, config, used, apiKey, now) {
  const access = requirePlanEntitlement(ent, now), limit = access.aiSlidesMonthlyLimit ?? 0;
  check(Number.isSafeInteger(used) && used >= 0, '사용량을 확인하지 못했어요.', 'usage-unavailable');
  return {allowed: limit > 0, enabled: Boolean(apiKey) && config?.enabled !== false,
    used, remaining: Math.max(0, limit - used), limit, unlimited: false,
    plan: access.plan, policyVersion: access.policyVersion, resetsAtMs: aiTimerMonth(now).resetsAtMs};
}
async function usage(db, uid, apiKey, now) {
  const [ent, config, used] = await db.getAll(db.doc(`subscriptionEntitlements/${uid}`), db.doc('appConfig/aiSlides'),
    db.doc(`users/${uid}/aiSlidesUsage/${aiTimerMonth(now).id}`));
  return usageValue(ent.data(), config.data(), used.data()?.used ?? 0, apiKey, now);
}
export function publicTemplateJob(j) {
  return {requestId: j.requestId, status: j.status, title: j.title, subtitle: j.subtitle, rawWod: j.rawWod,
    designId: j.design.id, designName: j.design.name, design: j.design, createdAtMs: j.createdAtMs,
    updatedAtMs: j.updatedAtMs, retryable: j.retryable ?? false, message: j.message ?? null,
    usage: j.provider?.usage ?? null, quotaCharged: j.quotaCharged,
    artifact: j.artifact ? {sha256: j.artifact.sha256, width: j.artifact.width, height: j.artifact.height} : null};
}
async function loadDesign(db, centerId, design, reader = db) {
  const submitted = design?.theme?.centerRecipe;
  check(submitted && validId(submitted.templateId), '기본 템플릿은 AI를 사용하지 않아요. 기본 생성으로 이용해 주세요.', 'basic-template-no-ai', 'invalid-argument');
  check(typeof design.id === 'string' && design.id.length <= 160 && typeof design.name === 'string' && design.name.length <= 200 &&
    JSON.stringify(design).length <= 50000, '선택한 디자인을 다시 확인해 주세요.', 'invalid-design', 'invalid-argument');
  const catalogRef = db.doc(`centers/${centerId}/slideTemplateCatalog/current`);
  const catalog = (await (reader === db ? catalogRef.get() : reader.get(catalogRef))).data();
  const template = catalog?.templates?.find(t => t.id === submitted.templateId && t.published === true);
  check(template?.recipe?.revision === submitted.revision && (submitted.centerId == null || submitted.centerId === centerId),
    '센터 템플릿이 변경됐어요. 목록을 새로 열어 주세요.', 'template-stale');
  const {validateTemplateRecipe} = await import('./template-layout.js');
  const recipe = validateTemplateRecipe(template.recipe, centerId);
  return {...design, theme: {...design.theme, centerRecipe: recipe}};
}
function sourceInput(input) {
  sourceLines(input?.rawWod);
  check(typeof input.title === 'string' && input.title.trim().length > 0 && input.title.length <= 60 &&
    typeof input.subtitle === 'string' && input.subtitle.length <= 120 &&
    !/[\x00-\x1F\x7F]/.test(input.title + input.subtitle), '제목과 안내 문구를 확인해 주세요.', 'invalid-input', 'invalid-argument');
  return {title: input.title.trim(), subtitle: input.subtitle.trim(), rawWod: input.rawWod};
}
async function download(bucket, descriptor) {
  const file = bucket.file(descriptor.path), [meta] = await file.getMetadata();
  check(meta.contentType === 'image/png' && Number(meta.size) <= 10 * 1024 * 1024, '템플릿 이미지를 확인하지 못했어요.', 'invalid-asset');
  const [bytes] = await file.download();
  check(rasterHash(bytes) === descriptor.sha256, '템플릿 이미지 버전이 변경됐어요.', 'invalid-asset');
  return bytes;
}

/** Acceptance only: no provider call and no work started after returning HTTP. */
export async function handleTemplateJobs({db, bucket, uid, input, apiKey, clock = Date.now}) {
  const centerId = input?.centerId, now = clock();
  await requireCenter(db, uid, centerId);
  if (input.action === 'list') {
    let query = db.collection(`users/${uid}/templateGenerationCenters/${centerId}/jobs`).orderBy('createdAtMs', 'desc');
    if (input.before != null) {
      check(validId(input.before), '목록 위치를 확인해 주세요.', 'invalid-cursor', 'invalid-argument');
      const cursor = await db.doc(jobPath(uid, centerId, input.before)).get();
      check(cursor.exists, '목록을 새로 열어 주세요.', 'invalid-cursor'); query = query.startAfter(cursor);
    }
    const page = await query.limit(21).get();
    await requireCenter(db, uid, centerId);
    return {jobs: page.docs.slice(0, 20).map(s => publicTemplateJob(s.data())),
      nextCursor: page.docs.length > 20 ? page.docs[19].id : null, usage: await usage(db, uid, apiKey, now)};
  }
  check(validId(input.requestId), '생성 요청을 확인해 주세요.', 'invalid-request', 'invalid-argument');
  const path = jobPath(uid, centerId, input.requestId), ref = db.doc(path), queue = queueRef(db, path);
  if (['status', 'asset'].includes(input.action)) {
    const j = (await ref.get()).data();
    check(j, '접수된 요청을 찾지 못했어요.', 'not-found', 'not-found');
    if (input.action === 'status') return {job: publicTemplateJob(j), usage: await usage(db, uid, apiKey, now)};
    check(j.status === 'complete' && j.artifact, '아직 이미지 생성이 끝나지 않았어요.', 'result-pending');
    const bytes = await download(bucket, j.artifact);
    await requireCenter(db, uid, centerId);
    return {base64: bytes.toString('base64'), sha256: j.artifact.sha256, width: j.artifact.width, height: j.artifact.height};
  }
  check(input.action === 'enqueue', '생성 방식을 확인해 주세요.', 'invalid-action', 'invalid-argument');
  const retryOf = input.retryOf ?? null;
  check(retryOf === null || validId(retryOf) && retryOf !== input.requestId, '재시도 요청을 확인해 주세요.', 'invalid-retry', 'invalid-argument');
  const old = (await ref.get()).data();
  if (old && retryOf) {
    check(old.retryOf === retryOf, '같은 요청 번호에 다른 재시도가 있어요.', 'request-conflict', 'already-exists');
    return {job: publicTemplateJob(old), usage: await usage(db, uid, apiKey, now)};
  }
  let source = input;
  if (retryOf) {
    const previous = (await db.doc(jobPath(uid, centerId, retryOf)).get()).data();
    check(previous?.status === 'failed' && previous.retryable === true, '이 요청은 상태 확인만 가능해요. 중복 AI 생성을 하지 않아요.', 'retry-unavailable');
    source = previous;
  }
  const values = sourceInput(source);
  // The identity is based on what the user submitted. A lost response can be
  // recovered even if the operator subsequently publishes a newer template.
  const requestHash = rasterHash(JSON.stringify({...values, design: source.design, retryOf}));
  if (old) {
    check(old.requestHash === requestHash, '같은 요청 번호에 다른 내용이 있어요.', 'request-conflict', 'already-exists');
    return {job: publicTemplateJob(old), usage: await usage(db, uid, apiKey, now)};
  }
  const design = await loadDesign(db, centerId, source.design);
  const month = aiTimerMonth(now).id, usageRef = db.doc(`users/${uid}/aiSlidesUsage/${month}`), budgetRef = db.doc(`aiTimerBudgets/${month}`);
  return db.runTransaction(async tx => {
    await requireCenter(db, uid, centerId, tx);
    const [job, ent, config, used, budget, previous] = await tx.getAll(ref, db.doc(`subscriptionEntitlements/${uid}`),
      db.doc('appConfig/aiSlides'), usageRef, budgetRef, retryOf ? db.doc(jobPath(uid, centerId, retryOf)) : ref);
    const status = usageValue(ent.data(), config.data(), used.data()?.used ?? 0, apiKey, now);
    if (job.exists) {
      check(job.data().requestHash === requestHash, '같은 요청 번호에 다른 내용이 있어요.', 'request-conflict', 'already-exists');
      return {job: publicTemplateJob(job.data()), usage: status};
    }
    if (retryOf) check(previous.data()?.status === 'failed' && previous.data()?.retryable && !previous.data()?.retriedBy,
      '이 실패 요청은 이미 다시 접수했어요.', 'already-retried');
    const fresh = await loadDesign(db, centerId, source.design, tx);
    check(rasterHash(JSON.stringify(fresh)) === rasterHash(JSON.stringify(design)), '템플릿이 변경됐어요.', 'template-stale');
    check(status.allowed, '현재 요금제에서 AI 생성을 사용할 수 없어요.', 'plan-required', 'permission-denied');
    check(status.enabled, 'AI 생성을 잠시 사용할 수 없어요. 기본 템플릿은 계속 사용할 수 있어요.', 'ai-unavailable');
    check(status.remaining > 0, '이번 달 AI 생성 횟수를 모두 사용했어요.', 'user-limit', 'resource-exhausted');
    check((used.data()?.lastAttemptMs ?? 0) + 5000 <= now, '잠시 후 다시 생성해 주세요.', 'cooldown', 'resource-exhausted');
    check((used.data()?.attempts ?? 0) < status.limit * 2, '반복 요청 한도에 도달했어요.', 'attempt-limit', 'resource-exhausted');
    check((budget.data()?.spentMicros ?? 0) + AI_TIMER_RESERVE <= AI_TIMER_BUDGET &&
      (budget.data()?.calls ?? 0) < AI_TIMER_GLOBAL_LIMIT, '서비스의 AI 생성 한도에 도달했어요.', 'service-limit', 'resource-exhausted');
    const value = {schemaVersion: 1, requestId: input.requestId, uid, centerId, ...values, design, requestHash, retryOf,
      status: 'pending', stage: 'pending', createdAtMs: now, updatedAtMs: now, month, quotaCharged: true, attempts: 0};
    tx.set(ref, value);
    tx.set(queue, {path, uid, centerId, requestId: input.requestId, dueAtMs: now});
    tx.set(usageRef, {used: status.used + 1, attempts: (used.data()?.attempts ?? 0) + 1, lastAttemptMs: now}, {merge: true});
    tx.set(budgetRef, {spentMicros: (budget.data()?.spentMicros ?? 0) + AI_TIMER_RESERVE,
      calls: (budget.data()?.calls ?? 0) + 1}, {merge: true});
    if (retryOf) tx.set(db.doc(jobPath(uid, centerId, retryOf)), {retriedBy: input.requestId, retryable: false}, {merge: true});
    return {job: publicTemplateJob(value), usage: {...status, used: status.used + 1, remaining: status.remaining - 1}};
  });
}

/** Firestore deliveries and recovery share a fenced durable claim. A provider
 * operation with an unknown outcome is NEVER automatically repeated. */
export async function processTemplateJob({db, bucket, uid, centerId, requestId, apiKey, clock = Date.now,
  generate, render}) {
  const path = jobPath(uid, centerId, requestId), ref = db.doc(path), queue = queueRef(db, path), token = randomUUID();
  const claimed = await db.runTransaction(async tx => {
    const s = await tx.get(ref), j = s.data();
    if (!j || ['complete', 'failed'].includes(j.status)) { tx.delete(queue); return null; }
    if (j.status === 'processing' && j.leaseUntilMs > clock()) return null;
    const uncertain = j.stage === 'provider' && !j.provider;
    const value = {...j, status: 'processing', token, leaseUntilMs: clock() + leaseMs,
      attempts: j.attempts + 1, updatedAtMs: clock()};
    tx.set(ref, value); tx.set(queue, {dueAtMs: value.leaseUntilMs}, {merge: true});
    return {job: value, uncertain};
  });
  if (!claimed) return;
  let j = claimed.job, artifact, failure, background, provider = j.provider;
  const patch = async value => db.runTransaction(async tx => {
    const current = (await tx.get(ref)).data();
    if (current?.token !== token || current.status !== 'processing') return false;
    tx.set(ref, {...value, updatedAtMs: clock()}, {merge: true}); return true;
  });
  try {
    if (claimed.uncertain) throw fail('unavailable', '이전 AI 응답을 확인하지 못했어요. 중복 호출하지 않고 원문을 보관했어요.', 'provider-uncertain');
    await requireCenter(db, uid, centerId);
    const fresh = await loadDesign(db, centerId, j.design);
    check(rasterHash(JSON.stringify(fresh)) === rasterHash(JSON.stringify(j.design)), '센터 템플릿이 변경됐어요. 다시 선택해 주세요.', 'template-stale');
    const recipe = j.design.theme.centerRecipe;
    background = await download(bucket, {path: recipe.backgroundPath, sha256: recipe.backgroundSha256});
    const impl = await import('./template-layout.js');
    if (!provider) {
      check(Boolean(apiKey), 'AI 연결을 준비 중이에요.', 'not-configured');
      if (!await patch({stage: 'provider'})) return;
      j.stage = 'provider';
      provider = await (generate ?? impl.requestTemplateLayout)({...j, recipe}, apiKey);
      if (!await patch({provider, stage: 'render'})) return;
      j.stage = 'render';
    }
    const answer = await (render ?? impl.renderTemplate)({...j, recipe, background, layout: provider.layout});
    await requireCenter(db, uid, centerId);
    // Each fenced worker owns its upload. A late worker can remove only its own
    // orphan, never a replacement worker's completed artifact with the same hash.
    artifact = {path: `users/${uid}/template-generations/${centerId}/${requestId}/${token}/${answer.sha256}.png`,
      sha256: answer.sha256, width: answer.width, height: answer.height};
    await bucket.file(artifact.path).save(answer.bytes, {resumable: false,
      metadata: {contentType: 'image/png', cacheControl: 'private, no-store', metadata: {sha256: answer.sha256}}});
    j.evidence = answer.evidence;
  } catch (error) { failure = error; }
  const reason = failure?.details?.reason;
  // A saved provider result can be rendered again without another call/charge.
  if (failure && provider && !reason && j.attempts < 3) {
    await db.runTransaction(async tx => {
      const current = (await tx.get(ref)).data();
      if (current?.token !== token || current.status !== 'processing') return;
      tx.set(ref, {provider, stage: 'render', leaseUntilMs: 0, updatedAtMs: clock()}, {merge: true});
      tx.set(queue, {dueAtMs: clock() + 60000}, {merge: true});
    });
    return;
  }
  let completed = false;
  await db.runTransaction(async tx => {
    const usageRef = db.doc(`users/${uid}/aiSlidesUsage/${j.month}`), budgetRef = db.doc(`aiTimerBudgets/${j.month}`);
    const [saved, used, budget] = await tx.getAll(ref, usageRef, budgetRef);
    if (saved.data()?.token !== token || saved.data()?.status !== 'processing') return;
    try { await requireCenter(db, uid, centerId, tx); }
    catch (error) { failure ??= error; }
    const uncertain = failure && !provider && j.stage === 'provider' && failure.details?.reason !== 'provider-rejected';
    const refund = Boolean(failure && !uncertain);
    const cost = provider?.costMicros ?? (uncertain ? AI_TIMER_RESERVE : 0);
    completed = !failure;
    tx.set(ref, {status: completed ? 'complete' : 'failed', stage: 'settled', updatedAtMs: clock(),
      message: completed ? null : uncertain ? 'AI 응답을 확인하지 못했어요. 중복 차감 없이 원문과 접수 상태를 보관했어요.'
        : failure?.details?.reason ? `${failure.message} 사용량 1회는 돌려드렸어요.` : '이미지를 저장하지 못했어요. 원문은 보관했으며 사용량 1회를 돌려드렸어요.',
      retryable: Boolean(failure && ['provider-rejected', 'not-configured'].includes(failure.details?.reason)),
      quotaCharged: !refund, artifact: completed ? artifact : null, provider: provider ?? null,
      evidence: completed ? j.evidence ?? null : null, costMicros: cost, leaseUntilMs: 0}, {merge: true});
    if (refund) tx.set(usageRef, {used: Math.max(0, (used.data()?.used ?? 1) - 1)}, {merge: true});
    tx.set(budgetRef, {spentMicros: Math.max(0, (budget.data()?.spentMicros ?? AI_TIMER_RESERVE) - AI_TIMER_RESERVE + cost)}, {merge: true});
    tx.delete(queue);
  });
  // An account deletion/ownership change during upload must not leave an
  // otherwise inaccessible orphan after the account cleanup has run.
  if (!completed && artifact) await bucket.file(artifact.path).delete({ignoreNotFound: true});
}

export async function recoverTemplateJobs(options) {
  const page = await options.db.collection('templateGenerationQueue').where('dueAtMs', '<=', (options.clock ?? Date.now)()).orderBy('dueAtMs').limit(6).get();
  for (let offset = 0; offset < page.docs.length; offset += 3) {
    await Promise.all(page.docs.slice(offset, offset + 3).map(doc => processTemplateJob({...options, ...doc.data()})));
  }
}
