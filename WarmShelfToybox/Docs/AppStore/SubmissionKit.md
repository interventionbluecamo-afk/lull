# Lull — App Store submission kit

October 7, 2026. Everything needed to take Lull Quiet Toybox from TestFlight 1.0 (2) to a
public App Store submission, in order. Items marked **Founder** need your accounts, money or
decisions; nobody else can do them. Items marked **Mac** are for ChatGPT on the Mac. Nothing
here has been submitted to Apple.

## 1. Blockers only you can clear (Founder)

1. **A support address and domain you control.** Every surface says `support@lull.app`, but on
   October 7 `lull.app` was a domain **for sale** (name servers `ns1/ns2.dan.com`, no mail
   server, the site redirects to a GoDaddy for-sale page). Mail sent there goes nowhere, and
   whoever buys the domain would receive parents' emails. Apple requires a working contact
   (Guideline 1.5) and a Support URL that leads to it.
   - Either buy `lull.app` and set up the mailbox, or pick a domain you own.
   - If the address changes, run this once from `WarmShelfToybox/` (replace the address):
     `grep -rl "support@lull.app" App LandingPageDeploy | xargs sed -i '' 's/support@lull.app/YOU@yourdomain.com/g' && python3 Tools/Store/build_privacy_page.py`
2. **Put the website online** (`LandingPageDeploy/`: home, privacy, support). Free options:
   Netlify (drag the folder onto app.netlify.com/drop) or Cloudflare Pages; then point the domain
   at it. Then set `LullLinks.privacyPolicyURL` in `App/Shared/ParentInfoViewController.swift`
   to `https://yourdomain/privacy.html` so the in-app policy also links to the web copy.
3. **Paid Apps Agreement, tax and banking** (Account Holder, App Store Connect → Business). The
   purchase cannot load for App Review, or in sandbox, until the agreement is Active.
4. **Finish the lifetime purchase** (`com.lull.full.lifetime`, Apple ID 6820224689, $9.99 US):
   - Review screenshot: on a device running the TestFlight build with a sandbox account, open the
     grown-up area so the purchase card shows the real price; take a screenshot; upload it.
   - Decide **Family Sharing** (it cannot be turned off once on). Recommended: on — families with
     several devices expect it, and it is a quiet premium signal.
   - Test in sandbox: buy, cancel, Ask to Buy (pending), relaunch, delete and reinstall, restore.
   - On the 1.0 version page, attach the purchase under *In-App Purchases and Subscriptions*
     before you submit (the first purchase must ride along with an app version).
5. **Trial decision (Guideline 3.1.1).** Lull's free week is a local timer. Apple's written rule
   for free trials of non-subscription apps is a $0 non-consumable named like "7-day Trial".
   The app now states the duration, what stays free, and the real price **before** the week
   starts (the other parts of that rule), and the review notes explain it. Recommendation:
   submit as is; if App Review objects, switch to a $0 "7-day Trial" product (about half a day
   of code). Your call.
6. **Kids Category age band** (permanent once approved): choose **Made for Kids → 5 and under**.
   Lull's core is 2–5; "6–8" would put it beside reading and maths apps for older children.
7. **Where to sell.** The purchase draft is US-only. Pick the same territories for the app.
   English-only 1.0 suits the US, UK, Canada, Australia, New Zealand and Ireland. Any EU
   country requires the **EU Digital Services Act trader** declaration, which publishes an
   address, phone and email on the EU store page; skipping the EU for 1.0 avoids that for now.

## 2. App Store Connect answers

