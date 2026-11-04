# Lull materials and motion — current handoff

November 4, 2026. All nine approved work packages are implemented in source, including the founder's continuation request for recurring Meadow discoveries and quieter detail along its routes. **TestFlight 1.1 (19) uploaded November 4 at 1:49 PM Central; Apple accepted the package and began processing. Founder physical testing is pending.**

## Current state

- Implementation commit **`3e1405b`** (`Add tactile toy interactions and recurring Meadow discoveries`) is pushed.
- The combined **Debug 1.1 (19)** build passes for **iPhone 18 Pro / iOS 27 Simulator**, including the final Sleepy Box bevel-gradient correction.
- Focused source, geometry, state and asset checks passed. Their scope and commands are recorded in the linked work-package notes; repeated model assertions are not live playtesting.
- Root rendered, viewed and captured **all nine toys and the shelf in phone portrait**, including Meadow in day and night. Additional confirmed coverage is **Wash in phone landscape and iPad Air M3 portrait/landscape** and **Meadow on iPad in portrait and landscape**. See [preview records](Previews/README.md) and the coverage limits below.
- Release archive and TestFlight upload succeeded from source `cc4690a`. Xcode reported **Uploaded Lull / EXPORT SUCCEEDED** at 13:49:08 Central on November 4. Apple was processing the package at upload completion. No App Store submission or store-setting change was made; the existing 1.0 review remains untouched and its live status was not rechecked.

The founder authorized execution of the [November 3 plan](../../Plan-Materials-Motion-2026-11-03.md) and resumed it after the Mac restart. Older notes describing these changes as proposed or implementation as paused are historical. The founder subsequently asked “can you do testflight too please,” authorizing this archive/export/TestFlight upload. That supersedes the earlier local-build hold only; it does not authorize changing the pending 1.0 review or submitting 1.1 to App Review.

## What changed

