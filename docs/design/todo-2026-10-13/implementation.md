# Project Todo implementation · 2026-10-13

Base: `origin/develop@5b931ca`, after PRs #40/#41/#42 and release PR #48. Branch: `hyroxseouldev/feat-todo-redesign-20261013`. All new screens use the existing `design.md` v5 Oat Sage tokens and original brand assets. v6 colors and Cue's final logo remain separate decisions.

The owner explicitly moved older team Todo issues **STA-22/24/25/31/32 to Done**. Their old requested features are excluded from this change. The current project queue is STA-133, STA-144, STA-145–152.

## Screen/state inventory and reuse

| Issue | Production area | Implemented / reused behavior | Evidence |
| --- | --- | --- | --- |
| 133 | Common application structure | Reuse merged v5 typography, state panels, dialogs, navigation and motion; apply selected welcome direction to the working screens | Root `design-qa.md`; same base throughout |
| 145 | Mobile welcome / account help | Concept 1 composition, example primary action, immediate Google, email text action, iOS Apple, existing TV branch | `sta145-152-review.md`; 16 captures |
| 146 | Content/templates/AI; input, generation, result | Preview then add to class; actual shared usage; failed usage lookup and empty results offer recovery; templates/manual editing preserve their existing quota behavior | `sta146-148-review.md` |
| 147 | Slide/timer editor; preview, internal tabs, sheets | Draft/save status, preview first, applying timer configuration separate from persisting slide; failure retains content; small-height settings scroll | Same review; save pending/success/error, keyboard/landscape/large type captures |
| 148 | Class editor/list/rehearsal | Class name/count/duration, explicit saving state, reorder including buttons, local rehearsal distinct from TV; incomplete dismissal not called achievement | Same review; empty/populated/paused/ended/completed states |
| 149 | Home/library/search/folders | Reuse PR #40/#42 catalog, retained search/scroll and error recovery; improve empty vs no-results actions and honest device summary | `sta149-151-review.md` |
| 150 | More/profile/center/subscription/operations/news | Account summary + grouped destinations, editable fields vs server state, profile load/retry, actual Free plan labels. Existing operations tabs and delete/reauth flows reused | Same review; common theme on preserved routes |
| 151 | TV list/pairing/code/confirmation/control | Loading/online/offline/last-response/send state distinguished, typed next actions, selected replacement IDs only, duplicate request lock | Same review; 12 management captures and server emulator coverage |
| 152 | Example→signup→Free→owned class→rehearsal | Recommended example, preserved continuation, explicit Free and separate first premium trial, real saved/rehearsed class ID achievement | `sta145-152-review.md`, `docs/free-plan-policy.md` |
| 144 | Installed-client compatibility follow-up | Review already-recorded retirement decision; preserve failing historical evidence and retained coverage, without inventing a semantic repair | `sta144-disposition.md` |

The common vocabulary is **내 수업 → 수업 만들기 → 수업에 추가 → 저장 → 이 기기에서 연습 → TV에서 수업 시작**. Applying a timer draft is not a server save. TV registration/online state is not proof of playback; existing verification/ACK checks are retained. User slide colors, timer canvases and center branding are not restyled as management UI.

## Server/product changes

Confirmed Free TV-one and Plus TV-three policies are enforced across the app, main Firebase resolver/rules, and companion pairing/activation server. Source grants retain paid periods, trial use and independent web/native revision histories. Existing TV registrations and active-class state survive a downgrade. New plan UI does not imply access when the server grant is missing.

The proposed Free 5-class / 1-reusable-slide limits were not confirmed; current unlimited class / 3-slot reuse behavior remains. Physical device testing, cohort/cost baselines and coach observation have not been performed. See the rollout contract and main/companion PRs before deployment.

## Verification

Final local results: Dart format and `flutter analyze` passed; full Flutter **908/908** passed; Node policy **146/146** and Firebase tooling **47/47** passed; `tool/firebase_contracts.mjs` passed current/frozen exports, all three active released readers, the two explicitly retired reader dispositions, and all **22/22** registered emulator suites. Companion TypeScript, policy/callback **9/9**, activation/pairing and web-grant emulator checks passed. The existing companion environment-independent suite passed **10**, with **5** database-dependent tests explicitly skipped. Capture fixtures passed and screenshots were reviewed. Release web compilation passed (50.5s).

Detailed evidence is summarized in the PR and the per-screen review files. Main checks include Dart formatting/static analysis, full Flutter regression, current/frozen source contracts, all configured Firebase emulator suites, Node policies and release web compilation. Companion checks include TypeScript and callback/policy tests plus isolated activation and source-grant emulators. Database-backed Neon suites remain explicitly skipped without their test environment.

Visual comparisons use source images and production-widget fixtures together, with density normalization documented in root `design-qa.md`. Actual user accounts, SMS, payments, physical displays, screen-reader operation and store uploads are not simulated as completed release checks.
