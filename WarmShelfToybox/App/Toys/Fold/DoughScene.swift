import SpriteKit
import UIKit

// MARK: - DoughScene

/// One large lump of warm clay dough. The whole toy is this single living object:
/// press it and it dents, lift your finger and the dough springs back with a sigh,
/// pinch it and it bulges up between your fingers. It breathes and hums to itself.
final class DoughScene: BaseToyScene {

    override var toyVoice: AudioManager.LullSoundVoice { .hum }  // soft clay breathing
    override var firstSessionHintKey: String? { "hint.dough" }
    override func firstSessionHintPoint() -> CGPoint {
        dough.position
    }

    private var dough = DoughNode()

    /// Per-touch press tracking. Key is the touch's identity.
    private final class Press {
        let touch: UITouch
        let startTime: TimeInterval
        var localPoint: CGPoint
        init(touch: UITouch, startTime: TimeInterval, localPoint: CGPoint) {
            self.touch = touch
            self.startTime = startTime
            self.localPoint = localPoint
        }
    }

    private var presses: [ObjectIdentifier: Press] = [:]
    private var lastUpdateTime: TimeInterval = 0
    private var idleSince: TimeInterval = 0
    private var isBreathing = false

    // Pinch tracking
    private var pinchStartDistance: CGFloat?
    private var pinchActive = false

