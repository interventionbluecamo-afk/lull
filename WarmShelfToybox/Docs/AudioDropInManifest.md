# Audio Drop-In Manifest

This is the exact map between the sounds you record and the names `AudioManager` looks for.
**Drop a file with the listed name anywhere under `App/Resources/Audio/...`, run `xcodegen generate`, and it plays — no code changes.**

## How lookup works

- `AudioManager` loads each sound by its **first resource name** (see `soundTunings` in
  [`AudioManager.swift`](../App/Shared/AudioManager.swift)).
- Supported extensions, in order: `.mp3`, `.wav`, `.m4a`. Any one works.
- Files are bundled flat, so the **filename must be globally unique** and match exactly (case-sensitive).
- Three copies of each player are pre-created for overlap, so rapid repeats won't cut off.
- Until a real file exists, the sound falls back to a bubble pop. That fallback is the thing we are
  replacing — every name below is currently bubble-pop-or-silent.
- `volume`/`rate` in the table are the current tuning; you can ignore them when recording
  (record clean and normalized) — they're applied on top. Keep masters mono, ~44.1kHz, trimmed tight.

---

## PRIORITY 1 — Launch toys (record these before shipping)

These three toys ship. This is the whole sensory layer for v1.

### Shared (used across the app)
| Record as | Plays when | Feel | vol |
|---|---|---|---|
| `soft-tap.mp3` | Any accepted toddler touch / toggle | Soft felt tap, ~80ms, no transient spike | 0.12 |
| `empty-tap.mp3` | Tap on empty space | Quieter, airier than soft-tap | 0.10 |
| `shelf-transition.mp3` | Opening a toy / returning to shelf | Gentle paper/whoosh swell, ~250ms | 0.12 |

### Bubbles
| Record as | Plays when | Feel | vol |
|---|---|---|---|
| `bubble-pop-small-1.mp3` ✅ exists | Small bubble pops | Light, high, wet | 0.18 |
| `bubble-pop-medium-1.mp3` ✅ exists | Medium bubble pops | Rounder pop | 0.24 |
| `bubble-pop-large-1.mp3` | Large bubble pops | Deeper, fuller, slower | 0.29 |
| `bubble-pop-rare-1.mp3` | Rare / mother bubble pops | Special — a soft chord or shimmer, not just a pop | 0.20 |

### Feed the People
| Record as | Plays when | Feel | vol |
|---|---|---|---|
| `food-pickup.mp3` | Lifting a food | Tiny soft pick-up | 0.12 |
| `food-release.mp3` | Dropping food back on table | Soft set-down | 0.12 |
| `food-plop.mp3` | New food appears in basket | Light plop/bounce | 0.13 |
| `feed-receive.mp3` | Food reaches a mouth | Warm "mm" / happy receive | 0.18 |
| `feed-happy.mp3` | **Full-table celebration** (all 3 fed) | Signature warm exhale / hum — the payoff | 0.16 |
| `feed-decline.mp3` | Wrong food offered | Gentle "no thanks", never harsh | 0.10 |
| `feed-chew-soft-1.mp3` ✅ exists | Soft foods chewed | Quiet soft chew | 0.11 |
| `feed-chew-crunch-1.mp3` ✅ exists | Apple/carrot/cookie chewed | Quiet crunch | 0.09 |

### Stack
| Record as | Plays when | Feel | vol |
|---|---|---|---|
| `stack-place.mp3` | Lifting / placing a stone | Soft pick-up, woody-soft | 0.14 |
| `stack-settle.mp3` | A stone lands / settles / topples | Gentle soft thud, no hard transient | 0.13 |
| `stack-wake.mp3` | Tower grows tall and the top stone **wakes** | Warm little chime / yawn — the payoff | 0.16 |

### Bloom (explorable garden world)
| Record as | Plays when | Feel | vol |
|---|---|---|---|
| `bloom-plant.mp3` | Each flower sprouts; critter/landmark taps | Tiny soft "pop"/sprout, quiet (plays rapidly while drawing — keep gentle) | 0.13 |
| `bloom-flourish.mp3` | Garden lush (~every 20 blooms); sun/moon tap | Warm chord / soft shimmer — the garden exhaling | 0.16 |

Bloom now also has: a pond (fish surfaces), a tree (fruit shakes down), a hollow log, a mossy
rock (beetle), a berry bush, a sleepy snail, roaming mouse/bear/bird, butterflies, fireflies, and
an obvious dawn/midday/dusk/night sky. All currently use `bloom-plant`/`bloom-flourish` + soft
fallbacks. **Optional future per-interaction sounds** (drop in to enrich): `pond-splash`,
`fruit-drop`, `critter-mouse`, `critter-bear`, `critter-bird`, `birdsong-ambient`, `night-crickets`.
They aren't wired yet — tell me and I'll route them in `AudioManager` like the others.

---

## PRIORITY 2 — Post-launch toys (only when you ship them)

Puddle Play, ClayBlocks, Soft Drop, Gentle Nest, Paint, and Warm Hum (music box) are gated out of v1.
Record these only when you bring a toy out of the reserve.

| Record as | Toy | Plays when |
|---|---|---|
| `puddle-tap-1.mp3` | Puddle Play | Light splash |
| `puddle-ripple-1.mp3` | Puddle Play | Strong splash |
| `puddle-raindrop-1.mp3` | Puddle Play | Raindrops |
| `puddle-creature-1.mp3` | Puddle Play | Creature appears / rainbow beat |

| Record as | Toy | Plays when |
|---|---|---|
| `block-pickup.mp3` | ClayBlocks | Lift a block |
| `block-release-1.mp3` ✅ exists | ClayBlocks | Drop a block |
| `block-settle-1.mp3` ✅ exists | ClayBlocks | Block settles |
| `mystery-shape.mp3` | ClayBlocks | New shape offered from tray |
| `music-box-tick.mp3` | Warm Hum | Mechanism tick |
| `music-box-stop.mp3` | Warm Hum | Mechanism stop |
| `music-object-pickup.mp3` | Warm Hum | Lift a sound object |
| `music-object-settle.mp3` | Warm Hum | Sound object settles |
| `music-note-wood-1.mp3` | Warm Hum | Pentatonic note (wood) |
| `music-note-clay-1.mp3` | Warm Hum | Pentatonic note (clay) |
| `music-note-bell-1.mp3` | Warm Hum | Pentatonic note (bell) |
| `music-note-stone-1.mp3` | Warm Hum | Pentatonic note (stone) |
| `music-note-paper-1.mp3` | Warm Hum | Pentatonic note (paper) |

---

## After dropping files in

```sh
cd WarmShelfToybox
xcodegen generate
```

Then build/run. In a Debug build, a missing file prints `AudioManager: missing audio for <profile>`
to the console — use that to confirm everything resolved.
