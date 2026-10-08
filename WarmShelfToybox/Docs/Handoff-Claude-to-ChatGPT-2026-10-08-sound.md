# Lull — Claude → ChatGPT handoff: new sound system, security, Mix-Up friends

October 8, 2026. Branch `claude/modest-bell-cjarqm` in `interventionbluecamo-afk/lull`; pull first.
Mac checkout `~/Desktop/lull v.2`, project `WarmShelfToybox/Lull.xcodeproj`, scheme `Lull`.
All nine toys stay. The founder owns play-testing and purchase testing; upload only with their
explicit approval.

Build 1.0 (3) is approved for upload from commit `263b315` only
(`Docs/Build3-Upload-Approval.md`). Everything below is newer, unverified on iOS, and is
**1.0 (4)** (`CURRENT_PROJECT_VERSION` is 4).

## What changed

### Sound (founder: "the sound system is awful — completely redo it")

Diagnosis (measured): a vibrato bug drifted held notes out of tune; ~38 dB loudness spread with
no limiter; thunks below what phone speakers play; cached "random" sounds repeated exactly;
100–200 ms tap latency from MP3s and main-thread synthesis; clicks from hard voice stealing; a
large-hall reverb on some sounds and none on others; the 13 MP3s had no recorded source or
licence.

Now:
- `App/Shared/LullToneEngine.swift` is the **sound book** (pure Foundation). Every sound is
  rendered from physical models: struck bars (marimba, glockenspiel), kalimba tines, small bells,
  tuned woodblocks, hollow wooden boxes, felt landing on felt, Minnaert bubbles, cloth, breath
  and soft hummed voices. One tuning (C major pentatonic), speaker-safe (nothing important below
  ~200 Hz), click-free fades, loudness set per bus, several variants per sound that rotate.
  109 named cues plus parametric notes `note.<kalimba|marimba|glock|glass|bell|wood|choir>.<0…19>`.
  The old `LullToneEngine.Spec/Voice` API still compiles (parked toys use it) and renders through
  the same models.
- `App/Shared/AudioManager.swift` is the **engine**: one `AVAudioEngine`; voice pools per bus
  (UI, effects, music, voices) plus loop slots for room beds; sample-accurate delays; oldest-first
  voice stealing that spares held notes; smooth fades; one small shared room (reverb 9% wet),
  a speaker EQ (high-pass 110 Hz, -2 dB above 9 kHz) and a peak limiter on the master. Same public
  API and the same haptic pulses as before. Lifecycle behaviour is unchanged from build 2/3
  (Sound Off, backgrounding, interruptions, Silent Mode with `.playback` + mixing), plus recovery
  from route changes and media-services resets.
- Toys: Sleepy Box, Drop Dots, Window, Meadow and Hum now use named cues instead of raw notes.
  Hum: bars are real struck instruments that ring out (knob: music box, marimba, glass, bell,
  woodblock, pluck); holding a bar lets a soft hummed "oo" swell in at its pitch (finite 9 s,
  fades on release); no room drone. Drop Dots keeps the approved "deeper as the column fills".
  Sleepy Box hums each shape's own note back in posting order.
- Room beds: quiet generative loops (indoor room tone, airy for Bubbles, breeze with an
  occasional bird for Meadow, crickets in the Window at night, a slow breathing bed when idle).
- The 13 MP3s and their project entries are removed. No audio files ship.

### Security (founder: "how will accounts be made?")
- **No accounts exist or are needed.** No sign-in, no network code, no analytics. The only
  identity is the parent's Apple Account, which Apple uses for the one-time purchase; Restore
  and (if the founder turns it on) Family Sharing work through StoreKit with no code changes.
- Fixed: the debug time-of-day override is Debug-only; the free week can't be stretched by
  turning the clock back (and shows at most 7 days); the grown-up check's 30 s rest survives a
  relaunch; privacy text mentions device backups; the website has strict security headers
  (`LandingPageDeploy/_headers`); `.gitignore` covers signing keys and certificates.
- Founder-only (not code): **make the GitHub repository private** (it is public); revoke any
  classic GitHub token used from the Mac and use the Keychain credential helper; give agents an
  App Store Connect login with the App Manager role rather than the Account Holder's; keep 2FA on.

### Mix-Up friends (founder: "my son loved the robot and police/fire")
See the Mix-Up section at the end; it lands in a separate commit.

## Verification done here (Linux, no Xcode)

- `swiftc -parse` on every changed file.
- The production engine type-checks and runs against AVFoundation/UIKit stand-ins
  (`Tools/Audio/AppleAudioStubs.swift`): `Tools/verify_audio_lifecycle.py` **53 checks pass**
  (Sound Off, session and engine retry, cooldowns, variation, delays, stealing, held notes,
  beds, background, interruptions, route change, Window day/night, haptics, friend voices).
