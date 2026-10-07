#!/usr/bin/env python3
"""Export runtime PNGs for state pairs (asleep/awake) with ONE shared crop per pair.

A pair crossfades in place, so both frames must keep the same canvas: the crop is the
union of both frames' meaningful alpha (> 128, so faint generation fringe can't inflate
it), padded a little, then both are resized identically. Masters stay untouched.

  python3 Tools/Art/export_pairs.py SRC_DIR DST_XCASSETS NAME[+NAME2] ... [--max 600]
      [--desaturate NAME=0.15]

`meadow-rock+meadow-rock-awake` exports a pair; a single name exports one image.
"""
import argparse
import json
import os

import numpy as np
from PIL import Image, ImageEnhance

ALPHA = 128
PAD = 0.04


def write_imageset(dst, name, img):
    folder = os.path.join(dst, f"{name}.imageset")
    os.makedirs(folder, exist_ok=True)
    for old in os.listdir(folder):
        if old.endswith(".png"):
            os.remove(os.path.join(folder, old))
    img.save(os.path.join(folder, f"{name}.png"), optimize=True)
    with open(os.path.join(folder, "Contents.json"), "w") as fh:
        json.dump({"images": [{"filename": f"{name}.png", "idiom": "universal", "scale": "3x"}],
                   "info": {"author": "xcode", "version": 1}}, fh, indent=2)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("groups", nargs="+")
    ap.add_argument("--max", type=int, default=600)
    ap.add_argument("--desaturate", action="append", default=[])
    args = ap.parse_args()
    desat = {k: float(v) for k, v in (d.split("=") for d in args.desaturate)}
    report = []
    for group in args.groups:
        names = group.split("+")
        imgs = [Image.open(os.path.join(args.src, f"{n}.png")).convert("RGBA") for n in names]
        union = np.zeros(imgs[0].size[::-1], dtype=bool)
        for im in imgs:
            union |= np.asarray(im.split()[3]) > ALPHA
        ys, xs = np.where(union)
        x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        px, py = int((x1 - x0) * PAD), int((y1 - y0) * PAD)
        w, h = imgs[0].size
        box = (max(0, x0 - px), max(0, y0 - py), min(w, x1 + px), min(h, y1 + py))
        for n, im in zip(names, imgs):
            out = im.crop(box)
            scale = min(1.0, args.max / max(out.size))
            out = out.resize((round(out.width * scale), round(out.height * scale)), Image.LANCZOS)
            if group in desat or n in desat:
                amount = desat.get(group, desat.get(n, 0))
                alpha = out.split()[3]
                out = ImageEnhance.Color(out.convert("RGB")).enhance(1 - amount).convert("RGBA")
                out.putalpha(alpha)
            write_imageset(args.dst, n, out)
            report.append({"name": n, "crop": list(map(int, box)), "size": list(out.size)})
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
