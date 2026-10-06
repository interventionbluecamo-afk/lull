# Codex Art Run - June 14 Window Frame

## Verdict

Yes: the Window scene deserves an authored frame/sill asset. The procedural frame works structurally, but the flat brown bars read like UI geometry. The replacement should make the scene feel like the child is inside the nursery looking out through a real wooden window, with a usable sill shelf in the foreground for the cat, lamp, nightlight, guests, and plant.

## Best Candidate

Use candidate D:

- Raw: `Assets/Staging/Drops/jun14-window-frame/window-frame-candidate-d-wide-sill.png`
- Keyed preview: `Assets/Staging/Drops/jun14-window-frame/window-frame-candidate-d-wide-sill-keyed.png`

Rejected direction:

- Candidates A/B: better wood but still decorative-frame/product feeling.
- Candidate C: good deep sill, but too narrow and too standalone.

## Prompt Used For Candidate D

Use case: stylized-concept
Asset type: keyed iOS SpriteKit game asset for Glow Window's authored interior window frame overlay
Input image: use the attached app screenshot as the exact composition reference for proportions and camera. Match the current wide arched nursery window, not a narrow freestanding toy window.

Primary request: Generate ONE WIDE INTERIOR ARCHED WINDOW FRAME WITH A REAL SILL SHELF, viewed from inside the nursery looking out. It should feel mounted into the room wall, like the foreground architecture of the room, not like a separate product on a background. Keep the same broad proportions as the app screenshot: wide arched window, straight lower sides, rounded top, chunky but crafted frame, one central vertical muntin, two horizontal rails, and a small fan of short spokes in the arched top. Include a broad horizontal bottom sill shelf that extends slightly beyond the window sides, with a visible top plane and rounded front lip so a cat, lamp, nightlight, or small visitor toy could plausibly rest on it.

Scene/backdrop: one flat solid teal (#3E6877) fills all non-wood pixels and all open panes for keying. No sky, no trees, no glass, no room wall, no curtains. The teal is only a removable key color.

Subject: honey-wood interior window frame and sill only. The frame must read as attached to the interior room, not as a standalone miniature. The side jambs should be relatively flat/front-facing, with only subtle bevel depth. The sill shelf is the hero: thick, sturdy, rounded, horizontal, connected to the frame, with a gentle top surface visible from the inside-looking-out viewpoint.

Style/medium: soft 3D clay-and-felt children's toy illustration, stop-motion still, matte carved warm honey wood, hand-sanded bevels, subtle wood grain, warm Montessori palette, premium handmade nursery object.

Composition/framing: wide portrait/square-friendly asset, centered, full window fully visible with generous padding. Match the screenshot's wide window proportions. Straight-on dollhouse/storybook camera with only a slight downward look at the sill top. Do not rotate the frame. Do not show side walls. Do not make it a narrow church-window shape.

Lighting/mood: soft key light from upper left on the wood only, with cream bevel highlights and warm cocoa inner grooves.

Materials/textures: rounded honey wood, tactile matte finish, subtle cocoa grain, soft clay-like depth at joins, no hard vector edges.

Text: none.

Constraints: no curtains, no cat, no lamp, no dial, no toys, no plant, no sky, no stars, no moon, no trees, no glass, no reflections, no wall, no drop shadow, no contact shadow, no ground plane. No freestanding product-shot pedestal. No cut-off edges. Open panes must remain clear teal. Must feel like we are inside looking out through a room window, with a usable sill shelf in the foreground.

## Landing Notes

- Treat `window-frame-candidate-d-wide-sill-keyed.png` as the first landing candidate.
- Scale to the existing `windowRect` plus the sill overhang, not to the old procedural stroke bounds.
- The sill should become the visual support plane for the cat/lamp/nightlight/guest objects.
- Keep the existing sky/trees/glass layers behind it and curtains in front/at the sides.
- Verify day and night, especially whether the lamp/nightlight sits on the sill instead of floating in front of it.
