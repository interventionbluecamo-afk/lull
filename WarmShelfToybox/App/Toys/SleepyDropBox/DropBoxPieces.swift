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

    /// Render the edge INSIDE the shared silhouette. The top face is inset and sits
    /// slightly high, leaving a thicker lower edge: wood has depth without enlarging
    /// a piece beyond its socket or adding a detached shiny sticker to its face.
    static func apply(to node: SKShapeNode, base: UIColor, size: CGSize,
                      painted: Bool = false, bevel: CGFloat = 0.065) {
        guard let path = node.path else { return }
        let bounds = path.boundingBoxOfPath
        guard bounds.width > 0, bounds.height > 0 else { return }
        let w = max(8, (size.width / 8).rounded() * 8)
        let h = max(8, (size.height / 8).rounded() * 8)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, alpha: CGFloat = 1
        base.getRed(&r, green: &g, blue: &b, alpha: &alpha)
        var transform = CGAffineTransform(a: w / bounds.width, b: 0, c: 0, d: -h / bounds.height,
                                         tx: -bounds.minX * w / bounds.width, ty: bounds.maxY * h / bounds.height)
        guard let outline = path.copy(using: &transform) else { return }
        // Include the path: equal-sized knobs, rounded rectangles and pieces cannot
        // accidentally share a bevel. Cache remains bounded across device rotations.
        var pathKey = ""
        outline.applyWithBlock { element in
            let e = element.pointee
            let count: Int
            switch e.type {
            case .moveToPoint, .addLineToPoint: count = 1
            case .addQuadCurveToPoint: count = 2
            case .addCurveToPoint: count = 3
            case .closeSubpath: count = 0
            @unknown default: count = 0
            }
            pathKey += "\(e.type.rawValue):"
            for i in 0..<count { pathKey += String(format: "%.1f,%.1f;", e.points[i].x, e.points[i].y) }
        }
        let key = String(format: "%.0fx%.0f-%.3f-%.3f-%.3f-%d-%.3f-", w, h, r, g, b, painted ? 1 : 0, bevel) + pathKey
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
            let lit = blend(base, with: WarmShelfPalette.paperHighlight, amount: painted ? 0.10 : 0.12)
            let shade = blend(base, with: WarmShelfPalette.cocoa, amount: painted ? 0.13 : 0.12)
            let colours = [lit.cgColor, base.cgColor, shade.cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colours,
                                         locations: [0, 0.5, 1]) {
                cg.drawLinearGradient(gradient, start: CGPoint(x: w * 0.12, y: 0),
                                      end: CGPoint(x: w * 0.86, y: h),
                                      options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            }
            var seed: UInt64 = 0x6C756C6C
            func random() -> CGFloat {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return CGFloat((seed >> 40) & 0xFFFFFF) / CGFloat(0xFFFFFF)
            }
            // A few broad, irregular growth contours, not a row of horizontal stripes.
            // Painted wood almost hides these; exposed wood shares the shell's quiet figure.
            cg.setLineCap(.round)
            for _ in 0..<(painted ? 5 : 10) {
                let y = random() * h
                let bend = (random() - 0.5) * h * 0.7
                let x = -w * 0.3 + random() * w * 0.45
                let length = w * (0.65 + random() * 0.65)
                let contour = CGMutablePath()
                contour.move(to: CGPoint(x: x, y: y))
                contour.addCurve(to: CGPoint(x: x + length, y: y + bend * 0.22),
                                 control1: CGPoint(x: x + length * 0.28, y: y + bend),
                                 control2: CGPoint(x: x + length * 0.54, y: y - bend * 0.55))
                cg.setStrokeColor(WarmShelfPalette.cocoa.withAlphaComponent(painted ? 0.025 : 0.045).cgColor)
                cg.setLineWidth(0.5 + random() * 0.65)
                cg.addPath(contour); cg.strokePath()
            }
            // Broken short fibres and matte pores have no evenly spaced rows. Their
            // contrast remains lower than the face, rim and carved wood edge.
            let poreCount = min(9000, max(350, Int(w * h / 2.2)))
            for index in 0..<poreCount {
                let ink = index.isMultiple(of: 2) ? WarmShelfPalette.paperHighlight : WarmShelfPalette.cocoa
                cg.setFillColor(ink.withAlphaComponent((painted ? 0.045 : 0.065) * (0.35 + random())).cgColor)
                let d = 0.25 + random() * 0.55
                cg.fillEllipse(in: CGRect(x: random() * w, y: random() * h,
                                         width: d * (1 + random() * 2.4), height: d))
            }
            let edge = min(w, h) * bevel
            var faceTransform = CGAffineTransform(a: (w - 2 * edge) / w, b: 0, c: 0,
                                                  d: (h - 2 * edge) / h, tx: edge, ty: edge * 0.45)
            if let face = outline.copy(using: &faceTransform) {
                cg.saveGState()
                cg.beginPath()
                cg.addPath(outline); cg.addPath(face); cg.clip(using: .evenOdd)
                let rimColours = [blend(base, with: WarmShelfPalette.paperHighlight, amount: 0.26).cgColor,
                                  base.cgColor,
                                  blend(base, with: WarmShelfPalette.cocoa, amount: 0.30).cgColor] as CFArray
                if let rim = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: rimColours,
                                        locations: [0, 0.32, 1]) {
                    cg.setAlpha(0.82)
                    // Wide drawers/trays project beyond this diagonal's endpoint.
                    // Extend its end colours over the entire clipped rim; stopping
                    // there leaves an angular unshaded wedge in an otherwise round edge.
                    cg.drawLinearGradient(rim, start: CGPoint(x: 0, y: 0),
                                          end: CGPoint(x: w * 0.15, y: h),
                                          options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                }
                cg.restoreGState()
                cg.beginPath()
                cg.addPath(face)
                cg.setStrokeColor(WarmShelfPalette.cocoa.withAlphaComponent(0.055).cgColor)
                cg.setLineWidth(0.65); cg.strokePath()
            }
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        cache.setObject(texture, forKey: key as NSString, cost: Int(w * h * 4 * format.scale * format.scale))
        node.fillColor = UIColor(white: 1, alpha: alpha)
        node.fillTexture = texture
    }
}

