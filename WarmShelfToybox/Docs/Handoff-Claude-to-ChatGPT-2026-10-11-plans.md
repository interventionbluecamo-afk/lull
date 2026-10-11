# Lull — Claude → ChatGPT handoff: build 9, the two plans, App Store Connect setup

October 11, 2026. Branch `claude/modest-bell-cjarqm` in `interventionbluecamo-afk/lull`; pull first.
Mac checkout `~/Desktop/lull v.2`, project `WarmShelfToybox/Lull.xcodeproj`, scheme `Lull`.

The source of truth for what's left is still `Docs/Launch/Launch-Checklist.md`. It has been updated
for everything below.

Rules:
- The feature freeze holds. All nine toys stay.
- Never commit signing keys (.p8, .p12, .mobileprovision, AuthKey files).
- TestFlight uploads are authorised. **Public App Review submission is not**: it needs checklist
  §1–§6 done and the founder's explicit go.

## 1. What changed since build 8

**Founder decision (October 11): new pricing.** The $9.99 one-time unlock and the on-device free
week are replaced by two App Store plans:

| Plan | Product ID | Type | Price (US) |
|---|---|---|---|
| **Lull Family** | `com.lull.family.yearly` (new) | Auto-renewable, 1 year, group "Lull Family" | $29.99 a year, **introductory offer: free for 1 week** |
| **Keep Forever** | `com.lull.full.lifetime` (existing, Apple ID 6820224689) | Non-consumable | **$59.99** (was $9.99) |

- Bubbles, Little Wash and Drop Dots stay free forever. No ads, no data, no accounts.
- Lull Family promises new toys each season. Keep Forever includes every future toy.

**Commits:**
- `21eb8d2`, the jury fixes:
  - Little Wash always finishes.
  - Shelf toys open on lift (a second finger or a drag cancels).
  - Phone landscape shelf fits all nine (5 + 4).
  - Sleepy Box drawer opens on tap.
  - Bubbles pop under a sliding finger.
