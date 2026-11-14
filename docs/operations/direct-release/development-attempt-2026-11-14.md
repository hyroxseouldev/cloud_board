# Development direct deployment — 2026-11-14

Requested source: `ed18722910eb58af4686c4559183e8063adcf6c9` (2.1.6+10).
Target: `cloud-board-development`, backend first, rules only after backend success.
Worktree: `/Users/sunmkim/orca/workspaces/cloudboardapp/direct-release-cli`.
Execution branch: `hyroxseouldev/direct-development-deploy`.
Node 22.21.1; existing Flutter 3.47.8 selected via FLUTTER_BIN.
The original dirty checkout was not changed.

## Attempt 1794632230157917 — failed before deployment

The backend plan selected only development and the source's explicit allowlist.
The CLI created the authorized receipt branch and completed source, environment,
toolchain and Firebase access checks. It then failed at `function-targets`:
`Per-function runtime configuration differs; a shared dotenv would change it`.

- Receipt started: `2026-11-14T04:57:10.221Z`.
- Receipt completed: `2026-11-14T04:57:50.642Z`.
- Receipt execution window: **40.421 seconds**, including dependency installation;
  this excludes the initial source/access preflight before receipt creation and
  is **not a successful deployment duration**.
- `deploy` was never started. Backend, rules, Hosting and stores were not deployed.
- Remote ledger readback confirmed terminal `failed`; there is no pending lock.
- Receipt: `build/direct-release/1794632230157917/attempt.json`, also retained in
  `cloudboard-deployment-receipts:direct-deployments.json` and branch history.
- Policy activation, enrollment, fixtures and global-user changes: not executed.

## Root cause and minimal correction

Read-only `functions:list` showed a common allowlisted nonsecret runtime digest
`8d7ddb6dd31ed6499f0f970525fa811da41cd7cb0089b80f53c684b834071500` for the 30
existing selected core functions. Five **excluded** managed AI endpoints have a
different runtime configuration: `cloudboardAiSlideRaster`, `cloudboardSlideStudio`,
`cloudboardTemplateJobs`, `generateTemplateJob`, `recoverTemplateJobs`.

The runtime checker incorrectly compared the entire codebase even though the
actual deployment excludes those five endpoints. The fix filters runtime input
by the development allowlist, or by explicit `--functions` selectors when present.
It does not write the excluded configuration, weaken equality among selected
functions, skip unknown-variable/secret checks, or change endpoint discovery,
omit rules, production policy or the legacy display boundary.

Read-only discovery with the corrected helper produced **41 exact selectors**:
40 allowlisted core endpoints (including 10 new image/usage API/trigger endpoints)
and `functions:cloudboard-auth:cloudboardSetDisplayState`. The result exactly
matched `developmentDeployTargets`. Existing selected secret bindings matched.
Runtime values and credentials were neither printed nor copied into this report.

Focused validation: Node22 `node --test tool/release/direct.test.mjs` — **17 passed,
0 failed, 0 skipped**. The new fixture covers excluded managed AI/legacy
configuration, no inventory mutation, narrow selection, continued failure on
selected mismatches and unknown variables. Existing omit, environment, secret,
receipt and partial-failure assertions remain.

Actual service deployment remains blocked pending the coordinator's reviewed
fix integration and new fixed source SHA. Do not rerun from dirty tools or mark
the failed attempt successful. A future attempt must use a new receipt ID.
The iOS readiness fix is owned by its separate worker and is not changed here.

## Attempt 1794632812372450 — provider source verified, CLI receipt failed

After PR176 was merged, the coordinator authorized fixed source
`d7c707b5efbd5b3ec187e82fdce4ab360ad2a4d6`. The clean detached checkout ran
`node tool/release/direct.mjs --source d7c707b5efbd5b3ec187e82fdce4ab360ad2a4d6 --environment development --scope backend --execute`
under Node22.21.1, with Flutter3.47.8 selected. Exactly 41 allowlisted selectors
were sent to development (40 core + isolated legacy display). No broad codebase,
Hosting, rules, production or store selector was sent.

