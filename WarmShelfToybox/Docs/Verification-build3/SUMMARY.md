# Build 3 deterministic verification

- Revision tested: `01d7b164be3e7f1be4c286f8a4453d049aa819d9`
- Branch: `claude/modest-bell-cjarqm`
- Started (UTC): 2026-10-07T20:24:24.476305+00:00
- Finished (UTC): 2026-10-07T20:25:15.424095+00:00
- Result: **9/9 scripts passed**, all final exit codes 0.
- Printed check counts total 1,058, plus four onboarding scenarios, four rest-suspension scenarios, and Window active-path checks.

| Script | Result | Reported coverage | Complete log |
| --- | --- | --- | --- |
| `verify_adult_gate.py` | PASS | 12 checks | [verify_adult_gate.log](verify_adult_gate.log) |
| `verify_audio_lifecycle.py` | PASS | 25 checks | [verify_audio_lifecycle.log](verify_audio_lifecycle.log) |
| `verify_feed.py` | PASS | 152 checks | [verify_feed.log](verify_feed.log) |
| `verify_mixup_layout.py` | PASS | 280 checks; 14 layout fixtures | [verify_mixup_layout.log](verify_mixup_layout.log) |
| `verify_mixup_stack.py` | PASS | 145 checks | [verify_mixup_stack.log](verify_mixup_stack.log) |
| `verify_onboarding_state.py` | PASS | 4 reported scenarios | [verify_onboarding_state.log](verify_onboarding_state.log) |
| `verify_rest_suspension.py` | PASS | 4 reported scenarios | [verify_rest_suspension.log](verify_rest_suspension.log) |
| `verify_window.py` | PASS | 176 native checks plus active-path checks | [verify_window.log](verify_window.log) |
| `verify_world_interactions.py` | PASS | 268 checks | [verify_world_interactions.log](verify_world_interactions.log) |

The first Mix-Up/Stack attempt stopped before running checks because system Python lacked Pillow. It passed when rerun with the Codex bundled Python and Pillow; the original output is retained in [verify_mixup_stack.initial.log](verify_mixup_stack.initial.log). No verification script or production Swift was changed.

Scope: production helper extraction, off-device Swift execution with stand-ins, source-path checks, and asset geometry checks. No app UI, simulator play-testing, physical audio checks, or purchase testing was performed. Those remain founder-owned.

Machine-readable records, full captured output, exit codes, durations, revision and environment details are in [results.json](results.json).
