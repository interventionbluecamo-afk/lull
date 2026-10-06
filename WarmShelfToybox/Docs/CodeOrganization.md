# Warm Shelf Code Organization

This app should stay small, readable, and toy-like. The goal is not to build a game engine. The goal is to make each toy easy to reason about, tune, and toddler-test.

## Current Shape

| Area | Responsibility |
| --- | --- |
| `App/Shared` | Reusable app and toy primitives: base scenes, palette, motion, feedback, haptics, audio, particles, registry, shelf. |
| `App/Toys/Bubbles` | Bubbles-only behavior and bubble drawing. |
| `App/Toys/ClayBlocks` | Clay Blocks-only physics, block drawing, source tray, height memory, and camera follow. |
| `App/Toys/FeedThePeople` | Feed-only characters, foods, cafeteria queue, thought bubbles, and feeding feedback. |
| `App/Resources` | Shipping and future assets, organized by medium and toy. |
| `Docs` | Product, build, asset, and implementation notes. |

## Rules

- Register toys only in `ToyRegistry`.
- Keep toy-specific code inside its toy folder unless another toy truly reuses it.
- Prefer a small typed helper over stringly-typed configuration.
- Prefer procedural SpriteKit drawing until an asset clearly improves toddler comprehension.
- Keep procedural texture centralized in `ProceduralTexture` so material feel stays consistent across toys.
- Use `TouchFeedbackAnimator.tactileSpark` for accepted toddler touches across toys. It is the Warm Shelf "the world noticed me" moment.
- Keep `App/Shared` boring and stable. Shared code should be reusable, not just convenient.
- Do not introduce an ECS, dependency injection framework, or third-party package for this stage.
- Every visual/audio asset needs a fallback path so the app still compiles and plays.
- Child-facing scenes stay text-free unless we intentionally create a parent-only surface.

## Refactor Triggers

Extract code when one of these is true:

- A scene has a private helper group that can be named as a real object.
- Two toys need the same behavior.
- A file becomes hard to tune during toddler testing.
- A visual system needs asset fallback plus procedural fallback.

Do not extract just because a file is long while the play feel is still changing quickly.

## Near-Term Pressure Points

These files are carrying the most responsibility right now:

- `ClayBlockScene.swift`: camera follow, ledge/table layout, mystery tray, procedural start pile, physics tuning, height memory.
- `FeedScene.swift`: cafeteria layout, character lifecycle, food lifecycle, thought bubbles, feeding effects.
- `CharacterNode.swift`: procedural character recipes, accessories, expressions, personality ticks.
- `ToyShelfScene.swift`: adaptive shelf layout and living toy previews.

Good future splits, once behavior settles:

- `ClayBlockCamera`
- `ClayBlockSourceTray`
- `ClayBlockHeightMemory`
- `FeedCharacterFactory`
- `FeedTableLayout`
- `ToyShelfPreviewFactory`

## Philosophy

The best Warm Shelf code should feel like the product: calm, direct, tactile, and obvious after you touch it.
