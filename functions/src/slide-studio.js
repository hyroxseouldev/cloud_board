import {HttpsError} from 'firebase-functions/v2/https';
import {handleMeteredAi} from './ai-timer.js';
import {readSlideDesignPrompt, requestAiSlideDesigns, validateSlideDesigns} from './ai-slide-designs.js';
import {rasterHash, sourceLines, requestRasterGroups, validateRasterDraft} from './ai-slide-raster-provider.js';

const validId = value => typeof value === 'string' && /^[A-Za-z0-9_-]{1,120}$/.test(value);
const fail = (code, message) => new HttpsError(code, message);

async function requireCenter(db, uid, centerId, reader = db) {
  if (!uid) throw fail('unauthenticated', '로그인 후 이용해 주세요.');
  if (!validId(centerId)) throw fail('invalid-argument', '센터를 확인해 주세요.');
  const [lock, onboarding, center] = await reader.getAll(db.doc(`accountDeletions/${uid}`),
    db.doc(`users/${uid}/onboarding/progress`), db.doc(`centers/${centerId}`));
  if (lock.exists || onboarding.data()?.storeId !== centerId || center.data()?.ownerUid !== uid) {
    throw fail('permission-denied', '현재 센터의 편집 권한을 확인해 주세요.');
  }
}

// Tokens are provider work, NOT a user currency. There is no token allowance in
// the existing plan policy, so null never means zero or unlimited.
export function studioTokenUsage(value) {
  if (!value || !['input', 'output'].every(k => Number.isSafeInteger(value[k]) && value[k] >= 0) ||
      !Number.isSafeInteger(value.input + value.output)) return null;
  return {input: value.input, output: value.output, total: value.input + value.output};
}

function publicOperation(job, requestId, now) {
  return {requestId, status: job.status === 'processing' && now - job.startedAtMs > 90000 ? 'uncertain' : job.status,
    operation: job.operation, result: job.result ?? null, usage: studioTokenUsage(job.usage),
    message: job.message ?? null};
}

