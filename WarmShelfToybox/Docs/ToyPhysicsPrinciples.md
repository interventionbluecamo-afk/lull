# Toy Physics Principles

Warm Shelf should use toy physics, not arcade physics.

## Decision

Default to authored, forgiving physical behavior. Use raw SpriteKit rigid-body simulation only when it makes the toy easier to understand and more satisfying for a toddler.

## Rules

- Touch down should acknowledge contact immediately.
- Accepted touches should create a tiny tactile spark unless the toy has a more specific one-beat response.
- Hit areas may be larger than the visible object.
- Objects should not fly away, become unreachable, or require precision.
- Motion can cheat in favor of the child.
- Each interaction should produce one clear sensory beat.
- Ambient motion should invite touch without demanding attention.

## Code

- `WarmShelfMotion` stores timing tokens.
- `ToyPhysicsProfile` stores material-feel and forgiveness values.
- `ForgivingHitArea` centralizes child-friendly hit testing.
- `TouchFeedbackAnimator` centralizes touch acknowledgement, tactile sparks, soft settling, pop rings, and empty-tap response.

## Bubbles

Bubbles are kinematic rather than fully simulated. They drift with authored wobble and soft damping, then pop instantly with a forgiving touch radius, one gentle burst, and a tiny ring.

## Clay Blocks

Clay Blocks uses real SpriteKit physics only where it helps the toddler read cause and effect: blocks fall, bump, stack, and settle. Dragging itself remains authored and forgiving so blocks stay under the finger and do not require precision.

The play mat is the physical world cue. Its top edge is aligned to the collision boundary so what the child sees and what the blocks do agree. Open-space taps can quietly offer another block from the tray, capped so the toy stays calm.

Shape variety should create physics variety before adding environmental effects. Cubes stack, planks bridge, tall blocks tip, cylinders roll, and bricks anchor.
