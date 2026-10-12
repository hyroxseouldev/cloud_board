# TV preparation protocol

Before a new class, the controller publishes one short-lived candidate at
`users/{owner}/displayPreparation/request`. The candidate identity (`sessionId`),
revision, workout/settings/target fingerprint and 90-second server-time expiry
are separate from `activeSession`. Preparing, retrying or excluding a TV never
changes an ongoing class. Rules reject replacement requests during active or
paused playback.

Paired TVs advertising `preparationProtocol: 1` prepare all distinct slide images
and the configured audio sources while connected, foreground and in standby.
They report an exact candidate receipt under `responses/{deviceId}`. A paired
anonymous display can write only its own receipt; the controller cannot forge
ready receipts. A retry clears the previous receipts. Old session display ACKs,
partial image counts, failed audio preparation, stale heartbeats, mismatched
revisions and expired candidates never count as ready.

The controller shows per-TV readiness and installed version/build/protocol.
Failed TVs can be retried or explicitly excluded. Selecting no TV when devices
are registered launches the phone player locally without publishing an empty
broadcast target list. Legacy TVs remain visibly unverified; their screen must
be explicitly confirmed for a compatible class. They are not labeled media-ready.
An advanced timer requiring a newer playback protocol still requires an update.

Immediately before starting, the app reapplies current preferences and checks the
candidate fingerprint, selected TVs, current request, receipts and fresh online
heartbeats again. Existing legacy-only direct starts remain compatible. New
capable TVs require the preparation proof. Server time offset is applied when
creating the candidate, checking its expiry and verifying the start.

Client bounds are 32 TVs, 64 distinct images, 10 MB image manifest and 90-second
expiry; image/audio preparation has finite timeouts. This verifies image decode
and silent native audio source preparation, not whether physical speakers are
audible. Flutter image cache can evict decoded images later, so this is not an
unlimited offline download guarantee. The existing playback cache/recovery flow
remains responsible for playback after connectivity loss.

The emulator suite `functions/test/display-preparation-emulator.mjs` checks
ownership, pairing, exact receipt identity, media completion, stale responses,
atomic retry/reset and active-class isolation. Flutter tests cover stale/failed
readiness, final preference changes, clock skew, retry/exclusion and phone-only
start without remote commands. Real TV speaker audibility, native audio hardware
and sustained disconnected playback still require physical-device QA.
