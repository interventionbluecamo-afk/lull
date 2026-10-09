import SpriteKit

/// A surprise a bubble can carry — a tiny clay treasure drifting inside that, when the
/// bubble pops, flutters down and settles on the sill (NorthStar's Bubbles spec).
enum BubbleCargo: CaseIterable { case leaf, star, petal, seed }

final class BubbleNode: SKNode {
    let radius: CGFloat
    let style: BubbleStyle
    let cargo: BubbleCargo?
    var hasPopped = false
    var onPopped: (() -> Void)?
    var isRare: Bool { style.isRare }
    var isMotherBubble: Bool { style.isMother }
    private let shellLayer = SKNode()

    init(radius: CGFloat, style: BubbleStyle = .pearl, cargo: BubbleCargo? = nil) {
        self.radius = radius
        self.style = style
        self.cargo = cargo
        super.init()
        name = "bubble"
        isUserInteractionEnabled = false
        buildBubble()
    }

    convenience init(radius: CGFloat, isRare: Bool) {
        self.init(radius: radius, style: isRare ? .lavender : .pearl)
    }

    /// Build the tiny treasure for a given cargo kind, ~one-third the bubble's size.
    /// Used both inside the bubble and (handed to the scene) for the settled object.
    static func makeCargoNode(_ kind: BubbleCargo, scale: CGFloat) -> SKNode {
        let node = SKNode()
        switch kind {
        case .leaf:
            let leaf = SKShapeNode(ellipseOf: CGSize(width: 13 * scale, height: 7.5 * scale))
            leaf.fillColor = WarmShelfPalette.sage.withAlpha(0.9); leaf.strokeColor = .clear
            leaf.zRotation = 0.5; node.addChild(leaf)
            let vein = SKShapeNode(rect: CGRect(x: -6 * scale, y: -0.5 * scale, width: 12 * scale, height: 1 * scale))
            vein.fillColor = WarmShelfPalette.cocoa.withAlpha(0.18); vein.strokeColor = .clear
            vein.zRotation = 0.5; node.addChild(vein)
        case .star:
            node.addChild(makeStar(points: 5, outer: 8 * scale, inner: 3.4 * scale, color: WarmShelfPalette.butter))
            let glint = SKShapeNode(circleOfRadius: 1.6 * scale)
            glint.fillColor = .white.withAlpha(0.7); glint.strokeColor = .clear
            glint.position = CGPoint(x: -1.6 * scale, y: 1.6 * scale); node.addChild(glint)
        case .petal:
            let petal = SKShapeNode(ellipseOf: CGSize(width: 9 * scale, height: 13 * scale))
            petal.fillColor = WarmShelfPalette.petal.withAlpha(0.92); petal.strokeColor = .clear
            node.addChild(petal)
        case .seed:
            let seed = SKShapeNode(ellipseOf: CGSize(width: 8 * scale, height: 11 * scale))
            seed.fillColor = WarmShelfPalette.sand.withAlpha(0.95); seed.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.12)
            seed.lineWidth = 1; node.addChild(seed)
        }
        return node
    }

    private static func makeStar(points: Int, outer: CGFloat, inner: CGFloat, color: UIColor) -> SKShapeNode {
        let path = CGMutablePath()
        for i in 0..<(points * 2) {
            let r = i.isMultiple(of: 2) ? outer : inner
            let a = CGFloat(i) / CGFloat(points * 2) * .pi * 2 - .pi / 2
            let p = CGPoint(x: cos(a) * r, y: sin(a) * r)
            i == 0 ? path.move(to: p) : path.addLine(to: p)
        }
        path.closeSubpath()
        let star = SKShapeNode(path: path)
        star.fillColor = color.withAlpha(0.95); star.strokeColor = .clear
        return star
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func containsScenePoint(_ point: CGPoint) -> Bool {
        guard let scene else { return false }

        let localPoint = convert(point, from: scene)
        let profile = isRare ? ToyPhysicsProfile.rareBubble : ToyPhysicsProfile.bubble
        return ForgivingHitArea.contains(localPoint: localPoint, radius: radius * 1.45, profile: profile)
    }

    private func buildBubble() {
        addChild(shellLayer)

        let outerGlow = SKShapeNode(circleOfRadius: radius * 1.04)
        outerGlow.fillColor = style.glowColor.withAlpha(style.glowAlpha)
        outerGlow.strokeColor = style.rimColor.withAlpha(style.isMother ? 0.42 : (isRare ? 0.28 : 0.22))
        outerGlow.lineWidth = max(1.5, radius * 0.028)
        outerGlow.zPosition = 0
        shellLayer.addChild(outerGlow)

        let body = SKShapeNode(circleOfRadius: radius)
        body.fillColor = style.bodyColor.withAlpha(style.bodyAlpha)
        body.strokeColor = style.rimColor.withAlpha(style.rimAlpha)
        body.lineWidth = max(style.isMother ? 3.2 : 2.4, radius * (style.isMother ? 0.060 : 0.052))
        body.zPosition = 1
        shellLayer.addChild(body)

        let upperVeil = SKShapeNode(ellipseOf: CGSize(width: radius * 1.42, height: radius * 0.90))
        upperVeil.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.055)
        upperVeil.strokeColor = .clear
        upperVeil.position = CGPoint(x: -radius * 0.08, y: radius * 0.20)
        upperVeil.zPosition = 1.4
        shellLayer.addChild(upperVeil)

        let lowerTint = SKShapeNode(ellipseOf: CGSize(width: radius * 1.24, height: radius * 0.62))
        lowerTint.fillColor = style.rimColor.withAlpha(0.052)
        lowerTint.strokeColor = .clear
        lowerTint.position = CGPoint(x: radius * 0.08, y: -radius * 0.30)
        lowerTint.zPosition = 1.45
        shellLayer.addChild(lowerTint)

        let blush = SKShapeNode(circleOfRadius: radius * 0.92)
        blush.fillColor = .clear
        blush.strokeColor = WarmShelfPalette.blushIridescence.withAlpha(style.shimmerAlpha)
        blush.lineWidth = max(1.2, radius * 0.024)
        blush.zPosition = 2
        shellLayer.addChild(blush)

        let highlight = SKShapeNode(ellipseOf: CGSize(width: radius * 0.48, height: radius * 0.26))
        highlight.fillColor = WarmShelfPalette.bubbleHighlight.withAlpha(0.78)
        highlight.strokeColor = .clear
        highlight.position = CGPoint(x: -radius * 0.28, y: radius * 0.32)
        highlight.zRotation = 0.42
        highlight.zPosition = 3
        shellLayer.addChild(highlight)

        let tinyHighlight = SKShapeNode(circleOfRadius: max(2, radius * 0.08))
        tinyHighlight.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.62)
        tinyHighlight.strokeColor = .clear
        tinyHighlight.position = CGPoint(x: radius * 0.23, y: radius * 0.18)
        tinyHighlight.zPosition = 3
        shellLayer.addChild(tinyHighlight)

        // A cargo bubble carries a tiny treasure that drifts and turns gently inside it,
        // glimpsed through the film — the "oh, what's in that one?" surprise.
        if let cargo {
            let treasure = BubbleNode.makeCargoNode(cargo, scale: radius / 46)
            treasure.alpha = 0.82
            treasure.zPosition = 2.5   // inside the film, under the highlights
            shellLayer.addChild(treasure)
            if !AmbientAnimator.reduceMotion {
                treasure.run(.repeatForever(.sequence([
                    .group([.moveBy(x: radius * 0.10, y: radius * 0.06, duration: 1.8),
                            .rotate(byAngle: 0.5, duration: 1.8)]),
                    .group([.moveBy(x: -radius * 0.10, y: -radius * 0.06, duration: 2.1),
                            .rotate(byAngle: -0.5, duration: 2.1)])
                ])))
            }
        }
    }

    /// A nearby pop visibly presses through the bubble before it follows. The short
    /// anticipation makes a chain reaction read as physical cause-and-effect.
    func receivePressureWave(from scenePoint: CGPoint) {
        guard !hasPopped, !AmbientAnimator.reduceMotion, let scene else { return }
        // Silent: the pop that follows is the sound (a chime per neighbour stacked up in chains).
        let source = convert(scenePoint, from: scene)
        let length = max(1, hypot(source.x, source.y))
        let away = CGPoint(x: -source.x / length * 4, y: -source.y / length * 4)
        let horizontal = abs(source.x) > abs(source.y)

        shellLayer.removeAction(forKey: "pressureWave")
        let press = SKAction.group([
            .move(to: away, duration: 0.055),
            .scaleX(to: horizontal ? 0.92 : 1.07, y: horizontal ? 1.07 : 0.92, duration: 0.055)
        ])
        let rebound = SKAction.group([
            .move(to: .zero, duration: 0.075),
            .scaleX(to: horizontal ? 1.045 : 0.97, y: horizontal ? 0.97 : 1.045, duration: 0.075)
        ])
        let settle = SKAction.scale(to: 1.0, duration: 0.09)
        press.timingMode = .easeOut
        rebound.timingMode = .easeOut
        settle.timingMode = .easeInEaseOut
        shellLayer.run(.sequence([press, rebound, settle]), withKey: "pressureWave")
    }

    func pop(in scene: SKScene) -> Bool {
        guard !hasPopped else { return false }
        hasPopped = true
        onPopped?()
        onPopped = nil
        removeAllActions()

        let popPoint = convert(CGPoint.zero, to: scene)
        // Play audio/haptic immediately — instant confirmation of intent.
        AudioManager.shared.playBubblePop(size: radius, isRare: isRare)
        HapticsManager.shared.bubblePop(size: radius, isRare: isRare)

        // The actual pop visuals, fired after the squash frame.
        let fireVisuals = { [weak self, weak scene] in
            guard let self, let scene else { return }
            self.alpha = 0
            TouchFeedbackAnimator.bubblePopRing(in: scene, at: popPoint, radius: self.radius, color: self.style.popColor)
            ParticleManager.bubblePop(
                in: scene,
                at: popPoint,
                radius: self.radius,
                primaryColor: self.style.popColor,
                secondaryColor: self.style.secondaryPopColor,
                isRare: self.isRare
            )
            if self.isRare {
                ParticleManager.softBurst(in: scene, at: popPoint, color: WarmShelfPalette.paperHighlight, count: 14)
                ParticleManager.softBurst(in: scene, at: popPoint, color: self.style.secondaryPopColor, count: 10)
                let ring = SKShapeNode(circleOfRadius: self.radius * 0.22)
                ring.fillColor = .clear
                ring.strokeColor = self.style.secondaryPopColor.withAlpha(0.62)
                ring.lineWidth = max(2, self.radius * 0.035)
                ring.position = popPoint
                ring.zPosition = 92
                scene.addChild(ring)
                let expand = SKAction.scale(to: 2.1, duration: 0.46); expand.timingMode = .easeOut
                ring.run(.sequence([.group([expand, .fadeOut(withDuration: 0.46)]), .removeFromParent()]))
            }
            self.removeFromParent()
        }

        if !AmbientAnimator.reduceMotion {
            // 48ms squash into the pop — makes it feel physical, like pressing a real bubble.
            let squash = SKAction.group([
                .scaleX(to: 1.24, duration: 0.048),
                .scaleY(to: 0.78, duration: 0.048)
            ])
            squash.timingMode = .easeOut
            shellLayer.run(.sequence([squash, .run(fireVisuals)]))
        } else {
            fireVisuals()
        }
        return true
    }
}
