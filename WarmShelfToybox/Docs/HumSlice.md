# Hum — Material Pass (Plan session 6)

*The strike-bar instrument: no lag, one bar at a time, blooming notes, room reverb —
all recent, all tuned, all kept. The founder's shelf object made the call: Hum is a
XYLOPHONE (better match than my tongue-drum idea — the bars ARE the mechanic).*

## Kept
Strike mechanics, per-note bloom visuals, reverb voice, no-lag touch.

## Art slots (@3x px)
| Slot | What |
| --- | --- |
| `hum-frame` | The wooden xylophone frame/bed, straight-on, EMPTY (no bars), with the gentle creature-like rounding of the shelf object. |
| `hum-bar-1..5` | From ONE band-sheet (5 horizontal bands, longest→shortest): rainbow felt-wood bars in our palette (terracotta, butter, sage, water-blue, lavender). Bars are separate so each strikes, blooms and breathes alone. |
| `hum-mallet` | The soft felt-tipped mallet (follows the finger or rests against the frame). |
| `hum-room` *(later, optional)* | Warm plate. |

Wiring: bars land on frame-relative measured positions (band-sheet split, registration
scripted — the Wren/cast pipeline verbatim).

## Audio
Engine tones are already the toy's voice; optional `hum-room-tone.mp3` bed later.
