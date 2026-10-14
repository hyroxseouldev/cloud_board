import assert from 'node:assert/strict';
import { test } from 'node:test';
import { randomBytes, randomUUID } from 'node:crypto';
import { readFile, readdir } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';
import type pg from 'pg';
import { SubscriptionService } from '../src/services/subscriptions.js';
import { handleAPI } from '../src/api.js';
import { POLICY_VERSION } from '../src/services/core.js';
import { GatewayError, type PaymentGateway, type PaymentSnapshot } from '../src/services/toss.js';

// Real PostgreSQL SQL/migrations in an isolated in-memory engine. Its single
// connection is serialized; this does not claim multi-server lock validation.
async function database() {
  const db = new PGlite();
  const dir = new URL('../drizzle/', import.meta.url);
  for (const file of (await readdir(dir)).filter((name) => name.endsWith('.sql')).sort())
    await db.exec(await readFile(new URL(file, dir), 'utf8'));
  let tail = Promise.resolve();
  async function acquire() {
    const previous = tail;
    let release!: () => void;
    tail = new Promise<void>((resolve) => {
      release = resolve;
    });
    await previous;
    return release;
  }
  const query = async (sql: string, params?: unknown[]) => db.query(sql, params);
  const pool = {
    query: async (sql: string, params?: unknown[]) => {
      const release = await acquire();
      try {
        return await query(sql, params);
      } finally {
        release();
      }
    },
    connect: async () => {
      const release = await acquire();
      return { query, release };
    },
  } as unknown as pg.Pool;
  return { db, pool };
}
class Gateway implements PaymentGateway {
  charges = 0;
  decline = false;
  loseResponse = false;
  paid = new Map<string, PaymentSnapshot>();
  async issue() {
    return { billingKey: 'injected-test-key' };
  }
  async charge(_key: string, _customer: string, orderId: string, amount: number) {
    if (this.paid.has(orderId)) return this.paid.get(orderId)!;
    if (this.decline) throw new GatewayError('DECLINED', false);
    this.charges++;
    const payment = {
      orderId,
      totalAmount: amount,
      status: 'DONE',
      currency: 'KRW',
      paymentKey: randomUUID(),
    };
    this.paid.set(orderId, payment);
    if (this.loseResponse) {
      this.loseResponse = false;
      throw new GatewayError('NETWORK_UNCERTAIN', true);
    }
    return payment;
  }
  async lookup(orderId: string) {
    return this.paid.get(orderId) ?? null;
  }
  async refund(paymentKey: string) {
    const p = [...this.paid.values()].find((p) => p.paymentKey === paymentKey)!;
    return { ...p, status: 'CANCELED', cancels: [{ cancelAmount: p.totalAmount }] };
  }
}

