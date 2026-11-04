# Lull artwork — start here

Updated November 3, 2026. Existing production paths and asset-slot names are preserved.

| Location | What belongs here |
| --- | --- |
| [`../../App/Resources/Assets.xcassets`](../../App/Resources/Assets.xcassets) | The production catalog Xcode bundles. Scenes refer to these stable slot names. |
| [`Inventory.json`](Inventory.json) | Generated catalog inventory: declared files, PNG dimensions, sizes, SHA-256 hashes, missing-file errors, duplicate hashes and reference-file candidates. |
| [`../AssetManifest.md`](../AssetManifest.md) | Navigation by the nine toys and shared artwork; older planning examples are marked historical. |
| [`../../Assets/README.md`](../../Assets/README.md) | Source/staging workspace, marketing sources and references outside the app target. Some raw/reference directories are gitignored. |
| Dated/batch folders below | Prompts, source records, decisions and previews for a particular art pass. Read the folder's README/manifest before reusing a file. |

**Bundled is not the same as active in the app.** Dynamic slot lookup, fallback artwork and procedural drawing cannot be resolved safely from filenames alone. The inventory never labels art safe to delete. Identical hashes are a navigation aid, not a deletion request. Filename-only source candidates are explicitly unverified.

## Current passes

- [`Materials-Motion-2026-11-03/`](Materials-Motion-2026-11-03/): November 3–4 approved nine-toy implementation, separate Wash brushes and Meadow roof, generation prompts/provenance, scoped verification and restart notes.
- [`Meadow-Materials-2026-11-03/`](Meadow-Materials-2026-11-03/): new overhead leaf shelter, shared material lighting and actual scene previews. Includes exact `Prompt.json`, source decisions, the nine-toy roadmap and the build handoff.
- [`Meadow-2026-11-03/`](Meadow-2026-11-03/): continuous felt ground, curled hedgehog, prompts and first-pass rationale.
- [`Wash-2026-11-03/`](Wash-2026-11-03/): portrait wash bay prompt and integration notes.
- [`Wash-Expansion-2026-10-17/`](Wash-Expansion-2026-10-17/), [`LittleWash/Source/`](LittleWash/Source/) and [`Wash-Vehicles-ChatGPT-Prompt.md`](Wash-Vehicles-ChatGPT-Prompt.md): vehicle/rig source records and checks.

## Historical batches — preserve as evidence

- [`Build10/`](Build10/): original baby ladybug, hiding leaf and original house/glow source images with prompts and manifest.
- [`Build7/`](Build7/): earlier Feed, Wash and shelf generations and preparation records.
- Older design-pass and staging folders in `Assets/` are candidates/source history, not an approved list of currently used art.

The old **`meadow-leaf-house-glow`** slot remains bundled, but the new Meadow renderer no longer uses it: doorway light is now drawn in code. Its original image remains under `Build10/Source/`. Keeping that source does not require restoring the old house overlay.

## Refresh the inventory

From `WarmShelfToybox/`:

```sh
python3 Tools/Art/inventory_assets.py
```

The script uses only Python's standard library. It reads `Contents.json`, checks declared files, extracts PNG dimensions, and hashes production files. It indexes reference filenames under `Assets/` and `Docs/Art/`; reference files are hashed only when their byte length could match a bundled file. Missing files or read errors return a nonzero exit code. It writes only the inventory JSON; it never moves, renames or deletes artwork.

When adding art: save the selected production file in its catalog slot, keep useful prompt/source evidence in a clearly named pass folder, render it in the actual game, then refresh this inventory. New layers intended to move independently should be separate assets rather than baked into a whole-room illustration.
