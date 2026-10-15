# Firebase release safety

Feature work is developed and reviewed against `develop`, then integrated into
`main`. Main and develop pushes do not deploy. Development deployment starts from
a version-matched `dev/vX.Y.Z-N` tag in main history and targets only
`cloud-board-development`, including `.dev` mobile QA. Manual QA requires the same
development-tag identity. Production uses a version-matched `vX.Y.Z` tag and
`cloud-board-stationd`, with required CI by default and an explicitly reasoned
manual `skip_ci` option. The current trigger, version-commit and evidence policy
is [feature verification](feature-verification.md); the detailed checks below do
not authorize branch-push deployment or equate a CI skip with a passing test.

## Run the complete check locally

Use the pinned Flutter SDK, Node 22 and Java 21. Install dependencies once:

```sh
npm ci --prefix functions
fvm flutter pub get
FLUTTER_BIN="$(command -v flutter)" node tool/firebase_contracts.mjs
node --test tool/release_backend_gate.test.mjs tool/firebase/*.test.mjs
```

Set `FLUTTER_BIN` to the FVM Flutter executable if Flutter is not on PATH. The
runner exports the actual Flutter workout, settings and v1/v2 playback documents,
checks the frozen client fixtures against `origin/main` (or `CONTRACT_BASE_REF`),
and runs every suite in `tool/firebase/contract-suites.json`. Firebase CLI version
15.29.0 is shared with production deployment. No production credentials are needed.

All four emulators use localhost ports 19380/19300/19399/19390. Existing suites
retain separate **demo** project namespaces; `singleProjectMode: false` is
intentional. Storage cross-service Firestore checks and actual Auth canaries use
the CLI's `demo-cloudboard` project, since cross-service emulation must share a
project. An emulator failure never falls back to a real project.

The runner resets fixture data between suites, enforces per-suite timeouts, kills
timed-out process groups and records every result. An unregistered emulator suite
fails inventory validation. Coverage HTML/JSON is gzip-compressed to keep both CI
artifacts and local disk use small; inspect with `gunzip -c FILE.html.gz > report.html`.
Storage reports are assertion results, not a misleading coverage percentage.

## Permission matrix

| Contract | Must succeed | Must fail |
| --- | --- | --- |
| Workout + summary transaction | Owner create/update/duplicate; supported old payloads; both schemas | Foreign/guest access; owner spoofing; invalid fields; orphan summary; deletion lock; partial write |
| Preferences | Real app document; revision update and legacy mirror | Stale revision; client schema activation; foreign account |
| Playback v1/v2 | Authorized owner; v1 pilot; paired TV read/ACK | Foreign/unpaired/revoked TV; TV session writes; expired native commands; stale ETag |
| Storage profile/brand/workout | Owner CRUD; valid MIME; size just below limit | Foreign/guest/TV client CRUD; bad MIME; size at limit; account deletion lock |
| AI/library/onboarding/billing | Existing entitled transactions and idempotent retries | Client entitlement/ownership changes; exhausted budget; duplicates; deletion locks |
| Mutation/recovery drill | Original rules allow owner and deny foreign account | Deny-all and allow-all mutations each break the appropriate contract |

Storage tests exercise authenticated SDK access. Existing tokenized image URLs
and already downloaded TV files are a separate distribution/revocation policy;
this PR does not claim to revoke downloaded content or change Storage rules.
STA-56 membership permissions remain a separate feature. The onboarding survey's
`role` field never grants access.

Frozen `1.0.0+2` data is sourced from its recorded commit and represents the reported
iOS client. Current exports use the shared Flutter serializer, not a substitute
JS field allowlist. A release should add a new frozen fixture with exact version,
build, platform, source SHA and digest to `supported-clients.json`. Never rewrite
or remove an existing fixture to make a rule change pass; retirement requires a
separate compatibility rollout and explicit test-policy change. Native device QA
is still needed for platform SDK/offline differences.

## Required check and deployment sequence

