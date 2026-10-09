import SpriteKit
import QuartzCore
import UIKit

/// Meadow — the ladybug who carries spring. A top-down endless-feeling meadow, dormant
/// pale winter felt as far as the eye can see. Lead her anywhere and her aura paints
/// moss, flowers, and warmth directly into the world. No loop to understand; the verb is
/// simply "lead her, and spring follows."
///
/// The camera follows the snail (inverse-world scroll, so the home chip stays put).
/// All motion authored. Slow is the toy.
final class MeadowScene: BaseToyScene {

    override var toyVoice: AudioManager.LullSoundVoice { .glowboard }
    override var firstSessionHintKey: String? { "hint.meadow" }
    override func firstSessionHintPoint() -> CGPoint {
        guard let snail else { return CGPoint(x: size.width / 2, y: size.height / 2) }
        return worldNode.convert(snail.position, to: self)
    }

    // MARK: - World
    private let worldNode = SKNode()      // everything lives here; scrolls opposite the snail
    private let groundLayer = SKNode()
    private let springLayer = SKNode()    // painted spring patches
    private let trailLayer = SKNode()
    private let lifeLayer = SKNode()      // flowers, butterflies
    private let snailLayer = SKNode()
    private let goldenVeil = SKSpriteNode()
    private var worldSize = CGSize.zero
    // Spring is ONE moss surface laid over the whole world and revealed only where the
    // ladybug has been: soft stamps form the reveal mask, and a feathered moss-coloured
    // edge sits under it. One texture scale everywhere (each old disc re-stretched the
    // moss into its own circle and wore a translucent ring, so the garden read as
    // overlapping stickers) and a bounded node count.
    private let springReveal = SKCropNode()
    private let springMask = SKNode()
    private let springFringe = SKNode()
    /// Honest coverage: coarse world cells the spring has actually reached. Also the
    /// de-dupe that stops a child circling one spot from piling up thousands of nodes.
    private var paintedCells = Set<Int>()
    private var coverCell: CGFloat = 24
    /// Fraction of the world that must be spring for the full-bloom moment. The old 0.4
    /// summed every overlapping stamp, so it fired after ~45s of leading; true coverage
    /// of 0.10 keeps that pacing.
    private let bloomCoverage: CGFloat = 0.10
    private var springEdgeColor: UIColor { isNight ? UIColor(hex: 0x6B7487) : UIColor(hex: 0x909947) }

    // MARK: - Snail
    private var snail: SKNode?
    private weak var snailShell: SKNode?
    private weak var wandererSprite: SKSpriteNode?   // the ladybug, when her art leads
    private var wandererRest: SKTexture?
    private var wandererFlutter: SKTexture?
    private var snailEyes: [SKShapeNode] = []
    private var snailTarget: CGPoint?     // world coords
    private var leadTouch: UITouch?
    private var snailAwake = false
    private var lastMeadowTouchTime: TimeInterval = 0   // for the recurring "lead me" invite
    private var lastInviteTime: TimeInterval = 0

    // MARK: - Spring (painted garden)
    private var springPaths: [CGPath] = []
    private var springArea: CGFloat = 0
    private var trailPoints: [CGPoint] = []
    private var trailNode: SKShapeNode?   // the bright living core
    private var trailHalo: SKShapeNode?   // the soft translucent magic around it
    private var petalBudget = 0           // live drifting petals, capped
    private var flowerTrail = MeadowFlowerTrail()
    private var flowerTrailNodes: [SKNode] = []
    // Spring is PAINTED where she's led — a soft mossy bloom laid inside her aura as she
    // moves (founder: a beautiful aura creating spring, not a loop to close).
    private var paintRadius: CGFloat = 60
    private var paintStep: CGFloat = 30
    private var lastPaintPoint: CGPoint?
    private var paintedSpringPoints: [CGPoint] = []
    private weak var springAura: SKSpriteNode?   // the glow around her that makes the spring
    private var flowers: [SKNode] = []
    private var bloomMomentFired = false
    private weak var dandelion: SKNode?
    private var butterflies: [SKNode] = []

    private var lastUpdateTime: TimeInterval = 0
    private var lastTone: [String: TimeInterval] = [:]
    private var lastBuiltSize = CGSize.zero

    private let trailStep: CGFloat = 12
    private let trailWidth: CGFloat = 26
    // MARK: - Landmarks (approved delight: destinations that wake)
    private var landmarks: [MeadowLandmark] = []
    private let springColor = UIColor(hex: 0x8FBE74)
    // Dormant != dead: late-winter sage-straw, already secretly green, so painted spring
    // reads as awakening rather than a hard cliff (founder daytime-contrast note).
    private let winterColor = UIColor(hex: 0xB4B889)
    private let winterNightColor = UIColor(hex: 0x9A9AAC)

