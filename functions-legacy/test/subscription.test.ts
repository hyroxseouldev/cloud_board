import assert from 'node:assert/strict';
import { test } from 'node:test';
import { randomUUID, randomBytes } from 'node:crypto';
import pg from 'pg';
import { readConfig } from '../src/config.js';
import { createAuth } from '../src/auth.js';
import { handleAPI } from '../src/api.js';
import { saveApplication, purgeApplications } from '../src/services/applications.js';
import {
  DAY,
  PRICE,
  POLICY_VERSION,
  effectiveStatus,
  trialDaysRemaining,
  nextBillingDate,
  seal,
  unseal,
  signCheckoutQuote,
  readCheckoutQuote,
} from '../src/services/core.js';
import { SubscriptionService } from '../src/services/subscriptions.js';
import { GatewayError, type PaymentGateway, type PaymentSnapshot } from '../src/services/toss.js';
const developmentOnly = process.env.NEON_BRANCH_NAME === 'development' && readConfig().local;
class FakeToss implements PaymentGateway {
  payments = new Map<string, PaymentSnapshot>();
  charges = 0;
  issued = 0;
  loseResponse = false;
  decline = false;
  async issue() {
    this.issued++;
    return { billingKey: 'test-billing-key', card: { number: '************1234' } };
  }
  async charge(_key: string, _customer: string, orderId: string, amount: number) {
    if (this.payments.has(orderId)) return this.payments.get(orderId)!;
    if (this.decline) throw new GatewayError('REJECT_CARD_PAYMENT', false);
    this.charges++;
    const p = {
      paymentKey: randomUUID(),
      orderId,
      status: 'DONE',
      totalAmount: amount,
      currency: 'KRW',
      receipt: { url: 'https://example.com/receipt' },
    };
    this.payments.set(orderId, p);
    if (this.loseResponse) {
      this.loseResponse = false;
      throw new GatewayError('NETWORK_UNCERTAIN', true);
    }
    return p;
  }
  async lookup(orderId: string) {
    return this.payments.get(orderId) || null;
  }
  async refund(paymentKey: string) {
    const p = [...this.payments.values()].find((p) => p.paymentKey === paymentKey)!;
    return { ...p, status: 'CANCELED', cancels: [{ cancelAmount: p.totalAmount }] };
  }
}
test('Korea calendar months, grace boundary and encryption integrity', () => {
  const jan = new Date('2028-01-31T09:30:00+09:00'),
    feb = nextBillingDate(jan);
  assert.equal(feb.toISOString(), '2028-02-29T00:30:00.000Z');
  assert.equal(nextBillingDate(feb, 31).toISOString(), '2028-03-31T00:30:00.000Z');
  const quote = signCheckoutQuote('owner', jan, 'test', 'secret');
  assert.equal(
    readCheckoutQuote(quote, 'owner', 'test', 'secret').toISOString(),
    jan.toISOString(),
  );
  assert.throws(() => readCheckoutQuote(quote, 'other', 'test', 'secret'), /만료/);
  assert.throws(() => readCheckoutQuote(quote + 'bad', 'owner', 'test', 'secret'), /만료/);
  assert.throws(() => readCheckoutQuote(quote, 'owner', 'live', 'secret'), /만료/);
  const now = new Date();
  assert.equal(effectiveStatus({ status: 'past_due', grace_ends_at: now }, now), 'expired');
  assert.equal(
    effectiveStatus(
      { status: 'active', current_period_end: new Date(+now + 1), cancel_at_period_end: true },
      now,
    ),
    'canceling',
  );
  const key = randomBytes(32).toString('base64'),
    value = seal('private-billing-key', key);
  assert.equal(unseal(value, key), 'private-billing-key');
  assert.throws(() => unseal(value, randomBytes(32).toString('base64')));
});
test(
  'Applications: duplicate races, changed payload rejection, persistence and seven-day purge',
  { skip: !developmentOnly },
  async () => {
    const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL, max: 3 });
    const keys = [randomUUID(), randomUUID()];
    let ids: string[] = [];
    const input = {
      idempotencyKey: keys[0],
      studio: 'Integration test',
      contactType: 'email',
      contact: `${randomUUID()}@example.invalid`,
      screens: 'unknown',
      consent: true,
      consentVersion: POLICY_VERSION,
    };
    try {
      const [a, b] = await Promise.all([
        saveApplication(pool, input, 'test-only'),
        saveApplication(pool, input, 'test-only'),
      ]);
      ids.push(a.id);
      assert.equal(a.id, b.id);
      await assert.rejects(
        () => saveApplication(pool, { ...input, studio: 'Changed' }, 'test-only'),
        /변경/,
      );
      const c = await saveApplication(pool, { ...input, idempotencyKey: keys[1] }, 'test-only');
      ids.push(c.id);
      assert.equal(
        (await pool.query('SELECT duplicate_of FROM cb_applications WHERE id=$1', [c.id])).rows[0]
          .duplicate_of,
        a.id,
      );
      await assert.rejects(() => saveApplication(pool, { ...input, consent: false }, 'test-only'));
      await pool.query(
        "UPDATE cb_applications SET expires_at=now()-interval '1 second' WHERE id=ANY($1::uuid[])",
        [ids],
      );
      await purgeApplications(pool, ids);
      const rows = (
        await pool.query('SELECT * FROM cb_applications WHERE id=ANY($1::uuid[])', [ids])
      ).rows;
      assert(
        rows.every(
          (r) =>
            r.contact === null &&
            r.message === null &&
            r.studio === null &&
            r.contact_hash === null &&
            r.purged_at,
        ),
      );
    } finally {
      await pool.query('DELETE FROM cb_notifications WHERE resource_id=ANY($1::uuid[])', [ids]);
      await pool.query('DELETE FROM cb_applications WHERE idempotency_key=ANY($1::uuid[])', [keys]);
      await pool.end();
    }
  },
);
test(
  'Better Auth owns web auth: Google-only routes, session-required SMS, no phone sign-in, owner/admin isolation',
  { skip: !developmentOnly },
  async () => {
    process.env.ENABLE_PASSWORD_TEST_AUTH = 'true';
    let code = '';
    const runtime = createAuth(readConfig(), async (input) => {
      code = input.code;
    });
    delete process.env.ENABLE_PASSWORD_TEST_AUTH;
    const locked = createAuth();
    const testIP = '198.18.' + [...randomBytes(2)].join('.');
    const email = `sms-${randomUUID()}@example.invalid`,
      phone =
        '+8210999' +
        String(Math.floor(Math.random() * 1e7))
          .padStart(7, '0')
          .slice(0, 5);
    const request = (path: string, body?: object, cookie = '') =>
      new Request(runtime.config.baseURL + path, {
        method: body ? 'POST' : 'GET',
        headers: {
          origin: runtime.config.baseURL,
          'Content-Type': 'application/json',
          cookie,
          'x-cloudboard-client-ip': testIP,
        },
        body: body ? JSON.stringify(body) : undefined,
      });
    const call = (path: string, body?: object, cookie = '') =>
      runtime.auth.handler(request('/api/auth/' + path, body, cookie));
    let uid = '';
    try {
      const disabled = await locked.auth.handler(
        request('/api/auth/sign-up/email', { email, password: randomUUID(), name: 'Test' }),
      );
      assert.equal(disabled.status, 404);
      assert.equal(
        (await call('sign-in/social', { provider: 'apple', callbackURL: runtime.config.baseURL }))
          .status,
        400,
      );
      const callback = await call('callback/google');
      assert.equal(
        callback.status,
        302,
        'Google callback must pass the hook and reject missing OAuth state',
      );
      assert.equal((await call('phone-number/send-otp', { phoneNumber: phone })).status, 401);
      const signup = await call('sign-up/email', {
        email,
        password: randomUUID() + 'xY1!',
        name: 'SMS test',
      });
      assert.equal(signup.status, 200);
      uid = (await signup.json()).user.id;
      const cookie = signup.headers
        .getSetCookie()
        .map((c) => c.split(';')[0])
        .join('; ');
      let response = await handleAPI(
        request('/api/account/subscription', undefined, cookie),
        runtime,
      );
      assert.equal(response.status, 403);
      assert.equal(
        (await call('phone-number/send-otp', { phoneNumber: phone }, cookie)).status,
        200,
      );
      assert.match(code, /^\d{6}$/);
      assert.equal(
        (
          await call(
            'phone-number/verify',
            { phoneNumber: phone, code: code === '000000' ? '111111' : '000000' },
            cookie,
          )
        ).status,
        400,
      );
      response = await call(
        'phone-number/verify',
        { phoneNumber: phone, code, disableSession: false, updatePhoneNumber: false },
        cookie,
      );
      assert.equal(
        response.status,
        200,
        'Server forces attaching phone to current Better Auth session',
      );
      const verified = await (await call('get-session', undefined, cookie)).json();
      assert.equal(verified.user.id, uid);
      assert.equal(verified.user.phoneNumberVerified, true);
      assert.equal((await call('phone-number/verify', { phoneNumber: phone, code })).status, 401);
      assert.equal(
        (await call('sign-in/phone-number', { phoneNumber: phone, password: 'unavailable' }))
          .status,
        404,
      );
      assert.equal((await call('update-user', { phoneNumberVerified: true }, cookie)).status, 400);
      assert.equal((await call('update-user', { name: '  ' }, cookie)).status, 400);
      assert.equal((await call('update-user', { name: '새 이름' }, cookie)).status, 200);
      assert.equal(
        (await (await call('get-session', undefined, cookie)).json()).user.name,
        '새 이름',
      );
      const trial = await (
        await handleAPI(request('/api/account/subscription', undefined, cookie), runtime)
      ).json();
      assert.equal(trial.subscription.trialDaysRemaining, 14);
      assert.equal(trial.subscription.status, 'pending_connection');
      assert.equal(trial.linked, false);
      const saveStore = await handleAPI(
        request(
          '/api/account/store',
          {
            name: '테스트 매장',
            businessType: '그룹 PT',
            address: '서울 테스트 주소',
            phone: '02-1234-5678',
          },
          cookie,
        ),
        runtime,
      );
      assert.equal(saveStore.status, 200);
      assert.equal(
        (
          await handleAPI(
            request(
              '/api/account/store',
              {
                name: '다른 매장',
                businessType: '',
                address: '',
                phone: '',
                ownerId: 'other-user',
              },
              cookie,
            ),
            runtime,
          )
        ).status,
        400,
      );
      const profile = await (
        await handleAPI(request('/api/account/subscription', undefined, cookie), runtime)
      ).json();
      assert.equal(profile.store.name, '테스트 매장');
      assert.equal(profile.store.phone, '02-1234-5678');
      assert.equal(profile.subscription.trialEndsAt, trial.subscription.trialEndsAt);
      assert.equal(
        (await handleAPI(request('/api/admin/overview', undefined, cookie), runtime)).status,
        403,
      );
      assert.equal((await handleAPI(request('/api/account/billing'), runtime)).status, 401);
      await call('sign-out', {}, cookie);
      assert.equal(await (await call('get-session', undefined, cookie)).json(), null);
    } finally {
      if (uid) {
        await runtime.pool.query(
          'DELETE FROM cb_subscriptions WHERE store_id IN (SELECT id FROM cb_stores WHERE owner_id=$1)',
          [uid],
        );
        await runtime.pool.query('DELETE FROM cb_stores WHERE owner_id=$1', [uid]);
        await runtime.pool.query('DELETE FROM "user" WHERE id=$1', [uid]);
      }
      await runtime.pool.query('DELETE FROM verification WHERE identifier=$1', [phone]);
      await runtime.pool.query('DELETE FROM rate_limit WHERE key LIKE $1 OR key=$2', [
        '%' + testIP + '%',
        'sms-user:' + uid,
      ]);
      await runtime.pool.end();
      await locked.pool.end();
    }
  },
);
test(
  'Billing: trial activation, charge races, unknown recovery, refunds, ownership, cancellation and renewals',
  { skip: !developmentOnly },
  async () => {
    const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL, max: 5 }),
      gateway = new FakeToss(),
      key = randomBytes(32).toString('base64'),
      svc = new SubscriptionService(pool, gateway, 'test', key);
    const owners = [randomUUID(), randomUUID(), randomUUID()];
    let stores: string[] = [];
    try {
      for (const owner of owners) {
        await pool.query(
          'INSERT INTO "user"(id,name,email,email_verified,phone_number_verified) VALUES($1,$2,$3,true,true)',
          [owner, 'Billing test', `${owner}@example.invalid`],
        );
        await pool.query(
          'INSERT INTO cb_identities(user_id,firebase_uid,phone_verified_at) VALUES($1,$2,now())',
          [owner, `test-${owner}`],
        );
        stores.push((await svc.createStore(owner, 'Test studio')).id);
      }
      const a = await svc.owned(owners[0]!);
      await Promise.all([
        svc.createStore(owners[0]!, 'Again'),
        svc.createStore(owners[0]!, 'Again'),
      ]);
      const b = await svc.owned(owners[0]!);
      assert.equal(+a.trial_started_at, +b.trial_started_at);
      assert.equal(a.trial_started_at, null);
      assert.equal(a.trial_ends_at, null);
      assert.equal(
        (await svc.checkout(owners[0]!, POLICY_VERSION)).status,
        'awaiting_auth',
        'Existing trial accounts can subscribe immediately',
      );
      await pool.query(
        "UPDATE cb_subscriptions SET status='trialing',trial_started_at=now()-interval '15 days',trial_ends_at=now()-interval '1 day' WHERE store_id=ANY($1::uuid[])",
        [stores],
      );
      const [p, p2] = await Promise.all([
        svc.checkout(owners[0]!, POLICY_VERSION),
        svc.checkout(owners[0]!, POLICY_VERSION),
      ]);
      assert.equal(p.id, p2.id);
      const apiRuntime = {
        pool,
        config: readConfig(),
        auth: {
          api: { getSession: async () => ({ user: { id: owners[0], phoneNumberVerified: true } }) },
        },
      } as unknown as Parameters<typeof handleAPI>[1];
      const refundRequest = () =>
        handleAPI(
          new Request('http://localhost:3087/api/account/refunds', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ paymentId: p.id, reason: 'Integration refund request' }),
          }),
          apiRuntime,
          svc,
        );
      assert.equal((await refundRequest()).status, 409, 'Unpaid orders cannot request a refund');
      const s = await svc.owned(owners[0]!);
      await assert.rejects(() => svc.authorize(owners[1]!, p.id, 'auth', 'wrong-customer'), /일치/);
      await Promise.all([
        svc.authorize(owners[0]!, p.id, 'auth', s.customer_key),
        svc.authorize(owners[0]!, p.id, 'auth', s.customer_key),
      ]);
      assert.equal(gateway.charges, 1);
      assert.equal((await svc.payment(p.id)).status, 'succeeded');
      const requests = await Promise.all([refundRequest(), refundRequest()]);
      assert(requests.every((r) => r.status === 200));
      const requestIds = await Promise.all(requests.map(async (r) => (await r.json()).id));
      assert.equal(requestIds[0], requestIds[1], 'Repeated requests have one refund case');
      assert.equal(
        (
          await pool.query(
            'SELECT count(*)::int AS count FROM cb_notifications WHERE resource_id=$1',
            [requestIds[0]],
          )
        ).rows[0].count,
        1,
      );
      const billingResponse = await handleAPI(
        new Request('http://localhost:3087/api/account/billing'),
        apiRuntime,
        svc,
      );
      assert.equal(
        (await billingResponse.json()).payments.find((item: any) => item.id === p.id).refundStatus,
        'requested',
      );
      const active = await svc.owned(owners[0]!);
      await svc.cancel(owners[0]!, true);
      assert.equal(effectiveStatus(await svc.owned(owners[0]!)), 'canceling');
      assert.equal(+(await svc.owned(owners[0]!)).current_period_end, +active.current_period_end);
      const refunded = await gateway.refund((await svc.payment(p.id)).payment_key);
      await svc.applySnapshot(p.id, refunded);
      await svc.applySnapshot(p.id, gateway.payments.get(p.order_id)!);
      assert.equal((await svc.payment(p.id)).status, 'refunded');
      assert.equal(effectiveStatus(await svc.owned(owners[0]!)), 'expired');
      const fresh = await svc.checkout(owners[0]!, POLICY_VERSION);
      await svc.authorize(owners[0]!, fresh.id, 'auth', s.customer_key);
      assert.equal(
        (await svc.owned(owners[0]!)).cancel_at_period_end,
        false,
        'Resubscribe enables only newly consented renewals',
      );
      const lost = await svc.checkout(owners[1]!, POLICY_VERSION),
        owner2 = await svc.owned(owners[1]!);
      gateway.loseResponse = true;
      await svc.authorize(owners[1]!, lost.id, 'auth', owner2.customer_key);
      assert.equal((await svc.payment(lost.id)).status, 'uncertain');
      const charges = gateway.charges;
      await svc.process(lost.id);
      assert.equal((await svc.payment(lost.id)).status, 'succeeded');
      assert.equal(
        gateway.charges,
        charges,
        'Reconcile successful provider charge without repeating it',
      );
      await pool.query(
        "UPDATE cb_subscriptions SET current_period_end=now()-interval '1 minute' WHERE store_id=$1",
        [stores[1]],
      );
      gateway.decline = true;
      await svc.scheduleRenewals(stores);
      assert.equal(effectiveStatus(await svc.owned(owners[1]!)), 'past_due');
      const failed = await svc.owned(owners[1]!);
      assert.equal(+failed.grace_ends_at - +failed.current_period_end, 7 * DAY);
      gateway.decline = false;
      await svc.retry(owners[1]!);
      assert.equal(effectiveStatus(await svc.owned(owners[1]!)), 'active');
      const before = gateway.charges;
      await svc.cancel(owners[1]!, true);
      await pool.query(
        "UPDATE cb_subscriptions SET current_period_end=now()-interval '1 minute' WHERE store_id=$1",
        [stores[1]],
      );
      await svc.scheduleRenewals(stores);
      assert.equal(gateway.charges, before);
      assert.equal(effectiveStatus(await svc.owned(owners[1]!)), 'expired');
    } finally {
      await pool.query(
        'DELETE FROM cb_notifications WHERE resource_id IN (SELECT id FROM cb_payments WHERE store_id=ANY($1::uuid[])) OR resource_id IN (SELECT r.id FROM cb_refund_requests r JOIN cb_payments p ON p.id=r.payment_id WHERE p.store_id=ANY($1::uuid[]))',
        [stores],
      );
      for (const table of ['cb_webhook_events', 'cb_refund_requests'])
        await pool.query(
          `DELETE FROM ${table} WHERE payment_id IN(SELECT id FROM cb_payments WHERE store_id=ANY($1::uuid[]))`,
          [stores],
        );
      for (const table of [
        'cb_payments',
        'cb_card_changes',
        'cb_setup_orders',
        'cb_audit_events',
        'cb_subscriptions',
      ])
        await pool.query(`DELETE FROM ${table} WHERE store_id=ANY($1::uuid[])`, [stores]);
      await pool.query('DELETE FROM cb_stores WHERE id=ANY($1::uuid[])', [stores]);
      await pool.query('DELETE FROM "user" WHERE id=ANY($1::text[])', [owners]);
      await pool.end();
    }
  },
);

test('Free days use the server clock, handle expiry, and disappear after paid conversion', () => {
  const now = new Date('2026-09-18T00:00:00Z');
  const trial = { status: 'trialing', trial_ends_at: new Date(+now + 14 * DAY) };
  assert.equal(trialDaysRemaining(trial, now), 14);
  assert.equal(trialDaysRemaining(trial, new Date(+trial.trial_ends_at - 1)), 1);
  assert.equal(trialDaysRemaining(trial, trial.trial_ends_at), 0);
  assert.equal(trialDaysRemaining(trial, new Date(+trial.trial_ends_at + DAY)), 0);
  assert.equal(trialDaysRemaining({ ...trial, status: 'active' }, now), null);
  assert.equal(trialDaysRemaining({ status: 'pending_connection' }, now), null);
});
