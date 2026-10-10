#!/usr/bin/env python3
"""Prepare delivered build 7 art using native alpha and proportional transforms only.

Requires Pillow. The manifest records raw sources, hashes, rectangular crops and
framing. No color-keying, alpha erasing, repainting or nonuniform scaling occurs.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import shutil
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "Docs/Art/Build7"
MANIFEST = ART / "Additional-art-source.json"


def bounds(image, threshold=32):
    if "A" not in image.getbands():
        return (0, 0, image.width, image.height)
    return image.getchannel("A").point(lambda value: 255 if value > threshold else 0).getbbox()


def prepare(entry, source):
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    if digest != entry["sourceSHA256"]:
        raise ValueError(f"{source.name}: preserved raw source hash changed")
    with Image.open(source) as original:
        if original.mode != entry["sourceMode"] or list(original.size) != entry["sourceSize"]:
            raise ValueError(f"{source.name}: unexpected native image format")
        mode = entry["preparation"]
        if mode == "preserve_native":
            return original.copy(), {"uniformScale": 1, "canvasSize": list(original.size)}
        if original.mode != "RGBA":
            raise ValueError(f"{source.name}: transparent object must be native RGBA")
        if mode == "resize_canvas":
            scale = entry["maximumCanvasSide"] / max(original.size)
            size = tuple(max(1, round(side * scale)) for side in original.size)
            return original.resize(size, Image.Resampling.LANCZOS), {"uniformScale": scale, "canvasSize": list(size)}
        crop = tuple(entry["sourceCrop"])
        cropped = original.crop(crop)
        visible = entry["measuredAlphaBounds"]
        scale = entry["visibleLongSide"] / max(visible[2] - visible[0], visible[3] - visible[1])
        resized_size = tuple(max(1, round(side * scale)) for side in cropped.size)
        canvas_size = tuple(entry["canvasSize"])
        if any(painted > side for painted, side in zip(resized_size, canvas_size)):
            raise ValueError(f"{source.name}: image leaves its canonical canvas")
        resized = cropped.resize(resized_size, Image.Resampling.LANCZOS)
        placement = tuple((side - painted) // 2 for side, painted in zip(canvas_size, resized_size))
        canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
        # Unmasked paste copies the native resampled RGBA channels unchanged.
        canvas.paste(resized, placement)
        return canvas, {"uniformScale": scale, "sourceCrop": list(crop), "resizedSize": list(resized_size),
                        "placement": list(placement), "canvasSize": list(canvas_size)}


def write_imageset(image, entry, source):
    name = entry["imageset"]
    destination = ROOT / "App/Resources/Assets.xcassets" / (name + ".imageset")
    destination.mkdir(parents=True, exist_ok=True)
    output = destination / (name + ".png")
    if entry["preparation"] == "preserve_native":
        shutil.copyfile(source, output)
    else:
        image.save(output, optimize=True)
    metadata = {"images": [{"filename": name + ".png", "idiom": "universal", "scale": "1x"},
                           {"idiom": "universal", "scale": "2x"},
                           {"idiom": "universal", "scale": "3x"}],
                "info": {"author": "xcode", "version": 1}}
    (destination / "Contents.json").write_text(json.dumps(metadata, indent=2) + "\n")
    return output


def update_shelf_bounds(records):
    path = ROOT / "App/Shared/ToyShelfScene.swift"
    text = path.read_text()
    for slot in ["shelf-dropdots", "shelf-mixup", "shelf-bubbles"]:
        record = records[slot + "-v2"]
        width, height = record["canvasSize"]
        left, top, right, bottom = record["visibleAlphaBounds"]
        replacement = f'"{slot}": (CGSize(width: {width}, height: {height}), CGRect(x: {left}, y: {top}, width: {right-left}, height: {bottom-top}))'
        pattern = rf'"{re.escape(slot)}": \(CGSize\(width: \d+, height: \d+\), CGRect\(x: \d+, y: \d+, width: \d+, height: \d+\)\)'
        text, count = re.subn(pattern, replacement, text)
        if count != 1:
            raise ValueError(f"Expected exactly one shelf geometry entry for {slot}")
    path.write_text(text)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, default=ART / "Source")
    parser.add_argument("--update-shelf-bounds", action="store_true", help="Update only the DropDots, Mix-Up and Bubbles shelf crop entries")
    args = parser.parse_args()
    records = {}
    for entry in json.loads(MANIFEST.read_text())["assets"]:
        source = args.source_dir / entry["sourceFile"]
        image, record = prepare(entry, source)
        output = write_imageset(image, entry, source)
        record.update({"sourceSHA256": entry["sourceSHA256"], "outputSHA256": hashlib.sha256(output.read_bytes()).hexdigest(),
                       "visibleAlphaBounds": list(bounds(image)), "measurementAlphaThreshold": 32, "outputMode": image.mode})
        records[entry["imageset"]] = record
    (ART / "Additional-art-preparation.json").write_text(json.dumps(records, indent=2) + "\n")
    if args.update_shelf_bounds:
        update_shelf_bounds(records)
    print(f"Registered {len(records)} build 7 art assets with native colors and transparency preserved.")


if __name__ == "__main__":
    main()
