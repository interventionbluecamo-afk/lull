import SpriteKit

/// The little bedtime world a Glowboard controls: a moon, a small string of stars, a felt cloud,
/// a couple of distant window lights, a warm lamp glow, and fireflies. It owns no touch logic —
/// the board's controls drive it through these setters, so cause (a control) and effect (the
/// world) stay cleanly separated.
///
/// The lights (lamp, moon, stars, fireflies) are drawn additively so they read as light over the
/// dimmer's night veil — but every glow is kept small and local, so the toy is the hero and the
/// atmosphere only frames it.
final class GlowWorldNode: SKNode {

    // Physical bodies (sit behind the veil — dimmed with the room)
    private let skyLayer = SKNode()
    private let moonDisc = SKShapeNode()
    private let moonShade = SKShapeNode()
    private let cloud = SKNode()
    private var starWire: SKShapeNode?

    // Light (additive — reads over the dark)
    private let glowLayer = SKNode()
    private let moonGlow = SKShapeNode()
    private let lampGlow = SKShapeNode()
    private let starLayer = SKNode()
    private let fireflyLayer = SKNode()
    private var stars: [SKShapeNode] = []

    private var worldSize: CGSize = .zero
    private var moonRadius: CGFloat = 22
    private var moonCenter: CGPoint = .zero

    /// Where the board's big "lamp" button sits, and how wide its glow pools — the scene sets
    /// these so the light spills locally around the real control, never as a screen-wide disc.
    var lampOrigin: CGPoint = .zero { didSet { lampGlow.position = lampOrigin } }
    var lampGlowRadius: CGFloat = 90

    private var lampLevel: CGFloat = 0
    private var moonLevel: CGFloat = 0.5
    private var starsUp = false

    override init() {
        super.init()
        skyLayer.zPosition = 0
        addChild(skyLayer)
        glowLayer.zPosition = 5
        addChild(glowLayer)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Layout

    func layout(in size: CGSize) {
        worldSize = size
        skyLayer.removeAllChildren()
        glowLayer.removeAllChildren()
        stars.removeAll()

        let landscape = size.width > size.height
        moonRadius = min(size.width, size.height) * (landscape ? 0.05 : 0.062)
        moonCenter = CGPoint(x: size.width * (landscape ? 0.84 : 0.80),
                             y: size.height * (landscape ? 0.84 : 0.88))

        buildWindowLights(in: size)
        buildCloud(in: size)
        buildMoon()
        buildStarString(in: size)
        buildLampGlow()

        applyMoon(animated: false)
        applyLamp(animated: false)
        applyStars(animated: false)
    }

    /// A couple of tiny far-off warm windows, like neighbouring houses settling for the night.
    private func buildWindowLights(in size: CGSize) {
        for (fx, fy, w) in [(0.10, 0.74, 0.030), (0.165, 0.70, 0.022)] as [(CGFloat, CGFloat, CGFloat)] {
            let wide = size.width * w
            let frame = SKShapeNode(rect: CGRect(x: -wide / 2 - 1.5, y: -wide * 0.7 - 1.5, width: wide + 3, height: wide * 1.4 + 3), cornerRadius: 2.5)
            frame.fillColor = WarmShelfPalette.cocoa.withAlpha(0.16)
            frame.strokeColor = .clear
            frame.position = CGPoint(x: size.width * fx, y: size.height * fy)
            frame.zPosition = 0.2
            skyLayer.addChild(frame)
            let pane = SKShapeNode(rect: CGRect(x: -wide / 2, y: -wide * 0.7, width: wide, height: wide * 1.4), cornerRadius: 2)
            pane.fillColor = WarmShelfPalette.butter.withAlpha(0.5)
            pane.strokeColor = .clear
            pane.blendMode = .add
            pane.position = frame.position
            pane.zPosition = 0.25
            skyLayer.addChild(pane)
        }
    }

    private func buildCloud(in size: CGSize) {
        cloud.removeFromParent()
        cloud.removeAllChildren()
        cloud.zPosition = 0.5
        let base = min(size.width, size.height) * 0.05
        let puffs: [(CGFloat, CGFloat, CGFloat)] = [(-base, 0, base * 0.9), (0, base * 0.2, base * 1.1), (base, 0, base * 0.82)]
        for puff in puffs {
            let e = SKShapeNode(ellipseOf: CGSize(width: puff.2 * 2.0, height: puff.2 * 1.2))
            e.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.20)
            e.strokeColor = .clear
            e.position = CGPoint(x: puff.0, y: puff.1)
            cloud.addChild(e)
        }
        cloud.position = CGPoint(x: moonCenter.x - moonRadius * 3.4, y: moonCenter.y - moonRadius * 1.0)
        skyLayer.addChild(cloud)
        if !AmbientAnimator.reduceMotion {
            cloud.run(.repeatForever(.sequence([
                .moveBy(x: base * 0.6, y: 0, duration: 10), .moveBy(x: -base * 0.6, y: 0, duration: 10)
            ])))
        }
    }

