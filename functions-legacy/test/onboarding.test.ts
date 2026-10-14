import assert from 'node:assert/strict';
import { test } from 'node:test';
import { randomUUID, randomBytes } from 'node:crypto';
import pg from 'pg';
import { handleAPI } from '../src/api.js';
import { readConfig } from '../src/config.js';
import { linkIdentity } from '../src/services/onboarding.js';
import { SubscriptionService } from '../src/services/subscriptions.js';
import { entitlementFor, syncEntitlements } from '../src/services/sync.js';
import {
  signCheckoutQuote,
  readCheckoutQuote,
  PRICE,
  POLICY_VERSION,
} from '../src/services/core.js';
import type { PaymentGateway } from '../src/services/toss.js';
const developmentOnly =
  process.env.NEON_BRANCH_NAME === 'development' &&
  process.env.BETTER_AUTH_URL?.startsWith('http://localhost');
const gateway: PaymentGateway = {
  issue: async () => ({ billingKey: 'fake' }),
  charge: async (_billingKey, _customerKey, orderId, amount) => ({
    paymentKey: 'fake-' + orderId,
    orderId,
    status: 'DONE',
    totalAmount: amount,
    currency: 'KRW',
  }),
  lookup: async () => null,
  refund: async () => {
    throw Error('unused');
  },
};
test('production entitlements allow free preparation and trial with test billing, never test-paid access', () => {
  const s = {
    store_id: 'store',
    display_limit: 3,
    revision: 1,
    billing_mode: 'test',
    status: 'pending_connection',
  };
  assert.equal(entitlementFor(s).canPairDisplay, true);
  assert.equal(entitlementFor(s).canStartClass, false);
  const trial = { ...s, status: 'trialing', trial_ends_at: new Date(Date.now() + 60000) };
  assert.equal(entitlementFor(trial).canStartClass, true);
  for (const status of ['active', 'past_due'])
    assert.equal(
      entitlementFor({
        ...s,
        status,
        current_period_end: new Date(Date.now() + 60000),
        grace_ends_at: new Date(Date.now() + 60000),
      }).canStartClass,
      false,
    );
  assert.equal(
    entitlementFor({ ...trial, deletion_requested_at: new Date() }).canPairDisplay,
    false,
  );
  assert.equal(entitlementFor(trial, new Date(trial.trial_ends_at)).canStartClass, false);
  const end = new Date('2026-09-18T00:00:00Z');
  const renewing = {
    ...s,
    status: 'active',
    billing_mode: 'live',
    current_period_end: end,
    cancel_at_period_end: false,
  };
  assert.equal(
    entitlementFor(renewing, new Date(+end + 1)).validUntilMs,
    +end + 7 * 86400000,
    'scheduler delay remains within the anchored renewal grace',
  );
  assert.equal(
    entitlementFor({ ...renewing, cancel_at_period_end: true }, new Date(+end + 1)).canStartClass,
    false,
  );
  const q = signCheckoutQuote('u', new Date(), 'test', 'secret', 99000);
  assert.equal(PRICE, 99000);
  assert.throws(() => readCheckoutQuote(q, 'u', 'test', 'secret', 39000));
});
test(
  'web-first creation, atomic identity binding, price locking and isolated sync retry',
  { skip: !developmentOnly },
  async () => {
    const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL, max: 5 });
    const ids = [randomUUID(), randomUUID(), randomUUID()];
    const stores: string[] = [];
    const svc = new SubscriptionService(pool, gateway, 'test', randomBytes(32).toString('base64'));
    const previousSync = process.env.ENTITLEMENT_SYNC_ENABLED;
    try {
      for (const id of ids)
        await pool.query(
          'INSERT INTO "user"(id,name,email,email_verified,phone_number_verified) VALUES($1,$2,$3,true,true)',
          [id, 'Onboarding test', id + '@example.invalid'],
        );
      const [first, duplicate] = await Promise.all([
        svc.createStore(ids[0], 'Studio'),
        svc.createStore(ids[0], 'Other'),
      ]);
      stores.push(first.id);
      assert.equal(first.id, duplicate.id);
      assert.equal(
        (await pool.query('SELECT * FROM cb_identities WHERE user_id=$1', [ids[0]])).rowCount,
        0,
      );
      assert.equal((await svc.owned(ids[0])).trial_started_at, null);
      const originalTrial = await svc.owned(ids[0]);
      await pool.query(
        "UPDATE cb_subscriptions SET status='pending_connection',trial_started_at=NULL,trial_ends_at=NULL WHERE store_id=$1",
        [first.id],
      );
      await svc.createStore(ids[0], 'Recovered account');
      assert.equal(
        +(await svc.owned(ids[0])).trial_ends_at,
        +originalTrial.trial_ends_at,
        'legacy pending accounts never receive a new trial',
      );
      assert.equal((await svc.owned(ids[0])).monthly_price, 99000);
      const runtime = {
        pool,
        config: readConfig(),
        auth: {
          api: { getSession: async () => ({ user: { id: ids[0], phoneNumberVerified: true } }) },
        },
      } as unknown as Parameters<typeof handleAPI>[1];
      const cardRequest = (path: string, body: object) =>
        handleAPI(
          new Request('http://localhost:3087' + path, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(body),
          }),
          runtime,
          svc,
        );
      const cardResponse = await cardRequest('/api/account/card', {});
      assert.equal(cardResponse.status, 200, 'free account can pre-register a card');
      const card = await cardResponse.json();
      const confirmations = await Promise.all([
        cardRequest('/api/account/card/confirm', {
          id: card.id,
          customerKey: card.customerKey,
          authKey: 'fake',
        }),
        cardRequest('/api/account/card/confirm', {
          id: card.id,
          customerKey: card.customerKey,
          authKey: 'fake',
        }),
      ]);
      assert(confirmations.every((r) => r.status === 200));
      assert.equal(
        (await svc.owned(ids[0])).status,
        'pending_connection',
        'card registration never starts paid access or a trial',
      );
      assert.equal(
        (
          await pool.query('SELECT count(*)::int AS count FROM cb_payments WHERE store_id=$1', [
            first.id,
          ])
        ).rows[0].count,
        0,
        'card registration never creates a charge',
      );

      const quoteResponse = await handleAPI(
        new Request('http://localhost:3087/api/checkout/quote'),
        runtime,
        svc,
      );
      assert.equal(
        quoteResponse.status,
        200,
        'unlinked account can see a checkout quote immediately',
      );
      const quote = await quoteResponse.json();
      assert.equal(quote.amount, 99000);
      assert.equal(
        (await cardRequest('/api/account/trial', { confirm: true })).status,
        404,
        'public trial-start flow is removed',
      );
      assert.equal(
        (
          await cardRequest('/api/checkout', {
            consent: false,
            consentVersion: POLICY_VERSION,
            quoteToken: quote.quoteToken,
          })
        ).status,
        400,
      );
      const directPayment = await cardRequest('/api/checkout', {
        consent: true,
        consentVersion: POLICY_VERSION,
        quoteToken: quote.quoteToken,
      });
      assert.equal(directPayment.status, 200);
      const paid = await directPayment.json();
      assert.equal(
        paid.status,
        'succeeded',
        'saved card can start a subscription without an app or display',
      );
      assert.equal(paid.amount, 99000);
      assert.equal((await svc.owned(ids[0])).trial_started_at, null);
      assert.equal(
        (await pool.query('SELECT 1 FROM cb_identities WHERE user_id=$1', [ids[0]])).rowCount,
        0,
      );
      await assert.rejects(() => svc.checkout(ids[0], POLICY_VERSION), /이미 이용 중/);

      stores.push((await svc.createStore(ids[1], 'Second')).id);
      const uid = 'fixture-' + randomUUID();
      const results = await Promise.allSettled([
        linkIdentity(pool, ids[0], uid),
        linkIdentity(pool, ids[1], uid),
      ]);
      assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
      const winner = results[0].status === 'fulfilled' ? 0 : 1,
        loser = 1 - winner;
      assert.equal((await linkIdentity(pool, ids[winner], uid)).linked, true);
      await assert.rejects(() => linkIdentity(pool, ids[winner], 'other-uid'), /연결/);
      await linkIdentity(pool, ids[loser], uid + '-2');
      assert.equal(
        (await linkIdentity(pool, ids[2], uid + '-3')).status,
        'web_registration_required',
      );
      process.env.ENTITLEMENT_SYNC_ENABLED = 'true';
      const syncPool = {
        query: (sql: string, values: unknown[]) =>
          sql.includes('SELECT s.*,i.firebase_uid')
            ? pool.query(
                sql.replace(
                  'ORDER BY s.updated_at',
                  'AND s.store_id=ANY($2::uuid[]) ORDER BY s.updated_at',
                ),
                [...values, stores],
              )
            : pool.query(sql, values),
      } as unknown as pg.Pool;
      const visited: string[] = [];
      await syncEntitlements(syncPool, undefined, async (row) => {
        if (!stores.includes(row.store_id)) return;
        visited.push(row.store_id);
        if (row.store_id === stores[0]) throw Error('Firestore unavailable after RTDB success');
      });
      assert.equal(visited.length, 2);
      const a = await svc.owned(ids[0]),
        b = await svc.owned(ids[1]);
      assert.equal(a.synced_revision, -1);
      assert.equal(a.sync_attempts, 1);
      assert.equal(b.synced_revision, b.revision);
      await syncEntitlements(syncPool, stores[0], async () => {});
      assert.equal((await svc.owned(ids[0])).synced_revision, a.revision);
      await pool.query(
        "UPDATE cb_subscriptions SET status='expired',monthly_price=39000 WHERE store_id=$1",
        [stores[0]],
      );
      await assert.rejects(() => svc.checkout(ids[0], POLICY_VERSION, new Date(), 99000), /요금/);
      const p = await svc.checkout(ids[0], POLICY_VERSION, new Date(), 39000);
      assert.equal(p.amount, 39000, 'existing agreed price survives new global price');
    } finally {
      if (previousSync === undefined) delete process.env.ENTITLEMENT_SYNC_ENABLED;
      else process.env.ENTITLEMENT_SYNC_ENABLED = previousSync;
      await pool.query('DELETE FROM cb_payments WHERE store_id=ANY($1::uuid[])', [stores]);
      await pool.query('DELETE FROM cb_card_changes WHERE store_id=ANY($1::uuid[])', [stores]);
      await pool.query('DELETE FROM cb_subscriptions WHERE store_id=ANY($1::uuid[])', [stores]);
      await pool.query('DELETE FROM cb_stores WHERE id=ANY($1::uuid[])', [stores]);
      await pool.query('DELETE FROM "user" WHERE id=ANY($1::text[])', [ids]);
      await pool.end();
    }
  },
);
