ALTER TABLE "cb_stores" ADD COLUMN "business_type" text;--> statement-breakpoint
ALTER TABLE "cb_stores" ADD COLUMN "address" text;--> statement-breakpoint
ALTER TABLE "cb_stores" ADD COLUMN "phone" text;--> statement-breakpoint
-- Existing verified accounts use their original post-verification store creation date.
-- Preserve trials already started and all paid subscriptions; never restart a trial.
UPDATE cb_subscriptions AS s
SET status='trialing', trial_started_at=t.created_at,
    trial_ends_at=t.created_at+interval '14 days', revision=s.revision+1, updated_at=now()
FROM cb_stores AS t JOIN "user" AS u ON u.id=t.owner_id
WHERE s.store_id=t.id AND s.status='pending_connection' AND s.trial_started_at IS NULL
  AND u.phone_number_verified=true AND t.deletion_requested_at IS NULL;
