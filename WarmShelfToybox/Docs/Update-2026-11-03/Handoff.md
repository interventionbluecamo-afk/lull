# Lull 1.1 (18) — November 3, 2026

Branch: `claude/modest-bell-cjarqm`. App: `com.lull.toybox.a5ct5fk3sy`, team `A5CT5FK3SY`.

## Release status

The founder authorized this update and its TestFlight upload. Source commit `7d7217f` is pushed. The Release archive and export both succeeded; Apple accepted **1.1 (18)** at 5:07 PM Central on November 3 and currently shows **Processing** in TestFlight. No App Review submission changes were made. Apple processing is the only remaining external step; installation availability has not been confirmed. If picking this up while processing has finished, check build 18 itself and add it to the existing Fam group only if it was not automatically assigned. Do not redo a tester/group audit or add What to Test notes.

**Do not withdraw or replace 1.0.** App Store Connect still showed 1.0 / four items Waiting for Review on November 3. This session has made no submission changes. After 1.0 is approved and the founder releases it, wait for Ready for Distribution, create the 1.1 App Store version, select the tested 1.1 build, update release copy/screenshots as needed, and submit that update. The TestFlight upload is separate from this App Review queue item.

## Included changes

- Meadow: new shared fine felt ground, sage by day / blue-green by night, soft translucent garden brush marks over the continuous felt (no cropped texture seams); existing leaf house visible from the beginning; hedgehog tuck-and-peek and two small pond ripples. Reactions preserve landmark scale, don't accumulate on repeated taps, settle during frost, restore quietly after rotation, and use opacity-only Reduce Motion feedback. No persistence or extra game loop added.
- Sleepy Box: shared hole/piece radius increased from 0.076 to 0.092 of shell height (about 21% larger, 46% more area). Rows spread over the existing front plane, expression moved into a smaller band above the drawer. Original shell aspect, top plane, socket shaping and drawer perspective retained. Tray and drag insets account for larger pieces.
- Little Wash: separate portrait bay with floor/drain visible, larger and higher vehicle with its original 1.6:1 canvas, two centered tools, towel removed from the model/UI/accessibility, subtle floor contact shadow. Helicopter shadow stays on the floor and fades during takeoff. Flexible sponge/hose completion, all twelve vehicles, drag tools, rotation and pause behavior retained.
- Grown-up help: existing Guided Access disclosure moved into PLAY with concise setup/start/end instructions and Apple's guide. External link remains behind the grown-up gate. All toy controllers and shelf request edge-gesture deferral on all edges, prioritizing that over Home-indicator auto-hide. This reduces accidental swipes; it does not lock the app. Guided Access is the actual single-app restriction. Real-device behavior remains for the founder to check.
- All nine toys retained. Website generator/output and local App Store copy remove the towel wording for the future release; no website or App Store listing changes published.

## Verification

- Release device archive and App Store Connect export/upload succeeded.
- Simulator Debug build succeeded with the installed Xcode / iOS 27.2 SDK, arm64 iPhone 18 Pro simulator (iOS 27.0).
- `verify_world_interactions.py`: 23,551 checks passed.
- `verify_meadow_little_ones.py`: 13,250 model checks and six scene checks passed.
- `verify_sleepy_box_layout.py`: 366 checks passed across phone/iPad portrait and landscape layouts.
- `verify_wash.py`: 48,700 production-model checks and 159 asset/provenance checks passed.
- `git diff --check` passed. No broad unrelated audit or repeated nine-toy playthrough.
- Portrait visual captures in `Previews/`. Final Meadow day/night, Sleepy Box and portrait Wash renders were inspected. The overloaded Mac initially captured black launch frames; those were replaced with fully rendered scenes. A visible garden seam was corrected to a low-opacity alpha-blended tint over the continuous ground. These are simulator renders, not physical-device gameplay or purchase verification.

First compile caught an unavailable `SafariServices` module in this installed SDK; the new guide now uses the app's existing gated external-browser pattern, removing that dependency. Full physical play, edge swipes, Guided Access, audio and purchase testing remain with the founder as requested.

## Art and code

Three images generated with built-in imagegen and saved into the asset catalog: `meadow-felt-ground`, `meadow-hedgehog-curled`, `wash-bay-portrait`. Exact prompts and references: `Docs/Art/Meadow-2026-11-03/` and `Docs/Art/Wash-2026-11-03/`. No API keys or runtime AI service added.

Primary changes: `App/Toys/Meadow/`, `App/Toys/SleepyDropBox/SleepyDropBoxScene.swift`, `App/Toys/Wash/`, `App/Shared/ParentInfoViewController.swift`, `ToyViewController.swift`, `ToyShelfViewController.swift` and the three focused verifiers. Both `project.yml` and `Lull.xcodeproj` carry version 1.1 / build 18.

## Founder check in TestFlight

Try the larger Sleepy Box pieces and a completed round; Wash in both orientations with the drain, two-tool dragging and helicopter; Meadow's house, ground and creature reactions; and the grown-up Guided Access instructions / accidental edge swipes. No new What to Test text or Founder Testing group audit is requested, so don't add those as follow-up work.

## Local build artifacts

- Final Debug log: `/private/tmp/lull-update18-debug-final.log`
- Final archive: `/Users/User2/Library/Developer/Xcode/Archives/2026-11-03/Lull-1.1-18-upload.xcarchive`
- Final archive log: `/private/tmp/lull-update18-archive-upload.log`
- Upload options: `/private/tmp/lull-update18-export-options.plist` (app-store-connect, destination upload, automatic signing, preserve version/build, upload symbols). Not an internal-only build: this same tested binary may be selected for 1.1 App Review later.

## References

- Apple Guided Access: https://support.apple.com/en-us/111795
- UIKit deferral: https://developer.apple.com/documentation/uikit/uiviewcontroller/preferredscreenedgesdeferringsystemgestures
- Auto-hide/deferral interaction is implementation evidence, not an explicit Apple guarantee: https://github.com/cocos/cocos-engine/pull/15920
- New-version workflow: https://developer.apple.com/help/app-store-connect/update-your-app/create-a-new-version
- TestFlight: https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/