    /// The meadow keeps the household's hours, like the Window and the Shelf Room.
    private var isNight: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.environment["LULL_DEBUG_MEADOW_NIGHT"] == "1" { return true }
        if ProcessInfo.processInfo.environment["LULL_DEBUG_MEADOW_NIGHT"] == "0" { return false }
        #endif
        return TimeOfDay.sky.isNight
    }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        AudioManager.shared.prewarm(prefixes: ["meadow.", "bird"])
        for degree in 12...19 {
            AudioManager.shared.prewarm(cue: "note.kalimba.\(degree)")
            AudioManager.shared.prewarm(cue: "note.glock.\(degree)")
        }
        ambientMoteInterval = 8
        addChild(worldNode)
        worldNode.zPosition = 1
        groundLayer.zPosition = 0;  worldNode.addChild(groundLayer)
        springLayer.zPosition = 2;  worldNode.addChild(springLayer)
        trailLayer.zPosition = 4;   worldNode.addChild(trailLayer)
        lifeLayer.zPosition = 6;    worldNode.addChild(lifeLayer)
        snailLayer.zPosition = 9;   worldNode.addChild(snailLayer)
        goldenVeil.zPosition = 30
        addChild(goldenVeil)
        rebuild()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 160, size.height > 160,
              abs(size.width - lastBuiltSize.width) > 2 || abs(size.height - lastBuiltSize.height) > 2 else { return }
        // A rotation must NEVER cost the child their garden (founder, June 12).
        // World coordinates are rotation-stable (worldSize keys off max(w,h)), so
        // every painted patch, flower, woken landmark and the wanderer herself carry over.
        let snap: MeadowSnap? = springPaths.isEmpty && paintedSpringPoints.isEmpty && flowerTrail.positions.isEmpty ? nil : MeadowSnap(
            paths: springPaths,
            paintStamps: paintedSpringPoints,
            area: springArea,
            bloomFired: bloomMomentFired,
            dandelionPosition: dandelion?.position,
            snailPos: snail?.position ?? .zero,
            trail: trailPoints,
            flowerSpots: flowers.compactMap { $0.parent != nil ? $0.position : nil },
            flowerTrail: flowerTrail,
            landmarksAwake: landmarks.map { $0.isAwake }
        )
        rebuild(restoring: snap)
    }

    private struct MeadowSnap {
        let paths: [CGPath]
        let paintStamps: [CGPoint]
        let area: CGFloat
        let bloomFired: Bool
        let dandelionPosition: CGPoint?
        let snailPos: CGPoint
        let trail: [CGPoint]
        let flowerSpots: [CGPoint]
        let flowerTrail: MeadowFlowerTrail
        let landmarksAwake: [Bool]
    }

    private func rebuild(restoring snap: MeadowSnap? = nil) {
        guard size.width > 160, size.height > 160 else { return }
        lastBuiltSize = size
        removeAction(forKey: "meadow.dandelionOffer")
        [groundLayer, springLayer, trailLayer, lifeLayer, snailLayer].forEach { $0.removeAllChildren() }
        flowers.removeAll(); butterflies.removeAll(); landmarks.removeAll()
        springPaths.removeAll(); trailPoints.removeAll(); trailNode = nil
        trailHalo = nil; petalBudget = 0
        springArea = 0; bloomMomentFired = false
        snailTarget = nil
        leadTouch = nil
        lastPaintPoint = nil
        paintedSpringPoints.removeAll()
        paintRadius = min(max(min(size.width, size.height) * 0.13, 48), 72) // the bloom her aura paints
        paintStep = paintRadius * 0.72                                      // overlap, so the garden is seamless
        coverCell = paintRadius * 0.5
        paintedCells.removeAll()

        worldSize = CGSize(width: max(size.width, size.height) * 2.6,
                           height: max(size.width, size.height) * 2.6)

        buildWinterGround()
        buildSpringSurface()
        if snap == nil { buildHomeSpring() }   // a restored garden brings its own home
        buildLandmarks()
        buildSnail()
        buildFlowerTrail()

        goldenVeil.size = size
        goldenVeil.position = CGPoint(x: size.width / 2, y: size.height / 2)
        goldenVeil.color = UIColor(hex: 0xFFC979)
        goldenVeil.blendMode = .add
        goldenVeil.alpha = 0

        if let snap {
            for path in snap.paths {
                addSpringPolygon(path, area: 0, sprinkle: 0, animated: false)
            }
            for p in snap.paintStamps {
                paintSpringStamp(at: p, animated: false, record: false)
            }
            paintedSpringPoints = snap.paintStamps
            springArea = snap.area
            bloomMomentFired = snap.bloomFired
            updateSpringGlow(allowMoment: false)
            for p in snap.flowerSpots { bloomRosette(at: p, silent: true) }
            flowerTrail = snap.flowerTrail
            for (slot, position) in flowerTrail.positions.enumerated() {
                flowerTrailNodes[slot].position = position
                flowerTrailNodes[slot].isHidden = false
            }
            for (lm, awake) in zip(landmarks, snap.landmarksAwake) where awake {
                lm.wake(instantly: true)
            }
            snail?.position = snap.snailPos
            if snap.bloomFired {
                if let puffPosition = snap.dandelionPosition {
                    offerDandelion(at: puffPosition, animated: false)
                } else {
                    scheduleDandelionOffer()
                }
            }
            trailPoints = snap.trail
            redrawTrail()
        }
        centerCamera(animated: false)

        #if DEBUG
        // LULL_DEBUG_MEADOW_DEMO=1 leads the snail out of home and back (QA / store shots).
        if snap == nil, ProcessInfo.processInfo.environment["LULL_DEBUG_MEADOW_DEMO"] == "1" {
            runMeadowDemo()
            return
        }
        #endif

        // First ever open: she teaches by doing — one small self-led wander out of
        // the garden, painting spring behind her. Show, never tell.
        if snap == nil, !LullDemoState.shared.hasSeenHint("meadow.watchme") {
            LullDemoState.shared.markHintSeen("meadow.watchme")
            runWatchMeLoop()
        }
    }

    /// A small autonomous wander: out the doorstep, over the top, home — ~7s.
    private func runWatchMeLoop() {
        setSnailAwake(true)
        let r = min(size.width, size.height) * 0.42
        var actions: [SKAction] = [.wait(forDuration: 1.4)]
        let waypoints: [CGPoint] = (0...6).map { i in
            let a = CGFloat(i) / 6 * .pi
            return CGPoint(x: cos(a) * r, y: sin(a) * r * 0.9)
        } + [.zero]
        for wp in waypoints {
            actions.append(.run { [weak self] in self?.snailTarget = wp })
            actions.append(.wait(forDuration: 0.55))
        }
        actions.append(.wait(forDuration: 1.8))
        actions.append(.run { [weak self] in
            guard let self else { return }
            self.snailTarget = nil
            self.setSnailAwake(false)
        })
        run(.sequence(actions), withKey: "watchme")
    }

    // MARK: - The dormant world

    private func buildWinterGround() {
        // Authored winter ground when it lands (night variant after dark); pale
        // sleeping felt otherwise — slate-moonlit when the household sleeps.
        let night = isNight
        let slot = night ? "meadow-winter-ground-night" : "meadow-winter-ground"
        let base = night ? winterNightColor : winterColor
        let groundArt = ToyArt.texture(slot) ?? (night ? ToyArt.texture("meadow-winter-ground") : nil)
        if let tex = groundArt {
            // Tiled at the art's own size (mirrored so every seam meets itself) instead of
            // one plate stretched over the whole world — that was a ~5x upscale that turned
            // the felt into blur next to the crisp creatures.
            let moonlit = night && ToyArt.texture(slot) == nil   // day art moonlit until night art lands
            addTiles(of: tex, to: groundLayer, tint: moonlit ? UIColor(hex: 0x2A2E4A) : nil)
        } else {
            let extent = MeadowWorldGeometry.groundSize(worldSize: worldSize)
            let ground = SKShapeNode(rectOf: extent)
            ground.fillColor = base
            ground.strokeColor = .clear
            groundLayer.addChild(ground)
            ProceduralTexture.applyClayFill(to: ground, base: base, size: extent)
        }

        if night {
            // Moonlight pools softly over the sleeping world.
            let moonVeil = SKShapeNode(rectOf: MeadowWorldGeometry.groundSize(worldSize: worldSize))
            moonVeil.fillColor = UIColor(hex: 0x20243A).withAlpha(0.12)
            moonVeil.strokeColor = .clear
            moonVeil.zPosition = 20
            groundLayer.addChild(moonVeil)
        }

        // Sleeping tufts and pebbles drifted across the whole world — quiet landmarks
        // so moving feels like going somewhere. The authored felt already carries its own
        // tufts; flat vector ovals on top of it only broke the material.
        guard groundArt == nil else { return }
        for _ in 0..<70 {
            let p = CGPoint(x: .random(in: -worldSize.width/2 + 60 ... worldSize.width/2 - 60),
                            y: .random(in: -worldSize.height/2 + 60 ... worldSize.height/2 - 60))
            if Bool.random() {
                let tuft = SKShapeNode(ellipseOf: CGSize(width: .random(in: 14...26), height: .random(in: 6...10)))
                tuft.fillColor = (night ? UIColor(hex: 0x8B8DA3) : UIColor(hex: 0xA6AB78)).withAlpha(0.8)
                tuft.strokeColor = .clear
                tuft.position = p
                tuft.zPosition = 0.2
                groundLayer.addChild(tuft)
            } else {
                let pebble = SKShapeNode(ellipseOf: CGSize(width: .random(in: 10...18), height: .random(in: 8...14)))
                pebble.fillColor = night ? UIColor(hex: 0x8E90A6) : UIColor(hex: 0xB0B48C)
                pebble.strokeColor = (night ? UIColor(hex: 0x787A90) : UIColor(hex: 0x969B6F)).withAlpha(0.6)
                pebble.lineWidth = 1
                pebble.position = p
                pebble.zPosition = 0.2
                groundLayer.addChild(pebble)
            }
        }
    }

    /// Covers the world with one texture at its native point size, mirrored tile to tile
    /// so edges always meet. All tiles share a texture, so they draw as one batch.
    private func addTiles(of tex: SKTexture, to parent: SKNode, tint: UIColor?, tintFactor: CGFloat = 0.4) {
        let ts = tex.size()
        let side = max(256, min(ts.width, ts.height))
        let nx = Int(ceil(worldSize.width / side)), ny = Int(ceil(worldSize.height / side))
        let originX = -CGFloat(nx) * side / 2, originY = -CGFloat(ny) * side / 2
        // One extra ring bleeds beyond the invisible play bounds, so the felt has no rim.
        for i in -1..<(nx + 1) {
            for j in -1..<(ny + 1) {
                let tile = SKSpriteNode(texture: tex)
                tile.size = CGSize(width: side, height: side)
                tile.position = CGPoint(x: originX + (CGFloat(i) + 0.5) * side,
                                        y: originY + (CGFloat(j) + 0.5) * side)
                if !i.isMultiple(of: 2) { tile.xScale = -1 }
                if !j.isMultiple(of: 2) { tile.yScale = -1 }
                if let tint { tile.color = tint; tile.colorBlendFactor = tintFactor }
                parent.addChild(tile)
            }
        }
    }

    /// The one spring surface: world-aligned moss (muted toward the felt palette — the raw
    /// texture is acid lime next to the straw winter and the clay creatures), shown only
    /// through the stamps in `springMask`, over a feathered edge in `springFringe`.
    private func buildSpringSurface() {
        springFringe.removeFromParent()
        springReveal.removeFromParent()
        springReveal.removeAllChildren()
        springMask.removeAllChildren()
        springFringe.removeAllChildren()
        springReveal.removeAllActions(); springFringe.removeAllActions()
        springReveal.alpha = 1
        springFringe.alpha = 1
        springReveal.maskNode = springMask
        springFringe.zPosition = 0
        springReveal.zPosition = 1
        springLayer.addChild(springFringe)
        springLayer.addChild(springReveal)

        let night = isNight
        if let moss = ToyArt.texture("meadow-spring-moss") {
            addTiles(of: moss, to: springReveal, tint: night ? UIColor(hex: 0x9AA0B8) : nil, tintFactor: 1)
        } else {
            springReveal.addChild(SKSpriteNode(color: night ? UIColor(hex: 0x5E7361) : springColor, size: worldSize))
        }
        let veil = SKSpriteNode(color: night ? UIColor(hex: 0x3E4560) : UIColor(hex: 0xB8B48E), size: worldSize)
        veil.alpha = night ? 0.35 : 0.30
        veil.zPosition = 1
        springReveal.addChild(veil)
    }

    /// A solid disc with an anti-aliased rim: one stamp of the spring reveal mask.
    private static let stampTexture: SKTexture = {
        let side: CGFloat = 128
        let img = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { ctx in
            UIColor.white.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 1, y: 1, width: side - 2, height: side - 2))
        }
        return SKTexture(image: img)
    }()

    /// Solid to 70% of its radius, then feathering to nothing: the soft felt edge where
    /// spring meets winter.
    private static let featherTexture: SKTexture = {
        let side: CGFloat = 128
        let img = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { ctx in
            let colors = [UIColor.white.cgColor, UIColor.white.cgColor,
                          UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: colors, locations: [0, 0.7, 1]) else { return }
            let c = CGPoint(x: side / 2, y: side / 2)
            ctx.cgContext.drawRadialGradient(grad, startCenter: c, startRadius: 0,
                                             endCenter: c, endRadius: side / 2, options: [])
        }
        return SKTexture(image: img)
    }()

    private func coverKey(_ ix: Int, _ iy: Int) -> Int { (ix &+ 4096) &* 8192 &+ (iy &+ 4096) }

    /// Marks the coverage cells a disc reaches; returns how many were new ground.
    @discardableResult
    private func markCovered(center p: CGPoint, radius r: CGFloat) -> Int {
        let c = coverCell
        let x0 = Int(floor((p.x - r) / c)), x1 = Int(floor((p.x + r) / c))
        let y0 = Int(floor((p.y - r) / c)), y1 = Int(floor((p.y + r) / c))
        var fresh = 0
        for ix in x0...x1 {
            for iy in y0...y1 {
                let cx = (CGFloat(ix) + 0.5) * c, cy = (CGFloat(iy) + 0.5) * c
                guard hypot(cx - p.x, cy - p.y) <= r else { continue }
                if paintedCells.insert(coverKey(ix, iy)).inserted { fresh += 1 }
            }
        }
        return fresh
    }

    private var springCoverage: CGFloat {
        CGFloat(paintedCells.count) * coverCell * coverCell / max(1, worldSize.width * worldSize.height)
    }

    /// The warm glow grows with the spring, and the full-bloom moment fires once it is
    /// truly widespread — only from live play, never from a rotation restore.
    private func updateSpringGlow(allowMoment: Bool) {
        let progress = springCoverage / bloomCoverage
        goldenVeil.alpha = min(0.16, progress * 0.12)
        if allowMoment, progress >= 1, !bloomMomentFired {
            bloomMomentFired = true
            fireBloomMoment()
        }
    }

    /// Home: the snail's own little spring garden — territory exists from second zero.
    private func buildHomeSpring() {
        let r: CGFloat = min(size.width, size.height) * 0.30
        let path = CGPath(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2), transform: nil)
        addSpringPolygon(path, area: .pi * r * r, sprinkle: 5, animated: false)
    }

    /// Approved delight: landmark seeds. A few fixed sleepers far out in the winter —
    /// a mossy rock, an old stump — give the endless world somewhere to walk TO.
    /// Her aura wakes them. No marker, no arrow, no objective.
    private func buildLandmarks() {
        let night = isNight
        let spots: [(CGFloat, CGFloat, MeadowLandmark.Kind)] = [
            (-0.27, 0.21, .rock),
            (0.26, -0.23, .stump),
            (0.04, 0.34, .mushroom),
            (-0.23, -0.30, .pebbles),
            (0.31, 0.13, .pond),
            (-0.33, -0.07, .stump),
            (0.10, -0.38, .rock)
        ]
        for (fx, fy, kind) in spots {
            let lm = MeadowLandmark(kind: kind, night: night)
            lm.position = CGPoint(x: worldSize.width * fx, y: worldSize.height * fy)
            lm.zPosition = 1
            lm.setScale(.random(in: 0.92...1.08))
            // Only art drawn from straight above can be turned; a side-view mushroom or
            // rock spun on the ground reads as tipping over.
            lm.zRotation = kind.isTopDown ? .random(in: -0.3...0.3) : 0
            lifeLayer.addChild(lm)
            landmarks.append(lm)
        }

        #if DEBUG
        // LULL_DEBUG_MEADOW_LANDMARK=1 parks a rock + stump beside home and wakes
        // them after 6s — art/state inspection without the long walk.
        if ProcessInfo.processInfo.environment["LULL_DEBUG_MEADOW_LANDMARK"] == "1" {
            for (i, kind) in MeadowLandmark.Kind.allCases.enumerated() {
                let lm = MeadowLandmark(kind: kind, night: night)
                lm.position = CGPoint(x: -240 + CGFloat(i) * 120, y: 200)
                lm.zPosition = 1
                lifeLayer.addChild(lm)
                landmarks.append(lm)
            }
            run(.sequence([.wait(forDuration: 6.0), .run { [weak self] in
                self?.landmarks.suffix(MeadowLandmark.Kind.allCases.count).forEach { $0.wake() }
            }]))
        }
        #endif
    }

    // MARK: - The snail (seen from above; the shell spiral is the hero)

    private func buildSnail() {
        let s: CGFloat = min(size.width, size.height) * 0.05    // founder round 2: smaller still
        let snailRoot = SKNode()
        snailRoot.position = .zero
        snailLayer.addChild(snailRoot)
        snail = snailRoot

        // Her spring aura — the beautiful glow that MAKES the world bloom wherever she's
        // led (founder, June 14). A soft warm-green pool of light that breathes, sitting
        // exactly over the radius she paints, so the magic reads as coming from her.
        let aura = SKSpriteNode(texture: ProceduralTexture.softRadialGlow)
        aura.size = CGSize(width: paintRadius * 4.2, height: paintRadius * 4.2)
        aura.color = isNight ? UIColor(hex: 0xBFE6C8) : UIColor(hex: 0xE8F7A8)
        aura.colorBlendFactor = 1
        aura.blendMode = .add
        aura.alpha = isNight ? 0.30 : 0.24
        aura.zPosition = -0.5
        snailRoot.addChild(aura)
        springAura = aura
        if !AmbientAnimator.reduceMotion {
            aura.run(.repeatForever(.sequence([
                .group([.scale(to: 1.12, duration: 1.6), .fadeAlpha(to: isNight ? 0.40 : 0.34, duration: 1.6)]),
                .group([.scale(to: 1.0, duration: 1.8), .fadeAlpha(to: isNight ? 0.30 : 0.24, duration: 1.8)])
            ])), withKey: "auraBreathe")
        }

        let shadow = SKSpriteNode(texture: ProceduralTexture.softClayShadow(size: CGSize(width: s * 2.6, height: s * 2.0)))
        shadow.position = CGPoint(x: s * 0.1, y: -s * 0.15)
        shadow.alpha = 0.7
        shadow.zPosition = -1
        snailRoot.addChild(shadow)

        // The wanderer: ladybug first when her art lands (founder, June 12 — round shell,
        // crisp heading, no teal history), the snail as the faithful fallback.
        let ladybug = ToyArt.sprite("meadow-ladybug-top", fit: CGSize(width: s * 2.2, height: s * 2.2))
        if let art = ladybug ?? ToyArt.sprite("meadow-snail-top", fit: CGSize(width: s * 3.0, height: s * 2.6)) {
            art.zPosition = 1
            if ladybug != nil {
                // Her head points UP in the art; the body faces +X in motion space.
                // Without this she walks sideways and her long axis swings huge on
                // turns (founder device QA, June 12).
                art.zRotation = -.pi / 2
            }
            snailRoot.addChild(art)
            if ladybug != nil, let flutter = ToyArt.texture("meadow-ladybug-flutter") {
                wandererSprite = art
                wandererRest = art.texture
                wandererFlutter = flutter
            }
        } else {
            // Top-down: a soft oat body peeking ahead of the spiral shell.
            let body = SKShapeNode(path: CGPath(roundedRect: CGRect(x: -s * 0.5, y: -s * 0.55, width: s * 2.2, height: s * 1.1),
                                                cornerWidth: s * 0.55, cornerHeight: s * 0.55, transform: nil))
            body.fillColor = UIColor(hex: 0xD9C7A4)
            body.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.14)
            body.lineWidth = 1.5
            body.zPosition = 0.4
            snailRoot.addChild(body)
            ProceduralTexture.applyClayFill(to: body, base: UIColor(hex: 0xD9C7A4), size: CGSize(width: s * 2.2, height: s * 1.1))

            // Tiny antennae forward.
            for sy in [-s * 0.22, s * 0.22] {
                let antenna = SKShapeNode(circleOfRadius: s * 0.12)
                antenna.fillColor = UIColor(hex: 0xCBB892)
                antenna.strokeColor = .clear
                antenna.position = CGPoint(x: s * 1.85, y: sy)
                antenna.zPosition = 0.45
                snailRoot.addChild(antenna)
            }

            let shell = SKNode()
            shell.position = CGPoint(x: -s * 0.1, y: 0)
            shell.zPosition = 1
            snailRoot.addChild(shell)
            snailShell = shell
            for (i, factor) in [1.0, 0.66, 0.34].enumerated() {
                let ring = SKShapeNode(circleOfRadius: s * 1.05 * factor)
                ring.fillColor = i == 0 ? WarmShelfPalette.terracotta : WarmShelfPalette.terracotta.withAlpha(i == 1 ? 0.8 : 0.62)
                ring.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.16)
                ring.lineWidth = 1.5
                ring.position = CGPoint(x: s * 0.06 * CGFloat(i), y: s * 0.04 * CGFloat(i))
                shell.addChild(ring)
            }
            let spiralDot = SKShapeNode(circleOfRadius: s * 0.12)
            spiralDot.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.7)
            spiralDot.strokeColor = .clear
            spiralDot.position = CGPoint(x: s * 0.16, y: s * 0.1)
            shell.addChild(spiralDot)

            // The sleepy eyes ride the head, readable from above.
            let ink = WarmShelfPalette.cocoa.withAlpha(0.6)
            snailEyes.removeAll()
            for sy in [-s * 0.2, s * 0.2] {
                let eye = SKShapeNode(path: MeadowScene.eyePath(open: false, s: s))
                eye.position = CGPoint(x: s * 1.45, y: sy)
                eye.zRotation = -.pi / 2
                eye.strokeColor = ink
                eye.fillColor = .clear
                eye.lineWidth = max(1.6, s * 0.07)
                eye.lineCap = .round
                eye.zPosition = 0.8
                snailRoot.addChild(eye)
                snailEyes.append(eye)
            }
        }

        if !AmbientAnimator.reduceMotion {
            snailRoot.run(.repeatForever(.sequence([
                .scale(to: 1.03, duration: 1.9), .scale(to: 1.0, duration: 2.1)
            ])), withKey: "breathe")
        }
    }

    private static func eyePath(open: Bool, s: CGFloat) -> CGPath {
        if open {
            return CGPath(ellipseIn: CGRect(x: -s * 0.08, y: -s * 0.04, width: s * 0.16, height: s * 0.18), transform: nil)
        }
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -s * 0.1, y: 0))
        p.addQuadCurve(to: CGPoint(x: s * 0.1, y: 0), control: CGPoint(x: 0, y: -s * 0.09))
        return p
    }

    private func setSnailAwake(_ awake: Bool) {
        guard snailAwake != awake else { return }
        snailAwake = awake
        let s: CGFloat = min(size.width, size.height) * 0.075
        for eye in snailEyes {
            eye.path = MeadowScene.eyePath(open: awake, s: s)
            eye.fillColor = awake ? WarmShelfPalette.cocoa.withAlpha(0.7) : .clear
            eye.strokeColor = awake ? .clear : WarmShelfPalette.cocoa.withAlpha(0.6)
        }
    }

    // MARK: - Camera (inverse world scroll; chrome stays put)

    private func centerCamera(animated: Bool) {
        guard let snail else { return }
        let target = CGPoint(x: size.width / 2 - snail.position.x,
                             y: size.height / 2 - snail.position.y)
        let clamped = clampWorldOffset(target)
        if animated {
            worldNode.run(.move(to: clamped, duration: 0.4))
        } else {
            worldNode.position = clamped
        }
    }

    /// The world node's offset, kept so the world always covers the whole screen.
    private func clampWorldOffset(_ p: CGPoint) -> CGPoint {
        MeadowWorldGeometry.cameraOffset(p, worldSize: worldSize, canvas: size)
    }

    // MARK: - Touch (lead the snail; world coords via the scrolling node)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        HapticsManager.shared.prepareForTouch()
        lastMeadowTouchTime = lastUpdateTime   // she's been noticed — hush the invite
        snail?.removeAction(forKey: "invite")
        snail?.setScale(1)                     // in case a bob was mid-flight
        for touch in touches {
            let screenP = touch.location(in: self)
            if leadTouch == nil, consumeShelfReturnTouch(at: screenP) { return }
            let p = worldNode.convert(screenP, from: self)

            if let puff = dandelion, puff.parent != nil,
               hypot(p.x - puff.position.x, p.y - puff.position.y) < 80 {
                firstFrost()
                continue
            }
            // Poking a landmark is its own little conversation (founder: they should
            // react). Awake ones delight; sleeping ones stir but keep their secret —
            // the aura can wake them too.
            if let lm = landmarks.first(where: { hypot(p.x - $0.position.x, p.y - $0.position.y) < 75 }) {
                if lm.isAwake {
                    lm.delight()
                    tone("note.glock.\(lm.kind.wakeDegree + 2)", minInterval: 0.3, volume: 0.55)
                } else {
                    // Founder call (June 12): sleepy UNTIL tapped or run over — a tap
                    // wakes them now. Walking near them does the same.
                    lm.wake()
                    wakeSound(lm.kind)
                }
                HapticsManager.shared.impact(style: .soft, intensity: 0.14)
                continue
            }
            if leadTouch == nil {
                leadTouch = touch
                removeAction(forKey: "watchme")
                removeAction(forKey: "trailRest")   // the journey resumes; the dew stays
                snailTarget = MeadowWorldGeometry.leadTarget(p, worldSize: worldSize)
                setSnailAwake(true)
                tone("meadow.wake", minInterval: 0.4)
                HapticsManager.shared.impact(style: .soft, intensity: 0.16)
            } else {
                breeze(at: p)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = leadTouch, touches.contains(touch) else { return }
        snailTarget = MeadowWorldGeometry.leadTarget(
            worldNode.convert(touch.location(in: self), from: self), worldSize: worldSize
        )
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = leadTouch, touches.contains(touch) { endLead() }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = leadTouch, touches.contains(touch) { endLead() }
    }

    private func endLead() {
        leadTouch = nil
        snailTarget = nil
        run(.sequence([.wait(forDuration: 1.6), .run { [weak self] in
            guard let self, self.snailTarget == nil else { return }
            self.setSnailAwake(false)
        }]), withKey: "doze")
        // The painted garden stays; her glowing wake settles softly when she stops.
        if !trailPoints.isEmpty {
            run(.sequence([.wait(forDuration: 1.3), .run { [weak self] in
                self?.restTrail()
            }]), withKey: "trailRest")
        }
    }

    /// Her wake fades when she rests — the garden she painted remains.
    private func restTrail() {
        guard snailTarget == nil, !trailPoints.isEmpty else { return }
        trailPoints.removeAll()
        lastPaintPoint = nil
        if let line = trailNode {
            trailNode = nil
            line.run(.sequence([.fadeOut(withDuration: 1.4), .removeFromParent()]))
        }
        if let halo = trailHalo {
            trailHalo = nil
            halo.run(.sequence([.fadeOut(withDuration: 1.4), .removeFromParent()]))
        }
    }

    /// The ladybug parts her shell for a beat — joy, in wing form. (Snail-era: no-op.)
    /// Texture swaps go through direct property assignment with the size re-asserted:
    /// SKAction.setTexture resized her to NATURAL texture size regardless of the
    /// resize flag (founder device QA — "turns HUGE": 227pt of ladybug).
    private func flutterWanderer() {
        guard let sprite = wandererSprite, let rest = wandererRest, let flutter = wandererFlutter,
              !AmbientAnimator.reduceMotion else { return }
        let keep = sprite.size
        func swap(_ t: SKTexture) -> SKAction {
            .run { [weak sprite] in
                sprite?.texture = t
                sprite?.size = keep
            }
        }
        sprite.removeAction(forKey: "flutter")
        sprite.run(.sequence([
            swap(flutter), .wait(forDuration: 0.34),
            swap(rest), .wait(forDuration: 0.2),
            swap(flutter), .wait(forDuration: 0.34),
            swap(rest)
        ]), withKey: "flutter")
    }

    private func breeze(at p: CGPoint) {
        guard !AmbientAnimator.reduceMotion else { return }
        for flower in flowers where hypot(flower.position.x - p.x, flower.position.y - p.y) < 120 {
            flower.removeAction(forKey: "sway")
            flower.run(.sequence([
                .rotate(toAngle: .random(in: 0.08...0.16), duration: 0.18),
                .rotate(toAngle: .random(in: -0.14 ... -0.07), duration: 0.24),
                .rotate(toAngle: 0, duration: 0.3)
            ]), withKey: "sway")
        }
        tone("meadow.breeze", minInterval: 0.5)
    }

    // MARK: - Update (glide, aura, trail)

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        let dt = lastUpdateTime == 0 ? 0 : min(0.05, currentTime - lastUpdateTime)
        lastUpdateTime = currentTime
        guard let snail, dt > 0 else { return }
        // currentTime is absolute uptime — anchor the idle clocks to the first frame.
        if lastMeadowTouchTime == 0 { lastMeadowTouchTime = currentTime; lastInviteTime = currentTime }

        if let target = snailTarget {
            let dx = target.x - snail.position.x
            let dy = target.y - snail.position.y
            let dist = hypot(dx, dy)
            if dist > 6 {
                // A keen little snail: brisk base pace, and it hustles a touch when the
                // finger leads far ahead (playtest: 92 felt sleepy even for a toddler).
                let speed: CGFloat = 150 + min(70, dist * 0.12)
                let step = min(dist, speed * dt)
                let np = CGPoint(x: snail.position.x + dx / dist * step,
                                 y: snail.position.y + dy / dist * step)
                snail.position = clampToWorld(np)
                // Turn smoothly through the shortest arc — never the old hard snap.
                let want = atan2(dy, dx)
                var delta = want - snail.zRotation
                while delta > .pi { delta -= .pi * 2 }
                while delta < -.pi { delta += .pi * 2 }
                snail.zRotation += delta * min(1, dt * 7)   // calm, continuous turning
                if !AmbientAnimator.reduceMotion {
                    snailShell?.zRotation = sin(currentTime * 6.5) * 0.05
                }
                walkStep(at: snail.position)
            }
        }

        // The camera drifts after the snail — soft lag, never a hard lock — and stops at the
        // world's edge, so the felt never ends in bare background at the borders.
        let want = clampWorldOffset(CGPoint(x: size.width / 2 - snail.position.x,
                                            y: size.height / 2 - snail.position.y))
        let cur = worldNode.position
        worldNode.position = CGPoint(x: cur.x + (want.x - cur.x) * min(1, dt * 4.6),
                                     y: cur.y + (want.y - cur.y) * min(1, dt * 4.6))

        if !AmbientAnimator.reduceMotion {
            for (i, b) in butterflies.enumerated() {
                let t = currentTime * 0.5 + Double(i) * 2.1
                b.position = CGPoint(x: CGFloat(sin(t * 0.7)) * worldSize.width * 0.2,
                                     y: CGFloat(sin(t * 1.13)) * worldSize.height * 0.16)
            }
        }

        // "Lead me" — if she's been sitting idle a while (and it isn't bedtime), the
        // ladybug gives a small spin to beckon. Every session, not just the first-open
        // teach; it backs off the instant she's touched (founder: she felt inert after
        // the one-time tutorial stopped).
        if snailTarget == nil, !snailAwake, !isNight, !AmbientAnimator.reduceMotion,
           currentTime - lastMeadowTouchTime > 5.5, currentTime - lastInviteTime > 7.5 {
            lastInviteTime = currentTime
            inviteWander()
        }
    }

    /// A small, gentle spin-and-bob in place — "I'm here, lead me." Returns to her resting
    /// facing so a following lead still turns her cleanly.
    private func inviteWander() {
        guard let snail else { return }
        let home = snail.zRotation
        snail.removeAction(forKey: "invite")
        let bob = SKAction.sequence([.scale(to: 1.12, duration: 0.16), .scale(to: 1.0, duration: 0.24)])
        let spin = SKAction.sequence([
            .rotate(toAngle: home + 0.5, duration: 0.18),
            .rotate(toAngle: home - 0.4, duration: 0.22),
            .rotate(toAngle: home + 0.22, duration: 0.20),
            .rotate(toAngle: home, duration: 0.22)
        ])
        snail.run(.group([bob, spin]), withKey: "invite")
        flutterWanderer()   // a wing-clap if she's the ladybug (snail-era: a no-op)
        tone("meadow.invite", minInterval: 1.0)
    }

    private func clampToWorld(_ p: CGPoint) -> CGPoint {
        MeadowWorldGeometry.position(p, worldSize: worldSize)
    }

    /// Each step: her aura paints spring, while the light trail shows where she just came from.
    private func walkStep(at p: CGPoint) {
        stampTrailFlower(behind: p)
        // She wakes whatever her aura reaches — the ladybug herself is the magic.
        for lm in landmarks where !lm.isAwake
            && hypot(p.x - lm.position.x, p.y - lm.position.y) < paintRadius + 28 {
            lm.wake()
            wakeSound(lm.kind)
        }

        // Spring is PAINTED where she is led: a soft mossy bloom inside her aura, stamped
        // as she moves so the garden grows along her path. No loop to close — leading her
        // IS the magic (founder, June 14: the paper.io loop was wrong for a 2-year-old).
        if let last = lastPaintPoint {
            if hypot(p.x - last.x, p.y - last.y) >= paintStep {
                paintSpringStamp(at: p); lastPaintPoint = p
            }
        } else {
            paintSpringStamp(at: p); lastPaintPoint = p
        }

        // Her magical wake — a glowing comet-tail ribbon along her recent path, matching
        // the aura. Rolling (capped), so it follows her instead of scrawling over the garden.
        if let last = trailPoints.last, hypot(p.x - last.x, p.y - last.y) < trailStep { return }
        trailPoints.append(p)
        if trailPoints.count > 30 { trailPoints.removeFirst(trailPoints.count - 30) }
        redrawTrail()
        spawnTrailPetal(at: p)
    }

    /// A fixed set of small felt blooms follows the walk. Old blooms are reused rather
    /// than accumulating nodes, and the painted garden keeps its own lasting flowers.
    private func buildFlowerTrail() {
        flowerTrail = MeadowFlowerTrail()
        flowerTrailNodes.removeAll()
        let palette = [WarmShelfPalette.petal, WarmShelfPalette.butter, WarmShelfPalette.lavender,
                       WarmShelfPalette.paperHighlight, WarmShelfPalette.waterBlue]
        for slot in 0..<MeadowFlowerTrail.capacity {
            let flower = SKNode()
            let color = palette[slot % palette.count]
            let bloomColor = isNight
                ? color.blended(with: UIColor(hex: 0x6E7287), fraction: 0.5) : color
            if let art = ToyArt.sprite("meadow-rosette", fit: CGSize(width: 21, height: 21)) {
                art.color = bloomColor
                art.colorBlendFactor = 0.55
                flower.addChild(art)
            } else {
                for petalIndex in 0..<5 {
                    let angle = CGFloat(petalIndex) * .pi * 2 / 5
                    let petal = SKShapeNode(ellipseOf: CGSize(width: 9, height: 6))
                    petal.position = CGPoint(x: cos(angle) * 4.5, y: sin(angle) * 4.5)
                    petal.zRotation = angle
                    petal.strokeColor = .clear
                    ProceduralTexture.applyClayFill(to: petal, base: bloomColor, size: CGSize(width: 9, height: 6))
                    flower.addChild(petal)
                }
                let heart = SKShapeNode(circleOfRadius: 2.4)
                heart.fillColor = WarmShelfPalette.paperHighlight
                heart.strokeColor = .clear
                flower.addChild(heart)
            }
            flower.zPosition = 0.7
            flower.zRotation = CGFloat(slot % 7 - 3) * 0.12
            flower.isHidden = true
            lifeLayer.addChild(flower)
            flowerTrailNodes.append(flower)
        }
    }

    private func stampTrailFlower(behind point: CGPoint) {
        guard let slot = flowerTrail.stamp(behind: point, heading: snail?.zRotation ?? 0) else { return }
        let flower = flowerTrailNodes[slot]
        flower.removeAllActions()
        flower.position = flowerTrail.positions[slot]
        flower.isHidden = false
        flower.alpha = 1
        flower.setScale(1)
        guard !AmbientAnimator.reduceMotion else { return }
        flower.setScale(0.2)
        let open = SKAction.scale(to: 1.07, duration: 0.20)
        let settle = SKAction.scale(to: 1, duration: 0.24)
        open.timingMode = .easeOut
        settle.timingMode = .easeInEaseOut
        flower.run(.sequence([open, settle]), withKey: "flowerTrail.grow")
    }

    private func resetFlowerTrail() {
        flowerTrail = MeadowFlowerTrail()
        for flower in flowerTrailNodes {
            flower.removeAllActions()
            flower.isHidden = true
            flower.alpha = 1
            flower.setScale(1)
        }
    }

    /// The living wake (founder, June 13 — the super-hex spirit in our voice): a
    /// soft translucent ribbon of light with a bright core, and petals that drift
    /// off her path — the world visibly comes alive WHERE SHE WALKS, because she
    /// is the one who makes it alive.
    private func redrawTrail() {
        guard trailPoints.count > 1 else {
            trailNode?.removeFromParent(); trailNode = nil
            trailHalo?.removeFromParent(); trailHalo = nil
            return
        }
        let night = isNight
        // Only a soft warm wake of light now. The bright white core line read as a
        // highlighter stroke drawn over the felt — the one flat-UI mark in the meadow.
        if trailHalo == nil {
            let halo = SKShapeNode()
            halo.strokeColor = UIColor(hex: 0xFFECBE).withAlpha(night ? 0.16 : 0.10)
            halo.lineWidth = 22
            halo.lineCap = .round
            halo.lineJoin = .round
            halo.fillColor = .clear
            halo.blendMode = .add
            halo.zPosition = 0
            trailLayer.addChild(halo)
            trailHalo = halo
        }
        trailHalo?.path = MeadowScene.smoothOpenPath(trailPoints)
    }

    /// A soft mossy bloom of spring, laid down where she is led — the brush the aura paints
    /// with. Each stamp opens the one moss surface a little wider (see `springReveal`).
    private func paintSpringStamp(at p: CGPoint, animated: Bool = true, record: Bool = true) {
        let r = paintRadius
        let fresh = markCovered(center: p, radius: r)
        // Ground that is already spring gets nothing new — no node, no chime. The chime
        // means "you made new spring". (Restores always lay their stamp.)
        if record, fresh == 0 { return }

        let stamp = SKSpriteNode(texture: MeadowScene.stampTexture)
        stamp.size = CGSize(width: r * 2, height: r * 2)
        stamp.position = p
        springMask.addChild(stamp)
        let edge = SKSpriteNode(texture: MeadowScene.featherTexture)
        edge.size = CGSize(width: r * 2.4, height: r * 2.4)
        edge.position = p
        edge.color = springEdgeColor
        edge.colorBlendFactor = 1
        edge.alpha = 0.5
        springFringe.addChild(edge)
        if record { paintedSpringPoints.append(p) }
        springArea = CGFloat(paintedCells.count) * coverCell * coverCell

        if animated, !AmbientAnimator.reduceMotion {
            stamp.setScale(0.45)
            let grow = SKAction.scale(to: 1, duration: 0.34); grow.timingMode = .easeOut
            stamp.run(grow)
            edge.alpha = 0
            edge.run(.fadeAlpha(to: 0.5, duration: 0.4))
        }
        // The garden's confetti — a wildflower opens now and then in her wake.
        if animated, Int.random(in: 0..<7) == 0 {
            bloomRosette(at: CGPoint(x: p.x + .random(in: -r * 0.4...r * 0.4),
                                     y: p.y + .random(in: -r * 0.4...r * 0.4)))
        }
        if animated {
            tone("meadow.paint", minInterval: 0.42)
            if paintedSpringPoints.count % 9 == 0 {
                HapticsManager.shared.impact(style: .light, intensity: 0.06)
            }
        }
        updateSpringGlow(allowMoment: animated)
    }

    /// A petal (or now and then a tiny sparkle) lets go of her wake and drifts.
    private func spawnTrailPetal(at p: CGPoint) {
        guard !AmbientAnimator.reduceMotion, petalBudget < 70 else { return }
        petalBudget += 1
        let night = isNight
        if Int.random(in: 0..<7) == 0 {
            // the sparkle: a little four-point star of light
            let sparkle = SKNode()
            for angle in [CGFloat(0), .pi / 2] {
                let arm = SKShapeNode(rectOf: CGSize(width: 9, height: 1.6), cornerRadius: 0.8)
                arm.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.95)
                arm.strokeColor = .clear
                arm.blendMode = .add
                arm.zRotation = angle
                sparkle.addChild(arm)
            }
            sparkle.position = CGPoint(x: p.x + .random(in: -7...7), y: p.y + .random(in: -7...7))
            sparkle.zPosition = 0.8
            sparkle.setScale(0.3)
            trailLayer.addChild(sparkle)
            sparkle.run(.sequence([
                .group([.scale(to: 1.0, duration: 0.18),
                        .rotate(byAngle: .random(in: -0.6...0.6), duration: 0.7)]),
                .group([.scale(to: 0.2, duration: 0.5), .fadeOut(withDuration: 0.5)]),
                .run { [weak self] in self?.petalBudget -= 1 },
                .removeFromParent()
            ]))
            return
        }
        let palette = [WarmShelfPalette.petal, WarmShelfPalette.butter,
                       WarmShelfPalette.lavender, WarmShelfPalette.paperHighlight]
        let petal = SKShapeNode(ellipseOf: CGSize(width: .random(in: 3.5...6), height: .random(in: 2.2...3.4)))
        petal.fillColor = (palette.randomElement() ?? .white).withAlpha(night ? 0.85 : 0.72)
        petal.strokeColor = .clear
        if night { petal.blendMode = .add }
        petal.position = CGPoint(x: p.x + .random(in: -6...6), y: p.y + .random(in: -6...6))
        petal.zRotation = .random(in: 0...(2 * .pi))
        petal.zPosition = 0.7
        trailLayer.addChild(petal)
        petal.run(.sequence([
            .group([.moveBy(x: .random(in: -14...14), y: .random(in: -8...18), duration: .random(in: 0.9...1.5)),
                    .rotate(byAngle: .random(in: -1.2...1.2), duration: 1.4),
                    .sequence([.wait(forDuration: 0.5), .fadeOut(withDuration: 0.8)])]),
            .run { [weak self] in self?.petalBudget -= 1 },
            .removeFromParent()
        ]))
    }

    /// Spring base patches, used for the home garden and restored saved shapes: the shape
    /// opens the moss surface, with the same feathered felt edge as her painted path.
    private func addSpringPolygon(_ path: CGPath, area: CGFloat, sprinkle: Int, animated: Bool) {
        let shape = SKShapeNode(path: path)
        shape.fillColor = .white
        shape.strokeColor = .clear
        shape.lineWidth = 0
        springMask.addChild(shape)
        let box = path.boundingBox
        let edge = SKSpriteNode(texture: MeadowScene.featherTexture)
        edge.size = CGSize(width: box.width * 1.14, height: box.height * 1.14)
        edge.position = CGPoint(x: box.midX, y: box.midY)
        edge.color = springEdgeColor
        edge.colorBlendFactor = 1
        edge.alpha = 0.5
        springFringe.addChild(edge)
        springPaths.append(path)

        // Honest coverage for the patch.
        let c = coverCell
        if c > 0, box.width > 0, box.height > 0 {
            for ix in Int(floor(box.minX / c))...Int(floor(box.maxX / c)) {
                for iy in Int(floor(box.minY / c))...Int(floor(box.maxY / c)) {
                    let centre = CGPoint(x: (CGFloat(ix) + 0.5) * c, y: (CGFloat(iy) + 0.5) * c)
                    if path.contains(centre) { paintedCells.insert(coverKey(ix, iy)) }
                }
            }
        }
        springArea = CGFloat(paintedCells.count) * coverCell * coverCell

        // Wildflower sprinkles — top-down rosettes, the garden's confetti.
        var placed = 0, attempts = 0
        while placed < sprinkle, attempts < sprinkle * 16 {
            attempts += 1
            let candidate = CGPoint(x: .random(in: box.minX...box.maxX),
                                    y: .random(in: box.minY...box.maxY))
            guard path.contains(candidate) else { continue }
            placed += 1
            let delay = animated ? Double(placed) * 0.06 : 0
            run(.sequence([.wait(forDuration: delay),
                           .run { [weak self] in self?.bloomRosette(at: candidate) }]))
        }

        if animated {
            if !AmbientAnimator.reduceMotion {
                shape.setScale(0.7)
                let grow = SKAction.scale(to: 1, duration: 0.4); grow.timingMode = .easeOut
                shape.run(grow)
                edge.alpha = 0
                edge.run(.fadeAlpha(to: 0.5, duration: 0.5))
            }
            tone("meadow.spring", minInterval: 0.3)
            HapticsManager.shared.impact(style: .soft, intensity: 0.3)
        }
        updateSpringGlow(allowMoment: animated)
    }

    /// A wildflower seen from above: a ring of petals around a bright heart.
    /// `silent` restores a flower without pop, tone, or haptic (rotation rebuilds).
    private func bloomRosette(at p: CGPoint, silent: Bool = false) {
        guard flowers.count < 260 else { return }
        let palette = [WarmShelfPalette.petal, WarmShelfPalette.butter,
                       WarmShelfPalette.lavender, WarmShelfPalette.waterBlue, WarmShelfPalette.rhubarb]
        let color = palette[flowers.count % palette.count]
        let r: CGFloat = .random(in: 7...11)

        let flower = SKNode()
        flower.position = p
        flower.zPosition = 0.5
        // Flowers fold their colour in for the night, like real ones do.
        let bloomColor = isNight
            ? color.blended(with: UIColor(hex: 0x6E7287), fraction: 0.5)
            : color
        if let art = ToyArt.sprite("meadow-rosette", fit: CGSize(width: r * 2.6, height: r * 2.6)) {
            art.color = bloomColor
            art.colorBlendFactor = 0.7
            flower.addChild(art)
        } else {
            for i in 0..<6 {
                let a = CGFloat(i) / 6 * .pi * 2
                let petal = SKShapeNode(ellipseOf: CGSize(width: r * 0.95, height: r * 0.6))
                petal.fillColor = bloomColor
                petal.strokeColor = .clear
                petal.position = CGPoint(x: cos(a) * r * 0.62, y: sin(a) * r * 0.62)
                petal.zRotation = a
                flower.addChild(petal)
            }
            let core = SKShapeNode(circleOfRadius: r * 0.4)
            core.fillColor = WarmShelfPalette.paperHighlight
            core.strokeColor = .clear
            core.zPosition = 0.1
            flower.addChild(core)
            if Int.random(in: 0..<22) == 0 {
                let ink = WarmShelfPalette.cocoa.withAlpha(0.6)
                for sx in [-r * 0.16, r * 0.16] {
                    let eye = SKShapeNode(circleOfRadius: 0.9)
                    eye.fillColor = ink; eye.strokeColor = .clear
                    eye.position = CGPoint(x: sx, y: 0.6)
                    eye.zPosition = 0.2
                    flower.addChild(eye)
                }
            }
        }
        lifeLayer.addChild(flower)
        flowers.append(flower)

        if silent {
            flower.zRotation = .random(in: -0.4...0.4)
            return
        }
        if AmbientAnimator.reduceMotion {
            tone("meadow.bloom", minInterval: 0.12)
            return
        }
        flower.setScale(0.05)
        let up = SKAction.scale(to: 1.12, duration: 0.2); up.timingMode = .easeOut
        let settle = SKAction.scale(to: 1.0, duration: 0.28); settle.timingMode = .easeInEaseOut
        flower.run(.sequence([up, settle]))
        flower.zRotation = .random(in: -0.4...0.4)
        tone("meadow.bloom", minInterval: 0.12)
        if flowers.count % 6 == 0 { HapticsManager.shared.impact(style: .light, intensity: 0.07) }
    }

    // MARK: - The full-spring moment & first frost

    private func fireBloomMoment() {
        tone("meadow.fullspring")
        HapticsManager.shared.impact(style: .soft, intensity: 0.3)
        goldenVeil.run(.fadeAlpha(to: 0.24, duration: 1.4))
        if !AmbientAnimator.reduceMotion {
            for (i, flower) in flowers.enumerated() {
                flower.run(.sequence([
                    .wait(forDuration: Double(i) * 0.01),
                    .rotate(byAngle: 0.12, duration: 0.3),
                    .rotate(byAngle: -0.09, duration: 0.36),
                    .rotate(byAngle: -0.03, duration: 0.4)
                ]))
            }
            for _ in 0..<2 { addButterfly() }
        }
        scheduleDandelionOffer()
    }

    private func scheduleDandelionOffer() {
        run(.sequence([.wait(forDuration: 3.0), .run { [weak self] in
            guard let self, self.bloomMomentFired else { return }
            self.offerDandelion()
        }]), withKey: "meadow.dandelionOffer")
    }

    private func addButterfly() {
        // After dark the visitors are fireflies — tiny pulsing lights over the spring.
        if isNight {
            let firefly = SKNode()
            let glow = SKShapeNode(circleOfRadius: 7)
            glow.fillColor = WarmShelfPalette.butter.withAlpha(0.5)
            glow.strokeColor = .clear
            glow.blendMode = .add
            firefly.addChild(glow)
            let core = SKShapeNode(circleOfRadius: 2.4)
            core.fillColor = UIColor(hex: 0xFFF3C2)
            core.strokeColor = .clear
            core.blendMode = .add
            firefly.addChild(core)
            if !AmbientAnimator.reduceMotion {
                glow.run(.repeatForever(.sequence([
                    .fadeAlpha(to: 0.15, duration: .random(in: 0.8...1.3)),
                    .fadeAlpha(to: 0.6, duration: .random(in: 0.7...1.2))
                ])))
            }
            firefly.zPosition = 22
            lifeLayer.addChild(firefly)
            butterflies.append(firefly)
            return
        }

        let b = SKNode()
        if let art = ToyArt.sprite("meadow-butterfly", fit: CGSize(width: 44, height: 36)) {
            b.addChild(art)
            if !AmbientAnimator.reduceMotion {
                art.run(.repeatForever(.sequence([.scaleX(to: 0.6, duration: 0.14), .scaleX(to: 1.0, duration: 0.16)])))
            }
        } else {
            for sx in [-1.0, 1.0] {
                let wing = SKShapeNode(ellipseOf: CGSize(width: 16, height: 22))
                wing.fillColor = sx < 0 ? WarmShelfPalette.butter : WarmShelfPalette.butter.withAlpha(0.88)
                wing.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.12)
                wing.lineWidth = 1
                wing.position = CGPoint(x: sx * 8, y: 0)
                b.addChild(wing)
                if !AmbientAnimator.reduceMotion {
                    wing.run(.repeatForever(.sequence([
                        .scaleX(to: 0.5, duration: 0.13), .scaleX(to: 1.0, duration: 0.15)
                    ])))
                }
            }
        }
        b.zPosition = 2
        lifeLayer.addChild(b)
        butterflies.append(b)
    }

    private func offerDandelion(at restoredPosition: CGPoint? = nil, animated: Bool = true) {
        guard dandelion == nil || dandelion?.parent == nil, let snail else { return }
        let puff = SKNode()
        // The pass-2 dandelion is a round puff seen from above, like the rest of the meadow.
        if let art = ToyArt.sprite("meadow-dandelion", fit: CGSize(width: 84, height: 84)) {
            puff.addChild(art)
        } else {
            let head = SKShapeNode(circleOfRadius: 22)
            head.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.9)
            head.strokeColor = WarmShelfPalette.paperHighlight
            head.lineWidth = 1
            puff.addChild(head)
            for _ in 0..<12 {
                let seed = SKShapeNode(circleOfRadius: 1.5)
                seed.fillColor = .white
                seed.strokeColor = .clear
                let a = CGFloat.random(in: 0..<(.pi * 2)), rr = CGFloat.random(in: 7...18)
                seed.position = CGPoint(x: cos(a) * rr, y: sin(a) * rr)
                head.addChild(seed)
            }
        }
        let preferred = restoredPosition ?? CGPoint(x: snail.position.x + 140, y: snail.position.y + 90)
        puff.position = MeadowDandelionGeometry.position(preferred: preferred, worldSize: worldSize)
        puff.zPosition = 3
        puff.alpha = animated ? 0 : 1
        lifeLayer.addChild(puff)
        dandelion = puff
        if animated { puff.run(.fadeIn(withDuration: 0.8)) }
        if !AmbientAnimator.reduceMotion {
            puff.run(.repeatForever(.sequence([
                .rotate(toAngle: 0.06, duration: 1.3), .rotate(toAngle: -0.06, duration: 1.5), .rotate(toAngle: 0, duration: 1.2)
            ])))
        }
    }

    /// First frost: the child blows the dandelion and winter tucks the meadow back in —
    /// petals lift away, the green sleeps, the little home garden remains. Begin again.
    private func firstFrost() {
        resetFlowerTrail()
        dandelion?.run(.sequence([.fadeOut(withDuration: 0.5), .removeFromParent()]))
        dandelion = nil
        removeAction(forKey: "meadow.dandelionOffer")
        tone("meadow.frost")
        HapticsManager.shared.impact(style: .soft, intensity: 0.22)

        let flying = flowers
        flowers.removeAll()
        bloomMomentFired = false
        goldenVeil.run(.fadeAlpha(to: 0, duration: 2.2))
        for b in butterflies { b.run(.sequence([.fadeOut(withDuration: 1.4), .removeFromParent()])) }
        butterflies.removeAll()

        for (i, flower) in flying.enumerated() {
            if AmbientAnimator.reduceMotion {
                flower.run(.sequence([.fadeOut(withDuration: 0.6), .removeFromParent()]))
                continue
            }
            let drift = SKAction.moveBy(x: .random(in: 60...180), y: .random(in: 40...140),
                                        duration: .random(in: 1.4...2.4))
            drift.timingMode = .easeIn
            flower.run(.sequence([
                .wait(forDuration: Double(i) * 0.009),
                .group([drift, .fadeOut(withDuration: 1.6),
                        .rotate(byAngle: .random(in: 0.4...1.2), duration: 2.0)]),
                .removeFromParent()
            ]))
        }

        // Winter tucks the spring surface back in as one, then the slate is wiped clean
        // (coverage too, so ground painted during the fade can be painted again).
        let tuck = SKAction.sequence([.wait(forDuration: 0.4), .fadeOut(withDuration: 2.0)])
        springFringe.run(tuck)
        springReveal.run(.sequence([tuck, .run { [weak self] in
            guard let self else { return }
            self.springMask.removeAllChildren()
            self.springFringe.removeAllChildren()
            self.paintedCells.removeAll()
            self.paintedSpringPoints.removeAll()
            self.lastPaintPoint = nil
            self.springArea = 0
            self.springReveal.alpha = 1
            self.springFringe.alpha = 1
        }]))
        springPaths.removeAll()
        paintedSpringPoints.removeAll()
        lastPaintPoint = nil
        springArea = 0
        trailPoints.removeAll()
        trailNode?.removeFromParent()
        trailNode = nil
        trailHalo?.removeFromParent()
        trailHalo = nil

        // The landmarks tuck themselves back in — ready to be found again.
        run(.sequence([.wait(forDuration: 1.4), .run { [weak self] in
            self?.landmarks.forEach { $0.sleep() }
        }]))

        // …but home never leaves. Spring keeps a doorstep.
        run(.sequence([.wait(forDuration: 2.6), .run { [weak self] in
            self?.buildHomeSpring()
            self?.setSnailAwake(false)
        }]))
    }

    /// Jitter-decimated points (a toddler's hand wobbles ~every sample; curves
    /// through every wobble read nervous, not handmade).
    private static func decimate(_ pts: [CGPoint], minStep: CGFloat) -> [CGPoint] {
        var out: [CGPoint] = []
        for q in pts {
            if let last = out.last, hypot(q.x - last.x, q.y - last.y) < minStep { continue }
            out.append(q)
        }
        return out
    }

    /// The same smoothing for the live dew line (open ends clamped).
    private static func smoothOpenPath(_ raw: [CGPoint]) -> CGPath {
        let p = decimate(raw, minStep: 14)
        let path = CGMutablePath()
        guard p.count >= 3 else {
            path.move(to: raw[0])
            for q in raw.dropFirst() { path.addLine(to: q) }
            return path
        }
        let n = p.count
        path.move(to: p[0])
        for i in 0..<(n - 1) {
            let p0 = p[max(0, i - 1)], p1 = p[i], p2 = p[i + 1], p3 = p[min(n - 1, i + 2)]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        return path
    }

    // MARK: - Demo

    #if DEBUG
    private func runMeadowDemo() {
        setSnailAwake(true)
        let r = min(size.width, size.height) * 0.46
        var actions: [SKAction] = [.wait(forDuration: 0.5)]
        // Out of the garden, a wide arc through winter, and home again.
        let waypoints: [CGPoint] = (0...10).map { i in
            let a = CGFloat(i) / 10 * .pi * 1.5 - .pi * 0.25
            return CGPoint(x: cos(a) * r, y: sin(a) * r)
        } + [.zero]
        for wp in waypoints {
            actions.append(.run { [weak self] in self?.snailTarget = wp })
            actions.append(.wait(forDuration: 0.85))
        }
        actions.append(.wait(forDuration: 3.0))   // let the final painted stretch land
        actions.append(.run { [weak self] in self?.snailTarget = nil })
        run(.sequence(actions))
    }
    #endif

    // MARK: - Sound

    private func tone(_ cue: String, minInterval: TimeInterval = 0, volume: Float = 1) {
        if minInterval > 0 {
            let now = CACurrentMediaTime()
            if let last = lastTone[cue], now - last < minInterval { return }
            lastTone[cue] = now
        }
        AudioManager.shared.play(cue: cue, volume: volume)
    }

    /// Each sleeper wakes on its own kalimba note, with a small sleepy "oh".
    private func wakeSound(_ kind: MeadowLandmark.Kind) {
        tone("note.kalimba.\(kind.wakeDegree)", minInterval: 0.3)
        AudioManager.shared.play(cue: "meadow.landmark.wake", volume: 0.7, delay: 0.04)
    }

    // MARK: - Accessibility

    override func accessibilityElements(in view: SKView) -> [UIAccessibilityElement] {
        var elements = super.accessibilityElements(in: view)
        if let snail {
            elements.append(makeActivatableAccessibilityElement(
                in: view, label: "Ladybug — tap to lead her to a new spot and paint spring as she moves",
                scenePosition: worldNode.convert(snail.position, to: self),
                size: CGSize(width: 120, height: 100), traits: .button
            ) { [weak self] in
                guard let self else { return }
                let r = min(self.size.width, self.size.height) * 0.4
                self.snailTarget = CGPoint(x: .random(in: -r...r), y: .random(in: -r...r))
                self.setSnailAwake(true)
            })
        }
        return elements
    }
}

