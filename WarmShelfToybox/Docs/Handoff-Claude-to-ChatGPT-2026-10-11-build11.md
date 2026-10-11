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
| 3 Sleepy Box holes on the front face | ⏳ next | See plan §2. The holes overlap the lid; lay them out from the measured shell fractions. |
| 4 Mix-Up felt theatre | ⏳ | Bring back `mixup-stage`, the curtains and the valance; no hard floor line. |
| 5 Drop Dots colour rounds | ⏳ | A new felt colour set after each pour; rings re-tint. |
| 6 Build 11 | ⏳ | Version 11, parse, verifiers, final handoff. |

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
   - Steps 3–5, once done: see the plan.
4. **TestFlight 1.0 (11)** with a What to Test (written in the final step).
