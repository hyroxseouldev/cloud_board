#!/usr/bin/env python3
"""Compose review thumbnails from captured pixels; never modifies evidence PNGs.

python3 tool/sta162_contact_sheets.py
Requires Pillow. Outputs compact JPEGs suitable for an issue attachment.
"""
import json
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageFont, ImageStat

ROOT = Path(__file__).resolve().parents[1] / "docs/design/sta162"
THUMB = (384, 216)
GAP, LABEL = 16, 30
FONT = ImageFont.load_default(size=15)


def paste(canvas, source, x, y):
    with Image.open(source) as image:
        canvas.paste(image.convert("RGB").resize(THUMB, Image.Resampling.LANCZOS), (x, y))


for group in ["catalog", "starters"]:
    files = sorted(p for p in (ROOT / "before").glob("*.png")
                   if p.name.startswith("catalog-") == (group == "catalog"))
    for phase in ["before", "after"]:
        if not all((ROOT / phase / p.name).exists() for p in files):
            continue
        columns = 3
        rows = (len(files) + columns - 1) // columns
        sheet = Image.new("RGB", (GAP + columns * (THUMB[0] + GAP), GAP + rows * (THUMB[1] + LABEL + GAP)), "#F7F5EF")
        draw = ImageDraw.Draw(sheet)
        for i, source in enumerate(files):
            x, y = GAP + i % columns * (THUMB[0] + GAP), GAP + i // columns * (THUMB[1] + LABEL + GAP)
            draw.text((x, y), f"{phase.upper()} / {source.stem}", font=FONT, fill="#2B332E")
            paste(sheet, ROOT / phase / source.name, x, y + LABEL)
        sheet.save(ROOT / f"{group}-{phase}-contact.jpg", quality=90, optimize=True)
    if all((ROOT / "after" / p.name).exists() for p in files):
        # Two designs per row, each with adjacent before/after at equal scale.
        pair_width = THUMB[0] * 2 + GAP
        row_height = THUMB[1] + LABEL * 2 + GAP
        sheet = Image.new("RGB", (GAP + 2 * (pair_width + GAP), GAP + ((len(files) + 1) // 2) * row_height), "#F7F5EF")
        draw = ImageDraw.Draw(sheet)
        for i, source in enumerate(files):
            x, y = GAP + i % 2 * (pair_width + GAP), GAP + i // 2 * row_height
            draw.text((x, y), source.stem, font=FONT, fill="#2B332E")
            for side, phase in enumerate(["before", "after"]):
                sx = x + side * (THUMB[0] + GAP)
                draw.text((sx, y + LABEL), phase.upper(), font=FONT, fill="#657066")
                paste(sheet, ROOT / phase / source.name, sx, y + LABEL * 2)
        sheet.save(ROOT / f"{group}-comparison.jpg", quality=90, optimize=True)

representative = "interval-starter_warmup.png"
if (ROOT / "after" / representative).exists():
    # Preserve full 1920px width for the user's reported WARM UP example.
    sheet = Image.new("RGB", (1920, 1080 * 2 + 96), "#F7F5EF")
    draw = ImageDraw.Draw(sheet)
    for i, phase in enumerate(["before", "after"]):
        y = i * 1128
        draw.text((24, y + 12), f"{phase.upper()} / INTERVAL STARTER / WARM UP", font=ImageFont.load_default(size=24), fill="#2B332E")
        with Image.open(ROOT / phase / representative) as source:
            sheet.paste(source.convert("RGB"), (0, y + 48))
    sheet.save(ROOT / "interval-warmup-comparison.jpg", quality=95, optimize=True)

# Compare original captured RGB pixels, not resized contact-sheet thumbnails.
comparisons = {}
for key in ["catalog-banner", "interval-warmup"]:
    canvas = ROOT / "paths" / f"{key}-canvas-1080p.png"
    fallback = ROOT / "paths" / f"{key}-saved-png-fallback.png"
    if canvas.exists() and fallback.exists():
        with Image.open(canvas) as a, Image.open(fallback) as b:
            diff = ImageChops.difference(a.convert("RGB"), b.convert("RGB"))
            comparisons[key] = {
                "size": list(a.size),
                "differentPixelBounds": diff.getbbox(),
                "meanAbsoluteRgbDifference": ImageStat.Stat(diff).mean,
            }
if comparisons:
    (ROOT / "paths" / "pixel-comparison.json").write_text(
        json.dumps(comparisons, indent=2) + "\n"
    )
