# Lull — handoff: founder reviews of builds 4 and 5 → polish passes (in progress)

October 9, 2026. Branch `claude/modest-bell-cjarqm` (`interventionbluecamo-afk/lull`). Read this
first if you are picking up from Claude. It is updated as work lands; the last section says what
was still in flight when it was written.

## Founder review of build 4 (verbatim summary)

- Loading screen cute. Home screen clean; felt theme missing there but **leave it alone for now**.
- **Tapping into a game makes an odd sand sound** — unpleasant.
- Bubbles: no comments.
- **Feed:** in landscape the request bubbles fall off the screen; needs more character diversity;
  rotate some foods between plays (e.g. carrot → grape on play 2); landscape touch area near the
  mouth doesn't find the food.
- **Stack:** gets boring quickly, missing the felt feel, the tower doesn't make sense in
  landscape — maybe change the game up.
- **Sleepy Box:** awesome, but sounds a bit harsh; shapes could change location on the box now and
  then, maybe a new box slides in.
- **Drop Dots:** still lining-up issues, some colours never come down; bigger dots and fewer
  columns would look better.
- **Hum:** awesome; keys should be more expressive when hit.
- **Meadow:** awesome; wants a trail of flowers, cleaner map edges, maybe a little globe.
- Overall: close; needs bug fixes and polish.

## Done and pushed

- `f542453` — **sound softening.** Entering a toy is a warm two-note kalimba (no noise whoosh);
  touch lifts and empty taps are a soft felt "pff" (no hiss); Sleepy Box drawer, bumps, tumbles,
  hover and box landing are rounder and quieter; rustle/air primitives darkened kit-wide; room beds
  moved below ~1 kHz (they read as sand/static on a phone speaker before). Sound kit 2,486 and
  lifecycle 53 checks pass. All in `App/Shared/LullToneEngine.swift`.
