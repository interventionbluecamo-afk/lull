# Build 11 pass: founder notes after build 10

**Living plan.** Claude updates this file after every step and pushes it. If Claude runs out,
ChatGPT continues from the first unchecked step in §3, following §4.

- Branch `claude/modest-bell-cjarqm`. Pull first.
- ChatGPT's local Mac work from build 10 was **not pushed**. If ChatGPT has compile fixes on the
  Mac, commit them to this branch before starting here, and resolve any conflicts in favour of
  both.

## 1. Founder notes (October 11, from playing build 10)

1. **Little Wash:** vehicles sit well above the ground in portrait on iPhone, and a bit too high
   in landscape.
2. **Drop Dots:** still gets boring quickly. Not enough dots for many combinations. "Maybe a new
   set of colours slides out."
3. **Sleepy Box:** loved. But the holes on screen don't line up realistically with the box.
4. **Mix-Up:** the room and stage are ugly, and the room cuts off harshly above the heart button.
5. **Purchases:** pricing and benefits shouldn't share a page with settings.

## 2. Findings

### Wash (`App/Toys/Wash/WashScene.swift`, `buildLayout`)

- `wash-bay` (1448 × 1086) is aspect-filled and centred on the screen.
- The vehicle's home comes from the tool tray and play rect only. Nothing ties the wheels to
  the painted floor.
- Every rig's wheel bottoms sit at about **0.88 of the vehicle canvas height** (fire truck
  0.881, tractor 0.880, digger 0.880).
- In portrait the bay is height-filled, so its floor (below the wall seam) only covers the
  bottom third. The vehicle sits above the tray, higher than that.

### Sleepy Box (`App/Toys/SleepyDropBox/SleepyDropBoxScene.swift`, `buildPlainShell` / `buildOpenings`)

- The shell is `sleepybox-v2-shell`, cropped to 1065 × 946. Measured from the crop's top:
  - lid top surface 0.01–0.07;
  - lid front lip 0.074–0.09;
  - **front face 0.095–0.745**;
  - drawer recess 0.75–0.95;
  - bottom rail 0.95–0.99;
  - front face horizontal span 0.02–0.98.
- The code centres the 2×2 hole grid at fy 0.34 with rows at fy 0.18 and 0.50.
- On a phone the holes are 2.2·r ≈ 81 pt on a 312 pt box, so the **top row spans
  fy 0.05–0.31 and overlaps the lid**. The holes look pasted on.
- The face anchor is at fy 0.71 (faceH 0.20), crowding the drawer recess at 0.75.
- Mock render: `scratchpad/art/sleepy-both.png` (not committed).

### Mix-Up (`App/Toys/MixUp/MixUpScene.swift`, `addRoom`)

- A procedural cream wall, a flat `floor` rectangle from y = 0 to `floorY` with a hard seam
  line, and a plain pedestal (a rect plus an ellipse). The heart sits below the floor line, so
  the floor's top edge reads as a harsh cut above it.
- Authored art exists but is unused:
  - `mixup-room` (a wooden theatre frame with shelves and a felt back panel);
  - `mixup-stage` (a round wooden stage with a felt top and carved stars);
  - `mixup-curtain-valance` and `mixup-curtain-swag-left/right` (red felt).
- They were removed on purpose on October 7: "ornate red/gold generated theatre replaced with
  a cream room" (`Docs/MixUp-Room-Layout-2026-10-07.md`).
- The shelf card (`shelf-mixup-v2`) still shows a red-curtained stage.

### Purchases (`App/Shared/ParentInfoViewController.swift`)

- The plans card (`makeStatusHero`, `makePlanTile`, `makeHeroNote`, purchase, restore and
  manage actions, `loadPurchaseOptions`) sits in the middle of the settings scroll.

### Drop Dots

- Build 10 has 12 dots (3 per colour) in a two-row tray, home columns, rainbow rows and an
  all-sorted finale.
- Ring colours are part of the board art (`columnRimColors` sampled). The front ring lips are
  sliced from the art.

## 3. Steps (check off as done; each ends with a commit and push)

- [x] **0.** This plan, plus the founder's answers on Drop Dots and the Mix-Up room (§5).
- [x] **1. Purchases on their own page.** `LullPlansViewController` holds the plans card and all
  purchase actions.
  - The grown-up area keeps a single compact "Full Toybox" status row with a chevron that
    opens it.
  - The welcome's "Try all nine free" opens the plans page directly (behind the adult check).
- [x] **2. Wash: wheels on the floor.** Measure the bay's floor contact line. Fit the bay so that
  line sits under the wheels (still covering the screen) in portrait and landscape. Verifier
  over device sizes.
- [x] **3. Sleepy Box: holes on the front face.** Use measured shell fractions for the hole grid,
  hole size and face. Mock renders for phone and iPad, portrait and landscape. Verifier.
