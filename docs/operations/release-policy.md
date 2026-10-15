# App/TV release policy operations

`appReleases/ios`, `appReleases/android`, and `appReleases/tv` are the update-policy source. `latestBuild` is the recommended build. Platform build numbers are independent. Remote Config must not duplicate these version fields.

## Build, deployment and public availability

Main merges start development Firebase builds/deployments and the separate
development mobile QA path without repeating the full integration CI suites.
Development apps use `cloud-board-development` and
`com.sunmkim.cloudboard.dev`. Missing development store registration or signing
credentials must be reported by the readiness gate; do not fall back to the
production app. Development success never authorizes a production version policy.

Production candidates start with a `vX.Y.Z` tag on a commit in main history. The
tag version must match the app version, and required CI must pass for the same
tag SHA before production server/web deployment or release-mode mobile upload.
Record the tag, app source SHA, validation run, backend receipt and actual platform
upload results. Existing release tags must not be moved, deleted or reused for a
different candidate. A manual retry or recovery still requires the release's
verified source and evidence.

The repository tag ruleset blocks updates and deletion of `refs/tags/v*` without
restricting tag creation. Its versioned definition is
[`tool/firebase/release-tag-rules.json`](../../tool/firebase/release-tag-rules.json).
This is separate from main/develop branch protection. Tag creation permission
alone does not authorize deployment: the workflow still verifies main ancestry,
version, fixed SHA and the required CI result.

Release automation does not submit an app for public availability merely because
TestFlight or Play internal testing accepted an upload. It also does not
automatically enable `appReleases`, raise `minimumBuild`, or prove that users can
install the replacement. Development QA must not publish production update news.
Keep store processing, review, public rollout and update-policy activation as
separate recorded states.

## Update-policy activation

Never equate a successful TestFlight/internal-track upload with a publicly installable release. Before enabling a global policy, record an availability evidence JSON containing `platform`, `build`, `version`, `storeUrl`, `installable: true`, `track: "production"`, `sourceSha`, verified `countries`, `deviceVerification` (OS/device and actual install result), `verifiedBy`, `verifiedAt`, and an official `verificationUrl`. Verification must be within seven days. Country/device coverage is operator evidence; the command does not pretend an HTTP 200 proves installation. If public distribution is not verified, leave the policy disabled.

1. Read current value and hash:
   `node functions/tools/release-policy.mjs tv --project cloud-board-development --show`
2. Validate the proposed policy without writing:
   `node functions/tools/release-policy.mjs tv policy.json --project cloud-board-development --evidence availability.json`
3. Apply the reviewed values using `--apply --expected-hash <shown-hash> --actor <operator> --reason <reason>` and the same evidence. A concurrent change fails without overwriting it.
4. Review `appReleasePolicyHistory/<returned-id>`. The old/new policy, hashes, operator, reason, timestamp and evidence are committed atomically with the policy.
5. To restore a previous value, use `tv --restore <history-id>` with the current hash, a new reason and fresh evidence if enabling. Without `--apply`, this is read-only. Restoration creates another history row; it does not erase history.

Emergency disabling (`enabled: false`) requires no store evidence so a broken notice can be removed during a store outage. If the history's previous value was absent, explicitly supply a disabled policy instead. Policies and history remain server/admin-only writes. Do not automatically raise `minimumBuild` with every release; use it only when a documented incompatibility requires it and the replacement is actually available.

Production writes require explicit `--project cloud-board-stationd`; no default points to production. These commands prepare or change update notices only. They neither roll back installed store apps nor deploy backend rules. Use the independently verified backend repair workflow for server recovery.

TV clients read only `appReleases/tv`; they do not fall back to the phone's Android policy even though both can use the same Google Play package URL. Missing, disabled, unpublished or invalid policies and unknown installed builds leave the app usable. Store return/resume and the retry action fetch the server policy again.

TV notices appear only after a connected standby and completed recovery are confirmed. Playing or paused classes, loading/error recovery, a lost connection, the completion screen, black-screen mode and TV identification take priority immediately. The required notice keeps the display mounted and excludes its controls from pointer and remote focus. Remote focus starts on Update; directional navigation reaches Retry (and Later for optional updates). Store-opening failures stay recoverable from the notice. These changes do not publish a production update policy.
