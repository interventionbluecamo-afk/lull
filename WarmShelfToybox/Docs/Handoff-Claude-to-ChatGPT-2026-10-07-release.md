# Lull — Claude → ChatGPT handoff: public-release pass

October 7, 2026, evening. Continues `Handoff-ChatGPT-to-Claude-2026-10-07.md`. Branch
`claude/modest-bell-cjarqm` in `interventionbluecamo-afk/lull`; pull before building. Mac
checkout `~/Desktop/lull v.2`, project `WarmShelfToybox/Lull.xcodeproj`, scheme `Lull`. All nine
toys stay; the Mix-Up redesign, the sound fixes and the $9.99 lifetime unlock are preserved.
The founder owns all play-testing and purchase testing; do not repeat broad play-tests.

Read next: `Docs/AppStore/SubmissionKit.md` (what submission needs, who does it) and
`Docs/AppStore/ArtReview-2026-10-07.md` (art findings and imagegen prompts).

## What changed in this pass

**App code** (commit `8135bcb` and the commit after it; no new Swift files, so the Xcode project
needs no new file references):
- `AdultGate.swift`: the grown-up check now shows three digits as words ("four · seven · two")
  to type as digits; a new question after each miss; three misses rest the check for 30 s
  (counts survive closing the check). Logic is in `AdultGateChallenge` (UIKit-free).
- `ParentInfoViewController.swift`: `LullLinks` (support email, optional privacy URL) in one
  place; a **Privacy** row opens `LullPrivacyViewController` (the policy, readable offline, same
  words as the website); Support falls back to a "Copy address" alert when no mail app is set
  up; Screen Time purchase limits are explained and disable the button; locked toys read "Part of
  the full toybox"; promise reads "No tracking or accounts — play stays on this device".
- `PaywallPreviewStrip.swift`: the parent offer shows the real felt shelf toys (from
  `ToyShelfScene.shelfObjectArt`, now internal), two rows of three on phones, breathing and a
  small hello (still under Reduce Motion); one accessibility label lists the included toys.
- `LullOnboardingViewController.swift`: the last welcome page is shorter (timeline, then the
  grown-up button, then one gate note) and names the real App Store price before the free week
  starts (loads products on open; offline it points to the grown-up area). Now imports StoreKit.
- `LullDemoState.swift`: refunds/revocations from `Transaction.updates` recheck entitlements;
  the purchase error is parent-facing.
- Copy: "handmade" claims replaced ("felt-and-wood", "calm, unhurried play").
- Build number **3** in `project.yml` and both `project.pbxproj` configurations.

**Art:** teal key-background shadows replaced with warm shadows on 15 assets (`despill.py`; see
the art review). No other art changed.

**Website:** `LandingPageDeploy/` replaced with a small static site: `index.html` (download
button shows "Coming soon" until launch), `privacy.html` (generated from the in-app policy by
`Tools/Store/build_privacy_page.py`), `support.html`, `site.css`, `assets/`. No cookies,
trackers or third-party fonts. The old concept images and press kit (which showed the parked
Bloom toy) were removed from the deploy folder; they remain in Git history and
`LandingPageSource/`.

**Store tooling:** `Docs/AppStore/screenshots.json` (8 shots, captions, what to capture) and
`Tools/Store/compose_screenshots.py` (upload-ready 1320 × 2868 iPhone and 2064 × 2752 iPad).

## Verification done here (Linux, no Xcode)

- `swiftc -parse` passes on every Swift file in `App/` and `App/Shared/`.
- `Tools/verify_adult_gate.py` compiled and ran the production `AdultGateChallenge`: 12 checks
  passed (format, accepted/rejected answers, 4,000-question spread, rest constants).
- Website rendered in headless Chromium (desktop and narrow widths).
- **Not done:** an iOS build or any simulator/device run of these changes.

## Your job on the Mac, in order

1. Pull, build Debug for a simulator and Release for a device; fix compile errors (likely spots:
   `AppStore.canMakePayments` availability, the `LullPrivacyViewController` layout, the new
   `PaywallPreviewStrip` height constraint).
2. Run every `Tools/verify_*.py` (add `verify_adult_gate.py`) and commit logs to
   `Docs/Verification-build3/`.
3. Quick look only (the founder does the real testing): the grown-up check accepts the typed
   digits and rests after three misses; Privacy opens and scrolls with large text; the offer
   shows six felt toys in two rows on iPhone; the last welcome page fits on the smallest iPhone
   with and without a loaded price.
4. If the founder has generated the new art (prompts A–D in the art review), crop and wire it
   with the existing imageset names and check each toy once.
5. Capture the eight store screenshots per `SubmissionKit.md` §4 and compose them; commit the
   composed PNGs to `Docs/AppStore/screenshots/` (not the asset catalog).
6. Optional, with a build after each step: remove unused legacy imagesets (art review item 10).
7. Archive and upload **1.0 (3)** for Founder Testing only after the founder approves; record it
   in `Docs/TestFlight-Release-…md`. Do not submit for App Review; that is the founder's step
   after `SubmissionKit.md` §1 is cleared.

## Founder-only blockers (do not invent these)

The support address `support@lull.app` is on a domain that was for sale on October 7, so it
cannot receive mail. A real mailbox and domain, hosting the website, the Paid Apps Agreement /
tax / banking, the purchase review screenshot and Family Sharing choice, the Kids age band, the
territories, and the trial-model decision are all listed in `SubmissionKit.md` §1. When the
founder gives the real address and domain, apply them with the one-line command there and set
`LullLinks.privacyPolicyURL`.
