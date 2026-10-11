# Lull — Claude → Claude handoff (computer-control session on the founder's Mac)

October 11, 2026. Written by the cloud Claude session for the next Claude session, which will
control the founder's Mac. Read all of this before acting.

## 1. Who and what

- **The founder** owns the Mac, Apple accounts, money and every decision. They aren't a
  developer: give plain, step-by-step words, and do the clicking yourself where you can.
  They are token-conscious: don't run big multi-agent fan-outs unless asked.
- **Lull** (repository folder `WarmShelfToybox`) is a calm felt-and-wood iOS toybox for ages
  2–6. Nine toys: Bubbles, Drop Dots, Hum (free), Little Wash, Feed, Window, Mix-Up,
  Sleepy Box, Meadow (paid).
  - UIKit plus SpriteKit, iOS 16 deployment target.
  - Bundle ID `com.lull.toybox.a5ct5fk3sy`, team `A5CT5FK3SY`, App Store Connect app ID
    `6819919245`.
- **Repository:** `github.com/interventionbluecamo-afk/lull`, branch
  **`claude/modest-bell-cjarqm`** (work only on this branch).
- **Mac checkout:** `~/Desktop/lull v.2`. Project:
  `~/Desktop/lull v.2/WarmShelfToybox/Lull.xcodeproj`, scheme `Lull`.
  `project.yml` (XcodeGen) is kept in sync, but the checked-in `.xcodeproj` is what gets built.
- **Build number:** `CURRENT_PROJECT_VERSION` is **11** in `project.yml` and in
  `project.pbxproj` (2 places). Marketing version 1.0.
- **Goals:** premium, Apple Design Award quality, App Store featuring.

## 2. Hard rules

- **Never commit or upload signing material:** `.p8`, `.p12`, `.mobileprovision`, `AuthKey*`.
- **TestFlight uploads are authorised. Public App Review submission is NOT.** It needs
  `Docs/Launch/Launch-Checklist.md` §1–§6 done and the founder's explicit go.
- **Never accept agreements** (Paid Apps Agreement, etc.) or enter payment or tax details. The
  Account Holder (the founder) does that.
- **Never delete the app** from App Store Connect, and never delete data or builds without asking.
- **Don't invent contact details.** `support@lull.app` is NOT owned; the founder will choose a
  mailbox.
- **Commits:**
  - Clear messages, ending with the attribution the session tells you to use.
  - No AI model names in commits.
  - Push to `claude/modest-bell-cjarqm`. No pull request unless asked.
  - On the Mac's git: when a merge opens the vim editor, use `Esc`, then `:wq`, then `Enter`
    (or pass `--no-edit`).
- **Design rules** (for any code change):
  - The child's shelf never shows prices, locks or plans.
  - Purchases and external links stay behind the adult check (`AdultGate`).
  - Sound answers outcomes only: nothing plays on its own or on a bare tap.
  - Faces are live code, never baked into art.
  - Respect Reduce Motion.

## 3. Your job right now: get build 11 onto TestFlight

State as of this handoff:
- The founder tried **Product → Archive** in Xcode. The first build failed on one error: "two
  `viewDidAppear` overrides in `ParentInfoViewController`". That is **fixed and pushed**
  (`eb77a2f`).
- Build 11 has **never compiled successfully** yet. More compile errors are possible; nothing in
  builds 9–11 was compiled against the iOS SDK before (cloud Claude only had `swiftc -parse`).

Steps:

1. **Terminal:**
   ```
   cd ~/Desktop/"lull v.2"
   git status
   git pull --no-rebase --no-edit origin claude/modest-bell-cjarqm
   ```
2. **Xcode:**
   - Open `WarmShelfToybox/Lull.xcodeproj`.
   - Set the run destination (top bar) to **Any iOS Device (arm64)**. It was on the
     "iPad (A16)" simulator, and you can't archive for a simulator.
   - **Product → Clean Build Folder**, then **Product → Archive**.
