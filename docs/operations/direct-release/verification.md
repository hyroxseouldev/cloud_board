# Main control-only direct-release handoff — 2026-11-14

- Worktree: `/Users/sunmkim/orca/workspaces/cloudboardapp/main-direct-release-cutover` (clean Orca worktree created from `origin/main`; original dirty checkout untouched).
- Branch: `hyroxseouldev/main-direct-release-cutover`; target: **main**, explicitly authorized control-only exception to the normal develop promotion.
- Original main: `f9edab461a148e68c995c1d97d160226bf1334c2`; app version remains **2.1.0+8**.
- Initial port: `2c13849c5031dcc2bcc65b091b614681d2a4e151`; final code commit after runtime integration: `87e2500cb217f103c58f0e241d395e69c4e8487e`. The final handoff commit changes this report only; its PR body records that head SHA.
- Source: [PR174](https://github.com/hyroxseouldev/cloud_board/pull/174), source head `8a0b3ebad3bff773a2986fcbb813310be7d7fb50`, develop squash `ed18722910eb58af4686c4559183e8063adcf6c9`. Only selected path diffs were applied; no develop merge or cherry-pick.
- Additional selected control fix: `8ccc4e415eede1f416ed265f26a385a3d3460263` (runtime comparison limited to deployment targets; only three tool files, no service-attempt report copied).
- Additional selected control fix: [PR175](https://github.com/hyroxseouldev/cloud_board/pull/175), `1926a15501ccd8a7844ef5a124fc7176dd6eb2c1` (exact Apple bundle match and supported capability query).

## Changes and main compatibility

Main's `tool/` and `.github/` were byte-identical to PR174's parent before porting.
35 changed destination files are identical to PR174. All seven retired workflow
fixtures are byte-identical to original main. The complete changed-path and blob
comparison is `/tmp/cloudboard-main-direct-port-2026-11-14/source-comparison.json`.

Ported the offline source/scope planner, selected-target direct CLI, runtime
configuration and secret-binding guards, receipt ledger/CAS and failure handling,
Firebase historical/direct readers, native source/backend adapter, installed-client
reader, news publisher, monitor rule expectations, and historical test paths.
Production still requires the exact version-matching immutable tag and main
ancestry. Signing, app/environment identity, build numbers, artifact inspection,
backend compatibility and omitted/externally managed endpoint protections remain.

Intentional differences from PR174:

- main's existing `functions/src/development-backend-config.js` is used unchanged. No newer develop application/functions module is imported or copied. The direct-target fixture checks main's actual allowlist and rejects absent develop-only media endpoints; production still excludes all listed development-only endpoints.
- Direct production backend/rules/functions plans now execute `verifyInstalledClients` before any deployment. PR174 adapted the reader but did not invoke it from direct execution. Missing frozen contracts, wrong source, artifact or deployment ID remain blocking. This is a control-only preservation fix and should be synchronized back to develop separately.
- The frozen-contract validator accepts exactly one historical `workflowRunId` or new `directDeploymentId`. Historical registry entries remain immutable; missing/ambiguous IDs and changed old registrations are rejected. No installed-client registry or fixture data was altered.
- The exact Apple readiness fix from PR175 is included without app/native configuration changes.
- The direct-deployment worker's runtime fix excludes managed functions outside the development allowlist and limits explicit-function comparison to the supplied selectors. Selected-function runtime/secret mismatches remain blocking. It imports main's existing allowlist and was rechecked with 17 direct tests after integration; no develop backend code was added.
- The active-workflow test additionally rejects push/PR/workflow_run/workflow_call hooks and all retired filenames in the three remaining workflow definitions.
- The guide records main 2.1.0+8, absent develop-only iOS export configuration and the coordinator's already-completed ruleset migration.

## Unchanged application and backend evidence

A mechanical allowlist rejects every changed path outside `tool/`,
`.github/workflows/` and the selected documentation. `git diff` reports **zero**
changes to lib, iOS, Android, functions (including tools/runtime), functions-legacy,
assets, web, config, tests, all Firebase rules/configuration, pubspec/lock,
`.fvmrc` and release notes. Git tree/blob IDs match original main exactly:

| Path | Unchanged tree/blob |
| --- | --- |
| `lib` | `2ae7af472c7a389d6ada7720879a846bc8aea84f` |
| `ios` | `2bcbf700c9176b51e0fa0ba97c312710cd4528f9` |
| `android` | `39aedd966069815eeae18191bf977c7bb3309acd` |
| `functions` | `4dcac431e1c74e9ff9041723da57f8abd633ff97` |
| `functions-legacy` | `0dc030baa1b075e26c47661b4a07d1fda5dad539` |
| `pubspec.yaml` | `35e76114c495578aaea21dc391d619cb73b327d3` |
| `pubspec.lock` | `f04dd90b7ae7a65ac26c1603a3bdfe19af6c3031` |
| `.fvmrc` | `54d5591bd0f88f1af90fd5093f66609b5284b722` |
| `release-notes` | `a0e0fe22db735a855b292604f49292dec0e317de` |

The control tools use the selected source's pinned Flutter version; main still
pins 3.47.0. No latest-develop app/server dependency was transplanted.

## Focused verification

Node: `/Users/sunmkim/.nvm/versions/node/v22.21.1/bin/node` (22.21.1).
The first three runs were on original main plus the subsequently committed code
changes; the applicable tested files are identical in the code commit above.
Readiness arrived after the installed-client run and was checked separately.
The subsequent three-file runtime patch was rechecked with the direct suite on
`a7ba615338e4ba5b6860355b62c6dd5003953630` plus that patch, then committed unchanged
as `87e2500cb217f103c58f0e241d395e69c4e8487e`. Earlier tests apply to unchanged
files; this is evidence reuse, not a claim that every check ran on the final SHA.
No test was deleted or skipped. These are local script/fixture results, not CI.

| Command / evidence | Result | Connection and limits |
| --- | --- | --- |
| `node --test tool/release/direct.test.mjs tool/release/source.test.mjs tool/firebase/environments.test.mjs tool/firebase/repository-rules.test.mjs` | 35 passed, 0 failed/skipped | Mock/fixture and actual offline CLI subprocesses; no provider connection. Direct tests were rerun below after adding the installed-client stage. |
| `node --test tool/release/direct.test.mjs tool/firebase/installed-clients.test.mjs tool/firebase/fixtures.test.mjs` | 31 passed, 0 failed/skipped | Main allowlist, production installed-client stage ordering, exact direct receipt source/artifact/ID, QA exclusion, frozen registration immutability. |
| `node --test tool/release/development_readiness.test.mjs` | 6 passed, 0 failed/skipped | Mock Apple metadata; no store API calls by this worker. |
| `node --test tool/release/direct.test.mjs` after runtime integration | 17 passed, 0 failed/skipped | Main allowlist/runtime selection, selected-config rejection and the full direct fixture/offline suite. |
| `verifyFixtures("f9edab461a148e68c995c1d97d160226bf1334c2")` from `tool/firebase/fixtures.mjs` | Passed | Offline actual registry/frozen files and Git historical provenance. |
| All changed `.mjs`: `node --check`; `git diff --cached --check` | Passed | Syntax/whitespace only. |
| Post-cutover ruleset receipt passed to `validateActiveRules` | Passed | Supplied local JSON; no policy API/write. |
| Six development scopes (direct test subprocesses) and six production scopes | Dry-run passed | No execute/upload/build/signing/reservation. Production source is original main and existing `v2.1.0`, confirmed locally to resolve to the same SHA and version. |
| Protected path diff + Git tree/blob equality + retired fixture bytes | Passed, 0 protected-path changes | Machine evidence in the comparison JSON; all non-control source preserved. |

Logs: `/tmp/cloudboard-main-direct-focused.log`,
`/tmp/cloudboard-main-installed-tests.log`,
`/tmp/cloudboard-main-readiness-tests.log`, `/tmp/cloudboard-main-runtime-tests.log`; production plan JSON files are under
`/tmp/cloudboard-main-direct-port-2026-11-14/`. The production dry-run reads the old
release SHA using the new control planner; it does not make that old release tree
contain the CLI or authorize an execution from a different checkout. A future
production candidate still needs a separately approved new matching version/tag;
the existing `v2.1.0` must never move.

Unchanged PR174 helper/historical tests reuse the original [verification record](https://github.com/hyroxseouldev/cloud_board/blob/ed18722910eb58af4686c4559183e8063adcf6c9/docs/operations/direct-release/verification.md),
including unchanged receipt/news/backend behavior and Python native-artifact/signing fixtures
(5 and 4 passed). The referenced files and their control dependencies are identical
except the explicitly rechecked paths above. They were **not rerun** as full CI,
Flutter, emulator, native or signing checks on main.

## Integration and notifications

Removed active workflows: `class-start-regressions.yml`,
`development-handoff.yml`, `firebase-development.yml`,
`firebase-hosting-merge.yml`, `google-play-main.yml`,
`testflight-main.yml`, `start-production-release.yml`.

Retained operations:

- `firebase-release-monitor.yml`: scheduled drift/save-alert observation and read-only branch-rule checks; understands direct and historical receipts.
- `app-update-news.yml`: explicit trusted-main publication from verified direct deployment IDs or historical workflow IDs; no workflow_run dependency on deleted deployments.
- `native-development-readiness.yml`: manual read-only app/store/profile inventory; no app build or upload.

The source has no PR/push/tag CI or automatic release trigger and no active
workflow needs/uses/dispatch reference to a deleted workflow. Old references in
receipt readers and inert fixtures are intentional historical evidence readers,
not calls to execute those workflows. The former release starter CLI refuses
Actions dispatch.

Only merging this PR to main completes the default-branch removal. Afterward new
PR/push/tag events cannot start the deleted handoff/CI/deployment workflows, so
those new failure-mail sources stop. Already queued/started old runs, received
email and failures from the retained operational workflows are separate; this
worker did not cancel runs or delete mail.

The coordinator already removed only `firebase-required` from ruleset 24924061;
its local before/after/direct receipts are under
`/tmp/cloudboard-direct-cutover-2026-11-14/`. This worker made no protection,
policy, tag, signing, store, receipt-branch or service changes. Tag rules are
untouched. The copied ruleset JSON files are inert historical test fixtures.

Implementation and focused checks are complete; main merge is the coordinator's
next step after final diff review. Full app builds/tests, actual callable/save
flows, production/development deployment, real CLI credential/signing acceptance,
store upload and sub-minute same-scope latency are **미실행 / 미확인** here. There
was no app/data change requiring real-save verification. Other dispatched workers'
service/TestFlight executions are separate and are not claimed as this PR's
verification or deployment.
