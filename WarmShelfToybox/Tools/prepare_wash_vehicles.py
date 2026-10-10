#!/usr/bin/env python3
"""Register delivered transparent Little Wash vehicles without repainting pixels.

Requires Pillow. Operations are rectangular crop, proportional resize, transparent
padding and imageset registration only. Native RGB/alpha are never keyed or erased.
Rig measurements come from Vehicle-art-source.json, not guessed runtime geometry.
"""
from pathlib import Path
import argparse
import hashlib
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "Docs/LittleWash/Vehicle-art-source.json"


def prepare(entry, source_dir):
    source = source_dir / entry["sourceFile"]
    original = Image.open(source)
    if original.mode != "RGBA":
        raise ValueError(f"{source.name}: expected native RGBA, got {original.mode}")
    crop = tuple(entry["sourceCrop"])
    cropped = original.crop(crop)
    width = 1280
    height = round(cropped.height * width / cropped.width)
    sx, sy = width / cropped.width, height / cropped.height
    image = cropped.resize((width, height), Image.Resampling.LANCZOS)
    raw_wheels = entry["measuredWheelArches"]
    # The separate wheel sprite slightly overlaps the inner arch; the body masks its top.
    wheel_radii = [wheel["radius"] * entry["wheelOverlapScale"] * sy for wheel in raw_wheels]
    raw_ground = max(w["center"][1] + w["radius"] for w in raw_wheels)
    left = 160
    top = round(880 - (raw_ground - crop[1]) * sy)
    if top < 0 or top + height > 1000:
        raise ValueError(f"{source.name}: body would leave canonical canvas")
    canvas = Image.new("RGBA", (1600, 1000), (0, 0, 0, 0))
    canvas.alpha_composite(image, (left, top))
    fx, fy = entry["faceCenter"]
    rig = {
        "faceCenter": [(left + (fx - crop[0]) * sx) / 1600,
                       (top + (fy - crop[1]) * sy) / 1000],
        "faceRadius": entry["faceRadius"] * sy / 1000,
        "wheels": [{"center": [(left + (w["center"][0] - crop[0]) * sx) / 1600,
                               (880 - radius) / 1000], "radius": radius / 1000}
                   for w, radius in zip(raw_wheels, wheel_radii)],
        "isMeasured": True,
        "groundLine": 0.88,
        "canvasSize": [1600, 1000],
        "bodyPlacement": [left, top, width, height],
        "sourceSHA256": hashlib.sha256(source.read_bytes()).hexdigest(),
    }
    return canvas, rig


def write_imageset(image, name):
    destination = ROOT / "App/Resources/Assets.xcassets" / (name + ".imageset")
    destination.mkdir(parents=True, exist_ok=True)
    image.save(destination / (name + ".png"), optimize=True)
    data = {"images": [{"filename": name + ".png", "idiom": "universal", "scale": "1x"},
                       {"idiom": "universal", "scale": "2x"},
                       {"idiom": "universal", "scale": "3x"}],
            "info": {"author": "xcode", "version": 1}}
    (destination / "Contents.json").write_text(json.dumps(data, indent=2) + "\n")


def update_rigs(rigs):
    model = ROOT / "App/Toys/Wash/WashModel.swift"
    text = model.read_text()
    start = text.index("    static func forVehicle(_ kind: WashVehicleKind) -> WashVehicleRig {")
    depth = 0
    end = None
    for index in range(text.index("{", start), len(text)):
        depth += (text[index] == "{") - (text[index] == "}")
        if depth == 0:
            end = index + 1
            break
    lines = ["    static func forVehicle(_ kind: WashVehicleKind) -> WashVehicleRig {", "        switch kind {"]
    for kind, rig in rigs.items():
        x, y = rig["faceCenter"]
        lines += [f"        case .{kind}:", "            return WashVehicleRig(",
                  f"                faceCenter: WashPoint(x: {x:.8f}, y: {y:.8f}), faceRadius: {rig['faceRadius']:.8f},",
                  "                wheels: ["]
        for wheel in rig["wheels"]:
            x, y = wheel["center"]
            lines.append(f"                    WashWheelRig(center: WashPoint(x: {x:.8f}, y: {y:.8f}), radius: {wheel['radius']:.8f}),")
        lines += ["                ], isMeasured: true)"]
    lines += ["        }", "    }"]
    if len(rigs) != 6:
        raise ValueError("Refuse to replace the six-case rig table with an incomplete cast")
    model.write_text(text[:start] + "\n".join(lines) + text[end:])


def contact_sheet(images, rigs, path):
    # Diagnostic only: the shipped PNGs keep their native transparent background.
    thumb_width, thumb_height = 400, 250
    sheet = Image.new("RGB", (thumb_width * len(images), thumb_height + 52), "#e8e1d1")
    draw = ImageDraw.Draw(sheet)
    for index, (kind, image) in enumerate(images.items()):
        tile = Image.new("RGBA", image.size, "#e8e1d1")
        rig = rigs[kind]
        pen = ImageDraw.Draw(tile)
        for wheel in rig["wheels"]:
            x, y = wheel["center"]; r = wheel["radius"] * 1000
            x *= 1600; y *= 1000
            pen.ellipse((x-r, y-r, x+r, y+r), fill="#453e37")
            pen.ellipse((x-r*.36, y-r*.36, x+r*.36, y+r*.36), fill="#c8b79c")
        tile.alpha_composite(image)
        pen = ImageDraw.Draw(tile)
        x, y = rig["faceCenter"]; r = rig["faceRadius"] * 1000
        x *= 1600; y *= 1000
        pen.ellipse((x-r, y-r, x+r, y+r), outline="#783539", width=3)
        for side in [-1, 1]:
            ex = x + side * r * .38
            pen.ellipse((ex-r*.09, y-r*.2, ex+r*.09, y), fill="#453e37")
        pen.arc((x-r*.35, y, x+r*.35, y+r*.4), start=0, end=180, fill="#453e37", width=4)
        pen.line((0, 880, 1600, 880), fill="#bd463c", width=3)
        sheet.paste(tile.resize((thumb_width, thumb_height), Image.Resampling.LANCZOS).convert("RGB"), (index*thumb_width, 28))
        draw.text((index*thumb_width+8, 8), kind, fill="#453e37")
    draw.text((8, thumb_height+34), "Diagnostic: measured live-face area + placeholder wheels; red line = shared wheel bottom", fill="#453e37")
    sheet.save(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, default=ROOT / "Docs/Art/LittleWash/Source")
    parser.add_argument("--allow-missing", action="store_true", help="Only register currently delivered assets; do not update Swift rig table")
    parser.add_argument("--contact-sheet", type=Path)
    args = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text())
    images, rigs = {}, {}
    for entry in manifest["vehicles"]:
        if not (args.source_dir / entry["sourceFile"]).is_file():
            if args.allow_missing:
                continue
            raise FileNotFoundError(args.source_dir / entry["sourceFile"])
        image, rig = prepare(entry, args.source_dir)
        write_imageset(image, entry["imageset"])
        images[entry["kind"]], rigs[entry["kind"]] = image, rig
    (ROOT / "Docs/LittleWash/Vehicle-rigs.json").write_text(json.dumps(rigs, indent=2) + "\n")
    if not args.allow_missing:
        update_rigs(rigs)
    if args.contact_sheet:
        contact_sheet(images, rigs, args.contact_sheet)
    print(f"Registered {len(images)} native-alpha vehicles; shared canvas 1600×1000, wheel bottom 880.")


if __name__ == "__main__":
    main()
