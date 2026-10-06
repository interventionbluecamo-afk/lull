import SpriteKit
import QuartzCore

// MARK: - Base

/// A handmade wooden/clay control on the Glowboard. Lives at scene level (not nested in a
/// scaled board) so touch maths stays simple, and exposes a generous invisible hit area plus
/// a quick-press / slow-release tactile response. Subclasses add their own behaviour and
/// report value changes through closures — the scene owns all sound and haptics so restraint
/// stays in one place.
class GlowControlNode: SKNode {
    /// The visible, deformable part. Pressing scales this; the hit area stays put.
    let art = SKNode()
    /// Generous, forgiving invisible target — bigger than the art, for small hands.
    var hitSize = CGSize(width: 96, height: 96)

    var onPressDown: (() -> Void)?
    var onPressUp: (() -> Void)?

    private(set) var isPressed = false

    override init() {
        super.init()
        addChild(art)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func contains(scenePoint p: CGPoint) -> Bool {
        let local = localPoint(p)
        return abs(local.x) <= hitSize.width / 2 && abs(local.y) <= hitSize.height / 2
    }

    func localPoint(_ scenePoint: CGPoint) -> CGPoint {
        CGPoint(x: scenePoint.x - position.x, y: scenePoint.y - position.y)
    }

    // Subclasses override and call super.
    func begin(at scenePoint: CGPoint) { isPressed = true }
    func move(to scenePoint: CGPoint) {}
    func end() { isPressed = false }
    func cancel() { end() }

    func pressArt(scale: CGFloat = 0.9) {
        art.removeAction(forKey: "press")
        let down = SKAction.scale(to: scale, duration: WarmShelfMotion.instantTouch)
        down.timingMode = .easeOut
        art.run(down, withKey: "press")
    }
    func releaseArt() {
        art.removeAction(forKey: "press")
        let up = SKAction.scale(to: 1, duration: 0.34)
        up.timingMode = .easeInEaseOut
        art.run(up, withKey: "press")
    }

    /// A recessed round well, carved into the board, so a round control reads as set in — never
    /// pasted on. Sits behind the (pressable) art and stays put while the control depresses.
    func addRoundSocket(radius: CGFloat) {
        let well = SKShapeNode(circleOfRadius: radius)
        well.fillColor = WarmShelfPalette.cocoa.withAlpha(0.18)
        well.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.22)
        well.lineWidth = 2.5
        well.zPosition = -0.7
        addChild(well)
        let innerShade = SKShapeNode(ellipseOf: CGSize(width: radius * 1.5, height: radius * 0.8))
        innerShade.fillColor = WarmShelfPalette.cocoa.withAlpha(0.14)
        innerShade.strokeColor = .clear
        innerShade.position = CGPoint(x: 0, y: -radius * 0.28)
        innerShade.zPosition = -0.65
        addChild(innerShade)
        let rimLight = SKShapeNode(circleOfRadius: radius - 1)
        rimLight.fillColor = .clear
        rimLight.strokeColor = WarmShelfPalette.paperHighlight.withAlpha(0.22)
        rimLight.lineWidth = 1.5
        rimLight.zPosition = -0.6
        addChild(rimLight)
    }

    /// A recessed slot/groove for the toggle and slider so they read as mounted in the board.
    func addSlotSocket(size s: CGSize, radius: CGFloat) {
        let well = SKShapeNode(rect: CGRect(x: -s.width / 2, y: -s.height / 2, width: s.width, height: s.height), cornerRadius: radius)
        well.fillColor = WarmShelfPalette.cocoa.withAlpha(0.15)
        well.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.2)
        well.lineWidth = 2
        well.zPosition = -0.7
        addChild(well)
        let rimLight = SKShapeNode(rect: CGRect(x: -s.width / 2 + 1, y: -s.height / 2 + 1, width: s.width - 2, height: s.height - 2), cornerRadius: radius)
        rimLight.fillColor = .clear
        rimLight.strokeColor = WarmShelfPalette.paperHighlight.withAlpha(0.16)
        rimLight.lineWidth = 1
        rimLight.zPosition = -0.6
        addChild(rimLight)
    }

    /// A round wooden cap shared by the button and the knob — clay depth, soft top highlight.
    static func woodenDisc(radius r: CGFloat, fill: UIColor = WarmShelfPalette.sand) -> SKShapeNode {
        let disc = SKShapeNode(circleOfRadius: r)
        disc.fillColor = fill
        disc.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.14)
        disc.lineWidth = 1.5
        ProceduralTexture.addMatteClayDepth(
            to: disc, ellipse: CGSize(width: r * 2, height: r * 2),
            zPosition: 0.1, highlightAlpha: 0.26, shadeAlpha: 0.06, rimAlpha: 0.05, speckleCount: 3
        )
        return disc
    }

    static func contactShadow(width: CGFloat, height: CGFloat, y: CGFloat, alpha: CGFloat = 0.14) -> SKShapeNode {
        let s = SKShapeNode(ellipseOf: CGSize(width: width, height: height))
        s.fillColor = WarmShelfPalette.contactShadow.withAlpha(alpha)
        s.strokeColor = .clear
        s.position = CGPoint(x: 0, y: y)
        s.zPosition = -1
        return s
    }
}