// MARK: - Landmark seeds

/// A sleeping destination out in the winter, seen from above. Art slots
/// "meadow-rock" / "meadow-stump" are checked first; the clay fallback holds the
/// corner until then. Waking is recognition, not reward: eyes open, a sprout, one note.
private final class MeadowLandmark: SKNode {
    enum Kind: CaseIterable {
        case rock, stump, mushroom, pond, pebbles

        var slot: String {
            switch self {
            case .rock: return "meadow-rock"
            case .stump: return "meadow-stump"
            case .mushroom: return "meadow-mushroom"
            case .pond: return "meadow-pond"
            case .pebbles: return "meadow-pebbles"
            }
        }
        /// Fit boxes for the runtime art. Rock, mushroom and pebbles are the top-down
        /// pass-2 exports, cropped to their bodies with ~4% padding (so the visible body is
        /// ~93% of the box): rock ≈ 104 pt, mushroom ≈ 100 pt, pebbles ≈ 115 × 95 pt,
        /// all about 2.4× the ladybug. Stump and pond keep their earlier art and boxes.
        var fit: CGSize {
            switch self {
            case .rock: return CGSize(width: 112, height: 109)
            case .stump: return CGSize(width: 112, height: 106)
            case .mushroom: return CGSize(width: 108, height: 107)
            case .pond: return CGSize(width: 126, height: 116)
            case .pebbles: return CGSize(width: 124, height: 102)
            }
        }
        /// Each sleeper hums its own waking note.
        var wakeDegree: Int {
            switch self {
            case .rock: return 14
            case .stump: return 16
            case .mushroom: return 17
            case .pond: return 12
            case .pebbles: return 15
            }
        }
        /// Drawn from directly above, so it can be turned on the ground. Every kind is now
        /// (rock, mushroom and pebbles were redrawn top-down in design pass 2).
        var isTopDown: Bool { true }
        /// The stump and pond art carries its own soft shadow (despilled from the teal key);
        /// the pass-2 top-down art has clean alpha and needs one from code.
        var hasBakedShadow: Bool {
            switch self {
            case .stump, .pond: return true
            case .rock, .mushroom, .pebbles: return false
            }
        }
        var fallbackTint: UIColor {
            switch self {
            case .rock: return UIColor(hex: 0x9AA08B)
            case .stump: return UIColor(hex: 0xB59578)
            case .mushroom: return UIColor(hex: 0xC2552E)
            case .pond: return UIColor(hex: 0x74A4B4)
            case .pebbles: return UIColor(hex: 0xC9BFA4)
            }
        }
    }
    let kind: Kind
    private(set) var isAwake = false

