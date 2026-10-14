ALTER TABLE "cb_card_changes" ADD COLUMN "auth_key_encrypted" text;--> statement-breakpoint
ALTER TABLE "cb_card_changes" ADD COLUMN "mode" text DEFAULT 'test' NOT NULL;--> statement-breakpoint
ALTER TABLE "cb_card_changes" ADD COLUMN "lease_until" timestamp with time zone;