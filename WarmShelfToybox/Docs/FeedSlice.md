# Feed — Slice Plan (Phase 2 of NorthStar)

*Concept: `~/Desktop/concepts/feed.png` — a wooden farm-stand. Four little customers lean
over the counter under bunting and a hanging lamp, each with a picture-bubble want
(apple, carrot, banana, egg-with-a-face). The child is the shopkeeper.*

## Verdict on the prototype (read 2026-06-10)

`FeedScene` already carries most of the concept's soul:

- Per-character `desiredFood` / `dislikedFood` and `hungerBites` ✓ (the want system exists)
- Visitor rotation (`feedsSinceVisitorChange`) ✓ (new friends wander up)
- Caring loop with no score ✓

## Deltas (the re-staging)

1. **Table → farm stand.** Characters move behind a wooden counter (upper half of the
   scene, leaning over it like the concept); food lives on pedestal plates along the
   counter's front edge (lower half). The drag verb is unchanged.
2. **Wants become visible.** A character's `desiredFood` shows as a soft picture-bubble
   (felt cloud, food icon) above their head. Serve the match → beaming, chewing, a little
   wave, bubble pops into petals. Serve anything else → it's still received kindly
   (a giggle, a polite nibble or a gentle head-shake per personality), bubble stays.
   Control of error is the picture match; no error is ever announced.
3. **Replenish from the basket.** Foods slide in from a woven basket at the side when a
   pedestal empties — the stand restocks itself, the child never runs out.
4. **The egg has a face** (concept). Food can be alive too; the egg blinks rarely. Once
   per long while a character *asks for the egg* and the egg looks delighted. No lore,
   just one wink of charm.
5. Characters stay procedural in this pass (they're already expressive); authored
   character art is its own later batch (pose/expression sheets, see shopping list).

## Art slots (sizes @3x px)

*All eleven delivered 2026-06-10 and landed in `Assets.xcassets`. **Staged same day**:
stand plate, counter front, restock basket and the four art foods are live; the
want-bubble already existed in code and now shows the felt food icons. Note: the egg
arrived as a halved boiled egg with yolk — kept deliberately, it's truer to a toddler's
plate; the face beat goes on the white above the yolk. Open: bread/berry/cookie/cup
spawn procedural until their art lands (prompts queued in `ArtShoppingList.md` 4e);
pedestal display + egg-face beat are the next Feed polish pass.*

| Slot | Size | What it is |
| --- | --- | --- |
| `feed-stand-back` | 1290×2796 | Full backdrop: stand interior wood frame, side shelves, green trees + sky through the opening, bunting flags, hanging lamp (off-state baked, warm). No characters. |
| `feed-counter` | 1400×500 | The wooden counter front with grain and edge wear — the food shelf. |
| `feed-basket` | 600×500 | Woven restock basket, tilted, a hint of produce inside. |
| `feed-pedestal` | 380×220 | One little wooden pedestal plate (reused ×4). |
| `feed-apple` | 380×380 | Chunky matte red apple, leaf. |
| `feed-carrot` | 380×420 | Plump carrot with soft greens. |
| `feed-banana` | 420×380 | Friendly thick banana. |
| `feed-egg` | 360×400 | Cream egg, face-less (procedural face overlays for blink/smile). |
| `feed-bubble` | 420×360 | Empty felt want-bubble cloud (food icon composited in code from the food sprites at small scale). |
| `feed-chalkboard` | 420×520 | Side chalkboard with food doodles (no readable text). |
| `feed-plant` | 500×600 | Potted plant for the counter end. |

## Audio drop-ins

| File | What |
| --- | --- |
| `feed-bubble-pop.mp3` | The want-bubble resolving into petals — soft, papery. |
| `feed-restock.mp3` | Basket slide + wooden set-down. |
| (existing) | `feed-chew-soft-1` / `feed-chew-crunch-1` already shipped. |

## Definition of done

`Docs/WindowSlice.md` bar, plus: a 2-year-old reads the want-bubble without any adult
explaining — the bubble, the match, the joy must speak entirely in pictures.
