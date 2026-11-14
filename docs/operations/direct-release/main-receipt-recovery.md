# Main receipt recovery port — 2026-11-14

- Worktree: `/Users/sunmkim/orca/workspaces/cloudboardapp/main-direct-receipt-recovery` (new clean Orca worktree; no helper worker).
- Branch: `hyroxseouldev/main-direct-receipt-recovery`; target: `main`.
- Main base: `c33f1dd6e27c4e730aedd6a6ddadaa3896cc560c`.
- Original fix: `4c90cfc70290fb6fddc4a8eb8fdb0069f3aa7429`, integrated by [PR179](https://github.com/hyroxseouldev/cloud_board/pull/179) into develop `ff1eb303332c9f532ccf84124d8e28223565033e`.
- Tested code commit: `519a72f563f40925da77679c74ed1c936db94c4c`. The final handoff commit adds only this report; the PR body records its head.

## Selected changes

Only the five requested control paths were patched; no whole develop merge or
cherry-pick and no development provider JSON/failed-attempt document was copied:

- `tool/firebase/direct-readback.mjs`: existing Firebase CLI login refresh requests its already-granted `firebase` scope instead of `firebase.database`; ADC behavior is unchanged.
- `tool/firebase/release.mjs`: direct execution uses a fresh `gh api` child process even with an in-memory GitHub token.
- `tool/release/direct-receipts.mjs`: uncertain PUT response triggers one latest-ledger read; accept only complete intended-document equality, never retransmit the PUT or overwrite another owner. State is cloned; only the latest pending owner can update, and terminal history is immutable.
- `tool/release/direct.mjs`: successful deploy/upload operation remains successful if its subsequent receipt save fails, with `receiptPersistence: unconfirmed`; overall failure remains distinguishable. Successful Firebase command exit, completion-marker presence, exact project/targets and stdout digest are retained without raw output or secrets.
- `tool/release/direct.test.mjs`: port the transport, persistence, conflict/terminal-owner and Firebase-login scope regressions while preserving main's existing tests.

All four implementation files are byte-identical to the original fix. The only
`tool/firebase` / `tool/release` difference from that fix is the existing main
specific direct-test content (main allowlist and active-workflow checks). Its
added/deleted lines are identical before and after this port.

## Focused verification and reuse

Original PR179 [evidence](https://github.com/hyroxseouldev/cloud_board/blob/4c90cfc70290fb6fddc4a8eb8fdb0069f3aa7429/docs/operations/direct-release/development-attempt-2026-11-14.md)
reports **43 passed, 0 failed/skipped** for:

```sh
node --test tool/release/direct.test.mjs \
  tool/firebase/release-cli.test.mjs tool/firebase/latest-release.test.mjs
```

That result is reused for identical helpers and historical receipt-reader tests;
it is not reported as a new run on main. The main-specific suite was rerun at the
tested code commit above using Node 22.21.1:

```sh
/Users/sunmkim/.nvm/versions/node/v22.21.1/bin/node --test tool/release/direct.test.mjs
```

**22 passed, 0 failed, 0 skipped**. This covers the imported fixes, pending-before-
work, main function-selection/configuration guards and six-scope offline plans.
The transport test uses a local fake `gh`, and provider calls are mocked; no real
Firebase/GitHub receipt/Apple/Play API was called by the tests.

`git diff --check` passed. Local evidence:

- `/tmp/cloudboard-main-receipt-recovery-tests.log`
- `/tmp/cloudboard-main-receipt-recovery-2026-11-14/source-equivalence.json`

## Source preservation and limits

The machine comparison enforces the five-file code allowlist and **zero** changes
to app/lib, native iOS/Android, functions (including runtime/tools), functions-
legacy, assets/web/config/tests, Firebase rules/config, pubspec/lock/SDK version,
release notes and active workflows. Git tree/blob IDs match the original main.
Main app version remains **2.1.0+8**.

Source/version/tag checks, signing, production/development targets, installed-
client policy, backend compatibility, omit/managed endpoint boundaries and runtime
configuration checks remain unchanged. Legitimate production configuration
mismatches still block execution; this fix does not weaken those checks or
inherit development provider configuration. The three operational workflows stay
unchanged and no CI/deploy trigger is added.

Implementation and focused main integration checks are complete; the coordinator
owns final diff review and the main merge. This worker did not execute a service
operation, repair/write a receipt, create a tag, change policy/ruleset/signing,
build/upload an app or alter the original dirty checkout. Actual production
credentials, deployment, readback and store behavior are **미실행 / 미확인** here.
The separately recorded development provider evidence is not claimed as a main
production result, and an old failed receipt is not converted into success by
this code port.
