import { randomUUID } from 'node:crypto';
import type pg from 'pg';
import { HttpError, transaction } from './core.js';

// Verification creates the billing shell only. The app server grants verified Free;
// existing trial and paid periods are never changed by bootstrap or retry.
export async function ensureAccountStore(pool: pg.Pool, owner: string, name: string, mode: string) {
  return transaction(pool, async (c) => {
    const user = (
      await c.query('SELECT phone_number_verified FROM "user" WHERE id=$1 FOR UPDATE', [owner])
    ).rows[0];
    if (!user?.phone_number_verified)
      throw new HttpError(403, 'PHONE_REQUIRED', '휴대폰 인증이 필요합니다.');
    const existing = (
      await c.query('SELECT deletion_requested_at FROM cb_stores WHERE owner_id=$1', [owner])
    ).rows[0];
    if (existing?.deletion_requested_at)
      throw new HttpError(403, 'ACCOUNT_DELETING', '삭제 처리 중인 계정입니다.');
    const store = (
      await c.query(
        'INSERT INTO cb_stores(owner_id,name) VALUES($1,$2) ON CONFLICT(owner_id) DO UPDATE SET name=cb_stores.name RETURNING *',
        [owner, name],
      )
    ).rows[0];
    await c.query(
      `INSERT INTO cb_subscriptions(store_id,customer_key,billing_mode,status)
       VALUES($1,$2,$3,'pending_connection') ON CONFLICT(store_id) DO NOTHING`,
      [store.id, randomUUID(), mode],
    );
    return store;
  });
}
