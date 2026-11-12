# Lull — product, design and update review before the next release

November 12, 2026. Founder-requested handoff to Claude. Repository: `interventionbluecamo-afk/lull`, branch `claude/modest-bell-cjarqm`. Starting revision: `fcee735` (beach implementation `daeb2bd`).

## Your assignment

Act as Lull's senior product and creative partner, applying the judgment associated with Apple editorial and premium iOS games, Duolingo, Candy Crush, Pixar, Crossy Road, Wordle and Pok Pok. These are lenses for your reasoning, not employment or credential claims. Combine interaction clarity, coherent personality, material craft, satisfying repetition, restraint and family trust. Use a Montessori-informed perspective on independence, exploration, repetition and self-correction; distinguish design judgment from evidence of learning benefits.

Give an honest high-level design review **and a readiness review of the current update** before we ship more changes. Understand the existing product; do not start over or deliver a generic audit. Challenge decisions, including ChatGPT's recent work. Preserve what already delights the founder's son. Recommend a bounded finishing pass, not an endless redesign or a wish list of new toys.

**First return your assessment and proposed changes. Do not start a sweeping implementation, generate a batch of replacement art, upload another TestFlight build, or alter App Review in this review task.** The founder wants the review before the next release push. Saving/pushing review documents for the shared cloud workflow is welcome.

## First priority: the beach breaks the path

New founder report: **“the path isn't working on the beach, which is sad.”** This is physical-use feedback, not resolved by previous passing checks. The exact installed build and whether “path” means the visible trail, movement, or both have not been reconfirmed.

Build 21 deliberately restricted flowers and spring paint to grass and placed the beach layer above earlier paint. This is a leading explanation for the disappearing visible path, not a reproduced diagnosis of every movement symptom. Inspect the complete interaction, including where the mother stops, whether a touch on a shell consumes a movement gesture, how followers behave, and what happens when crossing the boundary or rotating.

Source evidence at `fcee735` (line numbers may move):

- `MeadowScene.swift:2122`: `MeadowFlowerTrail.stamp` rejects non-grass blooms; restore also filters them.
- `MeadowScene.swift:1100`: `paintSpringStamp` returns immediately off grass.
- `MeadowScene.swift:135`: trail layer z=4, beach z=5; opaque beach fills can hide the light wake even while it is generated.
- `MeadowBeach.swift:18`: walking is clamped at −0.415 × world height, inland of the curved shoreline around −0.445 × height. Investigate the perceived stopping distance separately from trail visibility.
- `MeadowLittleOnes.swift:573`: followers use independent movement history and the land clamp; missing flowers alone does not establish a follower-path bug.

Product direction to assess: **the same drag should keep producing a legible, satisfying response across terrain**. A restrained trail of temporary impressions or tiny tracks in sand could continue the grass's flower trail without making flowers grow underwater. Match the overhead camera, local light and surface texture. Do not add instructions, a new tool or a reward system. The precise sand response is your design recommendation to make, not a mandated effect.

Acceptance for the eventual fix: a child can cross grass → sand → grass without losing control or feedback; the route is readable in day/night; mother and followers stay on land; shells remain optional; rotation and recurring baby returns preserve continuity; effects are bounded and respect Reduced Motion. Add only focused checks that catch the actual behavior. Do not preserve a test asserting “no flowers on sand” as proof that the whole experience is correct.

## What Lull needs to feel like

Nine calm toys for ages 2–6, with purchases/settings for grown-ups. The founder's son particularly loves Meadow and Little Wash. Lull's distinctive handmade art matters, but the founder has repeatedly noticed objects that look pasted in, overly generated, or inert.

The agreed design language:

- Simple handmade forms: chunky silhouettes, soft edges, restrained stitching/grain. Texture supports shape.
- A believable little space: one camera, light, scale and contact-shadow logic **within each toy**. Meadow is overhead; other toys need their own internally consistent camera, not forced overhead conversion.
- Material-specific movement: felt compresses, fabric bends, wood has weight, water spreads. Attached parts stay attached.
- Quick to notice, slow to settle. Direct manipulation answers immediately; the object then returns gently to rest.
- Discoveries caused by the child, with quiet space between them. Delight must have a readable cause. Scenery need not all animate.

Do not solve mismatched perspective with a grain overlay, or static composition with constant bobbing. Generate separate usable parts only where needed, with camera, light, contact plane, anchor and intended movement specified. Preserve strong existing assets. Avoid casino-style rewards, streak pressure, artificial scarcity and retention tricks aimed at children. Borrow clarity and satisfying loops from commercial games, not compulsion.

## Review scope — assess the product together