- Earlier today: new sound engine (build 4, installed on the founder's iPhone), Mix-Up robot /
  police officer / firefighter (build 5 source, `0679441`), security fixes. See
  `Handoff-Claude-to-ChatGPT-2026-10-08-sound.md`.

## In flight when this was written

Six toy fixes are being made in parallel on local branches (`claude/polish-feed`, `-stack`,
`-sleepybox`, `-dropdots`, `-hum`, `-meadow`, all based on `0679441`), then reviewed together and
merged into `claude/modest-bell-cjarqm`. **Local branches are not on GitHub until merged.** If this
handoff is the latest thing on the branch and those commits are missing, redo them from the plan:

| Toy | Plan |
|---|---|
| Feed | Clamp the wish bubble on screen in every orientation; fix landscape mouth acceptance (CastRig mouth at landscape scale, forgiving radius) and extend `Tools/verify_feed.py` to landscape; rotate the menu between plays from existing foods and auto-adopt new food imagesets (grape, pear…); make the cast data-driven so new friends join when their six `feed-cast-<name>-1…6` imagesets exist; prompts for 3 new friends and new foods. |
| Stack | Redesign within the scene: felt stones in the palette with sleepy faces that wake when placed, varied shapes per refill, a payoff when tall (a bird lands and sings, stones hum bottom-to-top), a soft funny topple, a landscape layout that makes sense (two spots or stepping stones). Free toy — must be great. |
| Sleepy Box | Every second completed round the box slides away and a fresh box slides in with the four holes rearranged (valid on all sizes; posting/clipping follows the holes). |
| Drop Dots | Find and fix "some colours never come down"; re-measure so dots sit centred on the painted floor; 4 bigger columns via a derived 4-channel board image. |
| Hum | Bars dip and spring back like real xylophone keys, a warm glow/ripple, expression scaled by tap speed, a breathing glow while a held bar sings; no node leaks; Reduce Motion. |
| Meadow | A pooled trail of small felt flowers behind the ladybug; endless world without visible edges (wrap-around or soft bounds); evaluate a small-planet curvature, implement only if safe, else a written plan. |

Rules that held for all of it: keep all nine toys; ages 2–6, calm; portrait + landscape + iPad within
safe areas; Reduce Motion; no edits to the sound files by toy work; verify with `swiftc -parse`,
`Tools/verify_*.py` (`SWIFT=…/swift` on Linux, `xcrun swift` on the Mac) and offline mocks; the
founder owns device testing; upload only with the founder's explicit approval.

## Next steps for whoever continues

1. Pull. If the six polish commits are merged, build Debug + Release on the Mac, run every
   `Tools/verify_*.py`, install on the founder's iPhone, and let the founder test. The next build
   number is in `project.yml` (`CURRENT_PROJECT_VERSION`).
2. If some are missing, redo them from the table above (one toy at a time, smallest first:
   Sleepy Box, Hum, Drop Dots, Feed, Meadow, Stack).
3. Art the founder may generate (prompts in `Docs/Polish-2026-10-09/` once merged, and
   `Docs/AppStore/ArtReview-2026-10-07.md`): Feed friends and foods, felt Stack stones, Meadow
   flowers, Wren in felt, Feed food set, Sleepy Box shapes.
4. Still open from before: GitHub repo is public (founder: make it private), support domain/email,
   store screenshots, website hosting, Paid Apps Agreement, Kids age band, trial model decision.


## Completed continuation — October 9

All six fallback polish changes are implemented, SDK-built and installed as 1.0 (5). Read [the current ChatGPT handoff](Handoff-ChatGPT-to-Claude-2026-10-09-build5.md) and its verification logs before continuing. Founder device approval is pending; this turn did not upload TestFlight.


## Founder review of build 5 (October 9, evening) — Claude's pass, in progress

Verbatim summary: Feed — food should refill only on the plate a child used (no moving or random
respawns while a child may want it next); the counter is a little high for some friends. Stack —
"doesn't make sense to have a bird here… replace this game with something completely new, 3 options
for me". Drop Dots — "why did you remove the colors from the holes… so a kid can match it, and then
make 3 in a row". Bubbles — more of a bubble *pop* sound; a more natural bird visually. Window — the
sky-tap sound is "horrible" day and night; more special visitors like the hot-air balloon. Sleepy Box
— "sounds are harsh STILL… PLEASANT AND CALM!!!!!!!". Meadow — what is the "random tone"; ideas to
improve it. General — home button sound harsh; "every single tap is a sound", switching toys is "TOO
MUCH"; haptics not felt; tapping Wren should wiggle him off and pop up elsewhere around the edges.

### Landed (pushed to `claude/modest-bell-cjarqm`)

| Commit | What |
|---|---|
| `6697f6c` | **Sound diet.** Rules: sound answers an outcome, never a bare touch; nothing plays on its own; warm and round, not bright metal or noise; loudness matched by ear (BS.1770 pre-filter), all buses −3 dB; rapid repeats of a touch sound step down to 40% (never music). Shelf card, home button, empty felt and Wren taps are haptic only; entering and leaving a toy is silent. Sleepy Box: lift/hover/drawer travel/rattle silent; the drop is a soft landing plus the shape's own felt-piano note (no hollow-box knock); the treasures roll out on a soft falling run. Window: sky taps silent (were a high glockenspiel); dial, lamp, curtain and plant softer; curtain drag silent. Meadow: the "random tone" was the idle invite (a note with the ladybug's wing flutter every 7.5 s), plus a random glockenspiel note every 0.4 s while she walked, a note per flower and random background birds — all removed. Bubbles: a real soap-bubble pop; no chime per neighbour in chains. New `softPluck` voice replaces the glockenspiel outside Hum and Mix-Up. |
| `70eefb3` | **Haptics felt.** Toys asked for 6–46% strength, mostly `.soft` (the faintest) — under what a hand notices. Requested strengths now map onto a felt range per style (soft ≥ 0.55, light ≥ 0.45, rigid ≥ 0.40); pulses within 60 ms merge. If still not felt: iOS Settings → Sounds & Haptics → System Haptics must be on. |
| `2cb3a11` | **Drop Dots colours.** Build 5 dropped the sage ring but kept five dot colours with exactly one dot each, so matching and three-in-a-row were impossible. Dots now use the four ring colours; the visible hand is six dots (one per ring plus a triple, colour changes per visit); the rim warms in the dot's colour over its home hole and glows when it lands there. `Tools/verify_dropdots.py`. |

Verification on Linux for all of the above: sound kit 2,606 checks; engine lifecycle 57; Drop Dots 10;
Feed 958, Hum 10,367, Mix-Up 399 + 280, adult gate, onboarding and rest verifiers pass; `swiftc
-parse` on every changed file. `verify_window.py` and `verify_world_interactions.py` need macOS.
**Not done here:** an iOS build and listening. The next build is 1.0 (6).

### Still to do in this pass (in order)

1. Feed: refill only the used plate; lower the wish counter slightly for some friends.
2. Wren peek-a-boo: tap → wiggles off the edge → pops up at another edge spot (quiet; reuse art).
3. Bubbles: a more natural bird (flight path, wing beats); Window: more rare visitors like the
   hot-air balloon.
4. Three options for a completely new toy to replace Stack (founder chooses); Meadow game ideas.
