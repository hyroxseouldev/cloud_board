# 1.1.1 post-upload evidence

Release source: `020371ce14f5f3ec3be87ee4b7947f58e488481f` ([main PR #54](https://github.com/hyroxseouldev/cloud_board/pull/54)). This follow-up registers the completed release on `develop` so subsequent compatibility checks include the clients that were actually uploaded.

| Surface | Version / build | Verified outcome |
| --- | --- | --- |
| Firebase / Flutter web | `1.1.1 (178.1)` | [Run 38530731453](https://github.com/hyroxseouldev/cloud_board/actions/runs/38530731453) succeeded. Exact-source full deployment receipt, live rules and workout/storage/TV/isolation canary including cleanup passed. Live `version.json` bytes match the sealed manifest. |
| iOS TestFlight | `1.1.1 (555)` | [Run 38530731452](https://github.com/hyroxseouldev/cloud_board/actions/runs/38530731452) succeeded; upload accepted at `2026-10-14T08:24:59Z`. Downloaded IPA hash matches the verified production-binding metadata. |
| Android / shared TV bundle | `1.1.1 (69)` | [Run 38530731410](https://github.com/hyroxseouldev/cloud_board/actions/runs/38530731410) succeeded; internal-testing upload completed at `2026-10-14T08:28:17Z`. Downloaded AAB hash matches the verified production-binding metadata. |

Native uploads use the same main source as the web release. TestFlight processing, public store availability and a physical-device smoke are not asserted by these upload receipts. No public store submission or mandatory-update policy change was performed for this release.

The immutable `1.1.1-main-020371ce14f5` workout/app fixtures come from the actual release workflow's contract artifact `11878012922`. Their payloads match the original exports; provenance records the original hashes, released source tree and exporter blobs. Existing client registrations and fixture bytes remain unchanged. The new source is active in the forward-reader matrix.

The companion website includes its PRs #9 and #10 through [release PR #11](https://github.com/hyroxseouldev/cloudboard-landing/pull/11), main `4fa45fcf916696909969d35050c722401295e91b`. Vercel production deployment succeeded. Production config/session routes returned expected responses, including unauthenticated `/api/me` rejection. The four selected `cloudboard-auth` functions are independently confirmed ACTIVE, including `cloudboardLinkAccount`. Firebase CLI returned exit 1 after successful function deployment because the region has no artifact cleanup policy; existing retention was preserved.

Existing billing and feature rollout settings remain unchanged. Audience branding continues to advertise `audience-logo-v1` / `standby`; deployment does not imply global feature activation.

Local registration validation passed 17 fixture, installed-client and reader-plan tests, as well as immutable-baseline and exact-source provenance checks. The read-only GitHub upload inventory maps all four platforms to this release. Required PR CI additionally checks the registered reader sources and Firebase contracts before merge.

Exact timestamps, artifact hashes, live rules and receipt metadata are retained in [post-upload-evidence.json](post-upload-evidence.json).
