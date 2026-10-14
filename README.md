# cloud_board

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Firebase environments

Local runs default to `development`. The registered development project is
`cloud-board-development`; the existing production project remains
`cloud-board-stationd`. iOS and Android/TV development use the separate
`com.sunmkim.cloudboard.dev` application ID, so both apps can coexist.
Production bundle IDs, store records and user data are unchanged.

```sh
fvm flutter run --flavor development
fvm flutter run -d chrome --dart-define=FIREBASE_ENV=development
node tool/firebase/environments.mjs check
node tool/firebase/environments.mjs deploy development rules
```

Native Xcode builds must select `development` or `production`; the old unqualified
`Runner` scheme deliberately fails before copying Firebase credentials. Android
chooses its Firebase SDK file by flavor. The application rejects inconsistent
Firebase credentials/endpoints before initialization. Production debug runs also
require the explicit `--dart-define=ALLOW_PRODUCTION_DEBUG=true`; normal store
workflows build the production release flavor.

`firebase.development.json` and its guarded deploy command pin the development
project and database together. Changing only `firebase use` is insufficient and
must not be used to switch the production config's Storage target. The
**Deploy isolated development Firebase** workflow runs on `develop` pushes or a
manual `develop` dispatch, tests all client contracts, then publishes the isolated core backend, development
rules and web. Its OIDC identity is restricted to this repository, branch and
workflow and has roles only in the development project; no service-account key
or production deployment secret is used.

Development Auth (Google, email/password and anonymous TV login), Firestore and
Realtime Database are provisioned. Native Google callback configuration and this
machine's Android debug signing fingerprints are registered. Other Android
signing certificates need their own Firebase SHA registration. Apple Sign-In for
the new development bundle and physical-device provisioning still require
separate Apple setup. Google login configuration/build verification is not a
substitute for signing in on a real device.

The development project shares the approved Firebase billing account, but keeps
its own Storage bucket, databases, identities and server credentials. Its backend
allowlist contains 15 core Functions and uses a dedicated runtime identity.
Development onboarding simulates SMS only for an explicitly approved tester;
[development backend operations](docs/firebase-development-backend.md) documents
approval and one-time code retrieval. Production SMS, purchase and AI secrets
are not copied. AI generation and store-billing endpoints remain outside the
development allowlist until separately configured integration tests are needed.

The guarded web build stamps the Firebase environment and bundle digest. To
publish a development bundle manually:

```sh
node tool/firebase/environments.mjs build development
node tool/firebase/environments.mjs deploy development backend
node tool/firebase/environments.mjs deploy development rules
node tool/firebase/environments.mjs deploy development web
```

A production or overwritten web build is rejected by the development deployer.

For released-client support, store-independent repairs and client recovery see
[compatibility contracts](docs/released-client-compatibility.md),
[manual backend repair](docs/firebase-emergency-repair.md) and
[runtime policy and draft recovery](docs/operations/runtime-policy-and-recovery.md).
A new app baseline is required for local draft recovery and remote feature
controls; older installed versions remain protected by compatible server rules.

## Google Play deployment

Merges to `main` build one signed Android App Bundle for both mobile and
Android TV and upload it to the Google Play internal testing track. The
`google-play` GitHub environment must contain these secrets:

