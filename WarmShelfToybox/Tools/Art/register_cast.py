#!/usr/bin/env python3
"""Register a Feed friend's expression frames to its neutral frame and export runtime PNGs.

Generated expression edits re-render the body a little: frames drift by up to ~30 master
pixels and some grow slightly. Swapping such textures in place makes the friend jump. This
tool finds, for every frame, the scale + offset that best overlays its head-and-shoulders
silhouette on the neutral frame's, applies it, then crops all six frames with ONE shared
box (so texture swaps never move the canvas) and writes them at runtime size.

The masters in ArtDrops stay untouched; outputs go to the asset catalog.

  python3 Tools/Art/register_cast.py ArtDrops/2026-10-07 App/Resources/Assets.xcassets \
      grandmother sprout knithat

Prints the per-frame transforms and the shared crop as JSON (keep it with the handoff).
"""
import json
import os
import sys

import numpy as np
from PIL import Image

ALPHA = 128            # "meaningful" alpha; faint generation fringe stays out of the boxes
VISIBLE_SHARE = 0.68   # top share of the figure that shows above the Feed counter
RUNTIME_WIDTH = 760    # px, 3x-scale asset: ~253 pt wide before the scene's own scaling
PAD = 0.03             # breathing room around the shared box, as a share of its size
FRAMES = 6


def mask_of(img, scale=1.0):
    a = np.asarray(img.split()[3]) if img.mode == "RGBA" else np.asarray(img)
    return a > ALPHA


def transform(img, s, dx, dy, size):
    """Scale by s about the canvas centre, then shift by (dx, dy) pixels."""
    w, h = size
    cx, cy = w / 2, h / 2
    # PIL's affine maps OUTPUT coords to INPUT coords.
    inv = 1 / s
    coeffs = (inv, 0, cx - inv * (cx + dx), 0, inv, cy - inv * (cy + dy))
    return img.transform(size, Image.AFFINE, coeffs, resample=Image.BICUBIC)


def visible_rows(mask):
    ys = np.where(mask.any(axis=1))[0]
    top, bottom = ys.min(), ys.max()
    return top, int(top + (bottom - top) * VISIBLE_SHARE)


def iou(a, b, rows):
    r0, r1 = rows
    a, b = a[r0:r1], b[r0:r1]
    inter = np.logical_and(a, b).sum()
    union = np.logical_or(a, b).sum()
    return inter / max(1, union)


def best_fit(neutral_small, frame_small, rows, k):
    """Coarse-to-fine search over scale and offset on downsampled alpha."""
    size = frame_small.size
    best = (-1, 1.0, 0, 0)
    for s in np.arange(0.90, 1.101, 0.02):
        for dx in range(-14, 15, 2):
            for dy in range(-14, 15, 2):
                m = mask_of(transform(frame_small, s, dx, dy, size))
                score = iou(neutral_small, m, rows)
                if score > best[0]:
                    best = (score, s, dx, dy)
    _, s0, dx0, dy0 = best
    for s in np.arange(s0 - 0.02, s0 + 0.0201, 0.005):
        for dx in np.arange(dx0 - 2, dx0 + 2.01, 0.5):
            for dy in np.arange(dy0 - 2, dy0 + 2.01, 0.5):
                m = mask_of(transform(frame_small, s, dx, dy, size))
                score = iou(neutral_small, m, rows)
                if score > best[0]:
                    best = (score, s, dx, dy)
    score, s, dx, dy = best
    return float(score), float(s), float(dx * k), float(dy * k)


def register_family(src_dir, member):
    frames = [Image.open(os.path.join(src_dir, f"feed-cast-{member}-{i}.png")).convert("RGBA")
              for i in range(1, FRAMES + 1)]
    size = frames[0].size
    k = 4  # search at quarter resolution
    small = [f.resize((size[0] // k, size[1] // k), Image.BILINEAR) for f in frames]
    neutral_small = mask_of(small[0])
    rows = visible_rows(neutral_small)
    report = {"member": member, "frames": []}
    aligned = [frames[0]]
    report["frames"].append({"frame": 1, "scale": 1.0, "dx": 0.0, "dy": 0.0,
                             "iou_before": 1.0, "iou_after": 1.0})
    for i in range(1, FRAMES):
        before = iou(neutral_small, mask_of(small[i]), rows)
        score, s, dx, dy = best_fit(neutral_small, small[i], rows, k)
        aligned.append(transform(frames[i], s, dx, dy, size))
        report["frames"].append({"frame": i + 1, "scale": round(s, 4), "dx": round(dx, 1),
                                 "dy": round(dy, 1), "iou_before": round(float(before), 4),
                                 "iou_after": round(score, 4)})
    # One shared crop: the union of every registered frame's meaningful alpha, padded.
    union = np.zeros(size[::-1], dtype=bool)
    for f in aligned:
        union |= mask_of(f)
    ys, xs = np.where(union)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    px, py = int((x1 - x0) * PAD), int((y1 - y0) * PAD)
    box = (max(0, x0 - px), max(0, y0 - py), min(size[0], x1 + px), min(size[1], y1 + py))
    report["crop"] = list(map(int, box))
    return aligned, box, report


def main(argv):
    src, dst, members = argv[1], argv[2], argv[3:]
    reports = []
    for member in members:
        aligned, box, report = register_family(src, member)
        for i, f in enumerate(aligned, start=1):
            out = f.crop(box)
            scale = RUNTIME_WIDTH / out.width
            out = out.resize((RUNTIME_WIDTH, round(out.height * scale)), Image.LANCZOS)
            name = f"feed-cast-{member}-{i}"
            folder = os.path.join(dst, f"{name}.imageset")
            os.makedirs(folder, exist_ok=True)
            for old in os.listdir(folder):
                if old.endswith(".png"):
                    os.remove(os.path.join(folder, old))
            out.save(os.path.join(folder, f"{name}.png"), optimize=True)
            with open(os.path.join(folder, "Contents.json"), "w") as fh:
                json.dump({"images": [{"filename": f"{name}.png", "idiom": "universal", "scale": "3x"}],
                           "info": {"author": "xcode", "version": 1}}, fh, indent=2)
        report["runtime_size"] = list(out.size)
        reports.append(report)
    print(json.dumps(reports, indent=2))


if __name__ == "__main__":
    main(sys.argv)
