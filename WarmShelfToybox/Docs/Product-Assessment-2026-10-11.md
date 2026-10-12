# Lull: product assessment and focused roadmap

October 11, 2026. Source baseline: `1739417`, build 12, branch `claude/modest-bell-cjarqm`.

## October 12 implementation update

The confirmed reminder/cancellation copy problems identified below have been corrected in build 13 source, including matching website/store copy. Build 13 supersedes unuploaded build 12. Both products now have Family Sharing, the free-week intro offer is configured, and the paid agreement is Active. The assessment below remains a dated view of baseline `1739417`; broader recommendations are not automatically implemented. Final build/upload results belong in the build-13 handoff.

## Evidence and limits

This assessment uses the build 11 and 12 handoffs, current toy and purchase source, the current Feed background asset, the founder's repeated device feedback, and the existing brand/expression documents. It is not a new hands-on play-test. Source presence does not establish that an interaction feels good on a phone. Build 11 testing remains the founder's responsibility; build 12 has not been uploaded by this pass. Recommendations below are product judgments unless labelled otherwise.

External references are limited to Apple's published design-award criteria and review guidance, and the original RevenueCat report cited by the preceding handoff. I have no inside knowledge of Apple's jury or editorial decisions.

## Honest assessment

Lull has a credible premium foundation: tactile objects, recognizable physical actions, a quiet emotional tone, nine different ways to play, and a parent-controlled stopping ritual. The founder has repeatedly singled out Feed and Sleepy Box as enjoyable. The decision to replace Stack with Little Wash gives the collection a particularly understandable cause-and-effect activity. Meadow's little parade gives it an emotional beginning, middle and homecoming.

I would not yet describe the whole product as exceptional. We have repeated evidence of gaps between an attractive asset and a convincing toy: floating vehicles, socket perspective, stage seams, shelf-to-scene mismatches and objects that feel static. Build 11 contains targeted fixes for several of these; they must not be labelled still broken without new device evidence. The recurring pattern nevertheless matters: our production process has been generating and repairing attractive parts faster than it has been enforcing one coherent world.

The larger opportunity is a recognizable relationship between the child's action and the world's answer. A sleepy box waking when touched, a visitor noticing an offered pear, and a freshly washed vehicle giving a small satisfied wobble are more memorable than an inventory of nine activities. My proposed product promise is **“A little world that notices your child.”** That is a creative direction, not a developmental or therapeutic claim.

Our business is also unproven. There is no Lull-specific evidence here establishing willingness to pay, repeat use across families, or superior conversion from the new hard paywall. We should preserve the current pricing long enough to learn something useful instead of repeatedly rewriting the offer around borrowed benchmarks.

## The five highest-impact changes

### 1. Make the first minute demonstrate value, then make the purchase promise exact

**Verified:** build 12 asks for the adult check, family settings and the offer before any toy is playable. All nine launch toys require an entitlement. Declining the offer opens a second reassurance sheet; declining that leads to the resting shelf. The real annual bill is prominent; prices and trial eligibility are obtained from StoreKit. Those are useful foundations.

**Judgment:** an unknown brand is asking for commitment before proving its tactile quality. A strip of moving toy images can establish charm, but does not communicate the feeling of playing. Keep the agreed paid model for this release, but replace generic benefit volume with a very short, accurate demonstration made from actual gameplay: scrub a muddy truck, offer food to a friend, fit a shape and open the drawer. A parent should see the child's role immediately. This can serve the welcome and App Store preview without adding another game or permanently free tier. Do not autoplay sound. If conversion later underperforms, a parent-controlled playable sample is a hypothesis to test, not an assumed requirement now.

Let “Not now” leave the offer directly. Put questions about the trial behind an optional “How the free week works” control. The current reassuring language is kind, but the second sales surface adds friction to a clear refusal.

**Confirmed copy problems:** the timeline and hesitation sheet promise a reminder without the qualification shown elsewhere; notification denial does not clearly state that no reminder is set. “Cancel during the free week and you pay nothing” omits the 24-hour condition stated in other copy. Fix both consistently, including the website. Use the actual trial transaction dates after purchase. Display “Reminder scheduled” only when scheduling succeeds, and “No reminder is set” otherwise. Both products now have Family Sharing enabled in App Store Connect. The two-plan claim should still describe each product's verified support; the shared OR condition is a latent overpromise if loaded product configuration differs, rather than a currently confirmed configuration mismatch.

Why first: trust, first-session conversion and approval readiness meet on this screen. Better decoration cannot compensate for an ambiguous billing promise.

### 2. Give Lull a recognizable cast and movement language

