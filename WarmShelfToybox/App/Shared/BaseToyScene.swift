import SpriteKit
import UIKit

// MARK: - Ambient sleep manager

/// Tracks child idle time and drives the "almost silence" rule:
/// 20 s idle → dim ambient 40 %; 60 s idle → full ambient silence + slow breath tone.
/// First touch wakes everything back over 2 s.
final class AmbientSleepManager {
    enum SleepState { case awake, dimmed, asleep }

    private(set) var state: SleepState = .awake
    private var lastTouchTime: TimeInterval = 0
    private var initialized = false

    var onWake: (() -> Void)?
    var onDim: (() -> Void)?
    var onSleep: (() -> Void)?

    func notifyTouch(at time: TimeInterval) {
        let wasAsleep = state != .awake
        lastTouchTime = time
        if wasAsleep { transition(to: .awake) }
    }

    func tick(currentTime: TimeInterval) {
        if !initialized { initialized = true; lastTouchTime = currentTime; return }
        let idle = currentTime - lastTouchTime
        let target: SleepState = idle > 60 ? .asleep : (idle > 20 ? .dimmed : .awake)
        if target != state { transition(to: target) }
    }

    private func transition(to newState: SleepState) {
        state = newState
        switch newState {
        case .awake:  onWake?()
        case .dimmed: onDim?()
        case .asleep: onSleep?()
        }
    }
}

// MARK: - BaseToyScene

class BaseToyScene: SKScene, UIGestureRecognizerDelegate {
    let audioManager = AudioManager.shared
    var onReturnToShelf: (() -> Void)?
    var showsShelfReturnHandle = false
    var ambientMoteInterval: TimeInterval = 0.42

    private var lastUpdateTime: TimeInterval = 0
    private var moteAccumulator: TimeInterval = 0
    private let shelfReturnHandleName = "shelfReturnHandle"
    private let shelfReturnHitName = "shelfReturnHandle.hit"
    // Home-return is armed on a handle touch and only fires on a clean tap-up — a swipe-through
    // cancels it — so a toddler mid-play can never accidentally exit.
    private var homeReturnArmed = false
    private var homeReturnStart = CGPoint.zero
    private var lastPaperBackgroundSize = CGSize.zero
    private var isObservingAppLifecycle = false

    // Ambient sleep system
    let ambientSleepManager = AmbientSleepManager()
    private weak var touchTrackerGR: UILongPressGestureRecognizer?

