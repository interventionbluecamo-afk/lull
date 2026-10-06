import SpriteKit

enum GardenCritterKind: CaseIterable {
    case mouse
    case bear
    case bird

    var displayScale: CGFloat {
        switch self {
        case .mouse: return 1.0
        case .bear: return 1.18
        case .bird: return 1.08
        }
    }

    var accessibilityName: String {
        switch self {
        case .mouse: return "little mouse"
        case .bear: return "friendly bear"
        case .bird: return "little bird"
        }
    }
}

/// A tiny clay critter-friend. The silhouettes stay toddler-readable (mouse, bear, bird),
/// but the surfaces are hand-sculpted and warm instead of alphabet-card flat.
final class GardenCritterNode: SKNode {
    let kind: GardenCritterKind
    private let s: CGFloat
    private var rangeMinX: CGFloat = 0
    private var rangeMaxX: CGFloat = 0
    private var reacting = false
    private var grabbed = false
    var isGrabbed: Bool { grabbed }
    private var lastDir: CGFloat = 1
    private var shadow: SKShapeNode?

    private var earLeft = SKNode()
    private var earRight = SKNode()
    private var wingNode = SKNode()
    /// `gaitNode` carries the walk waddle (bob + lean); `body` carries the art and the
    /// directional flip — kept separate so the two never fight.
    private var gaitNode = SKNode()
    private var body = SKNode()
    /// The two feet/paws (drawn as part of the body; not individually articulated).
    private var feet: [SKShapeNode] = []
    private var feetHome: [CGPoint] = []

    /// Where the critter's feet meet the ground (local y), so the shadow sits flat.
    private var footY: CGFloat {
        switch kind {
        case .mouse: return -12 * s
        case .bear: return -21 * s
        case .bird: return -18 * s
        }
    }

