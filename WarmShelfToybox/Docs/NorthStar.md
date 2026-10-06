# Lull — North Star (Final Product Vision)

*Status: governing doc for the final-product push, June 2026. Where this conflicts with
`TopChartsRoadmap.md` or `ThreeWeekShipPlan.md`, this wins. The current build is the
prototype — "the vision visualized." Everything in it, including mechanics, may change.
The brand laws in `Brand.md` and the child-safety promises do not change.*

**Goal: Apple Design Award. Top of the kids category. The trusted name in calm toddler play.**

---

## 1. The locked lineup (9 toys)

Bubbles · Feed · Stack · Sleepy Box · Window · Drop Dots · Mix-Up · Hum · Meadow

These names are final and parent-facing (registry: "Sleepy Drop Box" → **Sleepy Box**,
"Glow Window" → **Window**, "Feed the People" → **Feed**; IDs stay for save-state).
Bloom, Glowboard, Dough, Current stay parked. Nine is the number — Meadow earned the
ninth slot (founder call, June 11: the only novel mechanic in the box; the 2.8yo
thumb test closed loops once or twice, with scribble-mode carrying the rest). Every
toy must reach reference quality; nothing else joins the shelf before launch.

All toys live in the **Shelf Room** — the child's safe place. Real little room, warm wood,
ambient light that follows the actual time of day. No menus. Objects only.

## 2. Art direction: "Warm Clay" (locked, from /Desktop/concepts)

The concept art settles the prototype's biggest gap (procedural vector → authored material):

- **Soft-3D clay-and-wood render** — stop-motion stills feel: clay characters, wood toys,
  felt rugs, knit cushions, butter lamplight, gentle vignette.
- **Color discipline**: environments stay warm-neutral (wood, linen, cream). Saturated
  soft primaries belong only to the *manipulables* — the Montessori cue for "touch me."
- **Every toy is a place, not a screen**: market stand, theater, rug-top, window seat.
- **Diegetic UI only**: wooden buttons, chalkboards, a heart token, drawers. The single
  home chip (top-left, soft rounded square) is the only chrome. *If it isn't wood, felt,
  or light, it doesn't ship.*
- **Everything is alive** (per `AlivenessPrinciples.md`): the sorter box sleeps, the egg
  smiles, the cat dreams. Faces are earned, not pasted — sleepy lids, rosy cheeks.

**Wren** (pronoun: *they*, decided June 11) is the brand creature: terracotta clay blob, butter **moon patch**, five-expression
core sheet (neutral / happy / laughing / sleepy / surprised — see concepts thumbnail).
Wren lives on the shelf, stars in marketing art ("Wren loves mix-up"), joins the Mix-Up
cast. The app-icon mark (sleepy stack-stone with capstone, per `Brand.md`) is Wren's
kin — same clay, same moon patch. One family, one silhouette language.

## 3. Production model: digital stop-motion

We do **not** rebuild in 3D. We composite pre-rendered layered art in SpriteKit and keep
our existing motion language (anticipation → caused response → follow-through → slow
settle), physics, haptics, and audio systems — they are already the good part.

Per-toy pipeline:
1. **Concept frame** (done: Feed, Mix-Up, Sleepy Box, Window).
2. **Parts list** — decompose the frame: background plate, midground props, each
   interactive object, character rig parts (body/head/eyes/cheeks separate), expression
   atlas, light overlays (day/night/lamp glows).
3. **Generate/paint each part** on transparent background, style-anchored to the
   concept frame and the Wren sheet. Consistency pass.
4. **Atlas + import**; compose in SpriteKit with 2–3 parallax layers and additive
   light nodes.
5. **Wire to existing systems** (physics profile, haptic score, toy audio key, reverb).
6. **Device playtest with the 2.8-year-old.** His attention is the spec.

## 4. The toys — final mechanics

*(License confirmed: mechanics may change. Changes marked ◆.)*

**Bubbles** *(free)* — Keep the verb: pop. First-touch toy, zero setup, multi-touch.
Upgrade is material: real soap-film iridescence, a warm room behind, pops bloom in the
toy's musical key. Some bubbles carry tiny drifting cargo (leaf, star) that settles on
the sill. Do not over-design the simplest toy.

**Feed** ◆ — *The farm stand.* (Concept locked.) Four little customers lean over a wooden
counter, each with a picture-bubble want (apple, carrot, banana, egg-with-a-face). Child
serves by dragging food from pedestal plates. Match = beaming, happy chewing, a wave,
a new friend wanders up; basket replenishes the counter. "Wrong" food = a kind giggle and
a glance at the bubble — control of error with zero shame. Practical-life Montessori:
the child *cares for others*. This adds Lull's first soft purpose-loop, no score anywhere.

