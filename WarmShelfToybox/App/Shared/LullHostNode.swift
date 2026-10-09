import SpriteKit

// Wren — the capstone clay host
/// The capstone clay friend from the app icon: quiet at the edges, deeply alive on touch.
///
/// Host law: rest, notice, respond, settle. He should never interrupt the child, but when
/// a child reaches for him, the balancing stone makes the Stack mechanic feel alive.
final class LullHostNode: SKNode {

    enum HostState { case resting, noticing, responding }
    private(set) var state: HostState = .resting

    /// A clean, gameplay-facing expression vocabulary, mapped onto Wren's clay face.
    enum Expression { case neutral, smile, laugh, sleepy, surprised }

    private let r: CGFloat
    private let breathing = SKNode()

    private var sleepyEyes: [SKShapeNode] = []
    private var openEyes: [SKNode] = []
    private var pupils: [SKShapeNode] = []
    private var pupilHomes: [CGPoint] = []
    private var cheeks: [SKShapeNode] = []
    private var cheekHomes: [CGPoint] = []
    private var shadows: [SKShapeNode] = []
    private var shadowHomes: [CGPoint] = []
    private var shadowAlphas: [CGFloat] = []
    private var isLifted = false
    private var mouth: SKShapeNode?
    private var capstone: SKNode?
    private var capstoneGlint: SKShapeNode?
    private let capstoneHomeAngle: CGFloat = -0.12

    private let breatheKey = "host.breathe"
    private let sighKey = "host.sigh"
    private let capstoneKey = "host.capstone"
    private let capstoneLagKey = "host.capstoneLag"
    private let scaleKey = "host.scale"
    private let leanKey = "host.lean"
    private let bobKey = "host.bob"
    private let eyeKey = "host.eyes"
    private let pupilKey = "host.pupils"
    private let eyeWanderKey = "host.eyeWander"
    private let capstoneGlintKey = "host.capstoneGlint"
    private let landingKey = "host.landingSquash"

    init(scale: CGFloat = 1.0) {
        r = 58 * scale
        super.init()
        addChild(breathing)
        build()
        rest()
    }

    required init?(coder aDecoder: NSCoder) {
        r = 58
        super.init(coder: aDecoder)
    }

    // MARK: - Build

    private func build() {
        // Layered contact shadow: soft outer pool, darker inner weight, tiny foot contact.
        for (index, spec) in [
            (CGSize(width: r * 2.20, height: r * 0.52), CGFloat(0.07), CGFloat(-r * 0.96)),
            (CGSize(width: r * 1.72, height: r * 0.34), CGFloat(0.11), CGFloat(-r * 0.93)),
            (CGSize(width: r * 1.16, height: r * 0.20), CGFloat(0.09), CGFloat(-r * 0.90))
        ].enumerated() {
            let shadow = SKShapeNode(ellipseOf: spec.0)
            shadow.fillColor = WarmShelfPalette.contactShadow.withAlpha(spec.1)
            shadow.strokeColor = .clear
            shadow.position = CGPoint(x: 0, y: spec.2)
            shadow.zPosition = CGFloat(-3 + index)
            breathing.addChild(shadow)
            shadows.append(shadow)
            shadowHomes.append(shadow.position)
            shadowAlphas.append(spec.1)
        }

        // Authored Wren (head/body/legs cut from her sheet, face inpainted OFF the
        // head so her living procedural face rides the painted clay — house law).
        // The face cluster lifts onto the authored head, which stands taller than
        // the blob's face line; everything else (states, breathing, squash) is shared.
        let headTex = ToyArt.texture("wren-head")
        let bodyTex = ToyArt.texture("wren-body")
        let artMode = headTex != nil && bodyTex != nil
        let faceLift: CGFloat = artMode ? r * 0.40 : 0
        let cheekSpread: CGFloat = artMode ? r * 0.50 : r * 0.66

        let body: SKShapeNode
        if artMode {
            body = SKShapeNode()   // invisible armature; the authored clay hangs on it
            body.zPosition = 0
            breathing.addChild(body)

            if let legs = ToyArt.sprite("wren-legs", fit: CGSize(width: r * 1.1, height: r * 0.45)) {
                legs.position = CGPoint(x: 0, y: -r * 0.78)
                legs.zPosition = -0.5
                body.addChild(legs)
            }
            if let tex = bodyTex {
                let bodyArt = SKSpriteNode(texture: tex)
                let w = r * 1.55
                bodyArt.size = CGSize(width: w, height: w * tex.size().height / max(1, tex.size().width))
                bodyArt.position = CGPoint(x: 0, y: -r * 0.42)
                bodyArt.zPosition = 0
                body.addChild(bodyArt)
            }
            if let tex = headTex {
                let headArt = SKSpriteNode(texture: tex)
                let w = r * 1.5
                headArt.size = CGSize(width: w, height: w * tex.size().height / max(1, tex.size().width))
                headArt.position = CGPoint(x: 0, y: r * 0.34)
                headArt.zPosition = 1
                body.addChild(headArt)
            }
        } else {
            body = SKShapeNode(path: organicBodyPath())
            // Clay gradient (key light upper-left) so Wren reads dimensional like the icon.
            // Wren's signature red — the saturated tomato clay from the concept art, warmer and
            // bolder than the shelf terracotta so the little host pops as a character.
            let wrenRed = UIColor(hex: 0xE0472E)
            if let box = body.path?.boundingBoxOfPath {
                body.fillColor = .white
                body.fillTexture = ProceduralTexture.radialClayTexture(base: wrenRed, size: box.size)
            } else {
                body.fillColor = wrenRed
            }
            body.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.065)
            body.lineWidth = 1.5
            body.zPosition = 0
            breathing.addChild(body)

            let lowerWarmth = SKShapeNode(path: organicBodyPath(scaleX: 0.92, scaleY: 0.72, yOffset: -r * 0.12))
            lowerWarmth.fillColor = WarmShelfPalette.rhubarb.withAlpha(0.08)
            lowerWarmth.strokeColor = .clear
            lowerWarmth.zPosition = 0.2
            body.addChild(lowerWarmth)
        }
        if !artMode {
        // Cream moon patch (a brand signature) — a soft halo behind a slightly softer core so
        // it reads as part of the clay body, not a hard-cut white blob over the gradient.
        // A soft sheen in the upper-left, kept subtle so the body reads as matte clay (not a
        // glossy cream patch) — closer to the handmade-toy reference.
        let moonHalo = SKShapeNode(ellipseOf: CGSize(width: r * 0.92, height: r * 0.6))
        moonHalo.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.12)
        moonHalo.strokeColor = .clear
        moonHalo.position = CGPoint(x: -r * 0.42, y: r * 0.44)
        moonHalo.zRotation = -0.34
        moonHalo.zPosition = 0.38
        body.addChild(moonHalo)

