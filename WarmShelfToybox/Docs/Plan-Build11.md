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

- [ ] **0.** This plan, plus the founder's answers on Drop Dots and the Mix-Up room (§5).
- [ ] **1. Purchases on their own page.** `LullPlansViewController` holds the plans card and all
  purchase actions.
  - The grown-up area keeps a single compact "Full Toybox" status row with a chevron that
    opens it.
  - The welcome's "Try all nine free" opens the plans page directly (behind the adult check).
- [ ] **2. Wash: wheels on the floor.** Measure the bay's floor contact line. Fit the bay so that
  line sits under the wheels (still covering the screen) in portrait and landscape. Verifier
  over device sizes.
- [ ] **3. Sleepy Box: holes on the front face.** Use measured shell fractions for the hole grid,
  hole size and face. Mock renders for phone and iPad, portrait and landscape. Verifier.
- [ ] **4. Mix-Up room** (per the founder's answer, §5).
- [ ] **5. Drop Dots** (per the founder's answer, §5).
- [ ] **6. Build 11.** Version bump, parse, verifiers, handoff.

## 4. Specs

(Filled in as each step starts.)

## 5. Founder answers

(Pending.)

## 6. Status log

- Oct 11: findings and plan written.
