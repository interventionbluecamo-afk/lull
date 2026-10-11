#!/usr/bin/env python3
"""Rebuild launch website composites from the nine shipped shelf cards.

Run from any directory with Python + Pillow. Only performs alpha-bound cropping,
proportional resizing, and layout; does not generate or repaint app artwork.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "App/Resources/Assets.xcassets"
WEB = ROOT / "LandingPageDeploy/assets"
TOYS = ("bubbles", "wash", "dropdots", "feed", "hum", "window", "mixup", "sleepybox", "meadow")
CREAM = (248, 243, 233)
RESAMPLE = Image.Resampling.LANCZOS


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build() -> None:
    strip = Image.new("RGBA", (1600, 222), (0, 0, 0, 0))
    margin, gap, baseline = 16, 14, 212
    cell_width = (strip.width - margin * 2 - gap * (len(TOYS) - 1)) / len(TOYS)
    inputs = []
    for index, toy in enumerate(TOYS):
        path = ASSETS / f"shelf-{toy}-v2.imageset" / f"shelf-{toy}-v2.png"
        source = Image.open(path).convert("RGBA")
        # Trim nearly transparent canvas padding; keep original pixels/alpha.
        bounds = source.getchannel("A").point(lambda alpha: 255 if alpha > 4 else 0).getbbox()
        if bounds is None:
            raise ValueError(f"Empty shelf card: {path}")
        card = source.crop(bounds)
        scale = min(cell_width / card.width, 204 / card.height)
        size = (round(card.width * scale), round(card.height * scale))
        card = card.resize(size, RESAMPLE)
        left = round(margin + index * (cell_width + gap) + (cell_width - card.width) / 2)
        top = baseline - card.height
        strip.alpha_composite(card, (left, top))
        inputs.append({
            "toy": toy,
            "source": str(path.relative_to(ROOT)),
            "sha256": sha256(path),
            "crop": list(bounds),
            "stripRect": [left, top, card.width, card.height],
        })
    # A lossless strip retains the native transparency and delicate felt edges.
    strip.save(WEB / "toys.webp", lossless=True, method=6)

    # Preserve the existing social card: warm cream, centered Wren, one toy row.
    og = Image.new("RGB", (1200, 630), CREAM)
    icon_path = WEB / "icon-512.png"
    icon = Image.open(icon_path).convert("RGB").resize((300, 300), RESAMPLE)
    mask = Image.new("L", (1200, 1200), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, 1199, 1199), radius=280, fill=255)
    mask = mask.resize((300, 300), RESAMPLE)
    og.paste(icon, (450, 70), mask)
    row = strip.resize((1080, 150), RESAMPLE)
    og.paste(row, (60, 408), row)
    og.save(WEB / "og.png", optimize=True)

    manifest = {
        "purpose": "Launch website social card and transparent nine-toy strip",
        "method": "Existing art only: alpha-bound crop, proportional resize and composition",
        "script": "Tools/Store/compose_web_assets.py",
        "order": list(TOYS),
        "inputs": inputs,
        "icon": {"source": str(icon_path.relative_to(ROOT)), "sha256": sha256(icon_path), "identity": "Wren, unchanged"},
        "outputs": [
            {"file": name, "size": list(Image.open(WEB / name).size), "sha256": sha256(WEB / name)}
            for name in ("og.png", "toys.webp")
        ],
    }
    (WEB / "Composite-export.json").write_text(json.dumps(manifest, indent=2) + "\n")
    for output in manifest["outputs"]:
        print(f"{output['file']}: {output['size'][0]} x {output['size'][1]}")


if __name__ == "__main__":
    build()
