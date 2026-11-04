# Meadow's southern beach

Founder request, November 4: one beach edge with starfish, shells, flowing jellyfish and subtly visible fish. Perspective must remain consistent with Meadow.

## Art and spatial contract

The camera looks straight down. The sand, shore and sea are paths in the same world coordinate system as the garden; there is no horizon or perspective backdrop. All rotations derive the coast from the same square world extent. The mother and followers stop on dry land, while the unchanged camera bounds keep the sea visible beyond them.

- Sand begins near −0.36 × world height. The waterline is near −0.445 × height, with broad shallow curves. The conservative walking line is −0.415 × height, above the surf even at its crest.
- The existing felt ground texture supplies sand/water material at native tile scale. The beach covers spring/trail paint; new stored flowers and coverage points stay on grass.
- Six optional sea stars/shells lie on the sand with close contact shadows. Touch or VoiceOver activation makes a short restrained response and a slower return. No sound or reward is added.
- Three jellyfish are viewed from above, with circular translucent bells and fine current-following threads. Seven fish silhouettes travel slowly beneath the surface at low opacity. Their positions and node counts are bounded; Reduced Motion freezes the water/sea-life movement.
- No SpriteKit warp geometry is used by the new beach. The build 20 rendering mitigation is retained elsewhere.

## Generated assets

Built-in **image_gen**, two calls; no CLI fallback. Both outputs were inspected for a straight-down camera, simple felt forms and neutral lighting. The original RGBA PNGs are copied unmodified into the catalog, with dimensions and SHA-256 hashes recorded in [Assets.json](Assets.json). The complete final prompts are in [Prompts.json](Prompts.json).

- `App/Resources/Assets.xcassets/meadow-beach-starfish.imageset/meadow-beach-starfish.png`
- `App/Resources/Assets.xcassets/meadow-beach-shell.imageset/meadow-beach-shell.png`

Shoreline, jellyfish and fish use code-native geometry to preserve perspective and animate their parts independently. No generated ocean backdrop or replacement gameplay screenshot was made.

## Implementation and validation

Source: `App/Toys/Meadow/MeadowBeach.swift`, `MeadowScene.swift`, `MeadowLittleOnes.swift`. The Xcode project includes the new source; project.yml continues to include all App sources. Version **1.1 (21)**.

Focused production-geometry checks passed for land boundaries, valid flower-slot preservation through rotation, initial and recurring baby placement, and dandelion access. The combined Debug build passed. This is engineering evidence, not physical-device acceptance. The founder's build 19 renderer crash remains unreproduced; build 20's mitigation is included, with no new warp rendering introduced here.

DEBUG `LULL_DEBUG_MEADOW_BEACH=1` starts near the sand for captures and bypasses the introductory wander. Normal play starts at the house as before; lead the ladybug toward the bottom of the world to find the beach.

## Preview scope

[Day](isolated-native-beach-day-t0.png) and [night](isolated-native-beach-night-t6.png) are isolated native macOS SpriteKit renders of the production beach node at 874 × 402 points, exported at 2×. They use the real assets and production geometry. They are **not full iOS screenshots or physical-device tests**: ladybugs, scene controls and the rest of Meadow are excluded. The preview confirmed the shared overhead plane and corrected an olive sand tint before the final build. Day sand is warm cream; night sand is blue-gray. Subtle original wool fibres overlay the flat material colors.

The scene retains sea-life/tide phase through rotation. Final build/upload status is in [the beach handoff](Handoff.md).