1. Verify the immutable production tag, fixed source SHA, main ancestry, app
   version and deployment scope. Main advancement does not change this source.
   `Start production release` creates only a production tag; finalize the version
   commit first. Direct tag pushes run normal CI by default. A manual deployment
   may set `skip_ci=true` with a required `skip_ci_reason` and retained audit record.
2. Under the normal CI policy, run `app-validation`, class-start regressions and
   the Firebase contracts required by the selected scope, retaining their reports.
   An explicit skip omits heavy validation, never records it as passed, and does
   not remove environment, source, build or deployment checks.
3. Build the web artifact when the scope includes web, encrypt its symbols and
   remove public source maps. Aggregate the scope's required evidence and artifact
   hashes into the candidate manifest. Missing or failed required evidence blocks
   deployment; the explicit skip must be represented in the validation receipt.
4. `firebase-production` writes one production deployment at a time. A manual
   tag retry confirms the exact tag SHA and `web`, `rules`, `backend` or `full`
   scope. Verify targets, artifact hashes and canary configuration before writes;
   recheck tag identity, main ancestry and deployment ordering before publication.
   Web-only changes do not redeploy Functions; backend-only changes do not require
   a web build. Combined changes deploy and verify the backend before web.
5. Keep the applicable live-rule read-back and client smoke checks: client
   save/update/server-read, image CRUD, TV session/ACK and cross-account denial.
   Rule propagation has a bounded wait; authentication/API errors fail immediately.
6. Seal `release.json` with the actual deployed scope and source, and retain the
   matching run/attempt receipt for 90 days. Production store uploads check current
   backend compatibility before the release build and immediately before upload;
   they do not demand a new full deployment for an unchanged backend. Build-only
   artifacts still require the appropriate development/production tag and grant
   no upload permit by themselves.

Use **Re-run all jobs** for a failed workflow or the explicit manual retry from
the same immutable release tag. Each attempt must produce the evidence required
by its scope and declared CI mode; mixing artifacts from attempts is rejected
even when an individual older job was successful.

Firebase services cannot deploy atomically. If Functions succeeds but another
service or smoke fails, `firebase-attempt-*` and the workflow steps show partial
progress; no verified receipt or mobile permit is produced. Existing installed
clients still see whatever backend steps succeeded, which is why backward
compatibility and recovery matter. Rule checks are not an IAM test.

## Before production rollout

These are rollout prerequisites, **not operations performed by this PR**:

- Add `FIREBASE_WEB_API_KEY` to GitHub Actions secrets with this project's web API
  key. Use a key whose restrictions permit the CI Auth client. Ensure canary
  custom-token sign-in is supported by the existing Identity Toolkit configuration.
- Enable repository variable `FIREBASE_RELEASE_CANARY_ENABLED=true` only after
  reviewing provisioning permissions and the exact three reserved canary UIDs in
  `functions/tools/release-canary.mjs`. A missing flag/key blocks production **before**
  deployment. Existing required SOLAPI and symbol encryption configuration still applies.
- The deploy service account needs existing deploy permissions plus Auth user/custom
  token provisioning, synthetic fixture setup/cleanup, Rules read-back and database
  rules read access. Use the minimum appropriate IAM roles; verify these against the
  real project during rollout, since emulators do not replicate IAM.
- Only `cloudboard-release-owner`, `cloudboard-release-other`, `cloudboard-release-tv`
  are used. Existing UIDs must carry the canary claim; an unrelated account with
  the same UID makes setup fail. Test documents/images/device IDs use the exact
  `release-RUN-ATTEMPT` namespace. No customer scan, email/SMS, AI request or purchase
  is part of the smoke. Synthetic TV uses a dedicated signed-in identity to test
  the paired access mapping; anonymous-TV behavior is also tested in the emulator.
- `prepareCanary` is the limited Admin fixture boundary; assertions use client SDK
  tokens. Dedicated identities persist for reuse. A lease prevents concurrent smoke;
  cleanup is idempotent and scoped to the same run. An expired lease is not silently
  taken over. If a job is killed before cleanup,
  inspect that run's lease and rerun scoped cleanup before another smoke. Do not delete
  arbitrary user paths. Clean up stale run namespaces using the reviewed cleanup helper.
