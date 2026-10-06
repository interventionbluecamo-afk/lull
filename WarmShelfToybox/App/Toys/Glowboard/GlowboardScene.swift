import SpriteKit
import QuartzCore

/// Glowboard — a handmade wooden bedtime control board, seen from above. Five tactile controls
/// (a lamp button, a star switch, a moon dial, a room dimmer, and a firefly cord) each change a
/// tiny cozy night world. There is no goal and no menu: a finger touches a real-feeling control
/// and the bedroom answers. Quick to wake, slow to settle.
final class GlowboardScene: BaseToyScene {

    override var toyVoice: AudioManager.LullSoundVoice { .glowboard }
    override var firstSessionHintKey: String? { "hint.glowboard" }
    override func firstSessionHintPoint() -> CGPoint { button?.position ?? CGPoint(x: size.width / 2, y: size.height * 0.4) }

    // Layers
    private let worldNode = GlowWorldNode()
    private let boardNode = SKNode()
    private let dimVeil = SKShapeNode()

    // Controls
    private var controls: [GlowControlNode] = []
    private var button: GlowButtonNode!
    private var toggle: GlowToggleNode!
    private var knob: GlowKnobNode!
    private var slider: GlowSliderNode!
    private var cord: GlowCordNode!

    private var touchControl: [UITouch: GlowControlNode] = [:]

    // Authoritative state (kept here so a rotation rebuild restores the exact room).
    private var lampLevel: CGFloat = 0.55
    private var moonLevel: CGFloat = 0.5
    private var starsUp = false
    private var roomLight: CGFloat = 0.8     // a gentle evening, not a muddy dim

    private var lastTone: [String: TimeInterval] = [:]

    private let woodWarm = UIColor(hex: 0xC9A05E)

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        ambientMoteInterval = 1.6   // a calm room — only the faintest drift of dust in the light

        worldNode.zPosition = 1
        addChild(worldNode)

        boardNode.zPosition = 2
        addChild(boardNode)

        dimVeil.fillColor = UIColor(red: 0.06, green: 0.05, blue: 0.14, alpha: 1)
        dimVeil.strokeColor = .clear
        dimVeil.zPosition = 4
        dimVeil.alpha = 0
        addChild(dimVeil)

