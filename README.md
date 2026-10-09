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
