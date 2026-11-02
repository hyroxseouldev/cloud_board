# Class monitoring integration retired

The `forwardClassOperation` webhook integration (STA-191) is retired at the user's
request. The isolated `functions-monitoring` package, deployment helper and both
`firebase.monitoring*.json` configurations have been removed. No monitoring tag
or deployment should be created for this integration.

This removes external forwarding of class-operation events. The app's operation
event recording, history, class playback and normal Firebase codebases and rules
are unchanged. Existing event records are not deleted or rewritten.

## Cloud status

On 2026-10-29 at 16:11:52 UTC (2026-10-30 KST), authenticated read-only Cloud
Functions API requests returned `404 NOT_FOUND` for
`locations/asia-southeast1/functions/forwardClassOperation` in both API v1 and v2,
for both `cloud-board-stationd` and `timo-production-sunmkim`.

The function was already absent when checked; this change does not claim to have
deleted a live function. TIMO did not deploy this integration. No production
records, secrets, service accounts or IAM bindings were changed for this removal.
The source removal prevents redeployment from this revision; historical Git
commits and tags are retained.

Verification evidence is in [the removal handoff](verification/class-monitoring-removal.md).
