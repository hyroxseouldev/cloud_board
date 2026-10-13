# STA-144 follow-up disposition

The latest base already contains the owner's October 13 decision to retire forward semantic support for exactly Android production 52 and the shared iOS review 548 / Android closed 58 source group for 1.1.0. That decision is recorded in `tool/firebase/support-retirements.json` and `docs/release/1.1.0/compatibility-audit.md`. It supersedes implementing old-client forward compatibility; it does not establish that the old serializers or timer algorithms were repaired.

This Todo pass reviewed that disposition and retained the original failure evidence, frozen fixtures, source provenance, current reader of historical data, and historical writes against current rules. The registry, retirement authorization and non-semantic exception policy are unchanged. The three currently active reader groups (1b646438, a8653077, 92893662) must continue to pass the contract harness; the two retired groups must remain explicitly `retired`, not report fictional passing tests.

The new Free/Plus policy keeps existing timestamp and playback envelope contracts. Rules test that a running class remains controllable after downgrade while a new session obeys the new target cap. Old app wording and support for the new product flow are not guaranteed. No forced-update switch, production data migration, release upload or store state was changed here.

STA-144 is presented for review with this disposition. The original 52/58/548 semantic-loss bug must not be closed with a claim of a code fix. Reinstating their support would require a separate explicit support decision and the preservation/overwrite/start/control work described in the historical issue.
