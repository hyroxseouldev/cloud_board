# Native release identity and build numbers

Marketing version comes from the selected app source's `pubspec.yaml`. Production
Android/TV share `com.sunmkim.cloudboard` and one Play versionCode sequence. The
development app `com.sunmkim.cloudboard.dev` has a separate sequence; iOS also uses
a separate App Store Connect build sequence for each bundle. Neither helper changes a minimum supported
client version, a release-policy document, a store track, or store review state.

## Development-app QA and tagged production

`main` is the integration branch; merging or pushing to it does not start mobile
deployment. A `dev/vX.Y.Z-N` tag on main history starts the **existing development
app** path for TestFlight/Play internal QA, building only after store readiness is
confirmed. The tag version must match `pubspec.yaml`. No whole-app/TV suite or
production backend rollout is repeated.

Automatic production `vX.Y.Z` tags run required CI by default in
`firebase-hosting-merge.yml`. Native production workflows are configured to follow
a completed successful release workflow (`workflow_run`); confirm that those runs
actually start, using the manual fallback below if absent. An unfinished or failed
run does not authorize automatic upload. The source tag must still point to the
recorded SHA, be in main history, and match the selected `pubspec.yaml` version. The exact
source's common CI evidence or an explicit audited manual skip is checked before
upload, along with live production backend compatibility. Native workflows do
not deploy Firebase or Hosting.

| Route | App bundle/package | Firebase | Store destination |
| --- | --- | --- | --- |
| Development tag / manual `qa` | `com.sunmkim.cloudboard.dev` | `cloud-board-development` | Development app's TestFlight / Play internal |
| Release tag / manual `release` | `com.sunmkim.cloudboard` | `cloud-board-stationd` | TestFlight / Play internal |

Both routes can use the existing store-account authentication in GitHub environments
`testflight` and `google-play`, but app registration and signing/upload access must
be verified for each app. Build-number sequences and upload concurrency groups
are separate per app. Actual
signed AAB/IPA native settings and compiled Dart markers must match the selected
environment: development for QA, production for release. Development-tag web/server
and mobile QA share `cloud-board-development`.
Neither route automatically submits public App Store/Play review, changes tester
groups, or promotes a public store release. TestFlight distribution follows the
existing App Store Connect groups; QA is not Apple's “TestFlight Internal Only”
export restriction. Store processing and any later review remain external steps.

Manual runs use the trusted workflow **from main** and select `source_ref`:
QA accepts only a `dev/vX.Y.Z-N` tag; production release accepts only a `vX.Y.Z`
tag. Both must be in main history and match the selected marketing version.
Preflight pins the source SHA and the upload job verifies it again. Branches, raw
SHAs and fork URLs are rejected. `upload_to_testflight=false` or
`upload_to_play=false` keeps a signed artifact only (default false);
signing/version/artifact checks still run, while
store upload, Crashlytics upload and deployment gates are skipped. Automatic
development-tag/release-workflow runs request upload after the applicable
compatibility and artifact checks.

### Start a new production release

Use **Actions → Start production release → Run workflow** from `main`. Enter a
new `tag` matching that commit's `pubspec.yaml` version, choose `scope` (`full` by
default, or `web` / `backend` / `rules`), and leave `skip_ci=false` for normal CI.
To explicitly omit heavy CI, select `skip_ci=true` and provide `skip_ci_reason`.
The source is the main SHA captured when this run starts; a later main update does
not silently change the release candidate.

