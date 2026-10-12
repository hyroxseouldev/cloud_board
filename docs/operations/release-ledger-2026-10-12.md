# Release/support evidence — 2026-10-12

This records verified upload/hosting evidence separately from public availability. Source SHA: `a8653077314c5e5bf2f14e1a8495e4c9ab1f1b6b`.

| Role/platform | Build | Verified route | Deployment evidence | Public install verification |
| --- | --- | --- | --- | --- |
| iOS app | 553 | TestFlight upload | [successful workflow](https://github.com/hyroxseouldev/cloud_board/actions/runs/38216234409) | Pending country/device/App Store verification |
| Android app | 65 | Google Play internal track | [successful workflow](https://github.com/hyroxseouldev/cloud_board/actions/runs/38216234280) | Pending country/device/public-track verification |
| Android TV | 65 | Google Play internal track | Same Android package/workflow, TV role | Pending actual TV Play Store installation and remote navigation |
| Web | 142.1 | Firebase Hosting | [successful workflow](https://github.com/hyroxseouldev/cloud_board/actions/runs/38216234276) | Hosting available; cached older web clients remain supported |

Frozen payloads/readers and protocol support are registered in `tool/firebase/supported-clients.json`; original iOS `1.0.0+2` support is preserved. Upload success alone does not justify raising a minimum version. Build numbers are independent per platform.

Read-only Firestore check at `2026-10-12T13:31:39Z`: production `appReleases/ios`, `appReleases/android`, and `appReleases/tv` are all absent. Therefore no server-published minimum/recommended update requirement was active at that observation. This task did not publish a production policy.

Before enabling a global update policy, the operator must record actual store availability by country, track, OS and device, attach installation evidence using [release policy operations](release-policy.md), and verify the intended user can update. Current TestFlight/internal-upload facts must not be presented as public release facts.

## Device acceptance still required

Record old/new phone × old/new TV combinations using supported installed releases: save, start, pause, resume, background/return, network loss, reconnect, duplicate/expired command suppression, and offline continuity of already received content. Record account access for ordinary/trial/paid accounts and rejection for another owner or unpaired device. Emulator/unit test success is not physical-device verification.

For a controlled pilot, assign a responsible operator and stop expansion immediately on confirmed lesson interruption or data loss. Observe total attempts and terminal outcomes by platform/build before selecting numeric alert thresholds. Policy restoration, backend recovery, and installed-app downgrade are different operations; a policy change does not uninstall or downgrade a store app.
