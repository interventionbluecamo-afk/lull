import CoreGraphics
import Foundation

struct ToyPhysicsProfile {
    let hitScale: CGFloat
    let extraHitPadding: CGFloat
    let touchScale: CGFloat
    let settleDuration: TimeInterval
    let maxReleaseVelocity: CGFloat
    let driftDamping: CGFloat

    static let bubble = ToyPhysicsProfile(
        hitScale: 1.55,
        extraHitPadding: 28,
        touchScale: 0.86,
        settleDuration: WarmShelfMotion.pop,
        maxReleaseVelocity: 260,
        driftDamping: 0.72
    )

    static let rareBubble = ToyPhysicsProfile(
        hitScale: 1.34,
        extraHitPadding: 14,
        touchScale: 0.84,
        settleDuration: WarmShelfMotion.pop,
        maxReleaseVelocity: 220,
        driftDamping: 0.78
    )

    static let shelfCard = ToyPhysicsProfile(
        hitScale: 1.08,
        extraHitPadding: 18,
        touchScale: 0.93,   // a deeper, more physical press-in before the toy lifts open
        settleDuration: WarmShelfMotion.settle,
        maxReleaseVelocity: 180,
        driftDamping: 0.86
    )

    static let softDrag = ToyPhysicsProfile(
        hitScale: 1.42,
        extraHitPadding: 34,
        touchScale: 1.035,
        settleDuration: WarmShelfMotion.settle,
        maxReleaseVelocity: 240,
        driftDamping: 0.82
    )
}

