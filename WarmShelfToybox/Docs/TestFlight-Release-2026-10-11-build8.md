# TestFlight release — Lull 1.0 (8)

October 11, 2026, America/Chicago. TestFlight only; no public App Review submission.

## Verified outcome

- Upload: `xcodebuild -exportArchive` exit 0, `Uploaded Lull`, `EXPORT SUCCEEDED`, at 12:38 PM.
- ASC processing completed. Version 1.0, build 8, UUID `289f428f-00ed-47d4-84e4-f7e787ec2cc2`.
- Group: **Founder Testing**, Internal, **one tester**; verified on the build details page.
- What to Test saved and confirmed by ASC’s Saved button. Exact text: `Verification-build8/What-to-Test.txt`.
- [Build details](https://appstoreconnect.apple.com/teams/c88f15d6-fd7f-46d6-8a5d-a0f2337031df/apps/6819919245/testflight/ios/289f428f-00ed-47d4-84e4-f7e787ec2cc2).

## Scope and checks

App source: `14a9c1f`, including `1228523` launch change. Source differences since build 7 are the launch storyboard, removal of the old animated loading scene, evening tint transition, and build number 8. All nine toys remain unchanged. No compile fixes were required.

Debug simulator, signed Release archive, and Release simulator all succeeded. All 13 `Tools/verify_*.py` passed. Initial system-Python dependency errors in two scripts are retained; reruns with bundled Python/Pillow/NumPy passed without changing verification or app logic. Expected warnings about unused self, deprecated contentEdgeInsets and absent AppIntents metadata remain in the SDK summaries.

Results: `Docs/Verification-build8/`. Full logs are local `/private/tmp/lull-build8-{debug,archive,release-simulator,upload}.log`. Signed archive: `/private/tmp/lull-build8-20261011/Lull.xcarchive`. Release simulator: `/private/tmp/lull-build8-20261011/simulator/Build/Products/Release-iphonesimulator/Lull.app`.

Proof screenshot kept locally at `/private/tmp/lull-build8-testflight.jpg`; it is not committed because the surrounding account UI is unnecessary in the repository.

## Founder testing and launch work

No new physical-device, listening, purchase or performance pass is claimed. No founder app was deleted. Restart the phone first if the old launch image persists because of iOS caching; reinstalling removes local data.

App Store screenshots, real-play preview video and public submission are not done. ASC crash metrics display a dash; this was not recorded as a zero-crash test pass. Business page checked: Free Apps Agreement Active; Paid Apps Agreement New/unsigned. Tax/banking readiness unverified; no agreement accepted.

See `Docs/Handoff-ChatGPT-to-Claude-2026-10-11-build8.md` and `Docs/Launch/Launch-Checklist.md` for exact remaining work and founder decisions. Keep the 1.0 feature freeze.
