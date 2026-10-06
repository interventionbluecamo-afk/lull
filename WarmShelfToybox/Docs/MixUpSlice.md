# Mix-Up — Slice Plan (Phase 2 of NorthStar)

*Concepts: `~/Desktop/concepts/mixup.png` (the dress-up theater: round stage, red
curtains, warm spotlight, cast in cubbies, wooden side buttons, heart token) and
`mix2.png` (brand/marketing composition, "Wren loves mix-up").*

## Verdict on the prototype (read 2026-06-10)

`MixUpScene` has the verb and the treasure already:

- Head / body / legs flip zones with chevrons ✓ (mismatches are the joke — keep)
- **Keepsake system** ✓ — heart button saves looks to an in-world wooden creations
  shelf, tap a portrait to flip it back on. Exactly the NorthStar law (never Photos).

## Deltas (the theater)

1. **The dressing corner becomes a stage.** Round wooden platform, red curtain swags and
   valance, a warm spotlight pool. The curtain does one small ta-da swish when a look
   completes (all three zones changed since last swish — rate-limited, calm).
2. **The cast in cubbies.** Below the stage, a wooden shelf of 3–4 resident characters
   (Wren among them, per `mix2.png`). Tap a cubby → current performer hops down, chosen
   friend hops up through a tiny curtain shimmer. One new mechanic, one verb: choose.
3. Chevrons become carved wooden buttons (art swap, same hit areas, same flipping).
4. Wren's five-expression sheet (concepts thumbnail) drives the performer's reactions —
   surprised on a flip, laughing on a triple-mismatch, sleepy when idle.
5. Character art arrives **pre-split at the flip seams** (head / body / legs as separate
   images sharing a registration grid) so the existing zone system swaps art parts
   exactly like it swaps procedural parts today.

## Status 2026-06-10 — theater staged, Wren cast

Room plate, round stage + light pool, valance and side swags wired (creations ledge ducks
below the valance; keepsake flight intact). The Wren sheet split into registration-tuned
head/body/legs and **joined the flip pools** — her pieces now mix with every procedural
character, which is the whole joke. `LULL_DEBUG_MIXUP_LAST=1` opens on the newest parts
for QA. Deferred: cast-cubby selection (needs more art characters — bunny/bear follow
Wren's template), wooden button art for the chevrons, spotlight art (subtle procedural
pool used instead).

## Art slots (sizes @3x px)

| Slot | Size | What it is |
| --- | --- | --- |
| `mixup-room` | 1290×2796 | Backdrop: warm wooden room, shelves with tiny toys at the sides, soft wall. No stage, no characters. |
| `mixup-stage` | 1100×500 | Round wooden stage platform with carved edge. |
| `mixup-curtain-swag-left` / `-right` | 700×1500 each | Red theater curtain swags, tied. |
| `mixup-curtain-valance` | 1300×400 | The top valance with gold trim. |
| `mixup-spotlight` | 1000×1400 | Soft additive warm light cone + floor pool, feathered. |
| `mixup-cubby-shelf` | 1300×450 | Wooden shelf strip with 4 open cubbies. |
| `mixup-button` | 320×320 | One round carved wooden button blank (zone icons composited in code). |
| `mixup-heart-button` | 360×360 | The clay heart keepsake token. |
| `wren-head-1..n` / `wren-body-1..n` / `wren-legs-1..n` | 600×600 / 600×700 / 600×500 | Wren's flip parts, registration-aligned. (Start: 3 of each.) |

Other cast members (bunny from `mix2.png`, bear) follow Wren's template once Wren proves
the registration grid.

## Audio drop-ins

| File | What |
| --- | --- |
| `mixup-flip.mp3` | Soft card/page flip (one per zone change). |
| `mixup-tada.mp3` | The curtain's tiny swish + a warm two-note settle. Quiet. |
| `mixup-hop.mp3` | Cast change hop — felt landing. |

## Definition of done

`Docs/WindowSlice.md` bar, plus: a saved portrait on the wall must feel like the child's
own artwork hung by a proud parent — the keepsake shelf is the toy's heart.
