# Fixed-source direct releases

This is the replacement for GitHub Actions build/deploy workflows. A push, PR,
merge or version tag does **not** deploy. Run one selected target from a clean
checkout of an exact integrated commit. This change is developed on `develop`;
it is not a production deployment or permission to change production data.

## Commands

`direct.mjs` is offline plan/dry-run by default. It reads only the selected commit
with Git. Add `--execute` to build/deploy, and separately `--upload` for a store
upload. Use an Orca clean worktree; never reset/stash another checkout's changes.

```sh
node tool/release/direct.mjs --source FULL_40_CHARACTER_SHA --environment development --scope web
node tool/release/direct.mjs --source FULL_40_CHARACTER_SHA --environment development --scope backend
node tool/release/direct.mjs --source FULL_40_CHARACTER_SHA --environment development --scope rules
node tool/release/direct.mjs --source FULL_40_CHARACTER_SHA --environment development --scope functions --functions account-deletion:saveWorkout,account-deletion:cloudboardMedia
node tool/release/direct.mjs --source FULL_40_CHARACTER_SHA --environment development --scope ios --upload
node tool/release/direct.mjs --source FULL_40_CHARACTER_SHA --environment development --scope android --upload
node tool/release/direct.mjs --source FULL_40_CHARACTER_SHA --environment production --tag v2.1.6 --scope web
```

The examples are plans, not deployment commands. An executing development source
must be included in remote `develop`; production requires the exact immutable
`vX.Y.Z` tag, matching `pubspec.yaml` and inclusion in remote `main`. An existing
tag is never moved or deleted. Prepare/commit the version and editorial first;
create a new matching version tag explicitly after integration. The old
`start_release.mjs` executable refuses Actions dispatch. Its exported historical
planner remains for compatibility regression fixtures only.

| Scope | Actual operation |
| --- | --- |
| `web` | Flutter web build, environment/build stamp, Hosting only |
| `rules` | Firestore rules/indexes, RTDB rules, Storage rules only |
| `backend` development | Explicit development function allowlist, including isolated legacy display callable |
| `backend` production | Explicit non-omitted core function exports **and rules**, matching the old backend scope; no Hosting |
| `functions` | Only supplied `codebase:function` selectors; no rules or Hosting |
| `ios` / `android` | Signed build and inspection; upload only with `--upload`; no Firebase deployment |

Never substitute `firebase deploy --only functions` for the selectors. Production
excludes development-only 2.1.5 usage/media endpoints even if their declaration is
accidentally exposed, omitted schedules, and the externally managed/legacy
`cloudboard-auth` codebase. Production legacy changes continue to require
`tool/legacy-auth-release.mjs` and its migration evidence. Development reuses
`developmentFunctionNames` and the `cloudboardSetDisplayState` isolated package,
including its pinned functions-legacy build. Explicit selected function deploys
retain reviewed retry flags (`--force`); no whole-codebase deletion is requested.
No policy document is activated or account enrolled by this CLI.

## Local prerequisites and evidence

Use the existing authenticated `gh` session (repository contents/ref write for
receipt commits and Android number reservations), local Firebase CLI login, the
repository's pinned Flutter SDK, Node, Java/Android SDK or Xcode as applicable.
The CLI does not install SDKs. Firebase CLI remains pinned to 15.29.0 and cached
by npx. npm dependencies are reused only with the same package+lock digest and a
stamp from this CLI's successful install; changed locks rerun `npm ci`. Flutter
uses its existing pub/build caches. Stage start/end timestamps and dependency
reuse are recorded; no speed threshold is guaranteed.

`--execute` checks project access, source cleanliness, remote ancestry and SDK
identities before changing services. Production live-rule readback and canary
smoke additionally require the existing ADC authorization, provisioned canary,
`FIREBASE_RELEASE_CANARY_ENABLED=true` and `FIREBASE_WEB_API_KEY`. Provider and
platform authorization errors remain failures. A plan does not prove credentials,
permissions, signing or service availability.

Function discovery preserves the common, allowlisted **nonsecret** live runtime
configuration. Different per-function configurations, unknown variables and
changed secret bindings block the release. Provider feature flags are read from
that live configuration, not silently replaced with local defaults. Development
can supply exact `CLOUDBOARD_MEDIA_ALLOWED_ORIGINS`; wildcard origins are rejected.
A temporary nonsecret dotenv is created exclusively for deployment and removed
only if this invocation created it. Secret plaintext is never copied. Existing
source `.env`/`.secret` overrides are rejected. Actual local authentication is
used at execution; no credential file is created or logged.

### Mobile

Development must have `MOBILE_DEVELOPMENT_READY=true` locally, in addition to
successful app/profile inventory and signed-artifact verification. GitHub
Environment readiness remains an informational record, not a CLI credential.
QA uses `com.sunmkim.cloudboard.dev` + development Firebase. Production uses
`com.sunmkim.cloudboard` + production Firebase. iOS and Android are separately
selected; no EAS migration is introduced.

