# Installed client compatibility

`tool/firebase/supported-clients.json` is the append-only support ledger. A
server/rules rollout must continue to accept every registered client. A store
submission, internal-track upload or Hosting publication does not mean older
installations or already-open browser tabs have disappeared.

## Recorded releases

| Client | Version/build | Contract source | Scope of evidence |
| --- | --- | --- | --- |
| Reported historical iOS client | 1.0.0+2 | `1b64643860d2385d797dafba3db954063d28384f` | Frozen workout writes, both storage schemas |
| iOS TestFlight | 1.0.0+553 | `a8653077314c5e5bf2f14e1a8495e4c9ab1f1b6b` | Shared Flutter workout, preferences and playback v1/v2 serializers |
| Android internal | 1.0.0+65 | same | Same shared serializers |
| TV internal | 1.0.0+65 | same | Same serializers, paired-display access checked by emulator |
| Production web | 1.0.0+142.1 | same | Same serializers; includes tabs still running the previous bundle |

The October 12 fixtures were exported after release from a clean detached
checkout of that exact source commit, with its original exporter tests. They are
reproducible source-level fixtures, **not captured production requests** or a
claim that every native SDK/device behavior was tested. Their `provenance`
records the Git tree and exporter blob; the registry records successful release
workflow IDs. iOS/Android/TV/web share one set of payloads because their released
serializer source is the same. The historical iOS fixture is retained unchanged;
it is not relabeled as evidence for unrecorded historical builds.

## Required checks

`node tool/firebase_contracts.mjs` verifies frozen file hashes and the registry
against a trusted base commit. Changing a file and updating its hash, removing a
platform, changing a build number or deleting an old contract all fail. It then:

1. Exports the candidate app's real write payloads.
2. Checks retained fields, types and schema/protocol versions against frozen
   contracts. A schema upgrade requires a parallel wire format and an explicit
   rollout, rather than replacing the existing serializer.
3. Runs Flutter reader/edit tests against every recorded workout and the frozen
   preferences/playback contracts.
4. Checks out each distinct released source commit and executes its actual Dart
   readers and serializers against the candidate payloads. Dependency lockfiles
   are enforced; candidate application code is never copied into those checks.
   A report and logs are saved in `build/contracts/released-readers/`.
5. Replays both frozen and current payloads against candidate Firebase rules,
   including denied foreign/unauthenticated writes and paired-TV permissions.

These fixtures do not exercise every possible user document. New timer types,
enum values, optional fields and callable API changes need focused compatibility
tests in addition to the baseline. Use emulator tests for access policy, actual
released Dart readers for parsing behavior, and device QA for platform-specific
SDK/offline behavior.

The oldest serializer drops the later optional `designFingerprint` cache value.
This known, non-semantic omission is explicitly scoped in
`tool/firebase/compatibility-policy.json`; it is safe because missing fingerprints
recompute rendering rather than change workout content. Unlisted lost values
fail the historical serializer test. Exemptions need a specific path and reason;
an entire object cannot be exempted. The harness exercises DTOs after normal
v1/v2 snapshot hydration, while negotiation/permissions are tested separately.

## Schema changes while older clients remain installed

- Add optional fields with safe read defaults. Keep legacy field names, types,
  authorization paths and callable endpoints working during the support period.
- Deploy rules/backend compatibility before distributing a new writer.
- An old app doing a full-document write can discard a new field it does not
  know. A preservation fix in a new app cannot retrofit an already-installed
  version. Do not make future-only fields indispensable in a document overwritten
  by those clients. Store independently owned new data separately or retain a
  server-owned legacy adapter until those versions can be retired.
- Never activate a destructive migration merely because the latest build has
  been uploaded. Default migrations are dry runs and require an explicit,
  reviewed compatibility rollout.
- Negotiate TV wire capabilities for all selected devices, including offline
  devices. Missing capability metadata means legacy support, not the newest
  protocol. Disable only the incompatible new feature; keep existing classes
  usable.

## Registering the next released serializer

1. Check out the exact released commit in a clean, isolated worktree and install
   its pinned dependencies. Run its original
   `tool/export_workout_save_fixtures_test.dart` and
   `tool/export_app_contracts_test.dart` exporters.
2. Copy the resulting JSON into new uniquely named files under
   `functions/test/fixtures/workout-save/` and `app-contracts/`. Add the client,
   source commit, Git tree and exporter blob provenance. Do not regenerate an
   existing fixture with candidate code.
3. Append its registry entry with SHA-256 hashes and the real successful
   workflow/build/channel records. Reuse a shared contract only when the
   released serializer source is actually shared. Keep every existing entry.
4. Run the complete compatibility suite and retain the report with the release.

Contract retirement is a separate policy/rollout change requiring evidence about
installed versions and a deliberate support decision. A failing release is
never repaired by deleting its failing old-client fixture.

The required CI contract job also checks the latest actual iOS upload, Android/TV upload and Hosting publication against this registry (`tool/firebase/installed-clients.mjs`). It inspects successful upload steps, including uploads followed by a failed cleanup step, and excludes backend-only repairs. A missing source/run entry blocks the next change until the released client's immutable contracts and release metadata are registered. GitHub lookup failure is an explicit failed check, not permission to assume compatibility.
