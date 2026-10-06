import SpriteKit

final class HumObjectNode: SKNode {

    enum ObjectKind {
        case blob    // terracotta, felt voice, middle register
        case column  // waterBlue, breath voice, high register
        case disc    // sage, clay voice, low register
        case pebble  // butter, water voice, short decay
        case bar     // tuned clay xylophone bar — the instrument's voice
    }

    let kind: ObjectKind
    let pitchIndex: Int
    let objectColor: UIColor
    var homePosition: CGPoint = .zero
    private(set) var isHeld = false

    private let sizeRoot = SKNode()   // static size multiplier — kept clear of all animations
    private let artRoot = SKNode()
    private let faceRoot = SKNode()
    private let bodyNode: SKShapeNode
    private let shadowNode: SKSpriteNode
    private(set) var glowNode: SKShapeNode
    private var sleepyEyes: [SKShapeNode] = []
    private var openEyes: [SKNode] = []
    private var pupils: [SKShapeNode] = []
    private var mouthRest: SKShapeNode?
    private var mouthOpen: SKShapeNode?

    private let breatheKey: String
    private let idleKey: String
    private let sighKey = "hum.sigh"
    private let shimmerKey = "hum.shimmer"
    private let bodyPulseKey = "hum.bodyPulse"
    private let glowPulseKey = "hum.glowPulse"

    init(kind: ObjectKind, pitchIndex: Int, sizeScale: CGFloat = 1.0, tint: UIColor? = nil) {
        self.kind = kind
        self.pitchIndex = pitchIndex
        let (color, body, glowR) = Self.buildBody(kind: kind, tint: tint)
        let shadowSpec = Self.shadowSpec(kind: kind)
        self.objectColor = color
        self.bodyNode = body
        let shadow = SKSpriteNode(texture: ProceduralTexture.softClayShadow(size: shadowSpec.size))
        shadow.size = shadowSpec.size
        shadow.position = shadowSpec.position
        shadow.zPosition = -3
        self.shadowNode = shadow
        self.breatheKey = "hum.\(kind).rest"
        self.idleKey = "hum.\(kind).idle"

        let glow = SKShapeNode(circleOfRadius: glowR)
        glow.fillColor = color.withAlpha(0.18)
        glow.strokeColor = .clear
        glow.alpha = 0
        self.glowNode = glow

        super.init()
        isUserInteractionEnabled = false
        // sizeRoot carries the static size; self/artRoot/body keep animating around scale 1.
        sizeRoot.setScale(sizeScale)
        addChild(sizeRoot)
        sizeRoot.addChild(shadowNode)
        sizeRoot.addChild(glowNode)
        sizeRoot.addChild(artRoot)
        artRoot.addChild(bodyNode)
        buildFace()
        startResting()
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    // MARK: - Shape construction

    private static func buildBody(kind: ObjectKind, tint: UIColor?) -> (UIColor, SKShapeNode, CGFloat) {
        switch kind {
        case .blob:
            let color = WarmShelfPalette.terracotta
            let node = SKShapeNode(ellipseOf: CGSize(width: 72, height: 62))
            node.fillColor = color
            node.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.07)
            node.lineWidth = 1.5
            ProceduralTexture.applyClayFill(to: node, base: color, size: CGSize(width: 72, height: 62))
            decorateEllipse(node, size: CGSize(width: 72, height: 62), speckles: 4)
            return (color, node, 48)

        case .column:
            let color = WarmShelfPalette.waterBlue
            let rect = CGRect(x: -19, y: -44, width: 38, height: 88)
            let node = SKShapeNode(rect: rect, cornerRadius: 15)
            node.fillColor = color
            node.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.07)
            node.lineWidth = 1.5
            ProceduralTexture.applyClayFill(to: node, base: color, size: rect.size)
            ProceduralTexture.addMatteClayDepth(to: node, in: rect, cornerRadius: 15, zPosition: 0.1, highlightAlpha: 0.23, shadeAlpha: 0.050, rimAlpha: 0.035, speckleCount: 4)
            return (color, node, 38)

        case .disc:
            let color = WarmShelfPalette.sage
            let node = SKShapeNode(ellipseOf: CGSize(width: 90, height: 36))
            node.fillColor = color
            node.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.07)
            node.lineWidth = 1.5
            ProceduralTexture.applyClayFill(to: node, base: color, size: CGSize(width: 90, height: 36))
            decorateEllipse(node, size: CGSize(width: 90, height: 36), speckles: 4)
            return (color, node, 52)

