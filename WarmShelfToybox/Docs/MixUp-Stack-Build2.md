# Mix-Up and Stack — final build 2 pass

October 7, 2026. Supersedes the earlier 19-resident/crop-only pass.

## Mix-Up

Six distinct new felt friends — rabbit, bear, songbird, fox, mouse and frog — yield 216 combinations. Two native transparent atlases replace the damaged active cast. Their alpha is preserved; runtime texture rectangles select parts without color keying, despill or bitmap edits. Original source artwork stays in Git.

Heads register by chin; bodies share collar/waist lines; taller legs share a floor. The scene measures the entire cast to fit the room. A cream room and simple wood stand replace the ornate theatre. Fixed finger-sized controls sit outside the character; saved portraits fit their actual bounds. Saved recipes migrate once from both old 24-part and 19-part orders to cast version 3. Recipe count is preserved; retired identities adopt the closest new felt friend, so old saved appearances can change.

Masters and exact built-in imagegen prompts: `ArtDrops/2026-10-07-mixup/`. Runtime atlases: `App/Resources/Assets.xcassets/mixup-friends-{a,b}.imageset`.

## Stack

Opens with a wide base and one loose stone in a visible supply tray. The first-use gesture hint shows a move without reading; Reduce Motion uses static dots. A fresh stone appears in the same tray when its stone is lifted outside. The 12-stone limit and free placement/physics remain. Grabbing a stone cancels its appearance animation so it cannot unfreeze while held.

## Verification and evidence

- `verify_mixup_stack.py`: 145 checks for native RGBA atlases, unique parts, crop bounds, both legacy migrations and supply geometry.
- `verify_mixup_layout.py`: 280 checks across 14 phone/iPad layouts, safe areas, separate controls, saved cards and stage alignment.
- Whole-app simulator Debug and signed iPhone Release builds passed.
- Founder confirmed the revised physical iPhone checks passed, including Mix-Up parts/save, Stack refill and all-nine opening. Remaining hands-on testing belongs to the founder at their explicit request.

Source checks establish geometry/state, not child comprehension or award readiness. See the final handoff and jury-style review for evidence limits and follow-up priorities.
