# Lull 1.0 — launch checklist

Started October 10, 2026, at build 1.0 (8). This is the single list from here to "Submit for
Review". Owners: **Founder** (your accounts, money and decisions), **Mac** (ChatGPT on the Mac:
builds, devices, App Store Connect), **Claude** (code fixes, copy, docs). Tick items in this file
as they close. Nothing here has been submitted to Apple.

## 0. Rules from now (feature freeze)

- No new toys, features or redesigns for 1.0. All nine toys stay as they are.
- Code changes only for: confirmed bugs a tester would hit (toy, orientation, steps), App Review
  requirements, and the few "before launch" jury items in §5.
- Every other idea goes to §8 (first update after launch).
- Each code change bumps the build number, gets compiled on the Mac (Debug and Release), passes
  every `Tools/verify_*.py`, and goes to TestFlight.

## 1. Decisions only you can make

| | Decision | Recommendation |
|---|---|---|
| [x] | **Free week model** | Resolved October 11 (build 9): the local timer is gone. The free week is Lull Family's introductory offer, run by Apple (Guideline 3.1.2 disclosures in the plans card). |
| [x] | **Family Sharing** for both products (cannot be turned off later) | **On for both** (founder, October 11). |
| [ ] | **Kids age band** (permanent once approved) | Made for Kids → 5 and under. |
| [ ] | **Territories** | English-speaking first: US, UK, Canada, Australia and New Zealand if excluding the EU for 1.0. Ireland is in the EU; include it only with the applicable EU trader requirements resolved. |
| [x] | **Price** | Changed October 11 (founder): **Lull Family** $29.99 a year with a free week, or **Keep Forever** $59.99 once. Three toys free forever. Replaces $9.99 one-time. |
| [x] | **Free toys** | Bubbles, Drop Dots, Hum (founder, October 11). Little Wash is paid. |
| [ ] | **"New toys each season"** | The app, site and store page now promise it, and Lull Family's value depends on it. Confirm the first seasonal toy and its month (§8). Keep Forever includes every future toy. |
| [ ] | **Release style and target date** | Manual release. Avoid Apple's late-December slowdown. |
| [ ] | **Store name and subtitle** | "Lull Quiet Toybox" / "Calm toys for ages 2–6". |

## 2. Accounts, legal and web (Founder unless noted)

- [ ] **Public website address.** Founder prefers a free option (October 10). Recommended: Cloudflare Pages with its included `*.pages.dev` address; a paid custom domain is optional. Hosting/account and final address are not yet chosen.
- [ ] **Working support email owned by the founder.** An existing mailbox can be used; a domain mailbox is optional. Do not publish the unowned `support@lull.app` address. Claude swaps the chosen address in the app and site and rebuilds the privacy page.

### The landing page (`LandingPageDeploy/`)

**Finished October 11** and deploy-ready: home (the nine toys with Free tags, the three
plans with subscription terms), support, privacy, press, a 404 page, robots and sitemap.
No scripts or trackers. Light and dark. Checked at phone and desktop widths. How to build,
host and launch it: `Docs/Launch/Website.md`.

- [x] Refresh `assets/og.png` (1200 × 630) and `toys.webp` (1600 × 222) from all nine current shelf cards, keeping Wren. Completed October 11; reproducible script and source hashes included. No generated art.
- [x] Pages complete, with the plans, Family Sharing, Terms of Use links and a press page. One build command: `python3 Tools/Store/build_site.py`.
- [ ] Host it on Cloudflare Pages (free `NAME.pages.dev`). Founder; about 10 minutes (Website.md).
- [ ] Apply the address and the owned mailbox with **one command**. It updates every page, the
  app's `LullLinks`, SubmissionKit, the sitemap and the absolute share links. Then re-upload:
  `python3 Tools/Store/build_site.py --url https://NAME.pages.dev --email you@yourmail.com`
- [ ] App Store Connect URLs: Privacy `…/privacy.html`, Support `…/support.html`, Marketing `…/`.
- [ ] Check every page on a phone and a desktop after hosting: links, images, the email, a share preview.
- [ ] Launch day: `python3 Tools/Store/build_site.py --launched`, then re-upload.
- [ ] Later (§7): screenshots and the preview video on the press page; a founder note.
- [ ] **Paid Apps Agreement, tax and banking active.** Blocks both products, sandbox included. On October 11, ASC Business showed Free Apps Agreement Active and Paid Apps Agreement **New**, with “View and Agree to Terms.” Account Holder must complete this; tax/banking readiness has not been verified. No agreement was accepted by the agent.
- [ ] **Copyright line**: your legal name or company.
- [ ] **Make the GitHub repository private.** Revoke old tokens; give agents an App Manager role,
  not the Account Holder's.

## 3. The release candidate build (Mac + Claude)

- [ ] Fix the reproducible bugs from testing (§4). Claude.
- [ ] **Build 1.0 (11)** (supersedes 10; see `Docs/Handoff-Claude-to-ChatGPT-2026-10-11-build11.md`), Mac: the jury fixes, the two plans and the October 11 pass:
  - free toys Bubbles, Drop Dots and Hum;
  - the play timer per sitting;
  - the welcome rhythm page;
  - Drop Dots with 12 dots;
  - the Meadow little ones.

  Compile Debug and Release (the code was only syntax-checked in the cloud), run every
  verifier, add the Meadow art, and upload to TestFlight. See
  `Docs/Handoff-Claude-to-ChatGPT-2026-10-11-build10.md`.
- [x] Build 1.0 (8) compiles Debug and signed Release; all 13 verifiers pass. Logs and summaries in
  `Docs/Verification-build8/`. Completed October 11; no compile fixes needed.