3. **On compile errors:** fix them minimally in the Swift files.
   - Read the error, fix that line, and say what you did in the commit.
   - Don't redesign anything.
   - Most likely spots, all new and never compiled:
     - `App/Shared/LullPlansViewController.swift` (moved from `ParentInfoViewController`,
       with duplicated small helpers);
     - `App/Shared/ParentInfoViewController.swift` (`makeChevronRow(…detail:…)`);
     - `App/Shared/LullDemoState.swift` (StoreKit 2: `Product.SubscriptionInfo.isEligibleForIntroOffer`,
       `introductoryOffer.paymentMode/.period`, `subscriptionPeriod`, `status`,
       `RenewalInfo.willAutoRenew`, `Transaction.offerType/.productType/.expirationDate`);
     - `App/Toys/Meadow/MeadowLittleOnes.swift`;
     - `App/Toys/DropDots/DropDotsScene.swift` (`buildTray(…slots:)`, `makeRingTint`,
       `DropDotsColourSets`, `nextColourRound`);
     - `App/Toys/MixUp/MixUpScene.swift` (`addTheatreCurtains`, `softFloor`, `stageArtFrame`,
       `keepsakePosition`);
     - `App/Toys/SleepyDropBox/SleepyDropBoxScene.swift` (`SleepyBoxShellLayout`);
     - `App/Toys/Wash/WashScene.swift` and `WashModel.swift` (`WashBayFit`);
     - `App/Shared/AdultGate.swift` (`LullPlaySitting`, `LullPlayTimer`);
     - `App/Shared/LullOnboardingViewController.swift` (`rhythmPage`, `makeChoicePill`,
       `scaled`).
   - Also build **Debug** once (Product → Build) to catch `#if DEBUG` code.
4. **Verifiers:**
   - Run them from `~/Desktop/lull v.2/WarmShelfToybox`:
     `for v in Tools/verify_*.py; do echo "== $v"; python3 "$v" || echo "FAILED $v"; done`.
     On the Mac they use `xcrun swift`/`swiftc`.
   - Save the output to `Docs/Verification-build11/`.
   - Fix real failures. `verify_world_interactions.py` and `verify_window.py` only run on macOS.
5. **Commit and push** the fixes and logs:
   `git add -A && git commit -m "…" && git push origin claude/modest-bell-cjarqm`.
   First check `git status` for signing files.
6. **Upload:**
   - After "Archive Succeeded", the Organizer opens. If it doesn't: **Window → Organizer →
     Archives → Lull**.
   - Select **1.0 (11)**, then **Distribute App → App Store Connect → Upload**, keeping the
     defaults (automatic signing, team A5CT5FK3SY).
   - Wait for "Upload Successful".
7. **App Store Connect** (appstoreconnect.apple.com → Apps → Lull → TestFlight):
   - Wait for build 11 to finish processing.
   - Export compliance: **No** (no non-exempt encryption).
   - Add the build to the internal group **Founder Testing**.
   - Paste the **What to Test** from `Docs/Handoff-Claude-to-ChatGPT-2026-10-11-build11.md`
     (step 5).
8. Tell the founder it's ready in the TestFlight app, and **record it**: add a short
   `Docs/TestFlight-Release-2026-10-11-build11.md` (upload time, build, group) and push.

## 4. What builds 9–11 contain (so you can answer questions and test)

**Build 9** (jury fixes and new pricing):
- Wash always finishes.
- Shelf toys open on lift, and a second finger cancels.
- Phone landscape shelf shows 5 + 4.
- The Sleepy Box drawer opens on tap.
- Bubbles pop as a finger slides.
- **Pricing:**
  - Lull Family is an auto-renewable subscription, `com.lull.family.yearly`, $29.99/yr, in
    group "Lull Family", with a 1-week free introductory offer.
  - Keep Forever is the non-consumable `com.lull.full.lifetime` (Apple ID 6820224689),
    repriced from $9.99 to **$59.99**.
  - **Family Sharing is on for both** (founder).
  - There is no local trial anymore; the free week is Apple's intro offer.

**Build 10** (founder pass):
- **Free toys** are now Bubbles, Drop Dots and Hum; Little Wash is paid.
- **Play timer** counts per sitting and survives force-quit; an hour away starts a fresh sitting.
- **Welcome page 2** ("Your family's rhythm"): the play timer comes first (30 min suggested),
  then the wind-down hour, then where to change them.
- **Grown-up area:** the play timer card comes first.
- **Drop Dots:** 12 dots in a two-row tray. Home columns, rainbow rows and an all-sorted finale.
- **Meadow "find the little ones":**
  - Five baby ladybugs hide, follow her and hop between the flowers; she leads them home to
    the leaf house.
  - The art arrived from ChatGPT (`meadow-baby-ladybug`, `meadow-leaf-house`,
    `meadow-leaf-house-glow`, `meadow-hide-leaf`).

**Build 11** (founder notes on build 10):
- **Wash:** wheels stand on the painted floor (`WashBayFit`).
- **Sleepy Box:** holes sit on the box's front face (`SleepyBoxShellLayout`).
- **Mix-Up:** a felt theatre (round stage art, curtains, valance, soft floor, the heart kept
  clear).
