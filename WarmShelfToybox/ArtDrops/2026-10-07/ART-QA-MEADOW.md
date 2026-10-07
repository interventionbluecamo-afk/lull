# Icon and Meadow art QA

Reviewed 2026-10-07. Read-only image analysis and visual inspection; no PNGs or app code were changed. These are masters for integration, not a verified running-app build.

All eight masters are 1254 × 1254 pixels. `icon-bg.png` is opaque RGB. The other seven are RGBA cutouts with real transparency and zero alpha in all four corners. Their visible bodies are nearly opaque (typically alpha 252–253); stray saturated pixels outside the body have very low alpha, so the red/yellow specks emphasized by the image viewer are not evidence of a solid colored matte.

Bounds below use alpha > 128 and are expressed as left, top, right, bottom, with right/bottom exclusive. Any-nonzero-alpha bounds are wider because of faint fringe/noise; exact values are in `meadow-qa.json`.

| Master | Significant alpha bounds | Fully transparent pixels | Visual finding |
| --- | --- | ---: | --- |
| icon-bg | 0, 0, 1254, 1254 | 0% | Complete felt dusk field, moon at upper right, stars at upper left, usable clear center. Check layer composition at actual icon size. |
| icon-stone | 177, 113, 1077, 1168 | 54.366% | Complete character, plain belly, clear sleeping face, adequate framing. |
| meadow-rock | 96, 107, 1165, 1144 | 43.685% | Overhead rock with readable sleeping face; moss and flowers are consistent. |
| meadow-rock-awake | 95, 103, 1167, 1146 | 43.903% | Clear open eyes and smile; position and silhouette match closely. |
| meadow-mushroom | 73, 79, 1182, 1172 | 40.104% | Overhead cap, no visible stem; sleeping face is clear. Red is brighter than the other Meadow colors, a design judgment to check in the actual scene. |
| meadow-mushroom-awake | 73, 77, 1184, 1174 | 40.090% | Open face, spots and silhouette preserved closely. |
| meadow-pebbles | 123, 208, 1145, 1051 | 60.913% | Three recognizable sleeping faces. The largest face is rotated with its pebble; that does not imply a wrong camera. No regeneration justified on this basis. |
| meadow-dandelion | 122, 98, 1122, 1121 | 42.575% | Radial overhead puff, feathered transparent boundary, no stem or horizon. More naturalistic than the felt faces; stylistic consistency needs the in-scene check. |

## Asleep/awake alignment

| Pair | Silhouette IoU, alpha >128 | Alpha-weighted center shift in master pixels | Assessment |
| --- | ---: | --- | --- |
| Rock | 99.3841% | +0.333 x, −0.175 y | Suitable for a crossfade candidate; no material jump expected from framing. |
| Mushroom | 99.6035% | +0.096 x, +0.631 y | Suitable for a crossfade candidate; no material jump expected from framing. |

These measurements establish closely aligned outlines, not identical pixels. The generated edits slightly re-render texture and color outside the face. A real app crossfade remains the final visual check.

## Integration implications

`ToyArt.sprite` in `App/Shared/ProceduralTexture.swift` fits the whole texture canvas. All these masters are square and retain transparent padding. At the current Meadow fit boxes, approximate significant-body sizes are rock 84 × 81 points, mushroom 80 × 78, pebbles 65 × 54, and dandelion 61 × 62. A blind replacement would make the pebble family especially small.

Revisit the runtime fit sizes or prepare consistent padded exports before judging legibility. If preparing trimmed exports, use a shared crop for both frames of each asleep/awake pair, retaining edge padding; do not independently trim expressions or derive crops from any-nonzero alpha noise. Keep these masters unchanged.

After importing the three top-down landmark families, switch their `isTopDown` flags together with the art, and check their rotation, touch footprint, day/night contrast and wake transitions in the game. The round overhead dandelion also warrants a new square presentation fit. No current finding justifies spending another generation on the reviewed assets before those checks.
