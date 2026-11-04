import SpriteKit
import UIKit


/// The sorter and its pieces share soft, hand-finished wood. Grain is baked once per
/// colour/size, not animated or layered over the faces; the shared cutout paths stay exact.
enum SleepyWoodMaterial {
    private static let cache: NSCache<NSString, SKTexture> = {
        let cache = NSCache<NSString, SKTexture>()
        cache.countLimit = 48
        cache.totalCostLimit = 16 * 1024 * 1024
        return cache
    }()

    private static func blend(_ base: UIColor, with tint: UIColor, amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        var tr: CGFloat = 0, tg: CGFloat = 0, tb: CGFloat = 0
        base.getRed(&r, green: &g, blue: &b, alpha: &a)
        tint.getRed(&tr, green: &tg, blue: &tb, alpha: nil)
        return UIColor(red: r + (tr - r) * amount, green: g + (tg - g) * amount,
                       blue: b + (tb - b) * amount, alpha: a)
    }

    static func apply(to node: SKShapeNode, base: UIColor, size: CGSize, painted: Bool = false) {
        let w = max(8, (size.width / 8).rounded() * 8)
        let h = max(8, (size.height / 8).rounded() * 8)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, alpha: CGFloat = 1
        base.getRed(&r, green: &g, blue: &b, alpha: &alpha)
        let key = String(format: "%.0fx%.0f-%.3f-%.3f-%.3f-%d", w, h, r, g, b, painted ? 1 : 0)
        if let texture = cache.object(forKey: key as NSString) {
            node.fillColor = UIColor(white: 1, alpha: alpha)
            node.fillTexture = texture
            return
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: format).image { context in
            let cg = context.cgContext
            let lit = blend(base, with: WarmShelfPalette.paperHighlight, amount: painted ? 0.16 : 0.12)
            let shade = blend(base, with: WarmShelfPalette.cocoa, amount: painted ? 0.18 : 0.15)
            let colours = [lit.cgColor, base.cgColor, shade.cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colours,
                                         locations: [0, 0.48, 1]) {
                cg.drawLinearGradient(gradient, start: CGPoint(x: w * 0.12, y: 0),
                                      end: CGPoint(x: w * 0.86, y: h),
                                      options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            }
            // Deterministic fine grain; painted pieces show less of the wood underneath.
            var seed: UInt64 = 0x6C756C6C
            func random() -> CGFloat {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return CGFloat((seed >> 40) & 0xFFFFFF) / CGFloat(0xFFFFFF)
            }
            let lineCount = max(12, Int(h / (painted ? 1.3 : 1.1)))
            cg.setLineCap(.round)
            for line in 0..<lineCount {
                let y = (CGFloat(line) + random()) / CGFloat(lineCount) * h
                let bend = (random() - 0.5) * min(h * 0.12, 9)
                let x = -w * 0.1 + random() * w * 0.2
                let length = w * (0.55 + random() * 0.7)
                let light = line.isMultiple(of: 3)
                let ink = light ? WarmShelfPalette.paperHighlight : WarmShelfPalette.cocoa
                cg.setStrokeColor(ink.withAlphaComponent((painted ? 0.035 : 0.065) * (0.4 + random())).cgColor)
                cg.setLineWidth(0.35 + random() * 0.45)
                cg.move(to: CGPoint(x: x, y: y))
                cg.addCurve(to: CGPoint(x: x + length, y: y + bend * 0.3),
                            control1: CGPoint(x: x + length * 0.34, y: y + bend),
                            control2: CGPoint(x: x + length * 0.68, y: y - bend * 0.45))
                cg.strokePath()
            }
            // Tiny matte pores break up a perfectly smooth computer gradient.
            let poreCount = min(900, max(100, Int(w * h / 18)))
            for index in 0..<poreCount {
                let ink = index.isMultiple(of: 2) ? WarmShelfPalette.paperHighlight : WarmShelfPalette.cocoa
                cg.setFillColor(ink.withAlphaComponent(painted ? 0.035 : 0.045).cgColor)
                let d = 0.25 + random() * 0.4
                cg.fillEllipse(in: CGRect(x: random() * w, y: random() * h, width: d, height: d))
            }
        }
        let texture = SKTexture(image: image)
        cache.setObject(texture, forKey: key as NSString, cost: Int(w * h * 4 * format.scale * format.scale))
        node.fillColor = UIColor(white: 1, alpha: alpha)
        node.fillTexture = texture
    }
}

/// A little tactile treasure the child posts into the Sleepy Drop Box. Four distinct, cute,
/// readable silhouettes — a round ball, a triangle, a soft square, and an upright star — each with
/// matte clay/felt material, a soft separating contact shadow, and a gentle lift wobble. No
/// physics: the scene authors all motion, so a treasure can never fly off, stick, or vanish.
final class DropTreasureNode: SKNode {
    enum Kind: CaseIterable { case berry, triangle, cube, star }

    let kind: Kind
    let radius: CGFloat
    let variant: Int   // optional legacy tint; Sleepy Box keeps the same four colors every round

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

    /// The default tint gives each shape a stable identity. Alternate legacy tints remain
    /// available to other callers, but returning a treasure never changes it in this toy.
    var color: UIColor {
        let families: [Kind: [UInt32]] = [
            .berry:    [0xC96F50, 0xC4583F, 0xE0614A],
            .triangle: [0xD9B452, 0xEAA93C, 0xF6CF6E],
            .cube:     [0x829B82, 0x6F9655, 0x93B05A],
            .star:     [0x83AAB9, 0xE8C46E, 0xF2DCA0]
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
            SleepyWoodMaterial.apply(to: body, base: color, size: box.size, painted: true)
        }
        // Light and fine grain belong to one continuous surface, clipped to the exact
        // matching silhouette. Separate glossy ellipses/stripes made these look like icons.

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
        // The new sorter uses the exact shared geometry for pieces and openings.
        // Older bitmaps had padding and a differently oriented star silhouette.
        if ToyArt.texture("sleepybox-v2-shell") != nil { return nil }
        let slot: String
        let fit: CGSize
        switch kind {
        case .berry:    slot = "sleepybox-ball";     fit = CGSize(width: r * 2.0, height: r * 2.0)
        case .triangle: slot = "sleepybox-triangle"; fit = CGSize(width: r * 2.15, height: r * 2.15)
        case .cube:     slot = "sleepybox-cube";     fit = CGSize(width: r * 1.95, height: r * 1.95)
        case .star:     slot = "sleepybox-star";     fit = CGSize(width: r * 2.15, height: r * 2.15)
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
            let a = CGFloat(i) / CGFloat(points * 2) * .pi * 2 + .pi / 2
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
