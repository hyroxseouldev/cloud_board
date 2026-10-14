import {
  pgTable,
  text,
  timestamp,
  integer,
  boolean,
  jsonb,
  uuid,
  uniqueIndex,
  index,
} from 'drizzle-orm/pg-core';
import { user } from './schema.js';
const time = (name: string) => timestamp(name, { withTimezone: true, mode: 'date' });
export const identities = pgTable('cb_identities', {
  userId: text('user_id')
    .primaryKey()
    .references(() => user.id, { onDelete: 'cascade' }),
  firebaseUid: text('firebase_uid').notNull().unique(),
  phoneVerifiedAt: time('phone_verified_at'),
  createdAt: time('created_at').defaultNow().notNull(),
});
export const applications = pgTable(
  'cb_applications',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    idempotencyKey: uuid('idempotency_key').notNull().unique(),
    payloadHash: text('payload_hash').notNull(),
    contactHash: text('contact_hash'),
    studio: text('studio'),
    contactType: text('contact_type'),
    contact: text('contact'),
    region: text('region'),
    screens: text('screens'),
    help: text('help'),
    message: text('message'),
    source: text('source').notNull().default('website'),
    stage: text('stage').notNull().default('received'),
    nextActionAt: time('next_action_at'),
    linkedStoreId: uuid('linked_store_id'),
    duplicateOf: uuid('duplicate_of'),
    consentVersion: text('consent_version').notNull(),
    createdAt: time('created_at').defaultNow().notNull(),
    expiresAt: time('expires_at').notNull(),
    purgedAt: time('purged_at'),
  },
  (t) => [
    index('cb_applications_contact_idx').on(t.contactHash),
    index('cb_applications_expiry_idx').on(t.expiresAt),
  ],
);
export const stores = pgTable('cb_stores', {
  id: uuid('id').primaryKey().defaultRandom(),
  ownerId: text('owner_id')
    .notNull()
    .unique()
    .references(() => user.id),
  name: text('name').notNull(),
  businessType: text('business_type'),
  address: text('address'),
  phone: text('phone'),
  createdAt: time('created_at').defaultNow().notNull(),
  deletionRequestedAt: time('deletion_requested_at'),
});
export const subscriptions = pgTable('cb_subscriptions', {
  storeId: uuid('store_id')
    .primaryKey()
    .references(() => stores.id),
  status: text('status').notNull().default('pending_connection'),
  trialStartedAt: time('trial_started_at'),
  trialEndsAt: time('trial_ends_at'),
  currentPeriodStart: time('current_period_start'),
  currentPeriodEnd: time('current_period_end'),
  anchorDay: integer('anchor_day'),
  graceEndsAt: time('grace_ends_at'),
  cancelAtPeriodEnd: boolean('cancel_at_period_end').notNull().default(false),
  customerKey: text('customer_key').notNull().unique(),
  billingKeyEncrypted: text('billing_key_encrypted'),
  cardLabel: text('card_label'),
  billingMode: text('billing_mode').notNull().default('test'),
  monthlyPrice: integer('monthly_price').notNull().default(99000),
  pendingPlan: text('pending_plan'),
  syncAttempts: integer('sync_attempts').notNull().default(0),
  syncNextAttemptAt: time('sync_next_attempt_at'),
  syncError: text('sync_error'),
  revision: integer('revision').notNull().default(0),
  syncedRevision: integer('synced_revision').notNull().default(-1),
  displayLimit: integer('display_limit').notNull().default(3),
  updatedAt: time('updated_at').defaultNow().notNull(),
});
export const payments = pgTable(
  'cb_payments',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    storeId: uuid('store_id')
      .notNull()
      .references(() => stores.id),
    cycleKey: text('cycle_key').notNull(),
    orderId: text('order_id').notNull().unique(),
    kind: text('kind').notNull().default('subscription'),
    plan: text('plan'),
    status: text('status').notNull().default('awaiting_auth'),
    amount: integer('amount').notNull().default(99000),
    mode: text('mode').notNull(),
    paymentKey: text('payment_key').unique(),
    periodStart: time('period_start').notNull(),
    periodEnd: time('period_end').notNull(),
    authKeyEncrypted: text('auth_key_encrypted'),
    leaseUntil: time('lease_until'),
    attempts: integer('attempts').notNull().default(0),
    retryCount: integer('retry_count').notNull().default(0),
    errorCode: text('error_code'),
    receiptUrl: text('receipt_url'),
    refundedAmount: integer('refunded_amount').notNull().default(0),
    consentVersion: text('consent_version').notNull(),
    consentedAt: time('consented_at').notNull(),
    createdAt: time('created_at').defaultNow().notNull(),
    updatedAt: time('updated_at').defaultNow().notNull(),
  },
  (t) => [
    uniqueIndex('cb_payments_cycle_idx').on(t.storeId, t.cycleKey),
    index('cb_payments_reconcile_idx').on(t.status, t.updatedAt),
  ],
);
export const cardChanges = pgTable('cb_card_changes', {
  id: uuid('id').primaryKey().defaultRandom(),
  storeId: uuid('store_id')
    .notNull()
    .references(() => stores.id),
  status: text('status').notNull().default('pending'),
  authKeyEncrypted: text('auth_key_encrypted'),
  mode: text('mode').notNull().default('test'),
  leaseUntil: time('lease_until'),
  createdAt: time('created_at').defaultNow().notNull(),
});
export const auditEvents = pgTable('cb_audit_events', {
  id: uuid('id').primaryKey().defaultRandom(),
  actorId: text('actor_id').notNull(),
  storeId: uuid('store_id'),
  action: text('action').notNull(),
  data: jsonb('data').notNull().default({}),
  createdAt: time('created_at').defaultNow().notNull(),
});
export const notifications = pgTable('cb_notifications', {
  id: uuid('id').primaryKey().defaultRandom(),
  kind: text('kind').notNull(),
  resourceId: uuid('resource_id'),
  readAt: time('read_at'),
  createdAt: time('created_at').defaultNow().notNull(),
});
export const webhookEvents = pgTable('cb_webhook_events', {
  id: text('id').primaryKey(),
  paymentId: uuid('payment_id')
    .notNull()
    .references(() => payments.id),
  createdAt: time('created_at').defaultNow().notNull(),
});
export const refundRequests = pgTable('cb_refund_requests', {
  id: uuid('id').primaryKey().defaultRandom(),
  paymentId: uuid('payment_id')
    .notNull()
    .unique()
    .references(() => payments.id),
  reason: text('reason').notNull(),
  status: text('status').notNull().default('requested'),
  createdAt: time('created_at').defaultNow().notNull(),
});
export const setupOrders = pgTable('cb_setup_orders', {
  id: uuid('id').primaryKey().defaultRandom(),
  storeId: uuid('store_id')
    .notNull()
    .references(() => stores.id),
  status: text('status').notNull().default('consulting'),
  amount: integer('amount').notNull().default(149000),
  scope: text('scope').notNull(),
  approvedAt: time('approved_at'),
  completedAt: time('completed_at'),
  receivedAt: time('received_at'),
  reference: text('reference'),
  createdAt: time('created_at').defaultNow().notNull(),
});
