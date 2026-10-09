# Little Wash — image prompts

The founder generates these; ChatGPT adds them as imagesets with exactly these names. Faces are
**never** painted: every vehicle's face is drawn live in code on its windshield (house law, like
Wren and the Feed friends). Mud, foam, water and sparkle are added in code over the clean art.

## Shared style (paste before every prompt)

> Handmade needle-felt toy for a calm, premium children's app (ages 2–6), matching an existing
> felt-and-wood toybox: soft wool fibres you can almost feel, gently rounded chunky shapes,
> stitched seams, warm diffuse light from the upper left, soft sun-faded hand-dyed colours
> (terracotta, sage, butter, lavender, water-blue, petal, cream), never neon, never glossy
> plastic. One object, centred, fully visible, camera straight from the side, native
> transparent background, no drop shadow, no text, no letters, no numbers, no logos.

## 1. Vehicles (six), side view facing right — the stars

Make each on a **1600 × 1000** transparent canvas, all at the **same scale** and standing on the
**same ground line** (bottom 12% of the canvas empty below the wheels' bottoms), body about
80% of the canvas width. **No wheels** (they're a separate spinning image). Leave **dark felt
wheel arches** where the wheels go. The **windshield or cab window** is a plain pale-blue felt
panel with **no face, no eyes, no driver** (the face is drawn there in code). Clean, never
muddy.

| Name | Prompt (after the shared style) |
|---|---|
| `wash-fire-truck` | A chunky little felt **fire truck**: warm tomato-red body, cream stripe, a short wooden ladder on top with felt rungs, a small brass-felt bell, a rolled cream hose on the side. Friendly, compact, toy-like, not realistic. |
| `wash-police-car` | A rounded little felt **police car**: soft water-blue and cream body, a small two-part light bar on the roof in muted red and blue felt (unlit), round headlights. Gentle and friendly, not aggressive. No badge text. |
| `wash-tractor` | A small felt **farm tractor**: sage-green body, butter-yellow hubs area, short exhaust pipe, an open cab with a pale-blue felt window, big rear wheel arch and small front wheel arch. |
| `wash-school-bus` | A short, round felt **school bus**: butter-yellow body, a row of four pale-blue windows plus a separate front windshield panel, cocoa-brown bumper stripe. Short enough to look cuddly. |
| `wash-digger` | A small felt **digger**: terracotta-orange body, cab with a pale-blue window, a jointed felt arm with a little bucket resting in front, low tracks area left as dark felt (no wheels needed; code will add small wheels). |
| `wash-ice-cream-van` | A small felt **ice-cream van**: petal-pink and cream body with soft scalloped trim, a felt ice-cream cone on the roof, a serving hatch (closed), pale-blue windshield. |

## 2. Shared wheel

`wash-wheel` — **512 × 512**. A single round felt wheel seen from the side: dark charcoal-brown
felt tyre, cream felt hub with three stitched spokes (so spinning is visible), centred and
filling 92% of the canvas.

## 3. The wash bay (background)

`wash-bay` — **2732 × 2048** (iPad landscape; the app crops it for phones, so keep everything
important in the central 60% horizontally and between 20% and 85% vertically). A cosy felt-and-wood
**toy car wash** seen straight on: soft sage felt wall tiles, a warm honey wooden floor with a
small drain and a shallow felt puddle near the left entrance, a wooden shower bar across the
top with little felt water nozzles, two tall soft felt roller brushes standing at the far left
and right edges, a pegboard with nothing on it. The **centre is empty floor** where a vehicle
will stand. Calm, warm afternoon light. No vehicles, no people, no text.

## 4. Tools (three)

Each **512 × 512**, centred, filling about 80%, slight three-quarter view so it reads as an
object you can pick up.

| Name | Prompt |
|---|---|
| `wash-tool-sponge` | A chunky butter-yellow felt **sponge** with a few soft white felt foam bubbles on top. |
| `wash-tool-hose` | A short coiled terracotta felt **hose** ending in a rounded cream-and-water-blue felt **spray nozzle**. |
| `wash-tool-towel` | A neatly folded water-blue felt **towel** with a cream stitched stripe. |

## 5. Mud (four splats)

`wash-mud-1` … `wash-mud-4` — each **512 × 512**: one organic **felt mud splat**, soft fuzzy edges,
warm brown to cocoa with slightly darker centre and a few tiny wool flecks, different shapes
(round splat, long smear, drip with two drops, cluster of small blobs). Transparent background.
The code scatters, tints and clips them onto the vehicles.

## 6. Shelf card

`shelf-wash-v2` — match the composition, size, lighting and framing of `shelf-stack-v2` exactly
(same canvas, same wooden shelf edge). Subject: the felt fire truck half-covered in soft white
foam on a little wooden wash platform, a felt sponge beside it. **No face** on the truck (the
shelf animates it).

## 7. Later (optional, not needed for v1)

- Rare guests: `wash-guest-piglet-wagon` (a muddy-pink felt piglet sitting in a little wooden
  wagon, face drawn in code), `wash-guest-balloon-basket` (a hot-air-balloon wicker basket with
  a short felt balloon above), `wash-guest-rocket` (a round felt toy rocket).
- Other dirt kinds: `wash-leaf-1…3` (autumn felt leaves), `wash-snow-1…2` (white wool patches),
  `wash-paint-1…3` (soft felt paint splats in petal, butter, lavender).

**Checks before adding:** transparent edges clean at 100%; all six vehicles truly share scale and
ground line (line them up side by side); windshields blank; nothing reads as text.
