import { z } from 'zod';
import type pg from 'pg';
import { DAY, HttpError, POLICY_VERSION, fingerprint, hash, transaction } from './core.js';
const short = z.string().trim().max(100);
export const applicationInput = z
  .object({
    idempotencyKey: z.uuid(),
    studio: short.min(1, '매장명을 입력해 주세요.'),
    contactType: z.enum(['phone', 'email']),
    contact: z.string().trim().min(1).max(254),
    region: short.default(''),
    screens: z.enum(['1', '2', '3', '4+', 'unknown']),
    help: z.enum(['self', 'setup', 'unknown']).default('unknown'),
    message: z.string().trim().max(1500).default(''),
    consent: z.literal(true),
    consentVersion: z.literal(POLICY_VERSION),
    source: z.enum(['website', 'referral', 'outreach', 'demo']).default('website'),
    website: z.string().max(0).optional(),
  })
  .superRefine((d, ctx) => {
    if (d.contactType === 'email' && !z.email().safeParse(d.contact).success)
      ctx.addIssue({ code: 'custom', path: ['contact'], message: '이메일 주소를 확인해 주세요.' });
    if (d.contactType === 'phone' && !/^01[016789]\d{7,8}$/.test(d.contact.replace(/[-\s]/g, '')))
      ctx.addIssue({ code: 'custom', path: ['contact'], message: '휴대폰 번호를 확인해 주세요.' });
  });
export async function saveApplication(pool: pg.Pool, raw: unknown, secret: string) {
  const input = applicationInput.parse(raw);
  const contact =
    input.contactType === 'phone'
      ? input.contact.replace(/[-\s]/g, '')
      : input.contact.toLowerCase();
  const canonical = { ...input, contact };
  const payloadHash = hash(JSON.stringify(canonical));
  const contactHash = fingerprint(`${input.contactType}:${contact}`, secret);
  return transaction(pool, async (c) => {
    // A transaction-scoped lock serializes both network retries and repeat contacts.
    await c.query('SELECT pg_advisory_xact_lock(hashtext($1))', [input.idempotencyKey]);
    const previous = (
      await c.query(
        'SELECT id,payload_hash,created_at FROM cb_applications WHERE idempotency_key=$1',
        [input.idempotencyKey],
      )
    ).rows[0];
    if (previous) {
      if (previous.payload_hash !== payloadHash)
        throw new HttpError(
          409,
          'IDEMPOTENCY_CONFLICT',
          '입력 내용이 변경되었습니다. 새 신청으로 다시 제출해 주세요.',
        );
      return { id: previous.id, createdAt: previous.created_at };
    }
    await c.query('SELECT pg_advisory_xact_lock(hashtext($1))', [contactHash]);
    const duplicate = (
      await c.query(
        'SELECT id FROM cb_applications WHERE contact_hash=$1 AND purged_at IS NULL ORDER BY created_at DESC LIMIT 1',
        [contactHash],
      )
    ).rows[0];
    const row = (
      await c.query(
        `INSERT INTO cb_applications(idempotency_key,payload_hash,contact_hash,studio,contact_type,contact,region,screens,help,message,source,consent_version,expires_at,duplicate_of)
      VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14) RETURNING id,created_at`,
        [
          input.idempotencyKey,
          payloadHash,
          contactHash,
          input.studio,
          input.contactType,
          contact,
          input.region,
          input.screens,
          input.help,
          input.message,
          input.source,
          POLICY_VERSION,
          new Date(Date.now() + 7 * DAY),
          duplicate?.id || null,
        ],
      )
    ).rows[0];
    await c.query(
      "INSERT INTO cb_notifications(kind,resource_id) VALUES('application_received',$1)",
      [row.id],
    );
    return { id: row.id, createdAt: row.created_at };
  });
}
export async function purgeApplications(pool: pg.Pool, applicationIds?: string[]) {
  // Preserve only non-personal aggregate stage/source; free text and contact hashes go.
  return pool.query(
    `UPDATE cb_applications SET studio=NULL,contact_type=NULL,contact=NULL,contact_hash=NULL,region=NULL,screens=NULL,help=NULL,message=NULL,payload_hash='expired',purged_at=now() WHERE expires_at<=now() AND purged_at IS NULL AND ($1::uuid[] IS NULL OR id=ANY($1::uuid[]))`,
    [applicationIds ?? null],
  );
}
