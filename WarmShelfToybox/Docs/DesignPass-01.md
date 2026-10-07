# Lull — first design and interaction pass

October 6, 2026. Work is in the separate review copy. The original project is now available inside `Desktop/lull v.2`; it was not edited by this pass.

## The vision to preserve

Lull is a small room of physical-feeling toys. A child chooses an object, discovers a simple action, and repeats or changes it. The distinctive ingredients are the shelf, tactile materials, gentle character presence, and unhurried sound. The native UIKit/SpriteKit foundation supports this direction; a framework rewrite is unnecessary for the first beta.

The strongest learning connection is Sleepy Box: four shape comparisons, visible fit feedback, a deliberate drawer reset, and a finished state that rests. Exploration and construction in the other toys are promising, but their educational effects have not been measured. Montessori early-childhood environments emphasize independent choice, purposeful materials, repetition, and opportunities to detect mistakes; a digital activity needs its own review against these principles. [American Montessori Society](https://amshq.org/about-us/inside-the-montessori-classroom/early-childhood/)

## What needed attention

The original generated artwork varied in color, perspective, visible padding, and material. Some interactive surfaces were painted into images and then duplicated with code. The original sorter, for example, combined a baked drawer with a second drawer and overpainting. Tiny or overlapping touch regions and gesture ownership problems made the visual inconsistencies more consequential.

The app also contained trial-replay behavior that reset access, parent copy promising an ongoing release schedule, and Bubbles effects that became more frequent after prolonged popping. These were concrete source findings. The conclusion that the interface needs more visual restraint is a design judgment.

## Changes in this copy

- A neutral room, pale wood, matte clay, and a more legible shared palette. Nine fresh shelf-object sprites use one direction. Their visible bounds are measured and cropped by SpriteKit at runtime for consistent physical scale and shelf alignment.
- A simpler shelf with more breathing room, reduced idle invitations, and available toys as its visible objects. Non-playable decorative shelf fillers were removed.
- A consistent 52-point home target, safe-area placement, clear contrast, and reduced shared background decoration.
- A new blank sorter body. Code owns the four exact openings, pieces, face, and single drawer. Matching checks the nearest physical opening before the shape; release regions do not overlap. Four pieces return to stable tray positions, fast drawer pulls work, and rotation cancels stale returns. The completed sorter rests.
- Meadow, Drop Dots, Window, and Hum receive gesture/audio ownership fixes. Multi-touch is enabled in the toy view. Window's inactive lamp accessibility control is removed; its time control is actionable. Meadow's spoken description now matches direct painting.
- Feed now requires a deliberate drag to a bounded, illustrated mouth target. Missed and cancelled drops return home. A serving item cannot be grabbed twice; accepted bites commit before animation so rotation preserves them. Alternative food is accepted warmly while the pictured request remains; completing the request ends that visitor's meal. Accessible food actions explicitly offer an item.
- Window's dial stays within safe insets, accepts taps as well as turns, and protects against sudden jumps through its center. Wall gestures cannot move the controls off screen. Every sky tap receives a small local response, including during bird cooldown and Reduce Motion; comet frequency and sound are restrained.
- Runtime review found Window blank on the current simulator in both the original and redesigned builds. Disabling its live Core Image beam blur restored the scene. The beam now uses a feathered alpha texture baked once per layout, retaining time-of-day color and opacity without that live filter.
- The rest screen explicitly stops sustained audio, cancels active touches, and pauses play. Parent wake restores the prior interaction state and Window ambience. The two-finger parent shortcut remains on the shelf and is removed from toy screens, where it could interrupt Hum. Drop Dots cancellation returns a held dot without posting it.
- Bubbles retains occasional delight with a fixed frequency, without escalating surprise frequency as pop count rises.
- Welcome replay preserves the original trial date, purchase access, and parent preferences. Parent copy describes the current library and optional purchase without promising monthly releases or unsupported outcomes.
- Version and build settings are synchronized. TestFlight preparation is recorded separately.

This is a first pass. Most in-game artwork, the host character, and some toy-specific backgrounds still need individual art direction and device review. A fresh shelf thumbnail does not finish the activity behind it.

## Focused first family beta

Keep the nine-toy lineup, including Meadow and Hum, as the founder requested. Focus the first version on reliable, discoverable play with one understandable central action per activity; do not add new games, age profiles, or a release-calendar promise yet. The next pass should play every activity on a real iPhone and iPad, then improve the specific failures observed.

| Activity | Central action to make understandable | What to resolve with observation |
| --- | --- | --- |
| Sleepy Box | Fit shapes, then open the drawer | Can a child discover both fit and reset without help? |
| Stack | Place and balance blocks | Does assistance preserve the relationship between placement and result? |
| Feed | Offer food to a friend with pictured requests | Does the mouth target feel generous, and is the request/completion relationship clear? |
| Drop Dots | Post dots and return them | Can the child understand where dots go and how to recover them? |
| Hum | Touch, hold, and sweep musical bars | Do multiple fingers release reliably and feel expressive? |
| Meadow | Paint by touching and dragging | Is the result legible immediately, with room for variation? |
| Window | Tap or turn the time dial; explore sky and curtains | Are control location, time changes, and repeated taps understandable? |
| Bubbles | Touch and pop | Does play stay responsive and unhurried over a longer session? |
| Mix-Up | Arrange and play sounds | Do its controls communicate creation clearly without reading? |

A gentle ending is a promising product direction. Build it after the timer's session-versus-daily meaning is agreed and the basic lifecycle is verified. A sleep benefit or easier handback has not been established; do not advertise those outcomes as facts.

Observe ages 2–3 and 4–6 separately. The prototype was largely built around toddler interaction; meaningful depth for older children is a hypothesis to test. Ask an educator to review shape isolation, placement assistance, the matching/pretend-care distinction, and any eventual learning claims.

## Verification and remaining work

The original and redesigned simulator builds succeeded. Native state checks cover four welcome/trial cases. Sorter geometry checks cover 2,662 assertions across phone/tablet dimensions and both orientations; that fixture copies the geometry and is not a touch test. Production-extracted Feed checks cover 74 request, mouth-landmark, serving-bound, and no-request fallback cases. Window checks cover 176 geometry/control cases and nine active-path checks. Rest suspension checks cover four ordering/restoration scenarios with UI stand-ins. These fixtures do not establish UIKit touch dispatch, audio behavior, or child usability. Changes received Swift syntax checks.

Actual app rendering and parent welcome navigation were inspected on an iPhone 17e simulator. Rebinding and raising Device Hub's dedicated window resolved the earlier input problem: a sorter circle was dragged into its matching opening, and Window's dial tap visibly advanced daytime to sunset in the diagnostic build. The Mac locked during the next sorter test. Earlier unsuccessful attempts are not passed tests. Wrong-hole/reset, Feed, multiple-finger, sound, interruption, VoiceOver, and rotation tests remain essential, along with the production beam's final runtime check. No child usability or learning-outcome testing has been completed.

Dynamic toy accessibility needs a dedicated pass: objects can appear, disappear, or be replaced after the initial accessibility snapshot. Artwork for the individual activities also needs review at actual device size, rather than judging generated files alone.

TestFlight is prepared locally, not uploaded. Developer membership, app-record ownership, signing, product setup, and real-device acceptance remain unconfirmed. See [TestFlight preparation](TestFlight-Readiness-DesignPass01.md).

Claude's supplied transcript and the two expanded Feed/Window audits were reviewed. Their claims were checked against this source before implementation. Claude's visible changes panel showed no changes; the remaining five audit results were not available in the inspected history. Its proposed cuts, age target 2–5, and unsupported handback/sleep promises were not adopted.

See [continuation handoff](Handoff-2026-10-06.md) for the exact source location, verification, and next actions.

## Artwork records

The built-in ImageGen tool generated the new raster assets. `Assets/DesignPass-01/shelf-art-manifest.json` records the nine asset paths, prompts, sizes, and visible bounds. Original PNGs are copied unchanged into the asset catalog. Geometry remains code-owned where precise fit matters.

`direction-board.png` is a visual exploration. `sleepybox-v2-shell.png` is the blank birch body used beneath the sorter geometry. `shelfroom-v2-day.png` is the quiet room plate. Actual simulator screenshots are saved alongside them for review; concept art is not a substitute for those captures.
