# Mix-Up room and layout pass

October 7, 2026. Scene changes only; root integrates the new six-friend art and save migration.

The ornate red/gold generated theatre has been replaced with a cream room and a plain,
low wood stand. No curtain or old room texture is loaded by the scene. The picture shelf
and the character provide the room's detail.

Part-change controls occupy a separate right-hand lane. Their visible diameter is 44 pt
on phones and 54 pt on tablets, with 56/66 pt touch targets. They remain still while the
character hops or bows. Both tapping the character and the explicit controls change a
part. The control for feet now aligns with the feet instead of the platform below them.

The scene measures the union of the real part builders once and uses that envelope to
fit the character, set its floor baseline, and reserve control space. The existing slot
offsets are +92 / 0 / −88; it supports the taller new legs whose soles are −98. This also
makes the size calculation follow later changes to the cast rather than relying on a
hard-coded character height.

Saved looks have larger portrait cards. Each miniature is fitted and centred using its
actual assembled bounds instead of the old 340-unit guess that made portraits tiny.
Cards occupy the top of a portrait layout and a short left column in landscape. The
save flight targets both coordinates of its actual slot, including landscape Y. The
heart stays beneath the character. Saved looks now expose VoiceOver activation.

## Verification

- Swift parse passed for the staged scene.
- Production layout methods and the shared safe-area helper were extracted into a Swift
  fixture and run across **14 phone/iPad sizes and orientations with realistic safe-area
  insets**. **280 checks passed**: controls meet 44 pt minimums, control targets do not
  overlap vertically, discs remain outside the painted/breathing body, cards remain in
  the usable region, portrait cards clear the hopped character, landscape cards clear
  the body, and the −98 sole sits on the floor. The fixture used the new cast's conservative
  120 × 239 unit envelope.
- Root still needs the full iOS build and actual portrait/landscape gameplay verification.
  Source/geometry checks do not establish rendering or device touch behaviour.

Staged implementation: `App/Toys/MixUp/MixUpScene.swift`. The root release task merges
its cast-version-3 migration into the retained save store. This scene pass does not edit
`MixUpPart.swift`, raster artwork, other toys, or the repository's Git state.
