import SpriteKit

final class HumScene: BaseToyScene {

    // No ambient voice: an instrument must be SILENT until touched. (The old near-silent "clay
    // breathing" bed was audible on some devices and read as "playing sounds without tapping".)
    override var toyVoice: AudioManager.LullSoundVoice { .none }
    override var firstSessionHintKey: String? { "hint.hum" }
    override func firstSessionHintPoint() -> CGPoint {
        objects.first?.position ?? CGPoint(x: size.width * 0.5, y: size.height * 0.52)
    }

    // MARK: - Tuning (just intonation, root C3 ≈ 130 Hz)

    private let humFrequencies: [Double] = [
        130.81, 163.51, 196.22, 229.17,
        261.63, 327.03, 392.44, 523.25
    ]

    // MARK: - Object specs

    private let phoneSpec: [(HumObjectNode.ObjectKind, Int)] = [
        (.disc,   0),   // C3 — low root
        (.blob,   2),   // G3 — fifth
        (.column, 4),   // C4 — octave
        (.disc,   6),   // G4 — upper fifth
        (.pebble, 7),   // C5 — bell octave
    ]

    private let tabletSpec: [(HumObjectNode.ObjectKind, Int)] = [
        (.disc,   0),   // C3
        (.blob,   2),   // G3
        (.column, 4),   // C4
        (.disc,   6),   // G4 — upper fifth
        (.pebble, 1),   // E3
        (.blob,   3),   // Bb3
        (.pebble, 7),   // C5 — upper octave
    ]

    // Normalized positions: oversized note-friends on a toddler xylophone arc.
    private let phonePositions: [CGPoint] = [
        CGPoint(x: 0.21, y: 0.50),
        CGPoint(x: 0.36, y: 0.60),
        CGPoint(x: 0.56, y: 0.52),
        CGPoint(x: 0.77, y: 0.58),
        CGPoint(x: 0.53, y: 0.31),
    ]

    private let tabletPositions: [CGPoint] = [
        CGPoint(x: 0.15, y: 0.53),
        CGPoint(x: 0.30, y: 0.64),
        CGPoint(x: 0.47, y: 0.58),
        CGPoint(x: 0.64, y: 0.66),
        CGPoint(x: 0.81, y: 0.54),
        CGPoint(x: 0.38, y: 0.34),
        CGPoint(x: 0.62, y: 0.34),
    ]

    // MARK: - State

    private var objects: [HumObjectNode] = []
    private var touchToObject: [UITouch: HumObjectNode] = [:]
    private var lastTouchPositions: [UITouch: CGPoint] = [:]
    private var trailAccumulators: [UITouch: CGFloat] = [:]
    private var activeToneIDs: [ObjectIdentifier: String] = [:]
    private var inactiveObserver: NSObjectProtocol?
    private var sustainStartTimes: [ObjectIdentifier: TimeInterval] = [:]
    private let maxSustainSeconds: TimeInterval = 9   // a held note can never outlive this, even if a touch-up is lost
    private var noTouchSince: TimeInterval = 0
    private var lastSilenceSweep: TimeInterval = 0
    private let shimmerLayer = SKNode()
    private let soundFXLayer = SKNode()
    private let glowLayer = SKNode()
    private let instrumentTray = SKShapeNode()
    private let instrumentShadow = SKShapeNode()
    private var touchCaptureRadius: CGFloat { 118 * objectSizeScale }
    private var nearMissRadius: CGFloat { 160 * objectSizeScale }
    private var duetDistance: CGFloat { 152 * objectSizeScale }
    private var choirDistance: CGFloat { 172 * objectSizeScale }
    private var primaryRingRadius: CGFloat { 36 * objectSizeScale }
    private var strumRingRadius: CGFloat { 30 * objectSizeScale }

    // Strum: a finger that isn't holding anyone sweeps across the choir like a harp.
    private var strumTouches: Set<UITouch> = []
    private var lastStrummed: [ObjectIdentifier: TimeInterval] = [:]
    private var lastStrumCheck: [UITouch: TimeInterval] = [:]

    // A warm root+fifth pad that swells the room whenever a friend is being held.
    private var padActive = false
    private let roomPadID = "hum.roompad"
    private var lastHarmonyHeld = -1

    // Soft light behind the choir that brightens with held harmony (Monument-Valley calm).
    private let harmonyGlow = SKShapeNode(circleOfRadius: 1)
    private var objectSizeScale: CGFloat { isTablet ? 1.78 : 1.58 }
    // Bar instrument layout — each bar owns a column; a finger maps to exactly one.
    private var barSlot: CGFloat = 0
    private var barBaseY: CGFloat = 0
    private var barStrikeCount = 0
    private var activePairs: Set<ObjectPair> = []
    private var shimmerLines: [ObjectPair: SKShapeNode] = [:]
    private var activeShimmerIDs = Set<ObjectIdentifier>()
    private var lastChoirMoment: TimeInterval = 0
    private var didPlayOpeningInvitation = false
    private var humHoldTimers: [ObjectIdentifier: Timer] = [:]

    // Wren summoning: hold 3+ objects together for 3 s and the host appears — once a session.
    private var multiHoldTimer: TimeInterval = 0
    private var wrenHasAppeared = false
    private var lastUpdateTime: TimeInterval = 0

    private struct ObjectPair: Hashable {
        let a: ObjectIdentifier
        let b: ObjectIdentifier
        init(_ x: HumObjectNode, _ y: HumObjectNode) {
            let ix = ObjectIdentifier(x)
            let iy = ObjectIdentifier(y)
            a = ix.hashValue < iy.hashValue ? ix : iy
            b = ix.hashValue < iy.hashValue ? iy : ix
        }

        func contains(_ obj: HumObjectNode) -> Bool {
            let id = ObjectIdentifier(obj)
            return a == id || b == id
        }
    }

    private var isTablet: Bool { min(size.width, size.height) >= 700 }

    // MARK: - Tone voices (the clay knob switches the keys' sound)

    /// Three warm instrument voices, switched by one tactile clay knob. Kept to three so it
    /// stays a simple toy, not a synth: a bright music box, soft wood, and clear glass — all
    /// bloom in the shared room reverb, and any of them sound right on the pentatonic bars.
    private struct BarTone {
        let name: String
        let voice: LullToneEngine.Voice
        let gem: UIColor
    }
    private lazy var barTones: [BarTone] = [
        BarTone(name: "musicbox",  voice: LullToneEngine.Voice.celeste.with(body: 0.95, amplitude: 0.115), gem: WarmShelfPalette.butter),
        BarTone(name: "marimba",   voice: LullToneEngine.Voice.marimba.with(body: 0.58, amplitude: 0.15),  gem: WarmShelfPalette.terracotta),
        BarTone(name: "glass",     voice: LullToneEngine.Voice.glass.with(body: 0.95, amplitude: 0.11),    gem: WarmShelfPalette.waterBlue),
        BarTone(name: "bell",      voice: LullToneEngine.Voice.bell.with(body: 0.92, amplitude: 0.1),      gem: WarmShelfPalette.lavender),
        BarTone(name: "woodblock", voice: LullToneEngine.Voice.wood.with(body: 0.5, amplitude: 0.14),      gem: WarmShelfPalette.sage),
        BarTone(name: "pluck",     voice: LullToneEngine.Voice.clay.with(body: 0.44, amplitude: 0.13),     gem: WarmShelfPalette.petal)
    ]
    private var barToneIndex = 0
    private var currentBarTone: BarTone { barTones[barToneIndex % barTones.count] }
    private let toneButton = SKNode()
    private let toneButtonArt = SKNode()
    private weak var toneGem: SKShapeNode?

    // MARK: - Lifecycle

