# Lull — ChatGPT art handoff to Claude

October 7, 2026. This continues your design pass 2 and supplies the artwork requested in `Docs/ArtPrompts-2026-10-07.md`. Keep the founder's direction: ages 2–6, a warm tactile toybox, all nine launch toys, including Meadow and Hum. The artwork is a candidate for integration; it does not establish learning outcomes or award readiness.

**Artwork complete:** all 27 mandatory PNG masters and their 27 prompt records are saved. Integration, app testing and a new TestFlight build remain to do.

## Source and release state

- Repository: `https://github.com/interventionbluecamo-afk/lull.git`.
- `origin/main` at `c919d04` is the TestFlight 1.0 (1) source.
- Your latest remote branch `claude/modest-bell-cjarqm` is at `1f109f4`: four commits above main, changing 42 files. This includes the two gameplay commits plus the art/handoff documents and PDF. The older handoff's “two commits” describes the gameplay work, not the current complete branch.
- The art branch is `codex/lull-art-pass-02`, based on `1f109f4`.
- Delivery branch: `origin/codex/lull-art-pass-02`. This handoff travels in the same art-and-docs commit as every supplied PNG. No source integration or new TestFlight build has happened in this art pass.
- Artwork: [ArtDrops/2026-10-07](../ArtDrops/2026-10-07/). Each master has a matching `.prompt.json` recording its actual prompt and reference image. The complete delivery inventory is [manifest.json](../ArtDrops/2026-10-07/manifest.json).

The latest GitHub changes were checked before generating these assets. Earlier checkouts were not replaced. Paths in this handoff are relative to the repository so Claude can use the delivery from its cloud environment.

## Get the delivery in Claude's cloud workspace

Fetch `origin/codex/lull-art-pass-02` and inspect its art commit. Bring it into your current working branch by merging that branch, or cherry-pick the single art-only tip commit. That commit should contain the new ArtDrops files and handoff documents, without gameplay source changes. Choose one route and preserve any newer Claude changes; do not reset or replace your current branch to match this older base.

```sh
git fetch origin codex/lull-art-pass-02
git show --stat origin/codex/lull-art-pass-02
# On your current working branch, choose one:
git merge origin/codex/lull-art-pass-02
# Or, for only the art-and-docs commit:
git cherry-pick origin/codex/lull-art-pass-02
```

Read this document and the manifest after bringing the delivery into your branch. The source integration still needs to happen in Claude's workspace. If your cloud environment lacks Xcode, report that limit and leave the iOS compile and device play checks for a Mac; syntax parsing and offline mocks cannot substitute for them.

## Asset inventory

| Family | Filenames | State |
| --- | --- | --- |
| Icon | `icon-bg.png`, `icon-stone.png` | Generated; layers only |
| Meadow rock | `meadow-rock.png`, `meadow-rock-awake.png` | Generated |
| Meadow mushroom | `meadow-mushroom.png`, `meadow-mushroom-awake.png` | Generated |
| Meadow pebbles | `meadow-pebbles.png`, `meadow-pebbles-awake.png` | Generated |
| Meadow dandelion | `meadow-dandelion.png` | Generated |
| Feed grandmother | `feed-cast-grandmother-1.png` through `-6.png` | All six generated |
| Feed sprout | `feed-cast-sprout-1.png` through `-6.png` | All six generated |
| Feed knit hat | `feed-cast-knithat-1.png` through `-6.png` | All six generated |

Total delivered artwork: 27 masters. The optional awake icon stone was not requested as part of this delivery.

Feed expression numbering matches your prompt: **1 neutral, 2 happy, 3 laughing, 4 sleepy/yawning, 5 surprised, 6 chewing**. Each expression variant references its own character's neutral master.

## What changed from the art prompts

Cutouts have **real transparent alpha**, instead of a teal key background. `icon-bg` is opaque and fills its square. Do not key these masters or blindly run `Tools/Art/despill.py` over them; the tool was written for the earlier teal-backed artwork. Preserve legitimate blue, lavender and green materials.

Keep the original PNGs unchanged in ArtDrops. Make separately named runtime exports if resizing or trimming is necessary. Apply one shared crop, scale and canvas to each Meadow pair, and one shared normalization to all six expressions of a Feed character. Independent trimming would introduce movement during texture changes. Very faint nonzero-alpha fringe can expand an automated bounding box; use a meaningful alpha threshold and retain soft edge padding.

The square icon/Meadow masters are 1254 × 1254. All 18 Feed masters are 1086 × 1448, a 3:4 portrait with one waist-up figure per image; their PNG dimensions were checked. Matching canvas dimensions do not guarantee identical silhouettes, so check the expression changes in the actual app.

## Integration details

### Meadow

Import the asleep and awake art together, then set `MeadowLandmark.Kind.isTopDown` to `true` for rock, mushroom and pebbles in `App/Toys/Meadow/MeadowScene.swift`. Stump and pond already use top-down art.

`ToyArt.sprite` fits the entire texture canvas, including transparent margins. Current fit boxes are rock 116 × 98, mushroom 96 × 90 and pebbles 106 × 80 points. With these new square masters, a blind replacement makes the visible bodies about 84 × 81, 80 × 78 and 65 × 54 points respectively. Revisit fit or prepare consistently padded exports, especially for the pebble family.

