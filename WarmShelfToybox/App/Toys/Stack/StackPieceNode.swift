import SpriteKit

enum StackPieceKind: CaseIterable {
    case pebble   // wide, flat-bottomed — stacks easily
    case loaf     // taller rounded block
    case bean     // small rounded
    case stone    // round — rolls a little, playful

    func bodySize(scale: CGFloat) -> CGSize {
        switch self {
        case .pebble: return CGSize(width: 116 * scale, height: 74 * scale)
        case .loaf:   return CGSize(width: 84 * scale, height: 92 * scale)
        case .bean:   return CGSize(width: 80 * scale, height: 64 * scale)
        case .stone:  return CGSize(width: 78 * scale, height: 78 * scale)
        }
    }

    var cornerFactor: CGFloat {
        switch self {
        case .pebble: return 0.42
        case .loaf:   return 0.40
        case .bean:   return 0.46
        case .stone:  return 0.5
        }
    }

    var isRound: Bool { self == .stone }
}

/// Lull's expression law in one object: a stacking stone that feels things.
/// It sleeps, wakes when lifted, looks where it's going, gasps as it falls,
/// beams when it lands, and goes dizzy when it tumbles.
enum StackExpression {
    case sleeping
    case awake
    case happy
    case surprised
}

final class StackPieceNode: SKNode {
    let kind: StackPieceKind
    let bodySize: CGSize
    let baseColor: UIColor
    let isSignatureHero: Bool

    private(set) var isAwake = false
    private(set) var isHeld = false
    private var expression: StackExpression = .sleeping

    private var faceLayer = SKNode()
    private var leftEye = SKNode()
    private var rightEye = SKNode()
    private var leftPupil: SKShapeNode!
    private var rightPupil: SKShapeNode!
    private var leftLid: SKShapeNode!
    private var rightLid: SKShapeNode!
    private var smile: SKShapeNode!
    private var openMouth: SKShapeNode!
    private var cheekLeft: SKShapeNode!
    private var cheekRight: SKShapeNode!
    private var glow: SKShapeNode!
    private var artLayer = SKNode()
    private var capstoneLayer: SKNode?
    private var capstoneHomePosition = CGPoint.zero
    private var capstoneHomeAngle: CGFloat = -0.12
    private var pupilRadius: CGFloat = 3

