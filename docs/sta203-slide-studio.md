# STA-203 unified slide studio

Implementation starts at integration commit `e70beccb306a38303bba96620b64337e209abbac`.
The selected visual reference is Linear STA-203 attachment
`03-preview-first-focus-canvas` (2026-10-21); its text and example quota are not
data fixtures. Oat Sage colors and the existing Pretendard assets are used.

## 2026-10-21 morning decision: template-only creation

The creation page now offers only local template generation. Center templates
come exclusively from the current authorized center catalog; basic templates
and saved non-private styles have explicit source labels in the basic category.
The expanded picker retains the current category. Loading a center catalog does
not change the user's selected basic design or category.

Reference image picking, mode/preferences controls, AI retry/receipt controls and
usage displays are removed from this page. Title, optional exercise guidance,
raw lesson text, immutable preview/history, library save and class add remain.
The controller no longer loads AI usage or raster brand context on construction;
the page calls `generateTemplate`, which normalizes legacy modes and ignores old
AI-only input/pending state without issuing or retrying a paid operation. A
previous remote operation is not cancelled or refunded by this local transition.

Existing paid controller methods, API/data fields, backend endpoints, recovery
logic, templates and original artwork remain compatible. The sections below
record the earlier implementation and retained contracts, not current controls
on the template-only page. No save/add backend or pricing policy changes.

### Morning follow-up: usage and saved images

The template-only page again reads the server's actual AI remaining count on
entry and explicit refresh, without loading a raster brand or starting a paid
operation. Loading, missing data, failed refresh with the last known value,
zero remaining and unlimited are distinct. Template generation is clearly
labelled as not consuming an AI request and remains usable when quota is zero
or the usage read fails. Paid generation controls remain absent.

The header opens **저장된 이미지** on the existing child library route with
`SlideLibraryScreen(imagesOnly: true)`. The optional presentation filter uses a
nonempty `WorkoutModule.imageSource` (the existing DTO `imageUrl`), never an ID
prefix or favorite flag. Saved image rows retain reopening, search and workout
reuse through the existing handlers. Main library/quick insert defaults still
show all saved slides; no source data, save API, asset or metadata is changed.

## Route and behavior

`/editor/:id/images/create` remains the creation route. It now mounts one
account/center-scoped `SlideStudioController` instead of the content/template/AI
navigation tabs. The shipped raster child route remains valid for old deep
links, but the new screen uses the same raster actions and renderer inline.

- Center catalog designs, saved personal designs, generated style alternatives,
  and basic designs share a lazy horizontal picker and adaptive full picker.
  Selecting a design changes input only; the existing result is immutable.
- Each center card uses its authorized recipe and thumbnail loader. The full
  result uses the existing direct canvas layout. No private brand becomes a
  public asset, and no catalog publication is performed by this feature.
- Raw content stays in a stable text controller through expand/collapse and
  Korean IME composition. Title and optional preferences remain editable.
  Reference image replacement/removal is local until explicit style generation.
- Optional exercise guidance is entered separately and uses the existing
  `designSubtitle` field through preview/library DTOs. It starts empty, never
  copies a sample's time, and never changes work/rest/set timer values.
- A result retains the exact input snapshot, reference identity, design and
  request ID. Dirty input disables save/add for that result until regenerated.
  Late work is retained in history without replacing newer input or the visible
  earlier result. Undo restores a completed snapshot.
- Busy generation, saving, unknown request outcome, unsaved input/results and
  account changes use the existing exit guard and scope lifetime protections.

## Explicit generation modes

| Mode | Work | Existing quota |
| --- | --- | --- |
| Template as selected | Apply selected original recipe/style to input locally | No AI call or charge |
| AI content grouping | Luna selects contiguous source-line boundaries; source strings are retained | One shared `aiSlides` request |
| AI style suggestion | Existing editable style proposal from selected style description/colors and optional supplied image | One shared request; this is not raster artwork |
| AI background image | STA-202 artwork endpoint for the selected approved center reference; exact logo/text composited by existing renderer | One shared request, existing separate image budget reservation |

Content grouping uses the existing section representation on basic dynamic
designs and flow recipes. Fixed center slots and bundled original layouts cannot
represent groups: the UI explains this and blocks that paid operation before a
request, while free template use and the separate approved artwork path remain.
Supported designs validate the raw layout before requesting AI, then validate
the returned groups at the same fixed typography. No silent font shrinking,
truncation, number splitting or template redesign is introduced.

If a completed operation does not fit, the specific layout message, receipt and
groups remain available beside the previous preview. Retrying that receipt is
local and makes no model or status call. Existing groups are reused only if raw
text and instructions are unchanged. Edited raw/instructions instead produce an
explicit free template result from the current input with a visible notice;
old groups cannot overwrite the new words. The user can explicitly close the
receipt before starting a new paid request. This recovery state is scoped to the
open studio and protected by its exit/account guard, not a new persistence API.