- `d1a86bd`, the plans:
  - `App/Shared/LullDemoState.swift`: products, StoreKit 2 entitlement and plan state.
    - The local trial is deleted, and its stored keys are cleared on launch.
    - Access is exactly the StoreKit entitlement.
    - The free week's end date and auto-renew state are cached for display.
  - `App/Shared/ParentInfoViewController.swift`: the plans card.
    - Two tiles; the billed price is the largest text.
    - Apple's renewal terms, **Terms of Use** (Apple's standard EULA) and **Privacy Policy** links.
    - Manage subscription (Apple's in-app sheet), Restore purchases.
    - The "Start the free week" button.
  - `App/Shared/LullOnboardingViewController.swift`: the last welcome page.
    - It explains the free toys, Lull Family and Keep Forever.
    - The primary button "Try all nine free" opens the plans behind the adult check.
    - "Start with the free toys" finishes the welcome.
    - The welcome never opens toys by itself.
  - `App/SceneDelegate.swift`: entitlements are rechecked on every return to the foreground.
  - Parent chip's quiet dot: shows on the free week's last day, and after a plan ends until a
    grown-up opens the parent area.
  - Copy updated:
    - in-app privacy policy (effective October 11) and the regenerated `privacy.html`;
    - website home and support pages;
    - `Docs/AppStore/SubmissionKit.md` (products, description with EULA, review notes);
    - `Docs/Brand.md`;
    - `Assets/Marketing/Cards/6-price.html`.
  - `Tools/verify_onboarding_state.py` rewritten for the plan model (8 checks; passes).
- `CURRENT_PROJECT_VERSION` is **9** in both project definitions (build 9 was never uploaded).

**Not verified in the cloud:**
- The StoreKit and UIKit code was only syntax-checked (`swiftc -parse`); there's no iOS SDK here.
- `verify_onboarding_state.py` and `verify_audio_lifecycle.py` pass. `verify_wash.py` passed on
  `21eb8d2`.
- Expect possible small compile fixes. The APIs used are:
  - `Product.SubscriptionInfo.isEligibleForIntroOffer`, `introductoryOffer` (`paymentMode`,
    `period`), `subscriptionPeriod`, `status`;
  - `RenewalInfo.willAutoRenew`;
  - `Transaction.offerType`, `productType`, `expirationDate`, `originalID`;
  - `AppStore.showManageSubscriptions(in:)`, `AppStore.canMakePayments`.

  Deployment target: iOS 16. Fix minimally and say so in the commit.

## 2. App Store Connect setup (Founder + Mac)

### 2.1 Prerequisite

Business → **Paid Apps Agreement** must be **Active**: Account Holder only, with tax and
banking. On October 11 it was "New". Nothing below can be bought, even in sandbox, until then.
Don't accept agreements on the founder's behalf.

### 2.2 Lull Family (new auto-renewable subscription)

Apps → Lull → Monetization → **Subscriptions**:

1. **Create a subscription group.**
   - Reference name: `Lull Family`.
   - Group localization, English (U.S.): Display Name `Lull Family`.
2. **Create a subscription** in that group.
   - Reference name: `Lull Family Yearly`.
   - Product ID: **`com.lull.family.yearly`**. It must match exactly; IDs can never be reused.
3. **Subscription Duration:** 1 Year.
4. **Availability:** the same territories as the app (checklist §1).
5. **Subscription Prices:** base country United States, **$29.99**. Accept Apple's
   equalised prices for the others unless the founder wants round numbers.
6. **Introductory Offer** (Subscription Prices → "+" → Create Introductory Offer):
   - countries: all;
   - start: today, no end date;
   - type **Free**, duration **1 Week**.
7. **Family Sharing:** on, if the founder confirms (checklist §1). It cannot be turned off later.
8. **Localization**, English (U.S.):
   - Display Name `Lull Family`;
   - Description `All nine toys, plus new ones each season.`
9. **Review Information:**
   - Screenshot: the plans card on a device, from a TestFlight build with a sandbox account
     (real prices).
   - Notes: "Opens all nine toys. Bought in the grown-up area behind an adult check."
10. Tax category: the default (app software) unless the founder's accountant says otherwise.

### 2.3 Keep Forever (existing non-consumable, repriced)

Monetization → **In-App Purchases** → `com.lull.full.lifetime`:

1. Reference name: `Lull Keep Forever`. The product ID cannot change, and doesn't need to.
2. **Price:** United States **$59.99**, replacing $9.99. Apply to all territories.
3. Localization, English (U.S.):
   - Display Name `Keep Forever`;
   - Description `Every toy, now and later, for good.`
4. **Family Sharing:** on, if confirmed.
5. A new review screenshot: the plans card.

### 2.4 The 1.0 version page

1. Under **In-App Purchases and Subscriptions**, attach **both** products. A first subscription
   and a first IAP must ride with an app version.
2. **Description:** paste SubmissionKit §3. It ends with the subscription terms, the Terms of
   Use (Apple EULA) URL, and the Privacy Policy URL (once hosted). Guideline 3.1.2 needs these
   in the metadata as well as in the app.
3. **License Agreement:** leave Apple's standard EULA.
4. **App Review notes:** the new SubmissionKit §3 text. It describes both products, where they
   are, and says there is no timed trial.
5. **App Privacy** is unchanged: Data Not Collected. Apple handles purchases; the app stores
   only the plan state on the device.

### 2.5 Local testing (optional, helpful)

In Xcode: File → New → **StoreKit Configuration File** → "Sync this file with an app in App
Store Connect". Select it in a *local copy* of the scheme (Run → Options → StoreKit
Configuration). This lets the simulator show both plans, the free week and renewals before
the agreement is active. Don't change the shared `Lull` scheme, and don't ship it.

## 3. Build 1.0 (9)

1. Compile Debug and signed Release.
2. Run every `Tools/verify_*.py`. Put logs in `Docs/Verification-build9/`.
3. Upload to TestFlight, Founder Testing.
4. **What to Test** (paste):

```
Build 9: jury fixes + the new plans.

Toys:
• Little Wash: wash the mud off with just the sponge; it finishes and clears the foam.
• Shelf: a toy opens when you lift your finger. Dragging off it, or a second finger, cancels.
• iPhone landscape: all nine toys fit (5 + 4).
• Sleepy Box: tap the drawer knob; it opens.
• Bubbles: slide a finger through bubbles to pop them.

Plans (use a Sandbox Apple Account; Settings › Developer › Sandbox Apple Account):
• Fresh install: the last welcome page explains the free toys, Lull Family, and Keep Forever.
  "Start with the free toys" opens three toys.
• "Try all nine free" → adult check → plans card. The price is the largest text.
• Start the free week: Apple's sheet shows the free week and $29.99/year; all nine toys open;
  the card shows the end date.
• Manage subscription opens Apple's sheet; cancel; the card says it won't renew.
• Keep Forever: buy on a second sandbox account; the card says Keep Forever.
• Restore purchases, and delete and reinstall then restore.
```