// MARK: - Big soft button (the lamp)

/// Tap toggles the lamp; press-and-hold blooms it to full and warms; release exhales it back
/// to a resting glow. The lens in its centre lights with the level so the button *is* the lamp.
final class GlowButtonNode: GlowControlNode {
    var onLamp: ((CGFloat) -> Void)?

    private let lens = SKShapeNode()
    private let shadow: SKShapeNode
    private var radius: CGFloat = 44
    private var level: CGFloat = 0          // resting (toggled) level
    private var live: CGFloat = 0           // live level while held / exhaling
    private var restingBefore: CGFloat = 0
    private var holdStart: TimeInterval = 0

    init(unit: CGFloat, startLevel: CGFloat) {
        radius = unit * 0.62
        shadow = GlowControlNode.contactShadow(width: radius * 2.0, height: radius * 0.66, y: -radius * 0.86)
        super.init()
        level = startLevel; live = startLevel
        hitSize = CGSize(width: radius * 2.7, height: radius * 2.7)

        addRoundSocket(radius: radius * 1.2)
        addChild(shadow)
        let disc = GlowControlNode.woodenDisc(radius: radius, fill: WarmShelfPalette.sand)
        art.addChild(disc)

        // A warm inset ring so the lens reads as a real bulb set into the wood.
        let cradle = SKShapeNode(circleOfRadius: radius * 0.62)
        cradle.fillColor = WarmShelfPalette.cocoa.withAlpha(0.12)
        cradle.strokeColor = .clear
        cradle.zPosition = 0.2
        art.addChild(cradle)

        lens.path = CGPath(ellipseIn: CGRect(x: -radius * 0.5, y: -radius * 0.5, width: radius, height: radius), transform: nil)
        lens.fillColor = WarmShelfPalette.butter
        lens.strokeColor = .clear
        lens.blendMode = .add
        lens.zPosition = 0.3
        art.addChild(lens)
        setLens(level)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setLens(_ v: CGFloat) {
        lens.alpha = 0.16 + 0.84 * v
        lens.setScale(0.7 + 0.4 * v)
    }

    override func begin(at scenePoint: CGPoint) {
        super.begin(at: scenePoint)
        pressArt(scale: 0.9)
        shadow.run(.scale(to: 0.82, duration: WarmShelfMotion.instantTouch))   // shadow tightens when pressed in
        onPressDown?()
        restingBefore = level
        holdStart = CACurrentMediaTime()
        tweenLamp(from: live, to: 1.0, duration: 1.1)   // while held, bloom toward full
    }

    override func end() {
        super.end()
        releaseArt()
        shadow.run(.scale(to: 1, duration: 0.34))
        onPressUp?()
        removeAction(forKey: "lampRamp")

        let heldFor = CACurrentMediaTime() - holdStart
        let bloomed = live - restingBefore
        if heldFor < 0.22 && bloomed < 0.14 {
            // A quick tap → toggle on/off.
            level = restingBefore > 0.05 ? 0 : 0.72
            tweenLamp(from: live, to: level, duration: 0.45)
        } else {
            // A hold → keep it on, exhaling slowly from the bloom back to a warm resting glow.
            level = 0.74
            tweenLamp(from: live, to: level, duration: 1.25)
        }
    }

    private func tweenLamp(from a: CGFloat, to b: CGFloat, duration: TimeInterval) {
        removeAction(forKey: "lampRamp")
        let act = SKAction.customAction(withDuration: duration) { [weak self] _, t in
            guard let self else { return }
            let p = CGFloat(min(1, t / CGFloat(duration)))
            let eased = p * p * (3 - 2 * p)            // smoothstep
            let v = a + (b - a) * eased
            self.live = v
            self.onLamp?(v)
            self.setLens(v)
        }
        run(act, withKey: "lampRamp")
    }

    /// Programmatic tap — used by VoiceOver activation.
    func actuateTap() {
        onPressDown?()
        level = level > 0.05 ? 0 : 0.72
        tweenLamp(from: live, to: level, duration: 0.45)
    }
}

// MARK: - Toggle switch (the stars)

/// Flip up → stars appear; flip down → they fade. Forgiving: a tap toggles, a drag in either
/// direction sets it. Clear snapped states with a little travel arc and a wooden clack.
final class GlowToggleNode: GlowControlNode {
    var onToggle: ((Bool) -> Void)?
    var onSnap: (() -> Void)?

