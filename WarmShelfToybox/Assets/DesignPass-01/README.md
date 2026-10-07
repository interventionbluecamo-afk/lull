# Design pass 01 artwork

These assets form one design direction for Lull: pale birch, matte clay, broad soft daylight, restrained texture, clear silhouettes, and quiet neutral surroundings.

- `direction-board.png`: exploratory shelf/sorter composition; not a live screen.
- `shelfroom-v2-day.png`: empty neutral wall/floor room plate.
- `sleepybox-v2-shell.png`: blank birch box with one lower cavity; openings, drawer, pieces, and face are app geometry.
- `shelf-*-v2.png`: nine shelf-object assets. Exact prompts and output provenance are in `shelf-art-manifest.json`.
- `shelf-iphone-before-final.png`: actual simulator capture from the first integrated build.

Generated PNGs are preserved unchanged. The app fits visible alpha bounds using SpriteKit texture regions, avoiding inconsistent export padding. Transparent exports may contain colored RGB data under zero alpha; those pixels do not become a visible glow in the app. Judge the actual composited screen.

Art direction briefs for the first three outputs: a quieter shelf/sorter concept; a blank straight-on pale birch sorter shell without baked interactive holes or a second drawer; and an empty bright neutral wall with a low wood floor. These are brief summaries, not a reconstruction of the exact generation prompts.

Every asset remains provisional until its in-app scale, edges, and connection to the toy's actual action have passed review.
