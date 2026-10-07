#!/usr/bin/env python3
"""Remove the teal (#3E6877) key-background spill from keyed Lull art.

Image generation puts every object on flat teal, and the soft cast shadow it
paints under the object comes out teal too. After keying, that shadow survives
as a blue-green crescent and the edges keep a teal fringe. On the warm Lull
rooms that reads as a cold halo. This tool:

  * turns dark teal-cast pixels (the baked shadow) into a soft warm cocoa
    shadow whose opacity follows how dark the original was, and
  * neutralises the teal cast on the remaining semi-transparent edge pixels.

Opaque, light pixels are never touched, so genuinely blue art (water, felt)
survives. Usage:

  python3 Tools/Art/despill.py IN.png [OUT.png] [--shadow-strength 0.7]

With no OUT, the file is rewritten in place.
"""
import argparse
import sys

import numpy as np
from PIL import Image

SHADOW_RGB = np.array([52, 38, 28], dtype=np.float32)   # WarmShelfPalette cocoa, deepened


def despill(img: Image.Image, shadow_strength: float = 0.7) -> Image.Image:
    a = np.asarray(img.convert("RGBA")).astype(np.float32)
    rgb, alpha = a[..., :3], a[..., 3]
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    value = rgb.max(axis=2) / 255.0
    teal_cast = np.minimum(g, b) - r            # > 0 when both G and B exceed R
    visible = alpha > 0

    # 1. Baked shadow: dark and teal-cast. Recolour warm; opacity from darkness.
    shadow = visible & (teal_cast > 14) & (value < 0.46)
    darkness = np.clip((0.56 - value) / 0.46, 0.0, 1.0)
    new_alpha = alpha.copy()
    new_alpha[shadow] = alpha[shadow] * (0.25 + 0.75 * darkness[shadow]) * shadow_strength
    out_rgb = rgb.copy()
    out_rgb[shadow] = SHADOW_RGB

    # 2. Light fringe: semi-transparent and teal-cast. Pull G/B back to R's level.
    fringe = visible & ~shadow & (alpha < 250) & (teal_cast > 6)
    spill = teal_cast[fringe][:, None]
    fixed = rgb[fringe].copy()
    fixed[:, 1:] -= spill * 0.9
    out_rgb[fringe] = np.clip(fixed, 0, 255)

    out = np.dstack([out_rgb, new_alpha]).clip(0, 255).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("src")
    p.add_argument("dst", nargs="?")
    p.add_argument("--shadow-strength", type=float, default=0.7)
    args = p.parse_args(argv)
    out = despill(Image.open(args.src), args.shadow_strength)
    out.save(args.dst or args.src, optimize=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
