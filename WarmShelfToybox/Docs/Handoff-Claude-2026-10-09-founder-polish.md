# Lull — handoff: founder review of build 4 → polish pass (in progress)

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
