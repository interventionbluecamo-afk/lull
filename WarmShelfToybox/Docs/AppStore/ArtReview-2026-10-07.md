# Lull art review — October 7, 2026

A full review of every image in the asset catalog (≈ 250 imagesets), read as the App Store
screenshots and the first ten seconds of play will be read. This review was made from the art
files themselves and contact sheets, not from the running app. Where a finding depends on how a
scene composes the art, it says so.

## Verdict

Lull already has a real visual identity: **needle-felted wool toys and pale maple, in warm
linen light**. The Feed cast, the new Mix-Up friends, the Meadow landmarks, the Window objects,
the v2 shelf toys, the Drop Dots coins and the dusk icon all belong to one world. The gap is a
short list of pieces made of *other* materials — glossy clay, plastic and photographic food —
that sit right next to the felt in the most visible moments. Fix those seven pieces and every
toy can be screenshot without an off-model object in frame.

## The house look (use this to judge every new image)

- **Material ladder.** Anything soft or alive (characters, food, plants, shapes, buttons) is
  needle-felted wool with visible fibres. Anything structural (shelves, boards, frames, stands)
  is pale maple with a soft satin finish. Never glossy clay, plastic, varnish or photographic
  textures.
- **Light.** One soft key light from the upper left, warm fill, and a soft warm cocoa contact
  shadow (never teal, never black).
- **Palette.** Linen #F8F3E9, cream #EEE3D1, clay ink #49352A, cocoa #654B3A, terracotta
  #C96F50, sage #829B82, butter #D9B452, water blue #83AAB9, lavender #A696B3, petal #DD998B.
  Saturated primaries (fire-engine red, lemon yellow, lime green) read as "plastic toy aisle"
  and break the calm.
- **Faces.** Two dark bead eyes or closed sleepy arcs, a small mouth, round rosy cheeks. No
  eyebrows, no teeth, no glossy eye highlights larger than a pinpoint.
- **Shape language.** Rounded, slightly squat, hand-made irregularity; nothing perfectly
  geometric unless it is maple.

## What is excellent (keep as the reference set)

Feed cast (all 18 frames), Mix-Up friends A and B, Meadow rock / mushroom / pebbles / stump /
pond / ladybug / butterfly / snail / rosette, Window objects (cat, bird, moon, sun, lamps, pots,
guests), shelf v2 objects, Drop Dots board and coins, the app icon. When briefing new art,
attach one of these as the style reference.

## Findings, ranked by how often they appear in screenshots and play

| # | Where it shows | Problem | Fix | Imagegen? |
|---|---|---|---|---|
| 1 | **Wren, the host** — the shelf (screenshot 1), the welcome, the grown-up seal, Hum | Glossy, saturated red-orange clay (`wren-head`, `wren-body`, `wren-legs`). The only glossy character in the app, and it is on the first screen. | Rebuild Wren in felt, in the icon stone's terracotta with the butter cap, so the host *is* the icon character. Face stays procedural (head art has no face). | **Yes — prompt A** |
| 2 | **Feed food** (screenshot 2, every Feed session) | Four materials side by side: glossy clay apple / banana / carrot / egg, felt berries, photographic bread and cookie, wooden cup — next to perfectly felted friends. | One felt food set, same light and scale. | **Yes — prompt B** |
| 3 | **Sleepy Box shapes** | Glossy red ball and glossy yellow plastic triangle beside a felt cube and a gold felt-and-wood star. The shelf toy and the code colour the star **water blue**; the star art is gold, so the shelf promise and the toy disagree. | Four felt-wrapped shapes in the code's colours (terracotta ball, butter triangle, sage cube, water-blue star). | **Yes — prompt C** |
| 4 | **Stack capstone** | Glossy butter plastic pebble on matte felt stones. | Felt butter pebble. | **Yes — prompt D** |
| 5 | **Mix-Up heart button** | Glossy red plastic heart in the quiet felt room. | Felt heart in petal-terracotta. | **Yes — prompt D** |
| 6 | Window, Bubbles, Stack, Sleepy Box, Hum | Teal key-background shadows under 15 objects (yarn, suncatcher, library, capstone, watering can, boat, duck, cat rug, book, both cats, bubble pot, felt cube, Hum bed, block). | **Fixed in this pass** with `Tools/Art/despill.py` (warm cocoa shadows; objects untouched). | No |
| 7 | Hum frame and bed, bubble pot | Orange varnished wood, a step warmer and glossier than the maple used elsewhere. A colour-only correction made the frame look muddy, so it was not applied. | Optional: regenerate in pale maple when the next art batch runs (prompt E). | Optional |
| 8 | Meadow spring moss | The tile is lime; code already lays a warm veil over it. Judge on device before changing; a second desaturation risks grey. | Optional: regenerate as a muted felt moss tile (prompt E). | Optional |
| 9 | Room backdrops (shelf room, Window rooms, Bubbles room, Feed stand back, Sleepy Box floor) | Soft photographic interiors behind felt toys. This reads as "felt toys in a sunlit room" and is consistent across toys. Keep. Check on device that the light comes from the upper left in each. | No change now. | No |
| 10 | App size | Roughly 60 legacy imagesets are no longer drawn (v1 shelf objects, old Mix-Up part sets, `shelfroom-day/night`, Mix-Up curtains/room/stage, `feed-chalkboard`, `BrandHero`, `window-block`). Some names are still used as Mix-Up save-migration identities, not textures. | ChatGPT on the Mac: remove unused imagesets one group at a time, build, open every toy. | No |

## Moments to make screenshot-worthy (motion and composition, not new art)