**Verified:** the repository already has Wren, expression principles, authored friends and extensive motion. The expression document describes touch, carrying and settling responses, but its canonical example is the retired Stack toy. Brand.md still describes Stack in the icon/marketing story and still promises three free toys. These documents no longer reliably direct the current product.

**Judgment:** felt and wood are an appealing material choice; they do not, by themselves, create a memorable brand. Make the actual Lull characters identifiable by silhouette and behavior. Wren can be the quiet host; Feed visitors and the existing sleepy faces can carry the emotional identity. No new lore screen or voiced tutorial is required.

For the next art task, define a small shared set of rules: camera angle, floor/contact line, light direction, material detail at phone size, shadow softness and facial proportions. Use the same live parts in the shelf and the toy wherever practical. Animate the thing the child affects: a face, wheel, mouth, curtain or sponge. Whole-image bobbing is insufficient when the expected response is local. Pause and stillness should remain possible; not every object needs constant breathing or a face.

Keep the current Feed backdrop for now. Its open center is useful. Its warm wood and side pantry details should remain subordinate to faces and food; adjust contrast or framing only if the founder's device view still distracts. Another background regeneration is not the highest-return intervention.

Why second: this addresses the recurring “static images” concern and gives marketing something unmistakably Lull to show.

### 3. Make replay come from different possibilities, not a larger asset count

**Verified:** Feed now draws from a ten-item illustrated food list, presents four choices, rotates eaten plates under defined conditions, and uses a shuffled cast bag. Drop Dots now has twelve pieces, discovery patterns and changing color sets. Meadow has five hidden babies and a homecoming. Earlier requests for variety were partly implemented; we should not pretend those changes are absent.

**Judgment:** new food pictures and new colors can freshen a visit without changing what the child can do. The next increment should improve the consequences of choices. For Feed, prioritize distinct existing character reactions and a clear, satisfying end to each visit. Do not add more visitors until their differences are visible in motion. For Drop Dots, emphasize arranging, pouring, retrieving and seeing patterns; do not turn every arrangement into a correctness test. Preserve mixed-color experimentation alongside sorting.

Keep all nine, with deliberate roles:

| Toy | Role in the collection | Focus |
| --- | --- | --- |
| Feed | Care and character connection | Make current cast/food variety felt through reactions and a clear visit ending. |
| Little Wash | Visible transformation | Make dirty-to-clean progress readable under the hand and the departure satisfying. |
| Sleepy Box | Physical fit and self-correction | Protect its simplicity; accept the perspective fix only after founder confirmation. |
| Meadow | Exploration and homecoming | Make the first baby and the way home discoverable without instructions. |
| Mix-Up | Authorship and playful combinations | Make a saved creation feel like the child's own little friend; retain free mixing. |
| Hum | Musical agency | Clearly different expressions and response across keys, with a balanced sound range. |
| Window | Gentle discovery and a natural ending | Preserve the day/night transformation and the pleasure of closing the curtains. |
| Bubbles | Immediate, low-demand sensory play | Keep touch/swipe response and sound comfortable; it need not become a progression game. |
| Drop Dots | Arrangement, gravity and repeatable patterns | Make the tactile loop satisfying without depending on new palettes or rare gold dots. |

Montessori-informed value is strongest where a child chooses an action, sees its consequence and can repeat or correct it independently. Care play and sensory exploration are valid aims, but this does not establish a Montessori curriculum or learning outcome. An educator should review any stronger educational claim.

### 4. Turn “calm” into an end-to-end interaction standard

**Verified:** there are sound/haptic/motion controls, a per-sitting play timer, wind-down settings and a moon rest. Previous founder feedback repeatedly identified harsh sounds and confusing or physically implausible interactions. Those reports are historical; recent changes require the founder's ears and hands to judge.

**Judgment:** a calm app must respond promptly, make touch targets readable, avoid overlapping audio and let children finish. Lowering every sound equally is not enough if one pop has a sharp attack or several feedback cues combine. Treat the nine toys as one sound set with comparable perceived intensity. Use the existing controls rather than adding a large settings system.

Keep the stopping point emotionally complete: the visitor has eaten, the car has left clean, the babies are home, or the curtain closes. Where the timer interrupts, preserve state so a return is intelligible. Do not infer that dimming an app improves sleep. A parent-chosen rest is a controllable product behavior, not a clinical benefit.

The age range also needs evidence. Brand.md says 2–4 in places, launch guidance calls the core 2–5, and the store copy says 2–6. My hypothesis is that the simple physical toys fit the younger end best, while six-year-olds need more expressive freedom. Choose one external promise after a small founder-led observation across younger and older children. Avoid a new age-selection screen unless those observations establish a need.

### 5. Make the commercial promise small enough to keep

