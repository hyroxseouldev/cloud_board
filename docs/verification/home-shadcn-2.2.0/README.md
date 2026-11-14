# Home shadcn presentation — 2.2.0

The approved preparation page's sage/cream direction now extends to home through actual `shadcn_ui 0.59.0` widgets. The greeting is compact, observed display status remains actionable, and each class has local artwork, loaded slide/duration metadata, a folder badge, and separate 48px play/menu controls. The create action stays singular. Tablet cards use two columns when width and text permit; enlarged text returns to one column.

## Scope and source

- Clean Orca child `hyroxseouldev/home-shadcn`, based on `origin/develop` at `9c7dc4360d2ffe657e0af1317381f9207dde0a9e`.
- Production files: `workout_list_screen.dart`, new `home_shadcn.dart`, and home grid geometry in `workout_list_loading.dart`.
- Concrete widgets: `ShadCard` (class/connection), `ShadButton` (create/play/display), `ShadBadge.secondary` (folder), `ShadInput` (search), `ShadSelect` / `ShadOption` (existing folder metadata). Edit/copy/delete and list-mode menus retain their established Material popup behavior.
- `HomeShadcnScope` installs local ShadTheme/localizations/component overlays with existing AppColors and Pretendard. A regression test verifies that the Material Theme and Navigator seen inside home are identical to those outside it. Bottom navigation, router, preparation, player, editor and backend files are unchanged.
- Search, filter, list/page, refresh, edit-lock, action and repository/provider ownership remain in place. Folder selection uses already-loaded names. No extra detail reads, class images, media loads, fabricated statistics or decoration APIs.
- `pubspec.yaml` / lockfile unchanged; source version **2.2.0+12**. Offline pub get only recreated local tool configuration.
- Final PR head SHA is recorded in the PR. Checks ran against base SHA plus the exact production/test/fixture changes included in the feature commit; only documentation/evidence was collected afterward.

## Validation

SDK: `/Users/sunmkim/fvm/versions/3.47.8/bin/flutter` on macOS.

```sh
flutter analyze --no-pub \
  lib/src/app/feature/workouts/presentation/views/workout_list_screen.dart \
  lib/src/app/feature/workouts/presentation/widgets/home_shadcn.dart \
  lib/src/app/feature/workouts/presentation/widgets/workout_list_loading.dart \
  test/home_workout_list_test.dart test/home_workout_loading_test.dart \
  tool/fixtures/home_shadcn.dart
flutter test --no-pub \
  --dart-define=STA190_EVIDENCE=docs/verification/home-shadcn-2.2.0 \
  test/home_workout_list_test.dart test/home_workout_loading_test.dart
flutter build web --no-pub --target tool/fixtures/home_shadcn.dart --no-web-resources-cdn
python3 tool/fixtures/home_shadcn_server.py 8894
```

- [Analyze](analyze.log): no issues.
- [Focused tests](tests.log): **70 passed, zero skipped**. Existing optional screenshot test enabled. Covers search/folder restoration, metadata-only folder lookup, lazy pagination, page mode/deleted-page clamping, touch/mouse refresh, failure/recovery, busy actions, edit locks, empty/loading/error, local artwork despite remote class URLs, 320/390/430/834/844 widths and 1/1.3/2 text scales.
- Test finders now address shadcn controls; folder assertions target the select rather than new badges; whole-page blocking is distinguished from disabled buttons. The reduced-motion skeleton assertion settles the local overlay's one-time mount transition, then still requires no recurring frames. No checks removed or tests skipped.
- [Fixture build](fixture-build.log): standalone Flutter web build, not a production upload.
- Production home and unchanged bottom navigation run with `NavigationPreviewData` / memory repository. No Firebase initialization, production account, login, callable or real save. Port 8894 was free in `orca ports --all`; other workers' ports/tabs preserved.
- The initial plain-server preview exposed the shared Google Sign-In web plugin's public script bootstrap. The dedicated fixture server now blocks external script/connect/frame requests with CSP. The expected blocked-GIS console entry is documented, not represented as a completely clean console. No Firebase/account API or remote class media was used. See `browser-resources.json`.

## Actual Flutter browser evidence

| View | Evidence |
| --- | --- |
| Previous home, 390×844 | [Before](before-390.png) |
| New home, 390×844 | [After](after-390.png) |
| Previous wide grid, 1387×958 | [Before grid](before-grid.png) |
| New tablet grid, 834×1194 | [After tablet](after-tablet-834.png) |
| New narrow home, 320×568, 1.3× text | [Narrow](after-320-scale1.3.png) |
| New narrow home, 320×568, 2× text | [Large text](after-320-scale2.png) |
| New narrow home, 320×844, 2× text, full first card | [Large text / tall](after-320-scale2-tall.png) |

Before images reuse the **after** images from `/Users/sunmkim/CloudBoard-release-artifacts/2.2.0-development-9c7dc436/source-evidence/docs/verification/home-icon-cards-2.1.8`. The home source at prior evidence commit `1bc2d0a` and base `9c7dc43` is byte-identical. The prior evidence's before images had network thumbnails and are not this change's baseline. Grid viewports differ and are labeled accordingly. `search-390.png` is a widget-test capture, separate from browser images.

Live review: http://127.0.0.1:8894/ (also `?scale=1.3`, `?scale=2`, `?scene=empty`). Orca page `eaeddbc4-c04d-414b-a907-2368c3ba1694`. Worktree/server remain for coordinator review.

## Limits and handoff

Implementation and focused home verification are complete. Integration/merge/deployment are not performed. Physical iPhone/Android/TV, authenticated backend writes, full app/E2E suite, unrelated player/preparation tests, full integration CI, store uploads and release: **미실행 / 미확인** as applicable. Local web is not physical-device proof. Save behavior is unchanged; no real callable save/re-read validation is claimed. No dependency/version/release-note/workflow changes or tags. Coordinator owns integration with preparation-route/subset-Start work and release decisions.

Coordinator steering: the later 2.2.1+13 version/news change belongs exclusively to the preparation worker. This home branch retains its original 2.2.0+12 source baseline; coordinator integrates the release version afterward.
