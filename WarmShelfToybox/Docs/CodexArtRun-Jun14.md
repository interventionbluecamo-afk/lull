# Codex Art Run — June 14 (the rug's two floor toys)

The Window's rug now has two things a child can push around — a play ball and a
wooden block. They ship today as procedural clay stand-ins, so **this run is not
blocking**; it lifts them to the authored fidelity of the cat, pot, and watering can
that share the same rug. Two images.

## INSTRUCTIONS FOR CODEX — READ FIRST

1. Process **ONE numbered item at a time**, in order. Do not batch, do not parallelize.
2. For each item: send the quoted prompt **exactly as written** to GPT 5.5 image
   generation. One prompt → one image.
3. Save each result with the **exact filename given**, into
   `~/Desktop/WarmShelfToybox/Assets/Staging/Drops/jun14-codex/` (create the folder once).
4. Where an item says **ATTACH**, include the listed repo file(s) as image input — they
   are the style/material/light anchor, NOT the scale or the subject.
5. Do not edit, crop, recolor, or post-process any result. Save and move on (keying and
   landing happen in a separate pass — see the foot of this doc).
6. If a generation obviously fails (any text/letters/numbers in the image, wrong
   background, a drop shadow or ground plane, cut-off subject), retry once, then move on
   and note it.

*Scale law for both items: these are SMALL FLOOR TOYS — palm-sized, the kind of thing
a 2-year-old grabs in one hand, a touch SMALLER than the attached watering can. One
single object, at rest, gentle three-quarter view, nothing else in frame, and **no
ground shadow** (each toy moves in-app, so the scene draws its own shadow).*

---

## 1. `window-ball.png` — a soft play ball
## ATTACH: `App/Resources/Assets.xcassets/window-watering-can.imageset/window-watering-can.png` (material/light anchor only)

> Soft 3D clay-and-felt children's toy illustration, stop-motion still, matte clay and
> warm wood, hand-felted wool textures, consistent soft key light from the upper left,
> muted warm Montessori palette, cozy and serene, no text anywhere.
> Background: one perfectly flat, uniform solid teal (#3E6877) — no vignette, no
> gradient, no drop shadow, no ground plane. One small round children's PLAY BALL in
> soft matte water-blue clay (#85C5CF), one single pale cream (#FAF0D8) panel band
> curving smoothly around its middle, a soft white highlight glint at the upper left,
> plump and perfectly rounded, resting still. A palm-sized nursery toy. Square format.

## 2. `window-block.png` — a wooden toy block
## ATTACH: `App/Resources/Assets.xcassets/window-watering-can.imageset/window-watering-can.png` AND `App/Resources/Assets.xcassets/window-pot-2.imageset/window-pot-2.png` (material/light + terracotta-colour anchors)

> Soft 3D clay-and-felt children's toy illustration, stop-motion still, matte clay and
> warm wood, hand-felted textures, consistent soft key light from the upper left, muted
> warm Montessori palette, cozy and serene, no text anywhere.
> Background: one perfectly flat, uniform solid teal (#3E6877) — no vignette, no
> gradient, no drop shadow, no ground plane. One single chunky wooden TOY BUILDING
> BLOCK, a rounded soft cube of warm terracotta-painted wood (#D4583A), one flat
> hand-painted sage-green (#6A8B66) band across its front face with a small
> butter-yellow (#E8C045) dot centred on the band, **absolutely NO letters, numbers, or
> symbols anywhere** on it, a soft highlight along the top edge, gentle three-quarter
> view. A palm-sized nursery toy. Square format.

---

## After Codex — the landing pass (not Codex's job)
1. Key each raw teal generation: the **ball** gets a **circle-fit cut** (a vignette or
   stray rim fools the border flood; water-blue on teal is low-contrast — the circle cut
   is safer); the **block** gets the standard border-connected flood key + soft alpha
   ramp + content crop, per `WindowSlice.md`.
2. Land each as `App/Resources/Assets.xcassets/window-ball.imageset/` and
   `…/window-block.imageset/` (Contents.json, scale `3x`), lowercase-kebab filenames.
3. No code change needed: `buildFloorToys()` already prefers `ToyArt.sprite("window-ball")`
   / `("window-block")` and falls back to the procedural clay only when the slot is empty.
   Drop the art in, relaunch, confirm at day and night, mark both slots **FILLED** in
   `WindowSlice.md`.

*That is the whole platter — two images. Everything else on the rug (cat, the cat-rug
composite, all three pot stages, the watering can, the dial) is already landed.*
