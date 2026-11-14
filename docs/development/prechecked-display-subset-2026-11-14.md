# Prechecked display cohort and selected Start

Baseline: `origin/develop` `9c7dc4360d2ffe657e0af1317381f9207dde0a9e` (reported client: Dev TestFlight 2.2.0(3)). This change adds development/demo server support for a locally selected subset. It does not deploy functions, change account enrollment, change Firebase rules, or change operation/history data. The app owner separately implements the preparation page and proof checks.

## Wire contract

Prepare once with an explicit, nonempty eligible cohort **C**. Checkboxes only change local selection **S**. Start requires `S` nonempty, unique, and a subset of `C`; it does not prepare, cancel or reserve again. Empty targets have existing all-display/controller-only meanings elsewhere and must not be used to represent deselect-all in this flow.

Every admission response now advertises `supportsTargetSubset: true`. Old responses omit it; clients default to false. `targetDeviceIds`, `clientFingerprint`, `manifestHash`, `sessionId`, `epoch` and the media manifest continue to identify the original preparation cohort. An accepted selected commit additionally returns `selectedTargetDeviceIds`. The returned `session.targetDeviceIds` must exactly match the committed selection.

```json
{
  "schemaVersion": 1,
  "action": "commitSelected",
  "requestId": "commit_ADMISSION_ID",
  "admissionId": "ADMISSION_ID",
  "sessionId": "PREPARED_SESSION_ID",
  "epoch": 1,
  "manifestHash": "ORIGINAL_SERVER_MANIFEST_HASH",
  "selectedTargetDeviceIds": ["display-a"],
  "start": {
    "stepIndex": 0,
    "durationMs": 10000,
    "briefing": false,
    "scheduled": false,
    "scheduledAtMs": null,
    "updatedByDeviceId": "ORIGINAL_CONTROLLER_DEVICE_ID"
  }
}
```

A distinct action is required: the old `commit` handler ignores additional target fields and publishes all admission targets. The baseline action allowlist rejects `commitSelected` before database access. Clients must never fall back from a subset request to old `commit`. Old `commit` is usable only for an unchanged full cohort and retains its existing behavior, including old controller-only admissions.

Selected IDs are sorted on the server; duplicates and invalid IDs are rejected. Same selection and start converge through the existing durable commit request and `get`. Different selections or starts after `committing`/`active` return `idempotency_conflict`, even under another request ID. A legacy full-cohort retry against an already selected subset also conflicts. The original admission target list is never overwritten.

## Proof and authorization

The agreed app proof adds optional immutable `preparedTargetDeviceIds: C`. Its existing `clientFingerprint` is `preparationFingerprint(effectiveWorkout, C)`, not the selected-target fingerprint. Start must check the exact current request/session/revision/hash and cohort equality, latest effective workout/preferences, `S ⊆ C`, and current selected pairing/protocol/presence/health/receipts. Proofs without a cohort retain exact-target behavior. A checkbox is not readiness evidence.

The enrolled server owns the admission and immutable workout/media manifest. Before first acceptance it re-resolves selected display ownership, display UID/pairing binding, revocations, protocol and media metadata. It compares selected bindings to the frozen preparation bindings before restoring the original cohort fields for the full manifest-hash comparison. This preserves media/brand/workout binding without requiring removed, offline or failed *unselected* displays to remain eligible.

Only selected receipts are required, with the original admission/session/epoch/manifest, image count, audio success and timestamp window. Selected displays must still be `auto`, online and fresh under their connection-scoped heartbeat policy, with no current preparation health failure. Legacy `commit` does not gain a new presence requirement. First acceptance retains preparation expiry, current entitlement, usage config/inventory, active admission slot, daily/monthly quota and reservation rebinding checks. A previously accepted commit may recover after expiry; an active class is not stopped by preparation expiry, presence loss, or later quota/entitlement expiry.

The RTDB publication transaction checks selected receipts and frozen device bindings again, preserves the active-session exclusion, and publishes **S** only. A selected outbox record uses `phase: commitSelected`; old outbox code rejects that unknown phase rather than publishing C. `usageGate` and active-session schemas remain unchanged. No request/ACK or operation schema migration is needed.

