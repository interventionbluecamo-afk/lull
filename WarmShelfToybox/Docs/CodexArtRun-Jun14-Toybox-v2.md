# Codex Art Run — June 14d (toy box, v2 — POV fix)

The v1 toy box (jun14-room) was generated as a **three-quarter product shot** — you see
its whole right side and a lot of its top. The Lull window room is drawn **flat and
front-on** (the window, the dial, the pot all face the viewer head-on, with only a
slight look-down at the floor). A 3/4 box dropped into that flat room reads as "filmed
from a different camera" — it looks wrong. This regen locks the camera. Two images,
**replacing** the v1 files of the same name.

## INSTRUCTIONS FOR CODEX — READ FIRST

1. Two items, one at a time, exact prompt → one image. Keyed OBJECTS on one perfectly
   flat solid teal (#3E6877) — no gradient, vignette, drop shadow, or ground plane.
2. Save with the exact filenames into
   `~/Desktop/WarmShelfToybox/Assets/Staging/Drops/jun14-toybox-v2/` (create once):
   `window-toybox-closed.png`, then `window-toybox-open.png`.
3. **ATTACH `App/Resources/Assets.xcassets/window-pot-2.imageset/window-pot-2.png`** to
   BOTH — it's a floor object drawn at the EXACT camera we need (front-on, slight
   look-down). Match that camera, not the pot's shape.
4. **Item 2 must be the identical box to item 1** — same width, same front face, same
   camera, same footprint — ONLY the lid differs (down vs up). Generate item 1 first and
   ATTACH it to item 2 as well.
5. No post-process. Retry once on any failure (3/4 angle, visible side wall, text,
   baked-in toys, wrong background).

### THE CAMERA (read this twice — it's the whole point)
Draw the box **straight on from the front**, the way you'd see a low box sitting on the
floor right in front of you: its **front face squarely faces the viewer**, with only a
**gentle downward tilt** — just enough to see a little of the lid on top (closed) or down
into the open mouth (open). This is a **flat, 2D storybook / side-scrolling toy-room**
camera. **Do NOT rotate the box to a three-quarter angle. Do NOT show its right or left
side wall. No dramatic perspective, no product-shot vanishing lines.** Front face flat to
camera, like a dollhouse seen head-on.

---

## 1. `window-toybox-closed.png` — lid down, front-on
## ATTACH: window-pot-2.png (camera anchor)

> Soft 3D clay-and-felt children's toy illustration, stop-motion still, matte clay and
> warm honey wood, hand-felted wool textures, consistent soft key light from the upper
> left, muted warm Montessori palette, cozy and serene, no text anywhere.
> Background: one perfectly flat, uniform solid teal (#3E6877) — no vignette, no
> gradient, no drop shadow, no ground plane. A small CLOSED wooden toy chest seen
> STRAIGHT ON FROM THE FRONT, its front face squarely facing the viewer with only a
> gentle downward tilt (just a sliver of the rounded lid-top visible). Warm honey wood,
> a gently domed closed lid, soft rounded corners, a simple hand-painted sage-green band
> across the front face, and a small wooden clasp centered on the front. Flat dollhouse
> front view — NOT a three-quarter angle, NO side wall visible. Square format.

## 2. `window-toybox-open.png` — same box, lid hinged up
## ATTACH: window-pot-2.png AND the window-toybox-closed.png you just made (match it exactly)

> Soft 3D clay-and-felt children's toy illustration, stop-motion still, matte clay and
> warm honey wood, hand-felted wool textures, consistent soft key light from the upper
> left, muted warm Montessori palette, cozy and serene, no text anywhere.
> Background: one perfectly flat, uniform solid teal (#3E6877) — no vignette, no
> gradient, no drop shadow, no ground plane. The EXACT same wooden toy chest as the
> attached closed reference — same width, same front face with the sage band, same flat
> straight-on front camera, same footprint — now with its domed lid hinged STRAIGHT UP
> AND SLIGHTLY BACK, standing up behind the open mouth (the lid does NOT tip to the
> side). Looking down a little into the box from the front: the front wall faces the
> viewer, and over the front rim you see a soft, dim, shadowed empty interior (NO toys,
> NO objects inside — just gentle shadow). Flat dollhouse front view, NOT three-quarter,
> NO side wall. Square format.

---

## After Codex — the landing pass (code, mostly done)
1. Key each on teal (flood + soft alpha ramp + crop), land over the existing
   `window-toybox-closed` / `window-toybox-open` imagesets (3x).
2. The mechanic is already built and confirmed (tap to open/close, toys lift out on the
   mystery-box glow + sparkles, gather back). The box is base-anchored, so a front-on
   pair with a matching footprint drops straight in. Re-check placement vs the corner
   dial and the toys' release spots, screenshot day + night, done.

*Only the toy box. The library (jun14-room) was already correct — flat against the wall,
straight on — and stays.*