    // Tickle → giggle → a clay friend pops out
    private var pokeCount = 0
    private var babies: [ClayBabyNode] = []
    private let maxBabies = 5

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        buildDough()
        run(.sequence([.wait(forDuration: 0.9), .run { [weak self] in self?.dough.playHello() }]))
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 40, size.height > 40 else { return }
        buildDough()
    }

    private func buildDough() {
        dough.removeFromParent()
        dough = DoughNode()
        dough.configure(bodyRadius: min(size.width * 0.3, size.height * 0.26))
        dough.position = CGPoint(x: size.width / 2, y: size.height * 0.5)
        dough.zPosition = 10
        addChild(dough)
        isBreathing = true
        dough.startBreathing()
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let scenePoint = touch.location(in: self)
            if presses.isEmpty, consumeShelfReturnTouch(at: scenePoint) { return }

            // A clay friend that's already out gets first dibs on the touch: boop it and it hops.
            if let baby = babies.last(where: { $0.contains(scenePoint: scenePoint, in: self) }) {
                baby.boop()
                HapticsManager.shared.impact(style: .soft, intensity: 0.3)
                AudioManager.shared.playSoftTap()
                continue
            }

            let local = dough.convert(scenePoint, from: self)
            guard dough.contains(localPoint: local) else { continue }

            let press = Press(touch: touch, startTime: touch.timestamp, localPoint: local)
            presses[ObjectIdentifier(touch)] = press

            isBreathing = false
            dough.stopBreathing()
            dough.beginDent(key: ObjectIdentifier(touch).hashValue, at: local)
            dough.poke()
            dough.squishJiggle()
            HapticsManager.shared.impact(style: .soft, intensity: 0.35)
            AudioManager.shared.playSoftTap()
            registerPoke(at: local, scenePoint: scenePoint)

            if presses.count == 2 { beginPinch() }
        }
    }

    /// Poking tickles the dough. Every third poke it can't help giggling — and a little clay
    /// friend squeezes out. Counting pokes (rather than timing a streak) keeps the surprise
    /// reliable for a toddler who pokes at their own pace.
    private func registerPoke(at local: CGPoint, scenePoint: CGPoint) {
        pokeCount += 1
        if pokeCount % 3 == 0 {
            dough.giggle()
            HapticsManager.shared.celebration()
            AudioManager.shared.playMixCelebrate()
            spawnClayBaby(near: scenePoint)
        }
    }

    private func spawnClayBaby(near scenePoint: CGPoint) {
        if babies.count >= maxBabies {
            babies.removeFirst().meltAway()
        }
        // Size the friend to the dough so it reads as a real little character, and perch it
        // on the upper rim — it always climbs OUT over the top of the lump (clearly its own
        // creature), never buried in the face wherever the child happened to poke.
        let diameter = (dough.bodyRadius * 0.46).clamped(to: 52...96)
        let perch = CGPoint(
            x: dough.position.x + CGFloat.random(in: -0.45...0.45) * dough.bodyRadius,
            y: dough.position.y + dough.bodyRadius * 0.52   // upper rim of the lump
        )

        let baby = ClayBabyNode(diameter: diameter)
        baby.position = perch
        baby.zPosition = 12
        addChild(baby)
        babies.append(baby)
        baby.popOut { [weak self, weak baby] in
            guard let self, let baby else { return }
            self.babies.removeAll { $0 === baby }
        }
        AudioManager.shared.playBloomCritter()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let press = presses[ObjectIdentifier(touch)] else { continue }
            press.localPoint = dough.convert(touch.location(in: self), from: self)
        }
        updatePinch()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { endPress(touch) }
        if presses.count < 2 { endPinch() }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { endPress(touch) }
        if presses.count < 2 { endPinch() }
    }

    private func endPress(_ touch: UITouch) {
        guard presses.removeValue(forKey: ObjectIdentifier(touch)) != nil else { return }
        dough.releaseDent(key: ObjectIdentifier(touch).hashValue)
        if presses.isEmpty {
            dough.releaseSigh()
            idleSince = lastUpdateTime
        }
    }

    // MARK: - Pinch

    private func beginPinch() {
        let points = presses.values.map { $0.localPoint }
        guard points.count >= 2 else { return }
        pinchStartDistance = hypot(points[0].x - points[1].x, points[0].y - points[1].y)
        pinchActive = false
    }

    private func updatePinch() {
        guard presses.count == 2, let start = pinchStartDistance, start > 1 else { return }
        let points = presses.values.map { $0.localPoint }
        let current = hypot(points[0].x - points[1].x, points[0].y - points[1].y)
        let closeness = ((start - current) / start).clamped(to: 0...1)
        dough.setBulge(closeness * 0.18)
        if closeness > 0.18 && !pinchActive {
            pinchActive = true
            AudioManager.shared.playSoftTap()
        }
    }

    private func endPinch() {
        guard pinchStartDistance != nil else { return }
        pinchStartDistance = nil
        if pinchActive {
            pinchActive = false
            dough.releaseBulge()
            HapticsManager.shared.impact(style: .soft, intensity: 0.55)
        } else {
            dough.releaseBulge()
        }
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        let delta = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        // Feed live press depths each frame. The dent is visible the instant a finger
        // lands (toddlers need cause-and-effect now, not after a hold); the *pressure*
        // that scrunches the face is tracked separately so a light poke stays curious.
        var maxPressure: CGFloat = 0
        for press in presses.values {
            let reading = dentReading(for: press.touch, startTime: press.startTime, now: currentTime)
            dough.setDentDepth(key: ObjectIdentifier(press.touch).hashValue, depth: reading.visualDepth, at: press.localPoint)
            maxPressure = max(maxPressure, reading.pressure)
        }

        if !presses.isEmpty {
            dough.reactToPressure(deformation: maxPressure)
        }

        dough.tick(delta: delta)

        // Resume breathing after 2 s of calm.
        if presses.isEmpty && !isBreathing && currentTime - idleSince > 2.0 {
            isBreathing = true
            dough.startBreathing()
        }
    }

    private struct DentReading {
        let visualDepth: CGFloat   // what the dough shows (has an instant floor)
        let pressure: CGFloat      // 0...1 — how hard, drives the face
    }

    /// The instant a finger contacts the dough it sinks to a visible floor depth, then
    /// deepens with real pressure (3D Touch force) or, on the vast majority of devices
    /// without it, with how hard/long the child leans in.
    private func dentReading(for touch: UITouch, startTime: TimeInterval, now: TimeInterval) -> DentReading {
        let instantFloor: CGFloat = 18
        let pressureDepth: CGFloat
        if touch.maximumPossibleForce > 0 {
            let normalized = touch.force / touch.maximumPossibleForce          // 0...1
            pressureDepth = min(normalized * DoughNode.maxDentDepth, DoughNode.maxDentDepth)
        } else {
            // No force hardware: leaning in (holding) deepens the dent over ~0.6 s.
            let held = CGFloat(now - startTime)
            pressureDepth = min(held / 0.6, 1.0) * DoughNode.maxDentDepth
        }
        return DentReading(
            visualDepth: max(instantFloor, pressureDepth),
            pressure: pressureDepth / DoughNode.maxDentDepth
        )
    }
}

// MARK: - DoughNode

/// The dough lump. A radial blob whose boundary is pushed inward where fingers press,
/// rebuilt each frame while any dent is active. Released dents spring back with a fast
/// initial recovery then a slow exhale.
final class DoughNode: SKNode {

    static let maxDentDepth: CGFloat = 40

    private struct Dent {
        var localPoint: CGPoint
        var depth: CGFloat          // current rendered depth (points)
        var releasing: Bool = false
        var releaseElapsed: TimeInterval = 0
        var releaseFrom: CGFloat = 0
        let shadow: SKShapeNode
    }

    private let breathing = SKNode()
    private var body: SKShapeNode!
    private(set) var bodyRadius: CGFloat = 120
    private let verticalSquash: CGFloat = 0.86
    private let dentFalloff: CGFloat = 70

    private var lumpTable: [CGFloat] = []
    private let sampleCount = 56

    private var dents: [Int: Dent] = [:]
    private var dirty = true

