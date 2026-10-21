# Center template generation jobs

The existing basic-template renderer remains free and does not call AI. Center
templates use `cloudboardTemplateJobs` (asia-northeast3) to accept a durable job;
`generateTemplateJob` runs Luna and saves the final PNG independently of the app.
No existing callable, workout/slide schema, plan limit or playback contract changes.

## Contract

Authenticated, non-anonymous owners of the currently selected center may call:

- `enqueue`: `centerId`, `requestId`, `title`, `subtitle`, `rawWod`, `design`.
  `design.theme.centerRecipe` needs only `templateId` and `revision`; the server
  resolves the published catalog's recipe and private, hash-verified background.
- `status`: `centerId`, `requestId`.
- `list`: `centerId`, optional `before` (previous page's `nextCursor` request ID).
  Returns up to 20 jobs and `nextCursor` or null.
- `asset`: `centerId`, `requestId`; returns verified PNG base64, SHA-256 and
  dimensions only after `complete`. No public download token is created.
- Retry: `enqueue` with a new `requestId` and `retryOf`; source/design are restored
  by the server. Allowed only for a known retryable failure, once per failed job.

Acceptance/status return `{job, usage}` and list returns `{jobs, nextCursor, usage}`.
Jobs contain `requestId`, `status` (`pending`, `processing`, `complete`, `failed`),
the original input, design snapshot, timestamps, retryability, message and optional
artifact metadata. Client snapshots read
`users/{uid}/templateGenerationCenters/{centerId}/jobs/{requestId}`; clients cannot
write these records. Ordinary library images have no implied AI provenance and
do not belong in this job list.

## Processing and failures

Acceptance atomically reserves one existing AI-slide request and the shared Luna
budget. It never awaits the provider or launches unawaited work after responding.
Duplicate acceptance with identical input and request ID returns the same job;
changed input rejects. A Firestore trigger claims a fenced three-minute lease.
The completed model layout is checkpointed before rendering. Recovery runs every
five minutes, at most six jobs/three concurrent workers, and reuses that layout.
Each worker uploads to its own token-scoped private path, so a late worker's orphan
cleanup cannot remove a replacement worker's completed image.

An uncertain provider operation is not repeated or treated as free. A definite
rejection refunds the user request and allows explicit retry. Known local failures
also refund user usage; shared provider cost remains accounted. A crashed render
or upload resumes from its saved layout, with at most three worker attempts.
The final transaction rechecks account/center access. Account deletion locks block
access, and the existing recursive user-document/user-Storage cleanup covers jobs.

Luna selects contiguous source-line groups, headings and columns; it never supplies
replacement exercise strings or drawing commands. The compositor uses the original
strings, bundled licensed fonts and published artwork. It wraps/scales within a
readable bound, preserves the logo/header, and leaves the right body (x >= 1260 in
1920×1080 output) empty for the timer. Content too dense to retain is a visible
failure asking the user to split it; it is not silently truncated.

## Verification / rollout

Focused tests: `node --test functions/test/template-jobs.test.js` (run from repository
root) and `functions/test/template-jobs-rules-emulator.mjs` with the explicitly
local `demo-cloudboard-template-jobs-rules` project. Doubles are unit tests, not E2E.
Actual app acceptance → background Function → PNG → reopen/save must also be
verified against a development project or isolated local emulator with a dedicated
test account, recording whether real Luna was used.

Deploy the three additive Functions and Firestore rules before enabling the new
app. The renderer requires the lockfile's `@napi-rs/canvas` native optional package
for the runtime architecture (Node 22/Linux in Functions) and `functions/assets/fonts`.
The worker and recovery Functions use the existing `OPENAI_API_KEY` secret binding.
Development deployment and center catalog publication remain separate operations;
no production deployment, tag, mobile upload or release workflow is added here.