/// A little tactile treasure the child posts into the Sleepy Drop Box. Four distinct, cute,
/// readable silhouettes — a round ball, a triangle, a soft square, and an upright star — each with
/// painted wood, a close contact shadow, and a small weighted lift. No
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
        shadow.alpha = 0.78
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
            SleepyWoodMaterial.apply(to: body, base: color, size: box.size, painted: true, bevel: 0.085)
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
        setAwake(lifted)
        for key in ["lift", "wobble", "squash", "bump"] { body.removeAction(forKey: key) }
        shadow.removeAction(forKey: "lift")
        let duration: TimeInterval = AmbientAnimator.reduceMotion ? 0 : (lifted ? 0.14 : 0.28)
        // The contact stays under the piece; lifting broadens and softens it slightly.
        let contact = SKAction.group([
            .move(to: CGPoint(x: 0, y: -radius * (lifted ? 1.16 : 1.02)), duration: duration),
            .fadeAlpha(to: lifted ? 0.42 : 0.78, duration: duration),
            .scale(to: lifted ? 1.08 : 1, duration: duration)
        ])
        contact.timingMode = .easeOut
        shadow.run(contact, withKey: "lift")
        let pose = SKAction.group([.scale(to: lifted ? 1.055 : 1, duration: duration),
                                   .rotate(toAngle: lifted && !AmbientAnimator.reduceMotion ? 0.025 : 0,
                                           duration: duration)])
        pose.timingMode = lifted ? .easeOut : .easeInEaseOut
        body.run(pose, withKey: "lift")
    }

    /// Wood settles with a minute tilt, not a rubber squash. Retain the caller's
    /// landing-strength vocabulary while keeping every silhouette rigid.
    func squash(_ intensity: CGFloat) {
        guard !AmbientAnimator.reduceMotion else { return }
        body.removeAction(forKey: "squash")
        body.removeAction(forKey: "lift")
        body.setScale(1)
        let tilt = min(0.035, max(0.012, intensity * 0.25))
        let settle = SKAction.rotate(toAngle: 0, duration: 0.30)
        settle.timingMode = .easeInEaseOut
        body.run(.sequence([.rotate(toAngle: tilt, duration: 0.07), settle]), withKey: "squash")
    }

    func bumpRim() {
        guard !AmbientAnimator.reduceMotion else { return }
        body.removeAction(forKey: "bump")
        body.removeAction(forKey: "lift")
        body.setScale(1)
        let settle = SKAction.rotate(toAngle: 0, duration: 0.30)
        settle.timingMode = .easeInEaseOut
        body.run(.sequence([.rotate(toAngle: 0.065, duration: 0.09), settle]), withKey: "bump")
    }

    func settleImmediately() {
        body.removeAllActions(); shadow.removeAllActions()
        body.setScale(1); body.zRotation = 0
        shadow.position = CGPoint(x: 0, y: -radius * 1.02)
        shadow.setScale(1); shadow.alpha = 0.78
        setAwake(false)
    }
}
