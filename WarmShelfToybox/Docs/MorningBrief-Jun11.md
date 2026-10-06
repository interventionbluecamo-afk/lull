# Morning Brief — June 11
*New hire's first-night walkthrough. Background: ADA jury room, shipped toddler games,
Montessori doctorate. I played every toy at midnight so you'd know where we stand at
breakfast. Verdicts are honest; that's what you hired me for.*

---

## The headline

This toybox has a soul. The shelf at night — nine handmade objects under starlight with
Wren dozing at the end — is already an App Store editorial screenshot. Six of ten
surfaces would survive the jury table *today*. Three need their queued sessions. One
(Bubbles) is from a different, older app and it shows.

What impressed me most as the Montessori reviewer: nothing punishes, nothing rushes,
every reset belongs to the child (the drawer-pour, the dandelion, the wind). That
discipline is rarer than good art, and you have both.

---

## Toy by toy

**Shelf Room — ★ jury-ready.** Night mode is the single best frame in the app. The
authored objects read as real possessions. Wren wants their art face eventually, but their
procedural self holds the corner well. *Nit:* breathing-pool glows behind objects have
faintly visible edges on close look.

**Window — ★ jury-ready, two nits.** The dusk composition remains the hero shot.
*Correction (June 11, after live instrumentation):* the "cat ignores daylight" report
was a misread — the cross-fade works perfectly (overlay alpha measured 1.0 at day); the
*art* is the issue: the same-pose awake regen differs from asleep only by the eyes,
illegible at sill size. Fix is a regen (head clearly raised), not code. Second nit
(fixed June 11): the sun's halo now feathers radially instead of showing a disc edge.

**Meadow — ★ astonishing for a one-night toy.** The calmed night world is bedtime
poetry; the territory mechanic is the only genuinely novel interaction in the box.
Needs from here: the day winter ground art, founder thumb-test on loop-closing
forgiveness, and a *day* judging pass (I only saw it after dark).

**Sleepy Box — ready, one stain.** Frontal body reads true, face legible, drawer
behaves. The **teal keying remnant still ghosts along the bottom-left edge** of the box
— thin but findable; a juror with a 5K display finds it. One more keying pass or a
2-minute paint-over.

**Mix-Up — strong, seams 90% there.** Cat assembled cleanly head-to-body; **feet
hover a hair below some bodies** (saw it on the cat). The seam constants are close —
worth a per-zone ±2pt sweep with three or four characters on screen. Theater staging is
delightful; the empty creations ledge is invisible until first save, which is fine.

**Stack — the tint system vindicated itself.** Felt + palette + faces coexist; the
hero's moon patch and capstone survived. *Nit:* the vignette glow oval behind the play
area has a perceptible boundary; soften or enlarge. Founder's reported touch issue
remains unreproducible headless — needs the one-line description (item 2, next session).

**Feed — the staging works; the cast breaks the spell.** Stand, counter depth, basket,
felt foods, want-bubble: all coherent. Then a balloon-headed procedural character with
glasses floats behind the counter and the whole frame drops two grades. The character
art batch is now *the* highest-leverage Feed work. Also: with the counter crop, the
current characters read as disembodied heads — even before new art, raising them ~10pt
would help.

**Hum — charming bars, wrong furniture, slow to wake.** The art frame sits like a
footrest under tower-tall bars (known, queued). Also noted: **the scene takes ~12-14s
to first render in sim** (tone-engine warmup?) — measure on device; if it's >1s there,
that's a real first-impression cost. The keyed frame also carries a faint shadow blob
underneath — re-key when the rail-bed regen happens.

**Drop Dots — better than its reputation.** The procedural board is honest and the
sleepy tokens are sweet. The column wells read heavy/dark for our palette. Landed art
(board, tray, tokens, tab) is in the catalog unwired — its session will mostly be
calibration, like Sleepy Box.

**Bubbles — the time capsule.** Flat-stroked bubbles queue oddly up the left edge over
a muddy tan void with a hard-edged glow ellipse. It's the only surface that predates
the art direction entirely. Room + pot art are landed and waiting; this wiring session
is overdue and will be cheap relative to its impact.

---

## If I ran tomorrow (priority order)

1. **Window cat-awake overlay bug** — generated art not appearing; charm regression.
2. **Bubbles wiring** — biggest visual delta per hour in the app.
3. **Hum frame geometry** (+ first-render time measurement on device).
4. **Feed character art batch** — prompts in Wren sheet format; everything else there
   is done.
5. **Sleepy Box bottom-edge teal** + **Mix-Up feet seam sweep** — one polish hour.
6. Drop Dots wiring, Stack vignette feather, sun halo feather — the quiet pass.

## What I'd tell the jury already
"No ads, no scores, no fail states, no text at the child — and the toys *settle*
instead of celebrate. The household clock runs through every room. One toy plants
spring with a snail. Built by two people and a toddler."

Sleep was had by none of the toys. They're all breathing on the shelf. — your new
teammate 🧡

---

## Appendix A — Approved magic moments (founder-blessed, into the build queue)

**Sleepy Box — the composed lullaby.** When the fourth shape is posted, the box hums
the four notes back *in the order the shapes went in*. The child wrote a tiny song
without knowing it; every round writes a different one.

**Drop Dots — the column wave.** Filling a column to the top runs one soft arpeggio
up its dots, bottom to lid. And once in a blue moon the tray holds a golden dot that
hums a fifth higher and makes its neighbors harmonize when it lands.

**Mix-Up — the bow.** If the three parts ever happen to match — one whole creature —
the spotlight warms and they take a single small bow. No fanfare, no banner;
recognition, not reward. (At night, the saved portraits on the ledge close their eyes.)

## Appendix B — Approved UX / UI / mechanics (founder-selected June 11)

**1. Feed — the sandwich ask.** Rarely a friend wants two foods stacked (bubble shows
them stacked). First compound request in the toybox: planning, sequencing, same one
verb. (S–M)

**2. Window — peek-a-boo curtains.** ⭐ *founder: HUGE.* Close the curtains fully,
open them again: one small thing outside changed (bird on the sill now, cloud moved
on, a star fell). Object permanence turned into a game the child invents themselves.
**The cue** (founder note: the child needs a reason to close them sometimes): the
curtains already have a fabric "peek" invite in code — when a change is armed behind
them, that invite gets fuller and slower, with a soft inward draft sound: the curtains
themselves whisper *close me*. Never a hand, never an arrow. (S)

**3. Meadow — landmark seeds.** Scatter 3–4 fixed landmarks across the world (a big
mossy rock, an old stump). Claiming the loop AROUND one wakes it: the stump sprouts,
the rock opens lichen eyes. Gives the endless world destinations — exploration with
purpose, still zero objectives on screen. (M)

**4. Drop Dots — honest weight.** Landing thunk pitch deepens as a column fills —
physical truth in sound, and a toddler's first bar chart for the ear. (S)

**5. Shelf parallax breath.** Two-point device-tilt parallax between shelf layers —
the room becomes a diorama you're holding. Respects Reduce Motion. (S)

**6. One paper, every room.** ⭐ *founder: LOVE.* A 2% linen grain overlay unified
across all toys — the print-like cohesion trick; jurors feel it before they can name
it. (S)

*(Liquid Glass for the parent area — the founder's own seed — lives in Plan session 11
where the parent surface gets built, pending final call there. The other second-coffee
ideas were cut.)*
