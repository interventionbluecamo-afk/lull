import SpriteKit
import UIKit

enum AmbientAnimator {
    /// When a calmer experience is requested, ambient motion is CALMED, not frozen.
    /// Reduce Motion exists for vestibular comfort — large drifts, parallax, and
    /// celebration effects stay fully gated at their call sites — but a creature that
    /// stops breathing isn't calmer, it's dead, and "alive before touch" is the brand.
    /// The shared primitives therefore survive at reduced amplitude and slower tempo.
    static var reduceMotion: Bool {
        UIAccessibility.isReduceMotionEnabled || LullDemoState.shared.isReducedMotion
    }

    /// Amplitude multiplier for the surviving primitives under Reduce Motion.
    private static var calmAmplitude: CGFloat { reduceMotion ? 0.45 : 1.0 }
    /// Tempo multiplier — calmer also means slower, never twitchier.
    private static var calmTempo: TimeInterval { reduceMotion ? 1.4 : 1.0 }

    static func breathe(
        node: SKNode,
        scale: CGFloat = 1.025,
        duration: TimeInterval = 4.8,
        delay: TimeInterval = .random(in: 0...1.3)
    ) {
        let breathScale = 1.0 + (scale - 1.0) * calmAmplitude
        let half = duration * calmTempo * 0.5
        let up = SKAction.scale(to: breathScale, duration: half)
        let down = SKAction.scale(to: 1.0, duration: half)
        up.timingMode = .easeInEaseOut
        down.timingMode = .easeInEaseOut
        node.run(.sequence([.wait(forDuration: delay), .repeatForever(.sequence([up, down]))]))
    }

    static func idleDrift(
        node: SKNode,
        x: CGFloat = 10,
        y: CGFloat = 8,
        duration: TimeInterval = 5.5,
        delay: TimeInterval = .random(in: 0...1.5)
    ) {
        // Positional drift is the most vestibular of the primitives — it survives, but
        // at a third of its travel and slower, so the world floats rather than swims.
        let x = x * (reduceMotion ? 0.35 : 1.0)
        let y = y * (reduceMotion ? 0.35 : 1.0)
        let duration = duration * calmTempo
        node.removeAction(forKey: "ambientIdleDrift")
        node.removeAction(forKey: "ambientIdleDriftLoop")

        let captureAnchor = SKAction.run { [weak node] in
            guard let node else { return }
            let anchor = node.position
            let first = SKAction.move(to: CGPoint(x: anchor.x + x, y: anchor.y + y), duration: duration * 0.5)
            let second = SKAction.move(to: anchor, duration: duration * 0.5)
            first.timingMode = .easeInEaseOut
            second.timingMode = .easeInEaseOut
            node.run(.repeatForever(.sequence([first, second])), withKey: "ambientIdleDriftLoop")
        }

        node.run(.sequence([.wait(forDuration: delay), captureAnchor]), withKey: "ambientIdleDrift")
    }

    static func gentleFloatUp(node: SKNode, distance: CGFloat, duration: TimeInterval) {
        let move = SKAction.moveBy(x: CGFloat.random(in: -24...24), y: distance, duration: duration)
        move.timingMode = .easeInEaseOut
        node.run(move)
    }

    static func wobble(node: SKNode, amount: CGFloat = 0.08, duration: TimeInterval = 2.6) {
        let amount = amount * calmAmplitude
        let duration = duration * calmTempo
        let left = SKAction.rotate(toAngle: -amount, duration: duration * 0.5, shortestUnitArc: true)
        let right = SKAction.rotate(toAngle: amount, duration: duration, shortestUnitArc: true)
        let center = SKAction.rotate(toAngle: 0, duration: duration * 0.5, shortestUnitArc: true)
        left.timingMode = .easeInEaseOut
        right.timingMode = .easeInEaseOut
        center.timingMode = .easeInEaseOut
        node.run(.repeatForever(.sequence([left, right, center])))
    }

    static func touchPulse(node: SKNode, scale: CGFloat = 0.96) {
        node.removeAction(forKey: "touchPulse")
        let down = SKAction.scale(to: scale, duration: WarmShelfMotion.instantTouch)
        let up = SKAction.scale(to: 1.0, duration: WarmShelfMotion.touchReturn)
        down.timingMode = .easeOut
        up.timingMode = .easeInEaseOut
        node.run(.sequence([down, up]), withKey: "touchPulse")
    }
}
