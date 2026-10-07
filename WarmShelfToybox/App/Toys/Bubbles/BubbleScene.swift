import SpriteKit

final class BubbleScene: BaseToyScene {
    override var firstSessionHintKey: String? { "hint.bubbles" }
    override var toyVoice: AudioManager.LullSoundVoice { .bubbles }
    private var spawnAccumulator: TimeInterval = 0
    private var hasAuthoredRoom = false      // bubbles-room plate present this rebuild
    private weak var potNode: SKSpriteNode?  // the visible bubble source (art mode)
    private var lastSpawnX: CGFloat = -999   // anti-queue: weather never files in line
    private var bubbleLayer = SKNode()
    private var ambientLayer = SKNode()
    private var totalPopCount = 0
    private var trackedLiveBubbleCount = 0
    private var liveBubbles: [BubbleNode] = []
    private var quietMomentActive = false
    private var quietMomentStartTime: TimeInterval = 0
    private var lastMotherBubbleTime: TimeInterval = 0
    private var lastDeadBubblePrune: TimeInterval = 0
    private var maxLiveBubbles: Int {
        min(size.width, size.height) >= 700 ? 26 : 18
    }
    private struct BubbleSnapshot {
        let radius: CGFloat
        let style: BubbleStyle
        let xRatio: CGFloat
        let yRatio: CGFloat
        let alpha: CGFloat
        let zPosition: CGFloat
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        rebuildWorld()
        scheduleBubbleWeather()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        let snapshots = snapshotBubbles(oldSize: oldSize)
        rebuildWorld(preserving: snapshots)
    }

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        guard size.width > 120, size.height > 120 else { return }

        // Prune stale bubble references every 0.5s rather than every frame.
        if currentTime - lastDeadBubblePrune > 0.5 {
            lastDeadBubblePrune = currentTime
            pruneDeadBubbleReferences()
        }

        // O(n²) attraction only runs during quiet moments when bubbles need to cluster.
        // During normal play, SKAction drift handles ambient motion — running this at 120fps
        // for all 26 bubbles continuously is a needless thermal cost.
        if quietMomentActive {
            applyGentleBubbleAttraction()
        }

        if spawnAccumulator == 0 {
            spawnAccumulator = currentTime
        }
        if lastMotherBubbleTime == 0 {
            lastMotherBubbleTime = currentTime - 41
        }

        if quietMomentActive, currentTime - quietMomentStartTime > 1.15 {
            quietMomentActive = false
        }

        if !quietMomentActive, liveBubbleCount == 0, totalPopCount >= 8 {
            triggerQuietMoment(currentTime: currentTime)
            spawnAccumulator = currentTime
            return
        }

