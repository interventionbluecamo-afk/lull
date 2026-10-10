# Lull — Claude → ChatGPT handoff: build 8 and the road to launch

October 10, 2026. Branch `claude/modest-bell-cjarqm` in `interventionbluecamo-afk/lull`; pull first.
Mac checkout `~/Desktop/lull v.2`, project `WarmShelfToybox/Lull.xcodeproj`, scheme `Lull`.

**We are now in feature freeze for 1.0.** The single source of truth for everything left is
`Docs/Launch/Launch-Checklist.md`; tick items there as they close. All nine toys stay as they
are. Code changes only for confirmed bugs, App Review requirements, and the few small
"before launch" jury items Claude adds to the checklist. No new toys, features or redesigns.
Never commit signing keys.

## 1. What changed since build 7

- `1228523` **Launch screen.** Founder: "I hate the loading screen."
  - The 1.7 s vector loading animation and its yellow-cream system launch are gone.
  - `LaunchScreen.storyboard` now shows the shelf's own room picture, `shelfroom-v2-day`, full
    bleed, so launch flows straight into the shelf and the toys rise onto it.
  - The `UILaunchScreen` colour dictionary was removed from `Info.plist` and `project.yml`; the
    storyboard is the single launch definition.
  - At night the shelf's evening tint eases in.
  - `WarmShelfLaunchScene.swift` is no longer presented. The file is kept and unused.
- `CURRENT_PROJECT_VERSION` is **8** in both project definitions.
- The code audit of the build 7 checklist was **stopped by the founder** (token budget), so build 8
  carries no audit fixes. Bugs now come from the founder's hands-on TestFlight testing (toy,
  orientation, steps).
- An Apple Design Award style jury review is still running. Claude adds its results as §6 of
  this file, and any small "before launch" items to the checklist.

## 2. Your Mac work, in order

1. **Build 1.0 (8) now.** It contains only the launch-screen change since build 7.
   - Compile Debug and Release; fix compile errors minimally and say so in the commit.
   - Run every `Tools/verify_*.py`; put logs in `Docs/Verification-build8/`.
   - Upload to TestFlight, Founder Testing. The founder has authorised TestFlight uploads.
2. **Launch screen check on device.** iOS caches launch screens, so an updated build can still
   show the old one. Delete the app and reinstall from TestFlight, or restart the phone, before
   judging it. It should look like the empty shelf room, then the toys rise in.
3. **Website assets refresh.** Not image generation; compose from the current shelf cards.
   - `LandingPageDeploy/assets/og.png` (1200 × 630) and `toys.webp` (1600 × 222) date from
     October 7. They still show the old Stack stones and the old Mix-Up puppet.
   - Rebuild both from the nine current `shelf-*-v2` PNGs, in the same layout and style.
   - Keep the app icon (Wren) in `og.png`.
4. **Store captures** (checklist §6). Run a Release build on the 6.9" iPhone and 13" iPad
   simulators.
   - Spec: `Docs/AppStore/screenshots.json`. Compose with `Tools/Store/compose_screenshots.py`.
   - Get the founder's approval at thumbnail size.
5. **App Preview video**, 15–30 s, recorded from the Simulator or a device. Real play only: a hand
   washing the foamy fire truck, Feed's chewing smile, Sleepy Box's hum, the Window at dusk. No
   text and no UI chrome.
6. **App Store Connect, with the founder:**
   - metadata from `Docs/AppStore/SubmissionKit.md` §3 (check every toy line against build 8);
   - App Privacy: Data Not Collected;
   - the age rating questionnaire;
   - Kids › 5 and under;
   - the purchase's review screenshot, with the purchase **attached to the 1.0 version**;
   - review notes;
   - a **featuring nomination** (check the current lead time there).
7. **When the founder has a domain** (they are choosing one):
   - Host `LandingPageDeploy/` on it.
   - Claude swaps the support email, sets the in-app privacy link, and makes `og:image` an
     absolute URL; social previews need that.
   - Then put the Privacy, Support and Marketing URLs in App Store Connect.

## 3. Founder decisions you will need (recommendations in checklist §1)

- Free week model
- Family Sharing on/off
- Kids age band
- Territories
- Release date (manual release)
- Final name and subtitle
- Domain and support email
- Paid Apps Agreement active
- Copyright line
- Make the GitHub repository private

## 4. Image generation needed

### Needed before launch

**None.** The app's art is complete for 1.0.

- **The app icon stays.** The icon is Wren, the shelf host: a terracotta felt friend with the
  butter capstone (`wren-head`, `wren-body`). It matches what children meet on the shelf.
- **The website images in §2.3 are composites**, not image generation.
- **Screenshots and the preview video are captures**, not image generation.

### Optional, ready to adopt, not needed for 1.0

The prompts are written and the code adopts the files automatically if added:
- **Bubbles bird wing frames:** `bubble-bird-down`, `bubble-bird-glide`
  (`Docs/Polish-2026-10-09/Art-prompts.md`).
- **Little Wash rare guests and dirt kinds:** `wash-guest-*`, `wash-leaf-*`, `wash-snow-*`,
  `wash-paint-*` (`Docs/Polish-2026-10-09/Little-Wash-image-prompts.md` §7). Their behaviour still
  needs code, which is post-launch.

### Post-launch (first update)

- Meadow "find the little ones": a baby ladybug and a leaf house, dark and glowing
  (`Docs/Polish-2026-10-09/Founder-choices-build6.md` §2).

## 5. Things not to do

- No redesigns or new toys.
- Don't bake faces into art; faces are live code.
- Don't add sounds that play on their own or on bare taps (see the sound diet in `LullToneEngine.swift`).
- Don't submit for public App Review until checklist §1–§6 are done and the founder says so.

## 6. Jury review

_Pending: Claude appends the results here when the review finishes, and moves any small
"before launch" items into the checklist. The audit was stopped; there are no audit fixes._
