# Lull — Claude → ChatGPT handoff: build 10

October 11, 2026. Branch `claude/modest-bell-cjarqm` in `interventionbluecamo-afk/lull`; pull first.
Mac checkout `~/Desktop/lull v.2`, project `WarmShelfToybox/Lull.xcodeproj`, scheme `Lull`.

Build 10 replaces build 9, which was never confirmed uploaded. It contains everything from
build 9 (the jury fixes and the two plans) plus the founder's October 11 pass. The living plan,
with every step's notes, is `Docs/Plan-Build10.md`.

Rules:
- Never commit signing keys.
- TestFlight uploads are authorised.
- **No public App Review submission** without the founder's explicit go.

## 1. What's in build 10

| Area | Change | Files |
|---|---|---|
| Plans (from build 9) | Lull Family $29.99/yr with a free week, Keep Forever $59.99, StoreKit 2. App Store Connect setup is still in `Handoff-Claude-to-ChatGPT-2026-10-11-plans.md` §2. Family Sharing: **on for both** (founder). | `LullDemoState.swift`, `ParentInfoViewController.swift`, `LullOnboardingViewController.swift` |
| Free toys | **Bubbles, Drop Dots, Hum** are free. Little Wash is paid. | `ToyRegistry.swift`, plus copy |
| Play timer | Counts **per sitting** and survives force-quit. The rest comes back after a relaunch. An hour away starts fresh; a grown-up waking Lull starts fresh. | `AdultGate.swift` (`LullPlaySitting`, `LullPlayTimer`) |
| Welcome | Page 2 is "Your family's rhythm". The play timer comes first (30 min suggested on a first welcome), then the wind-down hour, then where to change them (it shows the real person button). | `LullOnboardingViewController.swift` |
| Grown-up area | The play timer card leads Family controls, with a live line: "Lull rests after 30 minutes of play (12 played this sitting)…". | `ParentInfoViewController.swift` |
| Drop Dots | **12 dots** (3 per colour) in a **two-row tray**. New discoveries: a home column, a rainbow row, and an **all sorted** finale. One song per landing. Golden dots are 1 in 80. | `DropDotsScene.swift` |
| Meadow | **Find the little ones:** 5 baby ladybugs hide under rustling leaves. They join a parade that follows her steps and hops over her flowers. She leads them home to a leaf house that glows. | new `App/Toys/Meadow/MeadowLittleOnes.swift`, `MeadowScene.swift` |
| Build | `CURRENT_PROJECT_VERSION` **10** | `project.yml`, `project.pbxproj` |

The new Swift file is already in `Lull.xcodeproj` (file reference, build file, Meadow group,
Sources).

## 2. Your Mac work, in order

1. **Compile Debug and Release.** Nothing in this pass was compiled against the iOS SDK; there
   was only `swiftc -parse` in the cloud. Fix compile errors minimally and name each fix in
   the commit. Most likely spots:
   - **StoreKit 2** (from build 9):
     - `Product.SubscriptionInfo.isEligibleForIntroOffer`, `introductoryOffer.paymentMode`,
       `subscriptionPeriod`, `status`, `RenewalInfo.willAutoRenew`;
     - `Transaction.offerType`, `.productType`;
     - `AppStore.showManageSubscriptions(in:)`.
   - **`MeadowLittleOnes.swift`** (new SpriteKit code):
     - `SKAction` sequences and the ternary in `goHome`;
     - `ToyArt.sprite`, `ProceduralTexture.applyClayFill`, `UIColor(hex:)` usage.
   - **`DropDotsScene.buildTray`**: it takes a new `slots:` parameter, and both call sites
     pass it.
   - **`LullOnboardingViewController`**: the `UIFontMetrics` helpers (`scaled`) and the new
     pill helpers.
2. **Run every `Tools/verify_*.py`.** On Linux, 13 pass; on the Mac also run
   `verify_window.py` and `verify_world_interactions.py` (its Drop Dots check now expects
   12 dots). Logs go in `Docs/Verification-build10/`.
3. **Meadow art (image generation).** Prompts are in `Docs/Plan-Build10.md` §5 (copied below).
   - Add the four PNGs as image sets named exactly:
     - `meadow-baby-ladybug`
     - `meadow-leaf-house`
     - `meadow-leaf-house-glow`
     - `meadow-hide-leaf`
   - The code picks them up automatically. Until then it uses stand-ins: her own art small,
     and a code-drawn leaf house and leaves.
   - Show the founder before committing.
