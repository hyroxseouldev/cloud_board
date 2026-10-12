# STA-121 v5 Soft Rhythm asset

Created 2026-10-12 with the built-in `image_gen` tool, using `transparent_background: true`. No API/CLI fallback was used. The final generated PNG was copied without resizing, recoloring, cropping, or alpha modification.

## Final asset

- Repository path: `assets/branding/soft_rhythm_mark.png`
- Generated original: `/Users/sunmkim/.codex/generated_images/01a12e4c-97b1-7e21-9b1c-67c152816cff/exec-a6afac97-71e0-49b5-9f4a-0f629570e327.png`
- SHA-256: `40b6e7aaaeb929fde964f4d9ea56508bc8db88b0959f180755f001a963a5e4ed`
- Format: PNG, 1254 × 1254, 8-bit RGBA, 935,743 bytes.
- Content: one Soft Rhythm symbol, with a dark sage upper board, light sage lower board, transparent diagonal gap, subtle internal dimensional shading, no text or icon tile.
- Palette targets: upper `#526B60`, lower `#B2C1AE`, highlight `#E3EAE2`. These are generation targets; the shaded image intentionally contains a range of colors rather than three exact flat fills.

## References

Both images were opened and visually inspected before generation.

| Role | Original path | SHA-256 |
| --- | --- | --- |
| Selected v5 palette / visual character | `/tmp/sta121-reference/selected-v5.png` | `570d387c625de3c475ee6573220d0f2beb83177cd8dace4cf7c74875c5abe26a` |
| Written v5 specification | `/tmp/sta121-reference/design-v5.md` | `15d7785dc9665d58595f61c29683d80f326c2a64564bcc106daeda4c285d71ad` |
| Soft Rhythm shape / subtle dimensionality only | `/Users/sunmkim/orca/workspaces/cloud_board/goldfish/output/design/cloudboard-brand-2026-10-12/04-soft-rhythm.png` | `c0e056f6f47bce51e1ced1790383ed77daaee532bf4892b98ad55b9deb654f88` |

The purple palette, surrounding tile, and typography in the large original are not part of this asset.

## Alpha and visual validation

The PNG was decoded for read-only inspection:

- Total pixels: 1,572,516.
- Alpha 0: 901,617 pixels.
- Alpha 255: 980 pixels.
- Partial alpha: 669,919 pixels; all 256 alpha levels are present.
- Visible body bounds at alpha ≥ 128: `[123, 290, 1175, 1066)` (left, top, right, bottom; right/bottom exclusive).
- Bounds at alpha ≥ 16: `[122, 290, 1176, 1067)`.
- The complete alpha > 0 bounds extend to `[0, 23, 1216, 1254)` because the generated output retains near-transparent peripheral pixels. Do not use that raw bounding box to auto-crop the visual mark.
- The two boards retain the tool's near-opaque interior alpha (typically 253–254), rather than being flattened to a background.
- The raw RGB preview can exaggerate near-transparent edge residue. For the selected file, saturated green edge pixels have alpha at most 15/255 (one pixel); the majority have alpha 1–5. These pixels were not manually modified.

The unmodified PNG was rendered in Chrome using normal alpha compositing on both the v5 oat background `#F7F5EF` and a dark background `#17241D`, at 300 px and 64 px. The two-board silhouette and diagonal gap remained clear, without a visible white border, chroma fringe, or background tile at those sizes. This is an asset review, not a claim of completed platform icon-mask or device splash verification.

Native icon exports should composite the shared transparent asset over the intended platform background and apply platform masking in the native export workflow. Keep the source PNG transparent. UI/splash placement can use the visible body bounds when optical alignment is needed.

## Generation record

### Pass 1 — source construction

Tool: built-in `image_gen`; `transparent_background: true`.

References, in order:

1. `/tmp/sta121-reference/selected-v5.png`
2. `/Users/sunmkim/orca/workspaces/cloud_board/goldfish/output/design/cloudboard-brand-2026-10-12/04-soft-rhythm.png`

