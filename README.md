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
