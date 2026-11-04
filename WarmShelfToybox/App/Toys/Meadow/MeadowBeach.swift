import SpriteKit

/// One southern coastline in the same overhead, rotation-stable world as the garden.
/// The conservative walking line leaves space for whole ladybug bodies above the surf.
enum MeadowBeachGeometry {
    static func grassEdge(atX x: CGFloat, worldSize: CGSize) -> CGFloat {
        let u = x / max(1, worldSize.width)
        return worldSize.height * (-0.36 + sin(u * .pi * 3.2 + 0.4) * 0.005
                                   + sin(u * .pi * 7.4) * 0.003)
    }

    static func shoreline(atX x: CGFloat, worldSize: CGSize) -> CGFloat {
        let u = x / max(1, worldSize.width)
        return worldSize.height * (-0.445 + sin(u * .pi * 3 + 0.8) * 0.006
                                   + sin(u * .pi * 5.6 - 0.3) * 0.004)
    }

    static func landMinimum(worldSize: CGSize) -> CGFloat { -worldSize.height * 0.415 }

    static func isGrass(_ p: CGPoint, worldSize: CGSize, clearance: CGFloat = 0) -> Bool {
        p.x.isFinite && p.y.isFinite && p.y >= grassEdge(atX: p.x, worldSize: worldSize) + max(0, clearance)
    }

    static func isLand(_ p: CGPoint, worldSize: CGSize, clearance: CGFloat = 0) -> Bool {
        p.x.isFinite && p.y.isFinite && p.y >= landMinimum(worldSize: worldSize) + max(0, clearance)
    }

    static func landPosition(_ p: CGPoint, worldSize: CGSize) -> CGPoint {
        CGPoint(x: p.x.isFinite ? p.x : 0,
                y: max(p.y.isFinite ? p.y : 0, landMinimum(worldSize: worldSize)))
    }
}

/// Sand, tide and small beach discoveries are layers, not a perspective-baked backdrop.
/// Water and its inhabitants share the overhead plane; no horizon or upright scenery.
final class MeadowBeachNode: SKNode {
    private struct Find {
        let root: SKNode
        let art: SKSpriteNode
        let turn: CGFloat
        let star: Bool
    }
    private struct Jelly {
        let root: SKNode
        let bell: SKNode
        let threads: [SKShapeNode]
        let home: CGPoint
        let radius: CGFloat
        let phase: CGFloat
    }
    private struct Fish {
        let root: SKNode
        let tail: SKNode
        let home: CGPoint
        let phase: CGFloat
    }

    private let worldSize: CGSize
    private let night: Bool
    private let foam = SKShapeNode()
    private let backwash = SKShapeNode()
    private let surf = SKShapeNode()
    private var finds: [Find] = []
    private var jellies: [Jelly] = []
    private var fish: [Fish] = []
    private var clock: CGFloat = 0
    private var frameBudget: TimeInterval = 0
    private var wasReduced = false

