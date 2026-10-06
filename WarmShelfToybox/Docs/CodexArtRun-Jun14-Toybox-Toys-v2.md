# Codex Art Run — June 14e (toybox toys, v2)

The ball and block are retired from the Window toybox. They read like generic floor
tokens, not like favorite things discovered inside a box. Replace them with two clear,
imagegen-friendly toys with different verbs: a tiny wooden wheeled train that scoots, and
a soft beanbag star that squishes.

## INSTRUCTIONS FOR CODEX — READ FIRST

1. Process **ONE numbered item at a time**, in order. Do not batch, do not parallelize.
2. For each item: send the quoted prompt **exactly as written** to GPT 5.5 image
   generation. One prompt → one image.
3. Save each result with the **exact filename given**, into
   `~/Desktop/WarmShelfToybox/Assets/Staging/Drops/jun14-toybox-toys-v2/` (create once).
4. Where an item says **ATTACH**, include the listed repo file(s) as image input. They are
   material/light/camera anchors only.
5. These are keyed OBJECTS on one perfectly flat solid teal (#3E6877) — no gradient,
   vignette, drop shadow, or ground plane.
6. Do not edit, crop, recolor, or post-process any result. Save and move on.
7. Retry once on any failure: text/letters/numbers, wrong background, baked-in shadow,
   cut-off subject, face/character features, or camera that does not match the room.

Scale law: both are SMALL FLOOR TOYS, palm-sized, smaller than the toybox and watering
can. One single object, at rest, flat storybook side/front camera with only a gentle
look-down, nothing else in frame. No ground shadow; the scene draws contact shadows.

## 1. `window-toy-train.png` — the tiny wheeled wooden toy
## ATTACH: `App/Resources/Assets.xcassets/window-toybox-closed.imageset/window-toybox-closed.png` AND `App/Resources/Assets.xcassets/window-watering-can.imageset/window-watering-can.png`

> Soft 3D clay-and-felt children's toy illustration, stop-motion still, matte clay and
> warm honey wood, hand-felted wool textures, consistent soft key light from the upper
> left, muted warm Montessori palette, cozy and serene, no text anywhere. Background: one
> perfectly flat, uniform solid teal (#3E6877) — no vignette, no gradient, no drop shadow,
> no ground plane. One tiny low WOODEN WHEELED TRAIN toy, palm-sized, seen straight from
> the side with only a gentle look-down like the attached room objects: warm honey wood
> rounded body, two simple dark-cocoa wooden wheels, a small sage-green cabin block, and
> one butter-yellow rounded nose on the front. Smooth carved folk-toy shapes, no face, no
> letters, no numbers, no symbols, no smoke stack, no cargo, no baked shadow. Square
> format.

## 2. `window-beanbag-star.png` — the soft squishy toy
## ATTACH: `App/Resources/Assets.xcassets/window-toybox-open.imageset/window-toybox-open.png` AND `App/Resources/Assets.xcassets/window-pot-2.imageset/window-pot-2.png`

> Soft 3D clay-and-felt children's toy illustration, stop-motion still, matte clay and
> warm wood, hand-felted wool textures, consistent soft key light from the upper left,
> muted warm Montessori palette, cozy and serene, no text anywhere. Background: one
> perfectly flat, uniform solid teal (#3E6877) — no vignette, no gradient, no drop shadow,
> no ground plane. One small soft BEANBAG STAR toy made of plump lavender-pink felt, five
> rounded pillowy points, visible hand-stitched cream seam around the edge, a tiny soft
> dimple at the center, slightly flattened on the bottom as if squishy and loved. No face,
> no letters, no numbers, no symbols, no baked shadow. Seen straight-on from the front
> with only a gentle look-down, matching the flat storybook room camera. Square format.

## After Codex — Landing Pass

1. Key each on teal with the standard border-connected flood, soft alpha ramp, despill,
   and content crop.
2. Land as `App/Resources/Assets.xcassets/window-toy-train.imageset/` and
   `App/Resources/Assets.xcassets/window-beanbag-star.imageset/` (`Contents.json`,
   scale `3x`, lowercase-kebab filenames).
3. No mechanic change needed: `GlowWindowScene.buildFloorToys()` already prefers these
   slots and falls back to procedural stand-ins when empty. The train scoots; the star
   squishes.