- `Tools/verify_sound_kit.py` renders all **523 sounds**: **2,486 checks pass** (no clicks,
  peaks ≤ -3 dBFS, nothing louder than its bus, every note on pitch in the pentatonic scale,
  seamless loops, every cue a toy names exists). `--wav DIR` writes them for listening.
- `verify_adult_gate.py` 12 and the onboarding scenarios pass.
- **Not done:** an iOS compile of the new engine. The stand-ins mirror the SDK signatures but
  are not the SDK. Likely spots if Xcode complains: `AudioUnitSetParameter` argument types and
  the `kLimiterParam_*` / `kAudioUnitScope_Global` constants, `AVAudioUnitEffect(audioComponentDescription:)`,
  `Notification.Name.AVAudioEngineConfigurationChange`, `AVAudioTime.hostTime(forSeconds:)`.
  Fix minimally in `AudioManager.swift` and say so in the commit.

## Your job on the Mac, in order

1. Pull. Build Debug (simulator) and Release (device). Fix compile errors; you may edit
   `AudioManager.swift` / `LullToneEngine.swift` for that.
2. Run every `Tools/verify_*.py` (`verify_audio_lifecycle.py` and `verify_sound_kit.py` replace
   the old audio check). Commit logs to `Docs/Verification-build4/`.
3. Install the Release build on the founder's iPhone and hand it to the founder to **listen**
   (they own testing). Nothing else.
4. Upload 1.0 (4) only after the founder approves it in words.

## Listening guide for the founder (what "good" sounds like)

- Nothing startles: no sound much louder than the touch that made it; no clicks; music never sour.
- Bubbles: small bubbles higher, big ones deeper; rare ones sparkle.
- Feed: three soft bites in time with the chewing face, a happy hum, a small kalimba run for the
  wished-for food.
- Stack: soft felt "tunks", louder for harder drops; a tumble when it falls.
- Sleepy Box: each shape lands in a hollow wooden box with its own note; all four hum back.
- Drop Dots: wooden clacks that get deeper as a column fills; a pour when the handle is pulled.
- Hum: a quick tap rings like a real instrument; holding a bar makes it sing; the knob changes
  the instrument.
- Window: lamp on and off sound different; the cat purrs; crickets at night; quiet room by day.
- Meadow: each sleeper wakes on its own note; a breeze and an occasional bird.
- Mix-Up: each friend has a small voice (robot beep-boop, officer's soft whistle, firefighter's
  bell, frog ribbit, mouse squeak…), and a bigger one when a whole friend is matched.
- Sound Off, Silent Mode, a phone call, headphones in and out, and leaving the app all behave as
  in build 2.

Tuning knobs if something is off (one place each): bus loudness `LullSoundBus.targetRMS`,
room `room.wetDryMix`, per-sound gain in each `LullSoundBook.recipe` case, cooldowns in
`AudioManager.cooldown(for:)`.

## Update after build 4: Mix-Up friends → build 1.0 (5)

Build 4 (sound only, from `6873084`) is installed on the founder's iPhone for listening
(`Handoff-ChatGPT-to-Claude-2026-10-08-build4.md`). Newer production code has landed since, so
the next build is **1.0 (5)** (`CURRENT_PROJECT_VERSION` = 5):

- `a0e388f` + `35d65a3` — **the robot, police officer and firefighter are back in Mix-Up** as
  friends 6–8 (nine friends, 729 combinations), using the legacy part art that the founder's son
  knew (robot2, officer with cleaned legs, firefighter), cropped and registered to the new cast
  (`Docs/MixUp-Friends-9.png`). Each of the nine friends has its own gentle arrival move and a
  whole-friend signature (robot glow and two-step, officer salute, firefighter hop and wave…),
  rare idle habits, its own voice from the sound book, and VoiceOver names ("police officer").
  Reduce Motion keeps one slow tilt only. Saves move to cast version 4 without shifting the six
  animals; robot/officer/firefighter saves from the build-1 era map back to them where the device
  has not already migrated them. A future felt atlas `mixup-friends-c` is wired but off until it
  exists: prompt and steps in `Docs/MixUp-Friends-Prompt.md`, measured by
  `Tools/Art/measure_atlas.py`.
- Verified here: Mix-Up/Stack 274 and layout 280 checks; Swift parse; an adversarial review
  (approve, no blockers; its nits are fixed).

Mac steps: pull, build Debug and Release, run all `Tools/verify_*.py`, install 1.0 (5) on the
founder's iPhone so they can hear the new sound **and** meet the returning friends. Upload only
with the founder's explicit approval of build 5.