    init(worldSize: CGSize, night: Bool, motionTime: CGFloat = 0) {
        self.worldSize = worldSize
        self.night = night
        self.clock = motionTime.isFinite ? max(0, motionTime).truncatingRemainder(dividingBy: 200 * .pi) : 0
        super.init()
        buildCoast()
        buildFinds()
        buildSeaLife()
        pose(at: clock)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var accessibilityFinds: [(label: String, position: CGPoint)] {
        finds.map { (label: $0.star ? "Starfish" : "Seashell", position: $0.root.position) }
    }

    var motionTime: CGFloat { clock }

    private var extent: CGFloat { worldSize.width / 2 + MeadowWorldGeometry.overscan }
    private var bottom: CGFloat { -worldSize.height / 2 - MeadowWorldGeometry.overscan }
    private func shore(_ x: CGFloat) -> CGFloat { MeadowBeachGeometry.shoreline(atX: x, worldSize: worldSize) }

    private func line(_ height: (CGFloat) -> CGFloat) -> CGPath {
        let path = CGMutablePath()
        for index in 0...100 {
            let x = -extent + CGFloat(index) / 100 * extent * 2
            let point = CGPoint(x: x, y: height(x))
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }

    private func area(_ height: (CGFloat) -> CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.addPath(line(height))
        path.addLine(to: CGPoint(x: extent, y: bottom))
        path.addLine(to: CGPoint(x: -extent, y: bottom))
        path.closeSubpath()
        return path
    }

    /// The same native-scale wool used by the meadow, dyed into sand and water.
    /// Clipping separate tiles preserves fibre size instead of stretching one image.
    private func material(path: CGPath, color: UIColor, at z: CGFloat) {
        let base = SKShapeNode(path: path)
        base.fillColor = color; base.strokeColor = .clear; base.zPosition = z
        addChild(base)
        guard let texture = ToyArt.texture("meadow-felt-ground") else { return }
        let crop = SKCropNode()
        let mask = SKShapeNode(path: path)
        mask.fillColor = .white; mask.strokeColor = .clear
        crop.maskNode = mask; crop.zPosition = z + 0.01
        let tileSide = max(256, min(texture.size().width, texture.size().height))
        let bounds = path.boundingBoxOfPath
        let loX = Int(floor(bounds.minX / tileSide)), hiX = Int(floor(bounds.maxX / tileSide))
        let loY = Int(floor(bounds.minY / tileSide)), hiY = Int(floor(bounds.maxY / tileSide))
        for x in loX...hiX { for y in loY...hiY {
            let tile = SKSpriteNode(texture: texture)
            tile.size = CGSize(width: tileSide, height: tileSide)
            tile.position = CGPoint(x: (CGFloat(x) + 0.5) * tileSide, y: (CGFloat(y) + 0.5) * tileSide)
            tile.xScale = x.isMultiple(of: 2) ? 1 : -1
            tile.yScale = y.isMultiple(of: 2) ? 1 : -1
            // The grass texture carries green pigment. Use it only as a faint
            // fibre layer over the dyed base; multiplicative tint made sand olive.
            tile.color = .white; tile.colorBlendFactor = 0
            tile.alpha = night ? 0.04 : 0.14
            crop.addChild(tile)
        } }
        addChild(crop)
    }

    private func buildCoast() {
        material(path: area { MeadowBeachGeometry.grassEdge(atX: $0, worldSize: worldSize) },
                 color: UIColor(hex: night ? 0x697578 : 0xE7D1A9), at: 0)
        let grassLip = SKShapeNode(path: line { MeadowBeachGeometry.grassEdge(atX: $0, worldSize: worldSize) })
        grassLip.strokeColor = UIColor(hex: night ? 0x344D49 : 0xA7B18D).withAlphaComponent(0.55)
        grassLip.lineWidth = 5; grassLip.lineCap = .round; grassLip.zPosition = 0.1
        addChild(grassLip)
        // Darker damp sand lies underneath the pale, gently advancing edge of water.
        material(path: area { shore($0) + 12 }, color: UIColor(hex: night ? 0x4C6269 : 0xC8B99E), at: 0.2)
        material(path: area { shore($0) }, color: UIColor(hex: night ? 0x294E5D : 0x80B4C2), at: 0.4)
        material(path: area { shore($0) - min(95, worldSize.height * 0.04) },
                 color: UIColor(hex: night ? 0x263F55 : 0x5F93AC), at: 0.5)
        surf.fillColor = UIColor(hex: night ? 0x537B80 : 0xB0D1CE).withAlphaComponent(0.22)
        surf.strokeColor = .clear; surf.zPosition = 0.6; addChild(surf)
        for (node, width, alpha) in [(foam, CGFloat(3.4), CGFloat(0.45)), (backwash, 1.6, 0.20)] {
            node.fillColor = .clear; node.strokeColor = UIColor(hex: 0xF3ECDD)
            node.lineWidth = width; node.lineCap = .round
            node.alpha = night ? alpha * 0.55 : alpha
            node.zPosition = 2; addChild(node)
        }
    }

    private func buildFinds() {
        let fractions: [CGFloat] = [-0.39, -0.25, -0.08, 0.12, 0.29, 0.42]
        for (index, fraction) in fractions.enumerated() {
            let isStar = index.isMultiple(of: 2)
            let side: CGFloat = isStar ? 62 : 51
            guard let art = ToyArt.sprite(isStar ? "meadow-beach-starfish" : "meadow-beach-shell",
                                         fit: CGSize(width: side, height: side)) else { continue }
            let root = SKNode()
            let x = fraction * worldSize.width
            let grass = MeadowBeachGeometry.grassEdge(atX: x, worldSize: worldSize)
            let lower = MeadowBeachGeometry.landMinimum(worldSize: worldSize) + 30
            root.position = CGPoint(x: x, y: grass * 0.45 + lower * 0.55)
            root.zPosition = 3
            let turn = CGFloat(index % 3 - 1) * 0.31
            art.zRotation = turn
            MeadowMaterialLight.apply(to: art, night: night)
            let shadow = SKSpriteNode(texture: ProceduralTexture.softClayShadow(size: CGSize(width: side * 0.9, height: side * 0.75)))
            shadow.size = CGSize(width: side * 0.9, height: side * 0.75)
            shadow.position = CGPoint(x: 1, y: -2); shadow.alpha = night ? 0.17 : 0.22
            root.addChild(shadow); root.addChild(art); addChild(root)
            finds.append(Find(root: root, art: art, turn: turn, star: isStar))
        }
    }

    private func buildSeaLife() {
        // Circular bells are seen from above; their fine threads trail in the current.
        for (index, xFraction) in [CGFloat(-0.30), 0.025, 0.34].enumerated() {
            let radius: CGFloat = index == 1 ? 19 : 15
            let x = worldSize.width * xFraction
            let home = CGPoint(x: x, y: shore(x) - (index == 1 ? 53 : 78))
            let root = SKNode(); root.position = home; root.zPosition = 1
            root.alpha = night ? 0.28 : 0.38
            let bell = SKNode()
            let disc = SKShapeNode(ellipseOf: CGSize(width: radius * 2, height: radius * 1.9))
            disc.fillColor = UIColor(hex: 0xD9D5DC).withAlphaComponent(0.8)
            disc.strokeColor = UIColor(hex: 0xE6E8DA).withAlphaComponent(0.7); disc.lineWidth = 1.5
            bell.addChild(disc)
            for petalIndex in 0..<4 {
                let angle = CGFloat(petalIndex) * .pi / 2 + .pi / 4
                let petal = SKShapeNode(ellipseOf: CGSize(width: radius * 0.45, height: radius * 0.55))
                petal.position = CGPoint(x: cos(angle) * radius * 0.25, y: sin(angle) * radius * 0.25)
                petal.fillColor = UIColor(hex: 0xADA7C0).withAlphaComponent(0.6); petal.strokeColor = .clear
                petal.zRotation = angle; bell.addChild(petal)
            }
            var threads: [SKShapeNode] = []
            for _ in 0..<5 {
                let thread = SKShapeNode()
                thread.strokeColor = UIColor(hex: 0xE0DFD8); thread.lineWidth = 1.1
                thread.lineCap = .round; thread.alpha = 0.7
                root.addChild(thread); threads.append(thread)
            }
            root.addChild(bell); addChild(root)
            jellies.append(Jelly(root: root, bell: bell, threads: threads, home: home,
                                 radius: radius, phase: CGFloat(index) * 2.1))
        }
        for index in 0..<7 {
            let root = SKNode(), tail = SKNode()
            let bodyPath = CGMutablePath()
            bodyPath.move(to: CGPoint(x: 13, y: 0))
            bodyPath.addCurve(to: CGPoint(x: -10, y: 0), control1: CGPoint(x: 3, y: 8), control2: CGPoint(x: -5, y: 7))
            bodyPath.addCurve(to: CGPoint(x: 13, y: 0), control1: CGPoint(x: -5, y: -7), control2: CGPoint(x: 3, y: -8))
            let body = SKShapeNode(path: bodyPath)
            let color = UIColor(hex: night ? 0x152C42 : 0x466C7B)
            body.fillColor = color; body.strokeColor = .clear
            let finPath = CGMutablePath()
            finPath.move(to: .zero); finPath.addLine(to: CGPoint(x: -9, y: 6))
            finPath.addQuadCurve(to: CGPoint(x: -9, y: -6), control: CGPoint(x: -7, y: 0)); finPath.closeSubpath()
            let fin = SKShapeNode(path: finPath); fin.fillColor = color; fin.strokeColor = .clear
            tail.position.x = -9; tail.addChild(fin); root.addChild(tail); root.addChild(body)
            let x = worldSize.width * (-0.40 + CGFloat(index) * 0.125)
            let home = CGPoint(x: x, y: shore(x) - CGFloat(index.isMultiple(of: 2) ? 95 : 43))
            root.position = home; root.alpha = night ? 0.14 : 0.18; root.zPosition = 0.8
            addChild(root); fish.append(Fish(root: root, tail: tail, home: home, phase: CGFloat(index) * 1.7))
        }
    }

    /// Thirty low-cost material updates per second; no warp meshes or action backlog.
    func advance(deltaTime: TimeInterval, reduceMotion: Bool) {
        guard deltaTime.isFinite, deltaTime > 0 else { return }
        if reduceMotion {
            if !wasReduced { pose(at: 0); resetTransientFeedback() }
            wasReduced = true; frameBudget = 0
            return
        }
        wasReduced = false
        let dt = min(0.05, deltaTime)
        // Every authored frequency completes whole cycles at this shared period.
        clock = (clock + CGFloat(dt)).truncatingRemainder(dividingBy: 200 * .pi)
        frameBudget += dt
        guard frameBudget >= 1.0 / 30 else { return }
        frameBudget = 0
        pose(at: clock)
    }

    private func pose(at t: CGFloat) {
        let tide = sin(t * 0.62) * 5
        foam.path = line { shore($0) + tide + sin($0 / 170 + t * 0.28) * 2 }
        backwash.path = line { shore($0) - 28 + sin($0 / 210 - t * 0.20) * 3 }
        surf.path = area { shore($0) + tide }
        for jelly in jellies {
            let p = t * 0.30 + jelly.phase
            jelly.root.position = CGPoint(x: jelly.home.x + sin(p) * 21, y: jelly.home.y + cos(p * 0.8) * 8)
            jelly.bell.setScale(1 + sin(t * 0.95 + jelly.phase) * 0.045)
            for (index, thread) in jelly.threads.enumerated() {
                let spread = CGFloat(index - 2) * jelly.radius * 0.28
                let sway = sin(t * 0.75 + CGFloat(index) * 0.6 + jelly.phase) * 5
                let path = CGMutablePath(); path.move(to: CGPoint(x: -jelly.radius * 0.4, y: spread))
                path.addCurve(to: CGPoint(x: -jelly.radius * 2.3, y: spread + sway - 5),
                              control1: CGPoint(x: -jelly.radius, y: spread + sway + 6),
                              control2: CGPoint(x: -jelly.radius * 1.6, y: spread - sway - 8))
                thread.path = path
            }
        }
        for visitor in fish {
            let p = t * 0.16 + visitor.phase
            visitor.root.position = CGPoint(x: visitor.home.x + sin(p) * 37, y: visitor.home.y + cos(p) * 8)
            visitor.root.zRotation = atan2(-8 * sin(p), 37 * cos(p))
            visitor.tail.zRotation = sin(t * 2.1 + visitor.phase) * 0.11
            // Passing under slightly deeper water makes a fish softly less visible.
            visitor.root.alpha = (night ? 0.10 : 0.14) + (1 + sin(p)) * 0.035
        }
    }

    @discardableResult
    func react(at point: CGPoint, reduceMotion: Bool) -> Bool {
        guard let find = finds.min(by: {
            hypot($0.root.position.x - point.x, $0.root.position.y - point.y)
                < hypot($1.root.position.x - point.x, $1.root.position.y - point.y)
        }), hypot(find.root.position.x - point.x, find.root.position.y - point.y) < 38 else { return false }
        let art = find.art
        art.removeAction(forKey: "beach.notice")
        art.setScale(1); art.zRotation = find.turn; art.alpha = 1
        if reduceMotion {
            art.alpha = 0.76
            art.run(.fadeAlpha(to: 1, duration: 0.5), withKey: "beach.notice")
        } else {
            let notice = SKAction.group([
                .scale(to: find.star ? 0.96 : 1.025, duration: 0.14),
                .rotate(toAngle: find.turn + (find.star ? 0.07 : -0.12), duration: 0.14)])
            let settle = SKAction.group([.scale(to: 1, duration: 0.8), .rotate(toAngle: find.turn, duration: 0.8)])
            notice.timingMode = .easeOut; settle.timingMode = .easeInEaseOut
            art.run(.sequence([notice, settle]), withKey: "beach.notice")
        }
        return true
    }

    func resetTransientFeedback() {
        for find in finds {
            find.art.removeAllActions(); find.art.setScale(1)
            find.art.zRotation = find.turn; find.art.alpha = 1
        }
        frameBudget = 0
    }
}
