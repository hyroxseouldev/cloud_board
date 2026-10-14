# STA-165 audience logo server contract and rollout

This change is implementation and local verification only. It does not activate a Firebase project, publish a mobile/TV build, change production rules, or verify a physical TV. The branch starts from `develop` `9583a33`; it does not depend on STA-164 being deployed.

## Contract

The existing server-owned `users/{ownerId}/operations/brandProjection` now contains:

```json
{
  "ownerId": "firebase-owner-uid",
  "revision": 12,
  "projectionRevision": 4,
  "policyVersion": "plan-entitlements-v2",
  "plan": "plus",
  "appliedAtMs": 1800000000000,
  "validUntilMs": 1800003600000,
  "audienceLogoVersion": "audience-logo-v1",
  "audienceLogoScope": "all-audience",
  "showCloudBoardLogo": false
}
```

`revision` remains the entitlement revision. `projectionRevision` increases inside the RTDB transaction on every committed projection, including preference and scope changes at the same entitlement revision. The transaction writes `brandConfig` (preserved original), `brand` (effective standby content) and the complete `brandProjection` together. Audience clients use the projection's own visibility value; they must not combine a raw configuration stream and an entitlement stream to calculate it.

Free publishes `showCloudBoardLogo: true` regardless of custom text, fullscreen images or the saved hidden preference. Plus/Premium use the existing `brandConfig.showCloudBoardLogo` preference; missing preferences continue to mean shown. A live Premium trial keeps Premium behavior. The change does not add a center logo to workout scenes.

The existing per-account `plan-entitlements-v2` prerequisite remains. v1 accounts receive no new audience projection and their legacy custom settings remain unchanged; activating audience branding never migrates quota policy. Recognized server-issued pilot grants and `legacy`/`cloudboard_pro` grants retain explicit branding capabilities. Unknown legacy branding capabilities, unknown/expired status, missing entitlements and failed reads do not become Free: the last confirmed projection remains untouched. The compatibility handling is local to branding and does not widen AI, storage or workout quotas.

Paired anonymous TVs cannot read owner-only Firestore entitlements or RTDB subscription access. Existing `brandProjection` rules already allow the owner and paired TV to read it while denying all client writes, including child writes. Private `brandConfig` stays owner-only. No new entitlement disclosure or playback write authority is introduced.

## Explicit activation

The server reads `appConfig/audienceBranding`:

```json
{
  "version": "audience-logo-v1",
  "enabled": true,
  "ownerIds": ["reviewed-owner-uid"]
}
```

Only the exact version, literal `enabled: true`, and an exact owner ID in the array activate that account. `allAccounts: true` explicitly enables all eligible v2 accounts. Unknown versions, absent/invalid configuration, disabled state or an excluded owner publish `standby` scope on the next successful projection. A configuration read failure leaves the previous projection intact instead of treating it as a disabled plan.

Public product copy may describe the expanded scope only when exact version + `enabled: true` + `allAccounts: true` are present. An owner allowlist is a limited rollout, not permission to advertise the feature for everyone. Companion public configuration follows the same predicate.

Changing the gate alone does not retrigger unchanged entitlement documents. Reconcile selected accounts explicitly after activation or deactivation. Later entitlement updates and successful brand saves use the existing `syncStandbyBranding`/`cloudboardSaveBrandConfig` paths. No new deployed function export is required.

## Readiness and controlled reconciliation

`tool/firebase/audience-branding.mjs` defaults to read-only. It checks canonical v2 branding access, deletion state, every registered display's existing `appPlatform`/`appBuild`, and supplied release evidence. Android/iOS additionally require the server `appReleases/{platform}` to be enabled, published, and to advertise a minimum supported build. It does not infer logo support from timing or image-preparation protocols.

Prepare a local JSON evidence file after publishing and verifying the build. Build numbers below are deliberately placeholders; do not copy them as release facts:

```json
{
  "audienceLogoVersion": "audience-logo-v1",
  "platforms": {
    "android": {
      "minimumBuild": 123,
      "publishedBuild": 123,
      "evidenceUrl": "https://example.invalid/replace-with-verified-release-evidence"
    },
    "web": {
      "allowedBuilds": ["123.1"],
      "evidenceUrl": "https://example.invalid/replace-with-verified-web-build-evidence"
    }
  }
}
```

For native platforms, the file asserts the first build with this implementation and the latest verified published build. Web Hosting uses `GITHUB_RUN_NUMBER.GITHUB_RUN_ATTEMPT` build IDs, so `allowedBuilds` lists exact verified strings; a different attempt is not inferred to be supported and the tool never parses these IDs as numbers. This is operator evidence, not a substitute for inspecting the release. Missing/unsupported platform, absent or older device build, an unlisted web build, unpublished build, or invalid mobile update configuration block applying `all-audience`. Unpaired devices are ignored. Offline/stale registered devices and an ongoing class are reported as warnings: readiness establishes code support, not evidence that an offline screen has already received the new policy. No paired devices also produces a warning rather than proving TV coverage.

