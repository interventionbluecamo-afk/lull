import SpriteKit

enum ParticleManager {
    static func bubblePop(
        in scene: SKScene,
        at position: CGPoint,
        radius: CGFloat,
        primaryColor: UIColor,
        secondaryColor: UIColor,
        isRare: Bool
    ) {
        let profile = BubblePopProfile(radius: radius, isRare: isRare)
        let startAngle = CGFloat.random(in: 0...(.pi * 2))

        for index in 0..<profile.count {
            let moteRadius = CGFloat.random(in: profile.moteRadius)
            let moteSize = CGSize(
                width: moteRadius * CGFloat.random(in: 1.0...profile.stretch),
                height: moteRadius * CGFloat.random(in: 0.82...1.16)
            )
            let mote = SKShapeNode(ellipseOf: moteSize)
            let color = index.isMultiple(of: 3) ? secondaryColor : primaryColor
            mote.fillColor = color.withAlpha(CGFloat.random(in: profile.alpha))
            mote.strokeColor = .clear
            mote.position = position
            mote.zRotation = CGFloat.random(in: -0.45...0.45)
            mote.zPosition = 82
            scene.addChild(mote)

            let angle = startAngle + (CGFloat(index) / CGFloat(profile.count)) * .pi * 2 + CGFloat.random(in: -profile.angleJitter...profile.angleJitter)
            let distance = CGFloat.random(in: profile.distance)
            let move = SKAction.moveBy(
                x: cos(angle) * distance,
                y: sin(angle) * distance + profile.lift,
                duration: profile.duration
            )
            let fade = SKAction.fadeOut(withDuration: profile.duration)
            let scale = SKAction.scale(to: CGFloat.random(in: 0.12...0.28), duration: profile.duration)
            move.timingMode = .easeOut
            mote.run(.sequence([.group([move, fade, scale]), .removeFromParent()]))
        }
    }

    static func softBurst(in scene: SKScene, at position: CGPoint, color: UIColor, count: Int = 9) {
        let safeCount = max(1, count)
        for index in 0..<safeCount {
            let radius = CGFloat.random(in: 2.5...6.5)
            let mote = SKShapeNode(circleOfRadius: radius)
            mote.fillColor = color.withAlpha(.random(in: 0.35...0.7))
            mote.strokeColor = .clear
            mote.position = position
            mote.zPosition = 80
            scene.addChild(mote)

            let angle = (CGFloat(index) / CGFloat(safeCount)) * .pi * 2 + CGFloat.random(in: -0.22...0.22)
            let distance = CGFloat.random(in: 22...56)
            let move = SKAction.moveBy(x: cos(angle) * distance, y: sin(angle) * distance + 8, duration: WarmShelfMotion.emptyTap)
            let fade = SKAction.fadeOut(withDuration: WarmShelfMotion.emptyTap)
            let scale = SKAction.scale(to: 0.2, duration: WarmShelfMotion.emptyTap)
            move.timingMode = .easeOut
            mote.run(.sequence([.group([move, fade, scale]), .removeFromParent()]))
        }
    }

    static func celebrate(in scene: SKScene, at position: CGPoint, intensity: CGFloat = 1.0) {
        let clamped = max(0.4, min(1.8, intensity))
        let colors = [
            WarmShelfPalette.butter,
            WarmShelfPalette.petal,
            WarmShelfPalette.waterBlue,
            WarmShelfPalette.sage,
            WarmShelfPalette.paperHighlight
        ]

        for (index, color) in colors.enumerated() {
            let offset = CGPoint(
                x: position.x + CGFloat.random(in: -14...14) * clamped,
                y: position.y + CGFloat.random(in: -6...12) * clamped
            )
            softBurst(in: scene, at: offset, color: color, count: Int(CGFloat(4 + index) * clamped))
        }
    }

    static func softRipple(in scene: SKScene, at position: CGPoint, color: UIColor = WarmShelfPalette.waterBlue) {
        let ripple = SKShapeNode(circleOfRadius: 8)
        ripple.position = position
        ripple.strokeColor = color.withAlpha(0.34)
        ripple.lineWidth = 2
        ripple.fillColor = .clear
        ripple.zPosition = 60
        scene.addChild(ripple)

        let grow = SKAction.scale(to: 2.8, duration: WarmShelfMotion.emptyTap)
        let fade = SKAction.fadeOut(withDuration: WarmShelfMotion.emptyTap)
        grow.timingMode = .easeOut
        ripple.run(.sequence([.group([grow, fade]), .removeFromParent()]))
    }

    static func ambientMote(in scene: SKScene, bounds: CGRect) {
        guard bounds.width > 0, bounds.height > 0 else { return }

        let radius = CGFloat.random(in: 1.5...3.2)
        let mote = SKShapeNode(circleOfRadius: radius)
        mote.fillColor = WarmShelfPalette.paperHighlight.withAlpha(.random(in: 0.22...0.48))
        mote.strokeColor = .clear
        mote.position = CGPoint(
            x: CGFloat.random(in: bounds.minX...bounds.maxX),
            y: CGFloat.random(in: bounds.minY...bounds.maxY)
        )
        mote.zPosition = 5
        scene.addChild(mote)

        let drift = SKAction.moveBy(
            x: CGFloat.random(in: -18...18),
            y: CGFloat.random(in: 24...58),
            duration: .random(in: 5.0...8.5)
        )
        let fade = SKAction.fadeOut(withDuration: 1.4)
        drift.timingMode = .easeInEaseOut
        mote.run(.sequence([drift, fade, .removeFromParent()]))
    }
}

private struct BubblePopProfile {
    let count: Int
    let moteRadius: ClosedRange<CGFloat>
    let distance: ClosedRange<CGFloat>
    let duration: TimeInterval
    let lift: CGFloat
    let alpha: ClosedRange<CGFloat>
    let angleJitter: CGFloat
    let stretch: CGFloat

    init(radius: CGFloat, isRare: Bool) {
        switch radius {
        case ..<48:
            count = isRare ? 9 : 6
            moteRadius = 2.0...4.8
            distance = 18...42
            duration = 0.30
            lift = 4
            alpha = 0.42...0.72
            angleJitter = 0.34
            stretch = 1.22
        case 48..<76:
            count = isRare ? 13 : 9
            moteRadius = 2.8...6.8
            distance = 26...62
            duration = WarmShelfMotion.emptyTap
            lift = 9
            alpha = 0.38...0.68
            angleJitter = 0.26
            stretch = 1.34
        default:
            count = isRare ? 18 : 14
            moteRadius = 4.2...9.5
            distance = 40...92
            duration = 0.58
            lift = 16
            alpha = 0.32...0.62
            angleJitter = 0.20
            stretch = 1.55
        }
    }
}
