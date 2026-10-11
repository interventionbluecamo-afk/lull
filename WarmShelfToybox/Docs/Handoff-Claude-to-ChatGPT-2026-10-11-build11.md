# Lull — Claude → ChatGPT handoff: build 11 (live, updated after every step)

Branch `claude/modest-bell-cjarqm`; pull first. Mac checkout `~/Desktop/lull v.2`, project
`WarmShelfToybox/Lull.xcodeproj`, scheme `Lull`.

- **If Claude stopped midway**, continue from the first unchecked step in
  `Docs/Plan-Build11.md` §3. It has the findings, specs and per-step notes.
- **Your build 10 Mac work was never pushed.** Commit your compile fixes and Meadow art to this
  branch first. Merge, don't overwrite.

Rules:
- Never commit signing keys.
- TestFlight uploads are authorised.
- No public App Review submission without the founder.

## Status

| Step | State | What |
|---|---|---|
| 0 Plan and founder answers | ✅ | Drop Dots: **new colours each round**. Mix-Up: **felt theatre like the shelf card**. |
| 1 Purchases on their own page | ✅ `4972f6b` | New `LullPlansViewController.swift` (in the Xcode project). The grown-up area has a "Full Toybox" row with a live status line. The welcome's "Try all nine free" opens it. |
| 2 Wash wheels on the floor | ✅ `a3f0887` | `WashBayFit` in `WashModel.swift`. Portrait sets the vehicle on the painted floor above the tools; landscape fits the bay to the wheels. |
| 3 Sleepy Box holes on the front face | ✅ | `SleepyBoxShellLayout`: sockets on the measured front face, the face between them and the drawer, slightly smaller pieces on phones. `verify_sleepy_box_layout.py`. |
| 4 Mix-Up felt theatre | ✅ | A soft floor (no seam), the round felt `mixup-stage`, a tiled valance and corner curtains. The heart is below the stage in portrait and beside it in landscape. `verify_mixup_layout.py`: 546 checks. |
| 5 Drop Dots colour rounds | ✅ | 5 felt sets take turns: after each pour a fresh shuffled hand pops in and the rings re-tint (felt overlays on the painted rings). `verify_dropdots.py`: 45 checks. |
| 6 Build 11 | ✅ | `CURRENT_PROJECT_VERSION` 11 in both places. All 15 Swift files changed since `21eb8d2` parse. All 14 Linux verifiers pass. |

## Mac work once the steps are done

1. **Compile Debug and Release.** Nothing here was compiled against the iOS SDK. Likely spots:
   - `LullPlansViewController.swift`: code moved from `ParentInfoViewController`, plus
     duplicated small helpers;
   - `ParentInfoViewController`: `makeChevronRow` gained a `detail:` parameter, and both call
     sites pass it;
   - `WashScene.buildLayout`: `art.texture?.size()`;
   - everything listed in the build 10 handoff.
2. **Run every `Tools/verify_*.py`.** All Linux-runnable ones pass in the cloud; also run the
   2 macOS ones. Logs go in `Docs/Verification-build11/`.
3. **Device checks:**
   - **Wash:** portrait and landscape on a small iPhone, a Pro Max and an iPad. Wheels touch the
     painted floor, and the tools don't cover the vehicle.
   - **Full Toybox page:** opens from the grown-up area row (as a sheet) and from the welcome.
     - Buy, restore and manage all work in sandbox.
     - Closing the sheet updates the row.
   - **Sleepy Box:** the sockets sit on the box's front face, below the lid, in both
     orientations. The pieces still feel chunky on a small iPhone.
   - **Mix-Up:**
     - The theatre frames the friend.
     - The curtains never cover the cards or controls.
     - The heart is clear of the stage in both orientations.
     - No hard floor line.
     - Is the curtain red right next to the shelf card?
   - **Drop Dots:**
     - Pour, then a new colour set appears and the rings change colour.
     - The felt ring overlays line up with the painted rings. If not, adjust the radii in
       `makeRingTint` (inner 0.044, outer 0.080 × board art width).
     - Rotation keeps the round.
4. **Meadow art** from the build 10 handoff §3, if not yet added (four PNGs; the code adopts
   them automatically).
5. **TestFlight 1.0 (11)** to Founder Testing. Build 11 includes everything in build 10.
   **What to Test** (paste):

```
Build 11: your notes from build 10.

Little Wash: the vehicles stand on the floor now, in portrait and landscape.

Sleepy Box: the four holes sit on the box's front face, below the lid, with the sleepy face
between them and the drawer.

Mix-Up: a felt theatre like the shelf card: a round wooden stage, red felt curtains and a
valance, and a soft floor with no hard line. The save heart is below the stage (beside it in
landscape).

Drop Dots: pour the dots out with the tab and a new colour set arrives (5 sets take turns);
the rings change colour to match.

Full Toybox: plans and prices are on their own page now. In the grown-up area, tap the
"Full Toybox" row. The welcome's "Try all nine free" opens the same page.

Everything from build 10 is included (free toys, play timer, Meadow little ones).
```

## If something looks wrong on device

| Area | What to adjust |
|---|---|
| Wash | Contact line: `WashBayFit.floorContactFy` (0.79). Lower it to sit further back on the floor, raise it to come forward. |
| Sleepy Box | Rows and size: `SleepyBoxShellLayout` (hole band 0.125–0.565, `maxPieceRadius` 0.076, face 0.655). |
| Mix-Up | Curtain width: `addTheatreCurtains` (0.30 portrait, 0.18 landscape). Valance height: 46/58. Stage size: `stageArtWidth`. |
| Drop Dots | Ring overlay radii: `makeRingTint` call (0.044/0.080 × art width). Colours: `DropDotsColourSets`. |

Rerun the matching `Tools/verify_*.py` after any change.
