# Lull — product and design review

October 7, 2026. Final source/design review of the Mac pass and both new Mix-Up atlases. This is an independent design judgment, not Apple's judging process or an award prediction. Physical acceptance is the founder’s explicit device report; further play-testing is left to the founder at their request.

## Verdict

Lull now has a clearer identity: nine tactile toys, child-directed exploration and a parent experience that explains value without selling inside play. The strongest potential awards story is **Delight and Fun and Interaction**, supported by consistent visuals. The remaining distance is reliable play across ages, devices and accessibility settings, followed by evidence from real families. More artwork or technology features alone will not close that distance.

Apple's current award descriptions emphasize satisfying experiences, intuitive controls, inclusive access and cohesive imagery. Those are useful review lenses; they are not a published scoring rubric or a promise of selection. [Apple Design Awards](https://developer.apple.com/design/awards/)

## Evidence and judgment

| Area | Evidence in the reviewed pass | Judgment / remaining proof |
| --- | --- | --- |
| Identity | All nine launch toys remain, including Hum and Meadow. The six new Mix-Up friends use two native transparent atlases, with one felt material and a restrained palette. | The new cast is a substantial improvement in visual coherence. Runtime seams, sizing and controls must be judged in the scene, not from the atlas alone. |
| Interaction | Feed now schedules its whole chew/laugh/happy recovery and rescales after rotation. Mix-Up measures its character envelope separately from finger-sized controls. Stack introduces the loose supply stone through one visual demonstration. | These address real friction. The first useful action still needs to be understandable to a two-year-old without an adult explanation. |
| Sound | Recorded and synthesized playback share an active-session gate. Backgrounding, interruption and Sound-off stop existing playback; returning resumes room ambience rather than an old held note. | Better lifecycle behavior is part of polish. Loudness, Silent Mode expectations, interruption recovery and sensory comfort require listening on the actual device. |
| Parent offer | Concrete benefits precede a real-price offer. Seven-day local trial and free toys are explained; Restore and reload are near the offer. Child shelf code contains no prices or upgrade actions. | This is a clearer reason to buy. Conversion improvement has not been measured. Keep the free path readable and the final page/offer from becoming too dense. |
| Learning / inclusion | Choosing, repetition, picture/touch play and parent controls are supported by the design. Source contains accessibility activation and Reduce Motion handling. | These support the Montessori-inspired intent; they do not prove educational gains or independently usable play across ages 2–6. Educator and family review, VoiceOver, large text and motor-access testing remain evidence gaps. |

## Release gates

**Internal TestFlight:** the final build and device checklist are the gate. Root must fill in actual iPhone portrait/landscape and iPad results, all-nine smoke play, state preservation, sound-off, rest/wake, background/foreground and Reduce Motion. Do not convert source checks or a signed build into a claim that these interactions passed. A failed core interaction, unreachable control, missing art, lost accepted state or persistent sound after stopping should hold the upload until fixed.

**Commercial / broader external release:** actual App Store Connect configuration for `com.lull.full.lifetime` remains unverified in this review. Confirm it is a non-consumable, then test localized price, success, cancellation, pending approval, relaunch and restore. The UI correctly withholds its offer if the real product is absent or the wrong type; that is honest behavior, not revenue readiness. `com.lull.full.annual` is still a recognized legacy entitlement, so purchased copy should not assume every user has lifetime access. Apple recommends testing using real product information and providing a restore mechanism. [Apple In-App Purchase](https://developer.apple.com/in-app-purchase/)

Verify the support address `support@lull.app`, publish the privacy-policy link and reconcile App Store privacy/age metadata with the binary before broad distribution. The local-play statement is supported by local state storage; StoreKit's Apple transactions should remain clear in the policy.

## Prioritized polish / backlog

1. Watch every Feed expression transition at normal play speed and check each Mix-Up join in the running scene. Texture flicker and visibly stretched seams weaken the handmade illusion even when the geometry passes.
2. Inspect the parent offer and three-page welcome on the smallest supported screen and with large text. Essential purchase, restore, close and free-play actions must remain reachable; concise benefits should carry the value.
3. Run observed sessions with younger and older children and their parents, including varied motor/sensory needs. Record what they understand, repeat or abandon. Keep educational claims modest until that evidence exists.
4. Finish remaining visual consistency, accessibility and commercial setup before adding more toys or decorative systems. Preserve the nine-toy scope for this version.

## Final evidence and decision

- Whole-app simulator Debug and signed physical-device Release builds passed.
- Eight verification scripts passed: 1,046 numbered checks plus onboarding/rest and Window scenario assertions.
- Founder confirmed the installed revised iPhone build: “Device checks pass; sound works.” This covered the requested Sound On/Silent Mode, Sound Off, Hum/Bubbles/Feed, Mix-Up/save, Stack/refill, Sleepy Box/shuffle and all-nine opening checklist. Founder then took ownership of all further testing.
- Agent inspected simulator welcome/trial page, adult gate, honest unavailable purchase screen and the new Mix-Up room/rabbit rendering. No comprehensive iPad, hardware-route, multi-touch, VoiceOver or child-study claim is made.
- App Store Connect initially had no IAP. The founder approved a $9.99 US non-consumable lifetime unlock; product 6820224689 was created. Configuration status is in the release note. Purchase/restore are not certified.
- **Decision: internal TestFlight can proceed using the founder’s device approval. Public App Store submission still requires the commercial, metadata and accessibility/family evidence work above.**

The first and final welcome pages are readable in the observed portrait view. The final page remains wordy; the parent offer's small primitive toy previews do not yet match the child shelf's art. Those are focused conversion/polish follow-ups. No measured conversion improvement or award outcome is claimed.