For iOS, use the existing `APP_STORE_CONNECT_API_KEY_PATH` named
`AuthKey_<KEY_ID>.p8`, `APP_STORE_CONNECT_KEY_ID`,
`APP_STORE_CONNECT_ISSUER_ID`, `IOS_TEAM_ID`, and `IOS_EXPORT_OPTIONS_PATH`.
The development export file is `ios/ExportOptions-Development.plist` from the iOS
configuration change. The local Apple Distribution identity and profiles must
already be installed. The CLI neither copies nor deletes that credential.
It reuses Flutter archive, entitlement preparation, xcodebuild export,
`inspect_ios_signing.py`, `inspect_native.py`, build-history recheck and altool.

For Android, use existing `ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_PASSWORD`,
`ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`
in memory, and `BUNDLETOOL_PATH` (pinned 1.18.3 SHA verified by the inspector).
`GOOGLE_PLAY_BOOTSTRAPPED=true` is required for upload. The existing complete
app-specific Play baseline/reservation allocator still applies. The development
baseline must be obtained from that app's real history; production is not reused.
The direct Play adapter uploads/validates/commits **internal** only.

Before a production native build and again before upload, the CLI reads the actual
backend receipt. Different fingerprints require the existing exact-source
mobile compatibility plan and its local emulator/client tests against the
recorded deployed backend copy. A newer app version alone is never compatibility
proof. The proof is stored with the attempt. No Actions CI is started or passed.
Artifact hashes, native/Dart environment, version/build, certificate/profile and
build-number rechecks remain mandatory. Upload success means TestFlight/Play
internal upload, **not** processing, external review or public release.

## Receipt storage and consumers

`build/direct-release/<id>/attempt.json` and the dedicated
`cloudboard-deployment-receipts` branch's `direct-deployments.json` contain the
fixed source, actor, project, exact targets, validation-not-run policy, stage
results/timestamps, runtime configuration digest and verified artifact/receipt.
They contain no tokens or secret values. The branch is created lazily on the first
explicit execution; this implementation task does not create it remotely.

A pending receipt is committed **before** build/deploy/upload. Contents API SHA
compare-and-swap serializes all direct runs across machines and environments.
Lost writes leave pending state; another run fails closed instead of racing.
There is no automatic timeout takeover or automatic retry of uploads/commits.
Local output and the receipt branch commit history retain partial results.
A failure before deployment may conservatively require reconciliation too.

Production full-backend/rules/web receipts embed the same format-1 manifest,
live-rule/smoke or compatible-backend proof as the previous workflow artifacts.
`latest-release` checks the direct ledger first for the CloudBoard repository, then reads historical
Actions artifacts if that component has no direct history. Historical receipt
validation is unchanged. Partial function deployment records command success but
cannot claim a full backend fingerprint; mobile/web compatibility blocks until a
complete backend/rules reconciliation establishes a verified receipt. Development
readback records selected function ACTIVE metadata, exact Firestore/Storage/RTDB rule hashes, or the deployed Hosting build stamp. Index readiness and actual callable/app behavior are not inferred from that readback. Development command success is not production backend verification; actual app/API QA and
policy activation remain separate.

The monitor, native CLI and CloudBoard repository readers use the adapter automatically;
`CLOUDBOARD_DIRECT_RECEIPTS=true` also explicitly selects it for helper execution.
Installed-client inventory accepts `directDeploymentId` alongside historical
`workflowRunId`, retaining uploaded production clients and excluding development.
Direct mobile receipts use schema 5 (fixed SHA development source); old schemas
1–4 remain readable. Register real installed clients/contracts after upload;
this CLI does not invent or delete their compatibility evidence.

App news remains a separate operational workflow. Run it from trusted main with
`direct_deployment_id=<receipt id>` or the old `deployment_run_id` for historical
recovery. It uses committed editorial at the actual source SHA and verified
production deploy/upload steps; QA and build-only records cannot publish news.
No raw commit body, PR success or pending receipt is publication evidence.

## Workflows removed / retained

Removed from `.github/workflows`:

- `class-start-regressions.yml`, `development-handoff.yml` (CI only).
- `firebase-development.yml`, `firebase-hosting-merge.yml`, `testflight-main.yml`,
  `google-play-main.yml`, `start-production-release.yml` (five deployment workflows).

They are inert fixtures in `tool/release/fixtures/retired-workflows`, preserving
existing historical tests instead of deleting/weakening those contracts. New
focused tests cover the live direct path and absence of deployment workflow
hooks/needs. Old workflow tests are **historical compatibility checks**, not proof
that Actions ran. No CI status is synthesized as passing.

Retained: `firebase-release-monitor.yml` (drift/save alerts),
`app-update-news.yml` (explicit confirmed-release publishing), and
`native-development-readiness.yml` (manual read-only store/profile inventory;
no build, upload, gating check or deployment). Its same direct information commands
are `node tool/release/development_readiness.mjs ios|android`. Existing alert and
support runtime code is retained. The retired STA-191 webhook is not restored.

