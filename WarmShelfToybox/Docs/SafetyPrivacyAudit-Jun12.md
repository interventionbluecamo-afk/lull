# Safety & Privacy Audit — June 12
*Full sweep of the codebase, manifests, and flows, with the Kids Category bar in
mind (which is stricter than COPPA). Method: exhaustive grep of every import,
network symbol, permission API, external-link path, and storage call, plus manual
review of the gate and purchase flows. Verdict first.*

## VERDICT: GREEN. No code changes required before submission.
The app collects nothing, sends nothing, tracks nothing, and asks for nothing.
The findings below are the evidence trail plus the submission checklist.

---

## Findings (evidence-based)

### Network & data collection — NONE ✓
- **Zero networking code.** No `URLSession`, no `URLRequest`, no socket, no
  http(s) string anywhere in `App/` Swift sources. The app is fully offline.
- **Zero third-party SDKs.** Every import is a system framework: AVFoundation,
  CoreGraphics, CoreImage, CoreMotion, Foundation, QuartzCore, SpriteKit,
  StoreKit, UIKit. No analytics, no crash reporters, no ad frameworks, nothing
  with a privacy manifest of its own to inherit.
- **Privacy manifest (PrivacyInfo.xcprivacy) is accurate:** `NSPrivacyTracking =
  false`, no tracking domains, **no collected data types**, and one
  required-reason API declared — UserDefaults, reason `CA92.1` (app's own
  settings). This matches reality exactly.
- **App Store privacy label: "Data Not Collected"** — defensible in full.

### Permissions & sensors ✓
- **No microphone, no camera.** AVFoundation is playback-only
  (`AVAudioSession .ambient`, mix-with-others — the polite category; the app
  never silences a parent's podcast). `outputVolume` is read once for the
  silent-mode visual boost; output only, no recording APIs anywhere.
- **CoreMotion**: `CMMotionManager` device-attitude only, for the shelf's ±5pt
  parallax breath. Requires NO permission and NO usage-description string
  (only CMMotionActivityManager would). Respects Reduce Motion; stops on scene
  exit. *Recommendation: one sentence in App Review notes — "device tilt is
  used solely for a cosmetic parallax on the shelf; no motion data is stored
  or leaves the device."*
- **No location, contacts, photos, push notifications, Bluetooth, or any
  usage-description key in Info.plist** (none needed, none present).

### Kids Category compliance ✓
- **Parental gate**: every path to the grown-up room goes through
  `AdultGate.present` (shelf chip, toy chip, both verified; the one ungated
  constructor call is `#if DEBUG` QA tooling that does not ship). Inside the
  room, purchase and restore are *individually* gated again — double-gated
  commerce.
- **External links**: exactly one — the support `mailto:` — and it lives
  inside the gated parent area. No web views, no social, no "more apps."
- **No child-facing prices, upgrade language, or locks** (the free shelf has
  no lock badges; locked toys simply aren't shown to the child).
- **No manipulative patterns**: no streaks, timers-as-pressure, daily rewards,
  or countdowns. The play timer is a *parent* tool that rests the app behind a
  calm moon. The trial countdown lives only behind the gate.
- **Third-party ads: none. Tracking: none. IDFA: never touched** — no
  AppTrackingTransparency needed (and Kids Category forbids IDFA anyway).

### Data at rest ✓
- All state is `UserDefaults.standard` on-device: settings, trial dates,
  hidden toys, Mix-Up keepsakes (recipes as integers — no images, no PII),
  wind-down hour. **No names, no photos, no free-text input anywhere in the
  app** — there is literally no keyboard surface a child can reach.
- No iCloud, no keychain, no app groups, no files written outside the sandbox.
- StoreKit 2 handles the one non-consumable; receipts stay in Apple's domain.

### Content & safety ✓
- No user-generated content, no sharing, no chat, no external media.
- Photosensitivity: no strobe-rate effects; the brightest event is a soft
  additive glow with ≥0.3s ramps. Reduce Motion calms all ambient animation.
- Loudness: synth amplitudes capped ≤0.12; haptics are .soft/.light.

## Submission checklist (App Store Connect side — not code)
- [ ] Category: **Kids**, age band **2–4** (locks IDFA/ads constraints — we
      already comply).
- [ ] Privacy label: **Data Not Collected** (matches manifest).
- [ ] App Review notes: CoreMotion sentence (above) + "fully offline; the only
      external link is a parent-gated support mailto" + parental-gate location
      for the reviewer (shelf, top-right chip, multiply-style gate).
- [ ] Export compliance: standard encryption exemption (no custom crypto) —
      `ITSAppUsesNonExemptEncryption = NO` in Info.plist before archive.
- [ ] Verify the DEBUG env hooks are absent from the Release archive (they are
      all `#if DEBUG`; archive a Release build and spot-check once).
- [ ] Screenshot set: no device frames with text overlapping the age band
      requirements; the captions live on our plates, not in-app.

## Watch-list for future features (so green stays green)
- The **room council Phase A** keeps everything local ✓ no impact.
- If audio sourcing brings third-party files: licensing docs into
  `Assets/Marketing/press/licenses/` — no code impact.
- If a future update adds iCloud sync for placements: revisit the privacy
  label (still "data not collected" if CloudKit private DB, but document it).
- Never add: web views, external links outside the gate, photo import, or any
  SDK without reading its privacy manifest first. The zero-SDK posture is a
  feature; guard it jealously.
