# Meadow — quiet felt and small reactions

November 3, 2026. Requested scope: improve the ground, show the existing leaf house from the start, and add a quiet hedgehog/pond response. The founder wants Meadow to remain one good toy in Lull, with no expansion into a bigger flagship game.

## Artwork

Generated with the built-in imagegen tool. Exact prompts and reference paths are in `Prompts.json`.

- `App/Resources/Assets.xcassets/meadow-felt-ground.imageset/meadow-felt-ground.png`: opaque 1254 × 1254 fine sage felt. One continuous material is tinted for day/night; gentle translucent sage or blue-green brush marks preserve its fibres as the garden grows. No baked pebbles or grass tufts, so repeating tiles stay quiet beside the existing creatures and flowers.
- `App/Resources/Assets.xcassets/meadow-hedgehog-curled.imageset/meadow-hedgehog-curled.png`: transparent 1254 × 1254 curled pose, derived from the existing top-down hedgehog. Replaces the visible face with matching felt quills during the tuck; the existing sprite and procedural expression return during the peek.

These are production assets in the repository, not external runtime dependencies. The earlier ground assets remain as fallbacks. No new sound assets were added.

## Code

`MeadowScene.swift` uses the shared ground texture, matching world alignment, and a restrained sage / blue-green palette. `MeadowLandmark` has an inner animated body so reactions preserve each landmark's original scale and angle. The hedgehog tucks and peeks; two pooled rings ripple within the pond's open water. Repeated taps cannot queue additional performances. Frost clears the reaction, rotation restores quietly, and Reduce Motion uses opacity-only feedback.

`MeadowLittleOnes.swift` shows the leaf house immediately, including before any baby is found and after rotation. Existing hiding places, baby movement, arrivals, house glow, and finale are retained.

Debug-only render aid: `LULL_DEBUG_MEADOW_REACTIONS=1` places a hedgehog and pond above home, wakes them after one second, and repeats their interaction after another 3.5 seconds. These additional landmarks never appear in Release builds. `LULL_DEBUG_MEADOW_NIGHT=0` / `1` selects the palette for preview.

No persistence, new outing loop, additional creatures, pricing, or App Store changes are included.
