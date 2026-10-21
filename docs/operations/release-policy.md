# App/TV release policy operations

`appReleases/ios`, `appReleases/android`, and `appReleases/tv` are the update-policy source. `latestBuild` is the recommended build. Platform build numbers are independent. Remote Config must not duplicate these version fields.

## Build, deployment and public availability

Main pushes integrate code only and do not deploy either environment. A
`dev/vX.Y.Z-N` tag on a commit in main history starts development Firebase
web/server deployment and development-app TestFlight / Play internal QA without
repeating full integration CI. The tag's version must match `pubspec.yaml`;
manual QA also requires this development tag, main ancestry and version match.
Development QA uses
the existing `com.sunmkim.cloudboard.dev` app and `development` flavor targeting
`cloud-board-development`. Release uses `com.sunmkim.cloudboard` and the
`production` flavor targeting `cloud-board-stationd`. Build numbering and upload
concurrency are separate for each app. Existing store-account credentials do not
prove development-app store registration or distribution signing access. iOS
development signing for installation on a device is already prepared; store
distribution readiness remains separately unverified. Confirm those prerequisites,
then set `MOBILE_DEVELOPMENT_READY=true` in each applicable GitHub Environment.
Until ready, QA stops before SDK installation, build and upload. The development
Play baseline is not yet present and must be based on the development app's own
verified store history.
QA does not require production backend compatibility or enter the production
installed-client ledger. Historical production-connected uploads remain tracked.
The separate app IDs retain separate app sandboxes; web environments use separate
origins. Never promote a development QA binary to public release; use the validated
production-flavor artifact.

Production candidates start with a `vX.Y.Z` tag on a commit in main history. The
tag version must match the app version. Automatic tag runs execute required CI by
default and require success for the same tag SHA before production server/web
deployment or release-mode mobile upload. Record the tag, app source SHA,
validation run, backend receipt and actual platform upload results. Existing
release tags must not be moved, deleted or reused for a different candidate.

