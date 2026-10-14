CREATE TABLE "cb_applications" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"idempotency_key" uuid NOT NULL,
	"payload_hash" text NOT NULL,
	"contact_hash" text,
	"studio" text,
	"contact_type" text,
	"contact" text,
	"region" text,
	"screens" text,
	"help" text,
	"message" text,
	"source" text DEFAULT 'website' NOT NULL,
	"stage" text DEFAULT 'received' NOT NULL,
	"next_action_at" timestamp with time zone,
	"linked_store_id" uuid,
	"duplicate_of" uuid,
	"consent_version" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"purged_at" timestamp with time zone,
	CONSTRAINT "cb_applications_idempotency_key_unique" UNIQUE("idempotency_key")
);
--> statement-breakpoint
CREATE TABLE "cb_audit_events" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"actor_id" text NOT NULL,
	"store_id" uuid,
	"action" text NOT NULL,
	"data" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "cb_card_changes" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"store_id" uuid NOT NULL,
	"status" text DEFAULT 'pending' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "cb_identities" (
	"user_id" text PRIMARY KEY NOT NULL,
	"firebase_uid" text NOT NULL,
	"phone_verified_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "cb_identities_firebase_uid_unique" UNIQUE("firebase_uid")
);
--> statement-breakpoint
CREATE TABLE "cb_notifications" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"kind" text NOT NULL,
	"resource_id" uuid,
	"read_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "cb_payments" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"store_id" uuid NOT NULL,
	"cycle_key" text NOT NULL,
	"order_id" text NOT NULL,
	"kind" text DEFAULT 'subscription' NOT NULL,
	"status" text DEFAULT 'awaiting_auth' NOT NULL,
	"amount" integer DEFAULT 39000 NOT NULL,
	"mode" text NOT NULL,
	"payment_key" text,
	"period_start" timestamp with time zone NOT NULL,
	"period_end" timestamp with time zone NOT NULL,
	"auth_key_encrypted" text,
	"lease_until" timestamp with time zone,
	"attempts" integer DEFAULT 0 NOT NULL,
	"retry_count" integer DEFAULT 0 NOT NULL,
	"error_code" text,
	"receipt_url" text,
	"refunded_amount" integer DEFAULT 0 NOT NULL,
	"consent_version" text NOT NULL,
	"consented_at" timestamp with time zone NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "cb_payments_order_id_unique" UNIQUE("order_id"),
	CONSTRAINT "cb_payments_payment_key_unique" UNIQUE("payment_key")
);
--> statement-breakpoint
CREATE TABLE "cb_refund_requests" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"payment_id" uuid NOT NULL,
	"reason" text NOT NULL,
	"status" text DEFAULT 'requested' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "cb_refund_requests_payment_id_unique" UNIQUE("payment_id")
);
--> statement-breakpoint
CREATE TABLE "cb_setup_orders" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"store_id" uuid NOT NULL,
	"status" text DEFAULT 'consulting' NOT NULL,
	"amount" integer DEFAULT 149000 NOT NULL,
	"scope" text NOT NULL,
	"approved_at" timestamp with time zone,
	"completed_at" timestamp with time zone,
	"received_at" timestamp with time zone,
	"reference" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "cb_stores" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"owner_id" text NOT NULL,
	"name" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deletion_requested_at" timestamp with time zone,
	CONSTRAINT "cb_stores_owner_id_unique" UNIQUE("owner_id")
);
--> statement-breakpoint
CREATE TABLE "cb_subscriptions" (
	"store_id" uuid PRIMARY KEY NOT NULL,
	"status" text DEFAULT 'pending_connection' NOT NULL,
	"trial_started_at" timestamp with time zone,
	"trial_ends_at" timestamp with time zone,
	"current_period_start" timestamp with time zone,
	"current_period_end" timestamp with time zone,
	"anchor_day" integer,
	"grace_ends_at" timestamp with time zone,
	"cancel_at_period_end" boolean DEFAULT false NOT NULL,
	"customer_key" text NOT NULL,
	"billing_key_encrypted" text,
	"card_label" text,
	"billing_mode" text DEFAULT 'test' NOT NULL,
	"revision" integer DEFAULT 0 NOT NULL,
	"synced_revision" integer DEFAULT -1 NOT NULL,
	"display_limit" integer DEFAULT 3 NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "cb_subscriptions_customer_key_unique" UNIQUE("customer_key")
);
--> statement-breakpoint
CREATE TABLE "cb_webhook_events" (
	"id" text PRIMARY KEY NOT NULL,
	"payment_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "user" ADD COLUMN "phone_number" text;--> statement-breakpoint
ALTER TABLE "user" ADD COLUMN "phone_number_verified" boolean;--> statement-breakpoint
ALTER TABLE "cb_card_changes" ADD CONSTRAINT "cb_card_changes_store_id_cb_stores_id_fk" FOREIGN KEY ("store_id") REFERENCES "public"."cb_stores"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "cb_identities" ADD CONSTRAINT "cb_identities_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "cb_payments" ADD CONSTRAINT "cb_payments_store_id_cb_stores_id_fk" FOREIGN KEY ("store_id") REFERENCES "public"."cb_stores"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "cb_refund_requests" ADD CONSTRAINT "cb_refund_requests_payment_id_cb_payments_id_fk" FOREIGN KEY ("payment_id") REFERENCES "public"."cb_payments"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "cb_setup_orders" ADD CONSTRAINT "cb_setup_orders_store_id_cb_stores_id_fk" FOREIGN KEY ("store_id") REFERENCES "public"."cb_stores"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "cb_stores" ADD CONSTRAINT "cb_stores_owner_id_user_id_fk" FOREIGN KEY ("owner_id") REFERENCES "public"."user"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "cb_subscriptions" ADD CONSTRAINT "cb_subscriptions_store_id_cb_stores_id_fk" FOREIGN KEY ("store_id") REFERENCES "public"."cb_stores"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "cb_webhook_events" ADD CONSTRAINT "cb_webhook_events_payment_id_cb_payments_id_fk" FOREIGN KEY ("payment_id") REFERENCES "public"."cb_payments"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "cb_applications_contact_idx" ON "cb_applications" USING btree ("contact_hash");--> statement-breakpoint
CREATE INDEX "cb_applications_expiry_idx" ON "cb_applications" USING btree ("expires_at");--> statement-breakpoint
CREATE UNIQUE INDEX "cb_payments_cycle_idx" ON "cb_payments" USING btree ("store_id","cycle_key");--> statement-breakpoint
CREATE INDEX "cb_payments_reconcile_idx" ON "cb_payments" USING btree ("status","updated_at");--> statement-breakpoint
ALTER TABLE "user" ADD CONSTRAINT "user_phone_number_unique" UNIQUE("phone_number");