        case .pebble:
            let color = WarmShelfPalette.butter
            let node = makePebble(color: color)
            return (color, node, 30)

        case .bar:
            let color = tint ?? WarmShelfPalette.terracotta
            let rect = CGRect(x: -23, y: -75, width: 46, height: 150)
            let node = SKShapeNode(rect: rect, cornerRadius: 18)
            node.fillColor = color
            node.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.08)
            node.lineWidth = 1.5
            ProceduralTexture.applyClayFill(to: node, base: color, size: rect.size)
            ProceduralTexture.addMatteClayDepth(to: node, in: rect, cornerRadius: 18, zPosition: 0.1, highlightAlpha: 0.22, shadeAlpha: 0.05, rimAlpha: 0.035, speckleCount: 4)
            return (color, node, 56)
        }
    }

    /// When an authored frame holds the bars, their individual contact shadows stack
    /// into a smudge over the art — the frame's own grounding does the work instead.
    func setShadowStrength(_ strength: CGFloat) {
        shadowNode.alpha = strength
    }

    private static func shadowSpec(kind: ObjectKind) -> (size: CGSize, position: CGPoint) {
        switch kind {
        case .blob:
            return (CGSize(width: 82, height: 20), CGPoint(x: 3, y: -36))
        case .column:
            return (CGSize(width: 56, height: 20), CGPoint(x: 2, y: -48))
        case .disc:
            return (CGSize(width: 92, height: 18), CGPoint(x: 2, y: -24))
        case .pebble:
            return (CGSize(width: 48, height: 15), CGPoint(x: 2, y: -27))
        case .bar:
            return (CGSize(width: 54, height: 16), CGPoint(x: 2, y: -82))
        }
    }

    private static func decorateEllipse(_ node: SKShapeNode, size: CGSize, speckles: Int) {
        ProceduralTexture.addMatteClayDepth(
            to: node,
            ellipse: size,
            zPosition: 0.1,
            highlightAlpha: 0.25,
            shadeAlpha: 0.050,
            rimAlpha: 0.035,
            speckleCount: speckles
        )
    }

    private static func makePebble(color: UIColor) -> SKShapeNode {
        let size: CGFloat = 36
        // Pre-defined irregular pebble shape using 8 control points
        let angles: [CGFloat] = [0, 0.82, 1.65, 2.44, 3.28, 4.08, 4.94, 5.76]
        let radii: [CGFloat]  = [1.00, 0.82, 0.94, 0.76, 0.88, 1.00, 0.80, 0.90]
        let verts: [CGPoint] = zip(angles, radii).map { (a, r) in
            CGPoint(x: cos(a) * size * r * 0.90, y: sin(a) * size * r * 0.74)
        }
        let n = verts.count
        let path = CGMutablePath()
        // Smooth catmull-style: move to midpoints, curve through each vertex
        let start = CGPoint(x: (verts[n-1].x + verts[0].x) / 2,
                            y: (verts[n-1].y + verts[0].y) / 2)
        path.move(to: start)
        for i in 0..<n {
            let curr = verts[i]
            let next = verts[(i + 1) % n]
            let mid  = CGPoint(x: (curr.x + next.x) / 2, y: (curr.y + next.y) / 2)
            path.addQuadCurve(to: mid, control: curr)
        }
        path.closeSubpath()

        let node = SKShapeNode(path: path)
        node.fillColor = color
        node.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.07)
        node.lineWidth = 1.5

        ProceduralTexture.applyClayFill(to: node, base: color, size: CGSize(width: size * 1.7, height: size * 1.4))
        ProceduralTexture.addMatteClayDepth(
            to: node,
            ellipse: CGSize(width: size * 1.62, height: size * 1.20),
            zPosition: 0.1,
            highlightAlpha: 0.28,
            shadeAlpha: 0.050,
            rimAlpha: 0.034,
            speckleCount: 3
        )
        return node
    }

    // MARK: - Face

    private func buildFace() {
        faceRoot.zPosition = 8
        bodyNode.addChild(faceRoot)

        let eyeY: CGFloat
        let eyeGap: CGFloat
        switch kind {
        case .blob:
            eyeY = 5; eyeGap = 15
        case .column:
            eyeY = 13; eyeGap = 11
        case .disc:
            eyeY = 0; eyeGap = 18
        case .pebble:
            eyeY = 3; eyeGap = 11
        case .bar:
            eyeY = 40; eyeGap = 11
        }

        for side in [-1.0, 1.0] {
            let x = CGFloat(side) * eyeGap
            let sleepyPath = CGMutablePath()
            sleepyPath.move(to: CGPoint(x: -6, y: 0))
            sleepyPath.addQuadCurve(to: CGPoint(x: 6, y: 0), control: CGPoint(x: 0, y: -4.2))
            let sleepy = SKShapeNode(path: sleepyPath)
            sleepy.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.42)
            sleepy.lineWidth = 2.2
            sleepy.lineCap = .round
            sleepy.fillColor = .clear
            sleepy.position = CGPoint(x: x, y: eyeY)
            sleepyEyes.append(sleepy)
            faceRoot.addChild(sleepy)

            let eye = SKNode()
            eye.position = CGPoint(x: x, y: eyeY)
            eye.setScale(0.01)
            eye.alpha = 0

            let white = SKShapeNode(ellipseOf: CGSize(width: 10.5, height: 12.5))
            white.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.94)
            white.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.10)
            white.lineWidth = 0.8
            eye.addChild(white)

            let pupil = SKShapeNode(circleOfRadius: 3.1)
            pupil.fillColor = WarmShelfPalette.cocoa.withAlpha(0.82)
            pupil.strokeColor = .clear
            pupil.position = CGPoint(x: 0.7 * CGFloat(side), y: -0.5)
            eye.addChild(pupil)
            pupils.append(pupil)

            let glint = SKShapeNode(circleOfRadius: 0.95)
            glint.fillColor = .white.withAlpha(0.78)
            glint.strokeColor = .clear
            glint.position = CGPoint(x: -1.4, y: 1.7)
            eye.addChild(glint)

            openEyes.append(eye)
            faceRoot.addChild(eye)
        }

        let mouthY: CGFloat
        let mouthWidth: CGFloat
        switch kind {
        case .blob:
            mouthY = -12; mouthWidth = 15
        case .column:
            mouthY = -5; mouthWidth = 11
        case .disc:
            mouthY = -9; mouthWidth = 17
        case .pebble:
            mouthY = -8; mouthWidth = 10
        case .bar:
            mouthY = 20; mouthWidth = 13
        }

        let mouthPath = CGMutablePath()
        mouthPath.move(to: CGPoint(x: -mouthWidth * 0.5, y: 0))
        mouthPath.addQuadCurve(to: CGPoint(x: mouthWidth * 0.5, y: 0),
                               control: CGPoint(x: 0, y: -mouthWidth * 0.18))
        let restingMouth = SKShapeNode(path: mouthPath)
        restingMouth.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.36)
        restingMouth.lineWidth = 2.0
        restingMouth.lineCap = .round
        restingMouth.fillColor = .clear
        restingMouth.position = CGPoint(x: 0, y: mouthY)
        mouthRest = restingMouth
        faceRoot.addChild(restingMouth)

        let singingMouth = SKShapeNode(ellipseOf: CGSize(width: mouthWidth * 0.62, height: mouthWidth * 0.50))
        singingMouth.fillColor = WarmShelfPalette.cocoa.withAlpha(0.62)
        singingMouth.strokeColor = WarmShelfPalette.paperHighlight.withAlpha(0.18)
        singingMouth.lineWidth = 0.8
        singingMouth.position = CGPoint(x: 0, y: mouthY - 0.5)
        singingMouth.setScale(0.12)
        singingMouth.alpha = 0
        mouthOpen = singingMouth
        faceRoot.addChild(singingMouth)
    }

    private func showEyes(open: Bool, duration: TimeInterval) {
        let duration = AmbientAnimator.reduceMotion ? 0 : duration
        for eye in sleepyEyes {
            eye.removeAction(forKey: "hum.eye.sleepy")
            eye.run(.fadeAlpha(to: open ? 0 : 1, duration: duration), withKey: "hum.eye.sleepy")
        }
        for eye in openEyes {
            eye.removeAction(forKey: "hum.eye.open")
            let scale = SKAction.scaleY(to: open ? 1 : 0.01, duration: duration)
            scale.timingMode = open ? .easeOut : .easeInEaseOut
            let fade = SKAction.fadeAlpha(to: open ? 1 : 0, duration: duration)
            eye.run(.group([scale, fade]), withKey: "hum.eye.open")
        }
        if open {
            runPupilNotice()
        } else {
            pupils.forEach { $0.removeAction(forKey: "hum.pupil") }
        }
    }

    private func showMouth(singing: Bool, duration: TimeInterval) {
        let duration = AmbientAnimator.reduceMotion ? 0 : duration
        mouthRest?.removeAction(forKey: "hum.mouth.rest")
        mouthOpen?.removeAction(forKey: "hum.mouth.open")
        mouthRest?.run(.fadeAlpha(to: singing ? 0 : 1, duration: duration), withKey: "hum.mouth.rest")
        let openScale = SKAction.scale(to: singing ? 1 : 0.12, duration: duration)
        openScale.timingMode = singing ? .easeOut : .easeInEaseOut
        let openFade = SKAction.fadeAlpha(to: singing ? 1 : 0, duration: duration)
        mouthOpen?.run(.group([openScale, openFade]), withKey: "hum.mouth.open")
    }

    private func runPupilNotice() {
        for pupil in pupils {
            pupil.removeAction(forKey: "hum.pupil")
            let dilate = SKAction.scale(to: 1.22, duration: 0.16)
            let settle = SKAction.scale(to: 1.0, duration: 0.64)
            dilate.timingMode = .easeOut
            settle.timingMode = .easeInEaseOut
            pupil.run(.sequence([dilate, settle]), withKey: "hum.pupil")
        }
    }

    // MARK: - Ambient breathing

    private func startResting() {
        guard !AmbientAnimator.reduceMotion else { return }
        removeAction(forKey: breatheKey)
        artRoot.removeAction(forKey: idleKey)
        let dur = Double.random(in: 4.0...6.0)
        let up = SKAction.scale(to: 1.015, duration: dur * 0.5)
        let dn = SKAction.scale(to: 1.000, duration: dur * 0.5)
        up.timingMode = .easeInEaseOut
        dn.timingMode = .easeInEaseOut
        let delay = Double.random(in: 0...1.3)
        run(.sequence([.wait(forDuration: delay),
                       .repeatForever(.sequence([up, dn]))]), withKey: breatheKey)
        startIdlePersonality(after: delay + 0.2)
    }

    private func startIdlePersonality(after delay: TimeInterval = 0) {
        guard !AmbientAnimator.reduceMotion else { return }
        artRoot.removeAction(forKey: idleKey)
        let wait = SKAction.wait(forDuration: delay)
        let idle: SKAction
        switch kind {
        case .blob:
            let left = SKAction.scaleX(to: 1.026, y: 0.986, duration: 1.0)
            let right = SKAction.scaleX(to: 0.986, y: 1.018, duration: 1.05)
            let rest = SKAction.scale(to: 1.0, duration: 0.85)
            left.timingMode = .easeInEaseOut
            right.timingMode = .easeInEaseOut
            rest.timingMode = .easeInEaseOut
            idle = .repeatForever(.sequence([left, right, rest, .wait(forDuration: 1.9)]))
        case .column:
            let lean = SKAction.rotate(toAngle: -0.035, duration: 1.05)
            let other = SKAction.rotate(toAngle: 0.028, duration: 1.2)
            let center = SKAction.rotate(toAngle: 0, duration: 0.9)
            lean.timingMode = .easeInEaseOut
            other.timingMode = .easeInEaseOut
            center.timingMode = .easeInEaseOut
            idle = .repeatForever(.sequence([lean, other, center, .wait(forDuration: 2.2)]))
        case .disc:
            let up = SKAction.moveBy(x: 0, y: 2.8, duration: 0.9)
            let down = SKAction.moveBy(x: 0, y: -2.8, duration: 1.1)
            up.timingMode = .easeOut
            down.timingMode = .easeInEaseOut
            idle = .repeatForever(.sequence([up, down, .wait(forDuration: 2.4)]))
        case .pebble:
            let turn = SKAction.rotate(byAngle: 0.11, duration: 1.0)
            let back = SKAction.rotate(byAngle: -0.11, duration: 1.15)
            turn.timingMode = .easeInEaseOut
            back.timingMode = .easeInEaseOut
            idle = .repeatForever(.sequence([turn, back, .wait(forDuration: 2.1)]))
        case .bar:
            // A sleepy clay bar breathes gently at the top, bottom planted on the rail.
            let up = SKAction.scaleY(to: 1.012, duration: 1.1)
            let dn = SKAction.scaleY(to: 1.0, duration: 1.2)
            up.timingMode = .easeInEaseOut
            dn.timingMode = .easeInEaseOut
            idle = .repeatForever(.sequence([up, dn, .wait(forDuration: 2.0)]))
        }
        artRoot.run(.sequence([wait, idle]), withKey: idleKey)
    }

    // MARK: - Touch states

    func noticeAndHold() {
        isHeld = true
        removeAction(forKey: breatheKey)
        removeAction(forKey: sighKey)
        artRoot.removeAction(forKey: idleKey)
        removeAction(forKey: "returnHome")
        showEyes(open: true, duration: 0.18)
        showMouth(singing: true, duration: 0.16)

        let fadeIn = SKAction.fadeAlpha(to: 1, duration: 0.18)
        fadeIn.timingMode = .easeOut
        glowNode.run(fadeIn)

        if kind == .bar {
            // A real key press: the bar dips into the rail and the clay squashes, then is held
            // compressed — quick to press in (the asymmetry law). Springs back in settleHome.
            let dip = SKAction.move(to: CGPoint(x: homePosition.x, y: homePosition.y - 12), duration: 0.08)
            dip.timingMode = .easeOut
            run(dip, withKey: "hum.hold")
            let squash = SKAction.group([
                .scaleY(to: 0.90, duration: 0.08),
                .scaleX(to: 1.06, duration: 0.08)
            ])
            squash.timingMode = .easeOut
            artRoot.run(squash, withKey: idleKey)
        } else {
            artRoot.run(SKAction.group([
                .move(to: .zero, duration: 0.12),
                .rotate(toAngle: 0, duration: 0.12),
                .scale(to: 1.0, duration: 0.12)
            ]))
            let up = SKAction.scale(to: 1.08, duration: 0.12)
            up.timingMode = .easeOut
            run(up, withKey: "hum.hold")
        }
    }

    func settleHome() {
        isHeld = false
        stopShimmer()
        showEyes(open: false, duration: 0.34)
        showMouth(singing: false, duration: 0.42)

        let fadeOut = SKAction.fadeAlpha(to: 0, duration: 1.2)
        fadeOut.timingMode = .easeInEaseOut
        glowNode.run(fadeOut)

        if kind == .bar {
            // Spring the key back up — slower than the press, with a cute little overshoot bob.
            let up = SKAction.move(to: homePosition, duration: 0.26)
            up.timingMode = .easeOut
            run(up, withKey: "returnHome")
            let unsquash = SKAction.group([
                .scaleY(to: 1.0, duration: 0.22),
                .scaleX(to: 1.0, duration: 0.22)
            ])
            unsquash.timingMode = .easeOut
            let bob = SKAction.sequence([
                .scaleY(to: 1.04, duration: 0.10),
                .scaleY(to: 1.0, duration: 0.16)
            ])
            artRoot.run(.sequence([unsquash, bob]), withKey: idleKey)
            run(.sequence([.wait(forDuration: 0.5), .run { [weak self] in self?.startResting() }]))
            return
        }

        playLittleSigh()

        let settle = SKAction.scale(to: 1.0, duration: 0.95)
        settle.timingMode = .easeInEaseOut
        run(settle, withKey: "hum.hold")

        let drift = SKAction.move(to: homePosition, duration: 2.2)
        drift.timingMode = .easeInEaseOut
        run(drift, withKey: "returnHome")

        run(.sequence([.wait(forDuration: 1.0), .run { [weak self] in
            self?.startResting()
        }]))
    }

    func playSoundPulse(intensity: CGFloat = 1.0) {
        guard !AmbientAnimator.reduceMotion else { return }
        bodyNode.removeAction(forKey: bodyPulseKey)
        glowNode.removeAction(forKey: glowPulseKey)

        let bodyUp = SKAction.scale(to: 1.0 + 0.045 * intensity, duration: 0.12)
        let bodyDown = SKAction.scale(to: 1.0, duration: 0.38)
        bodyUp.timingMode = .easeOut
        bodyDown.timingMode = .easeInEaseOut
        bodyNode.run(.sequence([bodyUp, bodyDown]), withKey: bodyPulseKey)

        let glowUp = SKAction.group([
            .scale(to: 1.0 + 0.16 * intensity, duration: 0.18),
            .fadeAlpha(to: min(1.0, 0.72 + 0.12 * intensity), duration: 0.18)
        ])
        let glowDown = SKAction.group([
            .scale(to: 1.0, duration: 0.62),
            .fadeAlpha(to: isHeld ? 1.0 : 0.0, duration: 0.62)
        ])
        glowUp.timingMode = .easeOut
        glowDown.timingMode = .easeInEaseOut
        glowNode.run(.sequence([glowUp, glowDown]), withKey: glowPulseKey)
    }

    func playDuetPulse() {
        playSoundPulse(intensity: 1.24)
        guard !AmbientAnimator.reduceMotion else { return }
        mouthOpen?.removeAction(forKey: "hum.mouth.duet")
        let widen = SKAction.scaleX(to: 1.18, y: 0.82, duration: 0.13)
        let round = SKAction.scale(to: 1.0, duration: 0.36)
        widen.timingMode = .easeOut
        round.timingMode = .easeInEaseOut
        mouthOpen?.run(.sequence([widen, round]), withKey: "hum.mouth.duet")
    }

    func playChoirPulse(delay: TimeInterval) {
        run(.sequence([.wait(forDuration: delay), .run { [weak self] in
            self?.playSoundPulse(intensity: 1.42)
            guard !AmbientAnimator.reduceMotion else { return }
            let lift = SKAction.moveBy(x: 0, y: 8, duration: 0.16)
            let settle = SKAction.moveBy(x: 0, y: -8, duration: 0.52)
            lift.timingMode = .easeOut
            settle.timingMode = .easeInEaseOut
            self?.bodyNode.run(.sequence([lift, settle]), withKey: "hum.choirLift")
        }]))
    }

    func playInvitePreview(after delay: TimeInterval = 0) {
        guard !AmbientAnimator.reduceMotion else { return }
        run(.sequence([
            .wait(forDuration: delay),
            .run { [weak self] in
                guard let self, !self.isHeld else { return }
                self.showEyes(open: true, duration: 0.18)
                self.showMouth(singing: true, duration: 0.16)
                self.playSoundPulse(intensity: 1.05)
            },
            .wait(forDuration: 0.72),
            .run { [weak self] in
                guard let self, !self.isHeld else { return }
                self.showEyes(open: false, duration: 0.34)
                self.showMouth(singing: false, duration: 0.42)
            }
        ]), withKey: "hum.invitePreview")
    }

    /// A bright, brief pluck when a strum finger sweeps past: eyes open, a little hop,
    /// a sound pulse, then it eases back to rest (it is not held).
    func strum() {
        guard !isHeld else { return }
        removeAction(forKey: "hum.strumReset")
        showEyes(open: true, duration: 0.10)
        showMouth(singing: true, duration: 0.10)
        playSoundPulse(intensity: 1.18)
        if !AmbientAnimator.reduceMotion {
            let hop = SKAction.sequence([
                .moveBy(x: 0, y: 7, duration: 0.08),
                .moveBy(x: 0, y: -7, duration: 0.18)
            ])
            hop.timingMode = .easeOut
            artRoot.run(hop, withKey: "hum.strumHop")
        }
        run(.sequence([
            .wait(forDuration: 0.55),
            .run { [weak self] in
                guard let self, !self.isHeld else { return }
                self.showEyes(open: false, duration: 0.32)
                self.showMouth(singing: false, duration: 0.36)
            }
        ]), withKey: "hum.strumReset")
    }

    func peekToward(_ point: CGPoint) {
        guard !isHeld, !AmbientAnimator.reduceMotion else { return }
        let rawDx = point.x - position.x
        let rawDy = point.y - position.y
        let dx = min(max(rawDx, -18), 18) * 0.18
        let dy = min(max(rawDy, -18), 18) * 0.18
        showEyes(open: true, duration: 0.14)
        let lean = SKAction.group([
            .moveBy(x: dx, y: dy, duration: 0.16),
            .rotate(byAngle: dx * 0.006, duration: 0.16)
        ])
        let back = SKAction.group([
            .moveBy(x: -dx, y: -dy, duration: 0.62),
            .rotate(byAngle: -dx * 0.006, duration: 0.62)
        ])
        lean.timingMode = .easeOut
        back.timingMode = .easeInEaseOut
        artRoot.run(.sequence([lean, back, .run { [weak self] in
            guard let self, !self.isHeld else { return }
            self.showEyes(open: false, duration: 0.30)
        }]), withKey: "hum.peek")
    }

    private func playLittleSigh() {
        guard !AmbientAnimator.reduceMotion else { return }
        removeAction(forKey: sighKey)
        let sink = SKAction.moveBy(x: 0, y: -4.5, duration: 0.28)
        let soften = SKAction.scaleX(to: 1.035, y: 0.965, duration: 0.28)
        let lift = SKAction.moveBy(x: 0, y: 4.5, duration: 0.72)
        let round = SKAction.scale(to: 1.0, duration: 0.72)
        sink.timingMode = .easeOut
        soften.timingMode = .easeOut
        lift.timingMode = .easeInEaseOut
        round.timingMode = .easeInEaseOut
        artRoot.run(.sequence([
            .group([sink, soften]),
            .group([lift, round])
        ]), withKey: sighKey)
    }

    func startShimmer() {
        if !isHeld {
            showEyes(open: true, duration: 0.16)
            showMouth(singing: true, duration: 0.16)
        }
        guard artRoot.action(forKey: shimmerKey) == nil else { return }
        let up = SKAction.scale(to: 1.03, duration: 0.4)
        let dn = SKAction.scale(to: 1.00, duration: 0.4)
        up.timingMode = .easeInEaseOut
        dn.timingMode = .easeInEaseOut
        artRoot.run(.repeatForever(.sequence([up, dn])), withKey: shimmerKey)
    }

    func stopShimmer() {
        artRoot.removeAction(forKey: shimmerKey)
        if !isHeld {
            showEyes(open: false, duration: 0.30)
            showMouth(singing: false, duration: 0.38)
        }
        let reset = SKAction.scale(to: 1.0, duration: 0.26)
        reset.timingMode = .easeInEaseOut
        artRoot.run(reset, withKey: shimmerKey)
    }

    // MARK: - Tone helpers

    var toneVoice: LullToneEngine.Voice {
        switch kind {
        case .blob:   return .felt
        case .column: return .breath
        case .disc:   return .clay
        case .pebble: return .water
        case .bar:    return .marimba
        }
    }

    var toneDecay: Double { kind == .pebble ? 0.8 : 1.8 }
}
