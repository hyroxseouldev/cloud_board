import assert from 'node:assert/strict';
import { test } from 'node:test';
import { randomUUID } from 'node:crypto';
import { cloudboardLinkAccount, cloudboardPairDisplay, cloudboardSetDisplayState } from '../src/index.js';
import { linkIdentity } from '../src/services/onboarding.js';
import { database } from './helpers/database.js';

for (const [name, callable] of Object.entries({ cloudboardLinkAccount, cloudboardPairDisplay, cloudboardSetDisplayState })) {
  test(`${name} retains unauthenticated errors without backend access`, async () => {
    await assert.rejects(callable.run({ data: {}, rawRequest: { headers: {} } } as any), { code: 'unauthenticated' });
    await assert.rejects(callable.run({ auth: { uid: 'owner', token: { firebase: { sign_in_provider: 'google.com' } } }, data: {}, rawRequest: { headers: {} } } as any), { code: 'unauthenticated' });
  });
}

test('native account linkage preserves historical paid data and rejects another Firebase identity', async () => {
  const { db, pool } = await database();
  const owner = randomUUID(), store = randomUUID();
  try {
    await pool.query('INSERT INTO "user"(id,name,email,phone_number_verified) VALUES($1,$2,$3,true)', [owner, 'Owner', `${owner}@example.invalid`]);
    await pool.query('INSERT INTO cb_stores(id,owner_id,name) VALUES($1,$2,$3)', [store, owner, 'Existing center']);
    await pool.query("INSERT INTO cb_subscriptions(store_id,status,monthly_price,customer_key,billing_mode,display_limit,revision) VALUES($1,'active',39000,$2,'live',3,7)", [store, randomUUID()]);
    assert.deepEqual(await linkIdentity(pool, owner, 'firebase-owner'), { status: 'linked', linked: true, storeId: store });
    await linkIdentity(pool, owner, 'firebase-owner');
    await assert.rejects(linkIdentity(pool, owner, 'different-owner'), { code: 'IDENTITY_CONFLICT' });
    const row = (await pool.query('SELECT status,monthly_price,display_limit,revision FROM cb_subscriptions WHERE store_id=$1', [store])).rows[0];
    assert.deepEqual(row, { status: 'active', monthly_price: 39000, display_limit: 3, revision: 8 });
  } finally { await db.close(); }
});