Before either tag, finalize the displayed version in a main commit and sync that
change back to develop. A rebuild of the same displayed version increments only
the platform build number. Use a commit title such as
`release: CloudBoard 1.2.2 - 주요 변경`; its body records version, changes,
deployment intent, development/production tags and CI policy, not a claim of
completed deployment. The **Start production release** menu creates production
tags only and does not bump the version. Development tags are pushed separately.
See the [version and tag procedure](../feature-verification.md#표시-버전-확정과-태그).

Draft app update news from each platform's last actually deployed main source SHA
to the candidate main SHA, allowing for different deployment intervals. Commit
the user-facing summary in `release-notes/current.json` with the candidate version;
do not expose raw commit bodies. News appears only after deployment/upload evidence
confirms the applicable build. See [app update news](../../release-notes/README.md).

Manual Firebase tag releases and manual native `release` runs may explicitly set
`skip_ci=true` with a non-empty `skip_ci_reason` to omit heavy CI. This option is
rejected for main verification and QA. A skipped run is not a passing CI result:
audit artifacts/receipts record `skipped`, the reason, actor, run and source/tag.
Fixed source SHA, main ancestry, tag immutability and version matching remain
required, as do build, signing, environment, numbering and actual artifact checks.
Native production backend compatibility checks also remain. Firebase deploys only
the selected production scope; skipping CI does not expand deployment targets.
A manual retry or recovery still requires the release's exact source and either
valid CI evidence or the explicit audited skip.

For a new production release, the **Start production release** menu creates its
tag and dispatches once with the selected targets and CI policy. For a server/web retry,
select the existing production tag in Actions manual dispatch; that tag must
contain a workflow version supporting these inputs. Older tagged workflows may
not offer them. An external production-tag push still starts normal CI
automatically, and a separate manual run does not change an existing automatic
run into a skipped run.

### Select server, web and mobile independently

In **Start production release**, choose at least one of `deploy_server`,
`deploy_web` and `deploy_mobile`. All three default to unchecked. The menu still
requires a new version-matching tag on the fixed main commit.

| Selected targets | Firebase scope | Result after validation |
| --- | --- | --- |
| Server | `backend` | Deploy Functions and data rules/indexes; no Hosting or mobile upload |
| Web | `web` | Deploy Hosting; no server deployment or mobile upload |
| Mobile | `verify` | Validate without Firebase deployment, then upload iOS and Android/TV |
| Server + web | `full` | Deploy server, pass backend smoke, then deploy web |
| Server + mobile | `backend` | Deploy server successfully, then upload both mobile platforms |
| Web + mobile | `web` | Deploy web successfully, then upload both mobile platforms |
| Server + web + mobile | `full` | Deploy server and web successfully, then upload both mobile platforms |

Mobile means TestFlight and Play internal-track uploads, not review submission
or public rollout. Existing platform-specific manual workflows remain available
for an iOS-only or Android/TV-only run. Unselected automatic mobile workflows may
start a short preflight, but skip source preparation, SDK installation, build
and upload.

The parent release records `mobileUploadRequested` in its validation artifact.
Automatic mobile preflight checks that artifact's digest and exact source, tag,
run and attempt before proceeding. A historical receipt without the field does
not authorize an automatic upload; use an explicit manual mobile run if needed.
Missing, expired or mismatched evidence blocks the follow-up.

For manual Firebase retries, `deploy_mobile` defaults to `false`, including
server-only repairs. Select it explicitly to request subsequent mobile uploads.
Direct production-tag pushes retain the automatic path: required CI, server/web
scope determined from deployed baselines, and mobile follow-up. Use the menu
when choosing components individually.

Mobile-only uses `verify`: it retains integration checks, including a web build,
but makes no server or Hosting deployment. This path cannot skip CI. An explicit
manual platform `release` retains its existing audited CI skip option. Server
and web selections can use the existing `skip_ci` plus reason; source, artifact,
environment, compatibility and applicable deployment smoke checks remain.

To install mobile first and deploy its server later, the mobile gate accepts
either identical backend inputs or successful contracts against the actual
deployed backend copy. A reviewed `release-notes/mobile-compatibility.json`
binds the app inputs and deployed backend to executable tests, including
waiting/disabled behavior for features requiring the later server. CI uses
candidate tests and DTOs with deployed server code/rules in local emulators.
Both pre-build and pre-upload gates verify the exact app/tag/run/attempt and
current backend fingerprint. A failed, missing or stale proof blocks upload,
including a manual CI skip. Web and rules deployments retain their exact-match
gates. See [mobile-first release](mobile-first-release.md) for the procedure and
the limits of source/emulator evidence.

To deploy the same candidate's server later, manually run Firebase from the
existing tag with `scope=backend` and `deploy_mobile=false`; the app is not rebuilt.
A different source requires a new candidate and matching tag. Never move the
mobile release's tag. Existing installed apps, TV and open web sessions must
remain compatible. TestFlight/internal upload success alone does not establish
availability for installation or successful device QA.

The release tag ruleset covers updates and deletion of `refs/tags/v*` and
`refs/tags/dev/v*` without restricting tag creation. Its versioned definition is
[`tool/firebase/release-tag-rules.json`](../../tool/firebase/release-tag-rules.json).
This is separate from main/develop branch protection. Tag creation permission
alone does not authorize deployment: the workflow still verifies main ancestry,
version, fixed SHA and the required CI result or explicit manual skip record.

The development OIDC provider accepts only this repository's
`firebase-development.yml` running on a strict `dev/vX.Y.Z-N` tag for push or
manual retry events. Repository and owner IDs remain pinned; main pushes do not
receive development deployment credentials. GitHub merge commits use the PR
title and body, so main promotion PRs include version, user-visible changes,
deployment tag/target, CI choice and the update-news comparison source.

Release automation does not submit an app for public availability merely because
TestFlight or Play internal testing accepted an upload. It also does not
automatically enable `appReleases`, raise `minimumBuild`, or prove that users can
install the replacement. Mobile QA must not publish production update news.
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
