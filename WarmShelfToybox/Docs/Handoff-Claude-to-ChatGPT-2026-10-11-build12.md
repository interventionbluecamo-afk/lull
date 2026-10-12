# Lull — Claude → ChatGPT handoff: build 12, the free-week-only model

October 11, 2026, evening. Written by the Claude session on the founder's Mac. Branch
`claude/modest-bell-cjarqm`. Read this before doing anything else.

## 1. Where things stand

- **Build 11** (1.0 (11)) compiled, all 16 verifiers passed, and it was uploaded to TestFlight. It's
  in **Founder Testing** (Ready to Submit = ready for testers). Logs: `Docs/Verification-build11/`.
- **Build 12** (code on this branch, `CURRENT_PROJECT_VERSION` 12) is the new money model below.
  It compiles (Debug, simulator) and was checked visually in the simulator. **Not yet done for 12:**
  - the verifiers (`for v in Tools/verify_*.py; do python3 "$v" || echo FAILED $v; done` from
    `WarmShelfToybox/`). `verify_mixup_stack` and `verify_sound_kit` need
    `pip install pillow numpy`, in a throwaway venv;
  - a Release archive and the TestFlight upload;
  - fixes from the multi-agent code review that was running when this was written. If its
    results aren't in the repository, re-review the diff of the build-12 commit.
- **Upload build 12 only after App Store Connect is finished (§3).** Until then, purchases can't
  load in TestFlight, and in build 12 nothing opens without a purchase. The founder would see only
  the resting card. Keep testing build 11 until then.

## 2. What changed in build 12 (founder decision: "free week trial only, it's a paywall")

**No free toys anymore.** Every toy needs Lull Family (the yearly subscription, $29.99, with a
**7-day free introductory offer**) or Keep Forever ($59.99 once). Research behind it (RevenueCat
2025 via secondary sources): hard paywalls convert about 12% of downloads to paid, versus about 2%
for freemium. A Blinkist-style timeline with "we remind you before you pay" raised trial starts
about 23%. Sago Mini World uses a free trial too.

- **Welcome (3 pages, no swiping):**
  1. Wren, "Calm toys for little hands.", the nine toys alive in a strip, and a **Set up Lull**
     button. That button asks the adult check, as Apple's kids rules require before prices.
  2. Play timer and wind-down hour (unchanged).
  3. **"Your toybox is ready."** The page:
     - says their setup back to them;
     - shows the toys;
     - shows a price card: **$29.99 a year** is the largest pricing text (Guideline 3.1.2), with
       the "7 DAYS FREE" pill, "About $2.50 a month · for the whole family", and a dated timeline
       (Today: nothing to pay · Day 5: Lull reminds you · Day 7: $29.99/yr unless you cancel a day
       before);
     - lists four "No surprises" promises (reminder, cancel in a few taps, Family Sharing, no
       data);
     - has a "Rather not subscribe? Buy once · $59.99" card, Restore / Terms / Privacy links, and
       the legal text.
     
     The pinned button is **Start my free week**, with "7 days free, then $29.99 a year. Cancel
     anytime." under it. **Not now** opens a "Not sure yet? That's okay." sheet: the honest
     explanation, plus Start / Pay once / **Decide later**.
- **Resting shelf:** without a purchase, the child sees "Nine toys are waiting · A grown-up can
  open the toybox", with an **I'm a grown-up** button that leads to the adult check and then the
  offer. Never prices or locks.
- **Full Toybox page** (grown-up area): the same offer when not open; when open, the free-week days
  left, a "Remind me 2 days before" button, and Manage subscription.
- **Free-week reminder:** after the free week starts, Lull asks for notification permission and
  sets **one silent local notification** 2 days before the week ends. The privacy policy (app and
  website) now says so.
- **Billing grace period** is honored in code. It only takes effect once it's switched on in App
  Store Connect.
- Purchases on these screens no longer ask the adult check twice: the screens themselves are behind
  it.
- **Updated to match:**
  - website templates (`Tools/Store/site/*`, rebuilt to `LandingPageDeploy/`; the price section
    has 2 cards plus 3 steps, and the "Free" tags are gone);
  - `Docs/AppStore/SubmissionKit.md` (description and App Review notes);
  - the grown-up area's shelf-toy rows.
