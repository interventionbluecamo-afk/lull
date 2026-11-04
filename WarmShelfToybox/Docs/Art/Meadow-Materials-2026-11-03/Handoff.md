# Lull materials and motion pass — November 3 evening

## Status

Founder tested build 1.1 (18) and reported that Meadow, Wash, Sleepy Box and Mix-Up sometimes look like disconnected generated illustrations. They want a recognizable design language, small meaningful responses to touch, and organized reusable assets. The founder remains responsible for physical play testing. **1.0 in App Review stays untouched.**

This is a focused first implementation plus a prioritized nine-toy roadmap. All three repairs are implemented and the combined Debug build **1.1 (19)** compiles. **Founder explicitly asked to hear the proposed ideas before submission. Hold further implementation and all TestFlight/App Store uploads. Build 19 has NOT been uploaded.** Build 18 is the previously uploaded baseline.

## Read first

- `Docs/Brand.md`: current production art rules (November 3 section).
- `Docs/AlivenessPrinciples.md`: quick notice, material-specific response, slow settle; restrained optional discoveries.
- `Docs/AssetManifest.md` and `Docs/Art/README.md`: production assets, source art, prompts and previews.
- `Docs/Art/Inventory.json`: generated catalog listing; bundled does not mean currently used by a scene.

The older NorthStar/Brand examples contain historical Stack/free-toy plans. Current product settings and release handoffs govern pricing, availability and lineup. No pricing or review configuration changed in this pass.

## First implementation

**Meadow:** Replaced the tall decorated house with a low, simple leaf shelter viewed from above. Removed the wooden display base, steps, flower trim and oversized spiral. The same neutral asset is tinted in day and night with other objects. Shared light now covers the mother, babies, hiding leaves, landmarks, flowers, butterflies and dandelions. Contact shadows stay close to objects. The warm doorway is drawn separately; the old full-house glow cannot reintroduce the daytime house. Arrival targets and finale sparks use the new doorway position. House remains visible from the start.

Exact generation prompt and provenance: `Prompt.json`. The new 1345×1169 transparent image is the unmodified built-in imagegen output in `meadow-leaf-house.imageset`. Previous house art remains under Build10 source. Day/night simulator material previews are in `Previews/`; the debug-only reaction flag places a hedgehog and pond near home for comparison. They are not new release-world placements or marketing captures.

**Sleepy Box:** Repaired the material mismatch while retaining exact shared shape/socket geometry and the larger build-18 pieces. Restrained grain, consistent shading, fewer disconnected shiny patches; drawer settling is now independent of display refresh rate, preserving the previous 60 Hz feel. The material cache is bounded to 16 MB.

**Mix-Up:** Repaired fragile neck and waist attachment during motion using shared collar/waist pivots and overlap; the head follows the body while staying independent during shirt flips. Existing animations already include admiration, breathing, shuffles, bows and save poses. Repeated recipes now acknowledge/promote an existing card while preserving historical saves. Existing duplicates are not silently deleted.

## Nine-toy priorities

Findings below are verified from code and the founder’s screenshots. Recommendations and priority are design judgments; no educational-outcome claim is implied. Unlisted toys were not physically played this session.

| Priority | Toy | Finding | Action / status |
| --- | --- | --- | --- |
| High | Meadow | House camera, daylight highlights and base disagreed with the overhead night world. | New simpler shelter, shared lighting and doorway glow implemented; founder device review pending. |
| High | Sleepy Box | Flat highlight patches and drawer disagree with detailed wood; drawer easing is frame-based. | Keep shared geometry, unify material and make settling time-based. Implemented; founder device review pending. |
| High | Mix-Up | Nearly zero overlap at neck/waist allows motion to disconnect parts; repeat saves create identical portraits. | Repair attachment points and acknowledge an existing recipe. Implemented; founder device review pending. |
| High, next | Little Wash | Touch-inviting side brushes are baked into both backgrounds. Existing vehicles/tools already react well. | Separate clean bay plates and transparent brush fibres, then bend under finger and damp back. Proposed; do not wiggle the entire image or overlay duplicate brushes. |
| Medium | Feed | Food pulses on approach; the friend already has several eating expressions. | Use the existing surprise face and small lean to notice approaching food, relaxing when it leaves. Proposed. |
| Medium | Window | Curtains already drag and respond, but whole-image scaling makes gathering stiff. | Anchor the top, let lower fabric lag and settle. Proposed. |
| Medium | Drop Dots | Many effects already exist; simultaneous stack jiggle can feel generic. | One delayed compression through the landed stack; review heavy tint before adding grain. Proposed. |
| Low | Hum | Expressive faces, pressure and release are present. | Refine tiny decaying key flex and a slower facial settle only if it reads better in motion. Proposed. |
| Low | Bubbles | Code-drawn shells, pressure waves and rare birds already provide variety. | Optional later: show an existing bird within a rare bubble before that same bird flies out. Proposed. |

## Wash implementation contract for the next pass

Remove only the brush fibres from portrait/landscape bay plates, retaining wooden supports and room composition. Generate a single transparent felt brush layer, reused where appropriate. A deformation grid bends local fibres toward the finger and settles over roughly 0.6 seconds. Keep Home/tool/vehicle gesture priority, separate brush touch ownership, generous inset touch areas, rotation/pause cleanup, Reduce Motion feedback and VoiceOver activation. No continuous spin, added reward or automatic noise. A room response must remain optional and cannot interfere with washing.

## Verification and release

- Meadow Debug simulator compile succeeded with the installed SDK.
- Meadow existing verifier: 13,250 model checks plus six scene checks passed.
- Day and night composite previews inspected; roof, lighting and doorway are evaluated together.
- Combined build-19 Debug compile passed. An unavailable cross-file colour helper was caught and replaced with a local helper in the Sleepy material renderer.
- Mix-Up verifier: 399 cast/registration checks and 546 layout checks passed; isolated production save-store checks cover duplicate prevention, recency and historic-save retention.
- Sleepy drawer convergence was checked at 30/60/120 Hz; shape/socket geometry is unchanged from build 18.
- Asset inventory: 283 entries, 299 files, zero missing files and zero read errors. Duplicate hashes are documented, not removed.
- Do not claim a physical-device pass or upload from these local previews.

## Founder pause on release — November 3 evening

The founder said: “dont bother submitting yet - i want to hear the proposed ideas first.” No build-19 archive/export/upload has started. Source and documentation are saved for discussion, not approved final art. Meadow day/night and joined Mix-Up renders were inspected. Sleepy Box’s material experiment compiles but still reads too flat/striped against the shell; treat it as an experiment to refine, not a finished design. No further implementation should precede the design discussion.