- The monitoring job audits active repository rules using its read-only built-in
  GitHub token. No stored `FIREBASE_GOVERNANCE_TOKEN` is required. Normal PR jobs
  receive no Firebase deployment credentials.
- Inspect the expected rule plan and verify the active rules on main and develop:

```sh
node tool/firebase/repository-rules.mjs plan
# Supply GITHUB_TOKEN securely; GITHUB_REPOSITORY=hyroxseouldev/cloud_board.
node tool/firebase/repository-rules.mjs check
```

The protection requires PRs, an up-to-date base and the exact check from GitHub
Actions, and disables administrator/force-push/deletion bypass. Until this separate
GitHub setting is applied, the workflow alone cannot prevent someone merging a
failed PR. The rules checker is read-only; changing protection is a separate
operator action. No merge queue is configured.

- Confirm the existing managed save alert is enabled with an enabled/verified
  receiver. `release-health.mjs` checks configuration but **does not prove delivery**.
  Client diagnostics now use structured `logger.write`: the previous
  `logger.error` SDK prepended an Error stack to the marker, which did not match
  the existing alert's exact message filter. The observer also recognizes that
  older log format for delayed reports.
  Send one authorized synthetic diagnostic during rollout and record receiver,
  event ID, sent/received timestamps and actual delivery latency in the issue.

## Observation and recovery

The hourly/main-only monitor reads the latest verified receipt, checks for Console
or manual-CLI rule drift, reviews save diagnostics and audits branch protections.
It defers while a deployment is running and never overwrites live rules or competes
for the deployment lock. A missing receipt/API access/alert configuration yields an
unknown/failing observation, not a healthy deployment. Review GitHub failure
notifications as well as the existing Cloud Logging save alert.

Diagnostics received in the last two hours (and after the release) are grouped by
action, Firebase code, platform and app version/build. This overlapping hourly
window catches delayed reports without alerting forever on a historical error.
Delayed events that occurred before the release are counted separately. There is
no success-rate claim without a success/attempt denominator. No logs is not proof
that a class saved. `health.json` excludes raw stacks, customer content and credentials.

When a release causes legitimate saves to fail:

1. Stop further publication; record failed SHA/run/attempt and affected app builds.
   Inspect the relevant suite and sanitized attempt artifacts. Keep existing rules
   strict; do not use allow-all as a repair.
2. Download the last verified `firebase-release-*` receipt and its `rules/` files.
   Produce a reviewable local candidate:

```sh
node tool/firebase/recovery.mjs PATH/release.json PATH/rules build/recovery
```

3. Review whether the previous rules support **all currently installed clients** and
   the currently deployed Functions. Copy a suitable candidate into a new isolated
   branch; run the full current contracts and review its diff. If old rules cannot
   support new writes, make a compatible forward fix instead.
4. Integrate the repair into main, finalize its version and release it through a
   new production tag. Keep the fixed source, ancestry, ordering and compatibility
   checks. An explicit manual CI skip requires a reason and audit evidence and
   does not authorize tag movement, source substitution or failed smoke checks.
5. Verify live versions, smoke cleanup and actual alert delivery; record detection
   and recovery timings. Keep data restoration (STA-71) and draft recovery (STA-97)
   separate from rules rollback.

The emulator suite records deny-all/allow-all detection and restored contracts in
`recovery-drill.json`, followed by the real client smoke twice. These measurements
are local verification evidence, not a production recovery SLA. Production rollout must
record the actual IAM/read-back/canary/receiver results before those Linear acceptance
items are checked off.

References: [Firebase rules tests](https://firebase.google.com/docs/rules/unit-tests),
[coverage reports](https://firebase.google.com/docs/rules/emulator-reports),
[Rules management](https://firebase.google.com/docs/rules/manage-deploy),
[emulator limitations](https://firebase.google.com/docs/emulator-suite/connect_storage),
[GitHub required checks](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches).
