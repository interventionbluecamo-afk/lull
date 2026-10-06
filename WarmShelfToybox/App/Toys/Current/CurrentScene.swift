import SpriteKit
import UIKit

final class CurrentScene: BaseToyScene {

    // MARK: - Wave simulation

    private let gridSize = 64
    private var grid: [[Float]] = []
    private var prevGrid: [[Float]] = []
    private var velGrid: [[Float]] = []
    private let damping: Float = 0.985
    private let waveC: Float = 0.18

    // MARK: - Rendering

    private var waterSprite = SKSpriteNode()
    private var bitmapContext: CGContext?

    // MARK: - Leaves

    private var leaves: [LeafNode] = []
    private var touchStartPositions: [UITouch: CGPoint] = [:]
    private var touchHitCreature: Set<UITouch> = []

    // MARK: - Creatures

    private var creatures: [WaterCreatureNode] = []
    private var creatureAccumulator: TimeInterval = 0
    private var lastCreatureUpdate: TimeInterval = 0
    private var lastDisturbancePoint: CGPoint?
    private var isTablet: Bool { min(size.width, size.height) >= 700 }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        super.didMove(to: view)

        initGrids()
        buildWaterSprite()
        spawnCreatures()
    }

    override func willMove(from view: SKView) {
        super.willMove(from: view)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        waterSprite.size = size
        waterSprite.position = CGPoint(x: size.width / 2, y: size.height / 2)
        remapCreatures(from: oldSize)
    }

    private func remapCreatures(from oldSize: CGSize) {
        guard size.width > 60, size.height > 60 else { return }
        if creatures.isEmpty {
            spawnCreatures()
            return
        }
        let sx = size.width / max(oldSize.width, 1)
        let sy = size.height / max(oldSize.height, 1)
        for creature in creatures {
            let home = CGPoint(x: creature.homePosition.x * sx, y: creature.homePosition.y * sy)
            creature.homePosition = home
            if creature.isAtRest { creature.position = home }
        }
    }

    // MARK: - Grids

    private func initGrids() {
        let empty = Array(repeating: Array(repeating: Float(0), count: gridSize), count: gridSize)
        grid = empty
        prevGrid = empty
        velGrid = empty
    }

    // MARK: - Water sprite

    private func buildWaterSprite() {
        waterSprite.removeFromParent()
        waterSprite = SKSpriteNode()
        waterSprite.size = size
        waterSprite.position = CGPoint(x: size.width / 2, y: size.height / 2)
        waterSprite.zPosition = 5
        addChild(waterSprite)

        // Create reusable bitmap context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        bitmapContext = CGContext(
            data: nil,
            width: gridSize,
            height: gridSize,
            bitsPerComponent: 8,
            bytesPerRow: gridSize * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    // MARK: - Simulation

    private func simulateStep() {
        var next = grid
        for y in 1..<(gridSize - 1) {
            for x in 1..<(gridSize - 1) {
                let laplacian = grid[y][x - 1] + grid[y][x + 1] + grid[y - 1][x] + grid[y + 1][x] - 4 * grid[y][x]
                velGrid[y][x] = damping * velGrid[y][x] + waveC * laplacian
                next[y][x] = grid[y][x] + velGrid[y][x]
                next[y][x] = max(-1.0, min(1.0, next[y][x]))
            }
        }
        prevGrid = grid
        grid = next
    }

    // MARK: - Render to texture

    private func renderWaterTexture() {
        guard let ctx = bitmapContext else { return }

        // Warm water: sage-teal deep, seafoam surface, cream foam — never cold blue/white.
        let deepR: Float = 0.55; let deepG: Float = 0.75; let deepB: Float = 0.70
        let surfR: Float = 0.85; let surfG: Float = 0.92; let surfB: Float = 0.88
        let foamR: Float = 1.0;  let foamG: Float = 0.97; let foamB: Float = 0.90

        guard let data = ctx.data else { return }
        let ptr = data.bindMemory(to: UInt8.self, capacity: gridSize * gridSize * 4)

        for y in 0..<gridSize {
            for x in 0..<gridSize {
                let h = grid[y][x]  // -1 ... +1
                var r, g, b: Float

                if h <= 0 {
                    // Deep → surface: h from -1 to 0
                    let t = (h + 1.0)  // 0...1
                    r = deepR + (surfR - deepR) * t
                    g = deepG + (surfG - deepG) * t
                    b = deepB + (surfB - deepB) * t
                } else {
                    // Surface → foam: h from 0 to +0.4 capped
                    let t = min(h / 0.4, 1.0)
                    r = surfR + (foamR - surfR) * t
                    g = surfG + (foamG - surfG) * t
                    b = surfB + (foamB - surfB) * t
                }

                let offset = (y * gridSize + x) * 4
                ptr[offset + 0] = UInt8(min(r * 255, 255))
                ptr[offset + 1] = UInt8(min(g * 255, 255))
                ptr[offset + 2] = UInt8(min(b * 255, 255))
                ptr[offset + 3] = 255
            }
        }

        if let cgImg = ctx.makeImage() {
            waterSprite.texture = SKTexture(cgImage: cgImg)
        }
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        guard size.width > 20, size.height > 20 else { return }

        simulateStep()
        simulateStep()
        renderWaterTexture()
        updateLeaves()
        updateCreatures(currentTime)
    }

    // MARK: - Creatures

    private func spawnCreatures() {
        guard creatures.isEmpty, size.width > 60, size.height > 60 else { return }

        let count = isTablet ? 4 : 3
        let margin: CGFloat = 72
        guard size.width > margin * 2, size.height > margin * 2 else { return }

        var placed: [CGPoint] = []
        var attempts = 0
        while placed.count < count && attempts < 240 {
            attempts += 1
            let candidate = CGPoint(
                x: .random(in: margin...(size.width - margin)),
                y: .random(in: margin...(size.height - margin))
            )
            if placed.allSatisfy({ hypot($0.x - candidate.x, $0.y - candidate.y) > 80 }) {
                placed.append(candidate)
            }
        }

        // Big enough to read as characters a toddler wants to chase and boop.
        let diameterRange: ClosedRange<CGFloat> = isTablet ? 60...74 : 50...60
        for (index, home) in placed.enumerated() {
            let creature = WaterCreatureNode(diameter: .random(in: diameterRange))
            creature.homePosition = home
            creature.position = home
            creature.zPosition = 20 + CGFloat(index)
            addChild(creature)
            creatures.append(creature)
            // Staggered hello: each wakes a beat after the last.
            creature.playWakeInvite(after: 1.5 + Double(index) * 0.4)
        }
    }

    private func updateCreatures(_ currentTime: TimeInterval) {
        guard !creatures.isEmpty else { return }
        let delta = lastCreatureUpdate == 0 ? 0 : currentTime - lastCreatureUpdate
        lastCreatureUpdate = currentTime
        creatureAccumulator += delta
        guard creatureAccumulator >= 0.3 else { return }
        creatureAccumulator = 0

        for creature in creatures where creature.isAtRest {
            let height = waveHeight(at: creature.position)
            if height > 0.65, let point = lastDisturbancePoint {
                creature.scatter(from: point, within: size)
            } else if height > 0.22, let point = lastDisturbancePoint {
                creature.notice(lookToward: point)
                creature.run(.sequence([
                    .wait(forDuration: 0.5),
                    .run { [weak creature] in
                        guard let creature, creature.currentState == .noticing else { return }
                        creature.swim(toward: point)
                    }
                ]))
            }
        }
    }

    private func waveHeight(at scenePoint: CGPoint) -> Float {
        let gx = Int(scenePoint.x / size.width * CGFloat(gridSize)).clamped(to: 0...(gridSize - 1))
        let gy = Int((1 - scenePoint.y / size.height) * CGFloat(gridSize)).clamped(to: 0...(gridSize - 1))
        return grid[gy][gx]
    }

    private func nudgeNearbyCreatures(at point: CGPoint) {
        lastDisturbancePoint = point
        // A touch is an invitation. Resting creatures within reach look up, then swim
        // over to the finger — the child can lead them around the pool and they always
        // drift home afterward. The reach scales with the pool so it feels equally alive
        // on a small phone and a big tablet; toddlers don't aim.
        let reach = (min(size.width, size.height) * 0.30).clamped(to: 130...260)
        for creature in creatures where creature.isAtRest {
            let d = hypot(creature.position.x - point.x, creature.position.y - point.y)
            guard d < reach else { continue }
            creature.notice(lookToward: point)
            creature.run(.sequence([
                .wait(forDuration: 0.12),   // a quick beat of recognition before approaching
                .run { [weak creature] in
                    guard let creature, creature.currentState == .noticing else { return }
                    creature.swim(toward: point)
                }
            ]), withKey: "creature.approach")
        }
    }

    // MARK: - Grid disturbance

    private func disturbGrid(at scenePoint: CGPoint, amplitude: Float, radius: Int = 3) {
        let gx = Int(scenePoint.x / size.width * CGFloat(gridSize))
        let gy = Int((1 - scenePoint.y / size.height) * CGFloat(gridSize))

        for dy in -radius...radius {
            for dx in -radius...radius {
                let dist = sqrt(Float(dx * dx + dy * dy))
                guard dist < Float(radius) else { continue }
                let nx = gx + dx
                let ny = gy + dy
                guard nx >= 0 && nx < gridSize && ny >= 0 && ny < gridSize else { continue }
                grid[ny][nx] += amplitude * (1 - dist / Float(radius))
            }
        }
    }

    // MARK: - Leaf bobbing

    private func updateLeaves() {
        for leaf in leaves {
            let lx = leaf.gridX.clamped(to: 0...(gridSize - 1))
            let ly = leaf.gridY.clamped(to: 0...(gridSize - 1))
            let h = CGFloat(grid[ly][lx])
            let targetY = leaf.homeY + h * 4.0
            // Lerp position.y toward target
            leaf.position.y += (targetY - leaf.position.y) * 0.18
        }
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let pt = touch.location(in: self)
            touchStartPositions[touch] = pt
            if consumeShelfReturnTouch(at: pt) { return }

            // A direct boop on a creature is the most delightful thing a child can do —
            // it giggles, twirls, and chirps right away. No ripple, no leaf, just joy.
            if let creature = creatureHit(at: pt) {
                touchHitCreature.insert(touch)
                creature.giggle()
                AudioManager.shared.playBloomCritter()
                HapticsManager.shared.softTap()
                continue
            }

            disturbGrid(at: pt, amplitude: 0.6)
            nudgeNearbyCreatures(at: pt)
            AudioManager.shared.playSoftTap()
        }
    }

    private func creatureHit(at point: CGPoint) -> WaterCreatureNode? {
        creatures
            .filter { hypot($0.position.x - point.x, $0.position.y - point.y) < $0.touchRadius }
            .min { a, b in
                hypot(a.position.x - point.x, a.position.y - point.y) <
                hypot(b.position.x - point.x, b.position.y - point.y)
            }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let pt = touch.location(in: self)
            disturbGrid(at: pt, amplitude: 0.25)
            nudgeNearbyCreatures(at: pt)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let pt = touch.location(in: self)
            let boopedCreature = touchHitCreature.contains(touch)
            if !boopedCreature, let start = touchStartPositions[touch] {
                let moved = hypot(pt.x - start.x, pt.y - start.y)
                if moved < 8 {
                    spawnLeaf(at: pt)
                }
            }
            touchStartPositions.removeValue(forKey: touch)
            touchHitCreature.remove(touch)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            touchStartPositions.removeValue(forKey: touch)
            touchHitCreature.remove(touch)
        }
    }

    // MARK: - Leaf spawning

    private func spawnLeaf(at point: CGPoint) {
        if leaves.count >= 12 {
            let oldest = leaves.removeFirst()
            oldest.run(.sequence([
                .fadeOut(withDuration: 0.6),
                .removeFromParent()
            ]))
        }

        let leaf = LeafNode(at: point)
        leaf.homeY = point.y
        leaf.gridX = Int(point.x / size.width * CGFloat(gridSize)).clamped(to: 0...(gridSize - 1))
        leaf.gridY = Int((1 - point.y / size.height) * CGFloat(gridSize)).clamped(to: 0...(gridSize - 1))
        leaf.zPosition = 30 + CGFloat(leaves.count)
        leaf.alpha = 0

        addChild(leaf)
        leaves.append(leaf)

        leaf.run(.fadeAlpha(to: 1.0, duration: 0.4))
    }

}

// MARK: - Comparable clamped helper

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
