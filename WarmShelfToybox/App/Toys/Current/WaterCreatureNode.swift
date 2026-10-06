import SpriteKit

/// A small clay jellyfish-creature that lives in the Current water.
///
/// Same host law as Wren (`LullHostNode`): it rests with sleepy eyes, notices a
/// disturbance, swims toward the splash that woke it, and always drifts back home
/// to sleep. A child can chase the creatures with waves — they never get lost.
final class WaterCreatureNode: SKNode {

    enum CreatureState: Equatable {
        case sleeping
        case noticing
        case swimming(toward: CGPoint)
        case scattering
    }

    // MARK: - Public

    var homePosition: CGPoint = .zero
    private(set) var currentState: CreatureState = .sleeping

    /// The scene only reacts to creatures that are calm at home.
    var isAtRest: Bool { currentState == .sleeping }

    /// Generous hit area for a direct boop (toddlers don't aim).
    var touchRadius: CGFloat { r * 1.7 }

    // MARK: - Geometry

    private let r: CGFloat
    private let bodyColor: SKColor

    private let breathing = SKNode()
    private let glow: SKShapeNode
    private var body: SKShapeNode!

    private var tentacles: [SKShapeNode] = []
    private var sleepyEyes: [SKShapeNode] = []
    private var openEyes: [SKNode] = []
    private var mouth: SKShapeNode?

    // MARK: - Action keys

    private let breatheKey = "creature.breathe"
    private let eyeKey = "creature.eyes"
    private let moveKey = "creature.move"
    private let liftKey = "creature.lift"
    private let glowKey = "creature.glow"
    private let resettleKey = "creature.resettle"
    private let tentacleKey = "creature.tentacle"
    private let idleKey = "creature.idle"

    // MARK: - Init

    init(diameter: CGFloat = 38) {
        r = diameter / 2
        // Warm sage-teal: the calm water creatures, not cold blue.
        bodyColor = SKColor(red: 0.45, green: 0.69, blue: 0.63, alpha: 1.0)

        let g = SKShapeNode(ellipseOf: CGSize(width: diameter * 1.4, height: diameter * 1.4 * 0.84))
        g.fillColor = bodyColor.withAlpha(0.12)
        g.strokeColor = .clear
        g.zPosition = -1
        glow = g

        super.init()
        addChild(glow)
        addChild(breathing)
        build()
        goToSleep(animated: false)
    }

    required init?(coder aDecoder: NSCoder) {
        r = 19
        bodyColor = SKColor(red: 0.45, green: 0.69, blue: 0.63, alpha: 1.0)
        glow = SKShapeNode()
        super.init(coder: aDecoder)
    }

    // MARK: - Build

    private func build() {
        // Tentacles hang behind the body so the body reads as the front of the bell.
        let count = 6
        for index in 0..<count {
            let frac = CGFloat(index) / CGFloat(count - 1)        // 0...1
            let x = (-0.60 + 1.20 * frac) * r
            let length = r * (0.66 + 0.20 * sin(frac * .pi))      // longer in the middle
            let width = r * 0.17

            let path = CGMutablePath()
            path.addRoundedRect(
                in: CGRect(x: -width / 2, y: -length, width: width, height: length),
                cornerWidth: width / 2, cornerHeight: width / 2
            )
            let tentacle = SKShapeNode(path: path)
            tentacle.fillColor = bodyColor.withAlpha(0.92)
            tentacle.strokeColor = .clear
            tentacle.position = CGPoint(x: x, y: -r * 0.62)
            tentacle.zPosition = -0.5
            breathing.addChild(tentacle)
            tentacles.append(tentacle)
        }

        body = SKShapeNode(path: bodyPath())
        body.fillColor = bodyColor
        body.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.06)
        body.lineWidth = 1.0
        body.zPosition = 0
        breathing.addChild(body)

