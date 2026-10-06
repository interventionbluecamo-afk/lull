# Window — Vertical Slice (Phase 1 of NorthStar)

*The slice that proves the Warm Clay pipeline: `~/Desktop/concepts/window.png` → layered
drop-in art → SpriteKit composition on top of the already-tuned `GlowWindowScene`.
See `Docs/NorthStar.md` for the why.*

## What the prototype already does (kept, do not rebuild)

One value (`dayPhase` 0…1) drives the whole room. The wooden dial turns it with inertia
and ratchet ticks; sky/wall/floor recolor continuously; sun and moon arc with sleepy
faces; stars bloom; a beam rakes the floor; curtains drag open/closed; the lamp taps on;
the sill cat sleeps by night and purrs when petted; zone moments (morning wake, night
bloom) fire only when the dial *settles* — never spammable. All of this is the final
mechanic. The slice replaces its **skin**, not its bones.

## Slice deltas built in code (this pass)

- **Arched window** — the concept's signature silhouette: round-arch top, springline
  bar, fan spokes in the lunette, cross muntins below.
- **Trees outside the glass** — two rounded clusters on a hill band; a day version and a
  night-silhouette version cross-fade with the phase (exactly how the authored art will).
- **Cream curtains** (concept palette) instead of terracotta.
- **Real-clock start** — the room opens at the household's actual time of day; evening
  feels like evening. The child takes over from there.
- **`ToyArt` drop-in rail** — any art slot below that is marked LIVE will automatically
  replace its procedural stand-in the moment a correctly named image lands in
  `Assets.xcassets` (preferred: drag into Xcode, no project regen) or anywhere in
  `App/Resources/Sprites/Window/`.

## Art slots

Rules (per `AssetManifest.md`): lowercase-kebab filenames, transparent background,
contact shadows baked only where noted, consistent key light **upper-left** (the concept's
lamp side). Sizes are pixel budgets at @3x; keep silhouettes chunky — they must read at
arm's length for a 2-year-old.

| Slot name | Size (px) | Status | What it is |
| --- | --- | --- | --- |
| `window-trees-day` | 1500×550 | **FILLED** | Rounded felt tree clusters + hill band, daylight greens. |
| `window-trees-night` | 1500×550 | **FILLED** | Night silhouette blues; cross-fades over the day version. (Regen candidate: composition should match day exactly — current pair differs, visible only briefly at dusk.) |
| `window-curtain-panel` | 700×1900 | **FILLED** | Cream felt panel. Generated with a baked-in rod; rod cropped off in processing — the scene draws its own rod the panels slide along. |
| `window-cat-asleep` | 650×420 | **FILLED** | Felt cat curled on a knit cushion, eyes closed. |
| `window-cat-awake` | 650×420 | **LIVE — art needed** | Same cat, same cushion, same footprint, sitting up soft-awake. Until it lands, the cat sleeps all day (graceful fallback). |
| `window-dial-face` | 800×800 | **FILLED** | The whole wooden wheel — carved ring, felt day/night halves, grip handle — turns as one piece (code skips the procedural ring/pointer when this art is present). |

