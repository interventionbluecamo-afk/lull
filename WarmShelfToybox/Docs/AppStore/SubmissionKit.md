> **October 12 status: build 1.0 (14) was submitted and is Waiting for Review.** All four review items were received at 3:33 PM America/Chicago. See `Docs/HANDOFF-CURRENT.md` for current state; older preparation steps below are historical and must not be restarted.

# Lull — App Store submission kit

Updated October 11, 2026 for the 1.0 (8) candidate. Preparation for a public App Store
submission, in order; distribution status is recorded separately in the build handoff. Items
marked **Founder** need your accounts, money or decisions; nobody else can do them. Items
marked **Mac** are for ChatGPT on the Mac. Public App Review has not been submitted. Track
outstanding work in `Docs/Launch/Launch-Checklist.md`.

## 1. Blockers only you can clear (Founder)

1. **A working support mailbox you control.** The app and site still use `support@lull.app`;
   ownership and delivery are not confirmed. The October 7 check found the domain for sale
   with no mail server; that is historical evidence, not a current availability check. Choose
   a mailbox you own and verify sending and receiving before publishing. A paid domain is
   optional; a working existing mailbox can serve the free website. Apple requires a working
   support contact ([Guideline 1.5](https://developer.apple.com/app-store/review/guidelines/)).
   Once chosen, apply it everywhere with `python3 Tools/Store/build_site.py --email ADDRESS`
   from `WarmShelfToybox/` (app, website and privacy page; see `Docs/Launch/Website.md`).
2. **Put the website online** (`LandingPageDeploy/`: home, support, privacy, press). Recommended free
   option, **not yet chosen or deployed**: Cloudflare Pages on its
   [Free plan](https://developers.cloudflare.com/pages/platform/limits/), at `https://YOURPROJECT.pages.dev/`,
   with the working mailbox above. A paid custom domain can be added later. Cloudflare's
   [Direct Upload guide](https://developers.cloudflare.com/pages/get-started/direct-upload/)
   covers uploading the folder and getting a `pages.dev` address. Then run
   `python3 Tools/Store/build_site.py --url https://YOURPROJECT.pages.dev`: it sets the app's
   privacy link, absolute share links, the sitemap and these URLs, and you re-upload. Put the
   same live URLs in App Store Connect. Test every page and the contact link before submission.
3. **Paid Apps Agreement, tax and banking** (Account Holder, App Store Connect → Business). The
   purchase cannot load for App Review, or in sandbox, until the agreement is Active.
4. **Set up the two products** (founder decision, October 11: Lull Family + Keep Forever).
   Full steps and exact wording: `Docs/Handoff-Claude-to-ChatGPT-2026-10-11-plans.md` §2.
   - **Lull Family**, auto-renewable subscription, product ID `com.lull.family.yearly`, in a new
     subscription group "Lull Family", 1 year, $29.99 US, with an **introductory offer: Free,
     1 week**, for new subscribers.
   - **Keep Forever**: the existing non-consumable `com.lull.full.lifetime` (Apple ID
     6820224689), renamed and repriced from $9.99 to **$59.99** US.
   - A review screenshot for each: `Docs/AppStore/IAP-review-screenshot.png` (the welcome's
     offer page with the launch prices, build 12). Replace it with a TestFlight capture once
     sandbox prices load, if you like; the layout is the same.
   - **Family Sharing: on for both** (founder decision, October 11; it cannot be turned off).
   - Test in sandbox: free week, renewal, cancel during the week, Ask to Buy, restore,
     delete and reinstall, Keep Forever.
   - On the 1.0 version page, attach **both** under *In-App Purchases and Subscriptions*
     before you submit (first purchases must ride along with an app version).
5. **Access model: free week only (founder decision, October 11, build 12).** There are no
   free toys. Every family starts Lull Family's free week (Apple's introductory offer) or buys
   Keep Forever; until then the shelf shows a calm "Nine toys are waiting" card with an
   "I'm a grown-up" button, never a price or a lock. The offer (welcome page 3 and the Full
   Toybox page) shows the billed price as the largest pricing text, the free week as dated
   steps, the renewal terms, Restore purchases, and links to the Terms of Use (Apple's
   standard EULA) and Privacy Policy (Guideline 3.1.2). The welcome never opens toys by itself.
   Plan and research: `Docs/Revenue-Plan-2026-10-11.md`.
6. **Kids Category age band** (permanent once approved): choose **Made for Kids → 5 and under**.
   Lull's core is 2–5; "6–8" would put it beside reading and maths apps for older children.
7. **Where to sell.** Set both products' availability to the same territories as the app.
   A proposed English-language launch outside the EU is the US, UK, Canada, Australia and
   New Zealand. Ireland is in the EU; include it only as part of an explicit EU launch
   decision. Complete App Store Connect’s trader-status assessment; EU distribution by a
   trader requires verified contact details displayed on the EU store page. Territories and
   trader status remain founder decisions, not selections made by this document.

## 2. App Store Connect answers

**App Privacy:** *Data Not Collected* for the app’s current behavior: no analytics, ads,
accounts or transmission of play data to the developer. Family settings, the plan state, the
optional free-week reminder (a local notification) and Mix-Up creations are local, subject to the device owner’s backups. Apple handles StoreKit
product loading, purchases and restore; those operations can use the network. Support email
voluntarily sends the sender’s address and message to the support mailbox. Keep the website
policy consistent with its chosen host. The app’s required-reason API declaration is UserDefaults.

**Age rating questionnaire:** answer *None / No* to every content question (violence, fear,
mature themes, gambling, contests, medical, alcohol, unrestricted web, user-generated content,
messaging). For parental-controls or age-assurance questions, say the settings, purchases and
external links are behind an adult check. The gate is not identity or age verification.
Expected result: 4+. Read each question on screen; Apple revised this questionnaire in 2025–26.

**Category:** Kids (from Made for Kids). Primary *Education*, secondary *Games › Family*.

**Export compliance:** already answered in the binary (`ITSAppUsesNonExemptEncryption = NO`).

**Content rights:** the app contains no third-party content you lack rights to (art was made
for Lull; confirm the audio sources in `Docs/AudioDropInManifest.md` are licensed for apps and
need no attribution).

## 3. Product page text (final for 1.0 (14), October 12; paste as is)

- **Name:** Lull Quiet Toybox
- **Subtitle (22/30):** Calm toys for ages 2–6
- **Promotional text (139/170):** Try all nine felt-and-wood toys free for 7 days. No ads, no
  tracking, no accounts, and a play timer that ends with a calm rest.
- **Keywords (99/100):** `toddler,preschool,montessori,sensory,baby,music,shapes,sorting,quiet,bedtime,learning,play,kid,felt`
- **Support URL:** `https://lulltoybox.pages.dev/support` · **Marketing URL:** `https://lulltoybox.pages.dev/`
  · **Privacy Policy URL:** `https://lulltoybox.pages.dev/privacy`
- **Copyright:** 2026 Timothy Doyle

**Description:**

> Lull is a quiet toybox for little hands. Nine felt-and-wood toys invite children aged 2 to 6
> to choose, try and repeat at their own pace: no levels, no scores, nothing to lose, and
> nothing to read.
>
> THE TOYS
> • Feed: each friend asks for a snack. Give it, and watch them chew and smile.
> • Mix-Up: swap heads, tops and legs across nine friends, including a robot, a police officer and a firefighter: 729 combinations.
> • Meadow: lead a ladybug through a meadow that wakes as it passes, and find her five little ones.
> • Hum: touch the singers to make gentle music, alone or in chords.
> • Window: turn the day into evening and see who visits.
> • Sleepy Box: post each shape into its hole and open the drawer.
> • Little Wash: scrub muddy trucks clean with a sponge, a hose and a towel.
> • Drop Dots: sort twelve felt dots into their colour homes, find rainbows, and pour them out again.
> • Bubbles: pop soft bubbles and find the little treasures some carry.
>
> MADE FOR CALM
> Lull has no ads, no tracking, no accounts and no data collection. There are no stars,
> streaks or timers pushing your child to keep going. As the evening arrives, the toybox grows
> warmer and dimmer. If you set a play timer, Lull rests behind a calm moon until a grown-up
> wakes it.
>
> GROWN-UPS SET THE PACE
> Settings live behind an adult check: choose which toys are on the shelf, turn sound and
> haptics on or off, choose calmer motion, and set a play timer and a wind-down hour.
>
> TRY ALL NINE TOYS FREE FOR A WEEK
> Lull Family opens all nine toys, and the new ones that arrive each season, starting with
> 7 days free for new subscribers. With notifications enabled, Lull schedules a reminder two days before the free week ends.
> Cancel at least 24 hours before the free week ends to avoid the charge. Rather not subscribe? Keep Forever is one
> payment for every toy, for good. Both work with Family Sharing, and both are chosen by a
> grown-up, behind the adult check.
>
> Lull Family is an auto-renewable subscription: 1 year, $29.99 (US) after the free week.
> Payment is charged to your Apple Account at confirmation of purchase, after any free trial.
> It renews automatically unless cancelled at least 24 hours before the end of the current
> period. Manage or cancel in your Apple Account settings.
> Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
> Privacy Policy: https://lulltoybox.pages.dev/privacy

Before pasting, check each toy line against the approved shipping build. Little Wash replaces
Stack from build 7 onward and needs the founder's device review. Replace the privacy URL with
the hosted one. Keep learning claims at this level; do not claim outcomes.

**App Review notes (build 9 onward; revise after the support decision):**

> Lull is a Kids Category toybox for ages 2–6. No account or login. The toys work offline;
> Apple’s product loading, purchase and restore functions need App Store connectivity. No
> play data is sent to the developer; family settings and Mix-Up creations remain on device.
>
> Grown-up area: tap the small person button at the bottom right of the shelf (or hold two
> fingers on the shelf). The adult check shows three numbers written as words, for example
> "four · seven · two"; type them as digits (472). Three misses rest the check for 30 seconds.
>
> Purchases (always behind the adult check): an auto-renewable subscription,
> com.lull.family.yearly ("Lull Family", 1 year, with a 1-week free introductory offer), and
> a non-consumable, com.lull.full.lifetime ("Keep Forever"). All toys need one of them; there
> is no local or timed trial. First launch: the welcome's "Set up Lull" button asks the adult
> check, then the family's play timer and wind-down hour, then the offer page ("Start my free
> week", "Buy once", Restore purchases, Terms of Use, Privacy Policy, subscription terms).
> "Not now" explains the free week and offers "Decide later". Later, the same offer is on the
> Your plan page: the shelf's "I'm a grown-up" button or the grown-up area's "Your plan"
> row, both behind the adult check. If the grown-up allows notifications after starting the
> free week, Lull schedules one local reminder two days before it ends.
> Without a purchase the child's shelf shows only "Nine toys are waiting · A grown-up can open
> the toybox"; it never shows prices, locks or upgrade prompts. Support email (lullios@proton.me) is inside the
> grown-up area, with the privacy policy, also at https://lulltoybox.pages.dev/privacy. The device's tilt moves
> the shelf picture slightly and is never stored.

## 4. Screenshots (Mac)

Spec and captions: `Docs/AppStore/screenshots.json` (9 shots; lead with the strongest three).
Compositor: `Tools/Store/compose_screenshots.py` (warm linen, serif caption, the real capture
with rounded corners; no device frames, no fake UI).

1. Build **Release for every capture**, using the approved shipping candidate, for the
   simulators **iPhone 17 Pro Max** (6.9", 1320 × 2868) and **iPad Pro 13"** (2064 × 2752).
   Lull hides the status bar, so no status-bar override is needed.
2. Open all nine toys legitimately: start Lull Family's free week (or buy Keep Forever) with a
   sandbox account, or use a local StoreKit test configuration in Xcode. No Debug unlock or
   UI hooks.
3. Play into each moment in the spec, then
   `xcrun simctl io booted screenshot ~/Desktop/lull-captures/iphone/03-feed.png` (use the shot
   ids as file names; `ipad/` for iPad; landscape iPad captures are fine).
4. Shot 9 (`09-grownups`) uses the current **Family settings** screen: family controls first,
   then Choose shelf toys and the Your plan row farther down. Capture the controls at the
   top for the product page. The separate IAP review screenshot must show the Your plan row
   with a successfully loaded App Store price; take that from TestFlight with sandbox access
   if the Release simulator cannot load the product. Never add a price to an image by hand.
5. `python3 Tools/Store/compose_screenshots.py --captures ~/Desktop/lull-captures --out ~/Desktop/lull-store`
   → upload `iphone/*.png` to the 6.9" slot and `ipad/*.png` to the 13" slot.
6. Review all nine at thumbnail size and get the founder's approval before uploading: one
   clear subject each, nothing clipped, no developer UI, no text that contradicts the caption.
   Placeholder composites are planning aids and must never be uploaded.

## 5. Last checks before *Submit for Review* (Mac + Founder)

- Build the current 1.0 (8) candidate from this branch and run all `Tools/verify_*.py`.
  TestFlight uploads to Founder Testing are already authorized by the October 10 handoff;
  the founder’s device review and public App Review approval are separate. Before release, check:
  welcome → adult check → setup → offer → free week (sandbox); grown-up check (words → digits, three misses rest it); privacy screen;
  support email (and the copy fallback with Mail signed out); purchase and restore in sandbox.
- Resolve §1.5 before public submission and reconcile all trial copy with the approved model.
- App Store Connect: version 1.0 page filled, build selected, purchase attached, screenshots,
  App Privacy, age rating, Kids band, review notes, contact info for App Review.
- Release: choose **manual release** so you control the launch day, then switch the website
  button to the App Store link (comment in `LandingPageDeploy/index.html`).
