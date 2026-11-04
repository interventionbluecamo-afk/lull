# Feed, Window and Drop Dots — materials and motion handoff

Implemented November 3–4, 2026 against `Docs/Plan-Materials-Motion-2026-11-03.md`, `Docs/Brand.md` and `Docs/AlivenessPrinciples.md`. Work paused for the Mac restart and resumed from the saved source edits. No asset generation, catalog changes, Xcode build, project regeneration, commit or upload was performed by this work package.

## Source and material contract

Existing production artwork remains authoritative. Feed uses its registered front-facing felt cast, the existing mouth landmarks and the existing counter occlusion. Window keeps its front-facing room/window plate, separate curtain panel, rod height and mirrored second panel. Drop Dots retains its board channels, circular clay token, contact shadows and four matching colour families. No room plate, board or contact shadow is deformed by the new motion.

| Toy | Existing part / attachment | New response |
| --- | --- | --- |
| Feed | `feed-cast-<member>-1/5/6` registered frames; existing `CastRig` mouth positions; base-pivot pose below the face | Held food supplies the gaze direction and attention strength. Pupils shift at most 0.9% of canvas width / 0.6% of height inside a localized mesh. A rigid lean is capped at 0.035 radians. The existing surprised frame opens the mouth near the food; receiving food clears anticipation and retains the existing chew/contentment cycle. |
| Window | `window-curtain-panel`; top-centred anchor at rod Y; separate room and rod | A 24×10 mesh gathers the panel horizontally. The top row stays at Y=1 while lower rows follow bounded hem openness. Direct header movement follows the touch; hem time constants are 0.085 s held / 0.22 s released. Light follows the same opening and final settle. |
| Drop Dots | `dropdots-token-blank` or existing fallback; fixed root in channel; body separate from contact shadow | One rigid compression travels down from the actual landed dot, 65 ms later per supporting row. Displacement is at most 2.2 pt and decreases by 0.72 per row. The final supporting dot settles within 0.70 s. No second landing squash or simultaneous hover jiggle remains. |

Feed iris centres (normalized production canvas, X from left, Y from top): sprout `(0.343, 0.682, 0.427)`; grandmother `(0.357, 0.657, 0.444)`; knithat `(0.350, 0.674, 0.500)`; mira `(0.363, 0.663, 0.538)`; jun `(0.354, 0.654, 0.536)`. Unknown future cast entries keep their authored gaze until their eye landmarks are measured; their approach pose and mouth response remain available.

## Integration details

- Feed attention only reads currently dragged, unserved food, including multitouch. Distance is measured in each friend's local coordinates. It cannot consume food, change wishes or commit a bite. Withdrawal settles more slowly than noticing. An independent pose node avoids interfering with arrival, food acceptance and chewing actions; the thought bubble stays registered to its existing location.
- Window retains existing peek-a-boo discoveries and its accessible open/close action. The old whole-panel sway is replaced by a small hem fold. The drag mapping now subtracts the closed offset, preventing a jump on the first motion event. Hit regions track the trailing cloth during a re-grab. The existing timed cloth hint is quieter and has no repeated sound.
- Drop Dots keeps finite hands, matching colours, colour rounds, top-dot return, reset pour and the existing discoveries. Pattern/home/rainbow/full-board reactions use restrained glows rather than additional token hops/scales. Only landed dots count toward a discovery; grid reservations remain available for concurrent drops. Repeated settling replaces the prior keyed action, and each token has at most one pattern halo.
- Drop Dots tint changed from 0.95 to 0.90, retaining clear colour matching while exposing slightly more of the source clay highlight. The procedural fallback highlight is also quieter. This is a small material adjustment, not a recolour of the palette or rings.
- Held dots now follow their grabbed point directly; the column rim previews the destination and alignment happens on release. Final touch coordinates are applied before release. Feed's existing direct food drag is unchanged.
- Reduced Motion disables Feed lean and curtain lag, and makes Drop Dots settling positional/rest-only. Directional expressions and fades remain readable. Rest/scene teardown clears transient poses; rotation rebuilds preserve content and return the new motion to its rest state. Existing sound/haptic settings remain in control.

## Verification

Passed:

- `python3 Tools/verify_feed.py`: 18,766 checks using extracted production code, including request preservation, cast rotation, mouth/edge rules, approach distance/direction, slower withdrawal, reduced motion and the eating lock.
- `python3 Tools/verify_window.py`: active-path checks and 13,209 native checks. New checks cover phone portrait/landscape and iPad widths, no first-drag jump, anchored top row, monotonic folds without inversion, nonzero hem gathering, 1,000 rapid reversals, complete release settling and reduced motion.
- `python3 Tools/verify_dropdots.py`: 49 checks plus native settling bounds and 2,000 dealt hands. Matching colours, finite-hand distribution, discoveries, actual-arrival gating, direct touch and replaceable settling are covered.
- `xcrun swiftc -frontend -parse` for `CharacterNode.swift`, `FeedScene.swift`, `GlowWindowScene.swift` and `DropDotsScene.swift`.
- Scoped `git diff --check`.

These are focused source/native-model checks, not evidence of rendered SpriteKit appearance. No app build was run in this work package. The root integration pass must still inspect actual game-size composition and touch feel after the consolidated build.

## Founder / integrated-device pass

1. Feed: bring food in from both sides, hold it near the mouth, withdraw without feeding, then feed it. Confirm the same five friends keep their existing meals and chew sequence; check pupil movement at phone size and no visible distortion around glasses. Repeat with Reduced Motion and rotate while holding food.
2. Window: pull low on either curtain, reverse quickly, let go and re-grab while settling. Confirm the top remains on the rod, the hem stays within its frame and beam brightness follows opening in day and night. Close/reopen for the existing discovery, use VoiceOver open/close, then pause or rotate mid-drag.
3. Drop Dots: drop several dots quickly into one channel, make a home column and a rainbow row, take a top dot back and pour. Confirm one descending weight response, quiet pattern glows, unchanged colour matching in the original and pastel rounds, and no residual displacement after pause/rotation. Repeat with Reduced Motion.

The consolidated build and this device pass remain the final visual/integration validation; no new art is requested.
