import SpriteKit
import QuartzCore

/// Glow Window — a cozy room with a giant window. A toddler turns one big chunky sun/moon dial and
/// the WHOLE room transforms, continuously, from morning to day to golden sunset to dusk to night:
/// the sky gradient shifts, the sun arcs over and sets, the moon and stars rise, the walls cool, a
/// warm light-spill rakes across the floor. Two big curtains pull open and closed; a cozy lamp taps
/// on to bloom amber light. No goal, no menu, no mascot — the room itself is the toy.
///
/// One value drives everything: `dayPhase` 0…1. The dial sets it; `applyPhase` paints the room from
/// it. All motion is authored and respects Reduce Motion.
final class GlowWindowScene: BaseToyScene {

    override var toyVoice: AudioManager.LullSoundVoice { .none }   // recorded day/night beds cross-fade from the dial
    override var firstSessionHintKey: String? { "hint.glowWindow" }
    override func firstSessionHintPoint() -> CGPoint { dialCenter }

    // MARK: - Layers (back → front)
    private let roomLayer = SKNode()        // wall + floor
    private let windowContent = SKCropNode() // sky, sun/moon, stars, clouds — clipped to the glass
    private let glassLayer = SKNode()        // reflections on the glass
    private let beamLayer = SKNode()         // light spill raking into the room
    private let frameLayer = SKNode()        // window frame + sill
    private let lampLayer = SKNode()
    private let curtainLayer = SKNode()
    private let particleLayer = SKNode()
    private let warmVeil = SKSpriteNode()    // golden wash, peaks at sunset
    private let coolVeil = SKSpriteNode()    // blue darkening, rises into night
    private let controlLayer = SKNode()      // the hero dial

    // MARK: - State (kept here so a rotation rebuild restores the exact room)
    private var dayPhase: CGFloat = 0.2      // overwritten from the real clock on first open
    private var hasSetClockPhase = false
    private enum Zone { case morning, day, sunset, dusk, night }
    private var currentZone: Zone = .day
    private var announcedZone: Zone? = .day  // start already "announced" so nothing fires on load
    private var zoneEnteredTime: TimeInterval = 0
    private var lastMomentTime: TimeInterval = 0
    private var curtainOpen: CGFloat = 1.0   // 1 = fully open, 0 = closed
    private var lampOn = false
    private var lampAutoOn: Bool?            // the lamp's own opinion; child taps override

    // MARK: - Geometry
    private var windowRect = CGRect.zero
    private var windowInner = CGRect.zero
    private var windowCenter = CGPoint.zero
    private var floorTopY: CGFloat = 0
    private var dialCenter = CGPoint.zero
    private var dialRadius: CGFloat = 60
    private var lampShadeCenter = CGPoint.zero
    private var lampShadeSize = CGSize.zero
    private weak var sillCat: SKNode?

    // MARK: - The living room (Phase A — Room Council, June 12)
    // The watering verb, movable-with-homes, and the visiting things. Placements
    // and growth persist: the room remembering what the child did IS the toy.
    private weak var flowerPotNode: SKSpriteNode?
    private var potCenter = CGPoint(x: -999, y: -999)
    private weak var canNode: SKNode?
    private var canHome = CGPoint.zero
    private var wateredThisHold = false
    private weak var guestNode: SKNode?
    private var guestCenter = CGPoint(x: -999, y: -999)
    private var plantHomes: [CGPoint] = []
    private var grabMovedDistance: CGFloat = 0
    private weak var rugGlow: SKSpriteNode?
    private weak var carriedNode: SKNode?
    private var carryTarget: CGPoint?
    // (b) the cat's second-home sleeping pose: one authored cat-on-rug composite that
    // replaces both the movable cat and the procedural rug when she's home on the rug
    // and asleep — no duplicate cat, no rug-on-rug.
    private weak var proceduralRug: SKNode?
    private weak var catRugComposite: SKSpriteNode?
    private weak var wallLibraryNode: SKSpriteNode?
    private var rugCenterPoint = CGPoint.zero

    private var todayStamp: Int {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return (c.year ?? 0) * 10000 + (c.month ?? 0) * 100 + (c.day ?? 0)
    }
    private weak var plantNode: SKNode?
    private var plantCenter = CGPoint.zero
    private var plantHitRadius: CGFloat = 0
    // Two cat toys the child can pull from the toy box. The old ball/block save
    // keys stay for compatibility, but the visible toys are now a felt fish and mouse.
    private weak var ballNode: SKNode?
    private weak var ballSpin: SKNode?      // compat name: the fish toy's visual, shadow stays put
    private var ballCenter = CGPoint.zero
    private var ballHitRadius: CGFloat = 0
    private weak var blockNode: SKNode?
    private weak var blockVisual: SKNode?   // compat name: the mouse toy visual, shadow stays put
    private var blockCenter = CGPoint.zero
    private var blockHitRadius: CGFloat = 0
    // The toy box: the play-toys live in it; tap to open (toys lift out on a soft glow)
    // and close (they gather back). Declutters the floor to just the room's residents.
    private weak var toyboxNode: SKSpriteNode?
    private weak var toyboxGlow: SKNode?
    private var toyboxOpen = false
    private var toyboxCenter = CGPoint.zero
    private var toyboxHitRadius: CGFloat = 0
    private var toyboxClosedTex: SKTexture?
    private var toyboxOpenTex: SKTexture?
    private weak var catTail: SKShapeNode?
    private var catEyes: [(node: SKShapeNode, offsetX: CGFloat)] = []
    private var catGlints: [SKShapeNode] = []
    private var catScale: CGFloat = 10
    private var catIsAwake: Bool?
    private var catCenter = CGPoint.zero
    private var catHitRadius: CGFloat = 0

    // MARK: - Updatable nodes
    private var glassBase: SKSpriteNode!
    private var glassTop: SKSpriteNode!
    private var wallNode: SKShapeNode?      // nil when authored room plates are present
    private var floorNode: SKShapeNode?
    private var roomNight: SKSpriteNode?    // authored night plate, cross-fades over day
    private var sunNode: SKNode!
    private var sunDisc: SKShapeNode?       // nil when the authored sun is present
    private var sunGlow: SKSpriteNode!      // radial falloff — light has no edge
    private var moonNode: SKNode!
    private var moonGlow: SKSpriteNode!
    private var stars: [SKShapeNode] = []
    private var cloudNode: SKNode!
    private var treesDay: SKNode!
    private var treesNight: SKNode!
    private weak var catSprite: SKSpriteNode?       // asleep base
    private weak var catAwakeSprite: SKSpriteNode?  // awake overlay — cross-faded, never snapped
    private var beamNode: SKShapeNode!
    private weak var beamEffect: SKEffectNode?   // blurs the beam so its edges dissipate, not a hard line
    private var lampGlow: SKSpriteNode!
    private var lampShade: SKShapeNode?     // nil when the authored floor lamp is present
    private var dialNode: SKNode!
    private var dialKnob: SKShapeNode!
    private var dialIcon: SKNode!
    private var dialPointer: SKSpriteNode?  // authored needle: it sweeps, the face stays put
    private var lampSprite: SKSpriteNode?   // authored floor lamp (texture-swapped on/off)
    private var curtainL: SKNode!
    private var curtainR: SKNode!
    private var curtainRestX: CGFloat = 0     // |x| of a fully-open panel centre from window centre

    // MARK: - Touch
    private enum Grab { case dial, curtainL, curtainR, room, can, cat, plant, ball, block }
    private var grabs: [UITouch: Grab] = [:]
    private var dialLastAngle: CGFloat = 0
    private var dialVelocity: CGFloat = 0
    private var curtainGrabDX: CGFloat = 0

    // MARK: - Particles / sound bookkeeping
    private var moteAccum: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0
    private var cloudDrift: CGFloat = 0

    // MARK: - Peek-a-boo curtains (approved delight ⭐)
    // Now and then, something outside wants to change — but only behind drawn cloth.
    // The curtains whisper "close me" (a fuller, slower peek with an inward draft);
    // fully closing applies the change unseen; reopening finds the world different.
    // Object permanence, turned into a game the child runs themselves.
    private enum PeekChange { case birdVisit, cloudJump, starFall }
    private var peekChange: PeekChange?
    private var peekRevealReady = false
    private weak var visitingBird: SKNode?

    // MARK: - Room peek (founder, June 12: "would it be too bold?" — not as a LEAN.)
    // Drag the walls and the whole room leans with the finger; the world outside the
    // glass lags behind (depth), and a sliver of the next part of the house shows at
    // the edge. Release, and the room settles home. A peek, never a teleport.
    private var roomPanX: CGFloat = 0
    private var roomGrabStartX: CGFloat = 0
    private var roomGrabBaseline: CGFloat = 0
    private let roomPeekMax: CGFloat = 240   // Pok Pok depth: a real lean (110 read as "a centimetre" — founder)
    private var lastTone: [String: TimeInterval] = [:]

    private let woodWarm = UIColor(hex: 0xC79A57)
    private let woodDark = UIColor(hex: 0x7E5526)