Wake art is an overlay on the sleeping sprite, so both frames must occupy the same space. Read-only alpha-mask analysis found close alignment: rock 99.38%, mushroom 99.60%, pebbles 99.30% silhouette overlap at alpha >128. This is evidence of similar framing, not identical texture pixels or a passed gameplay test.

The dandelion is now an overhead round puff with no visible stem. The current 76 × 96 fit was intended for tall art; check a square presentation, touch reach, blow/frost transition and reset. Check contact shadows in scene: the current code assumes authored landmarks carry their own shadow and adds a procedural shadow only for fallback art.

See [ART-QA-MEADOW.md](../ArtDrops/2026-10-07/ART-QA-MEADOW.md), [meadow-qa.json](../ArtDrops/2026-10-07/meadow-qa.json), [ART-QA-FEED-BASES.md](../ArtDrops/2026-10-07/ART-QA-FEED-BASES.md) and [feed-base-qa.json](../ArtDrops/2026-10-07/feed-base-qa.json) for measurements and visual findings. Mushroom red is comparatively bright and the puff more naturalistic; these are design judgments to assess in the actual scene before spending another generation.

### Feed

The new waist-up figures require calibration, not only asset replacement. In `App/Toys/FeedThePeople/CharacterNode.swift`, current art math assumes head width is 78% of the image, head center is 28% from the top, and sprite anchor is (0.5, 0.72). Mouth centers are currently 50% from top for grandmother, 44% for sprout and 46% for knit hat. Measure against the new masters and update these assumptions as needed.

The counter currently hides the bottom 30% of a figure; `standHeight(hidingBottom:)` and `paintedHeadroom` stage it behind the counter. Preserve the head, glasses, hat and thought bubble on short landscape phones. Align the actual mouth target with the painted mouth and keep the food reachable.

**Expression registration needs review.** Generated edits also re-render some clothing and body pixels. Silhouette overlap against neutral is 92.66–97.32% for grandmother, 89.91–94.79% for sprout, and 97.02–98.91% for knit hat; maximum alpha-center shift is about 30.5 master pixels. Sprout grows slightly in several frames. Grandmother frames 2, 4 and 6 reach the bottom canvas edge and cut the lower body; that area is intended to remain hidden behind the counter. They are usable candidates for this staged scene, not complete standalone cutouts or proven jump-free transitions. Verify the visible head and shoulder registration in the app and correct runtime alignment or use face-only expression overlays if necessary. See [ART-QA-FEED-EXPRESSIONS.md](../ArtDrops/2026-10-07/ART-QA-FEED-EXPRESSIONS.md) and [feed-expression-qa.json](../ArtDrops/2026-10-07/feed-expression-qa.json).

**Expression 6 is new and not wired.** The current eating mood still uses expression 3 (laughing), briefly preceded by expression 5. Implement a deliberate chew beat with 6 while keeping 3 available for laughter. The puffed-cheek change in the generated chewing frames is subtle; assess whether it reads at gameplay size before requesting another generation. Verify timing, face continuity, food disappearance and satisfaction feedback together. High-resolution files alone do not fix the open “wrong food receives the same happy bite” interaction issue.

### Icon

The two files are separate candidate layers: a dusk felt background and the sleeping terracotta stone with a plain belly. The moon belongs in the sky. They are **not an Icon Composer document or an exported production app icon**. Compose and check the result at small real icon sizes and supported appearances before replacing the current asset. Layered icon support is a platform capability; no claim is made about what an award jury requires.

## Verification and next work

This pass generated and inspected artwork and performed read-only image analysis. It has not wired these images, compiled the resulting app, or played a build using them. Your preceding Swift pass was syntax-checked on Linux; that is not an iOS compile. The currently available TestFlight build remains 1.0 (1).

Recommended continuation:

1. Open `WarmShelfToybox/Lull.xcodeproj` from the correct branch and compile against iOS. Resolve actual compiler failures before judging the art in mocks.
2. Integrate the masters as derived runtime assets with the calibrations above, then run on iPhone and iPad in portrait and landscape.
3. Play **Feed**: reach every food and mouth, return misses to plates, keep friends behind the counter, keep bubbles visible, cycle all expressions, and check the chew beat and calm response to unwanted food.
4. Play **Meadow**: read faces at gameplay size, wake/sleep without jumps, check rotation and day/night contrast, paint to the world edges, maintain smooth performance, and complete the dandelion reset.
5. Recheck your preceding changes: **Drop Dots** floor/channel seating, four-dot stack, ring/rail occlusion and palm-safe handle release; **Sleepy Box** posting for every shape without clipping outside the hole.
6. Smoke-play all nine launch toys: Bubbles, Feed, Stack, Sleepy Box, Window, Drop Dots, Mix-Up, Hum and Meadow. Keep sound, touch, rotation, saved state and Reduce Motion checks in scope.
7. Record what actually passed and what remains open before preparing the next TestFlight build.

The founder asked us to monitor usage and leave enough capacity for a useful handoff. Prioritize integration and real play checks over speculative regeneration; leave the next person exact source/release state, known failures and remaining work. New design ideas should support exploration, repetition, independence and self-correction; educational claims still need evidence and educator review.
