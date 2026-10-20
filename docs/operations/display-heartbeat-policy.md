# Display heartbeat policy (STA-197, 1.3.5 candidate)

The 1.3.5 app selects a default 60-second heartbeat and 180-second no-response
threshold. User decision on 2026-10-20: require the new app at rollout; do not add
center allowlists or a staged mixed-version rollout. This code does not publish
Remote Config, raise an app minimum build, deploy a server, or release an app.

## One policy

Firebase Remote Config parameter `cloudboard_display_heartbeat_v1` contains:

```json
{
  "schemaVersion": 1,
  "revision": 1,
  "heartbeatIntervalSeconds": 60,
  "noResponseTimeoutSeconds": 180
}
```

Only integer revisions >= 0, intervals 10–120 seconds, and timeouts at least
three intervals and at most 600 seconds are accepted. Revision 0 is the built-in
policy; published revisions must increase (start at 1). Reusing a revision with
changed values is ignored. Missing, invalid or unreachable policy retains the
last good policy, persisted under a Firebase-project-specific preferences key;
without one, the app selects 60/180. A cached malformed value is ignored.

The app fetches at connected foreground standby entry, not on every heartbeat.
The Remote Config SDK caches fetches for 15 minutes and has a 3-second fetch
budget; the policy service bounds its fetch to 4 seconds. Changes are not pushed
mid-class. Playing and paused classes keep the choice made before they started,
including an already submitted heartbeat. Re-entry/return to standby can fetch
the next revision, which is applied on the next heartbeat. An existing connection
can briefly keep its previous interval until that successful write.

## Applied policy and online state

The device writes `users/{owner}/devices/{device}/heartbeatPolicy` with all policy
fields plus `connectionId`, atomically with its heartbeat. The timer slows only
after a successful write. There is one periodic timer per live hook. Controllers
use this applied device policy for freshness, independently of their own Remote
Config fetch timing. An absent, invalid or previous-connection record retains
the pre-existing conservative 75-second interpretation until a valid policy is
published. An explicit `online: false` still takes effect immediately.

Heartbeats cannot recreate an absent/unpaired registration, move a connection
pointer, revive an offline presence, or overwrite a newer policy revision.
The current-connection fence applies to preparation-ready heartbeats too.
The existing `onDisconnect`, command subscriptions, connection recovery,
preparation ACK, and operation/webhook paths remain in place. The monitoring
codebase does not compute a separate heartbeat-age threshold.

## Operate and roll back

1. Release/install the supporting app (including displays and controllers) and
   verify the public replacement before separately enabling its required-update
   policy in `appReleases`. App release policy remains independent of Remote Config.
2. Publish the complete JSON with a new revision in the intended Firebase project.
3. At a safe standby boundary, read a device's applied `heartbeatPolicy` and its
   matching `currentConnectionId`. A Remote Config publish alone is not evidence
   that every device has applied the change.
4. To return to 20/75, publish those two values with a **higher** revision. Do not
   delete the parameter or lower the revision: the last-good cache intentionally
   survives missing/old values. An active class keeps its policy until standby.

## Verification and limits

Related VM/widget tests cover parse/cache/revision fallback, concurrent fetch,
60/180 freshness boundaries, one timer, class/pause policy freezing, standby
rollback, connection mismatch and unpair/deletion protection. The RTDB emulator
checks policy metadata under the existing security rules. Device/audio/network
SDK behavior and the final integrated six-minute class remain nightly QA tasks.

At a steady state, 3 displays × 5 hours produce 2,700 scheduled beats at 20 seconds
or 900 at 60 seconds, excluding first beats, retries and standby outside those
hours. That is a 67% reduction in scheduled beats, **not** measured overall RTDB
traffic or cost. Policy metadata adds a small per-record payload; actual SDK
traffic, listener fanout and retries require a matched runtime capture. No
production traffic or billing reduction has been measured by these tests.
