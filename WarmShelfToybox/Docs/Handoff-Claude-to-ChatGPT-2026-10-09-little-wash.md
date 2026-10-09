# Lull — Claude → ChatGPT handoff: build 6, then Little Wash

October 9, 2026. Branch `claude/modest-bell-cjarqm` in `interventionbluecamo-afk/lull`; pull first.
Mac checkout `~/Desktop/lull v.2`, project `WarmShelfToybox/Lull.xcodeproj`, scheme `Lull`.
All nine toys stay. The founder owns play, listening and purchase testing. **Upload only with
the founder's explicit approval.** Never commit signing keys.

## Part 1 — Build 1.0 (6) now (no Little Wash yet)

Everything from the founder's build-5 review is on the branch, written and verified on Linux
but **not yet compiled for iOS**. Read `Docs/Handoff-Claude-2026-10-09-founder-polish.md` (table
of commits) and `Docs/Polish-2026-10-09/Founder-choices-build6.md` §3 (what to check).

In short:
- **Sound.** Silent navigation and UI taps. Calm Sleepy Box, Window and Meadow. A real bubble
  pop. Loudness matched by ear, with repeats that soften.
- **Haptics** now strong enough to feel.
- **Drop Dots** colour matching is back.
- **Feed.** Food stays put; only the used plate refills; the counter is lower.
- **Wren** plays peek-a-boo.
- **Window** gets new sky visitors.
- **Bubbles bird** flies naturally.

`CURRENT_PROJECT_VERSION` is already **6**.

1. Pull. Build Debug (simulator) and Release (device). These were only parse-checked here, so fix
   any compile errors minimally and say so in the commit. Likely spots:
   - `GlowWindowScene` sky visitors (`launchKite`, `launchPaperPlane`…)
   - `BubbleScene.releaseBubbleBird` (weak captures of optional nodes)
   - `ToyShelfScene` Wren spots (`WrenSpot`, tuple placements)
   - `DropDotsScene` (`DropDotsHand`)
2. Run every `Tools/verify_*.py`: sound kit 2,606, lifecycle 57, Drop Dots 10, Feed 958 and the rest.
   Commit the logs to `Docs/Verification-build6/`.
3. Install Release on the founder's iPhone. Ask them to check System Haptics is on in iOS
   Settings. Stop there; they test.

## Part 2 — Little Wash replaces Stack (build 1.0 (7))

The founder chose it after research (`Docs/Polish-2026-10-09/Stack-replacement-overview.txt`).

**Wait for the art.** The founder generates it from `Docs/Polish-2026-10-09/Little-Wash-image-prompts.md`.
- Imageset names: `wash-fire-truck`, `wash-police-car`, `wash-tractor`, `wash-school-bus`,
  `wash-digger`, `wash-ice-cream-van`, `wash-wheel`, `wash-bay`, `wash-tool-sponge`,
  `wash-tool-hose`, `wash-tool-towel`, `wash-mud-1…4`, `shelf-wash-v2`.
- Build with procedural fallbacks so it runs before the art lands. Felt rounded-rect bodies and
  circles are fine; Claude's sketch is in the next bullet.
- An unfinished, untested canvas sketch of the toy is in
  `Docs/Polish-2026-10-09/little-wash-sketch/` (`carwash.js` uses the helpers in `engine.js`). It
  covers procedural felt vehicles, mud erasing, the three tools and completion; use it for
  reference only. The spec below is the source of truth.

### What the child does (the spec)

**Arrival.** A muddy vehicle rolls into a felt-and-wood wash bay through a little puddle splash.
Its face lives on the windshield: eyes follow the finger, cheeks warm as it gets cleaner.

**Washing.** Three big tools sit on a tray: sponge (default), hose and towel.
- Tap a tool to hold it; the finger carries it.
- Rub anywhere on the vehicle.
- **Any order works, and the sponge alone can finish** (a 2-year-old may never switch tools):
  - **Sponge:** mud fades under rubbing and turns to soft white foam. Foam slowly evaporates by
    itself after about 6–8 s.
  - **Hose:** rinses foam away fast and mud a bit faster, with falling droplets.
  - **Towel:** buffs and removes droplets and foam.

**Finished.** When it's clean (at least 93% of the mud gone, almost no foam):
- a sparkle sweeps across the silhouette;
- the face is delighted and does a small happy wiggle;
- its own soft toot plays;
- it drives off right, and the next one rolls in within 2 s.

**The cast and its order.**
- Shuffled order, never the same vehicle twice in a row.
- After the 4th wash, a rare guest about 1 in 8 times, once its art exists.

**Reactions** (rare, cute, never loud):
- giggles when scrubbed near the wheels;
- a tiny sneeze puff if foam covers the windshield;
- leans into the towel.

**Never:** a timer, a score, text, a fail state, sirens, or anything that plays on its own.

### Implementation plan

**Files.**
- New `App/Toys/Wash/WashScene.swift` (`BaseToyScene` subclass).
- New `App/Toys/Wash/WashModel.swift` holds the pure logic, with no UIKit/SpriteKit, so a verifier
  can compile it:
  - mud coverage math;
  - cast ordering;
  - completion rule;
  - the rig table: windshield face centre and radius, wheel centres and radii, all as fractions
    of each vehicle canvas.
  - Measure the rigs from the delivered art, like `FeedCatalog.json`.