- `ANDROID_UPLOAD_KEYSTORE_BASE64`
- `ANDROID_UPLOAD_KEYSTORE_PASSWORD`
- `ANDROID_UPLOAD_KEY_ALIAS`
- `ANDROID_UPLOAD_KEY_PASSWORD`
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`

The Play Console app must use the package name `com.sunmkim.cloudboard`, have
Play App Signing enabled, and opt in to the Android TV form factor. Google Play
uses the same AAB to generate device-specific mobile and TV packages.

This workflow targets only the private `internal` testing track; it never
promotes a release to the public production track. See
`docs/android-tv-internal-test.md` for the one-time setup and tester flow.

## Firebase release safeguards

The complete rules gate, immutable deployment receipt, synthetic client smoke,
branch-protection setup, monitoring and recovery workflow are documented in
[Firebase release safety](docs/firebase-release-safety.md). The local/CI entry
point is `node tool/firebase_contracts.mjs` (Node 22, Java 21, pinned Flutter).

The Firebase workflow tests the app's actual serialized workout and summary
documents together, including create/update/duplicate writes, supported older
clients, ownership and transaction rollback. Run locally with Java 21:

```sh
fvm flutter test tool/export_workout_save_fixtures_test.dart
firebase emulators:exec --config firebase.deletion-test.json --only firestore --project demo-cloudboard-workouts 'node functions/test/workout-save-emulator.mjs'
```

Current payloads are generated in `build/contracts/`. Frozen supported-client
payloads live in `functions/test/fixtures/workout-save/`; keep these when adding
fields or new releases. Do not regenerate old fixtures to make a rule change pass.
Deploy rules that accept both existing and new clients before uploading clients.
Removing old fields requires a separate compatibility rollout.

TestFlight and Google Play uploads, including manual uploads, require a successful
Firebase deployment for the same current `main` commit. A failed, skipped, stale
or missing backend deployment blocks upload. Retry the Firebase workflow first,
then retry the mobile workflow; the gate checks the latest run attempt again
immediately before upload. The GitHub token needs `actions: read`.

Handled workout save/copy failures automatically reach Crashlytics on native apps
and the authenticated diagnostic queue on all platforms. Cloud Logging alerting
uses `client_diagnostic` events for `workout.save` and `workout.duplicate`, with a
30-minute notification rate limit. Error details are visible only in debug builds.
To idempotently configure the email recipient with Monitoring edit permissions:

```sh
node functions/tools/workout-save-alert.mjs cloud-board-stationd ALERT_EMAIL --apply
```

The image creation route owns a fresh, in-memory session. It asks before discarding
unfinished content; explicitly saved class templates remain in the library.

## Legacy app/TV server ownership

The active `cloudboard-auth` functions previously maintained in the landing
repository are now source-controlled in `functions-legacy/`. The three callable
endpoints and existing HTTP API retain their names, `asia-southeast1` region,
codebase, contracts and shared Secret bindings. `firebase.legacy-auth.json` and
its deployment guard are separate from the default `account-deletion` release.
See [migration and landing cleanup](docs/legacy-auth-migration.md) for source
parity, local checks, the reviewed deployment plan and recovery procedure.

The landing is a static introduction/download site. Its old Vercel variable
copies can be removed only through the project-specific cleanup plan; they are
separate from Firebase originals shared by app onboarding, account linking and
historical billing. The source migration does not deploy or retire these services.

## Operations history

The operations report queries the selected calendar interval in `Asia/Seoul`,
including more than 1,000 stored events, and pages the displayed records in groups
of 50. Device/workout filters affect the summary; the event-type filter affects
the list. Historical device names and versions come from event snapshots.

Counts describe recorded session starts and end commands, excluding example
workouts; an end command does not prove a class was completed by every TV.
Connection time sums TV intervals with both a start and an end, so three TVs
connected for one hour count as three hours. Missing boundaries are partial data.
Server disconnection, TV receipt confirmation and observed playback interruption
are distinct events. Recovery requires a compatible event with an explicit
incident link. Missing causes, versions and recovery times remain unknown.

Queries that fail or are still loading do not show zero statistics. An empty
stored history is not proof that no classes or incidents occurred. The former
scheduled-start percentage is replaced by recorded counts because historical
schedule changes and missed occurrences are not available for a reliable denominator.
Telemetry retries reuse the event ID, cannot block playback, and retain the
existing account/paired-TV access boundaries. The detail view passes existing
error/session IDs to the STA-171 support route when it is available; until then,
it offers a copyable support record without creating another notification service.

The `Operations and legacy server compatibility` workflow runs the targeted
client/server regressions for `develop` PRs. Native login/billing and the physical
three-TV prepare/start/pause/resume/end matrix remain release checks; widget,
contract and emulator tests do not substitute for those checks.
