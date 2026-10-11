# Build 10 pass: free toys, play timer, Meadow little ones, Drop Dots

**Living plan.** Claude updates this file after every step and pushes it. If Claude runs out,
ChatGPT (or anyone) continues from the first unchecked step in §3, following the spec in §4.

- Branch `claude/modest-bell-cjarqm`, repo `interventionbluecamo-afk/lull`. Pull first.
- Commits are pushed after each step.

## 1. Founder decisions (October 11)

| Topic | Decision |
|---|---|
| Free toys | **Bubbles, Drop Dots, Hum** are free forever. **Little Wash becomes paid**, joining Feed, Mix-Up, Meadow, Sleepy Box and Window. |
| Play timer | Counts **per sitting** and **survives force-quit**. After the rest, only a grown-up wakes Lull. A fresh sitting starts after **1 hour away**. |
| Timer in the welcome | Must be **clear**: the welcome shows the play timer (pre-set to 30 min) and the wind-down hour, and where to change them. All family controls clean, accessible, obvious. |
| Meadow | "Find the little ones": baby ladybugs hide, join her, and follow in her steps, **hopping between the flowers** without squashing or re-blooming them. She leads them home to a leaf house. **Art from ChatGPT** (prompts in §5); the code works with a stand-in until the art lands. |
| Drop Dots | Now a free toy, so it must hold up. Today there are too few chances to match and it gets repetitive fast. |

The feature freeze is lifted for exactly these items. Build number goes to **10**: build 9 may
already have been uploaded by the Mac, and skipping a number is harmless.

## 2. What exists today (findings)

- **Free tiers:** `App/Shared/ToyRegistry.swift`, `accessTier:` on each toy. Bubbles, Little Wash
  and Drop Dots are `.free`. The child's shelf hides paid toys when locked, so the free shelf
  is exactly the free set.
- **Play timer:** `LullPlayTimer` in `App/Shared/AdultGate.swift`.
  - It counts foreground time in memory only (`accumulated`, `lastResume`).
  - A force-quit or relaunch starts again from zero.
  - `restPresented` isn't persisted either.
  - Setting: `LullDemoState.playTimerMinutes` (0 means off).
- **Welcome:** `App/Shared/LullOnboardingViewController.swift` has 3 pages:
  1. Welcome.
  2. Wind-down hour only ("When does the day wind down?", hour pills).
  3. Plans.

  The play timer is **not in the welcome at all**.
- **Grown-up area:** `ParentInfoViewController.render()`. Under "FAMILY CONTROLS":
  - one card with Sound, Haptics and Calmer motion;
  - one card with Play timer and Wind-down hour (option pills);
  - then Choose shelf toys and the plans card.
- **Meadow:** `App/Toys/Meadow/MeadowScene.swift` (1,885 lines).
  - She walks where she's led.
  - `MeadowFlowerTrail` stamps flowers behind her, 26 pt apart, alternating ±5 pt to each
    side, in a 64-slot ring buffer.
  - `MeadowSnap` carries the world across size changes.
  - Sounds only for outcomes: a friend wakes, a patch blooms, full spring, first frost.
- **Drop Dots:** `App/Toys/DropDots/DropDotsScene.swift`.
  - The board has 4 columns × 4 rows. Ring colours: rust, butter, blue, lavender.
  - Each visit deals **6 dots** (`totalTokens = 6`, `DropDotsHand.deal()` gives one of each
    colour plus two extra of one random colour).
  - All 6 sit visible in a one-row tray; there's no hidden reserve (founder, June 15).
  - So **only one colour can ever make three in a row**, and the 16-hole board can never fill
    ("board full" is unreachable).
  - Delights:
    - "home" glow when a dot lands under its own colour;
    - three-in-a-row glow;
    - column wave when a column fills to the top;
    - a rare golden dot (1 in 40);
    - pour-out pull.
  - Verifier: `Tools/verify_dropdots.py`.

## 3. Steps (check off as done; each ends with a commit and push)

- [x] **0. This plan committed.**
- [x] **1. Free toys swap.**
  - `ToyRegistry`: Hum `.free`, Little Wash `.fullToybox`.
  - Copy everywhere "Bubbles, Little Wash, and Drop Dots" appears becomes "Bubbles, Drop Dots,
    and Hum": the app (onboarding, plans card), site templates (index tags, plans, support,
    press) plus a rebuild, SubmissionKit, the checklist, the handoff, Website.md and the
    screenshots spec.
  - Check the verifiers for the free set.
