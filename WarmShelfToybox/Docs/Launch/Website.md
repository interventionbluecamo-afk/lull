# Lull website: how it's built and how to put it online

The site is finished and deploy-ready in `LandingPageDeploy/`. Two things only the founder can
supply are missing: **a public address** and **a support mailbox you own**. One command
applies both everywhere.

## What's on it

| Page | What it has |
|---|---|
| `index.html` | Hero with Wren and the App Store button ("Coming soon" until launch); the nine toys with names, one-line descriptions and **Free** tags on Bubbles, Drop Dots and Hum; why families choose Lull; the three plans (Free, Lull Family $29.99/year after a free week, Keep Forever $59.99) with the subscription terms and the Terms of Use link |
| `support.html` | Settings; plans; the free week; cancelling; Family Sharing; restoring on another device; greyed-out buttons; the play-timer moon; refunds; terms |
| `privacy.html` | The in-app policy, word for word (built from the Swift) |
| `press.html` | The 100-word story, a fact sheet, artwork downloads (icon, social card, the toy strip, each toy) |
| `404.html` | "This page wandered off the shelf" |
| `robots.txt`, `sitemap.xml` | Written by the build; the sitemap appears once the address is set |
| `_headers` | Strict security headers (no scripts allowed at all) and a week's caching for images |

The site has no scripts, cookies, trackers, analytics or third-party fonts, matching the app's
privacy promise. It works in light and dark mode. It was checked at phone (390 pt) and desktop
(1280 pt) widths with the security headers on: no blocked resources and no sideways scrolling.

## How it's built

- **Edit** the page templates in `Tools/Store/site/`, the styles in `LandingPageDeploy/site.css`,
  or the privacy policy in `App/Shared/ParentInfoViewController.swift`
  (`LullPrivacyViewController.sections`). Never edit the HTML in `LandingPageDeploy/`; it's
  rebuilt.
- **Build:** `python3 Tools/Store/build_site.py` from `WarmShelfToybox/`. It reuses the saved
  settings in `Tools/Store/site.json`.
- **Images:** `python3 Tools/Store/compose_web_assets.py` rebuilds the social card, the toy strip,
  the small toy images and the small icon from the app's own shelf art. Nothing is generated or
  repainted.

## Putting it online (free, about 10 minutes)

1. **Cloudflare Pages, free plan.** At dash.cloudflare.com: Workers & Pages → Create →
   Pages → **Upload assets**.
   - Give the project a name; the address becomes `https://NAME.pages.dev`.
   - Upload the whole `LandingPageDeploy` folder.
2. **Apply the address and your mailbox**, from `WarmShelfToybox/`:
   ```
   python3 Tools/Store/build_site.py --url https://NAME.pages.dev --email you@yourmail.com
   ```
   This one command updates:
   - every page's email;
   - absolute share-image and canonical links, plus the sitemap;
   - the app's support email and privacy link (`LullLinks`), which needs a new app build;
   - the URLs in `Docs/AppStore/SubmissionKit.md`.
   It prints a warning while the email is still the unowned `support@lull.app`.
3. **Upload `LandingPageDeploy` again** (Cloudflare: Create new deployment).
4. **Check on a phone and a desktop:**
   - every link;
   - the images;
   - the mail link;
   - a made-up address, which should show the 404 page;
   - a share preview, e.g. paste the address into Messages.
5. **App Store Connect:**
   - Privacy Policy URL `https://NAME.pages.dev/privacy.html`;
   - Support URL `https://NAME.pages.dev/support.html`;
   - Marketing URL `https://NAME.pages.dev/`.
6. Commit the changes, and rebuild the app so its privacy link and email match.

A custom domain can be added later in Cloudflare. Run step 2 again with the new `--url`, then
re-upload.

## Launch day

After Apple approves the app and it's released:

```
python3 Tools/Store/build_site.py --launched
```

Upload again. The home page button becomes "Download on the App Store". The press page says
"Available now". Safari shows Apple's app banner (`apple-itunes-app`, app ID 6819919245).

## Later (not needed for launch)

- Screenshots and the App Preview video on the press page, once they're captured (checklist §6).
- A founder note in your own words for the press page. The footer already carries "Made with
  patience by two people and a toddler".
- `LandingPageSource/` and the older marketing cards are stale drafts. Don't host them.
