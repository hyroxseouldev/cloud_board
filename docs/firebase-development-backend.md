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
Development sign-in targets the development Firebase Auth project. The Apple
sign-in provider is not configured there, and native Google and Apple sign-in
flows have not been verified. Firebase SDK configuration alone does not prove
that native provider login works.

The development web's canonical URL is
`https://cloud-board-development.firebaseapp.com/`. Its `web.app` alias redirects
there while preserving the path, query and fragment. Hosted development Google
sign-in uses a full-page redirect so the app and Firebase's `/__/auth/` helper
share one origin. This recovers the development Chrome flow where the Google
popup closed without delivering the auth result (`popup-closed-by-user`). Local
previews and production retain popup sign-in. Verify the real Google round trip
and the returned app session; a successful build alone does not verify OAuth.

The guarded development build versions both the Flutter bootstrap and app script
URLs with the app bundle's SHA-256. Development Hosting revalidates cached files
so a reopened page loads the deployed build instead of retaining an older login
flow. This changes only development build output and Hosting configuration.

## Main development deployment and release tags

The normal development trigger is a merge into `main`. The development workflow
builds the web app and deploys only `cloud-board-development`. Separate mobile
QA workflows target the existing separate development app
`com.sunmkim.cloudboard.dev` using this development Firebase project, subject to
store readiness. Main does not run the complete Flutter,
Chrome and Firebase contract suites before each development build. Environment
isolation, successful compilation, artifact identity and deployment results still
need to be checked. A development deployment is not production validation.

Production starts from a `vX.Y.Z` tag whose commit belongs to main history and whose
version matches the app version. Automatic tag runs execute required integration
CI by default and require success for that exact tag SHA before production
deployment or release-mode mobile upload. Only manual Firebase tag releases or
manual native `release` runs may omit heavy CI with `skip_ci=true` and a non-empty
`skip_ci_reason`. Audit artifacts/receipts record the skip, reason, actor, run and
source/tag; a skip is not reported as passed CI. Tag/SHA/main ancestry/version,
build, environment, signing, numbering and artifact checks remain, as does native
production backend compatibility. Production deployment scope remains explicit.
A main push does not authorize production server/web deployment. Development-app
mobile QA is allowed without full CI and does not require a production backend
receipt; the release-only skip option is rejected for main and QA. See
[feature verification](feature-verification.md).

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

Main-triggered TestFlight / Play internal uploads use the existing development
bundle/package `com.sunmkim.cloudboard.dev` and `development` flavor. Its native
Firebase SDK registrations/configuration already exist in this project; no new
Firebase app registration is required for this policy. Production release builds
retain `com.sunmkim.cloudboard`, the `production` flavor and `cloud-board-stationd`.

Development App Store Connect / Play app registration, signing and upload access
are still unverified. Existing `testflight` / `google-play` account credentials do
not establish readiness for the separate development app. Confirm each platform,
then set `MOBILE_DEVELOPMENT_READY=true` in its GitHub Environment. Until then,
preflight reports blocked and skips SDK installation, build and upload. Build
numbers and upload concurrency are separate per app. The development Play
baseline file is absent; prepare it from verified development-app store history,
not the production baseline.

Check development Google OAuth configuration, native signing/callback settings
and actual native Google sign-in with a development account. Apple login additionally
needs its development Firebase provider configuration before an end-to-end check.
These native provider checks are separate from store distribution readiness, and
neither has been established by the documentation or workflow change.

Development QA is excluded from production installed-client tracking, public app
news and minimum-version changes. Historical production-connected QA receipts
remain tracked. Development and production apps use separate app IDs and their
existing app sandboxes; web environments use separate origins. The development
onboarding flow must be checked using a development account; production
accounts/data do not migrate.

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