/** Additive studio API. Does not change any shipped endpoint or plan limit. */
export async function handleSlideStudio({db, uid, input, apiKey, clock = Date.now,
  organize = requestRasterGroups, design = requestAiSlideDesigns}) {
  const centerId = input?.centerId, now = clock();
  await requireCenter(db, uid, centerId);
  const session = db.doc(`users/${uid}/slideStudioCenters/${centerId}`);
  const status = () => handleMeteredAi({db, uid, input: {action: 'status'}, apiKey, now,
    feature: 'aiSlides', operation: 'studio', action: 'generate'});
  if (input.action === 'usage') {
    const access = await status();
    let last = null;
    if (input.requestId != null) {
      if (!validId(input.requestId)) throw fail('invalid-argument', '요청을 확인해 주세요.');
      if (input.kind === 'raster') {
        const job = (await db.doc(`users/${uid}/aiSlideRasterCenters/${centerId}/jobs/${input.requestId}`).get()).data();
        const usage = job?.usage;
        if (job?.status === 'completed' && usage && ['textInput', 'imageInput', 'imageOutput']
          .every(k => Number.isSafeInteger(usage[k]) && usage[k] >= 0)) {
          last = {requestId: input.requestId, kind: 'image',
            ...studioTokenUsage({input: usage.textInput + usage.imageInput, output: usage.imageOutput})};
        }
      } else {
        const job = (await session.collection('operations').doc(input.requestId).get()).data();
        const usage = studioTokenUsage(job?.usage);
        if (job?.status === 'completed' && usage) last = {requestId: input.requestId, kind: job.operation, ...usage};
      }
    }
    await requireCenter(db, uid, centerId);
    return {schemaVersion: 1, ...access,
      tokenAllowance: {kind: 'not-metered', remaining: null, limit: null},
      lastOperationTokens: last, observedAtMs: now};
  }
  if (!validId(input.requestId)) throw fail('invalid-argument', '생성 요청을 확인해 주세요.');
  const jobRef = session.collection('operations').doc(input.requestId);
  if (input.action === 'status') {
    const job = (await jobRef.get()).data();
    if (!job) throw fail('not-found', '접수 상태를 확인하지 못했어요. 입력과 이전 결과는 유지됩니다.');
    const access = await status();
    if (!access.allowed) throw fail('permission-denied', 'AI 슬라이드 이용 권한을 확인해 주세요.');
    await requireCenter(db, uid, centerId);
    return {...access, job: publicOperation(job, input.requestId, now)};
  }
  if (input.action !== 'generate' || !['organize', 'style'].includes(input.operation)) {
    throw fail('invalid-argument', '올바른 생성 방식이 아닙니다.');
  }
  let source;
  if (input.operation === 'organize') {
    const lines = sourceLines(input.rawWod);
    if (typeof input.brief !== 'string' || input.brief.length > 1000) throw fail('invalid-argument', '요청은 1,000자 이내로 입력해 주세요.');
    source = {rawWod: input.rawWod, brief: input.brief, lines,
      key: rasterHash(JSON.stringify({version: 'studio-groups-v1', centerId,
        rawWod: input.rawWod, brief: input.brief}))};
  } else {
    source = readSlideDesignPrompt(input);
    source.key = rasterHash(JSON.stringify({version: 'studio-style-v1', centerId, key: source.key}));
  }
  const hash = rasterHash(`${input.operation}/${source.key}`);
  const claim = await db.runTransaction(async tx => {
    await requireCenter(db, uid, centerId, tx);
    const saved = (await tx.get(jobRef)).data();
    if (saved) {
      if (saved.hash !== hash) throw fail('already-exists', '이 요청은 다른 입력으로 접수됐어요. 새 요청으로 생성해 주세요.');
      return {existing: saved};
    }
    const job = {hash, operation: input.operation, status: 'processing', startedAtMs: now};
    tx.set(jobRef, job);
    return {created: job};
  });
  if (claim.existing) {
    const access = await status();
    if (!access.allowed) throw fail('permission-denied', 'AI 슬라이드 이용 권한을 확인해 주세요.');
    return {...access, job: publicOperation(claim.existing, input.requestId, now)};
  }
  // The durable outer claim is never reclaimed, even after a crash/timeout.
  // Repeated taps and lost-response retries can only read this request.
  let response, usage = null, failure;
  try {
    const capture = async (value, key) => {
      const answer = await (input.operation === 'style' ? design : organize)(value, key);
      usage = studioTokenUsage(answer.usage);
      return answer;
    };
    const validate = input.operation === 'style'
      ? result => validateSlideDesigns(result, source)
      : result => {
          validateRasterDraft({rawWod: source.rawWod, title: '오늘의 수업', brief: source.brief, groups: result.groups});
          return result;
        };
    response = await handleMeteredAi({db, uid, apiKey, now, input: {...input, action: 'generate'},
      feature: 'aiSlides', operation: input.operation === 'style' ? 'design' : 'content',
      action: 'generate', parse: () => source, recognize: capture, validate});
    // Cache hits bypass the shared meter's validator; recheck exact source.
    response.result = validate(response.result);
  } catch (error) {
    failure = error;
  }
  const rejected = failure && ['invalid-argument', 'permission-denied', 'failed-precondition',
    'resource-exhausted', 'aborted'].includes(failure.code);
  const settled = {...claim.created, status: failure ? (rejected ? 'rejected' : 'uncertain') : 'completed',
    result: response?.result ?? null, usage, message: failure
      ? '생성을 완료하지 못했어요. 같은 요청의 상태를 확인할 수 있으며 입력과 이전 결과는 유지됩니다.' : null};
  await db.runTransaction(async tx => {
    await requireCenter(db, uid, centerId, tx);
    tx.set(jobRef, settled);
  });
  return {...await status(), job: publicOperation(settled, input.requestId, now)};
}