## Reservation and media behavior

Preparation still reserves remote asset bytes multiplied by `(C.length + 1)` using existing accounting. The extra controller allowance is a reservation, not an automatic controller download. This patch neither downloads media at Start nor refunds prechecks because a display was deselected. Served/unknown bytes remain charged; unused reservations remain conservative until existing cancellation/completion handling releases them. Start retains current-period rebinding and grant-expiry checks. This can reject a large cohort even if a smaller selected set would have fitted; that is the cost of prechecking the entire cohort, not permission to bypass quota.

During `preparing`, the cohort can fetch preparation media. Once selection is accepted (`committing`/`active`), only selected displays can use admission media or protected playback capacity; the owner/controller retains its existing authorization. Existing records without `selectedTargetDeviceIds` use their original cohort. Membership is rechecked in the transfer transaction to fence a concurrent commit, and the unchanged gateway rechecks context on lease issue, HEAD, GET and after Storage I/O. Previously issued preparation leases cannot give excluded displays active playback access.

Existing controller automatic-download suppression remains an app concern. The server's reservation does not cause a download. TV preparation stays on the existing standby/media path; ongoing class controls, playback snapshots, retention, operations and history are unchanged.

## Minimal code and deployment boundary

| File | Responsibility |
| --- | --- |
| `functions/src/class-admission.js` | Additive action/capability, subset validation and frozen commit selection, selected receipt/presence/binding validation, idempotency and outbox publication |
| `functions/src/image-usage-ledger.js` | Selected participant authorization after commit, repeated membership check before transfer reservation |
| `functions/test/class-admission-subset.test.js` | Focused opt-in local Firestore/RTDB/Storage and gateway integration |

`functions/src/media-gateway.js`, `functions/src/index.js`, RTDB/Firestore/Storage rules, packages and Flutter are unchanged by this server patch. New fields are additive internal admission fields; existing data is not rewritten.

**A later approved development release must treat these four function targets as one compatibility unit:**

1. `account-deletion:cloudboardMediaLease`
2. `account-deletion:cloudboardMedia`
3. `account-deletion:retryImageUsageOutbox`
4. `account-deletion:cloudboardClassAdmission`

Update and verify media authorization and outbox consumers before exposing the new admission capability; the app follows the complete server release. Deploying only the callable is insufficient because Cloud Functions revisions carry their own copies of the shared modules. The distinct outbox phase protects against an old outbox publisher, but old media functions still lack selected membership. Do not roll those consumers back while new subset admissions are active. No production deployment is required for the non-enrolled legacy RTDB path, and these usage endpoints remain development/demo-only.

Actual development account enrollment and the currently running server revision are **unverified** here. Source presence and `supportsTargetSubset` design are not proof of deployment. Root owns release approval and fixed-SHA rollout; this task performs no deployment.

## Focused verification

Run only against local demo emulators, using Node 22 and Java 21:

```sh
USAGE_SUBSET_TEST=1 firebase emulators:exec --only firestore,database,storage \
  --project demo-cloudboard-subset --config firebase.image-usage-emulator.json \
  'node --test functions/test/class-admission-subset.test.js'
node --test functions/test/media-gateway.test.js functions/test/image-usage-policy.test.js
```

The subset suite covers selected ready/unselected failed or removed; immutable preparation and conservative reservation; old all-target commit; empty/duplicate/foreign/superset/stale proofs; current selected receipt, heartbeat, health, re-pairing and revocation; changed media/brand; expiry, entitlement, quota and slot; canonical replay and concurrent different selections; outbox uncertainty/recovery; unrelated active-session preservation; excluded old lease issue/HEAD/GET; selected body transfer; and the context-to-transfer commit race.

These are local Admin SDK/HTTP handler checks with injected actor/token verification and clock. They do **not** establish actual app + callable persistence, actual TV media retention, live rules enforcement for a changed schema (rules are unchanged), TestFlight readiness, or a deployed backend result. Those remaining app/development checks belong to integration after the approved server release. The analysis/evidence handoff is `/tmp/cloudboard-precheck-contract-2026-11-14.md`.