        // Cream highlight, upper-left.
        let highlight = SKShapeNode(ellipseOf: CGSize(width: r * 0.86, height: r * 0.5))
        highlight.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.55)
        highlight.strokeColor = .clear
        highlight.position = CGPoint(x: -r * 0.4, y: r * 0.36)
        highlight.zRotation = -0.32
        highlight.zPosition = 0.3
        body.addChild(highlight)

        // Terracotta dimple accents.
        let dimples: [(CGPoint, CGFloat)] = [
            (CGPoint(x: 0.42, y: 0.24), 0.10),
            (CGPoint(x: -0.5, y: -0.2), 0.08),
            (CGPoint(x: 0.16, y: -0.46), 0.07),
            (CGPoint(x: 0.6, y: -0.3), 0.06)
        ]
        for (pt, rad) in dimples {
            let dimple = SKShapeNode(circleOfRadius: rad * r)
            dimple.fillColor = WarmShelfPalette.terracotta.withAlpha(0.30)
            dimple.strokeColor = .clear
            dimple.position = CGPoint(x: pt.x * r, y: pt.y * r)
            dimple.zPosition = 0.4
            body.addChild(dimple)
        }

        buildFace()
    }

    private func buildFace() {
        let eyeX = r * 0.34
        let eyeY = r * 0.10

        for sign in [CGFloat(-1), CGFloat(1)] {
            let sleepy = SKShapeNode(path: sleepyEyeArcPath(openFraction: 1))
            sleepy.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.78)
            sleepy.lineWidth = max(1.4, r * 0.05)
            sleepy.lineCap = .round
            sleepy.fillColor = .clear
            sleepy.position = CGPoint(x: sign * eyeX, y: eyeY)
            sleepy.zPosition = 3
            body.addChild(sleepy)
            sleepyEyes.append(sleepy)

            let eye = SKNode()
            eye.position = CGPoint(x: sign * eyeX, y: eyeY + r * 0.01)
            eye.zPosition = 4

            let white = SKShapeNode(ellipseOf: CGSize(width: r * 0.26, height: r * 0.29))
            white.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.96)
            white.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.10)
            white.lineWidth = 0.8
            eye.addChild(white)

            let pupil = SKShapeNode(circleOfRadius: r * 0.085)
            pupil.fillColor = WarmShelfPalette.cocoa.withAlpha(0.88)
            pupil.strokeColor = .clear
            pupil.position = CGPoint(x: sign * r * 0.012, y: -r * 0.006)
            eye.addChild(pupil)

            let glint = SKShapeNode(circleOfRadius: r * 0.026)
            glint.fillColor = .white.withAlpha(0.9)
            glint.strokeColor = .clear
            glint.position = CGPoint(x: -r * 0.04, y: r * 0.045)
            eye.addChild(glint)

            eye.alpha = 0
            eye.yScale = 0.01
            body.addChild(eye)
            openEyes.append(eye)
        }

        let m = SKShapeNode(path: smilePath())
        m.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.55)
        m.lineWidth = max(1.2, r * 0.045)
        m.lineCap = .round
        m.fillColor = .clear
        m.position = CGPoint(x: 0, y: -r * 0.24)
        m.zPosition = 3
        body.addChild(m)
        mouth = m
    }

    private func bodyPath() -> CGPath {
        let n = 24
        let squashY: CGFloat = 0.84
        var pts: [CGPoint] = []
        for i in 0..<n {
            let a = CGFloat(i) / CGFloat(n) * .pi * 2
            let lump = 1 + 0.06 * sin(a * 3 + 0.5) + 0.035 * cos(a * 2)
            pts.append(CGPoint(x: cos(a) * r * lump, y: sin(a) * r * lump * squashY))
        }
        let path = CGMutablePath()
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        path.move(to: mid(pts[n - 1], pts[0]))
        for i in 0..<n {
            path.addQuadCurve(to: mid(pts[i], pts[(i + 1) % n]), control: pts[i])
        }
        path.closeSubpath()
        return path
    }

    private func sleepyEyeArcPath(openFraction: CGFloat) -> CGPath {
        let p = CGMutablePath()
        let ew = r * 0.2
        p.move(to: CGPoint(x: -ew, y: 0))
        p.addQuadCurve(to: CGPoint(x: ew, y: 0), control: CGPoint(x: 0, y: r * 0.15 * openFraction))
        return p
    }

    private func smilePath() -> CGPath {
        let p = CGMutablePath()
        let w = r * 0.2
        p.move(to: CGPoint(x: -w, y: 0))
        p.addQuadCurve(to: CGPoint(x: w, y: 0), control: CGPoint(x: 0, y: -r * 0.12))
        return p
    }

    // MARK: - Opening invitation

    /// Briefly open the eyes, glance around, and close again — the toy's hello.
    func playWakeInvite(after delay: TimeInterval) {
        guard !AmbientAnimator.reduceMotion else { return }
        run(.sequence([
            .wait(forDuration: delay),
            .run { [weak self] in
                guard let self, self.currentState == .sleeping else { return }
                self.showSleeping(false, duration: 0.22)
                self.brightenGlow(to: 0.2, duration: 0.3)
                self.perkTentacles(fast: false)
            },
            .wait(forDuration: 0.85),
            .run { [weak self] in
                guard let self, self.currentState == .sleeping else { return }
                self.showSleeping(true, duration: 0.34)
                self.brightenGlow(to: 0.12, duration: 0.5)
            }
        ]), withKey: resettleKey)
    }

    // MARK: - States

    func notice(lookToward point: CGPoint? = nil) {
        guard currentState == .sleeping || currentState == .noticing else { return }
        currentState = .noticing
        removeAction(forKey: resettleKey)
        removeAction(forKey: idleKey)

        showSleeping(false, duration: 0.16)
        brightenGlow(to: 0.25, duration: 0.2)
        liftBody(by: r * 0.1, duration: 0.18)
        animateTentacles(fast: true)
        perkTentacles(fast: true)

        if let point { lean(toward: point) }

        // If nothing else takes over, drift back to sleep on its own.
        run(.sequence([
            .wait(forDuration: 1.6),
            .run { [weak self] in
                guard let self, self.currentState == .noticing else { return }
                self.returnHome()
            }
        ]), withKey: resettleKey)
    }

    func swim(toward point: CGPoint) {
        currentState = .swimming(toward: point)
        removeAction(forKey: resettleKey)
        removeAction(forKey: idleKey)
        removeAction(forKey: moveKey)

        showSleeping(false, duration: 0.14)
        brightenGlow(to: 0.25, duration: 0.2)
        liftBody(by: r * 0.12, duration: 0.18)
        animateTentacles(fast: true)
        lean(toward: point)

        // Stop a little short of the finger so the creature gathers around it rather than
        // landing exactly on the touch point.
        let dx = point.x - position.x
        let dy = point.y - position.y
        let dist = max(hypot(dx, dy), 1)
        let stop = max(0, dist - r * 1.3)
        let target = CGPoint(x: position.x + dx / dist * stop, y: position.y + dy / dist * stop)

        let move = SKAction.move(to: target, duration: 1.0)
        move.timingMode = .easeOut
        run(.sequence([move, .run { [weak self] in self?.returnHome() }]), withKey: moveKey)
    }

    /// Booped directly! A happy squish, a little spin, bright eyes — pure payoff, no waiting.
    func giggle() {
        removeAction(forKey: resettleKey)
        removeAction(forKey: idleKey)
        removeAction(forKey: moveKey)
        currentState = .noticing

        showSleeping(false, duration: 0.1)
        brightenGlow(to: 0.3, duration: 0.12)
        animateTentacles(fast: true)
        perkTentacles(fast: true)

        guard !AmbientAnimator.reduceMotion else {
            run(.sequence([.wait(forDuration: 0.6), .run { [weak self] in self?.goToSleep(animated: true) }]), withKey: moveKey)
            return
        }

        breathing.removeAction(forKey: breatheKey)
        let squash = SKAction.scaleX(to: 1.22, y: 0.82, duration: 0.1)
        let rebound = SKAction.scaleX(to: 0.9, y: 1.14, duration: 0.12)
        let settle = SKAction.scale(to: 1.0, duration: 0.18)
        squash.timingMode = .easeOut
        rebound.timingMode = .easeOut
        settle.timingMode = .easeInEaseOut
        breathing.run(.sequence([squash, rebound, settle]), withKey: "creature.giggle")

        // A whole-body twirl of delight.
        let spin = SKAction.rotate(byAngle: .pi * 2, duration: 0.5)
        spin.timingMode = .easeInEaseOut
        breathing.run(spin, withKey: "creature.lean")

        let hop = SKAction.sequence([
            .moveBy(x: 0, y: r * 0.5, duration: 0.14),
            .moveBy(x: 0, y: -r * 0.5, duration: 0.2)
        ])
        hop.timingMode = .easeOut
        run(hop)

        run(.sequence([
            .wait(forDuration: 0.9),
            .run { [weak self] in
                guard let self, self.currentState == .noticing else { return }
                self.goToSleep(animated: true)
            }
        ]), withKey: resettleKey)
    }

    func scatter(from point: CGPoint, within bounds: CGSize) {
        currentState = .scattering
        removeAction(forKey: resettleKey)
        removeAction(forKey: idleKey)
        removeAction(forKey: moveKey)

        showSleeping(false, duration: 0.1)
        brightenGlow(to: 0.25, duration: 0.12)
        animateTentacles(fast: true)

        var dx = position.x - point.x
        var dy = position.y - point.y
        let len = max(hypot(dx, dy), 0.001)
        dx /= len; dy /= len
        let flee = r * 4.2
        let target = CGPoint(
            x: (position.x + dx * flee).clamped(to: r * 1.4 ... bounds.width - r * 1.4),
            y: (position.y + dy * flee).clamped(to: r * 1.4 ... bounds.height - r * 1.4)
        )

        let dash = SKAction.move(to: target, duration: 0.4)
        dash.timingMode = .easeIn
        run(.sequence([
            dash,
            .wait(forDuration: 0.25),
            .run { [weak self] in self?.returnHome() }
        ]), withKey: moveKey)
    }

    private func returnHome() {
        removeAction(forKey: moveKey)
        let back = SKAction.move(to: homePosition, duration: 2.5)
        back.timingMode = .easeInEaseOut
        lean(toward: homePosition)
        run(.sequence([back, .run { [weak self] in self?.goToSleep(animated: true) }]), withKey: moveKey)
    }

    private func goToSleep(animated: Bool) {
        currentState = .sleeping
        let duration: TimeInterval = animated ? 0.5 : 0
        showSleeping(true, duration: duration)
        brightenGlow(to: 0.12, duration: animated ? 0.6 : 0)
        liftBody(by: 0, duration: animated ? 0.6 : 0)
        straighten(duration: animated ? 0.6 : 0)
        startBreathing()
        animateTentacles(fast: false)
        scheduleIdlePeek()
    }

    // MARK: - Motion helpers

    private func startBreathing() {
        guard !AmbientAnimator.reduceMotion else { return }
        breathing.removeAction(forKey: breatheKey)
        let up = SKAction.scale(to: 1.012, duration: 2.5)
        let down = SKAction.scale(to: 1.0, duration: 2.5)
        up.timingMode = .easeInEaseOut
        down.timingMode = .easeInEaseOut
        breathing.run(.repeatForever(.sequence([up, down])), withKey: breatheKey)
    }

    private func animateTentacles(fast: Bool) {
        guard !AmbientAnimator.reduceMotion else { return }
        let amplitude: CGFloat = fast ? 0.3 : 0.14
        for (index, tentacle) in tentacles.enumerated() {
            tentacle.removeAction(forKey: tentacleKey)
            let base = (fast ? 0.46 : 1.1) + Double(index) * 0.08
            let left = SKAction.rotate(toAngle: amplitude, duration: base)
            let right = SKAction.rotate(toAngle: -amplitude, duration: base * 1.12)
            left.timingMode = .easeInEaseOut
            right.timingMode = .easeInEaseOut
            let phase = SKAction.wait(forDuration: Double(index) * 0.09)
            tentacle.run(.sequence([phase, .repeatForever(.sequence([left, right]))]), withKey: tentacleKey)
        }
    }

    private func perkTentacles(fast: Bool) {
        guard !AmbientAnimator.reduceMotion else { return }
        for tentacle in tentacles {
            let perk = SKAction.scaleY(to: 0.84, duration: 0.14)
            let settle = SKAction.scaleY(to: 1.0, duration: 0.3)
            perk.timingMode = .easeOut
            settle.timingMode = .easeInEaseOut
            tentacle.run(.sequence([perk, settle]))
        }
    }

    private func liftBody(by amount: CGFloat, duration: TimeInterval) {
        breathing.removeAction(forKey: liftKey)
        guard duration > 0 else { breathing.position.y = amount; return }
        let move = SKAction.moveTo(y: amount, duration: duration)
        move.timingMode = .easeOut
        breathing.run(move, withKey: liftKey)
    }

    private func lean(toward point: CGPoint) {
        guard !AmbientAnimator.reduceMotion else { return }
        let dx = point.x - position.x
        let angle = (dx / (r * 6)).clamped(to: -1...1) * 0.12
        let rotate = SKAction.rotate(toAngle: angle, duration: 0.24)
        rotate.timingMode = .easeOut
        breathing.run(rotate, withKey: "creature.lean")
    }

    private func straighten(duration: TimeInterval) {
        guard duration > 0 else { breathing.zRotation = 0; return }
        let rotate = SKAction.rotate(toAngle: 0, duration: duration)
        rotate.timingMode = .easeInEaseOut
        breathing.run(rotate, withKey: "creature.lean")
    }

    private func brightenGlow(to alpha: CGFloat, duration: TimeInterval) {
        glow.removeAction(forKey: glowKey)
        guard duration > 0 else { glow.fillColor = bodyColor.withAlpha(alpha); return }
        let from = glow.fillColor.lullAlpha   // capture once — no compounding moving target
        let fade = SKAction.customAction(withDuration: duration) { [weak self] _, elapsed in
            guard let self else { return }
            let t = (elapsed / CGFloat(duration)).clamped(to: 0...1)
            self.glow.fillColor = self.bodyColor.withAlpha(from + (alpha - from) * t)
        }
        fade.timingMode = .easeInEaseOut
        glow.run(fade, withKey: glowKey)
    }

    // MARK: - Idle life
    // A character is never fully static: even asleep, a creature occasionally peeks,
    // glances, and dozes off again so the water feels inhabited between waves.

    private func scheduleIdlePeek() {
        guard !AmbientAnimator.reduceMotion else { return }
        removeAction(forKey: idleKey)
        run(.sequence([
            .wait(forDuration: .random(in: 5...10)),
            .run { [weak self] in self?.playIdlePeek() }
        ]), withKey: idleKey)
    }

    private func playIdlePeek() {
        guard currentState == .sleeping else { scheduleIdlePeek(); return }
        showSleeping(false, duration: 0.26)
        brightenGlow(to: 0.17, duration: 0.3)
        liftBody(by: r * 0.08, duration: 0.5)   // a slow, sleepy rise — Y only, reset cleanly
        run(.sequence([
            .wait(forDuration: 0.9),
            .run { [weak self] in
                guard let self, self.currentState == .sleeping else { return }
                self.showSleeping(true, duration: 0.34)
                self.brightenGlow(to: 0.12, duration: 0.5)
                self.liftBody(by: 0, duration: 0.6)
            },
            .wait(forDuration: 0.4),
            .run { [weak self] in self?.scheduleIdlePeek() }
        ]), withKey: idleKey)
    }

    private func showSleeping(_ sleeping: Bool, duration: TimeInterval) {
        sleepyEyes.forEach { $0.removeAction(forKey: eyeKey) }
        openEyes.forEach { $0.removeAction(forKey: eyeKey) }

        guard duration > 0 else {
            sleepyEyes.forEach { $0.alpha = sleeping ? 1 : 0 }
            openEyes.forEach { $0.alpha = sleeping ? 0 : 1; $0.yScale = sleeping ? 0.01 : 1 }
            mouth?.path = smilePath()
            return
        }

        if sleeping {
            for eye in openEyes {
                let close = SKAction.scaleY(to: 0.01, duration: duration * 0.5)
                close.timingMode = .easeInEaseOut
                eye.run(.sequence([close, .fadeOut(withDuration: 0)]), withKey: eyeKey)
            }
            for eye in sleepyEyes {
                eye.run(.sequence([.wait(forDuration: duration * 0.3), .fadeIn(withDuration: duration * 0.4)]), withKey: eyeKey)
            }
        } else {
            for eye in sleepyEyes {
                eye.run(.fadeOut(withDuration: duration * 0.4), withKey: eyeKey)
            }
            for eye in openEyes {
                eye.yScale = 0.01
                eye.alpha = 1
                let open = SKAction.scaleY(to: 1.0, duration: duration * 0.7)
                open.timingMode = .easeOut
                eye.run(.sequence([.wait(forDuration: duration * 0.2), open]), withKey: eyeKey)
            }
        }
    }
}

// MARK: - Helpers

private extension SKColor {
    var lullAlpha: CGFloat {
        var a: CGFloat = 0
        getRed(nil, green: nil, blue: nil, alpha: &a)
        return a
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
