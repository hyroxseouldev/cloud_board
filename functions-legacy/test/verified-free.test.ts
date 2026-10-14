import assert from 'node:assert/strict';
import { test } from 'node:test';
import { randomUUID } from 'node:crypto';
import { database } from './helpers/database.js';
import { ensureAccountStore } from '../src/services/account.js';
import {
  verifiedWebUser,
  matchingAppAccess,
  readAppAccess,
} from '../src/services/verified-access.js';
import { entitlementFor } from '../src/services/sync.js';
import { handleAPI } from '../src/api.js';
import { SubscriptionService } from '../src/services/subscriptions.js';
import { publishPhoneVerification } from '../src/services/verification-proof.js';

const now = Date.now();
const active = {
  managed: true,
  plan: 'free',
  status: 'active',
  canStartClass: true,
  validUntilMs: now + 100000,
  revision: 1,
  policyVersion: 'plan-entitlements-v2',
};
test('activation waits for both projections, exact revision, valid status and trusted Free proof', async () => {
  assert.equal(matchingAppAccess(active, active, now, true), true);
  assert.equal(matchingAppAccess(active, active, now, false), false);
  for (const patch of [
    { status: 'unknown' },
    { status: 'expired' },
    { status: 'legacy' },
    { plan: 'missing' },
    { validUntilMs: Infinity },
    { validUntilMs: '99999999999999' },
    { validUntilMs: now },
    { canStartClass: false },
  ]) {
    const candidate = { ...active, ...patch };
    assert.equal(matchingAppAccess(candidate, candidate, now, true), false);
  }
  assert.equal(matchingAppAccess(active, { ...active, revision: 2 }, now, true), false);
  assert.equal(matchingAppAccess(active, null, now, true), false);
  assert.equal(
    matchingAppAccess({ ...active, maxWorkouts: 7 }, { ...active, maxWorkouts: 99 }, now, true),
    false,
  );
  const legacy = { ...active, plan: 'premium', status: 'trialing' };
  assert.equal(
    matchingAppAccess(legacy, legacy, now, false),
    true,
    'existing valid trial is not revoked by missing new proof',
  );
  for (const plan of ['legacy', 'cloudboard_pro']) {
    const grant = { ...active, plan, status: 'legacy' };
    assert.equal(matchingAppAccess(grant, grant, now), true);
    assert.equal(matchingAppAccess(grant, { ...grant, revision: 2 }, now), false);
    assert.equal(matchingAppAccess(grant, grant, grant.validUntilMs), false);
  }
  for (const plan of ['free', 'plus', 'premium']) {
    const grant = { ...active, plan, status: 'legacy' };
    assert.equal(matchingAppAccess(grant, grant, now, true), false);
  }
  assert.deepEqual(await readAppAccess(), { status: 'awaiting_app' });
  assert.deepEqual(
    await readAppAccess('uid', () => {
      throw Error('offline');
    }),
    { status: 'unavailable' },
  );
});

