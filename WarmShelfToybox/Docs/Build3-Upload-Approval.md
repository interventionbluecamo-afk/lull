# Build 1.0 (3) — founder upload approval

- **Approved by the founder on 2026-10-07 at 20:46 UTC** ("upload it"), in the Claude cloud session.
- Scope: archive and upload **1.0 (3)** to App Store Connect and assign it to **Founder Testing**
  (internal) only. This is not approval for external beta review or public App Review.
- **Build from commit `263b315` exactly.** Its app source is identical to `01d7b16` (verified:
  no differences under `App/`, `project.yml`, `Lull.xcodeproj`), the source ChatGPT built,
  verified and installed in `Docs/Handoff-ChatGPT-to-Claude-2026-10-07-build3.md`.
  Claude is pushing sound and Mix-Up changes to this branch in parallel; those are unverified and
  must not go into build 3.

## Steps on the Mac

```
cd ~/Desktop/"lull v.2"
git fetch origin
git checkout --detach 263b315
```

Xcode: open `WarmShelfToybox/Lull.xcodeproj` → scheme **Lull** → destination **Any iOS Device
(arm64)** → **Product › Archive** → Organizer → **Distribute App** → **App Store Connect** →
**Upload**. Confirm the archive says 1.0 (3) and bundle `com.lull.toybox.a5ct5fk3sy`. If Xcode says it
can't find an account for team A5CT5FK3SY, refresh **Xcode › Settings › Accounts** and retry (this
happened for build 2).

After processing (App Store Connect → TestFlight): add build 3 to **Founder Testing**, paste the
What to Test below, then return the checkout to the branch:

```
git checkout claude/modest-bell-cjarqm && git pull
```

Suggested What to Test:

> Build 3 prepares the parent side for the App Store. The grown-up check now shows three numbers
> written as words (type them as digits); three misses rest it for 30 seconds. The grown-up area
> has a Privacy page and a support fallback when Mail isn't set up. The purchase card shows the real
> felt toys, and the last welcome page names the price before the free week. Warmer shadows on 15
> objects. Please try the grown-up check, Privacy (also with large text), the welcome on your
> smallest iPhone, and restore purchase.

Record the result (uploaded, processed, assigned, What to Test saved) in
`Docs/TestFlight-Release-2026-10-07-build3.md`.