**Verified:** the model is $29.99 annually with an eligible seven-day trial, or $59.99 once. The annual description promises new toys each season; lifetime includes future toys. The current code also has grace-period support, whose store setting still matters.

**Judgment:** keep the prices stable for the initial cohort. The key unknown is whether families value the whole experience enough to return and pay. Track aggregate store outcomes—downloads, trials, paid conversions, cancellations/refunds and proceeds—alongside voluntary parent feedback. Do not add child-level tracking to answer this.

RevenueCat's 2025 report does contain the roughly 12% versus 2% hard-paywall/freemium medians cited in the handoff. They compare groups of apps, not randomized versions of Lull, so they do not establish that this paywall will improve our results. The report also reports higher refund rates for hard paywalls. Treat the model as a testable business choice, not a proven conversion fix.

Before selling “new toys each season,” name the next deliverable, owner, date and realistic production budget—or narrow the promise before launch. $59.99 is roughly two years of the headline annual price; this is arithmetic, not a profitability analysis. The lifetime promise creates ongoing support/content obligations. Keep the option, but budget those obligations instead of assuming new subscriptions will pay for them.

For App Store presentation, lead with three real interactions and the family benefit, not nine thumbnails or an abstract “Montessori” badge. Suggested main line remains “Calm toys for little hands”; the supporting sentence should explain what children do: care for friends, experiment with sound, sort, build combinations and explore. Apple evaluates memorable interaction, delight, inclusivity and craft; a nomination is not a substitute for a reliable business or satisfied families.

## The short action list

### App experience and trust
- **Finding:** the paid-only first session asks for belief before proof. **Action:** show a short real-gameplay demonstration before the offer; let “Not now” exit directly. **Priority: High.**
- **Finding:** reminder and cancellation assurances are inconsistent. **Action:** qualify reminders everywhere, show permission/scheduling status, and use one clear no-charge cancellation deadline. **Priority: High.**

### Gameplay
- **Finding:** Feed/Drop Dots have more variety in code; different-looking rounds may still feel the same. **Action:** prioritize recognizable character responses and satisfying arrange/pour/reset loops over more assets. **Priority: High.**
- **Finding:** repeated physical/audio defects undermine the calm promise. **Action:** use the founder's build-11 findings to close remaining floor, socket, stage, sound and touch issues once; preserve natural endings. **Priority: High.**

### Branding and artwork
- **Finding:** Lull's personality is less defined than its materials. **Action:** establish Wren/cast behavior and one art/motion reference; reuse actual toy parts on the shelf. **Priority: High.**
- **Finding:** the intended age range and brand documents disagree. **Action:** replace retired Stack/free-toy messaging and select one evidence-supported audience statement. **Priority: Medium.**

### Monetization and release
- **Finding:** build 12 depends entirely on working purchases. **Action:** finish store configuration, wait for Active agreement status, run the required build checks and have the founder verify purchase/restore before release. **Priority: High.**
- **Finding:** seasonal content and lifetime access create unbudgeted obligations. **Action:** commit one funded content milestone or narrow the promise; evaluate the current prices with aggregate store results. **Priority: High.**
- **Finding:** website/support URLs remain release work. **Action:** publish the existing site with a real support address and align its offer, privacy copy and store metadata. **Priority: High.**

## Scope control

This is a ranked roadmap, not authorization to redesign all nine toys. Before the next upload, resolve confirmed purchase-copy problems and required store setup. Let the founder finish hands-on checks. Keep larger cast/gameplay refinements as targeted follow-ups based on those observations. No new toy, progression economy, streak, competitive score or additional review round is proposed.

## Sources

Local: `App/Shared/LullPlansViewController.swift` (offer, timeline, reminder, hesitation sheet); `LullOnboardingViewController.swift`; `LullDemoState.swift`; `ToyRegistry.swift`; `ToyShelfViewController.swift`; `App/Toys/FeedThePeople/FeedScene.swift` (food list, cast and plate rotations); `App/Toys/DropDots/DropDotsScene.swift`; `App/Toys/Meadow/MeadowLittleOnes.swift`; `Docs/Plan-Build11.md`; `Docs/Brand.md`; `Docs/ExpressionPrinciples.md`; `Docs/AppStore/SubmissionKit.md`; build-12 handoff.

- [Apple Design Awards](https://developer.apple.com/design/awards/): public criteria and current examples; no inference of inside jury knowledge.
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), especially 1.3 and 3.1.2: adult-gated commerce, subscription disclosure and ongoing value.
- [RevenueCat State of Subscription Apps 2025](https://www.revenuecat.com/state-of-subscription-apps-2025): the primary source of the benchmark used by the preceding handoff; observational benchmark, not a Lull forecast.