    private let sleepFace = SKNode()   // rock: closed lichen lids. stump: bare rings.
    private let wakeFace = SKNode()    // rock: open eyes + moss. stump: the sprout.
    private var artSprite: SKSpriteNode?
    private var hasAuthoredFaces = false   // rock with both painted plates: faces live in the art

    init(kind: Kind, night: Bool) {
        self.kind = kind
        super.init()
        build(night: night)
    }
    required init?(coder: NSCoder) { fatalError("MeadowLandmark is code-built") }

    private func build(night: Bool) {
        // One shadow each: art with a baked shadow (stump, pond) gets none from code; the
        // clean pass-2 art and the procedural understudies get a soft contact shadow,
        // nudged down-right away from the upper-left key light.
        let hasArt = ToyArt.texture(kind.slot) != nil
        if !hasArt || !kind.hasBakedShadow {
            let size = hasArt ? CGSize(width: kind.fit.width * 1.02, height: kind.fit.height * 0.96)
                              : CGSize(width: 130, height: 110)
            let shadow = SKSpriteNode(texture: ProceduralTexture.softClayShadow(size: size))
            shadow.position = hasArt ? CGPoint(x: kind.fit.width * 0.05, y: -kind.fit.height * 0.07) : .zero
            shadow.zPosition = -1
            shadow.alpha = hasArt ? (night ? 0.35 : 0.5) : (night ? 0.5 : 0.8)
            addChild(shadow)
        }

        // Every kind is slot-driven now (June 12 batch): one asleep plate, one
        // painted -awake plate with the real face. Procedural bodies are the
        // emergency understudies only.
        if let art = ToyArt.sprite(kind.slot, fit: kind.fit) {
            if night { art.color = UIColor(hex: 0x2A2E4A); art.colorBlendFactor = 0.35 }
            addChild(art)
            artSprite = art
            hasAuthoredFaces = ToyArt.texture("\(kind.slot)-awake") != nil
            if hasAuthoredFaces { return }   // faces live in the paint; nothing procedural to add
        }

        switch kind {
        case .rock:
            if artSprite == nil {
                let body = SKShapeNode(ellipseOf: CGSize(width: 112, height: 90))
                body.fillColor = night ? UIColor(hex: 0x83869A) : UIColor(hex: 0x9AA08B)
                body.strokeColor = (night ? UIColor(hex: 0x6E7188) : UIColor(hex: 0x84876F)).withAlpha(0.7)
                body.lineWidth = 2
                addChild(body)
                for (dx, dy, w, h) in [(-24.0, 13.0, 26.0, 13.0), (18.0, -11.0, 20.0, 11.0)] {
                    let fleck = SKShapeNode(ellipseOf: CGSize(width: w, height: h))
                    fleck.fillColor = (night ? UIColor(hex: 0x9295A8) : UIColor(hex: 0xAAB096)).withAlpha(0.8)
                    fleck.strokeColor = .clear
                    fleck.position = CGPoint(x: dx, y: dy)
                    body.addChild(fleck)
                }
            }
            let ink = WarmShelfPalette.cocoa.withAlpha(night ? 0.45 : 0.35)
            for sx in [-1.0, 1.0] {
                let lid = SKShapeNode()
                let p = CGMutablePath()
                p.move(to: CGPoint(x: -6, y: 0))
                p.addQuadCurve(to: CGPoint(x: 6, y: 0), control: CGPoint(x: 0, y: -5))
                lid.path = p
                lid.strokeColor = ink
                lid.lineWidth = 2.4
                lid.lineCap = .round
                lid.fillColor = .clear
                lid.position = CGPoint(x: sx * 15, y: 6)
                sleepFace.addChild(lid)
            }
            for sx in [-1.0, 1.0] {
                let eye = SKShapeNode(circleOfRadius: 3.4)
                eye.fillColor = WarmShelfPalette.cocoa.withAlpha(0.78)
                eye.strokeColor = .clear
                eye.position = CGPoint(x: sx * 15, y: 6)
                wakeFace.addChild(eye)
            }
            let smile = SKShapeNode()
            let sp = CGMutablePath()
            sp.move(to: CGPoint(x: -7, y: -8))
            sp.addQuadCurve(to: CGPoint(x: 7, y: -8), control: CGPoint(x: 0, y: -13))
            smile.path = sp
            smile.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.55)
            smile.lineWidth = 2.2
            smile.lineCap = .round
            smile.fillColor = .clear
            wakeFace.addChild(smile)
            // Waking moss settles along the rock's brow.
            for (dx, w) in [(-26.0, 30.0), (2.0, 38.0), (28.0, 24.0)] {
                let moss = SKShapeNode(ellipseOf: CGSize(width: w, height: 12))
                moss.fillColor = UIColor(hex: night ? 0x5E7361 : 0x8FBE74).withAlpha(0.9)
                moss.strokeColor = .clear
                moss.position = CGPoint(x: dx, y: 36)
                wakeFace.addChild(moss)
            }

        case .stump:
            if artSprite == nil {
                let bark = SKShapeNode(circleOfRadius: 47)
                bark.fillColor = night ? UIColor(hex: 0x6B5A50) : UIColor(hex: 0x8A6E50)
                bark.strokeColor = .clear
                addChild(bark)
                let top = SKShapeNode(circleOfRadius: 40)
                top.fillColor = night ? UIColor(hex: 0x8B7A6C) : UIColor(hex: 0xB59578)
                top.strokeColor = .clear
                top.zPosition = 0.1
                addChild(top)
                for r in [27.0, 16.0, 7.0] {
                    let ring = SKShapeNode(circleOfRadius: r)
                    ring.fillColor = .clear
                    ring.strokeColor = UIColor(hex: 0x8A6E50).withAlpha(night ? 0.5 : 0.35)
                    ring.lineWidth = 2
                    ring.zPosition = 0.2
                    top.addChild(ring)
                }
            }
            // The sprout waits at the heart of the rings.
            let stem = SKShapeNode(rectOf: CGSize(width: 2.6, height: 14), cornerRadius: 1.3)
            stem.fillColor = UIColor(hex: 0x7FA968)
            stem.strokeColor = .clear
            stem.position = CGPoint(x: 0, y: 6)
            wakeFace.addChild(stem)
            for sx in [-1.0, 1.0] {
                let leaf = SKShapeNode(ellipseOf: CGSize(width: 16, height: 9))
                leaf.fillColor = UIColor(hex: night ? 0x6E8A66 : 0x8FBE74)
                leaf.strokeColor = .clear
                leaf.position = CGPoint(x: sx * 8, y: 13)
                leaf.zRotation = sx * 0.5
                wakeFace.addChild(leaf)
            }

        case .mushroom, .pond, .pebbles:
            // Art is the norm for these (June 12 batch); the understudy is a soft
            // tinted clay blob wearing the standard sleeping/waking face.
            if artSprite == nil {
                let blob = SKShapeNode(ellipseOf: CGSize(width: kind.fit.width * 0.92,
                                                         height: kind.fit.height * 0.88))
                blob.fillColor = night ? kind.fallbackTint.withAlpha(0.7) : kind.fallbackTint
                blob.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.2)
                blob.lineWidth = 1.5
                addChild(blob)
            }
            let ink2 = WarmShelfPalette.cocoa.withAlpha(night ? 0.45 : 0.4)
            for sx in [-1.0, 1.0] {
                let lid = SKShapeNode()
                let p = CGMutablePath()
                p.move(to: CGPoint(x: -6, y: 0))
                p.addQuadCurve(to: CGPoint(x: 6, y: 0), control: CGPoint(x: 0, y: -5))
                lid.path = p
                lid.strokeColor = ink2
                lid.lineWidth = 2.4
                lid.lineCap = .round
                lid.fillColor = .clear
                lid.position = CGPoint(x: sx * 14, y: 4)
                sleepFace.addChild(lid)
                let eye = SKShapeNode(circleOfRadius: 3.2)
                eye.fillColor = WarmShelfPalette.cocoa.withAlpha(0.78)
                eye.strokeColor = .clear
                eye.position = CGPoint(x: sx * 14, y: 4)
                wakeFace.addChild(eye)
            }
            let grin = SKShapeNode()
            let gp = CGMutablePath()
            gp.move(to: CGPoint(x: -6, y: -9))
            gp.addQuadCurve(to: CGPoint(x: 6, y: -9), control: CGPoint(x: 0, y: -14))
            grin.path = gp
            grin.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.55)
            grin.lineWidth = 2.2
            grin.lineCap = .round
            grin.fillColor = .clear
            wakeFace.addChild(grin)
        }

        sleepFace.zPosition = 2
        wakeFace.zPosition = 2
        wakeFace.alpha = 0
        wakeFace.setScale(kind == .stump ? 0.05 : 0.9)
        addChild(sleepFace)
        addChild(wakeFace)
    }

    func wake(instantly: Bool = false) {
        guard !isAwake else { return }
        isAwake = true
        // Authored sleeper: the waking is painted — crossfade to the open-eyed plate.
        if hasAuthoredFaces, let art = artSprite, let awakeTex = ToyArt.texture("\(kind.slot)-awake") {
            let overlay = SKSpriteNode(texture: awakeTex)
            overlay.size = CGSize(width: art.size.width / max(art.xScale, 0.001), height: art.size.height / max(art.yScale, 0.001))
            overlay.color = art.color
            overlay.colorBlendFactor = art.colorBlendFactor
            overlay.alpha = instantly ? 1 : 0
            overlay.zPosition = 0.1
            overlay.name = "awakeOverlay"
            art.addChild(overlay)
            if !instantly { overlay.run(.fadeIn(withDuration: 0.5)) }
        }
        if instantly {   // rotation restore: woken stays woken, no ceremony
            sleepFace.alpha = 0
            wakeFace.alpha = 1
            wakeFace.setScale(1)
            return
        }
        sleepFace.run(.fadeOut(withDuration: 0.5))
        if AmbientAnimator.reduceMotion {
            wakeFace.setScale(1)
            wakeFace.run(.fadeIn(withDuration: 0.6))
            return
        }
        let grow = SKAction.scale(to: 1.0, duration: kind == .stump ? 0.8 : 0.5)
        grow.timingMode = .easeOut
        wakeFace.run(.group([.fadeIn(withDuration: 0.5), grow]))
        // One slow breath — alive now.
        run(.sequence([
            .scale(to: 1.04, duration: 0.55),
            .scale(to: 1.0, duration: 0.7)
        ]))
    }

    func sleep() {
        guard isAwake else { return }
        isAwake = false
        if let overlay = artSprite?.childNode(withName: "awakeOverlay") {
            overlay.run(.sequence([.fadeOut(withDuration: 1.6), .removeFromParent()]))
        }
        wakeFace.run(.fadeOut(withDuration: 1.6))
        wakeFace.run(.scale(to: kind == .stump ? 0.05 : 0.9, duration: 1.6))
        sleepFace.run(.sequence([.wait(forDuration: 0.8), .fadeIn(withDuration: 1.2)]))
    }

    /// An awake landmark, poked: one happy squash-and-stretch. Recognition both ways.
    func delight() {
        guard isAwake else { return }
        removeAction(forKey: "delight")
        if AmbientAnimator.reduceMotion {
            run(.sequence([.scale(to: 1.03, duration: 0.2), .scale(to: 1.0, duration: 0.3)]), withKey: "delight")
            return
        }
        run(.sequence([
            .group([.scaleX(to: 1.06, duration: 0.1), .scaleY(to: 0.95, duration: 0.1)]),
            .group([.scaleX(to: 0.97, duration: 0.12), .scaleY(to: 1.05, duration: 0.12)]),
            .group([.scaleX(to: 1.0, duration: 0.22), .scaleY(to: 1.0, duration: 0.22)])
        ]), withKey: "delight")
        wakeFace.run(.sequence([.scale(to: 1.12, duration: 0.12), .scale(to: 1.0, duration: 0.26)]))
    }

    /// A sleeping landmark, poked: it stirs in its sleep and settles deeper.
    func stir() {
        guard !isAwake else { return }
        removeAction(forKey: "delight")
        guard !AmbientAnimator.reduceMotion else { return }
        let home = zRotation
        run(.sequence([
            .rotate(byAngle: 0.03, duration: 0.12),
            .rotate(byAngle: -0.05, duration: 0.16),
            .rotate(toAngle: home, duration: 0.22)
        ]), withKey: "delight")
    }
}

