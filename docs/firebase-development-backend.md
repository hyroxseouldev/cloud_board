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

The 15 endpoints support workout summaries, settings compatibility, libraries,
account deletion, onboarding/trials, diagnostics and playback snapshot cleanup.
AI generation, real SMS and Apple/Google Play billing endpoints are not deployed
to this project. No production provider credentials are copied. Store purchases
and external provider integration need their own separately configured tests.
Google and email/password sign-in use the development Firebase Auth project.

## Main development deployment and release tags

The normal development trigger is a merge into `main`. The development workflow
builds the web app and deploys only `cloud-board-development`; development mobile
QA is a separate platform workflow. Main does not run the complete Flutter,
Chrome and Firebase contract suites before each development build. Environment
isolation, successful compilation, artifact identity and deployment results still
need to be checked. A development deployment is not production validation.

Production starts from a `vX.Y.Z` tag whose commit belongs to main history and whose
version matches the app version. Required integration CI must pass for that exact
tag SHA before production deployment or release-mode mobile upload. A main push
does not authorize production deployment, and a development receipt does not
authorize a production mobile upload. See [feature verification](feature-verification.md).

The development workflow authenticates using this Workload Identity provider:

```text
projects/1339501332/locations/global/workloadIdentityPools/github-development/providers/github
github-development@cloud-board-development.iam.gserviceaccount.com
```

Before enabling main deployments, verify that the provider permits
`refs/heads/main` and
`hyroxseouldev/cloud_board/.github/workflows/firebase-development.yml@refs/heads/main`.
Keep the repository ID `1356721972`, owner ID `218802270`, and `push` / manual
dispatch restrictions. The repository-scoped `roles/iam.workloadIdentityUser`
binding remains sufficient; do not broaden project permissions for a ref change.
Repository workflow changes and remote identity-policy changes are separate
steps, and both must be confirmed before claiming authentication works.

Development mobile apps use `com.sunmkim.cloudboard.dev` and this development
Firebase project. Their App Store Connect / Play app registrations and app-specific
signing/upload permissions must be confirmed separately. The readiness gate reports
missing setup and blocks that platform's upload. Do not substitute the production
app or production Firebase when development setup is incomplete. Registration,
build success, upload success and tester installation are separate evidence;
none is established merely by adding the workflow.

Store account authentication is intentionally shared through the existing GitHub
Environments `testflight` and `google-play`; do not create duplicate environments
or copy the same secrets. Set `MOBILE_DEVELOPMENT_READY=true` in the corresponding
environment only after the development app registration, signing and upload
permissions are confirmed. Without that setting, preflight reports `BLOCKED`
and skips the development build/upload. Sharing account authentication does not
change the app target: artifact checks still enforce the `.dev` app ID and
development Firebase binding. The store-readiness diagnostic is read-only: it
does not create apps or issue signing certificates.

Neither development builds nor TestFlight/internal-track uploads publish the app
to the general public, publish production update news, or raise minimum supported
versions. Store review and production availability remain separate operations.

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

The development onboarding secret must be printable UTF-8 text (for example a base64url-encoded random value). Secret Manager API `payload.data` is transport base64 and is decoded by the API; encoding raw random bytes only once stores binary data that Cloud Run cannot inject as an environment variable. Never reuse production provider credentials.
