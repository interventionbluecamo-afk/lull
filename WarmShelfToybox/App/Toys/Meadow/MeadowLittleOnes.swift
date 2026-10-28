import SpriteKit

// Find the little ones (founder, October 11). Five baby ladybugs hide around the meadow,
// peeking from under leaves. When she walks near one, it pops out and joins a little parade
// that follows in her steps, hopping between her flowers (never squashing or re-blooming
// them). She leads them home to a leaf house in the home garden; each one hops in and the
// house glows warmer. No counter, no timer, no way to fail. New hiding places each visit.

// MARK: - The model (no SpriteKit, so it can be checked off-device)

/// A small, seedable random source, so a visit's hiding places survive a rotation rebuild.
struct MeadowSeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A value in 0..<1.
    mutating func unit() -> CGFloat { CGFloat(next() >> 11) / CGFloat(UInt64(1) << 53) }
}

struct MeadowLittleOnesModel {
    enum Place: Equatable { case hidden, following, home }

    static let count = 5
    /// How close she must pass for a little one to notice her and join.
    static let findRadius: CGFloat = 64
    /// Spacing between little ones along her path.
    static let paradeGap: CGFloat = 30
    /// How close to the leaf house brings the parade home.
    static let houseRadius: CGFloat = 70
    /// Within this of a flower, a little one hops up and steps aside so the flower is never squashed.
    static let flowerClearance: CGFloat = 16
    private static let trailStep: CGFloat = 4

    struct Snapshot: Equatable {
        var spots: [CGPoint]
        var places: [Place]
        var parade: [Int]
        var house: CGPoint
        var trail: [CGPoint] = []
        var paradeSpacing: CGFloat = MeadowLittleOnesModel.paradeGap
    }

    private(set) var spots: [CGPoint]
    private(set) var places: [Place]
    /// Little ones following her, in the order they joined (first = right behind her).
    private(set) var parade: [Int] = []
    let house: CGPoint
    let paradeSpacing: CGFloat
    /// Her recent path, newest last, long enough for the whole parade.
    private(set) var trail: [CGPoint] = []

    var homeCount: Int { places.filter { $0 == .home }.count }
    var allHome: Bool { homeCount == Self.count }
    /// The house appears once the first little one has been found.
    var houseVisible: Bool { places.contains { $0 != .hidden } }
    var snapshot: Snapshot { Snapshot(spots: spots, places: places, parade: parade, house: house, trail: trail, paradeSpacing: paradeSpacing) }

    init(worldSize: CGSize, homeRadius: CGFloat, avoid: [CGPoint], seed: UInt64, paradeSpacing: CGFloat = Self.paradeGap) {
        self.paradeSpacing = max(Self.paradeGap, paradeSpacing)
        spots = Self.hidingSpots(worldSize: worldSize, homeRadius: homeRadius, avoid: avoid, seed: seed)
        places = Array(repeating: .hidden, count: spots.count)
        house = Self.housePosition(homeRadius: homeRadius)
    }

    init(restoring snapshot: Snapshot) {
        spots = snapshot.spots
        places = snapshot.places
        parade = snapshot.parade
        house = snapshot.house
        trail = snapshot.trail
        paradeSpacing = snapshot.paradeSpacing
    }

