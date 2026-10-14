import assert from 'node:assert/strict';
import { test } from 'node:test';
import { randomUUID } from 'node:crypto';
import type { Database } from 'firebase-admin/database';
import { cloudboardLinkAccount, cloudboardPairDisplay, cloudboardSetDisplayState } from '../src/index.js';
import { pairDisplay } from '../src/services/pairing.js';
import { linkIdentity } from '../src/services/onboarding.js';
import { database } from './helpers/database.js';

for (const [name, callable] of Object.entries({ cloudboardLinkAccount, cloudboardPairDisplay, cloudboardSetDisplayState })) {
  test(`${name} retains unauthenticated errors without backend access`, async () => {
    await assert.rejects(callable.run({ data: {}, rawRequest: { headers: {} } } as any), { code: 'unauthenticated' });
    await assert.rejects(callable.run({ auth: { uid: 'owner', token: { firebase: { sign_in_provider: 'google.com' } } }, data: {}, rawRequest: { headers: {} } } as any), { code: 'unauthenticated' });
  });
}

test('TV pairing preserves existing registration and cold-cache transaction semantics', async () => {
  const now = Date.now();
  const data: Record<string, any> = {
    'subscriptionAccess/owner': { managed: true, status: 'active', plan: 'free', policyVersion: 'plan-entitlements-v2', maxActiveDisplays: 1, displaysUnlimited: false, canStartClass: true, validUntilMs: now + 60_000 },
    'pairingCodes/123456': { deviceId: 'second-tv', displayUid: 'tv-user', expiresAtMs: now + 60_000 },
    'users/owner/devices': { existing: { id: 'existing', paired: true, displayState: 'auto' } },
  };
  const db = { ref(path: string) { return {
    get: async () => ({ exists: () => data[path] != null, val: () => data[path] }),
    transaction: async (update: (value: unknown) => unknown) => {
      // An RTDB transaction can run with null before server retry.
      update(null); const next = update(data[path] ?? null);
      if (next !== undefined) data[path] = next;
      return { committed: next !== undefined, snapshot: { exists: () => next != null, val: () => next } };
    },
    update: async (next: object) => { data[path] = { ...data[path], ...next }; },
  }; } } as unknown as Database;
  const request = { code: '123456', name: 'Second TV', zoneName: 'Center' };
  assert.deepEqual(await pairDisplay(db, 'owner', request), { paired: true, deviceId: 'second-tv' });
  assert.equal(data['users/owner/devices'].existing.displayState, 'auto');
  assert.equal(data['users/owner/devices']['second-tv'].displayState, 'black');
  assert.equal(data['displayAccess/tv-user'].ownerId, 'owner');
  assert.deepEqual(await pairDisplay(db, 'owner', request), { paired: true, deviceId: 'second-tv' });
  assert.equal(Object.keys(data['users/owner/devices']).length, 2);
  data['accountDeletions/owner'] = { state: 'pending' };
  await assert.rejects(pairDisplay(db, 'owner', request), { code: 'permission-denied' });
});

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