test('verified SQL bootstrap never issues/restarts a trial and preserves existing dates and price', async () => {
  const { db, pool } = await database();
  const owner = randomUUID();
  try {
    await pool.query(
      'INSERT INTO "user"(id,name,email,phone_number_verified) VALUES($1,$2,$3,false)',
      [owner, 'Owner', `${owner}@example.invalid`],
    );
    await assert.rejects(ensureAccountStore(pool, owner, 'Center', 'test'), {
      code: 'PHONE_REQUIRED',
    });
    assert.equal((await pool.query('SELECT count(*)::int AS n FROM cb_stores')).rows[0].n, 0);
    assert.deepEqual(
      await verifiedWebUser(pool, owner, async () => {
        throw Error('must not use email as identity');
      }),
      { verified: false, available: true },
    );
    const fakeSession = {
      pool,
      config: { local: true },
      auth: {
        api: { getSession: async () => ({ user: { id: owner, phoneNumberVerified: true } }) },
      },
    } as any;
    const service = new SubscriptionService(pool, {} as any, 'test', 'unused');
    const me = await handleAPI(new Request('http://localhost/api/me'), fakeSession, service);
    assert.equal(
      (await me.json()).user.phoneVerified,
      false,
      'session/client boolean cannot bypass the SQL record',
    );
    const denied = await handleAPI(
      new Request('http://localhost/api/account/bootstrap', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: '{}',
      }),
      fakeSession,
      service,
    );
    assert.equal(denied.status, 403);
    await pool.query('UPDATE "user" SET phone_number_verified=true WHERE id=$1', [owner]);
    const [first, retry] = await Promise.all([
      ensureAccountStore(pool, owner, 'Center', 'test'),
      ensureAccountStore(pool, owner, 'Rename', 'test'),
    ]);
    assert.equal(first.id, retry.id);
    const stored = async () =>
      (await pool.query('SELECT * FROM cb_subscriptions WHERE store_id=$1', [first.id])).rows[0];
    const original = await stored();
    assert.equal(original.status, 'pending_connection');
    assert.equal(original.trial_started_at, null);
    assert.equal(original.trial_ends_at, null);
    assert.equal(
      entitlementFor(original).canStartClass,
      false,
      'billing shell must not independently create Free',
    );
    const start = new Date(now - 1000),
      end = new Date(now + 86400000);
    for (const status of ['trialing', 'expired', 'active']) {
      await pool.query(
        'UPDATE cb_subscriptions SET status=$2,trial_started_at=$3,trial_ends_at=$4,current_period_end=$4,monthly_price=39000 WHERE store_id=$1',
        [first.id, status, start, end],
      );
      await ensureAccountStore(pool, owner, 'Retry', 'live');
      const after = await stored();
      assert.equal(after.status, status);
      assert.equal(+after.trial_started_at, +start);
      assert.equal(+after.trial_ends_at, +end);
      assert.equal(+after.current_period_end, +end);
      assert.equal(after.monthly_price, 39000);
    }
    const svc = new SubscriptionService(pool, {} as any, 'test', 'unused');
    const runtime = {
      pool,
      config: { local: true },
      auth: {
        api: { getSession: async () => ({ user: { id: owner, phoneNumberVerified: true } }) },
      },
    } as any;
    const oldTrial = await handleAPI(
      new Request('http://localhost/api/account/trial', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: '{"confirm":true}',
      }),
      runtime,
      svc,
    );
    assert.equal(oldTrial.status, 404, 'old public web trial endpoint cannot issue a trial');
    await pool.query(
      'INSERT INTO cb_identities(user_id,firebase_uid,phone_verified_at) VALUES($1,$2,now())',
      [owner, 'deleted-owner'],
    );
    await pool.query('UPDATE cb_stores SET deletion_requested_at=now() WHERE id=$1', [first.id]);
    await assert.rejects(
      publishPhoneVerification(pool, owner, 'deleted-owner', () => {
        throw Error('SQL deletion must block before Firebase is consulted');
      }),
      { code: 'ACCOUNT_DELETING' },
    );
  } finally {
    await db.close();
  }
});

test('historical native server verification recovers SQL by provider subject; outages and spoofed sessions do not verify', async () => {
  const { db, pool } = await database();
  const owner = randomUUID();
  try {
    await pool.query(
      'INSERT INTO "user"(id,name,email,phone_number_verified) VALUES($1,$2,$3,false)',
      [owner, 'Owner', `${owner}@example.invalid`],
    );
    await pool.query(
      "INSERT INTO account(id,user_id,provider_id,account_id,updated_at) VALUES($1,$2,'google',$3,now())",
      [randomUUID(), owner, 'verified-google-subject'],
    );
    let received = '';
    assert.deepEqual(
      await verifiedWebUser(pool, owner, async (subject) => {
        received = subject;
        return false;
      }),
      { verified: false, available: true },
    );
    assert.equal(received, 'verified-google-subject');
    assert.deepEqual(
      await verifiedWebUser(pool, owner, async () => {
        throw Error('network');
      }),
      { verified: false, available: false },
    );
    assert.equal(
      (await pool.query('SELECT phone_number_verified FROM "user" WHERE id=$1', [owner])).rows[0]
        .phone_number_verified,
      false,
    );
    assert.deepEqual(await verifiedWebUser(pool, owner, async () => true), {
      verified: true,
      available: true,
    });
    assert.deepEqual(
      await verifiedWebUser(pool, owner, async () => {
        throw Error('already verified must not recheck');
      }),
      { verified: true, available: true },
    );
    await pool.query('UPDATE "user" SET phone_number_verified=false WHERE id=$1', [owner]);
    await pool.query(
      'INSERT INTO cb_identities(user_id,firebase_uid,phone_verified_at) VALUES($1,$2,now())',
      [owner, 'historically-verified'],
    );
    assert.deepEqual(
      await verifiedWebUser(pool, owner, async () => {
        throw Error('historical SQL verification must not require a new native lookup');
      }),
      { verified: true, available: true },
    );
    const proof = entitlementFor({ status: 'pending_connection', phone_number_verified: true });
    assert.equal(proof.phoneVerified, true);
    assert.equal(proof.canStartClass, false);
    assert.equal(
      entitlementFor({ status: 'pending_connection', phone_verified_at: new Date() }).phoneVerified,
      true,
    );
    assert.equal(
      entitlementFor({ status: 'active', phone_number_verified: false, paidHistory: true })
        .phoneVerified,
      false,
    );
  } finally {
    await db.close();
  }
});
