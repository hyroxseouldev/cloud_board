# STA-33 — compact home implementation QA

Date: 2026-09-25

## Evidence and comparison

- Selected visual: `/Users/sunmkim/.codex/generated_images/01a08de2-8e40-7921-a76c-c4f878ee2ae1/exec-4e09ed30-21ca-42f6-93a9-c265358f6305.png`.
- Rendered implementation: `docs/design/home-list/implementation.jpg`, captured from the rebuilt iPhone 17 Pro simulator. Capture tool exports 368 × 800 pixels; the app runs at the simulator's native logical viewport. No CSS viewport applies to this native Flutter implementation.
- Source and final implementation were opened together in one tool result. Compared the whole home and focused on the appbar, greeting, folder control, thumbnail, row actions and bottom-right FAB. Both are idle/light theme, one workout, with search and drawer closed.
- Native status bar and safe areas account for the source's missing system chrome. The real account name, folder and actual disconnected display state intentionally replace mock content. The existing waterfall image is loaded from workout data and cropped to a square for the list.
- Prior login QA preserved at `docs/design/login-welcome/qa.md`.

## Findings and fixes

1. Initial simulator review: folder selector was not right-aligned, drawer wordmark inherited small text, and the overflow action lacked the reference's rounded surface. Corrected all three and added the final row divider.
2. Final comparison: compact hierarchy, rounded thumbnail, separate play/overflow buttons, white background and lower-right plus FAB match the approved direction. Existing Pretendard and purple theme are retained; system chrome and real data differ intentionally. No actionable P0/P1/P2 visual findings remain in the reviewed home state.
3. A subsequent capture caught the user opening the folder menu rather than the drawer; it was not used as drawer visual verification. Drawer destinations are verified by widget tests. No claim of a complete visual audit of every destination page.

## Behavior and checks

- Search moves to the appbar action, receives focus, clears/closes, and restores prior page and scroll offset.
- Folder filtering and pagination retained; single-page controls hidden.
- Mobile uses a compact list; iPad portrait/landscape retain three-column grids; existing web maximum width retained.
- Drawer links retain existing destinations; the duplicate favorites destination was removed after user feedback. Favorites remains a filter inside the slide library.
- Display connection label uses paired/online device data rather than a mock count.
- Existing playback entry, preflight, copy/delete actions and active-workout edit restrictions retained.
- Targeted home, auth-router and slide-template tests passed; resize coverage includes 320–1600 logical width and 2× text, plus iPad portrait/landscape.
- Targeted static analysis passed. Final iPhone simulator build/install/launch passed.
- Real display pairing and a complete class playback session were not retested for this home layout change. No backend, authentication or subscription schema changes.

## Follow-up: drawer navigation

- User reported the drawer closing visibly only after returning from a destination. Previous code started drawer close and route push together, allowing the offstage home ticker to pause before close finished.
- Queue one destination, close the drawer, and navigate after Flutter unmounts the fully dismissed drawer content. The early onDrawerChanged(false) callback is not used as an animation-completion signal. Pending navigation is guarded against duplicate taps and an unmounted/non-current home route.
- Regression test verifies the destination is absent while the drawer closes, drawer content is absent even offstage on the destination and during back navigation, and another menu destination still works afterward. Home suite: 14 passed; targeted static analysis passed.
- Drawer now has one slide-library destination; favorites remains inside that page.

final result: passed


## Slide editor inline bottom tabs — 2026-09-25

- Scope: selected third displayed mock; existing Flutter app bottom tabs only.
- Source visual truth: docs/design/editor-inline-tabs/reference.png (1430×1100 component concept, intended logical width390).
- Implementation: docs/design/editor-inline-tabs/implementation.jpg (368×800 tool-normalized screenshot of iPhone17Pro402×874 logical viewport).
- State: sound tab selected, light theme. Source and implementation opened together in one comparison tool result. Compared app-owned bottom bar regions, normalized concept width390 and implementation width402; full-screen image includes OS chrome and existing preview that are outside this component change.
- Typography: Pretendard, compact12px (11px below350 width), selected700weight. Inline labels readable and untruncated in screenshot and320/390/834/844 tests. Larger accessibility text uses stacked icon/label layout rather than truncation.
- Layout: white full-width bar, thin divider, icon left of label, lavender selected rounded rectangle.56px content height,48px targets and native bottom safe area. Library receives slightly more width for its longer label. No floating shadow or outer pill.
- Color: existing primary #77729D, primaryContainer #E4E1EE, outlineVariant #E6E3EF. Matches source palette.
- Assets: existing Material outlined icons (timer/image/volume/overlapping slides), no raster assets needed by the implementation.
- Copy: 타이머 / 배경 / 소리 / 라이브러리 exactly retained. Existing sound explanations outside the bar retained.
- Comparison history: first narrow320 widget check found1.8px overflow; reduced font to11px at widths below350. Repeated four-size tab tests and timing tests:9passed. Post-fix simulator capture confirms single-line text and selected sound state. Native accessibility snapshot exposes all four as buttons.
- Findings: no actionable P0/P1/P2 component differences. Minor source/render icon stroke and panel-width differences follow the existing app icon library and responsive constraints.
- Verification: analyzer clean; native hot reload successful; sound tab tap verified. No browser prototype, build or deployment involved.
- Follow-up: large accessibility text fallback has not been visually captured on simulator.
- final result: passed

## STA-34 — Firebase onboarding, design 3 (2026-09-25)

- Reference: `docs/design/onboarding/reference.png`, 850×1848, approved purpose-selection mock 3.
- Implementation: `docs/design/onboarding/purpose-fixture.png`, real Flutter widgets at 390×844 logical / 780×1688 raster, regular Pretendard and Material icons loaded, fake repository with operating selected. This is a deterministic UI fixture, not a production account with fabricated verification.
- Live entry: `docs/design/onboarding/phone-simulator.jpg`, 368×800 normalized screenshot from iPhone 17 Pro, authenticated callable loaded successfully after hot reload. No real SMS was sent.
- Reference, purpose fixture and live phone entry were opened together in one comparison result. Compared normalized full frames and the heading, progress indicators, grouped choices, selected border, bottom primary action and explanatory copy.
- White background, existing lavender theme, three purpose rows, trailing radio controls, outline group and bottom CTA match the chosen direction. AppBar uses the existing brand style; `건너뛰기` is clarified as `나중에` because it saves progress. Initial production state has no preselected purpose. Native status bar/safe area appears on device and is outside the supplied mock.
- Existing Material outlined icons replace the mock's drawn icons. No generated raster assets are needed in the app. Form body scrolls independently above the bottom action, with a 600 logical-pixel content limit on wider devices.
- Tests cover 320/390/834 widths without overflow, failed save retry, explicit trial consent, existing-access completion and auth redirect. The phone screen uses a scrollable body for the keyboard. Subsequent center fields and trial steps were behavior-tested; not all field combinations have live simulator screenshots.
- No actionable P0/P1/P2 visual findings in the reviewed purpose and phone states. Actual SMS delivery and full production OTP completion remain manual checks.
- final result: passed for reviewed visual states.