    private let paddle = SKNode()
    private var isUp: Bool
    private var trackHeight: CGFloat = 70
    private var startLocalY: CGFloat = 0
    private var pending: Bool?

    init(unit: CGFloat, startUp: Bool) {
        isUp = startUp
        super.init()
        let w = unit * 1.2, h = unit * 2.0
        trackHeight = h
        hitSize = CGSize(width: w * 2.0, height: h * 1.5)

        addSlotSocket(size: CGSize(width: w * 1.5, height: h * 1.14), radius: w * 0.75)
        addChild(GlowControlNode.contactShadow(width: w * 1.3, height: w * 0.6, y: -h * 0.62))

        // A recessed wooden slot.
        let slot = SKShapeNode(rect: CGRect(x: -w / 2, y: -h / 2, width: w, height: h), cornerRadius: w / 2)
        slot.fillColor = WarmShelfPalette.cocoa.withAlpha(0.2)
        slot.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.10)
        slot.lineWidth = 1
        art.addChild(slot)

        // Two faint detents so the up/down homes read.
        for sign in [CGFloat(1), CGFloat(-1)] {
            let dot = SKShapeNode(circleOfRadius: w * 0.07)
            dot.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.20)
            dot.strokeColor = .clear
            dot.position = CGPoint(x: 0, y: sign * (h / 2 - w * 0.5))
            art.addChild(dot)
        }

        // The clay switch cap that slides between homes — a tall lever, not a dot.
        let cap = SKShapeNode(rect: CGRect(x: -w * 0.34, y: -w * 0.52, width: w * 0.68, height: w * 1.04), cornerRadius: w * 0.3)
        cap.fillColor = WarmShelfPalette.butter
        cap.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.12)
        cap.lineWidth = 1.2
        ProceduralTexture.addMatteClayDepth(to: cap, ellipse: CGSize(width: w * 0.68, height: w * 1.04),
                                            zPosition: 0.1, highlightAlpha: 0.28, shadeAlpha: 0.06, rimAlpha: 0.05, speckleCount: 2)
        paddle.addChild(cap)
        paddle.zPosition = 1
        art.addChild(paddle)
        paddle.position = paddleHome(up: isUp)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func paddleHome(up: Bool) -> CGPoint {
        CGPoint(x: 0, y: (up ? 1 : -1) * (trackHeight / 2 - trackHeight * 0.22))
    }

    override func begin(at scenePoint: CGPoint) {
        super.begin(at: scenePoint)
        startLocalY = localPoint(scenePoint).y
        pending = nil
        onPressDown?()
        paddle.run(.scale(to: 0.92, duration: WarmShelfMotion.instantTouch))
    }

    override func move(to scenePoint: CGPoint) {
        let dy = localPoint(scenePoint).y - startLocalY
        if dy > 12 { pending = true } else if dy < -12 { pending = false }
    }

    override func end() {
        super.end()
        paddle.run(.scale(to: 1, duration: 0.3))
        let target = pending ?? !isUp     // a drag sets direction; a plain tap flips
        if target != isUp {
            isUp = target
            snapPaddle()
            onSnap?()
            onToggle?(isUp)
        } else {
            // No state change — settle the paddle home without a clack.
            paddle.run(.move(to: paddleHome(up: isUp), duration: 0.18))
        }
    }

    private func snapPaddle() {
        paddle.removeAction(forKey: "snap")
        // Travel with a tiny overshoot for a satisfying mechanical flip.
        let home = paddleHome(up: isUp)
        let over = CGPoint(x: 0, y: home.y + (isUp ? 1 : -1) * trackHeight * 0.06)
        let go = SKAction.move(to: over, duration: 0.12)
        let settle = SKAction.move(to: home, duration: 0.12)
        go.timingMode = .easeOut; settle.timingMode = .easeInEaseOut
        paddle.run(.sequence([go, settle]), withKey: "snap")
    }

    /// Programmatic flip — used by VoiceOver activation.
    func actuateFlip() {
        isUp.toggle()
        snapPaddle()
        onSnap?()
        onToggle?(isUp)
    }
}

