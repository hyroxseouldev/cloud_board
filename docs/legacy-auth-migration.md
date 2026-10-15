# STA-172: app/TV server ownership and landing cleanup

The four active `cloudboard-auth` functions now have source, offline tests,
production-source parity evidence and an isolated deployment configuration in
`cloud_board/functions-legacy`. This change does **not** deploy production or
remove Vercel variables, secrets, keys, IAM bindings, OAuth configuration or data.
The native/three-TV release matrix below still needs real-device evidence.

## Source and read-only evidence

The source is `hyroxseouldev/cloudboard-landing` commit
`4fa45fcf916696909969d35050c722401295e91b`, immediately before the static landing
migration. [migration-baseline.json](../functions-legacy/migration-baseline.json)
records the immutable GCS ZIP object generations and SHA-256 digests retrieved
from all four live functions on 2026-10-14. Each archive's 23 supporting runtime
modules exactly matches the TypeScript build here. The four exported handler
ASTs also match; only inactive exports/imports and the local dev launcher were
removed. This describes the original STA-172 baseline. The reviewed
[STA-176 pairing bridge](sta176-legacy-pairing-bridge.md) changes only the pairing
handler and service, with separate compiled hashes; the historical baseline
is preserved. Existing SQL schema and historical account/payment logic are preserved.

[Read-only inventory](release/sta172/read-only-inventory-2026-10-14.json) was
refreshed at approximately 23:05 KST:

- Exactly four ACTIVE functions in `asia-southeast1`, codebase `cloudboard-auth`;
  Node 22, function names, memory/timeouts, auth behavior and Secret bindings match.
- No Scheduler jobs or Eventarc triggers in `asia-southeast1`. Existing app jobs
  (6) and triggers (11) in `asia-northeast3` remain unrelated and must be preserved.
- The default compute service account still consumes the eight legacy secrets.
  SOLAPI is also shared with app onboarding. Only `github-actions` has a
  user-managed active key; it is an app deployment credential, not a landing key.
- Firebase Auth domains remain localhost and the project firebaseapp/web.app
  domains. Individual Google OAuth origins/redirect URIs still need Console review.
- Vercel `cloudboard-landing` has the same 21 variables, all production-only.
  Production is READY. The static source references only `VERCEL_ENV` and the
  optional public preview flag, not the old server variables.

A paginated HTTP access-log sample still shows `/api/config`, `/api/me`, and
`/api/auth/get-session` requests. It cannot establish the absence of real clients,
callbacks or old web subscribers. **Retain `cloudboardAuth` and all its routes and
Secret bindings.** Web-only retirement requires separate consumer/callback and
historical subscription evidence. No source secret value, token or DB connection
string is included in the evidence.

## Classification and preservation

| Item | Treatment |
| --- | --- |
| Three app callables and existing HTTP API | Manage in `functions-legacy`; preserve names, `asia-southeast1`, `cloudboard-auth` |
| Vercel's 21 old server variables | Remove only landing copies after review and variable-free deployment verification |
| DATABASE_URL / BETTER_AUTH_SECRET | Preserve Firebase originals and historical account-link/entitlement data |
| SOLAPI keys, sender, shared Google OAuth client | Preserve app consumers; do not rotate/delete as landing cleanup |
| BILLING_ENCRYPTION_KEY, Toss credentials and old subscription records | Preserve until payment callbacks, cancellation/refunds and historical recovery are retired |
| Default compute IAM and github-actions key | Preserve shared app deployment/runtime permissions |
| Inactive maintenance/sync/deletion exports | Do not restore or deploy |
| Old Vercel deployments containing server code | Exclude from rollback; rebuild a reviewed static-only revision |

## Build and deployment plan

Use the commands in [functions-legacy/README.md](../functions-legacy/README.md).
The default `firebase.json` remains `account-deletion` only. Its existing release
manifest and app deployment cannot accidentally include the migrated source.
PR CI builds and checks the migrated package separately.

After completing native regression and committing the reviewed candidate, use
Firebase CLI 15.29.0. This plan command performs **read-only cloud calls** and
writes a local inventory plus an ignored, mode-0600 `.env.cloud-board-stationd`:

```sh
node tool/legacy-auth-release.mjs plan
```

The plan copies the existing non-Secret runtime settings from live metadata;
values are never printed. It checks that all four functions agree. Firebase
managed environment fields are excluded. Do not add a shared `.env`, copy Vercel
secrets, change billing flags or enable entitlement sync. Secret Manager values
are never read. The guard separately lists version metadata and rejects a deploy
that would silently bind a newer secret version.

Complete a local release evidence JSON (keep `checks` pending until performed):

```json
{
  "candidateDigest": "digest emitted by the check/plan command",
  "sourceSha": "40-character reviewed candidate commit",
  "appVersions": { "released": "version/build/platform", "candidate": "version/build/platform" },
  "tvVersion": "version/build and three device identifiers",
  "infrastructureReview": "pending",
  "pairingBackend": {
    "project": "cloud-board-stationd",
    "region": "asia-northeast3",
    "function": "pairDisplayConnection",
    "sourceSha": "40-character deployed canonical-backend commit",
    "smoke": "pending"
  },
  "checks": {
    "legacyPairingBridge": "pending",
    "googleAppleLogin": "pending",
    "phoneFreeActivation": "pending",
    "legacyAccountEntitlement": "pending",
    "pairDisplay": "pending",
    "setDisplayState": "pending",
    "threeTvClassLifecycle": "pending"
  }
}
```

