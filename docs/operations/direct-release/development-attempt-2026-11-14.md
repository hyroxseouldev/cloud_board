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