// MARK: - Rotary knob (the moon)

/// A forgiving circular drag: any touch that begins near the knob rotates it by the angle it
/// sweeps around the centre, so messy toddler swipes still turn the moon's brightness and phase.
final class GlowKnobNode: GlowControlNode {
    var onMoon: ((CGFloat) -> Void)?
    var onStep: (() -> Void)?

    private var radius: CGFloat = 40
    private let range: CGFloat = .pi * 1.5     // 270° of travel
    private var rotation: CGFloat = 0
    private var lastAngle: CGFloat = 0
    private var lastNotch = -1

    init(unit: CGFloat, startLevel: CGFloat) {
        radius = unit * 0.58
        super.init()
        hitSize = CGSize(width: radius * 2.9, height: radius * 2.9)
        rotation = (startLevel - 0.5) * range

        addRoundSocket(radius: radius * 1.22)
        addChild(GlowControlNode.contactShadow(width: radius * 1.9, height: radius * 0.62, y: -radius * 0.84))
        let disc = GlowControlNode.woodenDisc(radius: radius, fill: WarmShelfPalette.sand)
        art.addChild(disc)

        // A carved pointer notch so the rotation is unmistakable.
        let notch = SKShapeNode(rect: CGRect(x: -radius * 0.06, y: radius * 0.30, width: radius * 0.12, height: radius * 0.5), cornerRadius: radius * 0.06)
        notch.fillColor = WarmShelfPalette.cocoa.withAlpha(0.42)
        notch.strokeColor = .clear
        notch.zPosition = 0.4
        art.addChild(notch)
        art.zRotation = rotation
        lastNotch = Int((startLevel * 8).rounded())
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func begin(at scenePoint: CGPoint) {
        super.begin(at: scenePoint)
        let l = localPoint(scenePoint)
        lastAngle = atan2(l.y, l.x)
        onPressDown?()
        art.run(.scale(to: 0.96, duration: WarmShelfMotion.instantTouch))
    }

    override func move(to scenePoint: CGPoint) {
        let l = localPoint(scenePoint)
        let ang = atan2(l.y, l.x)
        var delta = ang - lastAngle
        while delta > .pi { delta -= 2 * .pi }
        while delta < -.pi { delta += 2 * .pi }
        lastAngle = ang
        rotation = max(-range / 2, min(range / 2, rotation + delta))
        art.zRotation = rotation
        let level = (rotation + range / 2) / range
        onMoon?(level)
        let notch = Int((level * 8).rounded())
        if notch != lastNotch { lastNotch = notch; onStep?() }
    }

    override func end() {
        super.end()
        art.run(.scale(to: 1, duration: 0.3))
        onPressUp?()
    }

    /// Programmatic step — used by VoiceOver activation. Bumps the moon up, wrapping at full.
    func actuateStep() {
        var level = (rotation + range / 2) / range
        level += 0.2
        if level > 1.001 { level = 0 }
        rotation = (level - 0.5) * range
        art.run(.rotate(toAngle: rotation, duration: 0.2, shortestUnitArc: true))
        onMoon?(level)
        onStep?()
    }
}

// MARK: - Dimmer slider (the room)

/// A pill track with a chunky clay thumb. Tap or drag anywhere along it and the thumb follows —
/// no precision needed. Maps smoothly to overall room dimness.
final class GlowSliderNode: GlowControlNode {
    var onDim: ((CGFloat) -> Void)?
    var onEdge: (() -> Void)?

    private let thumb = SKNode()
    private var trackWidth: CGFloat = 200
    private var value: CGFloat = 0.6
    private var lastEdge = false

