# App/TV release policy operations

`appReleases/ios`, `appReleases/android`, and `appReleases/tv` are the update-policy source. `latestBuild` is the recommended build. Platform build numbers are independent. Remote Config must not duplicate these version fields.

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
