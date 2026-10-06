# Lull: Release Readiness Checklist

## Current Blockers

- [ ] Repair the local Xcode installation so `LaunchScreen.storyboard` and the asset
  catalog compile without the "iOS 18.2 Platform Not Installed" or missing simulator
  runtime errors.
- [ ] Build and launch on a physical iPhone.
- [ ] Build and launch on a physical iPad.
- [ ] Complete the five-child and five-parent proof gate.

## Kids Category Hard Stops

- [ ] Every external link, support action, purchase, and restore action remains behind
  the parental gate.
- [ ] The child shelf contains no locks, prices, upgrade prompts, links, or purchase
  teases.
- [ ] The app contains no behavioral ads, third-party analytics, tracking identifiers,
  accounts, or unnecessary child data collection.
- [ ] A public privacy-policy URL accurately states the shipped app's data practices.
- [ ] A working support URL or support email is available to parents.
- [ ] App Store Connect privacy answers match the binary and privacy manifest.
- [ ] Age rating, Kids Category age band, screenshots, and description make only claims
  already true in the shipping build.

Why: any mismatch between the parent promise, metadata, and binary risks rejection and
breaks trust.

## Purchase Trust

- [ ] A StoreKit test configuration covers the lifetime product.
- [ ] Purchase success unlocks the full toybox after relaunch.
- [ ] Pending, cancelled, unavailable, and failed purchases show calm parent-facing
  messages and never change the child shelf unexpectedly.
- [ ] Restore works on a clean install and after relaunch.
- [ ] Legacy annual entitlement remains recognized without being sold.
- [ ] The lifetime price is validated with parents before final submission.

## Child Experience

- [ ] A child can enter every visible shelf toy.
- [ ] No core action requires spoken or written instruction.
- [ ] Meaningful child-created state survives rotation.
- [ ] Two-handed and accidental-second-finger input does not break play.
- [ ] No object becomes unreachable or falls permanently outside the play area.
- [ ] No toy contains a timer, score, streak, fail state, or manipulative reward loop.
- [ ] Reduce Motion, sound-off, and haptics-off still leave cause and effect legible.

## Device Matrix

- [ ] Small supported iPhone, portrait and landscape.
- [ ] Current-size iPhone, portrait and landscape.
- [ ] Standard iPad, portrait and landscape.
- [ ] At least one older supported physical device.
- [ ] Background/foreground, interruption, rotation, and relaunch smoke tests.
- [ ] Stable frame pacing during the busiest Stack, Bubbles, Feed, and Bloom moments.

## Release Confidence

- [ ] Unit tests cover shelf access, entitlements, and time-of-day behavior.
- [ ] UI smoke tests cover onboarding, shelf entry, parent gate, purchase, restore, and
  relaunch.
- [ ] Custom SpriteKit controls have reliable VoiceOver activation behavior.
- [ ] No crash, hang, missing asset, clipped control, or broken sound appears in the
  final device matrix.
- [ ] The final App Store build is archived and validated through Xcode.