Read-only example (requires authorized Admin SDK credentials for the explicit target):

```sh
node tool/firebase/audience-branding.mjs \
  --project YOUR_PROJECT \
  --database-url https://YOUR_PROJECT-default-rtdb.asia-southeast1.firebasedatabase.app \
  --owner REVIEWED_OWNER \
  --support /absolute/path/to/verified-builds.json
```

After separately authorizing the account rollout and reviewing the report, append `--apply --confirm-project YOUR_PROJECT` to reconcile those exact owner IDs. The tool never writes the rollout gate, entitlement, release policy, session, or device record. It writes only the existing branding projection through the production projector. It re-reads readiness immediately before applying and then verifies the returned scope and monotonically increased projection revision. A failed/unknown result is reported rather than claimed as applied. Multiple explicit `--owner` values are supported, capped at 100; there is no wildcard bulk mutation.

Disabling scope can be reconciled even when a TV is old, because restoring `standby` does not require the new renderer. Missing/deleted/expired/v1 account state still blocks publication. Apply is idempotent in behavior but each confirmed publication receives a new projection revision. Re-running repairs transient cross-service failures; an error cannot erase `brandConfig`.

## Release order and compatibility

1. Deploy reviewed server code and existing rules after CI, keeping audience activation disabled. Confirm actual function deployment succeeds; a merge or green unit test does not establish deployment.
2. Publish the Flutter TV/mobile and web builds containing the common audience overlay. Record real build numbers and evidence. Configure `appReleases` only after store publication; retain the existing safe-standby update presentation.
3. Run the read-only readiness command for selected accounts, inspect installed builds and unresolved offline devices, then explicitly enable only reviewed owner IDs and reconcile them.
4. Verify standby/briefing, countdown, workout/image/timer, rest/paused, completion return and true black screen on a physical TV. Check bright/dark backgrounds, safe area, distance readability and transitions. Validate cached/offline reconnect behavior. This step is not claimed by local tests.
5. After release coverage is established, explicitly enable global scope, reconcile the intended account population in controlled batches, and switch public copy via the same global readiness predicate.

An older TV binary cannot acquire a missing overlay from server data. It retains its previous renderer and is not considered fully compliant until updated; supported minimum builds are therefore release evidence, never invented constants. This change adds no hard playback block and does not interrupt a running, paused or offline-recovering class. Updated clients change only the audience overlay and preserve the player/session identity. Black screen remains black. An offline client's already cached confirmed visibility remains its last confirmed state until reconnect; expiry of a cached logo policy is not authorization to start another class. No first-time unknown policy is fabricated as Free.

To roll scope back, disable/remove the owner from the gate and reconcile: current supported clients return to standby-only scope on confirmed receipt, without erasing the hidden preference. An offline client may retain its last confirmed all-audience scope until reconnect. A newer unknown policy version is not interpreted locally.

## Local verification

- `node --test functions/test/*.test.js`: server regression suite, including audience gate, forced Free, paid preference, same-revision settings, originals/upgrade, v1 preservation, recognized pilot/legacy, stale/unknown/deletion handling.
- `node --test tool/firebase/audience-branding.test.mjs`: read-only no-write guarantee, explicit target/apply confirmation, build/release checks, fresh-state recheck and publication verification.
- `functions/test/standby-branding-emulator.mjs`: existing Storage and owner/TV separation coverage plus actual Admin SDK Free/Plus projection, concurrent monotonic revisions, client-forged scope/visibility rejection, unknown-state preservation and scope deactivation.

Local results on 2026-10-14:

- Server Node suite: **171/171 passed**, `/tmp/sta165-node.log`.
- `node --test tool/firebase/*.test.mjs`: **52/52 passed**, `/tmp/sta165-tools.log`.
- Firestore/RTDB/Storage emulator, Node 22: **passed**, `/tmp/sta165-branding-emulator.log`. The first run exposed an isolated test namespace mismatch between the Admin SDK and rules test client; both now target the same demo namespace and the final run includes real projector reads through the paired-TV client.

Emulator command: `firebase emulators:exec --only firestore,database,storage --project demo-cloudboard-branding --config /tmp/sta165-emulators.json 'node functions/test/standby-branding-emulator.mjs'`, with Node 22 and Android Studio JBR. Emulator ports were local 193xx and the processes were shut down after completion. No production command or paid/provider API call was part of this verification.
