# Bubbles — Material Pass (Plan session 4)

*Playtest: "feels so different from the rest." The verb (pop) and multi-touch stay
untouched; the gap is staging — bubbles float in a void while every other toy lives
in a room.*

## Kept
Pop mechanics, bubble sizes/rarity, pop particles, sounds. **The bubble film itself
stays procedural** — iridescence and translucency over a moving background can't be a
static sprite; engine-drawn is correct here.

## Deltas
1. `bubbles-room` full-canvas plate behind everything (soft warm nursery corner,
   airy light — the warm room the bubbles drift through).
2. `bubbles-pot` — the wooden bubble pot from the shelf object, large, sits low in
   the scene as the visible source; bubbles rise from its mouth (anchors "where do
   bubbles come from" + matches the shelf story).
3. Procedural film tint re-tuned over the warmer plate (engine, no art).

## Audio (drop-in)
Existing pops kept; add `bubbles-ambience.mp3` (airy, near-silent room tone).