    private func buildMoon() {
        let r = moonRadius
        moonDisc.path = CGPath(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2), transform: nil)
        moonDisc.fillColor = UIColor(hex: 0xF4EFD6)
        moonDisc.strokeColor = WarmShelfPalette.sand.withAlpha(0.22)
        moonDisc.lineWidth = 1
        moonDisc.position = moonCenter
        moonDisc.zPosition = 1
        skyLayer.addChild(moonDisc)

        for (dx, dy, cr) in [(-0.30, 0.18, 0.18), (0.24, 0.30, 0.13), (0.06, -0.34, 0.15)] as [(CGFloat, CGFloat, CGFloat)] {
            let crater = SKShapeNode(circleOfRadius: r * cr)
            crater.fillColor = WarmShelfPalette.sand.withAlpha(0.16)
            crater.strokeColor = .clear
            crater.position = CGPoint(x: r * dx, y: r * dy)
            crater.zPosition = 0.1
            moonDisc.addChild(crater)
        }

        moonShade.path = CGPath(ellipseIn: CGRect(x: -r * 1.04, y: -r * 1.04, width: r * 2.08, height: r * 2.08), transform: nil)
        moonShade.fillColor = WarmShelfPalette.linen
        moonShade.strokeColor = .clear
        moonShade.zPosition = 0.5
        moonDisc.addChild(moonShade)

