# Home local icon cards — 2.1.8 feature handoff

Home list/grid thumbnails now use local Material icons and vector decoration. Stable workout IDs select four muted palettes, and the already-loaded module count selects an empty/single/multiple-slide icon. No image source is consumed by home cards, no extra detail/metadata request is added, and media elsewhere is unchanged. Below 360px, existing play/more buttons stack vertically to preserve text space; the slide count precedes the folder so truncation keeps the count visible.

## Source and scope

- Clean Orca child branch `hyroxseouldev/home-icons-2-1-8` from `origin/develop` at `00a004fd1ab1a50a0baee5e96c532be237cd6ee2`.
- Final handoff SHA is recorded in the PR; commands below ran on the identical Dart source before the feature commit. Only documentation/evidence was added afterwards.
- Production edits: `workout_list_screen.dart`, presentation-only `workout_icon_tile.dart`.
- No provider, repository, backend, schema, preparation/player, version, release-note, deployment, or unrelated media changes. Original developer checkout was not modified.

## Validation

Flutter SDK: `/Users/sunmkim/fvm/versions/3.47.8/bin/flutter`.

```sh
flutter analyze --no-pub lib/src/app/feature/workouts/presentation/views/workout_list_screen.dart lib/src/app/feature/workouts/presentation/widgets/workout_icon_tile.dart test/home_icon_cards_preview.dart test/home_workout_list_test.dart
flutter test --no-pub test/home_workout_list_test.dart test/home_workout_loading_test.dart
flutter run --no-pub -d web-server -t test/home_icon_cards_preview.dart --web-hostname 127.0.0.1 --web-port 8808
```

- [Analyze](analyze.log): no issues.
- [Widget tests](tests.log): 68 passed, 1 existing optional screenshot-evidence test skipped. Includes remote media URL with no `WorkoutImage`/`Image` instantiated in the home scroll content at phone/grid widths; enabled play callback and edit/copy/delete menu retained. Existing tests cover search, folder filtering, pagination, refresh failure/recovery, empty/loading/error states, edit locks, responsive bounds and text scale up to 2.
- Initial new test assertions were corrected to scope image absence to home content (the app logo is intentionally still an image) and to locate the actual IconButton rather than its RawTooltip. Final log contains the passing run.
- Actual production Flutter screens in Orca internal browser, local fixture providers/repository only. No Firebase initialization, callable, production user data, or production images. Baseline media is a bundled sample asset. Port 8808 was free in `orca ports --all`; the other worker's 8796 server was left alone.
- Browser debug startup logged a Flutter `debugFrameWasSentToEngine` assertion on the unmodified baseline, and hot restart briefly showed a blank page; full reload restored the fixture. This is not reported as a clean browser-console run. Final screenshots show no layout overflow; widget layout tests pass.

| View | Before | After |
| --- | --- | --- |
| Phone 390×844, 1× text | [Before](before-390.png) | [After](after-390.png) |
| Grid 1387×958, 1× text | [Before](before-grid.png) | [After](after-grid.png) |
| Narrow 320×844, 1.3× text | Existing baseline truncation observed | [After](after-320-scale1.3.png) |

## Limits and integration

Performance percentage/timing: not measured; the removed home image-widget path is verified directly. Actual media remains available in other screens. Long text still uses existing ellipsis rules, with slide count prioritized. Server writes are unchanged; real save/callable checks are not applicable. Full suite, full integration CI, mobile builds, real-device checks, TestFlight/store uploads and deployment: **미실행**. Preparation/slide flicker changes and 2.1.8+12 version metadata belong to the other worker and require coordinator integration. No merge, tag, main change, or deployment was performed by this worker.
