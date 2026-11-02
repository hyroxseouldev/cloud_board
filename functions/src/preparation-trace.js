// Optional 2.0.6 diagnostics. Existing 2.0.5 payloads remain valid unchanged.
const counters = {targetCount: 32, targetIndex: 31, pendingWrites: 1000,
  connectionChanges: 1000000, observerAgeMs: 2592000000, connectionAgeMs: 2592000000,
  lifecycleAgeMs: 2592000000, writeElapsedMs: 86400000, mediaElapsedMs: 86400000,
  responseElapsedMs: 86400000, heartbeatElapsedMs: 86400000, httpStatus: 599};
const enums = {connection: ['unknown', 'connected', 'disconnected', 'error'],
  lifecycle: ['unknown', 'resumed', 'inactive', 'hidden', 'paused', 'detached'],
  requestMatch: ['same', 'different', 'absent'], probeStage: ['auth', 'http'],
  stage: ['request', 'images', 'audio', 'response', 'heartbeat'],
  transportCode: ['permission-denied', 'unauthenticated', 'unavailable', 'deadline-exceeded',
    'resource-exhausted', 'aborted', 'not-found', 'failed-precondition', 'timeout', 'unexpected']};
export function validatePreparationTrace(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Invalid preparation trace');
  for (const [key, item] of Object.entries(value)) {
    const valid = Object.hasOwn(counters, key) ? Number.isInteger(item) && item >= 0 && item <= counters[key] :
      Object.hasOwn(enums, key) ? enums[key].includes(item) :
      key === 'superseded' ? typeof item === 'boolean' :
      key === 'requestId' ? typeof item === 'string' && /^prepare-[a-z0-9-]{1,80}$/.test(item) :
      key === 'parentOperationId' ? typeof item === 'string' && /^[a-f0-9]{32}$/.test(item) : false;
    if (!valid) throw new Error('Invalid preparation trace');
  }
  return {...value};
}
