# Art prompts — design pass 2 (October 7, 2026)

Paste-ready prompts for ChatGPT image generation. Each prompt is complete; nothing to
assemble. Keyed objects use the house teal background so they can be cut out; full-bleed
plates say so. After generating, put the PNGs in `WarmShelfToybox/ArtDrops/2026-10-07/`
(this folder IS tracked by Git, unlike `Assets/Staging/Drops/`) and push. Claude keys,
despills (`Tools/Art/despill.py`), sizes and wires them.

House prefix used below:

> Soft 3D clay-and-felt children's toy illustration, stop-motion still, matte clay and warm
> wood, hand-felted wool textures, consistent soft key light from the upper left, muted
> warm Montessori palette, cozy and serene, no text anywhere.

---

## 1. App icon — "sleepy stone at dusk" (priority)

Why: the current icon loses the character in a beige border at small sizes and washes out on
light wallpapers. A dusk sky gives the strongest contrast at every size and says what Lull is
for (the calm wind-down). The moon moves off the belly (it read as a letter C at 29pt) into
the sky. See `Assets/DesignPass-02/icon-directions.png` and `icon-moon-in-sky.png`.

Make it as **layers** so Xcode's Icon Composer can build the light, dark, clear and tinted
appearances (an Apple Design Award jury will look for this).

**1a. icon-bg** (square, 1024×1024, FULL CANVAS, no teal)
> Soft 3D clay-and-felt children's toy illustration, stop-motion still, hand-felted wool
> textures, cozy and serene, no text anywhere. A calm dusk sky made of felt filling the whole
> square edge to edge: deep indigo at the top fading to soft plum-lavender near the bottom, a
> few tiny cream felt stars scattered in the upper left, a small cream felt crescent moon in
> the upper right with a faint warm glow around it, and one low, wide, rounded felt hill in
> muted slate-blue along the bottom edge. Nothing in the centre — the centre is left empty
> for a character. Square format.

**1b. icon-stone** (square, 1024×1024, on teal)
> Soft 3D clay-and-felt children's toy illustration, stop-motion still, matte clay and warm
> wood, consistent soft key light from the upper left, muted warm Montessori palette, cozy and
> serene, no text anywhere. Background: one perfectly flat, uniform solid teal (#3E6877) — no
> vignette, no gradient, no drop shadow, no ground plane. The signature sleepy stacking stone,
> seen straight on: a rounded terracotta clay stone, egg-shaped and a little wider at the
> bottom, with gently closed sleepy eyes (two soft dark arcs), a tiny calm smile and two rosy
> round cheeks, and a small butter-yellow clay pebble balanced on top as a capstone. The belly
> is plain — no moon, no markings. Matte clay with a faint thumbprint texture. Centred,
> filling about 70% of the frame. Square format.

**1c. icon-stone-awake** (optional, for the store/brand sheet — ATTACH 1b and match exactly)
> The exact same stone, same camera, same light — now its eyes are softly open and its smile
> is a little wider. Same flat teal background.

---

## 2. Meadow — one camera (priority)

Why: Meadow is seen from directly above, but the rock, mushroom, pebbles and dandelion were
drawn from the side, so they look like stickers on the felt. The code no longer spins them
(it made them look like they were tipping over); once these land, flip `isTopDown` to `true`
for each kind in `MeadowScene.swift`. The stump and pond are already correct.

Generate each "asleep" first, then the "awake" by ATTACHING the asleep image.

**2a. meadow-rock** (square, on teal)
> Soft 3D clay-and-felt children's toy illustration, stop-motion still, matte clay and warm
> wood, hand-felted wool textures, consistent soft key light from the upper left, muted warm
> Montessori palette, cozy and serene, no text anywhere. Background: one perfectly flat,
> uniform solid teal (#3E6877) — no vignette, no gradient, no drop shadow, no ground plane.
> A round grey felt stone seen DIRECTLY FROM ABOVE, straight-down bird's-eye view, with soft
> patches of green felt moss and two tiny pale lichen flowers on its top, and a sleeping face
> on the top surface: two gently closed eyes as soft dark arcs and a small calm mouth. Square.

**2b. meadow-rock-awake** — ATTACH 2a:
> The exact same stone from directly above, same moss and flowers, same camera and light —
> now awake: round dark eyes open with a tiny highlight, rosy cheeks, a small happy smile.
> Same flat teal background. Square.

**2c. meadow-mushroom** (square, on teal)
> [house prefix + teal background sentence as in 2a] A plump red felt mushroom cap seen
> DIRECTLY FROM ABOVE, straight-down view: a round red dome with cream felt spots, the stem
> hidden underneath, and a sleeping face on top of the cap — two gently closed eyes and a
> small calm mouth. Square.

**2d. meadow-mushroom-awake** — ATTACH 2c: same cap from above, now eyes open, rosy cheeks,
happy smile. Same flat teal background. Square.

**2e. meadow-pebbles** (square, on teal)
> [house prefix + teal background sentence] A little family of three round felt pebbles
> seen DIRECTLY FROM ABOVE — one large oat-coloured, one medium sand-coloured, one small grey —
> nestled together, each with a sleeping face on its top surface. Square.

**2f. meadow-pebbles-awake** — ATTACH 2e: the same three pebbles from above, all awake and
smiling, rosy cheeks. Same flat teal background. Square.

**2g. meadow-dandelion** (square, on teal)
> [house prefix + teal background sentence] A dandelion seed-puff seen DIRECTLY FROM ABOVE:
> a round fluffy white wool sphere of tiny soft seeds, the stem hidden below it, ready for one
> breath of wind. Square.

---

## 3. Feed — sharper friends (worth doing)

Why: the three friends are cut from one 1254px five-up sheet and drawn about 3× larger than
their pixels, so they look soft beside the crisp food. One figure per image at full size
fixes it. The new counter hides everything below the chest, so waist-up is enough.

**3a. feed-cast-grandmother-1** (portrait 3:4, at least 1024px wide, on teal)
> Soft 3D clay-and-felt children's toy illustration, stop-motion still, matte clay and warm
> wood, hand-felted wool textures, consistent soft key light from the upper left, muted warm
> Montessori palette, cozy and serene, no text anywhere. Background: one perfectly flat,
> uniform solid teal (#3E6877) — no vignette, no gradient, no drop shadow, no ground plane.
> One felt grandmother doll, seen straight on, waist up: a round cream felt face with round
> gold wire glasses, a soft grey felt bun on top, a mustard knitted shawl over her shoulders,
> calm neutral expression with eyes open and a tiny closed smile. Centred, the head filling
> the upper half. Portrait 3:4.

Then, each ATTACHING 3a and matching it exactly (same pose, framing, light, background):
- **-2 happy**: eyes open and smiling, a soft smile.
- **-3 laughing**: eyes squeezed into happy arcs, mouth open in a laugh.
- **-4 sleepy**: eyes gently closed, small "o" yawn.
- **-5 surprised**: eyes wide, small round "oh" mouth.
- **-6 chewing** (new): cheeks puffed round, mouth closed — mid-chew.

Repeat the same six for **sprout** (a round terracotta clay head with a tiny stem sprout on
top, a green knitted sweater) and **knithat** (a deep brown clay face with a lavender striped
knit hat with a pompom, a blue knitted sweater).

---

## 4. Not needed any more

- Drop Dots coins: done in code — `dropdots-token-blank` is the plain berry puck re-toned to
  cream and tinted per ring colour. A regeneration is optional.
- Drop Dots board knob: painted out of `dropdots-board.png`; the walnut pull on the rail is
  the one handle.
- Meadow ground and moss: now tiled at their native size; no regeneration needed.
