# Free 1 TV / Plus 3 TV · STA-152

Implementation candidate dated 2026-10-13. This document does not record deployment, store publication, or physical-device verification.

| Capability | Free | Plus | Premium / active premium trial |
| --- | --- | --- | --- |
| Price / duration | No card, no expiry | Existing store products and prices | Existing products and prices |
| Simultaneously active TVs | 1 | 3 | Unlimited |
| Saved classes | Existing unlimited policy | Existing unlimited policy | Existing unlimited policy |
| Reusable saved slides | Existing 3-slot policy | 3 | Unlimited |
| AI | Existing Premium gate | Existing Premium gate | Existing quota and provider checks |

The issue's proposed 5 classes / 1 reusable slide limits have not been approved. They are not silently activated. No existing class, reusable slide, registered display, or active class is deleted on downgrade.

## Server authority and transitions

`onboardingFree/{uid}` is server-owned. Explicit `startFree` checks the deletion lock, verified phone, and center ownership in a Firestore transaction. It is idempotent and independent of the premium trial. Verified native paid/trial history and server-owned web paid/trial history can enroll fallback Free. Missing, malformed, expired, or unconfirmed access is not interpreted as an active Free entitlement.

Free is the lowest-priority grant. Premium, assigned legacy access and Plus retain their own expiration and capabilities. Canceling auto-renewal does not shorten the paid period. Expiry/refund removes only the affected paid grant; the resolver falls back to another eligible grant or enrolled Free. Paid/trial history survives Free so a used trial cannot restart.

The finite wire timestamp `253402300799999` preserves the existing `validUntilMs` contract. Current UI describes this as no expiry and does not show year 9999. It does not confer access without the explicit server grant.

`appConfig/freePlan.enrollmentEnabled = false` stops new Free enrollment, including new automatic fallback enrollment. It does not revoke existing Free, paid rights, or a running class. Stop enrollment before a staged rollout if a closed pilot is required; absent configuration currently permits enrollment.

## TV registration, activation, and downgrade

The companion `cloudboard-landing` backend owns `cloudboardPairDisplay` and `cloudboardActivateDisplay`. Registration retains all TVs and automatically activates only available plan slots. A new inactive TV may replace only IDs explicitly selected by the coach through `replaceDeviceIds`; the backend validates the list and serializes concurrent changes. Unselected TVs remain unchanged. Switching a running class preserves status and timer position and changes its target IDs/revision.

RTDB rules enforce one target for Free and three for the new Plus projection. Historical explicit Plus-1 projections stay bounded until refreshed. Existing session targets remain controllable after a downgrade; the next new session uses the new cap. The active session is not restarted or resumed by display replacement.

## Web and native entitlement reconciliation

SQL subscription revisions and Firebase projection revisions are separate counters. The companion writer publishes its latest grant and server-confirmed `trialUsed` / `paidHistory` under `subscriptionEntitlements/{uid}.webGrant`. Once a Firebase billing account exists it never directly replaces the aggregate entitlement, RTDB projection, or profile. Older SQL grant revisions are ignored.

The existing entitlement trigger creates a billing account when needed for a verified web grant, then resolves native, web, trial, pilot and Free grants together. Web grant updates replace the old baseline, including expiration/cancellation, while keeping native purchases. The nested source grant stays in Firestore and is omitted from the RTDB projection. Scheduled billing reconciliation processes grant expiry even when SQL has no new revision.

## Rollout contract

1. Review both the Flutter/Firebase PR and companion backend PR together. Deploy neither client behavior nor Free enrollment on its own.
2. If a pilot is needed, set the new-enrollment switch false before rollout. Deploy the main resolver/trigger and rules, then the companion pairing/activation/source-grant writer. Only then release the updated client and enable enrollment for the agreed rollout.
3. Existing native billing accounts refresh through billing load/scheduled reconciliation. Existing web-only subscriptions need an authorized resync (`cloudboard-landing/functions/scripts/reconcile-display-policy.ts`, default dry-run with reviewed count on apply) to publish `webGrant`; merely deploying code does not backfill SQL records. Do not rewrite store product IDs, paid periods, purchase ownership, or existing user data to force the migration.
4. Old clients may display old Free wording or treat Plus-3 as legacy bounded access. Server caps remain authoritative. This candidate does not claim new UI/product support in retired 52/58/548 clients or silently change mandatory-update policy.
5. Validate real SMS, store purchase/restore, Free→Plus, Premium→Plus→Free, three concurrent TVs/fourth rejection, explicit replacement and physical-TV ACK before public rollout. User-observation and cost baselines remain separate release work.

## Automated evidence

`functions/test/free-plan.test.js`, `free-plan-emulator.mjs`, and `free-display-rules-emulator.mjs` cover grant priority, missing-access denial, verified enrollment, trial reuse prevention, web/native preservation, plan cap enforcement and ongoing-session downgrade behavior. Both emulator suites are registered in `tool/firebase/contract-suites.json`.

The companion backend adds policy unit tests and `display-policy.emulator.ts` / `web-grant.emulator.ts` for concurrent activation/registration, explicit paused-session replacement, source revision ordering and deletion locks. Production-widget tests cover the display selection dialog and first-use continuation. Captures are fixtures, not observations of real users or physical TVs.
