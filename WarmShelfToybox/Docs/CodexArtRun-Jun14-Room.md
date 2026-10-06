# Codex Art Run — June 14c (the toybox + the nook library)

Decluttering the living room (founder, June 14): the play-toys (ball, block, and any
we add) should live in a **toy box** the child opens and closes, instead of cluttering
the floor. Only the room's residents stay out — the cat, the growing plant + its
watering can, and the lamp. And the right-side peek gets a payoff: a cute **wall
library** discovered when the room leans. Three images.

## INSTRUCTIONS FOR CODEX — READ FIRST

1. Process **ONE numbered item at a time**, in order. One prompt → one image, sent
   **exactly as written** to GPT 5.5 image generation.
2. **These are keyed OBJECTS, not backgrounds.** Each on one perfectly flat solid teal
   (#3E6877) — no gradient, no vignette, no drop shadow, no ground plane — so the
   background can be removed cleanly.
3. Save each with the **exact filename**, into
   `~/Desktop/WarmShelfToybox/Assets/Staging/Drops/jun14-room/` (create the folder once).
4. Where an item says **ATTACH**, include the listed repo file as the material/light
   anchor only (NOT the scale, NOT the subject).
5. **Item 2 must match item 1 exactly** — same box, same size, same three-quarter angle,
   same footprint — only the lid differs. Generate item 1 first and ATTACH it to item 2.
6. Do not post-process. Save and move on. Retry once on an obvious failure (any text/
   letters, wrong background, a baked-in ground shadow, cut-off subject).

*Scale law: the toy box is a chunky floor object about the size of the watering can or a
little larger — a thing a toddler lifts a lid on. The library is a small wall shelf. One
object each, at rest, soft key light from the upper left, nothing else in frame.*

---

## 1. `window-toybox-closed.png` — the toy box, lid down
## ATTACH: `App/Resources/Assets.xcassets/window-watering-can.imageset/window-watering-can.png` (material/light anchor)

> Soft 3D clay-and-felt children's toy illustration, stop-motion still, matte clay and
> warm honey wood, hand-felted wool textures, consistent soft key light from the upper
> left, muted warm Montessori palette, cozy and serene, no text anywhere.
> Background: one perfectly flat, uniform solid teal (#3E6877) — no vignette, no
> gradient, no drop shadow, no ground plane. One small CLOSED wooden toy chest with a
> gently rounded domed lid, warm honey wood with soft rounded corners and a simple
> hand-painted sage-green band across the front, plump and inviting, seen from a gentle
> three-quarter front view at rest. A child's toy box. Square format.

## 2. `window-toybox-open.png` — the same box, lid open
## ATTACH: `window-toybox-closed.png` (the box you just made — MATCH it exactly)

> Soft 3D clay-and-felt children's toy illustration, stop-motion still, matte clay and
> warm honey wood, hand-felted wool textures, consistent soft key light from the upper
> left, muted warm Montessori palette, cozy and serene, no text anywhere.
> Background: one perfectly flat, uniform solid teal (#3E6877) — no vignette, no
> gradient, no drop shadow, no ground plane. The EXACT same wooden toy chest as the
> attached reference — same size, same three-quarter angle, same footprint — now with
> its domed lid OPEN and tipped back on its hinges. Inside: a soft, dim, shadowed
> interior with just one or two vague rounded toy shapes nestled deep in shadow (kept
> simple and indistinct — NOT detailed toys). Warm and inviting, as if waiting to be
> reached into. Square format.

## 3. `window-wall-library.png` — the cozy nook bookshelf
## ATTACH: `App/Resources/Assets.xcassets/window-watering-can.imageset/window-watering-can.png` (material/light anchor)

> Soft 3D clay-and-felt children's toy illustration, stop-motion still, matte clay and
> warm honey wood, hand-felted wool textures, consistent soft key light from the upper
> left, muted warm Montessori palette, cozy and serene, no text anywhere.
> Background: one perfectly flat, uniform solid teal (#3E6877) — no vignette, no
> gradient, no drop shadow, no ground plane. One small cute WALL-MOUNTED bookshelf: two
> warm wooden shelves holding a row of plump, rounded picture books leaning at soft
> angles in muted terracotta, sage, butter, water-blue and lavender — the book spines
> completely BLANK, absolutely NO letters, numbers, or titles anywhere. Tucked among the
> books: one tiny potted round succulent and one small sleepy clay friend (a little
> felt owl with closed eyes). Cozy and storybook, seen straight on as if flat against a
> wall. Tall portrait format.

---

## After Codex — the landing pass (code, not Codex)
1. Key each on teal (border flood + soft alpha ramp + crop), land as
   `window-toybox-closed`, `window-toybox-open`, `window-wall-library` imagesets
   (Contents.json, scale `3x`).
2. Wire in `GlowWindowScene.swift`:
   - Toy box, lower-left of the window: tap to open/close (swap closed↔open art with a
     little lid-lift); the ball/block (and future toys) live IN it — opening lifts them
     out to the floor, closing gathers them home. Keep the big dial in the corner clear
     of it (screenshot to confirm no collision).
   - Wall library: mount it in the RIGHT nook so leaning reveals it (rides the room
     parallax). Decorative first; one pullable book is a fast follow.
   - While here, retune the plant + watering-can `fit:` sizes (founder: awkward) and
     screenshot — regen only if the art's own proportions are off.
3. Each slot keeps a procedural fallback so the build is never blocked on art.

*Three images. The ball, block, cat, plant, can and lamp are all existing live sprites —
nothing interactive is baked into these plates.*