If the release owner explicitly waives physical/native QA for this candidate,
record each unperformed native journey above as `"waived"`, not `"passed"`.
Attach the same `qaWaiver` record accepted by
[`requirePhysicalQaWaiver`](../tool/release/class_start_physical_gate.mjs):
`sha` equal to `sourceSha`, `result: "waived"`, non-empty `approvedBy` and
`reason`, UTC ISO `approvedAt`/`expiresAt` (at most 24 hours apart, current at
predeploy), and `physicalQaPerformed: false`. The guard rejects an invalid
supplied waiver even when other checks say passed. A pending/missing journey
does not implicitly become waived. Keep version inventory truthful; it is not
evidence that those app/TV builds were physically tested. Preserve this release
evidence JSON with the deployment record; predeploy prints waived journeys as
not performed.

The waiver applies only to `googleAppleLogin`, `phoneFreeActivation`,
`legacyAccountEntitlement`, `pairDisplay`, `setDisplayState` and
`threeTvClassLifecycle` native journeys. It does not waive canonical backend
deployment/smoke, `checks.legacyPairingBridge`, infrastructure review, candidate
source/digest, live drift, runtime configuration or secret-version checks.
Server/API and source-contract evidence must describe the actual automated
checks performed, separately from the unperformed native journeys.

Capture supporting screenshots/log references with the evidence. Test isolated
accounts in the development backend with both the released and candidate app:
Google/Apple login, phone verification/Free activation, Google subject linkage
and existing web-issued prices/periods/entitlements, pairing and display state.
Use three physical TVs: prepare → start → pause/resume → finish, including the
STA-166 regression. Do not force customer TV reconnection during a class.

Compare Scheduler, Eventarc, Secret bindings/IAM and shared credential metadata
with the saved inventory before marking `infrastructureReview` passed. Any new
trigger, function deletion, changed shared permissions or unrelated source
replacement blocks release. Refresh `plan` within 30 minutes of deployment.
Only after evidence is passed, this is the explicit production command:

```sh
CLOUDBOARD_LEGACY_RELEASE_EVIDENCE=build/legacy-auth/native-regression.json \
  firebase deploy --config firebase.legacy-auth.json \
  --project cloud-board-stationd \
  --only functions:cloudboard-auth:cloudboardAuth,functions:cloudboard-auth:cloudboardLinkAccount,functions:cloudboard-auth:cloudboardPairDisplay,functions:cloudboard-auth:cloudboardSetDisplayState \
  --non-interactive
node tool/legacy-auth-release.mjs verify
```

Do not use `--force`, a broad `functions` selector or the previous landing
`functions/` directory. Predeploy rebuilds the code and checks active contracts,
project, source SHA/digest, live drift, fresh inventory, exact runtime config and
secret versions. Verification permits only source/hash changes on the four
migrated functions; all other function metadata must match. Afterwards re-read
Scheduler/Eventarc/IAM and run app/TV smoke. This guard does not substitute for
those service inventories or physical-device verification.

## Vercel cleanup review

The exact 21 keys and actual targets/IDs are in the inventory's `vercel.variables`.
They include DB/Auth, Toss/billing, SOLAPI, admin/feature flags and gateway settings.
No preview/development copies were present at the refreshed check. Re-query
`GET /v10/projects/prj_ep3C0KporVqzs7W39tRNo2ZmAuaG/env?decrypt=false` immediately
before cleanup and inspect only `id`, `key`, `target`, `type` and custom targets.
Never request decryption or print the raw response.

The production source must remain the static landing commit
`1a3eda9ee39d371e69fa92cdf79279968fe8f041` or a reviewed successor. Run `pnpm check`
in a clean checkout with none of the 21 variables. Verify introduction, pricing,
App Store/Play downloads, privacy/terms links and old-path 404 behavior. Review the
exact metadata diff before deleting each existing variable by its project-scoped
ID with `DELETE /v9/projects/prj_ep3C0KporVqzs7W39tRNo2ZmAuaG/env/{id}`. Missing or
new targets/keys require a revised plan; do not blindly remove project-wide vars.
This repository intentionally has no automatic destructive cleanup command.

Redeploy the static revision without those copies, verify Production READY and
links, then re-list metadata and attach the before/after diff. Previously built
Vercel deployments can retain their old environment, so deleting a current copy
is not key revocation. Do not roll back to a deployment containing server routes;
rebuild a known static-only revision. Original secret retirement, if justified
later, must separately verify every app consumer, historical data decryption,
payment callback and recovery path.

Apply the prepared [landing README patch](release/sta172/landing-readme-server-ownership.patch)
in a reviewed `cloudboard-landing` PR. It is not applied to that remote repository
by this change. It documents server ownership, shared settings and rollback policy.

## Recovery and remaining acceptance

Keep the exact source commit, runtime config, secret version metadata and immutable
live archive generations from the predeploy plan. For a faulty migration, stop
publication, compare evidence, and create a reviewed forward-fix/rollback candidate
from the preserved four-function source. Run current tests and native checks;
deploy only the same four exports using the same config and bindings. Never
restore the old index wholesale (it contains inactive schedules/triggers), revert
data or roll back Firebase rules as part of this server-source migration.

Local tests validate callable guards and the authenticated pairing bridge (the
canonical backend owns pairing retries/slot preservation), display
activation transactions, in-memory SQL account links, historical pricing/periods,
HTTP business logic and deployment drift blockers. Five inherited Neon integration
suites are skipped; no native Google/Apple flow or physical three-TV test is claimed.
The inherited dependency lock currently reports 6 moderate and 5 high npm audit
findings; versions are preserved for parity and require a separate upgrade review.
STA-172 is development-ready when CI passes, but Vercel cleanup, companion README
publication, OAuth inspection, native regression, production migration and final
before/after infrastructure verification remain release actions.