This menu checks main ancestry and the app version, rejects an existing tag or
past Firebase workflow history for that tag, creates the immutable tag with the
workflow's `GITHUB_TOKEN`, then dispatches the Firebase release workflow once from
that tag. GitHub does not start a tag-push workflow for this token's tag creation;
the explicit `workflow_dispatch` starts the requested run. This avoids launching
both default push CI and a separate manual skip run. External/manual tag pushes
still start default CI. See [GitHub's workflow trigger rules](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow).

The `release-start-<run>-<attempt>` artifact records the original actor, tag,
source SHA, scope, CI choice/reason and dispatch status in `release-start.json`.
An accepted dispatch is not a deployment or CI success. If tag creation succeeds
but dispatch fails or times out, the tag stays in place and the starter does not
retry or delete it. First check Actions for an accepted run; if none exists, use
the Firebase release workflow's manual retry from that exact tag, with the
recorded `confirm_sha`, scope and CI choice. Do not rerun the starter to reuse a
tag, and do not delete or move the tag.

After Firebase finishes, verify the actual deployment steps and successful backend
receipt; the overall workflow conclusion alone does not prove deployment. Then
check for native runs for that release tag. If none starts, dispatch each missing
native workflow from `main`, using the same `source_ref=vX.Y.Z`,
`release_mode=release` and `upload_to_play=true` or `upload_to_testflight=true`.
Use `skip_ci=false` to reuse the successful tag validation or its audited skip;
an explicitly requested native skip instead requires `skip_ci=true` and a
non-empty `skip_ci_reason`. Do not dispatch a duplicate while a run for that
platform and tag is queued or running. Both paths retain the backend compatibility
checks before building and uploading.

Production internal testing is a stage before store availability. The same
verified production build can later be promoted through the store's release
process; that transition does not itself require CI skipping or a separate
production QA mode. Development-tag QA remains the separate `.dev` app and
development Firebase.

### Explicit manual CI skip

Both manual Firebase tag releases and manual native `release` runs accept
`skip_ci` (boolean, default `false`) and `skip_ci_reason` (required and non-empty
when skipping). Firebase requires dispatching from the release tag, the matching
`confirm_sha`, and an actual deployment scope: `full`, `backend`, `rules` or `web`.
Main/`verify` and mobile QA reject the skip option. Automatic tag pushes retain
required CI by default.

For server/web, use Actions manual dispatch on a tag that contains this workflow
version. An older tag's workflow may not support the new inputs. Pushing a tag
starts the default CI run; `skip_ci` is not a tag-creation option. Starting a
separate manual skip run does not alter the already-started automatic run.

The skip omits heavy app validation, class-start regressions and Firebase emulator
contracts. It does not omit exact tag/SHA/main ancestry/version checks, required
builds, signing, environment identity, build numbering, artifact/manifest checks,
post-deployment smoke or native production backend compatibility. Web builds still
run when the selected scope needs them. Deployment remains limited to that scope.
When CI is skipped for `backend`, `rules` or `full`, the two candidate DTO exporters
separately create the live-smoke inputs; source SHA, file list and hashes are verified before writes.
Generating those inputs is not a passing app or emulator-contract CI result.

Firebase writes `release-validation-<run_id>-<run_attempt>` with a `release.json`
audit record containing `schemaVersion: 1`, `kind: release-validation`, `sourceSha`,
`releaseTag`, `runId`, `runAttempt`, `validationMode: required | skipped`, `reason`
and `actor`. `required` records the requested mode, not passing test results.
`skipped` is explicitly reported as `CI SKIPPED`, never as CI success.

A manual native release can request its own skip without a prior Firebase skip
receipt. An automatic native continuation may inherit a Firebase skip only after
checking that successful trusted release run's exact run/attempt, SHA and tag.
Mobile receipts preserve the skip source, reason, actor and execution details.
Ordinary release uploads still require actual CI evidence; QA and build-only
runs record that the release CI proof was not requested.

### Development app readiness and environment boundaries

The `.dev` Firebase SDK registrations/configuration already exist. Its App Store
Connect / Play registration, signing and upload readiness are still unverified.
After confirming these for each platform, set `MOBILE_DEVELOPMENT_READY=true` in
that platform's GitHub Environment. Otherwise preflight reports blocked and stops
before SDK installation, build and upload, including manual QA build-only runs.
The development Play baseline file is not yet present; prepare it from the actual
development app's complete store history. Do not reuse production's baseline.
QA uses the development flavor and `.dev` app ID; release uses production and the
base app ID with exact-tag CI evidence or an explicit audited manual skip.

QA does not require a production backend receipt. Release checks the actual
production receipt against candidate backend/rules fingerprints before native
build and again before upload. Development deployment is not release evidence.

Development QA does not publish public news, modify version policy or replace
production installed-client contracts. Historical QA uploads that actually used
production Firebase remain in that ledger. Schema 3 receipts require the app
package and environment to agree with the QA/release mode; historical
schema 1/2 receipts retain their original identity rules.

The separate app IDs use their existing app sandboxes, and web environments use
separate origins. A QA binary must not be promoted to public release: build and
validate the production flavor instead.

Every artifact has a `mobile-source-<run>-<attempt>` receipt with separate app
source SHA and workflow SHA, mode, **verified environment**, Firebase identity,
version/build and artifact hash. Release-mode receipts also require the release
tag; QA receipts do not. Guard tools run in the trusted workflow checkout (`control/`), compilation in
`app/`. News and compatibility tracking read the app source from that receipt.

AAB/IPA inspection checks version/build, package/bundle, native Firebase
project/app/database/bucket and the compile-time Dart environment/flavor marker in
every architecture. Cross-environment combinations are rejected. AAB signing must
match the configured Play upload certificate; IPA entitlement/profile checks remain
mandatory. Bundletool is pinned to 1.18.3 and its release asset SHA-256.

## Play versionCode issuance

`play_version_code.mjs --reserve RECEIPT.json`:

1. Reads current tracks, bundles and APKs in a temporary uncommitted Play edit,
   then deletes the edit. Read errors fail closed.
2. Combines these values with the selected app's complete historical upload
   baseline and reservations: `refs/tags/play-version-code-development/N` for
   development, `refs/tags/play-version-code/N` for production.
3. Atomically creates the next unused reservation tag, including on reruns and
   build-only jobs. Competing allocations retry; other failures stop the build.
4. Writes the receipt (source SHA, run/attempt, store observation and baseline).

The Play API describes **current** bundles, not every discarded historical
upload. Therefore the initial reservation requires a complete Play Console App
Bundle Explorer inspection within 24 hours, recorded in the app-specific file:
`play-version-code-baseline.json` for production or
`play-version-code-baseline-development.json` for development. The latter does
not yet exist. The authenticated October 12 production inspection found 47 bundles
and highest-ever code 65; see the linked store inventory evidence. This is not a
development-app baseline. If the first reservation happens later, refresh that
app's inspection and baseline.

All future manual builds/uploads must use this allocator too. Never delete or
reuse a reservation tag, including a failed/unuploaded build. If someone uploads
an artifact built outside this allocator, recheck complete Play Console history
and update the baseline before issuing another code. The API and tag history
cannot prove absence of arbitrary out-of-band historical uploads.

The allocator requires `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`, `GITHUB_TOKEN`
(contents write), `GITHUB_REPOSITORY`, and the exact app `SOURCE_SHA` (historical
same-source workflows fall back to `GITHUB_SHA`); workflow jobs
also provide `GITHUB_RUN_ID`/`GITHUB_RUN_ATTEMPT`. `--inventory-only` needs only the
Play credential and never reserves a tag. `--recheck RECEIPT.json` verifies the
reservation and that Play has not advanced past it. Do not print credentials.

## iOS numbering

`ios_build_number.mjs --next` selects `IOS_BUNDLE_ID` and traverses all App Store Connect build pages and
chooses the maximum existing numeric build plus one. A verified development app
with no builds starts at 1; missing production build history still fails closed. This fixes relying on the
most recently uploaded build, which can be smaller than an older upload. The
workflow serializes runs for the same app; `--recheck` rejects a build if another upload advanced
App Store Connect while it was compiling. This does not change the reviewed or
publicly released iOS marketing version.

## Focused verification

```sh
node --test tool/release/*.test.mjs
python3 -m unittest discover -s tool/release -p 'test_*.py'
flutter test test/firebase_environment_test.dart
```

Official API contracts:

- [Play current bundles](https://developers.google.com/android-publisher/api-ref/rest/v3/edits.bundles/list)
- [GitHub atomic reference creation](https://docs.github.com/en/rest/git/refs#create-a-reference)
- [Dart AOT entry-point retention](https://github.com/dart-lang/sdk/blob/main/runtime/docs/compiler/aot/entry_point_pragma.md)
