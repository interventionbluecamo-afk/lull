# Audio

Lull ships no audio files. Every sound is synthesized at runtime from the physical models in
`App/Shared/LullToneEngine.swift` (the sound book) and played by `App/Shared/AudioManager.swift`.
That keeps one tuning, one room and one loudness standard across all toys, and nothing to license.

- Add or change a sound: edit its recipe in `LullSoundBook.recipe` (and `cueIDs`), then run
  `python3 Tools/verify_sound_kit.py --wav <dir>` to render, check and listen.
- Engine behaviour (Sound Off, background, interruptions, beds, held notes):
  `python3 Tools/verify_audio_lifecycle.py`.

The previous MP3 recordings were removed in October 2026: none had recorded provenance or licence.
