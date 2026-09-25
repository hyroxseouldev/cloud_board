# Login welcome — concept 3 implementation QA

Date: 2026-09-25

## Evidence

- Source visual truth: `/Users/sunmkim/.codex/generated_images/01a08de2-8e40-7921-a76c-c4f878ee2ae1/exec-3e0359df-2d10-41f9-ad31-dfa8827e45b5.png` (851 × 1848).
- Rendered implementation: `docs/design/login-welcome/implementation.png` (804 × 1748), captured from the actual Flutter LoginScreen with production theme/assets/fonts in a widget render harness.
- Viewport: 402 × 874 logical pixels, capture density 2; simulated safe-area insets 62 top / 34 bottom. Source is a generated concept without system chrome. Compare content proportions at equal displayed width, not raw pixel offsets. No CSS viewport applies to this native Flutter screen.
- State: logged out, idle, light theme, iOS with both providers. The harness does not draw the OS status bar. Simulator build/run succeeded; account help and Google account chooser were observed, then home was observed after the user's login interaction. The user's authenticated simulator session was preserved, so the saved idle evidence uses the render harness.
- Full-view comparison: source and rendered implementation opened together in one comparison tool result, including a second capture after the button font correction. Both retain centered wordmark, lavender sculpture, welcoming headline, supporting copy, provider buttons and account help.
- Focused comparison: button labels and illustration edges are readable at the saved 804-pixel width. Checked their glyph rendering, alpha edges and Google mark in that same comparison; no separate crop needed.

## Findings and comparison history

1. Initial capture: button labels rendered with test fallback glyphs; button TextStyle lacked an explicit app font. Set Pretendard explicitly for consistent rendering across the app and harness.
2. Post-fix capture: both provider labels render legibly; welcome copy fits; all idle controls remain visible. No actionable P0/P1/P2 findings remain.

## Required fidelity surfaces

- Typography: production Pretendard, bold wordmark/headlines, smaller supporting copy. Button font now explicit. Concept lettering is approximated by the app's existing font rather than introducing a second family.
- Layout: centered constrained column, 24-pixel side margins, rounded 54-pixel-minimum buttons. Safe areas explain top offset relative to the mock. Short screens and large text scroll rather than clip.
- Colors: existing pale lavender surface and muted accent tokens; black Apple and outlined white Google buttons. Flat background is an intentional production adaptation of the concept's very subtle decorative backdrop.
- Images: generated raster asset preserves the selected lavender play/slide/timer direction, transparent edges show no opaque rectangle. Sculpture is a regenerated illustration, not a pixel-identical crop. Google uses the official asset at preserved aspect ratio.
- Copy: welcome and account instructions retained. The mock's free-trial badge intentionally replaced with neutral login copy: STA-34 onboarding/trial is not implemented yet, so no unfulfilled trial claim is displayed.

## Verification

- Existing Apple auth and auth-router tests plus two new login interaction/layout tests: 11 passed.
- Temporary rendered-screen capture also passed; removed after saving the evidence.
- New checks: pending provider spinner remains inside its button, duplicate input blocked, cancel restores buttons, account help reachable/dismissible at 320 × 568 with 1.5× text scaling.
- Targeted static analysis: passed.
- iPhone 17 Pro simulator build/install/launch: passed. Real Apple sign-in, Android TV remote behavior and web authentication were not exercised end to end in this change.

## Implementation checklist

- [x] Selected concept 3 integrated into existing login page.
- [x] Existing authentication controller/provider visibility retained.
- [x] Button-local loading and duplicate guard.
- [x] Short-screen accessibility checks and reference comparison.
- [ ] Enable trial messaging only when STA-34 is connected.

final result: passed
