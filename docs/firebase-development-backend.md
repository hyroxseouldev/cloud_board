# Development backend operations

The isolated Firebase project is `cloud-board-development`. Its core Functions
use `development-runtime@cloud-board-development.iam.gserviceaccount.com`, zero
minimum instances and only project-scoped permissions. The deploy target list is
maintained in `functions/src/development-backend-config.js`; use the guarded
development workflow/command to deploy it. No production deployment is performed
by these operator commands.

```sh
node functions/scripts/development-onboarding.mjs deploy-targets --project cloud-board-development
```

The 14 endpoints support workout summaries, settings compatibility, libraries,
account deletion, onboarding/trials, diagnostics and playback snapshot cleanup.
AI generation, real SMS and Apple/Google Play billing endpoints are not deployed
to this project. No production provider credentials are copied. Store purchases
and external provider integration need their own separately configured tests.
Google and email/password sign-in use the development Firebase Auth project.

## Test onboarding without sending SMS

Provision a fresh random value in this project's Secret Manager under
`CLOUDBOARD_DEVELOPMENT_ONBOARDING_SECRET`. Only the development runtime identity
needs access to that secret. Do not rotate it casually: it hashes phone ownership
and active verification challenges in this project's test data.

1. Sign in to the development app normally, then obtain that development Auth UID
   from its Firebase console. The commands never create an account.
2. Using Admin credentials authorized for the development project, grant the
   explicit test account and sign out/in to refresh its ID token:

   ```sh
   node functions/scripts/development-onboarding.mjs grant-tester --project cloud-board-development --uid TEST_UID
   ```

3. Request an SMS code in the development app. The existing rate limits, random
   six-digit code, HMAC verification, expiry and phone ownership checks still run.
   An Admin-granted `developmentTester` claim is required before a challenge is
   saved. No SMS provider is contacted. Read the code for that exact UID:

   ```sh
   node functions/scripts/development-onboarding.mjs read-code --project cloud-board-development --uid TEST_UID
   ```

4. Enter that code in the app and complete onboarding normally. Trial access is
   issued only inside the development project's Firestore/Realtime Database.

The outbox contains only the code and its five-minute expiry. App clients,
including tester accounts, cannot read/list/write it. Codes are never logged by
Functions or returned in a callable response. Operator CLI output contains the
requested code; do not paste it into shared logs. An expired code is rejected by
the CLI and verification flow. Account deletion removes its outbox record.

To remove testing access, revoke the claim, outstanding login tokens and outbox:

```sh
node functions/scripts/development-onboarding.mjs revoke-tester --project cloud-board-development --uid TEST_UID
```

Production onboarding retains its existing SMS delivery and secret bindings;
simulation rejects every project except the exact development project.
