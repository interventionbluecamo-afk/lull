# Jury Review Results - June 14

## Review Method

This was a practical build review, not a pretend awards-panel essay. The jury reviewed the current simulator build, direct-launched each child-shelf toy where possible, used existing debug staging for toys that expose it, captured screenshots, and inspected the real touch/drag code paths for interaction bugs.

Important limitation: the local `simctl` setup can launch and capture scenes reliably, but it cannot inject real finger touches. So this is a simulator visual + debug-state + code-path review, not a live toddler/user test.

Evidence folder:

- `Assets/Staging/JuryReview-Jun14/`
- Original contact sheet: `Assets/Staging/JuryReview-Jun14/jury-contact-sheet.png`
- Post-fix captures: `stack-after.png`, `hum-after.png`, `dropdots-after.png`

## Jury Seats

1. Pixar/DreamWorks character animator: staging, silhouette, charm, material weight, and physical scene logic.
2. Senior iOS/SpriteKit engineer: hit testing, z order, persistence, state bugs, layout, and debugability.
3. Montessori early-childhood researcher: agency, direct cause/effect, no pressure, fine-motor fit, and object permanence.
4. Duolingo-style retention designer: repeatable delight, invitations, emotional payoff, and return value without rewards.
5. Apple App Store editorial reviewer: trust, polish, screenshot honesty, premium feel, and rejection-risk weirdness.

## Executive Verdict

The app now has a very strong emotional center. Feed, Bubbles, Sleepy Box, Window, Meadow, and Mix-Up all read as authored, warm, and unusually coherent for a young-child toybox. The strongest scenes feel like physical little objects coming alive, not minigames wearing a soft skin.

The weakest pattern was not core mechanics. It was scene logic: a few toys opened with too much empty vertical space, a few objects did not quite respect the room/surface they belonged to, and one token-reset path needed to be more honest under impatient child input.

The jury's headline: keep cutting anything that feels like a UI screen, keep making every object obey its room, and make the first five seconds of every toy look finished before the child does anything.

## Ranked Findings

### 1. Window Scene: Scene Logic Must Be Ruthless

Juror consensus: the Window is now the flagship room, but it is also the scene where impossible placement breaks the spell fastest.

Observed issues before the pass:

- Tree bottoms visually floated above the sill, creating a fake layered-card feeling.
- Toybox wanted to belong against the wall, not float forward like a product shot.
- Night glows around the lamp/toybox felt like hard graphics instead of soft light in the room.
- Some floor objects were staged without fully respecting the floor/wall relationship.

Decision:

- This was a ship-now fix because it affected the flagship scene and App Store screenshot trust.

Result:

- Fixed in `GlowWindowScene.swift` during the Window pass: buried tree bottoms under the sill, moved toybox against the wall/baseboard, softened lamp/nightlight glows, improved prop placement, mounted the right-nook library, and landed front-on toybox art.

### 2. Stack: First Five Seconds Felt Too Empty

Pixar/DreamWorks juror:

Stack had good sleepy characters, but too much air above them. It read less like a toy staged for little hands and more like a prototype waiting for content.

iOS/SpriteKit juror:

The layout math put the portrait floor too low, and the invitation piece spawned above the visible stage after a longer delay.

Montessori juror:

The child should immediately understand "these soft things can be touched and stacked." The first view was calm, but under-inviting.

Decision:

- Ship-now.

Implemented:

- Raised the portrait play plane.
- Shortened the opening invitation delay.
- Spawned the invitation piece inside the upper play field instead of above the screen.

Files:

- `App/Toys/Stack/StackScene.swift`

### 3. Hum: The Instrument Was Beautiful But Framed Like A UI Panel

Pixar/DreamWorks juror:

The xylophone bars are charming, but the first capture had too much top void and then, after lifting, the bars crowded the phone edges.

Montessori juror:

The instrument should feel reachable. It should sit where a child naturally taps, not low like a footer.

Apple editorial juror:

The art is premium, but edge-crowding makes screenshots feel less intentional.

Decision:

- Ship-now.

Implemented:

- Raised the instrument tray and bar baseline into the active child zone.
- Tightened phone tray width.
- Reduced phone bar scale so the authored bed has breathing room without losing toy heft.

Files:

- `App/Toys/Hum/HumScene.swift`

### 4. Drop Dots: Reset Needed To Be More Child-Proof

iOS/SpriteKit juror:

The finite-token reset logic was already thoughtful, but there was still an edge case: a child can touch reset while another dot is being dragged, and reset could begin while token actions were still in flight.

Montessori juror:

Object permanence matters here. The same dot should clearly return; reset should not feel like the toy swaps pieces behind the child's back.

Decision:

- Ship-now because it is a small code change that protects the toy's honesty.

Implemented:

- Reset does not trigger during an active drag.
- Reset cancels old token actions and clears lifted state before pouring pieces home.

Files:

- `App/Toys/DropDots/DropDotsScene.swift`

### 5. Feed, Bubbles, Sleepy Box, Meadow, Mix-Up: Mostly Hold

Feed:

- Strong emotional read immediately.
- The open-nook backdrop direction was correct: real sprites should be fed on top, not baked into the plate.
- Next refinement: continue checking food rest positions after any plate/counter adjustment.

Bubbles:

- Very clear cause/effect, beautiful calm motion, strong toddler affordance.
- Next refinement: preserve the uncluttered first impression; do not add UI.

Sleepy Box:

- One of the strongest toy premises: readable, tactile, and immediately understandable.
- Next refinement: keep watching z-depth and touch forgiveness as more shape art lands.

Meadow:

- High charm, strong wake-loop promise, good visual identity.
- Next refinement: every landmark needs a readable face and a clearly staged before/after state; no faceless "pretty object" landmarks.

Mix-Up:

- Strong authored character stage and premium theatrical feel.
- Next refinement: make sure the play invitation stays child-led, not button-led, wherever possible.

## Improvement Backlog

These are not emergency fixes, but they are the next best refinements:

1. Add an automated screenshot harness that bypasses onboarding, direct-launches every toy with `LULL_DEBUG_TOY`, and writes a dated contact sheet.
2. Add a lightweight "scene logic audit" checklist for authored art: every object must answer what surface it touches, what plane it belongs to, and where its shadow/light comes from.
3. For Window, keep replacing generic floor toys with authored objects that look good emerging from the toybox: a wooden train and a beanbag star were selected as better than ball/block.
4. For Feed, verify food rest points against the new open-nook backdrop and counter sprite after every backdrop change.
5. For Meadow, enforce the face rule: if a landmark wakes, the face has to be large, kind, and legible at device scale.

## Implemented In This Pass

- Stack staging and first invitation timing.
- Hum instrument position, scale, and phone framing.
- Drop Dots reset/drag safety and reset action cleanup.
- Prior Window scene-logic fixes remain part of the June 14 review thread.

## Verification

Build:

```sh
xcodebuild -project Lull.xcodeproj -scheme Lull -configuration Debug -destination 'generic/platform=iOS Simulator' build
```

Result: build succeeded.

Screenshots:

- `Assets/Staging/JuryReview-Jun14/stack-after.png`
- `Assets/Staging/JuryReview-Jun14/hum-after.png`
- `Assets/Staging/JuryReview-Jun14/dropdots-after.png`

