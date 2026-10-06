# Lull

First playable vertical slice for Lull: a calm, tactile toddler toy platform.

This build contains:

- A living SpriteKit toy shelf.
- One large Bubbles toy card.
- A playable Bubbles toy with soft drifting bubbles, instant pops, gentle particles, and subtle empty-tap feedback.
- A small Clay Blocks prototype for drag, stack, bump, and settle testing.
- A first Feed the People prototype for caring, dragging food, generous snapping, and expression feedback.
- A first Soft Drop prototype for one-touch dropping, switchable ledges, and immediate cause/effect play.
- Gentle Nest and Puddle Play prototypes for recognizable real-world toddler play.

## Requirements

- macOS with Xcode installed.
- XcodeGen is recommended and was used for this scaffold.

## Run

From this folder:

```sh
cd WarmShelfToybox
xcodegen generate
open Lull.xcodeproj
```

In Xcode, select an iPad or iPhone simulator/device and run the `Lull` scheme.

The app supports portrait and landscape. Toy scenes resize with SpriteKit, the shelf recomposes for the current orientation, and active toy objects are preserved through rotation where it matters for play continuity.

## Landing Page

A first static landing page lives at `LandingPageDeploy/index.html`, with its web images and press downloads beside it in `LandingPageDeploy/img` and `LandingPageDeploy/press`. Open the HTML file directly in a browser to review the early public-facing story for Lull, the current brand candidate for the Warm Shelf project.

## Product Rules In This Slice

- No text, scores, levels, instructions, or menu overlays inside the Bubbles toy.
- Touch feedback is immediate.
- Motion stays soft, slow, warm, and low-stimulation.
- Empty taps still respond with a tiny ripple/mote.
- Future toys should be registered in `ToyRegistry`.
- Future toy interactions should use the shared Warm Shelf toy-physics helpers instead of raw, unforgiving physics by default.
- Toy scenes use a small text-free shelf pull to return home without adding a menu overlay.
- A parent-only information sheet is available with a two-finger long press.

## Current Toys

- `Bubbles`: tap-to-pop toy for visibility, pop, sound, and repetition testing.
- `Clay Blocks`: tiny prototype for toddler drag, drop, stacking, and collision feel.
- `Feed the People`: early prototype for relational play with three characters and draggable food.
- `Soft Drop`: early prototype for tap-to-drop pieces and gently switchable ledges.
- `Gentle Nest`: early prototype for placing eggs, birds, twigs, and leaves in a cozy nest.
- `Puddle Play`: early prototype for rainy puddle ripples, splashes, ducks, frogs, and fish.

## Warm Shelf Toy Physics

The product bias is authored toy behavior first, raw simulation second. Use `WarmShelfMotion`, `ToyPhysicsProfile`, `ForgivingHitArea`, and `TouchFeedbackAnimator` to keep touch targets generous, motion soft, and feedback immediate.

## Code Organization

Lull is intentionally lightweight. `App/Shared` holds only reusable platform pieces, each toy owns its own scene and nodes under `App/Toys`, and future toys should become visible by adding one descriptor in `ToyRegistry`.

See `Docs/CodeOrganization.md` before extracting new helpers. The short version: keep the toddler play loop easy to read, avoid building an engine, and only split code when a helper has a clear owner or is reused by more than one toy.

## Asset Library

Shipping app assets live under `App/Resources` and are tracked in `Docs/AssetManifest.md`. Non-shipping source art and generated staging images live under `Assets`. All real audio, sprite, and texture files should have procedural or silent fallbacks so the app keeps building while the art library grows.

## Audio

Bubble pops use `App/Resources/Audio/bubble-pop.mp3`, with gentle haptics as fallback.

The app is ready for a real sensory-audio pass: size-varied bubble pops, block pickup/release/settle sounds, feeding reactions, empty taps, and shelf transitions.
