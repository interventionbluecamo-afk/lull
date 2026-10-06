# Audio Scouting — what to find, what to skip, how it lands
*For the founder's sourcing run. The synth tone engine (pentatonic, per-toy
voices) is DONE and stays native — do not shop for chimes, pops, or notes.
What's missing is the AIR: room tone, material foley, and three signature
moments. Conventions at the bottom; the integration side is already built
(AudioManager profiles + AudioDropInManifest.md naming).*

## Principles (the brand's ears)
- **Real materials, close-mic'd, quiet.** Wood on felt, wool, paper, breath.
  Nothing synthetic, nothing reverbed like a hall — this is a small room.
- **Loops must be seamless** and LONG (90s+ for ambience; short loops fatigue
  parents before children).
- **No music with melody.** The tone engine owns pitch. The only exception is
  the shelf's night bed (see below) which may carry 2–3 sleepy notes per minute.
- **Peak around -20 LUFS integrated for beds, -14 for one-shots.** We mix at
  whisper level; headroom matters more than loudness.
- Formats: **48k or 44.1k WAV/AIFF masters**; we convert to .m4a (AAC 192k) on
  landing. Mono for positional one-shots, stereo for beds.

## TIER 1 — ship-blockers (the app feels silent without these)

| file | what it is | length | notes |
|---|---|---|---|
| `amb-room-day.m4a` | the household's day room tone: soft air, distant homely movement, a clock-less calm | 2 min loop | the whole-app bed under every toy by day |
| `amb-room-night.m4a` | the night version: deeper quiet, occasional house settle | 2 min loop | crossfades with the clock |
| `amb-window-day.m4a` | outside-the-glass: faint birds, leaves, far air | 90s loop | Window only, ducks when curtains close |
| `amb-window-night.m4a` | night outside: cricket-sparse, one distant owl at most | 90s loop | restraint is the spec |
| `foley-wood-set.wav` | 8–12 small wooden contacts: block on block, soft knocks, a wooden slide | one-shots | Stack, Drop Dots, Sleepy Box thunks get REAL undertones layered beneath the synth |
| `foley-felt-set.wav` | felt/wool handling: presses, soft drops, a brush | one-shots | tokens, treasures, the cast |
| `foley-paper-set.wav` | page-soft paper ticks and slides | one-shots | Mix-Up flips, curtain peek |

## TIER 2 — the signature moments (what reviews quote)

| file | what it is | notes |
|---|---|---|
| `shelf-night-bed.m4a` | the shelf at night: a barely-there lullaby bed — felt piano or kalimba, 2–3 notes a minute over room tone | the App Store editorial frame needs its sound |
| `meadow-air.m4a` | open-air meadow: grass hush, one bee pass per minute | day Meadow |
| `bubbles-air.m4a` | high soft air, almost nothing — the sky between pops | replaces silence, not the pops |
| `water-sprinkle.wav` | a small watering can tip: 2s sprinkle on soil | the Phase A watering verb |
| `purr-loop.wav` | a real cat purr, close and slow, 20s loop | the sill cat; ducked under everything |

## TIER 3 — nice, not necessary
- `drawer-wood-slide.wav` (Sleepy Box / Drop Dots pulls get a real slide bed)
- `rain-on-window.m4a` (Bubbles rain weather + a future Window mood)
- seasonal one-shots for the visiting-things basket (a paper boat being set down…)

## Sourcing recommendations (lived experience)
1. **Record the foley yourself** — Tier 1's wood/felt/paper sets are 30 minutes
   with the actual toys on a phone in a quiet closet; authenticity beats library
   polish and the rights are absolute. (Voice memos at 0 gain, two inches away.)
2. Libraries that fit the brand if recording isn't on: **Soniss GDC bundles**
   (royalty-free, huge, real-material heavy), **BBC Sound Effects archive**
   (license check for commercial), **Artlist/Soundstripe SFX** (subscription,
   clean licensing for apps). Avoid freesound for ship audio — license hygiene
   per-file is a tax.
3. The night bed: commission or pick an instrumental stem with **stems
   deliverable** so we can drop the melody line if it's too present.
4. **Licensing requirement: royalty-free for paid app distribution, no
   attribution-required clauses** (Kids Category, no credits screen planned).

## How it lands (my side, zero work for you)
Drop masters in `Assets/Staging/Drops/audio-<date>/` with the names above (or
close — I'll rename). I convert, loudness-match, loop-check, wire through
AudioManager's existing profile tables, and verify per-toy ducking (toy voices
already duck the bed via `currentToyVoice`). Reduce-Motion/sound-off paths are
already honest.
