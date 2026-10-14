# 1.1.0 post-upload evidence and installed-client registration

This follow-up targets `develop`; it does not advance the released `main` commit. The release source is `9289366258f561b2b5b040b24f461b1db008e295`. Registration waits for actual successful upload/deployment steps and inspected build metadata. A build-only artifact is not an uploaded client.

## Final-main release observations

| Surface | Workflow | Verified version/build | Deployment/upload evidence |
| --- | --- | --- | --- |
| Firebase web | [38271696281](https://github.com/hyroxseouldev/cloud_board/actions/runs/38271696281) | `1.1.0 (159.1)` in both sealed artifact and live Hosting `version.json` | Full production deployment succeeded at `2026-10-12T15:57:03.655Z`; exact main SHA / attempt 1, live rules, workout/storage/TV/isolation canary and cleanup all passed. |
| Android / shared TV bundle | [38271696288](https://github.com/hyroxseouldev/cloud_board/actions/runs/38271696288) | `1.1.0 (68)` | Actual final-main AAB accepted and Play edit committed to internal testing at `2026-10-12T16:13:02Z`; run succeeded. |
| iOS TestFlight | [38271696253](https://github.com/hyroxseouldev/cloud_board/actions/runs/38271696253) | `1.1.0 (554)` | Actual final-main IPA upload accepted at `2026-10-12T16:11:11Z`; run succeeded. ASC processing/TestFlight readiness and App Store publication are not verified. |

The verified web deployment and native uploads are registered under `1.1.0-main-9289366258f5` with new immutable workout/app fixtures, exact source tree/exporter blobs and original artifact hashes. The Android/TV entries describe the shared internal AAB; they do not assert TV public distribution. All pre-existing records remain unchanged. The new source is active in the forward reader matrix by default.

The sealed candidate artifact `11758016228` (`firebase-candidate-38271696281-1`) has scope `full`; its source/run/attempt match the table. All 144 bundled build files match their manifest hashes, including the original exports: workout SHA-256 `8daa55719daedb133adea17a8937bc6ce0f82f1bef42642ddb0c573fc4e959da`, app SHA-256 `2a8f03366d511ed327b770d7b43d8232c131bf6ec7863a7bc036a5f3dfead760`.

The final receipt was independently validated against that exact candidate manifest. Its manifest hash is `98041eaf00a8f7a15c769289c69c6d0bb82f8f1281c7b14db654550f6ec3a28c`. A cache-busted request to [live Hosting version.json](https://cloud-board-stationd.web.app/version.json) returned the exact sealed `1.1.0 (159.1)` metadata. [Machine-readable observations](post-upload-evidence.json) retain the receipt, canary and live-version summary.

Native artifact verification confirmed production Firebase binding for both packages (`com.sunmkim.cloudboard`). The IPA SHA-256 is `5694f711191ff8b8478115a772db13885f0d5ffbf77c781bbe5c431f73ecf7ea`; Apple accepted delivery `9225b102-6693-4b8d-beef-48271422decb`. The AAB SHA-256 is `72171e0985210cb88468dacf2d580e2dbf029321358578454b89b6f37d93d253`; Google Play committed edit `06468497176628521120`. All three upload/deployment workflows use the exact same main source.

## Follow-up registration checks

The complete Firebase tool unit suite passed (47 tests), and a fresh read-only GitHub inventory confirmed the latest successful uploads for all four platforms match this cohort exactly. The new fixture cohort passed current exporter/reader tests (36), all three active original-source readers (`1b6464`, `a86530`, `9289366`), and scoped Firestore/Realtime Database emulator suites. The retired two source groups remain explicit historical baselines. Old and new create/update/duplicate writes, both playback wire formats, owner isolation and rejected-write rollback remain tested. Registry/provenance checks compare against the unchanged `develop` baseline; no existing frozen record is replaced.

The reader-plan tests now cover every distinct registered source instead of assuming there are exactly four. A separate regression adds two synthetic platform registrations for one new source and proves it remains active by default and runs once; the two explicitly retired source groups cannot expand accidentally. Historical capability tests select their actual source SHA rather than assuming the last registry entry is old.

## Android preparation smoke: scope and limits

The available native smoke evidence is for preparation source `8613f130bd7a2fb24913d4bf503ccaedd04b473c`, Android `1.1.0 (67)`, [CI run 38269093137](https://github.com/hyroxseouldev/cloud_board/actions/runs/38269093137), artifact `11756557711`. Its AAB SHA-256 is `08284f0981472c6ec5380255fef665396a73b5a6dc6085d697042f080c4f9c30`.

Bundletool 1.18.3 produced a locally debug-signed APK; all 56 original native-library and Flutter-asset files were byte-identical. A read-only Pixel 3a API 33 ARM64 emulator session exercised cold launch, anonymous exploration, interval selection, local playback, pause and observed completion. This was an emulator, not a physical device or Play-installed binary. It does not verify the final main source, Google Play signing-dependent login/integrity, authenticated Firestore saves, phone/TV pairing or TV playback.

The source evidence remains under `cloudboard-stability-recovery/native-capture/prep-8613f13-67/native-smoke-evidence.json`; screenshot hashes and individual observations are recorded there. This preparation build must not be entered in the installed-client registry as a real store upload.

## Store submission and remaining checks

- Preserve the existing store images for this core release. New listing drafts/renders were not approved as verified native captures and are not part of this upload. The complete native screenshot set and TV assets remain unfinished.
- The release owner promoted the exact final-main AAB `1.1.0 (68)` to production release `3` and sent the single change for review. Play Console shows it under **검토 중인 변경사항** with **전체 출시 시작**, while quick automatic checks are still running before the review handoff. This records submission receipt, not completed checks or approval. Managed publishing is enabled; the new production release is not public. The [console screenshot](google-play-1.1.0-68-review-submitted.jpg) is retained alongside its SHA-256 in the machine-readable evidence. Existing store images and country scope were retained.
- Android TV public distribution/form-factor readiness remains separate from the shared AAB's TV activity and internal upload.
- Do not activate mandatory-update requirements until actual 1.1.0 store availability is verified. This registry follow-up does not mutate production runtime policies.
- Physical-device / final-main installed smoke and authenticated editing/storage checks remain distinct from the preparation-emulator evidence above.