- **Main code:**
  - `App/Shared/LullPlansViewController.swift` (LullPlanOffer, LullFreeWeekReminder,
    LullPurchaseFlow, LullOfferView, LullOfferPauseViewController, the Full Toybox page);
  - `LullOnboardingViewController.swift`;
  - `ToyShelfViewController.swift` (resting card);
  - `ToyRegistry.swift` (all toys are `.fullToybox`);
  - `LullDemoState.swift` (StoreKit helpers, grace period).
- **Simulator QA trick:** in a Debug build, launch with `LULL_DEBUG_PLANS_PREVIEW=1`
  (shows launch prices when the store has none; the buttons do nothing),
  `LULL_DEBUG_FORCE_ONBOARDING=1` and `LULL_DEBUG_ONBOARD_PAGE=2`.

## 3. App Store Connect: what's done and what the founder must do

Checked October 11 (read-only, then the founder clicked):

- **Paid Apps Agreement:** signed, but **"Pending User Info"**. The founder must add the
  **bank account** and the **U.S. W-9 tax form** (Business). Nothing can be bought, even in
  TestFlight, until it shows Active. Claude/ChatGPT must never enter these.
- **Lull Family Yearly** (`com.lull.family.yearly`, Apple ID 6821708789, group "Lull Family"
  22465940):
  - already set: $29.99 US in all 175 countries, name "Lull Family", description, Family Sharing on;
  - **to do:**
    - **Create Introductory Offer**: all countries, start today, no end date, Free, 1 week.
      Claude's permission system blocked it from doing this; the founder must click it;
    - group display name (group page → Display Name and Description → Create → "Lull Family",
      Use App Name);
    - a review screenshot.
- **Keep Forever** (`com.lull.full.lifetime`, Apple ID 6820224689), **to do:**
  - Family Sharing → Turn On (permanent);
  - Availability: 1 of 175 countries → all;
  - check the price is $59.99;
  - rename the display name from "Lull Full Toybox" to **Keep Forever**, description "One payment,
    no subscription. Every toy, for good.";
  - a review screenshot.
- **Review screenshot** (both products): a PNG of the offer page with prices. Make it from a Debug
  simulator build with `LULL_DEBUG_PLANS_PREVIEW=1 LULL_DEBUG_FORCE_ONBOARDING=1
  LULL_DEBUG_ONBOARD_PAGE=2`, then `xcrun simctl io booted screenshot offer.png`. Or take it in
  TestFlight once prices load. It wasn't saved yet.
- **Recommended:** Subscriptions page → **Set Up Billing Grace Period**, 16 days.
- Do **not** click "Add for Review". Products are submitted with the 1.0 version, and that needs
  the founder's go.

## 4. Next steps, in order

1. Founder: bank + W-9, then the App Store Connect clicks in §3.
2. Run the verifiers, apply any confirmed review fixes, archive 1.0 (12), and upload (see
   `Docs/Handoff-Claude-to-Claude-2026-10-11-computer.md` §3 for commands). Add it to Founder
   Testing. Paste this **What to Test**:

   ```
   Build 12: the new free-week model. No free toys now.
   1. Delete Lull, install build 12. The welcome: "Set up Lull" asks the grown-up check.
   2. Last page "Your toybox is ready": is it clear? Tap "Not now" to see the reassurance sheet.
   3. Start my free week (TestFlight purchases are free). All nine toys open; allow the reminder.
   4. Grown-up area, Full Toybox: days left, Manage subscription. Cancel there; the toys stay open
      until the week ends, then the shelf shows "Nine toys are waiting".
   ```
3. Founder device checks from build 11 (Wash wheels on the floor, Sleepy Box holes, Mix-Up
   theatre, Drop Dots colour sets, Meadow little ones) still apply.
4. Website hosting (needs an address and a mailbox the founder owns): `Docs/Launch/Website.md`.

## 5. Rules (unchanged)

- Never commit signing files.
- TestFlight uploads are OK; App Review submission needs the founder's go.
- Never accept agreements or enter payment or tax details.
- Don't invent contact details.
- Child's shelf: no prices or locks.
- Purchases stay behind the adult check.
- Sound only answers touch.
- Respect Reduce Motion.
