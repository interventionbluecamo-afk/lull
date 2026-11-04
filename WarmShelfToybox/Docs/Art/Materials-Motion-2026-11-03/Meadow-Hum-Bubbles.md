# Meadow, Hum and Bubbles — materials and motion

Implementation resumed November 4, 2026 after the requested Mac restart. This implements the approved November 3 plan plus the founder’s November 4 request for continual baby discoveries and more detail along Meadow’s routes; it makes no release or store changes. The root integration pass owns the consolidated build and simulator/device review.

## Meadow

- The shelter uses `meadow-leaf-house-base` and `meadow-leaf-house-roof` only when both are available with matching fitted canvas sizes. Otherwise the existing `meadow-leaf-house` remains static. A moving roof is never overlaid on a duplicate baked roof.
- Both generated layers retain the 1345 × 1169 canvas. Normalized attachment is **(0.65, 0.70)** and doorway center is **(0.485, 0.16)**, with SpriteKit's upward Y axis. The roof's anchor and position preserve registration at rest.
- Only the front leaf foreshortens to Y scale **0.97** and turns **−0.018 rad** over **0.16 s**. The base, doorway and contact shadow remain stationary. The front leaf is above the arriving baby; the base and doorway warmth are below it.
- A baby reaches an apron immediately outside the actual entrance, turns toward the doorway, then tucks under the roof. It retains its body size. The doorway warms as each visible arrival completes, rather than jumping to the model's final count before the parade arrives.
- Overlapping arrivals keep the roof open. After the last arrival it waits 0.18 s, then settles over 0.8 s. The previous whole-house finale scale was removed; the bounded seven-spark finale remains.
- Reduced Motion uses fades and a doorway pose, with no traveling hop or roof movement. Pause/background commits any already-recorded arrivals to their home state, resets the leaf and warmth, and removes transient sparks. Rotation rebuild uses the existing saved model and follower state.
- November 4 continuation: the same five baby/leaf slots are reused **8–10.8 seconds** after delivery. A bounded search chooses a fresh position outside the visible rectangle plus a generous margin, away from the mother, home, landmarks and other slots. If no safe point exists, the slot stays home and retries after one second; visibility rules are never weakened. New placements have no arrival animation or sound.
- Slot cooldowns, placement seed and a bounded warmth count survive rotation. The house stays warm after its first five welcomes, and the welcome finale is not repeated or escalated. Active baby/leaf storage remains five slots with no lifetime node history.
- Seeded ground details occupy at most **81 spaced clusters**, generally fewer after home/landmark clearance. Small overhead leaves and rosettes reuse the existing art; tiny faceless material pebbles avoid suggesting additional sleeping characters. The scenery is under the painted trail/flowers, has no hit targets or idle actions, and is regenerated deterministically on rotation rather than accumulated during walking.
- Generated source, prompts and production asset records are maintained by the root integration pass in `Assets.json` and `Prompts.json`. The source layers were visually inspected; actual scene composition is part of the consolidated simulator pass.

## Hum

- Reuses `hum-mallet`; no replacement art. Its felt-head contact anchor is **(0.155, 0.805)** on the 968 × 743 canvas. The mallet retains its aspect ratio despite the keys' separate width/height layout scaling.
- A strike couples the mallet's 65 ms contact with **2.264–3.14 local points** of key deflection, depending on the existing bounded intensity. Visible key width stays exactly unchanged. Vertical compression is at most **1.16%**; the competing whole-key sound-pulse inflation was removed.
- A single keyed response recovers over 0.72 s. Release settles from the current pose without a second bounce. Rapid touches replace the same mallet/key actions.
- Face and warmth now follow the existing release decay (1.8 s for the bars), with 0.18 s of readable expression before the fade. Pitch routing, voice choice, note volume and held-note ownership are unchanged.
- Reduced Motion retains the mallet contact pose and expression through short fades, with no key deflection or mallet travel. Existing teardown clears the new mallet along with key feedback. Each key owns one mallet; existing sound-effect nodes remain bounded to 64.

## Bubbles

- The fixed 1-in-12 eligibility decision now happens when an ordinary large bubble is created. Up to two visible passengers/departures can exist; the 48 ms pop transition is included in that budget.
- A `BubbleBirdNode` is visibly carried inside the bubble before input. Pop reparents that exact node into the departure layer; no random bird is constructed after the pop. Ordinary empty bubbles keep their existing behavior.
- The same release path covers direct touch, swiping, VoiceOver and an existing mother-bubble pressure wave. VoiceOver identifies a bubble carrying a bird and uses the ordinary pop action.
- The bird faces its eventual departure direction while still carried. Its 2.8 s flight uses the existing authored wing frames; its full body is not stretched. Reduced Motion leaves the freed bird in place for a short fade.
- Rotation snapshots preserve which bubbles carry passengers, and remove completed departures. Pause/background removes departing birds and completes any pending shell-pop transition so it cannot release a delayed bird on return.

## Files and checks

Changed source:

- `App/Toys/Meadow/MeadowLittleOnes.swift`
- `App/Toys/Meadow/MeadowScene.swift`
- `App/Toys/Hum/HumObjectNode.swift`
- `App/Toys/Bubbles/BubbleNode.swift`
- `App/Toys/Bubbles/BubbleScene.swift`
- `Tools/verify_hum.py` (updated assertions for the new smaller physical bounds and fixed key width)
- `Tools/verify_meadow_little_ones.py` (recurrence, persistent warmth/cooldowns, visibility exclusion, long-play storage and ground-detail layout)

Verification completed:

- `Tools/verify_hum.py`: **10,376 checks passed**, covering intensity/cadence, exact fixed width, deflection bounds, reduced motion, sound-decay duration bounds and effect budget.
- `Tools/verify_meadow_little_ones.py`: **22,438 model checks and 8 scene checks passed**, including 100 further deliveries/discovery cycles, stable storage and warmth, offscreen-only replenishment, rotation-equivalent countdown/seed state, and bounded sparse ground details.
- Swift frontend parse passed for all seven Meadow/Hum/Bubbles source files.
- Scoped `git diff --check` passed.
- Bubble passenger identity/lifecycle fixture: **33 checks passed**, plus rotation, accessibility, no post-pop random creation and pause cleanup source contracts. `/tmp/lull_check_bubble_passenger.py` extracts the production pop method and passenger count; rendering/audio are stubbed, so it verifies ownership and one-shot release rather than actual SpriteKit timing.

No Xcode build, project regeneration, commit or push was performed by this subtask. Remaining integration review: phone portrait/landscape and iPad scene appearance; repeated baby discovery after the first five and route-detail density; shelter entry occlusion and small roof lift; mallet/face readability; the visible-bird-to-flight transition; physical audio/touch feel and Reduce Motion. Source checks are not a substitute for that review.
