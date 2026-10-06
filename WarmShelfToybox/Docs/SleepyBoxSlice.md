# Sleepy Box — Slice Plan (Phase 2 of NorthStar)

*Concept: `~/Desktop/concepts/sleepybox.png` — top-down view of a sleeping wooden
shape-sorter on a crochet rug, four colored shape-mouths, a drawer of sorted treasures.*

## Verdict on the prototype (read 2026-06-10)

`SleepyDropBoxScene` already IS the concept's mechanic — this was the happiest audit of
the lineup:

- Posting box with felt-lined holes and muffled thunks ✓
- **The drawer-pull reset** (treasures tumble back out) ✓ — the concept's signature beat
- Sleepy face with moods (sleepy/curious/happy/surprised) ✓
- Authored motion, no physics, nothing can get stuck ✓
- `accepts` per opening = physical control of error, never a "wrong answer" message ✓

So Sleepy Box is an **art pass, not a redesign**. Keep every mechanic and timing.

## Deltas when art lands

1. **Fixed treasure colors.** `returnCycle` currently re-tints shapes each drawer-pull.
   With authored art the four treasures keep the concept's identity forever: red ball,
   yellow triangle, green cube, gold star. Consistency over variety — a toddler's beloved
   objects don't change color overnight.
2. **Face stays procedural** (drawn over the art body). The mood system animates eye/mouth
   paths; baking a face into the plate would kill it. The art body ships face-less.
3. **Holes baked into the body plate.** The four felt-rimmed openings (red circle, yellow
   triangle, green square, blue star — concept colors) are part of the body art; the scene
   maps its opening centers onto the plate's proportions (constants documented next to the
   slot wiring when it lands).
4. As the box fills, it drifts deeper asleep and the room dims a notch — the wind-down
   nudge from `Docs/NorthStar.md`. (Small code beat, no art dependency.)

## Art slots (sizes @3x px; conventions per `Docs/WindowSlice.md`)

*All eight delivered and **wired 2026-06-10** — the box, drawer, floor and treasures run
authored art with the procedural face/moods on top, every interaction intact. Notes:
treasure faces stay procedural so they still wake when lifted; the drawer art covers its
baked slot when closed and reveals it when pulled; `faceScale` tightens the face for the
art's front panel. Open items: body regen to a straight-on view (playtest: 3/4 angle
feels odd — prompt 4a in `ArtShoppingList.md`; re-measure the hole fractions in
`buildArtBox` when it lands), solid triangle regen (4b — the rim-like first attempt is
stashed at `Assets/Staging/SleepyDropBox/sleepybox-triangle-rim.png`).*

| Slot | Size | What it is |
| --- | --- | --- |
| `sleepybox-floor` | 1290×2796 | Full backdrop: warm wood floor + round crochet rug, top-down, soft lamp pool of light. No box, no shapes. |
| `sleepybox-body` | 1300×1500 | The wooden sorter box, face-on/top-down like the concept, four felt-rimmed shape holes baked in, NO face, drawer slot visible but drawer closed/absent. |
| `sleepybox-drawer` | 1100×420 | The drawer alone, open, empty, with its little wooden knob. Slides in code. |
| `sleepybox-ball` | 420×420 | Chunky matte red clay ball. |
| `sleepybox-triangle` | 420×420 | Chunky yellow wooden triangle block. |
| `sleepybox-cube` | 420×420 | Chunky green wooden cube. |
| `sleepybox-star` | 420×420 | Chunky gold wooden star. |
| `sleepybox-plant` | 600×700 | Corner plant glimpsed at frame edge (concept upper-left). |

Treasures need a **front-facing and a "tucked" 3/4 angle**? No — one angle each; the
drawer shows them small, reuse with scale. Keep it to one sprite per treasure.

## Audio drop-ins

| File | What |
| --- | --- |
| `sleepybox-thunk-1..3.mp3` | Muffled felt-lined thunks, three depths. |
| `sleepybox-drawer-open.mp3` | Soft wooden slide + tiny tumble. |
| `sleepybox-snore.mp3` | The faintest contented snore loop, barely there. |

## Definition of done

Same bar as `Docs/WindowSlice.md` §Definition of done, plus: the drawer-pull pour reads
as the *reward* — the child should reset the toy because pouring is the fun part.
