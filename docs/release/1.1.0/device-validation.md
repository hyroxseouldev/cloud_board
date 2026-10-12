# 1.1.0 device validation record

Status: **not executed**. This worksheet is a release gate, not test evidence. Use the exact signed AAB/IPA intended for submission. Do not uninstall the old app to simulate an update.

## Record once per device

Record device model, OS, country/store account eligibility, app role (phone or TV), installed version/build, installer/track, source SHA and artifact hash when available. Record the old-to-new update path, tester, time, account tier and result. Use redacted account/device identifiers and sample class content; never attach sign-in credentials or customer class data.

| Installed baseline | Candidate | State that must survive | Result |
| --- | --- | --- | --- |
| Play public Android 1.0.0 (52) | Android 1.1.0, reserved code | Login, entitlement, saved classes, styles/settings, unsaved recovery draft, paired TV | Pending |
| Play closed Android 1.0.0 (58) | Same candidate | Same state | Pending |
| iOS review 548 / TestFlight 553, if installed | Candidate 1.1.0 TestFlight build | Same state, keychain login, purchase entitlement | Pending |
| Existing installed TV; record its real version and distribution channel | Candidate 1.1.0 TV | Pairing, device assignment, preferences, playback recovery | Pending; public Android TV form factor is not yet configured |

## Mixed-version lesson matrix

| Controller | TV | Result |
| --- | --- | --- |
| Existing installed controller | Existing installed TV | Pending baseline |
| 1.1.0 controller | Existing installed TV | Pending |
| Existing installed controller | 1.1.0 TV | Pending |
| 1.1.0 controller | 1.1.0 TV | Pending |

For each supported pair, create/edit/save/duplicate a class; verify old and newly saved classes; prepare image/sound assets; start, pause, resume and finish; background/restore the controller; interrupt/reconnect the network. Check media-ready state separately from command acknowledgment. An unresponsive TV must not show success, and reconnecting must not replay expired or duplicate commands.

Repeat relevant authorization checks with normal, trial and paid accounts. An unpaired TV and a different account must be denied. Verify update-policy/Remote Config changes do not interrupt or change an ongoing lesson; evaluate new policy only at the documented next-operation boundary.

Capture expected behavior, observed result, time, build pair and redacted diagnostic event IDs for every failure. Block release on data loss, lesson interruption, authorization leakage, wrong environment or authentication/entitlement/pairing regression. Automated tests support this matrix but do not complete it.
