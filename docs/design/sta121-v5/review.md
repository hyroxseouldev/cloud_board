# STA-121 v5 independent visual review

Reviewed on 2026-10-12 using the Product Design `design-qa` skill and its QA rubric. This report supports the root agent's final `design-qa.md`.

## Findings

- **Resolved [P2]: initial class visibility in short viewports.** The final 844×390 landscape capture shows the first class title above the fixed controls. The final 320×568 capture at 2× text shows the start of the first class and its thumbnail; scrolling remains necessary to view the full row at this accessibility scale. The compact player is 48px high in landscape and 64px in narrow large-text mode. In the latter, removing the redundant expansion arrow gives `일시정지 · 8:00` enough room while the player body still opens the class. Header spacing and an unused loading slot were also reduced. No remaining P0/P1/P2 was found in this visual review.
- **Evidence correction:** files named `comparison-home-landscape-before.png` and `comparison-home-320-large-text-before.png` were copied after the first compact changes had already landed. They are earlier captured iterations, **not preserved images of the original no-row state**. Landscape was byte-identical before the last typography pass; its current delta reflects the final letter-spacing adjustment. The large-text pair demonstrates the status-label improvement and the final typography adjustment. The P2 closure relies on the final screenshots and the regression assertions described below, not on a claimed before/after pixel delta for the original issue.

## Evidence and normalization

- Source: `reference-v5.png`, 853×1844, SHA-256 `570d387c625de3c475ee6573220d0f2beb83177cd8dace4cf7c74875c5abe26a`.
- Implementation: `home-390-active.png`, 780×1688, actual 390×844 Flutter logical viewport at DPR 2 and 2× export. SHA-256 at this review: `96c37d3b7e50dc68846d6efcf52c9b25763b817731e3b8cfc7b43510f1e8a806`.
- Matched state: three classes, one connected display, a paused class at 8:00, Home selected, search closed. The progress fraction differs because the implementation renders its fixture's real playback state.
- Normalization: proportionally reduce the source to 780×1686 and add two oat-colored pixels at its bottom; leave the implementation unchanged. No screenshot content is stretched or repainted.
- Full comparison: `comparison-home-390-full.png`.
- Focused comparisons: `comparison-home-header.png`, `comparison-home-list.png`, `comparison-home-navigation.png`. All four combined images were opened and inspected.
- Compact iteration comparisons: `comparison-home-landscape-fixed.png` and `comparison-home-large-text-fixed.png`. Each pair uses unscaled equal-size source PNGs, with labels explicitly distinguishing the earlier captured iteration from the final capture. Both combined images were opened.
- Final compact hashes: landscape `305210af9a071b750818f37d8409f6a668893430a6d8bb485551e14f8a9c36bd`; 320px 2× text `231874b32855ce32d18cb1fc2da42bac22a759d62c194937795ee16ef1eb4cef`.
- Final login capture: `login.png`, SHA-256 `b38a95dfbd778fba3d8eccb8abc9534e5ed393a62da71bd05a699c544b97c43f`; opened after the typography pass.
- Additional renders opened: 320px active/large text, landscape, iPad portrait/landscape, desktop, idle, loading, error, empty. Loading/error/empty captures use a standalone page fixture without the app shell; the absent dock in those captures is not classified as a product defect.

## Required fidelity surfaces

