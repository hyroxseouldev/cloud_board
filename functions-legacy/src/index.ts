import { onRequest, onCall, HttpsError } from 'firebase-functions/v2/https';
import { getAuthRuntime } from './auth.js';
import { defineSecret, defineString } from 'firebase-functions/params';
import { handleAuthRequest } from './http.js';
import { pairDisplay } from './services/pairing.js';
import { linkFromApp } from './services/onboarding.js';
import { HttpError } from './services/core.js';
import { syncAfterChange } from './services/sync.js';
import { firebaseServices } from './services/firebase.js';

const databaseURL = defineSecret('DATABASE_URL');
const authSecret = defineSecret('BETTER_AUTH_SECRET');
const optionalSecrets = [
  'GOOGLE_CLIENT_SECRET',
  'TOSS_SECRET_KEY',
  'BILLING_ENCRYPTION_KEY',
  'SOLAPI_API_KEY',
  'SOLAPI_API_SECRET',
  'CLOUDBOARD_GATEWAY_SECRET',
].map((name) => defineSecret(name));
defineString('BETTER_AUTH_URL');
defineString('AUTH_TRUSTED_ORIGINS');

export const cloudboardAuth = onRequest(
  {
    region: 'asia-southeast1',
    secrets: [databaseURL, authSecret, ...optionalSecrets],
    minInstances: 0,
    maxInstances: 3,
    concurrency: 20,
    memory: '256MiB',
    timeoutSeconds: 180,
  },
  async (req, res) => {
    try {
      await handleAuthRequest(req, res);
    } catch {
      console.error('Authentication request failed');
      if (!res.headersSent)
        res.status(500).json({ error: 'Authentication temporarily unavailable' });
      else res.end();
    }
  },
);

// Native app callable; web login and all web sessions remain Better Auth.
export const cloudboardSetDisplayState = onCall(
  { region: 'asia-southeast1', maxInstances: 3, timeoutSeconds: 30 },
  async (request) => {
    if (!request.auth || request.auth.token.firebase?.sign_in_provider === 'anonymous')
      throw new HttpsError('unauthenticated', '매장 계정 로그인이 필요합니다.');
    const bearer = request.rawRequest.headers.authorization?.match(/^Bearer (.+)$/i)?.[1];
    if (!bearer) throw new HttpsError('unauthenticated', '다시 로그인해 주세요.');
    try {
      await firebaseServices().auth.verifyIdToken(bearer, true);
    } catch {
      throw new HttpsError('unauthenticated', '다시 로그인해 주세요.');
    }
    const { activateDisplay } = await import('./services/display-activation.js');
    return activateDisplay(firebaseServices().realtime, request.auth.uid, request.data);
  },
);

export const cloudboardPairDisplay = onCall(
  { region: 'asia-southeast1', maxInstances: 3, timeoutSeconds: 30 },
  async (request) => {
    if (!request.auth || request.auth.token.firebase?.sign_in_provider === 'anonymous')
      throw new HttpsError('unauthenticated', '매장 계정 로그인이 필요합니다.');
    const bearer = request.rawRequest.headers.authorization?.match(/^Bearer (.+)$/i)?.[1];
    if (!bearer) throw new HttpsError('unauthenticated', '다시 로그인해 주세요.');
    try {
      await firebaseServices().auth.verifyIdToken(bearer, true);
    } catch {
      throw new HttpsError('unauthenticated', '다시 로그인해 주세요.');
    }
    return pairDisplay(firebaseServices().realtime, request.auth.uid, request.data);
  },
);

// Callable SDK supplies the Firebase ID token; verify revocation and provider again.
export const cloudboardLinkAccount = onCall(
  {
    region: 'asia-southeast1',
    maxInstances: 3,
    timeoutSeconds: 60,
    secrets: [databaseURL, authSecret],
  },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', '로그인이 필요합니다.');
    const bearer = request.rawRequest.headers.authorization?.match(/^Bearer (.+)$/i)?.[1];
    if (!bearer) throw new HttpsError('unauthenticated', '로그인이 필요합니다.');
    try {
      const pool = getAuthRuntime().pool;
      const result = await linkFromApp(pool, bearer);
      if ('storeId' in result) await syncAfterChange(pool, result.storeId);
      return result;
    } catch (e) {
      if (e instanceof HttpError)
        throw new HttpsError(e.status === 409 ? 'already-exists' : 'permission-denied', e.message);
      throw new HttpsError('unavailable', '계정 연결을 다시 시도해 주세요.');
    }
  },
);
