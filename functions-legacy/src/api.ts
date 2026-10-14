import {
  verifiedWebUser,
  recoverVerifiedAccount,
  readAppAccess,
} from './services/verified-access.js';
import { z } from 'zod';
import { randomUUID } from 'node:crypto';
import type { getAuthRuntime } from './auth.js';
import {
  HttpError,
  POLICY_VERSION,
  PRICE,
  DAY,
  effectiveStatus,
  canStartSubscription,
  trialDaysRemaining,
  hash,
  nextBillingDate,
  assertLiveReady,
  seal,
  transaction,
  signCheckoutQuote,
  readCheckoutQuote,
} from './services/core.js';
import { applicationInput, saveApplication, purgeApplications } from './services/applications.js';
import { SubscriptionService } from './services/subscriptions.js';
import { TossGateway, type PaymentGateway } from './services/toss.js';
import { syncEntitlements, syncAfterChange } from './services/sync.js';
import { linkFromWeb } from './services/onboarding.js';
import {
  catalogPlans,
  monthlyPrices,
  paidPlan,
  readWebSalesReady,
  requireWebSalesReady,
} from './services/plan-catalog.js';
import { applyPlanPolicy, planEntitlements } from './services/plan-entitlements.js';
import { firebaseServices } from './services/firebase.js';
import {
  accountAudienceBranding,
  publicAudienceBranding,
  readBrandProjection,
  readPublicAudienceBranding,
} from './services/audience-branding.js';
type Runtime = ReturnType<typeof getAuthRuntime>;
const uuid = z.uuid();
const json = (body: unknown, status = 200) =>
  Response.json(body, { status, headers: { 'Cache-Control': 'no-store' } });
