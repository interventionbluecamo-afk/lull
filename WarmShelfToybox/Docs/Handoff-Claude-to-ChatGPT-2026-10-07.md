# Lull — Claude → ChatGPT handoff: build, play-test, TestFlight 1.0 (2)

October 7, 2026. Read this first, then `Docs/Handoff-2026-10-07.md` (design pass 2) and
`Docs/ChatGPT-Art-Handoff-2026-10-07.md` (the art you delivered). Founder direction is
unchanged: ages 2–6, all nine toys (Bubbles, Feed, Stack, Sleepy Box, Window, Drop Dots,
Mix-Up, Hum, Meadow), warm tactile shelf, Apple Design Award quality bar.

## Source state

- Repository `interventionbluecamo-afk/lull`, branch **`claude/modest-bell-cjarqm`**. Code
  tip **`d43956b`** (the commit after it only adds this handoff and its PDF). It contains, in order on top of `main` (`c919d04`, TestFlight 1.0 (1)):
  - `9727fc9` Drop Dots seating, Sleepy Box posting, art despill tool
  - `b10749e` Feed shopkeeper counter, Meadow cohesion
  - `7ccd825`, `1f109f4` design pass 2 handoff, prompts, mocks, PDF
  - `5c57cbd` your 27 art masters (fast-forwarded in unchanged)
  - `d43956b` **this integration** (Feed cast + chew beat, top-down Meadow, dusk icon,
    build number 2)
- On the Mac: `cd ~/Desktop/"lull v.2" && git fetch origin && git checkout claude/modest-bell-cjarqm && git pull`.
  Build from `WarmShelfToybox/Lull.xcodeproj` in that folder (not the older ChatGPT
  checkpoint folders). No Swift files were added, so the Xcode project needs no regeneration;
  new imagesets live inside the existing asset catalog.
- Version **1.0 (2)**: `CURRENT_PROJECT_VERSION` is already 2 in `project.yml` and both
  build configurations in `project.pbxproj`. Bundle ID unchanged:
  `com.lull.toybox.a5ct5fk3sy`.

## What this integration changed

**Feed** (`CharacterNode.swift`, `FeedScene.swift`, 18 cast imagesets + 3 new `-6`)
- Runtime frames come from `Tools/Art/register_cast.py`: each expression is fitted (scale +
  offset) to its friend's neutral frame on the head-and-shoulders silhouette, then all six
  share one crop. Overlap with neutral rose from 92.5–98% to 98.5–99.7%. Masters untouched.
- `CastRig` (per friend, measured on the new neutral exports): head width 0.875 / 0.893 /
  0.933 of the canvas (grandmother / sprout / knithat), head centre 0.40 / 0.44 / 0.48 and
  mouth 0.505 / 0.52 / 0.573 from the top. The sprite is sized so the painted head is
  2 × headRadius and anchored on the head centre, so the mouth target, the warm flash and the
  want bubble sit on the face.
- Chew beat for the painted cast: surprised (5) for 0.18 s, then three chews alternating
  chewing (6, with a small cheek squash) and neutral (1), then happy (2). If the friend's wish
  was just granted, laughing (3) shows for 0.7 s before happy. Eating now lasts 0.93 s
  (`chewBeatDuration`) instead of 0.16 s. Every timed swap is keyed and cancelled by the next
  mood (the old surprise flash outlived the eating beat and could leave the laugh frame up
  during the happy beat).
- The counter hides the bottom 26% of a friend (was 30%), so a little collar shows instead
  of cutting at the chin.

**Meadow** (`MeadowScene.swift`, 7 imagesets)
- Rock, mushroom and pebbles (asleep + awake) and the dandelion come from
  `Tools/Art/export_pairs.py`: one shared crop per pair (alpha > 128, 4% padding),
  600 px max side; mushroom saturation −15% to sit with the felt palette.
- Fit boxes now match the cropped bodies: rock 112 × 109, mushroom 108 × 107, pebbles
  124 × 102 (visible ≈ 93%, about 2.4× the ladybug). All landmarks are top-down
  (`isTopDown`), so they get the small random turn. Clean-alpha art gets a soft contact shadow
  from code; stump and pond keep their baked one (`hasBakedShadow`). Dandelion fit 84 × 84.

**Icon** — every size in `AppIcon.appiconset` regenerated from your two layers (stone at 72%
of the height, resting on the hill). Composition kept at
`Assets/DesignPass-02/icon-composed-1024.png`. This is a flattened icon; a layered Icon
Composer version with dark and tinted appearances is still to do (see below).

## Verification done here (Linux, no Xcode)

