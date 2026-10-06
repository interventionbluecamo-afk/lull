import SpriteKit

enum BloomFeatureKind: CaseIterable {
    case pond
    case tree
    case log
    case snailRock
    case rock
    case bush
}

/// A discoverable landmark out in the garden world. Built rooted at the soil line
/// (origin at its base on the ground) and reacts when tapped.
final class BloomFeatureNode: SKNode {
    let kind: BloomFeatureKind
    private let scaleFactor: CGFloat
    private var snail: SKNode?
    private var snailAwake = false

    init(kind: BloomFeatureKind, scale: CGFloat) {
        self.kind = kind
        self.scaleFactor = scale
        super.init()
        name = "feature"
        switch kind {
        case .pond: buildPond()
        case .tree: buildTree()
        case .log: buildLog()
        case .snailRock: buildSnailRock()
        case .rock: buildRock()
        case .bush: buildBush()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Generous tap radius around the landmark.
    var tapRadius: CGFloat {
        switch kind {
        case .tree: return 120 * scaleFactor
        case .pond: return 110 * scaleFactor
        case .log: return 90 * scaleFactor
        case .snailRock: return 80 * scaleFactor
        case .rock: return 76 * scaleFactor
        case .bush: return 92 * scaleFactor
        }
    }

    private func buildPond() {
        let s = scaleFactor
        // An earthen basin dug into the ground — the pond sits IN the soil, not on it.
        let basin = SKShapeNode(ellipseOf: CGSize(width: 212 * s, height: 72 * s))
        basin.fillColor = UIColor(hex: 0x4A3220).withAlpha(0.96)
        basin.strokeColor = .clear
        basin.position = CGPoint(x: 0, y: -8 * s)
        addChild(basin)
        // Water filling the hollow, recessed below the grass line.
        let water = SKShapeNode(ellipseOf: CGSize(width: 188 * s, height: 54 * s))
        water.fillColor = WarmShelfPalette.waterBlue.withAlpha(0.62)
        water.strokeColor = WarmShelfPalette.bubbleRim.withAlpha(0.3)
        water.lineWidth = 1.5
        water.position = CGPoint(x: 0, y: -10 * s)
        addChild(water)
        // Depth shadow along the far edge.
        let depth = SKShapeNode(ellipseOf: CGSize(width: 168 * s, height: 22 * s))
        depth.fillColor = WarmShelfPalette.cocoa.withAlpha(0.16)
        depth.strokeColor = .clear
        depth.position = CGPoint(x: 0, y: 0)
        addChild(depth)
        let shine = SKShapeNode(ellipseOf: CGSize(width: 60 * s, height: 13 * s))
        shine.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.4)
        shine.strokeColor = .clear
        shine.position = CGPoint(x: -42 * s, y: -14 * s)
        addChild(shine)
        // A grassy near rim so it seats into the meadow.
        let rim = SKShapeNode(ellipseOf: CGSize(width: 206 * s, height: 64 * s))
        rim.fillColor = .clear
        rim.strokeColor = WarmShelfPalette.sage.withAlpha(0.4)
        rim.lineWidth = 5 * s
        rim.position = CGPoint(x: 0, y: -7 * s)
        addChild(rim)
    }

    private func buildTree() {
        let s = scaleFactor
        let bark = UIColor(hex: 0x9B6B43)
        let barkDark = UIColor(hex: 0x6E481F)

        // Tapered trunk with a gentle root flare — not a flat rectangle.
        let trunkPath = CGMutablePath()
        trunkPath.move(to: CGPoint(x: -20 * s, y: 0))
        trunkPath.addQuadCurve(to: CGPoint(x: -9 * s, y: 150 * s), control: CGPoint(x: -11 * s, y: 60 * s))
        trunkPath.addLine(to: CGPoint(x: 9 * s, y: 150 * s))
        trunkPath.addQuadCurve(to: CGPoint(x: 20 * s, y: 0), control: CGPoint(x: 11 * s, y: 60 * s))
        trunkPath.closeSubpath()
        let trunk = SKShapeNode(path: trunkPath)
        trunk.fillColor = bark; trunk.strokeColor = .clear
        addChild(trunk)
        // Bark grain — a couple of soft vertical striations + a knot.
        for dx in [CGFloat(-4), 4] {
            let grain = SKShapeNode(rect: CGRect(x: dx * s - 1, y: 16 * s, width: 2 * s, height: 110 * s), cornerRadius: 1)
            grain.fillColor = barkDark.withAlpha(0.3); grain.strokeColor = .clear
            addChild(grain)
        }
        let knot = SKShapeNode(ellipseOf: CGSize(width: 9 * s, height: 13 * s))
        knot.fillColor = barkDark.withAlpha(0.35); knot.strokeColor = .clear
        knot.position = CGPoint(x: 3 * s, y: 86 * s); addChild(knot)

        let canopy = SKNode()
        canopy.position = CGPoint(x: 0, y: 185 * s)
        canopy.name = "treeCanopy"
        addChild(canopy)

        let blobs: [(CGFloat, CGFloat, CGFloat)] = [(-42, -12, 58), (42, -8, 54), (0, 26, 70), (-24, 40, 48), (28, 38, 50)]
        // Darker under-layer (depth/shadow), offset down-right.
        for blob in blobs {
            let under = SKShapeNode(circleOfRadius: blob.2 * s)
            under.fillColor = UIColor(hex: 0x4E6B49); under.strokeColor = .clear
            under.position = CGPoint(x: (blob.0 + 5) * s, y: (blob.1 - 8) * s)
            canopy.addChild(under)
        }
        // Main canopy mass.
        for blob in blobs {
            let leaf = SKShapeNode(circleOfRadius: blob.2 * s)
            leaf.fillColor = WarmShelfPalette.sage; leaf.strokeColor = .clear
            leaf.position = CGPoint(x: blob.0 * s, y: blob.1 * s)
            canopy.addChild(leaf)
        }
        // Top-left sunlit highlight.
        let highlights: [(CGFloat, CGFloat, CGFloat)] = [(-30, 40, 30), (-8, 52, 22)]
        for (hx, hy, hr) in highlights {
            let hl = SKShapeNode(circleOfRadius: hr * s)
            hl.fillColor = UIColor(hex: 0x86A878).withAlpha(0.7); hl.strokeColor = .clear
            hl.position = CGPoint(x: hx * s, y: hy * s); canopy.addChild(hl)
        }
        // Leaf dapple texture.
        ProceduralTexture.addCircularSpeckles(
            to: canopy, radius: 74 * s, count: 22,
            lightColor: UIColor(hex: 0x9FBE8F), darkColor: UIColor(hex: 0x4E6B49),
            alpha: 0.18...0.42, dotRadius: 1.6...4.2, zPosition: 1
        )
        // A few little fruits peeking out.
        let fruits: [(CGFloat, CGFloat)] = [(-34, -4), (30, 14), (6, -18)]
        for (fx, fy) in fruits {
            let fruit = SKShapeNode(circleOfRadius: 6 * s)
            fruit.fillColor = WarmShelfPalette.terracotta.withAlpha(0.9); fruit.strokeColor = .clear
            fruit.position = CGPoint(x: fx * s, y: fy * s); fruit.zPosition = 2
            canopy.addChild(fruit)
        }
    }

    private func buildLog() {
        let s = scaleFactor
        // A soft mossy log lying in the grass — bark, end-grain, a cosy hollow, moss on top.
        let bark = UIColor(hex: 0x86592F)
        let body = SKShapeNode(rect: CGRect(x: -78 * s, y: 0, width: 156 * s, height: 46 * s), cornerRadius: 23 * s)
        body.fillColor = bark.withAlpha(0.96)
        body.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.08)
        body.lineWidth = 1
        body.position = CGPoint(x: 0, y: 24 * s)
        addChild(body)
        // Bark striations.
        for i in 0..<3 {
            let line = SKShapeNode(rect: CGRect(x: -50 * s, y: 0, width: 90 * s, height: 2.5 * s), cornerRadius: 1.2 * s)
            line.fillColor = UIColor(hex: 0x6E481F).withAlpha(0.5); line.strokeColor = .clear
            line.position = CGPoint(x: -6 * s, y: CGFloat(16 + i * 9) * s)
            addChild(line)
        }
        // Left end: end-grain rings.
        let endGrain = SKShapeNode(ellipseOf: CGSize(width: 26 * s, height: 46 * s))
        endGrain.fillColor = UIColor(hex: 0xB78A52).withAlpha(0.96); endGrain.strokeColor = .clear
        endGrain.position = CGPoint(x: -74 * s, y: 24 * s); addChild(endGrain)
        for i in 0..<3 {
            let ring = SKShapeNode(ellipseOf: CGSize(width: CGFloat(18 - i * 6) * s, height: CGFloat(32 - i * 10) * s))
            ring.fillColor = .clear; ring.strokeColor = UIColor(hex: 0x7A5226).withAlpha(0.55); ring.lineWidth = 1.5 * s
            ring.position = CGPoint(x: -74 * s, y: 24 * s); addChild(ring)
        }
        // Right end: a cosy dark hollow.
        let hollowRim = SKShapeNode(ellipseOf: CGSize(width: 30 * s, height: 44 * s))
        hollowRim.fillColor = UIColor(hex: 0x6E481F).withAlpha(0.96); hollowRim.strokeColor = .clear
        hollowRim.position = CGPoint(x: 74 * s, y: 24 * s); addChild(hollowRim)
        let hollow = SKShapeNode(ellipseOf: CGSize(width: 22 * s, height: 34 * s))
        hollow.fillColor = UIColor(hex: 0x2E1C0E).withAlpha(0.98); hollow.strokeColor = .clear
        hollow.position = CGPoint(x: 76 * s, y: 24 * s); addChild(hollow)
        // Moss tufts on top.
        for x in [-30, 4, 36] {
            let moss = SKShapeNode(ellipseOf: CGSize(width: 30 * s, height: 14 * s))
            moss.fillColor = WarmShelfPalette.sage.withAlpha(0.85); moss.strokeColor = .clear
            moss.position = CGPoint(x: CGFloat(x) * s, y: 44 * s); addChild(moss)
        }
    }