        let spawnInterval: TimeInterval = liveBubbleCount < 5 ? 0.22 : 0.54
        if !quietMomentActive, currentTime - spawnAccumulator > spawnInterval {
            spawnAccumulator = currentTime
            if liveBubbleCount < maxLiveBubbles {
                spawnBubble(fromBottom: true, forceMother: shouldSpawnMotherBubble(currentTime: currentTime), currentTime: currentTime)
            }
        }
    }

    private func rebuildWorld(preserving snapshots: [BubbleSnapshot] = []) {
        guard size.width > 120, size.height > 120 else { return }

        bubbleLayer.removeFromParent()
        ambientLayer.removeFromParent()
        trackedLiveBubbleCount = 0
        liveBubbles.removeAll()

        ambientLayer = SKNode()
        ambientLayer.zPosition = 0
        addChild(ambientLayer)

        bubbleLayer = SKNode()
        bubbleLayer.zPosition = 20
        addChild(bubbleLayer)

        // Warm Clay staging, revised (founder, June 11): our bubbles are 2D, so the
        // world behind them is WEATHER, not architecture — a soft air field by day, a
        // starred dusk after dark, following the household clock. The room plate stays
        // as fallback; the pot remains the visible source either way.
        hasAuthoredRoom = false
        potNode = nil
        let night = TimeOfDay.sky.isNight
        let isAirWorld = ToyArt.texture(night ? "bubbles-air-night" : "bubbles-air-day") != nil
        if let tex = ToyArt.texture(night ? "bubbles-air-night" : "bubbles-air-day")
                  ?? ToyArt.texture("bubbles-room") {
            hasAuthoredRoom = true
            let ts = tex.size()
            let plate = SKSpriteNode(texture: tex)
            let cover = max(size.width / max(1, ts.width), size.height / max(1, ts.height)) * 1.08
            plate.size = CGSize(width: ts.width * cover, height: ts.height * cover)
            plate.position = CGPoint(x: size.width / 2, y: size.height / 2)
            plate.zPosition = -10
            ambientLayer.addChild(plate)
        }
        // The pot belonged to the nursery; in the open air it read as furniture in the
        // sky (founder: "out of place, ugly"). Air world: bubbles are simply BORN of
        // the air below the screen — no machine, no source, just weather.
        if hasAuthoredRoom, !isAirWorld, let potTex = ToyArt.texture("bubbles-pot") {
            let isPadLikeCanvas = min(size.width, size.height) >= 700
            let potWidth = min(size.width * (isPadLikeCanvas ? 0.40 : 0.48), 420)
            let pot = SKSpriteNode(texture: potTex)
            pot.size = CGSize(width: potWidth, height: potWidth * potTex.size().height / max(1, potTex.size().width))
            pot.anchorPoint = CGPoint(x: 0.5, y: 0)
            pot.position = CGPoint(x: size.width / 2, y: -pot.size.height * 0.08)
            pot.zPosition = 12   // in front of the breath rings, behind every bubble
            ambientLayer.addChild(pot)
            potNode = pot
        }

        if hasAuthoredRoom {
            addNightTintIfNeeded()   // the authored room keeps the household's night
        } else {
            addWarmAirBands()
            addSceneVariance()
        }
        if isAirWorld {
            addDriftingClouds(night: night)
        }

        if snapshots.isEmpty {
            let isPadLikeCanvas = min(size.width, size.height) >= 700
            let initialCount = isPadLikeCanvas ? (size.width > size.height ? 20 : 22) : (size.width > size.height ? 14 : 16)
            for index in 0..<initialCount {
                spawnBubble(
                    fromBottom: false,
                    initialY: CGFloat(index) / CGFloat(max(1, initialCount - 1)) * size.height + CGFloat.random(in: -30...40)
                )
            }
            addOpeningBreathCue()
        } else {
            snapshots.forEach(restoreBubble)
        }

        quietMomentActive = false
    }

    /// The household's night veil — kept over authored art too (it sits in front of
    /// the z = -10 room plate by design); the daytime tint is dropped in art mode.
    private func addNightTintIfNeeded() {
        let sky = TimeOfDay.sky
        guard sky.isNight else { return }
        let tint = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        tint.fillColor = UIColor(hex: 0x2A3358).withAlpha(0.1)
        tint.strokeColor = .clear
        tint.zPosition = -3.5
        ambientLayer.addChild(tint)
    }

    /// Two felt clouds on their own slow errands — one behind the bubbles, one
    /// whisper-faint in front. The air world breathes even before anyone touches it.
    private func addDriftingClouds(night: Bool) {
        guard !AmbientAnimator.reduceMotion else { return }
        let specs: [(y: CGFloat, w: CGFloat, z: CGFloat, alpha: CGFloat, dur: Double)] = [
            (0.72, 0.42, -2, night ? 0.22 : 0.5, 95),
            (0.34, 0.26, 44, night ? 0.10 : 0.2, 140)
        ]
        for (i, s) in specs.enumerated() {
            guard let cloud = ToyArt.sprite("window-cloud",
                fit: CGSize(width: size.width * s.w, height: size.width * s.w * 0.62)) else { continue }
            cloud.alpha = s.alpha
            cloud.zPosition = s.z
            let y = size.height * s.y
            let startX = i == 0 ? -cloud.size.width : size.width + cloud.size.width
            cloud.position = CGPoint(x: startX, y: y)
            ambientLayer.addChild(cloud)
            let across = size.width + cloud.size.width * 2
            let dir: CGFloat = i == 0 ? 1 : -1
            cloud.run(.repeatForever(.sequence([
                .moveBy(x: dir * across, y: 0, duration: s.dur),
                .moveBy(x: -dir * across, y: 0, duration: 0)
            ])))
            // start mid-journey so the sky is never empty on arrival
            cloud.position.x = startX + dir * across * CGFloat.random(in: 0.2...0.7)
        }
    }

    /// The passenger: a tiny felt bird flutters free of a popped bubble and flies
    /// away — blink and you miss it, which is the point.
    private func releaseBubbleBird(from p: CGPoint) {
        let s: CGFloat = 11
        let dir: CGFloat = p.x > size.width / 2 ? -1 : 1   // fly toward the nearer edge
        let bird = SKNode()
        let flapper = SKNode()   // the visual — flaps + pops in, independent of facing & flight
        bird.addChild(flapper)
        let wing: SKNode?
        if let art = ToyArt.sprite("bubble-bird", fit: CGSize(width: s * 5.2, height: s * 5.2)) {
            art.zPosition = 0
            flapper.addChild(art)
            wing = nil
        } else {
            let body = SKShapeNode(ellipseOf: CGSize(width: s * 2.2, height: s * 1.6))
            body.fillColor = UIColor(hex: 0xC9836B)
            body.strokeColor = .clear
            flapper.addChild(body)
            let belly = SKShapeNode(ellipseOf: CGSize(width: s * 1.2, height: s * 0.9))
            belly.fillColor = UIColor(hex: 0xF2E0C8)
            belly.strokeColor = .clear
            belly.position = CGPoint(x: -s * 0.2, y: -s * 0.3)
            flapper.addChild(belly)
            let eye = SKShapeNode(circleOfRadius: s * 0.13)
            eye.fillColor = WarmShelfPalette.cocoa.withAlpha(0.85)
            eye.strokeColor = .clear
            eye.position = CGPoint(x: -s * 0.75, y: s * 0.25)
            flapper.addChild(eye)
            let wingNode = SKShapeNode(ellipseOf: CGSize(width: s * 1.2, height: s * 0.8))
            wingNode.fillColor = UIColor(hex: 0xB06A55)
            wingNode.strokeColor = .clear
            wingNode.position = CGPoint(x: s * 0.25, y: s * 0.15)
            flapper.addChild(wingNode)
            wing = wingNode
        }

        bird.position = p
        bird.zPosition = 60
        bird.xScale = dir        // FACE the way she flies (the art faces +x; left flips it)
        flapper.setScale(0.3)
        addChild(bird)

        // She pops free, then beats her wings away — the whole body flaps (the art has no
        // separate wing), so she reads as flying, never sliding.
        flapper.run(.scale(to: 1.0, duration: 0.16))
        if !AmbientAnimator.reduceMotion {
            flapper.run(.sequence([.wait(forDuration: 0.16),
                .repeatForever(.sequence([.scaleY(to: 0.84, duration: 0.09), .scaleY(to: 1.0, duration: 0.11)]))]))
            wing?.run(.repeatForever(.sequence([.scaleY(to: 0.45, duration: 0.07), .scaleY(to: 1.0, duration: 0.08)])))
        }

        // A natural arc: up and out on an easing glide, with a gentle flutter that fades —
        // and a hair of nose-up bank, instead of a straight diagonal slide.
        let startP = p
        let outX = dir * size.width * 0.58
        let climb = size.height * 0.46
        let dur = 1.9
        let fly = SKAction.customAction(withDuration: dur) { node, t in
            let k = CGFloat(t) / CGFloat(dur)
            let ease = 1 - pow(1 - k, 2.2)
            let flutter = CGFloat(sin(Double(k) * .pi * 5)) * (1 - k)
            node.position = CGPoint(x: startP.x + outX * ease, y: startP.y + climb * ease + flutter * 12)
            node.zRotation = flutter * 0.07
        }
        bird.run(.sequence([fly, .removeFromParent()]))
        bird.run(.sequence([.wait(forDuration: dur * 0.66), .fadeOut(withDuration: dur * 0.34)]))
        AudioManager.shared.playBird()
    }

    private func addOpeningBreathCue() {
        let center = CGPoint(x: size.width * 0.50, y: size.height * (size.width > size.height ? 0.48 : 0.42))
        for index in 0..<3 {
            let ring = SKShapeNode(circleOfRadius: CGFloat(30 + index * 18))
            ring.fillColor = .clear
            // Warm light over the authored room; the icy cyan stays for the bare mode.
            ring.strokeColor = (hasAuthoredRoom ? WarmShelfPalette.paperHighlight : WarmShelfPalette.bubbleHighlight).withAlpha(0.16)
            ring.lineWidth = max(1.2, min(size.width, size.height) * 0.002)
            ring.position = center
            ring.alpha = 0
            ring.zPosition = 6 + CGFloat(index)
            ambientLayer.addChild(ring)

            let grow = SKAction.scale(to: 1.65 + CGFloat(index) * 0.16, duration: 1.10 + Double(index) * 0.12)
            let fadeIn = SKAction.fadeAlpha(to: 0.72, duration: 0.16)
            let fadeOut = SKAction.fadeOut(withDuration: 0.88)
            grow.timingMode = .easeOut
            ring.run(.sequence([
                .wait(forDuration: 0.32 + Double(index) * 0.18),
                .group([grow, .sequence([fadeIn, fadeOut])]),
                .removeFromParent()
            ]))
        }
    }

    private var liveBubbleCount: Int { trackedLiveBubbleCount }

    private func snapshotBubbles(oldSize: CGSize) -> [BubbleSnapshot] {
        guard oldSize.width > 120, oldSize.height > 120 else { return [] }

        pruneDeadBubbleReferences()

        return liveBubbles.compactMap { bubble -> BubbleSnapshot? in
            guard !bubble.hasPopped else { return nil }

            return BubbleSnapshot(
                radius: bubble.radius,
                style: bubble.style,
                xRatio: (bubble.position.x / oldSize.width).clamped(to: 0...1),
                yRatio: (bubble.position.y / oldSize.height).clamped(to: -0.2...1.2),
                alpha: bubble.alpha,
                zPosition: bubble.zPosition
            )
        }
    }

    /// Subtle scene variety — a soft pool of light for depth, a few faint far-off bubbles drifting
    /// behind the play (parallax), and a whisper-soft tint of the time of day, so the open space
    /// feels authored and a little different each session without ever becoming busy.
    private func addSceneVariance() {
        let glow = SKShapeNode(ellipseOf: CGSize(width: size.width * 1.1, height: size.height * 0.72))
        glow.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.12)
        glow.strokeColor = .clear
        glow.blendMode = .add
        glow.position = CGPoint(x: size.width * 0.5, y: size.height * 0.66)
        glow.zPosition = -3
        ambientLayer.addChild(glow)

        let sky = TimeOfDay.sky
        if sky.lightTintAlpha > 0 || sky.isNight {
            let tint = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            tint.fillColor = (sky.isNight ? UIColor(hex: 0x2A3358) : sky.lightTint).withAlpha(sky.isNight ? 0.1 : sky.lightTintAlpha * 1.3)
            tint.strokeColor = .clear
            tint.zPosition = -3.5
            ambientLayer.addChild(tint)
        }

        guard !AmbientAnimator.reduceMotion else { return }
        for _ in 0..<6 {
            let far = SKShapeNode(circleOfRadius: CGFloat.random(in: 6...16))
            far.fillColor = WarmShelfPalette.bubbleHighlight.withAlpha(.random(in: 0.05...0.1))
            far.strokeColor = WarmShelfPalette.bubbleHighlight.withAlpha(0.08); far.lineWidth = 1
            far.position = CGPoint(x: .random(in: 0...size.width), y: .random(in: 0...size.height))
            far.zPosition = -1.5
            ambientLayer.addChild(far)
            AmbientAnimator.idleDrift(node: far, x: .random(in: -24...24), y: .random(in: -30...30), duration: .random(in: 9...15))
        }
    }

    private func addWarmAirBands() {
        for index in 0..<4 {
            let width = size.width * CGFloat.random(in: 0.36...0.72)
            let height = CGFloat.random(in: 46...92)
            let band = makeRoundedRect(
                size: CGSize(width: width, height: height),
                radius: height / 2,
                fill: (index.isMultiple(of: 2) ? WarmShelfPalette.paperHighlight : WarmShelfPalette.warmCream)
                    .withAlpha(.random(in: 0.08...0.14))
            )
            band.position = CGPoint(
                x: CGFloat.random(in: width / 2...max(width / 2, size.width - width / 2)),
                y: CGFloat(index + 1) / 5.0 * size.height
            )
            band.zPosition = -2
            ambientLayer.addChild(band)
            AmbientAnimator.idleDrift(
                node: band,
                x: CGFloat.random(in: -16...16),
                y: CGFloat.random(in: -8...12),
                duration: .random(in: 6.5...9.0)
            )
        }
    }

    /// Occasional surprises keep the same quiet frequency from the first touch onward.
    /// Playing longer never increases bird odds or shortens the mother-bubble interval.
    private let birdOdds = 12
    private let motherFloor: TimeInterval = 28

    private func shouldSpawnMotherBubble(currentTime: TimeInterval) -> Bool {
        let elapsed = currentTime - lastMotherBubbleTime
        guard elapsed > motherFloor else { return false }
        return elapsed > 40 || Double.random(in: 0...1) < 0.16
    }

    private func spawnBubble(
        fromBottom: Bool,
        initialY: CGFloat? = nil,
        forceMother: Bool = false,
        currentTime: TimeInterval? = nil
    ) {
        guard size.width > 120, size.height > 120 else { return }

        let maxRadius = min(CGFloat(92), max(CGFloat(42), size.width * 0.18))
        let style: BubbleStyle = forceMother ? .mother : BubbleStyle.random()
        let radius = forceMother ? min(maxRadius * 1.34, min(size.width, size.height) * 0.24) : CGFloat.random(in: 46...maxRadius)
        let displayRadius = style.isRare ? min(radius * (style.isMother ? 1.0 : 1.14), size.width * 0.25) : radius
        // (Founder, June 14: the falling-leaf/seed cargo read ugly — removed. A little
        // bird fluttering free on a special pop will replace it once its art lands.)
        let bubble = BubbleNode(radius: displayRadius, style: style)
        bubble.alpha = CGFloat.random(in: 0.90...1.0)

        let minX = displayRadius
        let maxX = max(minX, size.width - displayRadius)
        var spawnX = CGFloat.random(in: minX...maxX)
        // Bubbles are weather, not a queue: one re-roll breaks up single-file flows.
        if abs(spawnX - lastSpawnX) < displayRadius * 1.5 {
            spawnX = CGFloat.random(in: minX...maxX)
        }
        lastSpawnX = spawnX
        var spawnY = initialY ?? -displayRadius - CGFloat.random(in: 0...120)
        if fromBottom, initialY == nil, let pot = potNode {
            // Bubbles rise from the pot's mouth — "where bubbles come from" made visible.
            let rimY = pot.position.y + pot.size.height * 0.70
            spawnX = (size.width * 0.5 + CGFloat.random(in: -pot.size.width * 0.16 ... pot.size.width * 0.16))
                .clamped(to: minX...maxX)
            spawnY = rimY - displayRadius * 0.3 + CGFloat.random(in: -10...14)
        }
        bubble.position = CGPoint(x: spawnX, y: spawnY)
        bubble.zPosition = CGFloat.random(in: 10...40)
        trackBubbleLifecycle(bubble)
        bubbleLayer.addChild(bubble)
        if style.isMother, let currentTime {
            lastMotherBubbleTime = currentTime
            AmbientAnimator.breathe(node: bubble, scale: 1.055, duration: 2.7, delay: 0)
            TouchFeedbackAnimator.tactileSpark(in: self, at: bubble.position, color: style.popColor, count: 5, includesRipple: true)
        }

        beginDrift(for: bubble)
    }

    private func restoreBubble(_ snapshot: BubbleSnapshot) {
        guard size.width > 120, size.height > 120 else { return }

        let maxRadius = min(CGFloat(92), max(CGFloat(42), size.width * 0.18))
        let radius = min(snapshot.radius, maxRadius)
        let bubble = BubbleNode(radius: radius, style: snapshot.style)
        bubble.alpha = snapshot.alpha
        bubble.position = CGPoint(
            x: (size.width * snapshot.xRatio).clamped(to: radius...(size.width - radius)),
            y: size.height * snapshot.yRatio
        )
        bubble.zPosition = snapshot.zPosition
        trackBubbleLifecycle(bubble)
        bubbleLayer.addChild(bubble)

        beginDrift(for: bubble)
    }

    private func trackBubbleLifecycle(_ bubble: BubbleNode) {
        liveBubbles.append(bubble)
        trackedLiveBubbleCount = liveBubbles.count
        bubble.onPopped = { [weak self, weak bubble] in
            guard let self, let bubble else { return }
            self.unregisterBubble(bubble)
        }
    }

    private func unregisterBubble(_ bubble: BubbleNode) {
        liveBubbles.removeAll { $0 === bubble || $0.parent == nil || $0.hasPopped }
        trackedLiveBubbleCount = liveBubbles.count
    }

    private func pruneDeadBubbleReferences() {
        liveBubbles.removeAll { $0.parent == nil || $0.hasPopped }
        trackedLiveBubbleCount = liveBubbles.count
    }

    private func beginDrift(for bubble: BubbleNode) {
        let displayRadius = bubble.radius
        let style = bubble.style
        let upwardDistance = max(displayRadius * 3, size.height - bubble.position.y + displayRadius * 3)
        let profile = style.isRare ? ToyPhysicsProfile.rareBubble : ToyPhysicsProfile.bubble
        let radiusWeight = (displayRadius / 56).clamped(to: 0.78...1.45)
        let distanceWeight = (upwardDistance / max(size.height, 1)).clamped(to: 0.45...1.4)
        let motherWeight: CGFloat = style.isMother ? 1.24 : 1.0
        let duration = Double.random(in: WarmShelfMotion.bubbleFloat) * TimeInterval(radiusWeight * distanceWeight * motherWeight)
        let driftX = CGFloat.random(in: -52...52) * profile.driftDamping * (style.isMother ? 0.65 : 1.0)
        let move = SKAction.moveBy(x: driftX, y: upwardDistance, duration: duration)
        let fadeIn = SKAction.fadeAlpha(to: bubble.alpha, duration: 0.4)
        let retire = SKAction.run { [weak self, weak bubble] in
            guard let self, let bubble, !bubble.hasPopped else { return }
            bubble.onPopped = nil
            self.unregisterBubble(bubble)
            bubble.removeFromParent()
        }
        move.timingMode = .easeInEaseOut

        bubble.alpha = 0
        bubble.run(.group([fadeIn, .sequence([move, retire])]))
        AmbientAnimator.wobble(node: bubble, amount: CGFloat.random(in: 0.025...0.09), duration: .random(in: 2.3...4.8))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        HapticsManager.shared.prepareForTouch()

        for touch in touches {
            let point = touch.location(in: self)

            if consumeShelfReturnTouch(at: point) {
                return
            }

            if let bubble = topBubble(at: point) {
                let isMother = bubble.isMotherBubble
                let popPoint = bubble.convert(CGPoint.zero, to: self)
                AudioManager.shared.updateSoundPosition(
                    nodeID: "bubble.\(ObjectIdentifier(bubble).hashValue)",
                    screenPoint: popPoint,
                    sceneSize: size
                )
                let wasBig = bubble.radius > 64
                if bubble.pop(in: self) {
                    registerPop()
                    if isMother {
                        releaseBabyBubbles(from: popPoint, color: bubble.style.popColor)
                        // Only the mother sends a pressure wave — one tap, one pop,
                        // is the everyday truth (founder: cascades on every tap read
                        // wrong). Her burst staying special is what makes it special.
                        chainPop(near: popPoint, excluding: bubble)
                    }
                    // A passenger bird occasionally joins a large pop, at fixed odds.
                    if wasBig, !isMother, Int.random(in: 0..<birdOdds) == 0 {
                        releaseBubbleBird(from: popPoint)
                    }
                }
            } else {
                TouchFeedbackAnimator.emptyTap(in: self, at: point)
            }
        }
    }

    /// A visible pressure wave reaches the closest neighbours before they pop, keeping
    /// the cascade surprising while preserving clear physical cause-and-effect.
    private func chainPop(near point: CGPoint, excluding: BubbleNode) {
        pruneDeadBubbleReferences()
        var candidates: [(bubble: BubbleNode, dist: CGFloat)] = []
        for bubble in liveBubbles {
            if bubble.hasPopped || bubble === excluding { continue }
            let dist = hypot(bubble.position.x - point.x, bubble.position.y - point.y)
            // Wider chain radius so cascades feel surprising rather than accidental.
            if dist < bubble.radius * 0.7 + 120 {
                candidates.append((bubble, dist))
            }
        }
        candidates.sort { $0.dist < $1.dist }
        for pair in candidates.prefix(2) {
            let b: BubbleNode = pair.bubble
            let popDelay = 0.08 + TimeInterval(pair.dist / 520)
            let anticipationDelay = max(0.02, popDelay - 0.13)
            run(.sequence([
                .wait(forDuration: anticipationDelay),
                .run { [weak b] in b?.receivePressureWave(from: point) },
                .wait(forDuration: popDelay - anticipationDelay),
                .run { [weak self, weak b] in
                    guard let self, let b, !b.hasPopped else { return }
                    if b.pop(in: self) { self.registerPop() }
                }
            ]))
        }
    }

    private func applyGentleBubbleAttraction() {
        let bubbles = liveBubbles
        guard bubbles.count > 1 else { return }

        for bubble in bubbles {
            var forceX: CGFloat = 0
            var forceY: CGFloat = 0

            for other in bubbles where other !== bubble {
                let dx = other.position.x - bubble.position.x
                let dy = other.position.y - bubble.position.y
                let distance = hypot(dx, dy)
                guard distance > 20, distance < 180 else { continue }

                let baseStrength: CGFloat = bubble.isMotherBubble || other.isMotherBubble ? 0.08 : 0.22
                let strength = baseStrength * ((180 - distance) / 180)
                forceX += (dx / distance) * strength
                forceY += (dy / distance) * strength
            }

            bubble.position.x += forceX.clamped(to: -0.42...0.42)
            bubble.position.y += forceY.clamped(to: -0.28...0.28)
        }
    }

    private func releaseBabyBubbles(from scenePoint: CGPoint, color: UIColor) {
        let count = Int.random(in: 7...8)
        for index in 0..<count {
            let baby = BubbleNode(radius: CGFloat.random(in: 18...30), style: BubbleStyle.preview(index: index))
            baby.position = scenePoint
            baby.alpha = 0
            baby.setScale(0.62)
            baby.zPosition = CGFloat(64 + index)
            trackBubbleLifecycle(baby)
            bubbleLayer.addChild(baby)

            let angle = CGFloat(index) / CGFloat(count) * .pi * 2 + CGFloat.random(in: -0.36...0.36)
            let distance = CGFloat.random(in: 48...102)
            let burst = SKAction.moveBy(
                x: cos(angle) * distance,
                y: sin(angle) * distance - CGFloat.random(in: 8...28),
                duration: Double.random(in: 0.58...0.82)
            )
            burst.timingMode = .easeOut
            baby.run(.sequence([
                .group([
                    .fadeAlpha(to: CGFloat.random(in: 0.88...0.98), duration: 0.22),
                    .scale(to: 1.0, duration: 0.22),
                    burst
                ]),
                .run { [weak self, weak baby] in
                    guard let self, let baby, baby.parent != nil else { return }
                    self.beginDrift(for: baby)
                }
            ]))
            AmbientAnimator.wobble(node: baby, amount: CGFloat.random(in: 0.035...0.07), duration: Double.random(in: 2.0...3.4))
        }

        // The baby bubbles are the event; particles only underline their emergence.
        ParticleManager.softBurst(in: self, at: scenePoint, color: color, count: 10)
        ParticleManager.softBurst(in: self, at: scenePoint, color: WarmShelfPalette.paperHighlight, count: 6)
        HapticsManager.shared.bubblePop(size: 120, isRare: true)
        AudioManager.shared.playBubbleBreath()
    }

    private func topBubble(at point: CGPoint) -> BubbleNode? {
        pruneDeadBubbleReferences()
        return liveBubbles
            .filter { !$0.hasPopped && $0.containsScenePoint(point) }
            .sorted { $0.zPosition > $1.zPosition }
            .first
    }

    // No visible counter or score — Lull's promise. The pop count only gates the quiet
    // moment; it never earns anything. Bubble rain is WEATHER: it drifts in on its own
    // gentle clock, the same whether the child popped two bubbles or two hundred —
    // delight without a meter behind it.
    private func registerPop() {
        totalPopCount += 1
    }

    private func scheduleBubbleWeather() {
        removeAction(forKey: "bubbleWeather")
        run(.sequence([
            .wait(forDuration: .random(in: 80...140)),
            .run { [weak self] in
                guard let self else { return }
                self.triggerBubbleRain(styles: [.pearl, .water, .butter], count: Int.random(in: 10...13))
                self.scheduleBubbleWeather()
            }
        ]), withKey: "bubbleWeather")
    }

    private func triggerBubbleRain(styles: [BubbleStyle], count: Int) {
        guard size.width > 120, size.height > 120 else { return }

        for index in 0..<count {
            let delay = Double(index) * 0.045
            run(.sequence([
                .wait(forDuration: delay),
                .run { [weak self] in
                    guard let self else { return }
                    let style = styles.randomElement() ?? .pearl
                    let radius = CGFloat.random(in: 22...46)
                    let bubble = BubbleNode(radius: radius, style: style)
                    bubble.alpha = CGFloat.random(in: 0.84...0.98)
                    bubble.position = CGPoint(
                        x: CGFloat.random(in: radius...(self.size.width - radius)),
                        y: self.size.height + radius + CGFloat.random(in: 0...60)
                    )
                    bubble.zPosition = CGFloat.random(in: 28...54)
                    self.trackBubbleLifecycle(bubble)
                    self.bubbleLayer.addChild(bubble)

                    let drift = SKAction.moveBy(
                        x: CGFloat.random(in: -34...34),
                        y: -self.size.height * CGFloat.random(in: 0.34...0.56),
                        duration: Double.random(in: 4.8...6.8)
                    )
                    drift.timingMode = .easeInEaseOut
                    bubble.run(.sequence([drift, .run { [weak self, weak bubble] in
                        guard let self, let bubble else { return }
                        self.beginDrift(for: bubble)
                    }]))
                    AmbientAnimator.wobble(node: bubble, amount: 0.045, duration: Double.random(in: 2.2...3.8))
                }
            ]))
        }

        HapticsManager.shared.softTap()
        AudioManager.shared.playBubbleBreath()
    }

    private func triggerQuietMoment(currentTime: TimeInterval) {
        guard !quietMomentActive else { return }
        quietMomentActive = true
        quietMomentStartTime = currentTime

        let point = CGPoint(x: size.width / 2, y: size.height * 0.44)
        ParticleManager.softRipple(in: self, at: point, color: WarmShelfPalette.bubbleRim)

        run(.sequence([
            .wait(forDuration: 0.56),
            .run { [weak self] in
                guard let self else { return }
                let radius = min(max(self.size.width * 0.16, 56), 112)
                let style: BubbleStyle = [.pearl, .water, .blush].randomElement() ?? .pearl
                let bubble = BubbleNode(radius: radius, style: style)
                bubble.alpha = 0
                bubble.position = CGPoint(x: self.size.width / 2, y: self.size.height * 0.36)
                bubble.zPosition = 62
                self.trackBubbleLifecycle(bubble)
                self.bubbleLayer.addChild(bubble)

                let appear = SKAction.group([
                    .fadeAlpha(to: 0.98, duration: 0.40),
                    .scale(to: 1.04, duration: 0.40)
                ])
                appear.timingMode = .easeOut
                bubble.setScale(0.72)
                bubble.run(.sequence([
                    appear,
                    .run { [weak self, weak bubble] in
                        guard let self, let bubble else { return }
                        self.quietMomentActive = false
                        self.beginDrift(for: bubble)
                    }
                ]))
                AudioManager.shared.playBubbleBreath()
            }
        ]))
    }

    override func accessibilityElements(in view: SKView) -> [UIAccessibilityElement] {
        var elements = super.accessibilityElements(in: view)
        pruneDeadBubbleReferences()
        let bubbles = liveBubbles
            .filter { !$0.hasPopped }
            .sorted { $0.zPosition > $1.zPosition }
            .prefix(8)

        elements.append(contentsOf: bubbles.map { bubble in
            let popPoint = bubble.convert(CGPoint.zero, to: self)
            return makeActivatableAccessibilityElement(
                in: view,
                label: bubble.isRare ? "rare bubble — tap to pop" : "bubble — tap to pop",
                scenePosition: bubble.position,
                size: CGSize(width: bubble.radius * 2.4, height: bubble.radius * 2.4),
                traits: .button
            ) { [weak self, weak bubble] in
                guard let self, let bubble, !bubble.hasPopped else { return }
                let isMother = bubble.isMotherBubble
                if bubble.pop(in: self) {
                    self.registerPop()
                    if isMother {
                        self.releaseBabyBubbles(from: popPoint, color: bubble.style.popColor)
                        self.chainPop(near: popPoint, excluding: bubble)
                    }
                }
            }
        })

        return elements
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
