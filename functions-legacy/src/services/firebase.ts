import { getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { getDatabase } from 'firebase-admin/database';
import { HttpError } from './core.js';
const projectId = process.env.GCLOUD_PROJECT || 'cloud-board-stationd';
export function firebaseServices() {
  if (
    process.env.BETTER_AUTH_URL?.startsWith('http://localhost') &&
    process.env.FIREBASE_APP_LINK_ENABLED !== 'true' &&
    !process.env.FIREBASE_AUTH_EMULATOR_HOST
  ) {
    throw new HttpError(
      503,
      'APP_LINK_NOT_CONFIGURED',
      '앱 계정 연결을 준비 중입니다. 잠시 후 다시 확인해 주세요.',
    );
  }
  const app =
    getApps()[0] ||
    initializeApp({
      projectId,
      databaseURL: `https://${projectId}-default-rtdb.asia-southeast1.firebasedatabase.app`,
    });
  return { auth: getAuth(app), firestore: getFirestore(app), realtime: getDatabase(app) };
}
// Firebase is used only to resolve the existing APP owner. Web authentication
// and SMS verification are exclusively Better Auth.
export async function resolveAppUser(googleSubject: string): Promise<string> {
  const { auth, firestore } = firebaseServices();
  const result = await auth.getUsers([{ providerId: 'google.com', providerUid: googleSubject }]);
  const record = result.users[0];
  if (record?.disabled) throw new HttpError(403, 'APP_ACCOUNT_DISABLED', '비활성화된 앱 계정입니다.');
  if (!record)
    throw new HttpError(
      409,
      'APP_ACCOUNT_REQUIRED',
      '앱에서 같은 Google 계정으로 먼저 로그인해 주세요.',
    );
  if ((await firestore.doc(`accountDeletions/${record.uid}`).get()).exists)
    throw new HttpError(403, 'ACCOUNT_DELETING', '삭제 처리 중인 앱 계정입니다.');
  return record.uid;
}
export async function appDevices(uid: string) {
  const realtime = firebaseServices().realtime;
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(
      () => reject(new HttpError(503, 'DEVICE_LOOKUP_TIMEOUT', '기기 정보를 가져오지 못했습니다.')),
      6000,
    );
  });
  const snap = await Promise.race([realtime.ref(`users/${uid}/devices`).get(), timeout]).finally(
    () => clearTimeout(timer),
  );
  const devices = Object.values(snap.val() || {}) as any[];
  return devices
    .filter((d) => d?.mode === 'display' && d.paired === true)
    .map((d) => ({
      id: d.id,
      name: d.name || '매장 화면',
      online: d.online === true,
      lastSeenAtMs: d.lastSeenAtMs,
    }));
}
