> **October 12 status: build 1.0 (14) was submitted and is Waiting for Review.** All four review items were received at 3:33 PM America/Chicago. See `Docs/HANDOFF-CURRENT.md` for current state; older preparation steps below are historical and must not be restarted.

# Submit Lull 1.0 (14): App Store Connect, field by field

October 12, 2026. Everything below is decided. Work top to bottom.

- **App Store Connect:** Apps → Lull Quiet Toybox → **iOS App 1.0**.
- **Full copy:** `Docs/AppStore/SubmissionKit.md` §3.
- **Screenshots:** `~/Desktop/lull-store/`.

## A. Before the version page

1. **TestFlight:** build **14** shows "Ready to Submit". Install it and do a 5-minute pass on your
   phone:
   - welcome, then grown-up check, then Start my free week (free in TestFlight);
   - all nine toys open;
   - grown-up area, Your plan;
   - Restore purchases.
2. **In-App Purchases → Keep Forever** and **Subscriptions → Lull Family Yearly:** upload
   `~/Desktop/Lull-IAP-review-screenshot.png` under **Review Information → Screenshot**. Save
   each. Do not click "Add for Review" on them; they go with the version (step C7).

## B. App Information (left menu)

| Field | Value |
|---|---|
| Name | Lull Quiet Toybox |
| Subtitle | Calm toys for ages 2–6 |
| Category | Primary: **Education**. Secondary: **Entertainment**. (There is no "Kids" choice here; Kids comes from the age rating below.) |
| Content rights | Does not contain third-party content |
| Age rating | Answer **None / No** to every content question. At the end, turn on **Made for Kids** and choose **5 and under**. This puts Lull in the Kids category, and it's permanent once approved. |
| Privacy Policy URL | https://lulltoybox.pages.dev/privacy |

**App Privacy** (left menu): **Data Not Collected**, then Publish.

## C. The 1.0 version page

1. **Screenshots:**
   - iPhone 6.9" slot: drag all of `~/Desktop/lull-store/iphone/*.png` (8 images, in name
     order);
   - iPad 13" slot: `~/Desktop/lull-store/ipad/*.png`.
2. **Promotional text:** Try all nine felt-and-wood toys free for 7 days. No ads, no tracking, no
   accounts, and a play timer that ends with a calm rest.
3. **Description:** paste from SubmissionKit §3, starting "Lull is a quiet toybox…" and ending
   with the Privacy Policy line.
4. **Keywords:**
   `toddler,preschool,montessori,sensory,baby,music,shapes,sorting,quiet,bedtime,learning,play,kid,felt`
5. **Support URL:** https://lulltoybox.pages.dev/support. **Marketing URL:**
   https://lulltoybox.pages.dev
6. **Build:** choose **1.0 (14)**. Export compliance: No.
7. **In-App Purchases and Subscriptions:** add **Lull Family Yearly** and **Keep Forever**.
8. **Copyright:** 2026 Timothy Doyle
9. **App Review Information:**
   - sign-in required: **No**;
   - contact: your name, phone, lullios@proton.me;
   - Notes: paste "App Review notes" from SubmissionKit §3.
10. **Version release:** **Manually release this version**.
11. **Pricing and Availability** (left menu): price **Free**, availability **United States** only.

## D. Submit

- **Add for Review**, then **Submit to App Review**. Founder clicks.
- Review usually takes 1–3 days.
- **If Apple replies with a question or rejection:** paste it to Claude.
- **When approved:**
  1. Click **Release**.
  2. Run `python3 Tools/Store/build_site.py --launched` (Claude does this).
  3. Re-upload `LandingPageDeploy` to Cloudflare. The site button then switches to "Download on the
     App Store".

## Known and accepted for 1.0

- Promise kept on the store page: new toys each season. Plan the first one for about January.
- Small things found in review, deferred:
  - the offer page loses its scroll position after a purchase attempt;
  - the price card sits below the fold in iPhone landscape;
  - page slides still animate with Reduce Motion on.
