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
EXPECTED_KINDS = {
    "fireTruck", "policeCar", "tractor", "schoolBus", "digger", "iceCreamVan",
    "garbageTruck", "mailTruck", "camper", "towTruck", "ambulance", "helicopter",
}


def read_source(entry, source_dir):
    source = source_dir / entry["sourceFile"]
    original = Image.open(source)
    if original.mode != "RGBA":
        raise ValueError(f"{source.name}: expected native RGBA, got {original.mode}")
    crop = tuple(entry["sourceCrop"])
    if not (len(crop) == 4 and 0 <= crop[0] < crop[2] <= original.width
            and 0 <= crop[1] < crop[3] <= original.height):
        raise ValueError(f"{source.name}: crop must be a nonempty rectangle inside the source")
    return source, original.crop(crop), crop


def prepare(entry, source_dir):
    source, cropped, crop = read_source(entry, source_dir)
    raw_wheels = entry["measuredWheelArches"]
    preparation = entry.get("preparation", "wheel-ground")
    if preparation == "body-baseline":
        width = int(entry.get("bodyWidth", 1268))
        bottom = int(entry.get("bodyBottom", 880 if entry["kind"] == "helicopter" else 770))
        if not (0 < width <= 1600 and 20 < bottom <= 1000):
            raise ValueError(f"{source.name}: invalid body width or baseline")
        height = round(cropped.height * width / cropped.width)
        # Bound tall art with proportional scaling; do not crop off a mast or boom.
        if height > bottom - 20:
            height = bottom - 20
            width = round(cropped.width * height / cropped.height)
        left = (1600 - width) // 2
        top = bottom - height
    elif preparation == "wheel-ground":
        # Preserve the first six vehicles' original preparation exactly.
        width = 1280
        height = round(cropped.height * width / cropped.width)
        raw_ground = max(w["center"][1] + w["radius"] for w in raw_wheels)
        left = 160
        top = round(880 - (raw_ground - crop[1]) * (height / cropped.height))
    else:
        raise ValueError(f"{source.name}: unknown preparation {preparation!r}")
    if width < 1 or height < 1 or top < 0 or top + height > 1000:
        raise ValueError(f"{source.name}: body would leave canonical canvas")
    sx, sy = width / cropped.width, height / cropped.height
    image = cropped.resize((width, height), Image.Resampling.LANCZOS)
    # The separate wheel sprite slightly overlaps the inner arch; the body masks its top.
    wheel_radii = [wheel["radius"] * entry["wheelOverlapScale"] * sy for wheel in raw_wheels]
    if preparation == "body-baseline":
        # Grounding can lower a fitted wheel below its source arch. Keep its upper edge
        # tucked behind the arch as well as its bottom on the common floor.
        for i, wheel in enumerate(raw_wheels):
            arch_top = top + (wheel["center"][1] - wheel["radius"] - crop[1]) * sy
            wheel_radii[i] = max(wheel_radii[i], (880 - arch_top) * 0.5 * 1.025)
    canvas = Image.new("RGBA", (1600, 1000), (0, 0, 0, 0))
    canvas.alpha_composite(image, (left, top))
    fx, fy = entry["sourceFaceCenter"] if "sourceFaceCenter" in entry else entry["faceCenter"]
    face_radius = entry["sourceFaceRadius"] if "sourceFaceRadius" in entry else entry["faceRadius"]
    rig = {
        "faceCenter": [(left + (fx - crop[0]) * sx) / 1600,
                       (top + (fy - crop[1]) * sy) / 1000],
        "faceRadius": face_radius * sy / 1000,
        "wheels": [{"center": [(left + (w["center"][0] - crop[0]) * sx) / 1600,
                               (880 - radius) / 1000], "radius": radius / 1000}
                   for w, radius in zip(raw_wheels, wheel_radii)],
        "isMeasured": True,
        "groundLine": 0.88,
        "canvasSize": [1600, 1000],
        "bodyPlacement": [left, top, width, height],
        "sourceSHA256": hashlib.sha256(source.read_bytes()).hexdigest(),
    }
    rotor_center = entry.get("sourceRotorCenter", entry.get("rotorCenter"))
    if rotor_center is not None:
        rx, ry = rotor_center
        rig["rotorCenter"] = [(left + (rx - crop[0]) * sx) / 1600,
                              (top + (ry - crop[1]) * sy) / 1000]
        rig["rotorWidth"] = entry.get("rotorWidth", 0.75)
    if entry["kind"] == "helicopter" and (raw_wheels or rotor_center is None):
        raise ValueError("Helicopter must have no wheels and a measured rotor centre")
    return canvas, rig


