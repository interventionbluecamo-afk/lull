# Materials and motion pass — November 3–4, 2026

Read [Handoff.md](Handoff.md) for the current implementation, build status, release hold and founder checklist. Source implementation is pushed at `3e1405b`; all nine toys remain. Confirmed simulator coverage includes all nine phone portrait scenes and the shelf, Meadow day/night, Wash phone landscape and iPad Air M3 portrait/landscape, and Meadow iPad portrait/landscape. Founder physical acceptance remains pending.

## Navigation

| File | Purpose |
| --- | --- |
| [Handoff.md](Handoff.md) | Current status and remaining validation. This supersedes the earlier proposed/paused implementation status. |
| [Meadow-Hum-Bubbles.md](Meadow-Hum-Bubbles.md) | Shelter anchors, recurring five-slot discovery state, route details, mallet/contact timing and visible bird ownership. |
| [Wash.md](Wash.md) | Clean-plate camera contract, brush anchors, gesture priority, wetting/drain behavior and cleanup. |
| [Sleepy-MixUp.md](Sleepy-MixUp.md) | Wood material/bevel follow-up, exact shape/socket geometry, connected cast motion and saved-recipe retention. |
| [Feed-Window-Dots.md](Feed-Window-Dots.md) | Food attention/eye landmarks, curtain mesh/attachment and delayed stack settling. |
| [Assets.json](Assets.json) | Generated-source paths, selected production copies, dimensions, hashes and first tuft candidate. |
| [Prompts.json](Prompts.json) | Exact clean-room, initial tuft and registered shelter-layer prompts. |
| [Wash-neutral-tuft-prompt.json](Wash-neutral-tuft-prompt.json) | Exact final colour-only edit of the registered tuft. |
| [Previews/README.md](Previews/README.md) | Root-owned record of actual simulator captures. See [confirmed coverage and limits](Handoff.md#confirmed-simulator-evidence): a limited Meadow held-touch/rotation observation is recorded; physical timing/audio/multitouch/Reduced Motion/VoiceOver acceptance is still pending. |

## Generated parts and reference chain

The selected outputs below are copied **unmodified** into the production catalog. `Assets.json` retains their original Codex-generated paths and hashes; the tracked production PNGs preserve the selected bytes even if the local generated-image cache is later unavailable. Existing asset slot names and fallback/source history remain intact.

| Production part | Input/reference and exact record |
| --- | --- |
| [wash-bay-clean](../../../App/Resources/Assets.xcassets/wash-bay-clean.imageset/wash-bay-clean.png) | Edited from the [original landscape bay](../../../App/Resources/Assets.xcassets/wash-bay.imageset/wash-bay.png); `Prompts.json` → `washLandscape`; `Assets.json` → `wash-bay-clean`. |
| [wash-bay-portrait-clean](../../../App/Resources/Assets.xcassets/wash-bay-portrait-clean.imageset/wash-bay-portrait-clean.png) | Edited from the [original portrait bay](../../../App/Resources/Assets.xcassets/wash-bay-portrait.imageset/wash-bay-portrait.png); `Prompts.json` → `washPortrait`; `Assets.json` → `wash-bay-portrait-clean`. Earlier portrait source: [Wash-2026-11-03/Prompt.json](../Wash-2026-11-03/Prompt.json). |
| [wash-brush-tuft](../../../App/Resources/Assets.xcassets/wash-brush-tuft.imageset/wash-brush-tuft.png) | Initial style reference: original landscape bay. Initial generation: `Prompts.json` → `washBrush`. The [archived colour study](Source/wash-brush-tuft-color-study.png) is the first candidate, not active production. The final neutral colour edit is in `Wash-neutral-tuft-prompt.json`; both outputs are recorded under `Assets.json` → `wash-brush-tuft`. |
| [meadow-leaf-house-base](../../../App/Resources/Assets.xcassets/meadow-leaf-house-base.imageset/meadow-leaf-house-base.png) | Registered extraction from the [selected one-piece shelter](../../../App/Resources/Assets.xcassets/meadow-leaf-house.imageset/meadow-leaf-house.png); `Prompts.json` → `meadowBase`; `Assets.json` → `meadow-leaf-house-base`. |
| [meadow-leaf-house-roof](../../../App/Resources/Assets.xcassets/meadow-leaf-house-roof.imageset/meadow-leaf-house-roof.png) | Same one-piece shelter/reference canvas; `Prompts.json` → `meadowRoof`; `Assets.json` → `meadow-leaf-house-roof`. The rest-state registration and hinge/doorway measurements are in [Meadow-Hum-Bubbles.md](Meadow-Hum-Bubbles.md#meadow). |

The selected one-piece shelter's own prompt, old-house/material references and output hash are in [Meadow-Materials-2026-11-03/Prompt.json](../Meadow-Materials-2026-11-03/Prompt.json). The [older Build10 house](../Build10/Source/meadow-leaf-house.png) remains historical evidence. The old full-house glow stays bundled but is not used by the new doorway renderer.

No new production images were needed for the other seven toys. Their scoped notes identify reused art, procedural surfaces and attachment measurements; follow the source links in [Handoff.md](Handoff.md#what-changed).

## Repository-wide references

- [Approved plan](../../Plan-Materials-Motion-2026-11-03.md), [Brand](../../Brand.md), [Aliveness Principles](../../AlivenessPrinciples.md).
- [Art navigation](../README.md), [catalog inventory](../Inventory.json), [asset map](../../AssetManifest.md), [source/staging guide](../../../Assets/README.md).
- [Current project handoff](../../HANDOFF-CURRENT.md). Earlier release entries are historical and do not authorize a new upload.

Catalog presence does not establish runtime use, and matching hashes do not authorize deletion. The scoped notes preserve exact verification commands and limits; their large model-check counts must not be described as live play sessions.