    init(unit: CGFloat, width: CGFloat, startValue: CGFloat) {
        value = startValue
        trackWidth = width
        super.init()
        let h = unit * 0.7
        hitSize = CGSize(width: width + unit * 1.4, height: unit * 2.0)

        addSlotSocket(size: CGSize(width: width + unit * 0.5, height: h * 2.0), radius: h)
        addChild(GlowControlNode.contactShadow(width: width * 0.92, height: h * 0.8, y: -h * 0.9))

        let track = SKShapeNode(rect: CGRect(x: -width / 2, y: -h / 2, width: width, height: h), cornerRadius: h / 2)
        track.fillColor = WarmShelfPalette.cocoa.withAlpha(0.2)
        track.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.14)
        track.lineWidth = 1
        art.addChild(track)
        // Chunky wooden end caps so the track reads as a real fitting.
        for sign in [CGFloat(-1), CGFloat(1)] {
            let endCap = SKShapeNode(circleOfRadius: h * 0.62)
            endCap.fillColor = WarmShelfPalette.sand
            endCap.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.14)
            endCap.lineWidth = 1
            endCap.position = CGPoint(x: sign * width / 2, y: 0)
            art.addChild(endCap)
        }

        // A little sun/moon engraving at each end hints at bright ↔ dim without any text.
        for (sign, alpha) in [(CGFloat(-1), CGFloat(0.10)), (CGFloat(1), CGFloat(0.26))] {
            let mark = SKShapeNode(circleOfRadius: h * 0.20)
            mark.fillColor = WarmShelfPalette.paperHighlight.withAlpha(alpha)
            mark.strokeColor = .clear
            mark.position = CGPoint(x: sign * (width / 2 - h * 0.5), y: 0)
            art.addChild(mark)
        }

        let cap = SKShapeNode(circleOfRadius: h * 0.78)
        cap.fillColor = WarmShelfPalette.terracotta
        cap.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.12)
        cap.lineWidth = 1.2
        ProceduralTexture.addMatteClayDepth(to: cap, ellipse: CGSize(width: h * 1.56, height: h * 1.56),
                                            zPosition: 0.1, highlightAlpha: 0.28, shadeAlpha: 0.06, rimAlpha: 0.05, speckleCount: 2)
        thumb.addChild(cap)
        thumb.zPosition = 1
        art.addChild(thumb)
        thumb.position = CGPoint(x: thumbX(value), y: 0)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func thumbX(_ v: CGFloat) -> CGFloat { (-0.5 + v) * trackWidth }

    override func begin(at scenePoint: CGPoint) {
        super.begin(at: scenePoint)
        onPressDown?()
        thumb.run(.scale(to: 1.08, duration: WarmShelfMotion.instantTouch))
        setFromTouch(scenePoint, animated: true)
    }

    override func move(to scenePoint: CGPoint) {
        setFromTouch(scenePoint, animated: false)
    }

    override func end() {
        super.end()
        thumb.run(.scale(to: 1, duration: 0.3))
    }

    private func setFromTouch(_ scenePoint: CGPoint, animated: Bool) {
        let x = localPoint(scenePoint).x
        let v = max(0, min(1, (x / trackWidth) + 0.5))
        value = v
        let tx = thumbX(v)
        if animated {
            thumb.run(.move(to: CGPoint(x: tx, y: 0), duration: 0.12))
        } else {
            thumb.position.x = tx
        }
        onDim?(v)
        let atEdge = v < 0.04 || v > 0.96
        if atEdge && !lastEdge { onEdge?() }
        lastEdge = atEdge
    }

    /// Programmatic toggle between brighter and dimmer — used by VoiceOver activation.
    func actuateToggle() {
        value = value > 0.5 ? 0.25 : 0.9
        thumb.run(.move(to: CGPoint(x: thumbX(value), y: 0), duration: 0.2))
        onDim?(value)
        onEdge?()
    }
}

// MARK: - Pull cord (the fireflies)

/// Pull the bead down and the cord stretches; let go and it snaps back with an elastic rebound,
/// flinging a soft swarm of fireflies a beat later. The board's one little Pixar moment.
final class GlowCordNode: GlowControlNode {
    var onRelease: ((CGPoint) -> Void)?

    private let cord = SKShapeNode()
    private let bead = SKNode()
    private var anchor = CGPoint.zero
    private var restY: CGFloat = -60
    private var maxStretch: CGFloat = 70

    init(unit: CGFloat) {
        super.init()
        let beadR = unit * 0.34
        restY = -unit * 1.0
        maxStretch = unit * 1.8
        anchor = CGPoint(x: 0, y: unit * 0.5)
        hitSize = CGSize(width: beadR * 4.0, height: unit * 4.2)

        cord.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.5)
        cord.lineWidth = max(2, unit * 0.07)
        cord.lineCap = .round
        cord.fillColor = .clear
        art.addChild(cord)

