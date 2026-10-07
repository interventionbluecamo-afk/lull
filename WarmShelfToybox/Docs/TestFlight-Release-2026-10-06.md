# Lull TestFlight release

October 6, 2026. Upload requested by the founder.

- Apple developer team: Timothy Doyle, A5CT5FK3SY. Connected account has Admin access. Existing Apple Development signing identity works; the earlier sandbox-only zero-identity check was misleading.
- Registered explicit identifier: `com.lull.toybox.a5ct5fk3sy`. Apple rejected the prototype identifier `com.lull.Lull` as unavailable. Both source copies now use the registered identifier.
- App Store Connect record created: **Lull Quiet Toybox**, app ID **6819919245**, SKU `lull-toybox-ios-01`, English (U.S.), iOS/iPadOS. Apple rejected the plain name Lull as already in use. Home-screen name remains Lull.
- TestFlight: https://appstoreconnect.apple.com/teams/c88f15d6-fd7f-46d6-8a5d-a0f2337031df/apps/6819919245/testflight
- Version 1.0, build 1. Both optimized device archives succeeded. The registered-identifier archive is saved at `/private/tmp/lull-testflight-20261006/Lull-beta.xcarchive`; log `/private/tmp/lull-testflight-beta-archive.log`.
- Added `ITSAppUsesNonExemptEncryption=false`. No app-owned encryption or external networking dependency was found; source uses platform StoreKit.
- Production Window beam replacement visibly rendered in Device Hub on iPhone 17e/iOS 27. Final-mask dial touch attempts did not succeed through the remote input surface; earlier diagnostic dial tap was confirmed. Full gameplay/device/VoiceOver checks remain beta testing work.
- **Uploaded and enabled for internal TestFlight testing.** Xcode reported `EXPORT SUCCEEDED` and upload success at 21:37:19 UTC. Apple completed processing; the Founder Testing group visibly shows version 1.0 (1), status **Testing**, one tester and one build. The connected founder account was added and its tester status is **Invited**; automatic distribution is disabled. The build’s What to Test guidance was saved. No external group or public App Store release was created.
- Build detail: https://appstoreconnect.apple.com/teams/c88f15d6-fd7f-46d6-8a5d-a0f2337031df/apps/6819919245/testflight/ios/ca7aeea2-867b-4c9c-ab1c-5ecc9830c733
- Confirmation screenshot: `testflight-testing-2026-10-06.jpg`. Upload log: `/private/tmp/lull-testflight-upload.log`. Install through the TestFlight invitation for the connected Apple account.

## Beta description

Lull is a quiet shelf of nine tactile toys for ages 2–6: Bubbles, Feed, Stack, Sleepy Box, Window, Drop Dots, Mix-Up, Hum, and Meadow. Children explore at their own pace. Parents can adjust sound and motion, tuck toys away, and set an optional play limit. This beta seeks feedback on discoverability, comfort, and reliability.

## What to test

Try every toy and return to the shelf. Focus on feeding and missed drops; sorter openings and reset; Window dial and curtain; Hum with two fingers; and Drop Dots cancellation. Try rotation, sound off, Reduce Motion, background/foreground, and rest followed by parent wake. Test parent settings, welcome replay, and VoiceOver. Adults may test sandbox purchase and restore once the product is configured. Report confusing, clipped, stuck, or unexpectedly noisy behavior with device and iOS version. Observe whether children can discover actions without written instructions.

## Review notes

No app sign-in is required. A fresh install opens the welcome and starts a seven-day local trial with all nine toys. After the trial, Bubbles, Stack, and Drop Dots remain free. The full toybox references non-consumable `com.lull.full.lifetime`, which still needs App Store Connect product configuration. The grown-up area opens with the person button on the shelf and an addition question. Purchase and restore present another grown-up check.

Existing `support@lull.app` remains unverified. Owner-confirmed feedback and review contacts are needed before external beta review. Do not invent these. No ads or third-party analytics are included. No child usability or learning study has been completed.
