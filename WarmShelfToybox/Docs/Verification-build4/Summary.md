# Lull 1.0 (4) — Mac verification

Completed 2026-10-08T16:03:03.064855+00:00.

**All 10 `Tools/verify_*.py` scripts pass.** Production source is unchanged from revision `6873084d11be2a36b6796acfbf522a144a190d13` on branch `claude/modest-bell-cjarqm`. No UI, listening, play or purchase testing was performed; the founder owns those checks.

| Script | Status | Reported count | Full log |
| --- | --- | --- | --- |
| `verify_adult_gate.py` | PASS | 12 checks | [verify_adult_gate.log](verify_adult_gate.log) |
| `verify_audio_lifecycle.py` | PASS | 53 checks | [verify_audio_lifecycle.log](verify_audio_lifecycle.log) |
| `verify_feed.py` | PASS | 152 checks | [verify_feed.log](verify_feed.log) |
| `verify_mixup_layout.py` | PASS | 280 checks | [verify_mixup_layout.log](verify_mixup_layout.log) |
| `verify_mixup_stack.py` | PASS | 145 checks | [verify_mixup_stack.log](verify_mixup_stack.log) |
| `verify_onboarding_state.py` | PASS | 4 scenario groups | [verify_onboarding_state.log](verify_onboarding_state.log) |
| `verify_rest_suspension.py` | PASS | 4 scenario groups | [verify_rest_suspension.log](verify_rest_suspension.log) |
| `verify_sound_kit.py` | PASS | 2,486 checks / 523 rendered sounds | [verify_sound_kit.log](verify_sound_kit.log) |
| `verify_window.py` | PASS | 176 native checks + active-source-path assertions | [verify_window.log](verify_window.log) |
| `verify_world_interactions.py` | PASS | 268 checks | [verify_world_interactions.log](verify_world_interactions.log) |

The scripts reporting numeric check totals account for **3,572 checks**, plus the onboarding and rest scenario groups and Window source-path assertions listed above. The sound-kit run rendered samples for measurement only; no audio files were shipped or played.

## Lifecycle harness correction

The initial lifecycle run failed at “Waking fades the breathing bed out.” Its original `spinReal` waited by wall time while advancing the simulated clock by only 20 ms per run-loop cycle. On macOS, longer cycles could leave the simulated fade unfinished: instrumentation measured 1.8 s of wall time advancing the simulated clock only 1.6 s, and a 1.7 s wait advancing it only 1.42 s. The instrumented harness passed 53 checks against unchanged production code.

Only `Tools/verify_audio_lifecycle.py` was corrected: the simulated clock now advances by elapsed monotonic time, reaches the requested duration, and gives the production fade timer one bounded final run-loop interval. All lifecycle assertions remain. The corrected script passed **53 checks** on rerun. No production Swift files were edited. Other passing scripts were not repeated.

- [Initial failure](verify_audio_lifecycle-initial-failure.log)
- [Diagnostic timing run](verify_audio_lifecycle-diagnostic.log)
- [Corrected lifecycle run](verify_audio_lifecycle.log)
- [Machine-readable results and production source hashes](verification-results.json)

## Environment and scope

- Apple Swift 6.4 (`swiftlang-6.4.0.34.1`, arm64 macOS).
- Codex bundled Python 3.12.14, Pillow 12.3.0 and NumPy 2.3.5.
- Full per-script output, timestamps, exit status and revision are retained in this directory.
- No production source changed during any verification run. The only tracked working-tree change is the verification harness correction above; logs are untracked for review. No commit or push was made.