    // Face
    private var sleepyEyes: [SKShapeNode] = []
    private var openEyes: [SKNode] = []
    private var mouth: SKShapeNode?
    private var faceState: FaceState = .resting
    private enum FaceState { case resting, curious, stressed }

    private let breatheKey = "dough.breathe"
    private let bulgeKey = "dough.bulge"
    private let eyeKey = "dough.eyes"

    override init() {
        super.init()
        addChild(breathing)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        addChild(breathing)
    }

    // MARK: - Build

    func configure(bodyRadius radius: CGFloat) {
        bodyRadius = max(radius, 60)
        breathing.removeAllChildren()
        dents.removeAll()
        sleepyEyes.removeAll()
        openEyes.removeAll()
        mouth = nil

        // Stable lumps so the silhouette doesn't shimmer between frames.
        lumpTable = (0..<sampleCount).map { i in
            let a = CGFloat(i) / CGFloat(sampleCount) * .pi * 2
            return 1 + 0.05 * sin(a * 3 + 0.7) + 0.035 * cos(a * 2 - 0.4) + 0.02 * sin(a * 5)
        }

        buildShadow()

        body = SKShapeNode(path: bodyPath())
        body.fillColor = WarmShelfPalette.terracotta
        body.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.06)
        body.lineWidth = 1.5
        body.zPosition = 0
        breathing.addChild(body)

        let warmth = SKShapeNode(ellipseOf: CGSize(width: bodyRadius * 1.4, height: bodyRadius * 1.0))
        warmth.fillColor = WarmShelfPalette.rhubarb.withAlpha(0.08)
        warmth.strokeColor = .clear
        warmth.position = CGPoint(x: 0, y: -bodyRadius * 0.18)
        warmth.zPosition = 0.1
        body.addChild(warmth)