    deinit {
        if let inactiveObserver { NotificationCenter.default.removeObserver(inactiveObserver) }
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        if inactiveObserver == nil {
            inactiveObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.willResignActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in self?.teardownToyAudio() }
        }
        ambientMoteInterval = 1.2
        buildSereneBackdrop()
        glowLayer.name = "humGlowLayer"
        glowLayer.zPosition = 2
        addChild(glowLayer)
        shimmerLayer.name = "shimmerLayer"
        shimmerLayer.zPosition = 30
        addChild(shimmerLayer)
        soundFXLayer.name = "humSoundFXLayer"
        soundFXLayer.zPosition = 70
        addChild(soundFXLayer)
        buildInstrumentTray()
        buildObjects()
        buildToneButton()
        scheduleOpeningInvitation()
    }

    /// A still, Monument-Valley-calm light: a soft warm glow from above and a gentle
    /// harmony halo behind the choir that breathes brighter as friends sing together.
    private func buildSereneBackdrop() {
        let light = SKShapeNode(circleOfRadius: max(size.width, size.height) * 0.6)
        light.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.5)
        light.strokeColor = .clear
        light.blendMode = .alpha
        light.position = CGPoint(x: size.width * 0.5, y: size.height * 0.92)
        light.zPosition = 1
        light.name = "humSoftLight"
        addChild(light)

        harmonyGlow.path = CGPath(ellipseIn: CGRect(x: -size.width * 0.42, y: -size.width * 0.42,
                                                    width: size.width * 0.84, height: size.width * 0.84), transform: nil)
        harmonyGlow.fillColor = WarmShelfPalette.butter.withAlpha(0.16)
        harmonyGlow.strokeColor = .clear
        harmonyGlow.position = CGPoint(x: size.width * 0.5, y: size.height * 0.52)
        harmonyGlow.zPosition = 2
        harmonyGlow.alpha = 0
        glowLayer.addChild(harmonyGlow)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 80, size.height > 80 else { return }
        layoutInstrumentTray()
        remapHomePositions(from: oldSize)
        positionToneButton()
        childNode(withName: "humSoftLight")?.position = CGPoint(x: size.width * 0.5, y: size.height * 0.92)
        harmonyGlow.position = CGPoint(x: size.width * 0.5, y: size.height * 0.52)
    }

    private func buildInstrumentTray() {
        instrumentShadow.name = "humInstrumentShadow"
        instrumentShadow.fillColor = WarmShelfPalette.contactShadow.withAlpha(0.09)
        instrumentShadow.strokeColor = .clear
        instrumentShadow.zPosition = 3
        addChild(instrumentShadow)

        instrumentTray.name = "humInstrumentTray"
        instrumentTray.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.22)
        instrumentTray.strokeColor = WarmShelfPalette.butter.withAlpha(0.18)
        instrumentTray.lineWidth = 1.4
        instrumentTray.zPosition = 4
        addChild(instrumentTray)
        layoutInstrumentTray()
    }

    private func layoutInstrumentTray() {
        let width = min(size.width * (isTablet ? 0.86 : 0.88), isTablet ? 920 : 540)
        let height = min(size.height * 0.46, isTablet ? 470 : 392)
        let radius = min(width, height) * 0.2
        let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)

        instrumentTray.path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        instrumentTray.position = CGPoint(x: size.width * 0.5, y: size.height * (isTablet ? 0.435 : 0.455))

        let shadowRect = rect.insetBy(dx: -8, dy: -7)
        instrumentShadow.path = CGPath(roundedRect: shadowRect, cornerWidth: radius + 6, cornerHeight: radius + 6, transform: nil)
        instrumentShadow.position = CGPoint(x: instrumentTray.position.x, y: instrumentTray.position.y - 13)
    }

    private func buildObjects() {
        objects.forEach { $0.removeFromParent() }
        objects.removeAll()
        touchToObject.removeAll()
        // Stop any still-ringing sustains before dropping their handles, so a rebuild can't orphan a note.
        activeToneIDs.values.forEach { LullToneEngine.shared.stopAmbient(id: $0, fadeOut: 0.1) }
        activeToneIDs.removeAll()
        sustainStartTimes.removeAll()
        activePairs.removeAll()
        shimmerLines.removeAll()
        activeShimmerIDs.removeAll()
        shimmerLayer.removeAllChildren()
        soundFXLayer.removeAllChildren()

        childNode(withName: "humFrame")?.removeFromParent()

        // A tuned row of clay xylophone bars: bottoms aligned on a wooden rail, tops
        // descending left→right, pitched as an ascending C-major pentatonic so any sweep is
        // harmonious. Low = big & warm, high = small & bright.
        let landscape = size.width > size.height
        // 5 big, well-spaced bars on a phone in portrait (6 only fit with no gap); 6 in landscape, 8 on iPad.
        let barCount = isTablet ? 8 : (landscape ? 6 : 5)
        let tints = barTints(count: barCount)
        // Big chunky music bars that fill the width and sit low, close to the child.
        let availableWidth = min(size.width * (isTablet ? 0.84 : 0.82), isTablet ? 900 : 520)
        let slot = availableWidth / CGFloat(barCount)
        let startX = (size.width - availableWidth) / 2 + slot / 2
        let baseY = max(safePlayRect().minY + 26 * (isTablet ? 1.5 : 1.32),
                        size.height * (landscape ? 0.26 : (isTablet ? 0.295 : 0.325)))

        barSlot = slot
        barBaseY = baseY
        addXylophoneFrame(slot: slot, count: barCount, baseY: baseY)

        for i in 0..<barCount {
            let t = barCount > 1 ? CGFloat(i) / CGFloat(barCount - 1) : 0
            let scale = (1.2 - 0.22 * t) * (isTablet ? 1.46 : 1.22)
            let obj = HumObjectNode(kind: .bar, pitchIndex: i, sizeScale: scale, tint: tints[i])
            let home = CGPoint(x: startX + CGFloat(i) * slot, y: baseY + 75 * scale)
            obj.homePosition = home
            obj.position = home
            obj.zPosition = CGFloat(10 + i)
            if ToyArt.texture("hum-bed-topdown") != nil || ToyArt.texture("hum-frame") != nil {
                obj.setShadowStrength(0.18)   // the bed grounds them; no shadow pile-up
            }
            addChild(obj)
            objects.append(obj)
        }

        // Pre-render ONLY the current voice synchronously so the first strike is instant
        // without stalling first render (QA: ~13s cold start in debug builds came from
        // synth-rendering all six voices + sustains on the main thread inside didMove).
        // Other voices and the sustain beds warm in the background a beat after the
        // scene is up; an unwarmed note still renders on demand via play()'s fallback.
        let activeTone = currentBarTone
        for i in 0..<barCount {
            let degree = min(5 + i, 19)
            LullToneEngine.shared.prewarm(.single(degree, activeTone.voice), cacheKey: "hum.bar.\(activeTone.name).\(degree)")
        }
        let deferredTones = barTones.filter { $0.name != activeTone.name }
        let sustainSpecs = objects.map { (id: "hum.sustain.\(toneDegree(for: $0))", spec: humSustainSpec(for: $0)) }
        run(.sequence([.wait(forDuration: 1.2), .run {
            for tone in deferredTones {
                for i in 0..<barCount {
                    let degree = min(5 + i, 19)
                    LullToneEngine.shared.prewarm(.single(degree, tone.voice), cacheKey: "hum.bar.\(tone.name).\(degree)")
                }
            }
            for s in sustainSpecs {
                LullToneEngine.shared.prewarmAmbient(id: s.id, spec: s.spec)
            }
        }]), withKey: "deferredPrewarm")
    }

    /// Warm clay-rainbow across the row — distinct hues so each bar reads as its own note,
    /// never neon (drawn from the shelf palette).
    private func barTints(count: Int) -> [UIColor] {
        let spectrum: [UIColor] = [
            WarmShelfPalette.terracotta, WarmShelfPalette.butter, WarmShelfPalette.sage,
            WarmShelfPalette.waterBlue, WarmShelfPalette.lavender, WarmShelfPalette.petal,
            WarmShelfPalette.rhubarb, WarmShelfPalette.sand
        ]
        return (0..<count).map { spectrum[$0 % spectrum.count] }
    }

    /// A single warm wooden rail the bars rest across — reads instantly as an instrument.
    private func addXylophoneFrame(slot: CGFloat, count: Int, baseY: CGFloat) {
        let frame = SKNode()
        frame.name = "humFrame"
        frame.zPosition = 6
        addChild(frame)

        let width = slot * CGFloat(count) + slot * 0.6

        // The top-down bed (founder, June 11 — perspective law: every asset matches its
        // scene's camera; the bars are seen from above, so their furniture is too).
        // Two honey rails cross the bars near their ends, felt pads beneath.
        // Measured art (fractions of height, from the TOP): rail centers 0.22 / 0.79;
        // end caps live in the outer ~6% per side.
        if let tex = ToyArt.texture("hum-bed-topdown") {
            let art = SKSpriteNode(texture: tex)
            let deviceMul: CGFloat = isTablet ? 1.46 : 1.22
            let typicalBarHeight = 150 * (1.2 - 0.22 * 0.5) * deviceMul
            let bedH = typicalBarHeight * 1.02
            let artWidth = min(width * 1.04, size.width - 8)
            // 9-slice X: the carved end caps keep their shape; only the rail run
            // stretches across however many bars this device shows.
            art.centerRect = CGRect(x: 0.06, y: 0, width: 0.88, height: 1)
            art.size = CGSize(width: artWidth, height: bedH)
            art.position = CGPoint(x: size.width / 2, y: baseY + typicalBarHeight * 0.5)
            frame.addChild(art)
            return
        }

        // Legacy front-view creature frame — superseded by the bed, kept as fallback.
        if let tex = ToyArt.texture("hum-frame") {
            let art = SKSpriteNode(texture: tex)
            let deviceMul: CGFloat = isTablet ? 1.46 : 1.22
            let typicalBarHeight = 150 * (1.2 - 0.22 * 0.5) * deviceMul
            let railTopFrac: CGFloat = 0.42
            let windowFrac: CGFloat = 0.36
            let railTuck: CGFloat = 6
            let idealHeight = (typicalBarHeight * 0.5 + railTuck) / windowFrac
            let height = min(idealHeight, (baseY - railTuck) / (railTopFrac - 0.05))
            let artWidth = min(width, size.width - 8)
            // 9-slice: the dot-eyed scroll ends keep their proportions; only the slat
            // band stretches across however many bars this device shows.
            art.centerRect = CGRect(x: 0.18, y: 0, width: 0.64, height: 1)
            art.size = CGSize(width: artWidth, height: height)
            art.position = CGPoint(x: size.width / 2,
                                   y: baseY - railTuck + (0.5 - railTopFrac) * height)
            frame.addChild(art)
            return   // the art bakes its own grounding shadow
        }

        let railY = baseY + 18

        // A soft shadow beneath the rail grounds the whole instrument.
        let railShadow = SKShapeNode(rect: CGRect(x: -width / 2, y: -20, width: width, height: 30), cornerRadius: 15)
        railShadow.fillColor = WarmShelfPalette.contactShadow.withAlpha(0.12)
        railShadow.strokeColor = .clear
        railShadow.position = CGPoint(x: size.width / 2, y: railY - 6)
        frame.addChild(railShadow)

        let rail = SKShapeNode(rect: CGRect(x: -width / 2, y: -17, width: width, height: 34), cornerRadius: 17)
        rail.fillColor = WarmShelfPalette.sand
        rail.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.12)
        rail.lineWidth = 1.5
        rail.position = CGPoint(x: size.width / 2, y: railY)
        frame.addChild(rail)
        ProceduralTexture.applyClayFill(to: rail, base: WarmShelfPalette.sand, size: CGSize(width: width, height: 34))

        let shade = SKShapeNode(rect: CGRect(x: -width / 2, y: -17, width: width, height: 9), cornerRadius: 4.5)
        shade.fillColor = WarmShelfPalette.cocoa.withAlpha(0.09)
        shade.strokeColor = .clear
        shade.position = CGPoint(x: size.width / 2, y: railY - 4)
        frame.addChild(shade)

        let highlight = SKShapeNode(rect: CGRect(x: -width / 2 + 8, y: 9, width: width - 16, height: 4), cornerRadius: 2)
        highlight.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.5)
        highlight.strokeColor = .clear
        highlight.position = CGPoint(x: size.width / 2, y: railY)
        frame.addChild(highlight)

        // Chunky wooden end caps so the rail reads as a real instrument.
        for sx in [-1, 1] {
            let cap = SKShapeNode(circleOfRadius: 21)
            cap.fillColor = WarmShelfPalette.sand
            cap.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.14)
            cap.lineWidth = 1.5
            cap.position = CGPoint(x: size.width / 2 + CGFloat(sx) * width / 2, y: railY)
            frame.addChild(cap)
            let capHi = SKShapeNode(circleOfRadius: 7)
            capHi.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.4); capHi.strokeColor = .clear
            capHi.position = CGPoint(x: cap.position.x - 4, y: cap.position.y + 4)
            frame.addChild(capHi)
        }
    }

    private func remapHomePositions(from oldSize: CGSize) {
        // Bars are a structured row, so re-lay the whole instrument for the new canvas.
        buildObjects()
    }

    // MARK: - Tone knob (switch the keys' voice)

    /// A little hand-shaped clay-and-wood knob that rests by the instrument, like a small
    /// thing left on a tray. Pressing it switches the voice of every bar. A coloured gem on
    /// top shifts hue with each press, so the change is something a toddler can *see* as well
    /// as hear. It is quiet and out of the way — never competing with the bars.
    private func buildToneButton() {
        toneButton.removeFromParent()
        toneButton.removeAllChildren()
        toneButtonArt.removeAllChildren()
        toneButton.name = "humToneButton"
        toneButton.zPosition = 9
        toneButton.addChild(toneButtonArt)

        let shadow = SKShapeNode(ellipseOf: CGSize(width: 56, height: 18))
        shadow.fillColor = WarmShelfPalette.contactShadow.withAlpha(0.12)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -23)
        shadow.zPosition = -1
        toneButtonArt.addChild(shadow)

        let baseRect = CGRect(x: -25, y: -25, width: 50, height: 50)
        let base = SKShapeNode(circleOfRadius: 25)
        base.fillColor = WarmShelfPalette.sand.withAlpha(0.97)
        base.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.12)
        base.lineWidth = 1.5
        toneButtonArt.addChild(base)
        ProceduralTexture.addMatteClayDepth(
            to: base, ellipse: baseRect.size, zPosition: 0.1,
            highlightAlpha: 0.26, shadeAlpha: 0.06, rimAlpha: 0.04, speckleCount: 3
        )

        // A soft cradle ring so the gem reads as set into the clay.
        let cradle = SKShapeNode(circleOfRadius: 15)
        cradle.fillColor = WarmShelfPalette.cocoa.withAlpha(0.10)
        cradle.strokeColor = .clear
        cradle.zPosition = 1
        toneButtonArt.addChild(cradle)

        let gem = SKShapeNode(circleOfRadius: 13)
        gem.fillColor = currentBarTone.gem
        gem.strokeColor = WarmShelfPalette.paperHighlight.withAlpha(0.42)
        gem.lineWidth = 1
        gem.zPosition = 2
        toneButtonArt.addChild(gem)
        toneGem = gem

        let glint = SKShapeNode(circleOfRadius: 3.4)
        glint.fillColor = UIColor.white.withAlpha(0.6)
        glint.strokeColor = .clear
        glint.position = CGPoint(x: -3.8, y: 4.2)
        glint.zPosition = 3
        gem.addChild(glint)

        addChild(toneButton)
        positionToneButton()
    }

    private func positionToneButton() {
        guard toneButton.parent != nil else { return }
        let scale: CGFloat = isTablet ? 1.34 : 1.04
        toneButton.setScale(scale)
        // Just below the wooden rail, centred — sitting on the instrument's stand, clear of
        // the bars themselves so a strike and a knob-press never get confused.
        toneButton.position = CGPoint(x: size.width * 0.5, y: barBaseY - 46 * scale)
    }

    private func toneButtonContains(_ point: CGPoint) -> Bool {
        guard toneButton.parent != nil else { return false }
        let radius = 40 * toneButton.xScale   // generous, forgiving toddler target
        return hypot(point.x - toneButton.position.x, point.y - toneButton.position.y) < radius
    }

    private func cycleToneVoice() {
        barToneIndex = (barToneIndex + 1) % barTones.count
        let tone = currentBarTone

        // Physical clay press: a quick squash in, a slower ease back out (quick-to-wake,
        // slow-to-settle — Lull's asymmetry law made tactile).
        toneButtonArt.removeAction(forKey: "press")
        let press = SKAction.scale(to: 0.84, duration: 0.07); press.timingMode = .easeOut
        let settle = SKAction.scale(to: 1.0, duration: 0.34); settle.timingMode = .easeInEaseOut
        toneButtonArt.run(.sequence([press, settle]), withKey: "press")

        // The gem takes on the new voice's colour with a tiny pop.
        toneGem?.fillColor = tone.gem
        toneGem?.removeAction(forKey: "gemPop")
        toneGem?.run(.sequence([
            .scale(to: 1.22, duration: 0.10),
            .scale(to: 1.0, duration: 0.22)
        ]), withKey: "gemPop")

        HapticsManager.shared.play(score: .toneSwitch)
        if AudioManager.shared.isEnabled {
            // A soft wooden "tok" for the press itself.
            LullToneEngine.shared.play(
                .single(2, LullToneEngine.Voice.clay.with(body: 0.18, amplitude: 0.13)),
                cacheKey: "hum.knob.press"
            )
        }

        // The instrument answers in its new voice: bars pulse left→right and the middle one
        // sings a single soft preview note, so the child hears the change without a fanfare.
        let order = objects.sorted { $0.position.x < $1.position.x }
        for (i, bar) in order.enumerated() {
            bar.run(.sequence([
                .wait(forDuration: Double(i) * 0.035),
                .run { [weak bar] in bar?.playSoundPulse(intensity: 0.5) }
            ]))
        }
        // A short ascending preview phrase in the NEW voice — the change is unmistakable & satisfying.
        if !order.isEmpty {
            let picks = [0, order.count / 2, order.count - 1]
            for (j, idx) in picks.enumerated() where idx < order.count {
                let bar = order[idx]
                run(.sequence([.wait(forDuration: 0.1 + Double(j) * 0.13), .run { [weak self, weak bar] in
                    guard let self, let bar else { return }
                    self.spawnSoundRing(at: bar.position, color: tone.gem, radius: self.primaryRingRadius * 0.7)
                    bar.playSoundPulse(intensity: 0.7)
                    self.playHumOnset(for: bar)
                }]))
            }
        }
    }

    private func scheduleOpeningInvitation() {
        guard !didPlayOpeningInvitation, !objects.isEmpty else { return }
        didPlayOpeningInvitation = true
        run(.sequence([.wait(forDuration: 0.72), .run { [weak self] in
            self?.playOpeningInvitation()
        }]))
    }

    private func playOpeningInvitation() {
        guard touchToObject.isEmpty else { return }
        for (index, obj) in objects.prefix(2).enumerated() {
            let delay = Double(index) * 0.34
            obj.playInvitePreview(after: delay)
            run(.sequence([.wait(forDuration: delay), .run { [weak self, weak obj] in
                guard let self, let obj, self.touchToObject.isEmpty else { return }
                self.spawnSoundRing(at: obj.position, color: obj.objectColor, radius: self.primaryRingRadius * 0.92)
                self.playHumOnset(for: obj)
            }]))
        }
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        HapticsManager.shared.prepareForTouch()
        for touch in touches {
            let point = touch.location(in: self)
            if touchToObject.isEmpty, consumeShelfReturnTouch(at: point) { return }

            // The clay knob switches the instrument's voice — checked before striking so a
            // tap on it never also rings a bar.
            if toneButtonContains(point) {
                cycleToneVoice()
                continue
            }

            // A xylophone: a touch STRIKES the one bar under the finger. Bars never move.
            if let bar = barUnderFinger(point) {
                strikeBar(bar, for: touch)
            } else {
                TouchFeedbackAnimator.emptyTap(in: self, at: point)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let current = touchToObject[touch] else { continue }
            guard let bar = barUnderFinger(touch.location(in: self)), bar !== current else { continue }
            // A glissando releases this finger's ownership; another finger may still hold the bar.
            releaseObject(for: touch)
            strikeBar(bar, for: touch)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { releaseObject(for: touch); endStrum(touch) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { releaseObject(for: touch); endStrum(touch) }
    }

    private func endStrum(_ touch: UITouch) {
        strumTouches.remove(touch)
        lastStrumCheck.removeValue(forKey: touch)
    }

    /// Strike one bar: it wakes, bounces, and rings out. No sustained drone, no dragging —
    /// a xylophone, not a held object.
    private func strikeBar(_ bar: HumObjectNode, for touch: UITouch) {
        let alreadyHeld = touchToObject.values.contains { $0 === bar }
        touchToObject[touch] = bar
        bar.noticeAndHold()
        bar.playSoundPulse(intensity: 1.1)
        spawnSoundRing(at: bar.position, color: bar.objectColor, radius: primaryRingRadius)
        playHumOnset(for: bar)
        if !alreadyHeld {
            startSustainedTone(for: bar)
            startHeldSparkle(for: bar)
        }
        HapticsManager.shared.softTap()

        // Subtle pizazz: soft note-motes lift off, neighbours gently resonate, and once in a
        // while a little extra flourish surprises — never loud, always calm.
        let liftPoint = CGPoint(x: bar.position.x, y: bar.position.y + 46)
        spawnNoteMotes(at: liftPoint, color: bar.objectColor, count: 4)   // a lively spray on each strike / sweep
        spawnSoundRing(at: liftPoint, color: bar.objectColor.withAlpha(0.6), radius: strumRingRadius * 0.8)
        resonateNeighbors(of: bar)
        barStrikeCount += 1
        if Int.random(in: 0..<7) == 0 {
            spawnNoteMotes(at: liftPoint, color: bar.objectColor, count: 5)
            spawnSoundRing(at: bar.position, color: WarmShelfPalette.paperHighlight, radius: primaryRingRadius * 1.3)
        }
    }

    /// A couple of soft note-motes lift off a struck bar and fade — quiet sparkle, not confetti.
    private func spawnNoteMotes(at point: CGPoint, color: UIColor, count: Int) {
        guard !AmbientAnimator.reduceMotion else { return }
        for _ in 0..<count {
            let mote = SKShapeNode(circleOfRadius: CGFloat.random(in: 2.0...3.6))
            mote.fillColor = color.withAlpha(0.5)
            mote.strokeColor = .clear
            mote.position = point
            mote.zPosition = 60
            soundFXLayer.addChild(mote)
            let drift = SKAction.moveBy(
                x: CGFloat.random(in: -18...18),
                y: CGFloat.random(in: 42...82),
                duration: Double.random(in: 0.9...1.4)
            )
            drift.timingMode = .easeOut
            mote.run(.sequence([
                .group([drift, .fadeOut(withDuration: 1.25), .scale(to: 0.6, duration: 1.25)]),
                .removeFromParent()
            ]))
        }
    }

    /// A struck bar nudges its immediate neighbours — the row feels connected and alive.
    private func resonateNeighbors(of bar: HumObjectNode) {
        for other in objects where other !== bar && abs(other.pitchIndex - bar.pitchIndex) == 1 {
            other.playSoundPulse(intensity: 0.28)
        }
    }

    /// The single bar a finger is over — nearest by column, within the instrument band.
    private func barUnderFinger(_ point: CGPoint) -> HumObjectNode? {
        guard point.y > barBaseY - 80, point.y < barBaseY + 240 else { return nil }
        var best: HumObjectNode?
        var bestDX = max(barSlot * 0.62, 40)
        for bar in objects {
            let dx = abs(bar.position.x - point.x)
            if dx < bestDX { best = bar; bestDX = dx }
        }
        return best
    }

    // MARK: - Strum (harp sweep)

    /// As a free finger sweeps, each friend it passes over sings a bright pluck in turn.
    private func strumSweep(touch: UITouch) {
        let point = touch.location(in: self)
        let now = lastUpdateTime
        let strumRadius = 74 * objectSizeScale
        for obj in objects {
            if touchToObject.values.contains(where: { $0 === obj }) { continue }
            let d = hypot(obj.position.x - point.x, obj.position.y - point.y)
            guard d < strumRadius else { continue }
            let id = ObjectIdentifier(obj)
            if let last = lastStrummed[id], now - last < 0.34 { continue }   // one pluck per pass
            lastStrummed[id] = now
            obj.strum()
            spawnSoundRing(at: obj.position, color: obj.objectColor, radius: strumRingRadius)
            playHumOnset(for: obj)
            HapticsManager.shared.softTap()
        }
    }

    private func releaseObject(for touch: UITouch) {
        guard let obj = touchToObject.removeValue(forKey: touch) else { return }
        lastTouchPositions.removeValue(forKey: touch)
        trailAccumulators.removeValue(forKey: touch)
        guard !touchToObject.values.contains(where: { $0 === obj }) else { return }

        stopSustainedTone(for: obj)
        stopHeldSparkle(for: obj)
        playHumRelease(for: obj)
        activePairs = activePairs.filter { !$0.contains(obj) }
        obj.settleHome()
    }

    private func nearestFreeObject(at point: CGPoint) -> HumObjectNode? {
        objects
            .filter { obj in
                !touchToObject.values.contains(where: { $0 === obj })
                && hypot(obj.position.x - point.x, obj.position.y - point.y) < touchCaptureRadius
            }
            .min(by: { a, b in
                hypot(a.position.x - point.x, a.position.y - point.y) <
                hypot(b.position.x - point.x, b.position.y - point.y)
            })
    }

    private func nearestObject(at point: CGPoint, within radius: CGFloat) -> HumObjectNode? {
        objects
            .filter { hypot($0.position.x - point.x, $0.position.y - point.y) < radius }
            .min(by: { a, b in
                hypot(a.position.x - point.x, a.position.y - point.y) <
                hypot(b.position.x - point.x, b.position.y - point.y)
            })
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        lastUpdateTime = currentTime
        // A clean instrument: no shimmer-lines, room drone, choir, or Wren-summon — just a
        // soft glow that warms while a bar is held.
        updateHarmonyGlow(heldCount: objects.filter { $0.isHeld }.count)

        // Absolute silence guarantee: if NO fingers are down for 2 s, sweep every possible sustain
        // channel — kills any zombie the bookkeeping lost track of, regardless of cause.
        if touchToObject.isEmpty {
            if noTouchSince == 0 { noTouchSince = currentTime }
            if currentTime - noTouchSince > 2.0, currentTime - lastSilenceSweep > 2.0 {
                lastSilenceSweep = currentTime
                for degree in 5...19 { LullToneEngine.shared.stopAmbient(id: "hum.sustain.\(degree)", fadeOut: 0.4) }
            }
        } else {
            noTouchSince = 0
        }

        // Safety net: a sustained note must never outlive the finger holding it. Stop any sustain
        // whose bar is no longer under a touch (a release/cancel that slipped through, a glissando
        // orphan, a rebuild) — and HARD-CAP every sustain so even a lost touch-up (the stuck-touch
        // bug) can't ring a note forever; a capped note also forgets its stuck touch so it plays again.
        if !activeToneIDs.isEmpty {
            let heldIDs = Set(touchToObject.values.map { ObjectIdentifier($0) })
            for (id, toneID) in activeToneIDs {
                let held = heldIDs.contains(id)
                let aged = currentTime - (sustainStartTimes[id] ?? currentTime) > maxSustainSeconds
                guard !held || aged else { continue }
                LullToneEngine.shared.stopAmbient(id: toneID, fadeOut: 0.3)
                activeToneIDs.removeValue(forKey: id)
                sustainStartTimes.removeValue(forKey: id)
                if aged {
                    for (t, b) in touchToObject where ObjectIdentifier(b) == id { touchToObject.removeValue(forKey: t) }
                    if let bar = objects.first(where: { ObjectIdentifier($0) == id }) { bar.settleHome(); stopHeldSparkle(for: bar) }
                }
            }
        }
    }

    override func teardownToyAudio() {
        super.teardownToyAudio()
        LullToneEngine.shared.stopAmbient(id: roomPadID, fadeOut: 0.4)
        // Called before the hosting view pauses, on scene removal, and when the app becomes inactive.
        activeToneIDs.values.forEach { LullToneEngine.shared.stopAmbient(id: $0, fadeOut: 0.2) }
        activeToneIDs.removeAll()
        sustainStartTimes.removeAll()
        humHoldTimers.values.forEach { $0.invalidate() }
        humHoldTimers.removeAll()
        touchToObject.removeAll()
        lastTouchPositions.removeAll()
        trailAccumulators.removeAll()
        strumTouches.removeAll()
        lastStrumCheck.removeAll()
        activePairs.removeAll()
        for obj in objects {
            stopHeldSparkle(for: obj)
            if obj.isHeld { obj.settleHome() }
        }
        harmonyGlow.alpha = 0
        noTouchSince = 0
        padActive = false
    }

    /// A warm root+fifth pad fades the whole room into harmony while anyone is held.
    private func updateRoomPad(heldCount: Int) {
        if heldCount > 0 && !padActive {
            padActive = true
            guard AudioManager.shared.isEnabled else { return }
            let pad = LullToneEngine.AmbientSpec(
                frequency: 65.41,                                   // C2 root
                partials: [(1, 0.6), (1.5, 0.4), (2, 0.32), (3, 0.12), (4, 0.05)],
                noiseGain: 0.02, lfoHz: 0.07, lfoDepth: 0.22,
                amplitude: 0.03, duration: 8
            )
            LullToneEngine.shared.playAmbient(id: roomPadID, spec: pad, volume: 0.5, fadeIn: 1.6)
        } else if heldCount == 0 && padActive {
            padActive = false
            LullToneEngine.shared.stopAmbient(id: roomPadID, fadeOut: 2.2)
        }
    }

    private func updateHarmonyGlow(heldCount: Int) {
        guard heldCount != lastHarmonyHeld else { return }
        lastHarmonyHeld = heldCount
        let target: CGFloat = heldCount == 0 ? 0 : min(0.34, 0.12 + 0.11 * CGFloat(heldCount))
        let fade = SKAction.fadeAlpha(to: target, duration: 0.9)
        fade.timingMode = .easeInEaseOut
        harmonyGlow.run(fade, withKey: "glow")
    }

    // MARK: - Wren summoning

    private func summonWren() {
        let host = LullHostNode(scale: 0.6)
        host.position = CGPoint(x: size.width / 2, y: -150)
        host.zPosition = 200
        addChild(host)

        let center = CGPoint(x: size.width / 2, y: size.height * 0.52)
        let floatUp = SKAction.move(to: center, duration: 1.4)
        floatUp.timingMode = .easeOut

        let heldCentroid = centerPoint(of: objects.filter { $0.isHeld })

        host.run(.sequence([
            floatUp,
            .wait(forDuration: 0.3),
            .run { [weak host] in
                guard let host else { return }
                // Full giggle (eyes wide, cheeks bloom, triple bob, capstone spin) that also
                // leans and looks toward the cluster of objects the child is holding.
                host.giggle(at: heldCentroid)
                AudioManager.shared.playMixCelebrationCombo()
            },
            .wait(forDuration: 2.2),
            .run { [weak host] in
                guard let host else { return }
                let shrink = SKAction.scale(to: 0, duration: 1.8)
                let rise = SKAction.moveBy(x: 0, y: 240, duration: 1.8)
                shrink.timingMode = .easeIn
                rise.timingMode = .easeIn
                host.run(.sequence([
                    .group([shrink, rise]),
                    .removeFromParent()
                ]))
            },
            .wait(forDuration: 1.8),
            .run { [weak self] in
                // wrenHasAppeared stays true: this is a once-per-session moment.
                self?.multiHoldTimer = 0
            }
        ]), withKey: "hum.summonWren")
    }

    // MARK: - Shimmer

    private func updateShimmerEffect(currentTime: TimeInterval) {
        let held = Array(touchToObject.values)
        guard !held.isEmpty else {
            stopActiveShimmers()
            activePairs.removeAll()
            // Remove all cached lines on full release.
            shimmerLines.values.forEach { $0.removeFromParent() }
            shimmerLines.removeAll()
            return
        }

        var inPair = Set<ObjectIdentifier>()
        var pairsThisFrame = Set<ObjectPair>()

        for a in held {
            for b in objects where b !== a {
                let pair = ObjectPair(a, b)
                guard !pairsThisFrame.contains(pair) else { continue }
                let d = hypot(a.position.x - b.position.x,
                              a.position.y - b.position.y)
                guard d < duetDistance else { continue }

                inPair.insert(ObjectIdentifier(a))
                inPair.insert(ObjectIdentifier(b))
                pairsThisFrame.insert(pair)
                a.startShimmer()
                b.startShimmer()
                if !activePairs.contains(pair) {
                    a.playDuetPulse()
                    b.playDuetPulse()
                    spawnDuetBloom(between: a, and: b)
                    playHumDuet(a, b)
                    HapticsManager.shared.softTap()
                }

                let closeness = max(0, 1 - d / duetDistance)
                let mid = CGPoint(x: (a.position.x + b.position.x) * 0.5,
                                  y: (a.position.y + b.position.y) * 0.5)
                let control = CGPoint(x: mid.x, y: mid.y + 8 * sin(CGFloat(pair.a.hashValue % 11)))
                let path = CGMutablePath()
                path.move(to: a.position)
                path.addQuadCurve(to: b.position, control: control)

                if let line = shimmerLines[pair] {
                    // Reuse: update properties in place (no rasterisation thrash).
                    line.path = path
                    line.strokeColor = WarmShelfPalette.butter.withAlpha(0.22 + 0.22 * closeness)
                    line.lineWidth = 1.6 + 2.2 * closeness
                    line.glowWidth = 2.0 + 3.5 * closeness
                } else {
                    let line = SKShapeNode(path: path)
                    line.strokeColor = WarmShelfPalette.butter.withAlpha(0.22 + 0.22 * closeness)
                    line.lineWidth = 1.6 + 2.2 * closeness
                    line.glowWidth = 2.0 + 3.5 * closeness
                    shimmerLayer.addChild(line)
                    shimmerLines[pair] = line
                }
            }
        }

        // Remove lines for pairs that disappeared this frame.
        for (pair, line) in shimmerLines where !pairsThisFrame.contains(pair) {
            line.removeFromParent()
            shimmerLines.removeValue(forKey: pair)
        }

        for obj in objects {
            let id = ObjectIdentifier(obj)
            if activeShimmerIDs.contains(id), !inPair.contains(id) {
                obj.stopShimmer()
            }
        }
        activeShimmerIDs = inPair
        activePairs = pairsThisFrame
        evaluateChoir(held: held, currentTime: currentTime)
    }

    private func stopActiveShimmers() {
        for obj in objects where activeShimmerIDs.contains(ObjectIdentifier(obj)) {
            obj.stopShimmer()
        }
        activeShimmerIDs.removeAll()
    }

    private func evaluateChoir(held: [HumObjectNode], currentTime: TimeInterval) {
        guard currentTime - lastChoirMoment > 2.4 else { return }
        for anchor in held {
            let neighbors = objects
                .filter { $0 !== anchor }
                .map { obj -> (obj: HumObjectNode, distance: CGFloat) in
                    let d = hypot(anchor.position.x - obj.position.x, anchor.position.y - obj.position.y)
                    return (obj, d)
                }
                .filter { $0.distance < choirDistance }
                .sorted { $0.distance < $1.distance }
            guard neighbors.count >= 2 else { continue }

            let trio = [anchor, neighbors[0].obj, neighbors[1].obj]
            guard maxDistance(in: trio) < choirDistance else { continue }

            lastChoirMoment = currentTime
            let center = centerPoint(of: trio)
            spawnChoirBloom(at: center, objects: trio)
            playHumChoir(trio)
            for (index, obj) in trio.enumerated() {
                obj.playChoirPulse(delay: Double(index) * 0.055)
            }
            HapticsManager.shared.celebration()
            return
        }
    }

    private func maxDistance(in objects: [HumObjectNode]) -> CGFloat {
        var maxD: CGFloat = 0
        for i in 0..<objects.count {
            for j in (i + 1)..<objects.count {
                let a = objects[i], b = objects[j]
                maxD = max(maxD, hypot(a.position.x - b.position.x, a.position.y - b.position.y))
            }
        }
        return maxD
    }

    private func centerPoint(of objects: [HumObjectNode]) -> CGPoint {
        guard !objects.isEmpty else { return CGPoint(x: size.width / 2, y: size.height / 2) }
        let sum = objects.reduce(CGPoint.zero) { acc, obj in
            CGPoint(x: acc.x + obj.position.x, y: acc.y + obj.position.y)
        }
        return CGPoint(x: sum.x / CGFloat(objects.count), y: sum.y / CGFloat(objects.count))
    }

    // MARK: - Trail motes

    private func spawnTrailMote(at point: CGPoint, color: UIColor) {
        let mote = SKShapeNode(circleOfRadius: .random(in: 3...5))
        mote.fillColor = color.withAlpha(0.35)
        mote.strokeColor = .clear
        mote.position = point
        mote.zPosition = 50
        addChild(mote)

        let drift = SKAction.moveBy(x: .random(in: -8...8), y: 20, duration: 1.8)
        let fade  = SKAction.fadeOut(withDuration: 1.8)
        drift.timingMode = .easeOut
        mote.run(.sequence([.group([drift, fade]), .removeFromParent()]))
    }

    private func spawnSoundRing(at point: CGPoint, color: UIColor, radius: CGFloat) {
        guard !AmbientAnimator.reduceMotion else { return }
        let root = SKNode()
        root.position = point
        soundFXLayer.addChild(root)

        for index in 0..<2 {
            let ring = SKShapeNode(circleOfRadius: radius)
            ring.fillColor = .clear
            ring.strokeColor = color.withAlpha(index == 0 ? 0.42 : 0.24)
            ring.lineWidth = index == 0 ? 3.0 : 1.8
            ring.glowWidth = index == 0 ? 3.5 : 1.5
            ring.setScale(0.34)
            ring.alpha = 0.94
            root.addChild(ring)

            let wait = SKAction.wait(forDuration: Double(index) * 0.10)
            let expand = SKAction.group([
                .scale(to: index == 0 ? 1.18 : 1.36, duration: 0.64),
                .fadeOut(withDuration: 0.64)
            ])
            expand.timingMode = .easeOut
            ring.run(.sequence([wait, expand]))
        }

        root.run(.sequence([.wait(forDuration: 0.86), .removeFromParent()]))
    }

    private func spawnListeningRipple(at point: CGPoint) {
        guard !AmbientAnimator.reduceMotion else { return }
        let ripple = SKShapeNode(circleOfRadius: 20)
        ripple.fillColor = .clear
        ripple.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.18)
        ripple.lineWidth = 2.0
        ripple.position = point
        ripple.zPosition = 75
        soundFXLayer.addChild(ripple)
        let expand = SKAction.group([
            .scale(to: 1.8, duration: 0.52),
            .fadeOut(withDuration: 0.52)
        ])
        expand.timingMode = .easeOut
        ripple.run(.sequence([expand, .removeFromParent()]))
    }

    private func spawnDuetBloom(between a: HumObjectNode, and b: HumObjectNode) {
        guard !AmbientAnimator.reduceMotion else { return }
        let mid = CGPoint(x: (a.position.x + b.position.x) * 0.5,
                          y: (a.position.y + b.position.y) * 0.5)
        let root = SKNode()
        root.position = mid
        soundFXLayer.addChild(root)

        let halo = SKShapeNode(circleOfRadius: 24)
        halo.fillColor = WarmShelfPalette.butter.withAlpha(0.18)
        halo.strokeColor = WarmShelfPalette.paperHighlight.withAlpha(0.38)
        halo.lineWidth = 1.2
        halo.setScale(0.3)
        root.addChild(halo)
        let bloom = SKAction.group([
            .scale(to: 1.25, duration: 0.52),
            .fadeOut(withDuration: 0.52)
        ])
        bloom.timingMode = .easeOut
        halo.run(bloom)

        for index in 0..<5 {
            let mote = SKShapeNode(circleOfRadius: CGFloat.random(in: 2.4...4.0))
            mote.fillColor = (index.isMultiple(of: 2) ? a.objectColor : b.objectColor).withAlpha(0.42)
            mote.strokeColor = .clear
            root.addChild(mote)
            let angle = CGFloat(index) / 5.0 * .pi * 2 + CGFloat.random(in: -0.22...0.22)
            let distance = CGFloat.random(in: 18...34)
            let drift = SKAction.moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: 0.72)
            let fade = SKAction.fadeOut(withDuration: 0.72)
            drift.timingMode = .easeOut
            mote.run(.sequence([.group([drift, fade]), .removeFromParent()]))
        }

        root.run(.sequence([.wait(forDuration: 0.82), .removeFromParent()]))
    }

    private func spawnChoirBloom(at point: CGPoint, objects: [HumObjectNode]) {
        guard !AmbientAnimator.reduceMotion else { return }
        let root = SKNode()
        root.position = point
        soundFXLayer.addChild(root)

        for index in 0..<3 {
            let halo = SKShapeNode(circleOfRadius: 52 + CGFloat(index) * 18)
            halo.fillColor = index == 0 ? WarmShelfPalette.paperHighlight.withAlpha(0.11) : .clear
            halo.strokeColor = WarmShelfPalette.butter.withAlpha(0.24 - CGFloat(index) * 0.045)
            halo.lineWidth = 2.0
            halo.glowWidth = 4.0
            halo.setScale(0.28)
            root.addChild(halo)
            let wait = SKAction.wait(forDuration: Double(index) * 0.10)
            let expand = SKAction.group([
                .scale(to: 1.16, duration: 1.05),
                .fadeOut(withDuration: 1.05)
            ])
            expand.timingMode = .easeOut
            halo.run(.sequence([wait, expand]))
        }

        for index in 0..<12 {
            let mote = SKShapeNode(circleOfRadius: CGFloat.random(in: 2.6...5.2))
            let color = objects[index % max(objects.count, 1)].objectColor
            mote.fillColor = color.withAlpha(0.36)
            mote.strokeColor = .clear
            root.addChild(mote)
            let angle = CGFloat(index) / 12.0 * .pi * 2 + CGFloat.random(in: -0.16...0.16)
            let distance = CGFloat.random(in: 42...82)
            let drift = SKAction.moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: 1.18)
            let fade = SKAction.fadeOut(withDuration: 1.18)
            drift.timingMode = .easeOut
            mote.run(.sequence([.group([drift, fade]), .removeFromParent()]))
        }

        root.run(.sequence([.wait(forDuration: 1.32), .removeFromParent()]))
    }

    // MARK: - Tone playback

    private func playHumOnset(for obj: HumObjectNode) {
        guard AudioManager.shared.isEnabled else { return }
        let degree = toneDegree(for: obj)
        if obj.kind == .bar {
            // One clean, pre-rendered note per strike in the chosen voice — lush in the reverb.
            let tone = currentBarTone
            LullToneEngine.shared.play(.single(degree, tone.voice), cacheKey: "hum.bar.\(tone.name).\(degree)")
            return
        }
        let upper = min(degree + 2, 19)
        let spec = LullToneEngine.Spec.arp([degree, upper], step: 0.055, humAttackVoice(for: obj))
        LullToneEngine.shared.play(spec, cacheKey: "hum.onset.\(humKindName(obj.kind)).\(obj.pitchIndex)")
    }

    private func playHumNearMiss(for obj: HumObjectNode) {
        guard AudioManager.shared.isEnabled else { return }
        let degree = min(toneDegree(for: obj) + 1, 19)
        let voice = LullToneEngine.Voice.breath.with(body: 0.20, amplitude: 0.060, noiseGain: 0.36)
        LullToneEngine.shared.play(.single(degree, voice), cacheKey: "hum.near.\(obj.pitchIndex)")
    }

    private func playHumDuet(_ a: HumObjectNode, _ b: HumObjectNode) {
        guard AudioManager.shared.isEnabled else { return }
        let degrees = [toneDegree(for: a), toneDegree(for: b)].sorted()
        let voice = LullToneEngine.Voice.choir.with(body: 0.85, amplitude: 0.12, noiseGain: 0.04)
        let spec = LullToneEngine.Spec.chord(degrees, voice)
        LullToneEngine.shared.play(spec, cacheKey: "hum.duet.\(degrees[0]).\(degrees[1])")
    }

    private func playHumChoir(_ trio: [HumObjectNode]) {
        guard AudioManager.shared.isEnabled else { return }
        let degrees = Array(Set(trio.map { toneDegree(for: $0) })).sorted()
        let chordDegrees = Array(degrees.prefix(3))
        // A full warm choir chord, answered by a rising music-box shimmer an octave up.
        let chord = LullToneEngine.Spec.chord(
            chordDegrees,
            LullToneEngine.Voice.choir.with(body: 1.0, amplitude: 0.12, noiseGain: 0.04)
        )
        let sparkleDegrees = chordDegrees.map { min($0 + 5, 19) }   // +1 octave in the pentatonic
        let exhale = LullToneEngine.Spec.arp(
            sparkleDegrees,
            step: 0.085,
            LullToneEngine.Voice.celeste.with(body: 0.9, amplitude: 0.07)
        )
        let key = chordDegrees.map(String.init).joined(separator: ".")
        LullToneEngine.shared.playSequence([
            (spec: chord, delay: 0, cacheKey: "hum.choir.\(key).chord"),
            (spec: exhale, delay: 0.34, cacheKey: "hum.choir.\(key).sparkle")
        ])
    }

    private func playHumRelease(for obj: HumObjectNode) {
        guard AudioManager.shared.isEnabled else { return }
        if obj.kind == .bar { return }   // a struck bar simply rings out in the reverb
        let degree = toneDegree(for: obj)
        let lower = max(0, degree - 2)
        let voice = LullToneEngine.Voice.breath.with(body: 0.46, amplitude: 0.052, noiseGain: 0.34)
        let spec = LullToneEngine.Spec.arp([degree, lower], step: 0.085, voice)
        LullToneEngine.shared.play(spec, cacheKey: "hum.release.\(obj.pitchIndex)")
    }

    private func startSustainedTone(for obj: HumObjectNode) {
        guard AudioManager.shared.isEnabled else { return }
        let id = ObjectIdentifier(obj)
        stopSustainedTone(for: obj)
        let toneID = "hum.sustain.\(toneDegree(for: obj))"   // per-pitch so it can be pre-rendered
        activeToneIDs[id] = toneID
        sustainStartTimes[id] = CACurrentMediaTime()
        // A clearly present sustain: leaning on a bar keeps the note singing under the strike,
        // so a child can hold a note down (the playtest wish) — still soft, never droning loud.
        // loopCount 2 ≈ 9.6 s ceiling: the sustain is finite AT THE AUDIO LAYER, so a lost touch
        // can never leave a note droning — it always dies on its own even with zero bookkeeping.
        LullToneEngine.shared.playAmbient(id: toneID, spec: humSustainSpec(for: obj), volume: 0.62, fadeIn: 0.07, loopCount: 2)
        AudioManager.shared.updateSoundPosition(nodeID: toneID, screenPoint: obj.position, sceneSize: size)
    }

    private func humSustainSpec(for obj: HumObjectNode) -> LullToneEngine.AmbientSpec {
        LullToneEngine.AmbientSpec(
            frequency: LullToneEngine.shared.pitchHz(forDegree: toneDegree(for: obj)),
            partials: humPartials(for: obj),
            noiseGain: obj.kind == .column ? 0.075 : 0.016,
            lfoHz: obj.kind == .pebble ? 0.42 : 0.18,
            lfoDepth: obj.kind == .pebble ? 0.12 : 0.07,
            amplitude: sustainedAmplitude(for: obj),
            duration: 4.8
        )
    }

    private func stopSustainedTone(for obj: HumObjectNode) {
        let id = ObjectIdentifier(obj)
        sustainStartTimes.removeValue(forKey: id)
        guard let toneID = activeToneIDs.removeValue(forKey: id) else { return }
        LullToneEngine.shared.stopAmbient(id: toneID, fadeOut: obj.toneDecay)
    }

    private func humPartials(for obj: HumObjectNode) -> [(ratio: Double, gain: Double)] {
        switch obj.kind {
        case .blob:
            return [(1, 0.86), (1.5, 0.26), (2, 0.32), (3, 0.10)]
        case .column:
            return [(1, 0.58), (2, 0.40), (3, 0.12), (4, 0.05)]
        case .disc:
            return [(1, 0.76), (1.25, 0.14), (2, 0.44), (3, 0.16)]
        case .pebble:
            return [(1, 0.72), (2, 0.42), (3, 0.12)]
        case .bar:
            return [(1, 0.82), (2, 0.30), (3, 0.10)]
        }
    }

    private func sustainedAmplitude(for obj: HumObjectNode) -> Double {
        switch obj.kind {
        case .blob: return 0.036
        case .column: return 0.030
        case .disc: return 0.038
        case .pebble: return 0.032
        case .bar: return 0.050   // a held bar sustains audibly — you can lean on a note
        }
    }

    private func toneDegree(for obj: HumObjectNode) -> Int {
        // Ascending C-major pentatonic from C4 (degree 5). Consecutive degrees are consecutive
        // pentatonic steps, so striking the bars left→right is a clean rising run — no wrong notes.
        return min(5 + obj.pitchIndex, 19)
    }

    private func humAttackVoice(for obj: HumObjectNode) -> LullToneEngine.Voice {
        // Each kind sings with its own beautiful timbre; all bloom in the shared reverb.
        switch obj.kind {
        case .blob:   return .choir.with(body: 0.62, amplitude: 0.13, noiseGain: 0.05)   // warm "aah"
        case .column: return .glass.with(body: 0.95, amplitude: 0.11)                    // crystalline
        case .disc:   return .marimba.with(body: 0.52, amplitude: 0.15)                  // soft wood
        case .pebble: return .celeste.with(body: 0.95, amplitude: 0.115)                 // music box
        case .bar:    return .marimba.with(body: 0.58, amplitude: 0.15)                  // xylophone wood
        }
    }

    private func humKindName(_ kind: HumObjectNode.ObjectKind) -> String {
        switch kind {
        case .blob: return "blob"
        case .column: return "column"
        case .disc: return "disc"
        case .pebble: return "pebble"
        case .bar: return "bar"
        }
    }

    // MARK: - Accessibility

    override func accessibilityElements(in view: SKView) -> [UIAccessibilityElement] {
        var elements = super.accessibilityElements(in: view)
        for obj in objects {
            let typeName: String
            switch obj.kind {
            case .blob:   typeName = "soft blob"
            case .column: typeName = "tall column"
            case .disc:   typeName = "round disc"
            case .pebble: typeName = "small pebble"
            case .bar:    typeName = "xylophone bar"
            }
            elements.append(makeActivatableAccessibilityElement(
                in: view,
                label: "\(typeName) — tap to play a sound",
                scenePosition: obj.position,
                size: CGSize(width: 88, height: 88),
                traits: .button
            ) { [weak self, weak obj] in
                guard let self, let obj else { return }
                self.objectTouched(obj)
                self.run(.sequence([
                    .wait(forDuration: 1.2),
                    .run { [weak self, weak obj] in
                        guard let self, let obj else { return }
                        self.objectReleased(obj)
                    }
                ]))
            })
        }
        if toneButton.parent != nil {
            elements.append(makeActivatableAccessibilityElement(
                in: view,
                label: "Change the instrument's sound",
                scenePosition: toneButton.position,
                size: CGSize(width: 76, height: 76),
                traits: .button
            ) { [weak self] in
                self?.cycleToneVoice()
            })
        }
        return elements
    }

    private func objectTouched(_ obj: HumObjectNode) {
        obj.noticeAndHold()
        HapticsManager.shared.softTap()
        spawnSoundRing(at: obj.position, color: obj.objectColor, radius: primaryRingRadius)
        obj.playSoundPulse(intensity: 1.08)
        playHumOnset(for: obj)
        startSustainedTone(for: obj)
        startHumHoldPulse(for: obj)
    }

    private func objectReleased(_ obj: HumObjectNode) {
        guard !touchToObject.values.contains(where: { $0 === obj }) else { return }
        stopHumHoldPulse(for: obj)
        stopSustainedTone(for: obj)
        stopHeldSparkle(for: obj)
        playHumRelease(for: obj)
        activePairs = activePairs.filter { !$0.contains(obj) }
        obj.settleHome()
    }

    private func startHumHoldPulse(for obj: HumObjectNode) {
        let id = ObjectIdentifier(obj)
        humHoldTimers[id]?.invalidate()
        var pulsesLeft = 8
        let timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] t in
            guard pulsesLeft > 0, self != nil else { t.invalidate(); return }
            pulsesLeft -= 1
            HapticsManager.shared.play(score: .humHold)
        }
        humHoldTimers[id] = timer
    }

    private func stopHumHoldPulse(for obj: HumObjectNode) {
        let id = ObjectIdentifier(obj)
        humHoldTimers[id]?.invalidate()
        humHoldTimers.removeValue(forKey: id)
    }

    /// The held note made visible: a soft glow breathes around the bar and note-motes keep lifting
    /// off it for as long as it's held. Cleared the instant it's released.
    private func startHeldSparkle(for bar: HumObjectNode) {
        guard !AmbientAnimator.reduceMotion else { return }
        bar.removeAction(forKey: "heldSparkle")
        let emit = SKAction.sequence([
            .wait(forDuration: 0.28),
            .run { [weak self, weak bar] in
                guard let self, let bar, bar.isHeld else { return }
                let p = CGPoint(x: bar.position.x + .random(in: -20...20), y: bar.position.y + .random(in: 34...68))
                self.spawnNoteMotes(at: p, color: bar.objectColor, count: 2)
            }
        ])
        bar.run(.repeatForever(emit), withKey: "heldSparkle")

        if bar.childNode(withName: "heldGlow") == nil {
            let glow = SKShapeNode(circleOfRadius: 74)
            glow.name = "heldGlow"
            glow.fillColor = bar.objectColor.withAlpha(0.3)
            glow.strokeColor = .clear
            glow.blendMode = .add
            glow.zPosition = -1
            glow.alpha = 0
            bar.addChild(glow)
            glow.run(.fadeAlpha(to: 1, duration: 0.2))
            glow.run(.repeatForever(.sequence([.scale(to: 1.18, duration: 0.85), .scale(to: 0.94, duration: 0.85)])), withKey: "breathe")
        }
    }

    private func stopHeldSparkle(for bar: HumObjectNode) {
        bar.removeAction(forKey: "heldSparkle")
        bar.childNode(withName: "heldGlow")?.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
    }
}