    /// One neutral wool surface shared by every shape and tinted by its palette color.
    /// Fibres are baked once; no per-piece grain nodes or per-frame rasterization.
    private static let feltTexture: SKTexture = {
        let side: CGFloat = 96
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        let image = renderer.image { context in
            let cg = context.cgContext
            UIColor(white: 0.96, alpha: 1).setFill()
            cg.fill(CGRect(x: 0, y: 0, width: side, height: side))
            let colors = [UIColor(white: 1, alpha: 1).cgColor,
                          UIColor(white: 0.96, alpha: 1).cgColor,
                          UIColor(white: 0.91, alpha: 1).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: colors, locations: [0, 0.56, 1]) {
                cg.drawRadialGradient(gradient,
                                      startCenter: CGPoint(x: side * 0.36, y: side * 0.30), startRadius: 0,
                                      endCenter: CGPoint(x: side * 0.5, y: side * 0.52), endRadius: side * 0.82,
                                      options: [.drawsAfterEndLocation])
            }
            var seed: UInt64 = 0x5F317A91
            func sample() -> CGFloat {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return CGFloat((seed >> 32) & 0xFFFF) / 65535
            }
            cg.setLineCap(.round)
            for index in 0..<340 {
                let point = CGPoint(x: sample() * side, y: sample() * side)
                let angle = sample() * .pi * 2
                let length = 0.7 + sample() * 2.6
                cg.setLineWidth(0.30 + sample() * 0.35)
                cg.setStrokeColor(UIColor(white: index.isMultiple(of: 3) ? 0.62 : 1,
                                          alpha: index.isMultiple(of: 3) ? 0.085 : 0.20).cgColor)
                cg.move(to: point)
                cg.addLine(to: CGPoint(x: point.x + cos(angle) * length,
                                      y: point.y + sin(angle) * length))
                cg.strokePath()
            }
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }()

    init(kind: StackPieceKind, color: UIColor, scale: CGFloat, isSignatureHero: Bool = false) {
        self.kind = kind
        self.baseColor = color
        self.isSignatureHero = isSignatureHero
        self.bodySize = kind.bodySize(scale: scale)
        super.init()
        name = isSignatureHero ? "stackHero" : "stackPiece"
        build()
        configurePhysics()
        apply(.sleeping, animated: false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        let radius = min(bodySize.width, bodySize.height) * kind.cornerFactor
        let rect = CGRect(x: -bodySize.width / 2, y: -bodySize.height / 2, width: bodySize.width, height: bodySize.height)

        // Shadow is cast on the ground by the scene (see StackScene.updateShadows),
        // so it stays flat and never rotates with the body.
        glow = SKShapeNode(rect: rect.insetBy(dx: -8, dy: -8), cornerRadius: radius + 8)
        glow.fillColor = WarmShelfPalette.butter.withAlpha(0.20)
        glow.alpha = 0
        glow.strokeColor = .clear
        glow.zPosition = -0.5
        addChild(glow)

        let body = SKShapeNode(rect: rect, cornerRadius: radius)
        body.fillColor = baseColor
        body.fillTexture = Self.feltTexture
        body.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.07)
        body.lineWidth = max(0.8, bodySize.width * 0.007)
        addChild(body)
        if isSignatureHero { buildSignatureDetails() }

        faceLayer.zPosition = 2
        addChild(faceLayer)

        let eyeSpacing = bodySize.width * 0.20
        let eyeY = bodySize.height * 0.04
        pupilRadius = max(2.5, bodySize.width * 0.030)
        let lidWidth = bodySize.width * 0.085

        for (index, eye) in [leftEye, rightEye].enumerated() {
            let side = index == 0 ? -1.0 : 1.0
            eye.position = CGPoint(x: CGFloat(side) * eyeSpacing, y: eyeY)
            faceLayer.addChild(eye)

            let pupil = SKShapeNode(circleOfRadius: pupilRadius)
            pupil.fillColor = WarmShelfPalette.cocoa.withAlpha(0.82)
            pupil.strokeColor = .clear
            eye.addChild(pupil)

            let glint = SKShapeNode(circleOfRadius: pupilRadius * 0.4)
            glint.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.85)
            glint.strokeColor = .clear
            glint.position = CGPoint(x: -pupilRadius * 0.3, y: pupilRadius * 0.35)
            pupil.addChild(glint)

            let lidPath = CGMutablePath()
            lidPath.move(to: CGPoint(x: -lidWidth, y: 0))
            lidPath.addQuadCurve(to: CGPoint(x: lidWidth, y: 0), control: CGPoint(x: 0, y: -lidWidth * 0.9))
            let lid = SKShapeNode(path: lidPath)
            lid.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.62)
            lid.lineWidth = max(2, bodySize.width * 0.018)
            lid.lineCap = .round
            lid.zPosition = 1
            eye.addChild(lid)

            if index == 0 { leftPupil = pupil; leftLid = lid } else { rightPupil = pupil; rightLid = lid }
        }

        for side in [-1.0, 1.0] {
            let cheek = SKShapeNode(circleOfRadius: bodySize.width * 0.05)
            cheek.fillColor = WarmShelfPalette.petal.withAlpha(0.45)
            cheek.strokeColor = .clear
            cheek.position = CGPoint(x: CGFloat(side) * bodySize.width * 0.30, y: -bodySize.height * 0.02)
            cheek.alpha = 0
            faceLayer.addChild(cheek)
            if side < 0 { cheekLeft = cheek } else { cheekRight = cheek }
        }

