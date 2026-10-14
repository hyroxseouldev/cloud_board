import { HttpError } from './core.js';
export interface PaymentSnapshot {
  paymentKey: string;
  orderId: string;
  status: string;
  totalAmount: number;
  balanceAmount?: number;
  currency: string;
  method?: string;
  approvedAt?: string;
  receipt?: { url: string };
  cancels?: { cancelAmount: number }[];
}
export interface PaymentGateway {
  issue(
    authKey: string,
    customerKey: string,
    key: string,
  ): Promise<{ billingKey: string; card?: { number?: string; issuerCode?: string } }>;
  charge(
    billingKey: string,
    customerKey: string,
    orderId: string,
    amount: number,
    key: string,
    orderName?: string,
  ): Promise<PaymentSnapshot>;
  lookup(orderId: string): Promise<PaymentSnapshot | null>;
  refund(paymentKey: string, reason: string, key: string): Promise<PaymentSnapshot>;
}
export class GatewayError extends Error {
  constructor(
    public code: string,
    public uncertain: boolean,
  ) {
    super(code);
  }
}
export class TossGateway implements PaymentGateway {
  constructor(
    private secret: string,
    private mode: string,
  ) {
    if (!secret.startsWith(mode === 'live' ? 'live_sk_' : 'test_sk_'))
      throw new HttpError(503, 'KEY_MODE_MISMATCH', '결제 환경 설정을 확인해 주세요.');
  }
  private async call(path: string, body?: unknown, key?: string): Promise<any> {
    let res: Response;
    try {
      res = await fetch(`https://api.tosspayments.com/v1${path}`, {
        method: body ? 'POST' : 'GET',
        headers: {
          Authorization: `Basic ${Buffer.from(this.secret + ':').toString('base64')}`,
          'Content-Type': 'application/json',
          ...(key ? { 'Idempotency-Key': key } : {}),
        },
        body: body ? JSON.stringify(body) : undefined,
        signal: AbortSignal.timeout(65000),
      });
    } catch {
      throw new GatewayError('NETWORK_UNCERTAIN', true);
    }
    let value: any;
    try {
      value = await res.json();
    } catch {
      throw new GatewayError('INVALID_PROVIDER_RESPONSE', true);
    }
    if (!res.ok)
      throw new GatewayError(
        String(value.code || 'PROVIDER_ERROR'),
        res.status >= 500 || res.status === 409 || res.status === 429,
      );
    return value;
  }
  issue(authKey: string, customerKey: string, key: string) {
    return this.call('/billing/authorizations/issue', { authKey, customerKey }, key);
  }
  charge(
    billingKey: string,
    customerKey: string,
    orderId: string,
    amount: number,
    key: string,
    orderName = 'CloudBoard Pro 월 구독',
  ) {
    return this.call(
      `/billing/${encodeURIComponent(billingKey)}`,
      { customerKey, amount, orderId, orderName },
      key,
    );
  }
  async lookup(orderId: string) {
    try {
      return await this.call(`/payments/orders/${encodeURIComponent(orderId)}`);
    } catch (e) {
      if (e instanceof GatewayError && ['NOT_FOUND_PAYMENT', 'NOT_FOUND'].includes(e.code))
        return null;
      throw e;
    }
  }
  refund(paymentKey: string, reason: string, key: string) {
    return this.call(
      `/payments/${encodeURIComponent(paymentKey)}/cancel`,
      { cancelReason: reason },
      key,
    );
  }
}