test('selected paid plan is immutable in ledger, activates only on success, preserves trial and old periods', async () => {
  const { db, pool } = await database(),
    gateway = new Gateway();
  const svc = new SubscriptionService(pool, gateway, 'test', randomBytes(32).toString('base64'));
  const owner = randomUUID();
  try {
    await pool.query(
      'INSERT INTO "user"(id,name,email,email_verified,phone_number_verified) VALUES($1,$2,$3,true,true)',
      [owner, 'Local test', `${owner}@example.invalid`],
    );
    const store = await svc.createStore(owner, 'Local studio');
    const original = await svc.owned(owner);
    const [a, b] = await Promise.all([
      svc.checkout(owner, POLICY_VERSION, undefined, 49000, 'plus'),
      svc.checkout(owner, POLICY_VERSION, undefined, 49000, 'plus'),
    ]);
    await assert.rejects(
      svc.checkout(
        owner,
        POLICY_VERSION,
        new Date(+new Date(a.period_start) + 1000),
        49000,
        'plus',
      ),
      { code: 'QUOTE_CHANGED' },
    );
    assert.equal(
      (await svc.checkout(owner, POLICY_VERSION, new Date(a.period_start), 49000, 'plus')).id,
      a.id,
    );
    assert.equal(a.id, b.id);
    assert.equal(a.plan, 'plus');
    assert.equal(a.amount, 49000);
    assert.equal(
      (await svc.owned(owner)).display_limit,
      3,
      'quote/reservation cannot grant Plus before payment',
    );
    await assert.rejects(svc.checkout(owner, POLICY_VERSION, undefined, 1, 'plus'), {
      code: 'PRICE_CHANGED',
    });
    const premium = await svc.checkout(owner, POLICY_VERSION, undefined, 99000, 'premium');
    assert.notEqual(premium.id, a.id);
    assert.equal((await svc.payment(a.id)).status, 'canceled');
    const plus = await svc.checkout(owner, POLICY_VERSION, undefined, 49000, 'plus');
    gateway.loseResponse = true;
    await svc.authorize(owner, plus.id, 'auth', original.customer_key);
    assert.equal((await svc.payment(plus.id)).status, 'uncertain');
    await assert.rejects(svc.checkout(owner, POLICY_VERSION, undefined, 99000, 'premium'), {
      code: 'PAYMENT_PENDING',
    });
    await svc.process(plus.id);
    assert.equal(gateway.charges, 1);
    assert.equal((await svc.payment(plus.id)).status, 'succeeded');
    const active = await svc.owned(owner);
    assert.equal(active.display_limit, 1);
    assert.equal(active.monthly_price, 49000);
    assert.equal(+active.trial_ends_at, +original.trial_ends_at);
    await svc.changePlan(owner, 'premium', POLICY_VERSION);
    const reserved = await svc.owned(owner);
    assert.equal(reserved.pending_plan, 'premium');
    assert.equal(reserved.display_limit, 1);
    assert.equal(+reserved.current_period_end, +active.current_period_end);
    assert.equal(gateway.charges, 1);
    const runtime = {
      pool,
      config: { local: true },
      auth: {
        api: { getSession: async () => ({ user: { id: owner, phoneNumberVerified: true } }) },
      },
    } as unknown as Parameters<typeof handleAPI>[1];
    const cancelResponse = await handleAPI(
      new Request('http://localhost/api/account/plan', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ cancel: true }),
      }),
      runtime,
      svc,
    );
    assert.equal(
      cancelResponse.status,
      200,
      'cancel remains available without any sales readiness proof or new consent',
    );
    assert.equal(
      (await svc.owned(owner)).pending_plan,
      null,
      'reselecting current plan cancels its reservation',
    );
    await svc.changePlan(owner, 'premium', POLICY_VERSION);
    await svc.cancel(owner, true);
    await assert.rejects(svc.changePlan(owner, 'plus', POLICY_VERSION), {
      code: 'PLAN_CHANGE_UNAVAILABLE',
    });
    await svc.cancelPlanChange(owner);
    assert.equal((await svc.owned(owner)).pending_plan, null);
    assert.equal((await svc.owned(owner)).cancel_at_period_end, true);
    await svc.cancel(owner, false);
    await svc.changePlan(owner, 'premium', POLICY_VERSION);
    await pool.query(
      "UPDATE cb_subscriptions SET current_period_end=now()-interval '1 minute' WHERE store_id=$1",
      [store.id],
    );
    await Promise.all([svc.scheduleRenewals([store.id]), svc.scheduleRenewals([store.id])]);
    const upgraded = await svc.owned(owner);
    assert.equal(gateway.charges, 2);
    assert.equal(upgraded.display_limit, -1);
    assert.equal(upgraded.monthly_price, 99000);
    assert.equal(upgraded.pending_plan, null);
    await svc.changePlan(owner, 'plus', POLICY_VERSION);
    await pool.query(
      "UPDATE cb_subscriptions SET current_period_end=now()-interval '1 minute' WHERE store_id=$1",
      [store.id],
    );
    gateway.decline = true;
    await svc.scheduleRenewals([store.id]);
    assert.equal(
      (await svc.owned(owner)).display_limit,
      -1,
      'failed downgrade charge cannot apply new paid capabilities',
    );
    await assert.rejects(svc.cancelPlanChange(owner), { code: 'PAYMENT_PENDING' });
    assert.equal((await svc.owned(owner)).pending_plan, 'plus');
    await svc.cancel(owner, true);
    await assert.rejects(svc.cancelPlanChange(owner), { code: 'PAYMENT_PENDING' });
    await assert.rejects(svc.retry(owner), { code: 'RENEWAL_CANCELED' });
    await svc.cancel(owner, false);
    gateway.decline = false;
    await svc.retry(owner);
    const downgraded = await svc.owned(owner);
    assert.equal(downgraded.display_limit, 1);
    assert.equal(downgraded.monthly_price, 49000);
    await svc.applySnapshot(
      plus.id,
      await gateway.refund((await svc.payment(plus.id)).payment_key),
    );
    assert.equal(
      +(await svc.owned(owner)).current_period_end,
      +downgraded.current_period_end,
      'old-cycle refund never revokes a later cycle',
    );
    assert.equal((await svc.payment(plus.id)).amount, 49000);
    assert.equal((await svc.payment(plus.id)).plan, 'plus');
    const latest = (
      await pool.query(
        "SELECT * FROM cb_payments WHERE store_id=$1 AND status='succeeded' ORDER BY period_end DESC LIMIT 1",
        [store.id],
      )
    ).rows[0];
    await svc.applySnapshot(latest.id, await gateway.refund(latest.payment_key));
    assert.equal((await svc.owned(owner)).status, 'expired');
    await svc.applySnapshot(latest.id, gateway.paid.get(latest.order_id)!);
    assert.equal((await svc.owned(owner)).status, 'expired', 'late DONE cannot resurrect refund');
    assert.equal(+(await svc.owned(owner)).trial_ends_at, +original.trial_ends_at);
  } finally {
    await db.close();
  }
});