    init(kind: GardenCritterKind, scale: CGFloat) {
        self.kind = kind
        self.s = scale * kind.displayScale
        super.init()
        name = "critter"

        // A soft ground shadow anchors the critter to the floor as it moves past things.
        let sh = SKShapeNode(ellipseOf: CGSize(width: 44 * s, height: 13 * s))
        sh.fillColor = WarmShelfPalette.contactShadow.withAlpha(0.13)
        sh.strokeColor = .clear
        sh.position = CGPoint(x: 3 * s, y: footY)
        sh.zPosition = -1
        addChild(sh)
        shadow = sh

        addChild(gaitNode)
        gaitNode.addChild(body)
        switch kind {
        case .mouse: buildMouse()
        case .bear: buildBear()
        case .bird: buildBird()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var accessibilityName: String { kind.accessibilityName }

    /// Vertical offset of the critter's "heart" above its base, for tap-targeting.
    var tapYOffset: CGFloat { 18 * s }

    // MARK: - Builders

    private func eye(at p: CGPoint, r: CGFloat) {
        let white = SKShapeNode(circleOfRadius: r)
        white.fillColor = WarmShelfPalette.paperHighlight; white.strokeColor = .clear
        white.position = p; body.addChild(white)
        let pupil = SKShapeNode(circleOfRadius: r * 0.55)
        pupil.fillColor = WarmShelfPalette.cocoa.withAlpha(0.85); pupil.strokeColor = .clear
        pupil.position = CGPoint(x: p.x + r * 0.18, y: p.y + r * 0.18); body.addChild(pupil)
        let glint = SKShapeNode(circleOfRadius: r * 0.28)
        glint.fillColor = WarmShelfPalette.paperHighlight; glint.strokeColor = .clear
        glint.position = CGPoint(x: p.x - r * 0.1, y: p.y + r * 0.35); body.addChild(glint)
    }

    private func cheek(at p: CGPoint, r: CGFloat) {
        let c = SKShapeNode(circleOfRadius: r)
        c.fillColor = WarmShelfPalette.petal.withAlpha(0.5); c.strokeColor = .clear
        c.position = p; body.addChild(c)
    }

    private func clayDimple(x: CGFloat, y: CGFloat, r: CGFloat, alpha: CGFloat = 0.055, on parent: SKNode? = nil) {
        let dimple = SKShapeNode(circleOfRadius: r * s)
        dimple.fillColor = WarmShelfPalette.cocoa.withAlpha(alpha)
        dimple.strokeColor = .clear
        dimple.position = CGPoint(x: x * s, y: y * s)
        (parent ?? body).addChild(dimple)
    }

    private func clayHighlight(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, alpha: CGFloat = 0.10, on parent: SKNode? = nil) {
        let highlight = SKShapeNode(ellipseOf: CGSize(width: width * s, height: height * s))
        highlight.fillColor = WarmShelfPalette.paperHighlight.withAlpha(alpha)
        highlight.strokeColor = .clear
        highlight.position = CGPoint(x: x * s, y: y * s)
        highlight.zRotation = -0.22
        (parent ?? body).addChild(highlight)
    }

    private func buildMouse() {
        let gray = UIColor(hex: 0xA9A29B)
        let tail = SKShapeNode(path: {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -26 * s, y: 14 * s))
            p.addQuadCurve(to: CGPoint(x: -52 * s, y: 30 * s), control: CGPoint(x: -46 * s, y: 6 * s))
            return p
        }())
        tail.strokeColor = WarmShelfPalette.petal.withAlpha(0.9); tail.lineWidth = 4 * s; tail.lineCap = .round; tail.fillColor = .clear
        body.addChild(tail)
        for (ear, sign) in [(earLeft, CGFloat(-1)), (earRight, CGFloat(1))] {
            ear.position = CGPoint(x: sign * 12 * s, y: 26 * s); body.addChild(ear)
            let outer = SKShapeNode(circleOfRadius: 15 * s); outer.fillColor = gray.withAlpha(0.96); outer.strokeColor = .clear; ear.addChild(outer)
            let inner = SKShapeNode(circleOfRadius: 9 * s); inner.fillColor = WarmShelfPalette.petal.withAlpha(0.85); inner.strokeColor = .clear; ear.addChild(inner)
        }
        let blob = SKShapeNode(ellipseOf: CGSize(width: 56 * s, height: 46 * s))
        blob.fillColor = gray.withAlpha(0.96); blob.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.05); blob.lineWidth = 1
        blob.position = CGPoint(x: 0, y: 14 * s); body.addChild(blob)
        let snout = SKShapeNode(ellipseOf: CGSize(width: 30 * s, height: 26 * s)); snout.fillColor = gray.withAlpha(0.98); snout.strokeColor = .clear; snout.position = CGPoint(x: 22 * s, y: 10 * s); body.addChild(snout)
        let nose = SKShapeNode(circleOfRadius: 4 * s); nose.fillColor = WarmShelfPalette.petal; nose.strokeColor = .clear; nose.position = CGPoint(x: 37 * s, y: 8 * s); body.addChild(nose)
        eye(at: CGPoint(x: 14 * s, y: 18 * s), r: 8 * s)
        cheek(at: CGPoint(x: 24 * s, y: 8 * s), r: 4 * s)
        for sign in [CGFloat(-1), CGFloat(1)] {
            let foot = SKShapeNode(ellipseOf: CGSize(width: 12 * s, height: 7 * s)); foot.fillColor = WarmShelfPalette.petal.withAlpha(0.85); foot.strokeColor = .clear; foot.position = CGPoint(x: sign * 10 * s, y: -10 * s); body.addChild(foot)
            feet.append(foot); feetHome.append(foot.position)
        }
    }

    private func buildBear() {
        let clay = UIColor(hex: 0xA87655)
        let warmEdge = WarmShelfPalette.cocoa.withAlpha(0.07)
        let cream = WarmShelfPalette.sand.withAlpha(0.72)

        // Small ears first so the bean body overlaps them like real soft clay.
        for (ear, sign) in [(earLeft, CGFloat(-1)), (earRight, CGFloat(1))] {
            ear.position = CGPoint(x: sign * 16 * s, y: 35 * s); body.addChild(ear)
            let outer = SKShapeNode(ellipseOf: CGSize(width: 17 * s, height: 18 * s))
            outer.fillColor = clay.withAlpha(0.97)
            outer.strokeColor = .clear
            outer.zRotation = sign * 0.12
            ear.addChild(outer)

            let inner = SKShapeNode(ellipseOf: CGSize(width: 8 * s, height: 9 * s))
            inner.fillColor = WarmShelfPalette.petal.withAlpha(0.48)
            inner.strokeColor = .clear
            inner.position = CGPoint(x: 0, y: -1 * s)
            ear.addChild(inner)
        }

        let bodyPath = CGMutablePath()
        bodyPath.move(to: CGPoint(x: -25 * s, y: -21 * s))
        bodyPath.addCurve(to: CGPoint(x: -30 * s, y: 9 * s),
                          control1: CGPoint(x: -34 * s, y: -12 * s),
                          control2: CGPoint(x: -35 * s, y: 0))
        bodyPath.addCurve(to: CGPoint(x: -18 * s, y: 36 * s),
                          control1: CGPoint(x: -29 * s, y: 23 * s),
                          control2: CGPoint(x: -25 * s, y: 31 * s))
        bodyPath.addCurve(to: CGPoint(x: 2 * s, y: 43 * s),
                          control1: CGPoint(x: -10 * s, y: 43 * s),
                          control2: CGPoint(x: -4 * s, y: 43 * s))
        bodyPath.addCurve(to: CGPoint(x: 22 * s, y: 34 * s),
                          control1: CGPoint(x: 11 * s, y: 43 * s),
                          control2: CGPoint(x: 18 * s, y: 40 * s))
        bodyPath.addCurve(to: CGPoint(x: 30 * s, y: 6 * s),
                          control1: CGPoint(x: 31 * s, y: 23 * s),
                          control2: CGPoint(x: 35 * s, y: 12 * s))
        bodyPath.addCurve(to: CGPoint(x: 23 * s, y: -20 * s),
                          control1: CGPoint(x: 31 * s, y: -6 * s),
                          control2: CGPoint(x: 30 * s, y: -15 * s))
        bodyPath.addCurve(to: CGPoint(x: -25 * s, y: -21 * s),
                          control1: CGPoint(x: 12 * s, y: -28 * s),
                          control2: CGPoint(x: -13 * s, y: -28 * s))
        bodyPath.closeSubpath()

        let bean = SKShapeNode(path: bodyPath)
        bean.fillColor = clay.withAlpha(0.98)
        bean.strokeColor = warmEdge
        bean.lineWidth = 1
        body.addChild(bean)

        clayHighlight(x: -9, y: 24, width: 17, height: 8, alpha: 0.09)
        clayDimple(x: -14, y: 8, r: 1.2)
        clayDimple(x: 10, y: 31, r: 1.0)
        clayDimple(x: 17, y: -6, r: 1.1)

        let belly = SKShapeNode(ellipseOf: CGSize(width: 29 * s, height: 27 * s))
        belly.fillColor = cream
        belly.strokeColor = .clear
        belly.position = CGPoint(x: -1 * s, y: -3 * s)
        body.addChild(belly)

        let muzzle = SKShapeNode(ellipseOf: CGSize(width: 24 * s, height: 17 * s))
        muzzle.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.76)
        muzzle.strokeColor = .clear
        muzzle.position = CGPoint(x: 1 * s, y: 18 * s)
        body.addChild(muzzle)

        let nose = SKShapeNode(ellipseOf: CGSize(width: 8 * s, height: 5.8 * s))
        nose.fillColor = WarmShelfPalette.cocoa.withAlpha(0.84)
        nose.strokeColor = .clear
        nose.position = CGPoint(x: 1 * s, y: 22 * s)
        body.addChild(nose)

        let mouth = SKShapeNode(path: {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -4 * s, y: 16 * s))
            p.addQuadCurve(to: CGPoint(x: 5 * s, y: 16 * s), control: CGPoint(x: 1 * s, y: 12 * s))
            return p
        }())
        mouth.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.44)
        mouth.lineWidth = 1.4 * s
        mouth.lineCap = .round
        mouth.fillColor = .clear
        body.addChild(mouth)

        eye(at: CGPoint(x: -9 * s, y: 30 * s), r: 5.5 * s)
        eye(at: CGPoint(x: 11 * s, y: 30 * s), r: 5.5 * s)
        cheek(at: CGPoint(x: -15 * s, y: 22 * s), r: 4.6 * s)
        cheek(at: CGPoint(x: 17 * s, y: 22 * s), r: 4.6 * s)

        for sign in [CGFloat(-1), CGFloat(1)] {
            let arm = SKShapeNode(ellipseOf: CGSize(width: 11 * s, height: 17 * s))
            arm.fillColor = clay.withAlpha(0.94)
            arm.strokeColor = .clear
            arm.position = CGPoint(x: sign * 25 * s, y: 1 * s)
            arm.zRotation = sign * 0.18
            body.addChild(arm)
        }

        for sign in [CGFloat(-1), CGFloat(1)] {
            let paw = SKShapeNode(ellipseOf: CGSize(width: 15 * s, height: 9 * s))
            paw.fillColor = WarmShelfPalette.sand.withAlpha(0.55)
            paw.strokeColor = .clear
            paw.position = CGPoint(x: sign * 13 * s, y: -20 * s)
            body.addChild(paw)
            feet.append(paw); feetHome.append(paw.position)
        }
    }

    private func buildBird() {
        let feather = [WarmShelfPalette.waterBlue, WarmShelfPalette.butter, WarmShelfPalette.terracotta].randomElement()!
        let wingTint = feather == WarmShelfPalette.butter ? WarmShelfPalette.terracotta.withAlpha(0.22) : WarmShelfPalette.paperHighlight.withAlpha(0.18)

        for (x, y, rot) in [(-21 as CGFloat, 8 as CGFloat, -0.45 as CGFloat), (-20, 1, -0.18)] {
            let tail = SKShapeNode(ellipseOf: CGSize(width: 18 * s, height: 8 * s))
            tail.fillColor = feather.withAlpha(0.72)
            tail.strokeColor = .clear
            tail.position = CGPoint(x: x * s, y: y * s)
            tail.zRotation = rot
            body.addChild(tail)
        }

        for sign in [CGFloat(-1), CGFloat(1)] {
            let leg = SKShapeNode(rect: CGRect(x: -1.1 * s, y: -18 * s, width: 2.2 * s, height: 10 * s), cornerRadius: 1.1 * s)
            leg.fillColor = WarmShelfPalette.terracotta.withAlpha(0.68)
            leg.strokeColor = .clear
            leg.position = CGPoint(x: sign * 5 * s, y: 0)
            body.addChild(leg)
        }

        let bodyPath = CGMutablePath()
        bodyPath.move(to: CGPoint(x: -18 * s, y: -17 * s))
        bodyPath.addCurve(to: CGPoint(x: -20 * s, y: 17 * s),
                          control1: CGPoint(x: -27 * s, y: -6 * s),
                          control2: CGPoint(x: -28 * s, y: 8 * s))
        bodyPath.addCurve(to: CGPoint(x: 3 * s, y: 31 * s),
                          control1: CGPoint(x: -15 * s, y: 29 * s),
                          control2: CGPoint(x: -5 * s, y: 33 * s))
        bodyPath.addCurve(to: CGPoint(x: 25 * s, y: 12 * s),
                          control1: CGPoint(x: 16 * s, y: 30 * s),
                          control2: CGPoint(x: 25 * s, y: 24 * s))
        bodyPath.addCurve(to: CGPoint(x: 18 * s, y: -13 * s),
                          control1: CGPoint(x: 27 * s, y: 0),
                          control2: CGPoint(x: 25 * s, y: -8 * s))
        bodyPath.addCurve(to: CGPoint(x: -18 * s, y: -17 * s),
                          control1: CGPoint(x: 9 * s, y: -23 * s),
                          control2: CGPoint(x: -8 * s, y: -24 * s))
        bodyPath.closeSubpath()

        let torso = SKShapeNode(path: bodyPath)
        torso.fillColor = feather.withAlpha(0.97)
        torso.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.055)
        torso.lineWidth = 1
        body.addChild(torso)

        clayHighlight(x: -7, y: 18, width: 15, height: 7, alpha: 0.11)
        clayDimple(x: -9, y: 3, r: 0.9)
        clayDimple(x: 8, y: 24, r: 0.8)
        clayDimple(x: 14, y: -3, r: 0.8)

        let belly = SKShapeNode(ellipseOf: CGSize(width: 22 * s, height: 25 * s))
        belly.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.48)
        belly.strokeColor = .clear
        belly.position = CGPoint(x: 4 * s, y: 3 * s)
        body.addChild(belly)

        wingNode.position = CGPoint(x: -5 * s, y: 11 * s); body.addChild(wingNode)
        let wingPath = CGMutablePath()
        wingPath.move(to: CGPoint(x: 4 * s, y: 8 * s))
        wingPath.addCurve(to: CGPoint(x: -16 * s, y: 0),
                          control1: CGPoint(x: -3 * s, y: 7 * s),
                          control2: CGPoint(x: -12 * s, y: 5 * s))
        wingPath.addCurve(to: CGPoint(x: 2 * s, y: -9 * s),
                          control1: CGPoint(x: -13 * s, y: -8 * s),
                          control2: CGPoint(x: -4 * s, y: -11 * s))
        wingPath.addCurve(to: CGPoint(x: 4 * s, y: 8 * s),
                          control1: CGPoint(x: 8 * s, y: -3 * s),
                          control2: CGPoint(x: 9 * s, y: 3 * s))
        wingPath.closeSubpath()
        let wing = SKShapeNode(path: wingPath)
        wing.fillColor = wingTint
        wing.strokeColor = .clear
        wingNode.addChild(wing)

        for (x, h, rot) in [(-6 as CGFloat, 9 as CGFloat, -0.25 as CGFloat), (0, 11, 0), (6, 8, 0.22)] {
            let tuft = SKShapeNode(ellipseOf: CGSize(width: 5 * s, height: h * s))
            tuft.fillColor = feather.withAlpha(0.86)
            tuft.strokeColor = .clear
            tuft.position = CGPoint(x: x * s, y: 31 * s)
            tuft.zRotation = rot
            body.addChild(tuft)
        }

        let beak = SKShapeNode(path: {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 18 * s, y: 17 * s))
            p.addLine(to: CGPoint(x: 29 * s, y: 14 * s))
            p.addLine(to: CGPoint(x: 18 * s, y: 11 * s))
            p.closeSubpath()
            return p
        }())
        beak.fillColor = WarmShelfPalette.terracotta.withAlpha(0.95)
        beak.strokeColor = .clear
        body.addChild(beak)

        eye(at: CGPoint(x: 12 * s, y: 21 * s), r: 5.4 * s)
        cheek(at: CGPoint(x: 16 * s, y: 13 * s), r: 4.1 * s)

        for sign in [CGFloat(-1), CGFloat(1)] {
            let foot = SKShapeNode(ellipseOf: CGSize(width: 8 * s, height: 4 * s))
            foot.fillColor = WarmShelfPalette.terracotta.withAlpha(0.58)
            foot.strokeColor = .clear
            foot.position = CGPoint(x: sign * 6 * s, y: -18 * s)
            body.addChild(foot)
            feet.append(foot); feetHome.append(foot.position)
        }
    }

    // MARK: - Roaming

    func startRoaming(in rangeMinX: CGFloat, _ rangeMaxX: CGFloat) {
        self.rangeMinX = rangeMinX
        self.rangeMaxX = rangeMaxX
        guard !AmbientAnimator.reduceMotion else { return }
        scheduleNextMove()
        let idle = SKAction.sequence([.wait(forDuration: .random(in: 1.5...3.5)), .run { [weak self] in self?.idleTwitch() }])
        run(.repeatForever(idle), withKey: "idle")
    }

    /// Picked up by the child — pauses roaming, lifts, and the shadow shrinks away.
    func grab() {
        grabbed = true
        removeAction(forKey: "move")
        removeAction(forKey: "reactResume")
        stopGait()
        reacting = false
        run(.scale(to: 1.16, duration: 0.14), withKey: "grab")
        shadow?.run(.group([.fadeAlpha(to: 0.05, duration: 0.14), .scale(to: 0.7, duration: 0.14)]))
        idleTwitch()
    }

    /// Set down — settles with a soft squash and wanders again from where it landed.
    func release() {
        grabbed = false
        run(.scale(to: 1.0, duration: 0.16), withKey: "grab")
        shadow?.run(.group([.fadeAlpha(to: 0.13, duration: 0.2), .scale(to: 1.0, duration: 0.2)]))
        body.run(.sequence([.scaleX(to: lastDir * 1.06, y: 0.92, duration: 0.08), .scaleX(to: lastDir, y: 1.0, duration: 0.16)]))
        scheduleNextMove()
    }

    /// Smoothly turn to face the travel direction (only when it actually changes).
    private func faceTo(_ dir: CGFloat) {
        guard dir != lastDir else { return }
        lastDir = dir
        let flip = SKAction.scaleX(to: dir, y: 1, duration: 0.2)
        flip.timingMode = .easeInEaseOut
        body.run(flip, withKey: "face")
    }

    /// A smooth whole-body waddle: a gentle bob paired with a slight lean into each
    /// step (like Pok Pok creatures). No articulated legs — that's what read as janky.
    /// `gaitNode` carries the waddle so it never fights the directional flip on `body`.
    private func startGait(stepDur: TimeInterval) {
        guard !AmbientAnimator.reduceMotion, gaitNode.action(forKey: "gait") == nil else { return }
        let amt = (kind == .bear ? 2.2 : 3.0) * s
        let lean: CGFloat = kind == .bear ? 0.035 : 0.055
        let up = SKAction.moveBy(x: 0, y: amt, duration: stepDur); up.timingMode = .easeInEaseOut
        let down = SKAction.moveBy(x: 0, y: -amt, duration: stepDur); down.timingMode = .easeInEaseOut
        let leanR = SKAction.rotate(toAngle: -lean, duration: stepDur); leanR.timingMode = .easeInEaseOut
        let leanL = SKAction.rotate(toAngle: lean, duration: stepDur); leanL.timingMode = .easeInEaseOut
        gaitNode.run(.repeatForever(.sequence([.group([up, leanR]), .group([down, leanL])])), withKey: "gait")
    }

    private func stopGait() {
        gaitNode.removeAction(forKey: "gait")
        let settle = SKAction.group([.moveTo(y: 0, duration: 0.22), .rotate(toAngle: 0, duration: 0.22)])
        settle.timingMode = .easeInEaseOut
        gaitNode.run(settle)
    }

    private func scheduleNextMove() {
        guard !AmbientAnimator.reduceMotion, !reacting, !grabbed else { return }
        let target = CGFloat.random(in: rangeMinX...rangeMaxX)
        let dir: CGFloat = target >= position.x ? 1 : -1
        faceTo(dir)
        // Longer rests between wanders — the garden should feel still and quiet, not busy.
        let pause = TimeInterval.random(in: kind == .bear ? 3.0...6.0 : 2.0...4.5)

        if kind == .bird {
            hopTowards(target, pause: pause)
            return
        }

        // Walkers: smooth horizontal glide on the node + a real step cadence on the body.
        let speed: CGFloat = (kind == .bear ? 58 : 96) * s
        let stepLength: CGFloat = (kind == .bear ? 30 : 24) * s
        let stepDur = TimeInterval(max(0.18, stepLength / speed))
        let dur = TimeInterval(max(0.5, abs(target - position.x) / speed))
        startGait(stepDur: stepDur)
        let move = SKAction.moveTo(x: target, duration: dur)
        move.timingMode = .easeInEaseOut
        run(.sequence([
            move,
            .run { [weak self] in self?.stopGait() },
            .wait(forDuration: pause),
            .run { [weak self] in self?.scheduleNextMove() }
        ]), withKey: "move")
    }

    /// Bird hops: horizontal travel on the node, the arc + flutter on the body, so the
    /// shadow stays planted while the bird lifts off and lands.
    private func hopTowards(_ target: CGFloat, pause: TimeInterval) {
        let steps = max(1, Int(abs(target - position.x) / (34 * s)))
        let stepX = (target - position.x) / CGFloat(steps)
        let stepDur = 0.34
        var horizontal: [SKAction] = []
        var vertical: [SKAction] = []
        for _ in 0..<steps {
            let glide = SKAction.moveBy(x: stepX, y: 0, duration: stepDur)
            glide.timingMode = .easeInEaseOut
            horizontal.append(glide)
            let up = SKAction.moveBy(x: 0, y: 22 * s, duration: stepDur * 0.5); up.timingMode = .easeOut
            let down = SKAction.moveBy(x: 0, y: -22 * s, duration: stepDur * 0.5); down.timingMode = .easeIn
            vertical.append(.sequence([.run { [weak self] in self?.flutterWings() }, up, down]))
        }
        body.run(.sequence(vertical))
        run(.sequence([
            .sequence(horizontal),
            .wait(forDuration: pause),
            .run { [weak self] in self?.scheduleNextMove() }
        ]), withKey: "move")
    }

    private func idleTwitch() {
        switch kind {
        case .mouse, .bear:
            let wiggle = SKAction.sequence([.rotate(byAngle: 0.16, duration: 0.1), .rotate(byAngle: -0.16, duration: 0.12)])
            earLeft.run(wiggle); earRight.run(.sequence([.wait(forDuration: 0.05), wiggle]))
        case .bird:
            flutterWings()
        }
    }

    private func flutterWings() {
        wingNode.run(.sequence([.scaleX(to: 0.4, y: 1, duration: 0.1), .scaleX(to: 1, y: 1, duration: 0.12)]))
    }

    /// The payoff a toddler taps for: a big, unmistakable "you touched me!" beat — a crouch of
    /// anticipation, a joyful leap with a squash landing, and a kind-specific flourish on top.
    /// The old reaction was a small hop that fell short in playtests; this one clearly delights.
    func react() {
        guard !reacting else {
            // Mid-celebration — rapid taps still get an extra happy bounce + flourish.
            body.run(.sequence([.scaleY(to: 1.12, duration: 0.08), .scaleY(to: 1.0, duration: 0.14)]))
            kindFlourish()
            return
        }
        reacting = true
        removeAction(forKey: "move")
        removeAction(forKey: "reactResume")
        stopGait()

        let lift = 32 * s
        let crouch = SKAction.scaleY(to: 0.86, duration: 0.09); crouch.timingMode = .easeOut   // anticipation
        let up = SKAction.group([
            .moveBy(x: 0, y: lift, duration: 0.18),
            .scaleY(to: 1.12, duration: 0.18)
        ]); up.timingMode = .easeOut
        let down = SKAction.moveBy(x: 0, y: -lift, duration: 0.20); down.timingMode = .easeIn
        let land = SKAction.sequence([
            .scaleY(to: 0.9, duration: 0.06),
            .scaleY(to: 1.0, duration: 0.18)
        ])
        body.run(.sequence([crouch, up, down, land]), withKey: "react")

        // A warm whole-body squash-and-grow so the joy reads even at a glance.
        run(.sequence([.scale(to: 1.16, duration: 0.16), .scale(to: 1.0, duration: 0.24)]), withKey: "reactScale")

        kindFlourish()
        run(.sequence([.wait(forDuration: 1.3), .run { [weak self] in
            self?.reacting = false
            self?.scheduleNextMove()
        }]), withKey: "reactResume")
    }

    /// Each critter celebrates in its own voice — the silly specificity is the charm.
    private func kindFlourish() {
        switch kind {
        case .mouse:
            // an excited little shimmy + ear wiggle
            body.run(.sequence([
                .rotate(toAngle: 0.16, duration: 0.06), .rotate(toAngle: -0.16, duration: 0.08),
                .rotate(toAngle: 0.10, duration: 0.06), .rotate(toAngle: 0, duration: 0.08)
            ]), withKey: "flourish")
            idleTwitch()
        case .bear:
            // a happy, heavy waddle-sway
            body.run(.sequence([
                .rotate(toAngle: 0.12, duration: 0.12), .rotate(toAngle: -0.12, duration: 0.16),
                .rotate(toAngle: 0.06, duration: 0.10), .rotate(toAngle: 0, duration: 0.12)
            ]), withKey: "flourish")
            idleTwitch()
        case .bird:
            // an excited double flutter
            flutterWings()
            run(.sequence([.wait(forDuration: 0.14), .run { [weak self] in self?.flutterWings() }]))
        }
    }
}
