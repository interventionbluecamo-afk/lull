# Mix-Up friends C: robot, police officer, firefighter

October 8, 2026. The robot, police officer and firefighter are back in Mix-Up as cast indices 6, 7 and 8 (nine friends, 729 combinations). For now they use the build-1 part images (`robot2-*`, `officer-*` and `firefighter-*`; officer-legs is despilled). Those parts are a little more saturated than the felt animals and have bigger glossy eyes. This page holds the prompt for the matching atlas, `mixup-friends-c`, and the steps to wire it in. The code already prefers atlas C once its rects are measured, so the art can be swapped without a code change beyond pasting the rects.

Saves are not affected. Indices 6-8 stay robot, officer and firefighter, so **do not bump `castVersion`** for this art swap.

## 1. Generate

Use the built-in image generator with a transparent background, in the same mode as `ArtDrops/2026-10-07-mixup/prompts.json`. Attach these references:

- `ArtDrops/2026-10-07-mixup/mixup-friends-a.png` and `mixup-friends-b.png` for style, scale, layout and the felt palette.
- The nine legacy parts in `App/Resources/Assets.xcassets/` (`robot2-head/body/legs`, `officer-head/body/legs`, `firefighter-head/body/legs`) to show who the friends are.

Paste-ready prompt (one atlas, 1536x1024 landscape):

```text
Use case: stylized-concept.
Asset type: one transparent modular character sprite atlas for Lull, a calm tactile children's toy for ages 2–6.
Create a landscape atlas of THREE DIFFERENT handmade felt friends, in THREE COLUMNS and THREE ROWS, all isolated on a truly transparent background. Column 1 a friendly little robot of soft warm-gray felt with a rounded square head, a cream felt face plate and a short stalk antenna topped with a small butter-yellow felt ball, the ball sitting firmly on its stalk; column 2 a kind police officer doll with short dark hair, a small moustache and a soft dusty-navy peaked cap with a small butter-yellow felt star badge; column 3 a cheerful firefighter doll with curly dark hair and a rounded muted clay-red felt helmet with a small cream shield on the front. Row 1: their separate heads only, front facing, chin flat at the same height; antenna, cap and helmet included and kept compact, each head about as tall as it is wide. Row 2: their separate short rounded torsos and arms only, with a clean flat top neckline and flat bottom waist. Robot torso: warm-gray felt chest box with three small stitched dots in sage, butter and clay, soft rounded gray arms with mitten-like hands; officer torso: dusty-navy felt uniform shirt with cream buttons, two pocket flaps, a small butter-yellow star badge stitched on, and warm felt hands; firefighter torso: muted clay-red felt coat with ochre reflective bands, wooden toggle fasteners, an ochre collar and warm felt hands. Keep arms out to sides so a flat waist line is clear. Row 3: their separate short legs and two feet only, attached together at a flat wide top waist seam; robot two stacked warm-gray felt leg rings joined at the top by one flat felt hip plate, with rounded gray boots; officer dusty-navy trousers with a small ochre belt buckle and soft dark-brown shoes; firefighter charcoal trousers with ochre bands and cocoa-brown boots.
This is ONE interoperable mix-and-match doll set that matches the attached felt animals: same size heads, same size torsos, same width top seam on every leg piece; each head can fit on any torso, and any torso can fit on any legs. Parts should touch seamlessly when assembled. Every part is ONE connected piece: the antenna ball sits on its stalk, badges are stitched on, and both legs and feet are joined by the waist seam. Uniform camera: straight-on orthographic; same soft light from upper left. No perspective, no turning, no floor shadows, no room, no base, no separators, no text, no labels. Leave generous clear transparent gaps BETWEEN all nine separate parts, no overlap, no extra whole characters. Each cell occupies exactly one third of width and one third of height, centered in its cell. Use large cell filling artwork, leaving 8% padding each side.
Style: premium stop-motion wool felt dolls, fine matte wool fibers, plump rounded forms, friendly small black bead eyes with one subtle highlight (the robot's bead eyes sit in small cream felt rings), gentle smiles, softly blushed cheeks. Warm cream, sage, clay and dusty blue palette, restrained charming detail; uniforms in muted dusty navy and clay red, never black and never bright red. Calm and gentle, nothing scary: no sirens, no flashing lights, no tools, no hoses, no weapons. All painted material must be fully opaque, including dark navy edges and fibers: no eaten-away speckles, holes, ragged transparent patches or keyed color contamination. Clean alpha antialiasing only at the exterior silhouette. NO checkerboard baked into image. Flat neck and waist mating seams matter more than embellishment.
```