- [x] **2. Play timer per sitting, survives relaunch.** Spec §4.1. Add `Tools/verify_play_timer.py`.
- [x] **3. Welcome page 2: "Your family's rhythm".** Spec §4.2.
- [x] **4. Grown-up area: a clear play timer card.** Spec §4.3.
- [x] **5. Drop Dots: more matches, more to discover.** Spec §4.4. Update `verify_dropdots.py`.
- [x] **6. Meadow little ones.** Spec §4.5. Add `Tools/verify_meadow_little_ones.py` for the
  pure model.
- [ ] **7. Build 10.**
  - `CURRENT_PROJECT_VERSION` 10 in `project.yml` and `Lull.xcodeproj/project.pbxproj`
    (2 places).
  - Syntax-check every changed Swift file.
  - Run every verifier that runs on Linux.
- [ ] **8. Handoff for ChatGPT.**
  - Art prompts (§5).
  - Build 10 compile and TestFlight; What to Test.
  - What needs eyes on a device: Drop Dots tray layout, Meadow parade, welcome page 2.

## 4. Specs

### 4.1 Play timer (per sitting, survives force-quit)

- Persist in `UserDefaults`:
  - `lull.timer.played` (seconds played this sitting);
  - `lull.timer.lastActive` (when play last paused or stopped);
  - `lull.timer.resting` (the rest is showing and waiting for a grown-up).
- Count time only while active. On pause (resign active), add to played time and save. Also
  save on every 20-second tick, so a crash or force-quit loses at most 20 seconds.
- When the app comes back:
  - **1 hour or more** since `lastActive`: a fresh sitting. Played time goes to 0 and the
    rest clears.
  - **Less than an hour:** keep counting from the saved time. If `resting` is set, show the
    rest again straight away. Force-quitting must not skip it.
- A grown-up waking Lull (`parentWoke`) or changing the timer starts a fresh sitting
  (played time 0, rest cleared).
- The timer only appears over child play screens (unchanged). Parent screens and purchases
  stay usable.
- Keep the counting logic UIKit-free (a small struct) so a verifier can run it on Linux.

### 4.2 Welcome page 2 — "Your family's rhythm"

- Eyebrow `YOUR FAMILY'S RHYTHM`. Title "Play, then rest." (short, warm).
- **Play timer first.** One line: "Lull rests after this much play. Only a grown-up can wake
  it." Big pills `Off · 15 · 30 · 45 · 60 min`, with **30 pre-selected** on a first welcome.
  A replayed welcome shows the current setting.
- A small, calm preview of the rest: the moon veil.
- **Wind-down hour second** (the existing pills), one line: "After this hour, play turns
  warmer and sleepier."
- Footer line, with a picture of the button: "Change these anytime: tap the small person button
  at the bottom right of the shelf. Sound, haptics, calmer motion and which toys are on the
  shelf are there too."
- Accessibility:
  - each pill has a VoiceOver label ("Play timer, 30 minutes") and the selected trait;
  - Dynamic Type; 44 pt minimum targets.
- The choice is saved in `finish()` (along with the wind-down hour). A fresh sitting starts
  when it's saved.

### 4.3 Grown-up area — play timer card

- First thing under the header, before the sound, haptics and motion card: its own card titled
  "Play timer".
  - A status line: "Lull rests after 30 minutes of play. 12 minutes played this sitting." When
    off: "Off. Lull never rests on its own."
  - The pills.
  - "Wind-down hour" moves into the same card under it, titled "Rhythm" or kept separate if
    cleaner.
- Pills are accessible buttons with labels and the selected trait.

### 4.4 Drop Dots — more matches, more to discover

Goal: a 2–4-year-old always has many ways to make something happen, with no failure and no
score.