        let highlight = SKShapeNode(ellipseOf: CGSize(width: r * 0.58, height: r * 0.38))
        highlight.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.4)
        highlight.strokeColor = .clear
        highlight.position = CGPoint(x: -r * 0.46, y: r * 0.46)
        highlight.zRotation = -0.34
        highlight.zPosition = 0.4
        body.addChild(highlight)

        for index in 0..<12 {
            let dimple = SKShapeNode(circleOfRadius: dimpleRadius(index: index))
            dimple.fillColor = WarmShelfPalette.cocoa.withAlpha(dimpleAlpha(index: index))
            dimple.strokeColor = .clear
            dimple.position = dimplePosition(index: index)
            dimple.zPosition = 0.5
            body.addChild(dimple)
        }
        }   // !artMode — moon patch and dimples belong to the procedural blob only

        for sign in [CGFloat(-1), CGFloat(1)] {
            let cheek = SKShapeNode(circleOfRadius: r * 0.18)
            let home = CGPoint(x: sign * cheekSpread, y: -r * 0.17 + faceLift)
            cheek.fillColor = UIColor(hex: 0xC23420).withAlpha(0.72)   // tone-on-tone red cheeks, per concept
            cheek.strokeColor = .clear
            cheek.position = home
            cheek.zPosition = 2
            body.addChild(cheek)
            cheeks.append(cheek)
            cheekHomes.append(home)
        }

        for sign in [CGFloat(-1), CGFloat(1)] {
            let path = CGMutablePath()
            let ew = r * 0.20
            path.move(to: CGPoint(x: -ew, y: 0))
            path.addQuadCurve(to: CGPoint(x: ew, y: 0), control: CGPoint(x: 0, y: r * 0.16))
            let eye = SKShapeNode(path: path)
            eye.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.82)
            eye.lineWidth = r * 0.045
            eye.lineCap = .round
            eye.fillColor = .clear
            eye.position = CGPoint(x: sign * r * 0.34, y: r * 0.04 + faceLift)
            eye.zPosition = 3
            body.addChild(eye)
            sleepyEyes.append(eye)
        }

        for sign in [CGFloat(-1), CGFloat(1)] {
            let eye = SKNode()
            eye.position = CGPoint(x: sign * r * 0.34, y: r * 0.055 + faceLift)
            eye.zPosition = 4

            let white = SKShapeNode(ellipseOf: CGSize(width: r * 0.26, height: r * 0.30))
            white.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.97)
            white.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.10)
            white.lineWidth = 1
            eye.addChild(white)

            // Concept-art eyes: big glossy black buttons that nearly fill the sclera, with one
            // large soft catchlight high and a tiny lower sparkle — instant plush-toy life.
            let iris = SKShapeNode(circleOfRadius: r * 0.125)
            iris.fillColor = UIColor(hex: 0x2A1810)
            iris.strokeColor = .clear
            eye.addChild(iris)

            let pupil = SKShapeNode(circleOfRadius: r * 0.1)
            pupil.fillColor = UIColor(hex: 0x16100B)
            pupil.strokeColor = .clear
            let pupilHome = CGPoint(x: sign * r * 0.010, y: -r * 0.006)
            pupil.position = pupilHome
            eye.addChild(pupil)
            pupils.append(pupil)
            pupilHomes.append(pupilHome)

            let bigGlint = SKShapeNode(ellipseOf: CGSize(width: r * 0.085, height: r * 0.075))
            bigGlint.fillColor = .white.withAlpha(0.97)
            bigGlint.strokeColor = .clear
            bigGlint.position = CGPoint(x: -r * 0.045, y: r * 0.055)
            eye.addChild(bigGlint)

            let tinyGlint = SKShapeNode(circleOfRadius: r * 0.022)
            tinyGlint.fillColor = .white.withAlpha(0.75)
            tinyGlint.strokeColor = .clear
            tinyGlint.position = CGPoint(x: r * 0.05, y: -r * 0.045)
            eye.addChild(tinyGlint)

            eye.alpha = 0
            eye.yScale = 0.01
            body.addChild(eye)
            openEyes.append(eye)
        }

        let m = SKShapeNode(path: contentMouthPath())
        m.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.60)
        m.lineWidth = r * 0.05
        m.lineCap = .round
        m.fillColor = .clear
        m.position = CGPoint(x: 0, y: -r * 0.23 + faceLift)
        m.zPosition = 3
        body.addChild(m)
        mouth = m

        // The authored head wears its painted butter cap; the animated clay capstone
        // is the procedural blob's hat only (two hats is one too many).
        if !artMode {
            let stone = makeCapstone()
            stone.position = CGPoint(x: r * 0.56, y: r * 0.78)
            stone.zRotation = capstoneHomeAngle
            stone.zPosition = 6
            breathing.addChild(stone)
            capstone = stone
        }
    }

    private func organicBodyPath(scaleX: CGFloat = 1, scaleY: CGFloat = 1, yOffset: CGFloat = 0) -> CGPath {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * r * scaleX, y: y * r * scaleY + yOffset)
        }
        // A clean, mirror-symmetric clay dome — rounded top, gently settled (wider) bottom —
        // so the silhouette reads finished like the icon, not lumpy and hand-wobbled.
        let path = CGMutablePath()
        path.move(to: p(0, 1.0))
        path.addCurve(to: p(1.05, 0.02), control1: p(0.60, 1.03), control2: p(1.03, 0.60))
        path.addCurve(to: p(0.66, -0.82), control1: p(1.07, -0.40), control2: p(1.00, -0.66))
        path.addCurve(to: p(0, -0.92), control1: p(0.40, -0.93), control2: p(0.20, -0.92))
        path.addCurve(to: p(-0.66, -0.82), control1: p(-0.20, -0.92), control2: p(-0.40, -0.93))
        path.addCurve(to: p(-1.05, 0.02), control1: p(-1.00, -0.66), control2: p(-1.07, -0.40))
        path.addCurve(to: p(0, 1.0), control1: p(-1.03, 0.60), control2: p(-0.60, 1.03))
        path.closeSubpath()
        return path
    }

    private func dimplePosition(index: Int) -> CGPoint {
        let points: [CGPoint] = [
            CGPoint(x: -0.66, y: -0.34), CGPoint(x: -0.38, y: 0.18),
            CGPoint(x: -0.12, y: -0.56), CGPoint(x: 0.18, y: 0.38),
            CGPoint(x: 0.52, y: -0.22), CGPoint(x: 0.74, y: 0.14),
            CGPoint(x: -0.78, y: 0.20), CGPoint(x: 0.34, y: -0.55),
            CGPoint(x: -0.18, y: 0.62), CGPoint(x: 0.64, y: 0.46),
            CGPoint(x: -0.52, y: 0.48), CGPoint(x: 0.02, y: -0.22)
        ]
        let pt = points[index % points.count]
        return CGPoint(x: pt.x * r, y: pt.y * r)
    }

    private func dimpleRadius(index: Int) -> CGFloat {
        [0.026, 0.040, 0.030, 0.048, 0.034, 0.024, 0.032, 0.045, 0.023, 0.036, 0.028, 0.022][index % 12] * r
    }

    private func dimpleAlpha(index: Int) -> CGFloat {
        [0.035, 0.052, 0.042, 0.030, 0.048, 0.038, 0.033, 0.055, 0.026, 0.044, 0.032, 0.036][index % 12]
    }

    private func makeCapstone() -> SKNode {
        let node = SKNode()
        let size = CGSize(width: r * 0.82, height: r * 0.30)
        let stone = SKShapeNode(rectOf: size, cornerRadius: size.height * 0.48)
        stone.fillColor = UIColor(hex: 0xF2A33C)   // the concept's little orange beret-pebble
        stone.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.10)
        stone.lineWidth = max(0.8, r * 0.012)
        node.addChild(stone)

        let lowerShade = SKShapeNode(ellipseOf: CGSize(width: size.width * 0.72, height: size.height * 0.30))
        lowerShade.fillColor = WarmShelfPalette.cocoa.withAlpha(0.055)
        lowerShade.strokeColor = .clear
        lowerShade.position = CGPoint(x: size.width * 0.06, y: -size.height * 0.18)
        lowerShade.zPosition = 0.1
        stone.addChild(lowerShade)

        let highlight = SKShapeNode(ellipseOf: CGSize(width: size.width * 0.48, height: size.height * 0.32))
        highlight.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.46)
        highlight.strokeColor = .clear
        highlight.position = CGPoint(x: -size.width * 0.12, y: size.height * 0.18)
        highlight.zRotation = -0.25
        highlight.zPosition = 0.2
        stone.addChild(highlight)

        for x in [CGFloat(-0.20), CGFloat(0.20)] {
            let dimple = SKShapeNode(circleOfRadius: max(0.8, r * 0.016))
            dimple.fillColor = WarmShelfPalette.cocoa.withAlpha(0.10)
            dimple.strokeColor = .clear
            dimple.position = CGPoint(x: size.width * CGFloat(x), y: -size.height * 0.04)
            dimple.zPosition = 0.25
            stone.addChild(dimple)
        }

        let glint = SKShapeNode(ellipseOf: CGSize(width: size.width * 0.12, height: size.height * 0.16))
        glint.fillColor = .white.withAlpha(0.78)
        glint.strokeColor = .clear
        glint.position = CGPoint(x: -size.width * 0.22, y: size.height * 0.18)
        glint.zRotation = -0.28
        glint.alpha = 0
        glint.zPosition = 0.35
        stone.addChild(glint)
        capstoneGlint = glint

        return node
    }

    // MARK: - Public State

    func rest() {
        state = .resting
        removeAction(forKey: "host.sequence")
        showSleeping(true, duration: 0)
        mouth?.path = contentMouthPath()
        resetCheeks(duration: 0.24)
        centerPupils(duration: 0.2)
        breathing.removeAction(forKey: scaleKey)
        breathing.run(.scale(to: 1.0, duration: 0.3))
        startAmbientBreathing()
        startCapstoneIdle()
        scheduleEyeWander()
        scheduleCapstoneGlint()
    }

    func notice(toward point: CGPoint? = nil) {
        state = .noticing
        breathing.removeAction(forKey: breatheKey)
        breathing.removeAction(forKey: sighKey)
        removeAction(forKey: eyeWanderKey)

        let perk = SKAction.scale(to: 1.062, duration: 0.18)
        perk.timingMode = .easeOut
        breathing.run(perk, withKey: scaleKey)
        showSleeping(false, duration: 0.16)
        dilatePupils(to: 1.24, settleTo: 1.0, duration: 0.18, settleDuration: 0.52)

        if let point {
            leanToward(scenePoint: point, amount: 0.075, duration: 0.18)
            trackEyes(toward: point, strength: 1.0)
        }
        capstoneNoticeBounce()
    }

    func respond() {
        state = .responding
        mouth?.path = happyMouthPath()
        mouth?.run(.sequence([.scale(to: 1.16, duration: 0.12), .scale(to: 1.0, duration: 0.18)]))
        bloomCheeks(alpha: 0.78, lift: r * 0.055, duration: 0.18)
        bounce(height: r * 0.12, upDuration: 0.16, downDuration: 0.30, squash: true)
    }

    func settle() {
        state = .resting
        let down = SKAction.scale(to: 1.0, duration: 0.95)
        down.timingMode = .easeInEaseOut
        breathing.run(down, withKey: scaleKey)
        let straighten = SKAction.rotate(toAngle: 0, duration: 0.85)
        straighten.timingMode = .easeInEaseOut
        breathing.run(straighten, withKey: leanKey)
        centerPupils(duration: 0.45)
        showSleeping(true, duration: 0.6)
        resetCheeks(duration: 0.72)
        mouth?.run(.sequence([.wait(forDuration: 0.48), .run { [weak self] in
            self?.mouth?.path = self?.contentMouthPath()
        }]))
        run(.sequence([.wait(forDuration: 1.0), .run { [weak self] in
            guard let self, self.state == .resting else { return }
            self.startAmbientBreathing()
            self.scheduleEyeWander()
        }]))
    }

    func tapped(at point: CGPoint? = nil) {
        removeAction(forKey: "host.sequence")
        run(.sequence([
            .run { [weak self] in self?.notice(toward: point) },
            .wait(forDuration: 0.20),
            .run { [weak self] in self?.respond() },
            .wait(forDuration: 0.75),
            .run { [weak self] in self?.settle() }
        ]), withKey: "host.sequence")
        HapticsManager.shared.softTap()
    }

    /// Peek-a-boo (founder, build 5): a quick happy wiggle before Wren scoots off the edge.
    /// Quiet on purpose: no sound, just a delighted face and a wiggle.
    func wiggle() {
        removeAction(forKey: "host.sequence")
        state = .responding
        breathing.removeAction(forKey: breatheKey)
        removeAction(forKey: eyeWanderKey)
        showSleeping(false, duration: 0.08)
        centerPupils(duration: 0.1)
        mouth?.path = delightedMouthPath()
        bloomCheeks(alpha: 0.9, lift: r * 0.08, duration: 0.1)
        guard !AmbientAnimator.reduceMotion else { return }
        let a: CGFloat = 0.16
        breathing.run(.sequence([
            .rotate(toAngle: a, duration: 0.07), .rotate(toAngle: -a, duration: 0.1),
            .rotate(toAngle: a * 0.8, duration: 0.1), .rotate(toAngle: -a * 0.6, duration: 0.09),
            .rotate(toAngle: 0, duration: 0.08)
        ]), withKey: leanKey)
    }

    func giggle(at point: CGPoint? = nil) {
        removeAction(forKey: "host.sequence")
        state = .responding
        showSleeping(false, duration: 0.10)
        if let point {
            leanToward(scenePoint: point, amount: 0.09, duration: 0.10)
            trackEyes(toward: point, strength: 1.0)
        }
        dilatePupils(to: 1.34, settleTo: 1.10, duration: 0.10, settleDuration: 0.24)
        mouth?.path = delightedMouthPath()
        bloomCheeks(alpha: 0.96, lift: r * 0.10, duration: 0.12)

        let bob = SKAction.sequence([
            .moveBy(x: 0, y: r * 0.13, duration: 0.07),
            .moveBy(x: 0, y: -r * 0.13, duration: 0.10)
        ])
        bob.timingMode = .easeOut
        breathing.run(.sequence([
            .repeat(bob, count: 3),
            .run { [weak self] in self?.playLandingSquash(intensity: 1.0) },
            .wait(forDuration: 0.58),
            .run { [weak self] in self?.settle() }
        ]), withKey: bobKey)

        let spin = SKAction.rotate(byAngle: .pi * 2, duration: 0.42)
        spin.timingMode = .easeInEaseOut
        capstone?.run(spin, withKey: capstoneLagKey)
        AudioManager.shared.playMixCelebrate()
        HapticsManager.shared.softTap()
    }

    func beginLongPress(at point: CGPoint) {
        removeAction(forKey: "host.sequence")
        notice(toward: point)
        mouth?.path = happyMouthPath()
        bloomCheeks(alpha: 0.82, lift: r * 0.065, duration: 0.14)
        leanToward(scenePoint: point, amount: 0.19, duration: 0.18)
        trackEyes(toward: point, strength: 1.18)
    }

    func continueLongPress(at point: CGPoint) {
        state = .responding
        leanToward(scenePoint: point, amount: 0.19, duration: 0.10)
        trackEyes(toward: point, strength: 1.18)
    }

    func endLongPress(at point: CGPoint? = nil) {
        if let point {
            trackEyes(toward: point, strength: 0.8)
        }
        bounce(height: r * 0.20, upDuration: 0.15, downDuration: 0.34, squash: true)
        run(.sequence([.wait(forDuration: 0.68), .run { [weak self] in self?.settle() }]), withKey: "host.sequence")
        AudioManager.shared.playToySettle()
    }

    func trackEyes(toward point: CGPoint, strength: CGFloat = 1.0) {
        showSleeping(false, duration: 0.08)
        let local = localPoint(fromScenePoint: point)
        let maxOffset = r * 0.045 * strength
        let offset = CGPoint(
            x: (local.x / (r * 1.8)).clamped(to: -1...1) * maxOffset,
            y: (local.y / (r * 1.8)).clamped(to: -1...1) * maxOffset
        )
        for (index, pupil) in pupils.enumerated() {
            let home = pupilHomes[index]
            let move = SKAction.move(to: CGPoint(x: home.x + offset.x, y: home.y + offset.y), duration: 0.08)
            move.timingMode = .easeOut
            pupil.run(move, withKey: pupilKey)
        }
    }

    // MARK: - Expression & motion API (gameplay-facing)

    /// Set Wren's face to one of five readable expressions. Built on the existing clay machinery
    /// so it stays perfectly consistent with the rest of his behaviour.
    func setExpression(_ expression: Expression, animated: Bool = true) {
        removeAction(forKey: "host.sequence")
        let dur: TimeInterval = animated ? 0.18 : 0
        switch expression {
        case .neutral:
            showSleeping(false, duration: dur)
            mouth?.path = contentMouthPath()
            resetCheeks(duration: max(0.01, dur))
            centerPupils(duration: max(0.01, dur))
        case .smile:
            showSleeping(false, duration: dur)
            mouth?.path = happyMouthPath()
            if animated { mouth?.run(.sequence([.scale(to: 1.12, duration: 0.10), .scale(to: 1.0, duration: 0.16)])) }
            bloomCheeks(alpha: 0.80, lift: r * 0.05, duration: max(0.01, dur))
            centerPupils(duration: max(0.01, dur))
        case .laugh:
            showSleeping(false, duration: dur)
            mouth?.path = delightedMouthPath()
            bloomCheeks(alpha: 0.96, lift: r * 0.10, duration: max(0.01, dur))
            dilatePupils(to: 1.20, settleTo: 1.06, duration: 0.10, settleDuration: 0.26)
            if animated { bounce(height: r * 0.10, upDuration: 0.12, downDuration: 0.24, squash: true) }
        case .sleepy:
            showSleeping(true, duration: dur)
            mouth?.path = contentMouthPath()
            resetCheeks(duration: max(0.01, dur))
            centerPupils(duration: max(0.01, dur))
        case .surprised:
            showSleeping(false, duration: dur)
            mouth?.path = surprisedMouthPath()
            bloomCheeks(alpha: 0.60, lift: r * 0.02, duration: max(0.01, dur))
            dilatePupils(to: 1.36, settleTo: 1.18, duration: 0.10, settleDuration: 0.30)
            if animated { breathing.run(.sequence([.scale(to: 1.06, duration: 0.10), .scale(to: 1.0, duration: 0.22)]), withKey: scaleKey) }
        }
    }

    /// A soft, occasional blink — only meaningful while Wren is awake (open-eyed).
    func blink() {
        guard (openEyes.first?.alpha ?? 0) > 0.5 else { return }
        for eye in openEyes {
            eye.removeAction(forKey: "host.blink")
            let close = SKAction.scaleY(to: 0.08, duration: 0.06)
            let open = SKAction.scaleY(to: 1.0, duration: 0.12)
            close.timingMode = .easeIn; open.timingMode = .easeOut
            eye.run(.sequence([close, open]), withKey: "host.blink")
        }
    }

    /// Picked up like a soft toy: the body lifts and rounds while the contact shadow drops away
    /// and softens beneath it. Pass `false` to set him back down.
    func setLifted(_ lifted: Bool) {
        guard lifted != isLifted else { return }
        isLifted = lifted
        for (index, shadow) in shadows.enumerated() {
            shadow.removeAction(forKey: "host.lift")
            let home = shadowHomes[index]
            let move = SKAction.move(to: CGPoint(x: home.x, y: home.y - r * (lifted ? 0.07 : 0)), duration: 0.2)
            let fade = SKAction.fadeAlpha(to: shadowAlphas[index] * (lifted ? 0.5 : 1.0), duration: 0.2)
            let scale = SKAction.scale(to: lifted ? 0.82 : 1.0, duration: 0.2)
            shadow.run(.group([move, fade, scale]), withKey: "host.lift")
        }
        breathing.removeAction(forKey: "host.liftScale")
        let bodyScale = SKAction.scale(to: lifted ? 1.05 : 1.0, duration: lifted ? 0.16 : 0.3)
        bodyScale.timingMode = lifted ? .easeOut : .easeInEaseOut
        breathing.run(bodyScale, withKey: "host.liftScale")
    }

    /// A gentle, self-rescheduling idle blink. No-op under Reduce Motion.
    func startIdleBlink() {
        guard !AmbientAnimator.reduceMotion else { return }
        removeAction(forKey: "host.blinkLoop")
        let loop = SKAction.sequence([
            .wait(forDuration: Double.random(in: 3.0...6.5)),
            .run { [weak self] in self?.blink() }
        ])
        run(.repeatForever(loop), withKey: "host.blinkLoop")
    }

    // MARK: - Motion

    private func startAmbientBreathing() {
        // Reduce Motion calms Wren, it never stops them breathing — a frozen creature
        // isn't calmer, it's gone. Breath survives at half depth and slower tempo;
        // the sigh (a positional bob) stays gated below.
        let calm = AmbientAnimator.reduceMotion
        let depth: CGFloat = calm ? 0.45 : 1.0
        let tempo: TimeInterval = calm ? 1.4 : 1.0
        breathing.removeAction(forKey: breatheKey)
        breathing.removeAction(forKey: sighKey)

        let inhaleDuration: TimeInterval = 1.85 * tempo
        let exhaleDuration: TimeInterval = 2.15 * tempo
        let inhale = SKAction.customAction(withDuration: inhaleDuration) { [weak self] node, elapsed in
            guard let self else { return }
            let t = self.cubicBezierProgress(elapsed / inhaleDuration, p1y: 0.10, p2y: 0.88)
            node.xScale = 1.0 + 0.018 * depth * t
            node.yScale = 1.0 + 0.034 * depth * t
        }
        let exhale = SKAction.customAction(withDuration: exhaleDuration) { [weak self] node, elapsed in
            guard let self else { return }
            let t = self.cubicBezierProgress(elapsed / exhaleDuration, p1y: 0.18, p2y: 1.0)
            node.xScale = 1.0 + 0.018 * depth * (1 - t)
            node.yScale = 1.0 + 0.034 * depth * (1 - t)
        }
        breathing.run(.repeatForever(.sequence([inhale, exhale])), withKey: breatheKey)

        guard !calm else { return }
        let sigh = SKAction.sequence([
            .wait(forDuration: 6.4),
            .customAction(withDuration: 0.95) { [weak self] node, elapsed in
                guard let self else { return }
                let t = self.cubicBezierProgress(elapsed / 0.95, p1y: 0.10, p2y: 0.92)
                node.position.y = -self.r * 0.018 * t
            },
            .customAction(withDuration: 1.25) { [weak self] node, elapsed in
                guard let self else { return }
                let t = self.cubicBezierProgress(elapsed / 1.25, p1y: 0.12, p2y: 1.0)
                node.position.y = -self.r * 0.018 + self.r * 0.018 * t
            }
        ])
        breathing.run(.repeatForever(sigh), withKey: sighKey)
    }

    private func bounce(height: CGFloat, upDuration: TimeInterval, downDuration: TimeInterval, squash: Bool) {
        breathing.removeAction(forKey: bobKey)
        let up = SKAction.moveBy(x: 0, y: height, duration: upDuration)
        let down = SKAction.moveBy(x: 0, y: -height, duration: downDuration)
        up.timingMode = .easeOut
        down.timingMode = .easeIn
        breathing.run(.sequence([
            up,
            down,
            .run { [weak self] in
                guard let self else { return }
                if squash { self.playLandingSquash(intensity: min(1.2, height / (self.r * 0.18))) }
                self.capstoneSecondaryMotion(intensity: min(1.2, height / (self.r * 0.20)))
            }
        ]), withKey: bobKey)
    }

    private func playLandingSquash(intensity: CGFloat) {
        breathing.removeAction(forKey: landingKey)
        let squash = SKAction.scaleX(to: 1.0 + 0.11 * intensity, y: 1.0 - 0.12 * intensity, duration: 0.08)
        let rebound = SKAction.scaleX(to: 0.98, y: 1.045, duration: 0.10)
        let settle = SKAction.scale(to: 1.0, duration: 0.22)
        squash.timingMode = .easeOut
        rebound.timingMode = .easeOut
        settle.timingMode = .easeInEaseOut
        breathing.run(.sequence([squash, rebound, settle]), withKey: landingKey)
    }

    private func capstoneSecondaryMotion(intensity: CGFloat) {
        guard let capstone else { return }
        capstone.removeAction(forKey: capstoneLagKey)
        let lag = SKAction.rotate(byAngle: -0.16 * intensity, duration: 0.10)
        let spring = SKAction.rotate(byAngle: 0.22 * intensity, duration: 0.16)
        let settle = SKAction.rotate(toAngle: capstoneHomeAngle, duration: 0.26)
        lag.timingMode = .easeOut
        spring.timingMode = .easeOut
        settle.timingMode = .easeInEaseOut
        capstone.run(.sequence([.wait(forDuration: 0.06), lag, spring, settle]), withKey: capstoneLagKey)
    }

    private func capstoneNoticeBounce() {
        capstone?.removeAction(forKey: capstoneLagKey)
        let pop = SKAction.scale(to: 1.12, duration: 0.12)
        let settle = SKAction.scale(to: 1.0, duration: 0.20)
        pop.timingMode = .easeOut
        settle.timingMode = .easeInEaseOut
        capstone?.run(.sequence([pop, settle]), withKey: capstoneLagKey)
    }

    private func startCapstoneIdle() {
        guard !AmbientAnimator.reduceMotion else { return }
        capstone?.removeAction(forKey: capstoneKey)
        let tiltToPeak = SKAction.group([
            .rotate(toAngle: capstoneHomeAngle + 0.04, duration: 2.4),
            .sequence([.wait(forDuration: 1.8), .scale(to: 1.018, duration: 0.28), .scale(to: 1.0, duration: 0.32)])
        ])
        capstone?.run(.repeatForever(.sequence([
            .rotate(toAngle: capstoneHomeAngle - 0.04, duration: 2.2),
            tiltToPeak
        ])), withKey: capstoneKey)
    }

    private func leanToward(scenePoint: CGPoint, amount: CGFloat, duration: TimeInterval) {
        let local = localPoint(fromScenePoint: scenePoint)
        let lean = (local.x / (r * 2.0)).clamped(to: -1...1) * amount
        let action = SKAction.rotate(toAngle: lean, duration: duration)
        action.timingMode = .easeOut
        breathing.run(action, withKey: leanKey)
    }

    // MARK: - Eyes And Face

    private func showSleeping(_ sleeping: Bool, duration: TimeInterval) {
        sleepyEyes.forEach { $0.removeAction(forKey: eyeKey) }
        openEyes.forEach { $0.removeAction(forKey: eyeKey) }

        guard duration > 0 else {
            sleepyEyes.forEach { $0.alpha = sleeping ? 1 : 0 }
            openEyes.forEach { $0.alpha = sleeping ? 0 : 1; $0.yScale = sleeping ? 0.01 : 1 }
            return
        }

        if sleeping {
            let closeDur: CGFloat = 0.10
            let arcDur: CGFloat = 0.16
            for eye in openEyes {
                let close = SKAction.customAction(withDuration: closeDur) { node, elapsed in
                    node.yScale = max(0.01, 1.0 - elapsed / closeDur)
                }
                eye.run(.sequence([close, .run { eye.alpha = 0; eye.yScale = 0.01 }]), withKey: eyeKey)
            }
            for eye in sleepyEyes {
                eye.alpha = 0
                let openArc = SKAction.customAction(withDuration: arcDur) { [weak self] node, elapsed in
                    guard let self, let shape = node as? SKShapeNode else { return }
                    shape.path = self.sleepyEyeArcPath(openFraction: min(1, elapsed / arcDur))
                }
                eye.run(.sequence([
                    .wait(forDuration: closeDur * 0.55),
                    .fadeIn(withDuration: 0),
                    openArc
                ]), withKey: eyeKey)
            }
        } else {
            let closeArcDur: CGFloat = 0.08
            let openDur: CGFloat = 0.12
            for eye in sleepyEyes {
                let closeArc = SKAction.customAction(withDuration: closeArcDur) { [weak self] node, elapsed in
                    guard let self, let shape = node as? SKShapeNode else { return }
                    shape.path = self.sleepyEyeArcPath(openFraction: max(0, 1.0 - elapsed / closeArcDur))
                }
                eye.run(.sequence([
                    closeArc,
                    .fadeOut(withDuration: 0),
                    .run { [weak self] in eye.path = self?.sleepyEyeArcPath(openFraction: 1.0) }
                ]), withKey: eyeKey)
            }
            for eye in openEyes {
                eye.yScale = 0.01
                eye.alpha = 1
                let open = SKAction.customAction(withDuration: openDur) { node, elapsed in
                    node.yScale = min(1, elapsed / openDur)
                }
                eye.run(.sequence([.wait(forDuration: closeArcDur * 0.65), open, .run { eye.yScale = 1.0 }]), withKey: eyeKey)
            }
        }
    }

    private func sleepyEyeArcPath(openFraction: CGFloat) -> CGPath {
        let p = CGMutablePath()
        let ew = r * 0.20
        p.move(to: CGPoint(x: -ew, y: 0))
        p.addQuadCurve(to: CGPoint(x: ew, y: 0), control: CGPoint(x: 0, y: r * 0.16 * openFraction))
        return p
    }

    private func dilatePupils(to scale: CGFloat, settleTo: CGFloat, duration: TimeInterval, settleDuration: TimeInterval) {
        for pupil in pupils {
            pupil.removeAction(forKey: pupilKey + ".scale")
            let dilate = SKAction.scale(to: scale, duration: duration)
            let settle = SKAction.scale(to: settleTo, duration: settleDuration)
            dilate.timingMode = .easeOut
            settle.timingMode = .easeInEaseOut
            pupil.run(.sequence([dilate, settle]), withKey: pupilKey + ".scale")
        }
    }

    private func centerPupils(duration: TimeInterval) {
        for (index, pupil) in pupils.enumerated() {
            let move = SKAction.move(to: pupilHomes[index], duration: duration)
            move.timingMode = .easeInEaseOut
            pupil.run(move, withKey: pupilKey)
            let scale = SKAction.scale(to: 1.0, duration: duration)
            scale.timingMode = .easeInEaseOut
            pupil.run(scale, withKey: pupilKey + ".scale")
        }
    }

    private func bloomCheeks(alpha: CGFloat, lift: CGFloat, duration: TimeInterval) {
        for (index, cheek) in cheeks.enumerated() {
            let home = cheekHomes[index]
            let move = SKAction.move(to: CGPoint(x: home.x, y: home.y + lift), duration: duration)
            let fade = SKAction.fadeAlpha(to: alpha, duration: duration)
            move.timingMode = .easeOut
            fade.timingMode = .easeOut
            cheek.run(.group([move, fade]))
        }
    }

    private func resetCheeks(duration: TimeInterval) {
        for (index, cheek) in cheeks.enumerated() {
            let move = SKAction.move(to: cheekHomes[index], duration: duration)
            let fade = SKAction.fadeAlpha(to: 0.48, duration: duration)
            move.timingMode = .easeInEaseOut
            fade.timingMode = .easeInEaseOut
            cheek.run(.group([move, fade]))
        }
    }

    private func scheduleEyeWander() {
        guard !AmbientAnimator.reduceMotion else { return }
        removeAction(forKey: eyeWanderKey)
        let wait = SKAction.wait(forDuration: Double.random(in: 7...12))
        run(.sequence([wait, .run { [weak self] in self?.playIdleEyeWander() }]), withKey: eyeWanderKey)
    }

    private func playIdleEyeWander() {
        guard state == .resting else {
            scheduleEyeWander()
            return
        }
        // Stay serenely asleep on the shelf, like the icon — no eye-popping. Just a soft,
        // dreamy lean now and then, so he's alive without ever looking busy or cartoonish.
        let sway = SKAction.sequence([
            .rotate(toAngle: 0.02, duration: 1.1),
            .rotate(toAngle: 0, duration: 1.3)
        ])
        sway.timingMode = .easeInEaseOut
        breathing.run(sway, withKey: leanKey)
        run(.sequence([
            .wait(forDuration: 2.6),
            .run { [weak self] in self?.scheduleEyeWander() }
        ]), withKey: eyeWanderKey)
    }

    private func scheduleCapstoneGlint() {
        guard !AmbientAnimator.reduceMotion else { return }
        removeAction(forKey: capstoneGlintKey)
        run(.sequence([
            .wait(forDuration: Double.random(in: 4...8)),
            .run { [weak self] in self?.playCapstoneGlint() }
        ]), withKey: capstoneGlintKey)
    }

    private func playCapstoneGlint() {
        guard let glint = capstoneGlint else { return }
        glint.removeAllActions()
        glint.alpha = 0
        glint.position = CGPoint(x: -r * 0.15, y: r * 0.045)
        let flash = SKAction.group([
            .sequence([.fadeAlpha(to: 1.0, duration: 0.10), .fadeAlpha(to: 0, duration: 0.22)]),
            .moveBy(x: r * 0.11, y: r * 0.035, duration: 0.32)
        ])
        flash.timingMode = .easeOut
        glint.run(flash)
        scheduleCapstoneGlint()
    }

    // MARK: - Paths And Helpers

    private func contentMouthPath() -> CGPath {
        let p = CGMutablePath()
        let w = r * 0.22
        p.move(to: CGPoint(x: -w, y: 0))
        p.addQuadCurve(to: CGPoint(x: w, y: 0), control: CGPoint(x: 0, y: -r * 0.12))
        return p
    }

    private func happyMouthPath() -> CGPath {
        let p = CGMutablePath()
        let w = r * 0.31
        p.move(to: CGPoint(x: -w, y: r * 0.02))
        p.addQuadCurve(to: CGPoint(x: w, y: r * 0.02), control: CGPoint(x: 0, y: -r * 0.26))
        return p
    }

    private func delightedMouthPath() -> CGPath {
        let p = CGMutablePath()
        let w = r * 0.27
        p.addEllipse(in: CGRect(x: -w * 0.55, y: -r * 0.15, width: w * 1.1, height: r * 0.22))
        return p
    }

    private func surprisedMouthPath() -> CGPath {
        let p = CGMutablePath()
        let w = r * 0.13
        p.addEllipse(in: CGRect(x: -w, y: -r * 0.14, width: w * 2, height: r * 0.23))
        return p
    }

    private func localPoint(fromScenePoint point: CGPoint) -> CGPoint {
        if let scene {
            return convert(point, from: scene)
        }
        return point
    }

    private func cubicBezierProgress(_ raw: CGFloat, p1y: CGFloat, p2y: CGFloat) -> CGFloat {
        let t = raw.clamped(to: 0...1)
        let inv = 1 - t
        return 3 * inv * inv * t * p1y + 3 * inv * t * t * p2y + t * t * t
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
