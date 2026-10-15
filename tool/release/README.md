# Native release identity and build numbers

Marketing version comes from the selected app source's `pubspec.yaml`. Android/TV share
`com.sunmkim.cloudboard` and one Play versionCode sequence; iOS retains its own
App Store Connect build sequence. Neither helper changes a minimum supported
client version, a release-policy document, a store track, or store review state.

## Manual QA, release candidate and build-only

Run the native workflow **from main**, then choose the app code using `source_ref`.
It accepts `main`, `develop`, a `release/*` branch, tag name or full SHA in this
repository. The reference resolves once to an immutable commit. QA sources must
already be in main/develop history; release sources must be in main history.
Unmerged branches, fork URLs and tags pointing outside that history are rejected.
Tags are optional and never trigger a build automatically.

- `release_mode=qa` (default): build and optionally upload for QA without repeating
  whole-app/TV integration tests or waiting for a server/Hosting deployment.
- `release_mode=release`: upload requires successful common main validation for
  the exact app source. The latest validation attempt's actual app/class-start
  jobs must pass; a green PR handoff check is insufficient.
- Both upload modes immediately verify compatibility with the currently deployed
  backend. New undeployed Functions/rules cannot be bypassed by calling the build
  QA. The workflow never deploys the backend or web app.

To retain signed artifacts without uploading, use:

- Google Play: `upload_to_play=false`
- TestFlight: `upload_to_testflight=false`

Both default to false. Build-only runs retain the production flavor with
`FIREBASE_ENV=production`, signing and final AAB/IPA checks. They skip backend
compatibility and common release-validation gates, store upload, and iOS
Crashlytics symbol upload. A successful build is not a production publication
approval. Feature developers provide their relevant test evidence separately.

QA uses the existing production bundle/package and Firebase project. It does not
mean an isolated development backend. Google Play uploads remain on the internal
track; TestFlight uploads follow the existing App Store Connect tester-group
settings. This workflow does not change those groups, submit external beta review
or submit App Store review. `qa` is our workflow mode, not Apple's distinct
“TestFlight Internal Only” export restriction. Apple processing and any required
review still occur after upload.

QA runs never publish app update news or alter minimum/latest-version policy.
Production-connected QA installations still belong in the installed-client
compatibility ledger before changing their server contract.

Every artifact has a `mobile-source-<run>-<attempt>` receipt with separate app
source SHA and workflow SHA, mode, Firebase identity, version/build and artifact
hash. Guard tools run from the trusted workflow checkout (`control/`); app
compilation runs from the selected commit (`app/`). This prevents workflow HEAD
from being mistaken for the app source. Release news reads that same source.

The AAB/IPA reports verify marketing version, platform build number, production
package/bundle ID, embedded native Firebase project/app/database/bucket identities,
and the compile-time Dart environment/flavor marker in every native architecture.
AAB signing must match the configured Play upload certificate. Existing IPA
entitlement/signing checks also remain mandatory. Bundletool is pinned to 1.18.3
and its GitHub release asset SHA-256. Artifact SHA-256 is included in each report.

## Play versionCode issuance

`play_version_code.mjs --reserve RECEIPT.json`:

1. Reads current tracks, bundles and APKs in a temporary uncommitted Play edit,
   then deletes the edit. Read errors fail closed.
2. Combines these values with the complete historical upload baseline and all
   `refs/tags/play-version-code/N` reservations.
3. Atomically creates the next unused reservation tag, including on reruns and
   build-only jobs. Competing allocations retry; other failures stop the build.
4. Writes the receipt (source SHA, run/attempt, store observation and baseline).

The Play API describes **current** bundles, not every discarded historical
upload. Therefore the initial reservation requires a complete Play Console App
Bundle Explorer inspection within 24 hours, recorded in
`play-version-code-baseline.json`. The authenticated October 12 inspection found
47 bundles and highest-ever code 65; see the linked store inventory evidence.
If the first reservation happens later, refresh that inspection and baseline.

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

`ios_build_number.mjs --next` traverses all App Store Connect build pages and
chooses the maximum existing numeric build plus one. This fixes relying on the
most recently uploaded build, which can be smaller than an older upload. The
workflow serializes runs; `--recheck` rejects a build if another upload advanced
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
