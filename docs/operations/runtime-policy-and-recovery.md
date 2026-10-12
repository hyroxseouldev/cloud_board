# Runtime feature controls and workout recovery (STA-138)

These controls ship in the stabilization client. Older installed binaries do not gain these controls remotely. Server security rules and backward-compatible data must remain the primary protection for those clients.

## Operator controls

The single Firestore document `runtimePolicy/current` is readable by authenticated clients; only administrative credentials can write it. This is not an entitlement or security override. No workout text, account IDs, email addresses, or secrets belong in the policy.

```json
{
  "schemaVersion": 1,
  "revision": 1,
  "features": {
    "splitPlayback": {"enabled": true, "rolloutPercent": 100},
    "aiSlideGeneration": {"enabled": true, "rolloutPercent": 100}
  }
}
```

- `splitPlayback: false` starts the next session with the compatible v1 snapshot protocol. Existing split sessions continue using their immutable snapshot and normal commands. Basic class playback remains available.
- `aiSlideGeneration: false` pauses new AI content-generation requests with a user-facing explanation. Premium templates, manual editing, and existing generated slides remain available.
- `rolloutPercent` is an integer 0–100. Membership is deterministic for account ID and feature, consistent across that account's devices. It never grants paid access.
- Missing policy/feature preserves shipped behavior. Invalid, unreachable or deleted documents retain the last validated policy. Fetches occur at each new optional operation, with a four-second network timeout; ordinary saves do not fetch policy.
- The cache is scoped to Firebase project. Restoring a feature requires writing a **higher revision** with `enabled: true`, not deleting the document or decrementing its revision.

With approved Application Default Credentials for the explicitly chosen project:

```sh
node functions/tools/runtime-policy.mjs validate --file /path/to/policy.json
node functions/tools/runtime-policy.mjs show --project cloud-board-stationd
node functions/tools/runtime-policy.mjs apply --project cloud-board-stationd --file /path/to/policy.json --expected-revision -1
```

Use `-1` only when creating the document for the first time. For every later change pass the exact revision returned by `show`. The transaction rejects concurrent operator changes and non-increasing revisions. First rehearse in the development Firebase project by passing its project ID. Deploying this code does not create or change production policy.

## Save failure and recovery

The workout editor writes the entire draft, including ordering, name/folder, slide settings, and local images, to account-scoped local storage. Edits are debounced 300 ms and flushed before remote save and on backgrounding. Failed remote saves leave the draft available after relaunch. Local images are stored separately and reused, and a pointer is committed only after a complete snapshot is durable. A failed disk write preserves the previous committed snapshot and shows an inline storage warning.

Reopening the editor requires an explicit recovery choice. If the server version has changed or cannot be checked, recovery creates a new workout rather than overwriting server content. Remote saves also check the editor's original `updatedAt` inside the write transaction; conflicts offer “복사본으로 저장”. Successful saves and explicit discard clear the recovery record. Recovery data is local to the device/browser profile, not an account backup: uninstalling or clearing browser storage can remove it, and abrupt process termination can lose changes within the debounce window.

The existing per-slide draft mechanism remains responsible for edits still open within the slide editor. The full-workout draft preserves the containing new workout so those slide IDs and local edits remain reachable after relaunch. Unsaved drafts are never automatically submitted to the server.

## Verification

- `test/runtime_feature_policy_test.dart`: safe defaults, malformed/unavailable documents, cached stop across restart, deterministic cohort, monotonic revision.
- `test/playback_split_protocol_test.dart`: stopping split rollout affects only the next start; current session pause/resume remains operational.
- `test/workout_recovery_test.dart`: complete image-inclusive recovery, account/route isolation, failed replacements, serialized discard, concurrent version guard.
- `functions/test/runtime-policy.test.js`: validated operator input and atomic revision checks.

Before promoting to all users, exercise real-device airplane-mode save/relaunch/recovery and development policy stop/restore with one current phone, one current TV, and a supported older TV. Never claim a server-side control can repair behavior absent from a released binary.

## Remote Config rollout (STA-134 additional plan)

`cloudboard_optional_features_v1` is a Remote Config JSON parameter using the same validated `{schemaVersion: 1, revision, features}` schema. It contains optional feature flags only; **never** put minimum/recommended/published app builds here. Version requirements remain exclusively in `appReleases`.

The new-operation boundary fetches and activates flags (bounded timeout, minimum fetch interval 15 minutes), validates them, and caches the last good value per Firebase project. There is no real-time listener that changes an active lesson. The phone resolves the feature choice once when creating a session; TVs consume that session's existing protocol/snapshot and do not independently randomize flags. Percentage assignment uses the owner's stable identifier so the same center/account has the same cohort across restarts.

Firestore `runtimePolicy/current` remains the compatibility/emergency control for existing clients. The new Remote Config rollout is an additional restriction: it cannot turn on a feature disabled by that existing control. These are feature controls, not authorization; Rules/server ownership and entitlement checks still apply. Missing/malformed/unavailable Remote Config preserves validated existing behavior, while a known disabled value stays disabled during an outage. Basic saving and already running playback are not gated.

Use a pilot percentage for optional new functionality, verify TV capabilities before starting, and observe terminal operation outcomes before expansion. Source: [Firebase loading/activation guidance](https://firebase.google.com/docs/remote-config/loading). No production Remote Config template was published by this change.