4. **Device checks** (simulator first, then the founder's phone):
   - **Drop Dots, two-row tray:** portrait and landscape on iPhone SE or mini, iPhone Pro Max
     and iPad.
     - The dots sit in their troughs, the back trough's lip never covers the front dots, and
       the board isn't cramped.
     - Play to all sorted: the finale plays, then the tab bobs.
   - **Meadow:**
     - The little ones' size beside her and the flowers.
     - The parade hops over flowers and never sits on them.
     - The house appears at home after the first find.
     - All five home gives the glow, sparks and one chord.
     - Rotate mid-parade: nobody is lost.
     - Reduce Motion: no hops.
   - **Welcome page 2** fits on a small iPhone (it scrolls if not). VoiceOver reads "Play timer,
     30 minutes, selected".
   - **Play timer:**
     - Set 15 min, play until the moon rest, force-quit, reopen: the rest is still there.
     - A grown-up wakes it: play resumes, fresh.
     - Quick test: the Debug build can set the timer, then leave the app for over an hour.
   - **Free shelf** (no purchase): Bubbles, Drop Dots, Hum.
5. **TestFlight 1.0 (10)** to Founder Testing. **What to Test** (paste):

```
Build 10.

Free toys are now Bubbles, Drop Dots and Hum.

Drop Dots: twelve dots in a two-row tray. Try putting every dot under its own colour (watch the
finale), three of a colour in its own column, and four different colours across a row.

Meadow: five baby ladybugs hide under leaves. Lead her near a rustling leaf, then lead the
little parade home to the leaf house by her starting garden.

Play timer: the welcome's second page sets it (try 15 min). When Lull rests, close the app
fully and reopen. The rest should still be there until a grown-up wakes it.

Grown-up area: the play timer is now the first card.

Plans (sandbox): see the build 9 notes; nothing changed there.
```

6. **App Store Connect:** still per `Handoff-Claude-to-ChatGPT-2026-10-11-plans.md` §2 (two
   products, Family Sharing on, attach both to 1.0). The **Paid Apps Agreement** must be
   active first (Account Holder only).

## 3. Meadow art prompts

Match the existing Meadow and ladybug art: felt and wood, soft studio light, transparent PNG, no
text. No faces on the art; faces are live code.

1. `meadow-baby-ladybug.png`, 512 × 512, transparent.
   - A tiny felt ladybug baby, rounder and softer than the mother: a short red felt shell with
     three big black felt spots, a small black felt head, two little wool antennae with
     butter-yellow pom tips.
   - Seen from directly above, like `meadow-ladybug-top`, centred, with a soft contact shadow.
     No eyes or mouth.
2. `meadow-leaf-house.png`, 768 × 768, transparent.
   - A cosy little house made from one big curled sage-green felt leaf, on a small wooden base
     with moss.
   - A round doorway (dark felt inside), a tiny wooden step, two small felt flowers by the
     door, warm soft light. The Meadow palette.
3. `meadow-leaf-house-glow.png`, 768 × 768, transparent.
   - The same house, framed identically, at dusk: warm golden light glowing from the doorway
     and through the felt. (The code cross-fades it in as little ones arrive.)
4. `meadow-hide-leaf.png`, 256 × 256, transparent.
   - One broad sage felt leaf with a stitched vein, lying flat, one edge slightly lifted (where
     a little one peeks out).

Add each one to `App/Resources/Assets.xcassets/` as an image set with the same name (1x
universal), like the other Meadow art.

## 4. Open items for the founder (not code)

- Website address and support mailbox (`Docs/Launch/Website.md`; one command once chosen).
- Paid Apps Agreement.
- **"New toys each season":** pick the first one and its month.
- Kids age band, territories, release date, copyright line, make the repository private.

## 5. Things not to do

- No other features or redesigns beyond this pass.
- Never show a price, lock or plan on the child's shelf.
- No sounds on bare taps or on their own. The new sounds answer outcomes only: a little one
  joining, going home, all home, Drop Dots discoveries.
- No public App Review submission without the founder.
