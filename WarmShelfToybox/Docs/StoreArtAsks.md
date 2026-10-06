# App Store Art — generation prompts (marketing layer only)

*The principle, first, because it's a rejection risk and a trust risk both:*

**The gameplay in every screenshot is a REAL capture from the running app** — never
generated, never a mockup of UI that doesn't exist. Apple requires screenshots to show
the actual app, and "the honesty is the pitch" is the whole brand. Imagegen produces
only the **marketing layer**: the key-art opener, the warm backdrop each real capture
sits on, and small decorative garnishes. I composite the real captures + the Georgia
captions on top.

**These prompts are NOT the in-app house style.** No flat #3E6877 teal here — these are
finished full-bleed warm compositions. Letterforms are never generated (captions are
composited in real Georgia type, same as the shelf nameplate).

**Sizes** (generate generously, I crop/pad to exact):
- iPhone 6.9" — 1290 × 2796 (portrait, ~9:19.5). The required set.
- iPad 13" — 2064 × 2752 (portrait). Optional but recommended.
- Generate each backdrop as a **tall vertical portrait**; I extend/crop to spec.

**The palette to name in prompts** (the app's real one): linen #F2E8C6, paper #FAF0D8,
cream #ECDFAF, terracotta #D4583A, sage #6A8B66, butter #E8C045, water-blue #85C5CF,
lavender #A08BBB, petal #EA8E82, cocoa ink #5C3320.

---

## The gallery plan (7 panels) — so each prompt has its job

Premium kids-app pattern: a stylized **title opener**, then real captures on a calm
shared backdrop, each with one short Georgia headline in the top band, the captured
toy below. Proposed order + caption (caption copy is yours to bless):

1. **Title / hero** — key art, "Calm toys, made for little hands." *(generated, below)*
2. **Stack** capture — "Build a tower that wakes up."
3. **Window** capture (dusk) — "Turn the day toward night."
4. **Meadow** capture — "Lead the snail. Spring follows."
5. **Feed** capture — "Care for a hungry little friend."
6. **Bubbles/Hum** capture — "Pop, hum, and play — no rules."
7. **Trust panel** — "No ads. No subscription. $9.99 once." *(backdrop + type only)*

Panels 2–6 use **STORE-BACKDROP-DAY**; panel 3 may use **STORE-BACKDROP-NIGHT**.
Panel 7 uses the night backdrop with the trust marks composited.

---

## A. Hero / title key art — `store-hero` (the opener + press + TikTok)

*This is illustration, clearly the title card — not a fake screenshot. The money shot.*

> A warm, premium children's-app title illustration in soft 3D clay-and-felt
> stop-motion style: a cozy little wooden toy shelf in a sunlit nursery, seen
> straight on. On the shelf sit a few rounded handmade clay toys — a small terracotta
> stacking tower with a sleepy face, a cluster of pearly soap bubbles, a tiny green
> felt garden — and at the right end a plump terracotta clay creature with closed
> sleepy eyes, rosy cheeks, and a little butter-yellow stone balanced on its head,
> dozing. Warm linen (#F2E8C6) and cream walls, honey-wood shelf, butter lamplight,
> a gentle vignette, hand-felted wool textures, soft key light from the upper left.
> Generous calm empty space in the UPPER THIRD for a title to be added later (leave
> it uncluttered). Muted warm Montessori palette, no neon, no text anywhere. Tall
> vertical portrait composition.

## B. Shared screenshot backdrop, day — `store-backdrop-day`

*Reused behind panels 2, 4, 5, 6. Blank, calm, with room for a caption and a capture.*

> A soft, empty warm-paper backdrop for a children's-app screenshot: a gentle
> top-to-bottom wash from pale paper-cream (#FAF0D8) at the top to warm linen
> (#F2E8C6) lower down, with a very faint hand-pressed paper grain and a soft pool of
> warm light in the centre. Completely empty — no objects, no characters, no text,
> no UI. A calm clear band across the TOP THIRD for a headline, and an open lower area
> where a toy will be placed. Subtle, premium, uncluttered. Tall vertical portrait.

## C. Shared screenshot backdrop, night — `store-backdrop-night`

*Behind the Window/dusk panel (3) and the trust panel (7) — the wind-down mood.*

> A soft, empty warm backdrop for a children's-app screenshot at bedtime: a gentle
> wash from dusky lavender-grey (#A08BBB low-saturation) at the top down to deep warm
> cocoa-brown (#5C3320), a faint scatter of tiny soft stars near the top, one warm
> butter-gold lamp glow low and off-centre. Completely empty — no objects, no
> characters, no text, no UI. A calm clear band across the TOP THIRD for a headline.
> Tender, hushed, premium. Tall vertical portrait.

## D. Garnish — `store-wren-peek` (teal-keyed cutout, optional corner dressing)

*The one place the in-app house rule applies — keyed transparent so I can tuck it into
a screenshot corner. Use sparingly; never over a captured toy.*

> Soft 3D clay-and-felt stop-motion style, soft key light from upper left, muted warm
> Montessori palette, no text. Background: one perfectly flat solid teal (#3E6877),
> no shadow, no gradient. A plump terracotta clay creature with closed sleepy eyes,
> rosy felt cheeks, and a small butter-yellow stone balanced on its head, peeking in
> from one edge as if leaning into frame — only the head and one little paw visible,
> curious and gentle. Square format.

## E. App Preview poster frame — `store-preview-poster`

*The still shown before the 15-second preview plays. Brand.md's "marketing in one
beat": the sleepy stone waking. Illustration, not a capture (the video itself is real
gameplay).*

> Soft 3D clay-and-felt stop-motion children's-app illustration: a close, tender
> moment of a small child's fingertip gently lifting a sleepy terracotta clay stone
> off a little tower — the stone's eyes are just blinking open, a tiny warm glow and
> one soft sparkle around it, rosy cheeks, a butter-yellow capstone above. Warm linen
> background, honey-wood, butter light, soft key light from upper left, shallow cozy
> focus. Wonder and calm, no text anywhere. Tall vertical portrait.

---

## What I do with these
1. You generate A–E (drop in `Assets/Staging/Drops/<date>-store/`).
2. I capture the real toy scenes on device/sim at exact screenshot resolution
   (`LULL_DEBUG_*` levers stage them cleanly).
3. I composite: backdrop → real capture → Georgia caption (real type, your blessed
   copy) → optional keyed garnish. Export the 6.9" set (and 13" iPad set).
4. App Preview video is captured gameplay; `store-preview-poster` is its poster.

## NOT generated (decided)
- Any screenshot's actual toy/UI — always a real capture.
- Caption letterforms — composited in Georgia.
- The app icon — already final (the capstone clay friend).