- **Drop Dots:** a new felt colour set after every pour (5 sets), and the rings re-tint.
- **Full Toybox:** purchases moved to their own page, `LullPlansViewController`. The grown-up
  area has one "Full Toybox" row.

Details:
- **Plans:** `Docs/Plan-Build10.md` and `Docs/Plan-Build11.md`.
- **Handoffs:**
  - `Docs/Handoff-Claude-to-ChatGPT-2026-10-11-build10.md`;
  - `Docs/Handoff-Claude-to-ChatGPT-2026-10-11-build11.md` (the device-check list, and an
    "adjust here" table for each fix).

## 5. Device checks the founder should do on build 11

- **Wash:** the wheels touch the floor in portrait and landscape.
- **Sleepy Box:** the holes sit below the lid, and the pieces are still chunky enough.
- **Mix-Up:**
  - The curtains don't cover the cards or controls.
  - The heart is clear of the stage.
  - Is the curtain red right?
- **Drop Dots:** the ring colour overlays line up with the painted rings; after a pour a new
  colour set appears.
- **Meadow:** the babies' size, the hop over flowers, the house at home, the all-home finale.
- **Welcome page 2** fits on a small iPhone.
- **Play timer:** force-quit during the rest, and the rest comes back.
- **Full Toybox page:** opens from the grown-up row and from the welcome.

Tweak numbers are in the build 11 handoff's last table.

## 6. App Store Connect state (not finished; founder decisions)

- **Paid Apps Agreement:** was "New" (not accepted) on October 11. **The Account Holder must
  accept it and add tax and banking.** Until then purchases can't be tested, even in sandbox.
  Don't accept it for them.
- **Products:** Lull Family may still need creating, and Keep Forever repricing to $59.99.
  Exact setup is in `Docs/Handoff-Claude-to-ChatGPT-2026-10-11-plans.md` §2:
  - group "Lull Family";
  - product `com.lull.family.yearly`, 1 year, $29.99, intro offer Free 1 week;
  - Family Sharing on;
  - localization "Lull Family" / "All nine toys, plus new ones each season.";
  - review screenshot of the Full Toybox page;
  - Keep Forever renamed "Keep Forever" at $59.99;
  - both attached to the 1.0 version.

  Do this only with the founder watching and approving. ChatGPT may have started it; check
  what exists first.
- **Sandbox purchase test script:** the plans handoff §4. Sandbox time runs fast: the 1-week
  trial lasts about 3 minutes and a year about 1 hour.

## 7. Other open items (in `Docs/Launch/Launch-Checklist.md`)

- **Website** (`LandingPageDeploy/`): finished, not hosted.
  - The founder needs a free Cloudflare Pages address and a mailbox they own.
  - Then run `python3 Tools/Store/build_site.py --url https://NAME.pages.dev --email ADDRESS`
    from `WarmShelfToybox/` and upload the folder. Guide: `Docs/Launch/Website.md`.
  - At launch: `--launched`.
- **Founder decisions still open:**
  - Kids age band (recommended 5 and under), territories, release date (manual release).
  - Name and subtitle ("Lull Quiet Toybox" / "Calm toys for ages 2–6"), copyright line.
  - Make the GitHub repository private.
  - The first "new toys each season" toy.
- **Offered and not yet approved:** a fix so access isn't lost during Apple's billing grace
  period. `LullPurchaseManager.isFullToyboxTransaction` rejects `expirationDate < now`, which
  may lock toys during a billing retry. Ask before doing it.
- **Store page:** screenshots (Release build, 6.9" iPhone 1320 × 2868 and 13" iPad 2064 × 2752;
  spec in `Docs/AppStore/screenshots.json`; `Tools/Store/compose_screenshots.py`), an App
  Preview video, and a featuring nomination (at least 3 weeks before launch).
- **After launch (§8 of the checklist):** jury ideas, seasonal toys.

## 8. Where things are

| What | Path (inside `WarmShelfToybox/`) |
|---|---|
| Launch checklist (source of truth) | `Docs/Launch/Launch-Checklist.md` |
| Store copy and review notes | `Docs/AppStore/SubmissionKit.md` |
| Toys | `App/Toys/<Toy>/` |
| Shared app code (shelf, onboarding, parent area, plans, state, timer, gate) | `App/Shared/` |
| Art | `App/Resources/Assets.xcassets/` |
| Verifiers | `Tools/verify_*.py` |
| Website source and build | `Tools/Store/site/`, `Tools/Store/build_site.py` → `LandingPageDeploy/` |
