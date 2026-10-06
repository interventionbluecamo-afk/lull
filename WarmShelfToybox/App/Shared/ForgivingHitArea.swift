import CoreGraphics

enum ForgivingHitArea {
    static func contains(localPoint: CGPoint, radius: CGFloat, profile: ToyPhysicsProfile) -> Bool {
        let hitRadius = max(radius * profile.hitScale, radius + profile.extraHitPadding)
        return hypot(localPoint.x, localPoint.y) <= hitRadius
    }

    static func contains(localPoint: CGPoint, size: CGSize, profile: ToyPhysicsProfile) -> Bool {
        let hitSize = CGSize(
            width: max(size.width * profile.hitScale, size.width + profile.extraHitPadding * 2),
            height: max(size.height * profile.hitScale, size.height + profile.extraHitPadding * 2)
        )
        return CGRect(
            x: -hitSize.width / 2,
            y: -hitSize.height / 2,
            width: hitSize.width,
            height: hitSize.height
        ).contains(localPoint)
    }

    static func clampedReleaseVelocity(_ velocity: CGVector, profile: ToyPhysicsProfile) -> CGVector {
        let magnitude = hypot(velocity.dx, velocity.dy)
        guard magnitude > profile.maxReleaseVelocity, magnitude > 0 else { return velocity }

        let scale = profile.maxReleaseVelocity / magnitude
        return CGVector(dx: velocity.dx * scale, dy: velocity.dy * scale)
    }
}
