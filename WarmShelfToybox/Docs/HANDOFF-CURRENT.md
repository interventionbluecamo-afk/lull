# Lull — CURRENT HANDOFF (read first)

## Latest: marketing artwork — October 17, 2026 (ChatGPT)

- Created one App Store header and three Instagram/Facebook graphics for the play timer, grown-up controls and nine toys. Exports, originals, captions and exact prompts: `Docs/Marketing/2026-10-17/README.md`. Desktop pack: `Lull-Marketing-2026-10-17.zip`. Artwork has not been uploaded or published.
- Founder explicitly requested no TestFlight notes or Founder Testing verification. Do not pursue Apple sign-in or group checks as follow-up to this task. Build 1.1 (15) upload was already complete.


Updated October 12, 2026 by ChatGPT. Branch `claude/modest-bell-cjarqm` in `interventionbluecamo-afk/lull`. Mac checkout: `~/Desktop/lull v.2`.

## Current state: SUBMITTED TO APPLE

**Lull 1.0 (14) is Waiting for Review.** The founder clicked Submit for Review on October 12, 2026 at 3:33 PM America/Chicago; ChatGPT verified Apple's receipt and all four item statuses.

- Submission ID: `6a0fb891-02a0-4692-b70c-e9d49264ad07`.
- App Review: https://appstoreconnect.apple.com/apps/6819919245/distribution/reviewsubmissions/details/6a0fb891-02a0-4692-b70c-e9d49264ad07
- Submitted together: iOS App 1.0 / build 14, Lull Keep Forever (non-consumable), Lull Family Yearly (annual subscription), and Lull Family (subscription group).
- **Manual release** remains selected. Approval will not automatically publish the app.
- App Store name currently saved: **Lull: Quiet Toybox**; subtitle: Calm toys for ages 2–6.

## Final checks and corrections

- Founder explicitly confirmed build 14's welcome, purchase/restore and grown-up-page device checks pass. No duplicate agent gameplay pass.
- Build 14 was already uploaded by Claude. No new app code, build or upload was needed this session.
- Onboarding and parent-page source changes inspected: adult gate, setup, disclosed plan offer; grouped grown-up controls and constrained chevrons. No new redesign started.
- Version 1.0 had build 14 selected, final description/review notes/contact fields saved, no sign-in required and manual release selected.
- App Privacy published: Data Not Collected; live privacy URL correct.
- Age questionnaire reviewed: Made for Kids, ages 5 and under; 4+ calculated rating. Education / Entertainment categories saved.
- Both public URLs return HTTP 200: https://lulltoybox.pages.dev/privacy and /support, using `lullios@proton.me`.
- All **16 screenshot assets** (8 iPhone, 8 iPad) existed in Apple's Asset Library and became Ready for Review with this version. Local composites checked as a contact sheet. Dimensions: iPhone 1206×2622; iPad 2064×2752; all RGB. No generated replacement gameplay or new image generation.
- **Actual launch bug corrected:** the app itself was still available in all 175 territories, despite the agreed US-only plan. Set United States only and disabled automatic future-country availability. Verified 1 Available / 174 Not Available.
- Disabled untested Apple Silicon Mac distribution; Vision Pro remains off. Launch is iPhone/iPad.
- App download price verified US $0.00. Paid access remains annual $29.99 with an eligible one-week introductory offer, or Keep Forever $59.99. Family Sharing is on for both; 16-day billing grace period is on. Agreements/banking/tax previously verified Active.

## Next steps — do not restart submission preparation

1. Wait for Apple's response. No monitor/automation has been created. Founder can check App Review or bring the response to either assistant.
2. If Apple asks a question or rejects an item, address the specific finding. Do not withdraw the submission or start a broad redesign without the founder's direction.
3. After approval, founder chooses when to release. Then run `python3 Tools/Store/build_site.py --launched` from `WarmShelfToybox/` and upload `LandingPageDeploy` to Cloudflare Pages so the site points to the live App Store product.
4. The founder retained “new toys each season.” Plan the first update without delaying 1.0.

## Next update (1.1) — in progress, October 17 (Claude)

Not part of the 1.0 review. When 1.0 is approved, ship these as **version 1.1** (build 15+).
Do not upload a 1.0 build while 1.0 is in review.

1. **Done in code (committed, not uploaded): drag tools straight from the Wash tray.** The
   founder's son drags the sponge and hose from the tray rather than tapping first.
   - Touching a tool now picks it up: the slot dims, the tool rides 16 pt above the finger at
     full opacity, and it floats back to its slot on release.
   - The grab area is the whole slot.
   - Code: `App/Toys/Wash/WashScene.swift` (`Rub.carried`, `trayArt`, `carryLift`, `release`).
   - `verify_wash` passes. The founder still needs to try it on a device.
2. **Waiting on art: six new Wash vehicles** the founder's son asked for: garbage truck, mail
   truck, camper, tow truck, ambulance, and a **helicopter (special)**.
   - The founder generates them in ChatGPT with `Docs/Art/Wash-Vehicles-ChatGPT-Prompt.md`.
     It's also on the founder's Desktop as a PDF and a .txt.
   - The result arrives as `~/Desktop/lull-wash-vehicles.zip`:
     - `wash-garbage-truck`, `wash-mail-truck`, `wash-camper`, `wash-tow-truck`,
       `wash-ambulance` and `wash-helicopter`: each 1600 × 1000, vehicle width 1268 px, body
       bottom at y = 770 (helicopter skids at y = 880);
     - `wash-helicopter-rotor`: 1200 × 240.
   - **To add them:**
     1. Check each image. Faces must be blank, there must be no wheels or letters, and the
        background transparent.
     2. Add the imagesets.
     3. Add the `WashVehicleKind` cases.
     4. Measure each rig in `WashModel.swift`: face centre and radius on the windshield,
        wheel centres and radii from the arches. Wheel bottoms touch at 0.88, like the
        others.
     5. Give each vehicle a toot.
     6. Register the assets in `Tools/verify_wash.py`.
   - **Helicopter, the special visit:**
     - no wheels;
     - it descends from above with `wash-helicopter-rotor` spinning on the mast, lands on
       its skids, and the rotor slows;
     - it lifts off upward when clean;
     - it's rarer than the trucks (like the planned "rare guest", about 1 in 6 after the
       4th wash).

## Evidence, assets and context

- `Docs/Launch/Final-Submission-Check-2026-10-12.md`: scoped findings and exact receipt.
- `Docs/AppStore/Submitted-build14/`: the 16 listing composites, contact sheet and submission receipt, saved to Git for cloud Claude.
- `Docs/Launch/Submit-Day.md`: historical field-by-field guide; submission steps already complete.
- `Docs/Product-Assessment-2026-10-11.md`: longer strategic assessment and prioritized roadmap; recommendations, not new launch requirements.
- Site: https://lulltoybox.pages.dev; support: lullios@proton.me.
- Source and prior verifications are in Git. Never commit signing material, credentials, tax or banking information.
- Be token-thrifty; founder owns hands-on tests. Keep this file current and push after meaningful progress.

## October 17, 9:15 AM (Claude)
- **1.1 (15) is uploaded to App Store Connect** (by ChatGPT at 9:08 AM) and processing. It has the six new Wash vehicles and drag-from-tray. Code is committed (`08b20c5`).
- **Next:** once 1.1 (15) is Ready, the founder adds it to Founder Testing. The 1.0 (14) review is untouched. Submit 1.1 for review only after 1.0 is approved and released.
