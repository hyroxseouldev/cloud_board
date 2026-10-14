import { randomUUID } from 'node:crypto';
import type pg from 'pg';
import {
  DAY,
  POLICY_VERSION,
  HttpError,
  effectiveStatus,
  canStartSubscription,
  nextBillingDate,
  transaction,
  seal,
  unseal,
} from './core.js';
import { monthlyPrices, paidPlan, type PaidPlan } from './plan-catalog.js';
import { firebaseServices } from './firebase.js';
import { ensureAccountStore } from './account.js';
import { GatewayError, type PaymentGateway, type PaymentSnapshot } from './toss.js';
export class SubscriptionService {
  constructor(
    readonly pool: pg.Pool,
    readonly gateway: PaymentGateway,
    readonly mode: string,
    readonly encryptionKey: string,
  ) {}
  async owned(ownerId: string) {
    const s = (
      await this.pool.query(
        `SELECT s.*,t.name,t.business_type,t.address,t.phone,t.owner_id,t.deletion_requested_at FROM cb_subscriptions s JOIN cb_stores t ON t.id=s.store_id WHERE t.owner_id=$1`,
        [ownerId],
      )
    ).rows[0];
    if (!s) throw new HttpError(404, 'STORE_REQUIRED', '먼저 매장 정보를 등록해 주세요.');
    if (s.deletion_requested_at)
      throw new HttpError(403, 'ACCOUNT_DELETING', '삭제 처리 중인 계정입니다.');
    return s;
  }
  async createStore(ownerId: string, name: string) {
    return ensureAccountStore(this.pool, ownerId, name, this.mode);
  }
  async checkout(
    ownerId: string,
    consentVersion: string,
    quotedStart?: Date,
    quotedAmount?: number,
    selectedPlan?: PaidPlan,
  ) {
    if (consentVersion !== POLICY_VERSION)
      throw new HttpError(400, 'CONSENT_REQUIRED', '최신 월 자동 갱신 조건에 동의해 주세요.');
    const owned = await this.owned(ownerId);
    return transaction(this.pool, async (c) => {
      const s = (
        await c.query('SELECT * FROM cb_subscriptions WHERE store_id=$1 FOR UPDATE', [
          owned.store_id,
        ])
      ).rows[0];
      const amount = selectedPlan ? monthlyPrices[paidPlan(selectedPlan)] : s.monthly_price;
      if (quotedAmount !== undefined && quotedAmount !== amount)
        throw new HttpError(409, 'PRICE_CHANGED', '요금 안내를 새로 확인해 주세요.');
      if (!canStartSubscription(s))
        throw new HttpError(409, 'NOT_ELIGIBLE', '이미 이용 중인 구독을 확인해 주세요.');
      await c.query(
        "UPDATE cb_payments SET status='canceled' WHERE store_id=$1 AND status='awaiting_auth' AND created_at<now()-interval '30 minutes'",
        [s.store_id],
      );
      const pending = (
        await c.query(
          `SELECT * FROM cb_payments WHERE store_id=$1 AND status IN ('awaiting_auth','processing','uncertain') ORDER BY created_at DESC LIMIT 1`,
          [s.store_id],
        )
      ).rows[0];
      if (pending) {
        if (
          pending.status === 'awaiting_auth' &&
          (pending.amount !== amount ||
            (pending.plan ?? undefined) !== selectedPlan ||
            pending.mode !== this.mode ||
            pending.consent_version !== POLICY_VERSION)
        ) {
          await c.query("UPDATE cb_payments SET status='canceled' WHERE id=$1", [pending.id]);
        } else {
          if ((pending.plan ?? undefined) !== selectedPlan)
            throw new HttpError(
              409,
              'PAYMENT_PENDING',
              '이전 결제 상태를 확인한 뒤 요금제를 변경해 주세요.',
            );
          if (
            pending.status === 'awaiting_auth' &&
            quotedStart &&
            new Date(pending.period_start).getTime() !== quotedStart.getTime()
          )
            throw new HttpError(
              409,
              'QUOTE_CHANGED',
              '결제 안내가 변경되었습니다. 화면을 새로고침하고 이용 기간을 다시 확인해 주세요.',
            );
          return pending;
        }
      }
      const start = quotedStart || new Date(),
        id = randomUUID();
      const row = (
        await c.query(
          `INSERT INTO cb_payments(id,store_id,cycle_key,order_id,mode,period_start,period_end,consent_version,amount,plan,consented_at) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,now()) RETURNING *`,
          [
            id,
            s.store_id,
            `initial:${id}`,
            `cb_${id}`,
            this.mode,
            start,
            nextBillingDate(start),
            POLICY_VERSION,
            amount,
            selectedPlan ?? null,
          ],
        )
      ).rows[0];
      return row;
    });
  }
  async authorize(ownerId: string, id: string, authKey: string, customerKey: string) {
    const s = await this.owned(ownerId);
    if (customerKey !== s.customer_key)
      throw new HttpError(403, 'CUSTOMER_MISMATCH', '결제 계정이 일치하지 않습니다.');
    const p = (
      await this.pool.query('SELECT * FROM cb_payments WHERE id=$1 AND store_id=$2', [
        id,
        s.store_id,
      ])
    ).rows[0];
    if (!p) throw new HttpError(404, 'PAYMENT_NOT_FOUND', '결제 요청을 찾을 수 없습니다.');
    if (p.mode !== this.mode)
      throw new HttpError(409, 'MODE_MISMATCH', '결제 환경이 변경되었습니다.');
    if (p.status === 'awaiting_auth' && Date.now() - new Date(p.created_at).getTime() > 30 * 60000)
      throw new HttpError(
        409,
        'CHECKOUT_EXPIRED',
        '결제 요청이 만료되었습니다. 이용 기간을 확인하고 다시 시작해 주세요.',
      );
    if (p.status === 'awaiting_auth')
      await this.pool.query(
        `UPDATE cb_payments SET auth_key_encrypted=$2,status='uncertain',updated_at=now() WHERE id=$1 AND status='awaiting_auth'`,
        [id, seal(authKey, this.encryptionKey)],
      );
    return this.process(id);
  }
  async process(id: string) {
    const claimed = await transaction(this.pool, async (c) => {
      const p = (await c.query('SELECT * FROM cb_payments WHERE id=$1 FOR UPDATE', [id])).rows[0];
      if (
        !p ||
        ['succeeded', 'refunded', 'failed', 'canceled'].includes(p.status) ||
        p.status === 'awaiting_auth'
      )
        return null;
      if (p.lease_until && new Date(p.lease_until) > new Date()) return null;
      if (p.mode !== this.mode) return null;
      const s = (
        await c.query(
          'SELECT s.*,t.deletion_requested_at FROM cb_subscriptions s JOIN cb_stores t ON t.id=s.store_id WHERE s.store_id=$1 FOR UPDATE OF s',
          [p.store_id],
        )
      ).rows[0];
      if (
        s.deletion_requested_at ||
        (s.cancel_at_period_end && p.cycle_key.startsWith('renew:') && p.attempts === 0)
      ) {
        await c.query("UPDATE cb_payments SET status='canceled' WHERE id=$1", [id]);
        return null;
      }
      await c.query(
        `UPDATE cb_payments SET lease_until=now()+interval '3 minutes',status='processing',attempts=attempts+1,updated_at=now() WHERE id=$1`,
        [id],
      );
      return { p, s };
    });
    if (!claimed) return this.payment(id);
    const { p, s } = claimed;
    try {
      // Recover provider success before any retry, including crashes after charge.
      let result = p.attempts > 0 ? await this.gateway.lookup(p.order_id) : null;
      if (!result) {
        if (
          p.attempts > 0 &&
          p.retry_count === 0 &&
          Date.now() - new Date(p.created_at).getTime() > DAY
        ) {
          throw new GatewayError('MANUAL_RECONCILIATION_REQUIRED', true);
        }
        let key =
          s.billing_mode === p.mode && s.billing_key_encrypted
            ? unseal(s.billing_key_encrypted, this.encryptionKey)
            : null;
        if (p.auth_key_encrypted) {
          const issued = await this.gateway.issue(
            unseal(p.auth_key_encrypted, this.encryptionKey),
            s.customer_key,
            `${p.id}:issue`,
          );
          key = issued.billingKey;
          await this.pool.query(
            `UPDATE cb_subscriptions SET billing_key_encrypted=$2,card_label=$3,billing_mode=$4 WHERE store_id=$1`,
            [
              s.store_id,
              seal(key, this.encryptionKey),
              issued.card?.number ? `카드 ${issued.card.number.slice(-4)}` : '등록된 카드',
              this.mode,
            ],
          );
          await this.pool.query('UPDATE cb_payments SET auth_key_encrypted=NULL WHERE id=$1', [
            p.id,
          ]);
        }
        if (!key) throw new GatewayError('PAYMENT_METHOD_REQUIRED', false);
        const current = await this.owned(
          s.owner_id ||
            (await this.pool.query('SELECT owner_id FROM cb_stores WHERE id=$1', [s.store_id]))
              .rows[0].owner_id,
        );
        if (
          p.cycle_key.startsWith('renew:') &&
          (current.cancel_at_period_end ||
            Date.now() > new Date(p.period_start).getTime() + 7 * DAY)
        )
          throw new GatewayError('RENEWAL_STOPPED', false);
        if (this.mode === 'live') {
          const identity = (
            await this.pool.query(
              'SELECT i.firebase_uid FROM cb_stores t JOIN cb_identities i ON i.user_id=t.owner_id WHERE t.id=$1',
              [s.store_id],
            )
          ).rows[0];
          if (!identity) throw new GatewayError('APP_OWNER_REQUIRED', false);
          const firebase = firebaseServices();
          const record = await firebase.auth.getUser(identity.firebase_uid);
          if (
            record.disabled ||
            (await firebase.firestore.doc(`accountDeletions/${identity.firebase_uid}`).get()).exists
          )
            throw new GatewayError('ACCOUNT_DELETING', false);
        }
        result = await this.gateway.charge(
          key,
          s.customer_key,
          p.order_id,
          p.amount,
          `${p.id}:charge:${p.retry_count}`,
          p.plan === 'plus'
            ? 'CloudBoard Plus 월 구독'
            : p.plan === 'premium'
              ? 'CloudBoard Premium 월 구독'
              : undefined,
        );
      }
      await this.applySnapshot(p.id, result);
    } catch (e) {
      const error =
        e instanceof GatewayError ? e : new GatewayError('VERIFICATION_UNCERTAIN', true);
      await transaction(this.pool, async (c) => {
        await c.query(
          `UPDATE cb_payments SET status=$2,error_code=$3,lease_until=NULL,updated_at=now() WHERE id=$1 AND status NOT IN ('succeeded','refunded')`,
          [p.id, error.uncertain ? 'uncertain' : 'failed', error.code],
        );
        if (p.cycle_key.startsWith('renew:'))
          await c.query(
            `UPDATE cb_subscriptions SET status='past_due',grace_ends_at=COALESCE(grace_ends_at,current_period_end+interval '7 days'),revision=revision+1,updated_at=now() WHERE store_id=$1`,
            [s.store_id],
          );
        await c.query(
          `INSERT INTO cb_notifications(kind,resource_id) VALUES('payment_attention',$1)`,
          [p.id],
        );
      });
    }
    return this.payment(id);
  }
  async applySnapshot(id: string, r: PaymentSnapshot) {
    await transaction(this.pool, async (c) => {
      const p = (await c.query('SELECT * FROM cb_payments WHERE id=$1 FOR UPDATE', [id])).rows[0];
      if (
        !p ||
        r.orderId !== p.order_id ||
        r.totalAmount !== p.amount ||
        r.currency !== 'KRW' ||
        !r.paymentKey
      )
        throw new GatewayError('PAYMENT_VERIFICATION_FAILED', true);
      if (p.payment_key && p.payment_key !== r.paymentKey)
        throw new GatewayError('PAYMENT_KEY_MISMATCH', true);
      const s = (
        await c.query('SELECT * FROM cb_subscriptions WHERE store_id=$1 FOR UPDATE', [p.store_id])
      ).rows[0];
      const receipt = r.receipt?.url?.startsWith('https://') ? r.receipt.url : null;
      if (p.status === 'refunded') return;
      if (['CANCELED', 'PARTIAL_CANCELED'].includes(r.status)) {
        const refunded = (r.cancels || []).reduce((sum, x) => sum + x.cancelAmount, 0);
        if (refunded < p.refunded_amount) return;
        if (
          refunded > p.amount ||
          refunded < 0 ||
          (r.status === 'CANCELED' && refunded !== p.amount)
        )
          throw new GatewayError('REFUND_VERIFICATION_FAILED', true);
        await c.query(
          `UPDATE cb_payments SET status=$2,payment_key=$3,refunded_amount=$4,lease_until=NULL,auth_key_encrypted=NULL,updated_at=now() WHERE id=$1`,
          [id, r.status === 'CANCELED' ? 'refunded' : 'succeeded', r.paymentKey, refunded],
        );
        // Older refunds must not revoke a later paid cycle.
        if (
          r.status === 'CANCELED' &&
          s.current_period_end &&
          new Date(s.current_period_end).getTime() === new Date(p.period_end).getTime()
        )
          await c.query(
            `UPDATE cb_subscriptions SET status='expired',current_period_end=now(),cancel_at_period_end=true,revision=revision+1,updated_at=now() WHERE store_id=$1`,
            [p.store_id],
          );
        return;
      }
      if (r.status !== 'DONE') throw new GatewayError('PAYMENT_NOT_FINAL', true);
      if (p.status === 'refunded') return; // Never resurrect a refund from an older callback.
      const wasDone = p.status === 'succeeded';
      await c.query(
        `UPDATE cb_payments SET status='succeeded',payment_key=$2,receipt_url=$3,error_code=NULL,auth_key_encrypted=NULL,lease_until=NULL,updated_at=now() WHERE id=$1`,
        [id, r.paymentKey, receipt],
      );
      if (
        !wasDone &&
        (!s.current_period_end || new Date(s.current_period_end) < new Date(p.period_end))
      ) {
        const anchor = p.cycle_key.startsWith('renew:')
          ? s.anchor_day
          : new Date(new Date(p.period_start).getTime() + 9 * 3600000).getUTCDate();
        await c.query(
          `UPDATE cb_subscriptions SET status='active',current_period_start=$2,current_period_end=$3,anchor_day=$4,grace_ends_at=NULL,cancel_at_period_end=CASE WHEN $5 THEN false ELSE cancel_at_period_end END,
           monthly_price=CASE WHEN $6::text IS NOT NULL THEN $7 ELSE monthly_price END,
           display_limit=COALESCE($8::integer,display_limit),
           pending_plan=CASE WHEN $5 OR pending_plan=$6 THEN NULL ELSE pending_plan END,revision=revision+1,updated_at=now() WHERE store_id=$1`,
          [
            p.store_id,
            p.period_start,
            p.period_end,
            anchor,
            !p.cycle_key.startsWith('renew:'),
            p.plan ?? null,
            p.amount,
            p.plan === 'plus' ? 1 : p.plan === 'premium' ? -1 : null,
          ],
        );
      }
    });
  }
  async payment(id: string) {
    return (await this.pool.query('SELECT * FROM cb_payments WHERE id=$1', [id])).rows[0];
  }
  async processCard(id: string) {
    const change = (
      await this.pool.query(
        `UPDATE cb_card_changes SET status='processing',lease_until=now()+interval '3 minutes' WHERE id=$1 AND mode=$2 AND auth_key_encrypted IS NOT NULL AND status IN ('uncertain','processing') AND (lease_until IS NULL OR lease_until<now()) RETURNING *`,
        [id, this.mode],
      )
    ).rows[0];
    if (!change) return;
    try {
      const s = (
        await this.pool.query(
          'SELECT s.*,t.deletion_requested_at FROM cb_subscriptions s JOIN cb_stores t ON t.id=s.store_id WHERE store_id=$1',
          [change.store_id],
        )
      ).rows[0];
      if (s.deletion_requested_at) throw new GatewayError('ACCOUNT_DELETING', false);
      const issued = await this.gateway.issue(
        unseal(change.auth_key_encrypted, this.encryptionKey),
        s.customer_key,
        `${id}:card`,
      );
      await transaction(this.pool, async (c) => {
        // Deletion locks the store first as well; never restore a deleted account's key.
        const store = (
          await c.query('SELECT deletion_requested_at FROM cb_stores WHERE id=$1 FOR UPDATE', [
            s.store_id,
          ])
        ).rows[0];
        if (store.deletion_requested_at) throw new GatewayError('ACCOUNT_DELETING', false);
        const newer = await c.query(
          "SELECT id FROM cb_card_changes WHERE store_id=$1 AND status='complete' AND created_at>$2 LIMIT 1",
          [s.store_id, change.created_at],
        );
        if (newer.rowCount) {
          await c.query(
            "UPDATE cb_card_changes SET status='superseded',auth_key_encrypted=NULL,lease_until=NULL WHERE id=$1",
            [id],
          );
          return;
        }
        await c.query(
          'UPDATE cb_subscriptions SET billing_key_encrypted=$2,card_label=$3,billing_mode=$4 WHERE store_id=$1',
          [
            s.store_id,
            seal(issued.billingKey, this.encryptionKey),
            issued.card?.number ? `카드 ${issued.card.number.slice(-4)}` : '등록된 카드',
            this.mode,
          ],
        );
        await c.query(
          "UPDATE cb_card_changes SET status='complete',auth_key_encrypted=NULL,lease_until=NULL WHERE id=$1",
          [id],
        );
      });
    } catch (e) {
      const uncertain = !(e instanceof GatewayError) || e.uncertain;
      await this.pool.query(
        `UPDATE cb_card_changes SET status=$2,lease_until=now()+interval '1 minute',auth_key_encrypted=CASE WHEN $3 THEN auth_key_encrypted ELSE NULL END WHERE id=$1`,
        [id, uncertain ? 'uncertain' : 'failed', uncertain],
      );
    }
  }
  async reconcileCards() {
    await this.pool.query(
      "UPDATE cb_card_changes SET status='failed',auth_key_encrypted=NULL,lease_until=NULL WHERE mode=$1 AND status IN ('uncertain','processing') AND created_at<=now()-interval '1 day'",
      [this.mode],
    );
    const rows = (
      await this.pool.query(
        `SELECT id FROM cb_card_changes WHERE mode=$1 AND status IN ('uncertain','processing') AND (lease_until IS NULL OR lease_until<now()) AND created_at>now()-interval '1 day' LIMIT 5`,
        [this.mode],
      )
    ).rows;
    for (const row of rows) await this.processCard(row.id);
  }
  async cancel(ownerId: string, cancel: boolean) {
    const s = await this.owned(ownerId);
    if (!['active', 'canceling', 'past_due'].includes(effectiveStatus(s)))
      throw new HttpError(409, 'NO_ACTIVE_SUBSCRIPTION', '변경할 유료 구독이 없습니다.');
    await transaction(this.pool, async (c) => {
      await c.query('SELECT store_id FROM cb_subscriptions WHERE store_id=$1 FOR UPDATE', [
        s.store_id,
      ]);
      await c.query(
        'UPDATE cb_subscriptions SET cancel_at_period_end=$2,revision=revision+1,updated_at=now() WHERE store_id=$1',
        [s.store_id, cancel],
      );
      await c.query('INSERT INTO cb_audit_events(actor_id,store_id,action) VALUES($1,$2,$3)', [
        ownerId,
        s.store_id,
        cancel ? 'cancel_renewal' : 'resume_renewal',
      ]);
    });
    return this.owned(ownerId);
  }
  async cancelPlanChange(ownerId: string) {
    const owned = await this.owned(ownerId);
    return transaction(this.pool, async (c) => {
      const s = (
        await c.query('SELECT * FROM cb_subscriptions WHERE store_id=$1 FOR UPDATE', [
          owned.store_id,
        ])
      ).rows[0];
      const payment = (
        await c.query(
          `SELECT id FROM cb_payments WHERE store_id=$1 AND (
             status IN ('awaiting_auth','processing','uncertain') OR
             (status='failed' AND cycle_key LIKE 'renew:%' AND period_start=$2)
           ) LIMIT 1`,
          [s.store_id, s.current_period_end],
        )
      ).rows[0];
      if (payment)
        throw new HttpError(
          409,
          'PAYMENT_PENDING',
          '진행 중인 결제 상태를 확인한 뒤 예약을 취소해 주세요.',
        );
      await c.query(
        'UPDATE cb_subscriptions SET pending_plan=NULL,updated_at=now() WHERE store_id=$1',
        [s.store_id],
      );
      await c.query(
        "INSERT INTO cb_audit_events(actor_id,store_id,action) VALUES($1,$2,'cancel_plan_change')",
        [ownerId, s.store_id],
      );
      return { pendingPlan: null, pendingPrice: null, planChangeEffectiveAt: null };
    });
  }
  async changePlan(ownerId: string, value: unknown, consentVersion: string) {
    const plan = paidPlan(value);
    if (consentVersion !== POLICY_VERSION)
      throw new HttpError(
        400,
        'CONSENT_REQUIRED',
        '새 요금제의 월 자동 갱신 조건에 동의해 주세요.',
      );
    const owned = await this.owned(ownerId);
    return transaction(this.pool, async (c) => {
      const s = (
        await c.query('SELECT * FROM cb_subscriptions WHERE store_id=$1 FOR UPDATE', [
          owned.store_id,
        ])
      ).rows[0];
      if (
        effectiveStatus(s) !== 'active' ||
        s.cancel_at_period_end ||
        new Date(s.current_period_end).getTime() <= Date.now()
      )
        throw new HttpError(
          409,
          'PLAN_CHANGE_UNAVAILABLE',
          '이용 중인 구독과 다음 결제 일정을 먼저 확인해 주세요.',
        );
      const pending = (
        await c.query(
          "SELECT id FROM cb_payments WHERE store_id=$1 AND status IN ('awaiting_auth','processing','uncertain') LIMIT 1",
          [s.store_id],
        )
      ).rows[0];
      if (pending)
        throw new HttpError(409, 'PAYMENT_PENDING', '진행 중인 결제 상태를 먼저 확인해 주세요.');
      const currentPlan =
        s.display_limit === 1 ? 'plus' : s.display_limit === -1 ? 'premium' : null;
      const nextPlan =
        currentPlan === plan && s.monthly_price === monthlyPrices[plan] ? null : plan;
      await c.query(
        'UPDATE cb_subscriptions SET pending_plan=$2,updated_at=now() WHERE store_id=$1',
        [s.store_id, nextPlan],
      );
      await c.query(
        "INSERT INTO cb_audit_events(actor_id,store_id,action,data) VALUES($1,$2,'schedule_plan',$3::jsonb)",
        [
          ownerId,
          s.store_id,
          JSON.stringify({
            plan: nextPlan,
            amount: monthlyPrices[plan],
            effectiveAt: s.current_period_end,
            consentVersion,
          }),
        ],
      );
      return {
        pendingPlan: nextPlan,
        pendingPrice: nextPlan ? monthlyPrices[nextPlan] : null,
        planChangeEffectiveAt: nextPlan ? s.current_period_end : null,
      };
    });
  }
  async scheduleRenewals(storeIds?: string[]) {
    const due = (
      await this.pool.query(
        `SELECT * FROM cb_subscriptions WHERE status='active' AND current_period_end<=now() AND current_period_end>now()-interval '7 days' AND cancel_at_period_end=false AND billing_mode=$1 AND ($2::uuid[] IS NULL OR store_id=ANY($2::uuid[])) LIMIT 2`,
        [this.mode, storeIds ?? null],
      )
    ).rows;
    for (const candidate of due) {
      const inserted = await transaction(this.pool, async (c) => {
        const s = (
          await c.query('SELECT * FROM cb_subscriptions WHERE store_id=$1 FOR UPDATE', [
            candidate.store_id,
          ])
        ).rows[0];
        if (
          !s ||
          s.status !== 'active' ||
          s.cancel_at_period_end ||
          s.billing_mode !== this.mode ||
          new Date(s.current_period_end).getTime() > Date.now() ||
          new Date(s.current_period_end).getTime() <= Date.now() - 7 * DAY
        )
          return null;
        const id = randomUUID(),
          start = new Date(s.current_period_end),
          cycle = `renew:${start.toISOString()}`;
        // A committed cycle needs no new insert or row-lock wait while a worker settles it.
        if (
          (
            await c.query('SELECT id FROM cb_payments WHERE store_id=$1 AND cycle_key=$2', [
              s.store_id,
              cycle,
            ])
          ).rows[0]
        )
          return null;
        const plan = s.pending_plan
          ? paidPlan(s.pending_plan)
          : s.display_limit === 1
            ? 'plus'
            : s.display_limit === -1
              ? 'premium'
              : null;
        // Existing paid prices stay intact unless the owner explicitly schedules a change.
        const amount = s.pending_plan ? monthlyPrices[paidPlan(s.pending_plan)] : s.monthly_price;
        return (
          await c.query(
            `INSERT INTO cb_payments(id,store_id,cycle_key,order_id,status,mode,period_start,period_end,consent_version,amount,plan,consented_at)
           VALUES($1,$2,$3,$4,'uncertain',$5,$6,$7,$8,$9,$10,now()) ON CONFLICT(store_id,cycle_key) DO NOTHING RETURNING id`,
            [
              id,
              s.store_id,
              cycle,
              `cb_${id}`,
              this.mode,
              start,
              nextBillingDate(start, s.anchor_day),
              POLICY_VERSION,
              amount,
              plan,
            ],
          )
        ).rows[0];
      });
      if (inserted) await this.process(inserted.id);
    }
    const pending = (
      await this.pool.query(
        `SELECT id FROM cb_payments WHERE status IN ('uncertain','processing') AND mode=$1 AND updated_at<now()-interval '5 minutes' AND (lease_until IS NULL OR lease_until<now()) AND ($2::uuid[] IS NULL OR store_id=ANY($2::uuid[])) ORDER BY updated_at LIMIT 2`,
        [this.mode, storeIds ?? null],
      )
    ).rows;
    for (const p of pending) await this.process(p.id);
    await this.pool.query(
      `UPDATE cb_subscriptions SET status='expired',revision=revision+1,updated_at=now() WHERE ($1::uuid[] IS NULL OR store_id=ANY($1::uuid[])) AND ((status='active' AND cancel_at_period_end=true AND current_period_end<=now()) OR (status='past_due' AND grace_ends_at<=now()) OR (status='active' AND current_period_end<=now()-interval '7 days'))`,
      [storeIds ?? null],
    );
  }
  async retry(ownerId: string) {
    const s = await this.owned(ownerId);
    const p = (
      await this.pool.query(
        `SELECT * FROM cb_payments WHERE store_id=$1 AND cycle_key LIKE 'renew:%' AND status='failed' ORDER BY created_at DESC LIMIT 1`,
        [s.store_id],
      )
    ).rows[0];
    if (!p) throw new HttpError(409, 'NO_FAILED_PAYMENT', '재시도할 결제가 없습니다.');
    if (effectiveStatus(s) !== 'past_due')
      throw new HttpError(
        409,
        'RETRY_EXPIRED',
        '유예 기간이 끝났습니다. 새 구독의 이용 기간을 확인해 주세요.',
      );
    if (s.cancel_at_period_end)
      throw new HttpError(
        409,
        'RENEWAL_CANCELED',
        '갱신 중단 상태입니다. 먼저 구독 계속하기를 선택해 주세요.',
      );
    // After a definitive decline, retry with a new idempotency attempt but the
    // same orderId. The worker always checks for an existing successful payment first.
    await this.pool.query(
      `UPDATE cb_payments SET status='uncertain',lease_until=NULL,retry_count=retry_count+1 WHERE id=$1 AND status='failed'`,
      [p.id],
    );
    return this.process(p.id);
  }
}
