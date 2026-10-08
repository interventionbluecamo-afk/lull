# Lull — Mac sound build 4 checkpoint

October 8, 2026. Branch `claude/modest-bell-cjarqm` in `interventionbluecamo-afk/lull`; fetch and pull before continuing. Mac checkout `~/Desktop/lull v.2`; `WarmShelfToybox/Lull.xcodeproj`, scheme Lull. Follows `Handoff-Claude-to-ChatGPT-2026-10-08-sound.md`.

## Completed

- Pulled sound/security source **6873084d11be2a36b6796acfbf522a144a190d13**.
- Full Debug simulator and signed Release physical-device SDK builds passed. No production Swift compile fixes were needed. Both build summaries are in `Verification-build4/`.
- Device app plist confirms **1.0 (4)**, bundle `com.lull.toybox.a5ct5fk3sy`, team A5CT5FK3SY. All nine toys retained.
- All **10** `Tools/verify_*.py` scripts passed: **3,572 numeric checks**, plus onboarding/rest scenario groups and Window source assertions. New sound kit: 2,486 checks over 523 rendered sounds. Audio lifecycle: 53 checks. Full logs/revision/counts are in `Verification-build4/Summary.md` and `verification-results.json`.
- Only code change: corrected `Tools/verify_audio_lifecycle.py` test clock. Its old 20 ms increment per run-loop cycle lagged actual elapsed time under Mac load, causing a false failure for waking the breathing bed. The harness now advances using monotonic elapsed time and gives the production fade timer a final tick. All assertions remain; initial failure and diagnosis are retained. Production Swift remains unchanged.

## Installation and release status

**Installation pending:** first devicectl attempt could not establish the iPhone connection (CoreDevice 4000, control-channel reset by peer). Founder asked to unlock the iPhone, connect USB and accept Trust if shown; awaiting connection. The signed app is ready at the path below. Do not claim it installed until devicectl reports App installed.

**No build 4 archive or upload performed.** Founder owns listening/play/purchase testing and must explicitly approve this build before upload. Build 3's separate approval applies only to its recorded commit; it is not approval for build 4. Build 2 remains the last TestFlight build distributed by this Mac pass. No external beta review, public App Review submission, repository visibility change or account/credential change was performed.

No simulator play-tests, visual pass, sound listening or purchase tests were performed by the agent. Helper checks are not evidence of the actual iPhone speaker output. The scope for this handoff is compile, deterministic verification, install and founder listening — no screenshot/art/website work.

## Next action

1. With the founder's iPhone unlocked and connected, install the signed Release build below. Paired UDID: `00008150-001019AA3623C01C` (iPhone 17 Pro).
2. Founder fully closes/reopens Lull and listens using `Handoff-Claude-to-ChatGPT-2026-10-08-sound.md` → Listening guide. Check all nine toys, taps vs held notes, Sound Off, Silent Mode, headphones/interruptions and background/return. Do not repeat broad agent tests.
3. Only after explicit approval, archive/upload the matching **1.0 (4)** source to Founder Testing. If production changes meanwhile, rebuild/install that matching source and obtain approval for it; never upload an older archive under the new handoff.
4. Record actual install/approval/upload/processing/group assignment separately. Preserve ongoing Claude sound and Mix-Up work and all nine toys. Keep work/handoffs in GitHub.

## Mac-local artifacts

- Device app: `/private/tmp/lull-build4-20261008/device/Build/Products/Release-iphoneos/Lull.app`
- Simulator app: `/private/tmp/lull-build4-20261008/simulator/Build/Products/Debug-iphonesimulator/Lull.app`
- Full build logs: `/private/tmp/lull-build4-device.log`, `/private/tmp/lull-build4-simulator.log`
- First install attempt: `/private/tmp/lull-build4-device-install.log`

Signed binaries, credentials and derived data are not committed. Cloud Claude can read the production source, corrected verifier and all evidence in Git; it cannot use the Mac-local signed app.
