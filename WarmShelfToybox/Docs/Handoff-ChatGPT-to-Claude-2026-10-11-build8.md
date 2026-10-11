# Lull — ChatGPT → Claude, October 11, 2026

Branch: `claude/modest-bell-cjarqm`. Pull before working. Keep the 1.0 feature freeze and all nine toys.

## Current checkpoint

Pulled `14a9c1f`: founder stopped the audit for token budget; build 8 is cleared for TestFlight now. App source still contains only `1228523` launch changes since build 7. The jury section in your October 10 handoff remains pending. No additional app changes made by ChatGPT in this pass.

Build outcome: Debug simulator and signed Release archive both succeeded, exit code 0; no compile fixes needed. Archive confirms version 1.0 (8). **TestFlight 1.0 (8) is available to Founder Testing (Internal, one tester), with What to Test saved.** Upload succeeded at 12:38 PM America/Chicago on October 11, and Apple processing completed. Build UUID `289f428f-00ed-47d4-84e4-f7e787ec2cc2`. See `Docs/TestFlight-Release-2026-10-11-build8.md`. Device approval is not established by compilation/upload.

## Completed preparation

- All 13 `Tools/verify_*.py` passed; logs and `Verifier-results.json` are in `Docs/Verification-build8/`.
- System Python initially lacked Pillow and NumPy. Those two scripts passed with the bundled Python; initial dependency-failure logs retained. No app or verifier logic changed.
- Website `og.png` is 1200 × 630 and `toys.webp` is 1600 × 222. Both use all nine current shelf cards, including Wash/current Mix-Up/Bubbles/Drop Dots. Wren icon unchanged. Inspected the composition and verified source/output hashes and sizes. Rebuild via `Tools/Store/compose_web_assets.py`; manifest `LandingPageDeploy/assets/Composite-export.json`. No imagegen.
- Corrected website icon alt text to Wren.
- Updated `SubmissionKit.md` and `screenshots.json`: build 8, nine Release-only captures, current Family settings layout, actual price fallback and network behavior. No new App Store metadata has been submitted.
- Launch checklist updated with free website option, approved $9.99 price, composite completion and unresolved trial issue. Ireland removed from a proposed non-EU list because it is in the EU.
- `Docs/Verification-build8/What-to-Test.txt` focuses on launch and leaves gameplay/listening/device/purchase checks with the founder.

## Important prelaunch decisions

1. Founder wants a **free website option**. Recommended Cloudflare Pages Free at a `*.pages.dev` address plus a working mailbox they already own. No paid domain required. No account/address/mailbox chosen or site deployed yet. Still replace `support@lull.app`, set the app privacy link and absolute `og:image`, then set ASC URLs. Do not publish placeholders or assume the founder owns lull.app.
2. **Trial model is unresolved.** Apple Guideline 3.1.1 documents a $0 non-consumable `XX-day Trial` for a non-subscription timed trial, with disclosure before it starts. Current local timer starts even when price loading falls back to “The price is in the grown-up area.” Choose the documented trial flow, remove timed access while keeping the three free toys, or seek written Apple clarification. Do not plan on rejection as the compliance check. No trial code changed in build 8.
3. Remaining founder decisions are in the checklist: Family Sharing, age band, territories, name/subtitle, release date, legal/account details and repository privacy. No irreversible settings or agreements changed.
4. Apple featuring help recommends **at least three weeks lead time**; launch date needed before nomination. No nomination submitted.

## Still needed after this TestFlight handoff

- Founder device pass, including launch (restart phone first if iOS shows a cached old screen), every toy in both orientations, sound/settings, interruptions and a longer session. Do not delete the founder’s app automatically; it loses local settings/creations.
- Purchase/restore/Ask to Buy/trial expiry sandbox checks, and crash review. No device or purchase pass claimed here.
- Release simulator build also succeeded. Ready locally: `/private/tmp/lull-build8-20261011/simulator/Build/Products/Release-iphonesimulator/Lull.app`. Still capture 6.9-inch iPhone and 13-inch iPad, nine shots per `screenshots.json`, compose with `Tools/Store/compose_screenshots.py`, founder thumbnail approval. No new store captures made in this pass.
- Real-play App Preview (15–30 s), not generated or simulated footage. No video made.
- ASC privacy/age rating/category, final metadata, IAP screenshot + attach IAP to 1.0, review notes, support/privacy/marketing URLs; **Paid Apps Agreement is New/unsigned**, observed in ASC Business October 11 (Free Apps Agreement Active). Account Holder action required; tax/banking unverified. No agreement accepted.
- Jury review results still belong in your October 10 §6/checklist. No new audit needed unless founder reports a reproducible bug.
- **No public App Review submission** until checklist §1–§6 and explicit founder authorization.

## Mac continuation details

Checkout `~/Desktop/lull v.2`, Xcode project `WarmShelfToybox/Lull.xcodeproj`, scheme `Lull`, bundle `com.lull.toybox.a5ct5fk3sy`, team `A5CT5FK3SY`.
Build artifacts `/private/tmp/lull-build8-20261011/`; full logs `/private/tmp/lull-build8-{debug,archive,upload}.log` (local only). Cloud-readable summaries go in `Docs/Verification-build8/`.
Bundled Python with Pillow/NumPy: `/Users/User2/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3`.
**Xcode 27 simulator UI is Device Hub** (`com.apple.dt.Devices`), which successfully opened through computer use on October 10. Trying the old Simulator app identifier failed. Release screenshots must use real play, normal welcome/trial access and no Debug hooks. `simctl` works with the required Mac permissions.
Never commit signing material. Git launch-preparation checkpoint: `b68c1dd`.

## Sources checked

- https://developer.apple.com/app-store/review/guidelines/#in-app-purchase
- https://developer.apple.com/help/app-store-connect/manage-featuring-nominations/nominate-your-app-for-featuring/
- https://developers.cloudflare.com/pages/get-started/direct-upload/
- https://developers.cloudflare.com/pages/platform/limits/
