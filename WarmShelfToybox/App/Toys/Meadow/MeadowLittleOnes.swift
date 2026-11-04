import SpriteKit

// Find the little ones (founder, October 11). Five baby ladybugs hide around the meadow,
// peeking from under leaves. When she walks near one, it pops out and joins a little parade
// that follows in her steps, hopping between her flowers (never squashing or re-blooming
// them). A leaf house is visible in the home garden from the start; she leads them home,
// each one hops in, and the house glows warmer. No counter, no timer, no way to fail.
// Delivered slots quietly return to new offscreen hiding places, keeping five available
// without a restart, a counter, or an ever-growing node history.

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
        var worldSize: CGSize
        var homeRadius: CGFloat
        var avoid: [CGPoint]
        var replenishmentSeed: UInt64
        var restRemaining: [TimeInterval]
        var warmthCount: Int
    }

    private(set) var spots: [CGPoint]
    private(set) var places: [Place]
    /// Little ones following her, in the order they joined (first = right behind her).
    private(set) var parade: [Int] = []
    let house: CGPoint
    let paradeSpacing: CGFloat
    private let worldSize: CGSize
    private let homeRadius: CGFloat
    private let avoid: [CGPoint]
    private var replenishmentSeed: UInt64
    private(set) var restRemaining: [TimeInterval]
    /// Warmth records the visit's first five welcomes and then stays steady. It is bounded,
    /// independent of which reusable slots are currently out in the meadow.
    private(set) var warmthCount = 0
    /// Her recent path, newest last, long enough for the whole parade.
    private(set) var trail: [CGPoint] = []

    var homeCount: Int { places.filter { $0 == .home }.count }
    var allHome: Bool { homeCount == Self.count }
    /// Home is a quiet landmark from the start, even before anyone has been found.
    var houseVisible: Bool { true }
    var snapshot: Snapshot {
        Snapshot(spots: spots, places: places, parade: parade, house: house, trail: trail,
                 paradeSpacing: paradeSpacing, worldSize: worldSize, homeRadius: homeRadius,
                 avoid: avoid, replenishmentSeed: replenishmentSeed, restRemaining: restRemaining,
                 warmthCount: warmthCount)
    }

    init(worldSize: CGSize, homeRadius: CGFloat, avoid: [CGPoint], seed: UInt64, paradeSpacing: CGFloat = Self.paradeGap) {
        self.paradeSpacing = max(Self.paradeGap, paradeSpacing)
        self.worldSize = worldSize
        self.homeRadius = homeRadius
        self.avoid = avoid
        replenishmentSeed = seed
        restRemaining = Array(repeating: 0, count: Self.count)
        spots = Self.hidingSpots(worldSize: worldSize, homeRadius: homeRadius, avoid: avoid, seed: seed)
        places = Array(repeating: .hidden, count: spots.count)
        house = Self.housePosition(homeRadius: homeRadius)
    }

    init(restoring snapshot: Snapshot) {
        spots = snapshot.spots.map { MeadowBeachGeometry.landPosition($0, worldSize: snapshot.worldSize) }
        places = snapshot.places
        parade = snapshot.parade
        house = snapshot.house
        trail = snapshot.trail.map { MeadowBeachGeometry.landPosition($0, worldSize: snapshot.worldSize) }
        paradeSpacing = snapshot.paradeSpacing
        worldSize = snapshot.worldSize
        homeRadius = snapshot.homeRadius
        avoid = snapshot.avoid
        replenishmentSeed = snapshot.replenishmentSeed
        restRemaining = snapshot.restRemaining
        warmthCount = snapshot.warmthCount
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
            for i in parade {
                places[i] = .home
                restRemaining[i] = 8 + Double(i) * 0.7
            }
            warmthCount = min(Self.count, warmthCount + arrived.count)
            parade.removeAll()
        }
        return (found, arrived)
    }

    /// Reuse only delivered slots after a quiet pause. New leaves never appear inside
    /// the visible world rectangle or beside the mother. A blocked placement waits and
    /// retries with a bounded search; it never relaxes the visibility/clearance rules.
    mutating func replenish(dt: TimeInterval, mother: CGPoint, visibleWorld: CGRect) -> [Int] {
        guard dt.isFinite, dt > 0, mother.x.isFinite, mother.y.isFinite,
              visibleWorld.width.isFinite, visibleWorld.height.isFinite,
              visibleWorld.width > 0, visibleWorld.height > 0 else { return [] }
        let elapsed = min(dt, 0.05)
        let margin = max(Self.findRadius * 1.5, paradeSpacing * 1.5)
        let hiddenFromView = visibleWorld.insetBy(dx: -margin, dy: -margin)
        let half = min(worldSize.width, worldSize.height) / 2
        let inner = max(homeRadius * 1.8, half * 0.28)
        let outer = half * 0.82
        guard outer > inner else { return [] }
        var replenished: [Int] = []
        for i in places.indices where places[i] == .home {
            restRemaining[i] = max(0, restRemaining[i] - elapsed)
            guard restRemaining[i] == 0 else { continue }
            replenishmentSeed &+= 0x9E37_79B9_7F4A_7C15
            var random = MeadowSeededRandom(seed: replenishmentSeed)
            var destination: CGPoint?
            for _ in 0..<96 {
                let angle = random.unit() * .pi * 2
                let radius = inner + (outer - inner) * random.unit().squareRoot()
                let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
                guard MeadowBeachGeometry.isLand(point, worldSize: worldSize),
                      !hiddenFromView.contains(point),
                      hypot(point.x - mother.x, point.y - mother.y) >= Self.findRadius * 3,
                      hypot(point.x - spots[i].x, point.y - spots[i].y) >= max(120, half * 0.18),
                      avoid.allSatisfy({ hypot($0.x - point.x, $0.y - point.y) >= 110 }),
                      spots.indices.allSatisfy({ $0 == i || hypot(spots[$0].x - point.x, spots[$0].y - point.y) >= max(100, paradeSpacing * 2) })
                else { continue }
                destination = point
                break
            }
            guard let destination else {
                restRemaining[i] = 1 // a crowded/fully-visible world waits, without a hot loop
                continue
            }
            spots[i] = destination
            places[i] = .hidden
            replenished.append(i)
        }
        return replenished
    }

    func landPosition(_ point: CGPoint) -> CGPoint {
        MeadowBeachGeometry.landPosition(point, worldSize: worldSize)
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
            // Water exclusion is never relaxed by the crowded-world fallback below.
            guard MeadowBeachGeometry.isLand(p, worldSize: worldSize) else { continue }
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

/// Quiet material clusters between destinations. Fixed cells and a visit seed keep
/// rotation stable; scenery is bounded and never becomes a touch target or trail obstacle.
enum MeadowGroundDetails {
    struct Cluster: Equatable {
        let position: CGPoint
        let style: Int
        let turn: CGFloat
    }
    static let maximumClusters = 81

    static func layout(worldSize: CGSize, homeRadius: CGFloat, avoid: [CGPoint], seed: UInt64) -> [Cluster] {
        var random = MeadowSeededRandom(seed: seed ^ 0x5A67_0D33_A9F1_CE21)
        let step = min(worldSize.width, worldSize.height) * 0.88 / 9
        guard step > 0 else { return [] }
        var result: [Cluster] = []
        for x in -4...4 {
            for y in -4...4 {
                let point = CGPoint(x: (CGFloat(x) + (random.unit() - 0.5) * 0.28) * step,
                                    y: (CGFloat(y) + (random.unit() - 0.5) * 0.28) * step)
                let style = Int(random.next() % 3)
                let turn = (random.unit() - 0.5) * .pi * 1.3
                let onSurface = style == 1
                    ? MeadowBeachGeometry.isLand(point, worldSize: worldSize, clearance: 18)
                    : MeadowBeachGeometry.isGrass(point, worldSize: worldSize, clearance: 28)
                guard onSurface, hypot(point.x, point.y) > homeRadius * 1.4 + 30,
                      avoid.allSatisfy({ hypot($0.x - point.x, $0.y - point.y) > 125 }) else { continue }
                result.append(Cluster(position: point, style: style, turn: turn))
            }
        }
        return result
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
    private var houseRoof: SKSpriteNode?
    private var completedHomeCount = 0
    private var activeArrivals = 0
    private var houseDoor = CGPoint.zero
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
        finaleDone = model.warmthCount == MeadowLittleOnesModel.count
        completedHomeCount = model.warmthCount
        super.init()
        buildHouse(size: houseSize)
        for i in 0..<model.spots.count { buildBaby(i) }
        settle()
        motions = babies.map { MeadowFollowerMotion(position: $0.position, heading: $0.zRotation) }
        if let followers, followers.count == babies.count {
            motions = followers.map {
                MeadowFollowerMotion(position: model.landPosition($0.position), heading: $0.heading, lift: $0.lift)
            }
            for i in model.parade { applyMotion(i) }
        }
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Build

    private func buildHouse(size: CGFloat) {
        house.position = model.house
        house.zPosition = 0.2
        let fit = CGSize(width: size, height: size)
        // Both transparent layers share the original canvas and registration. A partial
        // delivery keeps the static shelter: never lay a movable leaf over its baked copy.
        let base = ToyArt.sprite("meadow-leaf-house-base", fit: fit)
        let roof = ToyArt.sprite("meadow-leaf-house-roof", fit: fit)
        let layered = base != nil && roof != nil && base?.size == roof?.size
        if let art = layered ? base : ToyArt.sprite("meadow-leaf-house", fit: fit) {
            MeadowMaterialLight.apply(to: art, night: night)
            house.addChild(art)
            // Normalized coordinates are measured on the 1345×1169 reference, y up.
            houseDoor = CGPoint(x: art.size.width * (0.485 - 0.5), y: art.size.height * (0.16 - 0.5))
            if layered, let roof {
                let attachment = CGPoint(x: 0.65, y: 0.70)
                roof.anchorPoint = attachment
                roof.position = CGPoint(x: (attachment.x - 0.5) * roof.size.width,
                                        y: (attachment.y - 0.5) * roof.size.height)
                roof.zPosition = 0.42 // the entering baby passes between the base and roof
                MeadowMaterialLight.apply(to: roof, night: night)
                house.addChild(roof)
                houseRoof = roof
            }
            let glow = SKSpriteNode(texture: ProceduralTexture.softRadialGlow)
            glow.size = CGSize(width: art.size.width * 0.34, height: art.size.height * 0.18)
            glow.position = houseDoor
            glow.color = UIColor(hex: 0xFFD092)
            glow.colorBlendFactor = 1
            glow.alpha = 0
            glow.zPosition = 0.01
            house.addChild(glow)
            houseGlow = glow
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
            houseDoor = door.position
            let light = SKShapeNode(ellipseOf: CGSize(width: w * 0.24, height: h * 0.34))
            light.fillColor = UIColor(hex: 0xFFC979)
            light.strokeColor = .clear
            light.position = door.position
            light.alpha = 0
            house.addChild(light)
            houseGlow = light
        }
        let shadow = SKSpriteNode(texture: ProceduralTexture.softClayShadow(size: CGSize(width: size * 0.96, height: size * 0.56)))
        shadow.position = CGPoint(x: size * 0.025, y: -size * 0.16)
        shadow.alpha = night ? 0.85 : 0.95
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
            MeadowMaterialLight.apply(to: art, night: night)
            body = art
        } else if let mother = ToyArt.sprite("meadow-ladybug-top", fit: fit) {
            mother.zRotation = -.pi / 2
            MeadowMaterialLight.apply(to: mother, night: night)
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
            MeadowMaterialLight.apply(to: art, night: night)
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

    private var glowLevel: CGFloat { CGFloat(completedHomeCount) / CGFloat(MeadowLittleOnesModel.count) * (night ? 0.70 : 0.40) }

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
    func step(mother: CGPoint, heading: CGFloat, flowers: [CGPoint], visibleWorld: CGRect, dt: TimeInterval) -> MeadowLittleOnesEvents {
        var events = MeadowLittleOnesEvents()
        for i in model.replenish(dt: dt, mother: mother, visibleWorld: visibleWorld) { hideAgain(i) }
        let (found, arrived) = model.motherMoved(to: mother)
        for i in found { join(i, delay: 0) }
        events.found = found.count

        // The parade follows her path, easing into place and hopping over the flowers.
        for (k, i) in model.parade.enumerated() where babies[i].action(forKey: "join") == nil {
            let target = model.paradePoint(k, mother: mother)
            let hop = MeadowLittleOnesModel.flowerHop(at: motions[i].position, flowers: flowers)
            // A vertical hop keeps the path continuous; a radial nudge flips at flower centres.
            motions[i].step(toward: model.landPosition(target), hop: hop.lift, dt: dt)
            motions[i].position = model.landPosition(motions[i].position)
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
            if model.warmthCount == MeadowLittleOnesModel.count, !finaleDone {
                finaleDone = true
                events.allHome = true
            }
        }
        return events
    }

    private func hideAgain(_ i: Int) {
        let baby = babies[i], body = babyBodies[i], leaf = leaves[i]
        baby.removeAllActions()
        body.removeAllActions()
        leaf.removeAllActions()
        leaf.position = model.spots[i]
        leaf.zRotation = CGFloat(i) * 1.3
        leaf.setScale(1)
        leaf.alpha = 1
        leaf.isHidden = false
        baby.position = peekPosition(i)
        baby.zRotation = leaf.zRotation + .pi / 2
        baby.zPosition = 0.5
        baby.alpha = 1
        baby.setScale(1)
        baby.isHidden = false
        body.position = .zero
        body.setScale(1)
        motions[i] = MeadowFollowerMotion(position: baby.position, heading: baby.zRotation)
        if !AmbientAnimator.reduceMotion { startPeeking(i) }
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

    private func goHome(_ i: Int, delay: TimeInterval) {
        activeArrivals += 1
        let baby = babies[i]
        baby.removeAllActions()
        babyBodies[i].removeAllActions()
        babyBodies[i].setScale(1)
        babyBodies[i].position = .zero
        baby.setScale(1)
        let door = CGPoint(x: model.house.x + houseDoor.x, y: model.house.y + houseDoor.y)
        let apron = CGPoint(x: door.x, y: door.y - babySize * 0.72)
        let reduce = AmbientAnimator.reduceMotion
        let distance = hypot(apron.x - baby.position.x, apron.y - baby.position.y)
        let approach = SKAction.move(to: apron, duration: reduce ? 0 : min(0.72, max(0.28, Double(distance / 240))))
        approach.timingMode = .easeInEaseOut
        let tuck = SKAction.move(to: CGPoint(x: door.x, y: door.y + babySize * 0.72), duration: reduce ? 0 : 0.30)
        tuck.timingMode = .easeInEaseOut
        baby.run(.sequence([
            .wait(forDuration: delay),
            .run { [weak self, weak baby] in
                self?.liftRoof()
                baby?.zPosition = 0.5
                if !reduce {
                    baby?.run(.rotate(toAngle: atan2(apron.y - (baby?.position.y ?? apron.y),
                                                    apron.x - (baby?.position.x ?? apron.x)),
                                      duration: 0.16, shortestUnitArc: true), withKey: "arrivalHeading")
                }
            },
            // Reduced Motion fades at the current position, then places the baby at the
            // real doorway. It never flies or shrinks across the meadow.
            reduce ? .fadeOut(withDuration: 0.18) : approach,
            .run { [weak baby] in
                baby?.position = apron
                baby?.zRotation = .pi / 2
                baby?.zPosition = 0.5
                if reduce { baby?.alpha = 1 }
            },
            tuck,
            .fadeOut(withDuration: reduce ? 0.24 : 0.12),
            .hide(),
            .run { [weak self] in self?.finishArrival() }
        ]), withKey: "arrival")
    }

    private func liftRoof() {
        guard let houseRoof, !AmbientAnimator.reduceMotion else { return }
        // Foreshorten only the front leaf around its stitched attachment. The house,
        // doorway, back leaf and contact shadow remain planted.
        let lift = SKAction.group([.scaleY(to: 0.97, duration: 0.16),
                                   .rotate(toAngle: -0.018, duration: 0.16)])
        lift.timingMode = .easeOut
        houseRoof.run(lift, withKey: "arrivalLeaf")
    }

    private func finishArrival() {
        activeArrivals = max(0, activeArrivals - 1)
        let warmthBeforeArrival = completedHomeCount
        completedHomeCount = min(model.warmthCount, completedHomeCount + 1)
        houseGlow?.run(.fadeAlpha(to: glowLevel, duration: 0.6), withKey: "doorWarmth")
        if activeArrivals == 0, let houseRoof {
            let settle = SKAction.group([.scale(to: 1, duration: 0.8),
                                         .rotate(toAngle: 0, duration: 0.8)])
            settle.timingMode = .easeInEaseOut
            houseRoof.run(.sequence([.wait(forDuration: 0.18), settle]), withKey: "arrivalLeaf")
        }
        if warmthBeforeArrival < MeadowLittleOnesModel.count,
           completedHomeCount == MeadowLittleOnesModel.count { finale() }
    }

    /// Pause/background settles committed arrivals without replaying a half-finished entry.
    func resetTransientFeedback() {
        removeAllActions()
        children.filter { $0.name == "homeSpark" }.forEach { $0.removeFromParent() }
        houseRoof?.removeAllActions()
        houseRoof?.setScale(1)
        houseRoof?.zRotation = 0
        houseGlow?.removeAllActions()
        completedHomeCount = model.warmthCount
        activeArrivals = 0
        for i in babies.indices {
            babies[i].removeAllActions()
            babyBodies[i].removeAllActions()
            babies[i].setScale(1)
            babies[i].alpha = 1
            babies[i].zPosition = 0.5
            babyBodies[i].setScale(1)
            babyBodies[i].position = .zero
            leaves[i].removeAllActions()
        }
        settle()
    }

    /// All five home: the house glows warm, and a few soft sparks rise from the doorway.
    private func finale() {
        houseGlow?.run(.sequence([.fadeAlpha(to: night ? 0.85 : 0.55, duration: 0.5), .fadeAlpha(to: glowLevel, duration: 0.8)]), withKey: "doorWarmth")
        guard !AmbientAnimator.reduceMotion else { return }
        for n in 0..<7 {
            let spark = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...3.5))
            spark.name = "homeSpark"
            spark.fillColor = UIColor(hex: 0xFFD98A)
            spark.strokeColor = .clear
            spark.position = CGPoint(x: model.house.x + houseDoor.x + CGFloat.random(in: -10...10), y: model.house.y + houseDoor.y)
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
