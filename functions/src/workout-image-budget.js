import {parseManagedSource, readManagedAsset, managedMetadata} from './managed-image-assets.js';
import {HttpsError} from 'firebase-functions/v2/https';

export const workoutImageLimitBytes = 100000000;
const mb = bytes => bytes > 0 && bytes < 10000 ? '<0.01' : (bytes / 1000000).toFixed(2);
export const workoutImageSources = workout => [...new Set([
  ...(workout?.modules ?? []).map(module => module?.imageUrl),
  workout?.countdownImageSource,
].filter(value => typeof value === 'string' && value.length > 0))];

// Parse supported Storage URLs only. Never fetch a URL supplied by a client.
export function ownedWorkoutImage(source, uid, bucketName, emulatorHost) {
  let url;
  try { url = new URL(source); } catch { return null; }
  let bucket, path;
  const firebaseUrl = url.protocol === 'https:' && url.hostname === 'firebasestorage.googleapis.com' && !url.port;
  const emulatorUrl = emulatorHost && url.protocol === 'http:' && url.host === emulatorHost;
  if ((firebaseUrl || emulatorUrl) && !url.username && !url.password) {
    const match = /^\/v0\/b\/([^/]+)\/o\/([^/]+)$/.exec(url.pathname);
    if (!match) return null;
    try { bucket = decodeURIComponent(match[1]); path = decodeURIComponent(match[2]); }
    catch { return null; }
  } else if (url.protocol === 'gs:') {
    bucket = url.hostname;
    try { path = decodeURIComponent(url.pathname.slice(1)); } catch { return null; }
  } else { return null; }
  if (bucket !== bucketName || !path.startsWith(`users/${uid}/workouts/`) ||
      path.split('/').length < 5 || path.split('/').some(p => !p || p === '.' || p === '..')) return null;
  return path;
}

/// One checker per callable invocation; transaction retries share metadata reads.
export function workoutImageBudgetChecker(bucket, uid, {
  emulatorHost = process.env.FIREBASE_STORAGE_EMULATOR_HOST,
  metadataTimeoutMs = 8000, totalTimeoutMs = 20000, managedContext = null,
} = {}) {
  const sizes = new Map();
  const deadline = Date.now() + totalTimeoutMs;
  async function metadataSize(path, managed) {
    let timer;
    try {
      return await Promise.race([
        (managed ? managedMetadata({...managedContext,bucket},managed).then(({metadata})=>[metadata]) : bucket.file(path).getMetadata()).then(([metadata]) => {
          const size = Number(metadata.size);
          if (!Number.isSafeInteger(size) || size < 0 || !metadata.contentType?.startsWith('image/')) {
            throw new Error('Invalid image metadata');
          }
          return size;
        }),
        new Promise((_, reject) => { timer = setTimeout(() => reject(new Error('Metadata timeout')),
          Math.max(1, Math.min(metadataTimeoutMs, deadline - Date.now()))); }),
      ]);
    } finally { clearTimeout(timer); }
  }
  return async (workout, previous) => {
    const oldSources = new Set(workoutImageSources(previous));
    const paths = new Map();
    let unknownCount = 0;
    for (const source of workoutImageSources(workout)) {
      const parsed = managedContext && parseManagedSource(source,managedContext);
      if (parsed) {
        const asset = await readManagedAsset({...managedContext,bucket},uid,parsed.assetId,parsed.generation);
        paths.set(`${asset.path}@${asset.generation}`,{path:asset.path,managed:asset});continue;
      }
      const path = ownedWorkoutImage(source, uid, bucket.name, emulatorHost);
      if (path) { paths.set(path,{path,managed:null}); continue; }
      // Do not break editing of historical external assets. They remain unknown,
      // never zero; new/copy/restored external URLs must be replaced by an upload.
      if (oldSources.has(source)) { unknownCount++; continue; }
      throw new HttpsError('failed-precondition',
        '이미지 용량을 확인할 수 없습니다. 이미지를 다시 선택한 뒤 저장해 주세요.',
        {reason: 'workout-image-unverifiable'});
    }
    const entries = [...paths.entries()];
    let next = 0, totalBytes = 0;
    async function worker() {
      while (next < entries.length) {
        const [key,{path,managed}] = entries[next++];
        if (Date.now() >= deadline) throw new Error('Metadata deadline');
        if (!sizes.has(key)) sizes.set(key, metadataSize(path,managed));
        const bytes = await sizes.get(key);
        totalBytes += bytes;
      }
    }
    try {
      const results = await Promise.allSettled(Array.from({length: Math.min(3, entries.length)}, worker));
      if (results.some(result => result.status === 'rejected')) throw new Error('Metadata failed');
    }
    catch {
      throw new HttpsError('failed-precondition',
        '이미지 용량을 확인하지 못했습니다. 연결을 확인하거나 이미지를 다시 선택한 뒤 저장해 주세요.',
        {reason: 'workout-image-metadata-unavailable'});
    }
    if (totalBytes > workoutImageLimitBytes) {
      throw new HttpsError('resource-exhausted',
        `워크아웃 이미지는 총 100 MB까지 저장할 수 있어요. ${mb(totalBytes - workoutImageLimitBytes)} MB 초과했어요. 큰 이미지를 줄이거나 삭제해 주세요.`,
        {reason: 'workout-image-budget-exceeded', totalBytes, limitBytes: workoutImageLimitBytes});
    }
    return {totalBytes, unknownCount};
  };
}