No action secretly chains content grouping with style/image generation. Counts
therefore describe one operation, not the number of style alternatives. There is
no token allowance in the current user plan: the UI explicitly says so and only
shows a provider-reported input/output total when available. Missing tokens are
unknown, never a conversion from counts, dollars or a reservation.

Raster mode requires the selected center template ID and recipe revision to
match the currently approved brand. Other templates remain usable in the local
path. Font/group choices are explicit; overflow is validated before a paid
image request and again during final composition. Timer duration/model behavior
is unchanged; raster artwork contains no drawn clock or time digits.

## Additive callable

New function: **`cloudboardSlideStudio`**, `asia-northeast3`, authenticated
non-anonymous callers, 90-second function timeout. Uses the existing secret
binding; this change neither provisions nor copies credentials.

All requests include `centerId`. The server verifies current onboarding center,
center owner and account-deletion lock. Existing endpoints, rules, entitlement
limits and their response contracts remain unchanged.

| action | Additional request | Response |
| --- | --- | --- |
| `usage` | optional `requestId`, `kind: studio/raster` | Existing `used/remaining/limit/allowed/enabled/resetsAtMs`, optional token contract below |
| `generate` | `requestId`, `operation: organize`, `rawWod`, `brief` | `job` plus current count status |
| `generate` | `requestId`, `operation: style`, `prompt`, optional validated `imageBase64/mimeType` | `job` plus count status |
| `status` | `requestId` | Same operation receipt; never calls a model |

`tokenAllowance: {kind: "not-metered", remaining: null, limit: null}` means no
user token-denominated allowance exists. `lastOperationTokens` is either null
or `{requestId, kind, input, output, total}` from that completed operation only.
It is **not** a complete monthly token total. Historical text jobs or cache hits
without stored provider usage stay unknown. Raster token breakdown is read from
the caller's existing private STA-202 job (reported text/image input and image
output only), never from a client estimate. The UI calls this the known portion
of the most recent request, not a complete total across unreported modalities.

Operations are stored separately at:
`users/{uid}/slideStudioCenters/{centerId}/operations/{requestId}`.
The server claims an ID once in a transaction before calling the existing
metering code. Repeated IDs with different structured input hashes are rejected.
The group hash uses canonical JSON boundaries; style cache keys include the
center. Source and style contracts are revalidated on metered cache hits.
No uploaded reference bytes are persisted in these operation documents.

A processing claim is never automatically reclaimed. A timeout/lost response
retains the ID and status-only retry. The UI can explicitly prepare a new request
after explaining possible additional usage. This preserves the old quota refund
and cost reservation semantics; it does not turn uncertain provider work into a
second implicit charge. Malformed/expired usage fails closed for AI actions.

The existing API fallback supplies old request counts when the new usage
endpoint is not yet deployed. Token support is then marked unavailable. Local
template creation and the existing library remain usable; the new AI operation
shows an honest unavailable message.

## Result save and compatibility

Generation is a temporary preview, not a library write. Save prepares the
reviewed final PNG once per result and reuses the existing authenticated image
upload plus `updateSlideLibrary` contract. Each result has a stable library ID.
A retry first reads the library: an existing matching ID is acknowledged without
minting another item or overwriting unrelated content. Existing server item
patches and plan limits remain authoritative.

The library stores the normal `WorkoutModule` (title, source text, image and
supported design fields). A private recipe is not serialized into legacy
documents. Center and raster results use the existing final image contract;
opening, adding, saving a class, re-reading and TV playback require no AI call.
The header pushes the studio's `library` child route, retaining the editor and
input/result state on the same navigator. The existing `/slides` main tab remains
unchanged and is not pushed as another stateful shell. Adding to the
current class does not require library saving and does not claim class save
success.

## Verification and rollout boundary

Worker tests are targeted state/repository, mock route widgets, real local
renderer/export and in-memory server transaction contracts. They do **not**
prove actual Firebase SDK/network persistence, provider image quality, actual
devices or TV playback.

Before deployment/integration acceptance, the coordinator owns:

1. Build a development app from the final PR/integration SHA.
2. On a local/development-only account, create a result with selected original
   center recipe; save independently; leave/reopen the library; add to class;
   save through the real callable; re-read/reopen without a model call.
3. Check AI usage and one explicit request, failed/uncertain status retry,
   separate new-request warning, dirty result, account/center access, and
   absent-new-server fallback.
4. Verify actual web/iPad/iOS/Android keyboard/safe-area/large text, original
   typography/logo and TV image contract.

Only the new callable needs additive deployment for new text operations/usage;
STA-202 raster endpoint and approved catalog/brand remain separate prerequisites.
No worker deployment, rules publish, store upload, live model call or workflow
dispatch was performed. The deployment owner must explicitly select the new
function; the existing isolated-development allowlist was not broadened.
