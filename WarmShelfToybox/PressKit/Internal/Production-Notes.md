# Maintenance and evidence — not a public NotebookLM source

Prepared November 13, 2026 from Lull repository `230f14b`, with no app changes. This is an owned-media/press resource, not an App Review submission or public release. Live availability and current App Store pricing were not checked. The existing local website configuration still has `launched: false`; that is not a substitute for live store status. The web reader could not open the public site; a direct HTTP request returned 200. This confirms the website responded, not App Store availability.

## Source of truth

- Upload only `NotebookLM/01-Lull-Overview.txt` for the clean factual product overview. `02-Podcast-Script.txt` is proposed narration, not testimony. `Prompts.txt` controls generation.
- The core nine-toy descriptions are established before the 1.1 beach update. Development images carry their actual build number.
- Current release evidence: `Docs/HANDOFF-CURRENT.md` and `Docs/Art/Meadow-Beach-2026-11-04/Handoff.md`; 1.1(21) uploaded November 4. No new availability claim is made here.
- Known open development issues include the beach path/drag feedback and unconfirmed SpriteKit crash mitigation. These belong in the engineering handoff, not in promotional screenshots described as released.
- The local `Claude outputs/Review-2026-11-12.md` and separate `Ladybug Kraft/` prototype are not incorporated into this press kit or committed by this task.

## Evidence for core statements

Paths relative to `WarmShelfToybox/`, at the source revision above:

| Topic | Evidence | Copy boundary |
|---|---|---|
| Nine current toys | `App/Shared/ToyRegistry.swift:30`, scene mappings at 55–182; `Docs/AppStore/SubmissionKit.md:100` | No Stack or prototype-only toys. |
| Timer choices | `App/Shared/ParentInfoViewController.swift:174` | Off/15/30/45/60 minutes. |
| Foreground sitting / hour reset | `App/Shared/AdultGate.swift:323`, 378–389, 431–445 | Never claim only a grown-up can ever wake it. |
| Moon rest | `App/Shared/AdultGate.swift:470` | App pause, not device-wide restriction. |
| Wind-down | `App/Shared/ParentInfoViewController.swift:189`; `App/Shared/TimeOfDay.swift:25` | Warmth/dimming, not sleep efficacy. |
| Local state/privacy/support | `App/Shared/ParentInfoViewController.swift:982`; `App/PrivacyInfo.xcprivacy:16` | Local data/backup, Apple purchases and voluntary support are qualified. |
| StoreKit | `App/Shared/LullDemoState.swift:394`, 478, 523–545 | No assertion that the app never connects to the internet. |
| Purchase model | `App/Shared/ToyRegistry.swift:204`; `App/Shared/LullPlansViewController.swift:7` | No permanent free toy tier. |
| Documented prices | `Docs/Launch/Launch-Checklist.md:23` | Historical configured US $29.99/year, eligible 7-day trial; $59.99 once. Reconfirm before public use. |
| Support email | `App/Shared/ParentInfoViewController.swift:52` | `lullios@proton.me`, not the historical unowned lull.app address. |
| Guided Access | `App/Shared/ParentInfoViewController.swift:319`; `Docs/Update-2026-11-03/Handoff.md` | Apple's feature; help card belongs to 1.1 update, not claimed shipped in 1.0. |
| Family-testing story | Founder messages in this project; `Docs/Marketing/2026-11-03-parent-campaign/Photo-guide-and-captions.txt` | No invented quote, biography, child testimonial or private child photo. |
| Visual rules | `Docs/Brand.md`, `Docs/AlivenessPrinciples.md` | Current production sections; older Stack concepts are historical. |

The repository's old “three free toys,” “$9.99,” “support@lull.app,” “new toys each season,” and old submission-status paragraphs must not silently enter generated copy. This kit intentionally makes no future cadence promise. Do not change existing purchase promises or store terms through this kit.

## Artwork handling

Originals remain unchanged in their existing folders. The press copies are byte-identical selected exports. `Asset-Catalog.json/csv` records original paths, SHA-256 hashes, types, build/status labels and available prompt provenance. `Full-Game-Asset-Inventory.json` indexes the broader game asset library for future production; paths point to the repository, not additional copies in this kit. Historical and cancelled concepts are not recommended press assets.

Use “Courtesy of Lull” as a proposed credit. Generated art is described honestly as promotional illustration or game art; no blanket claim of exclusive copyright or third-party permission is made. The kit does not grant rights to unrelated third-party logos, music, customer photos or fonts. Do not imply Apple, Google, Montessori organizations or named studios endorse Lull.

## Reuse / update procedure

1. Check the intended release build and public offer before a launch-specific campaign.
2. Update the overview/fact sheet, preserving the timer, privacy and eligibility qualifications.
3. Capture missing real screens/footage from that same build. Update asset status/version labels; do not invent UI with image generation.
4. Add chosen public founder media only after the founder deliberately selects it. Keep private device/payment/review screens out.
5. Rebuild the index and ZIPs with `python3 Tools/Marketing/package_press_kit.py`. The packager validates asset hashes and excludes Internal from the press distribution ZIP.
6. Listen to/watch generated output once for factual drift, mispronunciation, synthetic testimony and stale price/availability claims.

No website, social post, NotebookLM notebook or App Store field has been published or changed by this task.
