# Lull · Nat cut-paper assets

Four generated source-art masters are in `Outputs/`. Open [index.html](index.html) for the offline gallery. These assets have **not been wired into the app**; no application code or production assets were changed.

All four are native **1254 × 1254, 8-bit RGBA PNGs**. The prompts requested 1024 × 1024, but the generator returned 1254 × 1254. These masters were copied unchanged: no resizing, cropping, or alpha cleanup was performed. [Output-Manifest.json](Output-Manifest.json) records actual dimensions, matching SHA-256 hashes, and alpha checks. [Generation-Manifest.json](Generation-Manifest.json) preserves the full prompts and generated source paths.

Sitting and peeking are intentionally eyeless. The eye-pieces sheet contains three pieces that need extraction or reviewed SpriteKit texture rectangles before integration. Standing, walking, and sitting-closed were not requested for regeneration; their originals are included among the six unchanged references in `Inputs/`, alongside [Original-Brief.txt](Inputs/Original-Brief.txt). [Input-Manifest.json](Input-Manifest.json) records original and copied paths and matching hashes.

All four outputs have genuine alpha transparency, fully transparent corners, and large fully transparent background areas. The native sitting and sleeping files retain a small number of nonzero-alpha pixels at the outer border; the table records their count and maximum alpha on the 0–255 scale. The files remain unchanged.

| Output | Actual size (px) | Nonzero border pixels | Maximum border alpha |
| --- | --- | --- | --- |
| `nat-sitting-eyeless.png` | 1254 × 1254 | 55 | 1 |
| `nat-peeking-eyeless.png` | 1254 × 1254 | 0 | 0 |
| `nat-sleeping.png` | 1254 × 1254 | 23 | 1 |
| `nat-eye-pieces.png` | 1254 × 1254 | 0 | 0 |

The ZIP contains this folder’s complete contents with `index.html` at the archive root. Extract the ZIP before opening the gallery. An extracted copy is also available at `/Users/User2/Downloads/Lull-Nat-Assets-2026-11-13`.
