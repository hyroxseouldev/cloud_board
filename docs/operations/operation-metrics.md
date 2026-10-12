# Operation attempts and results

New clients send bounded operational metadata through the authenticated
`recordOperationTelemetry` callable. The existing error diagnostic/alert path is
unchanged. Counts cover instrumented clients only; historical releases cannot
retroactively report successful attempts. Shipping the backend alone does not
activate client instrumentation.

| Action | Attempt / success boundary |
| --- | --- |
| `workout.save` | A new/update/copy save reaches the save use case / its server write resolves. UI validation or a rejected edit before submission is outside this metric. |
| `tv.prepare` | A targeted TV's preparation operation starts / its assets prepare successfully. Cancellation is separate. |
| `playback.control.submit` | An accepted controller command starts / the server mutation resolves. This does **not** establish TV receipt. |
| `playback.control.ack` | A server-accepted command targets TVs / every selected, paired TV reports the exact session and expected revision. |

Acknowledgement observation is passive and bounded to one outstanding command
per controller, with a 12-second timeout. It never delays controls or resends
commands. A newer accepted command, changed session/revision/author/target set,
account/screen disposal or an unobservable stream cancels the measurement.
Missing exact receipts at the deadline fail with `timeout`; an old session's ACK
or a newer revision never becomes a success. The revision after a control is
conservatively matched to its observed baseline plus one; intervening revisions
are cancelled rather than attributed to that command. Sessions without explicit target IDs (local-only playback or legacy broadcasts)
have no TV acknowledgement attempt.

Metadata contains a random operation ID, allowlisted action/outcome, duration,
platform, installed version/build and controlled failure code. The server adds
an opaque per-operation key and derives `account`/`display` role from verified
Auth (anonymous users must be paired TVs). No workout text/title, image URL,
device ID, email, token, phone number or raw error is accepted or logged. The
server's private limiter document is account scoped and removed on deletion.

Each account is limited to 120 events/minute and 4,096/day, with at most 256
recent deduplication entries in one document. Expired documents are cleaned by
the existing daily cleanup job. The client persists at most 128 events for 24
hours, scoped to Firebase project and account, and retries without blocking the
operation. Sign-out/account changes discard the previous account's queue.
Operation completion and telemetry delivery are independent: crashes, offline
expiry, queue limits, telemetry throttling, sign-out, or log ingestion failure
can leave outcomes absent. These are **pending/unknown**, never successes.

In Cloud Logging select the intended project and filter:

```text
jsonPayload.message="operation_telemetry"
```

Export the matching entries as JSON, including enough history for outcomes
(the client can deliver up to 24 hours late), then run:

```sh
node functions/tools/operation-metrics.mjs operation-logs.json
```

The pure aggregator deduplicates by the server's opaque operation key and groups
by action, platform, installed version/build and trusted role. `attempts` counts
the union of observed attempts and terminal outcomes, since an outcome implies
an attempt even when the initial event is missing. `observedAttempts` and
`outcomeWithoutAttempt` expose that coverage difference. `success`, `failure`,
`cancelled` and `pending` remain separate. `failurePerAttemptRate` is
failure/attempts; `completedFailureRate` is failure/(success+failure), and is
null without a completed outcome. Always display pending, cancellation and
coverage counts alongside either rate; neither rate estimates every installed
user's experience. Compare equivalent cohorts/time windows and allow delayed
outcomes before investigating a change. Do not infer a healthy service from an
empty log result. The initial change adds measurement and aggregation, not a
new production alert policy or automatic release decision.