**App Privacy:** *Data Not Collected.* (No analytics, ads, accounts or network calls; StoreKit
purchases are Apple's.) The privacy manifest in the app already declares only UserDefaults.

**Age rating questionnaire:** answer *None / No* to every content question (violence, fear,
mature themes, gambling, contests, medical, alcohol, unrestricted web, user-generated content,
messaging). For parental-controls or age-assurance questions, say the settings, purchases and
the only outside link (email) are behind an adult check. Expected result: 4+. Read each
question on screen; Apple revised this questionnaire in 2025–26.

**Category:** Kids (from Made for Kids). Primary *Education*, secondary *Games › Family*.

**Export compliance:** already answered in the binary (`ITSAppUsesNonExemptEncryption = NO`).

**Content rights:** the app contains no third-party content you lack rights to (art was made
for Lull; confirm the audio sources in `Docs/AudioDropInManifest.md` are licensed for apps and
need no attribution).

## 3. Product page text (ready to paste; every claim is true in build 2)

- **Name:** Lull Quiet Toybox
- **Subtitle (22/30):** Calm toys for ages 2–6
- **Promotional text (120/170):** Nine felt-and-wood toys for little hands. No ads, no tracking,
  no accounts, and a play timer that ends with a calm rest.
- **Keywords (99/100):** `toddler,preschool,montessori,sensory,baby,music,shapes,sorting,quiet,bedtime,learning,play,kid,felt`
- **Support URL:** `https://YOURDOMAIN/support.html` · **Marketing URL:** `https://YOURDOMAIN/`
  · **Privacy Policy URL:** `https://YOURDOMAIN/privacy.html`
- **Copyright:** 2026 *your legal name or company*

**Description:**

> Lull is a quiet toybox for little hands. Nine felt-and-wood toys invite children aged 2 to 6
> to choose, try and repeat at their own pace: no levels, no scores, nothing to lose, and
> nothing to read.
>
> THE TOYS
> • Feed: each friend asks for a snack. Give it, and watch them chew and smile.
> • Mix-Up: swap heads, tops and legs to make 216 felt friends.
> • Meadow: lead a ladybug through a meadow that wakes as it passes.
> • Hum: touch the singers to make gentle music, alone or in chords.
> • Window: turn the day into evening and see who visits.
> • Sleepy Box: post each shape into its hole and open the drawer.
> • Stack: balance sleepy stones as high as they'll go.
> • Drop Dots: drop coins into the columns and pour them out again.
> • Bubbles: pop soft bubbles and find the little treasures some carry.
>
> MADE FOR CALM
> Lull has no ads, no tracking, no accounts and no data collection. There are no stars,
> streaks or timers pushing your child to keep going. As the evening arrives, the toybox grows
> warmer and dimmer. If you set a play timer, Lull rests behind a calm moon until a grown-up
> wakes it.
>
> GROWN-UPS SET THE PACE
> Settings live behind an adult check: choose which toys are on the shelf, turn sound, haptics
> and motion down, set a play timer and a wind-down hour.
>
> FREE TO TRY
> Bubbles, Stack and Drop Dots are free. Every new family gets a free week with all nine toys,
> then one optional purchase keeps them. No subscription.

Before pasting, check each toy line against the build (the founder confirmed all nine open and
play on device in build 2). Keep learning claims at this level; do not claim outcomes.

**App Review notes:**

> Lull is a Kids Category toybox for ages 2–6. No account, no login, no network features; it
> works offline. No data is collected.
>
> Grown-up area: tap the small person button at the bottom right of the shelf (or hold two
> fingers on the shelf). The adult check shows three numbers written as words, for example
> "four · seven · two"; type them as digits (472). Three misses rest the check for 30 seconds.
>
> Free week: finishing the welcome opens all nine toys for 7 days at no charge and with no
> payment details. The last welcome page states the duration, that Bubbles, Stack and Drop Dots
> stay free, and the price of the one-time purchase before the week begins. After 7 days the
> other six toys leave the child's shelf; nothing is charged.
>
> Purchase: one non-consumable, com.lull.full.lifetime ("Lull Full Toybox"), in the grown-up
> area with Restore beside it. The child's shelf never shows prices, locks or upgrade prompts.
> The only outside link is the support email, inside the grown-up area. The device's tilt moves
> the shelf picture slightly and is never stored.

## 4. Screenshots (Mac)

Spec and captions: `Docs/AppStore/screenshots.json` (8 shots; the first three show in search).
Compositor: `Tools/Store/compose_screenshots.py` (warm linen, serif caption, the real capture
with rounded corners; no device frames, no fake UI).

1. Build Debug for the simulators **iPhone 17 Pro Max** (6.9", 1320 × 2868) and **iPad Pro 13"**
   (2064 × 2752). Lull hides the status bar, so no status-bar override is needed.
2. Launch with every toy open (Debug only):
   `xcrun simctl launch --terminate-running-process booted com.lull.toybox.a5ct5fk3sy` after
   setting `SIMCTL_CHILD_LULL_DEBUG_FULL=1` in the same shell.
3. Play into each moment in the spec, then
   `xcrun simctl io booted screenshot ~/Desktop/lull-captures/iphone/02-feed.png` (use the shot
   ids as file names; `ipad/` for iPad; landscape iPad captures are fine).
4. Shot 8 (grown-ups) must come from a **Release** build (Debug shows a developer button).
5. `python3 Tools/Store/compose_screenshots.py --captures ~/Desktop/lull-captures --out ~/Desktop/lull-store`
   → upload `iphone/*.png` to the 6.9" slot and `ipad/*.png` to the 13" slot.
6. Look at all eight at thumbnail size before uploading: one clear subject each, nothing
   clipped, no developer UI, no text in the capture that contradicts the caption.

## 5. Last checks before *Submit for Review* (Mac + Founder)

- Build 1.0 (3) from this branch, run all `Tools/verify_*.py`, archive, upload, test on device:
  welcome → free week; grown-up check (words → digits, three misses rest it); privacy screen;
  support email (and the copy fallback with Mail signed out); purchase and restore in sandbox.
- App Store Connect: version 1.0 page filled, build selected, purchase attached, screenshots,
  App Privacy, age rating, Kids band, review notes, contact info for App Review.
- Release: choose **manual release** so you control the launch day, then switch the website
  button to the App Store link (comment in `LandingPageDeploy/index.html`).
