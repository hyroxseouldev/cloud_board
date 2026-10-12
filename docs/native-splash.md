# Native startup · v5 Oat Sage

STA-121 uses the same [Soft Rhythm master](../assets/branding/soft_rhythm_mark.png)
on the native launch screen and Flutter bootstrap, on `#F7F5EF`.
The fixed artwork canvas is 128 pt/dp; the image is decoded at the current device
pixel density. The first native-to-Flutter handoff waits only for this local image
to decode. Framework frames and Firebase initialization continue in parallel;
decode failure or fast navigation also releases the first-frame gate. Retries and
auth routing keep their existing behavior. There is no timed branding hold. Native launch resources use the full
master canvas so the mark does not change position at the Flutter handoff.

## Artwork and regeneration

[Asset provenance and exact prompts](design/sta121-v5/assets.md) document the generated
transparent raster master. `tool/brand_asset_exporter.dart` only performs density,
background and platform-mask exports. Launcher tiles center the visible artwork;
near-transparent edge residue is excluded from optical bounds. iOS/macOS/store
icons are opaque RGB. Android adaptive foregrounds and web maskable icons keep
extra safe padding. Android TV retains the CloudBoard name with the new mark.

| Export | Size / purpose |
| --- | --- |
| `assets/branding/app_icon.png` | 1024 × 1024 opaque review/store master |
| `assets/splash/mark.png` | 512 × 512, 4x source for 128 pt/dp |
| `assets/splash/mark_android12.png` | 1152 × 1152 with centered 512 px canvas |
| iOS LaunchImage | 128 / 256 / 384 px |
| Android splash | 128 / 192 / 256 / 384 / 512 px |
| Launcher exports | Android legacy/adaptive/TV, iOS, macOS, web, Windows |

```sh
fvm flutter pub get
fvm flutter test tool/generate_android_launcher_test.dart
bash tool/generate_native_splash.sh
```

`flutter_native_splash` stays pinned to 2.4.8. The wrapper exports artwork, runs
the generator and normalizes Android day/night themes and system bars to the
light oat surface. It also preserves iOS light launch appearance. Generated
resources are committed; CI does not need to regenerate them. Web generation
is disabled: its HTML canvas and manifest theme use the oat color directly.

Android 12+ keeps the existing edge-to-edge first-resume configuration so native
and Flutter coordinates agree. Resource changes require a new native build/install
and a **cold launch**. Hot reload cannot verify an OS launch screen. Do not delete
user app data to clear an iOS cached launch snapshot.

Current verification is recorded in [design-qa.md](../design-qa.md). Physical-device
launch timing and manufacturer-specific masking remain later device QA, as requested.

## Historical STA-53 evidence

The following results refer to the previous white/vector artwork and **do not**
measure v5 startup performance.

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