    /// Called as she walks. Returns the little ones that just joined, and those that just
    /// went into the house (in parade order).
    mutating func motherMoved(to p: CGPoint) -> (found: [Int], arrived: [Int]) {
        guard p.x.isFinite, p.y.isFinite else { return ([], []) }
        // Sample distance, not frames: equal spacing at 30, 60 and 120 Hz.
        let capacity = Int(CGFloat(Self.count + 1) * paradeSpacing / Self.trailStep) + 8
        if let last = trail.last {
            let distance = hypot(p.x - last.x, p.y - last.y)
            let steps = Int(distance / Self.trailStep)
            if steps > 0 {
                for step in max(1, steps - capacity + 1)...steps {
                    let t = CGFloat(step) * Self.trailStep / distance
                    trail.append(CGPoint(x: last.x + (p.x - last.x) * t, y: last.y + (p.y - last.y) * t))
                }
            }
        } else { trail.append(p) }
        if trail.count > capacity { trail.removeFirst(trail.count - capacity) }

        var found: [Int] = []
        for i in places.indices where places[i] == .hidden
            && hypot(spots[i].x - p.x, spots[i].y - p.y) < Self.findRadius {
            places[i] = .following
            parade.append(i)
            found.append(i)
        }
        var arrived: [Int] = []
        if !parade.isEmpty, hypot(p.x - house.x, p.y - house.y) < Self.houseRadius {
            arrived = parade
            for i in parade { places[i] = .home }
            parade.removeAll()
        }
        return (found, arrived)
    }

    /// Where the k-th follower walks: along her own path, `paradeGap` apart. A path shorter
    /// than the parade bunches them gently at its start.
    func paradePoint(_ k: Int, mother: CGPoint) -> CGPoint {
        let want = CGFloat(k + 1) * paradeSpacing
        var travelled: CGFloat = 0
        var previous = mother
        for point in trail.reversed() {
            let segment = hypot(previous.x - point.x, previous.y - point.y)
            if segment > 0, travelled + segment >= want {
                let t = (want - travelled) / segment
                return CGPoint(x: previous.x + (point.x - previous.x) * t,
                               y: previous.y + (point.y - previous.y) * t)
            }
            travelled += segment
            previous = point
        }
        return previous
    }

    /// Near a flower, a little one lifts (0...1) and steps sideways away from it, so it hops
    /// over and between the flowers instead of sitting on one.
    static func flowerHop(at p: CGPoint, flowers: [CGPoint]) -> (lift: CGFloat, nudge: CGVector) {
        var nearest: CGPoint?
        var best = flowerClearance
        for flower in flowers {
            let d = hypot(flower.x - p.x, flower.y - p.y)
            if d < best { best = d; nearest = flower }
        }
        guard let flower = nearest else { return (0, .zero) }
        let lift = 1 - best / flowerClearance
        let away = best > 0.001 ? CGVector(dx: (p.x - flower.x) / best, dy: (p.y - flower.y) / best)
                                : CGVector(dx: 0, dy: 1)
        let push = (flowerClearance - best) * 0.5
        return (lift, CGVector(dx: away.dx * push, dy: away.dy * push))
    }

    /// Spread-out places beyond the home garden (and beyond her first-visit wander), away
    /// from the landmarks and from each other, never at the world's edge.
    static func hidingSpots(worldSize: CGSize, homeRadius: CGFloat, avoid: [CGPoint], seed: UInt64) -> [CGPoint] {
        var random = MeadowSeededRandom(seed: seed)
        let half = min(worldSize.width, worldSize.height) / 2
        let inner = max(homeRadius * 1.6, half * 0.36)
        let outer = max(inner + 1, half * 0.8)
        var minApart = half * 0.3
        var spots: [CGPoint] = []
        var attempts = 0
        while spots.count < count {
            attempts += 1
            if attempts % 600 == 0 { minApart *= 0.8 }   // a crowded world relaxes, never stalls
            let angle = random.unit() * .pi * 2
            let radius = inner + (outer - inner) * random.unit().squareRoot()
            let p = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            let clearOfLandmarks = avoid.allSatisfy { hypot($0.x - p.x, $0.y - p.y) >= 110 }
            let apart = spots.allSatisfy { hypot($0.x - p.x, $0.y - p.y) >= minApart }
            guard attempts > 20_000 || (clearOfLandmarks && (apart || attempts > 6000)) else { continue }
            spots.append(p)
        }
        return spots
    }

    /// The leaf house stands in the home garden, beside (not on) her starting place.
    static func housePosition(homeRadius: CGFloat) -> CGPoint {
        CGPoint(x: homeRadius * 0.62, y: homeRadius * 0.5)
    }
}

