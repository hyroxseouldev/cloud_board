import {
  createCipheriv,
  createDecipheriv,
  createHash,
  createHmac,
  randomBytes,
  timingSafeEqual,
} from 'node:crypto';
import type pg from 'pg';
export class HttpError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string,
  ) {
    super(message);
  }
}
export const DAY = 86400000;
export const PRICE = 99000;
export const POLICY_VERSION = '2026-10-13-v5';
export function signCheckoutQuote(
  owner: string,
  start: Date,
  mode: string,
  secret: string,
  amount = PRICE,
  plan?: string,
) {
  const payload = Buffer.from(
    JSON.stringify({
      amount,
      plan,
      policy: POLICY_VERSION,
      owner,
      start: start.toISOString(),
      mode,
      expires: Date.now() + 15 * 60000,
    }),
  ).toString('base64url');
  return payload + '.' + createHmac('sha256', secret).update(payload).digest('base64url');
}
export function readCheckoutQuote(
  token: unknown,
  owner: string,
  mode: string,
  secret: string,
  amount = PRICE,
  plan?: string,
) {
  try {
    if (typeof token !== 'string' || token.length > 2000) throw new Error();
    const parts = token.split('.');
    if (parts.length !== 2) throw new Error();
    const [payload, signature] = parts;
    if (!payload || !signature) throw new Error();
    const expected = createHmac('sha256', secret).update(payload).digest(),
      actual = Buffer.from(signature, 'base64url');
    if (actual.length !== expected.length || !timingSafeEqual(actual, expected)) throw new Error();
    const value = JSON.parse(Buffer.from(payload, 'base64url').toString());
    if (
      value.owner !== owner ||
      value.mode !== mode ||
      value.amount !== amount ||
      value.plan !== plan ||
      value.policy !== POLICY_VERSION ||
      value.expires < Date.now()
    )
      throw new Error();
    const date = new Date(value.start);
    if (!Number.isFinite(date.getTime())) throw new Error();
    return date;
  } catch {
    throw new HttpError(
      409,
      'QUOTE_EXPIRED',
      '결제 안내가 만료되었습니다. 화면을 새로고침하고 이용 기간을 다시 확인해 주세요.',
    );
  }
}
export function hash(value: string) {
  return createHash('sha256').update(value).digest('hex');
}
export function fingerprint(value: string, secret: string) {
  return createHmac('sha256', secret).update(value).digest('hex');
}
export function seal(value: string, secret: string) {
  const key = Buffer.from(secret, 'base64');
  if (key.length !== 32) throw new Error('BILLING_ENCRYPTION_KEY must be 32-byte base64');
  const iv = randomBytes(12),
    cipher = createCipheriv('aes-256-gcm', key, iv);
  return Buffer.concat([
    iv,
    cipher.update(value, 'utf8'),
    cipher.final(),
    cipher.getAuthTag(),
  ]).toString('base64');
}
export function unseal(value: string, secret: string) {
  const data = Buffer.from(value, 'base64');
  const decipher = createDecipheriv(
    'aes-256-gcm',
    Buffer.from(secret, 'base64'),
    data.subarray(0, 12),
  );
  decipher.setAuthTag(data.subarray(-16));
  return Buffer.concat([decipher.update(data.subarray(12, -16)), decipher.final()]).toString(
    'utf8',
  );
}
// Calendar months in Korea, retaining the original billing day after short months.
export function nextBillingDate(
  start: Date,
  anchorDay = new Date(start.getTime() + 9 * 3600000).getUTCDate(),
): Date {
  const local = new Date(start.getTime() + 9 * 3600000);
  const y = local.getUTCFullYear(),
    m = local.getUTCMonth() + 1;
  const day = Math.min(anchorDay, new Date(Date.UTC(y, m + 1, 0)).getUTCDate());
  return new Date(
    Date.UTC(
      y,
      m,
      day,
      local.getUTCHours(),
      local.getUTCMinutes(),
      local.getUTCSeconds(),
      local.getUTCMilliseconds(),
    ) -
      9 * 3600000,
  );
}
export function effectiveStatus(s: any, now = new Date()) {
  if (s.status === 'pending_connection') return 'pending_connection';
  if (s.status === 'trialing')
    return s.trial_ends_at && new Date(s.trial_ends_at) > now ? 'trialing' : 'trial_expired';
  if (s.status === 'active')
    return s.current_period_end && new Date(s.current_period_end) > now
      ? s.cancel_at_period_end
        ? 'canceling'
        : 'active'
      : !s.cancel_at_period_end &&
          s.current_period_end &&
          new Date(s.current_period_end).getTime() + 7 * DAY > now.getTime()
        ? 'past_due'
        : 'expired';
  if (s.status === 'past_due')
    return s.grace_ends_at && new Date(s.grace_ends_at) > now ? 'past_due' : 'expired';
  return s.status;
}
export async function transaction<T>(pool: pg.Pool, work: (client: pg.PoolClient) => Promise<T>) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await work(client);
    await client.query('COMMIT');
    return result;
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
}
export function assertLiveReady() {
  const mode = process.env.BILLING_MODE || 'disabled';
  if (mode === 'disabled')
    throw new HttpError(503, 'BILLING_DISABLED', '구독 결제는 준비 중입니다.');
  if (mode === 'live' && process.env.LIVE_BILLING_APPROVED !== 'true')
    throw new HttpError(503, 'LIVE_NOT_APPROVED', '실결제 설정을 확인하고 있습니다.');
  return mode;
}

// Checkout is independent of app login, device pairing, and trial history.
export function canStartSubscription(s: Parameters<typeof effectiveStatus>[0]) {
  return ['pending_connection', 'trialing', 'trial_expired', 'expired'].includes(
    effectiveStatus(s),
  );
}

export function trialDaysRemaining(s: Parameters<typeof effectiveStatus>[0], now = new Date()) {
  if (!['trialing', 'trial_expired'].includes(s.status) || !s.trial_ends_at) return null;
  const end = new Date(s.trial_ends_at).getTime();
  return Number.isFinite(end) ? Math.max(0, Math.ceil((end - now.getTime()) / DAY)) : null;
}
