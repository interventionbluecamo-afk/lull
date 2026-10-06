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
    private var theaterValanceHeight: CGFloat = 0   // creations ledge clears the curtain top
    private var lastBowedMatch: String?             // the bow fires once per match, re-armed when it breaks
    private weak var stageLightPool: SKShapeNode?

    /// Scale off available *height* (not min dimension) so the character fills a tall
    /// portrait canvas but never overflows the short landscape one.
    private var mixScale: CGFloat {
        let landscape = size.width > size.height
        return (size.height / (landscape ? 380 : 490)).clamped(to: 0.9...2.6)
    }
    private var floorY: CGFloat { size.height * (size.width > size.height ? 0.24 : 0.31) }
    private var characterRootY: CGFloat { floorY + 76 * mixScale }   // sits lower, feet planted on the floor
    private var roomDecorScale: CGFloat { mixScale.clamped(to: 0.9...1.55) }

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

        let r = 23 * roomDecorScale
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
            let safe = view?.safeAreaInsets ?? .zero
            let landscape = size.width > size.height
            keepsakeButton.position = CGPoint(
                x: size.width - safe.right - (landscape ? 56 : 44) - r,
                y: floorY * (landscape ? 0.52 : 0.46)
            )
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

        let safe = view?.safeAreaInsets ?? .zero
        let landscape = size.width > size.height
        let x = size.width - safe.right - (landscape ? 56 : 44) - r
        let y = floorY * (landscape ? 0.52 : 0.46)
        keepsakeButton.position = CGPoint(x: x, y: y)

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
        let radius = 42 * roomDecorScale
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
        let innerW = miniFrameSize.width * 0.82
        let innerH = miniFrameSize.height * 0.82
        let texSize = texture.size()
        let fit = min(innerW / max(1, texSize.width), innerH / max(1, texSize.height))

        let recipe = currentRecipe()
        let newCount = min(MixUpCreationStore.load().count + 1, creationDisplayCapacity)
        let slots = shelfSlotPositions(count: newCount)
        let target = CGPoint(x: ledge.position.x + (slots.last?.x ?? 0), y: ledge.position.y)

        let flying = SKSpriteNode(texture: texture)
        flying.position = root.position
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
        static let capacity = 6
        static func load() -> [MixUpCreation] {
            guard let data = UserDefaults.standard.data(forKey: key),
                  let list = try? JSONDecoder().decode([MixUpCreation].self, from: data) else { return [] }
            return list
        }
        static func append(_ creation: MixUpCreation) {
            var list = load()
            list.append(creation)
            if list.count > capacity { list.removeFirst(list.count - capacity) }
            if let data = try? JSONEncoder().encode(list) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }

    private func currentRecipe() -> MixUpCreation {
        MixUpCreation(head: indices[.head] ?? 0, body: indices[.body] ?? 0, legs: indices[.legs] ?? 0)
    }

    private var miniFrameBaseWidth: CGFloat { min(58 * roomDecorScale, size.width * 0.13) }

    /// How many saved looks fit on this device's wall (the store keeps up to 6; we show the newest).
    private var creationDisplayCapacity: Int {
        let usable = size.width - 170   // clear of the home pebble and side margins
        return max(2, min(MixUpCreationStore.capacity, Int(usable / (miniFrameBaseWidth + 14))))
    }

    private func shelfSlotPositions(count: Int) -> [CGPoint] {
        let spacing = miniFrameSize.width + 14
        let total = CGFloat(max(0, count - 1)) * spacing
        return (0..<max(1, count)).map { CGPoint(x: -total / 2 + CGFloat($0) * spacing, y: 0) }
    }

    /// A wooden ledge high on the wall holding the child's saved creations — a quiet library of
    /// looks they made. The portraits are STATIC minis rebuilt from their recipes (true persistence,
    /// no images), so the live character below always stays the hero.
    private func buildCreationsShelf() {
        creationsLedge?.removeFromParent()
        creationFrames.removeAll()

        let frameW = miniFrameBaseWidth
        let frameH = frameW * 1.18
        miniFrameSize = CGSize(width: frameW, height: frameH)

        let ledge = SKNode()
        ledge.position = CGPoint(x: size.width / 2 + 20, y: safePlayRect().maxY - theaterValanceHeight - frameH * 0.55)
        ledge.zPosition = 1.18
        stage.addChild(ledge)
        creationsLedge = ledge

        let creations = Array(MixUpCreationStore.load().suffix(creationDisplayCapacity))
        let positions = shelfSlotPositions(count: max(1, creations.count))

        // The wooden board under the row — sized to its contents, with a little room to grow.
        let rowW = max(frameW * 2.2, (positions.last?.x ?? 0) - (positions.first?.x ?? 0) + frameW * 1.6)
        let board = SKShapeNode(rect: CGRect(x: -rowW / 2, y: -frameH * 0.6, width: rowW, height: 9 * roomDecorScale), cornerRadius: 4.5 * roomDecorScale)
        board.fillColor = WarmShelfPalette.sand.withAlpha(0.8)
        board.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.14)
        board.lineWidth = 1
        board.zPosition = 0
        ledge.addChild(board)
        let boardHi = SKShapeNode(rect: CGRect(x: -rowW / 2 + 4, y: -frameH * 0.6 + 6 * roomDecorScale, width: rowW - 8, height: 2), cornerRadius: 1)
        boardHi.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.4)
        boardHi.strokeColor = .clear
        boardHi.zPosition = 0.05
        ledge.addChild(boardHi)

        for (i, recipe) in creations.enumerated() {
            let frame = makeCreationFrame(recipe: recipe)
            frame.position = positions[i]
            frame.alpha = 0
            ledge.addChild(frame)
            frame.run(.sequence([.wait(forDuration: Double(i) * 0.05), .fadeIn(withDuration: 0.22)]))
            creationFrames.append((node: frame, recipe: recipe))
        }
    }

    /// One framed portrait: a static mini of the saved look, rebuilt from its 3-part recipe.
    private func makeCreationFrame(recipe: MixUpCreation) -> SKNode {
        let node = SKNode()
        let mat = SKShapeNode(
            rect: CGRect(x: -miniFrameSize.width / 2, y: -miniFrameSize.height / 2,
                         width: miniFrameSize.width, height: miniFrameSize.height),
            cornerRadius: 6
        )
        mat.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.96)
        mat.strokeColor = WarmShelfPalette.sand.withAlpha(0.55)
        mat.lineWidth = 2
        mat.zPosition = 1.5
        node.addChild(mat)

        let mini = SKNode()
        let s = miniFrameSize.height * 0.82 / 340   // a full character spans ~340 units at scale 1
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
        mini.position = CGPoint(x: 0, y: -miniFrameSize.height * 0.04)
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
        for (zone, rawIndex) in target {
            let parts = MixUpLibrary.parts(for: zone)
            guard !parts.isEmpty else { continue }
            let idx = ((rawIndex % parts.count) + parts.count) % parts.count
            guard indices[zone] != idx, !flipping.contains(zone), let slot = slots[zone] else { continue }
            changedAny = true
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
            transformationFlourish(zone: .body)
            AudioManager.shared.playMixFlip()
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

    private func addRoom() {
        let decorScale = roomDecorScale
        theaterValanceHeight = 0

        // The authored theater (Docs/MixUpSlice.md): room plate, round stage, red curtains.
        if let roomTex = ToyArt.texture("mixup-room") {
            buildTheaterRoom(roomTex, decorScale: decorScale)
            return
        }

        // A confident two-tone wall: one warm wash + a soft glow pooled behind the character.
        // (The old ghost-alpha wall patches and shelf furniture read as smudges — removed; the
        // creations ledge above is the wall's one piece of furniture now.)
        let wall = SKShapeNode(rect: CGRect(x: 0, y: floorY, width: size.width, height: size.height - floorY))
        wall.fillColor = WarmShelfPalette.warmCream.withAlpha(0.42); wall.strokeColor = .clear; wall.zPosition = 1
        stage.addChild(wall)

        let wallGlow = SKShapeNode(ellipseOf: CGSize(width: size.width * 0.95, height: (size.height - floorY) * 1.1))
        wallGlow.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.22)
        wallGlow.strokeColor = .clear
        wallGlow.position = CGPoint(x: size.width / 2, y: floorY + (size.height - floorY) * 0.42)
        wallGlow.zPosition = 1.02
        stage.addChild(wallGlow)

        // Gentle wallpaper dots: enough pattern to say "room", quiet enough to stay sleepy.
        var dy = floorY + 50 * decorScale; var even = true
        while dy < size.height - 20 {
            var dx: CGFloat = even ? 34 * decorScale : 70 * decorScale
            while dx < size.width - 14 {
                let dot = SKShapeNode(circleOfRadius: 2.4 * decorScale)
                dot.fillColor = WarmShelfPalette.sand.withAlpha(0.13)
                dot.strokeColor = .clear
                dot.position = CGPoint(x: dx, y: dy); dot.zPosition = 1.1; stage.addChild(dot); dx += 72 * decorScale
            }
            dy += 72 * decorScale; even.toggle()
        }

        let floor = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.width, height: floorY))
        floor.fillColor = WarmShelfPalette.sand.withAlpha(0.36); floor.strokeColor = .clear; floor.zPosition = 2
        stage.addChild(floor)

        var plankY = max(22 * decorScale, floorY * 0.16)
        while plankY < floorY - 18 * decorScale {
            let line = SKShapeNode(rect: CGRect(x: 0, y: plankY, width: size.width, height: max(1, decorScale)), cornerRadius: 0.5 * decorScale)
            line.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.075)
            line.strokeColor = .clear
            line.zPosition = 2.05
            stage.addChild(line)
            plankY += 34 * decorScale
        }

        let baseboard = SKShapeNode(rect: CGRect(x: 0, y: floorY - 4, width: size.width, height: 8))
        baseboard.fillColor = WarmShelfPalette.cocoa.withAlpha(0.12); baseboard.strokeColor = .clear; baseboard.zPosition = 2.1; stage.addChild(baseboard)
        let baseboardHighlight = SKShapeNode(rect: CGRect(x: 0, y: floorY + 3, width: size.width, height: 2))
        baseboardHighlight.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.18); baseboardHighlight.strokeColor = .clear; baseboardHighlight.zPosition = 2.12; stage.addChild(baseboardHighlight)

        // The creations shelf is the wall's one piece of furniture (it was stranded inside the
        // removed decor pass — restoring it restores the heart-save feature).
        buildCreationsShelf()

        // A real rug with conviction — big, warm, two-ring, properly under the character. It's the
        // room's anchor (the doll stands ON something), not a faint smudge.
        let rugY = floorY - 8 * mixScale
        let rugW = min(size.width * 0.8, 470 * decorScale)
        let rugH = 86 * decorScale
        let rug = SKShapeNode(ellipseOf: CGSize(width: rugW, height: rugH))
        rug.fillColor = WarmShelfPalette.terracotta.withAlpha(0.26)
        rug.strokeColor = WarmShelfPalette.terracotta.withAlpha(0.4)
        rug.lineWidth = 3.5
        rug.position = CGPoint(x: size.width / 2, y: rugY); rug.zPosition = 2.4; stage.addChild(rug)
        let rugInner = SKShapeNode(ellipseOf: CGSize(width: rugW * 0.7, height: rugH * 0.66))
        rugInner.fillColor = WarmShelfPalette.warmCream.withAlpha(0.2)
        rugInner.strokeColor = WarmShelfPalette.paperHighlight.withAlpha(0.3)
        rugInner.lineWidth = 2
        rugInner.zPosition = 0.1
        rug.addChild(rugInner)

        // A baked soft contact shadow under the feet, separate from the character squash.
        let shadowSize = CGSize(width: 150 * decorScale, height: 30 * decorScale)
        let footShadow = SKSpriteNode(texture: ProceduralTexture.softClayShadow(size: shadowSize))
        footShadow.size = shadowSize
        footShadow.alpha = 0.9
        footShadow.position = CGPoint(x: size.width / 2, y: floorY - 1 * decorScale)
        footShadow.zPosition = 2.55
        stage.addChild(footShadow)

        // A single quiet window — context without competition. The character is the scene.
        addWindow()
    }

    /// The dress-up theater: warm wooden room plate, a round stage under the performer,
    /// a soft spotlight pool, and red curtains framing the proscenium. The creations
    /// shelf (the keepsake wall) stays — it is the toy's heart.
    private func buildTheaterRoom(_ roomTex: SKTexture, decorScale: CGFloat) {
        let ts = roomTex.size()
        let plate = SKSpriteNode(texture: roomTex)
        let cover = max(size.width / max(1, ts.width), size.height / max(1, ts.height)) * 1.08
        plate.size = CGSize(width: ts.width * cover, height: ts.height * cover)
        plate.position = CGPoint(x: size.width / 2, y: size.height / 2)
        plate.zPosition = 1
        stage.addChild(plate)

        // The round wooden stage the performer stands on.
        if let platform = ToyArt.sprite("mixup-stage", fit: CGSize(width: min(size.width * 0.82, 500 * decorScale), height: 240 * decorScale)) {
            platform.position = CGPoint(x: size.width / 2, y: floorY - platform.size.height * 0.30)
            platform.zPosition = 2.4
            stage.addChild(platform)
            // A quiet pool of warm light on its top face.
            let pool = SKShapeNode(ellipseOf: CGSize(width: platform.size.width * 0.74, height: platform.size.height * 0.4))
            pool.fillColor = WarmShelfPalette.butter.withAlpha(0.2)
            pool.strokeColor = .clear
            pool.blendMode = .add
            pool.position = CGPoint(x: size.width / 2, y: floorY - 4 * decorScale)
            pool.zPosition = 2.45
            stage.addChild(pool)
            stageLightPool = pool
        }

        // Proscenium: valance across the top, swags at the sides — framing, never covering.
        if let valance = ToyArt.texture("mixup-curtain-valance") {
            let v = SKSpriteNode(texture: valance)
            let vScale = (size.width * 1.05) / max(1, valance.size().width)
            v.size = CGSize(width: valance.size().width * vScale, height: valance.size().height * vScale)
            v.anchorPoint = CGPoint(x: 0.5, y: 1)
            v.position = CGPoint(x: size.width / 2, y: size.height + 2)
            v.zPosition = 12
            stage.addChild(v)
            theaterValanceHeight = v.size.height   // the creations ledge ducks below it
        }
        for (slot, side) in [("mixup-curtain-swag-left", CGFloat(-1)), ("mixup-curtain-swag-right", CGFloat(1))] {
            guard let swag = ToyArt.sprite(slot, fit: CGSize(width: size.width * 0.30, height: (size.height - floorY) * 0.92)) else { continue }
            swag.anchorPoint = CGPoint(x: 0.5, y: 1)
            swag.position = CGPoint(x: size.width / 2 + side * (size.width / 2 - swag.size.width * 0.30), y: size.height + 2)
            swag.zPosition = 12
            stage.addChild(swag)
        }

        // The keepsake wall and the grounding shadow stay exactly as they are.
        buildCreationsShelf()
        let shadowSize = CGSize(width: 150 * decorScale, height: 30 * decorScale)
        let footShadow = SKSpriteNode(texture: ProceduralTexture.softClayShadow(size: shadowSize))
        footShadow.size = shadowSize
        footShadow.alpha = 0.9
        footShadow.position = CGPoint(x: size.width / 2, y: floorY - 1 * decorScale)
        footShadow.zPosition = 2.55
        stage.addChild(footShadow)
    }

    private func addQuietPlayroomDetails(decorScale: CGFloat) {
        guard size.width > 260, size.height > 260 else { return }

        let wallHeight = max(1, size.height - floorY)
        let shelfY = floorY + wallHeight * (size.width > size.height ? 0.42 : 0.34)
        let shelfX = size.width * (size.width > size.height ? 0.16 : 0.20)
        let shelfW = min(size.width * 0.32, 178 * decorScale)

        let shelfShadow = SKShapeNode(
            ellipseOf: CGSize(width: shelfW * 0.92, height: 10 * decorScale)
        )
        shelfShadow.fillColor = WarmShelfPalette.contactShadow.withAlpha(0.045)
        shelfShadow.strokeColor = .clear
        shelfShadow.position = CGPoint(x: shelfX, y: shelfY - 13 * decorScale)
        shelfShadow.zPosition = 1.18
        stage.addChild(shelfShadow)

        let shelf = SKShapeNode(
            rect: CGRect(x: -shelfW / 2, y: -4 * decorScale, width: shelfW, height: 8 * decorScale),
            cornerRadius: 4 * decorScale
        )
        shelf.fillColor = WarmShelfPalette.sand.withAlpha(0.34)
        shelf.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.08)
        shelf.lineWidth = 1
        shelf.position = CGPoint(x: shelfX, y: shelfY)
        shelf.zPosition = 1.22
        stage.addChild(shelf)

        let blockColors = [
            WarmShelfPalette.sage.withAlpha(0.20),
            WarmShelfPalette.butter.withAlpha(0.20),
            WarmShelfPalette.waterBlue.withAlpha(0.18)
        ]
        let blockRotations: [CGFloat] = [-0.06, 0.04, -0.03]
        for index in 0..<3 {
            let block = SKShapeNode(
                rect: CGRect(x: -11 * decorScale, y: -1 * decorScale, width: 22 * decorScale, height: 22 * decorScale),
                cornerRadius: 6 * decorScale
            )
            block.fillColor = blockColors[index]
            block.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.035)
            block.lineWidth = 1
            block.position = CGPoint(x: shelfX - 46 * decorScale + CGFloat(index) * 32 * decorScale, y: shelfY + 16 * decorScale)
            block.zRotation = blockRotations[index]
            block.zPosition = 1.26
            stage.addChild(block)
            ProceduralTexture.addMatteClayDepth(
                to: block,
                in: CGRect(x: -11 * decorScale, y: -1 * decorScale, width: 22 * decorScale, height: 22 * decorScale),
                cornerRadius: 6 * decorScale,
                zPosition: 0.1,
                highlightAlpha: 0.06,
                shadeAlpha: 0.012,
                rimAlpha: 0.010,
                speckleCount: 0
            )
        }

        // The creations shelf: a wooden ledge high on the wall holding the child's saved looks.
        buildCreationsShelf()
    }

    /// One quiet window on the upper wall, showing the same sky the rest of the app
    /// breathes with — dawn, midday, dusk, night, on the family's own wind-down clock.
    /// Context without competition: the character stays the hero. (This replaces an
    /// earlier busy dressing-room — wardrobe + mirror + framed art — that pulled focus.)
    private func addWindow() {
        let landscape = size.width > size.height
        let paneW = min(96 * mixScale, size.width * 0.22)
        let paneH = min(124 * mixScale, size.height * 0.20)
        let cx = size.width * (landscape ? 0.84 : 0.77)
        let cy = size.height * (landscape ? 0.74 : 0.83)
        let sky = TimeOfDay.sky
        let frameInset = 9 * mixScale

        // Painted-wood frame.
        let outer = SKShapeNode(rect: CGRect(x: -paneW / 2 - frameInset, y: -paneH / 2 - frameInset, width: paneW + frameInset * 2, height: paneH + frameInset * 2), cornerRadius: 9 * mixScale)
        outer.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.95)
        outer.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.16); outer.lineWidth = 2
        outer.position = CGPoint(x: cx, y: cy); outer.zPosition = 1.4
        stage.addChild(outer)

        // Sky pane, clipped so the cloud can drift off-edge.
        let crop = SKCropNode()
        let mask = SKShapeNode(rect: CGRect(x: -paneW / 2, y: -paneH / 2, width: paneW, height: paneH), cornerRadius: 4 * mixScale)
        mask.fillColor = .white; mask.strokeColor = .clear
        crop.maskNode = mask; crop.zPosition = 0.1
        outer.addChild(crop)

        let skyNode = SKSpriteNode(texture: TimeOfDay.gradientTexture(size: CGSize(width: paneW, height: paneH), top: sky.top, bottom: sky.bottom))
        skyNode.size = CGSize(width: paneW, height: paneH)
        crop.addChild(skyNode)

        // Sun or moon, placed where the app's sky puts it that hour.
        let orbR = 12 * mixScale
        let orbPos = CGPoint(x: -paneW / 2 + paneW * sky.orbX, y: -paneH / 2 + paneH * (0.34 + 0.52 * sky.orbHeight))
        let glow = SKShapeNode(circleOfRadius: orbR * 1.9)
        glow.fillColor = sky.orbGlow.withAlpha(0.45); glow.strokeColor = .clear
        glow.position = orbPos; glow.zPosition = 0.2; crop.addChild(glow)
        if !AmbientAnimator.reduceMotion {
            glow.run(.repeatForever(.sequence([.fadeAlpha(to: 0.26, duration: 2.6), .fadeAlpha(to: 0.5, duration: 2.6)])))
        }
        let orb = SKShapeNode(circleOfRadius: orbR)
        orb.fillColor = sky.orb; orb.strokeColor = .clear
        orb.position = orbPos; orb.zPosition = 0.3; crop.addChild(orb)

        if sky.starAlpha > 0 {
            for _ in 0..<7 {
                let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.8...1.6) * mixScale)
                star.fillColor = UIColor.white.withAlpha(sky.starAlpha * CGFloat.random(in: 0.5...1.0)); star.strokeColor = .clear
                star.position = CGPoint(x: .random(in: -paneW / 2 + 6...paneW / 2 - 6), y: .random(in: -paneH * 0.1...paneH / 2 - 6))
                star.zPosition = 0.25; crop.addChild(star)
                if !AmbientAnimator.reduceMotion {
                    star.run(.repeatForever(.sequence([.fadeAlpha(to: 0.2, duration: .random(in: 1.4...2.6)), .fadeAlpha(to: 1.0, duration: .random(in: 1.4...2.6))])))
                }
            }
        } else {
            // One soft cloud drifts slowly across the pane.
            let cloud = SKNode()
            let puffA = SKShapeNode(ellipseOf: CGSize(width: 32 * mixScale, height: 15 * mixScale)); puffA.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.85); puffA.strokeColor = .clear
            let puffB = SKShapeNode(ellipseOf: CGSize(width: 21 * mixScale, height: 12 * mixScale)); puffB.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.8); puffB.strokeColor = .clear; puffB.position = CGPoint(x: 11 * mixScale, y: 3 * mixScale)
            cloud.addChild(puffA); cloud.addChild(puffB)
            let cloudStartX = -paneW / 2 - 24 * mixScale
            cloud.zPosition = 0.28; cloud.position = CGPoint(x: cloudStartX, y: paneH * 0.2); crop.addChild(cloud)
            if AmbientAnimator.reduceMotion {
                cloud.position.x = 0
            } else {
                let drift = SKAction.moveBy(x: paneW + 48 * mixScale, y: 0, duration: 30)
                let reset = SKAction.run { cloud.position = CGPoint(x: cloudStartX, y: CGFloat.random(in: paneH * 0.02...paneH * 0.30)) }
                cloud.run(.repeatForever(.sequence([drift, reset])))
            }
        }

        // Muntin bars — reads instantly as a window.
        let barColor = WarmShelfPalette.paperHighlight.withAlpha(0.96)
        let vBar = SKShapeNode(rect: CGRect(x: -1.6 * mixScale, y: -paneH / 2, width: 3.2 * mixScale, height: paneH)); vBar.fillColor = barColor; vBar.strokeColor = .clear; vBar.zPosition = 0.5; outer.addChild(vBar)
        let hBar = SKShapeNode(rect: CGRect(x: -paneW / 2, y: -1.6 * mixScale, width: paneW, height: 3.2 * mixScale)); hBar.fillColor = barColor; hBar.strokeColor = .clear; hBar.zPosition = 0.5; outer.addChild(hBar)

        // Sill.
        let sill = SKShapeNode(rect: CGRect(x: -paneW / 2 - frameInset - 4 * mixScale, y: -paneH / 2 - frameInset - 7 * mixScale, width: paneW + frameInset * 2 + 8 * mixScale, height: 7 * mixScale), cornerRadius: 2 * mixScale)
        sill.fillColor = WarmShelfPalette.sand.withAlpha(0.65); sill.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.12); sill.lineWidth = 1
        sill.position = CGPoint(x: cx, y: cy); sill.zPosition = 1.45; stage.addChild(sill)
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
        let y = slotLocalY(zone)
        // Chunky clay toy-buttons, kept fully on-screen beside the character on every device — the
        // reach is clamped so the right/left column never clips off the edge or covers the keepsake.
        let r = 22 * mixScale
        let reach: CGFloat = min(102 * mixScale, size.width / 2 - max(14, safeInsets.left, safeInsets.right) - r - 6)
        // One "next" button per zone, not a pair. Tapping the doll already cycles forward;
        // the button's real job is signalling "this part changes" — three quiet clay signs
        // instead of six. (Parts wrap, so everything stays reachable.)
        for dir in [CGFloat(1)] {
            let chevron = SKNode()
            chevron.position = CGPoint(x: dir * reach, y: y)
            chevron.zPosition = 50
            // A chunky clay toy-button — not a flat UI chevron. Soft shadow, bevel, bold tab arrow.
            let shadow = SKShapeNode(circleOfRadius: r)
            shadow.fillColor = WarmShelfPalette.contactShadow.withAlpha(0.16); shadow.strokeColor = .clear
            shadow.position = CGPoint(x: 0, y: -3.5 * mixScale); shadow.zPosition = -1
            chevron.addChild(shadow)
            let disc = SKShapeNode(circleOfRadius: r)
            disc.fillColor = WarmShelfPalette.butter; disc.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.22); disc.lineWidth = 2
            chevron.addChild(disc)
            ProceduralTexture.applyClayFill(to: disc, base: WarmShelfPalette.butter, size: CGSize(width: r * 2, height: r * 2))
            let bevel = SKShapeNode(ellipseOf: CGSize(width: r * 0.95, height: r * 0.62))
            bevel.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.42); bevel.strokeColor = .clear
            bevel.position = CGPoint(x: -r * 0.16, y: r * 0.34); bevel.zPosition = 0.5
            disc.addChild(bevel)
            let a = 8.5 * mixScale
            let arrow = SKShapeNode(path: {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: dir * -a * 0.66, y: a)); p.addLine(to: CGPoint(x: dir * a, y: 0)); p.addLine(to: CGPoint(x: dir * -a * 0.66, y: -a)); p.closeSubpath(); return p
            }())
            arrow.fillColor = WarmShelfPalette.cocoa.withAlpha(0.72); arrow.strokeColor = .clear; arrow.zPosition = 1
            chevron.addChild(arrow)
            chevron.alpha = 0.0
            chevron.setScale(0.88)   // quieter at rest — the character is the hero, not the buttons
            root.addChild(chevron)
            chevrons.append((zone, dir, chevron))
            // Fade in to a recessive presence; one soft invite pulse, then stillness (no perpetual
            // pulsing competing with the doll).
            chevron.run(.sequence([.wait(forDuration: 0.6), .fadeAlpha(to: 0.66, duration: 0.3)]))
            if !AmbientAnimator.reduceMotion {
                disc.run(.sequence([.wait(forDuration: 2.2), .scale(to: 1.14, duration: 0.3), .scale(to: 1.0, duration: 0.35)]))
            }
        }
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

            // Chevron hit first (precise control).
            let localToRoot = CGPoint(x: point.x - root.position.x, y: point.y - root.position.y)
            if let hit = chevrons.min(by: { hypot($0.node.position.x - localToRoot.x, $0.node.position.y - localToRoot.y) < hypot($1.node.position.x - localToRoot.x, $1.node.position.y - localToRoot.y) }),
               hypot(hit.node.position.x - localToRoot.x, hit.node.position.y - localToRoot.y) < 46 * mixScale {
                flip(hit.zone, forward: hit.dir > 0)
                return
            }

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
                self?.flipping.remove(zone)
                self?.checkMatchedBow()
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
        run(.sequence([.wait(forDuration: 0.40), .run { [weak self] in
            guard let self else { return }
            switch zone {
            case .head: self.headPersonality(self.currentPartName(.head))
            case .body: self.peerDown(by: -0.16); self.showOffBody()
            case .legs: self.peerDown(by: -0.30); self.showOffLegs()
            }
            // After personality fires, check for a special theme combo.
            self.run(.sequence([.wait(forDuration: 0.55), .run { [weak self] in self?.checkSpecialCombo() }]))
        }]))
    }

    /// When all three zones accidentally align to a theme, the character gets a big moment —
    /// the joke of a full frog outfit, a complete knight, or a head-to-toe bird.
    private func checkSpecialCombo() {
        let head = currentPartName(.head)
        let body = currentPartName(.body)
        let legs = currentPartName(.legs)

        let color: UIColor?
        if head == "frog" && legs == "frog feet" {
            color = WarmShelfPalette.sage           // full frog
        } else if head == "bird" && body == "bird belly" && legs == "bird legs" {
            color = WarmShelfPalette.waterBlue      // full bird
        } else if (head == "king" || head == "queen") && body == "royal robe" && legs == "boots" {
            color = WarmShelfPalette.butter         // full royal
        } else if head == "bear" && legs == "paws" {
            color = UIColor(hex: 0x9B6B43)          // full bear
        } else if head == "robot" && body == "spacesuit" {
            color = WarmShelfPalette.waterBlue      // full robot
        } else {
            color = nil
        }

        guard let comboColor = color else { return }
        let origin = CGPoint(x: root.position.x, y: root.position.y)
        paperMotes(at: origin, count: AmbientAnimator.reduceMotion ? 3 : 14)
        TouchFeedbackAnimator.bubblePopRing(in: self, at: origin, radius: 64 * mixScale, color: comboColor)
        hop(height: 26 * mixScale, squash: true)
        AudioManager.shared.playMixCelebrationCombo()
        HapticsManager.shared.play(score: .mixUpCombo)
    }

    private func currentPartName(_ zone: MixUpZone) -> String {
        currentPart(zone)?.baseName ?? ""
    }

    /// Approved delight: the bow. All three zones settled on the SAME character — it is
    /// suddenly whole again. The spotlight warms and it takes one small bow. Recognition,
    /// not reward: no chime, no motes, once per match (re-armed when the match breaks).
    /// Name equality keeps this art-era-only — procedural pools never align by name.
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
        // Let the flip's own settle exhale finish before the character notices itself.
        run(.sequence([.wait(forDuration: 0.30), .run { [weak self] in self?.bowOnStage() }]))
    }

    private func bowOnStage() {
        // The spotlight warms briefly — layered over the authored pool (its node alpha
        // is already 1.0), or a soft pool at the feet in the procedural room.
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
            .wait(forDuration: 1.1),
            .fadeOut(withDuration: 1.3),
            .removeFromParent()
        ]))

        // One small bow: root nod (rotation only — root's SCALE belongs to the breathe
        // loop) plus a gentle body-slot dip. Absolute returns, hop-style.
        guard !AmbientAnimator.reduceMotion else { return }
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
        // No new sound — the settle tone just played; the calm IS the recognition.
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
            .move(to: CGPoint(x: 0, y: slotLocalY(.head)), duration: 0.30)
        ])
        dip.timingMode = .easeOut; back.timingMode = .easeInEaseOut
        head.run(.sequence([dip, .wait(forDuration: 0.34), back]), withKey: "react")
    }

    /// A signature beat for the species now wearing the head — the joke made motion.
    private func headPersonality(_ name: String) {
        guard let head = slots[.head] else { return }
        switch name {
        case "frog":
            hop(height: 26 * mixScale, squash: true)            // a springy leap
        case "lion":
            let shake = SKAction.sequence([
                .rotate(toAngle: 0.12, duration: 0.06), .rotate(toAngle: -0.12, duration: 0.08),
                .rotate(toAngle: 0.07, duration: 0.06), .rotate(toAngle: 0, duration: 0.06)
            ])
            head.run(shake, withKey: "react")                   // a tiny roar, mane and all
            head.run(.sequence([.scale(to: 1.14, duration: 0.10), .scale(to: 1.0, duration: 0.16)]))
        case "robot":
            let j: CGFloat = 3 * mixScale
            head.run(.sequence([                                 // a stiff little glitch-stutter
                .moveBy(x: j, y: 0, duration: 0.03), .moveBy(x: -2 * j, y: 0, duration: 0.04),
                .moveBy(x: 2 * j, y: 0, duration: 0.04), .moveBy(x: -j, y: 0, duration: 0.03)
            ]), withKey: "react")
        case "bird", "duck", "owl", "penguin":
            flapWings()
        case "bear":
            root.run(.sequence([                                 // a slow heavy sway
                .rotate(toAngle: 0.06, duration: 0.18), .rotate(toAngle: -0.06, duration: 0.24),
                .rotate(toAngle: 0, duration: 0.18)
            ]), withKey: "sway")
        case "cat", "fox", "mouse", "bunny":
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

    private func hop(height: CGFloat, squash: Bool) {
        // Absolute moves (not relative) and a hard reset to the grounded baseline first, so stacked
        // celebrations can never leave the character drifting in the air — it always lands home.
        let baseY = characterRootY
        root.removeAction(forKey: "hop")
        root.position.y = baseY
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
        body.run(.repeat(flap, count: 2), withKey: "react")
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
        switch Int.random(in: 0..<5) {
        case 0:
            head.run(.sequence([.rotate(toAngle: CGFloat.random(in: -0.12...0.12), duration: 0.4), .wait(forDuration: 0.7), .rotate(toAngle: 0, duration: 0.4)]), withKey: "react")
        case 1:
            root.run(.sequence([.moveBy(x: 0, y: 6 * mixScale, duration: 0.5), .moveBy(x: 0, y: -6 * mixScale, duration: 0.5)]), withKey: "hop")
        case 2:
            root.run(.sequence([
                .moveBy(x: 8 * mixScale, y: 0, duration: 0.5), .moveBy(x: -16 * mixScale, y: 0, duration: 0.7), .moveBy(x: 8 * mixScale, y: 0, duration: 0.5)
            ]), withKey: "hop")
        case 3:
            peerDown(by: -0.14)
            root.run(.sequence([.wait(forDuration: 0.9), .moveBy(x: 0, y: 8 * mixScale, duration: 0.14), .moveBy(x: 0, y: -8 * mixScale, duration: 0.22)]), withKey: "hop")
        default:
            root.run(.sequence([.rotate(toAngle: 0.05, duration: 0.16), .rotate(toAngle: -0.05, duration: 0.2), .rotate(toAngle: 0, duration: 0.16)]), withKey: "sway")
        }
    }

    // MARK: - Idle life

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        let delta = lastUpdate == 0 ? 0 : currentTime - lastUpdate
        lastUpdate = currentTime
        idleAccumulator += delta
        if idleAccumulator > 5.0 {
            idleAccumulator = 0
            guard flipping.isEmpty, root.action(forKey: "hop") == nil else { return }
            idleShowOff()
        }
    }

    override func accessibilityElements(in view: SKView) -> [UIAccessibilityElement] {
        var elements = super.accessibilityElements(in: view)
        for zone in MixUpZone.allCases {
            let name = currentPart(zone)?.name ?? ""
            let label: String
            switch zone {
            case .head: label = "head: \(name), tap to change"
            case .body: label = "body: \(name), tap to change"
            case .legs: label = "legs: \(name), tap to change"
            }
            let scenePos = CGPoint(x: root.position.x, y: root.position.y + slotLocalY(zone))
            elements.append(makeActivatableAccessibilityElement(
                in: view,
                label: label,
                scenePosition: scenePos,
                size: CGSize(width: 200, height: 90 * mixScale),
                traits: .button
            ) { [weak self] in
                self?.flip(zone, forward: true)
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
