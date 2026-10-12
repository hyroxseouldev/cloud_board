# Firebase repair without a store release

Installed apps must keep working while a compatible server fix is prepared. A
repair does not require a TestFlight or Play upload, a new Hosting bundle, or an
allow-all rule. It still requires the current and every frozen client contract,
including execution of the actual released Dart readers/serializers.

## Select the publication scope

The existing **Deploy Flutter Web to Firebase Hosting** workflow has a manual
**Run workflow** action. Select branch `main`, choose a required scope, and paste
the exact current 40-character `main` commit SHA into `confirm_sha`:

| Scope | Published | Left at existing live version |
| --- | --- | --- |
| `rules` (manual default) | Firestore rules/indexes, RTDB rules, Storage rules | Functions, Hosting and native clients |
| `backend` | Functions plus all data rules/indexes | Hosting and native clients |
| `full` | Functions, data rules/indexes and Hosting | Native upload requires its separate workflow |

Use `rules` only when the current Functions implementation already supports the
repair. If the rule change depends on a new callable/trigger or a previous
Functions deployment may be partial, use `backend` so the intended backend is
deployed together. These services are not atomic; a failed attempt does not mean
that every service stayed at its former version.

The action refuses a non-main branch, a mismatched SHA, or a superseded main
commit. All scopes run app validation, all Firebase contracts and real client
smoke. Web compilation remains a validation step even when Hosting publication
is skipped. A successful rules/backend repair creates a scoped, verified receipt
after live read-back and synthetic save/image/TV/isolation checks.

## Publish a new hotfix commit without triggering native uploads

1. Prepare a compatible forward fix in a PR. Preserve support for both old and
   new writers; a previous rules file is not automatically compatible with data
   already created by a newer client.
2. Validate the PR and merge to `main` with the explicit marker **`[backend only]`
   in the final main merge commit message**. The main push deploys Functions and
   rules, skips Hosting, and skips automatic iOS/Android/TV upload jobs. Merely
   placing the marker in a PR comment does not change the deployment scope.
3. Follow the same-SHA Firebase run through live checks and receipt publication.
   The monitoring job follows that backend receipt, even though the web app
   remains on its previous release.
4. If the deployment needs retrying, use **Re-run all jobs**, or manually run the
   action against that current main SHA and the desired repair scope. Do not
   execute an old SHA to bypass current-main checks.

Normal unmarked main pushes retain the full-release behavior. A manual Firebase
dispatch never dispatches mobile workflows itself. To publish native clients
later from a backend-only commit, first run a successful `full` Firebase dispatch
for the exact same current main SHA, then manually start the native workflows.

## Failure and observation rules

- The latest relevant main push **or manual dispatch** is authoritative. Failed,
  cancelled, missing or partial results do not fall back to an older green run.
- Mobile upload accepts only a verified **full** receipt for its exact main SHA,
  the exact run/attempt, matching rules hashes, and successful concrete Functions,
  smoke and Hosting steps. A backend/rules receipt is not a mobile release permit.
- The monitor accepts all verified scopes for live rule drift checks and defers
  while a production attempt is in progress. A newer failed attempt makes the
  observation fail rather than reporting an older release as healthy.
- An old receipt without scope is interpreted as `full` because that was the only
  publication mode before scoped repairs. New receipts bind scope to their
  manifest hash and their receipt metadata.

Record the failed and repaired run URLs, affected platform/builds, live smoke
result, alert delivery evidence and recovery timing in the incident issue. This
workflow provides a repair path; it is not evidence of a production recovery SLA
until a real authorized drill has been completed.