    private func buildRock() {
        let s = scaleFactor
        let rock = SKShapeNode(ellipseOf: CGSize(width: 96 * s, height: 60 * s))
        rock.fillColor = UIColor(hex: 0x9A8C7A).withAlpha(0.95); rock.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.06); rock.lineWidth = 1
        rock.position = CGPoint(x: 0, y: 22 * s); addChild(rock)
        let facet = SKShapeNode(ellipseOf: CGSize(width: 44 * s, height: 26 * s))
        facet.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.18); facet.strokeColor = .clear
        facet.position = CGPoint(x: -16 * s, y: 30 * s); addChild(facet)
        for x in [-24, 18] {
            let moss = SKShapeNode(ellipseOf: CGSize(width: 26 * s, height: 12 * s))
            moss.fillColor = WarmShelfPalette.sage.withAlpha(0.8); moss.strokeColor = .clear
            moss.position = CGPoint(x: CGFloat(x) * s, y: 40 * s); addChild(moss)
        }
    }

    private func buildBush() {
        let s = scaleFactor
        let blobs: [(CGFloat, CGFloat, CGFloat)] = [(-26, 16, 30), (26, 16, 30), (0, 30, 36), (-12, 8, 26), (14, 8, 26)]
        for blob in blobs {
            let leaf = SKShapeNode(circleOfRadius: blob.2 * s)
            leaf.fillColor = WarmShelfPalette.sage.withAlpha(0.9); leaf.strokeColor = .clear
            leaf.position = CGPoint(x: blob.0 * s, y: blob.1 * s); addChild(leaf)
        }
        // A few berries to find.
        for _ in 0..<4 {
            let berry = SKShapeNode(circleOfRadius: 5 * s)
            berry.name = "bushBerry"
            berry.fillColor = WarmShelfPalette.rhubarb.withAlpha(0.95); berry.strokeColor = .clear
            berry.position = CGPoint(x: .random(in: -28...28) * s, y: .random(in: 10...34) * s)
            berry.zPosition = 1; addChild(berry)
        }
    }

    private func buildSnailRock() {
        let s = scaleFactor
        let rock = SKShapeNode(ellipseOf: CGSize(width: 90 * s, height: 50 * s))
        rock.fillColor = UIColor(hex: 0x9A8C7A).withAlpha(0.9)
        rock.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.06)
        rock.lineWidth = 1
        rock.position = CGPoint(x: 0, y: 18 * s)
        addChild(rock)

        let snailNode = SKNode()
        snailNode.position = CGPoint(x: 6 * s, y: 36 * s)
        addChild(snailNode)
        snail = snailNode

        let body = SKShapeNode(ellipseOf: CGSize(width: 40 * s, height: 18 * s))
        body.fillColor = WarmShelfPalette.sand.withAlpha(0.95)
        body.strokeColor = .clear
        body.position = CGPoint(x: -6 * s, y: 0)
        snailNode.addChild(body)
        let shell = SKShapeNode(circleOfRadius: 18 * s)
        shell.fillColor = WarmShelfPalette.terracotta.withAlpha(0.92)
        shell.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.08)
        shell.lineWidth = 1
        shell.position = CGPoint(x: 4 * s, y: 4 * s)
        snailNode.addChild(shell)
        let swirl = SKShapeNode(circleOfRadius: 8 * s)
        swirl.fillColor = .clear
        swirl.strokeColor = WarmShelfPalette.paperHighlight.withAlpha(0.5)
        swirl.lineWidth = 2
        swirl.position = shell.position
        snailNode.addChild(swirl)
        // Closed sleepy eyes on the eye-stalk tips.
        for side in [-1.0, 1.0] {
            let stalk = SKShapeNode(rect: CGRect(x: -1.5 * s, y: 0, width: 3 * s, height: 12 * s), cornerRadius: 1.5 * s)
            stalk.fillColor = WarmShelfPalette.sand.withAlpha(0.95)
            stalk.strokeColor = .clear
            stalk.position = CGPoint(x: (-18 + side * 4) * s, y: 6 * s)
            snailNode.addChild(stalk)
        }
    }

    /// Returns a short text for VoiceOver.
    var accessibilityName: String {
        switch kind {
        case .pond: return "little pond"
        case .tree: return "tree"
        case .log: return "hollow log"
        case .snailRock: return "sleepy snail"
        case .rock: return "mossy rock"
        case .bush: return "berry bush"
        }
    }

    /// React to a tap. Returns an optional scene-space point where a creature should spawn.
    @discardableResult
    func poke(in scene: SKScene) -> Bool {
        switch kind {
        case .pond:
            for index in 0..<3 {
                let ripple = SKShapeNode(ellipseOf: CGSize(width: 40 * scaleFactor, height: 12 * scaleFactor))
                ripple.fillColor = .clear
                ripple.strokeColor = WarmShelfPalette.bubbleHighlight.withAlpha(0.5)
                ripple.lineWidth = 2
                ripple.position = CGPoint(x: 0, y: 8 * scaleFactor)
                ripple.alpha = 0
                addChild(ripple)
                let grow = SKAction.scale(to: 2.6 + CGFloat(index) * 0.5, duration: 0.9)
                grow.timingMode = .easeOut
                ripple.run(.sequence([
                    .wait(forDuration: Double(index) * 0.12),
                    .group([grow, .sequence([.fadeAlpha(to: 0.7, duration: 0.12), .fadeOut(withDuration: 0.78)])]),
                    .removeFromParent()
                ]))
            }
            surfaceFish()
            return false
        case .tree:
            if let canopy = childNode(withName: "treeCanopy") {
                canopy.run(.sequence([
                    .rotate(byAngle: 0.05, duration: 0.12),
                    .rotate(byAngle: -0.08, duration: 0.16),
                    .rotate(byAngle: 0.03, duration: 0.18)
                ]))
            }
            for _ in 0..<3 {
                let leaf = SKShapeNode(ellipseOf: CGSize(width: 16 * scaleFactor, height: 9 * scaleFactor))
                leaf.fillColor = WarmShelfPalette.sage.withAlpha(0.85)
                leaf.strokeColor = .clear
                leaf.position = CGPoint(x: CGFloat.random(in: -40...40) * scaleFactor, y: 175 * scaleFactor)
                addChild(leaf)
                let fall = SKAction.moveBy(x: CGFloat.random(in: -30...30) * scaleFactor, y: -175 * scaleFactor, duration: Double.random(in: 1.4...2.2))
                fall.timingMode = .easeIn
                let sway = SKAction.repeatForever(.sequence([.rotate(byAngle: 0.4, duration: 0.4), .rotate(byAngle: -0.4, duration: 0.4)]))
                leaf.run(.group([sway, .sequence([fall, .fadeOut(withDuration: 0.3), .removeFromParent()])]))
            }
            shakeDownFruit()
            return Bool.random()  // sometimes a bird/butterfly also flits out
        case .log:
            return true  // spawns a butterfly from the hollow
        case .snailRock:
            wakeSnail()
            return false
        case .rock:
            // A little beetle scurries out from under the rock.
            run(.sequence([.moveBy(x: 0, y: 3 * scaleFactor, duration: 0.08), .moveBy(x: 0, y: -3 * scaleFactor, duration: 0.12)]))
            let beetle = SKShapeNode(ellipseOf: CGSize(width: 16 * scaleFactor, height: 10 * scaleFactor))
            beetle.fillColor = WarmShelfPalette.cocoa.withAlpha(0.85); beetle.strokeColor = .clear
            beetle.position = CGPoint(x: 0, y: 6 * scaleFactor); beetle.zPosition = -1
            addChild(beetle)
            let dir: CGFloat = Bool.random() ? 1 : -1
            beetle.run(.sequence([.moveBy(x: dir * 90 * scaleFactor, y: 0, duration: 1.2), .fadeOut(withDuration: 0.3), .removeFromParent()]))
            return false
        case .bush:
            // Rustle, and jiggle the berries — one may drop.
            for child in children where child.name == "bushBerry" {
                child.run(.sequence([.moveBy(x: 0, y: 4 * scaleFactor, duration: 0.1), .moveBy(x: 0, y: -4 * scaleFactor, duration: 0.14)]))
            }
            if let berry = children.first(where: { $0.name == "bushBerry" }) {
                let drop = berry.copy() as! SKShapeNode
                drop.position = berry.position
                addChild(drop)
                drop.run(.sequence([.moveTo(y: 4 * scaleFactor, duration: 0.4), .group([.scaleX(to: 1.2, y: 0.8, duration: 0.08), .fadeOut(withDuration: 0.8)]), .removeFromParent()]))
            }
            return Bool.random()
        }
    }

    private func surfaceFish() {
        let s = scaleFactor
        let fish = SKNode()
        let bodyF = SKShapeNode(ellipseOf: CGSize(width: 28 * s, height: 16 * s))
        bodyF.fillColor = WarmShelfPalette.terracotta.withAlpha(0.92); bodyF.strokeColor = .clear
        fish.addChild(bodyF)
        let tail = SKShapeNode(path: {
            let p = CGMutablePath(); p.move(to: CGPoint(x: -12 * s, y: 0)); p.addLine(to: CGPoint(x: -22 * s, y: 8 * s)); p.addLine(to: CGPoint(x: -22 * s, y: -8 * s)); p.closeSubpath(); return p
        }())
        tail.fillColor = WarmShelfPalette.petal.withAlpha(0.9); tail.strokeColor = .clear; fish.addChild(tail)
        let eye = SKShapeNode(circleOfRadius: 2.4 * s); eye.fillColor = WarmShelfPalette.cocoa.withAlpha(0.85); eye.strokeColor = .clear; eye.position = CGPoint(x: 7 * s, y: 3 * s); fish.addChild(eye)

        fish.position = CGPoint(x: CGFloat.random(in: -40...40) * s, y: 6 * s)
        fish.zPosition = 8
        fish.setScale(0.6); fish.alpha = 0
        addChild(fish)
        let up = SKAction.group([.moveBy(x: 12 * s, y: 46 * s, duration: 0.32), .rotate(byAngle: -0.5, duration: 0.32), .fadeAlpha(to: 1, duration: 0.1), .scale(to: 1, duration: 0.2)])
        up.timingMode = .easeOut
        let down = SKAction.group([.moveBy(x: 12 * s, y: -46 * s, duration: 0.3), .rotate(byAngle: -0.7, duration: 0.3)])
        down.timingMode = .easeIn
        fish.run(.sequence([up, down, .fadeOut(withDuration: 0.1), .removeFromParent()]))
    }

    private func shakeDownFruit() {
        let s = scaleFactor
        for _ in 0..<Int.random(in: 1...2) {
            let fruit = SKShapeNode(circleOfRadius: 8 * s)
            fruit.fillColor = [WarmShelfPalette.terracotta, WarmShelfPalette.rhubarb, WarmShelfPalette.butter].randomElement()!.withAlpha(0.95)
            fruit.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.06); fruit.lineWidth = 1
            fruit.position = CGPoint(x: CGFloat.random(in: -42...42) * s, y: 165 * s)
            fruit.zPosition = 7
            addChild(fruit)
            let fall = SKAction.moveTo(y: 8 * s, duration: 0.5); fall.timingMode = .easeIn
            let squish = SKAction.sequence([.scaleX(to: 1.2, y: 0.8, duration: 0.08), .scale(to: 1, duration: 0.12)])
            // Bounce: quick pop up (0.10s easeOut), slow settle back (0.20s easeInEaseOut).
            let bounceUp = SKAction.moveBy(x: 0, y: 10 * s, duration: 0.10); bounceUp.timingMode = .easeOut
            let bounceDown = SKAction.moveBy(x: 0, y: -10 * s, duration: 0.20); bounceDown.timingMode = .easeInEaseOut
            let bounce = SKAction.sequence([bounceUp, bounceDown])
            fruit.run(.sequence([fall, .group([squish, bounce]), .wait(forDuration: 1.8), .group([.fadeOut(withDuration: 0.5), .scale(to: 0.6, duration: 0.5)]), .removeFromParent()]))
        }
    }

    private func wakeSnail() {
        guard let snail else { return }
        snailAwake.toggle()
        // A happy wiggle and a little glide.
        let wiggle = SKAction.sequence([
            .rotate(byAngle: 0.12, duration: 0.12),
            .rotate(byAngle: -0.18, duration: 0.16),
            .rotate(byAngle: 0.06, duration: 0.14)
        ])
        let glide = SKAction.sequence([
            .moveBy(x: 18 * scaleFactor, y: 0, duration: 0.8),
            .moveBy(x: -18 * scaleFactor, y: 0, duration: 0.9)
        ])
        glide.timingMode = .easeInEaseOut
        snail.run(.group([wiggle, glide]))
    }
}
