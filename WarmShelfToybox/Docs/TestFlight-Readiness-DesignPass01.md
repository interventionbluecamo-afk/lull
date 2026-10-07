# Lull — TestFlight preparation, design pass 01

Prepared October 6, 2026. Local configuration and beta notes are prepared. A signed archive, upload, App Store Connect processing, and tester invitations have not been completed by this preparation task. See `Handoff-2026-10-06.md` for the latest Feed, Window, and rest lifecycle changes and their verification limits.

## Configured app identity

| Item | Current value / evidence |
| --- | --- |
| Display name | Lull |
| Bundle identifier | `com.lull.Lull` |
| Version | `1.0`, preserved from the existing prototype |
| Build | `1`, preserved from the existing prototype |
| Platform | iPhone and iPad, iOS 16 or later |
| Xcode target | `Lull` |
| Configured team | `A5CT5FK3SY`; ownership and membership unverified |
| Existing signing setting | `iPhone Developer` in Debug and Release; unchanged |
| Product offered in code | `com.lull.full.lifetime` |
| Legacy entitlement recognized | `com.lull.full.annual`; no annual product offered |

`App/Info.plist` now reads version/build from `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`. `project.yml` and both target configurations in `Lull.xcodeproj/project.pbxproj` agree at **1.0 (1)**. If build 1 already exists in App Store Connect, choose the next unused build number before the first upload of this design pass. Apple associates uploads with the bundle identifier/version and identifies them with the build string. [Apple: Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)

The existing team is encoded in the Xcode project but not in `project.yml`. Recheck the owner-confirmed team and signing after regenerating the project. No team, certificate, provisioning profile, or account setting was created or changed.

## What is ready locally

- The app source, assets, parent copy, and design changes can be reviewed and built locally.
- Native Swift checks passed for first onboarding, active-trial replay, expired-trial replay, and purchased-access replay. Replay preserves trial dates, purchases, hidden toys, wind-down hour, and sound preference. Re-run with `python3 Tools/verify_onboarding_state.py`.
- Shelf VoiceOver activation was connected to the existing toy-opening path. Device testing remains necessary.
- Parent onboarding now describes current access accurately. Monthly-release and all-future-library promises were removed. The actual localized purchase price remains in the parent area.
- Version/build settings are synchronized. Property-list syntax validation passed for the app plist and Xcode project.

## Apple-side pieces still to confirm

1. The owner has the appropriate Apple Developer membership and App Store Connect access, and confirms which team owns Lull.
2. An app record and registered identifier match `com.lull.Lull` exactly. Existing records/build numbers have not been inspected.
3. Xcode can sign an archive for that app and team. The main task's environment check found **zero available code-signing identities**; a configured team string alone does not establish signing readiness. Confirm the distribution signing/provisioning setup through the owner's Xcode account.
4. The lifetime purchase is configured with the matching identifier and intended product type/price in App Store Connect. No StoreKit test configuration was found in this copy; product loading, purchases, and restores are unverified.
5. A feedback contact is confirmed. `support@lull.app` is already used by the parent support action, but mailbox ownership and delivery have not been verified. A public privacy-policy URL and support URL have not been supplied or verified.
6. After local/device checks and design acceptance, archive and validate, upload, wait for processing, complete the requested beta/export information, and assign the build to a tester group. Apple documents uploading after app-record creation and lists roles permitted to upload. [Apple: Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)

Internal testing is for App Store Connect users with app access (up to 100). Family testers outside that account belong in an external group; the first external build requires beta review. TestFlight builds are usable for up to 90 days. [Apple: TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)

## Checks still needed on real devices

- Fresh install, welcome completion, shelf entry, every visible toy, return home, and relaunch on both iPhone and iPad; portrait and landscape, including a smaller supported device.
- Two-handed play, accidental extra touches, rotation during a drag, sound interruptions, background/foreground, and long play sessions. Watch for unreachable objects, missing art, frame pacing, and audio that continues after leaving a toy.
- Parent gate and every external/support/purchase route, optional play limit and parent wake, hidden-toy behavior, sound-off, haptics-off, system Reduce Motion, and the app's calmer-motion preference.
- VoiceOver shelf opening and the core toy actions, including elements whose positions or objects change during play.
- Localized product loading, purchase success/cancellation/pending/failure, restore after a clean install, and entitlement after relaunch. TestFlight uses Apple's sandbox purchase environment; this app's local seven-day trial remains separate from StoreKit. [Apple: Testing In-App Purchases in TestFlight](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testing-subscriptions-and-in-app-purchases-in-testflight)
- Adult observation of children across the intended 2–6 range: discoverability, motor effort, meaningful repetition, natural pauses, and how independently children can choose and finish. The beta has no validated educational or sleep outcome claim.

The privacy manifest currently declares no collected data, no tracking, and app-only UserDefaults use (`CA92.1`). Reviewed source uses local settings and play state; no analytics or advertising SDK was identified. These are source observations, not a certification. Confirm the final archive, owner-approved policy, and App Store Connect answers agree.

## Draft beta information

**Beta description:** Lull is a quiet shelf of tactile toys for ages 2–6. Children can stack, post shapes, drop tokens, make music, and explore at their own pace. Parents can shape the shelf, sound, motion, and quiet hours. This beta is for feedback on comfort, discoverability, and reliability.

**What to test:** Try choosing a toy without instructions, completing its main action, and returning to the shelf. Try portrait and landscape, sound off, quieter motion, and two-handed play. In the parent area, try tucking toys away and replaying the welcome. Report anything confusing, clipped, stuck, unexpectedly noisy, or difficult to reach, along with device and iOS version. Purchase/restore tests should be carried out by a grown-up after the product setup is confirmed.

**Feedback email:** Use an owner-confirmed address; the email currently in the app has not been verified.

For external testing, Apple asks for beta app information and a feedback email. These drafts can be entered after the owner confirms the contacts and build. [Apple: Provide test information](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information)
