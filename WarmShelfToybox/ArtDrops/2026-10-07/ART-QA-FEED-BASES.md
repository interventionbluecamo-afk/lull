# Feed neutral masters and pebble-pair QA

Reviewed 2026-10-07 with read-only Pillow analysis and `view_image`. No images or app code changed.

## Feed neutral masters

All three PNGs are RGBA, 1086 × 1448 pixels, exactly 3:4 and wider than the requested 1024-pixel minimum. They have real transparency, zero alpha in the four corners, complete waist-up bodies, front-facing cameras and clear neutral faces. Character identity, clothes and warm clay/felt material are coherent. No targeted regeneration is justified before generating expressions.

| Master | Alpha >16 bounds | Alpha >128 bounds | Fully transparent pixels |
| --- | --- | --- | ---: |
| feed-cast-grandmother-1 | 92, 26, 996, 1431 | 93, 28, 995, 1431 | 36.802% |
| feed-cast-sprout-1 | 117, 54, 971, 1396 | 118, 55, 969, 1395 | 45.002% |
| feed-cast-knithat-1 | 115, 15, 972, 1426 | 117, 19, 970, 1426 | 40.304% |

Bounds are left, top, right, bottom with right/bottom exclusive. Exact any-nonzero and near-opaque bounds are in `feed-base-qa.json`.

### Knithat top edge

The pompom looks extremely close to the canvas top in the viewer. Numeric inspection finds only alpha 1 pixels in rows 0–11, with no pixels above alpha 16. Significant fur begins at row 15, and alpha >128 begins at row 19. No meaningful fur touches the boundary; the appearance is caused by barely visible fringe/noise. Keep the current frame for expression edits. If extra breathing room is added during integration, apply the same padded canvas to all six expressions rather than independently changing this master.

### Integration checks

The three heads sit at different heights because of bun, sprout and hat silhouettes. Existing Feed mouth/head assumptions must be checked against these new masters before hit regions and food travel are finalized. As rough visual landmarks only, the neutral mouths are near 51%, 52% and 57% down the full canvas for grandmother, sprout and knithat respectively. These estimates are not final interaction coordinates.

Neutral masters are suitable references for the next five expressions. Require the same dimensions, character size, camera, pose, clothing, lighting and position on every expression. Check all finished frames together before wiring the eating animation.

## Pebble pair

`meadow-pebbles-awake.png` is RGBA at 1254 × 1254. Its alpha >128 bounds are 122, 207, 1147, 1052; fully transparent pixels make up 60.960% of the canvas. All three open faces are readable, keep their natural individual tilts and preserve the family arrangement.

The asleep/awake silhouette IoU is 99.2981% at alpha >128. The alpha-weighted center shifts +0.840 pixels horizontally and +0.408 pixels vertically at master resolution. This is a closely aligned crossfade candidate; minor texture re-rendering still warrants a real in-game transition check. Keep a shared frame/crop for this pair, and account for the padded square canvas when setting runtime size.