/// Frame-rate-independent following, with a speed cap when a new baby joins far away.
struct MeadowFollowerMotion: Equatable {
    var position: CGPoint
    var heading: CGFloat = 0
    var lift: CGFloat = 0

    mutating func step(toward target: CGPoint, hop: CGFloat, dt: TimeInterval) {
        guard dt.isFinite, dt > 0, target.x.isFinite, target.y.isFinite else { return }
        let elapsed = CGFloat(min(dt, 0.05))
        let dx = target.x - position.x, dy = target.y - position.y
        let distance = hypot(dx, dy)
        let fraction = min(1 - exp(-12 * elapsed), 280 * elapsed / max(distance, 0.001))
        position.x += dx * fraction
        position.y += dy * fraction
        if distance > 0.5 {
            let turn = atan2(sin(atan2(dy, dx) - heading), cos(atan2(dy, dx) - heading))
            heading += turn * (1 - exp(-8 * elapsed))
        }
        lift += (max(0, min(1, hop)) - lift) * (1 - exp(-10 * elapsed))
    }
}

// MARK: - The little ones on screen

/// What the scene should answer with sound and touch.
struct MeadowLittleOnesEvents {
    var found = 0
    var arrived = 0
    var allHome = false
}

final class MeadowLittleOnesNode: SKNode {
    private(set) var model: MeadowLittleOnesModel
    private let babySize: CGFloat
    private let night: Bool
    private var babies: [SKNode] = []
    private var babyBodies: [SKNode] = []
    private var leaves: [SKNode] = []
    private let house = SKNode()
    private var houseGlow: SKNode?
    private var finaleDone: Bool
    private var motions: [MeadowFollowerMotion] = []
    struct Snapshot {
        let model: MeadowLittleOnesModel.Snapshot
        let followers: [MeadowFollowerMotion]
    }
    var snapshot: Snapshot {
        Snapshot(model: model.snapshot, followers: babies.indices.map {
            MeadowFollowerMotion(position: babies[$0].position, heading: babies[$0].zRotation, lift: motions[$0].lift)
        })
    }

