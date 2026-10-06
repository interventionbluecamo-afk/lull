# Codex Art Run — June 14b (Feed's backdrop, regenerated)

The current `feed-stand-back` plate is broken three ways (founder, June 14): red/cyan
**keying fringe** around the window and counter, smiling **food-faces baked into the
art** (they fight the real interactive friends and the food the child feeds them), and a
**hard rectangular window frame** that makes the friend read as a framed portrait, not a
friend leaning out to be fed. Direction chosen: **open counter, soft nook** — no hard
frame. One image.

## INSTRUCTIONS FOR CODEX — READ FIRST

1. ONE item. Send the quoted prompt **exactly as written** to GPT 5.5 image generation.
2. **This is a FULL-BLEED BACKGROUND, not a keyed object.** Generate a complete,
   edge-to-edge rectangular image. Do **NOT** put it on a flat teal field, do **NOT**
   remove or key out any background, do **NOT** leave transparency. (The fringe on the
   old one came from keying a background that never needed keying — a full-bleed plate
   has no cut-out, so no halo.)
3. Save as **`feed-stand-back.png`** into
   `~/Desktop/WarmShelfToybox/Assets/Staging/Drops/jun14-feed/` (create the folder once).
4. **ATTACH** the current plate as a *mood/palette* reference only — match its warmth and
   farm-stand feeling, but FIX everything listed in the prompt (open it up, no frame, no
   baked-in faces, no counter):
   `App/Resources/Assets.xcassets/feed-stand-back.imageset/feed-stand-back.png`
5. Do not post-process. Save and move on. If it fails (any text, any baked-in
   characters/food, a hard window frame, a counter, visible cut-out edges), retry once.

---

## 1. `feed-stand-back.png` — the open farm-stand nook (full-bleed background)
## ATTACH: the current `feed-stand-back.png` (mood + palette only — correct its faults)

> A warm, soft, slightly out-of-focus BACKGROUND for a children's farm-stand feeding
> scene, soft 3D clay-and-felt stop-motion style, matte clay and warm honey wood,
> hand-felted wool textures, gentle butter lamplight from the upper left, soft vignette,
> muted warm Montessori palette (linen #F2E8C6, cream #FAF0D8, terracotta #D4583A,
> sage #6A8B66, butter #E8C045, soft water-blue #85C5CF), cozy and serene, no text
> anywhere. The scene: a snug farm-stand nook seen from the child's side — to the soft
> upper sides, warm wooden shelves with a few rounded produce baskets gone gently blurry;
> up high, a small string of felt bunting and one soft warm hanging-lamp glow; and behind,
> an OPEN, dreamy, out-of-focus glimpse of rolling green countryside under a pale warm sky
> — with absolutely NO hard window frame, NO rectangular opening, and NO outline; just a
> soft, open, airy backdrop. Keep the LOWER THIRD calm, simple and uncluttered — a soft
> warm out-of-focus surface — because a separate counter, the friends, and the food are
> placed ON TOP of this in the app. CRITICAL: this background must be EMPTY of objects and
> creatures — do NOT draw any counter, table, friend, character, face, fruit, vegetable,
> egg, or food of any kind. Full-bleed tall vertical portrait, edge to edge, no border,
> no frame, no cut-out. About 1290×2796 or larger.

---

## After Codex — the landing pass (not Codex's job)
1. No keying — the plate is opaque full-bleed. Just resize/pad to fit the imageset and
   land it as `App/Resources/Assets.xcassets/feed-stand-back.imageset/` (Contents.json,
   scale `3x`), replacing the broken file.
2. Relaunch Feed and re-check in code: (a) the separate `feed-counter` sprite is now the
   only counter and sits at the right height, (b) the food row settles on that counter
   (founder: "food settles in a weird spot" — verify the food rest spots against the new
   plate), (c) the friends read as leaning over an open counter, not boxed in a frame.
3. This run only fixes the BACKDROP. The food-settle position is a code fix in
   `FeedScene.swift`, done in the same pass once the new plate is in.

*One image. The friends (CharacterNode) and the food items stay exactly as they are —
they are live sprites composited on top, never baked into this plate.*