## Required-check migration and cutover

Ruleset **24924061** still requires `firebase-required` on main/develop until an
administrator applies the reviewed migration. Removing workflow files alone will
leave a PR waiting forever. The migration removes only that required CI context;
PR review/thread resolution, force-push/deletion protection, bypass actors and
all other parameters remain. Tag ruleset **25151950** is untouched.

The exact before/after payloads from the 2026-11-14 read are
`ruleset-24924061-restore.json` and `ruleset-24924061-direct.json`. Refresh the read
before applying so unrelated intervening changes are not overwritten:

```sh
gh api repos/hyroxseouldev/cloud_board/rulesets/24924061 > /tmp/cloudboard-ruleset-before.json
node tool/firebase/migrate-direct-rules.mjs /tmp/cloudboard-ruleset-before.json > /tmp/cloudboard-ruleset-direct.json
# Review the JSON diff; only firebase-required must disappear.
# Administrator action, NOT executed by this implementation:
gh api --method PUT repos/hyroxseouldev/cloud_board/rulesets/24924061 --input /tmp/cloudboard-ruleset-direct.json
```

The transformer has no write mode and preserves unrelated required checks.
Confirm the effective rules with `node tool/firebase/repository-rules.mjs check`.
It intentionally reports the dead context until migration occurs. A record check
or a removed required context is not a test result.

The coordinator owns PR integration/migration. First inventory and finish/cancel
old deployment runs explicitly; do not mix workflow and direct writers. Merge the
reviewed change into develop after the minimal rules migration. Main still has
its own files until separately integrated: use a **workflow/control-tools-only**
main PR for removal+receipt observers+required-rule expectations, preserving main
app/backend/version content. Do not promote all develop application changes just
to stop handoff emails. Review that source diff independently; opening a develop
PR may still trigger the old default-branch PR workflow before this cleanup.
No main push or protection change is a Firebase/store deployment.

### Recovery

A pending receipt is a lock, including a process killed during compilation.
Inspect the local receipt, provider history and current process first; establish
that the original writer stopped. Reconcile the same ID in the ledger using its
fresh Contents SHA and an administrator-reviewed JSON update. Preserve successful
steps and mark unknown/failed stages as failed, with a terminal `completedAt`;
never mark an unverified upload successful or delete an attempt to unblock a run.
If initialization stopped after branch creation but before the first ledger file,
inspect that branch and write the empty schema-1 ledger only after proving no
writer/service operation started. Retain the branch commit history.

After partial Firebase changes, reconcile from the same/newer fixed source and
verify actual rules/functions rather than falling back to an old green receipt.
After uncertain mobile upload, inspect the store and allocate a fresh number if
another build is needed. Never reuse Play reservation tags, move version tags or
retry an ambiguous store commit automatically.

Rollback of this tooling is a reviewed PR restoring the archived workflow sources
and old consumer code together. Restore the prior required-check payload **only
when its workflow exists on the relevant branches**, or merging deadlocks again.
Keep direct receipt history and installed-client records. Ruleset restore is a
separate administrator action, not an automatic part of application rollback.

## Timing evidence and limits

The reused comparison report's CloudBoard production run 41635107038 took 502s:
128s web job (62s Flutter compile), 210s combined functions/rules deploy step and
19s Hosting deploy. Heavy CI was already skipped in that sample. These are
historical Actions step observations, not measurements of this CLI.
Timo's local/CLI route is the relevant architecture comparison; its native full
build samples are not a rebuttal of a user's sub-minute incremental experience.
No same-scope warm direct CloudBoard/Timo deployment duration was measured here.
Direct elapsed time depends on selected scope, SDK/cache, signing and provider
work. The dry-run/fixture timings are **not** service deployment timings.

## Verification of this implementation

Focused Node script/receipt/workflow-fixture tests: **198 passed, 0 failed,
0 skipped** on Node 24 and repository Node 22 before final readback additions.
The added direct readback/receipt suite has **16 passed, 0 failed, 0 skipped**.
Integration on develop 2.1.6+10 repeated the 32 relevant source/environment/direct
tests successfully; unchanged historical checks reuse their existing results. Native
artifact Python fixtures: **5 passed**; iOS signing fixtures: **4 passed**.
Actual CLI dry-runs cover all six development scopes and produce plans only.
The first combined run found one historical fixture path still pointing to a
removed workflow; the path was corrected, without deleting/skipping its assertions.

The execution environment initially resolved Node 24 and no `flutter` in PATH.
Installed Node 22.21.1 and Flutter 3.47.8 were found at the existing local SDK
locations; execution requires Node 22 and the source-pinned Flutter version.
Set `FLUTTER_BIN` to the existing pinned SDK path if not on PATH. No SDK install,
full application build/test, Firebase deployment, canary write, store build/upload,
receipt-branch write, tag creation, ruleset update or policy enrollment was
performed in this implementation task. Provider/credential/signing acceptance and
real target elapsed times remain **unverified** until an authorized execution.
