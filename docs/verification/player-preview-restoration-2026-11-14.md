# Playback UI restoration — 2026-11-14

## Scope and source

- Baseline: `8fc51e9bee125709923c8046f07f9f1ec4d9cd72` (`origin/develop`, shipped development 2.2.1(5)). Source version remains `2.2.1+13`.
- Rendering commit: `4f2dc4abd51fd12b09481ca7a0393cbd2a0d1c57`.
- Shared Sonner dependency: `0de8f9864788af21682f23cbce35c978bcd8c73f`, merged without rewriting its commit via `cc3dea919f33547a79d0bb2becefde1006756afa` at the coordinator's request.
- Countdown error integration: `7daf2a0cfde5945025c10db144d1c40477720c1a`.
- This worker changed player/control-panel/countdown rendering and focused tests/docs. The dependency commit owns app/root toast/auth/active-class changes. No preparation, controller, router, backend, version, dependency or lockfile implementation changes were made by this worker.

The user's latest requirement supersedes playback's former zero-image/on-demand-preview policy. Controllers now show the lazy carousel immediately; the preview open/close state and substitute dropdown are removed. The existing timeline picker remains. Current/adjacent slides retain the same Canvas/Image/provider ancestry. Controllers still skip the separate image warmup, and preparation remains text-only with zero media loads.

Countdown uses the authored image and the existing overlay color, opacity, number, title and fallback calculations. Before the change, suppression replaced `customImage` with an empty value and changed the fallback overlay as well as hiding the image. No saved settings or defaults were changed. Rendering was compared with stable 2.1.6 source `ff1eb303332c9f532ccf84124d8e28223565033e`; the countdown restoration matches that rendering logic. The subsequent integration routes only defaults load/save **failure** to the shared Sonner host; successful saves and stale-edit notices retain their prior feedback.

## Validation

SDK: `/Users/sunmkim/fvm/versions/3.47.8/bin/flutter` (existing 3.47.8). Dependencies resolved offline with no lockfile change.

Evidence root: `/Users/sunmkim/CloudBoard-release-artifacts/2.2.1-playback-sonner-fix/player`.

All executed tests are Flutter VM unit/widget tests with fake repositories/session streams/platform channels. Images are generated locally or delivered by an in-memory fake cache as real PNG bytes. There was no Firebase SDK connection, real HTTP image download, production image, account login, callable write, physical TV or iPhone test.

| Check | Actual source | Result | Evidence |
| --- | --- | --- | --- |
| Focused renderer/controller/countdown/audio/local-start tests, 8 files | `4f2dc4abd51fd12b09481ca7a0393cbd2a0d1c57` | 64 passed, 2 pre-existing failures; command exit 1, **not** an all-pass suite | `verified-rendering-tests.log` |
| Focused analyze, 3 implementation + 6 test/fixture files | Same rendering SHA | No issues | `verified-rendering-analyze.log` |
| Unchanged timeline test with exact baseline production sources | `8fc51e9bee125709923c8046f07f9f1ec4d9cd72` | 9 passed, same 2 failures | `baseline-timeline.log` |
| Countdown preferences/configuration and zero-target integration tests | `7daf2a0cfde5945025c10db144d1c40477720c1a`, with exact Sonner dependency above | 26 passed | `sonner-integration-tests.log` |
| Countdown implementation + preferences test analyze | Same integration SHA | No issues | `sonner-integration-analyze.log` |
| Local before/after fixture visual inspection | Baseline before; rendering SHA after | Visible carousel and authored countdown image restored | PNGs below |

The unchanged `workout_timeline_seek_test.dart` cases `remote partial seek preserves paused=true/false and rolls back failure` expect index 1 but observe index 0 at the first post-command assertion. Both were reproduced with baseline production files restored temporarily and then the restoration changes reinstated; the original test and PlayerController remain unchanged. No failing assertion was removed, skipped, or relabeled as passed. The coordinator was informed and requested that this unrelated failure remain outside this restoration.