## 4. Sandbox purchase pass (Founder, with the Mac's help)

Sandbox time runs fast:
- the **1-week free trial lasts about 3 minutes**;
- **1 year renews about every hour**, up to the account's renewal limit; the renewal rate can be
  changed in Settings → Developer → Sandbox Apple Account.

Expected results:

1. **Fresh install, free state.**
   - The welcome's last page lists the free toys, Lull Family with "First week free, then
     $29.99 a year", and Keep Forever at $59.99.
   - The shelf shows three toys.
2. **Start the free week.**
   - Apple's sheet shows the trial and the renewal price.
   - Afterwards all nine toys open.
   - The card reads "FREE WEEK · 1 DAY LEFT". The 3-minute sandbox week rounds up to 1 day, so
     the quiet dot shows on the parent chip.
3. **Cancel during the week** (Manage subscription). The card says Lull Family won't renew.
4. **Let it lapse.** After about 3 minutes, background the app and return.
   - The shelf goes back to three toys.
   - The parent chip shows the quiet dot until the parent area is opened.
5. **Not eligible again.** The same account no longer sees "Start the free week". The button
   reads "Subscribe · $29.99 a year".
6. **Renewal.** With a new sandbox account, start the free week and don't cancel.
   - After about 3 minutes it renews.
   - The card reads "LULL FAMILY … Renews automatically each year".
7. **Keep Forever.** It unlocks everything. The card reads "KEEP FOREVER", with no Manage button.
8. **Ask to Buy.**
   - Child sandbox account: "The purchase is waiting for approval."
   - After approval, the toys open without relaunching.
9. **Restore purchases**, plus delete and reinstall then restore: access and the plan come back.
10. **Screen Time**, In-App Purchases off: the buttons are disabled and the card says why.
11. **The child's shelf never shows a price, a lock, or a plan.**

## 5. Website

- `LandingPageDeploy/` copy now describes:
  - the free toys;
  - Lull Family at $29.99/year after a free week;
  - Keep Forever at $59.99;
  - "prices in US dollars may vary".
- `support.html` has new answers: the plans, the free week, how to cancel, restore.
- `privacy.html` was regenerated from the app.
- Still to do, unchanged:
  - host it;
  - the support email;
  - an absolute `og:image`;
  - the in-app privacy URL (`LullLinks.privacyPolicyURL`).
- Stale; don't host or use:
  - `LandingPageSource/` (an old draft at $39.99 for ages 2–4);
  - the older marketing cards other than `6-price.html`.

## 6. Jury review (Apple Design Award style)

Stopped at 2 of 8 jurors to save tokens. Both scored **6/10** with "could reach 8". The
results are in the checklist:
- **Fixed in build 9:** the five items in §1 above.
- **Before launch, if device testing agrees** (§5):
  - Little Wash tools show their action (a hose stream, a towel sheen).
  - Shelf cards react to touch again. Their reactions look for parts the v2 art no longer has.
- **First update** (§8):
  - toys open out of their shelf object;
  - Wren inside the toys;
  - felt confetti and hearts;
  - Core Haptics textures;
  - Feed's mouth opens as food nears;
  - a visible lullaby in Sleepy Box;
  - Hum echo;
  - Mix-Up swipe and felt chevrons;
  - home button robustness;
  - a touch vocabulary.
- **Discovery:**
  - An **App Preview video** (checklist §6) is the strongest single featuring asset.
  - The featuring nomination needs at least 3 weeks' lead time.

## 7. Founder decisions still open (checklist §1–§2)

- **Family Sharing** on both products (recommended: on).
- Kids age band (5 and under).
- Territories.
- Release date (manual).
- Store name and subtitle.
- Hosting address and a support email the founder owns.
- **Paid Apps Agreement** active.
- Copyright line.
- Make the GitHub repository private.
- **The first seasonal toy**: Lull Family promises new toys each season. Pick the first one and
  its month.

## 8. Things not to do

- No redesigns or new toys for 1.0.
- Never show a price, lock or plan on the child's shelf.
- Never move purchases or links out from behind the adult check.
- Don't advertise a fallback price. The app shows a plan only when the App Store returned it.
- Don't make the free week more prominent than the billed price on the plans card
  (Guideline 3.1.2).
- No sounds that play on their own or on bare taps.
- No public App Review submission until checklist §1–§6 are done and the founder says so.
