ALTER TABLE "cb_payments" ALTER COLUMN "amount" SET DEFAULT 99000;--> statement-breakpoint
ALTER TABLE "cb_subscriptions" ADD COLUMN "monthly_price" integer DEFAULT 99000 NOT NULL;--> statement-breakpoint
ALTER TABLE "cb_subscriptions" ADD COLUMN "sync_attempts" integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE "cb_subscriptions" ADD COLUMN "sync_next_attempt_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "cb_subscriptions" ADD COLUMN "sync_error" text;--> statement-breakpoint
-- Preserve the amount of existing paying customers; new stores use 99,000 KRW.
UPDATE cb_subscriptions s SET monthly_price = p.amount
FROM (SELECT DISTINCT ON (store_id) store_id,amount FROM cb_payments
      WHERE status='succeeded' ORDER BY store_id,created_at DESC) p
WHERE p.store_id=s.store_id;
