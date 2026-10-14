# Native release identity and build numbers

Marketing version comes from `pubspec.yaml` (currently `1.1.1`). Android/TV share
`com.sunmkim.cloudboard` and one Play versionCode sequence; iOS retains its own
App Store Connect build sequence. Neither helper changes a minimum supported
client version, a release-policy document, a store track, or store review state.

## Prepare signed artifacts without publishing

Run the existing native workflow on `release/*` (or `main`) with:

- Google Play: `upload_to_play=false`
- TestFlight: `upload_to_testflight=false`

Both default to false for manual dispatch. These runs still test the application,
build the production flavor with `FIREBASE_ENV=production`, sign it, and inspect
the final AAB/IPA. They skip the deployed-backend requirement and store upload;
iOS also skips Crashlytics symbol upload. A successful preparation run is **not**
a production publication approval. Actual upload paths retain the exact-main-SHA
backend gate and recheck the current store build history immediately before upload.

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
(contents write), `GITHUB_REPOSITORY`, and the exact `GITHUB_SHA`; workflow jobs
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