const safePayment = (p: any) => ({
  id: p.id,
  status: p.status,
  amount: p.amount,
  plan: p.plan ?? null,
  mode: p.mode,
  periodStart: p.period_start,
  periodEnd: p.period_end,
  createdAt: p.created_at,
  receiptUrl: p.receipt_url,
  refundedAmount: p.refunded_amount,
  errorCode: p.error_code,
});
export function makeServices(runtime: Runtime, gateway?: PaymentGateway) {
  const mode = process.env.BILLING_MODE || 'disabled';
  const off: PaymentGateway = {
    issue: async () => {
      throw new Error('Disabled');
    },
    charge: async () => {
      throw new Error('Disabled');
    },
    lookup: async () => null,
    refund: async () => {
      throw new Error('Disabled');
    },
  };
  return new SubscriptionService(
    runtime.pool,
    gateway ||
      (mode === 'disabled'
        ? off
        : {
            issue: (...args) =>
              new TossGateway(process.env.TOSS_SECRET_KEY || '', mode).issue(...args),
            charge: (...args) =>
              new TossGateway(process.env.TOSS_SECRET_KEY || '', mode).charge(...args),
            lookup: (...args) =>
              new TossGateway(process.env.TOSS_SECRET_KEY || '', mode).lookup(...args),
            refund: (...args) =>
              new TossGateway(process.env.TOSS_SECRET_KEY || '', mode).refund(...args),
          }),
    mode,
    process.env.BILLING_ENCRYPTION_KEY || '',
  );
}
export async function handleAPI(
  request: Request,
  runtime: Runtime,
  service?: SubscriptionService,
): Promise<Response> {
  try {
    const url = new URL(request.url),
      path = url.pathname,
      method = request.method;
    const pool = runtime.pool;
    if (path === '/api/config' && method === 'GET') {
      const [planSalesReady, audienceBranding] = await Promise.all([
        readWebSalesReady(),
        readPublicAudienceBranding(),
      ]);
      return json({
        price: PRICE,
        plans: catalogPlans,
        planSalesReady,
        audienceBranding,
        setupPrice: 149000,
        applicationRetentionDays: 7,
        supportHours: '10:00–18:00',
        supportEmail: 'vividxxxxx@gmail.com',
        policyVersion: POLICY_VERSION,
        googleEnabled: !!process.env.GOOGLE_CLIENT_ID && !!process.env.GOOGLE_CLIENT_SECRET,
        smsEnabled:
          !!process.env.SOLAPI_API_KEY &&
          !!process.env.SOLAPI_API_SECRET &&
          !!process.env.SOLAPI_FROM,
        applicationEnabled: process.env.APPLICATIONS_ENABLED === 'true',
        billingMode: process.env.BILLING_MODE || 'disabled',
        tossClientKey: process.env.TOSS_CLIENT_KEY || null,
        localPreview: runtime.config.local,
      });
    }
    let body: any = {};
    if (!['GET', 'HEAD'].includes(method)) {
      try {
        body = await request.json();
      } catch {
        throw new HttpError(400, 'INVALID_JSON', '입력 내용을 확인해 주세요.');
      }
    }
    if (path === '/api/applications' && method === 'POST') {
      if (process.env.APPLICATIONS_ENABLED !== 'true')
        throw new HttpError(
          503,
          'APPLICATIONS_DISABLED',
          '접수 준비 중입니다. 이메일로 문의해 주세요.',
        );
      const ip = request.headers.get('x-cloudboard-client-ip') || 'unresolved';
      const bucket = `lead:${hash(ip)}:${Math.floor(Date.now() / 600000)}`;
      const limit = await pool.query(
        `INSERT INTO rate_limit(id,key,count,last_request) VALUES($1,$1,1,$2) ON CONFLICT(key) DO UPDATE SET count=rate_limit.count+1 RETURNING count`,
        [bucket, Date.now()],
      );
      if (limit.rows[0].count > 10)
        throw new HttpError(429, 'RATE_LIMIT', '잠시 후 다시 신청해 주세요.');
      const receipt = await saveApplication(pool, body, runtime.config.secret);
      return json(receipt, 201);
    }
    const svc = service || makeServices(runtime);
    if (path === '/api/webhooks/toss' && method === 'POST') {
      const orderId = body?.data?.orderId;
      if (typeof orderId !== 'string') return json({ received: true });
      const payment = (await pool.query('SELECT * FROM cb_payments WHERE order_id=$1', [orderId]))
        .rows[0];
      if (!payment || payment.mode !== svc.mode) return json({ received: true });
      // The payload is only a hint. Read the authoritative payment from Toss.
      const snapshot = await svc.gateway.lookup(orderId);
      if (snapshot) {
        await svc.applySnapshot(payment.id, snapshot);
        await syncAfterChange(pool, payment.store_id);
        await pool.query(
          'INSERT INTO cb_webhook_events(id,payment_id) VALUES($1,$2) ON CONFLICT DO NOTHING',
          [hash(JSON.stringify(snapshot)), payment.id],
        );
      }
      return json({ received: true });
    }
    const session = await runtime.auth.api.getSession({ headers: request.headers });
    if (!session) throw new HttpError(401, 'LOGIN_REQUIRED', '로그인이 필요합니다.');
    const owner = session.user.id;
    const admin = (process.env.ADMIN_USER_IDS || '').split(',').includes(owner);
    const verification = await verifiedWebUser(pool, owner);
    if (path === '/api/me' && method === 'GET')
      return json({
        user: {
          id: owner,
          name: session.user.name,
          email: session.user.email,
          phoneVerified: verification.verified,
          phoneVerificationAvailable: verification.available,
          phoneNumber: session.user.phoneNumber || null,
          createdAt: session.user.createdAt,
        },
        admin,
      });
    if (!verification.available)
      throw new HttpError(
        503,
        'VERIFICATION_UNAVAILABLE',
        '인증 기록을 확인하지 못했습니다. 잠시 후 다시 확인해 주세요.',
      );
    if (!verification.verified)
      throw new HttpError(403, 'PHONE_REQUIRED', '휴대폰 문자 인증을 완료해 주세요.');
    if (path === '/api/account/bootstrap' && method === 'POST') {
      const result = await recoverVerifiedAccount(
        pool,
        owner,
        svc.mode,
        z
          .string()
          .trim()
          .min(1)
          .max(100)
          .parse(body.name || 'CloudBoard'),
      );
      return json(result);
    }
    if (path === '/api/account/store' && method === 'POST') {
      const input = z
        .object({
          name: z.string().trim().min(1, '매장명을 입력해 주세요.').max(100),
          businessType: z.string().trim().max(50),
          address: z.string().trim().max(200),
          phone: z
            .string()
            .trim()
            .max(30)
            .refine(
              (v) =>
                !v ||
                (/^[+\d() -]+$/.test(v) &&
                  v.replace(/\D/g, '').length >= 8 &&
                  v.replace(/\D/g, '').length <= 15),
              '매장 연락처를 확인해 주세요.',
            ),
        })
        .strict()
        .parse(body);
      const result = await pool.query(
        `UPDATE cb_stores SET name=$2,business_type=$3,address=$4,phone=$5
         WHERE owner_id=$1 AND deletion_requested_at IS NULL RETURNING id`,
        [owner, input.name, input.businessType || null, input.address || null, input.phone || null],
      );
      if (!result.rowCount)
        throw new HttpError(403, 'STORE_UNAVAILABLE', '매장 정보를 수정할 수 없습니다.');
      return json({ updated: true });
    }
    if (path === '/api/account/link-app' && method === 'POST') {
      const link = await linkFromWeb(pool, owner);
      if ('storeId' in link) await syncAfterChange(pool, link.storeId);
      return json(link);
    }
    if (path === '/api/account/store-name' && method === 'POST') {
      const s = await svc.owned(owner);
      await pool.query('UPDATE cb_stores SET name=$2 WHERE id=$1', [
        s.store_id,
        z.string().trim().min(1).max(100).parse(body.name),
      ]);
      return json({ updated: true });
    }
    if (path === '/api/account/stores' && method === 'POST') {
      const store = await svc.createStore(
        owner,
        z.string().trim().min(1).max(100).parse(body.name),
      );
      await syncAfterChange(pool, store.id);
      return json(store, 201);
    }
    if (
      ['/api/account/subscription', '/api/account/onboarding'].includes(path) &&
      method === 'GET'
    ) {
      const identity = (
        await pool.query('SELECT firebase_uid FROM cb_identities WHERE user_id=$1', [owner])
      ).rows[0];
      let s;
      try {
        s = await svc.owned(owner);
      } catch (e) {
        if (e instanceof HttpError && e.code === 'STORE_REQUIRED')
          return json({ subscription: null, linked: !!identity });
        throw e;
      }
      const pending = (
        await pool.query(
          `SELECT id,status FROM cb_payments WHERE store_id=$1 AND status IN ('awaiting_auth','processing','uncertain') ORDER BY created_at DESC LIMIT 1`,
          [s.store_id],
        )
      ).rows[0];
      let planPolicy: Record<string, unknown> = {
        ...planEntitlements(s.display_limit),
        entitlementAvailable: false,
      };
      let audienceBranding = publicAudienceBranding(undefined);
      try {
        const { firestore } = firebaseServices();
        const [policy, previous, projection, deletion] = await Promise.all([
          firestore.doc('appConfig/planPolicy').get(),
          identity?.firebase_uid
            ? firestore.doc(`subscriptionEntitlements/${identity.firebase_uid}`).get()
            : Promise.resolve(null),
          identity?.firebase_uid
            ? readBrandProjection(identity.firebase_uid)
            : Promise.resolve(null),
          identity?.firebase_uid
            ? firestore.doc(`accountDeletions/${identity.firebase_uid}`).get()
            : Promise.resolve(null),
        ]);
        planPolicy = {
          ...applyPlanPolicy(planEntitlements(s.display_limit), previous?.data(), policy.data()),
          entitlementAvailable: true,
        };
        if (identity?.firebase_uid && !deletion?.exists)
          audienceBranding = accountAudienceBranding(
            identity.firebase_uid,
            previous?.data(),
            projection,
          );
      } catch {
        /* Keep billing management available while capability lookup fails. */
      }
      const appAccess = await readAppAccess(identity?.firebase_uid);
      return json({
        appAccess,
        linked: !!identity,
        audienceBranding,
        store: { name: s.name, businessType: s.business_type, address: s.address, phone: s.phone },
        subscription: {
          storeId: s.store_id,
          storeName: s.name,
          status: effectiveStatus(s),
          canSubscribe: canStartSubscription(s),
          trialStartedAt: s.trial_started_at,
          trialEndsAt: s.trial_ends_at,
          trialDaysRemaining: trialDaysRemaining(s),
          currentPeriodStart: s.current_period_start,
          currentPeriodEnd: s.current_period_end,
          graceEndsAt:
            s.grace_ends_at ||
            (effectiveStatus(s) === 'past_due'
              ? new Date(new Date(s.current_period_end).getTime() + 7 * DAY)
              : null),
          cancelAtPeriodEnd: s.cancel_at_period_end,
          cardLabel: s.card_label,
          price: s.monthly_price,
          pendingPlan: s.pending_plan ?? null,
          pendingPrice: s.pending_plan ? monthlyPrices[paidPlan(s.pending_plan)] : null,
          planChangeEffectiveAt: s.pending_plan ? s.current_period_end : null,
          canChangePlan:
            effectiveStatus(s) === 'active' &&
            !s.cancel_at_period_end &&
            new Date(s.current_period_end).getTime() > Date.now() &&
            !pending,
          syncPending: s.revision > s.synced_revision,
          syncEnabled: process.env.ENTITLEMENT_SYNC_ENABLED === 'true',
          appLinkEnabled: !runtime.config.local || process.env.FIREBASE_APP_LINK_ENABLED === 'true',
          ...planPolicy,
          billingMode: s.billing_mode,
        },
        pendingPayment: pending || null,
      });
    }
    if (path === '/api/checkout/quote' && method === 'GET') {
      await requireWebSalesReady();
      const plan = paidPlan(url.searchParams.get('plan'));
      const amount = monthlyPrices[plan];
      const s = await svc.owned(owner);
      if (!canStartSubscription(s))
        throw new HttpError(409, 'NOT_ELIGIBLE', '이미 이용 중인 구독을 확인해 주세요.');
      const pending = (
        await pool.query(
          "SELECT period_start,period_end FROM cb_payments WHERE store_id=$1 AND status='awaiting_auth' AND created_at>now()-interval '30 minutes' ORDER BY created_at DESC LIMIT 1",
          [s.store_id],
        )
      ).rows[0];
      const periodStart = pending ? new Date(pending.period_start) : new Date();
      return json({
        amount,
        plan,
        periodStart,
        periodEnd: nextBillingDate(periodStart),
        quoteToken: signCheckoutQuote(
          owner,
          periodStart,
          svc.mode,
          runtime.config.secret,
          amount,
          plan,
        ),
      });
    }
    if (path === '/api/checkout' && method === 'POST') {
      assertLiveReady();
      await requireWebSalesReady();
      const plan = paidPlan(body.plan);
      const amount = monthlyPrices[plan];
      if (body.consent !== true)
        throw new HttpError(400, 'CONSENT_REQUIRED', '월 자동 갱신 조건에 동의해 주세요.');
      const s = await svc.owned(owner);
      let payment = await svc.checkout(
        owner,
        body.consentVersion,
        readCheckoutQuote(body.quoteToken, owner, svc.mode, runtime.config.secret, amount, plan),
        amount,
        plan,
      );
      if (
        payment.status === 'awaiting_auth' &&
        s.billing_key_encrypted &&
        s.billing_mode === svc.mode
      ) {
        await pool.query(
          "UPDATE cb_payments SET status='uncertain' WHERE id=$1 AND status='awaiting_auth'",
          [payment.id],
        );
        payment = await svc.process(payment.id);
        await syncAfterChange(pool, s.store_id);
      }
      return json({
        ...safePayment(payment),
        customerKey: s.customer_key,
        clientKey: process.env.TOSS_CLIENT_KEY,
      });
    }
    if (path === '/api/checkout/authorize' && method === 'POST') {
      assertLiveReady();
      const d = z
        .object({
          id: uuid,
          authKey: z.string().min(1).max(300),
          customerKey: z.string().min(1).max(300),
        })
        .parse(body);
      const payment = await svc.authorize(owner, d.id, d.authKey, d.customerKey);
      await syncAfterChange(pool, payment.store_id);
      return json(safePayment(payment));
    }
    if (path.startsWith('/api/account/payments/') && method === 'GET') {
      const id = uuid.parse(path.split('/').pop()),
        s = await svc.owned(owner),
        p = await svc.payment(id);
      if (!p || p.store_id !== s.store_id)
        throw new HttpError(404, 'NOT_FOUND', '결제 내역을 찾을 수 없습니다.');
      return json(safePayment(p));
    }
    if (path === '/api/account/billing' && method === 'GET') {
      const s = await svc.owned(owner);
      const payments = (
        await pool.query(
          'SELECT p.*,r.status AS refund_status FROM cb_payments p LEFT JOIN cb_refund_requests r ON r.payment_id=p.id WHERE p.store_id=$1 ORDER BY p.created_at DESC LIMIT 100',
          [s.store_id],
        )
      ).rows;
      const setup = (
        await pool.query(
          'SELECT id,status,amount,scope,received_at FROM cb_setup_orders WHERE store_id=$1 ORDER BY created_at DESC',
          [s.store_id],
        )
      ).rows;
      return json({
        payments: payments.map((p) => ({
          ...safePayment(p),
          refundStatus: p.refund_status || null,
        })),
        setupOrders: setup,
      });
    }
    if (path === '/api/account/plan' && method === 'POST') {
      if (body.cancel === true) return json(await svc.cancelPlanChange(owner));
      await requireWebSalesReady();
      if (body.consent !== true)
        throw new HttpError(400, 'CONSENT_REQUIRED', '새 월 요금과 적용 시점에 동의해 주세요.');
      return json(await svc.changePlan(owner, body.plan, body.consentVersion));
    }
    if (path === '/api/account/cancel' && method === 'POST') {
      if (body.confirm !== true)
        throw new HttpError(400, 'CONFIRM_REQUIRED', '다음 결제 중단을 확인해 주세요.');
      const s = await svc.cancel(owner, true);
      await syncAfterChange(pool, s.store_id);
      return json({ canceled: true });
    }
    if (path === '/api/account/resume' && method === 'POST') {
      const s = await svc.cancel(owner, false);
      await syncAfterChange(pool, s.store_id);
      return json({ resumed: true });
    }
    if (path === '/api/account/retry' && method === 'POST') {
      assertLiveReady();
      const payment = await svc.retry(owner);
      await syncAfterChange(pool, payment.store_id);
      return json(safePayment(payment));
    }
    if (path === '/api/account/card' && method === 'POST') {
      assertLiveReady();
      const s = await svc.owned(owner),
        id = randomUUID();
      if (
        ['active', 'canceling', 'past_due'].includes(effectiveStatus(s)) &&
        s.billing_mode !== svc.mode
      )
        throw new HttpError(
          409,
          'CARD_MODE_MISMATCH',
          '현재 구독과 같은 결제 환경에서 등록해 주세요.',
        );
      await pool.query('INSERT INTO cb_card_changes(id,store_id,mode) VALUES($1,$2,$3)', [
        id,
        s.store_id,
        svc.mode,
      ]);
      return json({ id, customerKey: s.customer_key, clientKey: process.env.TOSS_CLIENT_KEY });
    }
    if (path.startsWith('/api/account/card/') && method === 'GET') {
      const id = uuid.parse(path.split('/').pop()),
        s = await svc.owned(owner);
      const row = (
        await pool.query('SELECT id,status FROM cb_card_changes WHERE id=$1 AND store_id=$2', [
          id,
          s.store_id,
        ])
      ).rows[0];
      if (!row) throw new HttpError(404, 'NOT_FOUND', '결제수단 변경 요청을 찾을 수 없습니다.');
      return json(row);
    }
    if (path === '/api/account/card/confirm' && method === 'POST') {
      assertLiveReady();
      const d = z
          .object({ id: uuid, authKey: z.string().min(1).max(300), customerKey: z.string() })
          .parse(body),
        s = await svc.owned(owner);
      if (s.customer_key !== d.customerKey)
        throw new HttpError(403, 'CUSTOMER_MISMATCH', '결제 계정이 일치하지 않습니다.');
      const result = await pool.query(
        `UPDATE cb_card_changes SET status='uncertain',auth_key_encrypted=COALESCE(auth_key_encrypted,$3) WHERE id=$1 AND store_id=$2 AND mode=$4 AND status='pending' AND created_at>now()-interval '30 minutes' RETURNING id`,
        [d.id, s.store_id, seal(d.authKey, svc.encryptionKey), svc.mode],
      );
      if (!result.rowCount) {
        const previous = (
          await pool.query(
            'SELECT status FROM cb_card_changes WHERE id=$1 AND store_id=$2 AND mode=$3',
            [d.id, s.store_id, svc.mode],
          )
        ).rows[0];
        if (!previous || previous.status === 'pending')
          throw new HttpError(
            409,
            'CARD_CHANGE_EXPIRED',
            '만료된 카드 변경 요청입니다. 다시 등록해 주세요.',
          );
      }
      await svc.processCard(d.id);
      return json({ updated: true });
    }
    if (path === '/api/account/refunds' && method === 'POST') {
      const d = z
          .object({ paymentId: uuid, reason: z.string().trim().min(1).max(500) })
          .parse(body),
        s = await svc.owned(owner),
        p = await svc.payment(d.paymentId);
      if (!p || p.store_id !== s.store_id)
        throw new HttpError(404, 'NOT_FOUND', '결제 내역을 찾을 수 없습니다.');
      if (!['succeeded', 'refunded'].includes(p.status))
        throw new HttpError(409, 'PAYMENT_NOT_FINAL', '완료된 결제만 환불 요청할 수 있습니다.');
      const result = await transaction(pool, async (c) => {
        const inserted = (
          await c.query(
            'INSERT INTO cb_refund_requests(payment_id,reason) VALUES($1,$2) ON CONFLICT(payment_id) DO NOTHING RETURNING id',
            [p.id, d.reason],
          )
        ).rows[0];
        if (inserted) {
          await c.query(
            "INSERT INTO cb_notifications(kind,resource_id) VALUES('refund_requested',$1)",
            [inserted.id],
          );
          return inserted;
        }
        return (await c.query('SELECT id FROM cb_refund_requests WHERE payment_id=$1', [p.id]))
          .rows[0];
      });
      return json(result);
    }
    if (path === '/api/account/deletion' && method === 'POST') {
      if (body.confirm !== true)
        throw new HttpError(400, 'CONFIRM_REQUIRED', '계정 삭제 요청을 확인해 주세요.');
      const s = await svc.owned(owner);
      await transaction(pool, async (c) => {
        await c.query('SELECT store_id FROM cb_subscriptions WHERE store_id=$1 FOR UPDATE', [
          s.store_id,
        ]);
        await c.query(
          'UPDATE cb_subscriptions SET cancel_at_period_end=true,billing_key_encrypted=NULL,revision=revision+1 WHERE store_id=$1',
          [s.store_id],
        );
        await c.query('UPDATE cb_stores SET deletion_requested_at=now() WHERE id=$1', [s.store_id]);
        await c.query(
          "INSERT INTO cb_notifications(kind,resource_id) VALUES('account_deletion_requested',$1)",
          [s.store_id],
        );
      });
      await syncAfterChange(pool, s.store_id);
      return json({ status: 'requested', renewalStopped: true });
    }
    if (path.startsWith('/api/admin/')) {
      if (!admin) throw new HttpError(403, 'ADMIN_REQUIRED', '관리자 권한이 필요합니다.');
      if (path === '/api/admin/overview' && method === 'GET') {
        await purgeApplications(pool);
        const [leads, subs, alerts, refunds, usage, setup, payments] = await Promise.all([
          pool.query('SELECT * FROM cb_applications ORDER BY created_at DESC LIMIT 200'),
          pool.query(
            'SELECT s.*,t.name,t.owner_id FROM cb_subscriptions s JOIN cb_stores t ON t.id=s.store_id ORDER BY t.created_at DESC LIMIT 200',
          ),
          pool.query(
            'SELECT * FROM cb_notifications WHERE read_at IS NULL ORDER BY created_at DESC LIMIT 100',
          ),
          pool.query(
            `SELECT r.*,p.amount,p.mode,p.store_id FROM cb_refund_requests r JOIN cb_payments p ON p.id=r.payment_id WHERE r.status='requested'`,
          ),
          pool.query(
            `SELECT DISTINCT ON(store_id) store_id,data FROM cb_audit_events WHERE action='usage_recorded' ORDER BY store_id,created_at DESC`,
          ),
          pool.query(
            'SELECT o.*,t.name FROM cb_setup_orders o JOIN cb_stores t ON t.id=o.store_id ORDER BY o.created_at DESC LIMIT 200',
          ),
          pool.query(
            'SELECT p.*,t.name FROM cb_payments p JOIN cb_stores t ON t.id=p.store_id ORDER BY p.created_at DESC LIMIT 200',
          ),
        ]);
        return json({
          applications: leads.rows,
          subscriptions: subs.rows.map((s) => ({
            storeId: s.store_id,
            name: s.name,
            ownerId: s.owner_id,
            status: effectiveStatus(s),
            trialStartedAt: s.trial_started_at,
            trialEndsAt: s.trial_ends_at,
            currentPeriodEnd: s.current_period_end,
            mode: s.billing_mode,
            price: s.monthly_price,
            syncPending: s.revision > s.synced_revision,
            syncAttempts: s.sync_attempts,
            syncError: s.sync_error,
            ...usage.rows.find((u) => u.store_id === s.store_id)?.data,
          })),
          notifications: alerts.rows,
          refunds: refunds.rows,
          setupOrders: setup.rows,
          payments: payments.rows.map((p) => ({
            ...safePayment(p),
            storeName: p.name,
            orderId: p.order_id,
            paymentKey: p.payment_key,
            kind: p.kind,
          })),
        });
      }
      if (path === '/api/admin/sync' && method === 'POST') {
        await syncEntitlements(pool, uuid.parse(body.storeId));
        return json({ requested: true });
      }
      if (path === '/api/admin/applications' && method === 'POST')
        return json(
          await saveApplication(
            pool,
            { ...body, source: body.source || 'outreach' },
            runtime.config.secret,
          ),
          201,
        );
      if (path === '/api/admin/application' && method === 'POST') {
        const d = z
          .object({
            id: uuid,
            stage: z.enum([
              'received',
              'contact',
              'demo',
              'device_check',
              'trial',
              'paid',
              'closed',
            ]),
            nextActionAt: z.iso.datetime().nullable(),
            linkedStoreId: uuid.nullable().optional(),
          })
          .parse(body);
        await pool.query(
          'UPDATE cb_applications SET stage=$2,next_action_at=$3,linked_store_id=COALESCE($4,linked_store_id) WHERE id=$1',
          [d.id, d.stage, d.nextActionAt, d.linkedStoreId || null],
        );
        return json({ updated: true });
      }
      if (path === '/api/admin/notifications/read' && method === 'POST') {
        await pool.query('UPDATE cb_notifications SET read_at=now() WHERE id=$1', [
          uuid.parse(body.id),
        ]);
        return json({ updated: true });
      }
      if (path === '/api/admin/usage' && method === 'POST') {
        const d = z
          .object({
            storeId: uuid,
            count: z.number().int().nonnegative().max(100000),
            lastClassAt: z.iso.datetime(),
          })
          .parse(body);
        if (new Date(d.lastClassAt) > new Date())
          throw new HttpError(400, 'INVALID_DATE', '실제 수업 시각을 입력해 주세요.');
        if (!(await pool.query('SELECT id FROM cb_stores WHERE id=$1', [d.storeId])).rowCount)
          throw new HttpError(404, 'NOT_FOUND', '매장을 찾을 수 없습니다.');
        await pool.query(
          'INSERT INTO cb_audit_events(actor_id,store_id,action,data) VALUES($1,$2,$3,$4)',
          [
            owner,
            d.storeId,
            'usage_recorded',
            JSON.stringify({ usageCount: d.count, lastClassAt: d.lastClassAt }),
          ],
        );
        return json({ updated: true });
      }
      if (path === '/api/admin/extend-trial' && method === 'POST') {
        const d = z
          .object({
            storeId: uuid,
            endsAt: z.iso.datetime(),
            reason: z.string().trim().min(1).max(500),
          })
          .parse(body);
        if (new Date(d.endsAt) <= new Date())
          throw new HttpError(400, 'INVALID_DATE', '미래 종료일을 지정해 주세요.');
        await transaction(pool, async (c) => {
          const r = await c.query(
            `UPDATE cb_subscriptions SET trial_ends_at=$2,status='trialing',revision=revision+1 WHERE store_id=$1 AND trial_started_at IS NOT NULL AND status IN ('trialing','expired') AND current_period_start IS NULL RETURNING store_id`,
            [d.storeId, d.endsAt],
          );
          if (!r.rowCount) throw new HttpError(409, 'INVALID_STATE', '체험 상태를 확인해 주세요.');
          await c.query(
            'INSERT INTO cb_audit_events(actor_id,store_id,action,data) VALUES($1,$2,$3,$4)',
            [
              owner,
              d.storeId,
              'extend_trial',
              JSON.stringify({ endsAt: d.endsAt, reason: d.reason }),
            ],
          );
        });
        await syncAfterChange(pool, d.storeId);
        return json({ updated: true });
      }
      if (path === '/api/admin/refund' && method === 'POST') {
        assertLiveReady();
        const id = uuid.parse(body.id),
          r = (await pool.query('SELECT * FROM cb_refund_requests WHERE id=$1', [id])).rows[0];
        if (!r) throw new HttpError(404, 'NOT_FOUND', '요청을 찾을 수 없습니다.');
        const p = await svc.payment(r.payment_id);
        if (!p.payment_key || p.mode !== svc.mode)
          throw new HttpError(409, 'PAYMENT_NOT_FINAL', '확정된 결제를 확인해 주세요.');
        const existing = await svc.gateway.lookup(p.order_id);
        const snapshot =
          existing?.status === 'CANCELED'
            ? existing
            : await svc.gateway.refund(p.payment_key, '고객 요청 환불', `${id}:refund`);
        await svc.applySnapshot(p.id, snapshot);
        await syncAfterChange(pool, p.store_id);
        await pool.query("UPDATE cb_refund_requests SET status='completed' WHERE id=$1", [id]);
        return json({ refunded: true });
      }
      if (path === '/api/admin/setup-orders' && method === 'POST') {
        const d = z
          .object({ storeId: uuid, scope: z.string().trim().min(1).max(1500) })
          .parse(body);
        return json(
          (
            await pool.query(
              'INSERT INTO cb_setup_orders(store_id,scope) VALUES($1,$2) RETURNING id',
              [d.storeId, d.scope],
            )
          ).rows[0],
          201,
        );
      }
      if (path === '/api/admin/setup-order' && method === 'POST') {
        const d = z
          .object({
            id: uuid,
            status: z.enum(['approved', 'completed', 'paid']),
            reference: z.string().max(150).optional(),
          })
          .parse(body);
        if (d.status === 'paid' && !d.reference)
          throw new HttpError(400, 'REFERENCE_REQUIRED', '실제 입금 확인 정보를 입력해 주세요.');
        const result = await pool.query(
          `UPDATE cb_setup_orders SET status=$2,approved_at=CASE WHEN $2='approved' THEN now() ELSE approved_at END,completed_at=CASE WHEN $2='completed' THEN now() ELSE completed_at END,received_at=CASE WHEN $2='paid' THEN now() ELSE received_at END,reference=COALESCE($3,reference) WHERE id=$1 AND (($2='approved' AND status='consulting') OR ($2='completed' AND status='approved') OR ($2='paid' AND status='completed'))`,
          [d.id, d.status, d.reference || null],
        );
        if (!result.rowCount)
          throw new HttpError(409, 'INVALID_STATE', '현재 주문 단계를 확인해 주세요.');
        return json({ updated: true });
      }
    }
    throw new HttpError(404, 'NOT_FOUND', '요청한 기능을 찾을 수 없습니다.');
  } catch (e) {
    if (e instanceof z.ZodError)
      return json(
        {
          error: 'VALIDATION',
          message: '입력 내용을 확인해 주세요.',
          fields: Object.fromEntries(e.issues.map((i) => [i.path.join('.'), i.message])),
        },
        400,
      );
    if (e instanceof HttpError) return json({ error: e.code, message: e.message }, e.status);
    console.error('Business API request failed');
    return json(
      {
        error: 'TEMPORARY_ERROR',
        message: '처리를 완료하지 못했습니다. 잠시 후 다시 시도해 주세요.',
      },
      503,
    );
  }
}