        let highlight = SKShapeNode(ellipseOf: CGSize(width: bodyRadius * 0.9, height: bodyRadius * 0.62))
        highlight.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.7)
        highlight.strokeColor = .clear
        highlight.position = CGPoint(x: -bodyRadius * 0.42, y: bodyRadius * 0.4)
        highlight.zRotation = -0.34
        highlight.zPosition = 0.3
        body.addChild(highlight)

        buildDimples()
        buildFace()
    }

    private func buildShadow() {
        for (index, spec) in [
            (CGSize(width: bodyRadius * 2.3, height: bodyRadius * 0.52), CGFloat(0.07), -bodyRadius * 0.96),
            (CGSize(width: bodyRadius * 1.8, height: bodyRadius * 0.34), CGFloat(0.1), -bodyRadius * 0.93),
            (CGSize(width: bodyRadius * 1.2, height: bodyRadius * 0.2), CGFloat(0.08), -bodyRadius * 0.9)
        ].enumerated() {
            let shadow = SKShapeNode(ellipseOf: spec.0)
            shadow.fillColor = WarmShelfPalette.contactShadow.withAlpha(spec.1)
            shadow.strokeColor = .clear
            shadow.position = CGPoint(x: 0, y: spec.2)
            shadow.zPosition = CGFloat(-3 + index)
            breathing.addChild(shadow)
        }
    }

    private func buildDimples() {
        let points: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: -0.5, y: 0.3), 0.05, 0.05),
            (CGPoint(x: 0.46, y: 0.36), 0.04, 0.045),
            (CGPoint(x: -0.62, y: -0.26), 0.045, 0.04),
            (CGPoint(x: 0.6, y: -0.32), 0.05, 0.05),
            (CGPoint(x: -0.1, y: 0.58), 0.035, 0.035),
            (CGPoint(x: 0.28, y: -0.58), 0.04, 0.045),
            (CGPoint(x: 0.72, y: 0.04), 0.03, 0.03)
        ]
        for (pt, rad, alpha) in points {
            let dimple = SKShapeNode(circleOfRadius: rad * bodyRadius)
            dimple.fillColor = WarmShelfPalette.cocoa.withAlpha(alpha)
            dimple.strokeColor = .clear
            dimple.position = CGPoint(x: pt.x * bodyRadius, y: pt.y * bodyRadius * verticalSquash)
            dimple.zPosition = 0.5
            body.addChild(dimple)
        }
    }

    private func buildFace() {
        let eyeX = bodyRadius * 0.26
        let eyeY = bodyRadius * 0.08
        let ew = bodyRadius * 0.12

        for sign in [CGFloat(-1), CGFloat(1)] {
            let sleepy = SKShapeNode(path: sleepyEyeArcPath(flatten: 1))
            sleepy.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.78)
            sleepy.lineWidth = bodyRadius * 0.028
            sleepy.lineCap = .round
            sleepy.fillColor = .clear
            sleepy.position = CGPoint(x: sign * eyeX, y: eyeY)
            sleepy.zPosition = 3
            body.addChild(sleepy)
            sleepyEyes.append(sleepy)

            let eye = SKNode()
            eye.position = CGPoint(x: sign * eyeX, y: eyeY + bodyRadius * 0.01)
            eye.zPosition = 4

            let white = SKShapeNode(ellipseOf: CGSize(width: ew * 1.3, height: ew * 1.5))
            white.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.96)
            white.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.1)
            white.lineWidth = 0.8
            eye.addChild(white)

            let pupil = SKShapeNode(circleOfRadius: ew * 0.46)
            pupil.fillColor = WarmShelfPalette.cocoa.withAlpha(0.88)
            pupil.strokeColor = .clear
            pupil.position = CGPoint(x: sign * ew * 0.08, y: -ew * 0.05)
            eye.addChild(pupil)

            let glint = SKShapeNode(circleOfRadius: ew * 0.16)
            glint.fillColor = .white.withAlpha(0.9)
            glint.strokeColor = .clear
            glint.position = CGPoint(x: -ew * 0.22, y: ew * 0.26)
            eye.addChild(glint)

            eye.alpha = 0
            eye.yScale = 0.01
            body.addChild(eye)
            openEyes.append(eye)
        }

        let m = SKShapeNode(path: contentMouthPath())
        m.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.55)
        m.lineWidth = bodyRadius * 0.026
        m.lineCap = .round
        m.fillColor = .clear
        m.position = CGPoint(x: 0, y: -bodyRadius * 0.2)
        m.zPosition = 3
        body.addChild(m)
        mouth = m
    }

    // MARK: - Hit test

    func contains(localPoint: CGPoint) -> Bool {
        // Generous: anywhere inside the rough silhouette.
        let nx = localPoint.x / bodyRadius
        let ny = localPoint.y / (bodyRadius * verticalSquash)
        return nx * nx + ny * ny < 1.25
    }

    // MARK: - Dents

    func beginDent(key: Int, at point: CGPoint) {
        // Cancel any opening wiggle so the dough is upright — dents are computed in
        // un-rotated body space, so a leftover tilt would offset the indentation.
        removeAction(forKey: "dough.helloFace")
        body.removeAction(forKey: "dough.hello")
        body.zRotation = 0

        let shadow = SKShapeNode(circleOfRadius: dentFalloff * 0.6)
        shadow.fillColor = WarmShelfPalette.cocoa.withAlpha(0)
        shadow.strokeColor = .clear
        shadow.position = point
        shadow.zPosition = 0.6
        body.addChild(shadow)
        dents[key] = Dent(localPoint: point, depth: 16, shadow: shadow)   // visible on contact frame
        dirty = true
    }

    func setDentDepth(key: Int, depth: CGFloat, at point: CGPoint) {
        guard var dent = dents[key] else { return }
        dent.localPoint = point
        dent.depth = depth
        dent.releasing = false
        dents[key] = dent
        dirty = true
    }

    func releaseDent(key: Int) {
        guard var dent = dents[key] else { return }
        dent.releasing = true
        dent.releaseElapsed = 0
        dent.releaseFrom = dent.depth
        dents[key] = dent
    }

    /// Advance spring-back timers and rebuild the silhouette if anything moved.
    func tick(delta: TimeInterval) {
        guard !dents.isEmpty else {
            if dirty { rebuildBody(); dirty = false }
            return
        }

        let total: TimeInterval = 1.8
        let phase1: TimeInterval = 0.3   // fast spring covers 60% of the return
        var finished: [Int] = []

        for (key, var dent) in dents {
            if dent.releasing {
                dent.releaseElapsed += delta
                let returned: CGFloat
                if dent.releaseElapsed < phase1 {
                    let u = CGFloat(dent.releaseElapsed / phase1)
                    returned = 0.6 * (1 - (1 - u) * (1 - u))                  // easeOut
                } else {
                    let u = CGFloat((dent.releaseElapsed - phase1) / (total - phase1)).clamped(to: 0...1)
                    returned = 0.6 + 0.4 * (u * u * (3 - 2 * u))              // smoothstep exhale
                }
                dent.depth = dent.releaseFrom * (1 - returned)
                dents[key] = dent
                if dent.releaseElapsed >= total {
                    finished.append(key)
                }
                dirty = true
            }
            // Update the indent shadow alpha with depth.
            let alpha = (dent.depth / Self.maxDentDepth).clamped(to: 0...1) * 0.16
            dent.shadow.position = dent.localPoint
            dent.shadow.fillColor = WarmShelfPalette.cocoa.withAlpha(alpha)
        }

        for key in finished {
            dents[key]?.shadow.removeFromParent()
            dents.removeValue(forKey: key)
            dirty = true
        }

        if dirty {
            rebuildBody()
            dirty = false
        }
    }

    private func rebuildBody() {
        body?.path = bodyPath()
    }

    private func bodyPath() -> CGPath {
        var pts: [CGPoint] = []
        pts.reserveCapacity(sampleCount)
        let activeDents = dents.values.filter { $0.depth > 0.4 }

        for i in 0..<sampleCount {
            let a = CGFloat(i) / CGFloat(sampleCount) * .pi * 2
            let radius = bodyRadius * lumpTable[i]
            var point = CGPoint(x: cos(a) * radius, y: sin(a) * radius * verticalSquash)

            for dent in activeDents {
                let d = hypot(point.x - dent.localPoint.x, point.y - dent.localPoint.y)
                guard d < dentFalloff else { continue }
                let g = (1 - d / dentFalloff)
                let inward = dent.depth * g * g
                let len = max(hypot(point.x, point.y), 0.001)
                point.x -= point.x / len * inward
                point.y -= point.y / len * inward
            }
            pts.append(point)
        }

        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        let path = CGMutablePath()
        path.move(to: mid(pts[sampleCount - 1], pts[0]))
        for i in 0..<sampleCount {
            path.addQuadCurve(to: mid(pts[i], pts[(i + 1) % sampleCount]), control: pts[i])
        }
        path.closeSubpath()
        return path
    }

    // MARK: - Bulge (pinch)

    func setBulge(_ amount: CGFloat) {
        breathing.removeAction(forKey: bulgeKey)
        breathing.yScale = 1.0 + amount
        breathing.xScale = 1.0 - amount * 0.32
    }

    func releaseBulge() {
        breathing.removeAction(forKey: bulgeKey)
        let overshoot = SKAction.scaleX(to: 1.02, y: 0.98, duration: 0.14)
        let settle = SKAction.scale(to: 1.0, duration: 0.4)
        overshoot.timingMode = .easeOut
        settle.timingMode = .easeInEaseOut
        breathing.run(.sequence([overshoot, settle]), withKey: bulgeKey)
    }

    // MARK: - Breathing

    func startBreathing() {
        guard !AmbientAnimator.reduceMotion else { return }
        showSleeping(true, duration: 0.4)
        breathing.removeAction(forKey: breatheKey)
        let up = SKAction.scale(to: 1.012, duration: 3.0)
        let down = SKAction.scale(to: 1.0, duration: 3.0)
        up.timingMode = .easeInEaseOut
        down.timingMode = .easeInEaseOut
        breathing.run(.repeatForever(.sequence([up, down])), withKey: breatheKey)
    }

    func stopBreathing() {
        breathing.removeAction(forKey: breatheKey)
    }

    /// Opening invitation: a soft wiggle and a peek — "I'm here, squish me."
    func playHello() {
        guard !AmbientAnimator.reduceMotion, body != nil else { return }
        let tilt = SKAction.rotate(toAngle: 0.045, duration: 0.42)
        let backTilt = SKAction.rotate(toAngle: -0.035, duration: 0.5)
        let center = SKAction.rotate(toAngle: 0, duration: 0.42)
        tilt.timingMode = .easeInEaseOut
        backTilt.timingMode = .easeInEaseOut
        center.timingMode = .easeInEaseOut
        body.run(.sequence([tilt, backTilt, center]), withKey: "dough.hello")

        run(.sequence([
            .run { [weak self] in self?.showSleeping(false, duration: 0.3) },
            .wait(forDuration: 1.1),
            .run { [weak self] in self?.showSleeping(true, duration: 0.42) }
        ]), withKey: "dough.helloFace")
    }

    /// A springy bounce on every poke so the clay always feels soft and alive.
    func squishJiggle() {
        guard !AmbientAnimator.reduceMotion, body != nil else { return }
        body.removeAction(forKey: "dough.jiggle")
        let squash = SKAction.scaleX(to: 1.05, y: 0.95, duration: 0.08)
        let rebound = SKAction.scaleX(to: 0.975, y: 1.035, duration: 0.1)
        let settle = SKAction.scale(to: 1.0, duration: 0.16)
        squash.timingMode = .easeOut
        rebound.timingMode = .easeOut
        settle.timingMode = .easeInEaseOut
        body.run(.sequence([squash, rebound, settle]), withKey: "dough.jiggle")
    }

    /// Tickled! Eyes pop wide, a big delighted bounce, and a burst of warm sparkles.
    func giggle() {
        guard body != nil else { return }
        removeAction(forKey: "dough.ahh")
        removeAction(forKey: "dough.giggleReset")
        faceState = .resting
        resetSleepyArcs()

        guard !AmbientAnimator.reduceMotion else {
            showSleeping(false, duration: 0)
            mouth?.path = delightedMouthPath()
            return
        }

        showSleeping(false, duration: 0.1)
        mouth?.path = delightedMouthPath()
        mouth?.run(.sequence([.scale(to: 1.18, duration: 0.12), .scale(to: 1.0, duration: 0.18)]))

        // Joyful triple-bob + a little squash on landing.
        breathing.removeAction(forKey: bulgeKey)
        let up = SKAction.moveBy(x: 0, y: bodyRadius * 0.12, duration: 0.12)
        let down = SKAction.moveBy(x: 0, y: -bodyRadius * 0.12, duration: 0.14)
        up.timingMode = .easeOut
        down.timingMode = .easeIn
        breathing.run(.repeat(.sequence([up, down]), count: 2), withKey: bulgeKey)

        sparkleBurst()

        run(.sequence([
            .wait(forDuration: 1.2),
            .run { [weak self] in
                guard let self else { return }
                self.showSleeping(true, duration: 0.36)
                self.mouth?.path = self.contentMouthPath()
            }
        ]), withKey: "dough.giggleReset")
    }

    private func sparkleBurst() {
        guard !AmbientAnimator.reduceMotion else { return }
        let colors = [WarmShelfPalette.butter, WarmShelfPalette.petal, WarmShelfPalette.paperHighlight]
        for index in 0..<9 {
            let spark = SKShapeNode(circleOfRadius: bodyRadius * CGFloat.random(in: 0.025...0.045))
            spark.fillColor = colors[index % colors.count].withAlpha(0.95)
            spark.strokeColor = .clear
            spark.position = CGPoint(x: CGFloat.random(in: -bodyRadius * 0.3...bodyRadius * 0.3), y: bodyRadius * 0.4)
            spark.zPosition = 6
            breathing.addChild(spark)

            let angle = CGFloat.random(in: (.pi * 0.15)...(.pi * 0.85))   // fan upward
            let dist = bodyRadius * CGFloat.random(in: 0.55...1.1)
            let fly = SKAction.moveBy(x: cos(angle) * dist, y: sin(angle) * dist + bodyRadius * 0.2, duration: 0.7)
            fly.timingMode = .easeOut
            spark.run(.sequence([
                .group([fly, .fadeOut(withDuration: 0.7), .scale(to: 1.7, duration: 0.7)]),
                .removeFromParent()
            ]))
        }
    }

    // MARK: - Face reactions

    func poke() {
        guard faceState == .resting else { return }
        faceState = .curious
        // One eye opens slightly — a curious look.
        guard let eye = openEyes.first, !AmbientAnimator.reduceMotion else { return }
        eye.alpha = 1
        let open = SKAction.scaleY(to: 0.7, duration: 0.16)
        open.timingMode = .easeOut
        eye.run(open, withKey: eyeKey)
        sleepyEyes.first?.run(.fadeAlpha(to: 0.3, duration: 0.16), withKey: eyeKey)
    }

    func reactToPressure(deformation: CGFloat) {
        if deformation > 0.4 {
            guard faceState != .stressed else { return }
            faceState = .stressed
            showSleeping(true, duration: 0.12)
            for eye in sleepyEyes {
                eye.removeAction(forKey: eyeKey)
                eye.run(.customAction(withDuration: 0.14) { [weak self] node, t in
                    guard let self, let shape = node as? SKShapeNode else { return }
                    shape.path = self.sleepyEyeArcPath(flatten: 1 - 0.6 * (t / 0.14))
                }, withKey: eyeKey)
            }
            mouth?.path = stressedMouthPath()
        }
    }

    func releaseSigh() {
        // A giggle owns the face while it plays — don't stomp it on a tap-release.
        if action(forKey: "dough.giggleReset") != nil { return }
        faceState = .resting
        guard !AmbientAnimator.reduceMotion else {
            showSleeping(true, duration: 0)
            mouth?.path = contentMouthPath()
            resetSleepyArcs()
            return
        }
        resetSleepyArcs()
        // Eyes open briefly...
        showSleeping(false, duration: 0.16)
        mouth?.path = contentMouthPath()
        // ...a big sigh (a settle scale)...
        let sink = SKAction.scaleX(to: 1.03, y: 0.96, duration: 0.22)
        let lift = SKAction.scale(to: 1.0, duration: 0.5)
        sink.timingMode = .easeOut
        lift.timingMode = .easeInEaseOut
        breathing.run(.sequence([sink, lift]), withKey: bulgeKey)
        // ...then blink closed.
        run(.sequence([
            .wait(forDuration: 0.6),
            .run { [weak self] in self?.showSleeping(true, duration: 0.34) }
        ]), withKey: "dough.ahh")
    }

    private func resetSleepyArcs() {
        for eye in sleepyEyes {
            eye.removeAction(forKey: eyeKey)
            eye.path = sleepyEyeArcPath(flatten: 1)
        }
    }

    private func showSleeping(_ sleeping: Bool, duration: TimeInterval) {
        sleepyEyes.forEach { $0.removeAction(forKey: eyeKey) }
        openEyes.forEach { $0.removeAction(forKey: eyeKey) }
        let duration = AmbientAnimator.reduceMotion ? 0 : duration

        guard duration > 0 else {
            sleepyEyes.forEach { $0.alpha = sleeping ? 1 : 0 }
            openEyes.forEach { $0.alpha = sleeping ? 0 : 1; $0.yScale = sleeping ? 0.01 : 1 }
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

    // MARK: - Paths

    private func sleepyEyeArcPath(flatten: CGFloat) -> CGPath {
        let p = CGMutablePath()
        let ew = bodyRadius * 0.1
        p.move(to: CGPoint(x: -ew, y: 0))
        p.addQuadCurve(to: CGPoint(x: ew, y: 0), control: CGPoint(x: 0, y: bodyRadius * 0.075 * flatten))
        return p
    }

    private func contentMouthPath() -> CGPath {
        let p = CGMutablePath()
        let w = bodyRadius * 0.12
        p.move(to: CGPoint(x: -w, y: 0))
        p.addQuadCurve(to: CGPoint(x: w, y: 0), control: CGPoint(x: 0, y: -bodyRadius * 0.06))
        return p
    }

    private func stressedMouthPath() -> CGPath {
        let p = CGMutablePath()
        let w = bodyRadius * 0.08
        p.addEllipse(in: CGRect(x: -w * 0.6, y: -bodyRadius * 0.05, width: w * 1.2, height: bodyRadius * 0.06))
        return p
    }

    private func delightedMouthPath() -> CGPath {
        let p = CGMutablePath()
        let w = bodyRadius * 0.14
        p.addEllipse(in: CGRect(x: -w * 0.6, y: -bodyRadius * 0.11, width: w * 1.2, height: bodyRadius * 0.13))
        return p
    }
}

// MARK: - ClayBabyNode

/// A tiny clay friend that squeezes out of the dough when it's tickled: googly eyes,
/// a wobble, a blink, and — if no one boops it — it melts happily back into the lump.
final class ClayBabyNode: SKNode {

    private let r: CGFloat
    private let bodyColor: SKColor
    private let art = SKNode()
    private var eyes: [SKNode] = []
    private var onMelt: (() -> Void)?

    init(diameter: CGFloat = 44) {
        r = diameter / 2
        // Colors that pop against the terracotta dough so each friend reads as its own creature.
        let palette = [WarmShelfPalette.butter, WarmShelfPalette.sage, WarmShelfPalette.petal, WarmShelfPalette.lavender, WarmShelfPalette.waterBlue]
        bodyColor = palette.randomElement() ?? WarmShelfPalette.butter
        super.init()
        addChild(art)
        build()
        setScale(0.01)
    }

    required init?(coder aDecoder: NSCoder) {
        r = 22
        bodyColor = WarmShelfPalette.terracotta
        super.init()
    }

    private func build() {
        // Little contact shadow.
        let shadow = SKShapeNode(ellipseOf: CGSize(width: r * 1.8, height: r * 0.5))
        shadow.fillColor = WarmShelfPalette.contactShadow.withAlpha(0.1)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -r * 0.95)
        shadow.zPosition = -1
        art.addChild(shadow)

        // Lumpy little body.
        let n = 14
        var pts: [CGPoint] = []
        for i in 0..<n {
            let a = CGFloat(i) / CGFloat(n) * .pi * 2
            let lump = 1 + 0.08 * sin(a * 3 + 0.4)
            pts.append(CGPoint(x: cos(a) * r * lump, y: sin(a) * r * 0.92 * lump))
        }
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        let path = CGMutablePath()
        path.move(to: mid(pts[n - 1], pts[0]))
        for i in 0..<n { path.addQuadCurve(to: mid(pts[i], pts[(i + 1) % n]), control: pts[i]) }
        path.closeSubpath()

        let body = SKShapeNode(path: path)
        body.fillColor = bodyColor
        body.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.07)
        body.lineWidth = 1
        art.addChild(body)

        let highlight = SKShapeNode(ellipseOf: CGSize(width: r * 0.5, height: r * 0.32))
        highlight.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.5)
        highlight.strokeColor = .clear
        highlight.position = CGPoint(x: -r * 0.32, y: r * 0.34)
        highlight.zRotation = -0.3
        body.addChild(highlight)

        // Big googly eyes — the whole charm of the little guy.
        for sign in [CGFloat(-1), CGFloat(1)] {
            let eye = SKNode()
            eye.position = CGPoint(x: sign * r * 0.34, y: r * 0.12)
            let white = SKShapeNode(circleOfRadius: r * 0.3)
            white.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.98)
            white.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.12)
            white.lineWidth = 0.8
            eye.addChild(white)
            let pupil = SKShapeNode(circleOfRadius: r * 0.15)
            pupil.fillColor = WarmShelfPalette.cocoa.withAlpha(0.9)
            pupil.strokeColor = .clear
            pupil.position = CGPoint(x: sign * r * 0.03, y: -r * 0.02)
            eye.addChild(pupil)
            let glint = SKShapeNode(circleOfRadius: r * 0.05)
            glint.fillColor = .white
            glint.strokeColor = .clear
            glint.position = CGPoint(x: -r * 0.06, y: r * 0.07)
            eye.addChild(glint)
            body.addChild(eye)
            eyes.append(eye)
        }

        let mouthPath = CGMutablePath()
        mouthPath.move(to: CGPoint(x: -r * 0.16, y: -r * 0.22))
        mouthPath.addQuadCurve(to: CGPoint(x: r * 0.16, y: -r * 0.22), control: CGPoint(x: 0, y: -r * 0.38))
        let mouth = SKShapeNode(path: mouthPath)
        mouth.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.55)
        mouth.lineWidth = max(1, r * 0.06)
        mouth.lineCap = .round
        mouth.fillColor = .clear
        body.addChild(mouth)
    }

    func contains(scenePoint: CGPoint, in scene: SKScene) -> Bool {
        hypot(scenePoint.x - position.x, scenePoint.y - position.y) < r * 1.7
    }

    func popOut(onMelt: @escaping () -> Void) {
        self.onMelt = onMelt
        removeAllActions()
        let grow = SKAction.scale(to: 1.18, duration: 0.22)
        let settle = SKAction.scale(to: 1.0, duration: 0.16)
        grow.timingMode = .easeOut
        settle.timingMode = .easeInEaseOut
        let hop = SKAction.sequence([
            .moveBy(x: 0, y: r * 0.5, duration: 0.16),
            .moveBy(x: 0, y: -r * 0.5, duration: 0.2)
        ])
        run(.group([.sequence([grow, settle]), hop]))
        startIdleLife()
        scheduleMelt(after: 4.0)
    }

    /// Booped! A happy hop + squish.
    func boop() {
        removeAction(forKey: "baby.hop")
        let up = SKAction.moveBy(x: 0, y: r * 0.7, duration: 0.14)
        let down = SKAction.moveBy(x: 0, y: -r * 0.7, duration: 0.2)
        up.timingMode = .easeOut
        down.timingMode = .easeIn
        let squash = SKAction.sequence([
            .scaleX(to: 1.18, y: 0.85, duration: 0.1),
            .scaleX(to: 0.94, y: 1.1, duration: 0.12),
            .scale(to: 1.0, duration: 0.16)
        ])
        run(.group([.sequence([up, down]), squash]), withKey: "baby.hop")
        blink()
        scheduleMelt(after: 4.0)   // booping keeps the friend around longer
    }

    func meltAway() {
        removeAction(forKey: "baby.life")
        removeAction(forKey: "baby.blink")
        let sink = SKAction.group([
            .scale(to: 0.01, duration: 0.4),
            .moveBy(x: 0, y: -r * 0.6, duration: 0.4)
        ])
        sink.timingMode = .easeIn
        run(.sequence([sink, .run { [weak self] in self?.onMelt?() }, .removeFromParent()]))
    }

    private func scheduleMelt(after delay: TimeInterval) {
        removeAction(forKey: "baby.life")
        run(.sequence([.wait(forDuration: delay), .run { [weak self] in self?.meltAway() }]), withKey: "baby.life")
    }

    private func startIdleLife() {
        guard !AmbientAnimator.reduceMotion else { return }
        let lean = SKAction.rotate(toAngle: 0.1, duration: 0.7)
        let other = SKAction.rotate(toAngle: -0.1, duration: 0.8)
        let center = SKAction.rotate(toAngle: 0, duration: 0.6)
        lean.timingMode = .easeInEaseOut
        other.timingMode = .easeInEaseOut
        center.timingMode = .easeInEaseOut
        art.run(.repeatForever(.sequence([lean, other, center, .wait(forDuration: 0.6)])), withKey: "baby.wiggle")
        run(.repeatForever(.sequence([.wait(forDuration: .random(in: 1.6...3.0)), .run { [weak self] in self?.blink() }])), withKey: "baby.blink")
    }

    private func blink() {
        guard !AmbientAnimator.reduceMotion else { return }
        for eye in eyes {
            let close = SKAction.scaleY(to: 0.1, duration: 0.06)
            let open = SKAction.scaleY(to: 1.0, duration: 0.09)
            eye.run(.sequence([close, open]))
        }
    }
}

// MARK: - Helpers

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
