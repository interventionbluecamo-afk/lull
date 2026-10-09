import SpriteKit

/// Mix-Up — a living dress-up flip book. A character stands in a cosy dressing corner;
/// tap a zone (or its flip arrows) to swap head / body / legs. Mismatches are the joke.
final class MixUpScene: BaseToyScene {
    override var firstSessionHintKey: String? { "hint.mixup" }
    override var toyVoice: AudioManager.LullSoundVoice { .mixUp }
    override func firstSessionHintPoint() -> CGPoint { CGPoint(x: size.width / 2, y: characterRootY + 92 * mixScale) }

    private var stage = SKNode()
    private var root = SKNode()
    private var slots: [MixUpZone: SKNode] = [:]
    private var chevrons: [(zone: MixUpZone, dir: CGFloat, node: SKNode)] = []
    private var indices: [MixUpZone: Int] = [.head: 0, .body: 0, .legs: 0]
    private var flipping: Set<MixUpZone> = []
    private var changeCount = 0
    private var lastBuiltSize = CGSize.zero
    private var idleAccumulator: TimeInterval = 0
    private var lastUpdate: TimeInterval = 0

    // Keepsake — "save the moment." A clay heart button saves the current look onto a little
    // wooden creations shelf on the wall — a revisitable library of the characters the child has
    // made. Tap a saved portrait and that look page-flips back onto the live character. Pure
    // in-world: no Photos, no sharing, no second screen.
    private let keepsakeButton = SKNode()
    private let keepsakeButtonArt = SKNode()
    private weak var creationsLedge: SKNode?
    private var creationFrames: [(node: SKNode, recipe: MixUpCreation)] = []
    private var miniFrameSize: CGSize = .zero
    private var savingKeepsake = false
    private var lastFlourishAt: TimeInterval = 0
    private var lastBowedMatch: String?             // the bow fires once per match, re-armed when it breaks
    private weak var stageLightPool: SKShapeNode?

    /// The character and its controls have separate space. A circular control is
    /// finger-sized on a phone, rather than growing with the clay character.
    private lazy var characterEnvelope: CGRect = {
        var bounds = CGRect.null
        for zone in MixUpZone.allCases {
            let offset: CGFloat = zone == .head ? 92 : zone == .body ? 0 : -88
            for part in MixUpLibrary.parts(for: zone) {
                let frame = part.build(1).calculateAccumulatedFrame().offsetBy(dx: 0, dy: offset)
                bounds = bounds.union(frame)
            }
        }
        return bounds.isNull ? CGRect(x: -60, y: -98, width: 120, height: 239) : bounds
    }()

    private var controlRadius: CGFloat { isTabletLayout ? 27 : 22 }
    private var controlTouchRadius: CGFloat { controlRadius + 6 }
    private var keepsakeRadius: CGFloat { isTabletLayout ? 31 : 25 }
    private var floorY: CGFloat {
        max(safePlayRect().minY + (isLandscapeLayout ? 50 : 100),
            size.height * (isLandscapeLayout ? 0.19 : 0.25))
    }
    private var mixScale: CGFloat {
        let play = safePlayRect()
        let upperLimit = isLandscapeLayout ? play.maxY - 16
            : play.maxY - miniFrameBaseWidth * 1.42 - 16
        let heightFit = (upperLimit - floorY - 24) / max(237, characterEnvelope.height + 28)
        let widthFit = (play.width - 2 * (controlRadius * 2 + 18)) / max(130, characterEnvelope.width + 8)
        return min(heightFit, widthFit).clamped(to: 0.68...2.6)
    }
    private var characterRootY: CGFloat { floorY - characterEnvelope.minY * mixScale }
    private var roomDecorScale: CGFloat { mixScale.clamped(to: 0.9...1.55) }

    private func controlPosition(for zone: MixUpZone) -> CGPoint {
        let rightLimit = safePlayRect().maxX - controlRadius - 6
        let x = min(size.width / 2 + (characterEnvelope.maxX + 5) * mixScale + controlRadius + 18, rightLimit)
        let bodyY = characterRootY - 7 * mixScale
        let gap = controlRadius * 2 + 12
        let y: CGFloat
        switch zone {
        case .head: y = max(characterRootY + 76 * mixScale, bodyY + gap)
        case .body: y = bodyY
        case .legs: y = min(characterRootY + (characterEnvelope.minY - 42) / 2 * mixScale, bodyY - gap)
        }
        return CGPoint(x: x, y: y)
    }

    private func slotLocalY(_ zone: MixUpZone) -> CGFloat {
        switch zone {
        case .head: return 92 * mixScale
        case .body: return 0
        case .legs: return -88 * mixScale
        }
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        rebuild()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard abs(size.width - lastBuiltSize.width) > 2 || abs(size.height - lastBuiltSize.height) > 2 else { return }
        rebuild()
    }

    private func rebuild() {
        guard size.width > 160, size.height > 160 else { return }
        lastBuiltSize = size
        flipping.removeAll()
        chevrons.removeAll()
        creationFrames.removeAll()   // a fresh stage; the creations shelf is rebuilt from the store

        // Only rebuild our own content — leave the base paper + home handle untouched.
        stage.removeFromParent()
        stage = SKNode()
        stage.zPosition = 0
        addChild(stage)

        addRoom()

        #if DEBUG
        // LULL_DEBUG_MIXUP_LAST=1 opens on each pool's newest part (QA for art parts);
        // LULL_DEBUG_MIXUP_INDEX=n opens on pool index n across all zones.
        if ProcessInfo.processInfo.environment["LULL_DEBUG_MIXUP_LAST"] == "1" {
            for zone in MixUpZone.allCases {
                indices[zone] = max(0, MixUpLibrary.parts(for: zone).count - 1)
            }
        }
        if let v = ProcessInfo.processInfo.environment["LULL_DEBUG_MIXUP_INDEX"], let n = Int(v) {
            for zone in MixUpZone.allCases {
                indices[zone] = max(0, n % max(1, MixUpLibrary.parts(for: zone).count))
            }
        }
        #endif

        root = SKNode()
        root.position = CGPoint(x: size.width / 2, y: characterRootY)
        root.zPosition = 10
        stage.addChild(root)
        slots.removeAll()

        for zone in [MixUpZone.legs, .body, .head] {
            let slot = SKNode()
            slot.position = CGPoint(x: 0, y: slotLocalY(zone))
            // Big z gaps between zones so a body part's internal layers (collar, arms) can never
            // poke in front of the head — the head always reads cleanly on top.
            slot.zPosition = zone == .head ? 10 : (zone == .body ? 5 : 1)
            root.addChild(slot)
            slots[zone] = slot
            installPart(in: zone)
            addChevrons(for: zone)
        }
        AmbientAnimator.breathe(node: root, scale: 1.014, duration: 4.4)
        buildKeepsakeButton()
    }

    // MARK: - Keepsake ("save the moment")

    /// A small clay heart that rests on the floor. Press it and the character poses, a warm
    /// flash blooms, and a framed portrait of exactly this look lifts up and settles into the
    /// picture frame on the wall. "I made something special" — kept entirely in the toy.
    private func buildKeepsakeButton() {
        guard creationsLedge != nil else { keepsakeButton.removeFromParent(); return }
        keepsakeButton.removeFromParent()
        keepsakeButton.removeAllChildren()
        keepsakeButtonArt.removeAllChildren()
        keepsakeButton.name = "mixKeepsakeButton"
        keepsakeButton.zPosition = 30
        keepsakeButton.addChild(keepsakeButtonArt)

        let r = keepsakeRadius
        let shadow = SKShapeNode(ellipseOf: CGSize(width: r * 2.1, height: r * 0.7))
        shadow.fillColor = WarmShelfPalette.contactShadow.withAlpha(0.12)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -r * 0.92)
        shadow.zPosition = -1
        keepsakeButtonArt.addChild(shadow)

        // The authored clay heart, when it has landed — same press, same breath.
        if let art = ToyArt.sprite("mixup-heart-button", fit: CGSize(width: r * 2.3, height: r * 2.3)) {
            art.zPosition = 2
            keepsakeButtonArt.addChild(art)
            stage.addChild(keepsakeButton)
            keepsakeButton.position = CGPoint(x: size.width / 2,
                y: max(safeInsets.bottom + r + 12, floorY * 0.46))
            if !AmbientAnimator.reduceMotion {
                keepsakeButtonArt.run(.repeatForever(.sequence([
                    .wait(forDuration: 4.0),
                    .scale(to: 1.07, duration: 0.32),
                    .scale(to: 1.0, duration: 0.5)
                ])), withKey: "breath")
            }
            return
        }

