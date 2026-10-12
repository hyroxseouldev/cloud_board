# 1.1.0 store inventory

Read-only observations made on **2026-10-12, 14:23–14:38 UTC** through the existing authenticated App Store Connect and Google Play Console browser sessions. This inventory is a dated observation, not an authorization to publish. No build was uploaded, review submission changed, track promoted, country changed, or form factor enabled.

The accompanying [sanitized evidence](store-inventory.json) contains the observed build history and source links. Secrets, review credentials, account contact information, and browser session data are excluded.

## Actual store state

| Surface | Observed version/build | Observed status | Availability evidence |
| --- | --- | --- | --- |
| iOS App Store submission | Store version `1.0`, binary `1.0.0 (548)` | Waiting for Review; submitted October 6, 13:25 KST | South Korea is the only configured country. The public Korean App Store URL returns “page not found”; public installation is not established. |
| iOS TestFlight | `1.0.0 (553)` | Latest completed upload, October 12, 16:38 as displayed; Ready to Submit, internal test group assigned | TestFlight upload and group assignment do not establish public availability. No 1.1.0 build/version appeared. |
| Google Play production, phone/tablet | `1.0.0 (52)` | Available on Google Play, full rollout; last updated October 10, 16:09 as displayed | Country targeting: South Korea. Public Korean listing is visible with Install, version 1.0.0 and Android 7.0+. No physical installation performed. |
| Google Play closed Alpha | `1.0.0 (58)` | Available to testers, full rollout | One targeted country; not a public production release. |
| Google Play internal | `1.0.0 (65)` | Available to internal testers, full rollout; October 12, 16:40 as displayed | Internal upload only. |
| Android TV public distribution | No configured TV form factor | Advanced Settings → Form factors lists Android XR as active; Android TV remains in “Add form factor” | A shared AAB containing a TV activity is not evidence of a published TV form factor or successful TV-store installation. |

App Store Connect currently has **automatic release after approval** selected for the existing `1.0` submission. It was not changed. This is independent of the repository's manual-main deployment policy. A decision about retaining the current submission or replacing it with 1.1.0 belongs to the release operator; this preparation does not cancel it.

Google Play showed no unpublished changes. The app's production form-factor selector contained phone/tablet, Desktop and Android XR, without Android TV. No Android TV policy agreement, opt-in or submission was accepted. TV activation, any required review/assets, and a real TV Play Store install remain release steps.

### Android review-submission preparation

The user subsequently authorized preparing and submitting **Android 1.1.0 for production review**. This observation pass remains read-only; the release operator owns store mutations.

- Publishing Overview shows **Managed publishing OFF**. Its selected option explicitly says updates publish automatically after approval. To preserve a separate final-publication step, turn managed publishing on before sending production changes for review and verify the saved state. Merely uploading a completed production release with this existing setting would not preserve that separation.
- Policy/Programs overview says **no policy issues found**. App Content → Needs attention says all declarations are complete. The Completed tab has 10 declarations, including Data safety and Login details; both show September 12 as their last edit. This confirms console completion status, not that the declarations fully describe every new 1.1.0 feature or that the review account still signs in. The release owner must check those against the final artifact.
- The preparation checkout delegates SDK numbers to Flutter; its installed Flutter SDK defines compile/target SDK **36** and minimum SDK **24**. These are source/toolchain expectations, not a substitute for inspecting the final uploaded AAB. New-artifact validation errors, if any, cannot be known before that artifact is validated by Play.
- TV distribution is not enabled and does not become enabled just by submitting the phone/tablet production track. Do not claim a TV production review from that submission.

