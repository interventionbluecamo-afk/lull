# Feed expression art QA

Reviewed 2026-10-07. All 18 Feed PNGs were inspected visually and analyzed without changing images or app code. Metrics and portable filenames are in `feed-expression-qa.json`. This is an art handoff review; no gameplay transition has been verified with these files installed.

## File and expression checks

All 18 files are RGBA, 1086 × 1448 pixels (3:4), with real alpha and fully transparent corners. Neutral, happy, laugh, sleepy, surprise and chewing are recognizable and coherent within each family. Grandmother retains glasses, bun and mustard shawl; sprout retains its two leaves and green cable-knit sweater; knithat retains its striped lavender hat, pompom and blue sweater. No material identity or camera failure was found.

The edits are not pixel-identical outside the face. Generated variants change texture, color, body scale and position slightly. Knithat is the most stable family; grandmother and sprout require more care when aligning runtime expressions. Do not infer perfect animation registration from identical file dimensions.

## Alignment against each family's neutral

Silhouette IoU uses alpha >128. Center shifts are alpha-weighted master-pixel changes relative to frame 1; +x is right and +y is down. These measurements quantify framing, not facial landmarks.

| Family | Frame | Expression | Silhouette overlap | Center shift x, y |
| --- | ---: | --- | ---: | --- |
| Grandmother | 2 | Happy | 92.6601% | +16.745, +17.908 |
| Grandmother | 3 | Laugh | 95.7099% | +14.689, +1.365 |
| Grandmother | 4 | Sleepy | 92.7506% | +17.023, +17.243 |
| Grandmother | 5 | Surprise | 97.3232% | +9.163, −0.412 |
| Grandmother | 6 | Chewing | 92.7443% | +16.833, +17.312 |
| Sprout | 2 | Happy | 90.7330% | +13.626, +24.958 |
| Sprout | 3 | Laugh | 94.1835% | +3.241, +16.758 |
| Sprout | 4 | Sleepy | 94.7917% | +14.441, +2.340 |
| Sprout | 5 | Surprise | 89.9124% | +16.915, +24.584 |
| Sprout | 6 | Chewing | 89.9719% | +16.770, +25.427 |
| Knithat | 2 | Happy | 98.1498% | +3.715, −3.133 |
| Knithat | 3 | Laugh | 97.0169% | +7.999, −1.717 |
| Knithat | 4 | Sleepy | 98.6540% | +0.812, −3.552 |
| Knithat | 5 | Surprise | 98.7524% | +0.605, −2.249 |
| Knithat | 6 | Chewing | 98.9054% | +0.689, −3.237 |

The largest vertical center movement is 25.427 pixels, about 1.76% of master height. At a 288-point character presentation, unchanged full-canvas swapping would translate that movement into about 5.1 points. Body-shape differences may remain after a simple positional correction, so test the actual eating sequence before accepting its polish.

## Framing exception

Grandmother frames 2, 4 and 6 have meaningful lower-body pixels on the bottom canvas row: 515, 505 and 494 pixels respectively exceed alpha 128 there. Their lower body is cropped slightly by the canvas, unlike neutral. The Feed counter hides this part of the body, so this is not a necessary regeneration for the intended counter scene. These three are not complete standalone character cutouts; do not reuse them in a full-body presentation without addressing the bottom crop.

Sprout variants 2, 5 and 6 enlarge/lower the sweater and hands compared with neutral. They retain a small transparent bottom margin and are not clipped. Knithat frames retain meaningful top padding; no pompom clipping was found.

## Chewing assessment

All three frame-6 images have a closed mouth and softly fuller cheeks. Sprout shows the clearest cheek change, grandmother reads as contented chewing, and knithat's cheeks and softened lower-eye area support the same intent. These are subtle static expressions, not complete chewing animations. Context from food delivery, a small timed chew motion and the subsequent happy expression will determine whether children understand the reaction. Keep the closed-mouth state during the chew instead of using the open laugh frame as the chewing substitute.

## Integration recommendation

Preserve the masters. Prepare consistent frame placement for each six-frame family and recalibrate mouth/head interaction coordinates using the installed artwork. Keep any body cropping hidden behind the counter, and check neck/counter seating while switching every expression. A rapidly repeated unchanged texture swap may reveal body or shawl movement. Inspect portrait and landscape, small-device readability and the actual surprise → chewing → happy sequence before including the new art in another TestFlight build.

No major wrong-expression, wrong-identity or camera issue justifies another generation before this integration pass. The remaining concerns are documented framing and transition polish, not a claim that the assets are already perfectly registered animation frames.
