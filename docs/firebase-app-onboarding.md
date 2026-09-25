# Firebase app onboarding (STA-34)

Implemented on 2026-09-25 using approved purpose-selection mock 3. The app calls Firebase directly; no new Neon schema or web-account linking is required.

## User flow

Apple/Google login → SMS verification → operating/preparing/exploring → center details → explicit one-month trial or finish without trial → local sample class / display connection / home.

- New non-anonymous Firebase accounts created after 2026-09-25 20:00 KST enter onboarding automatically. Older accounts retain their current entry flow and can open **프로필 → 센터 정보 · 온보딩**. This fixed rollout boundary deliberately avoids interrupting existing users.
- Center name, role, center type and region are required; name/region may be undecided for preparing/exploring. Classroom/center scale, guidance, devices, audio and priorities are optional.
- Next/나중에 save the draft and step on the server. Unsubmitted edits have an exit guard. Profile provides later editing. A revision check protects changes from another device.
- SMS verification alone never starts a trial. A local sample can run without a connected display. No production sample workout is inserted.

## Firebase ownership

| Document/path | Purpose |
| --- | --- |
| `centers/{storeId}` | Server-assigned ID, authenticated owner, validated profile, revision |
| `users/{uid}/onboarding/progress` | Phone verified, step, complete/deferred flags, center ID |
| `onboardingPhoneChallenges/{uid}` | Expiring OTP HMAC, attempt count; temporary phone value |
| `onboardingPhoneOwners/{phoneHmac}` | Unique account ownership; client cannot read it |
| `onboardingSmsLimits/{key}` | Per-account and per-phone rate window |
| `onboardingTrials/{uid}` | Immutable trial start/end and policy version |
| `subscriptionEntitlements/{uid}` | Existing Firestore entitlement contract, source `app_trial` |
| RTDB `subscriptionAccess/{uid}` | Server-owned projection used by existing playback/pairing rules |

The callable validates Firebase ID tokens including revocation, rejects anonymous users and account-deletion locks, validates a strict profile allowlist and derives ownership from authenticated UID. Reported owner/coach role is metadata, never an authorization grant. Existing Firestore rules deny client access to private collections and writes to progress/entitlements.

Trial start is a transaction: one calendar month in Asia/Seoul, with month-end clamping; retries and concurrent devices retain the original dates. Valid paid/pilot grants are preserved and historical managed grants cannot request another trial. Existing expiry checks gate new class starts, while active class rules remain unchanged. No card or automatic charge is introduced.

`syncAppTrialAccess` retries a failed RTDB projection. Account deletion removes owned centers, verification state and native trial data, without deleting unrelated paid grants. `cleanupOnboardingVerification` removes expired challenges and rate records daily.

## Services and deployment

Firebase project: `cloud-board-stationd`, functions region: `asia-northeast3`, existing codebase: `account-deletion`.

- `cloudboardAppOnboarding`: load / sendCode / verifyCode / save / defer / complete / startTrial.
- `syncAppTrialAccess`: Firestore entitlement projection repair.
- `cleanupOnboardingVerification`: daily expired-verification cleanup.
- Account deletion functions include onboarding cleanup.

SMS delivery reuses SOLAPI through Firebase Functions. Credentials are Secret Manager secrets `SOLAPI_API_KEY`, `SOLAPI_API_SECRET`, `CLOUDBOARD_ONBOARDING_SECRET`; sender is private deployment environment `SOLAPI_FROM`. OTPs are not logged or stored in plaintext. Limits: 60-second resend cooldown, 5 requests per 15 minutes per account/phone, 5 incorrect attempts, 5-minute expiry. Do not rotate the onboarding HMAC key without migrating phone ownership hashes.

The main deployment workflow runs the onboarding Firestore/RTDB integration checks before deployment. It reads the sender from the GitHub repository secret `SOLAPI_FROM`, writes a temporary private Functions environment file and removes that file after deployment. The sender value is never committed; API credentials remain in Firebase Secret Manager.

The automatic legacy web-link call and profile web-link card are removed. Existing web billing service and its historical data are retained. Before full Neon retirement, migrate/reconcile existing web subscription writers so they cannot overwrite native app entitlements. App Store receipt validation, server notifications and purchase/restore UI are a separate follow-up; this change does not implement purchases.

## Verification

- Flutter widget coverage: 320/390/834 logical widths, phone before center, draft failure/retry, explicit trial start, existing-access completion, auth loading and onboarding redirects.
- Firebase emulator integration: SMS ownership/rate/attempt checks, resume and revision conflict, concurrent trial idempotency, expiry, paid/pilot preservation, client rule denial and account deletion cleanup.
- Unit tests: calendar-month arithmetic including leap/month-end and KST, profile validation, phone normalization.
- Production functions deployed; unauthenticated callable returns 401. Existing signed-in iPhone simulator loads the actual phone-verification screen after hot reload.
- No real SMS was sent and no live trial was issued as test data. Device delivery and entering a real OTP remain a manual end-to-end check.

Run integration checks:

```sh
firebase emulators:exec --project demo-cloudboard-onboarding --config firebase.onboarding-test.json --only firestore,database 'node functions/test/onboarding-emulator.mjs'
```

Requires Java 21+. Screenshot fixtures can be regenerated with `flutter test tool/onboarding_capture_test.dart`; outputs go to `/tmp/onboarding-purpose.png` and `/tmp/onboarding-phone.png`.