These are the frames people will remember and share. Capture each on the Mac before the store
screenshots and check for clipping, off-model art and empty space.

1. **First shelf frame** — Wren awake, all toys sitting on their boards, nothing cropped at the
   screen edge in portrait and landscape.
2. **Feed: the happy moment** — the friend's laugh right after the wished-for food, crumbs or a
   small warm glow, food plates visible.
3. **Mix-Up: the reveal** — a funny mixed friend stepping onto the stand, in the full frame.
4. **Meadow: the bloom** — the spring trail with a woken landmark and butterflies.
5. **Hum: a chord** — several notes lit at once.
6. **Window: dusk** — the lamp turning on as the sky shifts.
7. **The rest** — the moon veil when the play timer ends; this is the brand's signature
   (the app gets sleepy rather than cutting play off).

## Prompts (ChatGPT image generation, transparent background)

Use built-in image generation with **transparent background on**. Attach
`App/Resources/Assets.xcassets/feed-cast-grandmother-1.imageset/feed-cast-grandmother-1.png` and
`mixup-friends-a` as the style reference. Save outputs to `ArtDrops/2026-10-08/` with the file
names given, plus a `prompts.json` like `ArtDrops/2026-10-07-mixup/`. Claude or ChatGPT then
crops, sizes and wires them (the code already loads these slot names; no code changes are needed
for A–D if the files keep the same names and similar framing).

House line for every prompt:

> Needle-felted wool children's toy, stop-motion still, visible soft wool fibres, matte, one
> soft key light from the upper left with warm fill, soft warm brown contact shadow directly
> beneath, muted warm Montessori palette (terracotta #C96F50, butter #D9B452, sage #829B82,
> water blue #83AAB9, cream #EEE3D1), calm and cozy, transparent background, no text, no
> glossy highlights, no plastic.

**A. Wren, the host — `wren-parts-sheet.png` (then cut to `wren-head`, `wren-body`, `wren-legs`)**
> [House line] A parts sheet for one small round felt character, front view, orthographic, in
> three rows on a transparent background with generous space between parts. Row 1: the head
> only — a soft rounded dome of terracotta felt (#C96F50), slightly wider than tall, with a small
> butter-yellow felt cap tucked on the top right like a little bean-shaped hat; the face area is
> completely blank, smooth felt with no eyes, no mouth, no cheeks (a face is added by the app).
> Row 2: the body only — a short rounded terracotta felt body with two small soft wing-like arms
> at the sides and a flat top neckline. Row 3: two small rounded terracotta felt feet side by
> side. Same colour and fibre texture in all three rows; the head is a little taller than the body.

**B. Feed food set — `feed-food-atlas.png` (then cut to `feed-apple`, `feed-banana`,
`feed-berry`, `feed-bread`, `feed-carrot`, `feed-cookie`, `feed-cup`, `feed-egg`)**
> [House line] A 4 × 2 grid of eight separate felt play foods, each centred in its own cell
> with generous transparent space around it, all at the same scale and the same three-quarter
> front view: (1) a round red-terracotta felt apple with a little brown stem and one sage leaf;
> (2) a curved butter-yellow felt banana with brown tips; (3) a cluster of three dusty blue felt
> blueberries with tiny star-shaped crowns and one sage leaf; (4) a round golden-brown felt bread
> roll with a soft scored top; (5) an orange felt carrot with a sage felt leafy top; (6) a round
> oat-coloured felt cookie with darker felt oat flecks and one small bite missing; (7) a small
> maple wood cup filled with smooth cream felt milk; (8) a cream felt egg cut in half showing a
> soft butter-yellow felt yolk. Every item is matte wool felt with visible fibres; nothing shiny,
> nothing photographic.

**C. Sleepy Box shapes — `sleepybox-shapes-atlas.png` (then cut to `sleepybox-ball`,
`sleepybox-triangle`, `sleepybox-cube`, `sleepybox-star`)**
> [House line] A 2 × 2 grid of four chunky felt-covered toddler shapes, each centred in its cell
> with generous transparent space, straight-on front view, same size: (1) a terracotta felt ball;
> (2) a butter-yellow felt triangle with softly rounded corners; (3) a sage-green felt cube with
> softly rounded edges, seen face-on; (4) a water-blue felt five-point star with softly rounded
> points. Each shape is plump, soft and matte, made to fit a shape-sorter hole.

**D. Small accents — `accents-atlas.png` (then cut to `stack-capstone`, `mixup-heart-button`)**
> [House line] Two separate felt objects side by side with generous transparent space: (1) a
> small smooth butter-yellow felt pebble, oval and slightly flattened, like the top stone of a
> balancing stack; (2) a plump petal-pink-to-terracotta felt heart, front view, softly rounded.

**E. Optional, next batch — `hum-frame`, `hum-bed-topdown`, `bubbles-pot`, `meadow-spring-moss`**
> Same framing as today's files, in pale maple with a satin finish (frame, bed, pot) and a
> seamless, muted olive felt moss tile (moss). Only if the device check shows they stand out.

## After new art lands

1. Crop each item to its visible silhouette with a little padding (see `Tools/Art/export_pairs.py`
   for the shared-crop helper) and keep the existing imageset names.
2. Check sizes against today's framing in code: Wren parts are positioned in `LullHostNode.swift`
   (head/body/legs), Feed foods are fitted by `FeedScene`, Sleepy Box shapes by `DropTreasureNode`.
3. Despill only if a teal edge appears (transparent generation usually avoids it).
4. Look at each toy on device in day and night before the store screenshots.