| Toy | Implemented behavior | Detail and source |
| --- | --- | --- |
| Meadow | Registered shelter base and roof share the scene's day/night light. A baby enters the actual doorway under the front leaf, which lifts and settles independently. The same five baby/leaf slots quietly replenish at fresh offscreen locations after delivery; house warmth persists and the welcome finale does not escalate. Sparse seeded ground details add interest between landmarks without new touch targets. | [Scoped note](Meadow-Hum-Bubbles.md#meadow), [source](../../../App/Toys/Meadow/) |
| Little Wash | Clean portrait/landscape room plates support separate local brush tufts. Touch bends nearby fibres; hose contact wets them, with bounded runoff near the drain. Optional brush gestures survive another finger's tool pickup and normal vehicle departure. Vehicle/tool play retains priority. | [Scoped note](Wash.md), [source](../../../App/Toys/Wash/) |
| Sleepy Box | Quiet curved wood figure, restrained thickness/bevels and a consistent drawer/knob/tray material preserve the shared piece/socket geometry. Held pieces and drawer follow directly; release carries more weight. The integrated follow-up extends bevel-gradient endpoints to remove angular cutoffs on wide surfaces. | [Scoped note](Sleepy-MixUp.md#sleepy-box), [source](../../../App/Toys/SleepyDropBox/) |
| Mix-Up | Horizontal jointed flips keep collars, waists and feet connected. Soft ears, selected hats and sleeves have bounded secondary movement; rigid parts remain rigid. Repeated saves acknowledge the existing recipe while preserving historical saved creations. | [Scoped note](Sleepy-MixUp.md#mix-up), [source](../../../App/Toys/MixUp/) |
| Feed | A friend notices currently held food with gaze, a small grounded lean and an approaching-mouth response. Withdrawal relaxes the pose; acceptance retains the existing chewing, requests and cast variety. | [Scoped note](Feed-Window-Dots.md), [source](../../../App/Toys/FeedThePeople/) |
| Window | The curtain header stays on the rod; lower cloth gathers, trails slightly and settles. Light follows the opening. Re-grabs and rapid reversals use bounded cloth state, and the existing peek-a-boo discovery remains. | [Scoped note](Feed-Window-Dots.md), [source](../../../App/Toys/GlowWindow/) |
| Drop Dots | One small rigid settling response passes down the stack after an actual landing. Pattern discoveries use restrained glows instead of competing hops/scales. Tint is slightly lighter; direct dragging, finite hands, matching colours and the return/pour loops remain. | [Scoped note](Feed-Window-Dots.md), [source](../../../App/Toys/DropDots/) |
| Hum | The existing mallet, a tiny fixed-width key deflection and the face respond to the same strike. Expression and warmth soften with the existing sound decay; repeated strikes replace the current response. | [Scoped note](Meadow-Hum-Bubbles.md#hum), [source](../../../App/Toys/Hum/) |
| Bubbles | An occasional bubble visibly carries a bird before it is popped. The same bird then leaves through the normal touch/swipe/VoiceOver pop path; ordinary bubbles retain their behavior. Passenger/departure counts and interruption cleanup are bounded. | [Scoped note](Meadow-Hum-Bubbles.md#bubbles), [source](../../../App/Toys/Bubbles/) |

New motion includes Reduced Motion alternatives and rest/rotation cleanup. Existing sound and haptic settings apply. These are implemented contracts, still subject to the physical pass below.

## Evidence and provenance

Start with this folder's [README](README.md) for exact source files, production slots, original-reference links and prompt records. [`Assets.json`](Assets.json) maps generated originals to their unmodified production copies with dimensions and SHA-256 hashes. [`Prompts.json`](Prompts.json) contains the clean-bay/tuft and shelter-layer prompts; the final neutral tuft edit is recorded separately in [`Wash-neutral-tuft-prompt.json`](Wash-neutral-tuft-prompt.json).

The [catalog inventory](../Inventory.json) is refreshed and the [asset map](../../AssetManifest.md) records the new preferred layers and preserved fallbacks. No historical artwork or saved creations were deleted. Existing art supplies Feed, Window, Drop Dots, Hum, Bubbles and Mix-Up; Sleepy Box's change is a procedural material/rendering change.

Focused verification covers production state/geometry, shape and joint registration, saved-recipe retention, recurring Meadow slot bounds, brush gesture review, curtain reversals, actual-arrival stack feedback and bird identity. Build success establishes compilation. Still images establish only the composition captured. Neither proves touch timing, audio, sustained family use or physical-device behavior.

## Confirmed simulator evidence

| Coverage | Recorded observation |
| --- | --- |
| Phone portrait: nine toys and shelf | Actual integrated scenes were rendered, viewed and captured. [Preview index](Previews/README.md). Meadow includes both [day](Previews/meadow-day.jpg) and [night](Previews/meadow-night.jpg). |
| Sleepy Box final material | The corrected wide-surface bevel is visible in the [final capture](Previews/sleepy-box.jpg). |
| Bubbles passenger | The [capture](Previews/bubbles.jpg) shows an actual bird inside a bubble before popping. This still does not verify the complete departure timing. |
| Wash final fibres | The final neutral, wider tufts are visible in [phone portrait](Previews/wash-portrait.jpg); [phone landscape](Previews/wash-landscape.jpg), [iPad Air M3 portrait](Previews/wash-ipad.jpg) and [iPad landscape](Previews/wash-ipad-landscape.jpg) were also rendered and inspected. |
| Meadow iPad and limited interaction | [Portrait](Previews/meadow-ipad.jpg) and [landscape](Previews/meadow-ipad-landscape.jpg) were captured. A native Device Hub held touch moved the mother and extended the flower trail. Rotation retained the home, route and position. This is a specific simulator observation, not a completed device-play pass. |

**Coverage limits:** Wash framing is confirmed in both orientations on the phone and iPad. The attempted brush press did not provide a reliable captured deformation state, so brush flex/settle and multi-finger behavior are not claimed as visually validated. Physical timing, audio, multitouch, Reduced Motion and VoiceOver checks remain with the founder. The simulator evidence above does not mark those acceptance checks complete.

## Founder device pass — pending

Use the same installed build throughout, with phone portrait/landscape and an iPad where available. Check the new movement with ordinary and Reduced Motion settings, muted and audible playback, and a pause/resume or rotation during an active gesture.

- **Meadow:** return babies home, then keep walking beyond the initial five. Confirm quiet new hiding places, no visible spawn/pop-in, readable routes, and a grounded shelter in day and night. Watch a baby enter under the moving leaf.
- **Wash:** rub a brush, pick up a tool with another finger, then keep rubbing. Try hose contact and nearby drain runoff. Confirm brush targets do not take vehicle/tool gestures and both room orientations stay coherent.
- **Sleepy Box:** lift, post and retrieve pieces; drag and release the drawer. Check matte grain and bevels at normal phone size, exact socket alignment, and a clean return after interruption.
- **Mix-Up:** flip mixed parts and bow; watch neck, waist, feet and soft accessories. Save the same recipe twice, then revisit older saved cards.
- **Feed:** approach from either side, hold, withdraw and then feed. Confirm gaze/mouth readability, a natural relax, and the existing chew without a forced bite.
- **Window:** pull low on the fabric, reverse quickly, release and re-grab. Check the attached top, bounded hem, day/night light and the existing close/reopen discovery.
- **Drop Dots:** make a short stack, a colour match and a rainbow; return a top dot and pour. Look for one descending settling response and clear matching colours.
- **Hum:** play single notes and rapid repeated notes. Check the mallet/key/face connection, fixed spacing, gentle decay and sound level.
- **Bubbles:** when a bird is visible inside a bubble, pop it and follow that same bird leaving. Ordinary bubbles should remain simple and easy to pop.

Home, the parent timer and saved progress should remain usable throughout. Record concrete problems against the toy and gesture; no additional broad audit is required between small fixes.

## Engineering handoff and acceptance

Source implementation, the combined Debug build, focused checks, refreshed art inventory, documentation and the confirmed simulator captures are complete. Source is pushed at `3e1405b`; the accompanying documentation/capture commit records the final evidence. This engineering handoff does not complete founder acceptance.

1. Founder: complete the focused physical pass above. Timing, audio, multitouch, Reduced Motion, VoiceOver and sustained family-use results remain **pending**.
2. Founder: use **TestFlight → Lull → 1.1 (19)** once Apple finishes processing. If the build does not appear, check this build’s availability for the existing Fam group only; do not audit testers or create unsolicited testing notes.
3. Leave the submitted 1.0 version untouched. The new upload is a TestFlight build for a later 1.1 update, not an App Review resubmission.

## TestFlight upload record — November 4

- Source: `cc4690a` (implementation `3e1405b`); working tree was clean before archive.
- Archived app Info.plist: `com.lull.toybox.a5ct5fk3sy`, version `1.1`, build `19`.
- Xcode 27.2, Release, generic iOS destination, automatic signing, team `A5CT5FK3SY`, two build jobs.
- Archive: `/Users/User2/Library/Developer/Xcode/Archives/2026-11-04/Lull-1.1-19.xcarchive`.
- DerivedData: `/private/tmp/Lull-Materials19-Device`.
- Export options: `/private/tmp/lull-materials19-export-options.plist`; `method=app-store-connect`, `destination=upload`, automatic signing, version/build preserved, symbols uploaded, no internal-only restriction.
- Archive log: `/private/tmp/lull-materials19-archive.log` — **ARCHIVE SUCCEEDED**.
- Upload log: `/private/tmp/lull-materials19-upload.log` — **Upload succeeded / Uploaded Lull / EXPORT SUCCEEDED** at 13:49:08 Central.
- Apple’s last confirmed upload status: **Uploaded package is processing**. Processing completion / tester availability was not confirmed: the existing browser tab could be listed, but the browser control adapter failed to bind it (`browser.user is unavailable`). This did not affect the successful Xcode upload.
- No tester-group changes, What to Test edits, App Review changes, pricing or metadata changes were made. Physical acceptance remains pending with the founder.