def prepare_component(entry, source_dir):
    source, cropped, _ = read_source(entry, source_dir)
    canvas_size = tuple(entry.get("canvas", [1200, 240]))
    width = int(entry.get("bodyWidth", 1150))
    if canvas_size != (1200, 240) or not 0 < width <= canvas_size[0]:
        raise ValueError(f"{source.name}: expected 1200×240 rotor canvas with a fitting width")
    height = round(cropped.height * width / cropped.width)
    if height > canvas_size[1]:
        height = canvas_size[1]
        width = round(cropped.width * height / cropped.height)
    if width < 1 or height < 1:
        raise ValueError(f"{source.name}: component is too thin to prepare")
    image = cropped.resize((width, height), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    canvas.alpha_composite(image, ((canvas_size[0] - width) // 2,
                                   (canvas_size[1] - height) // 2))
    return canvas


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
    if set(rigs) != EXPECTED_KINDS or not all(rig["isMeasured"] for rig in rigs.values()):
        raise ValueError("Refuse to replace the twelve-case rig table with an incomplete or provisional cast")
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
    if end is None:
        raise ValueError("Cannot locate the end of the existing Swift rig table")
    lines = ["    static func forVehicle(_ kind: WashVehicleKind) -> WashVehicleRig {", "        switch kind {"]
    for kind, rig in rigs.items():
        x, y = rig["faceCenter"]
        lines += [f"        case .{kind}:", "            return WashVehicleRig(",
                  f"                faceCenter: WashPoint(x: {x:.8f}, y: {y:.8f}), faceRadius: {rig['faceRadius']:.8f},",
                  "                wheels: ["]
        for wheel in rig["wheels"]:
            x, y = wheel["center"]
            lines.append(f"                    WashWheelRig(center: WashPoint(x: {x:.8f}, y: {y:.8f}), radius: {wheel['radius']:.8f}),")
        if "rotorCenter" in rig:
            x, y = rig["rotorCenter"]
            lines += ["                ], isMeasured: true,",
                      f"                rotorCenter: WashPoint(x: {x:.8f}, y: {y:.8f}), rotorWidth: {rig['rotorWidth']:.8f})"]
        else:
            lines += ["                ], isMeasured: true)"]
    lines += ["        }", "    }"]
    model.write_text(text[:start] + "\n".join(lines) + text[end:])


def contact_sheet(images, rigs, path, components=None):
    # Diagnostic only: the shipped PNGs keep their native transparent background.
    if not images:
        return
    thumb_width, thumb_height = 400, 250
    columns = min(6, len(images))
    rows = (len(images) + columns - 1) // columns
    row_height = thumb_height + 28
    sheet = Image.new("RGB", (thumb_width * columns, row_height * rows + 30), "#e8e1d1")
    draw = ImageDraw.Draw(sheet)
    rotor_image = (components or {}).get("wash-helicopter-rotor")
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
        if rotor_image is not None and "rotorCenter" in rig:
            width = round(rig["rotorWidth"] * 1600)
            height = round(rotor_image.height * width / rotor_image.width)
            rotor = rotor_image.resize((width, height), Image.Resampling.LANCZOS)
            x, y = rig["rotorCenter"]
            tile.alpha_composite(rotor, (round(x * 1600 - width / 2), round(y * 1000 - height / 2)))
        pen = ImageDraw.Draw(tile)
        x, y = rig["faceCenter"]; r = rig["faceRadius"] * 1000
        x *= 1600; y *= 1000
        pen.ellipse((x-r, y-r, x+r, y+r), outline="#783539", width=3)
        for side in [-1, 1]:
            ex = x + side * r * .38
            pen.ellipse((ex-r*.09, y-r*.2, ex+r*.09, y), fill="#453e37")
        pen.arc((x-r*.35, y, x+r*.35, y+r*.4), start=0, end=180, fill="#453e37", width=4)
        pen.line((0, 880, 1600, 880), fill="#bd463c", width=3)
        tile_x = (index % columns) * thumb_width
        tile_y = (index // columns) * row_height
        sheet.paste(tile.resize((thumb_width, thumb_height), Image.Resampling.LANCZOS).convert("RGB"), (tile_x, tile_y + 28))
        draw.text((tile_x + 8, tile_y + 8), kind, fill="#453e37")
    draw.text((8, row_height * rows + 8), "Diagnostic: measured live-face area + placeholder wheels; red line = shared wheel/skid bottom", fill="#453e37")
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, help="Override the manifest's preserved-source directory")
    parser.add_argument("--allow-missing", action="store_true", help="Only register delivered assets; retain missing rig records and do not update Swift")
    parser.add_argument("--contact-sheet", type=Path)
    args = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text())
    source_dir = args.source_dir or ROOT / manifest.get("sourceDirectory", "Docs/Art/LittleWash/Source")
    kinds = [entry["kind"] for entry in manifest["vehicles"]]
    if len(kinds) != len(set(kinds)):
        raise ValueError("Duplicate vehicle kinds in source manifest")
    if not args.allow_missing and set(kinds) != EXPECTED_KINDS:
        raise ValueError("Full preparation requires all twelve vehicles; use --allow-missing for partial registration")
    # Prepare and validate every input before changing any registered output.
    images, rigs, components, asset_names = {}, {}, {}, {}
    for entry in manifest["vehicles"]:
        if not (source_dir / entry["sourceFile"]).is_file():
            if args.allow_missing:
                continue
            raise FileNotFoundError(source_dir / entry["sourceFile"])
        image, rig = prepare(entry, source_dir)
        images[entry["kind"]], rigs[entry["kind"]] = image, rig
        asset_names[entry["kind"]] = entry["imageset"]
    for entry in manifest.get("components", []):
        if not (source_dir / entry["sourceFile"]).is_file():
            if args.allow_missing:
                continue
            raise FileNotFoundError(source_dir / entry["sourceFile"])
        components[entry["imageset"]] = prepare_component(entry, source_dir)
    if not args.allow_missing and "wash-helicopter-rotor" not in components:
        raise ValueError("Full preparation requires the separate helicopter rotor component")
    for kind, image in images.items():
        write_imageset(image, asset_names[kind])
    for name, image in components.items():
        write_imageset(image, name)
    rig_path = ROOT / "Docs/LittleWash/Vehicle-rigs.json"
    records = json.loads(rig_path.read_text()) if args.allow_missing and rig_path.is_file() else {}
    records.update(rigs)
    rig_path.write_text(json.dumps(records, indent=2) + "\n")
    if not args.allow_missing:
        update_rigs(rigs)
    if args.contact_sheet:
        contact_sheet(images, rigs, args.contact_sheet, components)
    print(f"Registered {len(images)} native-alpha vehicles and {len(components)} components; vehicle canvas 1600×1000, ground 880.")


if __name__ == "__main__":
    main()