    init(model: MeadowLittleOnesModel, babySize: CGFloat, houseSize: CGFloat, night: Bool, restoring followers: [MeadowFollowerMotion]? = nil) {
        self.model = model
        self.babySize = babySize
        self.night = night
        finaleDone = model.allHome
        super.init()
        buildHouse(size: houseSize)
        for i in 0..<model.spots.count { buildBaby(i) }
        settle()
        motions = babies.map { MeadowFollowerMotion(position: $0.position, heading: $0.zRotation) }
        if let followers, followers.count == babies.count {
            motions = followers
            for i in model.parade { applyMotion(i) }
        }
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Build

    private func buildHouse(size: CGFloat) {
        house.position = model.house
        house.zPosition = 0.2
        let fit = CGSize(width: size, height: size)
        if let art = ToyArt.sprite("meadow-leaf-house", fit: fit) {
            house.addChild(art)
            if let glow = ToyArt.sprite("meadow-leaf-house-glow", fit: fit) {
                glow.alpha = 0
                house.addChild(glow)
                houseGlow = glow
            }
        } else {
            // Stand-in until the felt art lands: a curled sage leaf with a round, dark door.
            let w = size * 0.8, h = size * 0.62
            let dome = SKShapeNode(path: CGPath(ellipseIn: CGRect(x: -w / 2, y: -h * 0.42, width: w, height: h), transform: nil))
            dome.strokeColor = UIColor(hex: 0x5E7A4E).withAlphaComponent(0.5)
            dome.lineWidth = 2
            ProceduralTexture.applyClayFill(to: dome, base: UIColor(hex: night ? 0x56704F : 0x8FAE74), size: CGSize(width: w, height: h))
            house.addChild(dome)
            let vein = SKShapeNode(rectOf: CGSize(width: 2, height: h * 0.7), cornerRadius: 1)
            vein.fillColor = UIColor(hex: 0x6E8E5C).withAlphaComponent(0.6)
            vein.strokeColor = .clear
            vein.position = CGPoint(x: -w * 0.18, y: h * 0.08)
            vein.zRotation = 0.35
            house.addChild(vein)
            let door = SKShapeNode(ellipseOf: CGSize(width: w * 0.3, height: h * 0.42))
            door.fillColor = UIColor(hex: 0x3B2A1E)
            door.strokeColor = UIColor(hex: 0xC9A46A).withAlphaComponent(0.7)
            door.lineWidth = 2
            door.position = CGPoint(x: w * 0.12, y: -h * 0.08)
            house.addChild(door)
            let light = SKShapeNode(ellipseOf: CGSize(width: w * 0.24, height: h * 0.34))
            light.fillColor = UIColor(hex: 0xFFC979)
            light.strokeColor = .clear
            light.position = door.position
            light.alpha = 0
            house.addChild(light)
            houseGlow = light
        }
        let shadow = SKSpriteNode(texture: ProceduralTexture.softClayShadow(size: CGSize(width: size * 0.9, height: size * 0.4)))
        shadow.position = CGPoint(x: 0, y: -size * 0.28)
        shadow.zPosition = -0.1
        house.addChild(shadow)
        addChild(house)
    }

    private func buildBaby(_ i: Int) {
        let root = SKNode()
        root.zPosition = 0.5
        let shadow = SKSpriteNode(texture: ProceduralTexture.softClayShadow(size: CGSize(width: babySize * 1.2, height: babySize * 0.9)))
        shadow.position = CGPoint(x: babySize * 0.05, y: -babySize * 0.1)
        shadow.name = "shadow"
        root.addChild(shadow)
        let fit = CGSize(width: babySize, height: babySize)
        let body: SKNode
        if let art = ToyArt.sprite("meadow-baby-ladybug", fit: fit) {
            art.zRotation = -.pi / 2 // Bundled artwork faces up; movement heading zero faces right.
            body = art
        } else if let mother = ToyArt.sprite("meadow-ladybug-top", fit: fit) {
            mother.zRotation = -.pi / 2
            body = mother   // stand-in: her own felt art, small
        } else {
            let shell = SKShapeNode(circleOfRadius: babySize * 0.42)
            shell.fillColor = UIColor(hex: 0xC8402F)
            shell.strokeColor = UIColor(hex: 0x2B1B14)
            shell.lineWidth = 1.5
            for (dx, dy) in [(-0.16, 0.1), (0.14, -0.08), (0.02, 0.2)] {
                let spot = SKShapeNode(circleOfRadius: babySize * 0.08)
                spot.fillColor = UIColor(hex: 0x2B1B14)
                spot.strokeColor = .clear
                spot.position = CGPoint(x: babySize * dx, y: babySize * dy)
                shell.addChild(spot)
            }
            body = shell
        }
        root.addChild(body)
        addChild(root)
        babies.append(root)
        babyBodies.append(body)

        let leaf: SKNode
        if let art = ToyArt.sprite("meadow-hide-leaf", fit: CGSize(width: babySize * 1.9, height: babySize * 1.9)) {
            leaf = art
        } else {
            let shape = SKShapeNode(ellipseOf: CGSize(width: babySize * 1.9, height: babySize * 1.15))
            shape.strokeColor = UIColor(hex: 0x5E7A4E).withAlphaComponent(0.45)
            shape.lineWidth = 1.5
            ProceduralTexture.applyClayFill(to: shape, base: UIColor(hex: night ? 0x4E6A49 : 0x86A86B),
                                            size: CGSize(width: babySize * 1.9, height: babySize * 1.15))
            leaf = shape
        }
        leaf.zPosition = 0.7
        leaf.zRotation = CGFloat(i) * 1.3
        addChild(leaf)
        leaves.append(leaf)
    }

    /// Put everyone where the model says, without animation (build and rotation restore).
    private func settle() {
        for i in babies.indices {
            switch model.places[i] {
            case .hidden:
                babies[i].isHidden = false
                babies[i].position = peekPosition(i)
                babies[i].zRotation = leaves[i].zRotation + .pi / 2
                leaves[i].position = model.spots[i]
                leaves[i].isHidden = false
                if !AmbientAnimator.reduceMotion { startPeeking(i) }
            case .following:
                leaves[i].isHidden = true
                babies[i].isHidden = false
            case .home:
                leaves[i].isHidden = true
                babies[i].isHidden = true
            }
        }
        house.isHidden = !model.houseVisible
        houseGlow?.alpha = glowLevel
    }

    private func applyMotion(_ i: Int) {
        babies[i].position = motions[i].position
        babies[i].zRotation = motions[i].heading
        let lift = AmbientAnimator.reduceMotion ? 0 : motions[i].lift
        babyBodies[i].setScale(1 + lift * 0.12)
        babyBodies[i].position = CGPoint(x: 0, y: lift * babySize * 0.12)
    }

    private var glowLevel: CGFloat { CGFloat(model.homeCount) / CGFloat(MeadowLittleOnesModel.count) * 0.9 }

    /// A hidden little one sits mostly under its leaf, just its head showing.
    private func peekPosition(_ i: Int) -> CGPoint {
        let a = leaves.indices.contains(i) ? leaves[i].zRotation : 0
        let spot = model.spots[i]
        return CGPoint(x: spot.x + cos(a + .pi / 2) * babySize * 0.45, y: spot.y + sin(a + .pi / 2) * babySize * 0.45)
    }

    /// Now and then a leaf rustles, so a sharp-eyed child can spot where a little one hides.
    private func startPeeking(_ i: Int) {
        let rustle = SKAction.sequence([
            .wait(forDuration: 4 + Double(i) * 1.7, withRange: 3),
            .rotate(byAngle: 0.12, duration: 0.14),
            .rotate(byAngle: -0.22, duration: 0.18),
            .rotate(byAngle: 0.10, duration: 0.16)
        ])
        leaves[i].run(.repeatForever(rustle), withKey: "rustle")
    }

    // MARK: Play

    /// Every frame: notice her, walk the parade, bring them home.
    func step(mother: CGPoint, heading: CGFloat, flowers: [CGPoint], dt: TimeInterval) -> MeadowLittleOnesEvents {
        var events = MeadowLittleOnesEvents()
        let (found, arrived) = model.motherMoved(to: mother)
        for i in found { join(i, delay: 0) }
        events.found = found.count
        if !found.isEmpty, house.isHidden { showHouse() }

        // The parade follows her path, easing into place and hopping over the flowers.
        for (k, i) in model.parade.enumerated() where babies[i].action(forKey: "join") == nil {
            let target = model.paradePoint(k, mother: mother)
            let hop = MeadowLittleOnesModel.flowerHop(at: motions[i].position, flowers: flowers)
            // A vertical hop keeps the path continuous; a radial nudge flips at flower centres.
            motions[i].step(toward: target, hop: hop.lift, dt: dt)
            applyMotion(i)
        }

        // Peeking ones lean out a little as she comes near.
        for i in babies.indices where model.places[i] == .hidden {
            let d = hypot(model.spots[i].x - mother.x, model.spots[i].y - mother.y)
            let near = max(0, min(1, (MeadowLittleOnesModel.findRadius * 2.6 - d) / (MeadowLittleOnesModel.findRadius * 1.6)))
            let base = peekPosition(i)
            let out = babySize * 0.35 * near
            let a = leaves[i].zRotation + .pi / 2
            babies[i].position = CGPoint(x: base.x + cos(a) * out, y: base.y + sin(a) * out)
        }

        if !arrived.isEmpty {
            for (n, i) in arrived.enumerated() { goHome(i, delay: Double(n) * 0.32) }
            events.arrived = arrived.count
            if model.allHome, !finaleDone {
                finaleDone = true
                events.allHome = true
                run(.sequence([.wait(forDuration: Double(arrived.count) * 0.32 + 0.4), .run { [weak self] in self?.finale() }]))
            }
        }
        return events
    }

    private func join(_ i: Int, delay: TimeInterval) {
        let leaf = leaves[i]
        leaf.removeAction(forKey: "rustle")
        let baby = babies[i]
        motions[i] = MeadowFollowerMotion(position: baby.position, heading: baby.zRotation)
        if AmbientAnimator.reduceMotion {
            leaf.run(.sequence([.fadeOut(withDuration: 0.3), .hide()]))
            return
        }
        // The leaf lifts away; the little one pops out with a happy hop.
        leaf.run(.sequence([
            .group([.moveBy(x: 0, y: babySize * 0.6, duration: 0.3), .fadeOut(withDuration: 0.3),
                    .rotate(byAngle: 0.4, duration: 0.3)]),
            .hide()
        ]))
        let body = babyBodies[i]
        body.run(.sequence([.scale(to: 1.35, duration: 0.14), .scale(to: 0.95, duration: 0.12), .scale(to: 1, duration: 0.1)]))
        baby.run(.wait(forDuration: 0.36 + delay), withKey: "join")
    }

    private func showHouse() {
        house.isHidden = false
        guard !AmbientAnimator.reduceMotion else { return }
        house.setScale(0.3)
        house.alpha = 0
        house.run(.group([.fadeIn(withDuration: 0.6), .sequence([.scale(to: 1.06, duration: 0.5), .scale(to: 1, duration: 0.3)])]))
    }

    private func goHome(_ i: Int, delay: TimeInterval) {
        let baby = babies[i]
        baby.removeAllActions()
        let door = CGPoint(x: model.house.x + babySize * 0.3, y: model.house.y - babySize * 0.2)
        let level = glowLevel
        let reduce = AmbientAnimator.reduceMotion
        let hopIn = SKAction.move(to: door, duration: reduce ? 0.4 : 0.32)
        hopIn.timingMode = .easeInEaseOut
        baby.run(.sequence([
            .wait(forDuration: delay),
            reduce ? hopIn : .group([hopIn, .sequence([.scale(to: 1.25, duration: 0.16), .scale(to: 0.6, duration: 0.16)])]),
            .fadeOut(withDuration: 0.15),
            .hide(),
            .run { [weak self] in self?.houseGlow?.run(.fadeAlpha(to: level, duration: 0.4)) }
        ]))
    }

    /// All five home: the house glows warm, and a few soft sparks rise from the doorway.
    private func finale() {
        houseGlow?.run(.sequence([.fadeAlpha(to: 1, duration: 0.5), .fadeAlpha(to: 0.9, duration: 0.8)]))
        guard !AmbientAnimator.reduceMotion else { return }
        house.run(.sequence([.scale(to: 1.08, duration: 0.3), .scale(to: 1, duration: 0.5)]))
        for n in 0..<7 {
            let spark = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...3.5))
            spark.fillColor = UIColor(hex: 0xFFD98A)
            spark.strokeColor = .clear
            spark.position = CGPoint(x: model.house.x + CGFloat.random(in: -14...14), y: model.house.y)
            spark.zPosition = 1
            spark.alpha = 0
            addChild(spark)
            spark.run(.sequence([
                .wait(forDuration: Double(n) * 0.12),
                .group([.fadeIn(withDuration: 0.2),
                        .moveBy(x: CGFloat.random(in: -20...20), y: CGFloat.random(in: 50...90), duration: 1.4)]),
                .fadeOut(withDuration: 0.5),
                .removeFromParent()
            ]))
        }
    }
}
