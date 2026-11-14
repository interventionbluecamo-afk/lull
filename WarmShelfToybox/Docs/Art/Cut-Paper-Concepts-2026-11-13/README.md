# Lull cut-paper design concepts

These nine image-generation mockups explore the supplied cut-paper brief. Generated results are design concepts, not actual app screenshots or production replacements. This package makes no app or App Store changes and does not change PressKit assets.

`Inputs/` contains unchanged copies of all nine supplied images and [Original-Brief.txt](Inputs/Original-Brief.txt). [Input-Manifest.json](Input-Manifest.json) records original and copied paths, SHA-256 digests, byte counts, and image dimensions; all copies are byte-identical to their originals.

Nine concepts were generated with the built-in `image_gen` tool, one edit per requested toy using its matching source image and brief. The intended changes are limited to the background or materials expressly listed in each brief. Source layout, camera, framing, controls, geometry, and unchanged toy identity remain authoritative for implementation.

The Meadow beach input is **landscape, 1748 × 804 px**. Preserve that actual frame; the brief’s request for portrait is a typo. Preserve the other inputs’ actual dimensions and portrait framing as requested.

Generative edits may vary in dimensions or details. Every result requires visual approval and reconstruction as layered code before production use; a generated mockup is not a replacement for app assets or an App Store screenshot.

| Toy | Source copy | Dimensions (px) |
| --- | --- | --- |
| Bubbles | `1-bubbles.jpg` | 1206 × 2622 |
| Feed | `2-feed.jpg` | 1206 × 2622 |
| Little Wash | `3-little-wash.jpg` | 1206 × 2622 |
| Sleepy Box | `4-sleepy-box.jpg` | 1206 × 2622 |
| Window | `5-window.jpg` | 1206 × 2622 |
| Drop Dots | `6-drop-dots.jpg` | 1206 × 2622 |
| Mix-Up | `7-mix-up.jpg` | 1206 × 2622 |
| Hum | `8-hum.jpg` | 1206 × 2622 |
| Meadow beach | `9-meadow-beach.png` | 1748 × 804 |

## Generated outputs

Open [index.html](index.html) for the offline original/concept comparison gallery. `Outputs/` contains the nine generated PNGs, copied unchanged; [Output-Manifest.json](Output-Manifest.json) records paths, matching SHA-256 digests, actual dimensions, aspect-ratio differences, and review limitations. [Generation-Prompts.json](Generation-Prompts.json) preserves the prompts, and [Generation-Sources.json](Generation-Sources.json) maps the original generated files to packaged outputs.

These concepts are **not pixel exact**: their output dimensions and some proportions differ from the sources. Do not use them as implemented app screenshots or publish them as such. Source controls and geometry must remain authoritative when rebuilding approved treatments as layered code.

| Toy | Generated dimensions (px) | Output |
| --- | --- | --- |
| Bubbles | 784 × 2007 | `01-bubbles-cut-paper-concept.png` |
| Feed | 851 × 1848 | `02-feed-cut-paper-concept.png` |
| Little Wash | 851 × 1849 | `03-little-wash-cut-paper-concept.png` |
| Sleepy Box | 851 × 1849 | `04-sleepy-box-cut-paper-concept.png` |
| Window | 851 × 1848 | `05-window-cut-paper-concept.png` |
| Drop Dots | 784 × 2007 | `06-drop-dots-cut-paper-concept.png` |
| Mix-Up | 784 × 2007 | `07-mix-up-cut-paper-concept.png` |
| Hum | 784 × 2007 | `08-hum-cut-paper-concept.png` |
| Meadow beach | 1849 × 851 | `09-meadow-beach-cut-paper-concept.png` |

Review caveats:

- **Bubbles:** generated solid rims and shadows must not become literal paper bubbles in the app.
- **Mix-Up:** the bunny proportions drifted; preserve the source character proportions and geometry.
- **Meadow beach:** the water shows two dominant visible bands rather than the requested three overlapping sheets.
- **Drop Dots, Mix-Up, and Hum:** generated frame proportions visibly differ from their source frames. See the manifest for exact dimensions and aspect-ratio differences for all nine outputs.

The downloadable ZIP contains this folder’s complete contents with `index.html` at the archive root. Extract the archive, then open `index.html`; all image and document links work offline.