The passing tests cover immediate selected-TV/legacy/zero-TV carousels; absence of toggles; bounded lazy page construction (30-slide fixture); next/swipe/jump and failed-command rollback; touch locks; timer/pause/resume/seek behavior; unchanged ImageState/provider across timer ticks and 0→1→0 changes; new source decoding different actual PNG pixels; custom countdown/default overlay, explicit overlay color/opacity, disabled overlay, no-image color and slide fallback; countdown skip/audio; and defaults failure Sonner with successful retry feedback.

The actual router/local-start fixture retains preparation admission/access gates, duplicate-start guard, empty-workout/denial/cleanup-failure checks, owned candidate cancellation and pre-existing remote session safety. For both zero registered TVs and two registered/all deselected TVs: preparation media loads = 0, displayed playback media loads = 2 (countdown then slide, fake transport), external HTTP = 0, remote writes = 0, existing remote session unchanged. The two-registered case cancels exactly its owned preparation candidate.

### Commands

```sh
/Users/sunmkim/fvm/versions/3.47.8/bin/flutter test --no-pub --concurrency=1 \
  test/workout_control_panel_test.dart test/countdown_configuration_test.dart \
  test/player_rebuild_performance_test.dart test/zero_target_class_start_test.dart \
  test/playback_restoration_capture_test.dart test/countdown_skip_test.dart \
  test/countdown_audio_test.dart test/workout_timeline_seek_test.dart \
  --dart-define=STA190_EVIDENCE=/Users/sunmkim/CloudBoard-release-artifacts/2.2.1-playback-sonner-fix/player/after

/Users/sunmkim/fvm/versions/3.47.8/bin/flutter analyze --no-pub \
  lib/src/app/feature/workouts/presentation/views/workout_player_screen.dart \
  lib/src/app/feature/workouts/presentation/widgets/workout_control_panel.dart \
  lib/src/app/feature/workouts/presentation/widgets/workout_countdown.dart \
  test/workout_control_panel_test.dart test/countdown_configuration_test.dart \
  test/player_rebuild_performance_test.dart test/zero_target_class_start_test.dart \
  test/playback_restoration_capture_test.dart test/support/playback_image_cache_fixture.dart

/Users/sunmkim/fvm/versions/3.47.8/bin/flutter test --no-pub --concurrency=1 \
  test/countdown_preferences_test.dart test/countdown_configuration_test.dart \
  test/zero_target_class_start_test.dart

/Users/sunmkim/fvm/versions/3.47.8/bin/flutter analyze --no-pub \
  lib/src/app/feature/workouts/presentation/widgets/workout_countdown.dart \
  test/countdown_preferences_test.dart
```

### Screenshots (fake local widgets, not native app/E2E)

Relative to the evidence root:

- `before/controller-fake-session.png` / `after/controller-fake-session.png`
- `before/custom-countdown-fake-session.png` / `after/custom-countdown-fake-session.png`
- `after/local-fixture-0-tv-start-enabled.png`, `after/local-fixture-0-tv-timer-controls.png`
- `after/local-fixture-2-tv-start-enabled.png`, `after/local-fixture-2-tv-timer-controls.png`
- `after/row-initial.png`, `after/row-selection.png` (frame captures without extra settle to hide flicker)

The capture fixture uses generated geometric PNG artwork and a fake selected-TV session. The production source for before capture was the baseline; after captures were generated on the rendering commit. Later shared-toast integration does not change these renderer paths; the countdown configuration and affected navigation fixture were rechecked after dependency integration. Docs-only handoff changes reuse the recorded source results.

## Handoff and limits

Feature PR targets `develop`; coordinator owns dependency ordering, integration, any merge and fresh development TestFlight build. Merge the Sonner PR first so the player PR's final diff contains its own files. No main merge, archive, native build, upload, deploy, rule/IAM change or production action was performed here. Full CI, full suite, Firebase contracts and physical/native-device checks are **미실행/미확인**. These results do not certify TV delivery, native image transport, Firebase persistence, store upload or public release. Keep this child worktree until coordinator cleanup.
