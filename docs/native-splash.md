# Native startup (STA-53)

The native launch screen and Flutter bootstrap/auth restoration now share a white
background and the existing CloudBoard monitor mark at 128 logical pixels. The
mark is centered independently from the progress indicator or retry message.

The first Flutter frame is still painted **before** Firebase/device initialization.
There is no minimum display duration, `deferFirstFrame`, `preserve`/`remove` call,
new splash route, or lifecycle listener that replays it on resume. Initialization
failure leaves native UI immediately and uses the existing Flutter retry flow.
Auth restoration, onboarding guards, deep-link destinations and TV authentication
keep their existing behavior. Web HTML/hosting, app icons and TV launcher banners
are outside this change.

## Artwork and regeneration

The geometry comes from the existing
`docs/play-store/ko-KR/assets/branding/app-icon-draft.svg`. Its matching vector
painter, `StartupMarkPainter`, renders the first Flutter frame synchronously,
without waiting for image decoding. The same painter exports the native artwork.

| Source/export | Size | Use |
| --- | --- | --- |
| `assets/splash/mark.png` | 512 × 512 | 4x source, 128 pt/dp iOS and older Android |
| `assets/splash/mark_android12.png` | 1152 × 1152 | Centered 512 px mark; all four corners fit inside the 768 px safe circle |
| iOS LaunchImage | 128 / 256 / 384 px | 1x / 2x / 3x, centered without scaling to the device |
| Android splash | 128 / 192 / 256 / 384 / 512 px | mdpi through xxxhdpi |

`flutter_native_splash` is pinned to **2.4.8** under dev dependencies. Configuration
is in `flutter_native_splash.yaml`; web generation is disabled. Run from the repo:

```sh
fvm flutter pub get
bash tool/generate_native_splash.sh
git diff -- android ios assets/splash
```

The wrapper first exports the vector, calls the package generator, then normalizes
Android day/night LaunchTheme and NormalTheme to the app's light appearance and
system bars. It also keeps iOS light at native launch. Use the wrapper rather than
only the package command: the package retains the template's black night theme.
Keep generated resource files in version control with the configuration, so CI
does not need to regenerate them.
Two consecutive wrapper runs were checked for identical file hashes.

Android 12+ centers its system splash across the full window. `MainActivity`
therefore configures edge-to-edge once, after Flutter's first `onPostResume`
restores system bars and before the first draw on API 31+, so the mark does not
shift by half the navigation bar height. Later resumes retain the player's own
system UI mode. Older Android keeps its
existing viewport, matching its `launch_background.xml` window.

Package behavior and Android 12 image requirements:
[flutter_native_splash documentation](https://pub.dev/packages/flutter_native_splash).

## Verification — 2026-09-30

- Flutter 3.47.0 / Dart 3.13.0: full suite **424 passed**, analyzer clean.
- Chrome startup-screen and auth-routing suite: **8 passed**.
- Native image tests: Android 12 circular safe area, iOS and Android density sizes.
- Widget tests: 320×568, 402×874, 1024×1366, 1920×1080, 568×320;
  centered fixed-size mark; large-text retry remains scrollable/clickable.
- Startup tests: pending initialization paints; failure can retry; TV result is
  preserved; resume does not initialize again; auth deep-link destination retained;
  new accounts still enter onboarding; logged-out routing is unchanged.
- iPhone 17 Pro / iOS 26.2 Simulator: native rebuild, cold start recorded,
  existing login restored to the home screen. The mark stays in place at handoff.
- iPad Pro 11-inch M5 / iOS 26.2 Simulator: same native bundle installed and cold
  start recorded; centered 128 pt mark confirmed without tablet enlargement.
- Android API 33 arm64 emulator: profile APK, repeated cold starts to login,
  light/dark launch recordings and native-to-Flutter alignment inspection.

Native resources require a new build/install and **cold launch**. Hot reload and
hot restart cannot verify the OS launch screen. iOS can cache an older launch
snapshot; do not delete a user's app/data merely to invalidate this cache.

Physical Android TV, Android 11 and older, and release/profile timing on physical
iOS devices remain release QA items. The TV-size widget and shared resources are
verified, but those are not a substitute for a real TV launch. Onboarding and
failure routes are covered by controlled tests, not by creating production accounts.

## Cold-start timing method

Same Pixel 3a API 33 arm64 AVD, profile build, signed-out account, SwiftShader,
existing data retained. A warm-up launch precedes each five-run group. Each run
force-stops the process, uses `adb shell am start -W`, then checks login controls
with `uiautomator dump`. No compilation runs during the measured group.

`TotalTime` is Android's Activity first-draw metric, a proxy rather than a direct
Flutter engine first-frame trace. The login verification time includes the slow
UIAutomator dump and is an **upper bound**, not the exact interactive-frame time.
Emulator results have substantial host-load variance; they do not establish
physical-device startup speed or a guaranteed speed improvement.

| Run | Before first draw (ms) | After first draw (ms) | Before login verified by (ms) | After login verified by (ms) |
| --- | ---: | ---: | ---: | ---: |
| 1 | 4466 | 2933 | 8279 | 6474 |
| 2 | 2298 | 1818 | 6201 | 5135 |
| 3 | 2075 | 1862 | 6235 | 5088 |
| 4 | 2774 | 1933 | 6794 | 5119 |
| 5 | 2498 | 1582 | 6384 | 4796 |
| Median | 2498 | 1862 | 6384 | 5119 |

All ten runs reached the signed-out login controls. No startup regression was
observed in this sample. Direct engine-frame timing and physical-device
interactive timing still require a release profiling pass.

Recordings, measurement results and remaining device checks are attached to STA-53.
