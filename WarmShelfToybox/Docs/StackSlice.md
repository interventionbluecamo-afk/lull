# Stack — Hero Pass (Plan session 3)

*The signature toy and the icon's own character — the last flagship still procedural.
Mechanics are PROVEN (the emotional no-fail stacking is the brand) and do not change.*

## Kept
Everything: lift/wake, the tower, squash-settle physics feel, the capstone moment,
signature-hero logic, all sounds/haptics. Faces stay procedural over art bodies
(the waking eyes are the toy).

## Art slots (@3x px; one band-sheet + one single)
| Slot | What |
| --- | --- |
| `stack-stone-small` / `-medium` / `-large` | From ONE band-sheet (3 vertical bands, small→large): plump terracotta clay stones, faceless, matte, slightly squashed-resting. The shelf object + app icon are the anchors. |
| `stack-capstone` | The tiny butter-yellow capstone, faceless. |
| `stack-floor` *(later, optional)* | Warm nursery floor plate. |

Wiring: stone bodies swap under the existing procedural face/eye system exactly like
Sleepy Box treasures (`DropTreasureNode` pattern). Squash/wobble act on the node — art
deforms with it.

## Audio (drop-in)
`stack-lift.mp3`, `stack-settle-1..3.mp3` (felt-clay set-downs), `stack-capstone.mp3`
(the gentlest sparkle-resolve).
