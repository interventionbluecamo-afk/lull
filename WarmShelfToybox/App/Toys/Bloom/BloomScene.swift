import SpriteKit

final class BloomScene: BaseToyScene {
    override var firstSessionHintKey: String? { "hint.bloom" }
    override var toyVoice: AudioManager.LullSoundVoice { .bloom }
    private var worldNode = SKNode()
    private var soilLayer = SKNode()
    private var skyLayer = SKNode()
    private weak var sunNode: SKShapeNode?
    private var blooms: [BloomNode] = []
    private var features: [BloomFeatureNode] = []
    private var critters: [GardenCritterNode] = []
    private var bloomHeadShadows: [ObjectIdentifier: SKSpriteNode] = [:]
    private var lastBuiltSize = CGSize.zero
    private var soilTint: UIColor = UIColor(hex: 0x6E4B34)

    private var colorIndex = 0
    private var totalBlooms = 0
    private var completedFlourishes = Set<Int>()
    private var lastPlantSound: TimeInterval = 0
    private var lastUpdate: TimeInterval = 0
    private var fireflyAccumulator: TimeInterval = 0
    private var panVelocity: CGFloat = 0

    private var isWilting = false
    private var lifetimeBloomCount = 0

    // Touch state
    private var primaryTouch: UITouch?
    private var touchStartScene = CGPoint.zero
    private weak var draggedCritter: GardenCritterNode?
    private var critterMoved = false
    private var growingSeed: GrowingSeedNode?
    private var growingSeedWorldX: CGFloat = 0
    private var growingSeedHeight: CGFloat = 0
    private var growingSeedColor: UIColor = WarmShelfPalette.petal
    private var seedDidStretch = false
    private var lastSeedStretchSound: TimeInterval = 0

    // Stable procedural plan (ratios so it survives rebuilds/rotation).
    private var featurePlan: [(kind: BloomFeatureKind, xRatio: CGFloat)] = []

    private let maxBlooms = 80
    /// The flowers you grow take their colours from the current biome.
    private var gardenColors: [UIColor] = [
        WarmShelfPalette.petal, WarmShelfPalette.terracotta, WarmShelfPalette.butter,
        WarmShelfPalette.rhubarb, WarmShelfPalette.lavender, WarmShelfPalette.waterBlue
    ]
    /// Each visit is a fresh, seed-driven world (Minecraft-style): the seed deterministically
    /// chooses the biome, layout, and critters.
    private var biome: BloomBiome = .meadow
    private var worldSeed: UInt64 = 0

    private var worldWidthMultiplier: CGFloat = 3.0
    private var critterPlan: [GardenCritterKind] = []

    private struct BloomSnapshot {
        let kind: BloomKind
        let color: UIColor
        let xRatio: CGFloat
        let heightRatio: CGFloat
        let scaleRatio: CGFloat
    }

    private struct CritterSnapshot {
        let kind: GardenCritterKind
        let xRatio: CGFloat
    }

