# Lull — Mac build 3 handoff to Claude cloud

October 7, 2026. Continue on `claude/modest-bell-cjarqm` in `interventionbluecamo-afk/lull`. Fetch and pull first. This follows `Handoff-Claude-to-ChatGPT-2026-10-07-release.md`. Mac checkout: `~/Desktop/lull v.2`; project `WarmShelfToybox/Lull.xcodeproj`, scheme Lull.

## Completed on the Mac

- Pulled Claude's commits `8135bcb` and `01d7b164be3e7f1be4c286f8a4453d049aa819d9`. Working tree was clean before pull.
- Full simulator Debug build **passed**. Full signed physical-device Release build **passed**. No compile fixes or production-code edits were needed, including StoreKit `AppStore.canMakePayments`, privacy controller and preview strip.
- Built app plist confirms **1.0 (3)**, bundle `com.lull.toybox.a5ct5fk3sy`, team A5CT5FK3SY.
- All **nine** `Tools/verify_*.py` scripts passed: **1,058 printed checks**, four onboarding and four rest scenarios, plus Window active-path assertions. Complete outputs and summary are committed in `Docs/Verification-build3/`. Mix-Up/Stack first stopped because system Python lacked Pillow, then passed with Codex bundled Python; both attempts retained. No script changes were needed.
- Final signed **Release build 3 installed successfully on the founder's paired iPhone 17 Pro** via devicectl. The founder should fully close/reopen Lull before checking it.
- Simulator launch succeeded. A real iPhone 17e shelf view was observed with all nine toys and no welcome covering it. This was a limited capture inspection, not a play-test.

## Exact delivery status

**Build 3 has NOT been archived or uploaded.** Founder approval for build 3's upload has not been received. Prior device approval applies to build 2 and is not presented as a build 3 acceptance result.

**Build 2 remains the processed TestFlight build assigned to Founder Testing** (one internal tester), with saved What to Test. App Store Connect app ID 6819919245. No external beta review or public App Review submission has been performed.

The existing lifetime product remains `com.lull.full.lifetime`, non-consumable, Apple ID 6820224689, US $9.99, US-only draft availability, English (U.S.) name/description and saved notes. Its review screenshot and sandbox purchase/restore checks are pending. Family Sharing remains off pending the founder's choice.

## Unfinished work — do not mark passed

- Founder owns all play-testing and purchase testing. They reiterated the usage constraint (7% remaining), then requested this passoff. No further broad play-tests were run.
- Build 3's adult check entry and three-miss cooldown, privacy scrolling/large text, two-row parent preview, smallest-phone welcome with and without loaded price, refund/revocation and purchase-restriction behavior were **not checked in the running UI**. Deterministic checks/builds are recorded separately.
- The eight App Store screenshots for iPhone/iPad were **not captured or composed**. Device Hub's screenshot action was attempted, but no verified raw capture was obtained; there are no new upload-ready store PNGs from this pass. Do not use the inspection window image or placeholders as store assets. Shot 8 still needs Release UI with an actual loaded StoreKit price. Capture specs and compositor remain in `Docs/AppStore/screenshots.json` and `Tools/Store/compose_screenshots.py`.
- No new imagegen batch, art crops/wiring, unused imageset deletion, website deployment or store metadata submission was done. Claude's prior 15-asset shadow changes were preserved.
- A real controlled support domain/email was requested from the founder; no answer received before this handoff. `LullLinks.privacyPolicyURL` remains nil, and `support@lull.app` must not be represented as a working mailbox without founder confirmation.

## Next steps

1. Read `Docs/AppStore/SubmissionKit.md`, `Docs/AppStore/ArtReview-2026-10-07.md`, and `Docs/Verification-build3/SUMMARY.md`.
2. Have the founder check the installed build 3 parent changes, then obtain explicit approval before archiving/uploading **1.0 (3)** to Founder Testing. Leave play/purchase testing to them. No public App Review submission is authorized.
3. Keep all nine toys, the Mix-Up redesign/save migration, audio lifecycle fixes, and approved $9.99 lifetime product. Avoid another broad art pass while usage is tight.
4. Collect the founder's real domain and mailbox; update shared links, policy and website together. Account owner handles agreement/tax/banking. Founder decides trial model, Family Sharing, Kids age band and sale territories. Independently confirm current Apple rules before advising on the local-timer trial; the kit's proposed submit-as-is route is not an acceptance guarantee.
5. Finish verified real store captures and composition on the Mac after usage is replenished; cloud Claude cannot capture the local simulators or upload using Mac signing credentials. Keep originals/provenance and composed assets in Git as requested.
6. Commit work and a fresh handoff in GitHub. Do not conflate compiled code, helper checks, installed app, founder acceptance, upload, processing and public approval.

## Mac artifacts (not cloud-accessible)

- Simulator app: `/private/tmp/lull-build3-20261007/simulator/Build/Products/Debug-iphonesimulator/Lull.app`
- Signed device app: `/private/tmp/lull-build3-20261007/device/Build/Products/Release-iphoneos/Lull.app`
- Full build logs: `/private/tmp/lull-build3-simulator.log`, `/private/tmp/lull-build3-device.log`
- Install success log: `/private/tmp/lull-build3-device-install.log`

No signed binary, credentials or temporary derived data is committed. Root's only repo additions in this pass are verification results and handoff/release documentation; application source is still Claude's `01d7b16`.

## Concurrent Claude work preserved

Before this handoff push, GitHub advanced with `73b760e` (coordination note) and `ad707c5` (`Tools/Audio/lullsynth.py`). These commits were preserved by rebasing this documentation-only handoff. They do not change the production Swift built above; the new synthesis toolkit was not run or verified by this pass.

Claude is rebuilding sound and adding robot, officer and firefighter Mix-Up characters in parallel. Root made no changes to AudioManager, LullToneEngine, audio resources, Mix-Up source or its imagesets. Follow the coordination note in Claude’s release handoff; do not overwrite those files or delete the legacy Mix-Up art. The recorded build/check results apply to the `01d7b16` application source. Any subsequent production changes require a new matching build and founder acceptance before upload.