**Stack** *(free)* — The signature hero. Mechanics stay (emotional no-fail stacking, the
yawning tower, the capstone). Final pass = material: the stones become true Warm Clay
with Wren-family expressions. Stack gets the *matured* pipeline (after the slice), because
the hero deserves the practiced hand, not the learning run.

**Sleepy Box** ◆ — *The sleeping shape-sorter.* (Concept locked.) A wooden box with a
serene sleeping face; four shape-mouths with colored rims; chunky shapes on the rug.
Post a shape → the box gulps it sleepily (cheeks puff, lashes flutter), a soft muffled
note from inside. Wrong hole = it simply doesn't fit; gentle bonk; the box snores on.
The drawer below slowly fills — and **pulling the drawer open pours everything back out**.
The reset *is* the reward (Montessori cycle of activity). As all shapes go in, the box
drifts deeper asleep and the room dims a notch: a wind-down toy in disguise.

**Window** ◆ — *Turn the day off.* (Concept locked — flagship.) An arched window room:
window seat, sleeping cat, plant, star lamp, curtains that breathe. On the rug: one
wooden **day/night dial**. Turning it rolls the sky — sun arcs down, moon rises, trees go
silhouette-blue, the lamp warms on, the cat stretches/curls/sleeps, crickets fade in.
One glorious verb: *turn time.* Secondary touches only: pet the cat (purr haptic), tap
the lamp, touch the night sky (shooting star). This is the bedtime ritual made playable
and the App Store hero shot.

**Drop Dots** — Keep the verb: drop a dot at the top, it tumbles through pegs, lands in a
wooden groove. Upgrade: every peg-tick is a soft mallet note in key, the landing resolves
the phrase; dots are sleepy-faced and doze where they settle (slow-to-settle = brand).
Material pass to chunky painted wood.

**Mix-Up** ◆ — *The dress-up theater.* (Concept locked.) A round wooden stage, red
curtains, warm spotlight. The cast (Wren, bunny, bear…) waits in cubbies below — tap to
choose who's on stage. Wooden side buttons cycle hats / tops / bottoms. The heart token
saves the moment as a **framed portrait on the room wall** (existing law: in-world only,
never Photos/social). Curtain does a tiny ta-da swish. Symbolic play + choice-making.

**Hum** — Keep the new strike-only instrument feel (no lag, one bar at a time, blooming
strikes, room reverb). Final pass = body: it becomes a real wooden instrument-creature
(tongue-drum / glockenspiel hybrid) in Warm Clay materials.

**Shelf Room** ◆ — Needs its own concept frame; it is the first screen and the brand's
home. The shelf as real furniture in a real room; toys sit as physical objects; Wren
resident; light follows the household's actual evening. Backgrounds shift subtly and
rarely (seasons, weather) — noticed on the tenth visit, not the first.

**Parent area & timer** — *(revised 2026-06-10, founder call)* The parent area gets a
clean, beautifully **themed UI** — our palette, type, spacing, warmth — not a skeuomorphic
timer object. Parents need clarity, not a toy; the craft shows in restraint. What stays
unchanged is the child-facing half of the promise: when time is up **the app gets
sleepy, not the child gets cut off** — toys yawn, light dims, Wren dozes, the room
settles toward the shelf. No alarms, no abrupt endings. (The generated timer-dial art
remains in `~/Desktop/concepts/` as a palette/mood reference only.)

## 5. Build order

- **Phase 0 — concepts complete.** Generate in-style frames for: Shelf Room, Bubbles,
  Stack, Drop Dots, Hum, parent timer. (Style anchors: window.png + the Wren sheet.)
- **Phase 1 — vertical slice: Window to final quality.** Proves the whole pipeline
  (layered depth, lighting state machine, big manipulable, ambient creature, day/night
  audio) on the most marketable, most differentiated toy. Defines "reference quality."
- **Phase 2 — concept-ready toys:** Sleepy Box, Feed, Mix-Up.
- **Phase 3 — the rest:** Stack (hero polish), Bubbles, Drop Dots, Hum.
- **Phase 4 — the wrapper:** Shelf Room final, parent area + timer, icon + App Store
  set (mix2.png is the screenshot/brand template), 15s ad per `Brand.md`.

## 6. What we keep / what we change

**Keep:** the shelf model, no-fail/no-timer/no-score laws, free pair (Bubbles + Stack),
one-time $9.99 lifetime unlock + 7-day trial, the parent promise, the motion language,
the audio architecture (per-toy keys, room reverb), haptics, the aliveness/expression
principles, Wren on the shelf.

**Change:** every visual surface (procedural → Warm Clay authored layers), Feed/Mix-Up/
Sleepy Box mechanics as above, Window becomes the dial room, parent-facing names,
the timer becomes the sleepy-room ritual, app icon contrast pass once Stack's final
material exists.

**Never:** ads, subscriptions, child-facing prices/locks/streaks, social export, loud
reward loops, text at the child.