    /// Override in a toy scene to declare its ambient voice identity.
    /// BaseToyScene uses this to start/stop ambient tones automatically.
    var toyVoice: AudioManager.LullSoundVoice { .none }

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = WarmShelfPalette.linen
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        scaleMode = .resizeFill
        backgroundColor = WarmShelfPalette.linen
    }

    deinit {
        if isObservingAppLifecycle {
            NotificationCenter.default.removeObserver(self)
        }
    }

    /// Override in a toy to show a one-time "touch here" invitation on first ever open.
    var firstSessionHintKey: String? { nil }
    func firstSessionHintPoint() -> CGPoint { CGPoint(x: size.width / 2, y: size.height * 0.42) }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        beginObservingAppLifecycleIfNeeded()
        setupPaperBackground()
        setupGrainOverlay()
        layoutShelfReturnHandleIfNeeded()
        showFirstSessionHintIfNeeded()
        setupAmbientSleep()
        installTouchTracker(on: view)
        if toyVoice != .none {
            AudioManager.shared.currentToyVoice = toyVoice
            AudioManager.shared.startToyAmbient(toyVoice)
        }
    }

    override func willMove(from view: SKView) {
        super.willMove(from: view)
        teardownToyAudio()
        if let gr = touchTrackerGR { view.removeGestureRecognizer(gr) }
        touchTrackerGR = nil
    }

    /// Stop any sustained audio this toy owns. The toy VC PAUSES the SKView on dismiss
    /// rather than presenting nil, so willMove isn't reliably delivered — the VC calls
    /// this from viewWillDisappear too. Idempotent. Toys with their own looping audio
    /// (e.g. the Window's recorded day/night beds) override and stop it here.
    func teardownToyAudio() {
        if toyVoice != .none {
            AudioManager.shared.stopToyAmbient(toyVoice)
            AudioManager.shared.currentToyVoice = .none
        }
    }

    private func showFirstSessionHintIfNeeded() {
        guard let key = firstSessionHintKey, !LullDemoState.shared.hasSeenHint(key) else { return }
        LullDemoState.shared.markHintSeen(key)
        guard !AmbientAnimator.reduceMotion else { return }
        run(.sequence([.wait(forDuration: 1.1), .run { [weak self] in self?.presentFirstSessionHint() }]))
    }

    private func presentFirstSessionHint() {
        guard size.width > 60 else { return }
        let point = firstSessionHintPoint()
        let root = SKNode()
        root.position = point
        root.zPosition = 108  // below the shelf-return handle so it never blocks it
        addChild(root)

        let dot = SKShapeNode(circleOfRadius: 8)
        dot.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.85)
        dot.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.25)
        dot.lineWidth = 1.5
        root.addChild(dot)

        for index in 0..<2 {
            let ring = SKShapeNode(circleOfRadius: 16)
            ring.fillColor = .clear
            ring.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.26)
            ring.lineWidth = 2.5
            root.addChild(ring)
            let pulse = SKAction.sequence([
                .wait(forDuration: Double(index) * 0.4),
                .group([.scale(to: 2.6, duration: 1.1), .fadeOut(withDuration: 1.1)]),
                .run { ring.setScale(1); ring.alpha = 1 }
            ])
            ring.run(.repeat(pulse, count: 3))
        }
        root.run(.sequence([.wait(forDuration: 3.6), .fadeOut(withDuration: 0.5), .removeFromParent()]))
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        setupPaperBackground()
        setupGrainOverlay()
        layoutShelfReturnHandleIfNeeded()
    }

    override func update(_ currentTime: TimeInterval) {
        guard size.width > 20, size.height > 20 else { return }

        let delta = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        moteAccumulator += delta

        if moteAccumulator > ambientMoteInterval {
            moteAccumulator = 0
            ParticleManager.ambientMote(in: self, bounds: frame)
        }

        ambientSleepManager.tick(currentTime: currentTime)
    }

    func setupPaperBackground() {
        guard size.width > 0, size.height > 0 else { return }
        guard abs(lastPaperBackgroundSize.width - size.width) > 0.5 ||
            abs(lastPaperBackgroundSize.height - size.height) > 0.5 ||
            childNode(withName: "paperBackground") == nil
        else { return }

        childNode(withName: "paperBackground")?.removeFromParent()
        lastPaperBackgroundSize = size

        let background = SKNode()
        background.name = "paperBackground"
        background.zPosition = -100

        let base = SKShapeNode(rectOf: size)
        base.fillColor = WarmShelfPalette.linen
        base.strokeColor = .clear
        base.position = CGPoint(x: size.width / 2, y: size.height / 2)
        background.addChild(base)

        let lowerWarmth = SKShapeNode(
            rectOf: CGSize(width: size.width, height: size.height * 0.46)
        )
        lowerWarmth.fillColor = WarmShelfPalette.warmCream.withAlpha(0.16)
        lowerWarmth.strokeColor = .clear
        lowerWarmth.position = CGPoint(x: size.width / 2, y: size.height * 0.23)
        lowerWarmth.zPosition = 0.4
        background.addChild(lowerWarmth)

        let upperPaper = SKShapeNode(
            rectOf: CGSize(width: size.width, height: size.height * 0.34)
        )
        upperPaper.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.075)
        upperPaper.strokeColor = .clear
        upperPaper.position = CGPoint(x: size.width / 2, y: size.height * 0.83)
        upperPaper.zPosition = 0.45
        background.addChild(upperPaper)

        let clusterCount = Int(max(10, min(28, (size.width * size.height) / 62_000)))
        for _ in 0..<clusterCount {
            let origin = CGPoint(x: .random(in: 0...size.width), y: .random(in: 0...size.height))
            let speckles = Int.random(in: 2...5)
            for _ in 0..<speckles {
                let speckle = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.7...2.4))
                speckle.fillColor = WarmShelfPalette.sand.withAlpha(.random(in: 0.055...0.13))
                speckle.strokeColor = .clear
                speckle.position = CGPoint(
                    x: (origin.x + CGFloat.random(in: -22...22)).clamped(to: 0...size.width),
                    y: (origin.y + CGFloat.random(in: -18...18)).clamped(to: 0...size.height)
                )
                background.addChild(speckle)
            }
        }

        let bottomGlow = SKShapeNode(
            rectOf: CGSize(width: size.width, height: size.height * 0.36)
        )
        bottomGlow.fillColor = WarmShelfPalette.warmCream.withAlpha(0.14)
        bottomGlow.strokeColor = .clear
        bottomGlow.position = CGPoint(x: size.width / 2, y: size.height * 0.18)
        bottomGlow.zPosition = 1
        background.addChild(bottomGlow)

        let topVeil = SKShapeNode(
            rectOf: CGSize(width: size.width, height: size.height * 0.20)
        )
        topVeil.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.07)
        topVeil.strokeColor = .clear
        topVeil.position = CGPoint(x: size.width / 2, y: size.height * 0.90)
        topVeil.zPosition = 1
        background.addChild(topVeil)

        let quietEdge = SKShapeNode(
            rectOf: CGSize(width: size.width, height: size.height * 0.12)
        )
        quietEdge.fillColor = WarmShelfPalette.cocoa.withAlpha(0.018)
        quietEdge.strokeColor = .clear
        quietEdge.position = CGPoint(x: size.width / 2, y: size.height * 0.06)
        quietEdge.zPosition = 1.2
        background.addChild(quietEdge)

        addTimeOfDayWarmth(to: background)

        addChild(background)
    }

    // MARK: - One paper, every room (approved delight ⭐)
    // A single generated linen-grain texture laid over every scene at ~4% alpha —
    // the shelf and all nine toys feel printed on the same sheet of paper.

    private static let linenGrainTexture: SKTexture = {
        let side: CGFloat = 1024
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let image = renderer.image { ctx in
            // Transparent ground — only speckles carry pigment. On-screen strength
            // comes from the sprite's alpha, so the tones here stay strong.
            for _ in 0..<3000 {
                let tone: UIColor = Bool.random()
                    ? UIColor.white.withAlphaComponent(.random(in: 0.35...0.70))
                    : UIColor.black.withAlphaComponent(.random(in: 0.30...0.60))
                tone.setFill()
                let r = CGFloat.random(in: 0.4...1.2)
                ctx.cgContext.fillEllipse(in: CGRect(
                    x: .random(in: 0...side), y: .random(in: 0...side),
                    width: r * 2, height: r * 2))
            }
            // Faint horizontal fibres so it reads as linen, not static.
            UIColor.black.withAlphaComponent(0.18).setFill()
            for _ in 0..<160 {
                ctx.cgContext.fill(CGRect(
                    x: .random(in: 0...side), y: .random(in: 0...side),
                    width: .random(in: 6...22), height: 0.7))
            }
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }()

    private var grainOverlay: SKSpriteNode?

    private func setupGrainOverlay() {
        guard size.width > 0, size.height > 0 else { return }
        let overlay: SKSpriteNode
        if let existing = grainOverlay, existing.parent === self {
            overlay = existing
        } else {
            overlay = SKSpriteNode(texture: BaseToyScene.linenGrainTexture)
            overlay.name = "linenGrainOverlay"
            overlay.alpha = 0.04
            // Over everything in every toy (Wren tops out ~z260, chrome at z110).
            // It appears in nodes(at:) arrays — current call sites all filter by
            // name/type; never use bare atPoint(_:) in a toy or this sprite wins.
            overlay.zPosition = 4000
            overlay.isUserInteractionEnabled = false
            addChild(overlay)
            grainOverlay = overlay
        }
        overlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        // Cover-fit the square grain to the larger screen edge so it always fills.
        let cover = max(size.width, size.height)
        overlay.size = CGSize(width: cover, height: cover)
    }

    /// Lull lives up to its name: the room quietly warms and dims toward evening,
    /// so play naturally winds down at bedtime. A faint veil sits behind the toys,
    /// so the toys themselves stay vivid while the air around them softens.
    private func addTimeOfDayWarmth(to background: SKNode) {
        let warmth = currentTimeOfDayWarmth()
        guard warmth.alpha > 0 else { return }

        let veil = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        veil.fillColor = warmth.color.withAlpha(warmth.alpha)
        veil.strokeColor = .clear
        veil.position = CGPoint(x: size.width / 2, y: size.height / 2)
        veil.zPosition = 2
        background.addChild(veil)

        // A gentle lower glow, like a warm lamp, grows after dark.
        if warmth.glow > 0 {
            let glow = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height * 0.5))
            glow.fillColor = WarmShelfPalette.butter.withAlpha(warmth.glow)
            glow.strokeColor = .clear
            glow.position = CGPoint(x: size.width / 2, y: size.height * 0.16)
            glow.zPosition = 2.1
            background.addChild(glow)
        }
    }

    private func currentTimeOfDayWarmth() -> (color: UIColor, alpha: CGFloat, glow: CGFloat) {
        // Shared phase so the whole app (shelf + every toy) visibly shifts with the day.
        switch TimeOfDay.phase {
        case .dawn:   return (WarmShelfPalette.petal, 0.06, 0.03)
        case .midday: return (.clear, 0, 0)
        case .dusk:   return (WarmShelfPalette.terracotta, 0.10, 0.06)
        case .night:  return (WarmShelfPalette.cocoa, 0.14, 0.05)
        }
    }

    private func beginObservingAppLifecycleIfNeeded() {
        guard !isObservingAppLifecycle else { return }
        isObservingAppLifecycle = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(resetAmbientTiming),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(resetAmbientTiming),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func resetAmbientTiming() {
        lastUpdateTime = 0
        moteAccumulator = 0
    }

    // MARK: - Ambient sleep

    private func setupAmbientSleep() {
        let voice = toyVoice
        ambientSleepManager.onWake = { [weak self] in
            guard self != nil, voice != .none else { return }
            AudioManager.shared.wakeAmbient(voice)
        }
        ambientSleepManager.onDim = { [weak self] in
            guard self != nil, voice != .none else { return }
            AudioManager.shared.dimAmbient(voice)
        }
        ambientSleepManager.onSleep = { [weak self] in
            guard self != nil, voice != .none else { return }
            AudioManager.shared.sleepAmbient(voice)
        }
    }

    private func installTouchTracker(on view: SKView) {
        if let existing = touchTrackerGR { view.removeGestureRecognizer(existing) }
        let gr = UILongPressGestureRecognizer(target: self, action: #selector(handleAmbientTouch(_:)))
        gr.minimumPressDuration = 0
        gr.cancelsTouchesInView = false
        gr.delaysTouchesBegan = false
        gr.delaysTouchesEnded = false   // CRITICAL: default true would delay/drop touchesEnded to the
                                        // scene → lost releases (the Hum stuck-note root cause, and a
                                        // latent drag-release bug in every toy). Pass releases straight through.
        gr.delegate = self
        view.addGestureRecognizer(gr)
        touchTrackerGR = gr
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true   // the passive ambient tracker must never block scene touches or the parent-gate gesture
    }

    @objc private func handleAmbientTouch(_ gr: UILongPressGestureRecognizer) {
        switch gr.state {
        case .began:
            ambientSleepManager.notifyTouch(at: CACurrentMediaTime())
            // De-emphasise the home handle while the child is busy playing — unless they are
            // actually reaching for it (which arms a return via consumeShelfReturnTouch).
            if !homeReturnArmed, !touchHitsShelfHandle(at: scenePoint(from: gr)) {
                deEmphasizeHomeHandle(true)
            }
        case .changed:
            // If an armed handle touch wanders far, it's a swipe-through, not a tap — cancel it.
            if homeReturnArmed, hypot(scenePoint(from: gr).x - homeReturnStart.x, scenePoint(from: gr).y - homeReturnStart.y) > 24 {
                homeReturnArmed = false
                if let handle = childNode(withName: shelfReturnHandleName) {
                    TouchFeedbackAnimator.softSettle(node: handle, profile: .shelfCard)
                }
            }
        case .ended:
            if homeReturnArmed {
                homeReturnArmed = false
                performShelfReturn()
            } else {
                deEmphasizeHomeHandle(false)
            }
        case .cancelled, .failed:
            homeReturnArmed = false
            deEmphasizeHomeHandle(false)
        default:
            break
        }
    }

    private func scenePoint(from gr: UIGestureRecognizer) -> CGPoint {
        guard let view = gr.view else { return .zero }
        return convertPoint(fromView: gr.location(in: view))
    }

    private func touchHitsShelfHandle(at point: CGPoint) -> Bool {
        guard showsShelfReturnHandle, childNode(withName: shelfReturnHandleName) != nil else { return false }
        return nodes(at: point).contains { node in
            var current: SKNode? = node
            while let unwrapped = current {
                if unwrapped.name == shelfReturnHandleName || unwrapped.name == shelfReturnHitName {
                    return true
                }
                current = unwrapped.parent
            }
            return false
        }
    }

    private func deEmphasizeHomeHandle(_ dim: Bool) {
        guard let handle = childNode(withName: shelfReturnHandleName) else { return }
        if dim {
            handle.removeAction(forKey: "shelfReturnHandlePulse")
            handle.run(.fadeAlpha(to: 0.4, duration: 0.22), withKey: "homeDim")
        } else {
            handle.removeAction(forKey: "homeDim")
            startShelfReturnHandlePulse(on: handle)
        }
    }

    private func performShelfReturn() {
        guard let handle = childNode(withName: shelfReturnHandleName) else { return }
        TouchFeedbackAnimator.acknowledge(node: handle, profile: .shelfCard)
        audioManager.playSoftTap()   // haptic fires inside playSoftTap
        run(.sequence([
            .wait(forDuration: WarmShelfMotion.pop),
            .run { [weak self] in self?.onReturnToShelf?() }
        ]))
    }

    func makeRoundedRect(size: CGSize, radius: CGFloat, fill: UIColor, stroke: UIColor? = nil) -> SKShapeNode {
        let rect = CGRect(origin: CGPoint(x: -size.width / 2, y: -size.height / 2), size: size)
        let node = SKShapeNode(rect: rect, cornerRadius: radius)
        node.fillColor = fill
        node.strokeColor = stroke ?? .clear
        node.lineWidth = stroke == nil ? 0 : 2
        node.lineJoin = .round
        return node
    }

    @discardableResult
    func consumeShelfReturnTouch(at point: CGPoint) -> Bool {
        guard touchHitsShelfHandle(at: point), let handle = childNode(withName: shelfReturnHandleName) else { return false }

        // Arm an intentional tap — navigation fires on a clean tap-up (in handleAmbientTouch),
        // never on a swipe-through. We still consume the touch so play doesn't treat it.
        homeReturnArmed = true
        homeReturnStart = point
        TouchFeedbackAnimator.acknowledge(node: handle, profile: .shelfCard)
        return true
    }

    func accessibilityElements(in view: SKView) -> [UIAccessibilityElement] {
        guard showsShelfReturnHandle, let handle = childNode(withName: shelfReturnHandleName) else { return [] }

        return [
            makeActivatableAccessibilityElement(
                in: view,
                label: "Return to toy shelf",
                scenePosition: CGPoint(x: handle.position.x - 10, y: handle.position.y + 8),
                size: CGSize(width: 104, height: 84),
                traits: .button
            ) { [weak self] in self?.performShelfReturn() }
        ]
    }

    func makeAccessibilityElement(
        in view: SKView,
        label: String,
        scenePosition: CGPoint,
        size elementSize: CGSize,
        traits: UIAccessibilityTraits = .button
    ) -> UIAccessibilityElement {
        makeActivatableAccessibilityElement(
            in: view, label: label, scenePosition: scenePosition,
            size: elementSize, traits: traits, activationHandler: nil
        )
    }

    // MARK: - Responsive layout helpers

    /// Safe-area insets from the hosting view (zero before the view is attached).
    var safeInsets: UIEdgeInsets { view?.safeAreaInsets ?? .zero }

    var isLandscapeLayout: Bool { size.width > size.height }

    /// A rough tablet check from the smaller screen dimension — iPads are much larger than phones.
    var isTabletLayout: Bool { min(size.width, size.height) >= 700 }

    /// The usable play rectangle (scene coords, origin bottom-left): the full scene minus a reserved
    /// top band (status bar + the home-return pebble + any centred menu) and a bottom band (home
    /// indicator). Toys stage their hero objects and controls inside this rect on every device and
    /// orientation. `topReserve`/`bottomReserve` add extra room for a toy's own top/bottom furniture.
    func safePlayRect(topReserve: CGFloat = 0, bottomReserve: CGFloat = 0) -> CGRect {
        let safe = safeInsets
        let landscape = isLandscapeLayout
        let top = max(safe.top, landscape ? 16 : 24) + max(topReserve, landscape ? 46 : 66)
        let bottom = max(safe.bottom, landscape ? 12 : 22) + bottomReserve
        let side = max(safe.left, safe.right, landscape ? 28 : 14)
        let w = size.width - side * 2
        let h = size.height - top - bottom
        return CGRect(x: side, y: bottom, width: max(40, w), height: max(40, h))
    }

    func makeActivatableAccessibilityElement(
        in view: SKView,
        label: String,
        scenePosition: CGPoint,
        size elementSize: CGSize,
        traits: UIAccessibilityTraits = .button,
        activationHandler: (() -> Void)?
    ) -> ActivatableAccessibilityElement {
        let element = ActivatableAccessibilityElement(accessibilityContainer: view)
        element.accessibilityLabel = label
        element.accessibilityTraits = traits
        element.accessibilityFrameInContainerSpace = CGRect(
            x: scenePosition.x - elementSize.width / 2,
            y: size.height - scenePosition.y - elementSize.height / 2,
            width: elementSize.width,
            height: elementSize.height
        )
        element.activationHandler = activationHandler
        return element
    }

    private func layoutShelfReturnHandleIfNeeded() {
        childNode(withName: shelfReturnHandleName)?.removeFromParent()
        guard showsShelfReturnHandle, size.width > 120, size.height > 120 else { return }

        // A little clay home pebble, tucked into the top-left corner so it stays out of the
        // central play column — toddlers stack, grow, and build up the middle of the screen,
        // and a centered control was landing right in that path. It still reads as the one
        // way back to the shelf, and stays generously reachable for small hands and parents.
        let root = SKNode()
        root.name = shelfReturnHandleName
        let safe = view?.safeAreaInsets ?? .zero
        let landscape = size.width > size.height
        let tabWidth: CGFloat = 60
        let leftPadding = max(safe.left + 18 + tabWidth / 2, landscape ? 52 : 42)
        let topPadding = max(landscape ? 40 : 56, safe.top + (landscape ? 26 : 40))
        root.position = CGPoint(x: leftPadding, y: size.height - topPadding)
        root.zPosition = 110

        // Generous, forgiving hit target that reaches into the very corner.
        let hit = SKShapeNode(
            rectOf: CGSize(width: 104, height: 84),
            cornerRadius: 30
        )
        hit.name = shelfReturnHitName
        hit.fillColor = .clear
        hit.strokeColor = .clear
        hit.position = CGPoint(x: -10, y: 8)
        hit.zPosition = 0
        root.addChild(hit)

        let shadow = makeRoundedRect(
            size: CGSize(width: tabWidth, height: 46),
            radius: 22,
            fill: WarmShelfPalette.contactShadow.withAlpha(0.10)
        )
        shadow.position = CGPoint(x: 0, y: -3)
        shadow.zPosition = 0.5
        root.addChild(shadow)

        let tab = makeRoundedRect(
            size: CGSize(width: tabWidth, height: 46),
            radius: 22,
            fill: WarmShelfPalette.warmCream.withAlpha(0.96),
            stroke: WarmShelfPalette.cardBorder.withAlpha(0.6)
        )
        tab.lineWidth = 2
        tab.zPosition = 1
        root.addChild(tab)

        // Soft cream highlight along the top — a hand-shaped clay button, not a flat chip.
        let highlight = makeRoundedRect(
            size: CGSize(width: tabWidth - 18, height: 9),
            radius: 4.5,
            fill: WarmShelfPalette.paperHighlight.withAlpha(0.34)
        )
        highlight.position = CGPoint(x: 0, y: 13)
        highlight.zPosition = 2
        root.addChild(highlight)

        let homePath = CGMutablePath()
        homePath.move(to: CGPoint(x: -16, y: -3))
        homePath.addLine(to: CGPoint(x: 0, y: 11))
        homePath.addLine(to: CGPoint(x: 16, y: -3))
        homePath.move(to: CGPoint(x: -11, y: -2))
        homePath.addLine(to: CGPoint(x: -11, y: -13))
        homePath.addLine(to: CGPoint(x: 11, y: -13))
        homePath.addLine(to: CGPoint(x: 11, y: -2))
        let home = SKShapeNode(path: homePath)
        home.strokeColor = WarmShelfPalette.labelInk.withAlpha(0.82)
        home.fillColor = .clear
        home.lineWidth = 2.8
        home.lineCap = .round
        home.lineJoin = .round
        home.zPosition = 4
        root.addChild(home)

        addChild(root)
        startShelfReturnHandlePulse(on: root)
    }

    private func startShelfReturnHandlePulse(on node: SKNode) {
        node.removeAction(forKey: "shelfReturnHandlePulse")
        // A quiet breath every few seconds — present, never demanding. No directional nudge
        // now that it lives in the corner rather than reading as a centered drawer pull.
        let settle = SKAction.scale(to: 1.0, duration: 0.1)
        let wait = SKAction.wait(forDuration: 3.6)
        let up = SKAction.scale(to: 1.05, duration: 0.34)
        let down = SKAction.scale(to: 1.0, duration: 0.58)
        let glow = SKAction.fadeAlpha(to: 1.0, duration: 0.34)
        let calm = SKAction.fadeAlpha(to: 0.92, duration: 0.58)
        [up, down, glow, calm].forEach { $0.timingMode = .easeInEaseOut }
        node.alpha = 0.92
        node.run(.repeatForever(.sequence([
            settle,
            wait,
            .group([up, glow]),
            .group([down, calm])
        ])), withKey: "shelfReturnHandlePulse")
    }
}

// MARK: - ActivatableAccessibilityElement

/// UIAccessibilityElement subclass that fires a closure when VoiceOver activates the element.
final class ActivatableAccessibilityElement: UIAccessibilityElement {
    var activationHandler: (() -> Void)?

    override func accessibilityActivate() -> Bool {
        guard let handler = activationHandler else { return false }
        handler()
        return true
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
