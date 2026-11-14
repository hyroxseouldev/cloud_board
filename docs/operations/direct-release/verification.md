# Direct release implementation handoff — 2026-11-14

Worktree: `/Users/sunmkim/orca/workspaces/cloudboardapp/direct-release-cli`.
Branch: `hyroxseouldev/direct-release-cli`.
Base: `origin/develop` `bcdf4c4b981ce377c5661f87f41eb09d90af4f76` (2.1.6+10,
including preparation UX and development iOS export configuration).
No changes were made to the original checkout's dirty files or unique commits.

Tested code commit: **0a762db9d16167037c56b42ccf88766404dd255f**.
The final documentation-only handoff commit reuses these code results; it does not
claim tests were rerun merely because the SHA changed.

| Evidence | Result | Type / connection |
| --- | --- | --- |
| Direct plan/scope, clean source, runtime config, pending/CAS/failure receipt, old/new reader, native source, Play upload adapter and dev readback | 16 passed | Node unit/fixture plus real offline CLI subprocess; no provider connection |
| Final changed-code subset, command below | 54 passed, 0 failed, 0 skipped | Node 22.21.1; mocked provider requests / historical artifacts |
| Release helpers + Firebase source/receipt/manifest/rules + news + backend gate | 198 passed, 0 failed, 0 skipped | Node 22.21.1 before final dev readback addition; unchanged historical tests reused |
| After latest develop integration, direct/source/environment tests | 32 passed | Commit 2500a9b9082e7379bca8e754335a6d0f5a19940f; relevant integration verification |
| Native artifact inspection | 5 passed | Python fixtures; no real IPA/AAB build |
| iOS signing inspection | 4 passed | Python fixtures; no actual keychain/profile changes |
| Six development scopes and production web dry-run | Plan only | Offline; no deploy/build/reservation/upload |
| Source `HEAD` shorthand | Rejected as intended | Full fixed 40-character SHA required |
| Ruleset 24924061 | Read only; exact before/after payload prepared | GitHub read; no settings change |
| Full app tests/build, Firebase/Hosting, TestFlight/Play, live canary | **미실행** | No execution authorization in this implementation task |
| Real service/auth/signing acceptance and target duration | **미확인** | Follow-up actual execution required |

Final changed-code command:

```sh
/Users/sunmkim/.nvm/versions/node/v22.21.1/bin/node --test \
  tool/release/direct.test.mjs \
  tool/firebase/release-cli.test.mjs \
  tool/firebase/repository-rules.test.mjs \
  tool/firebase/installed-clients.test.mjs \
  tool/update-news/*.test.mjs
```

Broader relevant script command (prior unchanged evidence):

```sh
node --test tool/release/*.test.mjs \
  tool/firebase/{repository-rules,latest-release,release-cli,workflow-scope,development-plan,release-tags,installed-clients,environments,manifest}.test.mjs \
  tool/update-news/*.test.mjs tool/class_start_regressions.test.mjs \
  tool/release_backend_gate.test.mjs
python3 -m unittest discover -s tool/release -p 'test_*.py'
python3 -m unittest discover -s tool -p 'test_ios_signing.py'
```

Local logs: `/tmp/cloudboard-direct-node22.log`,
`/tmp/cloudboard-direct-integrated-tests.log`,
`/tmp/cloudboard-direct-head-tests.log`. These are test outputs, not service
receipts. The first historical-workflow path failure was corrected and its
assertions retained. No test was deleted/skipped to remove CI.

Seven active CI/deployment workflows were moved to inert historical fixtures.
Three operational workflows remain, including the manual read-only native store
inventory. There are no active calls/needs to the removed deployment workflows.
The old starter executable now fails with the direct-command migration message.

The PR can remain blocked on `firebase-required` until the coordinator removes
only that context from ruleset 24924061 using the reviewed JSON transformer.
PR/thread, force-push/deletion and immutable version-tag protections are preserved.
Do not treat a missing status context or a handoff record check as passed testing.
Main cleanup must use a separate control-tools/workflow-only PR without promoting
unreleased develop app/server/version changes. Details and recovery are in
[the direct release guide](README.md).

The original comparison reports are reused from
`/tmp/cloudboard-cicd-comparison-2026-11-14/`. They establish historical Actions
step timing only: sample 41635107038 was 502s, with 210s combined functions/rules,
62s Flutter web compile and 19s Hosting. A comparable warm direct deployment is
unmeasured; Timo's native full-build samples do not disprove a sub-minute local
incremental experience. This change does not promise sub-minute deployment.
