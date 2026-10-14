ALTER TABLE "cb_payments" ADD COLUMN "plan" text;--> statement-breakpoint
ALTER TABLE "cb_subscriptions" ADD COLUMN "pending_plan" text;