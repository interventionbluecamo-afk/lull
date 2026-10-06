import SpriteKit

enum BloomKind: CaseIterable {
    case flower
    case tallFlower
    case mushroom
    case berry
    case dandelion

    /// Weighted pick — common flowers, rare treats.
    static func random() -> BloomKind {
        switch Int.random(in: 0..<100) {
        case 0..<52: return .flower
        case 52..<70: return .tallFlower
        case 70..<82: return .berry
        case 82..<92: return .dandelion
        default: return .mushroom
        }
    }
}

/// A plant rooted at its origin (the soil point). Children extend upward, so scaling
/// the node's height grows it out of the ground. A head-only mode (stemHeight 0) is used
/// for static previews like the shelf card.
final class BloomNode: SKNode {
    let kind: BloomKind
    let stemHeight: CGFloat
    var snapshotColor: UIColor { baseColor }
    var snapshotScaleFactor: CGFloat { scaleFactor }
    var headShadowSpec: (size: CGSize, yOffset: CGFloat) {
        Self.headShadowSpec(kind: kind, scale: scaleFactor)
    }

    private var headNode = SKNode()
    private let baseColor: UIColor
    private let scaleFactor: CGFloat

    init(kind: BloomKind, color: UIColor, scale: CGFloat, stemHeight: CGFloat = 0) {
        self.kind = kind
        self.baseColor = color
        self.scaleFactor = scale
        self.stemHeight = stemHeight
        super.init()
        name = "bloom"
        build()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        let s = scaleFactor
        if stemHeight > 0 {
            if kind == .mushroom {
                buildMushroomStalk(height: stemHeight, scale: s)
            } else {
                buildStem(height: stemHeight, scale: s)
            }
        }
        headNode.position = CGPoint(x: 0, y: stemHeight)
        headNode.zPosition = 5
        addChild(headNode)
        buildHead(into: headNode, scale: s)
    }

    private static func headShadowSpec(kind: BloomKind, scale s: CGFloat) -> (size: CGSize, yOffset: CGFloat) {
        switch kind {
        case .flower:
            return (CGSize(width: 54 * s, height: 16 * s), -5 * s)
        case .tallFlower:
            return (CGSize(width: 62 * s, height: 18 * s), -7 * s)
        case .berry:
            return (CGSize(width: 42 * s, height: 14 * s), -8 * s)
        case .mushroom:
            return (CGSize(width: 54 * s, height: 15 * s), -8 * s)
        case .dandelion:
            return (CGSize(width: 44 * s, height: 14 * s), -6 * s)
        }
    }

    private func buildStem(height: CGFloat, scale s: CGFloat) {
        let stemWidth = max(4, 5 * s)
        let stem = SKShapeNode(rect: CGRect(x: -stemWidth / 2, y: 0, width: stemWidth, height: height), cornerRadius: stemWidth / 2)
        stem.fillColor = WarmShelfPalette.sage.withAlpha(0.92)
        stem.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.05)
        stem.lineWidth = 1
        addChild(stem)

