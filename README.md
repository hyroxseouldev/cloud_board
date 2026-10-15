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

## Integration and tagged deployments

`main` pushes integrate code only; they do not deploy. The current deployment
policy is [feature verification](docs/feature-verification.md).

| Trigger | Target | CI policy |
| --- | --- | --- |
| `dev/vX.Y.Z-N` tag in main history | Development web/server and `.dev` mobile apps using `cloud-board-development` | No full integration CI by default; required source, environment, build and artifact checks remain |
| `vX.Y.Z` tag in main history | Production web/server and base-ID mobile apps using `cloud-board-stationd` | Required CI by default; explicit manual `skip_ci` with a reason is available |

Finalize the displayed version in `pubspec.yaml` on main before creating either
tag, and sync that version commit back to develop. Same-version rebuilds use
automatically increasing platform build numbers. A release commit title such as
`release: CloudBoard 1.2.2 - 주요 변경` and its body record the version, changes,
deployment intent, development/production tags and CI policy; they do not prove
deployment completed. Manual mobile QA also requires a version-matched development
tag whose source is in main history.

The **Start production release** Actions menu creates production tags only and
does not automatically change the version. To start development deployment after
the version commit is on main:

```sh
git tag dev/v1.2.2-1 <version-commit-main-SHA>
git push origin refs/tags/dev/v1.2.2-1
```

Prepare user-facing [app update news](release-notes/README.md) from the diff between
each platform's previous actual deployment SHA and the candidate main SHA. Commit
the summary with the candidate version in `release-notes/current.json`; raw commit
bodies are not app copy. Successful deployment/upload evidence controls exposure.

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
**Deploy isolated development Firebase** workflow runs from a `dev/vX.Y.Z-N` tag,
including a manual retry of that tag, and publishes the isolated core backend,
development rules and web without requiring full integration CI. Its OIDC identity
is restricted to this repository, development tag refs and
workflow and has roles only in the development project; no service-account key
or production deployment secret is used.

Development Auth (Google, email/password and anonymous TV login), Firestore and
Realtime Database are provisioned. Native Google callback configuration and this
machine's Android debug signing fingerprints are registered. Other Android
signing certificates need their own Firebase SHA registration. Apple Sign-In for
the development Firebase provider still requires separate setup. iOS development
signing for installation on a device is already prepared; App Store Connect/Play
registration and store distribution signing/upload readiness remain separately
unverified. The QA store workflows require `MOBILE_DEVELOPMENT_READY=true` in each
applicable GitHub Environment before costly builds. Google login configuration/build verification is not a
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

Development tags build the `.dev` app; production tags build the base-ID app after
the applicable CI policy. Each produces one signed Android App Bundle for mobile
and Android TV and uploads it to that app's Google Play internal testing track
when store readiness and upload checks pass. Main pushes do not upload. The
`google-play` GitHub environment must contain these secrets:

- `ANDROID_UPLOAD_KEYSTORE_BASE64`
- `ANDROID_UPLOAD_KEYSTORE_PASSWORD`
- `ANDROID_UPLOAD_KEY_ALIAS`
- `ANDROID_UPLOAD_KEY_PASSWORD`
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`

The Play Console app must use the selected package name (`com.sunmkim.cloudboard.dev`
for development, `com.sunmkim.cloudboard` for production), have Play App Signing
enabled, and opt in to the Android TV form factor. Each app has separate build
number allocation and upload concurrency. Google Play
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

Production TestFlight and Google Play uploads require the fixed production tag's
CI evidence or explicit audited CI skip, plus compatibility with the actual
deployed production backend. A matching backend can come from an earlier source;
an unrelated main advance does not invalidate the fixed release. Missing,
incompatible or partially failed backend evidence blocks upload. Development QA
uses its development tag and Firebase project and does not require a production
backend receipt. See [native release checks](tool/release/README.md).

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

For manual operations/legacy diagnostics, run `firebase-hosting-merge.yml` from
`main` with `scope=verify` and `confirm_sha` set to that main commit. This runs the
app tests, operations-history emulator contract and legacy build/source/release
checks without production deployment. The duplicate `operations-compatibility`
workflow has been removed. Native login/billing and the physical three-TV
prepare/start/pause/resume/end matrix remain release checks; widget, contract and
emulator tests do not substitute for those checks.