    private var bloomScale: CGFloat { bloomScale(for: size) }
    // Thinner dirt band in landscape so the garden/sky aren't swallowed by ground.
    // A slim ground strip so the calm open sky dominates (not a big dead dirt band).
    private var soilLineY: CGFloat { soilLineY(for: size) }
    private var worldWidth: CGFloat { size.width * worldWidthMultiplier }
    private var minPanX: CGFloat { -(worldWidth - size.width) }
    private var minStem: CGFloat { 26 * bloomScale }
    // Let flowers reach dramatically tall — toddlers love dragging them way up into the sky.
    private var maxStem: CGFloat { maxStem(for: size) }
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        ambientMoteInterval = 0.9
        buildWorld()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard abs(size.width - lastBuiltSize.width) > 2 || abs(size.height - lastBuiltSize.height) > 2 else { return }
        let bloomSnapshots = snapshotBlooms(oldSize: oldSize)
        let critterSnapshots = snapshotCritters(oldSize: oldSize)
        let panRatio = currentPanRatio(oldSize: oldSize)
        buildWorld(preservingBlooms: bloomSnapshots, preservingCritters: critterSnapshots, preservingPanRatio: panRatio)
    }

    private func buildWorld(
        preservingBlooms bloomSnapshots: [BloomSnapshot] = [],
        preservingCritters critterSnapshots: [CritterSnapshot] = [],
        preservingPanRatio panRatio: CGFloat = 0
    ) {
        guard size.width > 160, size.height > 160 else { return }
        lastBuiltSize = size

        if featurePlan.isEmpty { featurePlan = makeFeaturePlan() }

        removeAction(forKey: "bloom.openingHint")
        cancelSeedGrowth(animated: false)
        skyLayer.removeFromParent()
        childNode(withName: "lightTint")?.removeFromParent()
        worldNode.removeFromParent()
        worldNode = SKNode()
        worldNode.zPosition = 5
        worldNode.position = CGPoint(x: (minPanX * panRatio).clamped(to: minPanX...0), y: 0)
        addChild(worldNode)
        blooms.removeAll()
        features.removeAll()
        critters.removeAll()
        bloomHeadShadows.removeAll()
        panVelocity = 0

        addSky()
        buildSoil()
        placeFeatures()
        critterSnapshots.isEmpty ? addCritters() : restoreCritters(critterSnapshots)
        addMole()
        if bloomSnapshots.isEmpty {
            if totalBlooms == 0 { addOpeningHint() }
        } else {
            restoreBlooms(bloomSnapshots)
        }
    }

    private func currentPanRatio(oldSize: CGSize) -> CGFloat {
        let oldWorldWidth = oldSize.width * worldWidthMultiplier
        let oldScrollableWidth = max(1, oldWorldWidth - oldSize.width)
        return (-worldNode.position.x / oldScrollableWidth).clamped(to: 0...1)
    }

    private func bloomScale(for sceneSize: CGSize) -> CGFloat {
        (min(sceneSize.width, sceneSize.height) / 480).clamped(to: 0.7...1.6)
    }

    private func soilLineY(for sceneSize: CGSize) -> CGFloat {
        max(96, sceneSize.height * (sceneSize.width > sceneSize.height ? 0.16 : 0.20))
    }

    private func maxStem(for sceneSize: CGSize) -> CGFloat {
        sceneSize.height * 0.6
    }

    private func snapshotBlooms(oldSize: CGSize) -> [BloomSnapshot] {
        guard oldSize.width > 160, oldSize.height > 160 else { return [] }
        let oldWorldWidth = oldSize.width * worldWidthMultiplier
        let oldMaxStem = maxStem(for: oldSize)
        let oldBloomScale = bloomScale(for: oldSize)

        return blooms.compactMap { bloom in
            guard bloom.parent != nil else { return nil }
            return BloomSnapshot(
                kind: bloom.kind,
                color: bloom.snapshotColor,
                xRatio: (bloom.position.x / oldWorldWidth).clamped(to: 0...1),
                heightRatio: (bloom.stemHeight / oldMaxStem).clamped(to: 0.02...1),
                scaleRatio: (bloom.snapshotScaleFactor / oldBloomScale).clamped(to: 0.72...1.35)
            )
        }
    }

    private func snapshotCritters(oldSize: CGSize) -> [CritterSnapshot] {
        guard oldSize.width > 160, oldSize.height > 160 else { return [] }
        let oldWorldWidth = oldSize.width * worldWidthMultiplier
        return critters.compactMap { critter in
            guard critter.parent != nil else { return nil }
            return CritterSnapshot(
                kind: critter.kind,
                xRatio: (critter.position.x / oldWorldWidth).clamped(to: 0...1)
            )
        }
    }

    private func restoreBlooms(_ snapshots: [BloomSnapshot]) {
        for snapshot in snapshots {
            let height = (snapshot.heightRatio * maxStem).clamped(to: 8...maxStem)
            let bloom = BloomNode(
                kind: snapshot.kind,
                color: snapshot.color,
                scale: bloomScale * snapshot.scaleRatio,
                stemHeight: height
            )
            bloom.position = CGPoint(
                x: (snapshot.xRatio * worldWidth).clamped(to: 14...(worldWidth - 14)),
                y: soilLineY
            )
            bloom.zPosition = 50 - (height / maxStem) * 20
            bloom.userData = ["rx": snapshot.xRatio]
            worldNode.addChild(bloom)
            installBloomHeadShadow(for: bloom, visible: true)
            bloom.restoreFullyGrown()
            blooms.append(bloom)
        }
    }

    private func bloomHeadShadowPosition(for bloom: BloomNode) -> CGPoint {
        let spec = bloom.headShadowSpec
        return CGPoint(
            x: bloom.position.x,
            y: bloom.position.y + bloom.stemHeight + spec.yOffset
        )
    }

    private func installBloomHeadShadow(for bloom: BloomNode, visible: Bool) {
        let id = ObjectIdentifier(bloom)
        guard bloomHeadShadows[id] == nil else { return }

        let spec = bloom.headShadowSpec
        let shadow = SKSpriteNode(texture: ProceduralTexture.softClayShadow(size: spec.size))
        shadow.size = spec.size
        shadow.position = bloomHeadShadowPosition(for: bloom)
        shadow.zPosition = max(0, bloom.zPosition - 0.2)
        shadow.alpha = visible ? 0.84 : 0
        shadow.setScale(visible ? 1.0 : 0.55)
        worldNode.addChild(shadow)
        bloomHeadShadows[id] = shadow
    }

    private func revealBloomHeadShadow(for bloom: BloomNode, after delay: TimeInterval) {
        let id = ObjectIdentifier(bloom)
        guard let shadow = bloomHeadShadows[id] else { return }
        shadow.removeAction(forKey: "bloom.headShadow.reveal")

        let fade = SKAction.fadeAlpha(to: 0.84, duration: 0.20)
        let scale = SKAction.scale(to: 1.0, duration: 0.22)
        fade.timingMode = .easeOut
        scale.timingMode = .easeOut
        shadow.run(.sequence([
            .wait(forDuration: delay),
            .group([fade, scale])
        ]), withKey: "bloom.headShadow.reveal")
    }

    private func removeBloomHeadShadow(for bloom: BloomNode) {
        let id = ObjectIdentifier(bloom)
        bloomHeadShadows[id]?.removeFromParent()
        bloomHeadShadows.removeValue(forKey: id)
    }

    private func syncBloomHeadShadows() {
        guard worldNode.parent != nil else { return }

        let liveIDs = Set(blooms.filter { $0.parent != nil }.map { ObjectIdentifier($0) })
        let staleIDs = bloomHeadShadows.keys.filter { !liveIDs.contains($0) }
        for id in staleIDs {
            bloomHeadShadows[id]?.removeFromParent()
            bloomHeadShadows.removeValue(forKey: id)
        }

        for bloom in blooms where bloom.parent != nil {
            let id = ObjectIdentifier(bloom)
            if bloomHeadShadows[id] == nil {
                installBloomHeadShadow(for: bloom, visible: true)
            }
            guard let shadow = bloomHeadShadows[id] else { continue }
            shadow.position = bloomHeadShadowPosition(for: bloom)
            shadow.zRotation = 0
            shadow.zPosition = max(0, bloom.zPosition - 0.2)
            if bloom.alpha < 0.98 {
                shadow.alpha = min(shadow.alpha, bloom.alpha * 0.84)
            }
        }
    }

    // MARK: - Burrowing mole (lives in the visible dirt)

    private weak var moleNode: SKNode?

    private func addMole() {
        let s = bloomScale
        let mole = SKNode()
        mole.name = "mole"
        let body = SKShapeNode(ellipseOf: CGSize(width: 48 * s, height: 30 * s))
        body.fillColor = UIColor(hex: 0x46352B).withAlpha(0.96); body.strokeColor = .clear
        mole.addChild(body)
        let snout = SKShapeNode(ellipseOf: CGSize(width: 20 * s, height: 15 * s))
        snout.fillColor = UIColor(hex: 0x46352B).withAlpha(0.98); snout.position = CGPoint(x: 18 * s, y: -1 * s)
        mole.addChild(snout)
        let nose = SKShapeNode(circleOfRadius: 4 * s); nose.fillColor = WarmShelfPalette.petal; nose.strokeColor = .clear
        nose.position = CGPoint(x: 29 * s, y: -1 * s); mole.addChild(nose)
        for sign in [CGFloat(-1), CGFloat(1)] {
            // Closed, content eyes (it's underground).
            let lid = SKShapeNode(path: { let p = CGMutablePath(); p.move(to: CGPoint(x: -3 * s, y: 0)); p.addQuadCurve(to: CGPoint(x: 3 * s, y: 0), control: CGPoint(x: 0, y: -2.5 * s)); return p }())
            lid.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.6); lid.lineWidth = 1.6 * s; lid.lineCap = .round
            lid.position = CGPoint(x: sign * 12 * s, y: 5 * s); mole.addChild(lid)
        }
        let paw = SKShapeNode(ellipseOf: CGSize(width: 16 * s, height: 10 * s))
        paw.fillColor = WarmShelfPalette.sand.withAlpha(0.85); paw.strokeColor = .clear
        paw.position = CGPoint(x: 6 * s, y: -12 * s); mole.addChild(paw)

        mole.position = CGPoint(x: worldWidth * 0.5, y: soilLineY * 0.55)
        mole.zPosition = 3  // above the dirt, behind the flowers — a cutaway tunnel view
        worldNode.addChild(mole)
        moleNode = mole
        moleRoam(mole)
    }

    private func moleRoam(_ mole: SKNode) {
        guard !AmbientAnimator.reduceMotion else { return }
        let target = CGFloat.random(in: 70...(worldWidth - 70))
        let depth = CGFloat.random(in: (soilLineY * 0.30)...(soilLineY * 0.72))
        let dir: CGFloat = target >= mole.position.x ? 1 : -1
        mole.run(.scaleX(to: dir, y: 1, duration: 0.12))
        let dur = TimeInterval(max(2.0, abs(target - mole.position.x) / (44 * bloomScale)))
        let move = SKAction.group([
            .moveTo(x: target, duration: dur),
            .moveTo(y: depth, duration: dur)
        ])
        move.timingMode = .easeInEaseOut
        // Occasionally push a little dirt mound up at the surface as it passes.
        let trail = SKAction.run { [weak self, weak mole] in
            guard let self, let mole, Int.random(in: 0..<2) == 0 else { return }
            self.moleSurfaceMound(atX: mole.position.x)
        }
        mole.run(.sequence([
            .group([move, .sequence([.wait(forDuration: dur * 0.5), trail])]),
            .wait(forDuration: .random(in: 1.0...2.2)),
            .run { [weak self, weak mole] in
                guard let self, let mole else { return }
                // Now and then, surface for a sniff before tunnelling on.
                if Int.random(in: 0..<3) == 0 { self.molePeek(mole) } else { self.moleRoam(mole) }
            }
        ]), withKey: "moleRoam")
    }

    /// The mole rises to break the surface, sniffs the air, then dives back under.
    private func molePeek(_ mole: SKNode) {
        moleSurfaceMound(atX: mole.position.x)
        let surfaceY = soilLineY + 6 * bloomScale  // head pokes just above the grass
        let backDown = CGFloat.random(in: (soilLineY * 0.4)...(soilLineY * 0.62))
        // Quick surface (0.30s easeOut), slow dive back (0.52s easeIn) — matches aliveness law.
        let rise = SKAction.moveTo(y: surfaceY, duration: 0.30); rise.timingMode = .easeOut
        let sniff = SKAction.sequence([
            .rotate(byAngle: 0.12, duration: 0.12), .rotate(byAngle: -0.12, duration: 0.14),
            .rotate(byAngle: 0.08, duration: 0.1), .rotate(byAngle: 0, duration: 0.1)
        ])
        let dive = SKAction.moveTo(y: backDown, duration: 0.52); dive.timingMode = .easeIn
        mole.run(.sequence([
            rise, sniff, .wait(forDuration: 0.5), dive,
            .wait(forDuration: .random(in: 0.6...1.4)),
            .run { [weak self, weak mole] in guard let self, let mole else { return }; self.moleRoam(mole) }
        ]), withKey: "moleRoam")
    }

    /// Tapped — the mole pops right out, does a happy wiggle, then burrows back down.
    private func molePopUp(_ mole: SKNode) {
        mole.removeAction(forKey: "moleRoam")
        moleSurfaceMound(atX: mole.position.x)
        let popY = soilLineY + 30 * bloomScale
        let up = SKAction.moveTo(y: popY, duration: 0.24); up.timingMode = .easeOut
        let wiggle = SKAction.sequence([
            .rotate(byAngle: 0.16, duration: 0.1), .rotate(byAngle: -0.16, duration: 0.12),
            .rotate(byAngle: 0.1, duration: 0.1), .rotate(byAngle: 0, duration: 0.1)
        ])
        let down = SKAction.moveTo(y: CGFloat.random(in: (soilLineY * 0.4)...(soilLineY * 0.6)), duration: 0.4); down.timingMode = .easeIn
        mole.run(.sequence([
            up, wiggle, .wait(forDuration: 0.4), down,
            .wait(forDuration: 0.6),
            .run { [weak self, weak mole] in guard let self, let mole else { return }; self.moleRoam(mole) }
        ]), withKey: "moleRoam")
    }

    private func moleSurfaceMound(atX x: CGFloat) {
        let mound = SKShapeNode(ellipseOf: CGSize(width: 30 * bloomScale, height: 12 * bloomScale))
        mound.fillColor = soilTint.withAlpha(0.95); mound.strokeColor = .clear
        mound.position = CGPoint(x: x, y: soilLineY + 3)
        mound.zPosition = 8
        mound.setScale(0.2)
        worldNode.addChild(mound)
        mound.run(.sequence([.scale(to: 1, duration: 0.2), .wait(forDuration: 2.0), .group([.fadeOut(withDuration: 1.2), .scale(to: 0.5, duration: 1.2)]), .removeFromParent()]))
    }

    // MARK: - Sky (obvious time of day)

    private func addSky() {
        skyLayer = SKNode()
        skyLayer.zPosition = -60  // behind the world, in front of the base paper
        addChild(skyLayer)

        // Lull's garden lives in the same warm, sunlit world as every other toy — a soft
        // cream sky that never darkens into night. Time-of-day lives in the framed windows
        // of the other toys; here it stays gently warm so the app reads as one place.
        let texture = TimeOfDay.gradientTexture(
            size: CGSize(width: 64, height: max(64, size.height)),
            top: WarmShelfPalette.paperHighlight,
            bottom: WarmShelfPalette.warmCream
        )
        let sky = SKSpriteNode(texture: texture)
        sky.size = CGSize(width: size.width, height: size.height)
        sky.position = CGPoint(x: size.width / 2, y: size.height / 2)
        sky.zPosition = 0
        skyLayer.addChild(sky)

        // Each biome's warm air.
        if biome.skyWashAlpha > 0 {
            let wash = SKSpriteNode(color: biome.skyWash, size: CGSize(width: size.width, height: size.height))
            wash.alpha = biome.skyWashAlpha
            wash.position = sky.position
            wash.zPosition = 0.5
            skyLayer.addChild(wash)
        }

        addDistantHills()

        // A soft, warm sun — always day in the garden.
        let orbRadius = 40 * (size.width / 400).clamped(to: 0.8...1.6)
        let orbX = 0.78 * size.width
        let orbY = soilLineY + (size.height - soilLineY) * 0.74
        let glow = SKShapeNode(circleOfRadius: orbRadius * 1.9)
        glow.fillColor = WarmShelfPalette.butter.withAlpha(0.22); glow.strokeColor = .clear
        glow.position = CGPoint(x: orbX, y: orbY); glow.zPosition = 1
        skyLayer.addChild(glow)
        let orb = SKShapeNode(circleOfRadius: orbRadius)
        orb.fillColor = WarmShelfPalette.butter.withAlpha(0.95); orb.strokeColor = .clear
        orb.position = CGPoint(x: orbX, y: orbY); orb.zPosition = 2
        orb.name = "sunOrb"
        skyLayer.addChild(orb)
        sunNode = orb
        AmbientAnimator.breathe(node: glow, scale: 1.08, duration: 5.0)

        addClouds()
    }

    /// Soft layered hills on the horizon — the serene, atmospheric depth of Alto's Odyssey and
    /// Monument Valley. Distant ridges sit higher and fainter (atmospheric perspective); nearer
    /// ones are lower and a touch stronger. Their bases hide behind the dirt, so they read as a
    /// wide, quiet world beyond the planting patch — giving the garden calm negative space
    /// instead of feeling flat or crowded.
    private func addDistantHills() {
        let horizon = soilLineY
        let widthScale = size.width / 400
        struct HillLayer { let alpha: CGFloat; let rise: CGFloat; let z: CGFloat }
        let layers = [
            HillLayer(alpha: 0.14, rise: 96 * widthScale, z: 0.30),   // far, faint, high
            HillLayer(alpha: 0.22, rise: 62 * widthScale, z: 0.40)    // near, stronger, low
        ]
        for layer in layers {
            // A few overlapping soft mounds so the ridgeline gently rolls across the width.
            let mounds = 2
            for j in 0...mounds {
                let w = size.width * CGFloat.random(in: 0.58...0.86)
                let mound = SKShapeNode(ellipseOf: CGSize(width: w, height: layer.rise * 2.1))
                mound.fillColor = biome.grass.withAlpha(layer.alpha)
                mound.strokeColor = .clear
                mound.position = CGPoint(
                    x: size.width * (CGFloat(j) / CGFloat(mounds)) + CGFloat.random(in: -52...52),
                    y: horizon + layer.rise * 0.5
                )
                mound.zPosition = layer.z
                skyLayer.addChild(mound)
            }
        }
    }

    private func addStars(alpha: CGFloat) {
        for _ in 0..<40 {
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.8...2.0))
            star.fillColor = WarmShelfPalette.paperHighlight.withAlpha(alpha * CGFloat.random(in: 0.5...1.0))
            star.strokeColor = .clear
            star.position = CGPoint(x: .random(in: 0...size.width), y: .random(in: soilLineY...size.height))
            star.zPosition = 1
            skyLayer.addChild(star)
            let twinkle = SKAction.sequence([
                .fadeAlpha(to: 0.2, duration: .random(in: 0.8...1.8)),
                .fadeAlpha(to: 1.0, duration: .random(in: 0.8...1.8))
            ])
            if !AmbientAnimator.reduceMotion {
                star.run(.repeatForever(.sequence([.wait(forDuration: .random(in: 0...2)), twinkle])))
            }
        }
    }

    private func addClouds() {
        // Fewer, slower clouds — Monument-Valley stillness, lots of quiet sky.
        let count = Int.random(in: 1...2)
        for _ in 0..<count {
            let cloud = SKNode()
            let w = CGFloat.random(in: 70...130) * (size.width / 400)
            for _ in 0..<3 {
                let puff = SKShapeNode(circleOfRadius: CGFloat.random(in: 16...28) * (size.width / 400))
                puff.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.5); puff.strokeColor = .clear
                puff.position = CGPoint(x: .random(in: -w / 2...w / 2), y: .random(in: -6...6))
                cloud.addChild(puff)
            }
            let startX = CGFloat.random(in: 0...size.width)
            cloud.position = CGPoint(x: startX, y: .random(in: size.height * 0.62...size.height * 0.92))
            cloud.zPosition = 1
            cloud.alpha = 0.9
            skyLayer.addChild(cloud)
            if !AmbientAnimator.reduceMotion {
                let drift = SKAction.moveBy(x: size.width + w, y: 0, duration: Double.random(in: 40...70))
                cloud.run(.repeatForever(.sequence([drift, .moveBy(x: -(size.width + w) * 2, y: 0, duration: 0), drift])))
            }
        }
    }

    private func addCritters() {
        // A random mix of critters lives in the meadow — each with its own stretch to roam.
        let kinds: [GardenCritterKind] = critterPlan.isEmpty ? [.mouse, .bear, .bird] : critterPlan
        installCritters(kinds.map { ($0, nil) })
    }

    private func restoreCritters(_ snapshots: [CritterSnapshot]) {
        installCritters(snapshots.map { ($0.kind, Optional($0.xRatio)) })
    }

    private func installCritters(_ placements: [(kind: GardenCritterKind, xRatio: CGFloat?)]) {
        guard !placements.isEmpty else { return }
        let lift: [GardenCritterKind: CGFloat] = [.mouse: 14, .bear: 26, .bird: 20]
        for (index, placement) in placements.enumerated() {
            let kind = placement.kind
            let critter = GardenCritterNode(kind: kind, scale: bloomScale)
            let territory = worldWidth / CGFloat(placements.count)
            let minX = territory * CGFloat(index) + 70
            let maxX = territory * CGFloat(index + 1) - 70
            let restoredX = placement.xRatio.map { ($0 * worldWidth).clamped(to: minX...maxX) }
            critter.position = CGPoint(
                x: restoredX ?? CGFloat.random(in: minX...maxX),
                y: soilLineY + (lift[kind] ?? 16) * bloomScale
            )
            critter.zPosition = 80
            worldNode.addChild(critter)
            critter.startRoaming(in: minX, maxX)
            critters.append(critter)
        }
    }

    private func makeFeaturePlan() -> [(BloomFeatureKind, CGFloat)] {
        // A fresh, seed-driven world each visit — the seed picks the biome, layout & critters.
        worldSeed = UInt64.random(in: 1...UInt64.max)
        var rng = SeededGenerator(seed: worldSeed)

        biome = BloomBiome.pick(using: &rng)
        soilTint = biome.soil
        gardenColors = biome.flowerColors
        // One focused screen — no panning. A single, lush, cause-and-effect garden.
        worldWidthMultiplier = 1.0

        // Weighted pool — bushes/rocks common, ponds/trees special.
        let pool: [BloomFeatureKind] = [.bush, .tree, .log, .pond, .snailRock]
        // One calm screen: a single landmark off to the side. The flowers the child grows
        // are the content — the scene starts spare and open, not a crowded diorama.
        let count = 1
        var chosen: [BloomFeatureKind] = []
        var hasPond = false
        var guardCount = 0
        while chosen.count < count, guardCount < 40 {
            guardCount += 1
            let k = pool.randomElement(using: &rng) ?? .bush
            if k == .pond && hasPond { continue }
            if k == .pond { hasPond = true }
            chosen.append(k)
        }

        // Critters: 2 of the biome's residents — enough life, not crowded.
        let residents = biome.critterKinds.shuffled(using: &rng)
        critterPlan = Array(residents.prefix(2))

        let singleSide: CGFloat = Bool.random(using: &rng) ? 0.18 : 0.82
        return chosen.enumerated().map { index, kind in
            let slot = count == 1 ? singleSide : (CGFloat(index) + 0.5) / CGFloat(count)
            let jitter = CGFloat.random(in: -0.04...0.04, using: &rng)
            return (kind: kind, xRatio: (slot + jitter).clamped(to: 0.08...0.92))
        }
    }

    private func buildSoil() {
        soilLayer = SKNode()
        soilLayer.zPosition = 0
        worldNode.addChild(soilLayer)

        let earth = SKShapeNode(rect: CGRect(x: -40, y: 0, width: worldWidth + 80, height: soilLineY), cornerRadius: 0)
        earth.fillColor = soilTint.withAlpha(0.94)
        earth.strokeColor = .clear
        soilLayer.addChild(earth)

        let deep = SKShapeNode(rect: CGRect(x: -40, y: 0, width: worldWidth + 80, height: soilLineY * 0.5), cornerRadius: 0)
        deep.fillColor = biome.deepSoil.withAlpha(0.55)
        deep.strokeColor = .clear
        deep.zPosition = 0.1
        soilLayer.addChild(deep)

        // Horizontal earth strata — gives the dirt a layered, textured feel.
        for i in 0..<3 {
            let y = soilLineY * (0.22 + CGFloat(i) * 0.26)
            let strata = SKShapeNode(rect: CGRect(x: -40, y: y, width: worldWidth + 80, height: 3), cornerRadius: 1.5)
            strata.fillColor = UIColor(hex: 0x3E2A18).withAlpha(0.22)
            strata.strokeColor = .clear
            strata.zPosition = 0.15
            soilLayer.addChild(strata)
        }

        let clumpCount = Int((worldWidth * soilLineY / 7000).clamped(to: 40...180))
        for _ in 0..<clumpCount {
            let speck = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.5...4.5))
            speck.fillColor = [UIColor(hex: 0x4A2F1B), UIColor(hex: 0x8A6346), WarmShelfPalette.cocoa].randomElement()!.withAlpha(.random(in: 0.18...0.4))
            speck.strokeColor = .clear
            speck.position = CGPoint(x: .random(in: 0...worldWidth), y: .random(in: 6...(soilLineY - 8)))
            speck.zPosition = 0.2
            soilLayer.addChild(speck)
        }

        let lip = SKShapeNode(rect: CGRect(x: -40, y: soilLineY - 6, width: worldWidth + 80, height: 10), cornerRadius: 4)
        lip.fillColor = biome.grass.withAlpha(0.5)
        lip.strokeColor = .clear
        lip.zPosition = 0.6
        soilLayer.addChild(lip)
        // Snowy biome has fewer/shorter "blades" (it's a snow crust, not grass). Kept sparse so
        // the ground reads calm and quiet rather than a busy lawn.
        let bladeCount = biome.prop == .pine ? Int(worldWidth / 46) : Int(worldWidth / 30)
        for _ in 0..<bladeCount {
            let blade = SKShapeNode(rect: CGRect(x: -1.2, y: 0, width: 2.4, height: CGFloat.random(in: 5...12)), cornerRadius: 1.2)
            blade.fillColor = biome.grass.withAlpha(.random(in: 0.4...0.7))
            blade.strokeColor = .clear
            blade.position = CGPoint(x: .random(in: 0...worldWidth), y: soilLineY - 2)
            blade.zRotation = .random(in: -0.2...0.2)
            blade.zPosition = 0.7
            soilLayer.addChild(blade)
        }
        addBiomeProps()
    }

    /// Each biome's signature surface decoration — the instant "this is a different place" cue.
    private func addBiomeProps() {
        let s = bloomScale
        switch biome.prop {
        case .daisies:
            for _ in 0..<2 {
                let x = CGFloat.random(in: 30...(worldWidth - 30))
                let stemH = CGFloat.random(in: 10...18) * s
                let stem = SKShapeNode(rect: CGRect(x: -1, y: 0, width: 2, height: stemH))
                stem.fillColor = biome.grass.withAlpha(0.7); stem.strokeColor = .clear
                stem.position = CGPoint(x: x, y: soilLineY - 2); stem.zPosition = 0.8; soilLayer.addChild(stem)
                for k in 0..<6 {
                    let a = CGFloat(k) / 6 * .pi * 2
                    let petal = SKShapeNode(ellipseOf: CGSize(width: 4 * s, height: 7 * s))
                    petal.fillColor = WarmShelfPalette.paperHighlight; petal.strokeColor = .clear
                    petal.position = CGPoint(x: x + cos(a) * 4 * s, y: soilLineY - 2 + stemH + sin(a) * 4 * s)
                    petal.zRotation = a; petal.zPosition = 0.85; soilLayer.addChild(petal)
                }
                let mid = SKShapeNode(circleOfRadius: 3 * s); mid.fillColor = WarmShelfPalette.butter; mid.strokeColor = .clear
                mid.position = CGPoint(x: x, y: soilLineY - 2 + stemH); mid.zPosition = 0.86; soilLayer.addChild(mid)
            }
        case .palm:
            // One palm, tucked to a side so the centre stays open for planting.
            addPalm(atX: worldWidth * (Bool.random() ? 0.16 : 0.84), scale: s)
        case .pine:
            // A small cluster of two pines to one side, plus a single snow mound.
            let side: CGFloat = Bool.random() ? 0.16 : 0.84
            addPine(atX: worldWidth * side, scale: s)
            addPine(atX: worldWidth * side + 44 * s, scale: s * 0.82)
            let mound = SKShapeNode(ellipseOf: CGSize(width: 70 * s, height: 18 * s))
            mound.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.7); mound.strokeColor = .clear
            mound.position = CGPoint(x: worldWidth * side, y: soilLineY + 2); mound.zPosition = 0.75; soilLayer.addChild(mound)
        case .fireflies:
            for _ in 0..<3 {
                let fly = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...3.4) * s)
                fly.fillColor = WarmShelfPalette.butter.withAlpha(0.9); fly.strokeColor = .clear
                fly.glowWidth = 4 * s
                fly.position = CGPoint(x: .random(in: 0...worldWidth), y: soilLineY + CGFloat.random(in: 20...140) * s)
                fly.zPosition = 70; worldNode.addChild(fly)
                let drift = SKAction.sequence([
                    .group([.moveBy(x: .random(in: -30...30), y: .random(in: -16...16), duration: .random(in: 1.6...2.8)),
                            .fadeAlpha(to: 0.25, duration: 1.2)]),
                    .group([.moveBy(x: .random(in: -30...30), y: .random(in: -16...16), duration: .random(in: 1.6...2.8)),
                            .fadeAlpha(to: 0.9, duration: 1.2)])
                ])
                if !AmbientAnimator.reduceMotion {
                    fly.run(.repeatForever(drift))
                }
            }
        }
    }

    private func addPalm(atX x: CGFloat, scale s: CGFloat) {
        let trunk = SKShapeNode(path: {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -4 * s, y: 0))
            p.addQuadCurve(to: CGPoint(x: 6 * s, y: 80 * s), control: CGPoint(x: -10 * s, y: 44 * s))
            p.addQuadCurve(to: CGPoint(x: -2 * s, y: 0), control: CGPoint(x: 0 * s, y: 44 * s))
            p.closeSubpath(); return p
        }())
        trunk.fillColor = UIColor(hex: 0x9B6B43); trunk.strokeColor = .clear
        trunk.position = CGPoint(x: x, y: soilLineY - 2); trunk.zPosition = 9; worldNode.addChild(trunk)
        for k in 0..<5 {
            let a = CGFloat(k) / 5 * .pi - .pi * 0.1
            let frond = SKShapeNode(ellipseOf: CGSize(width: 46 * s, height: 16 * s))
            frond.fillColor = WarmShelfPalette.sage.withAlpha(0.92); frond.strokeColor = .clear
            frond.position = CGPoint(x: x + 4 * s + cos(a) * 22 * s, y: soilLineY - 2 + 80 * s + sin(a) * 12 * s)
            frond.zRotation = a; frond.zPosition = 9.1; worldNode.addChild(frond)
        }
        let coconut = SKShapeNode(circleOfRadius: 5 * s); coconut.fillColor = UIColor(hex: 0x6E4B34); coconut.strokeColor = .clear
        coconut.position = CGPoint(x: x + 4 * s, y: soilLineY - 2 + 74 * s); coconut.zPosition = 9.2; worldNode.addChild(coconut)
    }

    private func addPine(atX x: CGFloat, scale s: CGFloat) {
        let trunk = SKShapeNode(rect: CGRect(x: -3 * s, y: 0, width: 6 * s, height: 16 * s))
        trunk.fillColor = UIColor(hex: 0x6E4B34); trunk.strokeColor = .clear
        trunk.position = CGPoint(x: x, y: soilLineY - 2); trunk.zPosition = 9; worldNode.addChild(trunk)
        for (i, w) in [CGFloat(40), 30, 20].enumerated() {
            let tier = SKShapeNode(path: {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: -w * s, y: 0)); p.addLine(to: CGPoint(x: w * s, y: 0)); p.addLine(to: CGPoint(x: 0, y: 34 * s)); p.closeSubpath(); return p
            }())
            tier.fillColor = UIColor(hex: 0x4E6B49); tier.strokeColor = .clear
            tier.position = CGPoint(x: x, y: soilLineY - 2 + 14 * s + CGFloat(i) * 22 * s); tier.zPosition = 9.1 + CGFloat(i) * 0.1; worldNode.addChild(tier)
            // a dusting of snow on the tier
            let snow = SKShapeNode(ellipseOf: CGSize(width: w * 1.2 * s, height: 6 * s))
            snow.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.85); snow.strokeColor = .clear
            snow.position = CGPoint(x: x, y: soilLineY - 2 + 14 * s + CGFloat(i) * 22 * s + 30 * s); snow.zPosition = 9.15 + CGFloat(i) * 0.1; worldNode.addChild(snow)
        }
    }

    private func placeFeatures() {
        for plan in featurePlan {
            let feature = BloomFeatureNode(kind: plan.kind, scale: bloomScale)
            feature.position = CGPoint(x: plan.xRatio * worldWidth, y: soilLineY)
            feature.zPosition = (plan.kind == .tree) ? 12 : 10  // background landmarks, behind flowers
            worldNode.addChild(feature)
            features.append(feature)
        }
    }

    private func addOpeningHint() {
        // Just one starter flower blooms to invite a tap — the rest is the child's to grow.
        run(.sequence([
            .wait(forDuration: 0.35),
            .run { [weak self] in
                guard let self else { return }
                self.growPlant(atWorldX: self.size.width * 0.5, stemHeight: self.minStem + 70 * self.bloomScale, silent: true)
            }
        ]), withKey: "bloom.openingHint")
    }

    // MARK: - Touch (tap = plant/interact)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        HapticsManager.shared.prepareForTouch()
        for touch in touches {
            let scenePoint = touch.location(in: self)
            if primaryTouch == nil, consumeShelfReturnTouch(at: scenePoint) { return }
            guard primaryTouch == nil else { continue }
            primaryTouch = touch
            touchStartScene = scenePoint

            // Touch on a critter picks it up (instead of panning the world).
            let world = CGPoint(x: scenePoint.x - worldNode.position.x, y: scenePoint.y)
            if let c = critterAt(world: world) {
                draggedCritter = c
                critterMoved = false
                c.grab()
                HapticsManager.shared.blockPickup()
                // A small lift-sparkle so the grab reads as physical.
                let liftPoint = CGPoint(x: world.x + worldNode.position.x, y: world.y + 18 * bloomScale)
                ParticleManager.softBurst(in: self, at: liftPoint, color: WarmShelfPalette.petal, count: 5)
            } else if shouldBeginSeedGrowth(atScene: scenePoint, world: world) {
                beginSeedGrowth(atScene: scenePoint, world: world)
            }
        }
    }

    private func critterAt(world: CGPoint) -> GardenCritterNode? {
        critters.first { hypot($0.position.x - world.x, ($0.position.y + 18 * bloomScale) - world.y) < 80 * bloomScale }
    }

    private func critterGroundLift(_ kind: GardenCritterKind) -> CGFloat {
        switch kind {
        case .mouse: return 14
        case .bear: return 26
        case .bird: return 20
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = primaryTouch, touches.contains(touch) else { return }
        let scenePoint = touch.location(in: self)

        // Carrying a critter — move it instead of panning.
        if let c = draggedCritter {
            if hypot(scenePoint.x - touchStartScene.x, scenePoint.y - touchStartScene.y) > 6 { critterMoved = true }
            let world = CGPoint(x: scenePoint.x - worldNode.position.x, y: scenePoint.y)
            let clampedX = world.x.clamped(to: 24...(worldWidth - 24))
            let clampedY = max(soilLineY + 6 * bloomScale, min(world.y, size.height - 24))
            c.position = CGPoint(x: clampedX, y: clampedY)
            return
        }

        if growingSeed != nil {
            if hypot(scenePoint.x - touchStartScene.x, scenePoint.y - touchStartScene.y) > 6 {
                seedDidStretch = true
            }
            updateSeedGrowth(atScene: scenePoint)
            return
        }

    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = primaryTouch, touches.contains(touch) else { return }
        if let c = draggedCritter {
            if !critterMoved {
                c.release()
                c.react()  // a tap (no real move) = a happy reaction
                critterDelightBurst(at: touchStartScene)
            } else {
                // Settle gently back to the ground, then resume wandering — never left floating.
                let groundY = soilLineY + critterGroundLift(c.kind) * bloomScale
                if abs(c.position.y - groundY) > 2 {
                    let fall = SKAction.moveTo(y: groundY, duration: 0.32)
                    fall.timingMode = .easeIn
                    let land = SKAction.sequence([
                        fall,
                        .moveBy(x: 0, y: 6 * bloomScale, duration: 0.08),
                        .moveBy(x: 0, y: -6 * bloomScale, duration: 0.12),
                        .run { [weak c] in c?.release() }
                    ])
                    c.run(land)
                } else {
                    c.release()
                }
                let landX = c.position.x + worldNode.position.x
                ParticleManager.softBurst(in: self, at: CGPoint(x: landX, y: groundY), color: WarmShelfPalette.sage, count: 4)
                AudioManager.shared.playBloomPlant()
            }
            draggedCritter = nil
            primaryTouch = nil
            return
        }
        if growingSeed != nil {
            finishSeedGrowth(atScene: touch.location(in: self))
            primaryTouch = nil
            return
        }
        handleTap(atScene: touchStartScene)
        primaryTouch = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        draggedCritter?.release()
        draggedCritter = nil
        cancelSeedGrowth(animated: true)
        if let touch = primaryTouch, touches.contains(touch) { primaryTouch = nil }
    }

    private func shouldBeginSeedGrowth(atScene point: CGPoint, world: CGPoint) -> Bool {
        guard world.x >= -20, world.x <= worldWidth + 20 else { return false }
        guard point.y >= soilLineY - 22, point.y <= size.height - 24 else { return false }

        if let sun = sunNode, hypot(sun.position.x - point.x, sun.position.y - point.y) < 74 {
            return false
        }

        if featureNear(world: world) != nil { return false }

        if let critter = critters.min(by: {
            hypot($0.position.x - world.x, ($0.position.y + 18 * bloomScale) - world.y) <
            hypot($1.position.x - world.x, ($1.position.y + 18 * bloomScale) - world.y)
        }), hypot(critter.position.x - world.x, (critter.position.y + 18 * bloomScale) - world.y) < 70 * bloomScale {
            return false
        }

        if world.y < soilLineY + 44 * bloomScale, let mole = moleNode,
           hypot(mole.position.x - world.x, mole.position.y - world.y) < 82 * bloomScale {
            return false
        }

        if nearestHead(toWorld: world) != nil { return false }
        return true
    }

    private func featureNear(world: CGPoint) -> BloomFeatureNode? {
        guard let feature = features.min(by: {
            hypot($0.position.x - world.x, ($0.position.y + 40 * bloomScale) - world.y) <
            hypot($1.position.x - world.x, ($1.position.y + 40 * bloomScale) - world.y)
        }) else { return nil }

        let distance = hypot(feature.position.x - world.x, (feature.position.y + 50 * bloomScale) - world.y)
        return distance < feature.tapRadius ? feature : nil
    }

    private func beginSeedGrowth(atScene point: CGPoint, world: CGPoint) {
        growingSeedWorldX = world.x.clamped(to: 14...(worldWidth - 14))
        growingSeedColor = gardenColors[colorIndex % gardenColors.count]
        growingSeedHeight = seedHeight(forScenePoint: point)
        seedDidStretch = false
        lastSeedStretchSound = 0

        let seed = GrowingSeedNode(color: growingSeedColor, scale: bloomScale)
        seed.position = CGPoint(x: growingSeedWorldX, y: soilLineY)
        seed.zPosition = 64
        seed.update(height: growingSeedHeight)
        worldNode.addChild(seed)
        growingSeed = seed

        dirtPuff(atWorldX: growingSeedWorldX)
        AudioManager.shared.playBloomPlant()   // haptic fires inside
    }

    private func updateSeedGrowth(atScene point: CGPoint) {
        let height = seedHeight(forScenePoint: point)
        guard abs(height - growingSeedHeight) > 1 else { return }

        growingSeedHeight = height
        growingSeed?.update(height: height)

        let now = CACurrentMediaTime()
        if seedDidStretch, now - lastSeedStretchSound > 0.18 {
            lastSeedStretchSound = now
            AudioManager.shared.playBloomStretch()
            // A soft tactile tick as the stem grows under the finger — you feel it stretch.
            HapticsManager.shared.impact(style: .soft, intensity: 0.16)
        }
    }

    private func finishSeedGrowth(atScene point: CGPoint) {
        let releaseHeight = seedHeight(forScenePoint: point)
        let finalHeight = max(releaseHeight, seedDidStretch ? minStem : minStem + 68 * bloomScale)
            .clamped(to: minStem...maxStem)
        growingSeed?.finishAndRemove()
        growingSeed = nil

        growPlant(
            atWorldX: growingSeedWorldX,
            stemHeight: finalHeight,
            silent: false,
            bloomsFromStem: true,
            forcedColor: growingSeedColor
        )
        gardenRespondsToNewBloom(atWorldX: growingSeedWorldX, stemHeight: finalHeight, color: growingSeedColor)
        AudioManager.shared.playBloomSettle()
        HapticsManager.shared.play(score: .bloomPlant)
    }

    private func cancelSeedGrowth(animated: Bool) {
        guard let growingSeed else { return }
        if animated {
            growingSeed.cancelAndRemove()
        } else {
            growingSeed.removeFromParent()
        }
        self.growingSeed = nil
    }

    private func seedHeight(forScenePoint point: CGPoint) -> CGFloat {
        (point.y - soilLineY).clamped(to: minStem * 0.65...maxStem)
    }

    private func handleTap(atScene point: CGPoint) {
        // The sun/moon is fixed in the sky — check it in scene space.
        if let sun = sunNode, hypot(sun.position.x - point.x, sun.position.y - point.y) < 70 {
            sun.run(.sequence([.scale(to: 1.12, duration: 0.16), .scale(to: 1.0, duration: 0.3)]))
            for index in 0..<8 {
                let ray = SKShapeNode(rectOf: CGSize(width: 3, height: 14), cornerRadius: 1.5)
                ray.fillColor = WarmShelfPalette.butter.withAlpha(0.7); ray.strokeColor = .clear
                ray.position = sun.position; ray.zPosition = -59
                let angle = CGFloat(index) / 8 * .pi * 2
                ray.zRotation = angle
                addChild(ray)
                let out = SKAction.moveBy(x: cos(angle) * 30, y: sin(angle) * 30, duration: 0.4)
                ray.run(.sequence([.group([out, .fadeOut(withDuration: 0.4)]), .removeFromParent()]))
            }
            AudioManager.shared.playBloomFlourish()   // haptic fires inside
            return
        }

        let world = CGPoint(x: point.x - worldNode.position.x, y: point.y)

        if let feature = features.min(by: { hypot($0.position.x - world.x, $0.position.y + 40 - world.y) < hypot($1.position.x - world.x, $1.position.y + 40 - world.y) }),
           hypot(feature.position.x - world.x, (feature.position.y + 50 * bloomScale) - world.y) < feature.tapRadius {
            let spawns = feature.poke(in: self)
            AudioManager.shared.playBloomCritter()   // haptic fires inside
            if spawns { spawnButterfly(nearWorldX: feature.position.x) }
            return
        }

        // A critter near the tap reacts (and takes priority over planting).
        if let critter = critters.min(by: {
            hypot($0.position.x - world.x, ($0.position.y + 18 * bloomScale) - world.y) <
            hypot($1.position.x - world.x, ($1.position.y + 18 * bloomScale) - world.y)
        }), hypot(critter.position.x - world.x, (critter.position.y + 18 * bloomScale) - world.y) < 64 * bloomScale {
            critter.react()
            critterDelightBurst(at: point)
            AudioManager.shared.playBloomCritter()   // haptic fires inside
            return
        }

        // Tap the dirt near the mole and it does a happy wiggle + a fresh molehill.
        if world.y < soilLineY + 40 * bloomScale, let mole = moleNode,
           hypot(mole.position.x - world.x, mole.position.y - world.y) < 80 * bloomScale {
            molePopUp(mole)
            AudioManager.shared.playBloomCritter()   // haptic fires inside
            return
        }

        if let flower = nearestHead(toWorld: world) {
            flower.cheer()
            ParticleManager.softBurst(in: self, at: point, color: WarmShelfPalette.butter, count: 4)
            HapticsManager.shared.softTap()
            return
        }

        let height = (world.y - soilLineY).clamped(to: minStem...maxStem)
        growPlant(atWorldX: world.x, stemHeight: height, silent: false)
    }

    private func growPlant(
        atWorldX x: CGFloat,
        stemHeight: CGFloat,
        silent: Bool,
        bloomsFromStem: Bool = false,
        forcedColor: UIColor? = nil
    ) {
        let clampedX = x.clamped(to: 14...(worldWidth - 14))
        let kind = BloomKind.random()
        let color = forcedColor ?? gardenColors[colorIndex % gardenColors.count]
        colorIndex += 1

        // Mushrooms are short and close to the ground — don't let them ride a tall stalk.
        let height = (kind == .mushroom) ? min(stemHeight, minStem + 22 * bloomScale) : stemHeight

        let bloom = BloomNode(kind: kind, color: color, scale: bloomScale * CGFloat.random(in: 0.9...1.12), stemHeight: height)
        bloom.position = CGPoint(x: clampedX, y: soilLineY)
        // Flowers live in a 30–50 band (taller plants sit behind), above soil/features,
        // below creatures (butterflies/critters) so those fly in front.
        bloom.zPosition = 50 - (height / maxStem) * 20
        bloom.userData = ["rx": clampedX / worldWidth]
        bloomsFromStem ? bloom.prepareToBloomFromStem() : bloom.prepareToGrow()
        worldNode.addChild(bloom)
        installBloomHeadShadow(for: bloom, visible: false)
        bloomsFromStem ? bloom.bloomFromStem() : bloom.grow()
        revealBloomHeadShadow(for: bloom, after: bloomsFromStem ? 0.04 : 0.24)
        blooms.append(bloom)
        totalBlooms += 1
        lifetimeBloomCount += 1
        dirtPuff(atWorldX: clampedX)

        if !silent {
            let now = CACurrentMediaTime()
            if now - lastPlantSound > 0.08 {
                lastPlantSound = now
                AudioManager.shared.playBloomPlant()   // haptic fires inside
            }
        }

        checkWiltThreshold()
        checkSeasonShift()
        checkFlourish()
    }

    private func gardenRespondsToNewBloom(atWorldX x: CGFloat, stemHeight: CGFloat, color: UIColor) {
        let headPoint = CGPoint(x: x + worldNode.position.x, y: soilLineY + stemHeight)

        if let critter = critters.min(by: { abs($0.position.x - x) < abs($1.position.x - x) }),
           abs(critter.position.x - x) < 170 * bloomScale {
            critter.react()
            let critterPoint = CGPoint(
                x: critter.position.x + worldNode.position.x,
                y: critter.position.y + 18 * bloomScale
            )
            ParticleManager.softBurst(in: self, at: critterPoint, color: color, count: 4)
        }

        if let sun = sunNode, stemHeight > maxStem * 0.52 {
            let glow = SKShapeNode(circleOfRadius: 32 * bloomScale)
            glow.fillColor = WarmShelfPalette.butter.withAlpha(0.22)
            glow.strokeColor = .clear
            glow.position = sun.position
            glow.zPosition = -58
            addChild(glow)
            glow.run(.sequence([
                .group([.scale(to: 2.0, duration: 0.48), .fadeOut(withDuration: 0.48)]),
                .removeFromParent()
            ]))
            sun.run(.sequence([.scale(to: 1.06, duration: 0.16), .scale(to: 1.0, duration: 0.26)]))
        }

        ParticleManager.softBurst(in: self, at: headPoint, color: color, count: 5)
        if totalBlooms.isMultiple(of: 4) || stemHeight > maxStem * 0.78 {
            spawnButterfly(nearWorldX: x)
        }
    }

    private func dirtPuff(atWorldX x: CGFloat) {
        for _ in 0..<5 {
            let speck = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.8...3.6) * bloomScale)
            speck.fillColor = UIColor(hex: 0x6E4B34).withAlpha(0.8)
            speck.strokeColor = .clear
            speck.position = CGPoint(x: x, y: soilLineY + 2)
            speck.zPosition = 55
            worldNode.addChild(speck)
            let angle = CGFloat.random(in: .pi * 0.15 ... .pi * 0.85)
            let dist = CGFloat.random(in: 14...30) * bloomScale
            let up = SKAction.moveBy(x: cos(angle) * dist, y: sin(angle) * dist, duration: 0.22)
            let down = SKAction.moveBy(x: cos(angle) * dist * 0.4, y: -sin(angle) * dist - 8, duration: 0.3)
            up.timingMode = .easeOut; down.timingMode = .easeIn
            speck.run(.sequence([up, .group([down, .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
        }
    }

    /// A direct tap on a critter earns a warm little burst of hearts and sparkle — the
    /// emotional payoff that makes a toddler feel the critter loved being touched.
    private func critterDelightBurst(at point: CGPoint) {
        ParticleManager.softBurst(in: self, at: point, color: WarmShelfPalette.butter, count: 5)
        guard !AmbientAnimator.reduceMotion else { return }
        let colors = [WarmShelfPalette.petal, WarmShelfPalette.rhubarb]
        for i in 0..<2 {
            let heart = SKShapeNode(path: Self.heartPath(size: CGFloat.random(in: 10...14) * bloomScale))
            heart.fillColor = colors[i % colors.count].withAlpha(0.92)
            heart.strokeColor = WarmShelfPalette.paperHighlight.withAlpha(0.5)
            heart.lineWidth = 1
            heart.position = CGPoint(x: point.x + CGFloat.random(in: -10...10), y: point.y + 8)
            heart.zPosition = 96
            heart.setScale(0.2)
            heart.zRotation = CGFloat.random(in: -0.2...0.2)
            addChild(heart)
            let pop = SKAction.scale(to: 1.0, duration: 0.18); pop.timingMode = .easeOut
            let rise = SKAction.moveBy(x: CGFloat.random(in: -16...16), y: 64 * bloomScale, duration: 1.05)
            rise.timingMode = .easeOut
            let sway = SKAction.sequence([
                .rotate(byAngle: 0.22, duration: 0.52), .rotate(byAngle: -0.22, duration: 0.52)
            ])
            heart.run(.sequence([
                pop,
                .group([rise, sway, .sequence([.wait(forDuration: 0.5), .fadeOut(withDuration: 0.55)])]),
                .removeFromParent()
            ]))
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

    private func nearestHead(toWorld world: CGPoint) -> BloomNode? {
        var best: BloomNode?
        // Generous radius — toddler fingers miss small targets and accidentally plant a new flower.
        var bestDist = 60 * bloomScale
        for bloom in blooms {
            let head = CGPoint(x: bloom.position.x, y: bloom.position.y + bloom.stemHeight)
            let d = hypot(head.x - world.x, head.y - world.y)
            if d < bestDist { best = bloom; bestDist = d }
        }
        return best
    }

    // MARK: - Life

    private func spawnButterfly(nearWorldX worldX: CGFloat) {
        // At most one butterfly at a time — a single quiet visitor, not a fluttering crowd.
        guard worldNode.children.filter({ $0.name == "butterfly" }).count < 1 else { return }
        let butterfly = makeButterfly(scale: bloomScale)
        butterfly.name = "butterfly"
        butterfly.position = CGPoint(x: worldX, y: soilLineY + 30 * bloomScale)
        butterfly.zPosition = 90
        worldNode.addChild(butterfly)
        flutter(butterfly, visitsLeft: Int.random(in: 3...5))
    }

    private func makeButterfly(scale: CGFloat) -> SKNode {
        let node = SKNode()
        let color = [WarmShelfPalette.petal, WarmShelfPalette.lavender, WarmShelfPalette.butter].randomElement()!
        let body = SKShapeNode(ellipseOf: CGSize(width: 4 * scale, height: 12 * scale))
        body.fillColor = WarmShelfPalette.cocoa.withAlpha(0.6); body.strokeColor = .clear
        node.addChild(body)
        for side in [-1.0, 1.0] {
            let wing = SKShapeNode(ellipseOf: CGSize(width: 16 * scale, height: 20 * scale))
            wing.fillColor = color.withAlpha(0.85); wing.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.05); wing.lineWidth = 1
            wing.position = CGPoint(x: CGFloat(side) * 9 * scale, y: 0)
            node.addChild(wing)
            if !AmbientAnimator.reduceMotion {
                wing.run(.repeatForever(.sequence([.scaleX(to: 0.4, y: 1, duration: 0.18), .scaleX(to: 1, y: 1, duration: 0.18)])))
            }
        }
        return node
    }

    private func flutter(_ butterfly: SKNode, visitsLeft: Int) {
        guard visitsLeft > 0, let target = blooms.randomElement() else {
            let exit = SKAction.move(to: CGPoint(x: butterfly.position.x + CGFloat.random(in: -60...60), y: size.height + 60), duration: 2.2)
            exit.timingMode = .easeIn
            butterfly.run(.sequence([exit, .removeFromParent()]))
            return
        }
        let dest = CGPoint(x: target.position.x, y: target.position.y + target.stemHeight + 14 * bloomScale)
        let fly = SKAction.move(to: dest, duration: Double.random(in: 1.4...2.2))
        fly.timingMode = .easeInEaseOut
        butterfly.run(.sequence([
            fly,
            .run { [weak target] in target?.cheer() },
            .wait(forDuration: Double.random(in: 0.6...1.2)),
            .run { [weak self, weak butterfly] in guard let self, let butterfly else { return }; self.flutter(butterfly, visitsLeft: visitsLeft - 1) }
        ]))
    }

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        syncBloomHeadShadows()
        let delta = lastUpdate == 0 ? 0 : currentTime - lastUpdate
        lastUpdate = currentTime

        // Fireflies come out at dusk and night.
        if (TimeOfDay.phase == .night || TimeOfDay.phase == .dusk), !blooms.isEmpty {
            fireflyAccumulator += delta
            if fireflyAccumulator > 1.4 { fireflyAccumulator = 0; spawnFirefly() }
        }
    }

    private func spawnFirefly() {
        guard worldNode.children.filter({ $0.name == "firefly" }).count < 6 else { return }
        guard let near = blooms.randomElement() else { return }
        let head = CGPoint(x: near.position.x, y: near.position.y + near.stemHeight)
        let fly = SKShapeNode(circleOfRadius: 3 * bloomScale)
        fly.name = "firefly"
        fly.fillColor = WarmShelfPalette.butter.withAlpha(0.9); fly.strokeColor = .clear; fly.glowWidth = 4
        fly.position = CGPoint(x: head.x + .random(in: -30...30), y: head.y + .random(in: -10...30))
        fly.alpha = 0; fly.zPosition = 92
        worldNode.addChild(fly)
        let drift = SKAction.moveBy(x: .random(in: -40...40), y: .random(in: 10...50), duration: 2.4)
        drift.timingMode = .easeInEaseOut
        let blink = SKAction.sequence([.fadeAlpha(to: 0.9, duration: 0.5), .fadeAlpha(to: 0.2, duration: 0.6), .fadeAlpha(to: 0.8, duration: 0.5), .fadeOut(withDuration: 0.8)])
        fly.run(.sequence([.group([drift, blink]), .removeFromParent()]))
    }

    private func wilt(bloom: BloomNode) {
        isWilting = true
        bloom.removeAction(forKey: "sway")

        // headNode is the child with zPosition == 5 — scale its petals inward and rotate.
        if let headNode = bloom.children.first(where: { $0.zPosition == 5 }) {
            let shrink = SKAction.scale(to: 0.3, duration: 6.0)
            let rotateToCentre = SKAction.rotate(toAngle: 0, duration: 6.0)
            shrink.timingMode = .easeInEaseOut
            rotateToCentre.timingMode = .easeInEaseOut
            headNode.run(.group([shrink, rotateToCentre]))
        }

        // Stem is the first SKShapeNode direct child — droop it gently.
        if let stemNode = bloom.children.first(where: { $0 is SKShapeNode }) {
            let droop = SKAction.rotate(byAngle: -0.3, duration: 6.0)
            droop.timingMode = .easeIn
            stemNode.run(droop)
        }

        // After the wilt animation, scale and fade the whole bloom then remove.
        let waitForWilt = SKAction.wait(forDuration: 6.0)
        let collapse = SKAction.group([
            .scale(to: 0.1, duration: 1.8),
            .fadeOut(withDuration: 1.8)
        ])
        collapse.timingMode = .easeIn
        bloomHeadShadows[ObjectIdentifier(bloom)]?.run(.sequence([
            .wait(forDuration: 6.0),
            .fadeOut(withDuration: 1.8)
        ]), withKey: "bloom.headShadow.wilt")
        bloom.run(.sequence([
            waitForWilt,
            collapse,
            .run { [weak self, weak bloom] in
                guard let self, let bloom else { return }
                self.removeBloomHeadShadow(for: bloom)
                bloom.removeFromParent()
                self.blooms.removeAll { $0 === bloom }
                self.isWilting = false
                self.checkWiltThreshold()
            }
        ]))
    }

    private func checkWiltThreshold() {
        guard !isWilting, blooms.count > 72 else { return }
        guard let oldest = blooms.first else { return }
        wilt(bloom: oldest)
    }

    private func checkSeasonShift() {
        let milestone = lifetimeBloomCount
        guard milestone == 20 || milestone == 40 || milestone == 60 || milestone == 80 else { return }

        // Audio: crossfade ambient to the new season character and ring the chime.
        let season: LullToneEngine.BloomSeason
        switch milestone {
        case 20: season = .summer
        case 40: season = .autumn
        case 60: season = .winter
        default: season = .spring   // 80 → back to spring
        }
        LullToneEngine.shared.transitionBloomAmbientToSeason(season)
        AudioManager.shared.playBloomSeasonChime(for: season)

        // Cycle through warm/cool tints based on milestone.
        let shiftIndex = milestone / 20  // 1, 2, 3, or 4
        let skyTints: [UIColor] = [
            UIColor(hue: 0.08, saturation: 0.28, brightness: 0.92, alpha: 1),   // warm amber
            UIColor(hue: 0.55, saturation: 0.22, brightness: 0.88, alpha: 1),   // cool blue
            UIColor(hue: 0.12, saturation: 0.32, brightness: 0.90, alpha: 1),   // golden
            UIColor(hue: 0.62, saturation: 0.18, brightness: 0.85, alpha: 1),   // dusk violet
        ]
        let soilTints: [UIColor] = [
            UIColor(hex: 0x7A5238),  // warmer
            UIColor(hex: 0x5E4B3A),  // cooler
            UIColor(hex: 0x7D5C3C),  // golden brown
            UIColor(hex: 0x5A4535),  // deep twilight
        ]
        let tintColor = skyTints[(shiftIndex - 1) % skyTints.count]
        let newSoil = soilTints[(shiftIndex - 1) % soilTints.count]

        // Subtle sky wash shift.
        let skyWash = SKSpriteNode(color: tintColor.withAlpha(0.12), size: CGSize(width: size.width, height: size.height))
        skyWash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        skyWash.zPosition = 0.8
        skyWash.alpha = 0
        skyLayer.addChild(skyWash)
        skyWash.run(.sequence([
            .fadeAlpha(to: 1.0, duration: 8.0),
            .wait(forDuration: 40.0),
            .fadeOut(withDuration: 8.0),
            .removeFromParent()
        ]))

        // Gently shift the soil layer's first child (the earth shape).
        soilTint = newSoil
        if let earth = soilLayer.children.first as? SKShapeNode {
            // SKShapeNode has no colorize action — overlay a sprite to blend the new tint.
            let overlay = SKSpriteNode(color: newSoil.withAlpha(0.94),
                                       size: CGSize(width: worldWidth + 80, height: soilLineY))
            overlay.anchorPoint = CGPoint(x: 0, y: 0)
            overlay.position = CGPoint(x: -40, y: 0)
            overlay.alpha = 0
            overlay.zPosition = earth.zPosition + 0.05
            soilLayer.addChild(overlay)
            overlay.run(.sequence([
                .fadeAlpha(to: 1.0, duration: 8.0),
                .run { earth.fillColor = newSoil.withAlpha(0.94); overlay.removeFromParent() }
            ]))
        }
    }

    private func checkFlourish() {
        let milestone = totalBlooms / 20
        guard milestone > 0, totalBlooms % 20 == 0, completedFlourishes.insert(milestone).inserted else { return }
        for (index, bloom) in blooms.enumerated() {
            bloom.run(.sequence([.wait(forDuration: Double(index % 12) * 0.03), .run { bloom.cheer() }]))
        }
        AudioManager.shared.playBloomFlourish()   // haptic fires inside
    }

    override func accessibilityElements(in view: SKView) -> [UIAccessibilityElement] {
        var elements = super.accessibilityElements(in: view)
        for feature in features {
            let scenePos = CGPoint(x: feature.position.x + worldNode.position.x, y: feature.position.y + 40 * bloomScale)
            guard scenePos.x > -40, scenePos.x < size.width + 40 else { continue }
            elements.append(makeActivatableAccessibilityElement(
                in: view,
                label: feature.accessibilityName,
                scenePosition: scenePos,
                size: CGSize(width: 120, height: 120),
                traits: .button
            ) { [weak self, weak feature] in
                guard let self, let feature else { return }
                let spawns = feature.poke(in: self)
                AudioManager.shared.playBloomCritter()
                if spawns { self.spawnButterfly(nearWorldX: feature.position.x) }
            })
        }
        for critter in critters {
            let scenePos = CGPoint(x: critter.position.x + worldNode.position.x, y: critter.position.y + 18 * bloomScale)
            guard scenePos.x > -40, scenePos.x < size.width + 40 else { continue }
            elements.append(makeActivatableAccessibilityElement(
                in: view,
                label: critter.accessibilityName,
                scenePosition: scenePos,
                size: CGSize(width: 90, height: 90),
                traits: .button
            ) { [weak self, weak critter] in
                guard let self, let critter else { return }
                critter.react()
                ParticleManager.softBurst(in: self, at: scenePos, color: WarmShelfPalette.petal, count: 4)
                AudioManager.shared.playBloomCritter()
            })
        }
        return elements
    }
}

private final class GrowingSeedNode: SKNode {
    private let scaleFactor: CGFloat
    private let color: UIColor
    private let stem = SKShapeNode()
    private let seed: SKShapeNode
    private let bud: SKShapeNode
    private let leafLeft: SKShapeNode
    private let leafRight: SKShapeNode
    private let halo: SKShapeNode

    init(color: UIColor, scale: CGFloat) {
        self.color = color
        self.scaleFactor = scale
        seed = SKShapeNode(ellipseOf: CGSize(width: 18 * scale, height: 12 * scale))
        bud = SKShapeNode(circleOfRadius: 9 * scale)
        leafLeft = SKShapeNode(ellipseOf: CGSize(width: 24 * scale, height: 11 * scale))
        leafRight = SKShapeNode(ellipseOf: CGSize(width: 24 * scale, height: 11 * scale))
        halo = SKShapeNode(circleOfRadius: 18 * scale)
        super.init()

        stem.strokeColor = WarmShelfPalette.sage.withAlpha(0.82)
        stem.lineWidth = max(3, 4.5 * scale)
        stem.lineCap = .round
        stem.fillColor = .clear
        stem.zPosition = 1
        addChild(stem)

        seed.fillColor = WarmShelfPalette.sand.withAlpha(0.96)
        seed.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.08)
        seed.lineWidth = 1
        seed.position = CGPoint(x: 0, y: 2 * scale)
        seed.zPosition = 3
        addChild(seed)

        for (leaf, side) in [(leafLeft, CGFloat(-1)), (leafRight, CGFloat(1))] {
            leaf.fillColor = WarmShelfPalette.sage.withAlpha(0.68)
            leaf.strokeColor = .clear
            leaf.zRotation = side * 0.46
            leaf.alpha = 0
            leaf.zPosition = 2
            addChild(leaf)
        }

        halo.fillColor = color.withAlpha(0.12)
        halo.strokeColor = .clear
        halo.alpha = 0.35
        halo.zPosition = 4
        addChild(halo)

        bud.fillColor = color.withAlpha(0.95)
        bud.strokeColor = WarmShelfPalette.paperHighlight.withAlpha(0.42)
        bud.lineWidth = max(1, 1.5 * scale)
        bud.zPosition = 5
        addChild(bud)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(height: CGFloat) {
        let h = max(8 * scaleFactor, height)
        let curve = sin(h / max(1, 120 * scaleFactor)) * 7 * scaleFactor
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addQuadCurve(
            to: CGPoint(x: curve, y: h),
            control: CGPoint(x: -curve * 0.55, y: h * 0.52)
        )
        stem.path = path

        let leafAlpha = ((h - 26 * scaleFactor) / max(1, 74 * scaleFactor)).clamped(to: 0...0.78)
        leafLeft.alpha = leafAlpha
        leafRight.alpha = leafAlpha
        leafLeft.position = CGPoint(x: -9 * scaleFactor, y: h * 0.42)
        leafRight.position = CGPoint(x: 9 * scaleFactor, y: h * 0.62)

        let budScale = (h / max(1, 96 * scaleFactor)).clamped(to: 0.56...1.16)
        bud.position = CGPoint(x: curve, y: h)
        bud.setScale(budScale)
        halo.position = bud.position
        halo.setScale((budScale * 0.9).clamped(to: 0.45...1.08))
    }

    func finishAndRemove() {
        removeAllActions()
        let fade = SKAction.fadeAlpha(to: 0, duration: 0.16)
        let soften = SKAction.scale(to: 1.04, duration: 0.16)
        run(.sequence([.group([fade, soften]), .removeFromParent()]))
    }

    func cancelAndRemove() {
        removeAllActions()
        let tuck = SKAction.group([
            .fadeOut(withDuration: 0.18),
            .scaleX(to: 1.0, y: 0.1, duration: 0.18)
        ])
        tuck.timingMode = .easeIn
        run(.sequence([tuck, .removeFromParent()]))
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
