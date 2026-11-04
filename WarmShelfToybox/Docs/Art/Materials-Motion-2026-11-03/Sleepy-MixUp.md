# Sleepy Box and Mix-Up implementation — November 4, 2026

Resumed after the founder's Mac restart. Source work and focused checks are complete; integrated build/preview and founder touch testing remain with the parent task. No release or upload was performed.

## Changed files

- `App/Toys/SleepyDropBox/DropBoxPieces.swift`
- `App/Toys/SleepyDropBox/SleepyDropBoxScene.swift`
- `App/Toys/MixUp/MixUpPart.swift`
- `App/Toys/MixUp/MixUpScene.swift`
- This scoped note.

## Sleepy Box

The material uses sparse irregular curved figure and broken matte fibres instead of dense horizontal stripes. An inset bevel has a broad upper light and thicker shaded lower edge, all clipped within the original shared silhouette. The material cache includes the path, remains capped at 48 textures/16 MB, and generates at most 9,000 small marks per cached texture. Drawer, knob, tray floor and lip use the same renderer and birch family. Production art, shape paths, socket paths, piece radius and layout measurements are unchanged.

The existing shell is the reference: 1315 × 1196 source, cropped by the existing code to 1065 × 946; shallow front perspective, broad upper-left light, quiet curved wood figure. Procedural bevels follow those existing shapes and illumination. No new images were generated, edited or added to the asset catalog. Contact shadows remain scene-owned for pieces/knob; no new baked shadow duplicates were introduced.

Held pieces and the drawer now follow the finger directly. Weight is in the release: a 1.055 lift instead of 1.16, a close softened contact shadow, minute rigid landing tilts, restrained posting and a short drawer return without a rubber bounce. Shell, drawer, face and sockets settle together by at most 1.1 points instead of stretching the shell under fixed sockets. Drawer return is time-based; invitation motion is keyed and canceled on a grab.

Pause, backgrounding and rotation restore the authoritative posted/loose-piece state and finish pending returns at their reserved destinations. The new `settleImmediately()` clears internal piece poses. Reduced Motion uses direct poses/fades and avoids the new tilts, wobble and returning-piece travel. Existing awake/tuck expressions and sound/haptic settings remain.

## Mix-Up

Added a 10 × 10 local warp grid to existing registered art. Bunny/short ears, songbird tuft, officer's felt cap and outer sleeves can trail a child-caused flip or bow. Lower face, torso center, collar and waist remain fixed. Robot parts and the firefighter's hard helmet stay rigid. Warp destinations remain inside the original art envelope, with maximum displacement under 2.8 percent; no duplicate ear/hat overlays or new cast assets. Each response notices in 0.16 seconds and settles over 0.64 seconds; its keyed action replaces any prior response. Reduced Motion leaves the grid undeformed.

Jointed parts now turn horizontally, preserving collar, waist and sole heights through the flip. The head continues following the body's collar without inheriting its narrowing page scale. A separate rig offset compensates for incidental sole movement from root breathing/bows, preserving intentional hops. All nine cast entries, registration rectangles and saved indices remain unchanged.

Accepted saves persist before the portrait animation. Interruption cannot lose the recipe or leave the save flag stuck. Saving an existing recipe promotes/acknowledges its current card. Six is now a visible-shelf limit rather than a storage truncation: new saves retain historical recipes and historical duplicates, while repeated presses add no new duplicate. New save under Reduced Motion appears with a short fade. Pause, backgrounding and rotation cancel pending moments, restore final selected parts and clear warps/flight state.

## Verification completed

- `Tools/verify_sleepy_box_layout.py`: **366 checks passed**.
- `Tools/verify_mixup_layout.py`: **546 checks passed**.
- `Tools/verify_mixup_stack.py`: **399 checks passed**, nine friends and 729 combinations. Used `/Users/User2/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3` because system Python lacks Pillow.
- Four changed Swift files: `xcrun swiftc -frontend -parse` passed.
- iOS simulator SDK typechecks passed for the complete `DropBoxPieces.swift` with dependency stubs, and production `MixUpSoftMotion`/`MixUpRigGeometry` helpers. These exercise real UIKit/SpriteKit APIs; they are not a whole-app compile.
- Isolated production geometry/save harness: **10,861 checks passed**. Covers exact identity rest, pinned face/neck/waist/torso, bounded deformation, positive mesh triangle areas, grounding across breath/rotation/scale, repeated save promotion, retained legacy duplicates and retention beyond six entries. Harness uses an isolated temporary UserDefaults suite, not live saved data.
- `git diff --check` passed for the four source files.

No xcodebuild, project regeneration, commit, push or upload was performed by this subagent. No integrated scene or physical-device preview is claimed. Parent combined preview should inspect material readability at actual phone size, horizontal Mix-Up flips, sleeves/ears during mixed bows, rotation during a save/posted-piece return and Reduced Motion. Source checks cannot establish touch feel or final art quality.

## Integrated preview follow-up

Root's `Previews/sleepy-box.jpg` revealed angular bevel cutoffs on the wide drawer/tray, despite correct silhouettes. The diagonal rim gradient stopped at its end plane because it used no extension options; on wide surfaces that plane crosses the visible rim. The renderer now extends both endpoint colours through the entire clipped ring and explicitly begins its clip/stroke paths. This is a shading correction only; geometry, sockets, tray bounds and materials are otherwise unchanged. Swift parse/diff checks passed again. Root incremental preview remains the visual confirmation step. Root reports the actual joined Mix-Up bunny preview looks good.
