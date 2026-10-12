# Lull — CURRENT HANDOFF (read this first, every session)

**The founder switches between Claude and ChatGPT to save money.** Whoever is working keeps
this file current *while* working, and pushes it after every meaningful step, so that the
other AI can continue if usage runs out mid-task. Keep it short. Older dated handoffs in
`Docs/` are background only.

Branch: `claude/modest-bell-cjarqm` · Repo: github.com/interventionbluecamo-afk/lull ·
Mac checkout: `~/Desktop/lull v.2` · Last updated: **October 12, 2026, by Claude**.

## Where we are

- **Goal now: submit Lull 1.0 (14) to App Review.** The founder said go. The founder clicks
  Submit themselves.
- **Build 1.0 (14):** uploaded to App Store Connect October 12 at 11:31 CDT. It contains:
  - the free-week-only model;
  - the review fixes;
  - support email `lullios@proton.me` and website links;
  - the regrouped grown-up area (Your plan / Play / Sound & motion / Shelf / Help & privacy).
  
  Build 13 is also in TestFlight.
- **Website live:** https://lulltoybox.pages.dev (Cloudflare Pages). To update it, rebuild with
  `python3 Tools/Store/build_site.py` from `WarmShelfToybox/`. The founder then drags the
  `LandingPageDeploy` folder into Cloudflare (lulltoybox → Create new deployment).
- **App Store Connect:**
  - agreements, banking and tax: Active;
  - Lull Family: $29.99 a year, 1-week free trial;
  - Keep Forever: $59.99;
  - Family Sharing on for both;
  - 16-day billing grace period on;
  - US only.
- **Founder decisions (final):**
  - Kids age band: 5 and under;
  - name and subtitle: Lull Quiet Toybox / Calm toys for ages 2–6;
  - "new toys each season" stays;
  - copyright: 2026 Timothy Doyle;
  - manual release.

## Next steps (in order)

1. **Screenshots:**
   - iPhone: done (8 images, `~/Desktop/lull-store/iphone/`). Apple's 2026 required slot is
     **"iPhone with Dynamic Island (medium display)" = 1206 × 2622** (or 1179 × 2556). 1320 × 2868
     is rejected there. No transparency allowed. Larger copies are in `lull-store/iphone-large/`;
   - iPad 13": done (8 images, `~/Desktop/lull-store/ipad/`), checked by eye.
     - Raw files: `/private/tmp/claude-502/-Users-User2-Desktop-lull-v-2/*/scratchpad/caps/ipad/`.
     - Compose with `python3 Tools/Store/compose_screenshots.py --captures <dir with iphone/ and ipad/> --out ~/Desktop/lull-store --devices ipad`.
     - The compose script needs Pillow (`pip install pillow` in a venv).
     - Captures come from a Debug build in the simulator, with env `LULL_DEBUG_FULL=1 LULL_DEBUG_TOY=<toy id>`.
     - Wait about 30 s after launch before capturing.
     - Check every image before the founder uploads.
2. **The founder fills in App Store Connect**, following `Docs/Launch/Submit-Day.md` field by
   field.
   - The built-in browser can't upload files, so the founder drags in the screenshots and the
     IAP review screenshot (`~/Desktop/Lull-IAP-review-screenshot.png`).
   - An AI may type text fields if the founder is signed in.
3. **The founder clicks Submit to App Review.** No AI submits or accepts agreements.
4. **After approval:** Release, then `build_site.py --launched`, then re-upload the site.

## Rules

- Never commit signing files.
- Never enter payment, tax or bank details, and never accept agreements.
- TestFlight uploads are OK. App Review submission is the founder's click.
- The child's shelf never shows prices or locks. Purchases stay behind the adult check.
- Be token-thrifty. No big multi-agent reviews unless asked.
