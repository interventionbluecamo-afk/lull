import SpriteKit

/// A little tactile treasure the child posts into the Sleepy Drop Box. Four distinct, cute,
/// readable silhouettes — a berry ball, a moon coin, a soft cube, and a star biscuit — each with
/// matte clay/felt material, a soft separating contact shadow, and a gentle lift wobble. No
/// physics: the scene authors all motion, so a treasure can never fly off, stick, or vanish.
final class DropTreasureNode: SKNode {
    enum Kind: CaseIterable { case berry, triangle, cube, star }

    let kind: Kind
    let radius: CGFloat
    let variant: Int   // each drawer-pull brings the same shapes back in fresh "outfits"

    private let body = SKShapeNode()
    private let shadow: SKSpriteNode

    init(kind: Kind, radius: CGFloat, variant: Int = 0) {
        self.kind = kind
        self.radius = radius
        self.variant = variant
        shadow = SKSpriteNode(texture: ProceduralTexture.softClayShadow(size: CGSize(width: radius * 2.9, height: radius * 1.22)))
        super.init()

        shadow.position = CGPoint(x: 0, y: -radius * 1.02)
        shadow.zPosition = -1
        shadow.alpha = 0.95
        addChild(shadow)

        buildBody()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Three warm tints per shape family. The SHAPE stays matched to its socket (the rule never
    /// changes); the colour cycles each return, so the toy feels quietly new every pull.
    var color: UIColor {
        let families: [Kind: [UInt32]] = [
            .berry:    [0xD24B3E, 0xC4583F, 0xE0614A],   // berry red → clay rust → warm coral
            .triangle: [0xF2C24C, 0xEAA93C, 0xF6CF6E],   // butter → honey → light gold
            .cube:     [0x82A648, 0x6F9655, 0x93B05A],   // sage → moss → spring sage
            .star:     [0xEACF86, 0xE8C46E, 0xF2DCA0]    // biscuit → toasted → vanilla cream
        ]
        let family = families[kind] ?? [0xD24B3E]
        return UIColor(hex: family[((variant % family.count) + family.count) % family.count])
    }

    private func buildBody() {
        let r = radius
        if let art = DropTreasureNode.artSprite(for: kind, radius: r) {
            // Warm Clay treasure: the authored felt/wood body with the same sleepy face
            // drawn on top — the little friend still wakes when lifted.
            addChild(body)
            art.zPosition = 0
            body.addChild(art)
            buildSleepyFace()
            return
        }
        switch kind {
        case .berry:
            body.path = CGPath(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2), transform: nil)
        case .triangle:
            body.path = DropTreasureNode.roundedTrianglePath(radius: r * 1.24, corner: r * 0.44)   // softer, chunkier wedge
        case .cube:
            let s = r * 1.78
            body.path = CGPath(roundedRect: CGRect(x: -s / 2, y: -s / 2, width: s, height: s), cornerWidth: s * 0.3, cornerHeight: s * 0.3, transform: nil)
        case .star:
            body.path = DropTreasureNode.softStarPath(outer: r * 1.3, inner: r * 0.64, points: 5)   // fatter, puffier points
        }
        body.fillColor = color
        body.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.12)
        body.lineWidth = 1.2
        body.zPosition = 0
        addChild(body)
        if let box = body.path?.boundingBoxOfPath {
            ProceduralTexture.applyClayFill(to: body, base: color, size: box.size)
        }

        // A soft static highlight, sized to the silhouette.
        // Matte clay light: one soft, broad sheen — no hard white specular, which read as plastic.
        let glint = SKShapeNode(ellipseOf: CGSize(width: r * 0.9, height: r * 0.6))
        glint.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.32)
        glint.strokeColor = .clear
        glint.position = CGPoint(x: -r * 0.28, y: r * 0.32)
        glint.zRotation = -0.5
        glint.zPosition = 0.3
        body.addChild(glint)
        // A whisper of reflected warmth along the lower edge grounds the piece like real clay.
        let underGlow = SKShapeNode(ellipseOf: CGSize(width: r * 1.1, height: r * 0.34))
        underGlow.fillColor = WarmShelfPalette.cocoa.withAlpha(0.1)
        underGlow.strokeColor = .clear
        underGlow.position = CGPoint(x: 0, y: -r * 0.52)
        underGlow.zPosition = 0.28
        body.addChild(underGlow)

