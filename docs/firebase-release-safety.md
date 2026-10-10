# Firebase release safety

This change is developed and reviewed against `develop`. Merging it to `develop`
runs checks only. Production settings, accounts, alert delivery and deployment are
not configured or exercised by a develop PR.

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

1. `app-validation`: Flutter analysis/tests, Functions and gate tests, release web
   build, encrypted symbols on main, and removal of public source maps.
2. `firebase-contracts`: complete fixture/emulator suite, with reports retained
   even when a test fails.
3. `firebase-required`: always runs and requires explicit success from both jobs,
   checks every suite and evidence hash, then creates the candidate manifest.
   Missing, skipped, neutral, failed, cancelled or timed-out checks never grant a
   release permit.
4. `firebase-production`: **main push only**, one production deployment at a time.
   Verify SHA, targets, every artifact hash and canary configuration before any
   Firebase change. Recheck current main immediately before backend/rules changes
   and Hosting publication. A superseded run cannot intentionally redeploy old rules.
5. Read actual Firestore/Storage Rules releases and RTDB rules, then perform client
   save/update/server-read, image CRUD, TV session/ACK and cross-account denial.
   Rule-version propagation has a bounded wait; authentication/API errors fail immediately.
6. Publish Hosting, recheck live rules/current main, seal `release.json`, and retain
   the matching run/attempt receipt for 90 days. Mobile workflows download and verify
   this receipt and its artifact digest both before build and immediately before upload.

Use **Re-run all jobs** for a failed workflow. A new attempt must produce fresh
contracts, build, manifest and receipt together; mixing artifacts from attempts
is rejected even when an individual older job was successful.

Firebase services cannot deploy atomically. If Functions succeeds but another
service or smoke fails, `firebase-attempt-*` and the workflow steps show partial
progress; no verified receipt or mobile permit is produced. Existing installed
clients still see whatever backend steps succeeded, which is why backward
compatibility and recovery matter. Rule checks are not an IAM test.

## Before promotion to main

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
- Configure a read-only repository Administration token as `FIREBASE_GOVERNANCE_TOKEN`
  for the monitoring job. Normal PR jobs never receive it or Firebase credentials.
- After `firebase-required` has succeeded on the heads of main and develop, inspect
  the offline plan, then apply protections deliberately with an admin token:

```sh
node tool/firebase/branch-protection.mjs plan
# GITHUB_TOKEN is supplied securely by the operator, not pasted into a command.
node tool/firebase/branch-protection.mjs apply
node tool/firebase/branch-protection.mjs check
```

The protection requires PRs, an up-to-date base and the exact check from GitHub
Actions, and disables administrator/force-push/deletion bypass. Until this separate
GitHub setting is applied, the workflow alone cannot prevent someone merging a
failed PR. The tool checks actual check availability before applying a branch rule.
No merge queue is configured.

- Confirm the existing managed save alert is enabled with an enabled/verified
  receiver. `release-health.mjs` checks configuration but **does not prove delivery**.
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
4. Release a newly verified main commit through the normal gate. Do not rerun an old
   workflow to bypass the current-main check. An emergency bypass, if needed, is an
   explicit operator decision and must be documented and later removed.
5. Verify live versions, smoke cleanup and actual alert delivery; record detection
   and recovery timings. Keep data restoration (STA-71) and draft recovery (STA-97)
   separate from rules rollback.

The emulator suite records deny-all/allow-all detection and restored contracts in
`recovery-drill.json`, followed by the real client smoke twice. These measurements
are local verification evidence, not a production recovery SLA. Main rollout must
record the actual IAM/read-back/canary/receiver results before those Linear acceptance
items are checked off.

References: [Firebase rules tests](https://firebase.google.com/docs/rules/unit-tests),
[coverage reports](https://firebase.google.com/docs/rules/emulator-reports),
[Rules management](https://firebase.google.com/docs/rules/manage-deploy),
[emulator limitations](https://firebase.google.com/docs/emulator-suite/connect_storage),
[GitHub required checks](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches).
