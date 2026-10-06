# The Kitchen — Phase B Plan (1.1 flagship, NOT pre-submission)
*Planned now so it ships fast later. The council's framing holds: this is a SECOND
ROOM, reached through the lean the child already knows.*

## The doorway (how you get there)
The room peek already rubber-bands at ±110pt. Phase B: leaning HARD past the right
edge (sustained pull past the band for ~0.5s) carries the camera through a doorway
into the kitchen viewport — one room over, same household, same clock. Leaning back
left returns. No buttons, no navigation chrome: the house is one continuous space
with two rooms. (Engineering: a second scene-region offset on the same layers, with
the snap handled like the lean — one camera system, two rest points.)

## The kitchen's verbs (three, capped — depth over density)
1. **The kettle** — set it on the stove dot, it warms with the real clock (a slow
   minute), then whistles SOFTLY (one breathy note, never shrill) and breathes
   steam. Take it off, it rests. Patience verb #2.
2. **The toast** — bread into the slot, it toasts by the clock, pops with a thunk;
   place it on the plate. The household's first "make something for someone."
3. **The cat's bowl** ⭐ — the connector: a small bowl on the kitchen floor. Fill
   it (a scoop by the bag); if the cat is home on the WINDOW rug, she pads over a
   beat later — the two rooms share one resident, which makes the house real.

## Furnishing (Pok Pok density law: 5–7 touchables)
Stove + kettle, toaster + bread, the bowl + bag, a window over the sink (shares
the real-clock sky), one chair, one hanging pan that swings on tap. Nothing else.

## Asset list (imagegen, when Phase B starts — NOT now)
- `kitchen-room-day` / `kitchen-room-night` plates (match window-room palette,
  arched window over a sink, warm wood counters)
- `kitchen-kettle` (2 cells: resting | steaming), `kitchen-toaster`,
  `kitchen-bread` (2 cells: pale | toasted), `kitchen-plate`,
  `kitchen-catbowl` (2 cells: empty | full), `kitchen-kibble-bag`,
  `kitchen-pan`, `kitchen-chair`
- The cat walks: `window-cat-walking` 2-cell mini-sheet (or we slide her sleeping
  sprite with a bob — decide on art quality at the time)

## State (all local, privacy posture unchanged)
`kitchen.kettleOn/Since`, `kitchen.breadStage`, `kitchen.bowlFull`,
`kitchen.catFedDay` — same UserDefaults pattern as the pot.

## Order of work when 1.1 opens
1. Doorway camera (the lean-through) — 1 session
2. Plates landed + the kettle verb — 1 session
3. Toast + bowl + the cat's walk — 1 session
4. Audio: kettle breath, toast thunk, kibble pour (add to AudioScouting tiers)

*Total honest estimate: 3–4 sessions + one art run. The tease for 1.0: nothing —
the doorway appears when the kitchen exists. No locked doors in a toddler's house.*
