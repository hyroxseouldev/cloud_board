# CloudBoard 2.0.0 installed-client contracts

The required `firebase-contracts` job checks the latest actual native uploads and
Hosting publication against `tool/firebase/supported-clients.json`. This entry
registers the already deployed 2.0.0 clients so the next candidate can validate
their contracts. It does not deploy an app, server or rule change.

## Released source and platform evidence

All four platforms share source
`ca86c80c95da701299f91fd3a7cb82a003faf0ce` (`v2.0.0`), tree
`2a6ebd4ec5536aed1041305a8eccaa3713d2f8ab`.

| Platform | Version / build | Channel | Actual successful upload/publication |
| --- | --- | --- | --- |
| iOS | 2.0.0 / 561 | TestFlight | [39601946387](https://github.com/hyroxseouldev/cloud_board/actions/runs/39601946387), 2026-10-21 21:58:52 KST |
| Android / TV | 2.0.0 / 76 | Play internal | [39601950946](https://github.com/hyroxseouldev/cloud_board/actions/runs/39601950946), 2026-10-21 21:56:10 KST |
| Web | 2.0.0 / 248.1 | Production Hosting | [39604165354](https://github.com/hyroxseouldev/cloud_board/actions/runs/39604165354), 2026-10-21 22:03:33 KST |

Native source receipts identify production `com.sunmkim.cloudboard` and
`cloud-board-stationd`; artifact SHA-256 values and source-receipt archive hashes
are retained in the ledger. Internal upload is not store review, general public
availability or device-installation evidence.

## Original exporter output reused

The original source's exporters ran successfully in
[backend run 39600831711](https://github.com/hyroxseouldev/cloud_board/actions/runs/39600831711),
step `Export candidate payloads for retained live smoke (not integration CI)`,
at 2026-10-21 21:36:52 KST. This registration reuses that output; it does not run
current-candidate exporters to reconstruct an older client.

| Original file | Original exported bytes SHA-256 |
| --- | --- |
| `app-current.json` | `65b4f2fc726c003d55bb5b1ad7fdd939192fbb6819c54749bcda0ec4c77b0820` |
| `workout-save-current.json` | `4e5b41c3e2302b40e9ea066b813bdb9d47b5e001e83aeb0d0e6aabc35c9f59f9` |

- Original archive: `firebase-smoke-inputs-39600831711-1`, ID `12345598286`,
  SHA-256 `b073672ac953527f2e621c19efddfc2fc6f0e380fd7ae89c0deaa9769f670e58`.
- Deployment receipt archive: `firebase-release-39600831711-1`, ID `12346795075`,
  SHA-256 `8975cbd4134a9addcf5db440c5d345ec74705440c45f967b71e26c35abc2950e`.
- Receipt manifest hash:
  `d70571973d6a71159a97c92795393032a77478a31aa4367e2d59e81a41460819`.
- App exporter blob: `3bd8cd2e7db68fa023c9bfbe34657626cb513143`.
- Workout exporter blob: `90d71feea180509156e9ce7bc78a13cf060a17fc`.
- Released `pubspec.lock` blob: `f04dd90b7ae7a65ac26c1603a3bdfe19af6c3031`.

The downloaded archive hashes match GitHub artifact digests. Exported bytes
match both smoke metadata and the release manifest; the manifest's canonical
hash matches the receipt. Source-tree and exporter blobs resolve from the exact
released commit. The two new `2.0.0-release-ca86c80c95da.json` fixtures preserve
the original payloads and add client/source/provenance metadata; their frozen
file hashes therefore differ from the raw export hashes above. Existing fixture
bytes, registry entries, validators and compatibility exceptions are unchanged.

## Registration validation

- `node --test tool/firebase/fixtures.test.mjs tool/firebase/installed-clients.test.mjs`:
  **13 passed, 0 failed**. The sample current payload now explicitly selects the
  latest released 2.0.0 source. Previously it used the 1.0.0 payload, whose null
  `workGaugeColor` cannot stand in for the newer string field. The existing
  field/type/protocol and immutability checks remain; an additional negative
  case rejects using the old payload as the new contract.
- `verifyFixtures('ca86c80c95da701299f91fd3a7cb82a003faf0ce')`:
  passed frozen hashes, append-only registry, source-tree and exporter-blob
  verification against the released baseline.
- `verifyInstalledClients(...)` with read-only GitHub API/artifact requests:
  passed and identified the exact three runs in the platform table, including
  the native source/artifact hashes. No Firebase data was read or written.

The 2.0.0 release's heavy CI was explicitly **skipped**, not passed. Successful
export generation, native upload, backend canary and this registry validation
do not replace full compatibility CI. The next mobile-only release will use its
own required CI; app behavior, emulator suites and native builds were not rerun
for this registration. No tag, workflow dispatch or store submission was made.