        let base = SKShapeNode(circleOfRadius: r)
        base.fillColor = WarmShelfPalette.warmCream.withAlpha(0.97)
        base.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.12)
        base.lineWidth = 1.5
        keepsakeButtonArt.addChild(base)
        ProceduralTexture.addMatteClayDepth(
            to: base, ellipse: CGSize(width: r * 2, height: r * 2), zPosition: 0.1,
            highlightAlpha: 0.26, shadeAlpha: 0.06, rimAlpha: 0.04, speckleCount: 2
        )

        let heart = SKShapeNode(path: Self.heartPath(size: r * 1.15))
        heart.fillColor = WarmShelfPalette.rhubarb.withAlpha(0.92)
        heart.strokeColor = WarmShelfPalette.paperHighlight.withAlpha(0.5)
        heart.lineWidth = 1
        heart.zPosition = 2
        keepsakeButtonArt.addChild(heart)

        stage.addChild(keepsakeButton)

        keepsakeButton.position = CGPoint(x: size.width / 2,
            y: max(safeInsets.bottom + r + 12, floorY * 0.46))

        // A gentle, occasional breath so it's noticed but never nags.
        if !AmbientAnimator.reduceMotion {
            keepsakeButtonArt.run(.repeatForever(.sequence([
                .wait(forDuration: 4.0),
                .scale(to: 1.07, duration: 0.32),
                .scale(to: 1.0, duration: 0.5)
            ])), withKey: "breath")
        }
    }

    private func keepsakeButtonContains(_ point: CGPoint) -> Bool {
        guard keepsakeButton.parent != nil else { return false }
        let radius = keepsakeRadius + 8
        return hypot(point.x - keepsakeButton.position.x, point.y - keepsakeButton.position.y) < radius
    }

    private func saveKeepsake() {
        guard !savingKeepsake, let view = self.view, let ledge = creationsLedge else { return }
        savingKeepsake = true

        // Press the heart: quick squash in, slow ease out (the asymmetry law made tactile).
        keepsakeButtonArt.removeAction(forKey: "breath")
        keepsakeButtonArt.removeAction(forKey: "press")
        let press = SKAction.scale(to: 0.82, duration: 0.08); press.timingMode = .easeOut
        let release = SKAction.scale(to: 1.0, duration: 0.34); release.timingMode = .easeInEaseOut
        keepsakeButtonArt.run(.sequence([press, release]), withKey: "press")

        HapticsManager.shared.play(score: .mixUpCombo)
        AudioManager.shared.playMixCelebrate()

        // A proud little pose and a soft flash of keepsake light.
        hop(height: 18 * mixScale, squash: true)
        if !AmbientAnimator.reduceMotion {
            flashCharacterShade(color: WarmShelfPalette.paperHighlight, peak: 0.3)
        }

        // Snapshot the character (hide the flip arrows so they don't end up in the portrait).
        chevrons.forEach { $0.node.isHidden = true }
        let texture = view.texture(from: root)
        chevrons.forEach { $0.node.isHidden = false }
        guard let texture else { savingKeepsake = false; return }

        // A copy of the character lifts off and flies up to its new spot on the creations shelf.
        let innerW = miniFrameSize.width * 0.84
        let innerH = miniFrameSize.height * 0.86
        let texSize = texture.size()
        let fit = min(innerW / max(1, texSize.width), innerH / max(1, texSize.height))

        let recipe = currentRecipe()
        let newCount = min(MixUpCreationStore.load().count + 1, creationDisplayCapacity)
        let slots = shelfSlotPositions(count: newCount)
        let target = CGPoint(x: ledge.position.x + (slots.last?.x ?? 0),
                             y: ledge.position.y + (slots.last?.y ?? 0))

        let flying = SKSpriteNode(texture: texture)
        let characterBounds = root.calculateAccumulatedFrame()
        flying.position = CGPoint(x: characterBounds.midX, y: characterBounds.midY)
        flying.zPosition = 60
        addChild(flying)

        let move = SKAction.move(to: target, duration: 0.72); move.timingMode = .easeInEaseOut
        let shrink = SKAction.scale(to: fit, duration: 0.72); shrink.timingMode = .easeInEaseOut
        flying.run(.group([move, shrink]), completion: { [weak self, weak flying] in
            flying?.removeFromParent()
            MixUpCreationStore.append(recipe)
            self?.buildCreationsShelf()
            self?.savingKeepsake = false
        })

        // A sparkle on the shelf as the new creation arrives.
        run(.sequence([
            .wait(forDuration: 0.66),
            .run { [weak self] in
                guard let self else { return }
                TouchFeedbackAnimator.bubblePopRing(in: self, at: target, radius: 26, color: WarmShelfPalette.butter)
            }
        ]))
    }

    // MARK: - Creations library (saved looks on a little wooden shelf)

    struct MixUpCreation: Codable, Equatable {
        let head: Int
        let body: Int
        let legs: Int
    }

    private enum MixUpCreationStore {
        private static let key = "lull.mixup.creations"
        private static let castVersionKey = "lull.mixup.creations.castVersion"
        private static let castVersion = 4   // 4: robot, officer, firefighter appended (6-8)
        static let capacity = 6
        static func load() -> [MixUpCreation] {
            let defaults = UserDefaults.standard
            guard let data = defaults.data(forKey: key),
                  let list = try? JSONDecoder().decode([MixUpCreation].self, from: data) else { return [] }
            let storedVersion = defaults.integer(forKey: castVersionKey)
            guard storedVersion != castVersion else { return list }
            let migrated = list.map { recipe in
                MixUpCreation(head: MixUpLibrary.migratedIndex(recipe.head, fromVersion: storedVersion),
                              body: MixUpLibrary.migratedIndex(recipe.body, fromVersion: storedVersion),
                              legs: MixUpLibrary.migratedIndex(recipe.legs, fromVersion: storedVersion))
            }
            if let data = try? JSONEncoder().encode(migrated) {
                defaults.set(data, forKey: key)
                defaults.set(castVersion, forKey: castVersionKey)
            }
            return migrated
        }
        static func append(_ creation: MixUpCreation) {
            var list = load()
            list.append(creation)
            if list.count > capacity { list.removeFirst(list.count - capacity) }
            if let data = try? JSONEncoder().encode(list) {
                UserDefaults.standard.set(data, forKey: key)
                UserDefaults.standard.set(castVersion, forKey: castVersionKey)
            }
        }
    }

    private func currentRecipe() -> MixUpCreation {
        MixUpCreation(head: indices[.head] ?? 0, body: indices[.body] ?? 0, legs: indices[.legs] ?? 0)
    }

    private var miniFrameBaseWidth: CGFloat {
        min(isTabletLayout ? 94 : 68, safePlayRect().width * 0.22)
    }

    /// Portrait keepsakes sit above the character; landscape keepsakes form a
    /// short column to its left so neither reduces the character to a thumbnail.
    private var creationDisplayCapacity: Int {
        let play = safePlayRect()
        let space = isLandscapeLayout ? play.height - 12 : play.width - 12
        let step = isLandscapeLayout ? miniFrameBaseWidth * 1.42 + 16 : miniFrameBaseWidth + 14
        return max(1, min(MixUpCreationStore.capacity, Int(space / step)))
    }

    private func shelfSlotPositions(count: Int) -> [CGPoint] {
        let step = isLandscapeLayout ? miniFrameSize.height + 16 : miniFrameSize.width + 14
        let total = CGFloat(max(0, count - 1)) * step
        return (0..<max(1, count)).map { index in
            isLandscapeLayout
                ? CGPoint(x: 0, y: total / 2 - CGFloat(index) * step)
                : CGPoint(x: -total / 2 + CGFloat(index) * step, y: 0)
        }
    }

    private func buildCreationsShelf() {
        creationsLedge?.removeFromParent()
        creationFrames.removeAll()
        miniFrameSize = CGSize(width: miniFrameBaseWidth, height: miniFrameBaseWidth * 1.42)
        let play = safePlayRect()
        let ledge = SKNode()
        ledge.position = isLandscapeLayout
            ? CGPoint(x: play.minX + miniFrameSize.width * 0.6 + 12, y: play.midY)
            : CGPoint(x: size.width / 2, y: play.maxY - miniFrameSize.height / 2 - 8)
        ledge.zPosition = 3
        stage.addChild(ledge)
        creationsLedge = ledge
        let creations = Array(MixUpCreationStore.load().suffix(creationDisplayCapacity))
        let positions = shelfSlotPositions(count: max(1, creations.count))

        func addLedge(at point: CGPoint, width: CGFloat) {
            let board = SKShapeNode(rectOf: CGSize(width: width, height: 7), cornerRadius: 3.5)
            board.position = CGPoint(x: point.x, y: point.y - miniFrameSize.height * 0.55)
            board.fillColor = WarmShelfPalette.sand.withAlpha(0.7)
            board.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.1)
            board.lineWidth = 1
            ledge.addChild(board)
        }
        if isLandscapeLayout {
            positions.forEach { addLedge(at: $0, width: miniFrameSize.width * 1.22) }
        } else {
            let width = (positions.last?.x ?? 0) - (positions.first?.x ?? 0) + miniFrameSize.width * 1.24
            addLedge(at: .zero, width: width)
        }

        if creations.isEmpty {
            // The quiet empty frame echoes the save heart; pressing it replaces
            // this placeholder with the child's own portrait.
            let empty = makeCreationMat()
            let heart = SKShapeNode(path: Self.heartPath(size: miniFrameSize.width * 0.3))
            heart.fillColor = WarmShelfPalette.petal.withAlpha(0.32)
            heart.strokeColor = WarmShelfPalette.rhubarb.withAlpha(0.18)
            heart.lineWidth = 1
            heart.zPosition = 2
            empty.addChild(heart)
            ledge.addChild(empty)
        }
        for (index, recipe) in creations.enumerated() {
            let frame = makeCreationFrame(recipe: recipe)
            frame.position = positions[index]
            ledge.addChild(frame)
            creationFrames.append((node: frame, recipe: recipe))
        }
    }

    private func makeCreationMat() -> SKNode {
        let node = SKNode()
        let mat = SKShapeNode(rectOf: miniFrameSize, cornerRadius: 8)
        mat.fillColor = WarmShelfPalette.paperHighlight
        mat.strokeColor = WarmShelfPalette.softLine.withAlpha(0.9)
        mat.lineWidth = 1.4
        mat.zPosition = 1.5
        node.addChild(mat)
        return node
    }

    /// One framed portrait: a static mini of the saved look, rebuilt from its 3-part recipe.
    private func makeCreationFrame(recipe: MixUpCreation) -> SKNode {
        let node = makeCreationMat()
        let mini = SKNode()
        let s: CGFloat = 1
        let stack: [(zone: MixUpZone, index: Int, z: CGFloat)] = [
            (.legs, recipe.legs, 1.52), (.body, recipe.body, 1.54), (.head, recipe.head, 1.56)
        ]
        for entry in stack {
            let parts = MixUpLibrary.parts(for: entry.zone)
            guard !parts.isEmpty else { continue }
            let idx = ((entry.index % parts.count) + parts.count) % parts.count
            let part = parts[idx].build(s)
            part.position = CGPoint(x: 0, y: zoneMiniY(entry.zone, scale: s))
            part.zPosition = entry.z
            mini.addChild(part)
        }
        let bounds = mini.calculateAccumulatedFrame()
        let fit = min(miniFrameSize.width * 0.84 / max(1, bounds.width),
                      miniFrameSize.height * 0.86 / max(1, bounds.height))
        mini.setScale(fit)
        mini.position = CGPoint(x: -bounds.midX * fit, y: -bounds.midY * fit)
        mini.isPaused = true   // a portrait, not a puppet — any part animations freeze solid
        node.addChild(mini)
        return node
    }

    private func zoneMiniY(_ zone: MixUpZone, scale s: CGFloat) -> CGFloat {
        switch zone {
        case .head: return 92 * s
        case .body: return 0
        case .legs: return -88 * s
        }
    }

    private func creationFrameHit(at point: CGPoint) -> (node: SKNode, recipe: MixUpCreation)? {
        guard let ledge = creationsLedge else { return nil }
        for entry in creationFrames {
            let p = CGPoint(x: ledge.position.x + entry.node.position.x, y: ledge.position.y + entry.node.position.y)
            if abs(point.x - p.x) < miniFrameSize.width * 0.62, abs(point.y - p.y) < miniFrameSize.height * 0.72 {
                return entry
            }
        }
        return nil
    }

    /// Bring a saved look back to life: the tapped portrait nods, then each zone page-flips to the
    /// saved part under one soft costume puff. Mash-safe: zones already mid-flip are skipped.
    private func applyCreation(_ recipe: MixUpCreation, from frameNode: SKNode) {
        frameNode.run(.sequence([.scale(to: 0.88, duration: 0.08), .scale(to: 1.0, duration: 0.2)]))
        let target: [MixUpZone: Int] = [.head: recipe.head, .body: recipe.body, .legs: recipe.legs]
        var changedAny = false
        var arrivingHead: String?
        for (zone, rawIndex) in target {
            let parts = MixUpLibrary.parts(for: zone)
            guard !parts.isEmpty else { continue }
            let idx = ((rawIndex % parts.count) + parts.count) % parts.count
            guard indices[zone] != idx, !flipping.contains(zone), let slot = slots[zone] else { continue }
            changedAny = true
            if zone == .head { arrivingHead = parts[idx].name }
            flipping.insert(zone)
            indices[zone] = idx
            let close = SKAction.scaleY(to: 0.04, duration: 0.13); close.timingMode = .easeIn
            let swap = SKAction.run { [weak self] in self?.installPart(in: zone) }
            let open = SKAction.scaleY(to: 1.12, duration: 0.16); open.timingMode = .easeOut
            let settle = SKAction.scaleY(to: 1.0, duration: 0.22); settle.timingMode = .easeInEaseOut
            slot.run(.sequence([close, swap, open, settle,
                                .run { [weak self] in
                                    self?.flipping.remove(zone)
                                    self?.checkMatchedBow()   // a saved look can complete a match too
                                }]), withKey: "flip")
        }
        if changedAny {
            removeAction(forKey: Self.wholeFriendShowKey)
            transformationFlourish(zone: .body)
            AudioManager.shared.playMixFlip()
            if let arrivingHead {
                // The returning friend says hello once its head has landed.
                run(.sequence([.wait(forDuration: 0.4), .run { [weak self] in self?.voiceArrival(of: arrivingHead) }]))
            }
        } else {
            hop(height: 10 * mixScale, squash: true)   // already wearing this look — a happy little hop
        }
    }

    private static func heartPath(size: CGFloat) -> CGPath {
        let w = size, h = size
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0, y: h * 0.30))
        p.addCurve(to: CGPoint(x: -w * 0.5, y: h * 0.05),
                   control1: CGPoint(x: -w * 0.1, y: h * 0.5),
                   control2: CGPoint(x: -w * 0.5, y: h * 0.38))
        p.addCurve(to: CGPoint(x: 0, y: -h * 0.5),
                   control1: CGPoint(x: -w * 0.5, y: -h * 0.22),
                   control2: CGPoint(x: -w * 0.15, y: -h * 0.30))
        p.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.05),
                   control1: CGPoint(x: w * 0.15, y: -h * 0.30),
                   control2: CGPoint(x: w * 0.5, y: -h * 0.22))
        p.addCurve(to: CGPoint(x: 0, y: h * 0.30),
                   control1: CGPoint(x: w * 0.5, y: h * 0.38),
                   control2: CGPoint(x: w * 0.1, y: h * 0.5))
        p.closeSubpath()
        return p
    }

    // MARK: - Room

    /// A quiet cream room and a plain wooden stand, using the same palette and
    /// soft material depth as the shelf. The character is the only ornament.
    /// Quiet wool fibres are a shared static material, without ornamental scenery.
    private static let roomFelt: SKTexture = {
        let side: CGFloat = 96
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            let cg = context.cgContext
            cg.setFillColor(WarmShelfPalette.linen.cgColor)
            cg.fill(CGRect(x: 0, y: 0, width: side, height: side))
            var seed: UInt64 = 0xF317A5
            func sample() -> CGFloat {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return CGFloat((seed >> 32) & 0xFFFF) / 65535
            }
            cg.setLineCap(.round)
            for index in 0..<650 {
                let p = CGPoint(x: sample() * side, y: sample() * side)
                let angle = sample() * .pi * 2
                let length = 0.7 + sample() * 2.0
                cg.setStrokeColor((index.isMultiple(of: 3) ? WarmShelfPalette.cocoa.withAlpha(0.035) : UIColor.white.withAlpha(0.22)).cgColor)
                cg.setLineWidth(0.3 + sample() * 0.45)
                cg.move(to: p)
                cg.addLine(to: CGPoint(x: p.x + cos(angle) * length, y: p.y + sin(angle) * length))
                cg.strokePath()
            }
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }()

    private func addRoom() {
        let decor = roomDecorScale
        let wall = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        wall.fillColor = WarmShelfPalette.linen
        wall.strokeColor = .clear
        wall.zPosition = 1
        stage.addChild(wall)
        let tileSide: CGFloat = 96
        for column in 0..<Int(ceil(size.width / tileSide)) {
            for row in 0..<Int(ceil(size.height / tileSide)) {
                let fibre = SKSpriteNode(texture: Self.roomFelt)
                fibre.size = CGSize(width: tileSide + 0.5, height: tileSide + 0.5)
                fibre.position = CGPoint(x: (CGFloat(column) + 0.5) * tileSide, y: (CGFloat(row) + 0.5) * tileSide)
                fibre.zPosition = 1.02
                stage.addChild(fibre)
            }
        }

        let light = SKSpriteNode(texture: ProceduralTexture.softRadialGlow)
        light.color = WarmShelfPalette.paperHighlight
        light.colorBlendFactor = 1
        light.size = CGSize(width: min(size.width * 1.2, 900), height: size.height * 0.9)
        light.position = CGPoint(x: size.width / 2, y: floorY + (size.height - floorY) * 0.42)
        light.alpha = 0.4
        light.zPosition = 1.1
        stage.addChild(light)

        let floor = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.width, height: floorY))
        floor.fillColor = WarmShelfPalette.warmCream.withAlpha(0.65)
        floor.strokeColor = .clear
        floor.zPosition = 2
        stage.addChild(floor)
        let seam = SKShapeNode(rect: CGRect(x: 0, y: floorY - 1, width: size.width, height: 2))
        seam.fillColor = WarmShelfPalette.cocoa.withAlpha(0.06)
        seam.strokeColor = .clear
        seam.zPosition = 2.05
        stage.addChild(seam)

        let width = min(safePlayRect().width * 0.72,
                        max(150, characterEnvelope.width * mixScale * 1.3), 440 * decor)
        let front = SKShapeNode(rectOf: CGSize(width: width, height: 24 * decor), cornerRadius: 10 * decor)
        front.fillColor = WarmShelfPalette.sand.withAlpha(0.76)
        front.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.14)
        front.lineWidth = 1
        front.position = CGPoint(x: size.width / 2, y: floorY - 20 * decor)
        front.zPosition = 2.3
        stage.addChild(front)
        let top = SKShapeNode(ellipseOf: CGSize(width: width, height: 42 * decor))
        top.fillColor = UIColor(hex: 0xDEC9AB)
        top.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.12)
        top.lineWidth = 1
        top.position = CGPoint(x: size.width / 2, y: floorY - 9 * decor)
        top.zPosition = 2.4
        stage.addChild(top)
        for index in -1...1 {
            let path = CGMutablePath()
            let y = CGFloat(index) * 7 * decor
            path.move(to: CGPoint(x: -width * 0.3, y: y))
            path.addQuadCurve(to: CGPoint(x: width * 0.3, y: y),
                              control: CGPoint(x: 0, y: y + 3 * decor))
            let grain = SKShapeNode(path: path)
            grain.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.07)
            grain.lineWidth = 1
            grain.zPosition = 0.01
            top.addChild(grain)
        }
        stageLightPool = top

        let shadowSize = CGSize(width: min(104 * mixScale, width * 0.7), height: 18 * decor)
        let shadow = SKSpriteNode(texture: ProceduralTexture.softClayShadow(size: shadowSize))
        shadow.size = shadowSize
        shadow.position = CGPoint(x: size.width / 2, y: floorY - 1.5 * decor)
        shadow.alpha = 0.55
        shadow.zPosition = 2.5
        stage.addChild(shadow)
        buildCreationsShelf()
    }

    private func installPart(in zone: MixUpZone) {
        guard let slot = slots[zone] else { return }
        let parts = MixUpLibrary.parts(for: zone)
        guard !parts.isEmpty else { return }
        let index = (indices[zone] ?? 0) % parts.count
        slot.removeAllChildren()
        let part = parts[index].build(mixScale)
        slot.addChild(part)
        // The toy view flattens z globally (ignoresSiblingOrder), so the slot's own z does
        // NOT lift its part. Band each zone apart by absolute z so the head always sits in
        // front of the body in front of the legs — and the whole character in front of the room.
        let band: CGFloat = zone == .head ? 40 : (zone == .body ? 30 : 20)
        liftZPosition(part, by: band)
    }

    /// Add a base z to a node and every descendant — preserves each part's internal layering
    /// while banding the zones apart under the view's global (sibling-order-ignoring) sort.
    private func liftZPosition(_ node: SKNode, by base: CGFloat) {
        node.zPosition += base
        node.children.forEach { liftZPosition($0, by: base) }
    }

    private func addChevrons(for zone: MixUpZone) {
        let r = controlRadius
        let chevron = SKNode()
        chevron.position = controlPosition(for: zone)
        // Scene-level controls stay still while the character bows or hops.
        chevron.zPosition = 50
        let shadow = SKShapeNode(circleOfRadius: r)
        shadow.fillColor = WarmShelfPalette.contactShadow.withAlpha(0.09)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -2)
        shadow.zPosition = 50
        chevron.addChild(shadow)
        let disc = SKShapeNode(circleOfRadius: r)
        disc.fillColor = WarmShelfPalette.warmCream
        disc.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.2)
        disc.lineWidth = 1.5
        disc.zPosition = 51
        chevron.addChild(disc)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -3, y: 7))
        path.addLine(to: CGPoint(x: 4, y: 0))
        path.addLine(to: CGPoint(x: -3, y: -7))
        let arrow = SKShapeNode(path: path)
        arrow.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.85)
        arrow.lineWidth = 3
        arrow.lineCap = .round
        arrow.lineJoin = .round
        arrow.zPosition = 52
        chevron.addChild(arrow)
        stage.addChild(chevron)
        chevrons.append((zone, 1, chevron))
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        HapticsManager.shared.prepareForTouch()
        for touch in touches {
            let point = touch.location(in: self)
            if consumeShelfReturnTouch(at: point) { return }

            // The clay heart saves the current look onto the creations shelf.
            if keepsakeButtonContains(point) {
                saveKeepsake()
                return
            }

            // A saved creation on the shelf — tap it to bring that look back to life.
            if let hit = creationFrameHit(at: point) {
                applyCreation(hit.recipe, from: hit.node)
                return
            }

            // The visible controls own only their reserved lane, not the body.
            if let hit = chevrons.min(by: {
                let first = $0.node.convert(CGPoint.zero, to: self)
                let second = $1.node.convert(CGPoint.zero, to: self)
                return hypot(first.x - point.x, first.y - point.y)
                    < hypot(second.x - point.x, second.y - point.y)
            }) {
                let center = hit.node.convert(CGPoint.zero, to: self)
                if hypot(center.x - point.x, center.y - point.y) < controlTouchRadius {
                    hit.node.run(.sequence([.scale(to: 0.92, duration: 0.07),
                                           .scale(to: 1, duration: 0.18)]), withKey: "press")
                    flip(hit.zone, forward: hit.dir > 0)
                    return
                }
            }
            let localToRoot = CGPoint(x: point.x - root.position.x, y: point.y - root.position.y)
            let localY = point.y - root.position.y
            let touchedCharacter = abs(localToRoot.x) < 140 * mixScale &&
                localY > -145 * mixScale && localY < 155 * mixScale
            if touchedCharacter {
                flip(zoneForLocalY(localY), forward: true)
            } else {
                TouchFeedbackAnimator.emptyTap(in: self, at: point)
            }
            return
        }
    }

    private func zoneForLocalY(_ y: CGFloat) -> MixUpZone {
        if y > 44 * mixScale { return .head }
        if y < -44 * mixScale { return .legs }
        return .body
    }

    private func flip(_ zone: MixUpZone, forward: Bool) {
        guard !flipping.contains(zone), let slot = slots[zone] else { return }
        let parts = MixUpLibrary.parts(for: zone)
        guard parts.count > 1 else { return }
        flipping.insert(zone)
        removeAction(forKey: Self.wholeFriendShowKey)   // the friend is changing: no bow for the old one
        let count = parts.count
        let cur = indices[zone] ?? 0
        indices[zone] = ((cur + (forward ? 1 : -1)) % count + count) % count

        let close = SKAction.scaleY(to: 0.04, duration: 0.13); close.timingMode = .easeIn
        let swap = SKAction.run { [weak self] in self?.installPart(in: zone) }
        let open = SKAction.scaleY(to: 1.12, duration: 0.16); open.timingMode = .easeOut
        // Settle slower than open — the page breathes back rather than snapping.
        let settle = SKAction.scaleY(to: 1.0, duration: 0.22); settle.timingMode = .easeInEaseOut
        slot.run(.sequence([
            close,
            swap,
            open,
            settle,
            .run {
                AudioManager.shared.playMixSettle()
            },
            .run { [weak self] in
                guard let self else { return }
                if zone == .head { self.voiceArrival(of: self.currentPartName(.head)) }
                self.flipping.remove(zone)
                self.checkMatchedBow()   // a whole friend cancels the arrival hello for its own
            }
        ]), withKey: "flip")

        changeCount += 1
        transformationFlourish(zone: zone)
        celebrate(zone: zone)
        AudioManager.shared.playMixFlip()   // haptic fires inside
    }

    /// The change should feel like a real little transformation — but calm. A soft clay "poof"
    /// blooms right at the zone as the new part appears, with a few drifting motes. It is
    /// *contained* (never a whole-screen flash) and rate-limited, so a toddler mashing the
    /// character gets a gentle, non-strobing response. The physical page-flip and the
    /// character's personality reaction carry the drama; the light just kisses the change.
    private func transformationFlourish(zone: MixUpZone) {
        let local = CGPoint(x: 0, y: slotLocalY(zone))
        let scenePoint = CGPoint(x: root.position.x, y: root.position.y + slotLocalY(zone))
        let rare = currentPart(zone)?.isRare == true
        let accent = rare ? WarmShelfPalette.rhubarb : WarmShelfPalette.butter

        let now = lastUpdate
        let rapid = now - lastFlourishAt < 0.5   // mashing → keep it quiet
        lastFlourishAt = now

        if !AmbientAnimator.reduceMotion && !rapid {
            // A soft tinted bubble-cloud blooms over the WHOLE zone as the new part swaps in behind
            // it — bigger and more magical than a dot, still a calm alpha bloom (never a flash).
            let reach = (zone == .body ? 100 : 84) * mixScale
            let cloud = SKNode()
            cloud.position = local
            cloud.zPosition = 53
            let puffs: [(CGFloat, CGFloat, CGFloat)] = [(0, 0, 1.0), (-0.5, 0.18, 0.64), (0.5, 0.16, 0.62), (-0.28, -0.2, 0.5), (0.3, -0.18, 0.52)]
            for (dx, dy, s) in puffs {
                let puff = SKShapeNode(circleOfRadius: reach * s)
                puff.fillColor = accent.withAlpha(0.26)
                puff.strokeColor = .clear
                puff.position = CGPoint(x: dx * reach, y: dy * reach)
                cloud.addChild(puff)
            }
            cloud.setScale(0.5)
            cloud.alpha = 0
            root.addChild(cloud)
            cloud.run(.sequence([
                .group([.scale(to: 1.0, duration: 0.14), .fadeAlpha(to: 0.55, duration: 0.12)]),
                .group([.scale(to: 1.36, duration: 0.4), .fadeOut(withDuration: 0.4)]),
                .removeFromParent()
            ]))
        }

        // A few soft motes — fewer still when mashing.
        paperMotes(at: scenePoint, count: AmbientAnimator.reduceMotion ? 2 : (rapid ? 3 : (rare ? 9 : 5)))

        // The clean rim ring is reserved for a settled or rare change — never every rapid tap.
        if !rapid {
            TouchFeedbackAnimator.bubblePopRing(
                in: self, at: scenePoint, radius: (rare ? 52 : 40) * mixScale, color: accent
            )
        }
    }

    /// A single deliberate warm flash for the keepsake "snapshot" moment (used only there —
    /// never on outfit changes). Kept gentle.
    private func flashCharacterShade(color: UIColor, peak: CGFloat) {
        let shade = SKShapeNode(ellipseOf: CGSize(width: 220 * mixScale, height: 330 * mixScale))
        shade.fillColor = color.withAlpha(0.9)
        shade.strokeColor = .clear
        shade.alpha = 0
        shade.blendMode = .add
        shade.position = CGPoint(x: 0, y: 6 * mixScale)
        shade.zPosition = 52
        root.addChild(shade)
        shade.run(.sequence([
            .fadeAlpha(to: peak, duration: 0.10),
            .fadeAlpha(to: 0, duration: 0.42),
            .removeFromParent()
        ]))
    }

    /// The new self has flipped in — now the character *reacts* to it. This is the soul of
    /// Mix-Up: not a slot machine, but a silly friend delighted by whatever it becomes.
    private func celebrate(zone: MixUpZone) {
        // The transformation light/ring/motes are handled by `transformationFlourish`. Here we
        // keep the *sound* restrained — only a rare or every-fifth change earns the warm chime —
        // and drive the personality beat so the character reacts to whatever it just became.
        let rareTaDa = currentPart(zone)?.isRare == true
        let bigTaDa = rareTaDa || changeCount % 5 == 0
        if bigTaDa {
            AudioManager.shared.playMixCelebrate()
        }

        // Let the part finish flipping in, then the whole character notices and reacts to it.
        // (The whole-friend moment, which replaced the procedural-era theme combos, is
        // driven by checkMatchedBow once every zone has settled.)
        run(.sequence([.wait(forDuration: 0.40), .run { [weak self] in
            guard let self else { return }
            switch zone {
            case .head: self.headPersonality(self.currentPartName(.head))
            case .body: self.peerDown(by: -0.16); self.showOffBody()
            case .legs: self.peerDown(by: -0.30); self.showOffLegs()
            }
        }]))
    }

    private func currentPartName(_ zone: MixUpZone) -> String {
        currentPart(zone)?.baseName ?? ""
    }

    private static let arrivalVoiceKey = "mixFriendArrivalVoice"
    private static let wholeFriendKey = "mixWholeFriend"
    private static let personalityKey = "mixPersonality"
    private static let wholeFriendShowKey = "mixWholeFriendShow"

    /// The friend whose head just landed says hello in its own voice, a beat after the
    /// settle tone so the two never stack. Keyed: mashing keeps only the newest hello,
    /// and a whole-friend moment (which has its own voice) cancels it.
    private func voiceArrival(of name: String) {
        guard !name.isEmpty else { return }
        removeAction(forKey: Self.arrivalVoiceKey)
        run(.sequence([
            .wait(forDuration: 0.12),
            .run { AudioManager.shared.playMixFriend(name, moment: .arrive) }
        ]), withKey: Self.arrivalVoiceKey)
    }

    /// Approved delight: the whole friend. All three zones settled on the SAME character —
    /// it is suddenly whole again. The spotlight warms, the friend says so in its own voice,
    /// does its own small signature move and takes one small bow. Once per match (re-armed
    /// when the match breaks). Name equality keeps this art-era-only — procedural pools
    /// never align by name.
    private func checkMatchedBow() {
        guard flipping.isEmpty else { return }   // only the LAST settling zone reports
        let name = currentPartName(.head)
        guard !name.isEmpty,
              name == currentPartName(.body),
              name == currentPartName(.legs) else {
            lastBowedMatch = nil                 // match broke — a future match may bow again
            return
        }
        guard lastBowedMatch != name else { return }
        lastBowedMatch = name
        removeAction(forKey: Self.arrivalVoiceKey)   // one voice: the whole-friend one
        // Let the flip's own settle exhale finish before the character notices itself.
        run(.sequence([.wait(forDuration: 0.30), .run { [weak self] in self?.bowOnStage(name) }]),
            withKey: Self.wholeFriendKey)
    }

    private func bowOnStage(_ name: String) {
        // A flip that started during the short pause already broke the match.
        guard currentPartName(.head) == name, currentPartName(.body) == name,
              currentPartName(.legs) == name else { return }
        AudioManager.shared.playMixFriend(name, moment: .wholeFriend)
        HapticsManager.shared.softTap()

        // Light is not motion: the robot's glow pulses under Reduce Motion too, once.
        if name == "robot" { robotGlowPulse(pulses: AmbientAnimator.reduceMotion ? 1 : 2, peak: 0.6) }
        let signature = AmbientAnimator.reduceMotion ? 0 : wholeFriendSignature(name)

        // The spotlight warms for the whole moment — layered over the authored pool (its
        // node alpha is already 1.0), or a soft pool at the feet in the procedural room.
        let warm: SKShapeNode
        if let pool = stageLightPool {
            warm = SKShapeNode(ellipseOf: pool.frame.size)
            warm.position = pool.position
            warm.zPosition = pool.zPosition + 0.01
        } else {
            warm = SKShapeNode(ellipseOf: CGSize(width: 240 * roomDecorScale, height: 56 * roomDecorScale))
            warm.position = CGPoint(x: root.position.x, y: floorY - 4 * roomDecorScale)
            warm.zPosition = 2.46
        }
        warm.fillColor = WarmShelfPalette.butter.withAlpha(0.22)
        warm.strokeColor = .clear
        warm.blendMode = .add
        warm.alpha = 0
        stage.addChild(warm)
        warm.run(.sequence([
            .fadeIn(withDuration: 0.5),
            .wait(forDuration: 1.1 + signature),
            .fadeOut(withDuration: 1.3),
            .removeFromParent()
        ]))

        // Its own signature first, then the small bow that closes every whole friend.
        guard !AmbientAnimator.reduceMotion else { return }
        run(.sequence([.wait(forDuration: signature), .run { [weak self] in self?.takeBow() }]),
            withKey: Self.wholeFriendShowKey)
    }

    private func takeBow() {
        // One small bow: root nod (rotation only — root's SCALE belongs to the breathe
        // loop) plus a gentle body-slot dip. Absolute returns, hop-style.
        root.removeAction(forKey: "sway")
        root.removeAction(forKey: "bow")
        let lean = SKAction.rotate(toAngle: 0.09, duration: 0.34); lean.timingMode = .easeInEaseOut
        let rise = SKAction.rotate(toAngle: 0, duration: 0.50);    rise.timingMode = .easeInEaseOut
        root.run(.sequence([lean, .wait(forDuration: 0.34), rise]), withKey: "bow")
        if let body = slots[.body] {
            body.removeAction(forKey: "react")
            body.run(.sequence([
                .scaleY(to: 0.94, duration: 0.34),
                .wait(forDuration: 0.34),
                .scaleY(to: 1.0, duration: 0.50)
            ]), withKey: "react")
        }
    }

    // MARK: - Whole friend (each friend's own signature flourish)

    private var headHome: CGPoint { CGPoint(x: 0, y: slotLocalY(.head)) }
    private var rootHomeX: CGFloat { size.width / 2 }

    private func eased(_ action: SKAction, _ mode: SKActionTimingMode = .easeInEaseOut) -> SKAction {
        action.timingMode = mode
        return action
    }

    /// Every new head move starts here: back to the head's home pose (place, tilt and the
    /// officer's half-turn squeeze) from wherever a cut-short reaction left it.
    private func headToRest(_ duration: TimeInterval) -> SKAction {
        eased(.group([.move(to: headHome, duration: duration), .rotate(toAngle: 0, duration: duration),
                      .scaleX(to: 1.0, duration: duration)]))
    }

    /// The same for the body: both axes back to 1 (a hug or a flutter cut short).
    private func bodyToRest(_ duration: TimeInterval) -> SKAction {
        eased(.group([.scaleX(to: 1.0, duration: duration), .scaleY(to: 1.0, duration: duration)]))
    }

    /// Head, body and legs all belong to one friend: it does the small thing only that
    /// friend would do. Calm and short (about a second or two), absolute targets so any
    /// interruption still lands home. Returns how long it takes, so the bow can follow.
    private func wholeFriendSignature(_ name: String) -> TimeInterval {
        guard let head = slots[.head], let body = slots[.body] else { return 0 }
        removeAction(forKey: Self.personalityKey)
        let m = mixScale
        let home = headHome
        let cx = rootHomeX
        switch name {
        case "robot":
            // A two-step stiff dance: step right, hold, step left, hold, home. Linear,
            // robot-precise moves; the head ticks against each step.
            let step: TimeInterval = 0.12, hold: TimeInterval = 0.26
            root.run(.sequence([
                .moveTo(x: cx + 5 * m, duration: step), .wait(forDuration: hold),
                .moveTo(x: cx - 5 * m, duration: step * 2), .wait(forDuration: hold),
                .moveTo(x: cx, duration: step)
            ]), withKey: "dance")
            root.run(.sequence([
                .rotate(toAngle: -0.04, duration: step), .wait(forDuration: hold),
                .rotate(toAngle: 0.04, duration: step * 2), .wait(forDuration: hold),
                .rotate(toAngle: 0, duration: step)
            ]), withKey: "sway")
            head.run(.sequence([
                headToRest(0.1),
                .rotate(toAngle: 0.07, duration: step), .wait(forDuration: hold),
                .rotate(toAngle: -0.07, duration: step * 2), .wait(forDuration: hold),
                .rotate(toAngle: 0, duration: step)
            ]), withKey: "react")
            return step * 4 + hold * 2 + 0.1
        case "officer":
            // A proper salute (cap tips and holds, standing tall), then a slow look one
            // way and the other, as if minding the street.
            head.run(.sequence([
                headToRest(0.1),
                eased(.group([.rotate(toAngle: -0.12, duration: 0.16),
                              .move(to: CGPoint(x: home.x + 2 * m, y: home.y - 3 * m), duration: 0.16)]), .easeOut),
                .wait(forDuration: 0.36),
                eased(.group([.rotate(toAngle: 0, duration: 0.24), .move(to: home, duration: 0.24)])),
                eased(.group([.move(to: CGPoint(x: home.x - 3 * m, y: home.y), duration: 0.42),
                              .scaleX(to: 0.95, duration: 0.42), .rotate(toAngle: 0.05, duration: 0.42)])),
                .wait(forDuration: 0.16),
                eased(.group([.move(to: CGPoint(x: home.x + 3 * m, y: home.y), duration: 0.6),
                              .rotate(toAngle: -0.05, duration: 0.6)])),
                .wait(forDuration: 0.16),
                eased(.group([.move(to: home, duration: 0.4), .scaleX(to: 1.0, duration: 0.4),
                              .rotate(toAngle: 0, duration: 0.4)]))
            ]), withKey: "react")
            body.run(.sequence([
                bodyToRest(0.16), eased(.scaleY(to: 1.04, duration: 0.2)),
                .wait(forDuration: 0.3), eased(.scaleY(to: 1.0, duration: 0.3))
            ]), withKey: "react")
            return 2.5
        case "firefighter":
            // A little hop, then a big friendly wave: the whole friend rocks side to side
            // while the helmet nods along the other way.
            hop(height: 12 * m, squash: true)
            let wave: [(CGFloat, TimeInterval)] = [(0.05, 0.24), (-0.05, 0.3), (0.035, 0.26), (0, 0.26)]
            root.run(.sequence([SKAction.wait(forDuration: 0.42)] + wave.map { eased(.rotate(toAngle: $0.0, duration: $0.1)) }),
                     withKey: "sway")
            head.run(.sequence([headToRest(0.42)] + wave.map { eased(.rotate(toAngle: -$0.0 * 1.2, duration: $0.1)) }),
                     withKey: "react")
            return 1.55
        case "bunny":
            // Hop, hop, hop — three soft bunny hops, ears tipping one way then the other.
            run(.sequence([
                .run { [weak self] in self?.hop(height: 8 * m, squash: false) }, .wait(forDuration: 0.42),
                .run { [weak self] in self?.hop(height: 10 * m, squash: false) }, .wait(forDuration: 0.42),
                .run { [weak self] in self?.hop(height: 7 * m, squash: true) }
            ]), withKey: Self.personalityKey)
            head.run(.sequence([
                headToRest(0.1),
                eased(.rotate(toAngle: 0.08, duration: 0.3)), eased(.rotate(toAngle: -0.08, duration: 0.42)),
                eased(.rotate(toAngle: 0, duration: 0.4))
            ]), withKey: "react")
            return 1.3
        case "bear":
            // A big, slow bear hug: the body squeezes wide, the head snuggles down into it.
            body.run(.sequence([
                eased(.group([.scaleX(to: 1.07, duration: 0.45), .scaleY(to: 0.97, duration: 0.45)])),
                .wait(forDuration: 0.35),
                eased(.group([.scaleX(to: 1.0, duration: 0.55), .scaleY(to: 1.0, duration: 0.55)]))
            ]), withKey: "react")
            head.run(.sequence([
                headToRest(0.1),
                eased(.move(to: CGPoint(x: home.x, y: home.y - 2.5 * m), duration: 0.45)),
                .wait(forDuration: 0.35), eased(.move(to: home, duration: 0.55))
            ]), withKey: "react")
            return 1.4
        case "songbird":
            // A gentle flutter-float: three unhurried wing beats, a little rise, a soft landing.
            let flap = SKAction.sequence([.scaleX(to: 0.9, duration: 0.14), .scaleX(to: 1.08, duration: 0.16),
                                          .scaleX(to: 1.0, duration: 0.14)])
            body.run(.sequence([bodyToRest(0.08), .repeat(flap, count: 3)]), withKey: "react")
            let baseY = characterRootY
            groundRoot()
            root.run(.sequence([
                eased(.moveTo(y: baseY + 12 * m, duration: 0.55), .easeOut), .wait(forDuration: 0.2),
                eased(.moveTo(y: baseY, duration: 0.6))
            ]), withKey: "hop")
            return 1.45   // outlasts the 1.40 s flap so a bow can't catch a wing mid-beat
        case "fox":
            // A proud little tiptoe strut, one way and back, head tipped to match.
            root.run(.sequence([
                eased(.moveTo(x: cx + 7 * m, duration: 0.38)), eased(.moveTo(x: cx - 7 * m, duration: 0.62)),
                eased(.moveTo(x: cx, duration: 0.38))
            ]), withKey: "dance")
            head.run(.sequence([
                headToRest(0.1),
                eased(.rotate(toAngle: -0.1, duration: 0.38)), eased(.rotate(toAngle: 0.1, duration: 0.62)),
                eased(.rotate(toAngle: 0, duration: 0.38))
            ]), withKey: "react")
            return 1.4
        case "mouse":
            // A shy, happy wiggle: duck, peek out, a whisker-wiggle and one tiny bounce.
            head.run(.sequence([
                headToRest(0.1),
                eased(.move(to: CGPoint(x: home.x, y: home.y - 3 * m), duration: 0.18), .easeOut),
                .wait(forDuration: 0.14),
                eased(.group([.move(to: home, duration: 0.22), .rotate(toAngle: 0.1, duration: 0.22)])),
                eased(.rotate(toAngle: -0.1, duration: 0.24)), eased(.rotate(toAngle: 0.05, duration: 0.2)),
                eased(.rotate(toAngle: 0, duration: 0.2))
            ]), withKey: "react")
            run(.sequence([.wait(forDuration: 0.54), .run { [weak self] in self?.hop(height: 7 * m, squash: true) }]),
                withKey: Self.personalityKey)
            return 1.25
        case "frog":
            // One big springy leap, then a little landing bounce.
            hop(height: 24 * m, squash: true)
            run(.sequence([.wait(forDuration: 0.5), .run { [weak self] in self?.hop(height: 8 * m, squash: true) }]),
                withKey: Self.personalityKey)
            return 1.0
        default:
            return 0
        }
    }

    /// A soft warm glow that pulses behind the robot's head, as if it just powered on.
    /// It rides on the head slot (so it follows every nod) and a head flip clears it.
    private func robotGlowPulse(pulses: Int, peak: CGFloat) {
        guard let head = slots[.head] else { return }
        let glow = SKSpriteNode(texture: ProceduralTexture.softRadialGlow)
        glow.color = WarmShelfPalette.butter
        glow.colorBlendFactor = 1
        glow.blendMode = .add
        glow.size = CGSize(width: 150 * mixScale, height: 150 * mixScale)
        glow.position = CGPoint(x: 0, y: -22 * mixScale)   // the robot's face, inside the head slot
        glow.zPosition = -9                                 // behind every part band, above the room
        glow.alpha = 0
        head.addChild(glow)
        let pulse = SKAction.sequence([eased(.fadeAlpha(to: peak, duration: 0.45)),
                                       eased(.fadeAlpha(to: peak * 0.3, duration: 0.5))])
        glow.run(.sequence([.repeat(pulse, count: max(1, pulses)), .fadeOut(withDuration: 0.6), .removeFromParent()]))
    }

    private func currentPart(_ zone: MixUpZone) -> MixUpPart? {
        let parts = MixUpLibrary.parts(for: zone)
        guard !parts.isEmpty else { return nil }
        return parts[(indices[zone] ?? 0) % parts.count]
    }

    private func paperMotes(at origin: CGPoint, count: Int) {
        let colors = [WarmShelfPalette.petal, WarmShelfPalette.butter, WarmShelfPalette.waterBlue, WarmShelfPalette.sage, WarmShelfPalette.terracotta]
        for i in 0..<count {
            let bit = SKShapeNode(circleOfRadius: CGFloat.random(in: 2.5...4.5) * mixScale)
            bit.fillColor = colors[i % colors.count].withAlpha(0.9); bit.strokeColor = .clear
            bit.position = origin; bit.zPosition = 60
            addChild(bit)
            let ang = CGFloat.random(in: .pi * 0.2 ... .pi * 0.8)
            let dist = CGFloat.random(in: 50...130) * mixScale
            let rise = SKAction.moveBy(x: cos(ang) * dist, y: sin(ang) * dist, duration: 0.5); rise.timingMode = .easeOut
            let fall = SKAction.moveBy(x: cos(ang) * dist * 0.3, y: -dist - 40, duration: 0.8); fall.timingMode = .easeIn
            bit.run(.group([.sequence([rise, fall]), .sequence([.wait(forDuration: 0.7), .fadeOut(withDuration: 0.6)])]))
            bit.run(.sequence([.wait(forDuration: 1.4), .removeFromParent()]))
        }
    }

    // MARK: - Personality (the character reacts to becoming each new thing)

    /// The head dips and tilts, as if peering down to admire a freshly-changed body or legs.
    private func peerDown(by angle: CGFloat) {
        guard let head = slots[.head] else { return }
        let dip = SKAction.group([
            .rotate(toAngle: angle, duration: 0.16),
            .moveBy(x: 0, y: -4 * mixScale, duration: 0.16)
        ])
        // Return to the head's exact home (absolute) so an interrupted dip can never leave
        // the head stranded low under the body.
        let back = SKAction.group([
            .rotate(toAngle: 0, duration: 0.30),
            .move(to: CGPoint(x: 0, y: slotLocalY(.head)), duration: 0.30),
            .scaleX(to: 1.0, duration: 0.30)
        ])
        dip.timingMode = .easeOut; back.timingMode = .easeInEaseOut
        head.run(.sequence([dip, .wait(forDuration: 0.34), back]), withKey: "react")
    }

    /// The friend whose head just landed says hello with its own small move — the joke made
    /// motion. Each of the nine friends has a different one; all are gentle (small heights,
    /// unhurried timing) and use absolute targets so a quick re-flip never strands the head.
    /// Under Reduce Motion everyone gets the same slow, small acknowledging tilt.
    private func headPersonality(_ name: String) {
        guard let head = slots[.head] else { return }
        removeAction(forKey: Self.personalityKey)
        let m = mixScale
        let home = headHome
        if AmbientAnimator.reduceMotion {
            head.run(.sequence([headToRest(0.1), eased(.rotate(toAngle: 0.06, duration: 0.32)),
                                eased(.rotate(toAngle: 0, duration: 0.44))]), withKey: "react")
            return
        }
        switch name {
        case "bunny":
            // Two soft little bunny hops, the second smaller.
            run(.sequence([
                .run { [weak self] in self?.hop(height: 9 * m, squash: false) }, .wait(forDuration: 0.42),
                .run { [weak self] in self?.hop(height: 6 * m, squash: false) }
            ]), withKey: Self.personalityKey)
        case "bear":
            root.run(.sequence([                                 // a slow heavy sway
                eased(.rotate(toAngle: 0.06, duration: 0.24)), eased(.rotate(toAngle: -0.06, duration: 0.32)),
                eased(.rotate(toAngle: 0, duration: 0.24))
            ]), withKey: "sway")
        case "songbird", "bird", "duck", "owl", "penguin":
            flapWings()
        case "fox":
            // A curious sideways peek: lean out, look, lean back.
            head.run(.sequence([
                headToRest(0.1),
                eased(.group([.move(to: CGPoint(x: home.x + 4 * m, y: home.y + 1 * m), duration: 0.22),
                              .rotate(toAngle: -0.15, duration: 0.22)]), .easeOut),
                .wait(forDuration: 0.3),
                eased(.group([.move(to: home, duration: 0.32), .rotate(toAngle: 0, duration: 0.32)]))
            ]), withKey: "react")
        case "mouse":
            // A shy little duck, then a peek up and a whisker-twitch.
            head.run(.sequence([
                headToRest(0.1),
                eased(.move(to: CGPoint(x: home.x, y: home.y - 4 * m), duration: 0.16), .easeOut),
                .wait(forDuration: 0.16),
                eased(.move(to: CGPoint(x: home.x, y: home.y + 2 * m), duration: 0.2)),
                .rotate(toAngle: 0.07, duration: 0.09), .rotate(toAngle: -0.07, duration: 0.12),
                .rotate(toAngle: 0, duration: 0.1),
                eased(.move(to: home, duration: 0.22))
            ]), withKey: "react")
        case "frog":
            hop(height: 22 * m, squash: true)                    // a springy leap
        case "robot":
            let j: CGFloat = 3 * m
            head.run(.sequence([                                 // a stiff little glitch-stutter
                headToRest(0.1),
                .moveBy(x: j, y: 0, duration: 0.03), .moveBy(x: -2 * j, y: 0, duration: 0.04),
                .moveBy(x: 2 * j, y: 0, duration: 0.04), .moveBy(x: -j, y: 0, duration: 0.03),
                .move(to: home, duration: 0.04)
            ]), withKey: "react")
        case "officer":
            // A small salute: the cap tips, holds a beat, and the officer stands up tall.
            head.run(.sequence([
                headToRest(0.1),
                eased(.group([.rotate(toAngle: -0.11, duration: 0.16),
                              .move(to: CGPoint(x: home.x + 2 * m, y: home.y - 3 * m), duration: 0.16)]), .easeOut),
                .wait(forDuration: 0.3),
                eased(.group([.rotate(toAngle: 0, duration: 0.24),
                              .move(to: CGPoint(x: home.x, y: home.y + 2 * m), duration: 0.24)])),
                eased(.move(to: home, duration: 0.26))
            ]), withKey: "react")
            slots[.body]?.run(.sequence([
                bodyToRest(0.1), .wait(forDuration: 0.36),
                eased(.scaleY(to: 1.04, duration: 0.2)), eased(.scaleY(to: 1.0, duration: 0.3))
            ]), withKey: "react")
        case "firefighter":
            // Two helmet nods ("ready!") and a small hop.
            head.run(.sequence([
                headToRest(0.1),
                eased(.move(to: CGPoint(x: home.x, y: home.y - 4 * m), duration: 0.12), .easeOut),
                eased(.move(to: home, duration: 0.16)),
                eased(.move(to: CGPoint(x: home.x, y: home.y - 3 * m), duration: 0.12), .easeOut),
                eased(.move(to: home, duration: 0.16))
            ]), withKey: "react")
            run(.sequence([.wait(forDuration: 0.56), .run { [weak self] in self?.hop(height: 10 * m, squash: true) }]),
                withKey: Self.personalityKey)
        // Procedural-era heads (fallback pools only).
        case "lion":
            let shake = SKAction.sequence([
                .rotate(toAngle: 0.12, duration: 0.06), .rotate(toAngle: -0.12, duration: 0.08),
                .rotate(toAngle: 0.07, duration: 0.06), .rotate(toAngle: 0, duration: 0.06)
            ])
            head.run(shake, withKey: "react")                   // a tiny roar, mane and all
            head.run(.sequence([.scale(to: 1.14, duration: 0.10), .scale(to: 1.0, duration: 0.16)]))
        case "cat":
            head.run(.sequence([                                 // a coy, curious tilt
                .rotate(toAngle: 0.20, duration: 0.14), .wait(forDuration: 0.20), .rotate(toAngle: 0, duration: 0.24)
            ]), withKey: "react")
        case "king", "queen":
            head.run(.sequence([                                 // a proud chin-up
                .moveBy(x: 0, y: 5 * mixScale, duration: 0.18), .wait(forDuration: 0.20), .moveBy(x: 0, y: -5 * mixScale, duration: 0.30)
            ]), withKey: "react")
        case "zebra":
            root.run(.sequence([                                 // a proud strut sway
                .rotate(toAngle: 0.07, duration: 0.10), .rotate(toAngle: -0.07, duration: 0.12),
                .rotate(toAngle: 0.04, duration: 0.08), .rotate(toAngle: 0, duration: 0.14)
            ]), withKey: "sway")
            hop(height: 14 * mixScale, squash: false)
        case "pig":
            head.run(.sequence([                                 // a happy snorting wriggle
                .rotate(toAngle: 0.16, duration: 0.09), .rotate(toAngle: -0.12, duration: 0.10),
                .rotate(toAngle: 0.07, duration: 0.08), .rotate(toAngle: 0, duration: 0.12)
            ]), withKey: "react")
            hop(height: 20 * mixScale, squash: true)
        case "dog":
            root.run(.sequence([                                 // excited tail-wag whole-body wiggle
                .rotate(toAngle: 0.09, duration: 0.07), .rotate(toAngle: -0.09, duration: 0.07),
                .rotate(toAngle: 0.07, duration: 0.06), .rotate(toAngle: -0.07, duration: 0.06),
                .rotate(toAngle: 0, duration: 0.10)
            ]), withKey: "sway")
            hop(height: 22 * mixScale, squash: true)
        default:
            hop(height: 14 * mixScale, squash: false)            // a happy little bounce
        }
    }

    /// Back on the floor (a snap, as hops always did) and gliding back to centre: an idle
    /// side-sway or a whole-friend strut cut short would otherwise leave it off-centre.
    private func groundRoot() {
        root.removeAction(forKey: "hop")
        root.position.y = characterRootY
        if abs(root.position.x - rootHomeX) > 0.5 {
            root.run(eased(.moveTo(x: rootHomeX, duration: 0.2)), withKey: "dance")
        }
    }

    private func hop(height: CGFloat, squash: Bool) {
        // Absolute moves (not relative) and a hard reset to the grounded baseline first, so stacked
        // celebrations can never leave the character drifting in the air — it always lands home.
        let baseY = characterRootY
        groundRoot()
        let up = SKAction.moveTo(y: baseY + height, duration: 0.16); up.timingMode = .easeOut
        let down = SKAction.moveTo(y: baseY, duration: 0.24); down.timingMode = .easeIn
        if squash, let body = slots[.body] {
            body.run(.sequence([.scaleY(to: 0.88, duration: 0.08), .scaleY(to: 1.06, duration: 0.12), .scaleY(to: 1.0, duration: 0.12)]))
        }
        root.run(.sequence([up, down]), withKey: "hop")
    }

    private func flapWings() {
        guard let body = slots[.body] else { return }
        let flap = SKAction.sequence([.scaleX(to: 0.86, duration: 0.10), .scaleX(to: 1.10, duration: 0.12), .scaleX(to: 1.0, duration: 0.10)])
        body.run(.sequence([bodyToRest(0.06), .repeat(flap, count: 2)]), withKey: "react")
        hop(height: 10 * mixScale, squash: false)
    }

    private func showOffBody() {
        guard let body = slots[.body] else { return }
        body.run(.sequence([.scale(to: 1.10, duration: 0.12), .scale(to: 1.0, duration: 0.18)]), withKey: "react")
        root.run(.sequence([
            .rotate(toAngle: 0.05, duration: 0.12), .rotate(toAngle: -0.05, duration: 0.14), .rotate(toAngle: 0, duration: 0.12)
        ]), withKey: "sway")
    }

    private func showOffLegs() {
        guard let legs = slots[.legs] else { return }
        // Try the new feet: quick shuffle, then exhale back — settle (0.20s) > shuffle steps (0.08s).
        let scaleOut = SKAction.scaleX(to: 1.10, duration: 0.08); scaleOut.timingMode = .easeOut
        let scaleIn = SKAction.scaleX(to: 0.92, duration: 0.08)
        let land = SKAction.scaleX(to: 1.0, duration: 0.20); land.timingMode = .easeInEaseOut
        legs.run(.sequence([scaleOut, scaleIn, land]), withKey: "react")
        hop(height: 16 * mixScale, squash: false)
    }

    /// When left alone, the character has a quiet life of its own: a curious tilt, a model
    /// sway showing off the outfit, or admiring itself — never the same beat twice in a row.
    private func idleShowOff() {
        guard let head = slots[.head] else { return }
        // Now and then (about one idle beat in five) the friend wearing the head does its
        // own tiny habit instead. Reduce Motion keeps only the shared, gentler beats.
        if !AmbientAnimator.reduceMotion, Int.random(in: 0..<5) == 0, idleQuirk(currentPartName(.head)) { return }
        switch Int.random(in: 0..<5) {
        case 0:
            head.run(.sequence([.rotate(toAngle: CGFloat.random(in: -0.12...0.12), duration: 0.4), .wait(forDuration: 0.7), .rotate(toAngle: 0, duration: 0.4)]), withKey: "react")
        case 1:
            root.run(.sequence([.moveBy(x: 0, y: 6 * mixScale, duration: 0.5), .moveBy(x: 0, y: -6 * mixScale, duration: 0.5)]), withKey: "hop")
        case 2:
            root.run(.sequence([   // absolute, so it always ends centred
                .moveTo(x: rootHomeX + 8 * mixScale, duration: 0.5), .moveTo(x: rootHomeX - 8 * mixScale, duration: 0.7),
                .moveTo(x: rootHomeX, duration: 0.5)
            ]), withKey: "hop")
        case 3:
            peerDown(by: -0.14)
            root.run(.sequence([.wait(forDuration: 0.9), .moveBy(x: 0, y: 8 * mixScale, duration: 0.14), .moveBy(x: 0, y: -8 * mixScale, duration: 0.22)]), withKey: "hop")
        default:
            root.run(.sequence([.rotate(toAngle: 0.05, duration: 0.16), .rotate(toAngle: -0.05, duration: 0.2), .rotate(toAngle: 0, duration: 0.16)]), withKey: "sway")
        }
    }

    /// A rare, tiny habit of whoever's head is on — small enough to be noticed only by a
    /// child who is watching. Returns false for heads without one.
    private func idleQuirk(_ name: String) -> Bool {
        guard let head = slots[.head], let body = slots[.body] else { return false }
        let m = mixScale
        let home = headHome
        switch name {
        case "robot":       // a quiet blink of its lights and one stiff head tick
            robotGlowPulse(pulses: 1, peak: 0.35)
            head.run(.sequence([headToRest(0.1), .rotate(toAngle: 0.05, duration: 0.08), .wait(forDuration: 0.4),
                                .rotate(toAngle: 0, duration: 0.08)]), withKey: "react")
        case "officer":     // touches the cap brim
            head.run(.sequence([headToRest(0.1), eased(.rotate(toAngle: -0.07, duration: 0.22)), .wait(forDuration: 0.3),
                                eased(.rotate(toAngle: 0, duration: 0.3))]), withKey: "react")
        case "firefighter": // one slow helmet nod
            head.run(.sequence([headToRest(0.1), eased(.move(to: CGPoint(x: home.x, y: home.y - 3 * m), duration: 0.26)),
                                eased(.move(to: home, duration: 0.36))]), withKey: "react")
        case "bunny":       // an ear flick, twice
            let flick = SKAction.sequence([.rotate(toAngle: 0.04, duration: 0.09), .rotate(toAngle: 0, duration: 0.15)])
            head.run(.sequence([headToRest(0.1), flick, .wait(forDuration: 0.12), flick]), withKey: "react")
        case "bear":        // a slow, sleepy stretch
            head.run(.sequence([headToRest(0.1), eased(.move(to: CGPoint(x: home.x, y: home.y + 3 * m), duration: 0.7)),
                                .wait(forDuration: 0.3), eased(.move(to: home, duration: 0.8))]), withKey: "react")
        case "songbird":    // one small wing ruffle
            body.run(.sequence([bodyToRest(0.08), .scaleX(to: 0.95, duration: 0.14), .scaleX(to: 1.04, duration: 0.14),
                                .scaleX(to: 1.0, duration: 0.16)]), withKey: "react")
        case "fox":         // two little sniffs
            let sniff = SKAction.sequence([.move(to: CGPoint(x: home.x, y: home.y + 1.5 * m), duration: 0.12),
                                           .move(to: home, duration: 0.14)])
            head.run(.sequence([headToRest(0.1), sniff, sniff]), withKey: "react")
        case "mouse":       // a whisker twitch
            head.run(.sequence([headToRest(0.1), .rotate(toAngle: 0.05, duration: 0.08), .rotate(toAngle: -0.05, duration: 0.1),
                                .rotate(toAngle: 0, duration: 0.1)]), withKey: "react")
        case "frog":        // a tiny bounce on the spot
            let baseY = characterRootY
            groundRoot()
            root.run(.sequence([eased(.moveTo(y: baseY + 4 * m, duration: 0.2), .easeOut),
                                eased(.moveTo(y: baseY, duration: 0.26), .easeIn)]), withKey: "hop")
        default:
            return false
        }
        return true
    }

    // MARK: - Idle life

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        let delta = lastUpdate == 0 ? 0 : currentTime - lastUpdate
        lastUpdate = currentTime
        idleAccumulator += delta
        if idleAccumulator > 5.0 {
            idleAccumulator = 0
            guard flipping.isEmpty, root.action(forKey: "hop") == nil,
                  action(forKey: Self.wholeFriendKey) == nil,
                  action(forKey: Self.wholeFriendShowKey) == nil else { return }
            idleShowOff()
        }
    }

    override func accessibilityElements(in view: SKView) -> [UIAccessibilityElement] {
        var elements = super.accessibilityElements(in: view)
        for zone in MixUpZone.allCases {
            let name = MixUpLibrary.friendlyName(currentPart(zone)?.name ?? "")
            let label: String
            switch zone {
            case .head: label = "head: \(name), tap to change"
            case .body: label = "body: \(name), tap to change"
            case .legs: label = "legs: \(name), tap to change"
            }
            let scenePos = controlPosition(for: zone)
            elements.append(makeActivatableAccessibilityElement(
                in: view,
                label: label,
                scenePosition: scenePos,
                size: CGSize(width: controlTouchRadius * 2, height: controlTouchRadius * 2),
                traits: .button
            ) { [weak self] in
                self?.flip(zone, forward: true)
            })
        }
        for (index, entry) in creationFrames.enumerated() {
            elements.append(makeActivatableAccessibilityElement(
                in: view, label: "Saved look \(index + 1), bring it back",
                scenePosition: entry.node.convert(CGPoint.zero, to: self),
                size: miniFrameSize, traits: .button
            ) { [weak self, weak frame = entry.node] in
                guard let frame else { return }
                self?.applyCreation(entry.recipe, from: frame)
            })
        }
        if keepsakeButton.parent != nil {
            elements.append(makeActivatableAccessibilityElement(
                in: view,
                label: "Keep this look — frame it on the wall",
                scenePosition: keepsakeButton.position,
                size: CGSize(width: 76, height: 76),
                traits: .button
            ) { [weak self] in
                self?.saveKeepsake()
            })
        }
        return elements
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