Read-only sources: [Publishing Overview](https://play.google.com/console/u/0/developers/5882095575387783300/app/4975842846741924244/publishing), [monitor/policy summary](https://play.google.com/console/u/0/developers/5882095575387783300/app/4975842846741924244/monitor), [App Content](https://play.google.com/console/u/0/developers/5882095575387783300/app/4975842846741924244/app-content/overview).

## Build-number evidence

The Google Play **All App Bundles** screen was inspected across **all 47 entries on all 5 pages**, including inactive bundles. Every entry has version name `1.0.0`. Highest recorded versionCode is **65**; 1.1.0 has not been uploaded. Observed codes, descending:

```text
65 64 63 62 61 60 58 57 56 55
54 53 52 51 50 49 47 45 44 43
42 40 38 37 36 34 33 32 31 30
29 28 27 22 21 20 18 17 16 15
14 13 12 11 10 8 3
```

This supports the checked Play allocator baseline of 65 as of this observation. Requery current store state and include reservations immediately before allocating a build number; later manual or CI uploads can make the snapshot stale. Gaps in the sequence are preserved rather than inferred as unused numbers.

The TestFlight UI's sole visible version group is 1.0.0 and the descending build list starts at 553; the latest upload list also starts at completed 553. This does not replace the release workflow's live App Store Connect query before allocation. No build number was reserved during inventory.

## Source mapping for compatibility checks

| Installed/review channel | GitHub artifact evidence | Source SHA |
| --- | --- | --- |
| Play production 52 | [run 36680683610](https://github.com/hyroxseouldev/cloud_board/actions/runs/36680683610), `cloudboard-alpha-aab-52`, uploaded September 30 | `c85167e863ee5e8e9212722572ab57df65801eeb` |
| Play closed Alpha 58 | [run 37411690762](https://github.com/hyroxseouldev/cloud_board/actions/runs/37411690762), `cloudboard-alpha-aab-58` | `c54588cc7733ac8577d11c036c21635d1f283f2a` |
| iOS review 548 | [run 37411690757](https://github.com/hyroxseouldev/cloud_board/actions/runs/37411690757), `cloudboard-ios-dsyms-548` and `cloudboard-ios-signing-548` | `c54588cc7733ac8577d11c036c21635d1f283f2a` |
| iOS TestFlight 553 / Play internal 65 | [iOS run](https://github.com/hyroxseouldev/cloud_board/actions/runs/38216234409), [Android run](https://github.com/hyroxseouldev/cloud_board/actions/runs/38216234280) | `a8653077314c5e5bf2f14e1a8495e4c9ab1f1b6b` |

The artifact names retain their original upload channel. Production 52's later promotion is evidenced by the current Play Console, not by renaming the original Alpha artifact. Compatibility verification must cover the production/review source versions as well as the newest internal upload.

## Release prerequisites still open

- Resolve iOS 1.0 review/automatic-release handling before registering or submitting the intended 1.1.0 release. The current console showed only release version 1.0.
- Upload 1.1.0 through the reviewed workflow, then verify its exact build, entitlements, processing and test-group availability. Existing GitHub environment secret **names** were present: six signing/API entries in `testflight`, five signing/API entries in `google-play`; their values and validity were not retrieved or tested by this inventory.
- Complete TV form-factor registration/review if public TV distribution is intended. Verify the actual TV store, country, OS/device eligibility and remote navigation.
- Install the public/test builds on the intended physical devices and run the old/new phone × old/new TV compatibility matrix. A visible Install button or CI upload does not count as completing that matrix.
- Keep mandatory-update policy disabled until the intended audience can actually obtain the required build. This inventory did not modify `appReleases`, Remote Config or any production backend.

## Source pages

- [App Store Connect release](https://appstoreconnect.apple.com/apps/6809105126/distribution/ios/version/inflight), [review submission](https://appstoreconnect.apple.com/apps/6809105126/distribution/reviewsubmissions/details/324915d6-1543-4b31-b0a6-c67001ad84c5), [version history](https://appstoreconnect.apple.com/apps/6809105126/distribution/activity/ios/versions), [availability](https://appstoreconnect.apple.com/apps/6809105126/distribution/pricing)
- [TestFlight builds](https://appstoreconnect.apple.com/teams/009c2dd2-b685-48bd-9037-5102f2059b33/apps/6809105126/testflight/ios), [public Korean App Store page](https://apps.apple.com/kr/app/id6809105126)
- [Play release overview](https://play.google.com/console/u/0/developers/5882095575387783300/app/4975842846741924244/releases/overview), [complete bundle history](https://play.google.com/console/u/0/developers/5882095575387783300/app/4975842846741924244/bundle-explorer-selector)
- [Play production country targeting](https://play.google.com/console/u/0/developers/5882095575387783300/app/4975842846741924244/tracks/production?tab=countryAvailability), [form factors](https://play.google.com/console/u/0/developers/5882095575387783300/app/4975842846741924244/advanced-distribution?tab=releaseTypes), [public Korean Play listing](https://play.google.com/store/apps/details?id=com.sunmkim.cloudboard&hl=ko&gl=KR)
