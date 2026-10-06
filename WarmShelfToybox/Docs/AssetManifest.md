# Warm Shelf Asset Manifest

This is the source of truth for Warm Shelf assets. Add real app files here as they land,
and keep non-shipping source or staging art in the top-level `Assets` workspace.

## Asset Principles

- Assets support calm, tactile play. They should not compete with the interaction.
- No text or instructional graphics inside toys.
- Use warm paper, matte clay, soft food, and low-contrast handmade details.
- Every asset must have a graceful fallback in code.
- Keep filenames lowercase kebab-case.

## Folder Map

| Folder | Purpose |
| --- | --- |
| `Assets/Marketing/Source` | Original marketing and press source images, not bundled into the app |
| `Assets/Staging/<Toy>` | Generated, QA, or candidate art grouped by toy before app integration |
| `LandingPageDeploy/img` | Web-ready landing page images |
| `LandingPageDeploy/press` | Downloadable press-kit files |
| `App/Resources/Audio/Bubbles` | Bubble pop variants by size and rare moments |
| `App/Resources/Audio/ClayBlocks` | Pickup, release, settle, mystery-shape sounds |
| `App/Resources/Audio/FeedThePeople` | Food receive, happy hum, decline/exhale sounds |
| `App/Resources/Audio/PuddlePlay` | Puddle taps, ripples, raindrops, creature responses |
| `App/Resources/Audio/Shared` | Empty taps, soft taps, shelf transition |
| `App/Resources/Textures/Paper` | Linen, table, shelf, and warm paper grain |
| `App/Resources/Textures/Materials` | Clay, food, and soft object material overlays |
| `App/Resources/Sprites/Food` | Optional handmade food sprites |
| `App/Resources/Sprites/Characters` | Optional modular character accessories/details |
| `App/Resources/Sprites/Shelf` | Optional home shelf object art |
| `App/Resources/Sprites/Particles` | Optional handmade particle flecks |
| `App/Resources/Reference` | Small app-adjacent reference files; keep bulky source-only work in `Assets/Staging` |

`App/Resources` is included by the Xcode target. Keep bulky generations, rejected
candidates, and source-only art in `Assets/Staging` until a final asset is intentionally
promoted.

## Shipping Assets

| File | Type | Used By | Notes |
| --- | --- | --- | --- |
| `App/Resources/Assets.xcassets/AppIcon.appiconset/Icon-1024.png` | image | App icon | Signature sleepy stacking friend with cream moon patch and balancing capstone. |
| `App/Resources/Assets.xcassets/BrandHero.imageset/brand-hero.png` | image | Parent onboarding | In-app copy of the signature hero artwork used to keep the first parent-facing moment consistent with the icon. |
| `App/Resources/Audio/bubble-pop.mp3` | audio | Bubbles fallback | Current uploaded pop sound, used by `AudioManager` as fallback for all bubble sizes. |
| `App/Resources/Audio/Bubbles/bubble-pop-small-1.mp3` | audio | Bubbles | Small/rare pop candidate, tuned quietly. |
| `App/Resources/Audio/Bubbles/bubble-pop-medium-1.mp3` | audio | Bubbles | Medium/large pop candidate, pitch-shifted by profile. |
| `App/Resources/Audio/ClayBlocks/block-release-1.mp3` | audio | Clay Blocks | Soft block release candidate. |
| `App/Resources/Audio/ClayBlocks/block-settle-1.mp3` | audio | Clay Blocks | Soft wood/block settle candidate. |
| `App/Resources/Audio/FeedThePeople/feed-chew-soft-1.mp3` | audio | Feed the People | Occasional soft chew accent after successful feeding. |
| `App/Resources/Audio/FeedThePeople/feed-chew-crunch-1.mp3` | audio | Feed the People | Occasional crunchy chew accent for apple/carrot. |

## Needed Next

### Audio

Recording targets: mono or stereo `.wav`, `.m4a`, or `.mp3`, trimmed below 700ms unless noted. Normalize softly around -20 LUFS integrated, keep peaks below -3 dB, remove sharp clicks, and test at 50% device volume. Sounds should feel optional; muted play must still read clearly.

| Proposed File | Used By | Design Notes |
| --- | --- | --- |
| `bubble-pop-large-1.mp3` | Bubbles | Lower, rounder, still gentle. |
| `bubble-pop-rare-1.mp3` | Bubbles | Softer and a little unusual, not flashy. |
| `empty-tap.mp3` | Shared | Barely audible paper/ripple response. |
| `soft-tap.mp3` | Shared | General object tap. |
| `shelf-transition.mp3` | Shared | Quiet movement back to shelf/toy. |
| `block-pickup.mp3` | Clay Blocks | Felt/clay lift. |
| `mystery-shape.mp3` | Clay Blocks | Source tray gives a new block. |
| `food-pickup.mp3` | Feed the People | Light fruit/food lift, distinct from block pickup. |
| `food-release.mp3` | Feed the People | Soft food set-down. |
| `food-plop.mp3` | Feed the People | Food returning from source tray to table. |
| `feed-receive.mp3` | Feed the People | Food accepted. |
| `feed-happy.mp3` | Feed the People | Tiny non-verbal happy response. |
| `feed-decline.mp3` | Feed the People | Very soft no-thanks response. |
| `puddle-tap-1.mp3` | Puddle Play | Small fingertip touch on water, quiet and close. |
| `puddle-ripple-1.mp3` | Puddle Play | Rounder first-splash response with a little body. |
| `puddle-raindrop-1.mp3` | Puddle Play | Tiny drop option; avoid playing constantly. |
| `puddle-creature-1.mp3` | Puddle Play | Tiny non-verbal creature response, no quack/croak joke. |

### Textures

| Proposed File | Used By | Design Notes |
| --- | --- | --- |
| `linen-grain-1.png` | Shared background | Very subtle, low-contrast paper grain. |
| `warm-cream-grain-1.png` | Shelf/table surfaces | Slightly warmer than background. |
| `clay-soft-noise-1.png` | Clay Blocks | Matte clay surface, no strong pattern. |

### Sprites

| Proposed File | Used By | Design Notes |
| --- | --- | --- |
| `food-apple-1.png` | Feed the People | Optional replacement for procedural apple. |
| `food-carrot-1.png` | Feed the People | Optional replacement for procedural carrot. |
| `food-egg-1.png` | Feed the People | Must stay visible on linen background. |
| `food-bread-1.png` | Feed the People | Warm, chunky, easy to grab. |
| `food-berry-1.png` | Feed the People | Simple, readable silhouette. |

## Code Integration Notes

- `AudioManager` already searches by resource name with `.mp3`, `.wav`, and `.m4a`.
- New audio files can be dropped into any resource subfolder as long as XcodeGen includes `App`.
- Sprite/texture use should be optional: if a texture is missing, scenes should continue drawing procedural SpriteKit shapes.
