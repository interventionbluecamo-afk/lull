import SpriteKit

// MARK: - Seeded randomness (NFT-style: a character is fully described by its seed)

/// Deterministic RNG (SplitMix64). Same seed → same character, every time, on every device.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

private extension UIColor {
    /// Blend toward another colour by `t` (0…1) — for soft shading without new constants.
    func mixed(with other: UIColor, _ t: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(
            red: r1 + (r2 - r1) * t,
            green: g1 + (g2 - g1) * t,
            blue: b1 + (b2 - b1) * t,
            alpha: a1 + (a2 - a1) * t
        )
    }
    var cuteDarkened: UIColor { mixed(with: WarmShelfPalette.cocoa, 0.22) }
}

// MARK: - Harmonised palettes (any pick looks good together)

/// A curated colour family. Cheeks stay rosy across all families — that's a cute constant.
struct CutePalette {
    let body: UIColor
    let belly: UIColor
    let cheek: UIColor
    let accent: UIColor
    let ink: UIColor

    var bodyDark: UIColor { body.cuteDarkened }

    static let families: [CutePalette] = [
        CutePalette(body: WarmShelfPalette.petal,      belly: WarmShelfPalette.paperHighlight, cheek: WarmShelfPalette.rhubarb,    accent: WarmShelfPalette.butter,     ink: WarmShelfPalette.cocoa),
        CutePalette(body: WarmShelfPalette.waterBlue,  belly: WarmShelfPalette.paperHighlight, cheek: WarmShelfPalette.petal,      accent: WarmShelfPalette.butter,     ink: WarmShelfPalette.cocoa),
        CutePalette(body: WarmShelfPalette.sage,       belly: WarmShelfPalette.linen,          cheek: WarmShelfPalette.petal,      accent: WarmShelfPalette.butter,     ink: WarmShelfPalette.cocoa),
        CutePalette(body: WarmShelfPalette.butter,     belly: WarmShelfPalette.paperHighlight, cheek: WarmShelfPalette.terracotta, accent: WarmShelfPalette.terracotta, ink: WarmShelfPalette.cocoa),
        CutePalette(body: WarmShelfPalette.terracotta, belly: WarmShelfPalette.butter,         cheek: WarmShelfPalette.rhubarb,    accent: WarmShelfPalette.butter,     ink: WarmShelfPalette.cocoa),
        CutePalette(body: WarmShelfPalette.lavender,   belly: WarmShelfPalette.paperHighlight, cheek: WarmShelfPalette.petal,      accent: WarmShelfPalette.butter,     ink: WarmShelfPalette.cocoa),
        CutePalette(body: WarmShelfPalette.sand,       belly: WarmShelfPalette.linen,          cheek: WarmShelfPalette.petal,      accent: WarmShelfPalette.terracotta, ink: WarmShelfPalette.cocoa),
        CutePalette(body: UIColor(hex: 0x9B6B43),      belly: WarmShelfPalette.sand,           cheek: WarmShelfPalette.petal,      accent: WarmShelfPalette.butter,     ink: WarmShelfPalette.cocoa)
    ]

    static func random(using rng: inout SeededGenerator) -> CutePalette {
        families.randomElement(using: &rng) ?? families[0]
    }
}

// MARK: - The cute face core (the Pudgy-Penguins cuteness, in one place)

enum CuteEyeStyle: CaseIterable { case round, sleepy, sparkle, wink }
enum CuteMouthStyle: CaseIterable { case smile, content, openSmile, tinyO }

/// Builds a reliably adorable face. Big eyes set low, wet glints, rosy cheeks, soft mouth.
/// Every character in Lull should get its face from here so cuteness is consistent.
struct CuteFace {
    var eyes: CuteEyeStyle = .round
    var mouth: CuteMouthStyle = .smile
    var eyeSpacing: CGFloat = 17
    var eyeY: CGFloat = 5
    var eyeRadius: CGFloat = 8.5
    var cheekSpacing: CGFloat = 30
    var cheekY: CGFloat = -7
    var cheekRadius: CGFloat = 6
    var mouthY: CGFloat = -14
    var mouthWidth: CGFloat = 15
    var ink: UIColor = WarmShelfPalette.cocoa
    var cheek: UIColor = WarmShelfPalette.petal

    func add(to node: SKNode, s: CGFloat) {
        CuteFace.cheeks(on: node, s: s, spacing: cheekSpacing, y: cheekY, r: cheekRadius, color: cheek)
        CuteFace.eyes(on: node, s: s, spacing: eyeSpacing, y: eyeY, r: eyeRadius, style: eyes, ink: ink)
        CuteFace.mouth(on: node, s: s, width: mouthWidth, y: mouthY, style: mouth, ink: ink)
    }

