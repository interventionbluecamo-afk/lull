# Meadow beach — build 1.1 (21)

November 4, 2026. Branch `claude/modest-bell-cjarqm`. Founder asked for a beach at one edge of Meadow, starfish, shells, flowing jellyfish and faint fish, with perspective kept consistent. All nine toys remain. Carry forward build 20's Drop Dots landscape fix and bounded SpriteKit renderer mitigation.

## What changed

- A southern beach transitions from grass to warm sand, damp sand and blue water, all in Meadow's existing overhead world. No horizon, upright ocean backdrop or isometric insert.
- Six optional sea-star/shell finds have tight contact shadows and restrained touch/VoiceOver reactions. Three translucent jellyfish have gently pulsing bells and current-following threads; seven faint fish swim below the surface. A low-amplitude tide runs at 30 material updates per second. Node counts and motion time stay bounded; no new warp meshes, audio or reward loop.
- Rotation retains world geometry and tide/sea-life phase, including a visit with no flowers yet. Mother and followers remain on land; baby hiding/recurrence positions remain reachable. Flowers and grass coverage stay on grass, while safe pebble clusters can remain on sand. Existing endless baby replenishment is retained.
- Reduced Motion stops the water/sea-life motion and uses a short fade for finds. VoiceOver exposes visible finds with 60-point targets and ignores stale/paused scene actions.
- Version/build are **1.1 (21)** in project.yml and the Xcode project. The new `MeadowBeach.swift` source is registered in the Xcode target.

## Art organization

Two original, unmodified RGBA assets: `meadow-beach-starfish` and `meadow-beach-shell`. Built-in image_gen, exactly two calls. Both use strict overhead prompts, neutral diffuse light and simple felt forms. Full prompts, provenance, hashes, dimensions and isolated day/night previews are beside this handoff in README.md, Prompts.json and Assets.json. AssetManifest.md and the generated asset inventory are current. Water, jellyfish and fish are code-native so parts can move independently.

## Verified / remaining

- Final combined Debug build succeeded: `/private/tmp/lull-build21-debug.log`, DerivedData `/private/tmp/Lull-Materials-Nov4`.
- Focused Meadow checks passed: 25,365 model + eight scene checks, and 23,761 world-interaction checks. They cover land/grass boundaries, flower-slot preservation, recurring baby placement and access. These are model checks, not play sessions.
- Four isolated native macOS beach-node frames rendered (day/night at 0/6 seconds). Final day/night colors and overhead forms were inspected. Two final previews are committed. **These are not full iOS or physical-device captures.** Device Hub/Simulator previously stalled; no full-scene touch/rotation acceptance is claimed.
- Swift parse and git whitespace checks passed.
- The founder's build 19 `add_subdivs` renderer crash is still unreproduced. Build 20's mitigation is included; do not claim the crash conclusively fixed. See `Docs/Update-2026-11-04/Handoff.md` for the crash evidence.

## Finding the beach / founder check

Start Meadow normally and lead the mother toward the bottom edge of the world. The shore continues across that edge. Try tapping a shell/star, then rotate at the beach with babies following. Check day/night readability and Reduced Motion on the phone. Retest the earlier crash action and Drop Dots landscape while using this build. No broad nine-toy review or duplicate founder acceptance gate is requested.

DEBUG-only `LULL_DEBUG_MEADOW_BEACH=1` starts at the sand and skips the introductory wander for captures. It is not active in the TestFlight build.

## Delivery

Release archive/upload in progress when this initial handoff was written. Record the actual Xcode result here before claiming delivery. Leave submitted **1.0 App Review untouched**. Do not change review metadata, prices, tester groups or What to Test notes as part of this beach update.