- [x] TestFlight 1.0 (8) uploaded October 11, processed, assigned to Founder Testing (Internal, one tester); What to Test saved. See `Docs/TestFlight-Release-2026-10-11-build8.md`.
- [ ] **Device pass**, Founder with the Mac's help. One small iPhone, one large iPhone and one
  iPad. Portrait and landscape for every toy. Check:
  - Silent Mode on, Sound Off, Haptics Off, Reduce Motion, VoiceOver on the shelf and in two toys.
  - A phone call mid-play, headphones in and out, leaving and returning.
  - The play timer rest.
  - A 30-minute session without a stutter or crash.
- [ ] **Purchase pass in sandbox**, Founder (script in the plans handoff §4):
  - Lull Family: start the free week, see the end date, cancel during the week, let it lapse
    (the quiet dot), renew.
  - Keep Forever: buy.
  - Ask to Buy, pending then approved.
  - Restore; delete and reinstall then restore.
  - Screen Time purchases off.
- [ ] Zero crashes in TestFlight (App Store Connect → TestFlight → Crashes). Mac.
- [ ] Launch to shelf feels instant. Toys open quickly. Nothing plays sound on its own or on a
  bare tap.

## 4. Bugs to fix before launch

The code audit was stopped (token budget). Bugs come from hands-on TestFlight testing of build 8.
Report each one with the toy, the orientation and the steps. Only reproducible bugs are fixed.

- [ ] Founder plays every toy on build 10, portrait and landscape, and lists anything broken.

## 5. Jury items worth doing before launch

The jury review stopped at 2 of 8 jurors (token budget). Both scored 6/10, "could reach 8".

Fixed in build 9 (`21eb8d2`):
- [x] Little Wash always finishes; foam alone never blocks the finale.
- [x] Shelf toys open on lift, not touch-down. A second finger or a drag cancels.
- [x] Phone landscape fits all nine toys (5 + 4).
- [x] Sleepy Box drawer opens with a tap as well as a pull.
- [x] Bubbles pop under a sliding finger, not only taps.

Still worth doing before launch, if founder testing agrees (small, Claude):
- [ ] Little Wash tools show their action: a visible hose stream and a towel sheen.
- [ ] Shelf cards react when touched. Their old reactions look for parts the v2 art no longer
  has, so they do nothing. Medium size; do it only if the shelf feels dead on device.

## 6. App Store page (Founder + Mac)

- [ ] Name, subtitle, promotional text, keywords and description: `Docs/AppStore/SubmissionKit.md` §3.
  Check every toy line against build 8, including Little Wash.
- [ ] **Screenshots** from a Release build:
  - 6.9" iPhone (1320 × 2868) and 13" iPad (2064 × 2752).
  - Spec in `Docs/AppStore/screenshots.json`; compose with `Tools/Store/compose_screenshots.py`.
  - Look at all of them at thumbnail size before uploading.
- [ ] **App Preview video** (15–30 s, no UI text, real play). Strongly recommended for featuring.
- [ ] App icon final at every size; looks right on light and dark home screens.
- [ ] App Privacy: Data Not Collected. Age rating questionnaire answered (expect 4+).
  Category: Kids › 5 and under (primary Education, secondary Games › Family).
- [ ] Support, Marketing and Privacy URLs from the landing page (§2).
- [ ] **Both products** (Lull Family subscription and Keep Forever): review screenshots uploaded,
  **attached to the 1.0 version**, availability matches the app's territories.
- [ ] Subscription group "Lull Family" has its display name and an App Store localization.
- [ ] Description ends with the subscription terms, the Terms of Use (Apple EULA) and Privacy
  Policy links (SubmissionKit §3).
- [ ] Review notes (SubmissionKit §3): grown-up area and check, the two plans, no accounts.

## 7. Discovery and awards (Founder + Claude)

- [ ] **App Store featuring nomination** in App Store Connect, submitted well before launch
  (Apple’s current guidance recommends a minimum of three weeks; confirm the launch date first). [Apple guidance](https://developer.apple.com/help/app-store-connect/manage-featuring-nominations/nominate-your-app-for-featuring/). Lead with the story: a calm, wordless toybox with no ads
  and no data, where every sound is made in code.
- [x] Press page on the website: the 100-word story, a fact sheet and artwork downloads.
- [ ] Add three screenshots, the preview video and a founder note to it once they exist.
- [ ] Apple Design Awards: there is no application; Apple's team chooses from shipped apps. The
  jury plan (§5, §8) is how we raise the odds.
- [ ] Launch-day message ready for the website and social posts.

## 8. First update after launch (not 1.0)

- **The first seasonal toy** (Lull Family's promise; pick the season and toy).
- Jury, next update:
  - Shelf toys open out of their shelf object (a zoom from the card into the toy).
  - Wren visits inside the toys, not only the shelf.
  - Felt confetti and hearts in place of the generic vector ones.
  - Core Haptics textures (scrub, pop, drawer).
  - Feed: the mouth opens as food comes near.
  - Sleepy Box: the lullaby is visible (notes or a glow).
  - Hum: a soft echo.
  - Mix-Up: swipe to change parts; felt chevrons.
  - Home button robustness; a written touch vocabulary across the nine toys.
- Parked ideas: Meadow "find the little ones", Little Wash rare guests, bird wing frames,
  localisation of the grown-up area.
- Optional: a win-back or monthly plan only if data shows yearly is a barrier.

## 9. Submission day

1. Final build selected on the 1.0 version page; both products attached.
2. Everything in §6 complete; App Review contact details filled in.
3. Submit for Review with **manual release**.
4. When approved: release on the chosen day. Then `python3 Tools/Store/build_site.py --launched`
   and re-upload the website (`Docs/Launch/Website.md`).