    private let dialAngleRange: CGFloat = .pi * 1.7   // how far you turn for a whole day

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        ambientMoteInterval = 9999   // we author our own atmospheric particles
        roomLayer.zPosition = 0;        addChild(roomLayer)
        windowContent.zPosition = 1.0;  addChild(windowContent)
        glassLayer.zPosition = 1.4;     addChild(glassLayer)
        beamLayer.zPosition = 1.2;      addChild(beamLayer)
        frameLayer.zPosition = 1.6;     addChild(frameLayer)
        lampLayer.zPosition = 1.8;      addChild(lampLayer)
        curtainLayer.zPosition = 2.2;   addChild(curtainLayer)
        particleLayer.zPosition = 2.6;  addChild(particleLayer)
        warmVeil.zPosition = 3.0;       addChild(warmVeil)
        coolVeil.zPosition = 3.1;       addChild(coolVeil)
        controlLayer.zPosition = 4.0;   addChild(controlLayer)
        if !hasSetClockPhase {
            hasSetClockPhase = true
            // LULL_DEBUG_PHASE=0…1 pins the room to a time of day (store screenshots, QA).
            if let forced = ProcessInfo.processInfo.environment["LULL_DEBUG_PHASE"].flatMap({ Double($0) }) {
                dayPhase = CGFloat(min(max(forced, 0), 1))
            } else {
                dayPhase = GlowWindowScene.phaseForClock()
            }
            // Arriving in any hour stays calm: the room is already "announced", so no
            // morning/night moment fires until the child actually turns the dial there.
            currentZone = phaseZone(dayPhase)
            announcedZone = currentZone
        }
        rebuild()
    }

    private var isLeaving = false   // once leaving, applyPhase must not re-ramp the audio bed

    override func teardownToyAudio() {
        isLeaving = true
        AudioManager.shared.stopWindowAmbience(fadeOut: 0.4)
        super.teardownToyAudio()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 120, size.height > 120, dialRadius > 1, oldSize != size else { return }
        rebuild()
    }

    // MARK: - Build

    private func rebuild() {
        guard size.width > 120, size.height > 120 else { return }
        [roomLayer, glassLayer, beamLayer, frameLayer, lampLayer, curtainLayer, particleLayer, controlLayer].forEach { $0.removeAllChildren() }
        windowContent.removeAllChildren()
        stars.removeAll()

        let landscape = size.width > size.height

        // The window is the hero — pulled close and generous (playtest: more window,
        // fewer side characters; the teddy is retired so nothing competes with it).
        // The window is the stage — pushed nearly edge to edge so the living world fills
        // the screen and the room is only a whisper of wall + the sill (founder + panel).
        let winW = min(size.width * (landscape ? 0.62 : 0.94), 760)
        let winH = min(size.height * (landscape ? 0.74 : 0.66), 820)
        windowCenter = CGPoint(x: size.width * (landscape ? 0.42 : 0.5), y: size.height * (landscape ? 0.52 : 0.555))
        windowRect = CGRect(x: windowCenter.x - winW / 2, y: windowCenter.y - winH / 2, width: winW, height: winH)
        let frameT = min(winW, winH) * 0.075
        windowInner = windowRect.insetBy(dx: frameT, dy: frameT)
        floorTopY = size.height * 0.24

        // The day dial is now a wall clock: still an object in the room, but no longer
        // stealing floor space from the toy box. It stays large enough for toddler hands.
        // The dial lives on the SILL now — a chunky disc in the foreground where a small
        // hand falls, while the world fills the glass above (founder + panel, June 15).
        dialRadius = min(size.width, size.height) * (landscape ? 0.10 : 0.115)
        let sillDialX = size.width * (landscape ? 0.80 : 0.26)
        dialCenter = CGPoint(x: sillDialX, y: windowRect.minY - dialRadius * 0.12)

        buildRoom()
        buildWindowContents()
        buildGlassAndFrame()
        buildSillCat()
        buildBeam()
        // Window stripped to a calm day↔night, tap-and-discover scene (founder, June 15:
        // we were over-scoping a small scene). No lamp, no toy box, no movable props — the
        // outdoors lights the room; the cat naps on the sill; the dial turns the sky.
        buildCurtains()
        buildDial()
        buildGlobalVeils()

        applyPhase(animated: false)
        applyCurtain(animated: false)
        applyLamp(animated: false)
        inviteCurtains()
        inviteDial()
        schedulePeekArm(initial: true)
        roomPanX = 0   // a fresh build re-centers the lean
        applyRoomPeek()
        #if DEBUG
        // QA: LULL_DEBUG_ROOM_PAN=240 stages a leaned room so the peek can be screenshot
        // (the sim can't inject a drag).
        if let s = ProcessInfo.processInfo.environment["LULL_DEBUG_ROOM_PAN"], let v = Double(s) {
            roomPanX = CGFloat(v); applyRoomPeek()
        }
        #endif
        // (The gen'd side-slices read wrong — founder. The expanded wallpaper plus
        // three-depth furniture parallax carries the peek now.)
        // buildLivingRoom() retired June 15 — the pot/can/guest/toy box/floor toys/plant
        // are gone in the stripped-down scene. The room (rug + nook library) + cat remain.
    }

    // MARK: - The living room (Phase A)

    private func buildLivingRoom() {
        let state = LullDemoState.shared
        let s = frameT()

        // The cat stays exactly where the child last left her — free placement, no slots
        // (a 2-year-old expects her to stay put, not snap to one of two spots — founder
        // playtest, June 14, overriding the earlier slot model). Default: her sill spot.
        if let place = state.windowCatPlace, let cat = sillCat {
            let p = clampCatSpot(denormalized(place))
            cat.position = p; catCenter = p
        }
        let sillPlantSpot = CGPoint(x: windowCenter.x - windowRect.width * 0.40,
                                    y: windowRect.minY + s * 0.6)
        plantHomes = [plantCenter, sillPlantSpot]
        if state.windowPlantHome == 1, let plant = plantNode {
            plant.position = sillPlantSpot
            plantCenter = sillPlantSpot
        }
        refreshRugGlow()

        // The flower pot and can belong at the back of the floor, against the wall.
        // Low foreground placement made them read as stickers sliding over the rug.
        let gardenFootY = floorTopY * 0.74

        // The flower pot — watering answers INSTANTLY (founder, June 13); the
        // one-drink-a-day rule still makes the full bloom a three-day friendship.
        let stage = state.windowPotStage
        if let pot = ToyArt.sprite("window-pot-\(stage)", fit: CGSize(width: s * 2.4, height: s * 3.4)) {
            pot.anchorPoint = CGPoint(x: 0.5, y: 0)
            pot.position = CGPoint(x: size.width * 0.765, y: gardenFootY)
            pot.zPosition = 0.50
            lampLayer.addChild(pot)
            flowerPotNode = pot
            potCenter = CGPoint(x: pot.position.x, y: pot.position.y + pot.size.height * 0.4)
        }

        // The watering can, waiting by the wall — sized like a real tool, not a charm
        // (founder: it read tiny beside the pot).
        if let can = ToyArt.sprite("window-watering-can", fit: CGSize(width: s * 2.85, height: s * 2.0)) {
            let canX = min(size.width * 0.88, size.width - can.size.width * 0.48)
            canHome = CGPoint(x: canX, y: gardenFootY + can.size.height * 0.50)
            can.position = canHome
            can.zPosition = 0.54
            lampLayer.addChild(can)
            canNode = can
        }

        buildTodaysGuest()
        buildFloorToys()
    }

    /// Two soft cat toys live in the toy box and spill onto the rug — a fish and a
    /// mouse. Each remembers where the child left it.
    /// The room had only the cat and watering can to move; these give the floor a little
    /// play corner without permanently cluttering it.
    ///
    /// Each is assembled as: a contact shadow (a direct child, so it never rotates) plus
    /// a visual sub-node that does the toy's response. The visual is the
    /// authored art slot if it's landed, else the procedural clay stand-in (the house
    /// rule: a missing slot falls back, shipping is never blocked on art).
    private func buildFloorToys() {
        let state = LullDemoState.shared
        let s = frameT()

        toyboxOpen = state.windowToyboxOpen
        #if DEBUG
        if ProcessInfo.processInfo.environment["LULL_DEBUG_TOYBOX_OPEN"] == "1" {
            toyboxOpen = true
            state.windowToyboxOpen = true
        } else if ProcessInfo.processInfo.environment["LULL_DEBUG_TOYBOX_OPEN"] == "0" {
            toyboxOpen = false
            state.windowToyboxOpen = false
        }
        #endif

        // The felt fish. Default spot: out on the rug right of the toy box; then
        // wherever the child last carried it. Saved under the old "ball" key so upgrades
        // do not strand existing placements.
        let ballDefault = CGPoint(x: size.width * 0.56, y: floorTopY * 0.32)
        let ball = SKNode()
        ball.addChild(contactShadow(width: s * 1.55, height: s * 0.38, dropY: -s * 0.48))
        let ballSpinNode = SKNode()
        ballSpinNode.addChild(ToyArt.sprite("window-cat-fish", fit: CGSize(width: s * 2.05, height: s * 1.28))
                              ?? proceduralCatFish(width: s * 1.8))
        ball.addChild(ballSpinNode)
        ballSpin = ballSpinNode
        let ballSpot = state.windowBallPlace.map { clampFloorSpot(denormalized($0)) } ?? ballDefault
        ball.position = ballSpot
        ballCenter = ballSpot
        ballHitRadius = s * 1.5
        ball.zPosition = 0.64   // frontmost floor prop, just over the can
        lampLayer.addChild(ball)
        ballNode = ball

        // The felt mouse. Default spot: out on the rug right of the fish; then where
        // left. Saved under the old "block" key for compatibility.
        let blockDefault = CGPoint(x: size.width * 0.70, y: floorTopY * 0.24)
        let block = SKNode()
        block.addChild(contactShadow(width: s * 1.35, height: s * 0.34, dropY: -s * 0.44))
        let blockVis = SKNode()
        blockVis.addChild(ToyArt.sprite("window-cat-mouse", fit: CGSize(width: s * 1.85, height: s * 1.18))
                          ?? proceduralCatMouse(width: s * 1.65))
        block.addChild(blockVis)
        blockVisual = blockVis
        let blockSpot = state.windowBlockPlace.map { clampFloorSpot(denormalized($0)) } ?? blockDefault
        block.position = blockSpot
        blockCenter = blockSpot
        blockHitRadius = s * 1.4
        block.zPosition = 0.62
        lampLayer.addChild(block)
        blockNode = block

        buildToybox()
        // The play-toys hide inside a closed box; only spill out when it's open.
        let toysOut = toyboxOpen
        for n in [ball, block] { n.alpha = toysOut ? 1 : 0; n.isHidden = !toysOut }
    }

    /// The toy box, lower-left: the home for the play-toys. Tap to open (they lift out on
    /// a soft mystery-box glow) and close (they gather back) — keeps the floor to just the
    /// room's residents (cat, plant, can, lamp). Authored art, procedural box as fallback.
    private func buildToybox() {
        let s = frameT()
        toyboxHitRadius = s * 2.2
        toyboxClosedTex = ToyArt.texture("window-toybox-closed")
        toyboxOpenTex = ToyArt.texture("window-toybox-open")

        // Furniture, not rug clutter: the chest sits against the back wall/baseboard,
        // leaving the rug open for the toys that spill out. Compute from the open art
        // height so the raised lid never climbs into the window rail.
        let targetW = s * 4.0
        func scaledHeight(_ tex: SKTexture?) -> CGFloat {
            guard let tex else { return 0 }
            return tex.size().height * targetW / max(1, tex.size().width)
        }
        let tallestBox = max(scaledHeight(toyboxClosedTex), scaledHeight(toyboxOpenTex), s * 2.8)
        let baseY = max(floorTopY * 0.54, min(floorTopY * 0.72, windowRect.minY - tallestBox - s * 0.6))
        let base = CGPoint(x: size.width * 0.30, y: baseY)

        let box = SKSpriteNode()
        let tex = (toyboxOpen ? toyboxOpenTex : toyboxClosedTex) ?? toyboxClosedTex
        if let tex {
            box.texture = tex
            let sc = targetW / tex.size().width   // width-fit, so the open lid extends UP not shrinks the body
            box.size = CGSize(width: tex.size().width * sc, height: tex.size().height * sc)
        } else {
            box.size = CGSize(width: s * 3.6, height: s * 2.8)
            box.color = WarmShelfPalette.sand; box.colorBlendFactor = 1   // bare fallback
        }
        box.anchorPoint = CGPoint(x: 0.5, y: 0)   // base-anchored so open/closed swap doesn't jump
        box.position = base
        toyboxCenter = toyboxMouthPoint(for: box)
        box.zPosition = 0.46
        lampLayer.addChild(box)
        toyboxNode = box
        if toyboxOpen { spawnToyboxGlow() }
    }

    private func resizeToybox() {
        guard let box = toyboxNode, let tex = box.texture else { return }
        let sc = (frameT() * 4.0) / tex.size().width
        box.size = CGSize(width: tex.size().width * sc, height: tex.size().height * sc)
        toyboxCenter = toyboxMouthPoint(for: box)
        toyboxGlow?.position = toyboxGlowPoint(for: box)
    }

    private func toyboxMouthPoint(for box: SKSpriteNode) -> CGPoint {
        CGPoint(x: box.position.x, y: box.position.y + box.size.height * (toyboxOpen ? 0.36 : 0.42))
    }

    private func toyboxGlowPoint(for box: SKSpriteNode) -> CGPoint {
        CGPoint(x: box.position.x, y: box.position.y + box.size.height * (toyboxOpen ? 0.38 : 0.42))
    }

    /// Tap the box: open (toys lift out on a soft mystery-box glow + sparkles) or close
    /// (toys gather back in). The lid presses, then the art swaps at the squash frame.
    private func toggleToybox() {
        guard let box = toyboxNode else { return }
        toyboxOpen.toggle()
        LullDemoState.shared.windowToyboxOpen = toyboxOpen
        HapticsManager.shared.impact(style: .soft, intensity: 0.2)
        let tex = toyboxOpen ? toyboxOpenTex : toyboxClosedTex
        box.run(.sequence([
            .scaleY(to: 0.93, duration: 0.08),
            .run { [weak self] in if let tex { box.texture = tex; self?.resizeToybox() } },
            .scaleY(to: 1.0, duration: 0.14)
        ]))
        if toyboxOpen {
            spawnToyboxGlow()
            releaseToys()
            AudioManager.shared.playWindowToyboxOpen()
        } else {
            removeToyboxGlow()
            gatherToys()
            tone(.single(5, .felt.with(body: 0.3, amplitude: 0.045, noiseGain: 0.5)), key: "toyboxClose", minInterval: 0.3)
        }
    }

    /// The toys ride out of the box to their resting spots — a little arc and a fade-in.
    private func releaseToys() {
        for (node, home) in [(ballNode, ballCenter), (blockNode, blockCenter)] {
            guard let node else { continue }
            node.isHidden = false
            node.position = toyboxCenter
            node.alpha = 0; node.setScale(0.5)
            let pop = SKAction.group([.move(to: home, duration: 0.42),
                                      .fadeIn(withDuration: 0.3),
                                      .scale(to: 1.0, duration: 0.42)])
            pop.timingMode = .easeOut
            node.run(pop)
        }
    }

    /// The toys gather back into the box and tuck away.
    private func gatherToys() {
        for node in [ballNode, blockNode].compactMap({ $0 }) {
            let gather = SKAction.group([.move(to: toyboxCenter, duration: 0.34),
                                         .fadeOut(withDuration: 0.34),
                                         .scale(to: 0.5, duration: 0.34)])
            gather.timingMode = .easeIn
            node.run(.sequence([gather, .run { node.isHidden = true; node.setScale(1.0); node.alpha = 0 }]))
        }
    }

    /// The "mystery box" light — a soft warm beam and pool rising from the open lid, with
    /// gentle sparkles. Kept calm (founder's bar): an invitation, not a fireworks show.
    private func spawnToyboxGlow() {
        guard toyboxGlow == nil, let box = toyboxNode, let parent = box.parent else { return }
        let s = frameT()
        let glow = SKNode()
        // Originate at the mouth and keep the light local: a warm invitation from inside
        // the chest, not a flashlight beam competing with the window or lamp.
        glow.position = toyboxGlowPoint(for: box)
        glow.zPosition = box.zPosition + 0.015
        parent.addChild(glow)
        toyboxGlow = glow

        let night = smoothstep(0.6, 0.92, dayPhase)
        let beamAlpha = 0.055 + night * 0.055
        let poolAlpha = 0.12 + night * 0.10
        let coreAlpha = 0.22 + night * 0.12

        let beam = SKShapeNode(path: { () -> CGPath in
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -s * 0.34, y: 0)); p.addLine(to: CGPoint(x: s * 0.34, y: 0))
            p.addLine(to: CGPoint(x: s * 0.95, y: s * 2.45)); p.addLine(to: CGPoint(x: -s * 0.95, y: s * 2.45))
            p.closeSubpath(); return p
        }())
        beam.fillColor = UIColor(hex: 0xFFE08A).withAlpha(beamAlpha); beam.strokeColor = .clear
        beam.blendMode = .add
        glow.addChild(beam)
        let pool = SKSpriteNode(texture: ProceduralTexture.softRadialGlow)
        pool.color = UIColor(hex: 0xFFE8A0); pool.colorBlendFactor = 1; pool.blendMode = .add
        pool.alpha = poolAlpha; pool.size = CGSize(width: s * 1.75, height: s * 0.8); pool.zPosition = 0.1
        pool.position.y = -s * 0.06
        glow.addChild(pool)
        // a small bright core right at the mouth — the "treasure" light
        let core = SKSpriteNode(texture: ProceduralTexture.softRadialGlow)
        core.color = UIColor(hex: 0xFFF6DC); core.colorBlendFactor = 1; core.blendMode = .add
        core.alpha = coreAlpha; core.size = CGSize(width: s * 0.82, height: s * 0.48); core.zPosition = 0.2
        glow.addChild(core)
        glow.alpha = 0
        glow.run(.fadeIn(withDuration: 0.35))
        if !AmbientAnimator.reduceMotion {
            beam.run(.repeatForever(.sequence([.fadeAlpha(to: 0.95, duration: 1.4),
                                               .fadeAlpha(to: 0.62, duration: 1.6)])))
            core.run(.repeatForever(.sequence([.fadeAlpha(to: coreAlpha * 1.12, duration: 1.0),
                                               .fadeAlpha(to: coreAlpha * 0.78, duration: 1.2)])))
            emitToyboxSparkle()
        }
    }

    private func emitToyboxSparkle() {
        guard let glow = toyboxGlow, toyboxOpen else { return }
        let s = frameT()
        let spark = SKShapeNode(circleOfRadius: .random(in: 1.0...2.0))
        spark.fillColor = UIColor(hex: 0xFFF0C0).withAlpha(0.72); spark.strokeColor = .clear
        spark.blendMode = .add
        spark.position = CGPoint(x: .random(in: -s * 0.34...s * 0.34), y: 0)
        glow.addChild(spark)
        let rise = SKAction.group([
            .moveBy(x: .random(in: -s * 0.22...s * 0.22), y: s * .random(in: 1.25...2.15), duration: .random(in: 1.4...2.2)),
            .sequence([.fadeIn(withDuration: 0.25), .wait(forDuration: 0.45), .fadeOut(withDuration: 0.9)])
        ])
        rise.timingMode = .easeOut
        spark.run(.sequence([rise, .removeFromParent()]))
        glow.run(.sequence([.wait(forDuration: .random(in: 0.85...1.35)),
                            .run { [weak self] in self?.emitToyboxSparkle() }]), withKey: "sparkLoop")
    }

    private func removeToyboxGlow() {
        guard let glow = toyboxGlow else { return }
        toyboxGlow = nil
        glow.removeAllActions()
        glow.run(.sequence([.fadeOut(withDuration: 0.4), .removeFromParent()]))
    }

    /// A soft contact shadow that grounds a floor toy, kept separate from the toy's
    /// visual so the toy can roll or tip without dragging its shadow around with it.
    private func contactShadow(width: CGFloat, height: CGFloat, dropY: CGFloat) -> SKShapeNode {
        let shadow = SKShapeNode(ellipseOf: CGSize(width: width, height: height))
        shadow.fillColor = WarmShelfPalette.cocoa.withAlpha(0.14); shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: dropY); shadow.zPosition = -0.1
        return shadow
    }

    // MARK: - Free placement (the child puts a thing down and it stays there)

    /// A scene point as a fraction of the scene, so a placement persists across the
    /// device↔sim size gap (and rotation). Round-trips with `denormalized`.
    private func normalized(_ p: CGPoint) -> (x: Double, y: Double) {
        (Double(p.x / max(1, size.width)), Double(p.y / max(1, size.height)))
    }
    private func denormalized(_ v: (x: Double, y: Double)) -> CGPoint {
        CGPoint(x: CGFloat(v.x) * size.width, y: CGFloat(v.y) * size.height)
    }

    // The room is wider than the screen: leaning reveals a nook of floor past each wall
    // edge, and a thing can be set down out there (it rides the lean back into view). So
    // the clamps reach ~0.7 of the peek past each edge — far enough to tuck a toy away,
    // not so far it's lost in the void.
    private var nookReach: CGFloat { roomPeekMax * 0.7 }

    /// The cat may rest anywhere on the floor/rug, up on the sill, or tucked into a side
    /// nook — but never floating in the glass or fully off in the void.
    private func clampCatSpot(_ p: CGPoint) -> CGPoint {
        CGPoint(x: min(max(p.x, -nookReach), size.width + nookReach),
                y: min(max(p.y, floorTopY * 0.16), windowRect.minY + frameT() * 0.7))
    }
    /// Toy-box toys stay down on the floor/rug or in a side nook, not up the wall.
    private func clampFloorSpot(_ p: CGPoint) -> CGPoint {
        CGPoint(x: min(max(p.x, -nookReach), size.width + nookReach),
                y: min(max(p.y, floorTopY * 0.12), floorTopY * 0.84))
    }

    /// Is a point on the round rug? (the cat dropped here is "home on the rug" — she may
    /// then curl into the asleep-on-rug composite at night, wherever on the rug she sits).
    private func isOnRug(_ p: CGPoint) -> Bool {
        let rw = size.width * 0.92 * 0.5, rh = floorTopY * 1.15 * 0.5
        let dx = (p.x - rugCenterPoint.x) / max(1, rw)
        let dy = (p.y - rugCenterPoint.y) / max(1, rh)
        return dx * dx + dy * dy <= 1.0
    }

    /// Procedural fallback for the fish: tiny, soft, and cat-readable if art is missing.
    private func proceduralCatFish(width w: CGFloat) -> SKNode {
        let node = SKNode()
        let h = w * 0.58
        let body = SKShapeNode(ellipseOf: CGSize(width: w * 0.72, height: h))
        body.fillColor = WarmShelfPalette.butter.withAlpha(0.92)
        body.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.14)
        body.lineWidth = max(1, w * 0.025)
        node.addChild(body)
        ProceduralTexture.applyClayFill(to: body, base: WarmShelfPalette.butter, size: CGSize(width: w * 0.72, height: h))

        let tail = SKShapeNode(path: {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: w * 0.24, y: 0))
            p.addQuadCurve(to: CGPoint(x: w * 0.50, y: h * 0.34), control: CGPoint(x: w * 0.42, y: h * 0.22))
            p.addQuadCurve(to: CGPoint(x: w * 0.50, y: -h * 0.34), control: CGPoint(x: w * 0.58, y: 0))
            p.closeSubpath()
            return p
        }())
        tail.fillColor = WarmShelfPalette.petal.withAlpha(0.92)
        tail.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.10)
        tail.lineWidth = max(1, w * 0.02)
        tail.zPosition = -0.05
        node.addChild(tail)

        let eyePath = CGMutablePath()
        eyePath.move(to: CGPoint(x: -w * 0.23, y: h * 0.02))
        eyePath.addQuadCurve(to: CGPoint(x: -w * 0.12, y: h * 0.02), control: CGPoint(x: -w * 0.175, y: -h * 0.08))
        let eye = SKShapeNode(path: eyePath)
        eye.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.72)
        eye.lineWidth = max(1.2, w * 0.025)
        eye.lineCap = .round
        eye.fillColor = .clear
        eye.zPosition = 0.2
        node.addChild(eye)
        return node
    }

    /// Procedural fallback for the mouse: a round felt pebble with ears and a curl tail.
    private func proceduralCatMouse(width w: CGFloat) -> SKNode {
        let node = SKNode()
        let h = w * 0.58
        let body = SKShapeNode(ellipseOf: CGSize(width: w * 0.78, height: h))
        body.fillColor = WarmShelfPalette.sand.withAlpha(0.96)
        body.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.12)
        body.lineWidth = max(1, w * 0.02)
        node.addChild(body)
        ProceduralTexture.applyClayFill(to: body, base: WarmShelfPalette.sand, size: CGSize(width: w * 0.78, height: h))

        for x in [-w * 0.18, -w * 0.02] {
            let ear = SKShapeNode(circleOfRadius: w * 0.11)
            ear.fillColor = WarmShelfPalette.sand
            ear.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.10)
            ear.lineWidth = 1
            ear.position = CGPoint(x: x, y: h * 0.36)
            ear.zPosition = -0.05
            node.addChild(ear)
        }
        let nose = SKShapeNode(circleOfRadius: w * 0.045)
        nose.fillColor = WarmShelfPalette.petal.withAlpha(0.92)
        nose.strokeColor = .clear
        nose.position = CGPoint(x: -w * 0.40, y: h * 0.05)
        nose.zPosition = 0.2
        node.addChild(nose)

        let tailPath = CGMutablePath()
        tailPath.move(to: CGPoint(x: w * 0.35, y: h * 0.02))
        tailPath.addCurve(to: CGPoint(x: w * 0.58, y: h * 0.10),
                          control1: CGPoint(x: w * 0.50, y: h * 0.22),
                          control2: CGPoint(x: w * 0.68, y: h * 0.18))
        tailPath.addCurve(to: CGPoint(x: w * 0.55, y: -h * 0.06),
                          control1: CGPoint(x: w * 0.49, y: h * 0.03),
                          control2: CGPoint(x: w * 0.47, y: -h * 0.05))
        let tail = SKShapeNode(path: tailPath)
        tail.strokeColor = WarmShelfPalette.petal.withAlpha(0.9)
        tail.lineWidth = max(2, w * 0.055)
        tail.lineCap = .round
        tail.fillColor = .clear
        tail.zPosition = -0.1
        node.addChild(tail)
        return node
    }

    /// A tap makes the fish wiggle a little — non-committal, like catStretch; real
    /// repositioning is a drag that settles to a home.
    private func nudgeWheeledToy() {
        guard let ball = ballNode else { return }
        let dir: CGFloat = Bool.random() ? 1 : -1
        // The whole toy scoots aside and back; the shadow holds.
        ball.run(.sequence([
            .moveBy(x: dir * frameT() * 0.55, y: 0, duration: 0.18),
            .moveBy(x: -dir * frameT() * 0.55, y: 0, duration: 0.34)
        ]))
        ballSpin?.run(.sequence([
            .rotate(toAngle: -dir * 0.07, duration: 0.18),
            .rotate(toAngle: 0, duration: 0.34)
        ]))
        tone(.single(12, .felt.with(body: 0.16, amplitude: 0.05)), key: "wheelpoke", minInterval: 0.25)
        HapticsManager.shared.impact(style: .soft, intensity: 0.14)
    }

    /// A tap squishes the felt mouse and lets it puff back up.
    private func squishSoftToy() {
        guard blockNode != nil else { return }
        blockVisual?.run(.sequence([
            .group([.scaleX(to: 1.12, duration: 0.10), .scaleY(to: 0.86, duration: 0.10),
                    .rotate(toAngle: 0.06, duration: 0.10)]),
            .group([.scaleX(to: 0.96, duration: 0.14), .scaleY(to: 1.08, duration: 0.14),
                    .rotate(toAngle: -0.03, duration: 0.14)]),
            .group([.scale(to: 1.0, duration: 0.20), .rotate(toAngle: 0, duration: 0.20)])
        ]))
        tone(.single(9, .felt.with(body: 0.18, amplitude: 0.045)), key: "softpoke", minInterval: 0.3)
        HapticsManager.shared.impact(style: .soft, intensity: 0.14)
    }

    private func refreshRugGlow() {
        rugGlow?.removeFromParent()
        guard isOnRug(catCenter), dayPhase > 0.7, lampOn else { return }
        // The floor lamp finds her wherever she's curled on the rug — the room notices.
        let glow = SKSpriteNode(texture: ProceduralTexture.softRadialGlow)
        glow.color = UIColor(hex: 0xFFE08A)
        glow.colorBlendFactor = 1
        glow.blendMode = .add
        glow.alpha = 0.12
        glow.size = CGSize(width: frameT() * 7, height: frameT() * 5)
        glow.position = catCenter
        glow.zPosition = 0.18
        roomLayer.addChild(glow)
        rugGlow = glow
    }

    private func growPot(to stage: Int) {
        guard let pot = flowerPotNode,
              let tex = ToyArt.texture("window-pot-\(stage)") else { return }
        let oldH = pot.size.height
        pot.texture = tex
        let ts = tex.size()
        let fitW = frameT() * 2.4, fitH = frameT() * 3.4
        let scale = min(fitW / max(1, ts.width), fitH / max(1, ts.height))
        pot.size = CGSize(width: ts.width * scale, height: ts.height * scale)
        potCenter = CGPoint(x: pot.position.x, y: pot.position.y + pot.size.height * 0.4)
        if !AmbientAnimator.reduceMotion {
            pot.run(.sequence([
                .scaleY(to: oldH / max(1, pot.size.height), duration: 0),
                .scaleY(to: 1.06, duration: 0.5),
                .scaleY(to: 1.0, duration: 0.3)
            ]))
        }
        for i in 0..<6 {
            let mote = SKShapeNode(circleOfRadius: 2.2)
            mote.fillColor = WarmShelfPalette.butter.withAlpha(0.8)
            mote.strokeColor = .clear
            mote.blendMode = .add
            mote.position = CGPoint(x: potCenter.x + .random(in: -14...14), y: potCenter.y)
            mote.zPosition = 2
            lampLayer.addChild(mote)
            mote.run(.sequence([
                .wait(forDuration: Double(i) * 0.06),
                .group([.moveBy(x: 0, y: 30, duration: 0.9), .fadeOut(withDuration: 0.9)]),
                .removeFromParent()
            ]))
        }
        tone(.arp([9, 12, 16], step: 0.1, .celeste.with(body: 0.5, amplitude: 0.04)), key: "potgrow")
        HapticsManager.shared.impact(style: .soft, intensity: 0.2)
    }

    /// One visiting thing per day, from a basket of returning friends.
    private func buildTodaysGuest() {
        let basket = ["window-suncatcher", "window-guest-boat", "window-guest-duck",
                      "window-guest-yarn", "window-guest-book"].filter { ToyArt.texture($0) != nil }
        guard !basket.isEmpty else { return }
        let slot = basket[(todayStamp / 7 + todayStamp) % basket.count]
        guard let guest = ToyArt.sprite(slot, fit: CGSize(width: frameT() * 2.0, height: frameT() * 2.2)) else { return }
        let sillH = min(windowRect.width, windowRect.height) * 0.09
        let sillTopY = windowRect.minY - sillH * 0.2 + sillH * 0.5
        guestCenter = CGPoint(x: windowCenter.x + windowRect.width * 0.34,
                              y: sillTopY + guest.size.height * 0.42)
        guest.position = guestCenter
        guest.zPosition = 0.48
        frameLayer.addChild(guest)
        guestNode = guest

        let state = LullDemoState.shared
        if state.windowGuestLastDay != todayStamp {
            state.windowGuestLastDay = todayStamp
            guest.alpha = 0
            guest.position.y += 10
            guest.run(.sequence([
                .wait(forDuration: 1.8),
                .group([.fadeIn(withDuration: 0.6),
                        .moveBy(x: 0, y: -10, duration: 0.6)]),
                .run { [weak self] in
                    self?.tone(.single(13, .celeste.with(body: 0.4, amplitude: 0.03)), key: "guest")
                }
            ]))
        }
    }

    /// A gentle idle pulse on the dial invites a child to turn it — no arrows, no words.
    private func inviteDial() {
        guard !AmbientAnimator.reduceMotion else { return }
        dialNode.removeAction(forKey: "inviteDial")
        let pulse = SKAction.run { [weak self] in
            guard let self, self.grabs.isEmpty else { return }
            self.dialKnob.run(.sequence([.scale(to: 1.05, duration: 0.4), .scale(to: 1, duration: 0.5)]))
        }
        dialNode.run(.sequence([.wait(forDuration: 2.6), pulse,
                                .repeatForever(.sequence([.wait(forDuration: 10), pulse]))]), withKey: "inviteDial")
    }

    private func buildRoom() {
        // Authored room plates (Docs/WindowSlice.md): an empty day room and night room
        // cross-fade with the phase; the warm/cool veils still breathe on top of them.
        if let day = ToyArt.texture("window-room-day"), let night = ToyArt.texture("window-room-night") {
            wallNode = nil
            floorNode = nil
            let dayPlate = roomPlate(day)
            dayPlate.zPosition = 0
            roomLayer.addChild(dayPlate)
            let nightPlate = roomPlate(night)
            nightPlate.zPosition = 0.05
            nightPlate.alpha = 0
            roomLayer.addChild(nightPlate)
            roomNight = nightPlate
            buildNookLibrary()
            return
        }
        roomNight = nil

        // Wall fills the scene; floor is a warm band along the bottom. Both recoloured by phase.
        let wall = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        wall.strokeColor = .clear
        wall.zPosition = 0
        roomLayer.addChild(wall)
        wallNode = wall

        let floor = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.width, height: floorTopY))
        floor.strokeColor = .clear
        floor.zPosition = 0.1
        roomLayer.addChild(floor)
        floorNode = floor

        // A soft skirting highlight where floor meets wall.
        let skirt = SKShapeNode(rect: CGRect(x: 0, y: floorTopY - 3, width: size.width, height: 4))
        skirt.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.12)
        skirt.strokeColor = .clear
        skirt.zPosition = 0.2
        roomLayer.addChild(skirt)

        // A cozy patterned round rug under the dial — grounds the lower scene with warm bands.
        // Wrapped in one container so it can fade as a unit when the cat-on-rug composite
        // takes over (she sleeps home on the rug at night).
        let rugSize = CGSize(width: size.width * 0.92, height: floorTopY * 1.15)
        let rugCenter = CGPoint(x: size.width / 2, y: floorTopY * 0.42)
        rugCenterPoint = rugCenter
        let rugContainer = SKNode()
        rugContainer.zPosition = 0.15
        roomLayer.addChild(rugContainer)
        proceduralRug = rugContainer
        let rug = SKShapeNode(ellipseOf: rugSize)
        rug.fillColor = WarmShelfPalette.terracotta.withAlpha(0.2)
        rug.strokeColor = WarmShelfPalette.terracotta.withAlpha(0.34)
        rug.lineWidth = 4
        rug.position = rugCenter
        rugContainer.addChild(rug)
        for (f, c) in [(0.74, WarmShelfPalette.butter), (0.5, WarmShelfPalette.sage), (0.28, WarmShelfPalette.petal)] {
            let ring = SKShapeNode(ellipseOf: CGSize(width: rugSize.width * f, height: rugSize.height * f))
            ring.fillColor = .clear
            ring.strokeColor = c.withAlpha(0.32)
            ring.lineWidth = 2.5
            ring.position = rugCenter
            ring.zPosition = 0.01
            rugContainer.addChild(ring)
        }

        // The authored cat-on-rug, hidden until she's both home here and asleep. Placed at
        // her curl spot (not the rug's centre) so it sits exactly where petting is detected —
        // tapping the visible sleeping cat always lands on her, never on empty floor.
        let curlSpot = CGPoint(x: size.width * 0.30, y: floorTopY * 0.55)
        if let composite = ToyArt.sprite("window-cat-rug", fit: CGSize(width: size.width * 0.36, height: floorTopY * 1.3)) {
            composite.position = curlSpot
            composite.zPosition = 0.17   // on the rug, below props; her own little mat reads as a cushion
            composite.alpha = 0
            roomLayer.addChild(composite)
            catRugComposite = composite
        }
        buildNookLibrary()
    }

    private func buildNookLibrary() {
        guard let shelf = ToyArt.sprite("window-wall-library",
                                        fit: CGSize(width: frameT() * 4.8, height: size.height * 0.24)) else { return }
        // A right-nook wall object: hidden at rest, discovered only when the child leans
        // the room. It rides with the wallpaper, not the foreground props.
        shelf.position = CGPoint(x: size.width + roomPeekMax * 0.48,
                                 y: floorTopY + shelf.size.height * 0.76)
        shelf.zPosition = 0.24
        roomLayer.addChild(shelf)
        wallLibraryNode = shelf
    }

    /// (b) Toggle the cat-on-rug composite. Shown only when she's resting ON the rug AND
    /// asleep; then the movable cat fades away so there's never a second cat. The composite
    /// follows wherever on the rug she was set, so it never teleports from her drop spot.
    private func refreshCatRugComposite() {
        guard let composite = catRugComposite else { return }
        let asleep = !(catIsAwake ?? false)
        let show = isOnRug(catCenter) && asleep
        if show { composite.position = catCenter }   // curl up exactly where she was left
        let dur = AmbientAnimator.reduceMotion ? 0.0 : 0.5
        composite.run(.fadeAlpha(to: show ? 1 : 0, duration: dur), withKey: "catRug")
        sillCat?.run(.fadeAlpha(to: show ? 0 : 1, duration: dur), withKey: "catRug")
    }

    private func buildWindowContents() {
        // Crop everything inside the glass to the arched window opening.
        let cr = min(windowInner.width, windowInner.height) * 0.1
        let mask = SKSpriteNode(texture: GlowWindowScene.archedMaskTexture(size: windowInner.size, bottomRadius: cr))
        mask.position = windowCenter
        windowContent.maskNode = mask

        // Two-stop vertical gradient sky: a solid base + a top colour fading down over it.
        glassBase = SKSpriteNode(color: .white, size: windowInner.size)
        glassBase.position = windowCenter
        glassBase.zPosition = 0
        windowContent.addChild(glassBase)

        glassTop = SKSpriteNode(texture: GlowWindowScene.verticalRamp(size: CGSize(width: 8, height: 64)))
        glassTop.size = windowInner.size
        glassTop.position = windowCenter
        glassTop.colorBlendFactor = 1
        glassTop.zPosition = 0.1
        windowContent.addChild(glassTop)

        // Stars (hidden by day, bloom at night).
        for _ in 0..<22 {
            let s = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.1...2.4))
            s.fillColor = UIColor(hex: 0xFFF6D9)
            s.strokeColor = .clear
            s.position = CGPoint(x: .random(in: windowInner.minX + 8...windowInner.maxX - 8),
                                 y: .random(in: windowCenter.y - windowInner.height * 0.1...windowInner.maxY - 8))
            s.alpha = 0
            s.zPosition = 0.2
            s.setScale(.random(in: 0.7...1.3))
            windowContent.addChild(s)
            stars.append(s)
        }

        // A soft drifting cloud (authored art when present).
        if let art = ToyArt.sprite("window-cloud", fit: CGSize(width: windowInner.width * 0.44, height: windowInner.width * 0.22)) {
            cloudNode = art
        } else {
            cloudNode = makeCloud(width: windowInner.width * 0.4)
        }
        cloudNode.position = CGPoint(x: windowInner.midX, y: windowInner.maxY - windowInner.height * 0.24)
        cloudNode.zPosition = 0.3
        windowContent.addChild(cloudNode)

        // The world outside: plump tree clusters on a soft hill, in front of the setting sun.
        // Built as a day version and a night-silhouette version that cross-fade with the phase.
        // The toy view flattens z globally (ignoresSiblingOrder), so the band must beat the
        // sun/moon DISCS' cumulative z (~2.5 within this crop), not just their parent nodes —
        // otherwise the sun rises in front of the forest.
        treesDay = treeBand(slot: "window-trees-day", day: true)
        treesDay.zPosition = 3.0
        windowContent.addChild(treesDay)
        treesNight = treeBand(slot: "window-trees-night", day: false)
        treesNight.zPosition = 3.06
        treesNight.alpha = 0
        windowContent.addChild(treesNight)

        // The sun: the glow halo is lighting and always procedural; the body is authored
        // art when present, else a warm disc with slowly turning rays and the house face.
        sunNode = SKNode()
        let sunR = min(windowInner.width, windowInner.height) * 0.13
        sunGlow = SKSpriteNode(texture: ProceduralTexture.softRadialGlow)
        sunGlow.size = CGSize(width: sunR * 4.6, height: sunR * 4.6)
        sunGlow.color = UIColor(hex: 0xFFE39A)
        sunGlow.colorBlendFactor = 1
        sunGlow.alpha = 0.46
        sunGlow.zPosition = 0
        sunGlow.blendMode = .add
        sunNode.addChild(sunGlow)
        if !AmbientAnimator.reduceMotion {
            sunGlow.run(.repeatForever(.sequence([.scale(to: 1.07, duration: 2.2), .scale(to: 1.0, duration: 2.2)])))
        }

        if let art = ToyArt.sprite("window-sun", fit: CGSize(width: sunR * 2.4, height: sunR * 2.4)) {
            sunDisc = nil
            // The felt sun carries its own rays; the halo steps back to a soft warmth.
            sunGlow.alpha = 0.3
            sunGlow.setScale(0.82)
            art.zPosition = 1
            sunNode.addChild(art)
        } else {
            let rays = SKNode()
            rays.zPosition = 0.4
            for i in 0..<12 {
                let ray = SKShapeNode(rect: CGRect(x: -sunR * 0.05, y: sunR * 1.25, width: sunR * 0.1, height: sunR * 1.15), cornerRadius: sunR * 0.05)
                ray.fillColor = UIColor(hex: 0xFFEAB0).withAlpha(0.34)
                ray.strokeColor = .clear
                ray.blendMode = .add
                ray.zRotation = CGFloat(i) / 12 * .pi * 2
                rays.addChild(ray)
            }
            sunNode.addChild(rays)
            if !AmbientAnimator.reduceMotion {
                rays.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 64)))
            }

            let disc = SKShapeNode(circleOfRadius: sunR)
            disc.fillColor = UIColor(hex: 0xFFCB45)
            disc.strokeColor = UIColor(hex: 0xFFE9A8).withAlpha(0.7)
            disc.lineWidth = 2
            disc.zPosition = 1
            sunNode.addChild(disc)
            let sunHi = SKShapeNode(ellipseOf: CGSize(width: sunR * 0.9, height: sunR * 0.6))
            sunHi.fillColor = UIColor.white.withAlpha(0.25); sunHi.strokeColor = .clear
            sunHi.position = CGPoint(x: -sunR * 0.28, y: sunR * 0.34); sunHi.zPosition = 1.1
            disc.addChild(sunHi)
            addSleepyFace(to: disc, radius: sunR, ink: UIColor(hex: 0xB8742A), blush: UIColor(hex: 0xFF9E48))
            sunDisc = disc
        }
        sunNode.zPosition = 0.5
        windowContent.addChild(sunNode)

        // The moon: a pale disc with craters + a cool glow.
        moonNode = SKNode()
        let moonR = min(windowInner.width, windowInner.height) * 0.11
        moonGlow = SKSpriteNode(texture: ProceduralTexture.softRadialGlow)
        moonGlow.size = CGSize(width: moonR * 4.8, height: moonR * 4.8)
        moonGlow.color = UIColor(hex: 0xBFD0F2)
        moonGlow.colorBlendFactor = 1
        moonGlow.alpha = 0.4
        moonGlow.blendMode = .add
        moonGlow.zPosition = 0
        moonNode.addChild(moonGlow)
        if let art = ToyArt.sprite("window-moon", fit: CGSize(width: moonR * 2.3, height: moonR * 2.3)) {
            art.zPosition = 1
            moonNode.addChild(art)
        } else {
            let moonDisc = SKShapeNode(circleOfRadius: moonR)
            moonDisc.fillColor = UIColor(hex: 0xFBF6E6)
            moonDisc.strokeColor = UIColor(hex: 0xFFFFFF).withAlpha(0.4)
            moonDisc.lineWidth = 1.5
            moonDisc.zPosition = 1
            moonNode.addChild(moonDisc)
            for _ in 0..<3 {
                let crater = SKShapeNode(circleOfRadius: moonR * CGFloat.random(in: 0.1...0.16))
                crater.fillColor = UIColor(hex: 0xE3DCBE).withAlpha(0.7)
                crater.strokeColor = .clear
                // Craters keep to the upper rim so the sleepy face below stays clean and readable.
                crater.position = CGPoint(x: .random(in: -moonR * 0.5...moonR * 0.5), y: .random(in: moonR * 0.45...moonR * 0.72))
                crater.zPosition = 1.1
                moonDisc.addChild(crater)
            }
            addSleepyFace(to: moonDisc, radius: moonR, ink: UIColor(hex: 0x8C84A8), blush: UIColor(hex: 0xC8B8E0))
        }
        moonNode.alpha = 0
        moonNode.zPosition = 0.5
        windowContent.addChild(moonNode)
        buildWindowLife()
    }

    // MARK: - The living world (layer #1 — creatures that come and go with the day)

    private var fireflies: [SKSpriteNode] = []
    private var butterflies: [SKNode] = []
    private weak var dawnMist: SKShapeNode?
    private var firefliesGlow: CGFloat = 0
    private var lastBalloonTime: TimeInterval = -1
    private var nextBalloonDelay: TimeInterval = 45

    /// The day's cast — hidden until their hour. Fireflies for dusk/night, butterflies for
    /// daylight, a low mist that lifts at dawn. applyPhase fades each in by the dial position.
    private func buildWindowLife() {
        fireflies.removeAll(); butterflies.removeAll()
        // Fireflies hover low, just over the treetops — warm gold so they never read as stars.
        let lo = windowCenter.y - windowInner.height * 0.40
        let hi = windowCenter.y - windowInner.height * 0.08
        for _ in 0..<9 {
            let f = SKSpriteNode(texture: ProceduralTexture.softRadialGlow)
            f.size = CGSize(width: 19, height: 19)
            f.color = UIColor(hex: 0xFFD86A); f.colorBlendFactor = 1; f.blendMode = .add
            f.alpha = 0
            f.position = CGPoint(x: .random(in: windowInner.minX + 18...windowInner.maxX - 18), y: .random(in: lo...hi))
            f.zPosition = 3.2
            windowContent.addChild(f)
            fireflies.append(f)
            if !AmbientAnimator.reduceMotion {
                f.run(.repeatForever(.sequence([
                    .moveBy(x: .random(in: -26...26), y: .random(in: -16...16), duration: .random(in: 2.4...3.6)),
                    .moveBy(x: .random(in: -26...26), y: .random(in: -16...16), duration: .random(in: 2.4...3.6))
                ])))
            }
        }
        for _ in 0..<2 {
            let b = makeButterfly()
            b.alpha = 0
            b.position = CGPoint(x: .random(in: windowInner.minX + 30...windowInner.maxX - 30),
                                 y: .random(in: windowCenter.y - windowInner.height * 0.06...windowCenter.y + windowInner.height * 0.28))
            b.zPosition = 3.3
            windowContent.addChild(b)
            butterflies.append(b)
            if !AmbientAnimator.reduceMotion {
                b.run(.repeatForever(.sequence([
                    .group([.moveBy(x: .random(in: 40...90), y: .random(in: -20...40), duration: .random(in: 3...4.2)), .rotate(toAngle: 0.2, duration: 1.6)]),
                    .group([.moveBy(x: .random(in: -90 ... -40), y: .random(in: -40...20), duration: .random(in: 3...4.2)), .rotate(toAngle: -0.2, duration: 1.6)])
                ])))
            }
        }
        let mist = SKShapeNode(ellipseOf: CGSize(width: windowInner.width * 1.4, height: windowInner.height * 0.46))
        mist.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.55); mist.strokeColor = .clear
        mist.position = CGPoint(x: windowCenter.x, y: windowCenter.y - windowInner.height * 0.16)
        mist.zPosition = 3.05; mist.alpha = 0
        windowContent.addChild(mist)
        dawnMist = mist
    }

    private func makeButterfly() -> SKNode {
        let n = SKNode()
        let c = [WarmShelfPalette.petal, WarmShelfPalette.butter, WarmShelfPalette.lavender].randomElement() ?? .white
        for sign in [CGFloat(-1), 1] {
            let wing = SKShapeNode(ellipseOf: CGSize(width: 9, height: 13))
            wing.fillColor = c.withAlpha(0.92); wing.strokeColor = .clear
            wing.position = CGPoint(x: sign * 4.5, y: 0)
            n.addChild(wing)
            if !AmbientAnimator.reduceMotion {
                wing.run(.repeatForever(.sequence([.scaleX(to: 0.35, duration: 0.13), .scaleX(to: 1.0, duration: 0.15)])))
            }
        }
        let body = SKShapeNode(ellipseOf: CGSize(width: 2.6, height: 9))
        body.fillColor = WarmShelfPalette.cocoa.withAlpha(0.6); body.strokeColor = .clear
        n.addChild(body)
        return n
    }

    /// The rare surprise (panel: one unpredictable thing) — a little hot-air balloon drifts
    /// across the sky now and then in daylight. "Oh, look!"
    private func launchBalloon() {
        let r = windowInner.width * 0.06
        let balloon = SKNode()
        let env = SKShapeNode(ellipseOf: CGSize(width: r * 2, height: r * 2.3))
        env.fillColor = ([WarmShelfPalette.petal, WarmShelfPalette.waterBlue, WarmShelfPalette.butter, WarmShelfPalette.sage].randomElement() ?? .white).withAlpha(0.95)
        env.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.12); env.lineWidth = 1
        balloon.addChild(env)
        let gore = SKShapeNode(rect: CGRect(x: -1.4, y: -r * 1.0, width: 2.8, height: r * 2.2))
        gore.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.5); gore.strokeColor = .clear
        balloon.addChild(gore)
        let basket = SKShapeNode(rect: CGRect(x: -r * 0.28, y: -r * 1.9, width: r * 0.56, height: r * 0.5), cornerRadius: 2)
        basket.fillColor = WarmShelfPalette.cocoa.withAlpha(0.8); basket.strokeColor = .clear
        balloon.addChild(basket)
        for sx in [CGFloat(-1), 1] {
            let line = SKShapeNode(rect: CGRect(x: sx * r * 0.26 - 0.6, y: -r * 1.5, width: 1.2, height: r * 0.6))
            line.fillColor = WarmShelfPalette.cocoa.withAlpha(0.5); line.strokeColor = .clear
            balloon.addChild(line)
        }
        let dir: CGFloat = Bool.random() ? 1 : -1
        let y = windowCenter.y + windowInner.height * .random(in: 0.12...0.3)
        let startX = dir > 0 ? windowInner.minX - r * 3 : windowInner.maxX + r * 3
        let endX = dir > 0 ? windowInner.maxX + r * 3 : windowInner.minX - r * 3
        balloon.position = CGPoint(x: startX, y: y)
        balloon.zPosition = 2.7
        windowContent.addChild(balloon)
        balloon.run(.repeatForever(.sequence([.moveBy(x: 0, y: 7, duration: 1.5), .moveBy(x: 0, y: -7, duration: 1.7)])), withKey: "bob")
        let drift = SKAction.moveTo(x: endX, duration: .random(in: 11...16)); drift.timingMode = .easeInEaseOut
        balloon.run(.sequence([drift, .removeFromParent()]))
    }

    private func makeCloud(width: CGFloat) -> SKNode {
        let cloud = SKNode()
        let puffs: [(CGFloat, CGFloat, CGFloat)] = [(-0.32, 0, 0.5), (0, 0.08, 0.66), (0.3, 0, 0.52), (-0.08, -0.1, 0.42)]
        for (dx, dy, s) in puffs {
            let p = SKShapeNode(circleOfRadius: width * 0.5 * s)
            p.fillColor = UIColor(hex: 0xFFFFFF).withAlpha(0.66)
            p.strokeColor = .clear
            p.position = CGPoint(x: dx * width, y: dy * width)
            cloud.addChild(p)
        }
        return cloud
    }

    /// A room plate, scaled and placed so the art's baseboard line lands exactly on this
    /// scene's floor line (floorTopY) with the canvas still covered above and below —
    /// otherwise the window appears to stand on the rug.
    private func roomPlate(_ tex: SKTexture) -> SKSpriteNode {
        let sprite = SKSpriteNode(texture: tex)
        let ts = tex.size()
        let floorFrac: CGFloat = 0.36   // fraction of plate height below the baseboard in the art
        let needH = max((size.height - floorTopY) / (1 - floorFrac), floorTopY / floorFrac, size.height)
        // Wallpaper extends past both screen edges so the room peek never runs out
        // of house (founder: expand the wallpaper, lose the weird slices).
        let scale = max(needH / max(1, ts.height), (size.width + roomPeekMax * 2.4) / max(1, ts.width))
        sprite.size = CGSize(width: ts.width * scale, height: ts.height * scale)
        let bottomY = floorTopY - sprite.size.height * floorFrac
        sprite.position = CGPoint(x: size.width / 2, y: bottomY + sprite.size.height / 2)
        return sprite
    }

    /// The world outside the glass — authored art if it has landed, otherwise a procedural
    /// stand-in: a hill band with two clusters of plump rounded trees.
    private func treeBand(slot: String, day: Bool) -> SKNode {
        if let tex = ToyArt.texture(slot) {
            let sprite = SKSpriteNode(texture: tex)
            // Outside scenery must tuck under the lower rail/sill. If a keyed tree band
            // ends exactly at the glass bottom, its soft transparent edge exposes a fake
            // strip of sky between the hill and shelf. Slight width overscan plus a buried
            // bottom edge makes the view read like a real landscape behind the window.
            let scale = (windowInner.width * 1.08) / max(1, tex.size().width)
            sprite.size = CGSize(width: tex.size().width * scale, height: tex.size().height * scale)
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
            // In short windows (landscape) the width-fit band would swallow the glass —
            // sink the overflow below the sill so only the treetops keep the view.
            let maxVisible = windowInner.height * 0.48
            let drop = max(0, sprite.size.height - maxVisible)
            let bottomBurial = max(frameT() * 0.75, windowInner.height * 0.045)
            sprite.position = CGPoint(x: windowInner.midX, y: windowInner.minY - bottomBurial - drop)
            return sprite
        }
        let band = SKNode()
        let h = windowInner.height * 0.24
        let hill = SKShapeNode(ellipseOf: CGSize(width: windowInner.width * 1.5, height: h * 1.1))
        hill.fillColor = day ? UIColor(hex: 0x9CC272) : UIColor(hex: 0x2C3554)
        hill.strokeColor = .clear
        hill.position = CGPoint(x: windowInner.midX, y: windowInner.minY + h * 0.1)
        hill.zPosition = 0.1
        band.addChild(hill)
        let light = day ? UIColor(hex: 0x8FBE74) : UIColor(hex: 0x303A5E)
        let dark = day ? UIColor(hex: 0x6E9A55) : UIColor(hex: 0x262F4D)
        let blobs: [(dx: CGFloat, dy: CGFloat, r: CGFloat, dark: Bool)] = [
            (-0.36, 0.5, 0.15, true), (-0.23, 0.74, 0.19, false), (-0.09, 0.5, 0.14, true),
            (0.17, 0.44, 0.12, false), (0.3, 0.62, 0.16, true), (0.43, 0.44, 0.12, false)
        ]
        for b in blobs {
            let tree = SKShapeNode(circleOfRadius: windowInner.width * b.r)
            tree.fillColor = b.dark ? dark : light
            tree.strokeColor = .clear
            tree.position = CGPoint(x: windowInner.midX + windowInner.width * b.dx,
                                    y: windowInner.minY + h * b.dy)
            band.addChild(tree)
        }
        return band
    }

    private func buildGlassAndFrame() {
        // Two soft diagonal reflection streaks on the glass.
        for (i, frac) in [0.28, 0.52].enumerated() {
            let streak = SKShapeNode(rect: CGRect(x: -windowInner.width * 0.04, y: -windowInner.height * 0.5,
                                                  width: windowInner.width * 0.08, height: windowInner.height), cornerRadius: windowInner.width * 0.04)
            streak.fillColor = UIColor.white.withAlpha(i == 0 ? 0.1 : 0.06)
            streak.strokeColor = .clear
            streak.zRotation = 0.32
            streak.position = CGPoint(x: windowInner.minX + windowInner.width * CGFloat(frac), y: windowCenter.y)
            streak.blendMode = .add
            glassLayer.addChild(streak)
        }
        // Clip reflections to the glass too.
        let cr = min(windowInner.width, windowInner.height) * 0.1
        let crop = SKCropNode()
        let mask = SKSpriteNode(texture: GlowWindowScene.archedMaskTexture(size: windowInner.size, bottomRadius: cr))
        mask.position = windowCenter
        crop.maskNode = mask
        glassLayer.children.forEach { node in
            node.removeFromParent(); crop.addChild(node)
        }
        glassLayer.addChild(crop)

        if let tex = ToyArt.texture("window-frame") {
            let frameArt = SKSpriteNode(texture: tex)
            frameArt.name = "window-frame-art"

            // The generated frame includes the sill in its own canvas. Align the visible
            // top of that shelf to the old procedural sill surface so the cat, lamp, and
            // daily guest still rest on the same physical ledge.
            let sillH = min(windowRect.width, windowRect.height) * 0.09
            let shelfTopY = windowRect.minY + sillH * 0.30
            let targetH = windowRect.height * 1.18
            let targetW = windowRect.width * 1.20
            let shelfTopLocalY = -targetH * 0.348
            frameArt.size = CGSize(width: targetW, height: targetH)
            frameArt.position = CGPoint(x: windowCenter.x, y: shelfTopY - shelfTopLocalY)
            frameArt.zPosition = 0.4
            frameLayer.addChild(frameArt)
            return
        }

        // The chunky arched frame — the concept's signature silhouette — plus muntins + a sill.
        let frame = SKShapeNode(path: GlowWindowScene.archedPath(
            in: CGRect(x: -windowRect.width / 2, y: -windowRect.height / 2, width: windowRect.width, height: windowRect.height),
            bottomRadius: windowRect.width * 0.06))
        frame.fillColor = .clear
        frame.strokeColor = woodWarm
        frame.lineWidth = min(windowRect.width, windowRect.height) * 0.15
        frame.position = windowCenter
        frame.zPosition = 0
        frameLayer.addChild(frame)
        // Inner + outer bead lines for carved depth.
        let innerBead = SKShapeNode(path: GlowWindowScene.archedPath(in: windowInner, bottomRadius: windowInner.width * 0.05))
        innerBead.fillColor = .clear; innerBead.strokeColor = woodDark.withAlpha(0.5); innerBead.lineWidth = 3; innerBead.zPosition = 0.2
        frameLayer.addChild(innerBead)
        let innerHi = SKShapeNode(path: GlowWindowScene.archedPath(in: windowInner.insetBy(dx: 2, dy: 2), bottomRadius: windowInner.width * 0.05))
        innerHi.fillColor = .clear; innerHi.strokeColor = WarmShelfPalette.paperHighlight.withAlpha(0.4); innerHi.lineWidth = 2; innerHi.zPosition = 0.25
        frameLayer.addChild(innerHi)

        // Muntins: a cross in the lower panes, a springline bar where the arch begins, and a
        // small fan of spokes through the lunette — reads as a real arched window.
        let archH = min(windowInner.width / 2, windowInner.height * 0.34)
        let springY = windowInner.maxY - archH
        let vBar = SKShapeNode(rect: CGRect(x: windowCenter.x - frameT() / 3, y: windowInner.minY, width: frameT() * 0.66, height: springY - windowInner.minY), cornerRadius: frameT() * 0.3)
        vBar.fillColor = woodWarm; vBar.strokeColor = woodDark.withAlpha(0.4); vBar.lineWidth = 1; vBar.zPosition = 0.3
        frameLayer.addChild(vBar)
        let hBar = SKShapeNode(rect: CGRect(x: windowInner.minX, y: (windowInner.minY + springY) / 2 - frameT() / 3, width: windowInner.width, height: frameT() * 0.66), cornerRadius: frameT() * 0.3)
        hBar.fillColor = woodWarm; hBar.strokeColor = woodDark.withAlpha(0.4); hBar.lineWidth = 1; hBar.zPosition = 0.3
        frameLayer.addChild(hBar)
        let springBar = SKShapeNode(rect: CGRect(x: windowInner.minX, y: springY - frameT() / 3, width: windowInner.width, height: frameT() * 0.66), cornerRadius: frameT() * 0.3)
        springBar.fillColor = woodWarm; springBar.strokeColor = woodDark.withAlpha(0.4); springBar.lineWidth = 1; springBar.zPosition = 0.3
        frameLayer.addChild(springBar)
        let spokeAngles: [CGFloat] = [.pi * 0.3, .pi * 0.5, .pi * 0.7]
        for a in spokeAngles {
            let spokeEndX: CGFloat = windowCenter.x + cos(a) * windowInner.width * 0.5
            let spokeEndY: CGFloat = springY + sin(a) * archH
            let spokePath = CGMutablePath()
            spokePath.move(to: CGPoint(x: windowCenter.x, y: springY))
            spokePath.addLine(to: CGPoint(x: spokeEndX, y: spokeEndY))
            let spoke = SKShapeNode(path: spokePath)
            spoke.strokeColor = woodWarm; spoke.lineWidth = frameT() * 0.5; spoke.lineCap = .round; spoke.zPosition = 0.3
            frameLayer.addChild(spoke)
        }

        // Window sill.
        let sillW = windowRect.width * 1.16, sillH = min(windowRect.width, windowRect.height) * 0.09
        let sill = SKShapeNode(rect: CGRect(x: -sillW / 2, y: -sillH / 2, width: sillW, height: sillH), cornerRadius: sillH * 0.4)
        sill.fillColor = woodWarm; sill.strokeColor = woodDark.withAlpha(0.4); sill.lineWidth = 2
        sill.position = CGPoint(x: windowCenter.x, y: windowRect.minY - sillH * 0.2)
        sill.zPosition = 0.4
        frameLayer.addChild(sill)
        let sillHi = SKShapeNode(rect: CGRect(x: -sillW / 2 + 6, y: sillH * 0.12, width: sillW - 12, height: sillH * 0.16), cornerRadius: sillH * 0.1)
        sillHi.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.3); sillHi.strokeColor = .clear
        sillHi.position = sill.position; sillHi.zPosition = 0.45
        frameLayer.addChild(sillHi)
    }

    private func frameT() -> CGFloat { min(windowRect.width, windowRect.height) * 0.075 }

    /// A little sleeping cat loafed on the sill — the most recognizable "cozy window at home"
    /// friend there is. It breathes slowly; tap it for a stretch, a tail flick, and a soft purr.
    private func buildSillCat() {
        let s = frameT() * 1.15
        catCenter = CGPoint(x: windowCenter.x + windowRect.width * 0.24, y: windowRect.minY + s * 0.58)
        catHitRadius = s * 2.3

        let cat = SKNode()
        cat.position = catCenter
        cat.zPosition = 0.5   // on the sill, in front of the glass; closed curtains still cover it
        frameLayer.addChild(cat)
        sillCat = cat

        // Authored cat (Docs/WindowSlice.md): an asleep base with the awake art stacked on
        // top — waking is a slow cross-fade plus a tiny stir, never a snap (playtest note).
        if let asleepTex = ToyArt.texture("window-cat-asleep") {
            let fit = CGSize(width: s * 3.6, height: s * 2.6)
            let sprite = SKSpriteNode(texture: asleepTex)
            let scale = min(fit.width / max(1, asleepTex.size().width), fit.height / max(1, asleepTex.size().height))
            sprite.size = CGSize(width: asleepTex.size().width * scale, height: asleepTex.size().height * scale)
            cat.addChild(sprite)
            catSprite = sprite
            if let awakeTex = ToyArt.texture("window-cat-awake") {
                let awake = SKSpriteNode(texture: awakeTex)
                let aScale = min(fit.width / max(1, awakeTex.size().width), fit.height / max(1, awakeTex.size().height))
                awake.size = CGSize(width: awakeTex.size().width * aScale, height: awakeTex.size().height * aScale)
                awake.anchorPoint = CGPoint(x: 0.5, y: 0)
                awake.position = CGPoint(x: 0, y: -sprite.size.height / 2)  // share the cushion's base line
                awake.alpha = 0
                awake.zPosition = 0.05
                cat.addChild(awake)
                catAwakeSprite = awake
                if !AmbientAnimator.reduceMotion {
                    awake.run(.repeatForever(.sequence([
                        .scaleY(to: 1.04, duration: 1.7), .scaleY(to: 1.0, duration: 1.9)
                    ])))
                }
            }
            catEyes.removeAll()
            catGlints.removeAll()
            catScale = s
            catIsAwake = nil
            if !AmbientAnimator.reduceMotion {
                sprite.run(.repeatForever(.sequence([
                    .scaleY(to: 1.04, duration: 1.7), .scaleY(to: 1.0, duration: 1.9)
                ])))
            }
            return
        }

        let fur = UIColor(hex: 0x9A7E6C)
        let furDark = UIColor(hex: 0x7C6354)

        let tail = SKShapeNode()
        let tailPath = CGMutablePath()
        tailPath.move(to: CGPoint(x: s * 1.0, y: -s * 0.28))
        tailPath.addQuadCurve(to: CGPoint(x: s * 1.85, y: s * 0.45), control: CGPoint(x: s * 2.05, y: -s * 0.4))
        tail.path = tailPath
        tail.strokeColor = furDark
        tail.lineWidth = s * 0.32
        tail.lineCap = .round
        tail.zPosition = -0.1
        cat.addChild(tail)
        catTail = tail

        let body = SKShapeNode(ellipseOf: CGSize(width: s * 2.5, height: s * 1.3))
        body.fillColor = fur
        body.strokeColor = furDark.withAlpha(0.5)
        body.lineWidth = 1.5
        cat.addChild(body)

        let head = SKShapeNode(circleOfRadius: s * 0.72)
        head.fillColor = fur
        head.strokeColor = furDark.withAlpha(0.5)
        head.lineWidth = 1.5
        head.position = CGPoint(x: -s * 0.95, y: s * 0.35)
        head.zPosition = 0.1
        cat.addChild(head)

        for ex in [-s * 0.34, s * 0.3] {
            let earPath = CGMutablePath()
            earPath.move(to: CGPoint(x: ex - s * 0.17, y: s * 0.48))
            earPath.addLine(to: CGPoint(x: ex + s * 0.17, y: s * 0.48))
            earPath.addLine(to: CGPoint(x: ex, y: s * 0.84))
            earPath.closeSubpath()
            let ear = SKShapeNode(path: earPath)
            ear.fillColor = furDark
            ear.strokeColor = .clear
            ear.zPosition = -0.05
            head.addChild(ear)
        }

        catEyes.removeAll()
        catGlints.removeAll()
        for ex in [-s * 0.26, s * 0.22] {
            let eye = SKShapeNode(path: GlowWindowScene.catEyePath(open: false, around: ex, s: s))
            eye.strokeColor = UIColor(hex: 0x4A3328)
            eye.fillColor = .clear
            eye.lineWidth = max(1.5, s * 0.06)
            eye.lineCap = .round
            eye.zPosition = 0.2
            head.addChild(eye)
            // The concept-art catchlight — a tiny white sparkle that only shows when awake.
            let glint = SKShapeNode(circleOfRadius: s * 0.045)
            glint.name = "glint"
            glint.fillColor = .white.withAlpha(0.95)
            glint.strokeColor = .clear
            glint.position = CGPoint(x: ex - s * 0.03, y: s * 0.06)
            glint.zPosition = 0.25
            glint.alpha = 0
            head.addChild(glint)
            catEyes.append((node: eye, offsetX: ex))
            catGlints.append(glint)
        }
        catScale = s
        catIsAwake = nil   // forces the first phase update to style the eyes

        if !AmbientAnimator.reduceMotion {
            body.run(.repeatForever(.sequence([
                .scaleY(to: 1.05, duration: 1.7), .scaleY(to: 1.0, duration: 1.9)
            ])))
            // Every little while the tail does one slow, contented sweep on its own.
            tail.run(.repeatForever(.sequence([
                .wait(forDuration: .random(in: 6...10)),
                .rotate(toAngle: 0.12, duration: 0.9),
                .rotate(toAngle: 0, duration: 1.1)
            ])), withKey: "idleWag")
        }
    }

    private static func catEyePath(open: Bool, around ex: CGFloat, s: CGFloat) -> CGPath {
        if open {
            // Bigger, rounder glossy button-eyes (concept-art proportions).
            return CGPath(ellipseIn: CGRect(x: ex - s * 0.11, y: -s * 0.08, width: s * 0.22, height: s * 0.26), transform: nil)
        }
        let p = CGMutablePath()
        p.move(to: CGPoint(x: ex - s * 0.12, y: s * 0.02))
        p.addQuadCurve(to: CGPoint(x: ex + s * 0.12, y: s * 0.02), control: CGPoint(x: ex, y: -s * 0.1))
        return p
    }

    /// By day the cat is softly awake (little open eyes); by night it sleeps. Cheap path swap.
    private func updateCat(awake: Bool) {
        guard catIsAwake != awake else { return }
        catIsAwake = awake
        refreshCatRugComposite()   // asleep-on-rug swaps to the authored composite
        if let base = catSprite {
            guard let overlay = catAwakeSprite else { return }
            overlay.removeAction(forKey: "wake")
            base.removeAction(forKey: "wake")
            if AmbientAnimator.reduceMotion {
                overlay.alpha = awake ? 1 : 0
                base.alpha = awake ? 0 : 1
            } else {
                // True cross-fade — the sleeping cat dissolves as the woken one arrives,
                // so the two poses never read as two cats.
                let inFade = SKAction.fadeAlpha(to: awake ? 1 : 0, duration: 0.5)
                inFade.timingMode = .easeInEaseOut
                let outFade = SKAction.fadeAlpha(to: awake ? 0 : 1, duration: 0.5)
                outFade.timingMode = .easeInEaseOut
                overlay.run(inFade, withKey: "wake")
                base.run(outFade, withKey: "wake")
                sillCat?.run(.sequence([.scale(to: 1.04, duration: 0.18), .scale(to: 1.0, duration: 0.34)]))
            }
            return
        }
        for eye in catEyes {
            eye.node.path = GlowWindowScene.catEyePath(open: awake, around: eye.offsetX, s: catScale)
            eye.node.fillColor = awake ? UIColor(hex: 0x241710) : .clear   // glossy near-black buttons
            eye.node.strokeColor = awake ? .clear : UIColor(hex: 0x4A3328)
        }
        for glint in catGlints {
            glint.run(.fadeAlpha(to: awake ? 1 : 0, duration: 0.25))
        }
    }

    private func catStretch() {
        guard let cat = sillCat else { return }
        if dayPhase < 0.58 {
            AudioManager.shared.playWindowCatHappy()
        } else {
            tone(.single(1, .breath.with(body: 0.5, amplitude: 0.035, noiseGain: 0.45)), key: "cat.purr", minInterval: 0.6)
        }
        HapticsManager.shared.impact(style: .soft, intensity: 0.14)

        // At night a petted cat sends up little love hearts — the sleepiest thank-you there is.
        emitCatLoveHearts(count: 3, force: false)

        guard !AmbientAnimator.reduceMotion else { return }
        cat.removeAction(forKey: "stretch")
        cat.run(.sequence([
            .group([.scaleX(to: 1.1, duration: 0.18), .scaleY(to: 0.94, duration: 0.18)]),
            .group([.scaleX(to: 1.0, duration: 0.32), .scaleY(to: 1.0, duration: 0.32)])
        ]), withKey: "stretch")
        // A proper happy wag: two full swishes, then settle.
        catTail?.run(.sequence([
            .rotate(toAngle: 0.22, duration: 0.13), .rotate(toAngle: -0.14, duration: 0.16),
            .rotate(toAngle: 0.18, duration: 0.14), .rotate(toAngle: -0.08, duration: 0.16),
            .rotate(toAngle: 0, duration: 0.18)
        ]))
    }

    private func emitCatLoveHearts(count: Int, force: Bool) {
        guard force || dayPhase > 0.6 else { return }
        guard !AmbientAnimator.reduceMotion else { return }
        for i in 0..<count {
            let heart = SKShapeNode(path: GlowWindowScene.tinyHeartPath(size: catScale * CGFloat.random(in: 0.32...0.46)))
            heart.fillColor = WarmShelfPalette.petal.withAlpha(0.85)
            heart.strokeColor = .clear
            heart.position = CGPoint(x: catCenter.x + .random(in: -catScale...catScale),
                                     y: catCenter.y + catScale * 0.8)
            heart.zPosition = 2.5
            heart.alpha = 0
            addChild(heart)
            let rise = SKAction.moveBy(x: .random(in: -10...10),
                                       y: catScale * CGFloat.random(in: 1.8...2.6),
                                       duration: 1.2)
            rise.timingMode = .easeOut
            heart.run(.sequence([
                .wait(forDuration: Double(i) * 0.16),
                .group([rise, .sequence([.fadeIn(withDuration: 0.18), .wait(forDuration: 0.5), .fadeOut(withDuration: 0.5)])]),
                .removeFromParent()
            ]))
        }
    }

    private func catReceivesToy(_ toy: SKNode?) -> Bool {
        guard let toy else { return false }
        let nearCat = hypot(toy.position.x - catCenter.x, toy.position.y - catCenter.y) < catHitRadius + frameT() * 1.2
        guard nearCat else { return false }
        emitCatLoveHearts(count: 4, force: true)
        if !AmbientAnimator.reduceMotion {
            sillCat?.run(.sequence([
                .group([.scaleX(to: 1.06, duration: 0.14), .scaleY(to: 0.96, duration: 0.14)]),
                .group([.scaleX(to: 1.0, duration: 0.28), .scaleY(to: 1.0, duration: 0.28)])
            ]), withKey: "toyLove")
            toy.run(.sequence([
                .moveBy(x: 0, y: frameT() * 0.22, duration: 0.12),
                .moveBy(x: 0, y: -frameT() * 0.22, duration: 0.22)
            ]), withKey: "offered")
            catTail?.run(.sequence([
                .rotate(toAngle: 0.24, duration: 0.12),
                .rotate(toAngle: -0.12, duration: 0.14),
                .rotate(toAngle: 0, duration: 0.18)
            ]))
        }
        tone(.arp([7, 11, 14], step: 0.08, .celeste.with(body: 0.35, amplitude: 0.035)), key: "cat.toy", minInterval: 0.5)
        HapticsManager.shared.impact(style: .soft, intensity: 0.18)
        return true
    }

    /// The house face: closed sleepy-arc eyes, a soft smile, rosy cheeks — the same charm the
    /// toys wear, so the sun and moon belong to the same family.
    private func addSleepyFace(to disc: SKShapeNode, radius r: CGFloat, ink: UIColor, blush: UIColor) {
        for sx in [-r * 0.36, r * 0.36] {
            let eyePath = CGMutablePath()
            eyePath.move(to: CGPoint(x: sx - r * 0.16, y: r * 0.08))
            eyePath.addQuadCurve(to: CGPoint(x: sx + r * 0.16, y: r * 0.08), control: CGPoint(x: sx, y: -r * 0.06))
            let eye = SKShapeNode(path: eyePath)
            eye.strokeColor = ink; eye.lineWidth = max(1.5, r * 0.07); eye.lineCap = .round; eye.fillColor = .clear
            eye.zPosition = 1.3
            disc.addChild(eye)
        }
        let smilePath = CGMutablePath()
        smilePath.move(to: CGPoint(x: -r * 0.2, y: -r * 0.26))
        smilePath.addQuadCurve(to: CGPoint(x: r * 0.2, y: -r * 0.26), control: CGPoint(x: 0, y: -r * 0.42))
        let smile = SKShapeNode(path: smilePath)
        smile.strokeColor = ink; smile.lineWidth = max(1.5, r * 0.07); smile.lineCap = .round; smile.fillColor = .clear
        smile.zPosition = 1.3
        disc.addChild(smile)
        for sx in [-r * 0.58, r * 0.58] {
            let cheek = SKShapeNode(ellipseOf: CGSize(width: r * 0.3, height: r * 0.18))
            cheek.fillColor = blush.withAlpha(0.4); cheek.strokeColor = .clear
            cheek.position = CGPoint(x: sx, y: -r * 0.12); cheek.zPosition = 1.25
            disc.addChild(cheek)
        }
    }

    private static func tinyHeartPath(size s: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0, y: -s * 0.45))
        p.addCurve(to: CGPoint(x: -s * 0.5, y: s * 0.18), control1: CGPoint(x: -s * 0.42, y: -s * 0.18), control2: CGPoint(x: -s * 0.5, y: 0))
        p.addArc(center: CGPoint(x: -s * 0.25, y: s * 0.22), radius: s * 0.26, startAngle: .pi, endAngle: 0, clockwise: false)
        p.addArc(center: CGPoint(x: s * 0.25, y: s * 0.22), radius: s * 0.26, startAngle: .pi, endAngle: 0, clockwise: false)
        p.addCurve(to: CGPoint(x: 0, y: -s * 0.45), control1: CGPoint(x: s * 0.5, y: 0), control2: CGPoint(x: s * 0.42, y: -s * 0.18))
        p.closeSubpath()
        return p
    }

    private func buildBeam() {
        // Light raking from the window across the floor. Real sunlight/moonlight has no
        // hard edge (founder: the line was too harsh) — so the trapezoid is wrapped in a
        // big Gaussian blur that feathers its sides and dissipates its far end. It also
        // spreads wider as it falls. Phase recolours the fill; the blur does the softness.
        let path = CGMutablePath()
        let topL = CGPoint(x: windowInner.minX + windowInner.width * 0.12, y: windowRect.minY)
        let topR = CGPoint(x: windowInner.maxX - windowInner.width * 0.12, y: windowRect.minY)
        let botL = CGPoint(x: windowInner.minX - windowInner.width * 0.46, y: 0)
        let botR = CGPoint(x: windowInner.maxX + windowInner.width * 0.46, y: 0)
        path.move(to: topL); path.addLine(to: topR); path.addLine(to: botR); path.addLine(to: botL); path.closeSubpath()
        beamNode = SKShapeNode(path: path)
        beamNode.fillColor = UIColor(hex: 0xFFE6A8)
        beamNode.strokeColor = .clear
        beamNode.zPosition = 0

        let soft = SKEffectNode()
        soft.shouldRasterize = false   // re-blurs as the phase recolours the fill
        soft.filter = CIFilter(name: "CIGaussianBlur",
                               parameters: ["inputRadius": min(windowInner.width, windowInner.height) * 0.085])
        soft.blendMode = .add
        soft.zPosition = 0
        soft.addChild(beamNode)
        beamLayer.addChild(soft)
        beamEffect = soft
    }

    private func buildLamp() {
        // Authored floor lamp: a real room object, not a charm perched on the sill. It
        // sits low-left on the floor so the window remains the hero and the shelf stays
        // believable as a place where the cat and small guests can rest.
        if let offTex = ToyArt.texture("window-floor-lamp-off") {
            lampShade = nil
            let baseY = floorTopY * 0.16
            let fitH = min(size.height * (isLandscapeLayout ? 0.50 : 0.39),
                           max(floorTopY * 1.32, windowRect.minY - baseY + frameT() * 1.45))
            let fit = CGSize(width: fitH * 0.38, height: fitH)
            let ts = offTex.size()
            let artScale = min(fit.width / max(1, ts.width), fit.height / max(1, ts.height))
            let lamp = SKSpriteNode(texture: offTex)
            lamp.size = CGSize(width: ts.width * artScale, height: ts.height * artScale)
            lamp.anchorPoint = CGPoint(x: 0.5, y: 0.02)
            let lampX = max(lamp.size.width * 0.62, min(size.width * 0.18, windowRect.minX + lamp.size.width * 0.34))
            lamp.position = CGPoint(x: lampX, y: baseY)
            lamp.zPosition = 0.47
            lampLayer.addChild(lamp)
            lampSprite = lamp
            // The tap target follows the shade, not the whole pole, so floor-toy drags
            // near the base don't accidentally toggle the light.
            lampShadeCenter = CGPoint(x: lamp.position.x, y: lamp.position.y + lamp.size.height * 0.78)
            lampShadeSize = CGSize(width: lamp.size.width * 1.34, height: lamp.size.height * 0.30)
            lampGlow = SKSpriteNode(texture: ProceduralTexture.softRadialGlow)
            lampGlow.color = UIColor(hex: 0xFFC65A)
            lampGlow.colorBlendFactor = 1
            lampGlow.size = CGSize(width: lamp.size.width * 2.35, height: lamp.size.width * 2.05)
            lampGlow.blendMode = .add
            lampGlow.position = lampShadeCenter
            lampGlow.zPosition = lamp.zPosition - 0.02
            lampGlow.alpha = 0
            lampLayer.addChild(lampGlow)
            return
        }
        lampSprite = nil

        // Procedural fallback: still a left floor lamp, never the retired sill star.
        let lampX = max(size.width * 0.13, windowRect.minX + dialRadius * 0.30)
        let baseY = floorTopY * 0.16
        lampShadeSize = CGSize(width: dialRadius * 1.1, height: dialRadius * 0.82)
        // Keep the shade clear of the glass AND the curtains: when the lamp sits in front of the
        // window horizontally (portrait, where the window is wide), drop the shade well below the
        // sill so it never overlaps the hanging curtains.
        let overlapsWindow = abs(lampX - windowCenter.x) < windowRect.width / 2 + lampShadeSize.width * 0.5
        let highY = floorTopY + size.height * (isLandscapeLayout ? 0.2 : 0.13)
        let belowWindowY = windowRect.minY - lampShadeSize.height * 1.15
        lampShadeCenter = CGPoint(x: lampX, y: overlapsWindow ? min(highY, belowWindowY) : highY)

        // glow first (under the shade), additive.
        lampGlow = SKSpriteNode(texture: ProceduralTexture.softRadialGlow)
        lampGlow.color = UIColor(hex: 0xFFC65A)
        lampGlow.colorBlendFactor = 1
        lampGlow.size = CGSize(width: lampShadeSize.width * 2.5, height: lampShadeSize.width * 2.15)
        lampGlow.blendMode = .add
        lampGlow.position = lampShadeCenter
        lampGlow.zPosition = -0.1
        lampGlow.alpha = 0
        lampLayer.addChild(lampGlow)

        // stand
        let stand = SKShapeNode(rect: CGRect(x: lampX - 3, y: baseY, width: 6, height: lampShadeCenter.y - baseY), cornerRadius: 3)
        stand.fillColor = woodDark; stand.strokeColor = .clear; stand.zPosition = 0
        lampLayer.addChild(stand)
        let foot = SKShapeNode(ellipseOf: CGSize(width: lampShadeSize.width * 0.7, height: 12))
        foot.fillColor = woodDark; foot.strokeColor = .clear
        foot.position = CGPoint(x: lampX, y: baseY); foot.zPosition = 0.1
        lampLayer.addChild(foot)

        // shade (a trapezoid)
        let sw = lampShadeSize.width, sh = lampShadeSize.height
        let shadePath = CGMutablePath()
        shadePath.move(to: CGPoint(x: -sw * 0.34, y: sh / 2))
        shadePath.addLine(to: CGPoint(x: sw * 0.34, y: sh / 2))
        shadePath.addLine(to: CGPoint(x: sw * 0.5, y: -sh / 2))
        shadePath.addLine(to: CGPoint(x: -sw * 0.5, y: -sh / 2))
        shadePath.closeSubpath()
        let shade = SKShapeNode(path: shadePath)
        shade.fillColor = UIColor(hex: 0xE8B765)
        shade.strokeColor = woodDark.withAlpha(0.4)
        shade.lineWidth = 2
        shade.position = lampShadeCenter
        shade.zPosition = 1
        lampLayer.addChild(shade)
        ProceduralTexture.applyClayFill(to: shade, base: UIColor(hex: 0xE8B765), size: CGSize(width: sw, height: sh))
        lampShade = shade
        let shadeHi = SKShapeNode(rect: CGRect(x: -sw * 0.26, y: sh * 0.16, width: sw * 0.52, height: sh * 0.16), cornerRadius: 4)
        shadeHi.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.32); shadeHi.strokeColor = .clear
        shadeHi.position = lampShadeCenter; shadeHi.zPosition = 1.1
        lampLayer.addChild(shadeHi)
        // A warm light-lip at the shade's open bottom — where the bulb's glow pours out.
        let lightLip = SKShapeNode(rect: CGRect(x: -sw * 0.5, y: -sh * 0.5 - 2, width: sw, height: 5), cornerRadius: 2.5)
        lightLip.fillColor = UIColor(hex: 0xFFE6A0).withAlpha(0.55); lightLip.strokeColor = .clear
        lightLip.position = lampShadeCenter; lightLip.zPosition = 1.15
        lampLayer.addChild(lightLip)
        // A short neck joining the shade to the stand, so it reads as one object.
        let neck = SKShapeNode(rect: CGRect(x: lampX - 4, y: lampShadeCenter.y - sh * 0.5 - 9, width: 8, height: 11), cornerRadius: 3)
        neck.fillColor = woodDark; neck.strokeColor = .clear; neck.zPosition = 0.95
        lampLayer.addChild(neck)
    }

    private func buildFloorPlant() {
        // A leafy potted plant on the floor, balancing the lamp — pointed two-tone leaves on soft
        // stems rising from the soil, so it reads as a real little houseplant, not a green blob.
        let s = dialRadius
        let plant = SKNode()
        plant.position = CGPoint(x: size.width * (isLandscapeLayout ? 0.1 : 0.13), y: floorTopY * 0.42)
        // Cumulative z: the sill sits at 1.6+0.4=2.0; the plant stands on the floor IN
        // FRONT of the wall, so it must beat the sill (founder QA: sill drew over it).
        plant.zPosition = 0.5
        lampLayer.addChild(plant)
        plantNode = plant
        plantCenter = plant.position
        plantHitRadius = s * 1.5
        // The same little plant lives in more than one room of this house — if the window
        // hasn't its own art yet, borrow Feed's (it is the identical prop).
        if let art = ToyArt.sprite("window-plant", fit: CGSize(width: s * 2.1, height: s * 2.7))
                  ?? ToyArt.sprite("feed-plant", fit: CGSize(width: s * 2.1, height: s * 2.7)) {
            art.position = CGPoint(x: 0, y: art.size.height * 0.5)   // pot base sits on the floor line
            plant.addChild(art)
            return
        }
        let pw = s * 0.92, ph = s * 0.74

        let shadow = SKShapeNode(ellipseOf: CGSize(width: pw * 1.7, height: ph * 0.32))
        shadow.fillColor = WarmShelfPalette.contactShadow.withAlpha(0.16); shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: ph * 0.05); shadow.zPosition = -0.3
        plant.addChild(shadow)

        // Leaves rise from the soil and fan out (behind the pot rim).
        let soilY = ph * 0.88
        let leafSpecs: [(angle: CGFloat, len: CGFloat, dark: Bool)] = [
            (-0.75, 0.85, true), (0.75, 0.9, true),
            (-0.4, 1.1, false), (0.42, 1.12, false),
            (-0.14, 1.34, true), (0.16, 1.38, false), (0.0, 1.5, false)
        ]
        for spec in leafSpecs {
            let leafLen = pw * 0.92 * spec.len
            let leaf = SKShapeNode(path: GlowWindowScene.leafPath(length: leafLen, width: pw * 0.32))
            leaf.fillColor = spec.dark ? UIColor(hex: 0x6E9350) : UIColor(hex: 0x87AD5F)
            leaf.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.16); leaf.lineWidth = 1
            leaf.position = CGPoint(x: 0, y: soilY)
            leaf.zRotation = spec.angle; leaf.zPosition = -0.1
            plant.addChild(leaf)
            let vein = SKShapeNode()
            let vp = CGMutablePath(); vp.move(to: .zero); vp.addLine(to: CGPoint(x: 0, y: leafLen * 0.88))
            vein.path = vp; vein.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.12); vein.lineWidth = max(1, pw * 0.028); vein.lineCap = .round
            vein.position = leaf.position; vein.zRotation = spec.angle; vein.zPosition = -0.09
            plant.addChild(vein)
        }

        // Soil + chunky terracotta pot (in front of the leaf bases).
        let soil = SKShapeNode(ellipseOf: CGSize(width: pw * 0.92, height: ph * 0.18))
        soil.fillColor = UIColor(hex: 0x4A2E1C); soil.strokeColor = .clear
        soil.position = CGPoint(x: 0, y: soilY); soil.zPosition = 0.05
        plant.addChild(soil)
        let pot = SKShapeNode(path: {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -pw * 0.5, y: ph)); p.addLine(to: CGPoint(x: pw * 0.5, y: ph))
            p.addLine(to: CGPoint(x: pw * 0.38, y: 0)); p.addLine(to: CGPoint(x: -pw * 0.38, y: 0))
            p.closeSubpath(); return p
        }())
        pot.fillColor = WarmShelfPalette.terracotta
        pot.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.3); pot.lineWidth = 1.5
        pot.zPosition = 0.1
        plant.addChild(pot)
        ProceduralTexture.applyClayFill(to: pot, base: WarmShelfPalette.terracotta, size: CGSize(width: pw, height: ph))
        let rim = SKShapeNode(rect: CGRect(x: -pw * 0.54, y: ph * 0.8, width: pw * 1.08, height: ph * 0.28), cornerRadius: ph * 0.12)
        rim.fillColor = WarmShelfPalette.terracotta
        rim.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.28); rim.lineWidth = 1.5
        rim.zPosition = 0.12
        plant.addChild(rim)
        let rimHi = SKShapeNode(rect: CGRect(x: -pw * 0.42, y: ph * 0.92, width: pw * 0.84, height: ph * 0.06), cornerRadius: 3)
        rimHi.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.3); rimHi.strokeColor = .clear; rimHi.zPosition = 0.13
        plant.addChild(rimHi)
    }

    private static func leafPath(length: CGFloat, width: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.move(to: .zero)
        p.addQuadCurve(to: CGPoint(x: 0, y: length), control: CGPoint(x: width, y: length * 0.5))
        p.addQuadCurve(to: .zero, control: CGPoint(x: -width, y: length * 0.5))
        p.closeSubpath()
        return p
    }

    private static func softStarPath(outer: CGFloat, inner: CGFloat) -> CGPath {
        let p = CGMutablePath()
        for i in 0..<10 {
            let radius = i.isMultiple(of: 2) ? outer : inner
            let a = -CGFloat.pi / 2 + CGFloat(i) * CGFloat.pi / 5
            let point = CGPoint(x: cos(a) * radius, y: sin(a) * radius)
            if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        p.closeSubpath()
        return p
    }

    private func buildCurtains() {
        // Two chunky fabric panels hanging over the window, draggable open/closed.
        let rodY = windowRect.maxY + frameT() * 0.4
        let panelH = windowRect.height + frameT() * 1.2
        let panelW = windowRect.width * 0.46
        curtainRestX = windowRect.width * 0.52   // open: tucked well out to the sides (gathered narrow)

        // A rod across the top (extended so the gathered panels still sit under it when open).
        let rod = SKShapeNode(rect: CGRect(x: windowCenter.x - windowRect.width * 0.72, y: rodY - 5, width: windowRect.width * 1.44, height: 10), cornerRadius: 5)
        rod.fillColor = woodDark; rod.strokeColor = .clear; rod.zPosition = 1
        curtainLayer.addChild(rod)
        for sx in [-1, 1] {
            let cap = SKShapeNode(circleOfRadius: 9)
            cap.fillColor = woodWarm; cap.strokeColor = woodDark.withAlpha(0.4); cap.lineWidth = 1.5
            cap.position = CGPoint(x: windowCenter.x + CGFloat(sx) * windowRect.width * 0.72, y: rodY)
            cap.zPosition = 1.1
            curtainLayer.addChild(cap)
        }

        let linen = UIColor(hex: 0xF3EADA)   // concept palette: soft cream linen panels
        curtainL = makeCurtainPanel(width: panelW, height: panelH, color: linen, mirrored: false)
        curtainR = makeCurtainPanel(width: panelW, height: panelH, color: linen, mirrored: true)
        curtainL.position = CGPoint(x: windowCenter.x - curtainRestX, y: rodY)
        curtainR.position = CGPoint(x: windowCenter.x + curtainRestX, y: rodY)
        curtainL.zPosition = 0.6
        curtainR.zPosition = 0.6
        curtainLayer.addChild(curtainL)
        curtainLayer.addChild(curtainR)
    }

    /// A panel anchored at the top (rod), hanging down, with vertical fold shading.
    private func makeCurtainPanel(width w: CGFloat, height h: CGFloat, color: UIColor, mirrored: Bool) -> SKNode {
        let node = SKNode()
        if let tex = ToyArt.texture("window-curtain-panel") {
            let sprite = SKSpriteNode(texture: tex)
            sprite.anchorPoint = CGPoint(x: 0.5, y: 1)   // hangs from the rod
            sprite.size = CGSize(width: w, height: h)
            node.addChild(sprite)
            node.xScale = mirrored ? -1 : 1
            return node
        }
        // Less pillowy, more fabric: gentle corners and deep vertical folds.
        let body = SKShapeNode(rect: CGRect(x: -w / 2, y: -h, width: w, height: h), cornerRadius: w * 0.07)
        body.fillColor = color
        body.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.22)
        body.lineWidth = 1.5
        node.addChild(body)
        ProceduralTexture.applyClayFill(to: body, base: color, size: CGSize(width: w, height: h))
        // Deep vertical fabric folds — alternating lit ridges and shadowed valleys.
        let folds = 6
        for i in 0..<folds {
            let fx = -w / 2 + w * (CGFloat(i) + 0.5) / CGFloat(folds)
            let dark = i % 2 == 0
            let band = SKShapeNode(rect: CGRect(x: fx - w * 0.045, y: -h + 10, width: w * 0.09, height: h - 20), cornerRadius: w * 0.045)
            band.fillColor = dark ? WarmShelfPalette.cocoa.withAlpha(0.17) : WarmShelfPalette.paperHighlight.withAlpha(0.17)
            band.strokeColor = .clear
            node.addChild(band)
        }
        // A gathered pleat header at the rod and a weighted hem.
        let header = SKShapeNode(rect: CGRect(x: -w / 2, y: -h * 0.055, width: w, height: h * 0.055), cornerRadius: w * 0.03)
        header.fillColor = WarmShelfPalette.cocoa.withAlpha(0.15); header.strokeColor = .clear
        node.addChild(header)
        let hem = SKShapeNode(rect: CGRect(x: -w / 2, y: -h, width: w, height: h * 0.045), cornerRadius: w * 0.03)
        hem.fillColor = WarmShelfPalette.cocoa.withAlpha(0.16); hem.strokeColor = .clear
        node.addChild(hem)
        node.xScale = mirrored ? -1 : 1
        return node
    }

    private func buildDial() {
        // The hero: a big chunky wooden sun/moon dial. Turn it to move the whole day.
        dialNode = SKNode()
        dialNode.position = dialCenter
        dialNode.zPosition = 0

        let shadow = SKSpriteNode(texture: ProceduralTexture.softClayShadow(size: CGSize(width: dialRadius * 2.55, height: dialRadius * 2.05)))
        shadow.position = CGPoint(x: dialRadius * 0.08, y: -dialRadius * 0.08)
        shadow.alpha = 0.72
        shadow.zPosition = -1
        dialNode.addChild(shadow)

        // Authored dial, preferred form (playtest 2026-06-10): the felt day/night face stays
        // put and only the wooden needle sweeps — turning the whole picture read as wrong.
        if let face = ToyArt.sprite("window-dial-face-static", fit: CGSize(width: dialRadius * 2.32, height: dialRadius * 2.32)),
           let needle = ToyArt.sprite("window-dial-needle", fit: CGSize(width: dialRadius * 0.9, height: dialRadius * 1.5)) {
            dialKnob = SKShapeNode(circleOfRadius: dialRadius * 1.16)
            dialKnob.fillColor = .clear
            dialKnob.strokeColor = .clear
            dialKnob.zPosition = 1
            face.zPosition = 0.1
            dialKnob.addChild(face)
            needle.anchorPoint = CGPoint(x: 0.5, y: 0.2)   // pivot at the paddle's wide end
            needle.zPosition = 0.2
            dialKnob.addChild(needle)
            dialPointer = needle
            dialNode.addChild(dialKnob)
            controlLayer.addChild(dialNode)
            applyDialRotation()
            return
        }
        dialPointer = nil

        // Interim authored wheel: ring, face and grip baked into one piece — it all turns.
        if let wheel = ToyArt.sprite("window-dial-face", fit: CGSize(width: dialRadius * 2.32, height: dialRadius * 2.32)) {
            dialKnob = SKShapeNode(circleOfRadius: dialRadius * 1.16)
            dialKnob.fillColor = .clear
            dialKnob.strokeColor = .clear
            dialKnob.zPosition = 1
            wheel.zPosition = 0.1
            dialKnob.addChild(wheel)
            dialNode.addChild(dialKnob)
            controlLayer.addChild(dialNode)
            applyDialRotation()
            return
        }

        // Fixed outer ring with tick marks (does not rotate).
        let ring = SKShapeNode(circleOfRadius: dialRadius * 1.16)
        ring.fillColor = woodDark
        ring.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.3)
        ring.lineWidth = 2
        ring.zPosition = 0
        dialNode.addChild(ring)
        for i in 0..<16 {
            let a = CGFloat(i) / 16 * .pi * 2
            let tick = SKShapeNode(rect: CGRect(x: -1.5, y: dialRadius * 1.02, width: 3, height: dialRadius * 0.1), cornerRadius: 1.5)
            tick.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.25); tick.strokeColor = .clear
            tick.zRotation = a; tick.zPosition = 0.1
            dialNode.addChild(tick)
        }
        // A fixed pointer at the top marking "now".
        let pointer = SKShapeNode(path: { () -> CGPath in
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -dialRadius * 0.1, y: dialRadius * 1.3))
            p.addLine(to: CGPoint(x: dialRadius * 0.1, y: dialRadius * 1.3))
            p.addLine(to: CGPoint(x: 0, y: dialRadius * 1.08))
            p.closeSubpath(); return p
        }())
        pointer.fillColor = WarmShelfPalette.butter; pointer.strokeColor = woodDark.withAlpha(0.5); pointer.lineWidth = 1
        pointer.zPosition = 0.5
        dialNode.addChild(pointer)

        // The turning knob.
        dialKnob = SKShapeNode(circleOfRadius: dialRadius)
        dialKnob.zPosition = 1
        dialNode.addChild(dialKnob)
        ProceduralTexture.applyClayFill(to: dialKnob, base: UIColor(hex: 0xDEB063), size: CGSize(width: dialRadius * 2, height: dialRadius * 2))
        dialKnob.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.22); dialKnob.lineWidth = 2
        // A soft lit dome highlight — the knob catches the light and reads as polished wood.
        let knobHi = SKShapeNode(ellipseOf: CGSize(width: dialRadius * 1.2, height: dialRadius * 0.78))
        knobHi.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.3); knobHi.strokeColor = .clear
        knobHi.position = CGPoint(x: -dialRadius * 0.12, y: dialRadius * 0.36); knobHi.zPosition = 1.02
        dialKnob.addChild(knobHi)
        let knobBevel = SKShapeNode(circleOfRadius: dialRadius * 0.86)
        knobBevel.fillColor = .clear; knobBevel.strokeColor = WarmShelfPalette.paperHighlight.withAlpha(0.26); knobBevel.lineWidth = 3
        knobBevel.zPosition = 1.05
        dialKnob.addChild(knobBevel)

        // Sun/moon motif carved on the knob (rotates with it).
        dialIcon = SKNode()
        dialIcon.zPosition = 1.1
        let sun = SKShapeNode(circleOfRadius: dialRadius * 0.26)
        sun.fillColor = UIColor(hex: 0xFFC83C); sun.strokeColor = woodDark.withAlpha(0.4); sun.lineWidth = 1.5
        sun.position = CGPoint(x: -dialRadius * 0.42, y: 0)
        for i in 0..<8 {
            let a = CGFloat(i) / 8 * .pi * 2
            let ray = SKShapeNode(rect: CGRect(x: -1.5, y: dialRadius * 0.3, width: 3, height: dialRadius * 0.12), cornerRadius: 1.5)
            ray.fillColor = UIColor(hex: 0xFFC83C); ray.strokeColor = .clear
            ray.zRotation = a
            sun.addChild(ray)
        }
        dialIcon.addChild(sun)
        let moon = SKShapeNode(path: GlowWindowScene.crescentPath(radius: dialRadius * 0.27))
        moon.fillColor = UIColor(hex: 0xFBF6E6); moon.strokeColor = woodDark.withAlpha(0.4); moon.lineWidth = 1.5
        moon.position = CGPoint(x: dialRadius * 0.44, y: 0)
        dialIcon.addChild(moon)
        // A grip bar across the middle.
        let grip = SKShapeNode(rect: CGRect(x: -dialRadius * 0.66, y: -dialRadius * 0.08, width: dialRadius * 1.32, height: dialRadius * 0.16), cornerRadius: dialRadius * 0.08)
        grip.fillColor = woodDark.withAlpha(0.18); grip.strokeColor = .clear
        dialIcon.addChild(grip)
        dialKnob.addChild(dialIcon)

        controlLayer.addChild(dialNode)
        dialNode.zRotation = -dayPhase * dialAngleRange
    }

    private func buildGlobalVeils() {
        for veil in [warmVeil, coolVeil] {
            veil.size = CGSize(width: size.width, height: size.height)
            veil.position = CGPoint(x: size.width / 2, y: size.height / 2)
            veil.alpha = 0
        }
        warmVeil.color = UIColor(hex: 0xFF8A3D)
        warmVeil.blendMode = .add
        coolVeil.color = UIColor(hex: 0x101633)
        coolVeil.blendMode = .alpha
    }

    // MARK: - Phase → room

    private func applyPhase(animated: Bool) {
        let p = dayPhase
        if !isLeaving { AudioManager.shared.setWindowAmbience(dayPhase: p, animated: animated) }

        // Colour stories across the day.
        let topSky = sample([(0, 0xF6C083), (0.2, 0x8FC0E8), (0.5, 0xF0975A), (0.7, 0x6E5E97), (0.9, 0x2C2F5C), (1, 0x191B36)], p)
        let botSky = sample([(0, 0xFFE9C6), (0.2, 0xD3E9F6), (0.5, 0xFFD79A), (0.7, 0xC59AB2), (0.9, 0x4E527C), (1, 0x303155)], p)
        let wall = sample([(0, 0xEEDAB2), (0.2, 0xF3E6C7), (0.5, 0xE7BC8E), (0.7, 0xBC9D9E), (0.9, 0x6C6E94), (1, 0x53556F)], p)
        let floor = sample([(0, 0xD8BD8E), (0.2, 0xDCC79A), (0.5, 0xCE9F6E), (0.7, 0x9C8088), (0.9, 0x55577A), (1, 0x434563)], p)

        glassBase.color = botSky; glassBase.colorBlendFactor = 1
        glassTop.color = topSky
        wallNode?.fillColor = wall
        floorNode?.fillColor = floor

        // Sun / moon along their arcs.
        let sunU = clamp(p / 0.52, 0, 1)
        sunNode.position = arcPoint(u: sunU)
        let sunVisible = 1 - smoothstep(0.42, 0.56, p)
        let moonU = clamp((p - 0.46) / 0.54, 0, 1)
        moonNode.position = arcPoint(u: moonU)
        let moonVisible = smoothstep(0.46, 0.64, p)
        sunDisc?.fillColor = sample([(0, 0xFFC83C), (0.5, 0xFF9E48)], p)
        sunGlow.color = sample([(0, 0xFFE39A), (0.5, 0xFF8A40)], p)

        // Stars bloom into night.
        let night = smoothstep(0.6, 0.92, p)

        // Outside, the trees slip into silhouette as night rises; the room plate follows.
        treesNight?.alpha = night
        roomNight?.alpha = night

        // The day's small cast fades in and out by the hour: butterflies at midday, fireflies
        // from dusk into night, a low mist that lifts off the trees through the early morning.
        let butterfly = bell(p, 0.27, 0.18)
        for b in butterflies { b.alpha = butterfly }
        firefliesGlow = smoothstep(0.52, 0.74, p)   // update() blinks each one around this
        dawnMist?.alpha = (1 - smoothstep(0.05, 0.26, p)) * 0.5

        // The room is alive: the lamp lights itself at dusk and rests again by day.
        // A child's tap still wins until the dial next crosses the boundary.
        let wantsLamp = p > 0.68
        if lampAutoOn != wantsLamp {
            lampAutoOn = wantsLamp
            if lampOn != wantsLamp {
                lampOn = wantsLamp
                applyLamp(animated: animated)
            }
        }

        // Light spill: warm sunbeam by day, cool moonlight by night, modulated by the curtain.
        let beamColor = sample([(0, 0xFFE6A8), (0.5, 0xFFB066), (0.75, 0x9FB0E8), (1, 0x8FA0E0)], p)
        let beamDay = 1 - smoothstep(0.55, 0.78, p)
        let beamNight = night
        let beamStrength = (beamDay * 0.34 + beamNight * 0.18) * curtainOpen

        // Global veils.
        let warm = bell(p, 0.5, 0.16) * 0.34
        let cool = smoothstep(0.6, 1.0, p) * 0.52

        if animated, !AmbientAnimator.reduceMotion {
            sunNode.run(.fadeAlpha(to: sunVisible, duration: 0.3))
            moonNode.run(.fadeAlpha(to: moonVisible, duration: 0.3))
            beamNode.run(.fadeAlpha(to: beamStrength, duration: 0.3))
            warmVeil.run(.fadeAlpha(to: warm, duration: 0.3))
            coolVeil.run(.fadeAlpha(to: cool, duration: 0.3))
            for s in stars { s.run(.fadeAlpha(to: night * CGFloat.random(in: 0.6...1), duration: 0.4)) }
        } else {
            sunNode.alpha = sunVisible
            moonNode.alpha = moonVisible
            beamNode.alpha = beamStrength
            warmVeil.alpha = warm
            coolVeil.alpha = cool
            for s in stars { s.alpha = night }
        }
        beamNode.fillColor = beamColor.withAlpha(1)

        // The dial reflects the phase; the cat keeps the room's hours (awake by day, asleep by night).
        applyDialRotation()
        updateCat(awake: p < 0.6)
    }

    /// Whole wheel turns in the interim/procedural forms; with the split art only the
    /// needle sweeps — from over the sun glyph in the morning to over the moon at night.
    private func applyDialRotation() {
        if let pointer = dialPointer {
            dialNode.zRotation = 0
            pointer.zRotation = .pi * 0.925 - dayPhase * dialAngleRange
        } else {
            dialNode.zRotation = -dayPhase * dialAngleRange
        }
    }

    private func arcPoint(u: CGFloat) -> CGPoint {
        let margin = windowInner.width * 0.12
        let x = windowInner.minX + margin + u * (windowInner.width - 2 * margin)
        let baseY = windowInner.minY + windowInner.height * 0.16
        let y = baseY + sin(u * .pi) * windowInner.height * 0.66
        return CGPoint(x: x, y: y)
    }

    // MARK: - Curtain

    private func applyCurtain(animated: Bool) {
        // open: panels tucked to the sides; closed: panels meet at centre.
        let closedX = windowRect.width * 0.16
        let lx = windowCenter.x - (curtainRestX * curtainOpen + closedX * (1 - curtainOpen))
        let rx = windowCenter.x + (curtainRestX * curtainOpen + closedX * (1 - curtainOpen))
        // Gather narrow when open (folds bunch → far more glass shows), fill wide when closed.
        let stretch = 0.5 + (1 - curtainOpen) * 0.6
        let setX: (SKNode, CGFloat) -> Void = { node, x in
            if animated, !AmbientAnimator.reduceMotion {
                let move = SKAction.move(to: CGPoint(x: x, y: node.position.y), duration: 0.34)
                move.timingMode = .easeOut
                node.run(.sequence([move, .run { self.curtainSway(node) }]))
                node.run(.scaleX(to: node.xScale < 0 ? -stretch : stretch, duration: 0.34))
            } else {
                node.position = CGPoint(x: x, y: node.position.y)
                node.xScale = (node.xScale < 0 ? -1 : 1) * stretch
            }
        }
        setX(curtainL, lx)
        setX(curtainR, rx)
    }

    /// Shortly after opening — and now and then while idle — the curtains give a soft fabric peek
    /// so a child (and parent) sees they're cloth you can pull. Cleared the moment anything is grabbed.
    private func inviteCurtains() {
        guard !AmbientAnimator.reduceMotion else { return }
        removeAction(forKey: "curtainInvite")
        let peek = SKAction.run { [weak self] in
            guard let self, self.grabs.isEmpty else { return }
            self.curtainPeek()
        }
        run(.sequence([.wait(forDuration: 1.1), peek,
                       .repeatForever(.sequence([.wait(forDuration: 13), peek]))]), withKey: "curtainInvite")
    }

    private func curtainPeek() {
        // When a change is armed behind them the peek grows fuller and slower, with a
        // soft inward draft — the curtains themselves whisper *close me*. Never an arrow.
        let armed = peekChange != nil && !peekRevealReady
        let amp: CGFloat = armed ? 26 : 12
        let outDur = armed ? 0.95 : 0.55
        let backDur = armed ? 1.2 : 0.7
        // Idle peek breathes OUTWARD (look, I'm cloth); the armed whisper drifts
        // INWARD, toward each other — the closing gesture itself, offered gently.
        let dir: CGFloat = armed ? -1 : 1
        for (panel, sign) in [(curtainL, CGFloat(-1)), (curtainR, CGFloat(1))] {
            guard let panel else { continue }
            let x0 = panel.position.x
            let out = SKAction.moveTo(x: x0 + sign * amp * dir, duration: outDur); out.timingMode = .easeOut
            let back = SKAction.moveTo(x: x0, duration: backDur); back.timingMode = .easeInEaseOut
            panel.run(.sequence([out, back]))
            curtainSway(panel)
        }
        if armed {
            tone(.single(3, .breath.with(body: 0.55, amplitude: 0.03, noiseGain: 0.85)), key: "curtain.whisper", minInterval: 2)
        } else {
            tone(.single(7, .breath.with(body: 0.3, amplitude: 0.02, noiseGain: 0.7)), key: "curtain.invite", minInterval: 2)
        }
    }

    private func curtainSway(_ node: SKNode) {
        guard !AmbientAnimator.reduceMotion else { return }
        let s = abs(node.xScale)
        let sign: CGFloat = node.xScale < 0 ? -1 : 1
        node.run(.sequence([
            .scaleX(to: sign * s * 1.03, duration: 0.16),
            .scaleX(to: sign * s * 0.99, duration: 0.18),
            .scaleX(to: sign * s, duration: 0.16)
        ]))
    }

    // MARK: - Lamp

    private func applyLamp(animated: Bool) {
        guard lampGlow != nil else { return }   // lamp retired in the stripped scene (June 15)
        let target: CGFloat = lampOn ? (lampSprite == nil ? 0.42 : 0.24) : 0
        if let sprite = lampSprite, let tex = ToyArt.texture(lampOn ? "window-floor-lamp-on" : "window-floor-lamp-off") {
            sprite.texture = tex
        }
        lampShade?.fillColor = lampOn ? UIColor(hex: 0xFFD27A) : UIColor(hex: 0xE8B765)
        if animated, !AmbientAnimator.reduceMotion {
            lampGlow.run(.fadeAlpha(to: target, duration: 0.5))
            let pressTarget: SKNode? = lampSprite ?? lampShade
            pressTarget?.run(.sequence([.scale(to: 1.06, duration: 0.12), .scale(to: 1, duration: 0.16)]))
        } else {
            lampGlow.alpha = target
        }
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        HapticsManager.shared.prepareForTouch()
        for touch in touches {
            let p = touch.location(in: self)
            if grabs.isEmpty, consumeShelfReturnTouch(at: p) { return }
            // The room may be leaned over (persistent peek): frame-anchored furniture
            // lives at its built coords PLUS the pan, so hit tests subtract it.
            let pr = CGPoint(x: p.x - roomPanX, y: p.y)
            let pg = CGPoint(x: p.x - roomPanX * 0.45, y: p.y)

            // Dial — the day/night clock on the wall (the one verb that stays).
            if hypot(pr.x - dialCenter.x, pr.y - dialCenter.y) < dialRadius * 1.35 {
                grabs[touch] = .dial
                dialLastAngle = atan2(pr.y - dialCenter.y, pr.x - dialCenter.x)
                dialVelocity = 0
                dialNode.removeAction(forKey: "inviteDial")
                dialKnob.run(.sequence([.scale(to: 0.92, duration: 0.07), .scale(to: 1, duration: 0.16)]))   // a firm chunky press
                HapticsManager.shared.impact(style: .soft, intensity: 0.22)
                continue
            }
            // Curtains.
            if let which = curtainHit(pr) {
                grabs[touch] = which
                let node = which == .curtainL ? curtainL! : curtainR!
                curtainGrabDX = pr.x - node.position.x
                continue
            }
            // The cat — tap to pet (a stretch, a purr, hearts at night). She naps on the
            // sill and is no longer carried (founder, June 15: a static, tap-to-discover cat).
            if hypot(pr.x - catCenter.x, pr.y - catCenter.y) < catHitRadius {
                catStretch()
                continue
            }
            // Glass taps: a generous window (founder: hard to touch) and no dead band
            // between day and night — the sky always answers.
            let glassRect = windowInner.insetBy(dx: -24, dy: -24)
            if dayPhase <= 0.65, glassRect.contains(pg) {
                flyBird(toward: p); continue
            }
            if dayPhase > 0.65, glassRect.contains(pg) {
                shootingStar(toward: p); continue
            }
            // Anywhere else — the walls themselves: grab the room and lean it.
            if !grabs.values.contains(.room) {
                grabs[touch] = .room
                roomGrabStartX = p.x
                roomGrabBaseline = roomPanX
                continue
            }
            TouchFeedbackAnimator.emptyTap(in: self, at: p)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let p = touch.location(in: self)
            let pr = CGPoint(x: p.x - roomPanX, y: p.y)   // pan-corrected (persistent peek)
            switch grabs[touch] {
            case .dial:
                let a = atan2(pr.y - dialCenter.y, pr.x - dialCenter.x)
                let d = angleDelta(a, dialLastAngle)
                dialLastAngle = a
                let dp = -d / dialAngleRange
                dialVelocity = dp
                setPhase(dayPhase + dp)
                dialTick()
            case .curtainL:
                let nx = pr.x - curtainGrabDX
                let frac = clamp((windowCenter.x - nx) / curtainRestX, 0, 1)
                setCurtain(open: frac, animated: false)
            case .curtainR:
                let nx = pr.x - curtainGrabDX
                let frac = clamp((nx - windowCenter.x) / curtainRestX, 0, 1)
                setCurtain(open: frac, animated: false)
            case .room:
                let raw = roomGrabBaseline + (p.x - roomGrabStartX) * 0.6
                // soft rubber band past the edge
                let limited = clamp(raw, -roomPeekMax * 1.25, roomPeekMax * 1.25)
                roomPanX = abs(limited) <= roomPeekMax
                    ? limited
                    : (limited > 0 ? roomPeekMax + (limited - roomPeekMax) * 0.35
                                   : -roomPeekMax + (limited + roomPeekMax) * 0.35)
                applyRoomPeek()
            case .can:
                guard let can = canNode else { break }
                grabMovedDistance += hypot(pr.x - (carryTarget?.x ?? can.position.x),
                                           pr.y - (carryTarget?.y ?? can.position.y)) * 0.5
                carriedNode = can
                carryTarget = pr
            case .cat:
                guard let cat = sillCat else { break }
                grabMovedDistance += hypot(pr.x - (carryTarget?.x ?? cat.position.x),
                                           pr.y - (carryTarget?.y ?? cat.position.y)) * 0.5
                if grabMovedDistance > 14 {
                    carriedNode = cat
                    carryTarget = pr
                    cat.setScale(1.06)
                    // If she was showing as the asleep-on-rug composite, lift the *visible*
                    // movable cat to the finger (else the child drags an invisible cat).
                    cat.alpha = 1
                    catRugComposite?.alpha = 0
                }
            case .plant:
                guard let plant = plantNode else { break }
                grabMovedDistance += hypot(pr.x - (carryTarget?.x ?? plant.position.x),
                                           pr.y - (carryTarget?.y ?? plant.position.y)) * 0.5
                if grabMovedDistance > 14 {
                    carriedNode = plant
                    carryTarget = pr
                    plant.setScale(1.05)
                }
            case .ball:
                guard let ball = ballNode else { break }
                grabMovedDistance += hypot(pr.x - (carryTarget?.x ?? ball.position.x),
                                           pr.y - (carryTarget?.y ?? ball.position.y)) * 0.5
                if grabMovedDistance > 12 {
                    carriedNode = ball
                    carryTarget = pr
                }
            case .block:
                guard let block = blockNode else { break }
                grabMovedDistance += hypot(pr.x - (carryTarget?.x ?? block.position.x),
                                           pr.y - (carryTarget?.y ?? block.position.y)) * 0.5
                if grabMovedDistance > 14 {
                    carriedNode = block
                    carryTarget = pr
                    block.setScale(1.05)
                }
            case .none:
                break
            }
        }
    }

    /// A carried thing eases to rest at the nearest of the given points (with a little
    /// squash-settle). Pass one point for free placement — where the child let go — or
    /// several to snap to fixed spots.
    private func settleProp(_ node: SKNode?, homes: [CGPoint], scale: CGFloat,
                            done: @escaping (Int) -> Void) {
        guard let node, !homes.isEmpty else { return }
        var bestIndex = 0
        var bestDist = CGFloat.greatestFiniteMagnitude
        for (i, home) in homes.enumerated() {
            let d = hypot(node.position.x - home.x, node.position.y - home.y)
            if d < bestDist { bestDist = d; bestIndex = i }
        }
        let settle = SKAction.move(to: homes[bestIndex], duration: 0.4)
        settle.timingMode = .easeOut
        node.run(.sequence([
            .group([settle, .scale(to: scale, duration: 0.3)]),
            .scaleY(to: 0.94, duration: 0.08),
            .scaleY(to: 1.0, duration: 0.16),
            .run { done(bestIndex) }
        ]))
        HapticsManager.shared.impact(style: .soft, intensity: 0.18)
    }

    /// The watering moment: once per hold, when the tipped can hovers the pot.
    private func waterPotIfReady() {
        guard !wateredThisHold, let can = canNode else { return }
        wateredThisHold = true
        let spout = CGPoint(x: can.position.x - frameT() * 1.0, y: can.position.y + frameT() * 0.2)
        for i in 0..<10 {
            let drop = SKShapeNode(circleOfRadius: .random(in: 1.8...3.0))
            drop.fillColor = WarmShelfPalette.waterBlue.withAlpha(0.85)
            drop.strokeColor = .clear
            drop.position = CGPoint(x: spout.x + .random(in: -4...4), y: spout.y)
            drop.zPosition = 2
            lampLayer.addChild(drop)
            let fall = SKAction.move(to: CGPoint(x: potCenter.x + .random(in: -12...12),
                                                 y: potCenter.y - frameT() * 0.6),
                                     duration: .random(in: 0.4...0.6))
            fall.timingMode = .easeIn
            drop.run(.sequence([
                .wait(forDuration: Double(i) * 0.05),
                .group([fall, .sequence([.wait(forDuration: 0.3), .fadeOut(withDuration: 0.25)])]),
                .removeFromParent()
            ]))
        }
        flowerPotNode?.run(.sequence([
            .rotate(toAngle: 0.05, duration: 0.12),
            .rotate(toAngle: -0.04, duration: 0.14),
            .rotate(toAngle: 0, duration: 0.14)
        ]))
        tone(.single(6, .breath.with(body: 0.5, amplitude: 0.05, noiseGain: 0.9)), key: "water")
        tone(.single(14, .celeste.with(body: 0.25, amplitude: 0.025)), key: "waterdrip", minInterval: 0.2)
        HapticsManager.shared.impact(style: .soft, intensity: 0.2)
        registerWatering()
    }

    private func registerWatering() {
        let state = LullDemoState.shared
        let today = todayStamp
        guard state.windowPotLastWateredDay != today else { return }   // one drink a day counts
        state.windowPotLastWateredDay = today
        if state.windowPotStage < 3 {
            let newStage = state.windowPotStage + 1
            state.windowPotStage = newStage
            // The droplets land, and THEN the plant answers — cause, then magic.
            run(.sequence([.wait(forDuration: 0.55), .run { [weak self] in
                self?.growPot(to: newStage)
            }]))
        } else if let pot = flowerPotNode {
            // The bloomed flower says thank you with a few petals.
            for i in 0..<4 {
                let petal = SKShapeNode(ellipseOf: CGSize(width: 5, height: 3))
                petal.fillColor = WarmShelfPalette.petal.withAlpha(0.85)
                petal.strokeColor = .clear
                petal.position = CGPoint(x: potCenter.x, y: pot.position.y + pot.size.height * 0.8)
                petal.zPosition = 2
                lampLayer.addChild(petal)
                petal.run(.sequence([
                    .wait(forDuration: Double(i) * 0.1),
                    .group([.moveBy(x: .random(in: -24...24), y: .random(in: -20 ... -6), duration: 1.1),
                            .rotate(byAngle: .random(in: -1...1), duration: 1.1),
                            .sequence([.wait(forDuration: 0.6), .fadeOut(withDuration: 0.5)])]),
                    .removeFromParent()
                ]))
            }
        }
    }

    /// The lean itself: the wallpaper lags slightly, the frame/props stay together, and
    /// the beam lags most. Touchable things must ride with their hit tests.
    private func applyRoomPeek() {
        roomLayer.position.x = roomPanX * 0.94
        frameLayer.position.x = roomPanX
        glassLayer.position.x = roomPanX
        lampLayer.position.x = roomPanX
        curtainLayer.position.x = roomPanX
        controlLayer.position.x = roomPanX
        // The sky + its arched MASK ride with the frame (1.0). At 0.45 the opening
        // slid slower than the wooden frame, so a big lean dragged the outside scene
        // out past the frame onto the wall (founder bug). The window is a hole in the
        // wall — it must move exactly with the wall/frame.
        windowContent.position.x = roomPanX
        beamLayer.position.x = roomPanX * 0.92
    }
    // No wipe-back (founder, Pok Pok law): where the child leans the room, the room
    // stays — exploring is the point. A fresh build re-centers naturally.

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { endTouches(touches) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { endTouches(touches) }

    private func endTouches(_ touches: Set<UITouch>) {
        for touch in touches {
            switch grabs[touch] {
            case .dial:
                dialKnob.run(.sequence([.scale(to: 1.04, duration: 0.1), .scale(to: 1, duration: 0.16)]))
            case .curtainL, .curtainR:
                applyCurtain(animated: true)
                tone(.single(6, .breath.with(body: 0.4, amplitude: 0.04, noiseGain: 0.7)), key: "curtain.settle")
                HapticsManager.shared.impact(style: .soft, intensity: 0.16)
            case .room:
                tone(.single(5, .breath.with(body: 0.35, amplitude: 0.025, noiseGain: 0.6)), key: "room.settle", minInterval: 0.4)
            case .can:
                wateredThisHold = false
                carriedNode = nil
                carryTarget = nil
                if let can = canNode {
                    let home = SKAction.move(to: canHome, duration: 0.45)
                    home.timingMode = .easeOut
                    can.run(.group([home, .rotate(toAngle: 0, duration: 0.3), .scale(to: 1.0, duration: 0.3)]))
                }
            case .cat:
                carriedNode = nil
                carryTarget = nil
                if grabMovedDistance > 14 {
                    // She settles exactly where she was let go (clamped into the room),
                    // and remembers it. settleProp with a single home eases her there.
                    let dropped = clampCatSpot(sillCat?.position ?? catCenter)
                    settleProp(sillCat, homes: [dropped], scale: 1.0) { [weak self] _ in
                        guard let self else { return }
                        self.catCenter = dropped
                        LullDemoState.shared.windowCatPlace = self.normalized(dropped)
                        self.refreshRugGlow()
                        self.refreshCatRugComposite()   // dropped onto the rug at night → the composite
                        AudioManager.shared.playSoftTap()
                    }
                } else {
                    catStretch()
                }
            case .plant:
                carriedNode = nil
                carryTarget = nil
                if grabMovedDistance > 14 {
                    settleProp(plantNode, homes: plantHomes, scale: 1.0) { [weak self] index in
                        guard let self else { return }
                        LullDemoState.shared.windowPlantHome = index
                        self.plantCenter = self.plantHomes[index]
                        self.plantShiver()
                    }
                } else {
                    plantShiver()
                }
            case .ball:
                carriedNode = nil
                carryTarget = nil
                if grabMovedDistance > 12 {
                    let dropped = clampFloorSpot(ballNode?.position ?? ballCenter)
                    settleProp(ballNode, homes: [dropped], scale: 1.0) { [weak self] _ in
                        guard let self else { return }
                        self.ballCenter = dropped
                        LullDemoState.shared.windowBallPlace = self.normalized(dropped)
                        self.ballSpin?.run(.rotate(toAngle: 0, duration: 0.5))
                        _ = self.catReceivesToy(self.ballNode)
                        AudioManager.shared.playSoftTap()
                    }
                } else {
                    nudgeWheeledToy()
                }
            case .block:
                carriedNode = nil
                carryTarget = nil
                if grabMovedDistance > 14 {
                    let dropped = clampFloorSpot(blockNode?.position ?? blockCenter)
                    settleProp(blockNode, homes: [dropped], scale: 1.0) { [weak self] _ in
                        guard let self else { return }
                        self.blockCenter = dropped
                        LullDemoState.shared.windowBlockPlace = self.normalized(dropped)
                        _ = self.catReceivesToy(self.blockNode)
                        AudioManager.shared.playSoftTap()
                    }
                } else {
                    squishSoftToy()
                }
            case .none:
                break
            }
            grabs.removeValue(forKey: touch)
        }
    }

    private func curtainHit(_ p: CGPoint) -> Grab? {
        // Tighter than it looks: the sill corners are crowded (cat, lamp, star), so the
        // curtain only claims touches near its own fabric (playtest).
        let panelW = windowRect.width * 0.42
        if p.y < windowRect.maxY, p.y > windowRect.minY {
            if abs(p.x - curtainL.position.x) < panelW * 0.42 { return .curtainL }
            if abs(p.x - curtainR.position.x) < panelW * 0.42 { return .curtainR }
        }
        return nil
    }

    private func setPhase(_ v: CGFloat) {
        dayPhase = clamp(v, 0, 1)
        applyPhase(animated: false)
    }

    private func setCurtain(open: CGFloat, animated: Bool) {
        curtainOpen = clamp(open, 0, 1)
        // Closed curtains put the lamp to rest — light behind drawn fabric read as
        // wrong (playtest). It re-evaluates itself when the room next changes.
        if curtainOpen < 0.35, lampOn {
            lampOn = false
            lampAutoOn = nil
            applyLamp(animated: true)
        }
        // follow finger immediately, gathering narrow as it opens
        let closedX = windowRect.width * 0.16
        let off = curtainRestX * curtainOpen + closedX * (1 - curtainOpen)
        let ws = 0.5 + (1 - curtainOpen) * 0.6
        curtainL.position = CGPoint(x: windowCenter.x - off, y: curtainL.position.y); curtainL.xScale = ws
        curtainR.position = CGPoint(x: windowCenter.x + off, y: curtainR.position.y); curtainR.xScale = -ws
        applyPhase(animated: false)   // light spill scales with the curtain
        tone(.single(4 + Int(curtainOpen * 6), .breath.with(body: 0.22, amplitude: 0.025, noiseGain: 0.7)), key: "curtain.drag", minInterval: 0.12)
        updatePeekABoo()
    }

    // MARK: - Peek-a-boo curtains

    private func schedulePeekArm(initial: Bool = false) {
        removeAction(forKey: "peekArm")
        var wait: TimeInterval = initial ? 26 : .random(in: 45...75)
        #if DEBUG
        if ProcessInfo.processInfo.environment["LULL_DEBUG_WINDOW_PEEK"] == "1" { wait = 2 }
        #endif
        run(.sequence([.wait(forDuration: wait),
                       .run { [weak self] in self?.armPeekChange() }]), withKey: "peekArm")
    }

    private func armPeekChange() {
        guard peekChange == nil, !peekRevealReady, curtainOpen > 0.7 else {
            run(.sequence([.wait(forDuration: 20), .run { [weak self] in self?.armPeekChange() }]),
                withKey: "peekArm")
            return
        }
        if dayPhase >= 0.75 {
            peekChange = .starFall
        } else {
            peekChange = (visitingBird == nil && Bool.random()) ? .birdVisit : .cloudJump
        }
        // No announcement — from here the curtains simply whisper (see curtainPeek).
    }

    private func updatePeekABoo() {
        if curtainOpen <= 0.1 {
            if let _ = peekChange, !peekRevealReady {
                peekRevealReady = true
                applyHiddenChange()
            } else if peekChange == nil, let bird = visitingBird {
                // The world moves while hidden in BOTH directions: a closed window
                // is also when a visiting bird quietly goes home.
                bird.removeFromParent()
            }
        } else if curtainOpen >= 0.55, peekRevealReady {
            let change = peekChange
            peekRevealReady = false
            peekChange = nil
            revealChange(change)
            schedulePeekArm()
        }
    }

    /// Behind drawn cloth, the world rearranges itself — silently.
    private func applyHiddenChange() {
        switch peekChange {
        case .cloudJump:
            cloudDrift += windowInner.width * .random(in: 0.45...0.7) * (Bool.random() ? 1 : -1)
            cloudNode?.position.y = windowInner.maxY - windowInner.height * .random(in: 0.16...0.34)
        case .birdVisit:
            spawnVisitingBird()
        case .starFall, .none:
            break   // the star falls at the reveal — a fall the child actually sees
        }
    }

    private func revealChange(_ change: PeekChange?) {
        switch change {
        case .starFall:
            runStarFall()
        case .birdVisit:
            departBird(after: .random(in: 18...26))
        case .cloudJump, .none:
            break   // the moved cloud IS the reveal
        }
    }

    /// A small felt bird, perched outside on the glass's bottom rail.
    private func spawnVisitingBird() {
        visitingBird?.removeFromParent()
        let s = windowInner.width * 0.045
        let bird = SKNode()

        let tail = SKShapeNode(ellipseOf: CGSize(width: s * 1.6, height: s * 0.55))
        tail.fillColor = UIColor(hex: 0xB06A55)
        tail.strokeColor = .clear
        tail.position = CGPoint(x: s * 1.5, y: s * 0.5)
        tail.zRotation = 0.35
        bird.addChild(tail)

        let body = SKShapeNode(ellipseOf: CGSize(width: s * 2.6, height: s * 2.0))
        body.fillColor = UIColor(hex: 0xC9836B)
        body.strokeColor = .clear
        bird.addChild(body)

        let belly = SKShapeNode(ellipseOf: CGSize(width: s * 1.5, height: s * 1.1))
        belly.fillColor = UIColor(hex: 0xF2E0C8)
        belly.strokeColor = .clear
        belly.position = CGPoint(x: -s * 0.3, y: -s * 0.35)
        belly.zPosition = 0.1
        bird.addChild(belly)

        let head = SKShapeNode(circleOfRadius: s * 0.95)
        head.fillColor = UIColor(hex: 0xC9836B)
        head.strokeColor = .clear
        head.position = CGPoint(x: -s * 1.0, y: s * 1.1)
        bird.addChild(head)

        let beak = SKShapeNode(path: {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 0, y: s * 0.22))
            p.addLine(to: CGPoint(x: -s * 0.62, y: 0))
            p.addLine(to: CGPoint(x: 0, y: -s * 0.18))
            p.closeSubpath()
            return p
        }())
        beak.fillColor = UIColor(hex: 0xE2A23E)
        beak.strokeColor = .clear
        beak.position = CGPoint(x: -s * 1.8, y: s * 1.05)
        bird.addChild(beak)

        let eye = SKShapeNode(circleOfRadius: s * 0.14)
        eye.fillColor = WarmShelfPalette.cocoa.withAlpha(0.85)
        eye.strokeColor = .clear
        eye.position = CGPoint(x: -s * 1.3, y: s * 1.25)
        eye.zPosition = 0.2
        bird.addChild(eye)

        let wing = SKShapeNode(ellipseOf: CGSize(width: s * 1.5, height: s * 1.0))
        wing.fillColor = UIColor(hex: 0xB06A55).withAlpha(0.9)
        wing.strokeColor = .clear
        wing.position = CGPoint(x: s * 0.3, y: s * 0.1)
        wing.zRotation = -0.25
        wing.zPosition = 0.15
        bird.addChild(wing)

        // Perched on the inner bottom rail, away from the cat's side of the sill.
        bird.position = CGPoint(x: windowCenter.x + windowRect.width * 0.24,
                                y: windowInner.minY + s * 1.0)
        bird.zPosition = 0.5
        bird.setScale(0.001)   // hidden behind cloth, but be safe against any sliver
        windowContent.addChild(bird)
        bird.setScale(1.0)
        visitingBird = bird

        if !AmbientAnimator.reduceMotion {
            bird.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: s * 0.12, duration: 1.1),
                .moveBy(x: 0, y: -s * 0.12, duration: 1.3)
            ])), withKey: "bob")
            tail.run(.repeatForever(.sequence([
                .wait(forDuration: .random(in: 3.5...6)),
                .rotate(toAngle: 0.6, duration: 0.12),
                .rotate(toAngle: 0.35, duration: 0.2)
            ])))
        }
    }

    private func departBird(after delay: TimeInterval) {
        guard let bird = visitingBird else { return }
        bird.run(.sequence([
            .wait(forDuration: delay),
            .run { [weak bird] in
                guard let bird else { return }
                bird.removeAction(forKey: "bob")
                if !AmbientAnimator.reduceMotion {
                    // little wing flutter as it lifts
                    bird.run(.repeat(.sequence([.scaleY(to: 0.82, duration: 0.07),
                                                .scaleY(to: 1.0, duration: 0.08)]), count: 8))
                }
            },
            .group([
                .moveBy(x: -windowInner.width * 0.5, y: windowInner.height * 0.5, duration: 1.5),
                .fadeOut(withDuration: 1.3)
            ]),
            .removeFromParent()
        ]))
    }

    /// One star lets go and slides down the sky; its old place stays empty.
    private func runStarFall() {
        guard let victim = stars.filter({ $0.alpha > 0.35 }).randomElement() ?? stars.randomElement() else { return }
        let from = victim.position
        if AmbientAnimator.reduceMotion {
            victim.run(.fadeAlpha(to: 0, duration: 1.2))
            return
        }
        let streak = SKNode()
        let headDot = SKShapeNode(circleOfRadius: 2.8)
        headDot.fillColor = UIColor(hex: 0xFFF6D9)
        headDot.strokeColor = .clear
        headDot.blendMode = .add
        streak.addChild(headDot)
        let dx = -windowInner.width * 0.34
        let dy = -windowInner.height * 0.4
        let tail = SKShapeNode(path: {
            let p = CGMutablePath()
            p.move(to: .zero)
            p.addLine(to: CGPoint(x: -dx * 0.22, y: -dy * 0.22))
            return p
        }())
        tail.strokeColor = UIColor(hex: 0xFFF6D9).withAlpha(0.55)
        tail.lineWidth = 1.6
        tail.lineCap = .round
        tail.blendMode = .add
        streak.addChild(tail)
        streak.position = from
        streak.zPosition = 0.6
        windowContent.addChild(streak)
        victim.run(.fadeAlpha(to: 0, duration: 0.25))
        let slide = SKAction.moveBy(x: dx, y: dy, duration: 0.85)
        slide.timingMode = .easeIn
        streak.run(.sequence([.group([slide, .fadeOut(withDuration: 0.85)]), .removeFromParent()]))
        tone(.single(16, .celeste.with(body: 0.5, amplitude: 0.028)), key: "starfall", minInterval: 2)
    }

    private func toggleLamp() {
        lampOn.toggle()
        applyLamp(animated: true)
        tone(.single(lampOn ? 7 : 3, .clay.with(body: 0.18, amplitude: 0.08, noiseGain: 0.14)), key: "lamp")
        if lampOn { tone(.single(0, .breath.with(body: 0.6, amplitude: 0.03, noiseGain: 0.4)), key: "lamp.hum") }
        HapticsManager.shared.impact(style: .soft, intensity: 0.2)
    }

    // MARK: - Special moments

    /// A wish on demand: tap the glass and a comet streaks TOWARD the tap. Comets vary in colour,
    /// sometimes arrive as a little trio, and the whole window brightens as they pass.
    private func shootingStar(toward target: CGPoint? = nil) {
        guard !AmbientAnimator.reduceMotion else { return }
        // The window glass itself catches the light for a breath.
        let glassFlash = SKSpriteNode(color: UIColor(hex: 0xFFF4D8), size: windowInner.size)
        glassFlash.position = windowCenter
        glassFlash.blendMode = .add
        glassFlash.alpha = 0
        glassFlash.zPosition = 0.42
        windowContent.addChild(glassFlash)
        glassFlash.run(.sequence([.fadeAlpha(to: 0.16, duration: 0.3), .fadeOut(withDuration: 0.9), .removeFromParent()]))

        let count = Int.random(in: 1...100) <= 30 ? Int.random(in: 2...3) : 1
        for i in 0..<count {
            run(.sequence([.wait(forDuration: Double(i) * 0.22), .run { [weak self] in
                self?.launchComet(toward: target, offset: CGFloat(i))
            }]))
        }
    }

    private func launchComet(toward target: CGPoint?, offset: CGFloat) {
        let tints: [UInt32] = [0xFFFBE8, 0xFFD98A, 0xBFD8FF, 0xF8C8D8]
        let tint = UIColor(hex: tints.randomElement() ?? 0xFFFBE8)
        let start = CGPoint(x: windowInner.maxX - 10 - offset * 26,
                            y: windowInner.maxY - windowInner.height * CGFloat.random(in: 0.06...0.2))
        let fallback = CGPoint(x: windowInner.minX + windowInner.width * 0.22, y: windowCenter.y + windowInner.height * 0.04)
        var end = target ?? fallback
        end.x = clamp(end.x + offset * 18, windowInner.minX + 14, windowInner.maxX - 14)
        end.y = clamp(end.y - offset * 12, windowInner.minY + 14, windowInner.maxY - 14)
        let angle = atan2(end.y - start.y, end.x - start.x)

        // A bright head with a soft halo and a long, tapering three-layer tail — a real wish.
        let star = SKNode()
        star.position = start
        star.zPosition = 0.45
        windowContent.addChild(star)

        let halo = SKShapeNode(circleOfRadius: 13)
        halo.fillColor = tint.withAlpha(0.4); halo.strokeColor = .clear; halo.blendMode = .add
        star.addChild(halo)
        let head = SKShapeNode(circleOfRadius: 4.6)
        head.fillColor = tint; head.strokeColor = .clear; head.blendMode = .add
        head.zPosition = 0.1
        star.addChild(head)
        for (len, thick, alpha) in [(CGFloat(72), CGFloat(4.2), CGFloat(0.34)), (46, 2.8, 0.5), (24, 1.8, 0.75)] {
            let seg = SKShapeNode(rect: CGRect(x: -len, y: -thick / 2, width: len, height: thick), cornerRadius: thick / 2)
            seg.fillColor = tint.withAlpha(alpha); seg.strokeColor = .clear; seg.blendMode = .add
            seg.zRotation = angle
            star.addChild(seg)
        }

        let move = SKAction.move(to: end, duration: 1.35); move.timingMode = .easeIn
        star.run(.sequence([
            .group([move, .sequence([.wait(forDuration: 1.0), .fadeOut(withDuration: 0.35)])]),
            .run { [weak self] in
                guard let self else { return }
                // The wish lands: a soft ring and three drifting star-flecks.
                let ring = SKShapeNode(circleOfRadius: 4)
                ring.strokeColor = tint.withAlpha(0.8); ring.lineWidth = 2; ring.fillColor = .clear; ring.blendMode = .add
                ring.position = end
                ring.zPosition = 0.45
                self.windowContent.addChild(ring)
                ring.run(.sequence([.group([.scale(to: 6, duration: 0.55), .fadeOut(withDuration: 0.55)]), .removeFromParent()]))
                for _ in 0..<3 {
                    let fleck = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.2...2.2))
                    fleck.fillColor = tint.withAlpha(0.8); fleck.strokeColor = .clear; fleck.blendMode = .add
                    fleck.position = end
                    fleck.zPosition = 0.45
                    self.windowContent.addChild(fleck)
                    fleck.run(.sequence([.group([
                        .moveBy(x: .random(in: -26...26), y: .random(in: -10...22), duration: 0.8),
                        .fadeOut(withDuration: 0.8)
                    ]), .removeFromParent()]))
                }
            },
            .removeFromParent()
        ]))
        tone(.arp([12, 16, 19, 24], step: 0.09, .glass.with(body: 0.85, amplitude: 0.055)), key: "shoot")
        HapticsManager.shared.impact(style: .light, intensity: 0.12)
    }

    private var lastBirdTime: TimeInterval = 0

    /// Every touchable thing is alive — the plant answers with a happy leaf shiver.
    private func plantShiver() {
        tone(.single(9, .breath.with(body: 0.16, amplitude: 0.035, noiseGain: 0.75)), key: "plant", minInterval: 0.4)
        HapticsManager.shared.impact(style: .light, intensity: 0.1)
        guard !AmbientAnimator.reduceMotion, let plant = plantNode else { return }
        plant.removeAction(forKey: "shiver")
        plant.run(.sequence([
            .rotate(toAngle: 0.05, duration: 0.08), .rotate(toAngle: -0.04, duration: 0.1),
            .rotate(toAngle: 0.025, duration: 0.1), .rotate(toAngle: 0, duration: 0.14)
        ]), withKey: "shiver")
    }

    /// Day's answer to the night comet: one little felt bird flutters across the glass,
    /// dipping past the child's finger. Never a flock, never loud.
    private func flyBird(toward target: CGPoint) {
        let now = CACurrentMediaTime()
        guard now - lastBirdTime > 7 else { return }
        lastBirdTime = now
        AudioManager.shared.playBird()
        HapticsManager.shared.impact(style: .light, intensity: 0.08)
        guard !AmbientAnimator.reduceMotion else { return }

        let fromLeft = Bool.random()
        let startX = fromLeft ? windowInner.minX - 30 : windowInner.maxX + 30
        let endX = fromLeft ? windowInner.maxX + 30 : windowInner.minX - 30
        let y = min(max(target.y, windowInner.minY + windowInner.height * 0.42), windowInner.maxY - 24)
        let bird = makeBird(facingRight: fromLeft)
        bird.position = CGPoint(x: startX, y: y + 12)
        bird.zPosition = 3.2   // in front of the tree line — a near visitor
        windowContent.addChild(bird)
        let duration = TimeInterval(2.6)
        let glide = SKAction.moveTo(x: endX, duration: duration)
        let dip = SKAction.sequence([
            .moveBy(x: 0, y: -10, duration: duration * 0.35),
            .moveBy(x: 0, y: 16, duration: duration * 0.4),
            .moveBy(x: 0, y: -6, duration: duration * 0.25)
        ])
        bird.run(.sequence([.group([glide, dip]), .removeFromParent()]))
    }

    private func makeBird(facingRight: Bool) -> SKNode {
        if let art = ToyArt.sprite("window-bird", fit: CGSize(width: windowInner.width * 0.12, height: windowInner.width * 0.1)) {
            if !AmbientAnimator.reduceMotion {
                art.run(.repeatForever(.sequence([.scaleY(to: 0.86, duration: 0.16), .scaleY(to: 1.0, duration: 0.18)])))
            }
            art.xScale = facingRight ? abs(art.xScale) : -abs(art.xScale)
            return art
        }
        let bird = SKNode()
        let w = windowInner.width * 0.05
        let body = SKShapeNode(ellipseOf: CGSize(width: w * 1.5, height: w))
        body.fillColor = UIColor(hex: 0xC97B4A)
        body.strokeColor = .clear
        bird.addChild(body)
        let belly = SKShapeNode(ellipseOf: CGSize(width: w * 0.9, height: w * 0.5))
        belly.fillColor = UIColor(hex: 0xEBD2B0)
        belly.strokeColor = .clear
        belly.position = CGPoint(x: w * 0.1, y: -w * 0.2)
        bird.addChild(belly)
        let wing = SKShapeNode(ellipseOf: CGSize(width: w * 0.9, height: w * 0.55))
        wing.fillColor = UIColor(hex: 0xA85F33)
        wing.strokeColor = .clear
        wing.position = CGPoint(x: -w * 0.1, y: w * 0.18)
        wing.zRotation = 0.4
        bird.addChild(wing)
        if !AmbientAnimator.reduceMotion {
            wing.run(.repeatForever(.sequence([.rotate(toAngle: -0.5, duration: 0.16), .rotate(toAngle: 0.4, duration: 0.18)])))
        }
        bird.xScale = facingRight ? 1 : -1
        return bird
    }

    private func phaseZone(_ p: CGFloat) -> Zone {
        if p < 0.14 { return .morning }
        if p < 0.42 { return .day }
        if p < 0.6 { return .sunset }
        if p < 0.8 { return .dusk }
        return .night
    }

    /// Morning wake: light blooms across the glass, a soft airy trill, dust drifts in the new beam.
    private func fireMorningWake() {
        tone(.arp([12, 16, 19, 16], step: 0.14, .celeste.with(body: 0.6, amplitude: 0.028)), key: "morning")
        guard !AmbientAnimator.reduceMotion else { return }
        let bloom = SKSpriteNode(color: UIColor(hex: 0xFFF6DC), size: windowInner.size)
        bloom.position = windowCenter; bloom.zPosition = 0.55; bloom.alpha = 0; bloom.blendMode = .add
        windowContent.addChild(bloom)
        bloom.run(.sequence([.fadeAlpha(to: 0.36, duration: 0.4), .fadeAlpha(to: 0, duration: 1.3), .removeFromParent()]))
        for _ in 0..<7 {
            let m = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.4...2.8))
            m.fillColor = UIColor(hex: 0xFFF0C8).withAlpha(0.6); m.strokeColor = .clear; m.blendMode = .add
            m.position = beamPoint(); m.zPosition = 0
            particleLayer.addChild(m)
            m.run(.sequence([.group([.moveBy(x: .random(in: -10...10), y: .random(in: 20...44), duration: .random(in: 1.4...2.4)), .fadeOut(withDuration: 1.8)]), .removeFromParent()]))
        }
    }

    /// Night bloom: the stars twinkle awake one by one, the moon's glow swells, a soft hush settles.
    private func fireNightBloom() {
        tone(.arp([7, 4, 0], step: 0.22, .breath.with(body: 0.7, amplitude: 0.03, noiseGain: 0.45)), key: "night")
        guard !AmbientAnimator.reduceMotion else { return }
        for (i, s) in stars.enumerated() {
            s.run(.sequence([.wait(forDuration: Double(i) * 0.045), .scale(to: 1.7, duration: 0.18), .scale(to: 1, duration: 0.34)]))
        }
        moonGlow?.run(.sequence([.scale(to: 1.32, duration: 0.6), .scale(to: 1, duration: 0.9)]))
        for _ in 0..<6 {
            let m = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.4...2.6))
            m.fillColor = UIColor(hex: 0xCBD6F2).withAlpha(0.5); m.strokeColor = .clear; m.blendMode = .add
            m.position = CGPoint(x: .random(in: windowInner.minX...windowInner.maxX), y: .random(in: windowCenter.y...windowInner.maxY))
            m.zPosition = 0.2
            windowContent.addChild(m)
            m.run(.sequence([.group([.moveBy(x: .random(in: -8...8), y: .random(in: 8...20), duration: .random(in: 1.6...2.6)), .fadeOut(withDuration: 2)]), .removeFromParent()]))
        }
    }

    // MARK: - Update loop (dial inertia, cloud drift, phase particles, twinkle)

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        guard dialRadius > 1 else { return }
        let dt = lastUpdateTime == 0 ? 0 : min(0.05, currentTime - lastUpdateTime)
        lastUpdateTime = currentTime

        // Dial inertia after release.
        if !grabs.values.contains(.dial), abs(dialVelocity) > 0.0002, !AmbientAnimator.reduceMotion {
            setPhase(dayPhase + dialVelocity)
            dialVelocity *= 0.9
            if abs(dialVelocity) <= 0.0002 { dialVelocity = 0 }
        }

        // Day-phase moments fire only when the dial SETTLES in a zone (~0.5s dwell) with a cooldown,
        // so a child spamming the dial back and forth never spams chimes or particles — the colour
        // and sun/star transitions still follow the dial smoothly every frame regardless.
        let zone = phaseZone(dayPhase)
        if zone != currentZone {
            currentZone = zone
            zoneEnteredTime = currentTime
        } else if zone != announcedZone, currentTime - zoneEnteredTime > 0.5, currentTime - lastMomentTime > 1.6 {
            announcedZone = zone
            lastMomentTime = currentTime
            if zone == .morning { fireMorningWake() }
            else if zone == .night { fireNightBloom() }
        }

        // A carried thing follows the finger on a soft spring — never snapped to it
        // (founder: movement read clunky; ease is the difference between dragging
        // a sprite and holding a toy).
        if let node = carriedNode, let target = carryTarget {
            let dx = (target.x - node.position.x) * 0.32
            node.position = CGPoint(x: node.position.x + dx,
                                    y: node.position.y + (target.y - node.position.y) * 0.32)
            if node === canNode {
                let nearPot = hypot(node.position.x - potCenter.x, node.position.y - potCenter.y) < frameT() * 2.8
                let wantTilt: CGFloat = nearPot ? -0.45 : -0.1
                node.zRotation += (wantTilt - node.zRotation) * 0.2
                if nearPot { waterPotIfReady() }
            } else if node === ballNode {
                let lean = clamp(-dx * 0.01, -0.08, 0.08)
                ballSpin?.zRotation += (lean - (ballSpin?.zRotation ?? 0)) * 0.22
            }
        }

        // Cloud drift.
        if !AmbientAnimator.reduceMotion, cloudNode != nil {
            cloudDrift += dt * 8
            var x = windowInner.midX - windowInner.width * 0.1 + cloudDrift
            let span = windowInner.width * 1.3
            if x > windowInner.maxX + span * 0.3 { cloudDrift = -span * 0.6; x = windowInner.minX - span * 0.3 }
            cloudNode.position = CGPoint(x: x, y: cloudNode.position.y)
            cloudNode.alpha = (1 - smoothstep(0.6, 0.85, dayPhase)) * 0.9   // clouds fade at night
        }

        // Twinkle stars at night.
        if !AmbientAnimator.reduceMotion, dayPhase > 0.7 {
            for (i, s) in stars.enumerated() where i % 3 == Int(currentTime * 2) % 3 {
                s.alpha = max(0.15, min(1, s.alpha + CGFloat.random(in: -0.2...0.2)))
            }
        }

        // Phase-based particles.
        moteAccum += dt
        let interval = dayPhase > 0.7 ? 1.1 : 0.55
        if moteAccum > interval, !AmbientAnimator.reduceMotion { moteAccum = 0; spawnMote() }

        // Fireflies breathe softly once their hour comes (firefliesGlow set in applyPhase).
        if firefliesGlow > 0.02 {
            for (i, f) in fireflies.enumerated() {
                if AmbientAnimator.reduceMotion {
                    f.alpha = firefliesGlow * 0.8
                } else {
                    let phase = currentTime * 1.6 + Double(i) * 0.8
                    f.alpha = firefliesGlow * (0.3 + 0.7 * CGFloat((sin(phase) + 1) / 2))
                }
            }
        } else {
            for f in fireflies where f.alpha != 0 { f.alpha = 0 }
        }

        // The rare surprise: now and then in daylight, a hot-air balloon drifts past. "Oh, look!"
        if dayPhase > 0.12, dayPhase < 0.62 {
            if lastBalloonTime < 0 {
                lastBalloonTime = currentTime          // start the clock on first daylight
            } else if currentTime - lastBalloonTime > nextBalloonDelay {
                lastBalloonTime = currentTime
                nextBalloonDelay = .random(in: 90...160)
                launchBalloon()
            }
        }
    }

    private func spawnMote() {
        let night = smoothstep(0.6, 0.92, dayPhase)
        let golden = bell(dayPhase, 0.5, 0.14)
        let inBeam = curtainOpen > 0.3 && dayPhase < 0.75
        let color: UIColor
        let radius: CGFloat
        let origin: CGPoint
        if night > 0.5 {
            color = UIColor(hex: 0xCBD6F2).withAlpha(0.5)
            radius = CGFloat.random(in: 1...2)
            origin = CGPoint(x: .random(in: size.width * 0.1...size.width * 0.9), y: .random(in: floorTopY...size.height * 0.5))
        } else if golden > 0.4 {
            color = UIColor(hex: 0xFFC979).withAlpha(0.55)
            radius = CGFloat.random(in: 1.4...2.8)
            origin = beamPoint()
        } else if inBeam {
            color = UIColor(hex: 0xFFF0C8).withAlpha(0.5)
            radius = CGFloat.random(in: 1...2.2)
            origin = beamPoint()
        } else {
            return
        }
        // Lamp specks near the shade when lit.
        let mote = SKShapeNode(circleOfRadius: radius)
        mote.fillColor = color; mote.strokeColor = .clear; mote.blendMode = .add
        mote.position = origin; mote.zPosition = 0
        particleLayer.addChild(mote)
        let drift = SKAction.moveBy(x: .random(in: -16...16), y: .random(in: 14...40), duration: .random(in: 2.6...4.2))
        drift.timingMode = .easeOut
        mote.run(.sequence([.group([drift, .sequence([.fadeAlpha(to: mote.fillColor.cgColor.alpha, duration: 0.6), .wait(forDuration: 1.4), .fadeOut(withDuration: 1.6)])]), .removeFromParent()]))

        if lampOn {
            let amber = SKShapeNode(circleOfRadius: CGFloat.random(in: 1...2))
            amber.fillColor = UIColor(hex: 0xFFD27A).withAlpha(0.6); amber.strokeColor = .clear; amber.blendMode = .add
            amber.position = CGPoint(x: lampShadeCenter.x + .random(in: -lampShadeSize.width * 0.5...lampShadeSize.width * 0.5),
                                     y: lampShadeCenter.y + .random(in: -10...10))
            amber.zPosition = 0
            particleLayer.addChild(amber)
            amber.run(.sequence([.group([.moveBy(x: .random(in: -8...8), y: .random(in: 12...30), duration: 3), .fadeOut(withDuration: 3)]), .removeFromParent()]))
        }
    }

    private func beamPoint() -> CGPoint {
        let t = CGFloat.random(in: 0...1)
        let topX = CGFloat.random(in: windowInner.minX...windowInner.maxX)
        let botX = topX + (topX - windowCenter.x) * 0.7
        return CGPoint(x: topX + (botX - topX) * t, y: windowRect.minY - (windowRect.minY) * t)
    }

    // MARK: - Sound / haptics

    private func tone(_ spec: LullToneEngine.Spec, key: String, minInterval: TimeInterval = 0) {
        guard AudioManager.shared.isEnabled else { return }
        if minInterval > 0 {
            let now = CACurrentMediaTime()
            if let last = lastTone[key], now - last < minInterval { return }
            lastTone[key] = now
        }
        LullToneEngine.shared.play(spec, cacheKey: "glowwin.\(key)")
    }

    private func dialTick() {
        tone(.single(6 + Int(dayPhase * 8), .felt.with(body: 0.09, amplitude: 0.04)), key: "dial.tick", minInterval: 0.05)
        if Int(dayPhase * 40) % 2 == 0 { HapticsManager.shared.impact(style: .light, intensity: 0.08) }
    }

    // MARK: - Helpers

    private func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { min(max(v, lo), hi) }
    private func smoothstep(_ a: CGFloat, _ b: CGFloat, _ x: CGFloat) -> CGFloat {
        let t = clamp((x - a) / max(0.0001, b - a), 0, 1); return t * t * (3 - 2 * t)
    }
    private func bell(_ x: CGFloat, _ c: CGFloat, _ w: CGFloat) -> CGFloat { let d = (x - c) / w; return CGFloat(exp(-Double(d * d))) }
    private func angleDelta(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        var d = a - b; while d > .pi { d -= 2 * .pi }; while d < -(.pi) { d += 2 * .pi }; return d
    }
    private func lerpColor(_ a: UIColor, _ b: UIColor, _ t: CGFloat) -> UIColor {
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa); b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        let u = clamp(t, 0, 1)
        return UIColor(red: ar + (br - ar) * u, green: ag + (bg - ag) * u, blue: ab + (bb - ab) * u, alpha: aa + (ba - aa) * u)
    }
    private func sample(_ stops: [(CGFloat, UInt32)], _ t: CGFloat) -> UIColor {
        guard let first = stops.first else { return .white }
        if t <= first.0 { return UIColor(hex: first.1) }
        for i in 1..<stops.count where t <= stops[i].0 {
            let (p0, c0) = stops[i - 1], (p1, c1) = stops[i]
            return lerpColor(UIColor(hex: c0), UIColor(hex: c1), (t - p0) / max(0.0001, p1 - p0))
        }
        return UIColor(hex: stops.last!.1)
    }

    private static func crescentPath(radius r: CGFloat) -> CGPath {
        let full = UIBezierPath(arcCenter: .zero, radius: r, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        let bite = UIBezierPath(arcCenter: CGPoint(x: r * 0.5, y: r * 0.1), radius: r * 0.86, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        full.append(bite.reversing())
        full.usesEvenOddFillRule = true
        return full.cgPath
    }

    private static func verticalRamp(size: CGSize) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            let cg = ctx.cgContext
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }
            cg.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
        }
        return SKTexture(image: img)
    }

    private static func roundedRectTexture(size: CGSize, radius: CGFloat, color: UIColor) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { _ in
            color.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: radius).fill()
        }
        return SKTexture(image: img)
    }

    /// The room opens at the household's real hour — evening already feels like evening
    /// ("the room that warms and dims toward bedtime"). The child takes over from there.
    private static func phaseForClock(date: Date = Date()) -> CGFloat {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let h = CGFloat(comps.hour ?? 12) + CGFloat(comps.minute ?? 0) / 60
        if h < 6 { return 0.95 }   // the small hours stay deep night
        let stops: [(h: CGFloat, p: CGFloat)] = [(6, 0.04), (9, 0.2), (12, 0.3), (15, 0.4), (18, 0.5),
                                                 (19.5, 0.66), (21, 0.82), (22.5, 0.93), (24, 0.96)]
        for i in 1..<stops.count where h <= stops[i].h {
            let a = stops[i - 1], b = stops[i]
            return a.p + (b.p - a.p) * (h - a.h) / max(0.0001, b.h - a.h)
        }
        return 0.95
    }

    /// Rect with a full elliptical arch on top and softly rounded bottom corners — the
    /// window's signature silhouette. Used for the frame strokes and (flipped) the crop masks.
    private static func archedPath(in rect: CGRect, bottomRadius br: CGFloat) -> CGPath {
        let archH = min(rect.width / 2, rect.height * 0.34)
        let springY = rect.maxY - archH
        let p = CGMutablePath()
        p.move(to: CGPoint(x: rect.minX + br, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY + br), control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: springY))
        let steps = 48
        for i in 1...steps {
            let a: CGFloat = .pi - .pi * CGFloat(i) / CGFloat(steps)
            p.addLine(to: CGPoint(x: rect.midX + cos(a) * rect.width / 2, y: springY + sin(a) * archH))
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + br))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - br, y: rect.minY), control: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }

    private static func archedMaskTexture(size: CGSize, bottomRadius: CGFloat) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            let cg = ctx.cgContext
            cg.translateBy(x: 0, y: size.height)
            cg.scaleBy(x: 1, y: -1)
            cg.addPath(archedPath(in: CGRect(origin: .zero, size: size), bottomRadius: bottomRadius))
            cg.setFillColor(UIColor.white.cgColor)
            cg.fillPath()
        }
        return SKTexture(image: img)
    }

    // MARK: - Accessibility

    override func accessibilityElements(in view: SKView) -> [UIAccessibilityElement] {
        var elements = super.accessibilityElements(in: view)
        guard dialRadius > 1 else { return elements }
        elements.append(makeActivatableAccessibilityElement(
            in: view, label: "Sun and moon dial — turn to move the day from morning to night",
            scenePosition: dialCenter, size: CGSize(width: dialRadius * 2.4, height: dialRadius * 2.4), traits: .adjustable
        ) { [weak self] in
            guard let self else { return }
            self.setPhase(self.dayPhase >= 0.95 ? 0 : self.dayPhase + 0.2)
        })
        elements.append(makeActivatableAccessibilityElement(
            in: view, label: curtainOpen > 0.5 ? "Curtains — close" : "Curtains — open",
            scenePosition: CGPoint(x: windowCenter.x, y: windowCenter.y), size: CGSize(width: windowRect.width, height: windowRect.height), traits: .button
        ) { [weak self] in
            guard let self else { return }
            self.setCurtain(open: self.curtainOpen > 0.5 ? 0 : 1, animated: true)
            self.applyCurtain(animated: true)
        })
        elements.append(makeActivatableAccessibilityElement(
            in: view, label: lampOn ? "Lamp — turn off" : "Lamp — turn on",
            scenePosition: lampShadeCenter, size: lampShadeSize, traits: .button
        ) { [weak self] in
            self?.toggleLamp()
        })
        return elements
    }
}
