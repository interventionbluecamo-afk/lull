# Codex Art Run — June 14e (floor lamp · cat toys · bubble bird)

The art the window room + bubbles need next (founder review, June 14). Five keyed
objects. (The toy-box front-on regen is a separate run already written —
`CodexArtRun-Jun14-Toybox-v2.md` — run that too.)

## INSTRUCTIONS FOR CODEX — READ FIRST
1. One item at a time, in order. Send the quoted prompt **exactly as written** → one image.
2. **Keyed OBJECTS** — each on one perfectly flat solid teal (#3E6877): no gradient,
   vignette, drop shadow, or ground plane.
3. Save with the **exact filename** into
   `~/Desktop/WarmShelfToybox/Assets/Staging/Drops/jun14-roomtoys/` (create once).
4. **ATTACH** the listed repo file as the camera/material anchor (NOT the subject).
5. Items 1 & 2 are the SAME lamp, on vs off — generate 1 first and ATTACH it to 2 so they
   match exactly. Same for nothing else here.
6. No post-process. Retry once on any failure (text, 3/4 angle where front-on is asked,
   baked-in ground shadow, cut-off subject, wrong background).

*Camera law (the toy-box lesson): the room is drawn FLAT and FRONT-ON. The floor lamp
must face the viewer head-on with only a slight look-down — NOT a three-quarter product
angle, no side wall. The little toys are flat storybook side views.*

---

## 1. `window-floor-lamp-off` — tall floor lamp, off
## ATTACH: `App/Resources/Assets.xcassets/window-pot-2.imageset/window-pot-2.png` (front-on camera anchor)
> Soft 3D clay-and-felt children's toy illustration, stop-motion still, matte clay and
> warm honey wood, hand-felted wool textures, soft key light from the upper left, muted
> warm Montessori palette, cozy and serene, no text. Background: one perfectly flat solid
> teal (#3E6877) — no gradient, vignette, shadow, or ground plane. One tall slender
> wooden FLOOR LAMP standing upright: a slim turned honey-wood pole on a small round
> weighted wooden base, topped by a soft rounded cream-linen lampshade, switched OFF (the
> shade is a calm unlit cream, no glow). Seen STRAIGHT ON FROM THE FRONT, flat storybook
> camera, facing the viewer — NOT a three-quarter angle, no side shown. Tall portrait.

## 2. `window-floor-lamp-on` — the same lamp, glowing
## ATTACH: the `window-floor-lamp-off` you just made (match it exactly)
> Soft 3D clay-and-felt children's toy illustration, stop-motion still, matte clay and
> warm honey wood, hand-felted wool textures, soft key light from the upper left, muted
> warm Montessori palette, cozy and serene, no text. Background: one perfectly flat solid
> teal (#3E6877) — no gradient, vignette, shadow, or ground plane. The EXACT same floor
> lamp as the attached reference — same pole, same base, same shade, same front-on camera
> — now switched ON: the cream-linen shade glowing warm and bright with butter-gold light
> from within, the shade clearly lit and inviting (do NOT draw a big pool of floor light —
> that glow is added in code; just light the shade itself). Tall portrait.

## 3. `window-cat-fish` — a toy fish, for the cat
## ATTACH: `App/Resources/Assets.xcassets/window-cat-asleep.imageset/window-cat-asleep.png` (felt-creature scale/style)
> Soft 3D clay-and-felt children's toy illustration, stop-motion still, matte clay, hand-
> felted wool textures, soft key light from the upper left, muted warm Montessori palette,
> cozy and serene, no text. Background: one perfectly flat solid teal (#3E6877) — no
> gradient, vignette, shadow, or ground plane. One small plump toy FISH, soft felt-and-
> clay, a butter-yellow body with a petal-pink tail and one little fin, a tiny calm
> closed-eye smile, a child's toy for a cat. Flat storybook side view, full object in
> frame, and NO shadow on the ground beneath it. Square.

## 4. `window-cat-mouse` — a toy mouse, for the cat
## ATTACH: `App/Resources/Assets.xcassets/window-cat-asleep.imageset/window-cat-asleep.png` (felt-creature scale/style)
> Soft 3D clay-and-felt children's toy illustration, stop-motion still, matte clay, hand-
> felted wool textures, soft key light from the upper left, muted warm Montessori palette,
> cozy and serene, no text. Background: one perfectly flat solid teal (#3E6877) — no
> gradient, vignette, shadow, or ground plane. One small round toy MOUSE, soft grey-sand
> felt, two little round ears, a tiny petal-pink nose, a thin curled tail, calm and cute,
> a child's toy for a cat. Flat storybook side view, full object in frame, and NO shadow
> on the ground beneath it. Square.

## 5. `bubble-bird` — flutters free when a special bubble pops
## ATTACH: `App/Resources/Assets.xcassets/window-cat-asleep.imageset/window-cat-asleep.png` (felt-creature style)
> Soft 3D clay-and-felt children's toy illustration, stop-motion still, matte clay, hand-
> felted wool textures, soft key light from the upper left, muted warm Montessori palette,
> cozy and serene, no text. Background: one perfectly flat solid teal (#3E6877) — no
> gradient, vignette, shadow, or ground plane. One tiny plump CLAY BIRD, a soft round
> body in gentle water-blue with a butter-yellow chest, one little wing lifted as if just
> taking off, a tiny calm beak, a single dot eye. Seen from the SIDE, mid-flutter, facing
> right, full object in frame, and NO shadow beneath it. Square.

---

## After Codex — landing (code, mine)
Key on teal (flood + teal-distance halo cut + crop — the stronger key from the script),
land as 3x imagesets. Each slot already has (or will get) a procedural fallback, so
nothing's blocked. Floor lamp wires to the LEFT with its glow + dusk auto-on; fish/mouse
become the toy-box contents (drag to cat → love hearts); bubble-bird replaces the cargo.
