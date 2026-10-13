# STA-145 · STA-152 implementation and visual QA

2026-10-13. Selected reference: `references/01-quiet-welcome.png` (concept 1, Android). Production widget captures: `sta145-152/`. No new logo was generated; `SoftRhythmMark` and the configured app name are reused.

## Implemented flow

- Mobile welcome: centered brand/small mark → “오늘의 수업을, 조금 더 여유롭게.” → one product explanation → example CTA → Google and text email action. iOS additionally shows Apple with its existing provider colors. The account-help dialog still explains previous sign-in methods, Apple's private email, and non-merged accounts.
- TV takes the existing focused sign-in branch. Mobile layout changes do not remove TV email/Google sign-in or introduce example browsing there.
- Public examples: one recommended basic class is selected by default. Alternative templates and purpose choices live in an expandable section. The selected template/purpose are still passed through sign-in and onboarding, and restored by the existing account-scoped exploration repository. Example controls and next actions remain local-only; shared rehearsal improvements belong to STA-148.
- Owned template: one preview first, optional remaining slides, then server-backed “내 수업으로 만들고 편집”. Existing import IDs and retry behavior remain unchanged; previously edited copies are reopened rather than replaced.
- First goal: show server-saved class + completed local rehearsal as two steps. Completion requires a non-null saved class ID matching the rehearsed class ID in the same account/center progress. Example playback and unsaved previews do not set this goal. Center/TV preparation follows separately; TV completion still requires its selected target's current playback ACK.
- Local rehearsal completion follows the existing per-slide completion callbacks for every module. Merely moving through slides or closing the screen is not completion. This is an implementation condition, not a claim of observed learning or uninterrupted real-time playback.

## Entry and continuation matrix

| Entry | Required now | Deferred / return behavior |
| --- | --- | --- |
| Public example | No account or TV | Recommendation can be changed; direct import path remains available |
| Existing member sign-in | Existing Google/Apple/email method | Account guidance and auth failure/detail/copy surfaces remain available |
| Example → sign-in | Preserve public starter key + allowlisted purpose | Cancel/failure retains the welcome/example route; email forwards the same query |
| Account needing phone verification | Existing server-required phone verification before private saving | “인증은 나중에” returns to the selected public example; no premium trial begins |
| Exploring / preparing | Explicit Free start if server advertises eligibility; selected purpose saved | Center detail form remains deferred; starter continuation is preserved |
| Operating center | Existing role, center name, type, and region requirements | Optional environment fields remain optional; later action retains prior behavior |
| Free selection | `startFree` is a server action, never a client entitlement | Failure stays on the current step for retry; no premium trial call |
| Optional premium trial | Expand details and press the separate explicit start button | Eligible Free accounts can start their first trial; existing paid/trial access is preserved |
| First saved class | Load that class and rehearse on this device | Center setup and TV pairing are subsequent actions |

Free copy uses only the confirmed TV-one-display, no-expiry/no-card policy. Proposed class/slide/AI limits are not published by these screens. `freeAvailable` and `freeActive` default to false when absent in an older response; server authorization remains authoritative. `startFree` follows View → Action controller → use case → repository → datasource.

## Screenshot comparison

`sta145-152/comparison-login.png` pairs the selected reference with the Android 390×844 fixture at DPR 2. Reference 853×1844 is proportionally reduced to 780×1686 and padded by two oat pixels at the bottom; implementation 780×1688 is unchanged. The combined image was opened, along with separate iOS, small/large-text, loading/error, recommendation, expanded choices, phone verification, Free choice, starter-save, and first-goal captures.

The source is a generated visual concept, not a device screenshot. Production uses flat Oat Sage tokens and Pretendard; it does not imitate image grain or baked lighting. Provider brand colors and Material icon shapes are preserved. Mobile text scales and scrolls rather than clipping or disabling font scaling. The iOS arrangement reduces decorative space to retain the extra Apple action.

| Fidelity surface | Review |
| --- | --- |
| Typography | Centered two-line value statement, quieter explanatory text and accessible action labels. Heading letter spacing follows the existing −1% rule. |
| Layout | Reference hierarchy retained. Email and existing-account guidance are text actions with ≥48px height. CTA and login actions remain reachable by scroll at 320px / 2× text. |
| Colors | Existing oat canvas, sage CTA, muted text and dividers reused; no new theme palette. |
| Assets | Same transparent two-board mark and real Google identity icon. Android symbol size refined after the first comparison; TV branch kept intact. |
| Content | One no-account/no-TV sentence, recommendation first, premium trial distinguished from public example and Free. |

## Validation and limits

- Final command: `flutter test --no-pub test/login_welcome_test.dart test/onboarding_test.dart test/first_use_journey_test.dart test/first_class_test.dart tool/sta145_152_capture_test.dart` — **33/33 passed** (`/tmp/sta145-152-final.log`): 32 behavioral/widget tests plus the production capture test, exporting 16 states. The 320px / 2× text capture includes a scrolled view of the demo, Google, email and account-help actions; the initial viewport does not show all actions at that scale.
- `dart analyze` on the owned auth/onboarding/starter files and tests/capture tool: **no issues** after resolving two brace lints.
- Existing guards tested include duplicate auth input/cancel recovery, TV sign-in branch, small-screen text scaling, selected purpose retry, account isolation/restart continuation, private-route gating, import retry preserving edited content, local-vs-TV completion, Free explicit start/failure retry, and first premium trial from Free.
- These are widget fixtures with local data. No SMS was sent, account created, plan deployed, real purchase made, physical TV controlled, or on-device/new-user observation performed by this task. Cohort metrics, baseline collection and 3–5 coach observation remain follow-up work as requested. No conversion or usability improvement is claimed from screenshots.

Final combined comparison and both 320px normal/2× action captures were opened after the final mark-size refinement. No clipping, inaccessible action, or functional blocker was found in these fixtures. At 2× text, long Korean button labels naturally wrap over two lines and the page scrolls; text scaling remains enabled.

Final SHA-256 evidence:

- Selected reference: `7be7214cf80800f8b39a7199aead80d9e6ce9d1682652d7db12267e8d9519551`
- Android 390 capture: `35574efbd94e743c84f1108dae0163a6995de8c01f03d53398fc40e8e096f069`
- Normalized comparison: `47df67fa6dcf820d23ace11fdd941cca0632dc52d9aaa26e1ce1f7e3b6e6e27c`

## Free server review and regressions

Independent review found and fixed Free being classified as legacy paid access, which blocked purchase preparation. Free now remains available while an enabled store can prepare a purchase; the billing kill switch is still enforced. Recognized old Plus-one-display grants receive the confirmed three-display policy, while unknown legacy limits are preserved.

Web grant revisions are independent from native projection revisions. The main resolver now consumes and retains the companion server's nested `webGrant`, honors web cancellation without reviving the old RTDB snapshot, preserves active native purchases, and uses verified web history for Free fallback and retrial prevention. The existing entitlement trigger initializes reconciliation for web-only accounts; deletion and pending-without-history guards remain in place. Companion publication and transaction tests are owned by the coordinating task.

- `node --test functions/test/free-plan.test.js functions/test/billing.test.js`: **12/12 passed** (`/tmp/sta152-billing-unit.log`).
- Isolated Firestore/RTDB emulator: Free, onboarding, billing and Google Play suites **all passed** (`/tmp/sta152-billing-emulator.log`). No production service or payment API was called.
- Final web-only trigger-service regression (automatic account initialization, pending state, deletion locks) also passed in the isolated emulator (`/tmp/sta152-web-trigger-emulator.log`).
