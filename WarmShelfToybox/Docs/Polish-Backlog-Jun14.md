# Polish Backlog — June 14 (founder review)

Captured so nothing's lost. Tags: **[quick]** small code · **[art]** needs imagegen ·
**[design]** a mechanic/look decision · **[rekey]** asset reprocessing.

## June 15 — son's morning play-through (his picks first)
- **DD (DropDots — his FAVORITE):** loves the mechanic. Visuals off: the dots look
  **heavy / out of place**, and when settled in the tray they **don't fit** the wells.
  And the return: **dots used on the board should go back to the tray** so the finite
  count reads (no infinite replenish). [art-fit + code + design]
- **BU (Bubbles):** enjoys it; only flaw — the **bird flies out of a popped bubble in an
  unrealistic, odd way.** Make the flight natural (lift, bank, off-screen). [code]
- **WI (Window — STRIP IT DOWN):** over-scoped a small scene. **Remove the cat, all the
  toys, the toy box, the floor lamp, plant, watering can, free placement.** Reduce to a
  calm **day↔night simulator**: smaller, authored, **tap + discover** (bird tap by day,
  shooting stars by night, sun/moon, clouds, curtains, the day/night control). Open
  question: keep the sleeping cat as a *static tap-to-pet* nap, or remove entirely? [big removal]
- **SB (SleepyDropBox — his FAVORITE):** functionally off — the authored box art has its
  **own drawer front, and the code pulls a second drawer front → two fronts.** Rethink
  the mixed imagegen + procedural so there's ONE coherent drawer. [art + code]

## In-flight (this session)
- **W1 — Window beam.** Was a hard-edged trapezoid (harsh line). Softened: wrapped in a
  big Gaussian blur so the edges feather and the far end dissipates like real light.
  *Done in code; on-device verify pending (sim had shut down).* **[quick ✓]**
- **W2 — Sill lamp + star → floor lamp.** Remove the sill star-lamp and the night-light
  star; the outdoors is the main light. Add a tall **floor lamp on the LEFT** (the empty
  peek side) — beautiful and bright when on. Front-on perspective. **[art + code]** —
  *prompt below.*
- **W3 — Toybox contents.** The train + beanbag-star are lame and don't fit "coming out
  of a box." Replace with the cat's things: a felt **fish** and a felt **mouse**, each
  draggable to the cat → cat answers with love hearts (reuse the night-pet heart burst).
  **[art + code]** — *prompts below.*
- **W4 — Toybox POV.** v1 was a 3/4 product shot; front-on regen queued
  (`CodexArtRun-Jun14-Toybox-v2`). **[art pending]**

## New review (batch 2)
- **S1 — Shelf.** The shelf is on a wall, yet the rug appears to touch it — reads wrong.
  Lower the rug so it clearly sits on the floor below the shelves. **[quick]**
- **F1 — Feed.** Food sits awkwardly on the counter and the counter's awkward to grab
  from; worse, the characters' **bottoms are visible** (should be hidden below the
  counter). Rework the lower third — mix procedural + the new open backdrop. **[design + art]**
- **D1 — DropDots.** Tokens land looking wrong in the tray (well-floor calibration) and
  the imagegen board + procedural tokens don't blend. Seat tokens on the channel floor;
  make the art/procedural seam invisible. **[code + art-fit]**
- **B1 — Bubbles.** Kill the falling leaf/seed cargo — it's ugly. Instead, on a special
  pop, a little **bird** flutters free and flies off naturally to one side. **[code + art]**
  — *prompt below.* (Cargo removed now; bird lands with art.)
- **M1 — Mix-Up.** The King repeats (appears twice after the bunny) — a sequencing bug.
  Several characters show **teal/asset-edge fringing** — re-key. **[quick + rekey]**
- **MD1 — Meadow.** Son still doesn't grasp "close the loop." For now drop the
  loop-to-claim; make spring a **beautiful magical radius that follows the ladybug**,
  painting the world as he leads her. Simpler, instantly legible. **[design + code]**
- **T1 — Transitions/loading.** Prettier scene transitions and loads that tell a small
  story (not a hard cut / blank wait). **[design + code]**

## Recommended order
1. Quick wins: **S1** rug, **B1** cargo removal (done), **M1** King dedup, **W1** verify.
2. **Re-key** the fringing assets (M1 + any others; bake into the keying script).
3. **MD1 Meadow radius** — the biggest legibility win for your son.
4. Run the **art prompts** (below) through Codex → land + wire: floor lamp, cat
   fish/mouse, bubble bird, toybox v2.
5. **F1 Feed** + **D1 DropDots** — the procedural+imagegen blend reworks.
6. **T1 transitions.**

---

## Ready prompts (house style, flat teal #3E6877, keyed objects)

Shared prefix: *Soft 3D clay-and-felt children's toy illustration, stop-motion still,
matte clay and warm wood, hand-felted textures, soft key light from upper left, muted
warm Montessori palette, cozy and serene, no text. Background one perfectly flat solid
teal (#3E6877) — no gradient, vignette, shadow, or ground plane.*

**`window-floor-lamp-off`** (ATTACH window-pot-2 for the front-on camera):
> …a tall slender wooden FLOOR LAMP standing on the floor, a slim turned-honey-wood pole
> on a small round weighted base, topped by a soft cream linen drum shade, switched OFF
> (no glow). Seen STRAIGHT ON from the front, flat storybook camera — NOT three-quarter,
> no side shown. Tall portrait.

**`window-floor-lamp-on`** (ATTACH the -off you just made — match it exactly):
> …the EXACT same floor lamp, same pole, base, shade, same front-on camera — now switched
> ON: the cream shade glowing warm butter-gold from within, lit and inviting (the wide
> floor pool of light is added in code, so just light the shade itself). Tall portrait.

**`window-cat-fish`** (a toy from the box, for the cat):
> …one small plump toy FISH, soft felt-and-clay, gentle butter-yellow body with a petal-
> pink tail and fin, a tiny calm closed-eye smile, no text, flat storybook side view, and
> NO shadow on the ground beneath it. Square.

**`window-cat-mouse`** (a toy from the box, for the cat):
> …one small round toy MOUSE, soft grey-sand felt, two little round ears, a tiny pink
> nose, a thin curled tail, calm and cute, no text, flat storybook side view, and NO
> shadow on the ground beneath it. Square.

**`bubble-bird`** (flies out of a popped bubble):
> …one tiny plump CLAY BIRD, soft round body in gentle water-blue with a butter-yellow
> chest and a small wing lifted as if just taking off, a tiny calm beak, no text, seen
> from the side mid-flutter, and NO shadow. Square.

*Feed (F1) and DropDots (D1) need a design pass before their prompts — they're about
blending procedural geometry with art, not a single new object.*