Before accepting a result, check these proportion limits. The code fits every part into fixed boxes, and the limits keep the new friends no more distorted than the animals:

| Part | Limit | Why |
|---|---|---|
| Head height / width, antenna, cap and helmet included | 1.28 or less (aim for about 1.0) | A taller head than bunny's grows the Mix-Up envelope, shrinks every character and breaks the layout fixture. |
| Body width / height | about 1.7-1.9 | The body is drawn into a 120x74 box, as in atlases a and b. |
| Legs width / height | about 1.15-1.25 | The legs are drawn into an 86x56 box with a shared floor. |

## 2. Store the master

1. Save the PNG as `ArtDrops/<date>-mixup-c/mixup-friends-c.png`. Save the exact prompt next to it as `prompts.json`, in the same shape as `ArtDrops/2026-10-07-mixup/prompts.json` (`"tool": "built-in image_gen"`, `"transparent_background": true`, `"mode": "generate"`, `"prompts": [ ... ]`).
2. Confirm the file is 1536x1024 RGBA with real transparency: corners at alpha 0 and no checkerboard. Do not despill, key or paint over it. Atlases a and b ship with their native alpha, and C should too.

## 3. Measure

```sh
cd WarmShelfToybox
python3 Tools/Art/measure_atlas.py ArtDrops/<date>-mixup-c/mixup-friends-c.png robot officer firefighter --sheet /tmp/mixup-c-rects.png
```

The tool finds connected components on alpha above 8. It requires exactly nine, sorts them row by row and then column by column, pads each box by 3 px and prints:

- one comment line per friend with the head, body and legs proportions, which flags any head taller than bunny's;
- the two Swift declarations, `friendsCCanvas` and `friendsCBounds`.

Open the `--sheet` image and check that every rect sits on the chin (head), the collar and waist (body), and the waist and soles (legs).

If the tool stops with "found N painted components", fix the art. Do not hand-tune the rects.

- **More than 9:** something is detached, such as an antenna ball floating above its stalk, a loose badge, or robot legs drawn as two separate columns. Dust under 16 px is ignored with a warning.
- **Fewer than 9:** two parts touch. Ask for wider transparent gaps.

## 4. Wire

1. Copy the master, byte-identical, to `App/Resources/Assets.xcassets/mixup-friends-c.imageset/mixup-friends-c.png`. Give it this `Contents.json`, the same shape as a and b (universal, 1x):

   ```json
   {
     "images": [
       { "filename": "mixup-friends-c.png", "idiom": "universal" }
     ],
     "info": { "author": "xcode", "version": 1 }
   }
   ```

2. In `App/Toys/MixUp/MixUpPart.swift`, replace these two placeholder lines with the two declarations the tool printed:

   ```swift
   private static let friendsCCanvas = CGSize(width: 1536, height: 1024)
   private static let friendsCBounds: [String: [MixUpZone: CGRect]] = [:]
   ```

   `artSource` then prefers atlas C for each of the three friends that has all three rects and whose imageset loads. Without rects, or without the imageset, the interim single-image parts are used.

3. Run the checks. On a Mac `xcrun swift` is used. Elsewhere, set `SWIFT` to a toolchain's `swift`.

   ```sh
   python3 Tools/verify_mixup_stack.py    # re-measures C and asserts each rect hugs its part, the head limit, cast order, migration
   python3 Tools/verify_mixup_layout.py   # unchanged envelope CGRect(-60, -98, 120, 239) on 14 layouts
   ```

4. Device QA. Launch with `LULL_DEBUG_MIXUP_INDEX=6`, then 7, then 8 (Debug builds): each opens as that whole friend. Flip one zone away and back to see its arrival move and its whole-friend moment (signature, then the bow). Then flip through some mixes and check for floating feet, gaps at the collar or waist, and halos.

5. Once C has shipped, the legacy `robot2-*`, `officer-*` and `firefighter-*` imagesets can retire. Until then they are the fallback, and `Docs/Handoff-Claude-to-ChatGPT-2026-10-07-release.md` keeps them out of the legacy-imageset cleanup.
