# Status — June 11, noon

*Where the toybox stands after the biggest single morning of the project. Companion to
`Plan.md` (the order of work) and `ArtAsks.md` (outstanding generations) — this is the
snapshot; those stay the living docs.*

---

## The headline

**Nine toys, all wearing authored art or wired for it, every approved delight built.**
This morning closed the QA brief's entire priority list, landed the founder's playtest
verdicts, shipped all six approved delights plus both magic-moment toys, landed 27 new
imagesets including the complete Feed cast, and re-thought Reduce Motion and silent
mode. The repo itself got reorganized (see "The house" below). One toy remains unwired
(Drop Dots — its session is next), one big sensory gap remains (audio, session 7,
deliberately skipped per founder order).

---

## The toybox, toy by toy

| Toy | State | Open items |
| --- | --- | --- |
| **Shelf Room** | ★ Carved nameplate, companions, tilt-parallax, real-clock plates — and now **authored boards** (3-band post-cap slice) + **authored Wren** (painted clay, living procedural face, butter cap) | Two-tier cabinet look = founder call (unit art carries 2 surfaces, phone runs 3 rows) |
| **Window** | ★ Legible cat-awake LANDED + verified; peek-a-boo curtains live (bird visit / cloud jump / star fall, curtains whisper *close me*); halos feathered | Frame-calibration session (8) for the stashed arched art |
| **Meadow** | ★ Confirmed toy #9 by thumb-test. paper.io flow hardened (closure forgiveness, resting trails); landmark seeds wake (painted rock plates crossfade) | The 8-prompt art batch (grounds, snail, rosette…) still ungenerated — only its prompts block it |
| **Sleepy Box** | ★ Composed lullaby: 4th treasure posted → box hums the notes back in posting order; teal ghost killed | Audio session thunks (7, parked) |
| **Mix-Up** | ★ The bow (match → spotlight warms, one small bow); one clay next-button per zone (founder fix); feet seams kissed | Cast cubbies session (10); portraits-sleep-at-night idea parked |
| **Stack** | ★ Autonomous reset REMOVED — the knockdown belongs to the child forever; grab radius widened; vignette feathered | — |
| **Feed** | Sandwich ask live (1-in-6 wants two foods, stacked bubble, both = wow); characters raised 10pt; **full 20-cell cast art LANDED** | Session 9: wire the authored cast over procedural CharacterNode — the highest-leverage visual swap left |
| **Bubbles** | Wired into the house: plaster room, raking light, pot-mouth spawning, pearl retune; rain is weather now, not wages (founder fix) | — |
| **Drop Dots** | ★ Wired (June 11 afternoon): measured-fit board, 3-band shaft compression, faces-on-art tokens, felt tray, authored tab + all three delights (honest weight, column wave, golden dot) | Landscape rack check on device (sim rotation lock) |
| **Hum** | Bar-driven 9-slice frame, staged tone prewarm (~13s debug cold-start fixed), navy shadow purged | Measure first-render on device in Release; `hum-rail-bed` regen only if geometry fights again |

**Cross-cutting:** one linen grain over every room ⭐ · Reduce Motion now *calms instead
of freezing* (breathe/drift survive at ~45%) · silent-mode visual boost when touches
can't be heard · trial Day-7 cliff is now a designed ending (parent-area states + quiet
8pt dot, nothing child-facing) · Wren's pronoun is *they*, swept everywhere.

---

## What landed today (chronological)

1. **Morning QA batch** — cat "bug" closed as art-not-code (instrumented proof);
   Bubbles wired; Hum geometry + staged prewarm + asset shadow purge; polish hour
   (Sleepy Box teal, Stack vignette, halo feathering, Meadow daytime sage-straw).
2. **Meadow flow pass** — homecoming forgiveness (26pt ring, area-gated), stale trails
   rest into shy flowers, landmark seeds with wake/sleep + debug hook.
3. **Approved delights batch** — composed lullaby, the bow, peek-a-boo curtains,
   sandwich ask, shelf parallax, global linen grain. All six, built and committed.
4. **Playtest-blessed fixes** — Stack reset removed, trial ending designed, Mix-Up
   one-button-per-zone, Bubbles rain declocked from pop counts.
5. **Founder decisions + UX passes** — Meadow = toy #9; Wren = they; Reduce-Motion
   calm pass; silent-mode boost.
6. **`requests611` batch 1** — 27 imagesets keyed + landed: Feed cast (4 sheets → 20
   expression cells, valley-cut for the touching grandmothers), legible cat-awake,
   carved nameplate, shelf companions (plant, blanket), Meadow rock asleep/awake
   plates + stump. Three wirings: rocks crossfade, nameplate composited, companions
   on the small shelves.

---

## Outstanding

**Sessions, in founder's order:** 5 (Drop Dots wiring + its three delights) → 2
remainder (shelf furniture layout + authored Wren) → ~~7 audio~~ *(skipped per founder)*
→ 8 (Window frame calibration) → 9 (Feed cast wiring) → 10 (cubbies) → 11 (parent area
+ Liquid Glass call) → 12 (store kit) → 13 (release hygiene).

**Art generations wanted** (all prompts paste-ready in `ArtAsks.md` / `Plan.md`):
- **Meadow batch of 8** — the only outstanding required set (winter/night grounds are
  full-canvas, rest teal).
- *Conditional:* `hum-rail-bed` (only if the frame fights again), icon contrast pass
  (pre-submission).
- Everything else from the June-11 list is **generated and landed**. ✅

**Known watch-items:** Hum first-render time on a real device in Release · landscape
clipping re-check on Feed's taller two-food bubble · `Tools/Claude/launch.json` points
at `/tmp/lull-server.js` (ephemeral — the landing-page server script won't survive a
reboot; consider moving the script into `Tools/`).

---

## The house (file organization, June 11)

Everything Lull now lives inside `WarmShelfToybox/`. The Desktop is clean.

```
WarmShelfToybox/
├── App/                    the app target (scenes, shared kit, resources/xcassets)
├── Assets/                 non-shipping art workspace (see Assets/README.md)
│   ├── Marketing/          press/marketing sources + the card set (Cards/)
│   ├── Staging/            per-toy staging & QA art (tracked)
│   │   └── Drops/          RAW generation batches by date (gitignored, indexed README)
│   └── Reference/          concepts, playtest phone shots, QA screenshots (gitignored)
├── Docs/                   the paper trail (Plan, NorthStar, ArtAsks, briefs, slices…)
├── LandingPageSource/      editable landing page   (was Desktop/lull-landing)
├── LandingPageDeploy/      deploy-ready copy
├── Tools/                  founder's local helper config (launch.json)
├── Archive/Backups/        the old manual .zip backups (gitignored — git is the backup)
├── Lull.xcodeproj          (+ project.yml for xcodegen)
└── README.md
```

Raw drops and reference archives (~250MB) are *organized on disk but gitignored* —
indexed by `Assets/Staging/Drops/README.md` so nothing is mystery-named again. New
generation drops: make a dated folder under `Assets/Staging/Drops/` and say so.

Left untouched on the Desktop, deliberately (personal or ambiguous): two camera JPGs,
`Resume25.pdf`, one May-23 screenshot, one June-2 screen recording (`.mov` — if that's
a Lull playtest recording, say the word and it joins `Assets/Reference/`).