        let smilePath = CGMutablePath()
        let sw = bodySize.width * 0.10
        smilePath.move(to: CGPoint(x: -sw, y: 0))
        smilePath.addQuadCurve(to: CGPoint(x: sw, y: 0), control: CGPoint(x: 0, y: -sw * 0.8))
        smile = SKShapeNode(path: smilePath)
        smile.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.5)
        smile.lineWidth = max(2, bodySize.width * 0.016)
        smile.lineCap = .round
        smile.position = CGPoint(x: 0, y: -bodySize.height * 0.16)
        smile.alpha = 0
        faceLayer.addChild(smile)

        openMouth = SKShapeNode(ellipseOf: CGSize(width: bodySize.width * 0.12, height: bodySize.width * 0.15))
        openMouth.fillColor = WarmShelfPalette.cocoa.withAlpha(0.42)
        openMouth.strokeColor = .clear
        openMouth.position = CGPoint(x: 0, y: -bodySize.height * 0.17)
        openMouth.alpha = 0
        faceLayer.addChild(openMouth)

        // Keep the felt performance separate from the physics node. The body stays
        // exactly under the child's finger while its artwork anticipates and follows.
        let artwork = children
        for child in artwork {
            child.removeFromParent()
            artLayer.addChild(child)
        }
        addChild(artLayer)
    }

    private func buildClayDimples() {
        let marks: [(CGFloat, CGFloat, CGFloat)]
        switch kind {
        case .pebble:
            marks = [(-0.28, 0.22, 0.010), (0.31, -0.18, 0.013)]
        case .loaf:
            marks = [(-0.24, -0.22, 0.012), (0.26, 0.27, 0.009)]
        case .bean:
            marks = [(-0.24, 0.20, 0.011), (0.22, -0.22, 0.010)]
        case .stone:
            marks = [(-0.20, 0.26, 0.010), (0.27, -0.16, 0.012)]
        }

        for mark in marks {
            let dimple = SKShapeNode(circleOfRadius: max(0.7, bodySize.width * mark.2))
            dimple.fillColor = WarmShelfPalette.cocoa.withAlpha(0.065)
            dimple.strokeColor = .clear
            dimple.position = CGPoint(x: bodySize.width * mark.0, y: bodySize.height * mark.1)
            dimple.zPosition = 1.1
            addChild(dimple)
        }
    }

    /// The signature friend is identifiable before its face is readable: terracotta felt,
    /// a cream moon patch, and one tiny balancing stone. These are identity cues, not rewards.
    private func buildSignatureDetails() {
        let patchRadius = min(bodySize.width, bodySize.height) * 0.13
        let patch = SKShapeNode(circleOfRadius: patchRadius)
        patch.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.86)
        patch.strokeColor = .clear
        patch.position = CGPoint(x: -bodySize.width * 0.16, y: bodySize.height * 0.27)
        patch.zPosition = 1.2
        addChild(patch)

        let crescentCut = SKShapeNode(circleOfRadius: patchRadius * 0.92)
        crescentCut.fillColor = baseColor
        crescentCut.strokeColor = .clear
        crescentCut.position = CGPoint(x: patchRadius * 0.50, y: patchRadius * 0.16)
        crescentCut.zPosition = 0.1
        patch.addChild(crescentCut)

        let marks: [(CGFloat, CGFloat, CGFloat)] = [
            (-0.32, -0.22, 0.015),
            (0.29, 0.21, 0.012),
            (0.35, -0.25, 0.010),
            (-0.08, 0.34, 0.009)
        ]
        for mark in marks {
            let dimple = SKShapeNode(circleOfRadius: max(0.8, bodySize.width * mark.2))
            dimple.fillColor = WarmShelfPalette.cocoa.withAlpha(0.07)
            dimple.strokeColor = .clear
            dimple.position = CGPoint(x: bodySize.width * mark.0, y: bodySize.height * mark.1)
            dimple.zPosition = 1.1
            addChild(dimple)
        }

        let capstoneSize = CGSize(width: bodySize.width * 0.40, height: bodySize.height * 0.18)
        let capstoneRoot = SKNode()
        capstoneRoot.position = CGPoint(x: bodySize.width * 0.10, y: bodySize.height * 0.54)
        capstoneRoot.zRotation = -0.12
        capstoneRoot.zPosition = 1.5
        addChild(capstoneRoot)
        capstoneLayer = capstoneRoot
        capstoneHomePosition = capstoneRoot.position
        capstoneHomeAngle = capstoneRoot.zRotation

        do {
            let capstone = SKShapeNode(
                rectOf: capstoneSize,
                cornerRadius: capstoneSize.height * 0.48
            )
            capstone.fillColor = WarmShelfPalette.butter.withAlpha(0.96)
            capstone.fillTexture = Self.feltTexture
            capstone.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.10)
            capstone.lineWidth = max(0.8, bodySize.width * 0.008)
            capstoneRoot.addChild(capstone)

            for x in [-0.18, 0.18] {
                let dimple = SKShapeNode(circleOfRadius: max(0.7, bodySize.width * 0.012))
                dimple.fillColor = WarmShelfPalette.cocoa.withAlpha(0.10)
                dimple.strokeColor = .clear
                dimple.position = CGPoint(x: capstoneSize.width * CGFloat(x), y: -capstoneSize.height * 0.05)
                dimple.zPosition = 0.2
                capstoneRoot.addChild(dimple)
            }
        }
    }

    private static func stoneArt(for kind: StackPieceKind, bodySize: CGSize) -> SKSpriteNode? {
        let slot: String
        switch kind {
        case .pebble: slot = "stack-stone-large"
        case .loaf:   slot = "stack-stone-medium"
        case .bean:   slot = "stack-stone-small"
        case .stone:  slot = "stack-stone-medium"
        }
        guard let tex = ToyArt.texture(slot) else { return nil }
        // Stretched to the exact body silhouette so stacking contact feels true.
        let sprite = SKSpriteNode(texture: tex)
        sprite.size = bodySize
        return sprite
    }

    private func configurePhysics() {
        let body: SKPhysicsBody
        if kind.isRound {
            body = SKPhysicsBody(circleOfRadius: bodySize.width / 2)
        } else {
            body = SKPhysicsBody(rectangleOf: CGSize(width: bodySize.width * 0.94, height: bodySize.height * 0.94))
        }
        body.categoryBitMask = PhysicsCategory.block
        body.collisionBitMask = PhysicsCategory.block | PhysicsCategory.surface | PhysicsCategory.wall
        body.contactTestBitMask = 0
        body.friction = 0.99
        body.restitution = 0.0
        body.linearDamping = 0.92
        body.angularDamping = 0.98
        body.mass = 0.9
        body.allowsRotation = true
        physicsBody = body
    }

    // MARK: - Physics helpers

    var velocity: CGVector { physicsBody?.velocity ?? .zero }
    var speed2D: CGFloat { hypot(velocity.dx, velocity.dy) }
    var spin: CGFloat { abs(physicsBody?.angularVelocity ?? 0) }
    var topY: CGFloat { position.y + bodySize.height * 0.5 }
    var bottomY: CGFloat { position.y - bodySize.height * 0.5 }
    var halfWidth: CGFloat { bodySize.width * 0.5 }

    // MARK: - Expression law

    func apply(_ next: StackExpression, animated: Bool = true) {
        expression = next
        leftLid.setScale(1)
        rightLid.setScale(1)
        openMouth.setScale(1)
        let d = animated ? 0.18 : 0.0
        func set(_ node: SKShapeNode?, _ a: CGFloat) {
            node?.removeAction(forKey: "blink")
            node?.removeAction(forKey: "yawn")
            node?.run(.fadeAlpha(to: a, duration: d), withKey: "expression")
        }
        func eyeScale(_ scale: CGFloat) {
            for eye in [leftEye, rightEye] {
                eye.removeAction(forKey: "expressionScale")
                if AmbientAnimator.reduceMotion {
                    eye.setScale(1)
                } else {
                    eye.run(.scale(to: scale, duration: d), withKey: "expressionScale")
                }
            }
        }
        switch next {
        case .sleeping:
            set(leftLid, 1); set(rightLid, 1)
            set(leftPupil, 0); set(rightPupil, 0)
            set(smile, isSignatureHero ? 0.56 : 0)
            set(openMouth, 0)
            set(cheekLeft, isSignatureHero ? 0.38 : 0)
            set(cheekRight, isSignatureHero ? 0.38 : 0)
            eyeScale(1)
        case .awake:
            set(leftLid, 0); set(rightLid, 0)
            set(leftPupil, 1); set(rightPupil, 1)
            set(smile, 0.5); set(openMouth, 0); set(cheekLeft, 0); set(cheekRight, 0)
            eyeScale(1)
            lookToward(.zero)
        case .happy:
            set(leftLid, 0); set(rightLid, 0)
            set(leftPupil, 1); set(rightPupil, 1)
            set(smile, 1); set(openMouth, 0); set(cheekLeft, 0.9); set(cheekRight, 0.9)
            eyeScale(1.05)
        case .surprised:
            set(leftLid, 0); set(rightLid, 0)
            set(leftPupil, 1); set(rightPupil, 1)
            set(smile, 0); set(openMouth, 1); set(cheekLeft, 0); set(cheekRight, 0)
            eyeScale(1.3)
        }
    }

    /// Pupils drift toward a direction (e.g. the finger, or the way it's flying).
    func lookToward(_ direction: CGVector) {
        if AmbientAnimator.reduceMotion {
            leftPupil.removeAction(forKey: "look")
            rightPupil.removeAction(forKey: "look")
            leftPupil.removeAction(forKey: "dizzy")
            rightPupil.removeAction(forKey: "dizzy")
            leftPupil.position = .zero
            rightPupil.position = .zero
            return
        }
        let len = hypot(direction.dx, direction.dy)
        let limit = pupilRadius * 0.9
        let offset: CGPoint
        if len < 0.01 {
            offset = .zero
        } else {
            offset = CGPoint(x: direction.dx / len * limit, y: direction.dy / len * limit)
        }
        let move = SKAction.move(to: offset, duration: 0.12)
        move.timingMode = .easeOut
        leftPupil.run(move, withKey: "look")
        rightPupil.run(move, withKey: "look")
    }

    func blink() {
        guard expression != .sleeping else {
            // A sleepy flutter — lids dip and rise.
            guard !AmbientAnimator.reduceMotion else {
                leftLid.removeAction(forKey: "blink")
                rightLid.removeAction(forKey: "blink")
                leftLid.setScale(1)
                rightLid.setScale(1)
                return
            }
            let dip = SKAction.sequence([.scaleY(to: 0.7, duration: 0.12), .scaleY(to: 1, duration: 0.18)])
            leftLid.run(dip, withKey: "blink"); rightLid.run(dip, withKey: "blink")
            return
        }
        let blink = SKAction.sequence([
            .group([.fadeAlpha(to: 1, duration: 0.06)]),
            .group([.fadeAlpha(to: 0, duration: 0.1)])
        ])
        leftLid.run(blink, withKey: "blink"); rightLid.run(blink, withKey: "blink")
    }

    func yawn() {
        guard expression == .sleeping, !isHeld else { return }
        if AmbientAnimator.reduceMotion {
            cancelArtMotion()
            resetArtPose()
            openMouth.setScale(1)
            openMouth.run(.sequence([.fadeAlpha(to: 0.35, duration: 0.5), .fadeOut(withDuration: 0.4)]), withKey: "yawn")
            return
        }
        artLayer.removeAction(forKey: "pieceBreathe")
        let seq = SKAction.sequence([
            .group([.fadeAlpha(to: 0.5, duration: 0.5), .scale(to: 1.8, duration: 0.5)]),
            .group([.fadeAlpha(to: 0, duration: 0.4), .scale(to: 1.0, duration: 0.4)])
        ])
        openMouth.run(seq, withKey: "yawn")
        let squeeze = SKAction.sequence([.scaleX(to: 1.04, y: 0.96, duration: 0.5), .scale(to: 1.0, duration: 0.4)])
        artLayer.run(.sequence([squeeze, .run { [weak self] in
            guard let self, !self.isHeld, !self.isAwake else { return }
            self.breatheSleepily()
        }]), withKey: "yawn")
    }

    func dizzy() {
        guard !isHeld else { return }
        removeAction(forKey: "dizzyRecovery")
        removeAction(forKey: "calmDown")
        cancelArtMotion()
        resetArtPose()
        leftPupil.removeAction(forKey: "look")
        rightPupil.removeAction(forKey: "look")
        // A tumble leaves it briefly dizzy: pupils wobble, little stars orbit.
        apply(.surprised)
        guard !AmbientAnimator.reduceMotion else {
            scheduleRestFace(after: 0.45, key: "dizzyRecovery")
            return
        }
        let wobble = SKAction.sequence([
            .moveBy(x: pupilRadius, y: 0, duration: 0.08),
            .moveBy(x: -pupilRadius * 2, y: 0, duration: 0.16),
            .moveBy(x: pupilRadius, y: 0, duration: 0.08)
        ])
        leftPupil.run(.repeat(wobble, count: 2), withKey: "dizzy")
        rightPupil.run(.repeat(wobble, count: 2), withKey: "dizzy")
        for i in 0..<2 {
            let star = SKShapeNode(circleOfRadius: pupilRadius * 0.7)
            star.name = "stackDizzyStar"
            star.fillColor = WarmShelfPalette.butter.withAlpha(0.8)
            star.strokeColor = .clear
            star.zPosition = 5
            faceLayer.addChild(star)
            let center = CGPoint(x: 0, y: bodySize.height * 0.32)
            let r = bodySize.width * 0.18
            let orbit = SKAction.customAction(withDuration: 0.9) { node, t in
                let a = CGFloat(i) * .pi + t / 0.9 * .pi * 2
                node.position = CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r * 0.5)
            }
            star.run(.sequence([.group([orbit, .fadeOut(withDuration: 0.9)]), .removeFromParent()]))
        }
        scheduleRestFace(after: 0.9, key: "dizzyRecovery")
    }

    // MARK: - Lifecycle reactions

    private func resetArtPose() {
        artLayer.position = .zero
        artLayer.zRotation = 0
        artLayer.setScale(1)
        capstoneLayer?.position = capstoneHomePosition
        capstoneLayer?.zRotation = capstoneHomeAngle
    }

    private func cancelArtMotion() {
        for key in ["pieceBreathe", "awakeBreathe", "towerPulse", "wakePerformance",
                    "carryPose", "landingSquish", "liftAnticipation", "knockoverJoy",
                    "yawn", "sleepPose"] {
            artLayer.removeAction(forKey: key)
        }
        capstoneLayer?.removeAction(forKey: "capstoneCarry")
        capstoneLayer?.removeAction(forKey: "capstoneRebalance")
    }

    private func setGlow(awake: Bool) {
        glow.run(.fadeAlpha(to: awake ? 1 : 0, duration: awake ? 0.4 : 0.3), withKey: "pieceGlow")
    }

    private func scheduleRestFace(after delay: TimeInterval, key: String) {
        run(.sequence([.wait(forDuration: delay), .run { [weak self] in
            guard let self, !self.isHeld, self.speed2D < 8 else { return }
            self.apply(self.isAwake ? .happy : .sleeping)
            if self.isAwake { self.startAwakeBreathe() } else { self.breatheSleepily() }
        }]), withKey: key)
    }

    /// Cancel pending performances without changing the scene's placed/supply state.
    func stopFeedback() {
        for key in ["calmDown", "holdFace", "dizzyRecovery", "shelfInvitation", "straighten"] {
            removeAction(forKey: key)
        }
        cancelArtMotion()
        glow.removeAction(forKey: "pieceGlow")
        glow.alpha = isAwake ? 1 : 0
        let pupils: [SKShapeNode] = [leftPupil, rightPupil]
        for pupil in pupils {
            pupil.removeAction(forKey: "look")
            pupil.removeAction(forKey: "dizzy")
            pupil.position = .zero
        }
        faceLayer.children.filter { $0.name == "stackDizzyStar" }.forEach { $0.removeFromParent() }
        resetArtPose()
        apply(isHeld || isAwake ? .happy : .sleeping, animated: false)
        if !isHeld {
            if isAwake { startAwakeBreathe() } else { breatheSleepily() }
        }
    }

    func beginHold() {
        isHeld = true
        physicsBody?.isDynamic = false
        physicsBody?.velocity = .zero
        physicsBody?.angularVelocity = 0
        stopFeedback()
        apply(.surprised)
        rebalanceCapstone(intensity: 0.7)
        run(.sequence([.wait(forDuration: 0.16), .run { [weak self] in
            guard let self, self.isHeld else { return }
            self.apply(.happy)
        }]), withKey: "holdFace")

        guard !AmbientAnimator.reduceMotion else {
            resetArtPose()
            zRotation = 0
            return
        }

        let gather = SKAction.scaleX(to: 1.045, y: 0.94, duration: 0.055)
        let spring = SKAction.scaleX(to: 0.985, y: 1.075, duration: 0.105)
        let soften = SKAction.scale(to: 1.035, duration: 0.14)
        gather.timingMode = .easeIn
        spring.timingMode = .easeOut
        soften.timingMode = .easeInEaseOut
        artLayer.run(.sequence([gather, spring, soften]), withKey: "liftAnticipation")

        let straighten = SKAction.rotate(toAngle: 0, duration: 0.18, shortestUnitArc: true)
        straighten.timingMode = .easeOut
        run(straighten, withKey: "straighten")
    }

    /// The physics node tracks the finger exactly; the felt artwork leans and lags by a
    /// few points so carrying feels authored without introducing control latency.
    func poseForCarry(_ direction: CGVector) {
        guard isHeld else { return }
        guard !AmbientAnimator.reduceMotion else {
            cancelArtMotion()
            resetArtPose()
            return
        }
        let length = hypot(direction.dx, direction.dy)
        guard length > 0.5 else { return }

        let nx = direction.dx / length
        let ny = direction.dy / length
        let targetAngle = -nx * 0.095
        let targetPosition = CGPoint(x: -nx * 3.0, y: -ny * 1.8)
        let pose = SKAction.group([
            .rotate(toAngle: targetAngle, duration: 0.085, shortestUnitArc: true),
            .move(to: targetPosition, duration: 0.085)
        ])
        pose.timingMode = .easeOut
        artLayer.run(pose, withKey: "carryPose")

        if let capstoneLayer {
            let follow = SKAction.group([
                .rotate(toAngle: capstoneHomeAngle + nx * 0.075, duration: 0.12, shortestUnitArc: true),
                .move(to: CGPoint(
                    x: capstoneHomePosition.x - nx * 3.2,
                    y: capstoneHomePosition.y - max(0, ny) * 1.6
                ), duration: 0.12)
            ])
            follow.timingMode = .easeOut
            capstoneLayer.run(follow, withKey: "capstoneCarry")
        }
    }

    func endHold() {
        isHeld = false
        removeAction(forKey: "holdFace")
        artLayer.removeAction(forKey: "liftAnticipation")
        physicsBody?.isDynamic = true
        physicsBody?.velocity = .zero
        physicsBody?.angularVelocity = 0
        apply(.happy)

        guard !AmbientAnimator.reduceMotion else {
            cancelArtMotion()
            resetArtPose()
            return
        }

        let passCenter = SKAction.group([
            .rotate(toAngle: artLayer.zRotation * -0.22, duration: 0.11, shortestUnitArc: true),
            .move(to: CGPoint(x: artLayer.position.x * -0.12, y: 0), duration: 0.11),
            .scale(to: 1.015, duration: 0.11)
        ])
        let rest = SKAction.group([
            .rotate(toAngle: 0, duration: 0.20, shortestUnitArc: true),
            .move(to: .zero, duration: 0.20),
            .scale(to: 1.0, duration: 0.20)
        ])
        passCenter.timingMode = .easeOut
        rest.timingMode = .easeInEaseOut
        artLayer.run(.sequence([passCenter, rest]), withKey: "carryPose")
        rebalanceCapstone(intensity: 0.55)
    }

    func reactFalling() {
        guard !isHeld, expression != .surprised else { return }
        removeAction(forKey: "calmDown")
        removeAction(forKey: "dizzyRecovery")
        leftPupil.removeAction(forKey: "dizzy")
        rightPupil.removeAction(forKey: "dizzy")
        apply(.surprised)
        lookToward(CGVector(dx: 0, dy: -1))
    }

    func reactLanded(hard: Bool) {
        guard !isHeld else { return }
        removeAction(forKey: "dizzyRecovery")
        squish(intensity: hard ? 1.0 : 0.6)
        rebalanceCapstone(intensity: hard ? 1.0 : 0.55)
        apply(.happy)
        blink()
        scheduleRestFace(after: 1.6, key: "calmDown")
    }

    func reactToKnockover() {
        guard !isHeld else { return }
        removeAction(forKey: "calmDown")
        removeAction(forKey: "dizzyRecovery")
        cancelArtMotion()
        resetArtPose()
        apply(.happy)
        guard !AmbientAnimator.reduceMotion else {
            scheduleRestFace(after: 0.45, key: "calmDown")
            return
        }
        let open = SKAction.scaleX(to: 1.08, y: 1.04, duration: 0.11)
        let settle = SKAction.scale(to: 1.0, duration: 0.20)
        open.timingMode = .easeOut
        settle.timingMode = .easeInEaseOut
        artLayer.run(.sequence([open, settle, .run { [weak self] in
            guard let self, !self.isHeld else { return }
            if self.isAwake { self.startAwakeBreathe() } else { self.breatheSleepily() }
        }]), withKey: "knockoverJoy")
        rebalanceCapstone(intensity: 0.8)
        scheduleRestFace(after: 1.6, key: "calmDown")
    }

    func squish(intensity: CGFloat = 1.0) {
        guard !isHeld else { return }
        cancelArtMotion()
        guard !AmbientAnimator.reduceMotion else {
            resetArtPose()
            return
        }
        let amount = min(0.22, 0.10 + intensity * 0.10)
        let down = SKAction.scaleX(to: 1.0 + amount, y: 1.0 - amount, duration: 0.07)
        let rebound = SKAction.scaleX(to: 0.98, y: 1.05, duration: 0.10)
        let up = SKAction.scale(to: 1.0, duration: 0.16)
        down.timingMode = .easeOut
        rebound.timingMode = .easeOut
        up.timingMode = .easeInEaseOut
        artLayer.run(.sequence([down, rebound, up, .run { [weak self] in
            guard let self, !self.isHeld else { return }
            if self.isAwake { self.startAwakeBreathe() } else { self.breatheSleepily() }
        }]), withKey: "landingSquish")
    }

    func breatheSleepily(delay: TimeInterval = 0) {
        guard !isHeld, !isAwake, !AmbientAnimator.reduceMotion else { return }
        guard artLayer.action(forKey: "pieceBreathe") == nil else { return }
        let up = SKAction.scale(to: 1.015, duration: 1.9)
        let down = SKAction.scale(to: 1.0, duration: 1.9)
        up.timingMode = .easeInEaseOut
        down.timingMode = .easeInEaseOut
        artLayer.run(.sequence([.wait(forDuration: delay), .repeatForever(.sequence([up, down]))]), withKey: "pieceBreathe")
    }

    func wake() {
        guard !isAwake else { return }
        isAwake = true
        removeAction(forKey: "calmDown")
        removeAction(forKey: "dizzyRecovery")
        setGlow(awake: true)
        guard !isHeld else { return }
        cancelArtMotion()
        openMouth.removeAction(forKey: "yawn")
        resetArtPose()
        apply(.surprised)

        if AmbientAnimator.reduceMotion {
            apply(.happy)
        } else {
            let gather = SKAction.scaleX(to: 1.04, y: 0.94, duration: 0.08)
            let rise = SKAction.group([
                .scaleX(to: 0.98, y: 1.08, duration: 0.13),
                .moveBy(x: 0, y: 5, duration: 0.13)
            ])
            let notice = SKAction.run { [weak self] in
                guard let self, self.isAwake, !self.isHeld else { return }
                self.apply(.happy)
            }
            let rest = SKAction.group([
                .scale(to: 1.0, duration: 0.22),
                .move(to: .zero, duration: 0.22)
            ])
            gather.timingMode = .easeIn
            rise.timingMode = .easeOut
            rest.timingMode = .easeInEaseOut
            artLayer.run(.sequence([gather, rise, notice, rest]), withKey: "wakePerformance")
        }

        startAwakeBreathe(delay: AmbientAnimator.reduceMotion ? 0 : 0.46)
        rebalanceCapstone(intensity: 1.0)
    }

    /// A tower-wide breath makes the signature payoff feel caused by the stack instead
    /// of pasted on as particles.
    func playTowerPulse(delay: TimeInterval, isTop: Bool) {
        guard !isHeld else { return }
        cancelArtMotion()
        resetArtPose()
        apply(.happy)
        guard !AmbientAnimator.reduceMotion else { return }
        let gather = SKAction.scaleX(to: 1.025, y: 0.975, duration: 0.07)
        let lift = SKAction.scaleX(to: 0.985, y: isTop ? 1.075 : 1.045, duration: 0.10)
        let settle = SKAction.scale(to: 1.0, duration: 0.18)
        let resumeIdle = SKAction.run { [weak self] in
            guard let self, !self.isHeld else { return }
            if self.isAwake {
                self.startAwakeBreathe()
            } else {
                self.breatheSleepily()
            }
        }
        gather.timingMode = .easeIn
        lift.timingMode = .easeOut
        settle.timingMode = .easeInEaseOut
        artLayer.run(.sequence([.wait(forDuration: delay), gather, lift, settle, resumeIdle]), withKey: "towerPulse")
    }

    func performShelfInvitation(delay: TimeInterval) {
        guard isSignatureHero, !AmbientAnimator.reduceMotion else { return }
        run(.sequence([
            .wait(forDuration: delay),
            .run { [weak self] in
                guard let self, !self.isHeld, !self.isAwake else { return }
                self.apply(.happy)
                self.playTowerPulse(delay: 0, isTop: true)
            },
            .wait(forDuration: 0.72),
            .run { [weak self] in
                guard let self, !self.isHeld, !self.isAwake else { return }
                self.apply(.sleeping)
            },
            .wait(forDuration: 0.28),
            .run { [weak self] in self?.yawn() }
        ]), withKey: "shelfInvitation")
    }

    func sleep() {
        let needsSleep = isAwake || expression != .sleeping
        isAwake = false
        guard !isHeld else {
            setGlow(awake: false)
            return
        }
        guard needsSleep else { return }
        removeAction(forKey: "calmDown")
        removeAction(forKey: "dizzyRecovery")
        cancelArtMotion()
        apply(.sleeping)
        setGlow(awake: false)
        if AmbientAnimator.reduceMotion {
            resetArtPose()
        } else {
            let rest = SKAction.group([.scale(to: 1.0, duration: 0.2),
                                       .move(to: .zero, duration: 0.2),
                                       .rotate(toAngle: 0, duration: 0.2)])
            artLayer.run(rest, withKey: "sleepPose")
            breatheSleepily(delay: 0.2)
            rebalanceCapstone(intensity: 0.4)
        }
    }

    private func rebalanceCapstone(intensity: CGFloat) {
        guard let capstoneLayer else { return }
        guard !AmbientAnimator.reduceMotion else {
            capstoneLayer.removeAction(forKey: "capstoneCarry")
            capstoneLayer.removeAction(forKey: "capstoneRebalance")
            capstoneLayer.position = capstoneHomePosition
            capstoneLayer.zRotation = capstoneHomeAngle
            return
        }
        let amount = 0.07 * min(max(intensity, 0.4), 1.0)
        capstoneLayer.removeAction(forKey: "capstoneCarry")
        let tip = SKAction.rotate(toAngle: capstoneHomeAngle + amount, duration: 0.12, shortestUnitArc: true)
        let counterTip = SKAction.rotate(toAngle: capstoneHomeAngle - amount * 0.55, duration: 0.16, shortestUnitArc: true)
        let settle = SKAction.rotate(toAngle: capstoneHomeAngle, duration: 0.24, shortestUnitArc: true)
        let returnHome = SKAction.move(to: capstoneHomePosition, duration: 0.24)
        tip.timingMode = .easeOut
        counterTip.timingMode = .easeInEaseOut
        settle.timingMode = .easeInEaseOut
        returnHome.timingMode = .easeInEaseOut
        capstoneLayer.run(.group([.sequence([tip, counterTip, settle]), returnHome]), withKey: "capstoneRebalance")
    }

    private func startAwakeBreathe(delay: TimeInterval = 0) {
        guard isAwake, !isHeld, !AmbientAnimator.reduceMotion else { return }
        artLayer.removeAction(forKey: "awakeBreathe")
        let up = SKAction.scale(to: 1.04, duration: 0.6)
        let down = SKAction.scale(to: 1.0, duration: 0.6)
        up.timingMode = .easeInEaseOut
        down.timingMode = .easeInEaseOut
        artLayer.run(
            .sequence([.wait(forDuration: delay), .repeatForever(.sequence([up, down]))]),
            withKey: "awakeBreathe"
        )
    }

    func setWakeAnticipation(_ progress: CGFloat) {
        guard !isAwake, !isHeld else { return }
        let clamped = min(max(progress, 0), 1)
        guard glow.action(forKey: "pieceGlow") == nil else { return }
        glow.alpha = 0.65 * clamped
    }
}
