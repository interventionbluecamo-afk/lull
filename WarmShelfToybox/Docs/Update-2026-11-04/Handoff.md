# Build 20 — Drop Dots landscape and renderer crash mitigation

November 4, 2026. Follow-up to the founder's physical testing of TestFlight **1.1 (19)**. All nine toys remain. The submitted 1.0 App Review version is untouched.

## Changes

- Drop Dots landscape now fits the measured board, both six-dot racks and contact shadow into the safe area beside Home. The previous height allowance was substantially larger than the actual artwork and unnecessarily shrank the whole toy. At 874 × 402 points with 62-point side insets and a 21-point bottom inset, the board is about 272 × 311 points and dot diameter about 37.5 points, approximately 36% larger than build 19. Portrait dimensions and placement are preserved. A late safe-area update after rotation refits the layout while retaining the board/tray contents.
- Feed, Window, Mix-Up and Wash now explicitly set `subdivisionLevels = 0` before their authored warp meshes are rendered. This preserves their authored displacement while avoiding additional SpriteKit refinement. No new artwork was generated.
- Version is **1.1 (20)** in both project.yml and Lull.xcodeproj.

## Crash evidence and limits

The founder supplied an Xcode crash point for TestFlight **1.1 (19)** on hardware `iPhone18,1`, OS **26.6.1 (23G83)**, November 4 at 13:55:20 Central. The main thread failed with `EXC_BAD_ACCESS (SIGBUS) / KERN_PROTECTION_FAILURE` in SpriteKit `add_subdivs`, called from `SKCSpriteNode::addBatchRenderElements`. The report contains no scene identifier or app-level triggering callback, so the offending toy is not established. The founder was asked which toy/gesture preceded the crash; no answer was available when this record was written.

The authored meshes have valid counts and ordering: Feed 40×40 cells, Window 24×10, Mix-Up 10×10, Wash 3×5. Native SpriteKit defaults to two additional subdivision levels. Disabling those levels is a bounded mitigation targeting the reported renderer path, **not a proven diagnosis or confirmed physical-device fix**. A small macOS Feed renderer probe also passed at the old default; it did not reproduce the iOS crash. Do not claim a buffer overflow, defective hardware, or a verified iOS fix without further evidence.

Apple property reference: https://developer.apple.com/documentation/spritekit/skwarpable/subdivisionlevels

## Verification

- Combined Debug 1.1 (20) build succeeded. Log: `/private/tmp/lull-build20-debug.log`; DerivedData: `/private/tmp/Lull-Materials-Nov4`.
- `python3 Tools/verify_dropdots.py`: 51 focused checks, 16 layout/asset cases and 2,000 finite deals pass. Covers unchanged portrait metrics, landscape board/racks/shadow/Home bounds, and 12 distinct accessible dot positions. These are model/geometry checks, not thousands of play sessions.
- `python3 Tools/verify_warp_rendering.py`: 52 native macOS SpriteKit render/readback frames pass across production Feed, Window, Mix-Up and Wash mesh formulas, including mirrored cloth, seven simultaneous brush tufts and reset. Counts and finite coordinates are validated before constructing each grid. This is a renderer smoke test, not iOS device QA.
- Swift parsing and whitespace checks pass.
- A fresh simulator visual capture could not be completed: Device Hub controls timed out and Simulator stalled during installation. The captured image was the simulator home screen, not Lull, and was excluded from the evidence. Landscape appearance therefore remains for the founder’s device check; geometry checks and successful compilation are the verified evidence.
- TestFlight receipt: pending below.

## Founder retest

1. In Drop Dots, compare landscape/portrait and rotate with some dots in the board and some in the trays. Check comfortable grabbing, unobstructed Home and retained dots.
2. Repeat the action that crashed build 19. If it recurs, report the toy and immediately preceding action, plus the new crash point. In particular, the changed renderer code is used by Feed gaze, Window curtains, Mix-Up soft accessories and Wash brushes.

No broader acceptance review, tester audit, What to Test edits or App Review resubmission is part of this fix.