- [x] **4. Mix-Up room** (per the founder's answer, §5).
- [x] **5. Drop Dots** (per the founder's answer, §5).
- [ ] **6. Build 11.** Version bump, parse, verifiers, handoff.

## 4. Specs

(Filled in as each step starts.)

## 5. Founder answers

- **Drop Dots: new colours each round.**
  - After a pour, a fresh felt set slides in with four new colours (fruit, sky, garden,
    night…).
  - The rings re-tint to match. Same calm play, no rules.
- **Mix-Up: felt theatre, like the shelf card.**
  - Bring back the authored art: the round wooden stage `mixup-stage`, the red felt curtains
    `mixup-curtain-swag-left/right` and `mixup-curtain-valance`, on a soft floor.
  - No hard floor line. Keep the October 7 layout gains (control lane, character fit,
    keepsake cards).

## 6. Status log

- Oct 11: findings and plan written.
- Oct 11, step 1 done:
  - **New `App/Shared/LullPlansViewController.swift`** (added to the Xcode project) holds the
    plans card, the tiles, the subscription terms, Terms/Privacy, Manage, Restore and every
    purchase action, all moved verbatim from `ParentInfoViewController`.
  - **Grown-up area:** a "FULL TOYBOX" row with a live status line
    (`LullPlansViewController.statusLine()`) opens the page as a sheet. It refreshes on
    `.lullAccessDidChange`.
  - **Welcome:** "Try all nine free" opens the plans page directly (behind the adult check).
  - Support page and SubmissionKit review notes now say "Full Toybox".
  - Needs the Mac compile, and a look at the sheet on iPhone and iPad.
- Oct 11, step 2 done:
  - `WashBayFit` (pure, in `WashModel.swift`): floor contact at fy 0.79 of `wash-bay` (the
    wall seam is at 0.61), wheel ground at 0.88 of every rig.
  - `WashScene.buildLayout`:
    - **portrait** sets the vehicle down on the painted floor, just above the tool tray;
    - **landscape** keeps the vehicle centred and fits the bay so its floor meets the wheels;
    - the bay always covers the screen and zooms only as needed.
  - `verify_wash.py` passes 13,336 checks, now including the bay fit across 9 screen sizes.
  - Mock before/after renders confirmed both orientations (scratchpad, not committed).
- Oct 11, step 3 done:
  - `SleepyBoxShellLayout` (pure, end of `SleepyDropBoxScene.swift`) is measured from the shell:
    - front face 0.095–0.745, drawer recess 0.75;
    - the two socket rows share the band 0.125–0.565, centred at about 0.235 and 0.455;
    - columns at 0.30 and 0.70;
    - the face is anchored at 0.655.
  - The piece radius is capped at 0.076 × the plate height (on a phone, about 24 pt instead
    of 37 pt; the iPad is almost unchanged), so each socket with its bevel fits its row with
    wood between the rows.
  - Only the shell-plate path changed. The older body-art and procedural paths are untouched.
  - `Tools/verify_sleepy_box_layout.py`: 18 checks pass. The mock render looks right in both
    orientations.
  - Needs a device check: the pieces still feel chunky enough on a small iPhone.
- Oct 11, step 4 done (`MixUpScene.swift`):
  - **Floor:** a soft gradient sprite (`softFloor`, fading over its top 40%) replaces the hard
    floor rectangle and seam line. There's no edge above the heart.
  - **Stage:** the round felt `mixup-stage` (`stageArtFrame`: 1.12 × the old stand's width;
    felt top centred 0.304 down at the feet) replaces the plain stand, with a warm light pool.
    The old stand stays as a fallback.
  - **Curtains** (`addTheatreCurtains`): the scalloped valance is tiled across the top (46 pt
    phone, 58 pt iPad), and the tied-back curtains hang at the top corners (30% of the width in
    portrait, 18% in landscape). They sit behind the cards (z 3) and controls (z 50).
  - **Heart** (`keepsakePosition`): below the stage in portrait, kept clear of its front;
    beside the stage in landscape.
  - `verify_mixup_layout.py` now checks the stage and heart: 546 checks across 17 sizes pass.
    `verify_mixup_stack` passes.
  - Not in the cloud: the curtain colour is the art's red (the shelf card is a little rosier).
    Judge on device and tint if wanted.
- Oct 11, step 5 done (`DropDotsScene.swift`):
  - **`DropDotsColourSets`:** 5 sets.
    1. The board's own felts (rust, butter, blue, lavender).
    2. Cherry, lemon, apple, plum.
    3. Pink, sky, mint, lilac.
    4. Marigold, leaf, berry, cornflower.
    5. Indigo, moon, teal, rose.
  - **Each pour** (`triggerReset`), once the dots are home in the tray (about 1.3 s + 0.07 s
    per dot): `nextColourRound()` slips the old dots away under the tray, pops in a fresh
    shuffled hand in the new colours, and re-tints the rings.
  - **Rings:** felt half-annulus overlays (`ringTints`) over each painted ring. The radii,
    0.044–0.080 of the board art width, are measured: the dark mouth ends at 0.045 and the
    ring at 0.079. The upper half sits behind the dots and the lower half in front, like the
    lip. Hidden in round 0.
  - Tokens, hover rims, discoveries and VoiceOver names follow `DropDotToken.roundFelts` and
    `roundNames`. Each visit starts on round 0. Rotation keeps the round.
  - `verify_dropdots.py`: 45 checks, including colour distance for every pair in every set.
  - Needs a device check: the ring overlays sit exactly on the painted rings, adjusting the
    radii if needed (`makeRingTint`, 0.044 and 0.080). And the swap feels calm.