        switch kind {
        case .triangle:
            // A soft highlight along the upper-left edge so the wedge reads chunky and lit.
            let hi = SKShapeNode()
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -r * 0.36, y: r * 0.08))
            p.addQuadCurve(to: CGPoint(x: r * 0.0, y: r * 0.78), control: CGPoint(x: -r * 0.26, y: r * 0.48))
            hi.path = p
            hi.strokeColor = WarmShelfPalette.paperHighlight.withAlpha(0.4)
            hi.lineWidth = max(2, r * 0.1)
            hi.lineCap = .round
            hi.fillColor = .clear
            hi.zPosition = 0.4
            body.addChild(hi)
        case .cube:
            // A lighter top face so the block reads chunky and dimensional.
            let s = r * 1.66
            let topFace = SKShapeNode(rect: CGRect(x: -s * 0.38, y: s * 0.1, width: s * 0.76, height: s * 0.26), cornerRadius: s * 0.12)
            topFace.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.26)
            topFace.strokeColor = .clear
            topFace.zPosition = 0.35
            body.addChild(topFace)
            // A soft shaded right side so the block reads three-dimensional, not a flat square.
            let sideShade = SKShapeNode(rect: CGRect(x: s * 0.1, y: -s * 0.42, width: s * 0.34, height: s * 0.74), cornerRadius: s * 0.12)
            sideShade.fillColor = WarmShelfPalette.cocoa.withAlpha(0.12)
            sideShade.strokeColor = .clear
            sideShade.zPosition = 0.34
            body.addChild(sideShade)
        case .star:
            break   // the sleepy face is the star's charm; no extra marking needed
        case .berry:
            // A few darker speckles — a matte berry, not a shiny plastic ball.
            for _ in 0..<5 {
                let speck = SKShapeNode(circleOfRadius: r * 0.05)
                speck.fillColor = WarmShelfPalette.cocoa.withAlpha(0.16)
                speck.strokeColor = .clear
                let a = CGFloat.random(in: 0..<(.pi * 2)), rr = CGFloat.random(in: 0.6...0.82) * r
                speck.position = CGPoint(x: cos(a) * rr, y: sin(a) * rr)
                speck.zPosition = 0.32
                body.addChild(speck)
            }
        }

        buildSleepyFace()
    }

    /// Every treasure is a little sleeping friend being tucked into the sleepy box — closed-arc
    /// eyes, a soft smile, rosy cheeks. The same face family as the rest of the toybox.
    private var faceEyes: [(node: SKShapeNode, offsetX: CGFloat, faceY: CGFloat)] = []

    /// Closed sleepy arc vs. a small open button-eye — swapped as the piece wakes/rests.
    private static func pieceEyePath(open: Bool, sx: CGFloat, faceY: CGFloat, r: CGFloat) -> CGPath {
        if open {
            return CGPath(ellipseIn: CGRect(x: sx - r * 0.085, y: faceY - r * 0.02, width: r * 0.17, height: r * 0.2), transform: nil)
        }
        let p = CGMutablePath()
        p.move(to: CGPoint(x: sx - r * 0.13, y: faceY + r * 0.08))
        p.addQuadCurve(to: CGPoint(x: sx + r * 0.13, y: faceY + r * 0.08), control: CGPoint(x: sx, y: faceY - r * 0.04))
        return p
    }

    /// Picked up → the little friend wakes (eyes open); set down or tucked in → back to sleep.
    /// Quiet by design: just an eye-path swap, no flailing.
    func setAwake(_ awake: Bool) {
        let r = radius
        let ink = WarmShelfPalette.cocoa.withAlpha(0.5)
        for eye in faceEyes {
            eye.node.path = DropTreasureNode.pieceEyePath(open: awake, sx: eye.offsetX, faceY: eye.faceY, r: r)
            eye.node.fillColor = awake ? WarmShelfPalette.cocoa.withAlpha(0.65) : .clear
            eye.node.strokeColor = awake ? .clear : ink
        }
    }

    private func buildSleepyFace() {
        let r = radius
        let ink = WarmShelfPalette.cocoa.withAlpha(0.5)
        let faceY: CGFloat = kind == .triangle ? -r * 0.12 : 0   // a wedge's visual centre sits lower
        for sx in [-r * 0.3, r * 0.3] {
            let eye = SKShapeNode(path: DropTreasureNode.pieceEyePath(open: false, sx: sx, faceY: faceY, r: r))
            eye.strokeColor = ink; eye.lineWidth = max(1.8, r * 0.07); eye.lineCap = .round; eye.fillColor = .clear
            eye.zPosition = 0.45
            body.addChild(eye)
            faceEyes.append((node: eye, offsetX: sx, faceY: faceY))
        }
        let smilePath = CGMutablePath()
        smilePath.move(to: CGPoint(x: -r * 0.15, y: faceY - r * 0.2))
        smilePath.addQuadCurve(to: CGPoint(x: r * 0.15, y: faceY - r * 0.2), control: CGPoint(x: 0, y: faceY - r * 0.32))
        let smile = SKShapeNode(path: smilePath)
        smile.strokeColor = ink; smile.lineWidth = max(1.8, r * 0.07); smile.lineCap = .round; smile.fillColor = .clear
        smile.zPosition = 0.45
        body.addChild(smile)
        for sx in [-r * 0.5, r * 0.5] {
            let cheek = SKShapeNode(ellipseOf: CGSize(width: r * 0.24, height: r * 0.14))
            cheek.fillColor = WarmShelfPalette.petal.withAlpha(0.32); cheek.strokeColor = .clear
            cheek.position = CGPoint(x: sx, y: faceY - r * 0.08); cheek.zPosition = 0.44
            body.addChild(cheek)
        }
    }

    private static func artSprite(for kind: Kind, radius r: CGFloat) -> SKSpriteNode? {
        let slot: String
        let fit: CGSize
        switch kind {
        case .berry:    slot = "sleepybox-ball";     fit = CGSize(width: r * 2.0, height: r * 2.0)
        case .triangle: slot = "sleepybox-triangle"; fit = CGSize(width: r * 2.3, height: r * 2.3)
        case .cube:     slot = "sleepybox-cube";     fit = CGSize(width: r * 1.95, height: r * 1.95)
        case .star:     slot = "sleepybox-star";     fit = CGSize(width: r * 2.6, height: r * 2.6)
        }
        return ToyArt.sprite(slot, fit: fit)
    }

    /// A soft equilateral triangle pointing up, with rounded corners.
    static func roundedTrianglePath(radius r: CGFloat, corner: CGFloat) -> CGPath {
        let pts = (0..<3).map { i -> CGPoint in
            let a = CGFloat.pi / 2 + CGFloat(i) * 2 * .pi / 3
            return CGPoint(x: cos(a) * r, y: sin(a) * r)
        }
        let path = CGMutablePath()
        path.move(to: CGPoint(x: (pts[0].x + pts[1].x) / 2, y: (pts[0].y + pts[1].y) / 2))
        path.addArc(tangent1End: pts[1], tangent2End: pts[2], radius: corner)
        path.addArc(tangent1End: pts[2], tangent2End: pts[0], radius: corner)
        path.addArc(tangent1End: pts[0], tangent2End: pts[1], radius: corner)
        path.closeSubpath()
        return path
    }

    static func softStarPath(outer: CGFloat, inner: CGFloat, points: Int) -> CGPath {
        var pts: [CGPoint] = []
        for i in 0..<(points * 2) {
            let a = CGFloat(i) / CGFloat(points * 2) * .pi * 2 - .pi / 2
            let rad = i.isMultiple(of: 2) ? outer : inner
            pts.append(CGPoint(x: cos(a) * rad, y: sin(a) * rad))
        }
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        let path = CGMutablePath()
        path.move(to: mid(pts[pts.count - 1], pts[0]))
        for i in 0..<pts.count {
            path.addQuadCurve(to: mid(pts[i], pts[(i + 1) % pts.count]), control: pts[i])
        }
        path.closeSubpath()
        return path
    }

    func setLifted(_ lifted: Bool) {
        setAwake(lifted)   // carried = awake; resting or tucked in = asleep
        shadow.removeAction(forKey: "lift")
        body.removeAction(forKey: "lift")
        let move = SKAction.group([
            .move(to: CGPoint(x: 0, y: lifted ? -radius * 2.05 : -radius * 1.02), duration: 0.18),
            .fadeAlpha(to: lifted ? 0.4 : 0.95, duration: 0.18),
            .scale(to: lifted ? 0.7 : 1, duration: 0.18)
        ])
        shadow.run(move, withKey: "lift")
        body.run(.scale(to: lifted ? 1.16 : 1, duration: 0.18), withKey: "lift")
        if lifted, !AmbientAnimator.reduceMotion {
            body.run(.sequence([
                .rotate(toAngle: 0.06, duration: 0.16), .rotate(toAngle: -0.05, duration: 0.22), .rotate(toAngle: 0, duration: 0.18)
            ]), withKey: "wobble")
        }
    }

    func squash(_ intensity: CGFloat) {
        let a = min(0.22, max(0.05, intensity))
        body.removeAction(forKey: "squash")
        body.run(.sequence([
            .scaleX(to: 1 + a, y: 1 - a, duration: 0.06),
            .scaleX(to: 1, y: 1, duration: 0.2)
        ]), withKey: "squash")
    }

    /// The piece nudges against a hole that doesn't fit it — a soft tilt + squish, never a buzz.
    func bumpRim() {
        body.removeAction(forKey: "bump")
        body.run(.sequence([
            .rotate(toAngle: CGFloat.random(in: -0.18...0.18), duration: 0.08),
            .scaleX(to: 1.12, y: 0.9, duration: 0.06),
            .group([.scaleX(to: 1, y: 1, duration: 0.18), .rotate(toAngle: 0, duration: 0.22)])
        ]), withKey: "bump")
    }
}
