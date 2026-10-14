import { publishPhoneVerification } from './verification-proof.js';
import type pg from 'pg';
import { HttpError, transaction } from './core.js';
import { firebaseServices, resolveAppUser } from './firebase.js';

// Only provider subjects verified by Google/Firebase are identity keys. Never email.
export async function linkIdentity(pool: pg.Pool, owner: string, uid: string) {
  try {
    return await transaction(pool, async (c) => {
      const user = (
        await c.query('SELECT phone_number_verified FROM "user" WHERE id=$1 FOR UPDATE', [owner])
      ).rows[0];
      if (!user?.phone_number_verified)
        throw new HttpError(403, 'PHONE_REQUIRED', '웹에서 문자 인증을 완료해 주세요.');
      const store = (
        await c.query('SELECT id,deletion_requested_at FROM cb_stores WHERE owner_id=$1', [owner])
      ).rows[0];
      if (store?.deletion_requested_at)
        throw new HttpError(403, 'ACCOUNT_DELETING', '삭제 처리 중인 계정입니다.');
      if (!store) return { status: 'web_registration_required', linked: false };
      const old = (
        await c.query('SELECT firebase_uid FROM cb_identities WHERE user_id=$1', [owner])
      ).rows[0];
      if (old && old.firebase_uid !== uid)
        throw new HttpError(409, 'IDENTITY_CONFLICT', '이미 연결한 앱 계정과 다릅니다.');
      await c.query(
        `INSERT INTO cb_identities(user_id,firebase_uid,phone_verified_at) VALUES($1,$2,now()) ON CONFLICT(user_id) DO NOTHING`,
        [owner, uid],
      );
      if (!old)
        await c.query(
          'UPDATE cb_subscriptions SET revision=revision+1,sync_next_attempt_at=NULL,updated_at=now() WHERE store_id=$1',
          [store.id],
        );
      return { status: 'linked', linked: true, storeId: store.id };
    });
  } catch (e: any) {
    if (e.code === '23505')
      throw new HttpError(409, 'IDENTITY_CONFLICT', '이미 다른 웹 계정에 연결된 앱 계정입니다.');
    throw e;
  }
}
export async function linkFromWeb(pool: pg.Pool, owner: string) {
  const google = (
    await pool.query("SELECT account_id FROM account WHERE user_id=$1 AND provider_id='google'", [
      owner,
    ])
  ).rows[0];
  if (!google) throw new HttpError(403, 'GOOGLE_REQUIRED', 'Google 계정으로 로그인해 주세요.');
  try {
    const uid = await resolveAppUser(google.account_id);
    const result = await linkIdentity(pool, owner, uid);
    if (result.linked) await publishPhoneVerification(pool, owner, uid);
    return result;
  } catch (e) {
    if (
      e instanceof HttpError &&
      ['APP_ACCOUNT_REQUIRED', 'APP_LINK_NOT_CONFIGURED'].includes(e.code)
    )
      return {
        status: e.code === 'APP_ACCOUNT_REQUIRED' ? 'awaiting_app' : 'connection_unavailable',
        linked: false,
      };
    throw e;
  }
}
export async function linkFromApp(pool: pg.Pool, idToken: string) {
  const { auth, firestore } = firebaseServices();
  const token = await auth.verifyIdToken(idToken, true);
  if (token.firebase.sign_in_provider !== 'google.com')
    throw new HttpError(403, 'GOOGLE_REQUIRED', '웹과 같은 Google 계정으로 로그인해 주세요.');
  const user = await auth.getUser(token.uid);
  const subject = user.providerData.find((p) => p.providerId === 'google.com')?.uid;
  if (
    !subject ||
    user.disabled ||
    (await firestore.doc(`accountDeletions/${user.uid}`).get()).exists
  )
    throw new HttpError(403, 'APP_ACCOUNT_UNAVAILABLE', '사용할 수 없는 앱 계정입니다.');
  const owners = (
    await pool.query(
      `SELECT a.user_id,u.phone_number_verified FROM account a JOIN "user" u ON u.id=a.user_id WHERE a.provider_id='google' AND a.account_id=$1`,
      [subject],
    )
  ).rows;
  if (!owners.length || !owners[0].phone_number_verified)
    return { status: 'web_registration_required', linked: false };
  if (owners.length !== 1)
    throw new HttpError(409, 'IDENTITY_CONFLICT', '계정 연결 확인이 필요합니다.');
  const result = await linkIdentity(pool, owners[0].user_id, user.uid);
  if (result.linked) await publishPhoneVerification(pool, owners[0].user_id, user.uid);
  return result;
}
