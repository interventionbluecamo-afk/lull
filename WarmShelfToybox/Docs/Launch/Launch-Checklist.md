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
| [ ] | **Free week model** (Guideline 3.1.1) | Resolve before public submission: Apple’s documented non-subscription trial uses a $0 non-consumable named "7-day Trial". Choose that flow, remove the timed trial, or obtain written clarification from App Review. The current local timer is not cleared by this checklist. See [Guideline 3.1.1](https://developer.apple.com/app-store/review/guidelines/#in-app-purchase). |
| [ ] | **Family Sharing** for the lifetime purchase (cannot be turned off later) | On. |
| [ ] | **Kids age band** (permanent once approved) | Made for Kids → 5 and under. |
| [ ] | **Territories** | English-speaking first: US, UK, Canada, Australia and New Zealand if excluding the EU for 1.0. Ireland is in the EU; include it only with the applicable EU trader requirements resolved. |
| [x] | **Price** | $9.99 one-time (founder approved). |
| [ ] | **Release style and target date** | Manual release. Avoid Apple's late-December slowdown. |
| [ ] | **Store name and subtitle** | "Lull Quiet Toybox" / "Calm toys for ages 2–6". |

## 2. Accounts, legal and web (Founder unless noted)

- [ ] **Public website address.** Founder prefers a free option (October 10). Recommended: Cloudflare Pages with its included `*.pages.dev` address; a paid custom domain is optional. Hosting/account and final address are not yet chosen.
- [ ] **Working support email owned by the founder.** An existing mailbox can be used; a domain mailbox is optional. Do not publish the unowned `support@lull.app` address. Claude swaps the chosen address in the app and site and rebuilds the privacy page.

### The landing page (`LandingPageDeploy/`)

Prepared locally; hosting, the working support email and final absolute social-image URL are still needed. The site has three pages:

- **Home:** the nine toys including Little Wash, free toys and free week, no ads/tracking/accounts,
  and an App Store button that shows "Coming soon" until launch.
- **Privacy:** the full policy, matching the one inside the app.
- **Support.**

Page links are relative. Set `og:image` to the absolute hosted URL before launch.

- [x] Refresh `assets/og.png` (1200 × 630) and `toys.webp` (1600 × 222) from all nine current shelf cards, keeping Wren. Completed October 11; reproducible script and source hashes included. No generated art.

- [ ] Host it at the chosen address, e.g. the free Cloudflare Pages subdomain. Founder.
  `_headers` adds strict security headers.
- [ ] Swap the support email (one command). Claude.
- [ ] Privacy link everywhere it's needed, all pointing at `https://<domain>/privacy.html`:
  - home footer (already there);
  - the app's grown-up area (`LullLinks.privacyPolicyURL`; Claude);
  - App Store Connect Privacy Policy URL.
- [ ] App Store Connect URLs: Support `https://<domain>/support.html`, Marketing `https://<domain>/`.
- [ ] Check every page on a phone and a desktop after hosting: links, images, the email.
- [ ] Launch day: swap "Coming soon" for the real App Store button (comment in `index.html`).
- [ ] Later (§7): a small press-kit section on the same site.
- [ ] **Paid Apps Agreement, tax and banking active.** The purchase can't load for App Review
  or sandbox without it.
- [ ] **Copyright line**: your legal name or company.
- [ ] **Make the GitHub repository private.** Revoke old tokens; give agents an App Manager role,
  not the Account Holder's.

## 3. The release candidate build (Mac + Claude)

- [ ] Fix the reproducible bugs from testing (§4). Claude.
- [ ] Build 1.0 (8)+ compiles Debug and Release, all verifiers pass, logs go in
  `Docs/Verification-build8/`. Mac.
- [ ] TestFlight to Founder Testing. Mac.
- [ ] **Device pass**, Founder with the Mac's help. One small iPhone, one large iPhone and one
  iPad. Portrait and landscape for every toy. Check:
  - Silent Mode on, Sound Off, Haptics Off, Reduce Motion, VoiceOver on the shelf and in two toys.
  - A phone call mid-play, headphones in and out, leaving and returning.
  - The play timer rest.
  - A 30-minute session without a stutter or crash.
- [ ] **Purchase pass in sandbox**, Founder: buy, cancel, Ask to Buy (pending then approved),
  restore, delete and reinstall then restore, free week running out.
- [ ] Zero crashes in TestFlight (App Store Connect → TestFlight → Crashes). Mac.
- [ ] Launch to shelf feels instant. Toys open quickly. Nothing plays sound on its own or on a
  bare tap.

## 4. Bugs to fix before launch

The code audit was stopped (token budget). Bugs come from hands-on TestFlight testing of build 8.
Report each one with the toy, the orientation and the steps. Only reproducible bugs are fixed.

- [ ] Founder plays every toy on build 8, portrait and landscape, and lists anything broken.

## 5. Jury items worth doing before launch

_To be filled from the Apple jury review now running. Only small, decisive items qualify; the
rest go to §8._

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
- [ ] In-app purchase: review screenshot uploaded, **attached to the 1.0 version**, availability
  matches the app's territories.
- [ ] Review notes (SubmissionKit §3): grown-up area and check, free week, purchase, no accounts.

## 7. Discovery and awards (Founder + Claude)

- [ ] **App Store featuring nomination** in App Store Connect, submitted well before launch
  (Apple’s current guidance recommends a minimum of three weeks; confirm the launch date first). [Apple guidance](https://developer.apple.com/help/app-store-connect/manage-featuring-nominations/nominate-your-app-for-featuring/). Lead with the story: a calm, wordless toybox with no ads
  and no data, where every sound is made in code.
- [ ] Press kit page on the website: three screenshots, the preview video, a 100-word story and
  a founder note.
- [ ] Apple Design Awards: there is no application; Apple's team chooses from shipped apps. The
  jury plan (§5, §8) is how we raise the odds.
- [ ] Launch-day message ready for the website and social posts.

## 8. First update after launch (not 1.0)

_To be filled with the jury's "next update" items and any parked ideas (Meadow "find the little
ones", Little Wash rare guests, bird wing frames, localisation of the grown-up area)._

## 9. Submission day

1. Final build selected on the 1.0 version page; the purchase attached.
2. Everything in §6 complete; App Review contact details filled in.
3. Submit for Review with **manual release**.
4. When approved: release on the chosen day. Switch the website button to the App Store link
   (see the comment in `LandingPageDeploy/index.html`).