    // MARK: Shared feature builders (reused by every character in the app)

    static func eyes(on node: SKNode, s: CGFloat, spacing: CGFloat, y: CGFloat, r: CGFloat,
                     style: CuteEyeStyle = .round, ink: UIColor = WarmShelfPalette.cocoa) {
        for sign in [CGFloat(-1), CGFloat(1)] {
            let p = CGPoint(x: sign * spacing * s, y: y * s)
            let isArc = style == .sleepy || (style == .wink && sign < 0)
            if isArc {
                arcEye(on: node, at: p, r: r * s, ink: ink)
            } else {
                eyeball(on: node, at: p, r: r * s, sparkle: style == .sparkle, ink: ink)
            }
        }
    }

    private static func eyeball(on node: SKNode, at p: CGPoint, r: CGFloat, sparkle: Bool, ink: UIColor) {
        let white = SKShapeNode(circleOfRadius: r)
        white.fillColor = WarmShelfPalette.paperHighlight; white.strokeColor = .clear
        white.position = p; node.addChild(white)
        let pupil = SKShapeNode(circleOfRadius: r * 0.62)
        pupil.fillColor = ink.withAlpha(0.9); pupil.strokeColor = .clear
        pupil.position = CGPoint(x: p.x + r * 0.12, y: p.y - r * 0.06); node.addChild(pupil)
        // Big glint = wet, alive eyes.
        let glint = SKShapeNode(circleOfRadius: r * 0.26)
        glint.fillColor = WarmShelfPalette.paperHighlight; glint.strokeColor = .clear
        glint.position = CGPoint(x: p.x - r * 0.22, y: p.y + r * 0.30); node.addChild(glint)
        if sparkle {
            let spark = SKShapeNode(circleOfRadius: r * 0.12)
            spark.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.8); spark.strokeColor = .clear
            spark.position = CGPoint(x: p.x + r * 0.28, y: p.y - r * 0.18); node.addChild(spark)
        }
    }

    private static func arcEye(on node: SKNode, at p: CGPoint, r: CGFloat, ink: UIColor) {
        let path = CGMutablePath()
        path.addArc(center: p, radius: r * 0.9, startAngle: .pi * 0.15, endAngle: .pi * 0.85, clockwise: false)
        let lash = SKShapeNode(path: path)
        lash.strokeColor = ink.withAlpha(0.85); lash.lineWidth = 2.6 * (r / 8.5); lash.lineCap = .round; lash.fillColor = .clear
        node.addChild(lash)
    }

    static func cheeks(on node: SKNode, s: CGFloat, spacing: CGFloat, y: CGFloat, r: CGFloat,
                       color: UIColor = WarmShelfPalette.petal) {
        for sign in [CGFloat(-1), CGFloat(1)] {
            let c = SKShapeNode(circleOfRadius: r * s)
            c.fillColor = color.withAlpha(0.45); c.strokeColor = .clear
            c.position = CGPoint(x: sign * spacing * s, y: y * s); node.addChild(c)
        }
    }

    static func mouth(on node: SKNode, s: CGFloat, width: CGFloat, y: CGFloat,
                      style: CuteMouthStyle = .smile, ink: UIColor = WarmShelfPalette.cocoa) {
        switch style {
        case .smile, .content:
            let drop: CGFloat = style == .smile ? width * 0.62 : width * 0.34
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -width * s, y: y * s))
            path.addQuadCurve(to: CGPoint(x: width * s, y: y * s), control: CGPoint(x: 0, y: (y - drop) * s))
            let m = SKShapeNode(path: path)
            m.strokeColor = ink.withAlpha(0.6); m.lineWidth = 2.4 * s; m.lineCap = .round; m.fillColor = .clear
            node.addChild(m)
        case .openSmile:
            let m = SKShapeNode(ellipseOf: CGSize(width: width * 1.5 * s, height: width * 1.1 * s))
            m.fillColor = WarmShelfPalette.rhubarb.withAlpha(0.55); m.strokeColor = .clear
            m.position = CGPoint(x: 0, y: y * s); node.addChild(m)
        case .tinyO:
            let m = SKShapeNode(circleOfRadius: width * 0.3 * s)
            m.fillColor = ink.withAlpha(0.5); m.strokeColor = .clear
            m.position = CGPoint(x: 0, y: y * s); node.addChild(m)
        }
    }
}
