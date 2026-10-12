# CloudBoard 1.1.0 release ledger

Tracking: [STA-143](https://linear.app/clyrdev/issue/STA-143). The candidate includes [PR #44](https://github.com/hyroxseouldev/cloud_board/pull/44) at `7d12923490b2f8ced04f0977117c3fdef3256142` and this release-preparation change, plus PR #45 (remove automatic Linear deployment posts while retaining app update news). The final source SHA, artifact hashes and CI runs must be recorded after the candidate is committed; a branch name is not a release identity.

## Authorized scope and current state

**Owner decision, October 13, 2026 KST:** there are no active users according to the owner, who explicitly authorized shipping 1.1.0, merging main and running automatic deployment. Forward semantic support for exactly public Android 52 and the source shared by review iOS 548 / closed Android 58 is retired in `tool/firebase/support-retirements.json`. This is a declared support change, not a compatibility fix or remotely verified usage count. [STA-144](https://linear.app/clyrdev/issue/STA-144) is follow-up work, not a release blocker. Original failures, frozen fixtures, current reads of old data and historical writes against current rules remain covered; the latest two source groups must still pass.

The owner explicitly requested **Android 1.1.0 submission for Google Play production review**. An internal-track upload alone does not fulfill that request. Public rollout remains manual. iOS preparation does not authorize replacing the existing 1.0 review submission. The current store baseline and source mappings are in [store-inventory.md](store-inventory.md).

Google Play managed publishing was disabled at inventory time. It was **enabled on October 12, 2026** to preserve manual publication while preparing the authorized production-review submission; the publishing overview confirmed the enabled state ([screenshot](managed-publishing-enabled.png)). No release or listing changes were submitted by this settings change. Verify it remains enabled before sending the production release and listing changes for review. Do not click the final publication action as part of review submission.

| Evidence | Status / source |
| --- | --- |
| Candidate marketing version | `1.1.0` in `pubspec.yaml`; workflows derive the release name from it |
| Android package / iOS bundle ID | `com.sunmkim.cloudboard`, preserved |
| Production Firebase | `cloud-board-stationd`; validate native resources and compiled Dart binding in the actual signed binary |
| Android previous public binary | `1.0.0 (52)`, Korea, full rollout |
| Highest historical Play upload | `65`, confirmed across all 47 uploads; reserve a fresh number immediately before each build |
| iOS previous review / latest test binary | Review `1.0.0 (548)` / TestFlight `1.0.0 (553)`; not evidence of public availability |
| Candidate IPA/AAB | Build-only preparation at `f7c064210fce45063b53e87a3b2b5db4dd1ddd4b`: [Android run 38265566752](https://github.com/hyroxseouldev/cloud_board/actions/runs/38265566752), [iOS run 38265571411](https://github.com/hyroxseouldev/cloud_board/actions/runs/38265571411); iOS passed as 1.1.0 (554), including signing, production Firebase and arm64 AOT binding; Android 66 compiled/signed but its inspector rejected bundletool STR formatting, now fixed and covered by regression tests; a new Android build is required |
| Final app + Firebase contract CI | Pending final candidate SHA; earlier PR #44 results do not replace this check |
| Production backend receipt for candidate | Main promotion and automatic deployment authorized; exact-SHA receipt pending |
| Upgrade and mixed phone/TV validation | Pending [physical-device matrix](device-validation.md) |
| Google Play images and copy | [Google Play materials](google-play/); widget render drafts must be replaced with verified candidate captures before submission |
| Production review / public rollout | Not submitted / not published by this preparation record |

The local application baseline at `f7c0642` passed analysis and **860 Flutter tests**. Release-helper checks passed **11 Node tests and 4 Python tests**. These checks do not establish retired-client forward compatibility; the separate historical audit preserves those failures and the explicit support decision.

## Build and evidence sequence

1. Freeze the candidate commit. Run the required app and Firebase contracts on that exact candidate, including all active released-source readers and explicit retirement evidence. Preserve old fixtures; do not label an unuploaded 1.1.0 candidate as an already released client.
2. Run the existing native workflows on the trusted `release/*` branch with their upload input set to `false`. They sign and retain artifacts but skip the backend deployment wait and store upload. Android reservations are append-only and consumed even if a build fails; re-runs allocate another code.
3. Inspect retained metadata reports. They must identify version 1.1.0, fresh platform build number, the unchanged app identifier, production Firebase resources, all release Dart architectures and the expected signing identity. Store the artifact SHA-256, source SHA, workflow run and attempt in the release record.
4. Prepare manual main promotion only after checks pass. Main push currently starts the Firebase production/web workflow and can start native upload workflows; it is not merely a branch move. The owner explicitly authorized this production step in the October 13 conversation. A build-only run must never be treated as a successful store upload or backend receipt.
5. Before any actual client upload, require the successful **same-main-SHA full backend receipt**, live-rule read-back and client permission canary through `tool/release_backend_gate.mjs`. Do not bypass the gate by manually uploading an earlier preparation artifact. If promotion changes the SHA, build and inspect a new candidate with a fresh build number.
6. Upload the verified Android candidate to internal testing, perform the device checks, and promote **that same AAB** to production review with the verified Korean listing materials and release notes. Verify managed publishing is on and the release/listing changes have actually been sent for review. Record the submitted versionCode and timestamp, not just the existence of a draft release.
7. When the owner later publishes, verify actual Play installation/update and listing appearance in Korea. Do not enable mandatory updates or register availability while review is pending. Keep minimum supported builds unchanged until actual availability is verified; only then apply the owner-authorized update policy.

## Candidate contract and release registration

The required Firebase CI artifact retains `build/contracts/workout-save-current.json`, `app-current.json`, the historical-reader report and the sealed candidate manifest. These are the actual candidate serializers and protocols; preserve them alongside the native artifact evidence. This candidate evidence is distinct from `tool/firebase/supported-clients.json`, whose entries describe already uploaded client builds.

After an actual upload, append the immutable serializer exports, exact uploaded source SHA, version/build, channel and successful upload run to the supported-client registry before the next backend change. Do not overwrite old exports or invent an upload run for a preparation build. Keep the split and legacy playback protocols represented. Public 52, closed 58 and iOS review 548 remain frozen historical-data baselines; their forward semantic support is explicitly retired. The latest test clients remain active forward compatibility baselines.

## Stop and recovery

Stop review/publication or rollout expansion for wrong Firebase/signing/version metadata, inaccessible old data, cross-owner access, authentication or subscription regression, lost pairing, failed lesson start/resume, or interrupted ongoing lessons. Retain the prior artifact and source mapping. A server rollback must still accept data written by the new client; an installed mobile build cannot be downgraded by stopping its rollout. If a binary fix is required, use a new version/build and repeat validation.

Do not equate CI success, internal upload, review approval, public availability, or a real-device upgrade. Record each separately, including pilot-center lesson outcomes and operation attempt counts before choosing rollout thresholds.
