#!/usr/bin/env python3
"""Register native transparent Little Wash wheel/tools using crop, uniform resize and padding.

Requires Pillow. Source pixels are never keyed, erased, recolored or repainted.
Crop rectangles and original hashes are recorded in Component-art-source.json.
"""
from pathlib import Path
import argparse
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "Docs/LittleWash/Component-art-source.json"


def prepare(entry, source_dir):
    source = source_dir / entry["sourceFile"]
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    if digest != entry["sourceSHA256"]:
        raise ValueError(f"{source.name}: source differs from preserved original")
    with Image.open(source) as original:
        if original.mode != "RGBA":
            raise ValueError(f"{source.name}: expected native RGBA, got {original.mode}")
        crop = tuple(entry["sourceCrop"])
        cropped = original.crop(crop)
        canvas_size = tuple(entry["canvasSize"])
        maximum = round(min(canvas_size) * entry["fillFraction"])
        scale = maximum / max(cropped.size)
        resized_size = tuple(max(1, round(side * scale)) for side in cropped.size)
        resized = cropped.resize(resized_size, Image.Resampling.LANCZOS)
        placement = tuple((side - painted) // 2 for side, painted in zip(canvas_size, resized_size))
        canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
        # Unmasked paste copies native resampled RGBA unchanged, including alpha.
        canvas.paste(resized, placement)
        return canvas, {"sourceSHA256": digest, "sourceCrop": list(crop),
                        "uniformScale": scale, "resizedSize": list(resized_size),
                        "placement": list(placement), "canvasSize": list(canvas_size)}


def write_imageset(image, name):
    destination = ROOT / "App/Resources/Assets.xcassets" / (name + ".imageset")
    destination.mkdir(parents=True, exist_ok=True)
    output = destination / (name + ".png")
    image.save(output, optimize=True)
    data = {"images": [{"filename": name + ".png", "idiom": "universal", "scale": "1x"},
                       {"idiom": "universal", "scale": "2x"},
                       {"idiom": "universal", "scale": "3x"}],
            "info": {"author": "xcode", "version": 1}}
    (destination / "Contents.json").write_text(json.dumps(data, indent=2) + "\n")
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, default=ROOT / "Docs/Art/LittleWash/Source")
    args = parser.parse_args()
    entries = json.loads(MANIFEST.read_text())["components"]
    preparation = {}
    for entry in entries:
        image, record = prepare(entry, args.source_dir)
        output = write_imageset(image, entry["imageset"])
        record["outputSHA256"] = hashlib.sha256(output.read_bytes()).hexdigest()
        preparation[entry["imageset"]] = record
    (ROOT / "Docs/LittleWash/Component-art-preparation.json").write_text(json.dumps(preparation, indent=2) + "\n")
    print(f"Registered {len(preparation)} native-alpha wheel/tool assets on 512×512 canvases.")


if __name__ == "__main__":
    main()
