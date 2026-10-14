# Existing app/TV Functions (`cloudboard-auth`)

STA-172 moves the four active functions from `cloudboard-landing` into this
repository. This is independent of the `functions/` / `account-deletion` codebase.
Production target: `cloud-board-stationd`, `asia-southeast1`, Node 22.

| Export | Contract retained | Secret references |
| --- | --- | --- |
| `cloudboardPairDisplay` | Authenticated callable; `{code,name,zoneName}` → `{paired,deviceId}` | None |
| `cloudboardSetDisplayState` | Authenticated callable; `{deviceId,displayState,replaceDeviceIds}` → `{changed}` | None |
| `cloudboardLinkAccount` | Firebase callable; existing Google subject identity linking and historical web grants | DATABASE_URL, BETTER_AUTH_SECRET |
| `cloudboardAuth` | Existing HTTP authentication/account/payment routes | Existing 8 references, unchanged |

`cloudboardAuth` remains available because callback/old client use has not been
fully retired. No database migration, billing change, key rotation, scheduler or
Firestore trigger is introduced. The prior `cloudboardMaintenance`,
`cloudboardStopBillingOnDeletion`, and `cloudboardSyncEntitlements` exports were
not active and are deliberately absent.

```sh
npm ci --prefix functions-legacy
npm run check --prefix functions-legacy
node tool/legacy-auth-release.mjs check
node --test tool/legacy-auth-release.test.mjs
```

Use Node 22 for both installation and execution. The test runner supplies only
local test configuration and does not inherit cloud credentials, DB URLs, billing
or SMS configuration. SQL tests use in-memory PGlite; five inherited Neon-only
integration tests remain skipped. They do not count as release verification.
`drizzle/*.sql` preserves the historical schema for these tests/recovery; no
migration command is run by build, test, predeploy or deployment.

The checked-in baseline records the exact predecessor commit and all four live
source ZIP generations/digests. The original STA-172 migration matched all 23 supporting modules and four
active handlers. STA-176 adds one reviewed exception: `cloudboardPairDisplay`
and `services/pairing` now forward to the atomic canonical pairing callable.
`sta176-pairing-bridge.json` pins only that compiled delta; the original baseline
remains unchanged, and every other module/handler remains baseline-checked. Dependency versions retain the live
lock; upgrades need their own compatibility review.

Read [migration/release/cleanup procedures](../docs/legacy-auth-migration.md)
before using the isolated `firebase.legacy-auth.json`. Default app deploys never
include this codebase. The migration guard blocks wrong projects, unexpected
exports, changed contracts, runtime config or secret versions, live drift and
missing app/TV regression evidence. Keep generated `lib/`, credentials and `.env*`
out of Git. Do not copy the old landing environment into CI secrets.

Read [STA-176 bridge validation and rollout](../docs/sta176-legacy-pairing-bridge.md)
before releasing this candidate. The fixed target is production project
`cloud-board-stationd`, region `asia-northeast3`, `pairDisplayConnection`.
Other runtime projects fail closed. Local tests stub all network access; no
isolated development deployment or production rollout has been performed.
Deploy and verify the canonical backend first. The release evidence now also
requires `pairingBackend` metadata/smoke and `checks.legacyPairingBridge`.