        // A small wooden peg the cord hangs from — a deliberate anchor, not a random attachment.
        let pegBase = SKShapeNode(circleOfRadius: unit * 0.16)
        pegBase.fillColor = WarmShelfPalette.sand
        pegBase.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.16)
        pegBase.lineWidth = 1
        pegBase.position = anchor
        pegBase.zPosition = 2
        art.addChild(pegBase)
        let pegHole = SKShapeNode(circleOfRadius: unit * 0.07)
        pegHole.fillColor = WarmShelfPalette.cocoa.withAlpha(0.4)
        pegHole.strokeColor = .clear
        pegHole.position = anchor
        pegHole.zPosition = 2.1
        art.addChild(pegHole)

        let knot = SKShapeNode(circleOfRadius: beadR)
        knot.fillColor = WarmShelfPalette.sage
        knot.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.14)
        knot.lineWidth = 1.2
        ProceduralTexture.addMatteClayDepth(to: knot, ellipse: CGSize(width: beadR * 2, height: beadR * 2),
                                            zPosition: 0.1, highlightAlpha: 0.26, shadeAlpha: 0.06, rimAlpha: 0.05, speckleCount: 2)
        bead.addChild(knot)
        bead.zPosition = 1
        art.addChild(bead)
        bead.position = CGPoint(x: 0, y: restY)
        layoutCord()
        idleSway()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// The bead's current position in the scene — where the fireflies should spill from.
    var beadScenePoint: CGPoint { CGPoint(x: position.x + bead.position.x, y: position.y + bead.position.y) }

    private func layoutCord() {
        let b = bead.position
        let path = CGMutablePath()
        path.move(to: anchor)
        // A gentle catenary droop toward the bead.
        let mid = CGPoint(x: (anchor.x + b.x) / 2, y: (anchor.y + b.y) / 2 - 6)
        path.addQuadCurve(to: b, control: mid)
        cord.path = path
    }

    private func idleSway() {
        guard !AmbientAnimator.reduceMotion else { return }
        bead.run(.repeatForever(.sequence([
            .rotate(toAngle: 0.05, duration: 1.8), .rotate(toAngle: -0.05, duration: 1.8)
        ])), withKey: "sway")
    }

    override func begin(at scenePoint: CGPoint) {
        super.begin(at: scenePoint)
        bead.removeAction(forKey: "sway")
        bead.removeAction(forKey: "snap")
        bead.zRotation = 0
        onPressDown?()
    }

    override func move(to scenePoint: CGPoint) {
        let l = localPoint(scenePoint)
        // Follow the finger downward, clamped; sideways pull is damped so it reads as a cord.
        let y = max(restY - maxStretch, min(restY + 8, l.y))
        let x = max(-30, min(30, l.x * 0.18))
        bead.position = CGPoint(x: x, y: y)
        layoutCord()
    }

    override func end() {
        super.end()
        let released = beadScenePoint
        let startY = bead.position.y
        let startX = bead.position.x
        let stretched = restY - startY          // how far it was pulled past rest (down = positive)
        let duration: TimeInterval = 0.55

        // A damped spring back to rest: a couple of soft elastic bounces, then still.
        bead.removeAction(forKey: "snap")
        let snap = SKAction.customAction(withDuration: duration) { [weak self] _, t in
            guard let self else { return }
            let p = Double(t) / duration
            let damp = exp(-4.4 * p)
            let osc = cos(2 * Double.pi * 1.25 * p)
            let y = self.restY + CGFloat(Double(startY - self.restY) * damp * osc)
            let x = startX * CGFloat(1 - p)
            self.bead.position = CGPoint(x: x, y: y)
            self.layoutCord()
        }
        run(.sequence([snap, .run { [weak self] in
            guard let self else { return }
            self.bead.position = CGPoint(x: 0, y: self.restY)
            self.layoutCord(); self.idleSway()
        }]), withKey: "snap")

        // Fireflies a beat after release — only if it was a real pull, not an idle tap.
        if stretched > 18 {
            run(.sequence([.wait(forDuration: 0.12), .run { [weak self] in self?.onRelease?(released) }]))
        }
    }

    /// Programmatic pull — used by VoiceOver activation.
    func actuatePull() {
        onPressDown?()
        let released = beadScenePoint
        bead.removeAction(forKey: "sway")
        bead.run(.sequence([.scale(to: 1.18, duration: 0.1), .scale(to: 1, duration: 0.2)]))
        run(.sequence([.wait(forDuration: 0.12), .run { [weak self] in self?.onRelease?(released) }]))
    }
}