1. **Gameplay and delight:** can a non-reader understand what responds, repeat an action with interest, and stop naturally? Does the response follow the finger? Is each new animation noticeable and meaningful at normal phone size? Does Meadow remain interesting after returning all babies? Does the coast belong to that loop?
2. **Artwork and space:** perspective, material consistency, day/night treatment, grounded objects, composition, layering, useful negative space and shelf-to-game resemblance. Inspect actual available captures; mark code-only or unobserved judgments explicitly.
3. **Phone/iPad experience:** portrait and landscape target sizes, safe areas, rotation continuity, motion/sound settings, VoiceOver and the grown-up gate. Focus on changed or evidenced weak areas; do not replay every historic checklist.
4. **Brand and parent experience:** is the reason to choose Lull immediately clear? Evaluate welcome → setup → offer → shelf and grown-up settings as one journey. Calm play, parent-set rest/timer, no ads and privacy should be concrete and understandable, with no unsubstantiated educational or behavioral promises.
5. **Business and update readiness:** does the quality and replay value justify the annual/Keep Forever offer? Is the offer understandable and honest? Identify actual release blockers versus worthwhile later polish. Do not change prices, paywalls, trial promises, store copy or legal/privacy claims during this review.

Cover all nine current toys, briefly and specifically: Meadow, Little Wash, Sleepy Box, Mix-Up, Feed, Window, Drop Dots, Hum and Bubbles. Older files mentioning Stack describe history, not the current lineup. Watchpoints from the update are Meadow's path/world continuity, Wash's room/tool/brush integration, Sleepy Box's large pieces and socket perspective, Mix-Up's joints/saved creations, Drop Dots' landscape size, and whether Feed/Window/Hum/Bubbles' new reactions improve play rather than just decorate it. Treat these as review questions, not claims that every area is still broken.

## Read these first; reuse existing evidence

Paths below are relative to `WarmShelfToybox/`:

- `Docs/HANDOFF-CURRENT.md`: latest entry governs; older entries are history.
- `Docs/Brand.md` and `Docs/AlivenessPrinciples.md`: current production sections take precedence over old Stack examples.
- `Docs/Art/Meadow-Beach-2026-11-04/Handoff.md`, `README.md`, `Prompts.json`: build 21 scope, originals/provenance and preview limitations.
- `Docs/Art/Materials-Motion-2026-11-03/Handoff.md` and `Previews/README.md`: nine-toy update and available integrated captures.
- `Docs/Update-2026-11-03/Handoff.md`: larger Sleepy Box, Wash orientation/two-tool change, Guided Access.
- `Docs/Update-2026-11-04/Handoff.md`: Drop Dots landscape fix and unresolved crash evidence.
- `Docs/AssetManifest.md` and `Docs/Art/Inventory.json`: organized asset map. Reuse strong artwork before proposing generation.
- Primary beach code: `App/Toys/Meadow/MeadowScene.swift`, `MeadowLittleOnes.swift`, `MeadowBeach.swift`. Parent journey: `App/Shared/LullOnboardingViewController.swift`, `LullPlansViewController.swift`, `ParentInfoViewController.swift`, `ToyShelfScene.swift`.

Build 21's beach previews are isolated native macOS node renders, **not full iOS playthroughs**. Builds and model assertions passed, but they did not establish satisfying touch behavior. Do not claim you played on a phone if your environment cannot do so. Use available evidence, state what needs a short founder capture/check, and keep working on the review without inventing results. No large research run or duplicate broad QA pass is needed.

## Release facts and limits

- 1.1 (21) uploaded successfully on November 4 at 2:53 PM Central. That upload receipt is verified; current Apple processing, availability and App Review state were **not rechecked November 12**.
- Builds 18–21 include the orientation/sizing changes, nine-toy materials/motion pass, recurring Meadow babies, landscape Drop Dots fix, and beach.
- The founder supplied a build 19 SpriteKit `add_subdivs` crash. Build 20 disables extra subdivision for authored warps in Feed, Window, Mix-Up and Wash. This is a mitigation, **not a reproduced or conclusively fixed crash**. Carry that uncertainty into your readiness verdict.
- Do not withdraw, replace or otherwise change the previously submitted 1.0 review. No new TestFlight/store action is part of this handoff. Reconfirm live release state only when a release action is requested.
- Founder owns physical testing and wants token discipline. No unsolicited tester-group audits or TestFlight notes.

## Deliver exactly this

1. A candid overall assessment: strongest qualities, what holds the update back, and the most important missed opportunity. Separate **verified observation**, **founder report**, **inference**, and **design judgment**.
2. **The five highest-impact changes**, ranked. For each: the concrete problem/example, proposed behavior or visual correction, why it matters, and a bounded implementation scope. Put the beach-path issue first unless evidence establishes a more serious release blocker.
3. A brief keep / refine / defer verdict for each of the nine toys. Do not invent nine fixes to fill the table.
4. A one-to-two-minute action list grouped into a few useful categories. Each item states **Finding / Action / Priority (High, Medium, Low)**; consolidate overlaps and put release blockers first.
5. A clear **ready / ready after named fixes / hold** verdict for the update, with evidence and only the essential remaining device checks. Separate required fixes from optional polish and give a finite stopping point.

Save the review and proposed finishing plan in `Docs/Review-2026-11-12.md`, update the top of `Docs/HANDOFF-CURRENT.md`, and push those documents so ChatGPT on the Mac can pick up the agreed work. End with a short founder-facing recommendation. No guaranteed awards, invented credentials, flattery, or automatic implementation of every suggestion.