/// The reset puff stays within the reachable felt world, including at camera edges.
/// Scene-independent geometry keeps the camera covered and eases a lead near soft bounds.
enum MeadowWorldGeometry {
    static let overscan: CGFloat = 96
    static func groundSize(worldSize: CGSize) -> CGSize {
        CGSize(width: worldSize.width + overscan * 2, height: worldSize.height + overscan * 2)
    }

    static func position(_ point: CGPoint, worldSize: CGSize) -> CGPoint {
        let limitX = max(0, worldSize.width / 2 - 50)
        let limitY = max(0, worldSize.height / 2 - 50)
        return CGPoint(x: min(max(point.x, -limitX), limitX),
                       y: min(max(point.y, -limitY), limitY))
    }

    static func leadTarget(_ point: CGPoint, worldSize: CGSize) -> CGPoint {
        func soften(_ value: CGFloat, extent: CGFloat) -> CGFloat {
            guard value.isFinite else { return 0 }
            let limit = max(0, extent / 2 - 50)
            let band = min(180, limit * 0.25)
            guard band > 0 else { return 0 }
            let start = limit - band
            let distance = abs(value)
            guard distance > start else { return value }
            let eased = start + band * (1 - exp(-(distance - start) / band))
            return value < 0 ? -eased : eased
        }
        return CGPoint(x: soften(point.x, extent: worldSize.width),
                       y: soften(point.y, extent: worldSize.height))
    }

