# Little Wash material interaction pass

Implemented November 4, 2026 after the founder resumed work.

## Art contract

Built-in imagegen edited the original portrait and landscape rooms into clean plates. Camera, upper-left light, wall/floor boundary, caps, bases and drain remain registered to their old compositions. Only brush fibres were removed; a narrow spindle fills the exposed gap. Exact prompts are in `Prompts.json`; unmodified files, dimensions and hashes are in `Assets.json`.

New production slots: `wash-bay-clean`, `wash-bay-portrait-clean`, `wash-brush-tuft`. The original two bay plates remain fallbacks. The scene only enables separate fibres if both clean room and tuft art exist; it cannot accidentally overlay new fibres on an old baked-in brush.

Tufts use a front-facing orthographic view and neutral upper-left lighting, with transparent margins and a top attachment at normalized y=0.915 (SpriteKit). Seven overlapping tufts form each column. Fractional room anchors are measured in source coordinates, y down: cap bottom 0.087/0.088, fibre bottom 0.456/0.650 for portrait/landscape, column centres x=0.026/0.974. The same `WashBayFit.frame` used by the room maps those anchors into the scene. No room image is stretched or warped during an interaction.

## Behavior

- Touch bends nearby tufts, with a fixed upper seam and a bounded, damped return. No idle spinning or automatic brush noises.
- Home, tools and vehicle have priority; separate optional brush fingers keep ownership until release. Picking up a tool or the normal vehicle departure does not cancel another finger's brush gesture.
- A hose wets the contacted tuft and makes a few drops fall. Water close enough to the drain produces bounded runoff beads and two small rings. Distant water does not magically trigger the drain.
- Reduce Motion removes fibre flex and travelling droplets; a restrained sheen supplies drain feedback. Brushes expose VoiceOver actions.
- Rotation, rest and teardown reset gestures/deformation/transient water. Source nodes and pools are bounded: fourteen tufts, sixty existing water drops, at most five temporary runoff nodes.

## Verification

Swift parse passed. Existing Wash model and asset verifier passed 48,700 model checks and 159 asset/provenance checks. A scoped ownership review identified and corrected brush cancellation during tool selection. Combined build and actual scene framing are recorded in the current handoff when complete. Physical touch feel remains the founder's check.
