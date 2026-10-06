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
        glow.fillColor = WarmShelfPalette.butter.withAlpha(0.0)
        glow.strokeColor = .clear
        glow.zPosition = -0.5
        addChild(glow)

        if let art = StackPieceNode.stoneArt(for: kind, bodySize: bodySize) {
            // Warm Clay body: the neutral felt stone tinted to this piece's palette
            // colour — material from the art, identity from the colour, the living face
            // on top. Every piece keeps its own hue; the magic keeps (founder note).
            art.color = baseColor
            art.colorBlendFactor = 0.85
            addChild(art)
            if isSignatureHero { buildSignatureDetails() }
        } else {
            let body = SKShapeNode(rect: rect, cornerRadius: radius)
            // Baked clay gradient reads through the silhouette; fillColor stays neutral so the
            // texture's own colour shows, preserving the piece's subtle translucency via alpha.
            var baseAlpha: CGFloat = 1
            _ = baseColor.getRed(nil, green: nil, blue: nil, alpha: &baseAlpha)
            body.fillColor = UIColor(white: 1, alpha: baseAlpha)
            body.fillTexture = ProceduralTexture.radialClayTexture(base: baseColor, size: rect.size)
            body.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.10)
            body.lineWidth = max(1, bodySize.width * 0.009)
            addChild(body)

            ProceduralTexture.addMatteClayDepth(
                to: self,
                in: rect,
                cornerRadius: radius,
                zPosition: 0.78,
                highlightAlpha: isSignatureHero ? 0.32 : 0.25,
                shadeAlpha: 0.066,
                rimAlpha: 0.045,
                speckleCount: isSignatureHero ? 5 : 3
            )

            if isSignatureHero {
                buildSignatureDetails()
            } else {
                buildClayDimples()
            }
        }

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

        // Keep the authored performance separate from the physics node. The stone stays
        // exactly under the child's finger while its clay body can anticipate and follow.
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

    /// The signature friend is identifiable before its face is readable: terracotta clay,
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

        if let capArt = ToyArt.sprite("stack-capstone", fit: CGSize(width: capstoneSize.width * 1.06, height: capstoneSize.height * 1.3)) {
            capstoneRoot.addChild(capArt)
        } else {
            let capstone = SKShapeNode(
                rectOf: capstoneSize,
                cornerRadius: capstoneSize.height * 0.48
            )
            capstone.fillColor = WarmShelfPalette.butter.withAlpha(0.96)
            capstone.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.10)
            capstone.lineWidth = max(0.8, bodySize.width * 0.008)
            capstoneRoot.addChild(capstone)

            let capstoneGlow = SKShapeNode(ellipseOf: CGSize(width: capstoneSize.width * 0.48, height: capstoneSize.height * 0.30))
            capstoneGlow.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.46)
            capstoneGlow.strokeColor = .clear
            capstoneGlow.position = CGPoint(x: -capstoneSize.width * 0.12, y: capstoneSize.height * 0.18)
            capstoneGlow.zPosition = 0.1
            capstoneRoot.addChild(capstoneGlow)

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
        let d = animated ? 0.18 : 0.0
        func set(_ node: SKShapeNode?, _ a: CGFloat) {
            node?.run(.fadeAlpha(to: a, duration: d))
        }
        switch next {
        case .sleeping:
            set(leftLid, 1); set(rightLid, 1)
            leftPupil.run(.fadeAlpha(to: 0, duration: d)); rightPupil.run(.fadeAlpha(to: 0, duration: d))
            set(smile, isSignatureHero ? 0.56 : 0)
            set(openMouth, 0)
            set(cheekLeft, isSignatureHero ? 0.38 : 0)
            set(cheekRight, isSignatureHero ? 0.38 : 0)
            leftEye.run(.scale(to: 1, duration: d)); rightEye.run(.scale(to: 1, duration: d))
        case .awake:
            set(leftLid, 0); set(rightLid, 0)
            leftPupil.run(.fadeAlpha(to: 1, duration: d)); rightPupil.run(.fadeAlpha(to: 1, duration: d))
            set(smile, 0.5); set(openMouth, 0); set(cheekLeft, 0); set(cheekRight, 0)
            leftEye.run(.scale(to: 1, duration: d)); rightEye.run(.scale(to: 1, duration: d))
            lookToward(.zero)
        case .happy:
            set(leftLid, 0); set(rightLid, 0)
            leftPupil.run(.fadeAlpha(to: 1, duration: d)); rightPupil.run(.fadeAlpha(to: 1, duration: d))
            set(smile, 1); set(openMouth, 0); set(cheekLeft, 0.9); set(cheekRight, 0.9)
            leftEye.run(.scale(to: 1.05, duration: d)); rightEye.run(.scale(to: 1.05, duration: d))
        case .surprised:
            set(leftLid, 0); set(rightLid, 0)
            leftPupil.run(.fadeAlpha(to: 1, duration: d)); rightPupil.run(.fadeAlpha(to: 1, duration: d))
            set(smile, 0); set(openMouth, 1); set(cheekLeft, 0); set(cheekRight, 0)
            leftEye.run(.scale(to: 1.3, duration: d)); rightEye.run(.scale(to: 1.3, duration: d))
        }
    }

    /// Pupils drift toward a direction (e.g. the finger, or the way it's flying).
    func lookToward(_ direction: CGVector) {
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
            let dip = SKAction.sequence([.scaleY(to: 0.7, duration: 0.12), .scaleY(to: 1, duration: 0.18)])
            leftLid.run(dip); rightLid.run(dip)
            return
        }
        let blink = SKAction.sequence([
            .group([.fadeAlpha(to: 1, duration: 0.06)]),
            .group([.fadeAlpha(to: 0, duration: 0.1)])
        ])
        leftLid.run(blink); rightLid.run(blink)
    }

    func yawn() {
        guard expression == .sleeping else { return }
        openMouth.removeAllActions()
        let seq = SKAction.sequence([
            .group([.fadeAlpha(to: 0.5, duration: 0.5), .scale(to: 1.8, duration: 0.5)]),
            .group([.fadeAlpha(to: 0, duration: 0.4), .scale(to: 1.0, duration: 0.4)])
        ])
        openMouth.run(seq)
        let squeeze = SKAction.sequence([.scaleX(to: 1.04, y: 0.96, duration: 0.5), .scale(to: 1.0, duration: 0.4)])
        artLayer.run(squeeze, withKey: "yawn")
    }

    func dizzy() {
        // A tumble leaves it briefly dizzy: pupils wobble, little stars orbit.
        apply(.surprised)
        guard !AmbientAnimator.reduceMotion else {
            run(.sequence([.wait(forDuration: 0.45), .run { [weak self] in self?.apply(.awake) }]))
            return
        }
        let wobble = SKAction.sequence([
            .moveBy(x: pupilRadius, y: 0, duration: 0.08),
            .moveBy(x: -pupilRadius * 2, y: 0, duration: 0.16),
            .moveBy(x: pupilRadius, y: 0, duration: 0.08)
        ])
        leftPupil.run(.repeat(wobble, count: 2))
        rightPupil.run(.repeat(wobble, count: 2))
        for i in 0..<2 {
            let star = SKShapeNode(circleOfRadius: pupilRadius * 0.7)
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
        run(.sequence([.wait(forDuration: 0.9), .run { [weak self] in self?.apply(.awake) }]))
    }

    // MARK: - Lifecycle reactions

    func beginHold() {
        physicsBody?.isDynamic = false
        physicsBody?.velocity = .zero
        physicsBody?.angularVelocity = 0
        artLayer.removeAction(forKey: "pieceBreathe")
        artLayer.removeAction(forKey: "awakeBreathe")
        artLayer.removeAction(forKey: "towerPulse")
        artLayer.removeAction(forKey: "wakePerformance")
        artLayer.removeAction(forKey: "carryPose")
        artLayer.removeAction(forKey: "landingSquish")
        apply(.surprised)
        rebalanceCapstone(intensity: 0.7)
        run(.sequence([.wait(forDuration: 0.16), .run { [weak self] in if self?.expression == .surprised { self?.apply(.happy) } }]), withKey: "holdFace")

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

    /// The physics node tracks the finger exactly; the clay artwork leans and lags by a
    /// few points so carrying feels authored without introducing control latency.
    func poseForCarry(_ direction: CGVector) {
        guard !AmbientAnimator.reduceMotion else { return }
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
        physicsBody?.isDynamic = true
        physicsBody?.velocity = .zero
        physicsBody?.angularVelocity = 0

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
        guard expression != .surprised else { return }
        apply(.surprised)
        lookToward(CGVector(dx: 0, dy: -1))
    }

    func reactLanded(hard: Bool) {
        squish(intensity: hard ? 1.0 : 0.6)
        rebalanceCapstone(intensity: hard ? 1.0 : 0.55)
        apply(.happy)
        blink()
        // Drift back to a calm sleepy state if it stays put.
        run(.sequence([.wait(forDuration: 1.6), .run { [weak self] in
            guard let self else { return }
            if self.speed2D < 8 && !self.isAwake { self.apply(.sleeping); self.breatheSleepily() }
        }]), withKey: "calmDown")
    }

    func reactToKnockover() {
        apply(.happy)
        guard !AmbientAnimator.reduceMotion else { return }
        artLayer.removeAction(forKey: "knockoverJoy")
        let open = SKAction.scaleX(to: 1.08, y: 1.04, duration: 0.11)
        let settle = SKAction.scale(to: 1.0, duration: 0.20)
        open.timingMode = .easeOut
        settle.timingMode = .easeInEaseOut
        artLayer.run(.sequence([open, settle]), withKey: "knockoverJoy")
        rebalanceCapstone(intensity: 0.8)
    }

    func squish(intensity: CGFloat = 1.0) {
        artLayer.removeAction(forKey: "landingSquish")
        let amount = min(0.22, 0.10 + intensity * 0.10)
        let down = SKAction.scaleX(to: 1.0 + amount, y: 1.0 - amount, duration: 0.07)
        let rebound = SKAction.scaleX(to: 0.98, y: 1.05, duration: 0.10)
        let up = SKAction.scale(to: 1.0, duration: 0.16)
        down.timingMode = .easeOut
        rebound.timingMode = .easeOut
        up.timingMode = .easeInEaseOut
        artLayer.run(.sequence([down, rebound, up]), withKey: "landingSquish")
    }

    func breatheSleepily(delay: TimeInterval = 0) {
        guard !AmbientAnimator.reduceMotion else { return }
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
        artLayer.removeAction(forKey: "pieceBreathe")
        removeAction(forKey: "calmDown")
        apply(.surprised)
        glow.run(.customAction(withDuration: 0.4) { node, t in
            (node as? SKShapeNode)?.fillColor = WarmShelfPalette.butter.withAlpha(0.20 * (t / 0.4))
        })

        if AmbientAnimator.reduceMotion {
            apply(.happy)
        } else {
            let gather = SKAction.scaleX(to: 1.04, y: 0.94, duration: 0.08)
            let rise = SKAction.group([
                .scaleX(to: 0.98, y: 1.08, duration: 0.13),
                .moveBy(x: 0, y: 5, duration: 0.13)
            ])
            let notice = SKAction.run { [weak self] in self?.apply(.happy) }
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
        guard !AmbientAnimator.reduceMotion else { return }
        artLayer.removeAction(forKey: "pieceBreathe")
        artLayer.removeAction(forKey: "awakeBreathe")
        let gather = SKAction.scaleX(to: 1.025, y: 0.975, duration: 0.07)
        let lift = SKAction.scaleX(to: 0.985, y: isTop ? 1.075 : 1.045, duration: 0.10)
        let settle = SKAction.scale(to: 1.0, duration: 0.18)
        let resumeIdle = SKAction.run { [weak self] in
            guard let self else { return }
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
            .run { [weak self] in self?.wake() },
            .wait(forDuration: 0.72),
            .run { [weak self] in self?.sleep() },
            .wait(forDuration: 0.28),
            .run { [weak self] in self?.yawn() }
        ]), withKey: "shelfInvitation")
    }

    func sleep() {
        guard isAwake else { return }
        isAwake = false
        artLayer.removeAction(forKey: "awakeBreathe")
        apply(.sleeping)
        glow.run(.customAction(withDuration: 0.3) { node, t in
            (node as? SKShapeNode)?.fillColor = WarmShelfPalette.butter.withAlpha(0.20 * (1 - t / 0.3))
        })
        artLayer.run(.scale(to: 1.0, duration: 0.2))
        breatheSleepily()
    }

    private func rebalanceCapstone(intensity: CGFloat) {
        guard let capstoneLayer, !AmbientAnimator.reduceMotion else { return }
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
        guard !AmbientAnimator.reduceMotion else { return }
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
        guard !isAwake else { return }
        let clamped = min(max(progress, 0), 1)
        glow.fillColor = WarmShelfPalette.butter.withAlpha(0.13 * clamped)
    }
}
