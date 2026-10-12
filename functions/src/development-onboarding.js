import {Timestamp} from 'firebase-admin/firestore';
import {HttpsError} from 'firebase-functions/v2/https';
import {developmentProject} from './development-backend-config.js';

// A claim is granted by an operator through Admin Auth, never by app input.
// Check before handleOnboarding can persist a challenge or consume its limits.
export function assertDevelopmentSmsTester(projectId, auth, action) {
  if (projectId === developmentProject && ['sendCode', 'verifyCode'].includes(action)
    && (auth?.token?.developmentTester !== true
      || auth.token.firebase?.sign_in_provider === 'anonymous')) {
    throw new HttpsError('permission-denied', '개발 테스트 계정 등록이 필요합니다.');
  }
}

export async function sendDevelopmentOnboardingSms({projectId, db, auth, code, now = Date.now()}) {
  if (projectId !== developmentProject) throw new Error('Development SMS is unavailable in this project');
  assertDevelopmentSmsTester(projectId, auth, 'sendCode');
  if (!auth?.uid || typeof code !== 'string' || !/^\d{6}$/.test(code)) throw new Error('Invalid development challenge');
  // Default-denied by Firestore rules. OTPs/recipients are never logged or
  // returned by the callable. Operators read only their explicit test UID.
  await db.doc(`developmentSmsOutbox/${auth.uid}`).set({
    code, expiresAt: Timestamp.fromMillis(now + 5 * 60_000),
  });
}
