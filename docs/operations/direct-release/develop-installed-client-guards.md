# Develop installed-client guard backport — 2026-11-14

- Worktree: `/Users/sunmkim/orca/workspaces/cloudboardapp/develop-installed-client-guards` (new clean Orca worktree, no additional worker).
- Branch: `hyroxseouldev/develop-installed-client-guards`, PR target: `develop`.
- Base: `d7c707b5efbd5b3ec187e82fdce4ab360ad2a4d6` (latest origin/develop at creation).
- Tested code commit: `ce46c8d61cb817637fceb70f92090031e66606c8`.
- Origin of the selected guards: [PR177](https://github.com/hyroxseouldev/cloud_board/pull/177), merged main `c33f1dd6e27c4e730aedd6a6ddadaa3896cc560c`.
- Final handoff adds this report only; its PR body records the final head. No main merge or whole-commit cherry-pick was used.

## Exact scope

Only six tool files changed:

- `tool/release/direct-plan.mjs`: add installed-client verification to **production backend/rules/functions** before deployment.
- `tool/release/direct.mjs`: invoke the existing installed-client reader and retain its result in the existing attempt record when that stage runs.
- `tool/firebase/fixtures.mjs`: accept exactly one `workflowRunId` or `directDeploymentId`; reject missing, malformed or ambiguous evidence. Existing frozen registrations remain immutable.
- `tool/release/direct.test.mjs`: add only two production-stage inclusion/ordering assertions.
- `tool/firebase/fixtures.test.mjs`, `tool/firebase/installed-clients.test.mjs`: reuse the main regressions for direct evidence, frozen identity/artifact/source, QA exclusion and historical registration immutability.

Five files are byte-identical to the corresponding merged-main files. The direct
test retains develop's existing allowlist/workflow/runtime tests; only the two
production-stage assertions were ported. Shared CLI/readiness/runtime fixes were
already present in develop and were not reintroduced.

## Verification and evidence reuse

On Node 22.21.1, at code commit `ce46c8d61cb817637fceb70f92090031e66606c8`:

```sh
/Users/sunmkim/.nvm/versions/node/v22.21.1/bin/node --test \
  tool/release/direct.test.mjs \
  tool/firebase/installed-clients.test.mjs \
  tool/firebase/fixtures.test.mjs
```

**32 passed, 0 failed, 0 skipped.** Mock/provider fixtures and real offline CLI
subprocesses only; no actual Firebase, Apple, Play or receipt API connection.
Log: `/tmp/cloudboard-develop-installed-client-tests.log`.

A separate offline comparison loaded the original base planner and the changed
planner with identical inputs: **16 cases passed**. All eight development scope /
mobile-upload variants are identical. Production web/native plans are identical;
production backend/rules/functions each add exactly one `installed-clients`
stage before deployment. No new development stage or API access was introduced.

The existing PR177 results for identical guard files are reused, with the focused
suite above covering integration into newer develop. Unchanged source/readiness,
Python artifact/signing and broad application tests were not repeated. No test
was removed or skipped to obtain these results. `git diff --check` passed.

Machine-readable local evidence:

- `/tmp/cloudboard-develop-installed-client-guards-2026-11-14/source-equivalence.json`: exact changed-file allowlist, main file equality and protected Git tree/blob equality.
- `/tmp/cloudboard-develop-installed-client-guards-2026-11-14/plan-equivalence.json`: before/after steps for all 16 plan cases.
- `/tmp/cloudboard-develop-installed-client-guards-2026-11-14/fingerprints.json`: original base versus tested code backend/functions/mobile fingerprints.

The repository fingerprint helpers returned identical values for base and code commit:

| Fingerprint | Value |
| --- | --- |
| `backendFingerprint` | `eb4d777670f7852ddd051263826b3efb8d8f85507b23055a7ec53ab3d3b07e75` |
| `functionsFingerprint` | `b6b342681d0d5d65f730262b63c8b2efd8002815fd2c5062150cae8a3eeca72e` |
| `mobileClientFingerprint` | `4ab2b8a4e7422215c5a593229c8598e847cc7aaccd55e54740bf0bf453371ffc` |

## Fixed development source reuse

Protected-path diff is **zero**. App/lib, native iOS/Android, functions (including
runtime/tools), functions-legacy, assets/web/config/tests, Firebase rules/config,
pubspec/lock/SDK version and release notes have identical Git tree/blob identities
to `d7c707b5efbd5b3ec187e82fdce4ab360ad2a4d6`. The workflow definitions,
`direct-runtime.mjs`, `direct-targets.mjs`, readiness, environment and development
display helpers, plus the installed-client registry are also unchanged.

Thus the already-running development backend/rules work and waiting development
iOS build can retain the exact fixed **d7c707b** source: this backport does not
change their app/backend/runtime bytes, development plan or target/config/signing
inputs. A new Git SHA alone is not a reason to restart that work. Their receipts
and observations must continue to identify the SHA actually executed; do not
relabel them as a deployment of this backport. Matching source bytes are reuse
evidence, not proof that the ongoing deployment or upload succeeded.

Only production pre-deployment inventory verification and contract evidence
validation change. No installed-client registration, support policy, user data,
app/runtime feature or development service behavior changes.

## Handoff limits

Implementation and focused regressions are complete; the coordinator owns review
and the develop squash merge. This worker did not deploy, create/update receipts
or tags, build/upload native apps, alter signing/policy/branch protection, merge
branches or touch the original dirty checkout. Actual deployment/upload status,
credentials, signing and end-to-end app behavior are **미실행 / 미확인** in this
control-only task; the separately dispatched execution owners retain those tasks.
