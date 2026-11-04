# Lull materials and interactive moments plan

November 3, 2026 plan; execution authorized by the founder's “go” and resumed November 4 after a Mac restart. All nine work packages are implemented and pushed at `3e1405b`; combined Debug 1.1 (19) passes on iPhone 18 Pro / iOS 27 Simulator. Confirmed simulator captures are recorded in the current handoff; focused founder physical acceptance remains pending. The founder subsequently authorized TestFlight: Release archive and upload succeeded November 4 at 1:49 PM Central; Apple began processing 1.1 (19). The 1.0 review remains untouched. Current status and evidence: [materials-and-motion handoff](Art/Materials-Motion-2026-11-03/Handoff.md).

## Outcome

Lull should feel like a collection of handmade toys made by the same artist. Forms, light, contact and movement should agree. The child causes small discoveries, and each response returns to calm. All nine toys remain; their familiar main gestures stay intact.

## Starting point at planning — November 3

- Build 18 is the uploaded baseline used for the founder's November 3 feedback.
- At plan creation, local build 19 contained initial Meadow lighting/shelter, Mix-Up attachment/save and Sleepy Box material work. The final implementation and subsequent TestFlight upload status are recorded above.
- The initial Sleepy Box grain read flat and striped. The implemented pass replaces it with quiet curved figure and consistent matte bevels; the founder's physical appearance review is still pending.
- Existing source assets, prompts, previews and catalog inventory are indexed under `Docs/Art/README.md`. Do not rearrange production paths or delete historical sources to make the folders look tidier.

## Shared art and motion standard

1. **Simple handmade forms:** chunky silhouettes, softened edges, restrained stitching and grain. Detail must read at actual play size.
2. **Believable spaces:** consistent perspective, light direction, relative scale and contact within each toy. The toys share an artistic hand, not an identical camera angle.
3. **Material-specific movement:** felt compresses, fabric bends from its attachment, wood carries weight, water spreads. Avoid stretching the complete illustration as a substitute for articulation.
4. **Quick to notice, slow to settle:** direct manipulation follows the finger without an animation delay. Reactions begin promptly; release returns gently to rest. Tune timing by material rather than giving everything the same bounce.
5. **Child-caused discoveries:** optional, understandable responses with quiet space between them. Repeated input updates a response rather than queuing performances.

Keep the existing sun-faded palette. Source art uses neutral illumination; scene lighting handles day/night where applicable. Grain belongs to the material, not a screen-wide noise filter. A contact shadow is either in the asset or rendered in the scene, never accidentally doubled.

## Image generation protocol

Before each generation, inspect the actual neighboring production art and record an asset contract:

- **Camera:** scene reference, overhead/front/three-quarter view, projection, visible top and side planes, tilt and horizon where relevant. Record numeric alignment measurements from the chosen reference before prompting; do not invent a new camera per asset.
- **Composition:** canvas dimensions, object bounds, scale, ground/contact line, orientation, pivot, attachment and overlap margins.
- **Material:** felt fibre size, seam restraint, painted wood finish, palette and edge softness, all judged at gameplay size.
- **Lighting:** shared light direction, broad soft highlights, ambient tint applied in code where appropriate, explicit shadow ownership.
- **Layer role:** background plate, movable component, occlusion layer or texture. Transparent cutouts contain no room or display pedestal; clean plates contain no duplicate version of the movable component.
- **Constraints:** no text, ornate miniature scenery, glossy plastic, detached baked glows or incompatible perspective. No faces baked into assets whose expressions are drawn by code.

Use one reference family at a time and composite it into the actual scene before generating variants. For Wash, use paired clean-plate edits that preserve the room composition and remove only the movable fibres. For Meadow's shelter, derive separable roof and doorway layers from the selected shelter reference. Reuse working assets when geometry or animation changes can solve the problem. No wholesale regeneration of the catalog.

Save exact prompts, references, originals, selected exports, attachment coordinates and scene previews under a dated art folder. Refresh the catalog inventory after production assets change. Source provenance and in-use status remain distinct.

## Work packages

