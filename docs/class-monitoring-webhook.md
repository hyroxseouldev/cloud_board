# Production class monitoring (STA-191)

A separate `class-monitoring` Functions codebase forwards newly created records at
`users/{ownerId}/operations/events/{eventId}` in production's Singapore database.
The sender includes `event_id`, `title`, `message`, and `status`. The stable ID is
a SHA-256 of the production project and full source event path. The message
contains allowlisted event metadata; no email, full user document or lesson
content is forwarded. Center names are unknown; the account ID is the mapping key.

The 11 supported records cover start/end, command failures, reported playback
interruptions/recovery, connection failures/recovery, and device connection/end
signals. Start approval does not prove TV playback, end does not prove normal
completion, and one device's event does not establish every device's state.
Only events actually recorded by existing clients can be forwarded. There is no
heartbeat, backfill, additional class-start condition, or existing-data mutation.

The function uses its delivered snapshot and has no database client or database
IAM role. Its dedicated `class-monitoring` service account has Eventarc receiver,
this function's Cloud Run invoker, and this webhook secret's accessor only.
`CLASS_MONITORING_WEBHOOK_KEY` lives in production Secret Manager. Development
and normal Firebase configs exclude this codebase; the deploy preflight rejects
any nonproduction target. The emulator uses a demo namespace and loopback mock.

Delivery uses an 8-second timeout, two maximum instances, concurrency 10 and a
15-minute retry window measured from CloudEvent time. HTTP 408/429/5xx and network
failures retry; other 4xx are dropped with status-only logs. Receiver outages never
change class state. Delivery is at least once; Moring confirmed duplicate-ID
handling (first request 202, duplicate 200). Events may be lost after the retry
window; this is not continuous proof of playback or a complete incident detector.

## Notification status

`status` classifies the recorded event, not the overall class or webhook HTTP
response. It is derived from the event type, never copied from an input field.

| status | Event types |
| --- | --- |
| success | playback_started, playback_restored, connection_recovered |
| failure | command_failed, command_receipt_failed, playback_interrupted, connection_failed |
| info | playback_completed, device_online, device_offline, device_shutdown |

Normal app/tab closure can produce device_offline; completion does not distinguish
normal completion from a manual stop. These remain informational. Receipt failure
means missing confirmation, not proven playback failure. The existing completion
receipt false alarm (STA-192) is a separate client fix and is not suppressed here.

## Isolated server release

This codebase is released independently of app/rules/backend releases. It requires
a clean fixed main commit, an immutable `monitoring/v<package version>` tag and an
explicit reason. It deploys only `functions:class-monitoring`; do not use the normal
app `vX.Y.Z` tag for this isolated server change. Existing app release gates and
production receipts remain unchanged. This path implements the user's explicit
request for immediate server-only deployment without releasing unrelated apps.

```sh
npm ci --prefix functions-monitoring
npm test --prefix functions-monitoring
# Java 21 and Node 22; local .secret.local contains only a fake key:
# CLASS_MONITORING_WEBHOOK_KEY=local-demo-webhook-key
firebase emulators:exec --project demo-cloudboard-monitoring \
  --config firebase.monitoring.emulator.json --only functions,database \
  'node functions-monitoring/test/emulator-smoke.mjs'
node functions-monitoring/deploy.mjs monitoring/v1.0.1 MAIN_SHA 'STA-191 requested server-only deployment'
```

After deployment verify ACTIVE, exact event path/instance, dedicated runtime and
trigger identities, Secret version, and the service-specific invoker binding.
The receipt is `build/monitoring/release.json`. Local emulator verification covers
supported creates, unchanged source/device/session data, filtering and no backfill.
Unit tests cover payload limits, retry classification, timeouts and secret masking.
No production fixture is written. Actual class-event arrival remains a separate
observation after a class action occurs; setup messages are explicitly marked.

To stop only this integration:
`firebase functions:delete forwardClassOperation --region asia-southeast1 --project cloud-board-stationd`.
This leaves existing functions, rules and records intact. A restart requires the
same reviewed isolated deployment; it does not replay missed historical records.