- `swiftc -parse` passes on every changed Swift file.
- `Tools/verify_feed.py` updated to the new rig and made to run with any Swift toolchain
  (`xcrun swift` on the Mac, `$SWIFT` elsewhere). It **compiled and passed 89 checks** here with
  Swift 6.1 — the extracted production `CastRig`, `artMouthPoint`, `receivedFood` and serving
  bounds. That is real type-checking of those pieces only.
- Offline mocks from the real PNGs and the code's math: Feed with each friend and expression
  in portrait and landscape, Meadow landmark scale, icon at 60/40/29 pt on light and dark.
- **Not done**: an iOS compile of the whole app, any simulator or device run, gestures,
  sound, rotation, VoiceOver. Treat every claim above as unplayed until you check it.

## Your job, in order

1. **Build** for an iOS simulator and a device. Fix compile errors first; the earlier passes
   were also only syntax-checked (Drop Dots, Feed counter, Meadow surface, Sleepy Box). Run
   `python3 Tools/verify_feed.py` and your other `Tools/verify_*.py` scripts.
2. **Play-test** (iPhone portrait + landscape, iPad), and record pass/fail:
   - **Feed**: friend chest-up behind the counter for all three friends, bubble fully visible,
     head never clipped in landscape; each food reaches the mouth and is accepted at the painted
     mouth; a miss returns to its plate; fresh food rises from under the counter onto its
     plate; the eat sequence reads surprise → chew ×3 → happy without the body jumping
     (watch grandmother 2/4/6 and sprout 2/5/6); a granted wish laughs then smiles;
     rotation mid-chew doesn't leave a wrong face.
   - **Meadow**: new rock, mushroom and pebbles read clearly at play size by day and night;
     wake crossfades don't jump; touch footprints feel right; the dandelion blow → first frost
     → home garden reset works; painting looks like one soft surface to the world edges;
     frame rate stays smooth after several minutes; rotation keeps the garden.
   - **Drop Dots**: dots rest on the painted floor in the middle of each channel; four fill a
     column; a dropped dot vanishes into its ring and reappears in the channel; the pour goes
     behind the rail into the tray; a palm resting on the handle and sliding off does not pour.
   - **Sleepy Box**: every shape posts into its hole without drawing outside it.
   - **Icon**: home screen at real size on light and dark wallpapers; Settings and Spotlight.
   - **Smoke-play all nine toys**, the shelf, the grown-up area, rest/wake, sound off,
     Reduce Motion and background/foreground.
3. **Fix** what fails, keeping fixes small; note anything you defer.
4. **TestFlight 1.0 (2)** — only if step 2 passes on device:
   - Archive (Any iOS Device), validate, upload with the same team and bundle ID as build 1.
   - Add it to the Founder Testing group. Suggested *What to Test*:

     > New in build 2: Feed has a real shop counter, sharper friends and a chewing moment;
     > Drop Dots dots now sit in the board and drop through the rings; Meadow's ground and
     > landmarks are redrawn to look like one felt world; new app icon. Please try: feeding
     > each friend (right and wrong food), Drop Dots drops and the pull handle, a long
     > Meadow walk, and posting every Sleepy Box shape. Tell us anything that looks jumpy,
     > clipped, stuck or confusing, with your device and iOS version.

   - Record the result in `Docs/TestFlight-Release-…md` the way build 1 was recorded.

## Known risks to watch

- Whole-app iOS compile has not happened for any of the Claude passes; expect a few fixes.
- Feed cast art is ~21 MB (18 PNGs at 760 px wide); consider asset-catalog lossy compression
  if app size matters.
- Mushroom red: muted 15%; judge it in the scene before regenerating anything.
- Registration fixed the silhouette, not texture: small shawl/sweater differences between
  frames may still flicker during the chew. If it bothers you, reduce to chew (6) ↔ chew (6)
  squash only, dropping the neutral in-between frame in `chewBeat(member:)`.
- `register_cast.py` takes ~6.5 minutes for the three friends (brute-force fit).

## Still open after this build

- Feed: a calm "not that one" for wrong food (today every food is accepted warmly).
- Icon: layered Icon Composer file from `ArtDrops/2026-10-07/icon-bg.png` and
  `icon-stone.png` with dark/tinted appearances.
- Mix-Up duplicate cast art (Queen = King copy), Window dead code, Drop Dots rainbow sort,
  and audits of Stack, Bubbles, Hum and the shelf.
- Before external testing: privacy-policy link, real support address, StoreKit product,
  trial model, grown-up check strength, timer policy.

Keep usage in reserve and leave a handoff when you stop.
