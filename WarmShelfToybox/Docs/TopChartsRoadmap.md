# Lull: Top-Charts Product Roadmap

## Product Verdict

Lull is an unusually coherent, developmentally thoughtful prototype. It is not yet a
top-chart product.

The central idea is strong: a calm, text-free shelf of tactile toys where every touch
has a gentle consequence and nothing can be failed. Stack is the clearest proof that
Lull can become distinct rather than merely tasteful.

The current ceiling is authorship. Too much of the visual and audio experience still
reads as procedural prototype work, the launch set spreads craft across too many toys,
and the product does not yet have one unforgettable character or interaction parents
can recognize from a small App Store icon.

## What Is Working

- The no-fail, no-timer, no-score interaction model is right for ages 2-4.
- Touch targets, multi-touch support, and forgiving placement respect tiny hands.
- Stack's emotional physics and Feed's caring loop create return value without rewards.
- The shelf, wind-down behavior, parent gate, and no-tracking architecture form a
  credible parent promise.
- The toy registry and shared interaction helpers make the concept extensible without
  requiring a large engine.

## What Caps The Product Today

- Procedural vector surfaces lack the material richness, lighting, and authored
  imperfection expected from a premium character toy.
- There is no signature hero with an instantly readable silhouette, face, and emotional
  payoff.
- The small audio library is reused too broadly and some clips are too long for crisp
  cause-and-effect feedback.
- Six launch toys divide attention before any one toy reaches reference-quality depth.
- The current app icon is pale, low-contrast, and anonymous at small sizes.
- There is no automated test target, StoreKit test configuration, or proven device
  matrix.
- Accessibility elements have labels, but the custom SpriteKit controls still need
  reliable VoiceOver activation behavior.

## Priority Roadmap

### P0 - Make The Child Shelf Truthful

Status: completed in the first audit pass.

- Every object visible on the child's shelf now opens.
- The free shelf is a consistent Bubbles and Stack starter pair.
- Purchases and the complete catalog stay entirely in the grown-up area.
- The store now offers the lifetime unlock only; the annual product remains recognized
  solely for legacy entitlement.
- Child name and age collection were removed, including cleanup of old local values.
- The privacy manifest now declares the app-only UserDefaults required reason.
- Unverified recurring-content promises were removed.

Why: a toddler should never discover that a friendly object is secretly a purchase
prompt, and the parent promise must be literally true.

### P1 - Turn Stack Into The Signature Hero

Status: signature identity and first emotional interaction pass completed.

- One expressive sleepy stone now has a bold silhouette, readable face, cream moon patch,
  tactile dimples, and a tiny balancing capstone.
- The character now appears consistently in Stack, on the shelf, in the launch moment,
  and in the app icon.
- The response arc now includes pre-wake anticipation, wobble, relief, cozy rest,
  capstone rebalancing, and delighted recovery after a fall.

Why: emotional reciprocity gives children a reason to return without streaks, prizes,
or pressure.

### P2 - Author The Sensory Layer

- Replace prototype-only surfaces with authored textures, controlled highlights,
  contact shadows, and small material imperfections.
- Record short interaction-specific foley for Stack, Feed, Bloom, Mix-Up, Paint, and
  shared shelf actions.
- Keep common responses under roughly 700 ms and reserve longer sounds for rare,
  child-triggered payoffs.

Why: ages 2-4 learn through immediate sensory cause and effect; premium material cues
also make the value obvious to parents.

### P3 - Launch Fewer, Better Toys

- Target Bubbles, Stack, Feed, and Bloom for the first public-quality set.
- Hold Mix-Up and Paint until their sensory identity and emotional payoff match the
  hero set.
- Give every launch toy one interaction that is unmistakably its own.

Why: four memorable toys earn stronger reviews and repeat play than six uneven ones.

### P4 - Prove The Toddler Experience On Devices

Status: source-level mechanics hardening completed; observed child and real-device
validation remain mandatory.

- Bubbles, Feed, Stack, Bloom, Mix-Up, and Paint now preserve the child's meaningful
  state across device rotation.
- Paint's color controls now use a spacious two-row portrait layout and choose the
  nearest visible color under an overlapping forgiving target.
- Mix-Up now changes a part only when the child touches the character or its large
  arrows; background scenery no longer triggers an unrelated change.
- Ambient loops in the newly polished toys now respect Reduce Motion while direct
  touch responses remain legible.
- Run five-second first-reach tests and ten-minute open-play sessions with ages 2-4.
- Validate two-handed input, rotation, return-handle discovery, speaker volume, haptics,
  and object reachability across supported iPhone and iPad sizes.
- Remove any interaction that needs explanation or causes repeated accidental exits.

Why: adult intuition cannot reliably predict what a two-year-old will notice, reach,
or repeat.

The concrete, low-cost gate is documented in `Docs/StackHeroValidation.md`.
The ordered zero-spend execution sequence is documented in
`Docs/ImmediateNextSteps.md`, and submission hard stops are tracked in
`Docs/ReleaseReadinessChecklist.md`.

### P5 - Build Release Confidence

- Add unit tests for shelf access, entitlement handling, and
  time-of-day behavior.
- Add UI smoke tests for onboarding, shelf entry, parent gate, purchase, restore, and
  relaunch.
- Add a StoreKit test configuration and profile the hero toys for stable 60 fps.
- Implement VoiceOver activation for custom SpriteKit controls.

Why: trust is the product; crashes, inaccessible controls, and purchase failures break
that trust immediately.

### P6 - Make The Store Page Recognizable

- Replace the current app icon with the high-contrast Stack hero.
- Show screenshots built around a child's action and the object's emotional response.
- Lead the parent story with: "No ads. No scores. Just play."
- Keep all claims concrete and already true in the shipping build.

Why: parents must understand the emotional and practical value before they can discover
the quieter details.

## Submission Hard Stops

- Do not place links, purchasing opportunities, upgrade prompts, or external
  distractions in the child experience.
- Do not add analytics, third-party SDKs, identifiers, or child data collection without
  a new privacy and Kids Category review.
- Do not submit until the public privacy policy, support URL, App Store Connect privacy
  answers, parental gate, purchases, and restore flow have been verified on real
  devices.
