# Warm Shelf Resources

This folder is the app's lightweight asset library. Keep assets small, quiet, and optional: every toy should still compile and play if a future asset is missing.

## Folders

- `Audio/`: short sound effects, grouped by toy and shared use.
- `Textures/`: subtle paper, clay, food, and material textures.
- `Sprites/`: hand-drawn or exported raster sprites for objects that outgrow procedural SpriteKit shapes.
- `Reference/`: non-shipping visual or sound references used while exploring style.

## Rules

- Prefer lowercase kebab-case filenames, for example `bubble-pop-small-1.mp3`.
- Keep child-facing toy assets wordless.
- Avoid high-contrast, neon, glossy, or arcade-style assets.
- Treat assets as enhancement, not dependency; code should use graceful fallback behavior.
- Add every real asset to `Docs/AssetManifest.md` when it lands.