    static func cameraOffset(_ point: CGPoint, worldSize: CGSize, canvas: CGSize) -> CGPoint {
        let halfW = worldSize.width / 2, halfH = worldSize.height / 2
        guard worldSize.width > canvas.width, worldSize.height > canvas.height else { return point }
        return CGPoint(x: min(max(point.x, canvas.width - halfW), halfW),
                       y: min(max(point.y, canvas.height - halfH), halfH))
    }
}

/// Slots and walking distance are saved with the garden; no flower is lost on rotation.
struct MeadowFlowerTrail {
    static let capacity = 64
    static let spacing: CGFloat = 26
    private(set) var positions: [CGPoint] = []
    private(set) var nextSlot = 0
    private(set) var lastWalkPoint: CGPoint?

    mutating func stamp(behind point: CGPoint, heading: CGFloat) -> Int? {
        guard point.x.isFinite, point.y.isFinite, heading.isFinite else { return nil }
        if let lastWalkPoint,
           hypot(point.x - lastWalkPoint.x, point.y - lastWalkPoint.y) < Self.spacing { return nil }
        lastWalkPoint = point
        let slot = nextSlot
        let side: CGFloat = slot.isMultiple(of: 2) ? 5 : -5
        let bloom = CGPoint(x: point.x - cos(heading) * 22 - sin(heading) * side,
                            y: point.y - sin(heading) * 22 + cos(heading) * side)
        if positions.count < Self.capacity { positions.append(bloom) } else { positions[slot] = bloom }
        nextSlot = (slot + 1) % Self.capacity
        return slot
    }
}

enum MeadowDandelionGeometry {
    static func position(preferred: CGPoint, worldSize: CGSize) -> CGPoint {
        let margin = min(64, min(worldSize.width, worldSize.height) * 0.25)
        let limitX = max(0, worldSize.width / 2 - margin)
        let limitY = max(0, worldSize.height / 2 - margin)
        return CGPoint(x: min(max(preferred.x, -limitX), limitX),
                       y: min(max(preferred.y, -limitY), limitY))
    }
}

private extension UIColor {
    /// Linear mix toward another colour — used to fold the meadow's colours in at night.
    func blended(with other: UIColor, fraction: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = min(max(fraction, 0), 1)
        return UIColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t,
                       blue: b1 + (b2 - b1) * t, alpha: a1 + (a2 - a1) * t)
    }
}
