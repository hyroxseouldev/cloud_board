# 1.1.0 installed-client compatibility audit

**Disposition updated on October 13, 2026 KST:** the owner declared that there are no active users and explicitly instructed shipping 1.1.0. `tool/firebase/support-retirements.json` records that conversation as the authority to retire forward semantic support for exactly the two failing source groups below. This is an owner declaration, not remotely verified usage telemetry. Frozen records, the failure evidence below, current reads of old data and old writes against current rules remain covered. The latest two source groups still must pass. No mandatory-update policy is activated; that requires actual store availability of 1.1.0 first.

The original audit found a STA-144 release blocker: actual Google Play production build 52 and the source shared by App Store review build 548 / Play closed build 58 do not preserve current timing and design semantics. These findings are preserved rather than claimed to be fixed. A successful latest-internal-build test does not establish compatibility with the retired clients.

Source/build mapping comes from the [store inventory](store-inventory.md). [Machine-readable evidence](compatibility-evidence.json) records the candidate export hashes, unchanged exception-policy hash, reader-harness hash, source SHAs, test counts, failure reasons and log hashes. This audit did not deploy rules, upload binaries or change store settings.

The subsequent [retirement verification](retirement-evidence.json) records successful active readers and the two explicit `retired` dispositions, bound to the new retirement-policy hash. The original failing audit above remains an accurate historical record.

## Results

| Original source | Actual release association | Reader/serializer and timer tests |
| --- | --- | --- |
| `c85167e863ee5e8e9212722572ab57df65801eeb` | Android production 52 | 2 passed, 10 failed |
| `c54588cc7733ac8577d11c036c21635d1f283f2a` | iOS review 548 / Android closed 58 | 2 passed, 10 failed |
| `1b64643860d2385d797dafba3db954063d28384f` | Previously registered 1.0.0+2 source | 12 passed |
| `a8653077314c5e5bf2f14e1a8495e4c9ab1f1b6b` | iOS internal 553 / Android internal 65 / registered web build | 12 passed |

Supporting checks passed: original historical exporters (2 tests per old source), current exporters/current readers of all frozen records (27 tests), registry and reader-plan tests (10), frozen provenance, current wire shape, and Firestore/Realtime Database emulator suites. Current and all registered historical create/update/duplicate writes remain permitted by the candidate rules. Permission success alone does not prove the old writer preserves new content.

The old sources support document schemas 1 and 2 and playback wire protocols 1 and 2. They advertise timing/playback capability 3. Their new frozen fixtures therefore record their actual two fixed-timer scenarios, preferences and both playback envelopes. They do not fabricate support for newer maximum/open timer modes. Existing frozen files and the six current save scenarios remain unchanged.

## Reproduced semantic failures

Both old module serializers discard `timingVersion`, `timerMode`, `timerDirection`, `rounds`, `roundRestSeconds` and `includeFinalRoundRest`. They also discard newer title/subtitle/design fields; build 52 additionally lacks the later template layout, font, italic and spacing fields. The strict preservation test reports missing field paths rather than silently accepting defaults. No new compatibility exceptions were added.

The original [build-52 save path](https://github.com/hyroxseouldev/cloud_board/blob/c85167e863ee5e8e9212722572ab57df65801eeb/lib/src/app/feature/workouts/data/datasources/workout_firestore_data_source.dart#L144) decodes into its old entity, re-encodes known fields and uses `transaction.set(reference, json)`. It preserves legacy root settings, not unknown module fields. Editing a newer workout with this installed client can therefore erase its new timing/design settings. The same path exists in the 548/58 source.

Playback tests use valid current editor factories and `timingValidationError == null` inputs:

- Fixed 60-second timing advances correctly in all four sources.
- For Time with a 60-second cap should remain on its result until coach action. At 61 seconds the old algorithms advance to index 1 instead of retaining index 0.
- Unlimited For Time should have an unlimited duration (`0`) and show elapsed time. Both old algorithms turn it into a 1-second phase (`1000` ms).

These behavioral tests are separate from serialization/rules fixtures. The latter deliberately exercise raw DTO fields; some maximum/open DTO combinations are not playable timer inputs. They are not used to assert playback behavior.

The current start path already checks required timing capability before sending advanced timers to an older TV (extended timing requires 4, timing version 3 requires 5). Therefore these tests do **not** establish that a current phone bypasses that guard. They establish that the old algorithms cannot safely interpret those semantics if reached, and that old writers cannot preserve them. Old controller/start/control and overwrite protection remain STA-144 work.

Raising the workout document schema without a compatible old-client access path is not a complete fix: the old decoder rejects unknown schema versions, and a rejected document can fail the whole workout query. Do not replace silent corruption with a broken library.

## Reproduction and provenance

`tool/firebase/historical_contract_export_test.dart` is injected into an exact detached checkout for each historical SHA, followed by `flutter pub get --enforce-lockfile`. It calls that source's real Firestore save and preferences save methods with recording transport fakes; original serializers and entities are unchanged. Playback envelopes use the original model and original split-protocol selector. The short-lived commit notification command is not represented as persisted playback state. The frozen records include the source tree, original source/lockfile blob hashes, and export-harness SHA-256.

Run candidate exporters and current readers:

```sh
flutter test tool/export_workout_save_fixtures_test.dart tool/export_app_contracts_test.dart test/released_client_contracts_test.dart
node --test tool/firebase/fixtures.test.mjs tool/firebase/released_readers.test.mjs
```

Run each original released reader and algorithm against those candidate exports:

```sh
FLUTTER_BIN=/absolute/path/to/flutter node tool/firebase/released_readers.mjs
```

Before the explicit retirement decision, the final command exited nonzero for the two actual old sources, as captured in `compatibility-evidence.json`. It now records those exact sources as `retired`, including the full authorization, and still requires both active source groups to pass. The manifest binds the retirement policy hash and exact per-source disposition; arbitrary skipped readers cannot pass. No installed build or historical fixture was removed from the registry.