The CLI exited 1 with `fetch failed` after the Firebase operation. Whole CLI
elapsed **193.554 seconds** (05:06:50.942085–05:10:04.497671 UTC); receipt window
191.079 seconds; deploy stage window 156.925 seconds. The latter includes the
receipt transport failure and is not an isolated Firebase operation measurement.
These timings neither establish nor disprove an under-one-minute narrow deployment.

Original remote/local receipt stays terminal **failed**, unmodified. No blind
retry was performed. The old helper discarded child stdout/stderr and successful
exit codes; the exact child exit result cannot be recovered from its logs. The
plain fetch error, versus its wrapped child-process errors, points to the later
GitHub receipt save, but a stale connection cause is an inference.

Read-only provider evidence now establishes more than ACTIVE status:

- All 41 selected functions ACTIVE, Node22; provider update times fall within
  05:08:50.344619215–05:10:02.575874521 UTC, the actual attempt window.
- Immutable provider source archives (bucket/object/generation) were downloaded
  to memory. All 40 core archives matched all 62 tracked source, certificate and
  package files at the fixed SHA; the legacy archive matched all 26 lib/package
  files in the isolated package generated for that attempt. Arbitrary other
  archive entries are not attested. No package, runtime environment values or
  credentials were saved by the evidence collector.
- All 40 core nonsecret configuration digests equal the preflight digest
  `8d7ddb6dd31ed6499f0f970525fa811da41cd7cb0089b80f53c684b834071500`; the isolated
  legacy environment remains empty. The existing onboarding binding remains
  `CLOUDBOARD_DEVELOPMENT_ONBOARDING_SECRET`; no other selected function has a
  provider secret binding. Provider revisions/build IDs are retained in the
  [sanitized evidence](development-provider-evidence-2026-11-14.json).
- New image/usage APIs and both enrollment/session triggers are ACTIVE. This is
  infrastructure/source readiness, **not** authenticated app-flow verification.
- Corrected local readback successfully GETs Firestore, Storage and RTDB rules.
  Rules were not deployed by this attempt and their candidate equality is not
  asserted. Policy activation, global enrollment and fixtures remain unexecuted.

## Receipt recovery correction and proposed next action

Local direct execution uses an independent `gh api` process for each GitHub
request even when an in-memory GITHUB_TOKEN is present. A completed external
operation retains its success when the following receipt save fails; future
Firebase operations preserve exit0, project, exact selectors, completion-marker
presence and output SHA256 without storing stdout or secrets. Overall attempts
still fail if required readback/persistence did not finish.

An uncertain CAS PUT is never replayed. The reader fetches the latest ledger
once and accepts it only if the entire intended document matches; otherwise it
stops. State snapshots prevent mutable attempts changing their prior ledger
state. Only the current pending owner can update; terminal history is immutable.
Firebase login refresh requests its granted `firebase` scope rather than the
ungranted `firebase.database` scope. ADC behavior remains unchanged.

Focused checks: Node22 `node --test tool/release/direct.test.mjs tool/firebase/release-cli.test.mjs tool/firebase/latest-release.test.mjs`
— **43 passed, 0 failed, 0 skipped**, including six-scope dry-runs, operation versus
persistence failure, pending-before-work, lost-response readback without PUT
replay, concurrent-owner/terminal protection, independent transport and login
scope fixtures. One initial transport fixture had an incorrect fake-CLI argv
index; correcting the fixture produced the stated result. Real external checks
in this correction are read-only. No whole-app tests/builds were repeated.

Proposed coordinator decision: merge the focused fix, retain failed attempt
1794632812372450, and preserve this linked reconciliation as a separate evidence
file on the authorized receipt branch with a create-only CAS write. Do not turn
the original into a success or create a fictitious successful deploy attempt.
After acceptance, execute development `--scope rules` from the approved fixed
integrated SHA, verify all three rules services and notify iOS. Backend redeploy
is unnecessary if this same-source evidence is accepted. Neither receipt history
nor actual services have been changed for this proposed reconciliation yet.