        // A small, soft halo — not a screen-eating disc.
        let glowR = r * 2.0
        moonGlow.path = CGPath(ellipseIn: CGRect(x: -glowR, y: -glowR, width: glowR * 2, height: glowR * 2), transform: nil)
        moonGlow.fillColor = UIColor(hex: 0xCFE0F2).withAlpha(0.3)
        moonGlow.strokeColor = .clear
        moonGlow.blendMode = .add
        moonGlow.position = moonCenter
        moonGlow.zPosition = 0
        glowLayer.addChild(moonGlow)
    }

    /// A little string of bulb-stars hung across the upper sky — a fairy-light string the star
    /// switch turns on and off, far more charming (and premium) than a scatter of dots.
    private func buildStarString(in size: CGSize) {
        starLayer.removeFromParent()
        starLayer.removeAllChildren()
        starLayer.zPosition = 1
        glowLayer.addChild(starLayer)

        let x0 = size.width * 0.09
        let x1 = size.width * 0.66
        let baseY = size.height * 0.90
        let sag = size.height * 0.028

        // The wire (a faint physical cord).
        let wire = CGMutablePath()
        let steps = 24
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = x0 + (x1 - x0) * t
            let y = baseY - sag * sin(.pi * t)
            if i == 0 { wire.move(to: CGPoint(x: x, y: y)) } else { wire.addLine(to: CGPoint(x: x, y: y)) }
        }
        let wireNode = SKShapeNode(path: wire)
        wireNode.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.22)
        wireNode.lineWidth = 1.4
        wireNode.fillColor = .clear
        wireNode.zPosition = 0.4
        skyLayer.addChild(wireNode)
        starWire = wireNode

        let count = 6
        for i in 0..<count {
            let t = (CGFloat(i) + 0.5) / CGFloat(count)
            let x = x0 + (x1 - x0) * t
            let y = baseY - sag * sin(.pi * t) - 6

            // A small dark socket on the wire (always visible, so the string reads when off).
            let socket = SKShapeNode(circleOfRadius: 2.2)
            socket.fillColor = WarmShelfPalette.cocoa.withAlpha(0.32)
            socket.strokeColor = .clear
            socket.position = CGPoint(x: x, y: y + 5)
            socket.zPosition = 0.45
            skyLayer.addChild(socket)

            let bulb = makeStar(radius: CGFloat.random(in: 3.0...4.4))
            bulb.position = CGPoint(x: x, y: y)
            bulb.alpha = 0
            bulb.setScale(0.4)
            starLayer.addChild(bulb)
            stars.append(bulb)
        }
    }

    private func makeStar(radius: CGFloat) -> SKShapeNode {
        let path = CGMutablePath()
        let r = radius, inner = radius * 0.4
        for i in 0..<8 {
            let a = CGFloat(i) / 8 * .pi * 2 - .pi / 2
            let rad = i.isMultiple(of: 2) ? r : inner
            let p = CGPoint(x: cos(a) * rad, y: sin(a) * rad)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        let star = SKShapeNode(path: path)
        star.fillColor = UIColor(hex: 0xFBF4DA).withAlpha(0.95)
        star.strokeColor = .clear
        star.blendMode = .add
        return star
    }

    private func buildLampGlow() {
        let r = lampGlowRadius
        lampGlow.path = CGPath(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2), transform: nil)
        lampGlow.fillColor = WarmShelfPalette.butter.withAlpha(0.32)
        lampGlow.strokeColor = .clear
        lampGlow.blendMode = .add
        lampGlow.position = lampOrigin
        lampGlow.zPosition = 0.4
        lampGlow.alpha = 0
        lampGlow.removeAllChildren()
        // A hotter inner core for a soft falloff, instead of one flat disc.
        let core = SKShapeNode(circleOfRadius: r * 0.5)
        core.fillColor = UIColor(hex: 0xFFE6A0).withAlpha(0.5)
        core.strokeColor = .clear
        core.blendMode = .add
        core.zPosition = 0.1
        lampGlow.addChild(core)
        glowLayer.addChild(lampGlow)

        fireflyLayer.removeFromParent()
        fireflyLayer.zPosition = 2
        glowLayer.addChild(fireflyLayer)
    }

    // MARK: - State the controls drive

    func setLamp(_ level: CGFloat, animated: Bool = true) {
        lampLevel = max(0, min(1, level))
        applyLamp(animated: animated)
    }

    func setMoon(_ level: CGFloat, animated: Bool = true) {
        moonLevel = max(0, min(1, level))
        applyMoon(animated: animated)
    }

    func setStars(up: Bool) {
        guard up != starsUp else { return }
        starsUp = up
        applyStars(animated: true)
    }

    private func applyLamp(animated: Bool) {
        // A local pool that blooms quickly and exhales slowly — quick to wake, slow to settle.
        let targetAlpha = 0.08 + 0.8 * lampLevel
        let targetScale = 0.72 + 0.4 * lampLevel
        lampGlow.removeAction(forKey: "lamp")
        guard animated, !AmbientAnimator.reduceMotion else {
            lampGlow.alpha = targetAlpha; lampGlow.setScale(targetScale); return
        }
        let fade = SKAction.fadeAlpha(to: targetAlpha, duration: 0.5)
        let scale = SKAction.scale(to: targetScale, duration: 0.5)
        fade.timingMode = .easeOut; scale.timingMode = .easeOut
        lampGlow.run(.group([fade, scale]), withKey: "lamp")
    }

    private func applyMoon(animated: Bool) {
        let r = moonRadius
        let shadeX = -r * 0.55 + (r * 2.6) * moonLevel
        let glowAlpha = 0.05 + 0.32 * moonLevel
        moonShade.removeAction(forKey: "phase")
        moonGlow.removeAction(forKey: "phase")
        guard animated, !AmbientAnimator.reduceMotion else {
            moonShade.position.x = shadeX
            moonGlow.alpha = glowAlpha
            return
        }
        let slide = SKAction.moveTo(x: shadeX, duration: 0.42); slide.timingMode = .easeInEaseOut
        let glow = SKAction.fadeAlpha(to: glowAlpha, duration: 0.42); glow.timingMode = .easeInEaseOut
        moonShade.run(slide, withKey: "phase")
        moonGlow.run(glow, withKey: "phase")
    }

    private func applyStars(animated: Bool) {
        for (index, star) in stars.enumerated() {
            star.removeAction(forKey: "twinkle")
            if starsUp {
                let delay = animated ? Double(index) * 0.08 : 0
                let appear = SKAction.group([.fadeAlpha(to: 0.95, duration: 0.4), .scale(to: 1, duration: 0.4)])
                appear.timingMode = .easeOut
                star.run(.sequence([.wait(forDuration: delay), appear, .run { [weak self, weak star] in
                    guard let self, let star else { return }
                    self.startTwinkle(star)
                }]))
            } else {
                let delay = animated ? Double(stars.count - index) * 0.07 : 0
                let vanish = SKAction.group([.fadeOut(withDuration: 0.5), .scale(to: 0.4, duration: 0.5)])
                vanish.timingMode = .easeIn
                star.run(.sequence([.wait(forDuration: delay), vanish]))
            }
        }
    }

    private func startTwinkle(_ star: SKShapeNode) {
        guard !AmbientAnimator.reduceMotion else { return }
        let dim = SKAction.fadeAlpha(to: 0.55, duration: .random(in: 1.4...2.4))
        let bright = SKAction.fadeAlpha(to: 0.95, duration: .random(in: 1.4...2.4))
        dim.timingMode = .easeInEaseOut; bright.timingMode = .easeInEaseOut
        star.run(.repeatForever(.sequence([dim, bright])), withKey: "twinkle")
    }

    // MARK: - Fireflies (the pull-cord payoff)

    func releaseFireflies(count: Int, from point: CGPoint) {
        let n = AmbientAnimator.reduceMotion ? max(2, count / 2) : count
        for i in 0..<n {
            let delay = Double(i) * 0.06
            run(.sequence([.wait(forDuration: delay), .run { [weak self] in
                self?.spawnFirefly(from: point)
            }]))
        }
    }

    private func spawnFirefly(from point: CGPoint) {
        let fly = SKShapeNode(circleOfRadius: CGFloat.random(in: 2.6...4.0))
        fly.fillColor = (Bool.random() ? WarmShelfPalette.butter : WarmShelfPalette.sage).withAlpha(0.85)
        fly.strokeColor = .clear
        fly.blendMode = .add
        fly.position = CGPoint(x: point.x + .random(in: -10...10), y: point.y + .random(in: -8...8))
        fly.setScale(0.3)
        fireflyLayer.addChild(fly)

        if AmbientAnimator.reduceMotion {
            fly.run(.sequence([
                .group([.fadeAlpha(to: 0.8, duration: 0.4), .scale(to: 1, duration: 0.4)]),
                .wait(forDuration: 1.6),
                .fadeOut(withDuration: 1.2), .removeFromParent()
            ]))
            return
        }

        let life = Double.random(in: 3.2...5.0)
        let appear = SKAction.group([.fadeAlpha(to: 0.9, duration: 0.5), .scale(to: 1, duration: 0.5)])
        appear.timingMode = .easeOut

        var wander: [SKAction] = []
        var steps = Int(life / 0.9)
        while steps > 0 {
            let move = SKAction.moveBy(x: .random(in: -34...34), y: .random(in: 14...46), duration: 0.9)
            move.timingMode = .easeInEaseOut
            wander.append(move)
            steps -= 1
        }
        let twinkle = SKAction.repeatForever(.sequence([
            .fadeAlpha(to: 0.45, duration: .random(in: 0.4...0.8)),
            .fadeAlpha(to: 0.9, duration: .random(in: 0.4...0.8))
        ]))
        fly.run(twinkle, withKey: "twinkle")
        fly.run(.sequence([
            appear,
            .group([.sequence(wander), .sequence([.wait(forDuration: life - 1.0), .fadeOut(withDuration: 1.0)])]),
            .removeFromParent()
        ]))
    }
}
