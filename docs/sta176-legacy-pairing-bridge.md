# STA-176 legacy pairing bridge

The installed app continues calling `cloudboardPairDisplay` in `asia-southeast1`,
codebase `cloudboard-auth`, with `{code,name,zoneName}`. Its successful result
remains exactly `{paired:true,deviceId}`. The callable retains its existing
30-second timeout, maximum instances, non-anonymous authentication requirement,
revocation check and lack of secret bindings. The verified bearer UID must also
match the callable's authenticated UID.

The old service reserved a device and then wrote `displayAccess` using a separate
Admin operation. An already-running invocation could finish that second write
after an installed client's direct RTDB unpair. The bridge removes both writes
from this codebase and delegates to the canonical root transaction in
[STA-176 PR #63](https://github.com/hyroxseouldev/cloud_board/pull/63). That
transaction serializes pairing with unpair and enforces
the current binding, entitlement and revocation checks.

## Wire contract and failure behavior

- Destination is fixed to
  `https://asia-northeast3-cloud-board-stationd.cloudfunctions.net/pairDisplayConnection`.
  The runtime `GCLOUD_PROJECT` must be `cloud-board-stationd`. Caller-supplied URL,
  project and operation IDs are discarded. Redirects are rejected.
- After the existing revocation check, the original Firebase ID token is forwarded
  in the Authorization header. The new callable independently authenticates it.
  The bridge creates one UUID for each invocation and posts
  `{data:{code,name,zoneName,operationId}}`. It does not retry HTTP internally.
  A subsequent app invocation uses a new UUID; canonical current-binding checks
  handle repeated pairing without replaying an archived operation from an older
  use of the same six-digit code.
- Headers and response body share a 20-second deadline. Response bodies are capped
  at 16 KiB. Success requires HTTP success and `result.paired === true` with a
  valid canonical device ID. Additional result fields are dropped.
- A callable error takes precedence over a result, even on HTTP 200. Only the
  reviewed status allowlist is mapped to static Korean messages. Upstream
  messages, details, token, headers and response contents are never logged or
  returned. Network, timeout, redirect, malformed response and unknown error
  failures produce `unavailable`. A timeout can leave a committed server result;
  it does not mean the server transaction was cancelled.
- There is no Admin fallback. Missing/unavailable canonical infrastructure stops
  pairing until it is available; the old two-write implementation is not used.

The POST/header/envelope implementation follows the official
[Firebase callable protocol](https://firebase.google.com/docs/functions/callable-reference).
No new package, secret, service account, Firebase export or runtime setting is
introduced. This branch does not change the other three legacy handlers.

## Source and release guards

`functions-legacy/migration-baseline.json` still records the original production
migration. `functions-legacy/sta176-pairing-bridge.json` separately pins the new
compiled entrypoint, only the `cloudboardPairDisplay` declaration, and only
`lib/services/pairing.js`. The release tool rejects other handler/module
exceptions and a return to the original pairing implementation. All other
baseline module hashes, the dependency lock, export list, settings and secret
bindings remain checked. The candidate digest includes this reviewed delta.

The source migration in PR #62 is now merged into `develop` (`06fbd65`). This
follow-up targets `develop` and includes that base. The existing
`operations-compatibility.yml` runs the legacy build/test/source/release checks
for this target; there is no `continue-on-error` on those steps. Repository
branch-protection configuration is outside this patch; its required-check
settings were not changed or verified here.

Predeploy additionally requires canonical backend project/region/function,
deployed source SHA and successful smoke evidence in `pairingBackend`, plus
`checks.legacyPairingBridge: "passed"`. The evidence template is in
[the migration procedure](legacy-auth-migration.md). These fields are operator
attestations backed by attached evidence, not an automatic live readiness probe.

## Local validation

All commands below used Node 22 in `/tmp/cloudboard-sta176-legacy`. Tests use
synthetic data, in-memory SQL and mocked HTTP/auth. The bridge test suite disables
real fetch before every test. It sets the production project name only to test
the runtime guard with mocked transport; it is **not** a deployment to production
or an isolated development Firebase project.

| Check | Result | Local log |
| --- | --- | --- |
| `npm ci --prefix functions-legacy --no-audit --no-fund` | Passed; unchanged dependency lock | `/tmp/sta176-legacy-install.log` |
| `npm run check --prefix functions-legacy` | TypeScript build passed; 51 passed, 5 inherited Neon-only skips, 0 failures | `/tmp/sta176-legacy-develop-check.log` |
| `node tool/legacy-auth-release.mjs check` | Passed; reviewed candidate digest emitted | `/tmp/sta176-legacy-develop-source-check.log` |
| `node --test tool/legacy-auth-release.test.mjs` | 15 passed, 0 skips/failures | `/tmp/sta176-legacy-develop-release-tests.log` |

The checked candidate digest is
`57c35c3622216f3ecaa340b5650c330f7fb8ddd131002f08e60556f9f38e0b60`.
[Recorded local summaries](release/sta176/legacy-pairing-validation.txt) retain the
commands, counts and digest; `/tmp` paths above are local working logs.

`pairing-bridge.test.ts` covers verified token forwarding, anonymous/missing/
revoked/mismatched identity rejection, exact destination and response shape,
UUID isolation, ignored caller routing fields, project/input validation,
allowlisted/sanitized errors, malformed/oversized responses, network failure,
and request/body deadlines. All 24 bridge tests passed without skip.

The old in-memory two-step pairing test in `migration-contract.test.ts` was
replaced because that implementation was removed. Bridge/auth behavior is now
covered in `pairing-bridge.test.ts`; atomic pairing, idempotency, entitlement limits,
unpair races and old-client compatibility belong to the canonical reducer and
RTDB emulator tests in PR #63. The primary PR reports 208 Node tests passed and
28 Firebase emulator contracts passed with zero skips; those tests were run in
the primary worktree, not duplicated or claimed as part of this branch's 51 tests.

## Rollout acceptance (not performed)

- [ ] Complete native Android/iOS builds and released/candidate app verification.
- [ ] Deploy and verify the canonical STA-176 backend and compatible database
  rules first; record exact backend source SHA and pairing smoke evidence.
- [ ] Complete candidate-bound migration evidence, infrastructure review, fresh
  read-only inventory and unchanged configuration/secret checks.
- [ ] Deploy this bridge through the existing guarded legacy release procedure.
  Verify all old legacy function revisions have stopped receiving work and
  already-running old invocations have drained. Source replacement cannot cancel
  an invocation already executing the old two-step Admin implementation.
- [ ] Verify released-app pairing/unpairing against the bridge, retry after an
  uncertain response, revoked tokens, invalid/reused codes and concurrent
  controllers. Do not exercise customer devices during a class.
- [ ] Verify three physical Android/Google TVs, mixed old/new app versions,
  preparation → start → pause/resume → finish, router disconnect/reconnect,
  token expiry, sleep/wake and a 24-hour soak using the primary TV checklist.
- [ ] Recheck function/runtime/secret/Scheduler/Eventarc/IAM inventory and record
  before/after evidence. No production data reconciliation is automatic.

No real service requests, deployment, native build, physical-TV test or production
rollout was performed while developing this bridge. There is no production
resolution claim until the backend and bridge are deployed and old invocations
have drained. For rollback, preserve the fixed public contract and canonical
atomic mutation path; do not restore the old two-write pairing service. A safe
forward fix or temporary pairing-unavailable response is preferable while the
canonical backend is repaired.