| Surface | Assessment |
| --- | --- |
| Fonts / typography | The production Pretendard rendering is clear. Titles, class metadata, and controls preserve the v5 hierarchy. `내 수업` uses the written 20px section role rather than the larger generated mock lettering; main/body optical weight is slightly stronger but consistent. At 2× text, labels wrap and title ellipsis preserves control room. Final home greeting/section/row/player headings use −1% letter spacing (26→−0.26, 20→−0.20, 17→−0.17); body text uses zero spacing. The refreshed home comparisons and login capture show no collision, awkward compression, or visible font fallback. |
| Spacing / layout | The 390px composition preserves brand → greeting → display band → class heading/filter → continuous divided list → mini control → four-tab dock. Row actions retain useful size. The first row starts approximately 20 logical px lower than the source; this is minor rhythm drift at 390px, where all three rows remain visible. The final compact layouts expose the start of the class list above the fixed controls; full rows remain scrollable. Wider 1–2-column bordered surfaces retain the existing responsive model; the source mock provides no tablet/desktop equivalent. |
| Colors / tokens | Warm oat, pale sage surfaces, dark sage actions, and green-gray secondary text match the written palette. This final comparison includes the refined muted token `#616B63`. Flat production fills intentionally omit the generated mock's paper/lighting variation. Status/selection remain distinguishable beyond color through text/icons. |
| Images / assets | The real generated Soft Rhythm mark is used, with readable two-board separation and no visible chroma halo in actual UI compositing. Class thumbnails retain the source content and crop intent. The smaller text inside thumbnails is raster content, not a UI text replacement. Standard icon forms differ slightly from the generated drawing, but preserve meaning and optical weight. |
| Copy / content | Visible app-specific labels match: `내 수업`, `수업 만들기`, `모든 폴더`, display status, pause/time, and the four destinations. Fixture class names/count and state match the source. Dynamic user greeting and state-specific error/empty copy are valid production variants. |

## Native icon and splash asset review

- `comparison-native-icons.png` composes actual exported iOS, Android legacy/adaptive, and Web PNGs with representative circle/rounded masks and 32/48/64px previews; it also shows actual macOS 16/32/64px, iOS 20px, Android 48px, and Web 32px files with clearly labeled zooms.
- `comparison-native-splash.png` composes the actual iOS @2x, Android pre-12 @2x, Android 12 @4x, and shared Flutter 128-logical-px mark on a 390×844 oat canvas. The mark's placement and visual size agree.
- Both QA composites were opened. No board clipping, visible green fringe, white perimeter border, or ambiguous single-board silhouette was found. The 16px version necessarily loses surface detail, but the diagonal separation remains visible.
- The adaptive preview uses the central 72dp viewport of its 108dp layer. Read-only pixel measurement found all alpha≥128 body pixels within the 66dp safe circle in all five Android densities; for xxxhdpi, maximum body radius is 110.56px versus a 132px safe radius. [Android's official adaptive icon guidance](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive) defines the layer/safe-zone constraints.
- These are QA composites of exported assets, **not device launch/launcher screenshots**. Exact OEM masks, launch transition, and system-bar behavior need the native verification owned by root.

## Comparison history

1. Initial 390px same-state full/focused comparison: no P0/P1 and no actionable 390px P2. Responsive inspection identified initial class-list visibility as P2.
2. Native export review: no actionable P0/P1/P2 in the asset/mask composites. No asset was modified by this review.
3. Final 390px full/focused comparisons were regenerated after the muted-color adjustment and opened again. No new actionable discrepancy was found.
4. Final compact captures were paired with the available earlier iterations and opened. Initial list content is now visible, and the narrow large-text player displays its complete status/time. The earlier evidence was correctly reclassified as intermediate captures.

5. After the final title/body letter-spacing pass, all four home comparisons and both compact pairs were regenerated and opened again, and the updated `login.png` was inspected. The hierarchy remains clear and no new P0/P1/P2 was found.

## Verification scope

- Read-only inspection of `test/main_navigation_test.dart` confirms regression assertions for an initially visible class row, compact player height, hit-testable resume/open controls, 48px tab targets, bottom safe area, and keyboard handling. The implementation owner reports 51/51 targeted tests and 2/2 capture tests passed after the fix; this independent reviewer did not run Flutter. The later root-run full suite plus both capture fixtures completed with `+719: All tests passed!` in `/tmp/sta121-final-tests.log`; the screenshots and hashes above are from that run.
- This report is visual QA of the captured production-widget fixtures and exported assets. It does not substitute for native device launch/launcher validation or prove scroll interaction solely from screenshots. Root owns the final interaction/native verification and final QA report.

## Follow-up polish

- [P3] If spacing is tuned later, reduce the 390px filter-to-first-row gap by roughly 16–20 logical px to follow the reference rhythm more closely without changing the 48px action targets.

final result: passed

No remaining actionable P0/P1/P2 in the reviewed screenshots or exported-asset composites. The P3 spacing polish above does not block this visual review.