        rebuild()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 80, size.height > 80, button != nil else { return }
        rebuild()
    }

    // MARK: - Build / layout

    private func rebuild() {
        guard size.width > 80, size.height > 80 else { return }

        dimVeil.path = CGPath(rect: CGRect(x: 0, y: 0, width: size.width, height: size.height), transform: nil)

        let landscape = size.width > size.height
        let boardW = min(size.width * (landscape ? 0.66 : 0.86), 560)
        let boardH = min(size.height * (landscape ? 0.74 : 0.54), 620)
        let boardCenter = CGPoint(x: size.width / 2, y: size.height * (landscape ? 0.46 : 0.40))
        let unit = min(boardW, boardH) * 0.16

        // Localise the lamp glow to a small pool around the button, then build the world + board.
        worldNode.lampGlowRadius = unit * 1.18 * 0.62 * 2.4
        worldNode.layout(in: size)
        buildBoardArt(center: boardCenter, size: CGSize(width: boardW, height: boardH))

        controls.forEach { $0.removeFromParent() }
        controls.removeAll()

        button = GlowButtonNode(unit: unit * 1.18, startLevel: lampLevel)
        toggle = GlowToggleNode(unit: unit, startUp: starsUp)
        knob = GlowKnobNode(unit: unit, startLevel: moonLevel)
        slider = GlowSliderNode(unit: unit, width: boardW * 0.6, startValue: roomLight)
        cord = GlowCordNode(unit: unit)

        // Arranged around the lamp hero with real negative space; tasteful asymmetry.
        button.position = CGPoint(x: boardCenter.x, y: boardCenter.y - boardH * 0.02)
        toggle.position = CGPoint(x: boardCenter.x - boardW * 0.30, y: boardCenter.y + boardH * 0.13)
        knob.position   = CGPoint(x: boardCenter.x + boardW * 0.30, y: boardCenter.y + boardH * 0.07)
        slider.position = CGPoint(x: boardCenter.x, y: boardCenter.y - boardH * 0.32)
        cord.position   = CGPoint(x: boardCenter.x + boardW * 0.36, y: boardCenter.y + boardH * 0.34)

        controls = [button, toggle, knob, slider, cord]
        for (index, control) in controls.enumerated() {
            control.zPosition = 8 + CGFloat(index) * 0.1
            addChild(control)
        }

        worldNode.lampOrigin = button.position
        wireControls()

        // Apply current room so the very first frame already reads as a warm bedtime board.
        worldNode.setLamp(lampLevel, animated: false)
        worldNode.setMoon(moonLevel, animated: false)
        if starsUp { worldNode.setStars(up: true) }
        applyDim(animated: false)
    }

    private func buildBoardArt(center: CGPoint, size boardSize: CGSize) {
        boardNode.removeAllChildren()
        let rect = CGRect(x: -boardSize.width / 2, y: -boardSize.height / 2, width: boardSize.width, height: boardSize.height)
        let radius = min(boardSize.width, boardSize.height) * 0.12

        // Soft, blurred contact shadow grounding the whole board.
        let shadow = SKSpriteNode(texture: ProceduralTexture.softClayShadow(size: CGSize(width: boardSize.width * 1.04, height: boardSize.height * 0.3)))
        shadow.position = CGPoint(x: center.x, y: center.y - boardSize.height * 0.46)
        shadow.zPosition = -0.5
        boardNode.addChild(shadow)

        // The wooden body, filled with a baked warm gradient so the light reads across it.
        let body = SKShapeNode(rect: rect, cornerRadius: radius)
        body.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.2)
        body.lineWidth = 2
        body.position = center
        body.zPosition = 0
        boardNode.addChild(body)
        ProceduralTexture.applyClayFill(to: body, base: woodWarm, size: boardSize)
        ProceduralTexture.addSoftGrainLines(to: body, in: rect.insetBy(dx: rect.width * 0.08, dy: rect.height * 0.1),
                                            count: 10, color: WarmShelfPalette.cocoa, alpha: 0.02...0.05, zPosition: 0.2)

        // Lit top bevel + a thin rim highlight + a bottom shade — carved, not flat.
        let bevel = SKShapeNode(rect: CGRect(x: rect.minX + radius * 0.5, y: rect.maxY - boardSize.height * 0.12, width: rect.width - radius, height: boardSize.height * 0.09), cornerRadius: radius * 0.5)
        bevel.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.22); bevel.strokeColor = .clear; bevel.zPosition = 0.3
        body.addChild(bevel)
        let rim = SKShapeNode(rect: rect.insetBy(dx: boardSize.width * 0.025, dy: boardSize.height * 0.022), cornerRadius: radius * 0.88)
        rim.fillColor = .clear; rim.strokeColor = WarmShelfPalette.paperHighlight.withAlpha(0.18); rim.lineWidth = 2; rim.zPosition = 0.35
        body.addChild(rim)
        let shade = SKShapeNode(rect: CGRect(x: rect.minX + radius * 0.5, y: rect.minY + boardSize.height * 0.03, width: rect.width - radius, height: boardSize.height * 0.1), cornerRadius: radius * 0.5)
        shade.fillColor = WarmShelfPalette.cocoa.withAlpha(0.08); shade.strokeColor = .clear; shade.zPosition = 0.25
        body.addChild(shade)

        // A recessed inner face where the controls sit, with a soft inner top shadow.
        let insetRect = rect.insetBy(dx: rect.width * 0.05, dy: rect.height * 0.05)
        let inset = SKShapeNode(rect: insetRect, cornerRadius: radius * 0.82)
        inset.fillColor = WarmShelfPalette.cocoa.withAlpha(0.06)
        inset.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.12)
        inset.lineWidth = 1.5
        inset.position = center
        inset.zPosition = 0.4
        boardNode.addChild(inset)
        let innerTopShade = SKShapeNode(rect: CGRect(x: insetRect.minX, y: insetRect.maxY - insetRect.height * 0.12, width: insetRect.width, height: insetRect.height * 0.12), cornerRadius: radius * 0.7)
        innerTopShade.fillColor = WarmShelfPalette.cocoa.withAlpha(0.06); innerTopShade.strokeColor = .clear
        innerTopShade.position = center; innerTopShade.zPosition = 0.45
        boardNode.addChild(innerTopShade)
        let insetRim = SKShapeNode(rect: insetRect, cornerRadius: radius * 0.82)
        insetRim.fillColor = .clear; insetRim.strokeColor = WarmShelfPalette.paperHighlight.withAlpha(0.12); insetRim.lineWidth = 1
        insetRim.position = center; insetRim.zPosition = 0.5
        boardNode.addChild(insetRim)
    }

    private func wireControls() {
        button.onLamp = { [weak self] v in
            guard let self else { return }
            self.lampLevel = v
            self.worldNode.setLamp(v, animated: false)
        }
        button.onPressDown = { [weak self] in
            self?.tone(.single(5, .clay.with(body: 0.22, amplitude: 0.085, noiseGain: 0.16)), key: "lamp.down")
            HapticsManager.shared.impact(style: .soft, intensity: 0.22)
        }
        button.onPressUp = { [weak self] in
            self?.tone(.single(7, .felt.with(body: 0.16, amplitude: 0.05)), key: "lamp.up")
            HapticsManager.shared.impact(style: .soft, intensity: 0.12)
        }

        toggle.onToggle = { [weak self] up in
            guard let self else { return }
            self.starsUp = up
            self.worldNode.setStars(up: up)
            if up {
                self.tone(.arp([7, 9, 12], step: 0.06, .celeste.with(body: 0.8, amplitude: 0.05)), key: "stars.up")
            } else {
                self.tone(.arp([12, 9, 7], step: 0.07, .breath.with(body: 0.4, amplitude: 0.045)), key: "stars.down")
            }
        }
        toggle.onSnap = {
            HapticsManager.shared.impact(style: .rigid, intensity: 0.30)
        }
        toggle.onPressDown = { [weak self] in
            self?.tone(.single(3, .clay.with(body: 0.13, amplitude: 0.08)), key: "toggle")
        }

        knob.onMoon = { [weak self] v in
            guard let self else { return }
            self.moonLevel = v
            self.worldNode.setMoon(v, animated: false)
        }
        knob.onStep = { [weak self] in
            self?.tone(.single(8, .felt.with(body: 0.10, amplitude: 0.045)), key: "knob.tick", minInterval: 0.05)
            HapticsManager.shared.impact(style: .light, intensity: 0.10)
        }

        slider.onDim = { [weak self] v in
            guard let self else { return }
            self.roomLight = v
            self.applyDim(animated: false)
            // A felt whisper that follows the value — rate-limited so a drag never spams.
            let degree = 4 + Int(v * 6)
            self.tone(.single(degree, .breath.with(body: 0.20, amplitude: 0.03, noiseGain: 0.5)), key: "slider", minInterval: 0.11)
        }
        slider.onEdge = { [weak self] in
            guard let self else { return }
            self.tone(.single(self.map(self.roomLight), .felt.with(body: 0.14, amplitude: 0.05)), key: "slider.edge")
            HapticsManager.shared.impact(style: .soft, intensity: 0.16)
        }

        cord.onPressDown = { [weak self] in
            self?.tone(.arp([5, 7], step: 0.05, .felt.with(body: 0.16, amplitude: 0.055)), key: "cord.pull")
        }
        cord.onRelease = { [weak self] point in
            guard let self else { return }
            self.worldNode.releaseFireflies(count: 10, from: point)
            self.tone(.arp([10, 12, 14, 17], step: 0.07, .celeste.with(body: 0.9, amplitude: 0.05)), key: "cord.fireflies")
            HapticsManager.shared.impact(style: .rigid, intensity: 0.24)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                HapticsManager.shared.impact(style: .soft, intensity: 0.14)
            }
        }
    }

    private func map(_ v: CGFloat) -> Int { v > 0.5 ? 10 : 4 }

    private func applyDim(animated: Bool) {
        let target = (1 - roomLight) * 0.42    // capped so the board stays readable even at darkest
        dimVeil.removeAction(forKey: "dim")
        guard animated, !AmbientAnimator.reduceMotion else { dimVeil.alpha = target; return }
        let fade = SKAction.fadeAlpha(to: target, duration: 0.4)
        fade.timingMode = .easeInEaseOut
        dimVeil.run(fade, withKey: "dim")
    }

    // MARK: - Sound

    private func tone(_ spec: LullToneEngine.Spec, key: String, minInterval: TimeInterval = 0) {
        guard AudioManager.shared.isEnabled else { return }
        if minInterval > 0 {
            let now = CACurrentMediaTime()
            if let last = lastTone[key], now - last < minInterval { return }
            lastTone[key] = now
        }
        LullToneEngine.shared.play(spec, cacheKey: "glow.\(key)")
    }

    // MARK: - Touch routing

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        HapticsManager.shared.prepareForTouch()
        for touch in touches {
            let point = touch.location(in: self)
            if touchControl.isEmpty, consumeShelfReturnTouch(at: point) { return }

            if let control = controlNearest(to: point) {
                touchControl[touch] = control
                control.begin(at: point)
            } else {
                TouchFeedbackAnimator.emptyTap(in: self, at: point)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            touchControl[touch]?.move(to: touch.location(in: self))
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            touchControl.removeValue(forKey: touch)?.end()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            touchControl.removeValue(forKey: touch)?.cancel()
        }
    }

    /// The control whose generous hit area contains the point, nearest by centre so overlapping
    /// targets resolve to the one the finger is really closest to.
    private func controlNearest(to point: CGPoint) -> GlowControlNode? {
        controls
            .filter { $0.contains(scenePoint: point) }
            .min { a, b in
                hypot(a.position.x - point.x, a.position.y - point.y) <
                hypot(b.position.x - point.x, b.position.y - point.y)
            }
    }

    // MARK: - Accessibility

    override func accessibilityElements(in view: SKView) -> [UIAccessibilityElement] {
        var elements = super.accessibilityElements(in: view)
        guard button != nil else { return elements }

        func element(_ label: String, at node: SKNode, size es: CGSize, _ action: @escaping () -> Void) {
            elements.append(makeActivatableAccessibilityElement(
                in: view, label: label, scenePosition: node.position, size: es, traits: .button, activationHandler: action
            ))
        }

        element("Bedside lamp — turns the light on and off", at: button, size: CGSize(width: 110, height: 110)) { [weak self] in
            self?.button.actuateTap()
        }
        element("Star switch — shows or hides the stars", at: toggle, size: CGSize(width: 96, height: 120)) { [weak self] in
            self?.toggle.actuateFlip()
        }
        element("Moon dial — turns to brighten the moon", at: knob, size: CGSize(width: 104, height: 104)) { [weak self] in
            self?.knob.actuateStep()
        }
        element("Room dimmer — makes the room brighter or darker", at: slider, size: CGSize(width: 200, height: 96)) { [weak self] in
            self?.slider.actuateToggle()
        }
        element("Firefly cord — pull to send out fireflies", at: cord, size: CGSize(width: 96, height: 150)) { [weak self] in
            self?.cord.actuatePull()
        }
        return elements
    }
}
