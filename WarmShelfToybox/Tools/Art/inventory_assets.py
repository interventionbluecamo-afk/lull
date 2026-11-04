#!/usr/bin/env python3
"""Inventory bundled catalog files without guessing which assets are used at runtime.

Standard library only. Reads catalog Contents.json files and image headers, hashes files,
then records byte-identical or filename-only candidates under Assets/ and Docs/Art/.
It never moves, renames, rewrites, or deletes artwork.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import struct
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "App/Resources/Assets.xcassets"
SOURCE_ROOTS = (ROOT / "Assets", ROOT / "Docs/Art")
MEDIA_SUFFIXES = {".png", ".jpg", ".jpeg", ".webp", ".tif", ".tiff", ".pdf", ".svg"}
ASSET_SUFFIXES = {".imageset", ".appiconset", ".colorset", ".dataset", ".symbolset"}


def relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def png_dimensions(path: Path) -> dict | None:
    if path.suffix.lower() != ".png":
        return None
    with path.open("rb") as stream:
        header = stream.read(24)
    if len(header) < 24 or header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        raise ValueError("Declared PNG does not have a valid PNG/IHDR header")
    width, height = struct.unpack(">II", header[16:24])
    return {"width": width, "height": height}


def category(name: str) -> str:
    for prefixes, label in (
        (("bubbles-", "bubble-"), "Bubbles"),
        (("dropdots-",), "Drop Dots"),
        (("hum-",), "Hum"),
        (("feed-",), "Feed"),
        (("mixup-",), "Mix-Up"),
        (("meadow-",), "Meadow"),
        (("window-",), "Window"),
        (("sleepybox-",), "Sleepy Box"),
        (("wash-",), "Little Wash"),
        (("shelf-", "shelfroom-", "wren-"), "Shared"),
    ):
        if name.startswith(prefixes):
            return label
    if name.endswith(("-head", "-body", "-legs")):
        return "Mix-Up"
    if name in {"AppIcon", "BrandHero", "LaunchBackground"}:
        return "Shared"
    return "Legacy or unclassified"


def normalized_stem(path: Path) -> str:
    stem = path.stem.lower()
    return stem.removesuffix("-source")


def referenced_filenames(value):
    if isinstance(value, dict):
        for key, child in value.items():
            if key == "filename" and isinstance(child, str):
                yield child
            else:
                yield from referenced_filenames(child)
    elif isinstance(value, list):
        for child in value:
            yield from referenced_filenames(child)


def build_inventory() -> dict:
    assets, files, missing, errors = [], [], [], []
    catalog_root = CATALOG.resolve()
    for manifest in sorted(CATALOG.rglob("Contents.json")):
        folder = manifest.parent
        if folder.suffix not in ASSET_SUFFIXES:
            continue
        entry = {
            "name": folder.stem,
            "category": category(folder.stem),
            "kind": folder.suffix[1:],
            "contents": relative(manifest),
            "files": [],
        }
        assets.append(entry)
        try:
            contents = json.loads(manifest.read_text())
        except (OSError, ValueError) as error:
            errors.append({"path": relative(manifest), "error": str(error)})
            continue
        for filename in sorted(set(referenced_filenames(contents))):
            path = folder / filename
            try:
                path.resolve().relative_to(catalog_root)
            except ValueError:
                errors.append({"path": relative(manifest), "error": "Filename points outside the asset catalog", "filename": filename})
                continue
            item = {"filename": filename, "path": relative(path), "exists": path.is_file()}
            entry["files"].append(item)
            if not item["exists"]:
                missing.append({"asset": folder.stem, "path": relative(path), "contents": relative(manifest)})
                continue
            try:
                item.update({"bytes": path.stat().st_size, "sha256": digest(path)})
                dimensions = png_dimensions(path)
                if dimensions:
                    item["png_dimensions"] = dimensions
                files.append(item)
            except (OSError, ValueError) as error:
                errors.append({"path": relative(path), "error": str(error)})

    # Exact matches require equal length. Skip hashing differently sized reference files.
    bundled_sizes = {item["bytes"] for item in files}
    source_hashes, source_names = defaultdict(list), defaultdict(list)
    source_count, hashed_source_count = 0, 0
    for directory in SOURCE_ROOTS:
        if not directory.exists():
            continue
        for path in sorted(directory.rglob("*")):
            if not path.is_file() or path.suffix.lower() not in MEDIA_SUFFIXES:
                continue
            source_count += 1
            source_names[normalized_stem(path)].append(relative(path))
            try:
                if path.stat().st_size in bundled_sizes:
                    source_hashes[digest(path)].append(relative(path))
                    hashed_source_count += 1
            except OSError as error:
                errors.append({"path": relative(path), "error": str(error)})
    bundled_hashes = defaultdict(list)
    for item in files:
        bundled_hashes[item["sha256"]].append(item["path"])
        item["byte_identical_reference_files"] = source_hashes.get(item["sha256"], [])
        item["filename_candidates_not_verified"] = source_names.get(normalized_stem(Path(item["filename"])), [])
    duplicates = [
        {"sha256": key, "paths": sorted(paths)}
        for key, paths in sorted(bundled_hashes.items()) if len(paths) > 1
    ]
    counts = defaultdict(int)
    for asset in assets:
        counts[asset["category"]] += 1
    return {
        "schema_version": 1,
        "generated_at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "catalog": relative(CATALOG),
        "scope": "Files declared by Contents.json in the production asset catalog; bundled does not mean runtime-active.",
        "limitations": [
            "Category is a navigation hint based on slot naming, not a runtime usage analysis.",
            "Dynamic texture lookup, fallbacks and generated art prevent this inventory from proving an asset unused.",
            "A matching hash proves identical bytes only; a filename match is an unverified reference candidate, not provenance or licensing evidence.",
            "Duplicate hashes are informational. No artwork is removed or renamed.",
            "Only PNG dimensions are read; other file types still have size and SHA-256 metadata.",
        ],
        "summary": {
            "asset_entries": len(assets), "declared_files": sum(len(a["files"]) for a in assets),
            "readable_files": len(files), "bundled_bytes": sum(item["bytes"] for item in files),
            "assets_by_category": dict(sorted(counts.items())),
            "missing_files": len(missing), "errors": len(errors), "duplicate_hash_groups": len(duplicates),
            "reference_files_indexed": source_count, "reference_files_hashed": hashed_source_count,
        },
        "assets": assets,
        "missing_files": missing,
        "errors": errors,
        "duplicate_hash_groups": duplicates,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "Docs/Art/Inventory.json")
    args = parser.parse_args()
    result = build_inventory()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n")
    summary = result["summary"]
    print(f"Wrote {args.output}: {summary['asset_entries']} asset entries, {summary['readable_files']} files, "
          f"{summary['missing_files']} missing, {summary['errors']} errors, "
          f"{summary['duplicate_hash_groups']} duplicate hash groups (nothing removed).")
    return int(bool(result["missing_files"] or result["errors"]))


if __name__ == "__main__":
    raise SystemExit(main())