Processing recipe for flat-background generations (ChatGPT 5.5 doesn't output alpha):
border-connected flood key at the sampled corner color, soft alpha ramp for felt fuzz,
background de-fringe, content crop — scripted, ~1 min for a batch. Circular objects get a
circle-fit cut instead (vignettes/drop shadows fool the flood fill).
| `window-room-day` | 1290×2796 | **FILLED** | Empty room plate. Aligned via `roomPlate()`: the art's baseboard must sit ≈36% up from the plate's bottom (`floorFrac` constant) — keep that framing in any regen. |
| `window-room-night` | 1290×2796 | **FILLED** | Night plate, cross-fades over day. Same 36% baseboard contract. |
| `window-frame` | 1274×1235 | **FILLED** | Authored honey-wood arched frame + usable sill shelf. Code aligns the generated sill surface to the existing shelf/cat/lamp positions; procedural frame remains fallback. |
| `window-seat-cushion` | 800×350 | stashed | Delivered + processed in `Assets/Staging/GlowWindow/Processed/`; lands with the frame/bench era. |
| `window-star-lamp-on` / `-off` | 600×900 | **FILLED** | Star table lamp on the sill's right end. **Lights itself at dusk (p>0.68), rests by day; child taps override until the next crossing.** |
| `window-plant` | 700×900 | LIVE — art needed | Potted plant, left side (a `sleepybox-plant` was delivered; window's own plant still open). |
| `window-sun` / `window-moon` | 500×500 each | **FILLED** | Felt sun and moon; procedural halos kept but softened under the art. |
| `window-cloud` | 700×300 | **FILLED** | Soft felt cloud, drifts in code. |
| `window-star-night-light` | 400×400 | **FILLED** | On the sill left of the cat; its glow breathes in with the night. |
| `window-dial-face-static` + `window-dial-needle` | 800×800 / 300×600 | **FILLED** | The playtest fix, verified day/night: face stays put, the wooden needle sweeps from the sun glyph (morning) to the moon (night). The original whole-wheel art remains as fallback. |
| `window-toybox-closed` / `window-toybox-open` | 1100×1100 | **FILLED** | Back-wall toy chest, base-anchored and front-on. Tap opens/closes; toys spill out and gather back. |
| `window-wall-library` | 900×1100 | **FILLED** | Right-nook wall shelf, revealed by the room lean. Decorative for now; it rides with the wallpaper, not the foreground floor. |
| `window-toy-train` | 600×600 | **LIVE — art needed** | Replacement for the retired ball. A tiny wooden wheeled toy that scoots when tapped and can be carried once the toybox opens. **No baked shadow** (scene grounds it). Procedural stand-in ships today. |
| `window-beanbag-star` | 600×600 | **LIVE — art needed** | Replacement for the retired block. A soft squishy felt star that compresses when tapped and can be carried once the toybox opens. **No baked shadow** (scene grounds it). Procedural stand-in ships today. |
| `window-ball` / `window-block` | 600×600 | retired | June 14: replaced by train + beanbag star. Existing art can remain in the catalog but is no longer used by `GlowWindowScene`; save keys remain only for placement compatibility. |

When the planned slots are wired, mark them LIVE here. **A slot with no file always falls
back to the procedural stand-in — shipping is never blocked on art.**

## Generation prompts

Use `window.png` itself as the image/style reference in every generation. Shared style
prefix for all parts:

> *Soft 3D clay-and-felt children's toy illustration, stop-motion still, matte clay and
> warm wood, hand-felted textures, butter lamplight from upper left, gentle vignette,
> muted warm Montessori palette, cozy and serene, no text, isolated object on a plain
> solid background, full object in frame.*

Then per part, for example:

- **trees-day**: "…a low horizontal band of plump rounded tree clusters in two soft
  greens on a gentle grassy hill, daylight, seen through a window."
- **trees-night**: "…the exact same rounded tree clusters and hill as deep blue-navy
  night silhouettes under starlight, no highlights."
- **curtain-panel**: "…a single hanging cream linen curtain panel with chunky soft
  pleats, gathered at a wooden rod, weighted hem."
- **cat-asleep**: "…a small plump grey-brown cat curled asleep on a round knit cushion,
  closed content eyes, tail wrapped around itself."
- **dial-face**: "…a circular carved wooden dial toy face, left half pale cream with an
  inlaid smiling sun, right half deep navy with an inlaid crescent moon and tiny stars,
  a chunky wooden grip bar across the middle, top-down view."
- **toy-train**: "…one tiny low wooden wheeled train toy, warm honey wood rounded body,
  two dark-cocoa wheels, small sage-green cabin block, one butter-yellow rounded nose on
  the front, no face, no letters/numbers/symbols, flat storybook side/front camera, and
  NO shadow on the ground beneath it."
- **beanbag-star**: "…one small soft beanbag star toy made of plump lavender-pink felt,
  five rounded pillowy points, cream stitched seam, tiny soft center dimple, no face, no
  letters/numbers/symbols, flat storybook front camera, and NO shadow on the ground
  beneath it."

Generators don't output real alpha: generate on a flat single-color background and
remove it (or export layered from a tool that does). Check edges at 300% — halo fringes
read as "sticker" and break the material illusion.

## Audio drop-ins (when ready, per `AudioDropInManifest.md` conventions)

| File | What |
| --- | --- |
| `window-ambience-day.mp3` | Distant soft birds, airy room tone. Loopable, very quiet. |
| `window-ambience-night.mp3` | Crickets and hush. Loopable. Cross-fades with day by phase. |
| `window-dial-tick.mp3` | One soft wooden ratchet tick (engine tones are the fallback). |
| `window-cat-purr.mp3` | Two seconds of close, soft purr. |

## Playtest decisions 2026-06-10 (founder, on device)

- **Dial**: face static, needle sweeps (whole-wheel rotation read wrong). Done, verified.
- **Cat**: waking is a slow cross-fade + stir, never a texture snap. A same-pose regen
  (lying, eyes open) is queued so the fade reads as *waking*, not re-posing.
- **Teddy retired** (code removed): the cat owns the soft-friend role; nothing competes
  with the window. Window enlarged ~13% and lowered — it is the hero.
- **Plant** borrows `feed-plant` art (same prop, same house) until/unless a dedicated
  `window-plant` lands.
- **Nightlight** lives at the lamp's foot on the right sill (anchored to the lamp).
- **Day glass tap → a little bird** flutters across past the finger (the day twin of the
  night comet; ≤1 at a time, 7s cooldown, two soft notes). `window-bird` art slot is
  live with a procedural felt-bird fallback.
- **Forest height self-limits**: oversized tree bands sink below the sill so at most
  ~46% of the glass is treetops (landscape playtest note).

## Verified 2026-06-10 (simulator, iPhone 16)

First five authored assets live in-scene at day / sunset / night — reference shots in
`Assets/Staging/GlowWindow/window-p0.3.png`, `window-p0.55.png`, `window-p0.9.png`.
Pipeline proven end to
end: ChatGPT 5.5 generation → scripted keying → imageset → `ToyArt` slot → lit scene.
Punch list: regen night trees to match day composition (visible at the right edge at
night); authored sun/moon will replace the procedural ones (Batch 1 #8–9); cat-awake
still pending so the cat sleeps all day. Sim note: screenshots need the Simulator window
open — headless `simctl` gives SpriteKit no Metal drawables (blank linen frames).

## Definition of done (slice = "reference quality")

1. Every LIVE slot filled with final art; planned slots wired and filled.
2. The room at dusk looks within arm's reach of `window.png`.
3. Sound: day/night ambience cross-fade in, tones only as accents.
4. 60fps on the oldest supported device; Reduce Motion path verified.
5. The 2.8-year-old turns the dial unprompted, and stays.
6. The dusk frame is screenshot-worthy enough to be the App Store hero shot.