- **The hand: 12 dots, 3 of each colour** (`totalTokens = 12`; `DropDotsHand.deal()` gives
  3 × each of 4 colours, shuffled).
  - Every colour can now fill its own column (sorting) and make three in a row.
  - All 12 stay visible (the founder's finite-set rule).
- **The tray holds 12 in two rows of 6.**
  - Portrait: two troughs, front and back, the back one slightly raised. Reuse the
    `dropdots-tray` art twice.
  - Landscape: two racks side by side.
  - The cell budget is adjusted so the board still fits.
  - Slot spacing stays at least the dot diameter.
- **New discoveries** (each visual plus one soft cue; never a score):
  1. **Home column:** a column holding three or more of its own colour → its ring glows and
     the column sings its colour (the existing wave, coloured).
  2. **Rainbow row:** four different colours across one row → a soft rainbow shimmer along the
     row.
  3. **All sorted:** every dot in its own colour's column → finale. All four rings glow in
     turn, the dots do a happy hop, one warm chord, then the pull-tab invites a pour.
- **Existing delights stay:** home glow, three in a row, golden dot, pour.
- **"Board full"** is still unreachable with 12 dots and 16 holes. Remove that dead path or
  leave it harmless. All sorted is the new finale.
- **Variety across pours:** each pour deals a freshly shuffled hand. The golden dot stays rare.

### 4.5 Meadow — find the little ones

- **Five little ones per visit**, hidden at spread-out spots (not at the start spot, not near
  edges, at least 120 pt apart, never on her current flower trail).
  - Each shows only a peeking hint (a tiny bit under a leaf, a mushroom or a flower, which
    sways now and then).
  - New spots each visit (each fresh scene).
- **Found:** when she walks within about 64 pt of one, it pops out, does a happy hop, and joins
  the parade.
  - One soft cue: an outcome, allowed by the sound diet. A light haptic.
- **Parade:**
  - The babies follow her own path (a breadcrumb history of her positions), about 30 pt apart,
    in a line.
  - Each baby is drawn above the trail layer but small. When its spot is within about 12 pt of
    a flower in `MeadowFlowerTrail`, it **hops** over it (a higher arc), so it never sits on or
    covers a flower.
  - The babies **never** stamp, bloom or change flowers.
- **Leaf house:** grows in gently (spot chosen away from her start) when the first baby joins.
  - When she walks near it with followers, each baby hops in, one at a time; the house glows a
    little warmer per baby.
  - All five home → finale: a warm glow, soft sparkles, one gentle chord.
  - No counter anywhere.
  - Babies that aren't found stay hidden. Nothing fails or times out.
- **Carry across rotation:** add the little ones and the house to `MeadowSnap` (found or
  hidden, positions, home count).
- **Reduce Motion:** no hops (babies glide); the finale glows without sparkles.
- **Art** (from ChatGPT, §5): `meadow-baby-ladybug`, `meadow-leaf-house`,
  `meadow-leaf-house-glow`, `meadow-hide-leaf`.
  - Until those exist, the code uses stand-ins: the existing ladybug art at about 0.42 scale
    for babies, and a code-drawn leaf dome for the house.
  - Load with `ToyArt.texture(...)`, falling back when nil.
- **Pure model** (`MeadowLittleOnes`, UIKit-free): hiding spots, find radius, parade follow,
  flower-hop test, home logic. `Tools/verify_meadow_little_ones.py` checks:
  - spacing;
  - not on the trail;
  - found within radius;
  - the parade never stamps flowers;
  - a hop over each flower;
  - all home → finale once.

## 5. Art prompts for ChatGPT (Meadow)

Match the existing Meadow and ladybug art: felt and wood, soft studio light, transparent PNG,
no text. Faces stay off the art; faces are live code.

1. `meadow-baby-ladybug.png`, 512 × 512, transparent.
   - A tiny felt ladybug baby, rounder and softer than the mother: a short red felt shell with
     three big black felt spots, a small black felt head, two little wool antennae with
     butter-yellow pom tips.
   - Seen from above at the same three-quarter angle as the mother ladybug, centred, with a
     soft contact shadow. No eyes or mouth.
2. `meadow-leaf-house.png`, 768 × 768, transparent.
   - A cosy little house made from one big curled sage-green felt leaf, standing on a small
     wooden base with moss.
   - A round doorway (dark felt inside), a tiny wooden step, two small felt flowers beside the
     door, warm soft light. Matches the Meadow's palette.
3. `meadow-leaf-house-glow.png`, 768 × 768, transparent.
   - The same house, framed identically, at dusk: warm golden light glowing from the doorway
     and through the felt.
4. `meadow-hide-leaf.png`, 256 × 256, transparent.
   - One broad sage felt leaf with a visible stitched vein, lying flat, slightly lifted at one
     edge (where a little one peeks out).

Add them to `App/Resources/Assets.xcassets/` as image sets with the same names (1x
universal, like the other Meadow art). The code picks them up automatically.

## 6. Status log

- Oct 11: plan written.
- Oct 11, step 1 done:
  - `ToyRegistry`: Hum is `.free`, Little Wash `.fullToybox`. (Glowboard, Stack and Bloom are
    `.free` but aren't in `launchToyIDs`.)
  - Copy updated in the app, site (Free tags; free toys listed first), SubmissionKit,
    Website.md and the plans handoff. Site rebuilt.
  - No verifier depends on the free set.
- Oct 11, step 2 done:
  - `LullPlaySitting` (a UIKit-free struct in `AdultGate.swift`) holds played time, last active
    and resting. `LullPlayTimer` saves it every 20-second tick and on pause.
  - On launch or return: a rest that was showing comes straight back (retried every second
    until a child screen is in front). An hour away lifts the veil by itself
    (`LullRestViewController.wakeWithoutGrownUp`).
  - `Tools/verify_play_timer.py`: 14 checks pass.
  - Needs a device check: force-quit while the rest is showing, then reopen. The rest returns.
- Oct 11, step 3 done:
  - `rhythmPage()` replaces `windDownPage()` in `LullOnboardingViewController`, with:
    - a play timer card: pills Off/15/30/45/60, a live status line, a moon-rest note;
    - a wind-down card: pills 5–9 pm, matching the grown-up area;
    - a "change these anytime" card showing the real person button.
  - 30 minutes is pre-selected only if no timer was ever chosen (new
    `LullDemoState.hasChosenPlayTimer`). `finish()` saves the timer.
  - The new page uses Dynamic Type; pills carry VoiceOver labels and the selected trait.
  - Needs a device check: the page fits on a small iPhone (it scrolls if not).
- Oct 11, step 4 done:
  - The grown-up area's first card is now the play timer (labels "15 min" etc.) with a live
    line: "Lull rests after 30 minutes of play (12 played this sitting). Only a grown-up can
    wake it…". The wind-down hour sits in the same card.
  - Sound, haptics and calmer motion follow, then the shelf toys and plans.
  - Pills were already accessible: label and selected trait.
- Oct 11, step 5 done (`DropDotsScene.swift`):
  - **Hand:** 12 dots, 3 of each colour (`DropDotsHand.perColour`).
  - **Tray, portrait:** two troughs. The back one is 1.3 cells up and drawn behind.
  - **Tray, landscape:** two racks; the board shifts right to keep the group centred.
  - **Cell budget:** +1.3 cells (portrait) and +1.3 (landscape width).
  - **Discoveries:** the new pure `DropDotsDiscoveries` has home columns, rainbow rows and
    sorted. In the scene, `refreshDiscoveries` gives one song per landing:
    - all sorted → `sortedFinale` (rings glow in turn, dots hop, "dots.full.board", then the
      tab invites a pour);
    - else a home column → `homeColumnSong` ("dots.pattern");
    - else a rainbow row → `rainbowShimmer` ("dots.wave").

    The three-in-a-row chime and the column wave stay silent when a bigger discovery sings.
    Rotation, sending a dot back and pouring re-notice silently.
  - **Golden dots:** 1 in 80 per dot (about the same per visit).
  - **VoiceOver:** "drop" picks the dot's own colour column first.
  - **Verifiers:** `verify_dropdots.py` passes 13 checks. `verify_world_interactions.py`
    is updated for the 12-dot hand (macOS only; run it on the Mac).
  - **Needs a device check:** the two-row tray in portrait and landscape on a small iPhone, an
    iPhone Pro Max and an iPad. Dots must not overlap the trough lips, and the board shouldn't
    feel cramped. If the back trough's art looks odd, a single taller tray is the fallback.
- Oct 11, step 6 done:
  - **New file** `App/Toys/Meadow/MeadowLittleOnes.swift`, added to `Lull.xcodeproj`
    (file reference, build file, Meadow group, Sources). XcodeGen picks it up from `App/`.
    It contains:
    - `MeadowSeededRandom`;
    - `MeadowLittleOnesModel` (pure): hiding spots, find radius 64, parade 30 apart along her
      path, `flowerHop` lift and sideways nudge within 16 pt of a flower, house in the home
      garden, a snapshot;
    - `MeadowLittleOnesNode` (SpriteKit): leaves that rustle; babies that lean out as she nears;
      pop-out and join; the parade with hop scale; the house growing in at the first find;
      hop-in at the door with a glow per baby; an all-home finale with sparks.
  - **Art:** uses ChatGPT's art when present (`meadow-baby-ladybug`, `meadow-leaf-house`,
    `meadow-leaf-house-glow`, `meadow-hide-leaf`). Otherwise: her own art small, and a
    code-drawn leaf house and leaves.
  - **`MeadowScene`:**
    - `buildLittleOnes` in `rebuild`;
    - stepped every frame in `update`;
    - `MeadowSnap.littleOnes` plus a per-visit seed for rotation;
    - `answerLittleOnes` sounds: a pluck when one joins, rising plucks as they go in,
      "meadow.fullspring" when all are home. Light/soft haptics.
  - `Tools/verify_meadow_little_ones.py`: 12,820 model checks and 6 scene checks pass.
  - **Needs a device check:**
    - babies' size beside her and the flowers;
    - the hop reads as hopping;
    - the house is visible at home;
    - Reduce Motion;
    - the finale.