        for (index, frac) in [0.42, 0.66].enumerated() {
            let side: CGFloat = index == 0 ? -1 : 1
            let leaf = SKShapeNode(ellipseOf: CGSize(width: 22 * s, height: 11 * s))
            leaf.fillColor = WarmShelfPalette.sage.withAlpha(0.82)
            leaf.strokeColor = .clear
            leaf.position = CGPoint(x: side * 11 * s, y: height * CGFloat(frac))
            leaf.zRotation = side * 0.5
            addChild(leaf)
        }
    }

    private func buildMushroomStalk(height: CGFloat, scale s: CGFloat) {
        let w = max(10, 14 * s)
        let stalk = SKShapeNode(rect: CGRect(x: -w / 2, y: 0, width: w, height: height), cornerRadius: w / 2)
        stalk.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.95)
        stalk.strokeColor = WarmShelfPalette.sand.withAlpha(0.4)
        stalk.lineWidth = 1
        addChild(stalk)
    }

    private func buildHead(into head: SKNode, scale s: CGFloat) {
        switch kind {
        case .flower:
            buildVariedFlower(into: head, scale: s, big: false)
        case .tallFlower:
            buildVariedFlower(into: head, scale: s, big: true)
        case .berry:
            let positions = [CGPoint(x: 0, y: 7 * s), CGPoint(x: -8 * s, y: -4 * s), CGPoint(x: 8 * s, y: -4 * s)]
            for pos in positions {
                let berry = SKShapeNode(circleOfRadius: 9 * s)
                berry.fillColor = baseColor.withAlpha(0.92)
                berry.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.05)
                berry.position = pos
                head.addChild(berry)
                ProceduralTexture.applyClayFill(to: berry, base: baseColor.withAlpha(0.92), size: CGSize(width: 18 * s, height: 18 * s))
                ProceduralTexture.addMatteClayDepth(
                    to: berry,
                    ellipse: CGSize(width: 18 * s, height: 18 * s),
                    zPosition: 0.1,
                    highlightAlpha: 0.22,
                    shadeAlpha: 0.042,
                    rimAlpha: 0.030,
                    speckleCount: 1
                )
                let glint = SKShapeNode(circleOfRadius: 2.6 * s)
                glint.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.7)
                glint.strokeColor = .clear
                glint.position = CGPoint(x: pos.x - 2.4 * s, y: pos.y + 2.4 * s)
                head.addChild(glint)
            }
            addSproutFace(to: head, faceWidth: 15 * s, center: positions[0])
        case .mushroom:
            let cap = SKShapeNode(ellipseOf: CGSize(width: 46 * s, height: 34 * s))
            cap.fillColor = (baseColor == WarmShelfPalette.sage ? WarmShelfPalette.terracotta : baseColor).withAlpha(0.95)
            cap.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.06)
            cap.position = CGPoint(x: 0, y: 6 * s)
            head.addChild(cap)
            ProceduralTexture.applyClayFill(to: cap, base: (baseColor == WarmShelfPalette.sage ? WarmShelfPalette.terracotta : baseColor).withAlpha(0.95), size: CGSize(width: 46 * s, height: 34 * s))
            ProceduralTexture.addMatteClayDepth(
                to: cap,
                ellipse: CGSize(width: 46 * s, height: 34 * s),
                zPosition: 0.1,
                highlightAlpha: 0.22,
                shadeAlpha: 0.045,
                rimAlpha: 0.030,
                speckleCount: 2
            )
            for _ in 0..<4 {
                let spot = SKShapeNode(circleOfRadius: CGFloat.random(in: 2.5...4.5) * s)
                spot.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.7)
                spot.strokeColor = .clear
                spot.position = CGPoint(x: CGFloat.random(in: -16...16) * s, y: 6 * s + CGFloat.random(in: -6...8) * s)
                head.addChild(spot)
            }
            addSproutFace(to: head, faceWidth: 22 * s, center: CGPoint(x: 0, y: 4 * s))
        case .dandelion:
            // A soft seed puff — radiating tufts you can blow apart.
            let core = SKShapeNode(circleOfRadius: 7 * s)
            core.fillColor = WarmShelfPalette.sand.withAlpha(0.5); core.strokeColor = .clear
            head.addChild(core)
            ProceduralTexture.addMatteClayDepth(
                to: core,
                ellipse: CGSize(width: 14 * s, height: 14 * s),
                zPosition: 0.1,
                highlightAlpha: 0.20,
                shadeAlpha: 0.032,
                rimAlpha: 0.024,
                speckleCount: 0
            )
            for index in 0..<14 {
                let angle = CGFloat(index) / 14 * .pi * 2
                let r = 15 * s
                let stalk = SKShapeNode(rect: CGRect(x: -0.8 * s, y: 0, width: 1.6 * s, height: r), cornerRadius: 0.8 * s)
                stalk.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.5); stalk.strokeColor = .clear
                stalk.zRotation = angle - .pi / 2
                head.addChild(stalk)
                let tuft = SKShapeNode(circleOfRadius: 3 * s)
                tuft.name = "dandeTuft"
                tuft.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.92); tuft.strokeColor = .clear
                tuft.position = CGPoint(x: cos(angle) * r, y: sin(angle) * r)
                head.addChild(tuft)
            }
        }
    }

    /// A flower head with lots of natural variety — random petal count, shape (round /
    /// pointed / skinny daisy), an optional fuller back-layer, and a varied centre — so no
    /// two flowers look alike.
    private func buildVariedFlower(into head: SKNode, scale s: CGFloat, big: Bool) {
        var rng = SystemRandomNumberGenerator()
        let shape = Int.random(in: 0..<3, using: &rng)            // 0 round, 1 pointed, 2 skinny daisy
        let count = shape == 2 ? Int.random(in: 11...16) : Int.random(in: big ? 7...10 : 5...8)
        let radius = (big ? 16 : 12) * s
        let petalW = (shape == 2 ? 7 : (big ? 16 : 17)) * s
        let petalH = (shape == 2 ? 26 : (big ? 30 : 26)) * s
        let layered = shape != 2 && Bool.random(using: &rng)

        func petalNode(scaleMul: CGFloat) -> SKShapeNode {
            switch shape {
            case 1: return SKShapeNode(path: Self.pointedPetal(w: petalW * scaleMul, h: petalH * scaleMul))
            default: return SKShapeNode(ellipseOf: CGSize(width: petalW * scaleMul, height: petalH * scaleMul))
            }
        }
        func ring(scaleMul: CGFloat, rotOffset: CGFloat, color: UIColor) {
            for index in 0..<count {
                let angle = CGFloat(index) / CGFloat(count) * .pi * 2 + rotOffset
                let p = petalNode(scaleMul: scaleMul)
                p.fillColor = color; p.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.04); p.lineWidth = 1
                p.position = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
                p.zRotation = angle + .pi / 2
                ProceduralTexture.addMatteClayDepth(
                    to: p,
                    ellipse: CGSize(width: petalW * scaleMul, height: petalH * scaleMul),
                    zPosition: 0.1,
                    highlightAlpha: 0.10,
                    shadeAlpha: 0.020,
                    rimAlpha: 0.016,
                    speckleCount: 0
                )
                head.addChild(p)
            }
        }

        // Optional fuller, darker back layer for depth.
        if layered { ring(scaleMul: 1.2, rotOffset: .pi / CGFloat(count), color: Self.darker(baseColor, 0.2).withAlpha(0.9)) }
        ring(scaleMul: 1.0, rotOffset: 0, color: baseColor.withAlpha(0.92))

        // Centre — varied colour + a soft dome and glint.
        let centerColor = [WarmShelfPalette.butter, WarmShelfPalette.cocoa.withAlpha(0.66), WarmShelfPalette.terracotta, WarmShelfPalette.sand].randomElement(using: &rng) ?? WarmShelfPalette.butter
        let center = SKShapeNode(circleOfRadius: radius * (shape == 2 ? 0.7 : 0.82))
        center.fillColor = centerColor; center.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.06); center.lineWidth = 1
        center.zPosition = 1; head.addChild(center)
        ProceduralTexture.addMatteClayDepth(
            to: center,
            ellipse: CGSize(width: radius * 1.56, height: radius * 1.56),
            zPosition: 0.1,
            highlightAlpha: 0.20,
            shadeAlpha: 0.036,
            rimAlpha: 0.024,
            speckleCount: 1
        )
        // Dotted seed centre on some flowers.
        if Bool.random(using: &rng) {
            for _ in 0..<6 {
                let dot = SKShapeNode(circleOfRadius: 1.6 * s)
                dot.fillColor = WarmShelfPalette.cocoa.withAlpha(0.4); dot.strokeColor = .clear
                dot.position = CGPoint(x: .random(in: -radius*0.4...radius*0.4), y: .random(in: -radius*0.4...radius*0.4))
                dot.zPosition = 1.5; head.addChild(dot)
            }
        }
        let glint = SKShapeNode(circleOfRadius: radius * 0.28)
        glint.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.8); glint.strokeColor = .clear
        glint.position = CGPoint(x: -radius * 0.25, y: radius * 0.25); glint.zPosition = 2
        head.addChild(glint)

        // The bloom wakes up smiling — a little clay sprout-friend in the family.
        addSproutFace(to: head, faceWidth: radius * 1.05)
    }

    /// A sleepy-arc face with rosy cheeks, so every grown bloom is a tiny clay friend that
    /// "wakes up" as its head pops open.
    private func addSproutFace(to head: SKNode, faceWidth w: CGFloat, center: CGPoint = .zero) {
        let ink = WarmShelfPalette.cocoa.withAlpha(0.72)
        let eyeGap = w * 0.30
        let eyeW = w * 0.18
        let lineW = max(1.2, w * 0.05)
        let eyeY = center.y + w * 0.06

        for sign in [CGFloat(-1), CGFloat(1)] {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -eyeW * 0.5, y: 0))
            p.addQuadCurve(to: CGPoint(x: eyeW * 0.5, y: 0), control: CGPoint(x: 0, y: w * 0.12))
            let eye = SKShapeNode(path: p)
            eye.strokeColor = ink; eye.lineWidth = lineW; eye.lineCap = .round; eye.fillColor = .clear
            eye.position = CGPoint(x: center.x + sign * eyeGap, y: eyeY)
            eye.zPosition = 4
            head.addChild(eye)
        }

        let mw = w * 0.24
        let my = center.y - w * 0.11
        let mp = CGMutablePath()
        mp.move(to: CGPoint(x: center.x - mw * 0.5, y: my))
        mp.addQuadCurve(to: CGPoint(x: center.x + mw * 0.5, y: my), control: CGPoint(x: center.x, y: my - w * 0.11))
        let mouth = SKShapeNode(path: mp)
        mouth.strokeColor = ink; mouth.lineWidth = lineW * 0.9; mouth.lineCap = .round; mouth.fillColor = .clear
        mouth.zPosition = 4
        head.addChild(mouth)

        for sign in [CGFloat(-1), CGFloat(1)] {
            let cheek = SKShapeNode(circleOfRadius: w * 0.08)
            cheek.fillColor = WarmShelfPalette.petal.withAlpha(0.5); cheek.strokeColor = .clear
            cheek.position = CGPoint(x: center.x + sign * eyeGap * 1.5, y: center.y - w * 0.03)
            cheek.zPosition = 3.5
            head.addChild(cheek)
        }
    }

    private static func darker(_ c: UIColor, _ t: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: r * (1 - t), green: g * (1 - t), blue: b * (1 - t), alpha: a)
    }

    private static func pointedPetal(w: CGFloat, h: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0, y: -h * 0.5))
        p.addQuadCurve(to: CGPoint(x: 0, y: h * 0.5), control: CGPoint(x: w * 0.62, y: 0))
        p.addQuadCurve(to: CGPoint(x: 0, y: -h * 0.5), control: CGPoint(x: -w * 0.62, y: 0))
        p.closeSubpath()
        return p
    }

    // MARK: - Growth (the Pixar beat)

    func prepareToGrow() {
        yScale = 0.02
        headNode.setScale(0.0)
        headNode.alpha = 0
    }

    func prepareToBloomFromStem() {
        removeAllActions()
        yScale = 1
        headNode.setScale(0.12)
        headNode.alpha = 0
    }

    func grow() {
        // Stem springs up from the dirt — quick perk (0.18s easeOut), slow exhale (0.28s easeInEaseOut).
        let perk = SKAction.scaleX(to: 1.0, y: 1.08, duration: 0.18); perk.timingMode = .easeOut
        let exhale = SKAction.scaleX(to: 1.0, y: 1.0, duration: 0.28); exhale.timingMode = .easeInEaseOut
        run(.sequence([perk, exhale]))

        // ...then the head opens with a happy overshoot.
        let open = SKAction.sequence([
            .wait(forDuration: 0.24),
            .run { [weak self] in
                guard let self else { return }
                let pop = SKAction.group([
                    .fadeAlpha(to: 1, duration: 0.2),
                    .sequence([.scale(to: 1.18, duration: 0.2), .scale(to: 1.0, duration: 0.14)])
                ])
                pop.timingMode = .easeOut
                self.headNode.run(pop)
            }
        ])
        run(.sequence([open, .run { [weak self] in self?.beginSway() }]))
    }

    func bloomFromStem() {
        headNode.removeAction(forKey: "open")
        // Wake fast (0.15s easeOut), settle slow (0.26s easeInEaseOut).
        let pop = SKAction.scale(to: 1.22, duration: 0.15); pop.timingMode = .easeOut
        let settle = SKAction.scale(to: 1.0, duration: 0.26); settle.timingMode = .easeInEaseOut
        let open = SKAction.group([
            .fadeAlpha(to: 1, duration: 0.18),
            .sequence([pop, settle])
        ])
        headNode.run(open, withKey: "open")
        run(.sequence([
            .wait(forDuration: 0.22),
            .run { [weak self] in self?.beginSway() }
        ]))
    }

    /// Head position in scene space — where butterflies land and sparkles bloom.
    func headScenePosition(in scene: SKScene) -> CGPoint {
        convert(headNode.position, to: scene)
    }

    private func beginSway() {
        guard !AmbientAnimator.reduceMotion else { return }
        // Sway pivots around the rooted base.
        let amount = CGFloat.random(in: 0.035...0.075)
        let dur = Double.random(in: 2.6...4.0)
        let left = SKAction.rotate(toAngle: -amount, duration: dur * 0.5, shortestUnitArc: true)
        let right = SKAction.rotate(toAngle: amount, duration: dur, shortestUnitArc: true)
        let mid = SKAction.rotate(toAngle: 0, duration: dur * 0.5, shortestUnitArc: true)
        [left, right, mid].forEach { $0.timingMode = .easeInEaseOut }
        run(.repeatForever(.sequence([left, right, mid])), withKey: "sway")
    }

    /// Rotation should preserve the child's garden without replaying every growth beat.
    func restoreFullyGrown() {
        removeAllActions()
        yScale = 1
        headNode.setScale(1)
        headNode.alpha = 1
        beginSway()
    }

    func cheer() {
        headNode.removeAction(forKey: "cheer")
        let up = SKAction.scale(to: 1.2, duration: 0.16)
        let down = SKAction.scale(to: 1.0, duration: 0.3)
        up.timingMode = .easeOut
        down.timingMode = .easeInEaseOut
        headNode.run(.sequence([up, down]), withKey: "cheer")
        if kind == .dandelion { scatterSeeds() }
    }

    /// Dandelion seeds float off on the breeze when the puff is touched.
    private func scatterSeeds() {
        let tufts = headNode.children.filter { $0.name == "dandeTuft" }
        for tuft in tufts {
            let flyaway = tuft.copy() as! SKShapeNode
            flyaway.position = convert(tuft.position, from: headNode)
            flyaway.alpha = tuft.alpha
            addChild(flyaway)
            let angle = CGFloat.random(in: (.pi * 0.1)...(.pi * 0.9))
            let dist = CGFloat.random(in: 40...110) * scaleFactor
            let drift = SKAction.moveBy(x: cos(angle) * dist + 30 * scaleFactor, y: sin(angle) * dist + 50 * scaleFactor, duration: Double.random(in: 1.6...2.6))
            drift.timingMode = .easeOut
            let spin = SKAction.rotate(byAngle: .pi * 2, duration: 2.0)
            flyaway.run(.sequence([.group([drift, spin, .fadeOut(withDuration: 2.0)]), .removeFromParent()]))
            tuft.run(.fadeOut(withDuration: 0.18))
        }
        // The puff regrows after a little while, so it can be blown again.
        run(.sequence([.wait(forDuration: 5.0), .run { [weak self] in
            self?.headNode.children.filter { $0.name == "dandeTuft" }.forEach { $0.run(.fadeAlpha(to: 0.92, duration: 0.6)) }
        }]))
    }
}