- New files need entries in `Lull.xcodeproj` (or regenerate with XcodeGen from `project.yml`).

**Registry (`App/Shared/ToyRegistry.swift`).**
- Add `washID = "wash"` and a `ToyDescriptor(id: washID, parentName: "Little Wash", accentColor:
  WarmShelfPalette.waterBlue, accessTier: .free, isDemoReady: true, makeScene: { WashScene(size: $0) })`.
- In `launchToyIDs`, replace `stackID` with `washID` (same slot; it stays one of the three free
  toys).
- Keep `StackScene` and its descriptor in the code but off the shelf, like the other parked toys.
- Check what a saved "last toy" or a trial record holding `stack` does after the switch, and fall
  back gracefully.

**Vehicle node.**
- Body sprite plus `wash-wheel` sprites at the rig positions; wheels rotate while driving, and a
  slight body bob over bumps.
- A live face on the windshield: reuse an existing house face implementation (Wren's or the Feed
  friends' eye, pupil, cheek and mouth code).

**Mud (recommended v1).**
- 30–60 splat sprites from `wash-mud-1…4`, tinted with slight brown variation and scattered more
  thickly low on the body.
- Clip them to the vehicle with an `SKCropNode` masked by the body sprite.
- Each splat has a `dirt` value from 1 to 0. Touch strength falls off with distance from the
  finger and scales by tool: sponge 1×, hose 1.6×, towel 0.4×.
- Alpha follows `dirt`; coverage is the sum of `dirt`.
- No pixel buffers, so it's easy to verify in `WashModel`.
- A later upgrade could be a true erase mask (`SKMutableTexture` at 20 Hz or less).

**Foam, droplets and sparkle.**
- Pooled nodes: foam capped at about 80, droplets at about 60.
- Sparkle is a gradient sweep masked by the body.

**Layout.**
- Portrait: vehicle centred in the upper middle, tray along the bottom.
- Landscape: vehicle centred, tray at the bottom or the trailing side.
- iPad: scale up.
- Keep clear of the safe areas and the home handle. Bay art is aspect-filled.

**Sound** (follow the sound diet in `LullToneEngine.swift`: sound answers outcomes, nothing plays
on its own, warm and soft). Add cues to `LullSoundBook` and `cueIDs`:
- `wash.arrive`: a soft puddle splash using the existing `bubble` and `feltThump` primitives.
- `wash.foam`: very quiet Minnaert plips, rate-limited to about 3 a second while scrubbing.
  Scrubbing itself is silent; the haptic carries it.
- `wash.rinse`: a soft low water texture while the hose is held. Use a held note via
  `startHeldNote` or a short loop, fading on release, low-passed below about 1.5 kHz (no hiss or
  "sand").
- `wash.sparkle`: a `softPluck` arpeggio, about 4 notes.
- `wash.toot.<kind>`, one per vehicle:
  - fire truck: a gentle hummed "wee-woo", like Mix-Up's firefighter
  - police: a soft whistle
  - tractor: a low putt-putt
  - bus: a two-tone soft horn
  - digger: a low beep
  - ice-cream van: a three-note music-box phrase

Then run `Tools/verify_sound_kit.py`. Its cue scan checks that every cue the scene names exists.

**Haptics.** Use `HapticsManager.shared.impact`; the felt floor is already applied.
- Soft light pulses while scrubbing, at most about 6 a second.
- A success pulse on sparkle.
- The tool pick is felt.

**Accessibility.**
- VoiceOver labels: "Muddy fire truck. Rub to wash it." The tools are buttons.
- Activating the vehicle cleans a quarter of it.

**Reduce Motion.** No wiggle or bounce. Slide-ins become short fades. Sparkle becomes a soft glow.

**Verifier.** Add `Tools/verify_wash.py` (compile `WashModel.swift` like the other verifiers). Check:
- the sponge alone reaches completion in a bounded number of strokes;
- the hose is faster;
- completion needs foam to be nearly gone;
- the cast never repeats back-to-back over 1,000 draws;
- the rig fractions are within 0…1 and wheels sit inside the canvas.

### Copy and store updates

These still say "Stack". Change them to "Little Wash", or "Wash" where space is tight, and keep
"Bubbles, Little Wash and Drop Dots are free":
- `App/Shared/LullOnboardingViewController.swift`
- `App/Shared/ParentInfoViewController.swift`
- `App/Shared/LullDemoState.swift`
- `App/Shared/WarmShelfLaunchScene.swift`
- `App/Shared/LullHostNode.swift` (check context)
- `LandingPageDeploy/index.html`
- `LandingPageDeploy/support.html`
- `Docs/AppStore/SubmissionKit.md`: the description bullet becomes *"Little Wash: scrub muddy
  trucks clean with a sponge, a hose and a towel."* Also update the review notes' free-toy list.
- `Docs/AppStore/screenshots.json`: the Stack shot becomes the hero, a half-clean fire truck in
  foam.

Leave the code-comment mentions of Stack alone.

### Done means

- Builds clean; all verifiers pass.
- The founder can wash all six vehicles in portrait and landscape on iPhone and iPad.
- 60 fps on an iPhone 12-class device.
- Installed as 1.0 (7) for the founder's testing.
- Upload only with their approval.
