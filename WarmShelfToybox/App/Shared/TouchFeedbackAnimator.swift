import SpriteKit
import UIKit
import AVFoundation

enum TouchFeedbackAnimator {
    /// True when a touch can't be heard (sound off, or system volume at zero) AND can't
    /// be felt (haptics off, or an iPad — no Taptic Engine). The muted-restaurant iPad
    /// is the most common toddler context there is; when it happens, the eyes carry the
    /// entire acknowledgment, so every visual beat below leans in a little.
    static var eyesCarryFeedback: Bool {
        let heard = AudioManager.shared.isEnabled
            && AVAudioSession.sharedInstance().outputVolume > 0.05
        let felt = HapticsManager.shared.isEnabled
            && UIDevice.current.userInterfaceIdiom == .phone
        return !heard && !felt
    }

    /// Multiplier for spark counts, ring presence, and compression depth in silent mode.
    private static var silentBoost: CGFloat { eyesCarryFeedback ? 1.35 : 1.0 }

    static func tactileSpark(
        in scene: SKScene,
        at position: CGPoint,
        color: UIColor,
        count: Int = 4,
        includesRipple: Bool = true
    ) {
        let count = Int((CGFloat(count) * silentBoost).rounded())
        if includesRipple || eyesCarryFeedback {
            ParticleManager.softRipple(in: scene, at: position, color: color)
        }

        ParticleManager.softBurst(
            in: scene,
            at: position,
            color: color.withAlpha(0.72),
            count: count
        )

        if count > 2 {
            ParticleManager.softBurst(
                in: scene,
                at: position,
                color: WarmShelfPalette.paperHighlight,
                count: max(1, count / 2)
            )
        }
    }

    static func acknowledge(node: SKNode, profile: ToyPhysicsProfile) {
        node.removeAction(forKey: "touchAcknowledge")

        // Deepen the compression slightly when the squash is the only answer the child gets.
        let compression = 1.0 - (1.0 - profile.touchScale) * silentBoost
        let down = SKAction.scale(to: compression, duration: WarmShelfMotion.instantTouch)
        let up = SKAction.scale(to: 1.0, duration: WarmShelfMotion.touchReturn)
        down.timingMode = .easeOut
        up.timingMode = .easeInEaseOut

        node.run(.sequence([down, up]), withKey: "touchAcknowledge")
    }

    static func softSettle(node: SKNode, to position: CGPoint? = nil, profile: ToyPhysicsProfile) {
        node.removeAction(forKey: "softSettle")

        var actions: [SKAction] = []
        if let position {
            let move = SKAction.move(to: position, duration: profile.settleDuration)
            move.timingMode = .easeOut
            actions.append(move)
        }

        let scale = SKAction.scale(to: 1.0, duration: profile.settleDuration)
        scale.timingMode = .easeInEaseOut
        actions.append(scale)

        node.run(.group(actions), withKey: "softSettle")
    }

    static func bubblePopRing(in scene: SKScene, at position: CGPoint, radius: CGFloat, color: UIColor) {
        let ring = SKShapeNode(circleOfRadius: radius * 0.82)
        ring.position = position
        ring.fillColor = .clear
        ring.strokeColor = color.withAlpha(eyesCarryFeedback ? 0.46 : 0.34)
        ring.lineWidth = max(1.5, radius * 0.028) * silentBoost
        ring.zPosition = 75
        scene.addChild(ring)

        let duration: TimeInterval = radius < 48 ? 0.13 : (radius > 76 ? 0.26 : WarmShelfMotion.pop)
        let scale: CGFloat = radius < 48 ? 1.14 : (radius > 76 ? 1.34 : 1.22)
        let expand = SKAction.scale(to: scale, duration: duration)
        let fade = SKAction.fadeOut(withDuration: duration)
        expand.timingMode = .easeOut
        ring.run(.sequence([.group([expand, fade]), .removeFromParent()]))
    }

    static func emptyTap(in scene: SKScene, at position: CGPoint) {
        ParticleManager.softRipple(in: scene, at: position)
        ParticleManager.softBurst(
            in: scene,
            at: position,
            color: WarmShelfPalette.paperHighlight,
            count: eyesCarryFeedback ? 4 : 3
        )
        AudioManager.shared.playEmptyTap()
        HapticsManager.shared.emptyTap()
    }
}
