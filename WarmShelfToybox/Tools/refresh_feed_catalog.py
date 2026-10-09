#!/usr/bin/env python3
"""Refresh the bundled Feed catalog from complete Xcode image sets (stdlib only).

A cast is available only when all six feed-cast-<name>-1...6.imageset
directories have valid Contents.json image entries pointing to local files.
The parked scarf cast stays excluded until its replacement art is reviewed.

New complete casts inherit the sprout rig. Their art must be registered to that
same geometry, or have measured values added to CAST_RIGS before release:
headWidth is painted head width / canvas width; headCentre and mouth are their
vertical centres measured from the canvas TOP / canvas height. Measure on the
neutral expression and verify the mouth target across all six expressions.
Friendly names for new casts default to "the <name> friend".

Run from any directory. --assets and --output allow isolated fixture checks.
The output is deterministic and is left untouched when its contents match.
"""

import argparse
import json
from pathlib import Path
import re


CAST_PATTERN = re.compile(r"feed-cast-([a-z0-9]+(?:-[a-z0-9]+)*)-([1-6])\.imageset")
CAST_ORDER = ("sprout", "mira", "grandmother", "jun", "knithat")
PARKED_CAST = {"scarf"}
CAST_RIGS = {
    "mira": ("Mira", 0.90, 0.405, 0.610),
    "jun": ("Jun", 0.90, 0.400, 0.585),
    "sprout": ("the little one", 0.893, 0.44, 0.520),
    "grandmother": ("the grandmother", 0.875, 0.40, 0.505),
    "knithat": ("the kid in the knit hat", 0.933, 0.48, 0.573),
}
FOOD_NAMES = ("apple", "carrot", "egg", "bread", "berry", "banana", "cookie", "cup", "grape", "pear")


def valid_imageset(imageset: Path) -> bool:
    """An empty slot or an unreferenced image does not count as available art."""
    try:
        metadata = json.loads((imageset / "Contents.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return False
    if not isinstance(metadata, dict) or not isinstance(metadata.get("images"), list):
        return False
    for image in metadata["images"]:
        if not isinstance(image, dict):
            continue
        filename = image.get("filename")
        # Xcode image-set filenames reference files inside this imageset.
        if not isinstance(filename, str) or not filename or Path(filename).name != filename:
            continue
        try:
            if (imageset / filename).is_file() and (imageset / filename).stat().st_size > 0:
                return True
        except OSError:
            continue
    return False


def build_catalog(assets: Path) -> dict:
    frames = {}
    foods = set()
    for imageset in sorted(assets.rglob("*.imageset")):
        if not imageset.is_dir() or not valid_imageset(imageset):
            continue
        match = CAST_PATTERN.fullmatch(imageset.name)
        if match:
            name, frame = match.groups()
            frames.setdefault(name, set()).add(int(frame))
        elif imageset.name.startswith("feed-"):
            name = imageset.name[len("feed-"):-len(".imageset")]
            if name in FOOD_NAMES:
                foods.add(name)

    complete = {name for name, found in frames.items()
                if found == set(range(1, 7)) and name not in PARKED_CAST}
    ordered = [name for name in CAST_ORDER if name in complete]
    ordered += sorted(complete.difference(CAST_ORDER))
    cast = []
    for name in ordered:
        friendly, width, centre, mouth = CAST_RIGS.get(
            name, (f"the {name.replace('-', ' ')} friend", *CAST_RIGS["sprout"][1:]))
        cast.append({"name": name, "friendlyName": friendly,
                     "headWidth": width, "headCentre": centre, "mouth": mouth})
    return {"version": 1, "cast": cast,
            "foods": [name for name in FOOD_NAMES if name in foods]}


def refresh(assets: Path, output: Path) -> dict:
    if not assets.is_dir():
        raise ValueError(f"asset catalog does not exist: {assets}")
    catalog = build_catalog(assets)
    content = json.dumps(catalog, indent=2, ensure_ascii=False) + "\n"
    try:
        unchanged = output.read_text(encoding="utf-8") == content
    except FileNotFoundError:
        unchanged = False
    if not unchanged:
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(content, encoding="utf-8")
    return catalog


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--assets", type=Path, default=root / "App/Resources/Assets.xcassets")
    parser.add_argument("--output", type=Path, default=root / "App/Resources/FeedCatalog.json")
    args = parser.parse_args()
    try:
        catalog = refresh(args.assets, args.output)
    except (OSError, ValueError) as error:
        parser.exit(1, f"Feed catalog refresh failed: {error}\n")
    print(f"Feed catalog: {len(catalog['cast'])} complete casts, {len(catalog['foods'])} food images")


if __name__ == "__main__":
    main()