| Order | Toy | Planned change | Acceptance condition |
| --- | --- | --- | --- |
| 1 | Meadow | Finish the overhead shelter and shared day/night lighting. Split roof leaves from the doorway; lift a leaf slightly as a baby arrives, tuck the baby behind it, then settle the leaf and warm the doorway. Keep the house visible from the start and preserve existing creature discoveries. | House, flowers and creatures share light and ground contact. Entry uses the actual doorway; roof motion does not stretch the whole house. Arrival remains readable without sound. |
| 2 | Little Wash | Separate brushes from portrait/landscape bay plates. Individual fibre groups bend where touched and return gently. Hose spray can wet a brush; a few drops lead toward a short drain ripple when water reaches it. Preserve sponge-and-hose play, two-tool tray, vehicle scale and contact shadows. | Brush targets work in both orientations without stealing a tool or vehicle gesture. Water follows a believable path. No continuous spinning, automatic spectacle or extra required washing step. |
| 3 | Sleepy Box | Keep the larger pieces and holes. Give painted pieces coherent thickness, softened bevels and quiet grain. Unify drawer, knob and tray with the wooden shell. Tune lift, posting and drawer release for weight; retain existing awake/tuck reactions. | Shared piece/socket geometry and box perspective remain exact. A piece looks like the same object before, during and after posting. Material avoids stripes, plastic shine and sticker-like highlights. |
| 4 | Mix-Up | Finish joined neck/waist motion and grounded feet. Add modest secondary motion to appropriate ears, sleeves or hats using separate parts or safe deformation. Maintain consistent registration across the cast and make repeat-save acknowledgement clear. | Mix-and-match combinations stay connected during flips and bows. Accessories do not detach or clip. Saving the same recipe adds no new duplicate; historical saved creations are preserved. |
| 5 | Feed | Have the friend notice approaching food with gaze, a tiny lean and a mouth response. Relax if the child pulls food away; connect existing chewing and contentment to the handoff. | Anticipation follows the actual food, not a timer; it does not seize the food or force feeding. Existing food and character variety remains intact. |
| 6 | Window | Keep the curtain top attached. Let lower fabric trail the finger slightly, gather in folds and settle after release; connect the light reveal to the opening. Preserve existing discoveries. | Fabric bends without stretching the room or detaching its top. Rapid reversals, rotation and release keep the curtain within its frame. |
| 7 | Drop Dots | Replace the simultaneous stack jiggle with a small delayed settling response passing through the stack after a dot lands. Keep restrained tint so the material remains visible. | The landing and response have one clear cause. Dots retain their shape, channels and matching colours; existing pattern feedback does not pile on top of the new motion. |
| 8 | Hum | Connect the mallet strike, a tiny key deflection and the existing expressive face. Let the expression soften with the sound's decay. | Key spacing and pitch remain stable. The response reads clearly at phone size; rapid playing does not accumulate wobble or loudness. Reduced Motion retains readable expressions. |
| 9 | Bubbles | In an occasional special bubble, show the existing little bird before popping. On the child's pop, that same bird emerges and flies away gently. Ordinary bubbles keep their existing simple behavior. | The bird does not appear from nowhere or get duplicated. The bubble remains easy to pop and the discovery creates no demand to chase, collect or wait. |

## Execution stages

November 4 addition from the founder: Meadow must remain playable after bringing all babies home, with more interest between landmarks. Implementation reuses five slots after a quiet pause, chooses fresh offscreen hiding locations, preserves house warmth and rotation state, and adds bounded low-contrast ground clusters below the flower trail. The extra scope has focused recurrence/placement checks.

Checked stages mean their source implementation is complete. They do not mark the final visual/device acceptance conditions as passed.

- [x] **A — Establish the reference:** scene material/layer contracts recorded; Meadow shelter layers and shared light implemented; Wash clean plates and separate brush interaction implemented.
- [x] **B — Finish the physical toys:** Wash brush/water responses in both layouts, Sleepy Box materials/weight (including the bevel follow-up), and Mix-Up connected motion/save retention implemented.
- [x] **C — Add responsive character and fabric:** Feed anticipation, anchored Window fabric and Drop Dots delayed settling implemented, with competing physical reactions removed or replaced.
- [x] **D — Refine sound-linked and small discoveries:** Hum strike/face decay and visible Bubbles passengers implemented. Meadow's November 4 recurrence/route-detail addition is also implemented. The final shelf-to-toy appearance review belongs to stage E.
- [ ] **E — Integrate and hand off — engineering complete, founder acceptance pending:** source is pushed at `3e1405b`; focused checks, combined Debug build, refreshed art inventory, documentation and confirmed captures are complete. Capture coverage includes all nine phone portrait scenes and shelf, Meadow day/night, Wash phone landscape and iPad Air M3 portrait/landscape, and Meadow iPad portrait/landscape. The accompanying docs/capture commit records the final evidence. Founder physical timing, audio, multitouch, Reduced Motion and VoiceOver acceptance remains pending, so this stage stays open. The founder subsequently requested TestFlight; the Release archive/upload succeeded November 4. App Review submission remains outside this task.

Stages define implementation order, not separate permission gates. Share scene previews and brief progress updates as work lands; ask only if a consequential design decision cannot be resolved from this plan.

## Interaction and accessibility contract

- Home and primary play interactions retain priority over optional scenery. Touch ownership is stable for the duration of a gesture; add forgiving touch regions without pulling play toward system edges.
- Existing system-gesture deferral and parent Guided Access guidance remain in place. Optional new interactions stay inside the comfortable play area.
- Every effect has a rest state and complete ending. Pause, backgrounding and rotation cannot leave bent fibres, detached parts or stuck glows. Preserve parent timer behavior and saved progress.
- Reduced Motion uses restrained fades, pose changes or direct positional feedback. VoiceOver must offer an equivalent action for meaningful interactive objects where appropriate.
- Existing sound-off and haptics settings apply. Visual feedback stands alone; add no harsh effects or competing sound layers.
- Keep textures and particle counts bounded. Reuse/cancel ongoing actions rather than creating an unbounded queue on repeated touches.

## Definition of done

- Changed scenes compile and relevant existing checks pass; add focused checks only for meaningful new state or gesture behavior.
- Inspect each changed composition at real play size, covering phone portrait/landscape and an iPad layout; check day/night only where the scene supports both. Check ordinary and Reduced Motion behavior for new movement.
- One consolidated founder device pass covers touch feel, audio and family use. Do not repeat a broad nine-toy audit after every small asset edit.
- A toy feels responsive without idle spectacle, preserves its main play loop, and returns cleanly to rest. Further ideas discovered during implementation go into a later backlog unless needed to make an accepted change work.
- Save source/art/prompts and current handoff in Git. No change to pricing, onboarding, store metadata or the submitted 1.0 build is included in this art/motion scope. The planning turn did not authorize upload; the founder subsequently authorized the completed November 4 TestFlight upload. No App Review submission is authorized.

