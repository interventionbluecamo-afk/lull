# Three-Week Ship Plan

This plan is the current path from toddler-test prototype to first App Store build.

## Current Thesis

Warm Shelf already knows what it is: calm, text-free, tactile digital toys for toddlers. The remaining submission gap is craft: audio, whole-body feedback, trust surface, accessibility, and physical-device polish.

## Week 1: Sensory Layer And Feed Core Feel

- Add richer Bubbles audio: small, medium, large, wet, and rare pop variants.
- Add reliable Feed mouth feedback on every successful feeding.
- Keep chew sounds quiet and food-sensitive; they should confirm the eating moment, not become a gag.
- Give Feed characters whole-body happy motion, not just facial changes.
- Keep Food touch audio separate from Clay Blocks audio.
- Add or source Clay Blocks pickup, release, settle, and tumble cascade audio.
- Recheck Clay Blocks opening state: first touch should invite either stacking or a satisfying collapse.

## Week 2: Trust, Polish, And Accessibility

- Slow Feed character arrivals so they read as friends joining a line, not spawned nodes.
- Add a soft plop/bounce when foods return to the table.
- Tune thought bubbles on iPhone: larger food icon, slower pulse, no task-like feeling.
- Expand the parent area with support contact, version number, and the no-data/no-ads promise.
- Improve VoiceOver labels: specific food names, hungry friend, new shape, return to shelf.
- Update `WarmShelf_MasterSheet.html` to match the current app state.
- Create an app icon that feels handmade and text-free.
- Add a subtle Clay Blocks standing-tower acknowledgement after a stable build.

## Week 3: Device Test And Store Build

- Test on physical iPad and iPhone: audio volume, haptics, rotation, multi-touch, block tunneling, and shelf return.
- Capture App Store screenshots for iPhone and iPad.
- Write App Store copy around the core promise: no scores, no instructions, no ads, just living toys.
- Prepare age rating and privacy answers: no backend, no ads, no accounts, no collection.
- Ship paid, not free, if the product promise remains premium and private.

## Explicitly Deferred

- Puddles or any fourth toy.
- Bitmap paper-grain textures beyond what is necessary for polish.
- Garage.
- Analytics.
- Localization beyond parent-facing text.

## Already Addressed From This Plan

- Parent area exists via two-finger long press.
- Feed rotation preservation is implemented.
- Feed mouth sound is reliable after successful feeding.
- Feed has whole-body satisfied shimmy.
- Food no longer calls block pickup/release audio directly.
- Bubbles and Clay Blocks have initial real audio assets wired through `AudioManager`.