Intermediate original: `/Users/sunmkim/.codex/generated_images/01a12e4c-97b1-7e21-9b1c-67c152816cff/exec-25093315-253e-4c4c-af07-2e9da782783d.png`

Exact prompt:

```text
Use case: background-extraction / precise-object-edit.
Asset type: production-ready transparent brand symbol, shared source for a native app icon and launch splash.
Input image 1: the selected Oat Sage v5 app screen. Use the two-board green symbol at the upper left as the final color and visual character reference.
Input image 2: the large purple Soft Rhythm brand presentation. Use ONLY its large two-board symbol as the precise silhouette and subtle 3D surface reference, not its purple palette, background tile, text, or page composition.
Primary request: recreate/extract exactly one standalone Soft Rhythm two-board symbol on a genuinely transparent alpha background. Keep the identity and geometry of the reference: two broad softly rounded asymmetric diagonal boards, stacked with a crisp narrow rising diagonal transparent gap from lower left to upper right. The upper board has a nearly horizontal outer top edge and a rising diagonal lower edge. The lower board has a rising diagonal upper edge and a nearly horizontal outer bottom edge. Preserve the rounded corners and gentle asymmetric slant from the reference; do not turn them into parallel pill bars, a letter, a cloud, or a play button.
Colors: upper board dark muted sage base #526B60; lower board light sage base #B2C1AE; restrained highlights in #E3EAE2. All shading stays within this sage family. No purple. Soft satin surfaces, very subtle rounded bevel and dimensional lighting, clear clean silhouette that remains legible at small app-icon sizes. Soft upper-left light, no dramatic reflections, no white outline or halo.
Composition: a single centered mark on a square 1536x1536 transparent canvas, about 76% of canvas width and 57% of canvas height, ample clear padding on all sides, optically centered. The two boards are the ONLY visible objects.
Constraints: no words, letters, numbers, labels, watermark, border, rounded icon tile, white backdrop, checkerboard pixels, ground plane, ambient backdrop, external cast shadow, extra shapes, duplicate symbols, or mockup. Truly transparent outside the boards and inside the diagonal gap, with clean anti-aliased alpha edges. Deliver the isolated logo asset only.
```

### Pass 2 — selected final

Tool: built-in `image_gen`; `transparent_background: true`.

Edit target: the pass 1 intermediate original above.

Exact prompt:

```text
Use case: precise-object-edit / background-extraction.
Edit the supplied standalone transparent Soft Rhythm logo. Preserve the exact two-board silhouette, relative positions, diagonal transparent gap, current muted sage palette, soft satin bevels, and centered square composition.
Only fix the transparency edges: remove every stray disconnected pixel, bright green/cyan chroma-key fringe, white speckle, and pale outline along the outside silhouette and along both sides of the diagonal gap. Every edge must be a clean, smooth, carefully anti-aliased boundary between the sage board itself and true transparency. There must be absolutely no fluorescent green edge, no white halo, no rough extraction residue, no baked-in black/checkerboard background, and no ambient shadow outside the boards.
Upper board base #526B60, lower board base #B2C1AE, restrained highlights #E3EAE2. Use these colors naturally for all edge pixels as well. Keep the subtle dimensional material and do not flatten or redesign the symbol.
One production-quality centered mark only, on a square transparent canvas between 1024 and 2048 pixels. No text, tile, frame, external cast shadow, or added objects. The areas outside the symbol and between the boards must have true zero alpha.
```

A third clean-contour alternative was inspected but not selected because its upper-board proportion drifted farther from the original. It remains outside the repository at `/Users/sunmkim/.codex/generated_images/01a12e4c-97b1-7e21-9b1c-67c152816cff/exec-b0733c23-b475-486a-918a-671e92436c3e.png`.

This task added only the shared image asset and this provenance record. It did not replace `login_welcome.png`, alter Flutter/native code, run a Flutter build, commit, publish, or update Linear.
