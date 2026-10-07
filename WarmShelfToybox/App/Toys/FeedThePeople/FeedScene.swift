import SpriteKit
import UIKit

final class FeedScene: BaseToyScene {
    override var firstSessionHintKey: String? { "hint.feed" }
    override func firstSessionHintPoint() -> CGPoint {
        let homes = startingFoodPositions(count: availableFoodKinds.count)
        if let want = characters.first?.desiredFood,
           let index = availableFoodKinds.firstIndex(of: want), homes.indices.contains(index) {
            return homes[index]
        }
        return homes.first ?? CGPoint(x: size.width / 2, y: size.height * 0.3)
    }
    override var toyVoice: AudioManager.LullSoundVoice { .feed }
    private var worldLayer = SKNode()
    private var tableLayer = SKNode()
    private var characterShadowLayer = SKNode()
    private var characterLayer = SKNode()
    private var foodLayer = SKNode()

    private var characters: [CharacterNode] = []
    private var characterShadows: [ObjectIdentifier: SKSpriteNode] = [:]
    private var activeFoodTouches: [UITouch: FoodNode] = [:]
    private var feedsSinceVisitorChange = 0
    private var foodSourcePosition: CGPoint {
        let verticalOffset: CGFloat
        if isPadLikeCanvas {
            verticalOffset = size.width > size.height ? 78 : 92
        } else {
            verticalOffset = size.width > size.height ? 58 : 96
        }

        return CGPoint(
            x: size.width / 2,
            y: tableTopY - verticalOffset
        )
    }

    private struct CharacterSpec {
        let base: UIColor
        let clothing: UIColor
        let personality: CharacterPersonality
        let radius: CGFloat
        let dislikedFood: FoodKind?
        let desiredFoods: [FoodKind]
        let hungerBites: Int
        let accessory: CharacterAccessory
        let hairStyle: CharacterHairStyle
        let outfitStyle: CharacterOutfitStyle
        var castMember: String? = nil   // authored felt friend; survives rotation
    }

    /// A different friend than last time, when the authored cast is available.
    private var lastCastMember: String?
    private func rollCastMember() -> String? {
        guard ToyArt.texture("feed-cast-sprout-1") != nil else { return nil }
        let pool = CharacterNode.castMembers.filter { $0 != lastCastMember }
        let pick = pool.randomElement() ?? CharacterNode.castMembers.randomElement()
        lastCastMember = pick
        return pick
    }

    private struct CharacterSlot {
        let position: CGPoint
        let zPosition: CGFloat
    }

    private struct CharacterSnapshot {
        let spec: CharacterSpec
        let mood: CharacterMood
        let bitesRemaining: Int
        let wishGranted: Bool
        let xRatio: CGFloat
        let yOffsetFromTable: CGFloat
        let zRotation: CGFloat
        let zPosition: CGFloat
        let alpha: CGFloat
    }

    private struct FoodSnapshot {
        let kind: FoodKind
    }

    private var tableTopY: CGFloat {
        tableTopY(for: size)
    }

    private var isPadLikeCanvas: Bool {
        isPadLikeCanvas(for: size)
    }

    private var foodScale: CGFloat {
        foodScale(for: size)
    }

    private var characterBaseScale: CGFloat {
        characterBaseScale(for: size)
    }

    private let availableFoodKinds: [FoodKind] = [.apple, .carrot, .banana, .egg]

    /// The shopkeeper's counter, measured on `feed-counter.png` (y from the TOP): the plank's
    /// top face runs 0.04…0.34 and its front edge 0.40…0.68; 6% at each end is the rounded
    /// plank end, never shown. Board windows start at staggered offsets so the seams
    /// between boards don't line up into a tiled floor.
    private enum CounterArt {
        static let topFaceTop: CGFloat = 0.04
        static let topFaceBottom: CGFloat = 0.34
        static let frontEdgeTop: CGFloat = 0.40
        static let frontEdgeBottom: CGFloat = 0.68
        static let insetX: CGFloat = 0.06
        static let boardOffsets: [CGFloat] = [0.0, 0.42, 0.18, 0.55, 0.30, 0.08, 0.47, 0.24]
        /// Share of a painted friend hidden behind the counter's far edge: the round base
        /// and the feet. The friend is seen from the chest up, leaning on the counter.
        static let hiddenFraction: CGFloat = 0.30
    }

    private var hasCounterArt: Bool { ToyArt.texture("feed-counter") != nil }
    private var counterLipHeight: CGFloat { isPadLikeCanvas ? 64 : 44 }
    /// Where the food plates stand on the countertop (y), a little nearer the child than
    /// the middle of the counter.
    private var counterPlateY: CGFloat {
        counterLipHeight + max(60, tableTopY - counterLipHeight) * 0.42
    }
    private var counterFoodSpread: CGFloat {
        min(size.width * (size.width > size.height ? 0.56 : 0.76), isPadLikeCanvas ? 620 : 330)
    }
    private var counterPlateSize: CGSize {
        let slot = counterFoodSpread / CGFloat(max(1, availableFoodKinds.count - 1))
        let widest = availableFoodKinds.map { $0.baseSize.width * foodScale }.max() ?? 80
        let w = min(slot * 0.9, widest * 1.08)
        return CGSize(width: w, height: w * 0.78)
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        rebuildWorld()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        let characterSnapshots = snapshotCharacters(oldSize: oldSize)
        let foodSnapshots = snapshotFoods(oldSize: oldSize)
        rebuildWorld(preservingCharacters: characterSnapshots, preservingFoods: foodSnapshots)
    }

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        syncCharacterShadows()
    }

    /// A still, sunlit room behind the table: two warm planes meeting at a soft horizon,
    /// a gentle seam of light, and an overhead glow — Monument-Valley calm.
    private func buildSereneBackdrop() {
        childNode(withName: "feedBackdrop")?.removeFromParent()
        let backdrop = SKNode()
        backdrop.name = "feedBackdrop"
        backdrop.zPosition = 1
        addChild(backdrop)

        // The authored farm stand (Docs/FeedSlice.md): trees, bunting, lamp and shelves
        // baked into one plate behind the friends.
        if let tex = ToyArt.texture("feed-stand-back") {
            let plate = SKSpriteNode(texture: tex)
            let ts = tex.size()
            let cover = max(size.width / max(1, ts.width), size.height / max(1, ts.height)) * 1.08
            plate.size = CGSize(width: ts.width * cover, height: ts.height * cover)
            plate.position = CGPoint(x: size.width / 2, y: size.height / 2)
            backdrop.addChild(plate)
            return
        }

        let horizon = tableTopY + (isPadLikeCanvas(for: size) ? 44 : 26)

        // Lower plane — a warm floor a touch deeper than the wall, for quiet depth.
        let floor = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.width, height: max(1, horizon)))
        floor.fillColor = WarmShelfPalette.warmCream.withAlpha(0.55)
        floor.strokeColor = .clear
        backdrop.addChild(floor)

        // A warm wall above the horizon — the room has a real back wall, not bare paper.
        let wall = SKShapeNode(rect: CGRect(x: 0, y: horizon, width: size.width, height: max(1, size.height - horizon)))
        wall.fillColor = WarmShelfPalette.warmCream.withAlpha(0.22)
        wall.strokeColor = .clear
        backdrop.addChild(wall)

        // A proper baseboard where floor meets wall — the one line that makes it read as a room.
        let baseboard = SKShapeNode(rect: CGRect(x: 0, y: horizon - 5, width: size.width, height: 7))
        baseboard.fillColor = WarmShelfPalette.cocoa.withAlpha(0.14)
        baseboard.strokeColor = .clear
        backdrop.addChild(baseboard)
        let seam = SKShapeNode(rect: CGRect(x: 0, y: horizon + 2, width: size.width, height: 2.5))
        seam.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.55)
        seam.strokeColor = .clear
        backdrop.addChild(seam)

        // Overhead light — a large, very soft warm glow from above.
        let light = SKShapeNode(circleOfRadius: max(size.width, size.height) * 0.55)
        light.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.42)
        light.strokeColor = .clear
        light.position = CGPoint(x: size.width * 0.5, y: size.height * 0.98)
        backdrop.addChild(light)

        // A second, tighter pool of light centered on where the friends gather.
        let pool = SKShapeNode(circleOfRadius: max(size.width, size.height) * 0.32)
        pool.fillColor = WarmShelfPalette.butter.withAlpha(0.07)
        pool.strokeColor = .clear
        pool.position = CGPoint(x: size.width * 0.5, y: horizon + size.height * 0.16)
        backdrop.addChild(pool)

        addSunlitWindow(to: backdrop, horizon: horizon)
    }

    /// A little sunlit window high on the wall — a soft glimpse of warm sky that makes the room
    /// feel like a real family breakfast nook. Sits up and to the side, clear of the friends.
    private func addSunlitWindow(to backdrop: SKNode, horizon: CGFloat) {
        let winW = min(size.width * 0.17, 116)
        let winH = winW * 1.04
        let center = CGPoint(x: size.width * (size.width > size.height ? 0.87 : 0.80),
                             y: max(horizon + size.height * 0.30, size.height * 0.80))

        let glow = SKShapeNode(rectOf: CGSize(width: winW * 1.8, height: winH * 1.8), cornerRadius: 30)
        glow.fillColor = WarmShelfPalette.butter.withAlpha(0.07)
        glow.strokeColor = .clear
        glow.position = center
        backdrop.addChild(glow)

        let frame = SKShapeNode(rectOf: CGSize(width: winW + 12, height: winH + 12), cornerRadius: 14)
        frame.fillColor = WarmShelfPalette.sand.withAlpha(0.5)
        frame.strokeColor = .clear
        frame.position = center
        backdrop.addChild(frame)

        let crop = SKCropNode()
        crop.position = center
        let mask = SKShapeNode(rectOf: CGSize(width: winW, height: winH), cornerRadius: 10)
        mask.fillColor = .white
        crop.maskNode = mask
        let sky = SKShapeNode(rectOf: CGSize(width: winW, height: winH))
        sky.fillColor = WarmShelfPalette.waterBlue.withAlpha(0.18)
        sky.strokeColor = .clear
        crop.addChild(sky)
        let sun = SKShapeNode(circleOfRadius: winW * 0.16)
        sun.fillColor = WarmShelfPalette.butter.withAlpha(0.5)
        sun.strokeColor = .clear
        sun.position = CGPoint(x: winW * 0.2, y: winH * 0.22)
        crop.addChild(sun)
        let hill = SKShapeNode(ellipseOf: CGSize(width: winW * 1.5, height: winH * 0.7))
        hill.fillColor = WarmShelfPalette.sage.withAlpha(0.34)
        hill.strokeColor = .clear
        hill.position = CGPoint(x: -winW * 0.1, y: -winH * 0.5)
        crop.addChild(hill)
        backdrop.addChild(crop)

        let muntin = SKShapeNode(rect: CGRect(x: center.x - 1, y: center.y - winH / 2, width: 2, height: winH))
        muntin.fillColor = WarmShelfPalette.sand.withAlpha(0.5)
        muntin.strokeColor = .clear
        backdrop.addChild(muntin)
        let rim = SKShapeNode(rectOf: CGSize(width: winW, height: winH), cornerRadius: 10)
        rim.fillColor = .clear
        rim.strokeColor = WarmShelfPalette.paperHighlight.withAlpha(0.5)
        rim.lineWidth = 2.5
        rim.position = center
        backdrop.addChild(rim)
    }

    private func tableTopY(for sceneSize: CGSize) -> CGFloat {
        // Sit the table higher so characters fill the upper-middle and the food
        // rests off the very bottom edge — no large empty void at the top.
        let landscape = sceneSize.width > sceneSize.height
        if landscape, !isPadLikeCanvas(for: sceneSize) {
            // A landscape phone needs a deeper counter (the food stands on it) and a
            // smaller friend above it — see foodScale/characterBaseScale.
            return max(140, min(sceneSize.height * 0.44, sceneSize.height - 200))
        }
        let ratio: CGFloat = landscape ? 0.40 : 0.42
        return max(140, min(sceneSize.height * ratio, sceneSize.height - 260))
    }

    private func isPadLikeCanvas(for sceneSize: CGSize) -> Bool {
        min(sceneSize.width, sceneSize.height) >= 700
    }

    private func foodScale(for sceneSize: CGSize) -> CGFloat {
        // Chunkier toy food — easier for toddler fingers to grab, bolder on screen.
        if isPadLikeCanvas(for: sceneSize) {
            return sceneSize.width > sceneSize.height
                ? min(2.7, max(2.16, sceneSize.height / 360))
                : min(3.1, max(2.5, sceneSize.width / 380))
        }

        if sceneSize.width > sceneSize.height {
            // Was up to 2.3 — an apple a third of the screen tall, overlapping the friend.
            return min(1.35, max(1.0, sceneSize.height / 330))
        }

        return min(1.6, max(1.34, sceneSize.width / 300))
    }

    private func characterBaseScale(for sceneSize: CGSize) -> CGFloat {
        // The friend is the centre of gravity — noticeably bigger and closer on every device.
        if isPadLikeCanvas(for: sceneSize) {
            return sceneSize.width > sceneSize.height
                ? min(1.44, max(1.2, sceneSize.height / 640))
                : min(1.74, max(1.44, sceneSize.width / 610))
        }

        if sceneSize.width > sceneSize.height {
            // Small enough that a friend standing behind the counter keeps the whole head
            // on screen (the old 1.31 clipped the top of the head in landscape).
            return min(1.3, max(0.98, sceneSize.height / 380))
        }

        return min(1.54, max(1.28, sceneSize.width / 300))
    }

    private func rebuildWorld(
        preservingCharacters characterSnapshots: [CharacterSnapshot] = [],
        preservingFoods foodSnapshots: [FoodSnapshot] = []
    ) {
        guard size.width > 160, size.height > 160 else { return }

        removeAction(forKey: "feed.replaceVisitor")
        removeAction(forKey: "feed.inviteNewVisitor")
        removeAction(forKey: "feed.moreFoodInvite")
        removeAction(forKey: "firstDesiredFoodInvite")
        for kind in availableFoodKinds {
            removeAction(forKey: "feed.respawn.\(kind.accessibilityName)")
        }

        activeFoodTouches.removeAll()
        characterShadows.removeAll()
        worldLayer.removeFromParent()

        buildSereneBackdrop()

        worldLayer = SKNode()
        worldLayer.zPosition = 18
        addChild(worldLayer)

        tableLayer = SKNode()
        tableLayer.zPosition = 0
        worldLayer.addChild(tableLayer)

        characterShadowLayer = SKNode()
        characterShadowLayer.zPosition = 11
        worldLayer.addChild(characterShadowLayer)

        characterLayer = SKNode()
        characterLayer.zPosition = 12
        worldLayer.addChild(characterLayer)

        foodLayer = SKNode()
        foodLayer.zPosition = 34
        worldLayer.addChild(foodLayer)

        addBackdrop()
        addTable()
        addFoodSource()
        characterSnapshots.isEmpty ? addCharacters() : addCharacters(from: characterSnapshots)
        if foodSnapshots.isEmpty {
            addFoods()
        } else {
            addFoods(from: foodSnapshots)
            ensureAvailableFoods(animated: true)
        }
        addAmbientTableLife()
        arrangeThoughtBubbles()
        if characterSnapshots.isEmpty && foodSnapshots.isEmpty {
            inviteFirstDesiredFood()
        }
    }

    /// Fan thought bubbles apart so they never overlap, even when friends stand close.
    private func arrangeThoughtBubbles() {
        let sorted = characters.sorted { $0.position.x < $1.position.x }
        let n = sorted.count
        for (i, character) in sorted.enumerated() {
            let t = n <= 1 ? 0.5 : CGFloat(i) / CGFloat(n - 1)
            let side = (t - 0.5) * 2
            let lift: CGFloat = (i == 0 || i == n - 1) ? 0 : character.headRadius * 0.6
            let desired = character.defaultThoughtBubbleLocalY + lift
            // Never let the bubble clip the top of the screen (matters in landscape).
            let maxLocalY = (size.height - 14 - character.thoughtBubbleHalfHeight) - character.position.y
            let localY = min(desired, max(character.headRadius * 1.2, maxLocalY))
            character.arrangeThoughtBubble(sideSign: side, localY: localY)
        }
    }

    private func snapshotCharacters(oldSize: CGSize) -> [CharacterSnapshot] {
        guard oldSize.width > 20, oldSize.height > 20 else { return [] }
        let oldTableTopY = tableTopY(for: oldSize)

        return characters.compactMap { character in
            guard character.parent != nil else { return nil }
            let spec = CharacterSpec(
                base: character.snapshotBaseColor,
                clothing: character.snapshotClothingColor,
                personality: character.personality,
                radius: character.headRadius,
                dislikedFood: character.dislikedFood,
                desiredFoods: character.desiredFoods,   // REMAINING wants — a half-served sandwich survives rotation
                hungerBites: character.hungerBites,
                accessory: character.snapshotAccessory,
                hairStyle: character.snapshotHairStyle,
                outfitStyle: character.snapshotOutfitStyle,
                castMember: character.castMember
            )
            return CharacterSnapshot(
                spec: spec,
                mood: character.snapshotMood,
                bitesRemaining: character.snapshotBitesRemaining,
                wishGranted: character.wishGranted,
                xRatio: oldSize.width > 0 ? character.position.x / oldSize.width : 0.5,
                yOffsetFromTable: character.position.y - oldTableTopY,
                zRotation: character.zRotation,
                zPosition: character.zPosition,
                alpha: character.alpha
            )
        }
    }

    private func snapshotFoods(oldSize: CGSize) -> [FoodSnapshot] {
        // A bite commits before its visual flight. Serving sprites are transient and
        // never reconstructed; ordinary food returns to its table home on rotation.
        foodLayer.children.compactMap { node in
            guard let food = node as? FoodNode, !food.isServing else { return nil }
            return FoodSnapshot(kind: food.kind)
        }
    }

    private func addTable() {
        let cx = size.width / 2

        if let tex = ToyArt.texture("feed-counter") {
            buildShopCounter(tex)
            return
        }

        let backY = tableTopY
        let depth = (size.width > size.height ? 0.30 : 0.34) * size.height
        let frontY = max(26, backY - depth)
        let backW = min(size.width * 0.72, isPadLikeCanvas ? 700 : 460)
        let frontW = size.width + 120

        // Soft floor shadow beneath the whole table.
        let shadow = SKShapeNode(ellipseOf: CGSize(width: frontW * 0.9, height: 46))
        shadow.fillColor = WarmShelfPalette.cocoa.withAlpha(0.05); shadow.strokeColor = .clear
        shadow.position = CGPoint(x: cx, y: frontY + 8); shadow.zPosition = -1
        tableLayer.addChild(shadow)

        // The front face (table side / thickness) — darker warm wood, fills to the bottom.
        // Clay-textured: a flat hex fill is what made the whole toy read as a prototype.
        let face = SKShapeNode(rect: CGRect(x: cx - frontW / 2, y: 0, width: frontW, height: frontY), cornerRadius: 0)
        face.fillColor = UIColor(hex: 0xB07A4E); face.strokeColor = .clear; face.zPosition = 0.4
        tableLayer.addChild(face)
        ProceduralTexture.applyClayFill(to: face, base: UIColor(hex: 0xB07A4E), size: CGSize(width: frontW, height: max(1, frontY)))

        // The table top — a warm wooden trapezoid (wider at the front for perspective).
        let topPath = CGMutablePath()
        topPath.move(to: CGPoint(x: cx - backW / 2, y: backY))
        topPath.addLine(to: CGPoint(x: cx + backW / 2, y: backY))
        topPath.addLine(to: CGPoint(x: cx + frontW / 2, y: frontY))
        topPath.addLine(to: CGPoint(x: cx - frontW / 2, y: frontY))
        topPath.closeSubpath()
        let top = SKShapeNode(path: topPath)
        top.fillColor = UIColor(hex: 0xCE9A66); top.strokeColor = .clear; top.zPosition = 0.5
        tableLayer.addChild(top)
        ProceduralTexture.applyClayFill(to: top, base: UIColor(hex: 0xCE9A66), size: CGSize(width: frontW, height: max(1, backY - frontY)))

        // Wood-grain seams, fanning toward the viewer.
        for f in [CGFloat(-0.55), -0.18, 0.18, 0.55] {
            let seam = CGMutablePath()
            seam.move(to: CGPoint(x: cx + backW * f, y: backY))
            seam.addLine(to: CGPoint(x: cx + frontW * f, y: frontY))
            let line = SKShapeNode(path: seam)
            line.strokeColor = UIColor(hex: 0xB07A4E).withAlpha(0.4); line.lineWidth = 2; line.fillColor = .clear
            line.zPosition = 0.55; tableLayer.addChild(line)
        }

        // Warm light highlight along the back edge + a crisp front lip.
        let backEdge = makeRoundedRect(size: CGSize(width: backW, height: 6), radius: 3, fill: WarmShelfPalette.paperHighlight.withAlpha(0.22))
        backEdge.position = CGPoint(x: cx, y: backY - 2); backEdge.zPosition = 0.56; tableLayer.addChild(backEdge)
        let frontLip = SKShapeNode(rect: CGRect(x: cx - frontW / 2, y: frontY - 3, width: frontW, height: 6), cornerRadius: 3)
        frontLip.fillColor = UIColor(hex: 0xDDAE7C); frontLip.strokeColor = .clear; frontLip.zPosition = 0.58
        tableLayer.addChild(frontLip)
    }

    /// The shopkeeper's counter, seen from the child's side of it. Its far edge is the table
    /// line the friend stands behind, and it runs to the bottom of the screen, so a friend
    /// is only ever seen from the chest up and the food rests ON a real surface. (It used
    /// to be one thin plank floating mid-screen, with the friend's round bottom poking out
    /// under it and the food hanging off its front face.) Built from the authored plank:
    /// its top face, cut into board strips with staggered seams, makes a deep counter top;
    /// its front edge becomes the near lip at the bottom of the screen.
    private func buildShopCounter(_ tex: SKTexture) {
        let ts = tex.size()
        let cx = size.width / 2
        let stripW = size.width + 40
        let usable = 1 - CounterArt.insetX * 2
        // About one screen-width of the plank per board keeps the wood near its painted
        // resolution (wider screens take more of it).
        let window = min(usable, max(0.35, stripW / max(1, ts.width)))
        let faceH = CounterArt.topFaceBottom - CounterArt.topFaceTop
        let boardNatH = faceH * ts.height * (stripW / max(1, window * ts.width))
        let lipH = counterLipHeight
        let farY = tableTopY
        // Under the counter z (accumulated 51 in tableLayer): above the friends (≈43),
        // below the food (≈92).
        let counterZ: CGFloat = 33

        // A soft shade on the friend where they lean in over the far edge.
        let lean = SKSpriteNode(texture: ProceduralTexture.softClayShadow(size: CGSize(width: size.width * 0.8, height: 34)))
        lean.position = CGPoint(x: cx, y: farY + 6)
        lean.alpha = 0.32
        lean.zPosition = counterZ - 0.2
        tableLayer.addChild(lean)

        // The top: boards from the far edge down to the lip, nearer boards a little taller
        // (depth), each a different window of the plank so no seam lines up.
        var y = farY
        var board = 0
        while y > lipH + 0.5 {
            let nearness = 1 - (y - lipH) / max(1, farY - lipH)
            let h = min(boardNatH * (1 + 0.25 * nearness), y - lipH + 1)
            let offset = CounterArt.boardOffsets[board % CounterArt.boardOffsets.count] * max(0, usable - window)
            let unit = CGRect(x: CounterArt.insetX + offset,
                              y: 1 - CounterArt.topFaceBottom,
                              width: window,
                              height: faceH * min(1, h / max(1, boardNatH)))
            let strip = SKSpriteNode(texture: SKTexture(rect: unit, in: tex))
            strip.size = CGSize(width: stripW, height: h)
            strip.anchorPoint = CGPoint(x: 0.5, y: 1)
            strip.position = CGPoint(x: cx, y: y)
            if board % 2 == 1 { strip.xScale = -1 }
            // A touch of shade toward the child so the top reads as one lit surface.
            strip.color = WarmShelfPalette.cocoa
            strip.colorBlendFactor = min(0.12, CGFloat(board) * 0.02)
            strip.zPosition = counterZ
            tableLayer.addChild(strip)
            y -= h
            board += 1
        }

        // The near lip: the plank's own front edge, running off the bottom of the screen.
        let lipUnit = CGRect(x: CounterArt.insetX, y: 1 - CounterArt.frontEdgeBottom,
                             width: window, height: CounterArt.frontEdgeBottom - CounterArt.frontEdgeTop)
        let lip = SKSpriteNode(texture: SKTexture(rect: lipUnit, in: tex))
        lip.size = CGSize(width: stripW, height: lipH + 6)
        lip.anchorPoint = CGPoint(x: 0.5, y: 1)
        lip.position = CGPoint(x: cx, y: lipH)
        lip.zPosition = counterZ + 0.1
        tableLayer.addChild(lip)

        // A thin lit rim on the far edge: the line the friend leans on.
        let rim = SKSpriteNode(color: WarmShelfPalette.paperHighlight, size: CGSize(width: stripW, height: 2.5))
        rim.alpha = 0.4
        rim.position = CGPoint(x: cx, y: farY - 1.25)
        rim.zPosition = counterZ + 0.1
        tableLayer.addChild(rim)

        // A wooden plate for every food: each food has a home it visibly goes back to.
        let homes = counterFoodPositions(count: availableFoodKinds.count)
        let plate = counterPlateSize
        for home in homes {
            let shade = SKSpriteNode(texture: ProceduralTexture.softClayShadow(size: CGSize(width: plate.width * 1.1, height: plate.height * 0.55)))
            shade.position = CGPoint(x: home.x + plate.width * 0.03, y: counterPlateY - plate.height * 0.3)
            shade.alpha = 0.45
            shade.zPosition = counterZ + 0.3
            tableLayer.addChild(shade)
            if let pedestal = ToyArt.sprite("feed-pedestal", fit: plate) {
                pedestal.position = CGPoint(x: home.x, y: counterPlateY)
                pedestal.zPosition = counterZ + 0.5
                tableLayer.addChild(pedestal)
            }
        }
    }

    /// Food homes on the counter: one row of plates across the top, each food standing on
    /// its plate (its bottom on the plate's top face).
    private func counterFoodPositions(count: Int) -> [CGPoint] {
        let spread = counterFoodSpread
        let startX = size.width / 2 - spread / 2
        let plateTop = counterPlateY + counterPlateSize.height * 0.16
        return (0..<count).map { index in
            let t = count == 1 ? 0.5 : CGFloat(index) / CGFloat(count - 1)
            let kind = availableFoodKinds.indices.contains(index) ? availableFoodKinds[index] : .apple
            let h = kind.baseSize.height * foodScale
            return CGPoint(x: startX + spread * t, y: plateTop + h * 0.40)
        }
    }

    /// A cheerful bunting banner fills the empty top (replaces the old cafeteria clutter).
    private func addBackdrop() {
        // The stand plate bakes its own bunting — never hang a second banner over it.
        guard ToyArt.texture("feed-stand-back") == nil else { return }
        // Hang the banner clearly BELOW the home handle so the string never crosses behind it.
        let y = size.height * (size.width > size.height ? 0.80 : 0.80)
        let inset: CGFloat = 30
        let stringPath = CGMutablePath()
        stringPath.move(to: CGPoint(x: inset, y: y + 6))
        stringPath.addQuadCurve(to: CGPoint(x: size.width - inset, y: y + 6), control: CGPoint(x: size.width / 2, y: y - 18))
        let string = SKShapeNode(path: stringPath)
        string.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.22); string.lineWidth = 2; string.fillColor = .clear
        string.zPosition = -6; tableLayer.addChild(string)

        let colors = [WarmShelfPalette.petal, WarmShelfPalette.butter, WarmShelfPalette.sage, WarmShelfPalette.waterBlue, WarmShelfPalette.lavender, WarmShelfPalette.terracotta]
        let count = max(6, Int(size.width / 70))
        for i in 0..<count {
            let t = CGFloat(i) / CGFloat(count - 1)
            let x = inset + t * (size.width - inset * 2)
            // Follow the gentle sag of the string.
            let sag = (1 - pow((t - 0.5) * 2, 2)) * 24
            let py = y + 6 - sag
            let flag = SKShapeNode(path: {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: -11, y: 0)); p.addLine(to: CGPoint(x: 11, y: 0)); p.addLine(to: CGPoint(x: 0, y: -20)); p.closeSubpath(); return p
            }())
            flag.fillColor = colors[i % colors.count].withAlpha(0.9); flag.strokeColor = .clear
            flag.position = CGPoint(x: x, y: py); flag.zPosition = -5; tableLayer.addChild(flag)
            flag.run(.repeatForever(.sequence([
                .wait(forDuration: .random(in: 1.6...3.0)),
                .rotate(toAngle: 0.06, duration: 0.9), .rotate(toAngle: -0.06, duration: 1.0), .rotate(toAngle: 0, duration: 0.7)
            ])))
        }
    }

    /// A woven round placemat the food is served on — clearly "here's the food", and it
    /// sits flat on the table (no confusing floating bowl).
    private func addFoodSource() {
        // With the shopkeeper's counter, fresh food comes up from under the counter (see
        // respawnFood); a basket behind the counter would never be seen.
        guard !hasCounterArt else { return }
        let w = min(size.width * (isPadLikeCanvas ? 0.5 : 0.66), isPadLikeCanvas ? 460 : 320)
        let h = w * 0.42
        let p = foodSourcePosition

        // The woven restock basket the food arrives from (Docs/FeedSlice.md).
        if let basket = ToyArt.sprite("feed-basket", fit: CGSize(width: w * 0.62, height: w * 0.5)) {
            let shadow = SKShapeNode(ellipseOf: CGSize(width: w * 0.66, height: h * 0.5))
            shadow.fillColor = WarmShelfPalette.cocoa.withAlpha(0.06)
            shadow.strokeColor = .clear
            shadow.position = CGPoint(x: p.x, y: p.y - h * 0.18)
            shadow.zPosition = 2
            tableLayer.addChild(shadow)
            basket.position = p
            basket.zPosition = 2.4
            tableLayer.addChild(basket)
            return
        }

        let shadow = SKShapeNode(ellipseOf: CGSize(width: w * 1.02, height: h * 1.05))
        shadow.fillColor = WarmShelfPalette.cocoa.withAlpha(0.05); shadow.strokeColor = .clear
        shadow.position = CGPoint(x: p.x, y: p.y - 4); shadow.zPosition = 2; tableLayer.addChild(shadow)

        // Woven placemat: a warm disc with concentric weave rings.
        let mat = SKShapeNode(ellipseOf: CGSize(width: w, height: h))
        mat.fillColor = WarmShelfPalette.linen.withAlpha(0.95)
        mat.strokeColor = WarmShelfPalette.sand.withAlpha(0.7); mat.lineWidth = 3
        mat.position = p; mat.zPosition = 2.4; tableLayer.addChild(mat)
        for f in [CGFloat(0.78), 0.54, 0.3] {
            let ring = SKShapeNode(ellipseOf: CGSize(width: w * f, height: h * f))
            ring.fillColor = .clear; ring.strokeColor = WarmShelfPalette.sand.withAlpha(0.28); ring.lineWidth = 2
            ring.position = p; ring.zPosition = 2.45; tableLayer.addChild(ring)
        }
        // Woven cross-hatch for texture.
        for i in -3...3 {
            let bar = makeRoundedRect(size: CGSize(width: w * 0.92, height: 1.4), radius: 0.7, fill: WarmShelfPalette.sand.withAlpha(0.16))
            bar.position = CGPoint(x: p.x, y: p.y + CGFloat(i) * h * 0.14); bar.zPosition = 2.46; tableLayer.addChild(bar)
        }
    }

    private func addCharacters() {
        let scale = characterBaseScale
        let characterSpecs = startingCharacterSpecs(scale: scale)
        let slots = characterSlots(for: characterSpecs.map(\.radius))
        characters = zip(characterSpecs, slots).map { spec, slot in
            addCharacter(spec: spec, in: slot, arrivalSide: nil)
        }
        addPlates(under: characters)
    }

    private func addCharacters(from snapshots: [CharacterSnapshot]) {
        // On rotation, keep WHO is at the table but re-derive clean slot positions for the
        // new orientation. Replaying stale offsets was what made rotation "break".
        let slots = characterSlots(for: snapshots.map { $0.spec.radius })
        characters = zip(snapshots, slots).map { snapshot, slot in
            let character = addCharacter(spec: snapshot.spec, in: slot, arrivalSide: nil)
            character.alpha = max(0.82, snapshot.alpha)
            character.restoreBitesRemaining(snapshot.bitesRemaining)
            character.restoreWishGranted(snapshot.wishGranted)
            character.restoreMood(snapshot.mood)
            return character
        }
        addPlates(under: characters)
        for character in characters where character.mood != .hungry {
            if character.visitIsComplete {
                satisfyAndReplace(character, after: character.mood == .eating ? 1.0 : 1.4)
            } else {
                character.inviteAnotherBite(after: character.mood == .eating ? 0.8 : 0.3)
            }
        }
    }

    private func startingCharacterSpecs(scale: CGFloat) -> [CharacterSpec] {
        // One friend at a time — a big, close-up hero with a clear, matchable want.
        let base = randomCharacterSpec(radius: 80 * scale)
        let wants = rollVisitorWants()
        return [CharacterSpec(
            base: base.base, clothing: base.clothing, personality: base.personality,
            radius: base.radius, dislikedFood: nil, desiredFoods: wants,
            // Sandwich friends are exactly as hungry as their ask, so completing
            // the stack and being full are the same happy moment.
            hungerBites: wants.count > 1 ? wants.count : startingHungerBites(),
            accessory: base.accessory, hairStyle: base.hairStyle, outfitStyle: base.outfitStyle,
            castMember: rollCastMember()
        )]
    }

    /// Approved delight: the sandwich ask. About 1 visitor in 6 wants TWO different
    /// foods, shown stacked in the bubble. Serving either removes it; both = the wow.
    /// The toybox's first compound request — planning and sequencing, same one verb.
    private func rollVisitorWants() -> [FoodKind] {
        var kinds = availableFoodKinds.shuffled()
        guard let first = kinds.first else { return [.apple] }
        kinds.removeFirst()
        if Int.random(in: 0..<6) == 0, let second = kinds.first {
            return [first, second]
        }
        return [first]
    }

    private func randomCharacterSpec(radius: CGFloat? = nil) -> CharacterSpec {
        let scale = characterBaseScale
        let bases = [
            WarmShelfPalette.petal,
            UIColor(hex: 0xB78E62),
            UIColor(hex: 0xA87D61),
            UIColor(hex: 0xC99A7E),
            UIColor(hex: 0x9F7357),
            UIColor(hex: 0xD7AA86),
            UIColor(hex: 0x77543F)
        ]
        let clothes = [
            WarmShelfPalette.terracotta,
            WarmShelfPalette.sage,
            WarmShelfPalette.butter,
            WarmShelfPalette.lavender,
            WarmShelfPalette.waterBlue
        ]
        let personalities: [CharacterPersonality] = [.fidgety, .calm, .slow]
        let desiredFoods: [FoodKind?] = [.apple, .carrot, .banana, .egg, nil, nil]
        let accessories: [CharacterAccessory] = [.none, .softCap, .softCrown, .flowerClip, .roundGlasses, .sunglasses]
        let hairStyles: [CharacterHairStyle] = [.none, .sprout, .tufts, .swoop]
        let outfitStyles: [CharacterOutfitStyle] = [.everyday, .apron, .overalls, .scarf, .buttonCoat, .starSweater]
        let dislikedFood: FoodKind? = nil   // positive-only: no friend ever dislikes a food
        let desiredFood = desiredFoods.randomElement() ?? nil
        let hungerBites = hungerBitesForNewFriend()

        return CharacterSpec(
            base: bases.randomElement() ?? WarmShelfPalette.petal,
            clothing: clothes.randomElement() ?? WarmShelfPalette.sage,
            personality: personalities.randomElement() ?? .calm,
            radius: radius ?? CGFloat.random(in: 54...70) * scale,
            dislikedFood: dislikedFood,
            desiredFoods: desiredFood.map { [$0] } ?? [],
            hungerBites: hungerBites,
            accessory: accessories.randomElement() ?? .none,
            hairStyle: hairStyles.randomElement() ?? .none,
            outfitStyle: outfitStyles.randomElement() ?? .everyday
        )
    }

    private func startingHungerBites() -> Int {
        Bool.random() ? 1 : 2
    }

    private func hungerBitesForNewFriend() -> Int {
        let roll = Int.random(in: 0..<100)
        if roll < 54 { return 1 }
        if roll < 90 { return 2 }
        return 3
    }

    private func characterSlots(for radii: [CGFloat]) -> [CharacterSlot] {
        let isLandscape = size.width > size.height
        let insets = view?.safeAreaInsets ?? .zero
        let count = CGFloat(radii.count)
        let usableWidth = size.width - insets.left - insets.right
        // Cluster eaters centrally in landscape so there's no wide dead gulf between them,
        // but give the (now larger) friends enough room that their heads don't merge.
        let span = min(usableWidth * (isLandscape ? 0.54 : 0.74), isPadLikeCanvas ? 720 : 400)
        let center = size.width / 2 + (insets.left - insets.right) / 2
        let firstX = center - span / 2
        let largestRadius = radii.max() ?? 60

        return radii.enumerated().map { index, radius in
            let rawX = count == 1 ? center : firstX + CGFloat(index) * span / max(1, count - 1)
            // Pad for the head AND its thought bubble, plus the safe area (home indicator),
            // so nothing ever clips the screen edge in landscape.
            let edgePadding = max(20, largestRadius * 0.95)
            let minX = insets.left + radius + edgePadding
            let maxX = size.width - insets.right - radius - edgePadding
            let x = min(max(rawX, minX), maxX)
            // Sit the friends right up at the table so the child can feed them close-up.
            // Lower offset in landscape also keeps heads clear of the home handle.
            let y = radius * (isLandscape ? 0.82 : 1.30)
            return CharacterSlot(
                position: CGPoint(x: x, y: tableTopY + y + 10),   // QA: lift heads clear of the counter crop
                // Below the counter's effective 15: friends arrive and stand BEHIND the
                // stand, waist hidden — the cells are waist-up for exactly this reason
                // (founder QA June 12: the big art cast was walking in over the counter).
                zPosition: 1 + CGFloat(index)
            )
        }
    }

    @discardableResult
    private func addCharacter(spec: CharacterSpec, in slot: CharacterSlot, arrivalSide: CGFloat?) -> CharacterNode {
        let character = CharacterNode(
            headRadius: spec.radius,
            baseColor: spec.base,
            clothingColor: spec.clothing,
            personality: spec.personality,
            dislikedFood: spec.dislikedFood,
            desiredFoods: spec.desiredFoods,
            hungerBites: spec.hungerBites,
            accessory: spec.accessory,
            hairStyle: spec.hairStyle,
            outfitStyle: spec.outfitStyle,
            castMember: spec.castMember
        )
        // Behind the counter, a painted friend stands so the far edge hides exactly its
        // round base and feet — chest up, leaning in, for every cast member's proportions.
        var home = slot.position
        if hasCounterArt, let stand = character.standHeight(hidingBottom: CounterArt.hiddenFraction) {
            home.y = tableTopY + stand
            // A tall friend (the knit hat) on a short landscape screen tucks a little
            // further behind the counter rather than lose the top of their head.
            if let headroom = character.paintedHeadroom {
                let overshoot = home.y + headroom - (size.height - 6)
                if overshoot > 0 { home.y -= min(overshoot, stand * 0.5) }
            }
        }
        if let arrivalSide {
            character.position = CGPoint(
                x: arrivalSide < 0 ? -spec.radius * 2.6 : size.width + spec.radius * 2.6,
                y: home.y
            )
        } else {
            character.position = home
        }
        character.zPosition = slot.zPosition
        character.alpha = arrivalSide == nil ? 1 : 0
        characterLayer.addChild(character)
        installCharacterShadow(for: character)

        if let arrivalSide {
            character.resetForArrival()
            let move = SKAction.move(to: home, duration: Double.random(in: 1.45...1.85))
            let fade = SKAction.fadeAlpha(to: 1, duration: 0.40)
            let leanIn = SKAction.rotate(toAngle: -arrivalSide * 0.10, duration: 0.28, shortestUnitArc: true)
            let leanOut = SKAction.rotate(toAngle: arrivalSide * 0.07, duration: 0.34, shortestUnitArc: true)
            let center = SKAction.rotate(toAngle: 0, duration: 0.42, shortestUnitArc: true)
            move.timingMode = .easeInEaseOut
            fade.timingMode = .easeInEaseOut
            leanIn.timingMode = .easeInEaseOut
            leanOut.timingMode = .easeInEaseOut
            center.timingMode = .easeInEaseOut
            character.run(.group([
                move,
                fade,
                .sequence([leanIn, leanOut, leanIn, center])
            ]), withKey: "arrival")
        }

        return character
    }

    private func characterShadowPosition(for character: CharacterNode) -> CGPoint {
        CGPoint(
            x: character.position.x + character.headRadius * 0.04,
            y: character.position.y - character.headRadius * 1.28
        )
    }

    private func installCharacterShadow(for character: CharacterNode) {
        let id = ObjectIdentifier(character)
        guard characterShadows[id] == nil else { return }

        let shadowSize = CGSize(
            width: character.headRadius * 1.58,
            height: max(16, character.headRadius * 0.24)
        )
        let shadow = SKSpriteNode(texture: ProceduralTexture.softClayShadow(size: shadowSize))
        shadow.size = shadowSize
        shadow.position = characterShadowPosition(for: character)
        shadow.alpha = character.alpha * 0.92
        shadow.zPosition = max(0, character.zPosition - 0.2)
        characterShadowLayer.addChild(shadow)
        characterShadows[id] = shadow
    }

    private func removeCharacterShadow(for character: CharacterNode) {
        let id = ObjectIdentifier(character)
        characterShadows[id]?.removeFromParent()
        characterShadows.removeValue(forKey: id)
    }

    private func syncCharacterShadows() {
        guard characterShadowLayer.parent != nil else { return }

        let liveIDs = Set(characters.filter { $0.parent != nil }.map { ObjectIdentifier($0) })
        let staleIDs = characterShadows.keys.filter { !liveIDs.contains($0) }
        for id in staleIDs {
            characterShadows[id]?.removeFromParent()
            characterShadows.removeValue(forKey: id)
        }

        for character in characters where character.parent != nil {
            let id = ObjectIdentifier(character)
            if characterShadows[id] == nil {
                installCharacterShadow(for: character)
            }
            guard let shadow = characterShadows[id] else { continue }
            shadow.position = characterShadowPosition(for: character)
            shadow.alpha = character.alpha * 0.92
            shadow.zPosition = max(0, character.zPosition - 0.2)
        }
    }

    private func addPlates(under characters: [CharacterNode]) {
        for character in characters {
            let plateWidth = character.headRadius * 1.72
            let plateHeight = character.headRadius * 0.38
            let plateY = tableTopY - (isPadLikeCanvas ? 28 : 22)

            let shadow = SKShapeNode(ellipseOf: CGSize(width: plateWidth * 0.96, height: plateHeight * 0.62))
            shadow.fillColor = WarmShelfPalette.cocoa.withAlpha(0.030)
            shadow.strokeColor = .clear
            shadow.position = CGPoint(x: character.position.x + character.headRadius * 0.04, y: plateY - 5)
            shadow.zPosition = 4.8
            tableLayer.addChild(shadow)

            let plate = SKShapeNode(ellipseOf: CGSize(width: plateWidth, height: plateHeight))
            plate.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.36)
            plate.strokeColor = WarmShelfPalette.sand.withAlpha(0.32)
            plate.lineWidth = max(1.0, character.headRadius * 0.014)
            plate.position = CGPoint(x: character.position.x, y: plateY)
            plate.zPosition = 5
            tableLayer.addChild(plate)

            let inner = SKShapeNode(ellipseOf: CGSize(width: plateWidth * 0.72, height: plateHeight * 0.54))
            inner.fillColor = .clear
            inner.strokeColor = WarmShelfPalette.sand.withAlpha(0.22)
            inner.lineWidth = max(0.9, character.headRadius * 0.010)
            inner.position = plate.position
            inner.zPosition = 5.2
            tableLayer.addChild(inner)
        }
    }

    private func addFoods() {
        let positions = startingFoodPositions(count: availableFoodKinds.count)

        for (index, kind) in availableFoodKinds.enumerated() {
            let food = makeFood(kind: kind, index: index)
            food.position = positions[index]
            foodLayer.addChild(food)
            runIdleFoodMotion(food, index: index)
        }
    }

    private func ensureAvailableFoods(animated: Bool) {
        let existingKinds = foodLayer.children.compactMap { ($0 as? FoodNode)?.kind }
        let missingKinds = availableFoodKinds.filter { kind in
            !existingKinds.contains(kind)
        }
        guard !missingKinds.isEmpty else { return }

        let positions = startingFoodPositions(count: availableFoodKinds.count)
        for kind in missingKinds {
            guard let homeIndex = availableFoodKinds.firstIndex(of: kind) else { continue }
            let food = makeFood(kind: kind, index: homeIndex)
            food.position = positions[homeIndex]
            food.alpha = animated ? 0 : 1
            food.setScale(animated ? 0.84 : 1.0)
            foodLayer.addChild(food)

            if animated {
                let appear = SKAction.group([
                    .fadeAlpha(to: 1, duration: 0.24),
                    .scale(to: 1.0, duration: 0.28)
                ])
                appear.timingMode = .easeOut
                food.run(.sequence([
                    appear,
                    .run { [weak self, weak food] in
                        guard let self, let food else { return }
                        self.runIdleFoodMotion(food, index: homeIndex)
                    }
                ]))
            } else {
                runIdleFoodMotion(food, index: homeIndex)
            }
        }
    }

    private func addFoods(from snapshots: [FoodSnapshot]) {
        for (index, snapshot) in snapshots.enumerated() {
            let food = makeFood(kind: snapshot.kind, index: index)
            food.position = food.homePosition
            foodLayer.addChild(food)
            runIdleFoodMotion(food, index: index)
        }
    }

    private func makeFood(kind: FoodKind, index: Int) -> FoodNode {
        let food = FoodNode(kind: kind, scale: foodScale)
        let homeIndex = availableFoodKinds.firstIndex(of: kind) ?? index
        let homes = startingFoodPositions(count: availableFoodKinds.count)
        food.homePosition = homes[min(homeIndex, homes.count - 1)]
        food.zPosition = CGFloat(40 + index)
        food.zRotation = CGFloat.random(in: -0.18...0.18)
        return food
    }

    private func inviteFirstDesiredFood() {
        run(.sequence([
            .wait(forDuration: 0.20),
            .run { [weak self] in
                guard let self else { return }
                let allFoods = self.foodLayer.children.compactMap { $0 as? FoodNode }

                if let character = self.characters.first(where: { $0.mood == .hungry && $0.hasRemainingDesires }) {
                    // Has a preference — invite each wished-for food, gently staggered.
                    character.playDesiredFoodDance()
                    for (index, desired) in character.desiredFoods.enumerated() {
                        guard let food = allFoods.first(where: { $0.kind == desired }) else { continue }
                        self.run(.sequence([
                            .wait(forDuration: Double(index) * 0.22),
                            .run { [weak self] in self?.pulseInvitedFood(food) }
                        ]))
                    }
                } else if let character = self.characters.first(where: { $0.mood == .hungry }) {
                    // No preference — animate the character and pulse all foods so the child
                    // understands "any of these will work."
                    character.playDesiredFoodDance()
                    for food in allFoods.prefix(2) {
                        self.run(.sequence([
                            .wait(forDuration: allFoods.firstIndex(of: food).map { Double($0) * 0.18 } ?? 0),
                            .run { [weak self] in self?.pulseInvitedFood(food) }
                        ]))
                    }
                }
            }
        ]), withKey: "firstDesiredFoodInvite")
    }

    private func pulseInvitedFood(_ food: FoodNode) {
        TouchFeedbackAnimator.tactileSpark(
            in: self,
            at: food.convert(CGPoint.zero, to: self),
            color: food.kind.fillColor,
            count: 6,
            includesRipple: true
        )
        // Asymmetric timing: quick lift (0.14s easeOut) → slow settle (0.28s easeInEaseOut).
        let dy = max(10, food.foodSize.height * 0.10)
        let lift = SKAction.moveBy(x: 0, y: dy, duration: 0.14); lift.timingMode = .easeOut
        let settle = SKAction.moveBy(x: 0, y: -dy, duration: 0.28); settle.timingMode = .easeInEaseOut
        let grow = SKAction.scale(to: 1.10, duration: 0.14); grow.timingMode = .easeOut
        let shrink = SKAction.scale(to: 1.0, duration: 0.28); shrink.timingMode = .easeInEaseOut
        food.run(.sequence([
            .group([lift, grow]),
            .group([settle, shrink])
        ]), withKey: "firstInvitePulse")
    }

    private func startingFoodPositions(count: Int) -> [CGPoint] {
        if hasCounterArt { return counterFoodPositions(count: count) }
        if !isPadLikeCanvas, size.height >= size.width, count > 4 {
            let columns = 4
            let spread = min(size.width * 0.76, 330)
            let columnGap = spread / CGFloat(columns - 1)
            let startX = size.width / 2 - spread / 2
            let backRowY = tableTopY - 58
            let frontRowY = tableTopY - 124

            return (0..<count).map { index in
                let row = index / columns
                let column = index % columns
                let xNudge: CGFloat = row == 0
                    ? CGFloat([0, -5, 6, 0][column])
                    : CGFloat([5, -7, 7, -5][column])
                let yNudge: CGFloat = row == 0
                    ? CGFloat([2, -8, 4, -3][column])
                    : CGFloat([-3, 5, -5, 4][column])
                return CGPoint(
                    x: startX + CGFloat(column) * columnGap + xNudge,
                    y: (row == 0 ? backRowY : frontRowY) + yNudge
                )
            }
        }

        let rowY = tableTopY - (isPadLikeCanvas ? 64 : 52)
        let spread = min(size.width * 0.62, isPadLikeCanvas ? 560 : 320)
        let startX = size.width / 2 - spread / 2

        return (0..<count).map { index in
            let fraction = count == 1 ? 0.5 : CGFloat(index) / CGFloat(count - 1)
            let x = startX + spread * fraction
            let yNudge: CGFloat = index.isMultiple(of: 2) ? 6 : -4
            return CGPoint(x: x, y: rowY + yNudge)
        }
    }

    private func runIdleFoodMotion(_ food: FoodNode, index: Int) {
        AmbientAnimator.idleDrift(
            node: food,
            x: CGFloat.random(in: -2.4...2.4),
            y: CGFloat.random(in: 1.8...4.0),
            duration: Double.random(in: 5.2...7.8),
            delay: Double(index) * 0.18
        )
    }

    private func addAmbientTableLife() {
        for index in 0..<8 {
            let mote = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.0...2.5))
            mote.fillColor = (index.isMultiple(of: 2) ? WarmShelfPalette.petal : WarmShelfPalette.sand)
                .withAlpha(CGFloat.random(in: 0.10...0.18))
            mote.strokeColor = .clear
            mote.position = CGPoint(
                x: CGFloat.random(in: size.width * 0.10...size.width * 0.90),
                y: tableTopY + CGFloat.random(in: 20...120)
            )
            mote.zPosition = 4
            worldLayer.addChild(mote)
            AmbientAnimator.idleDrift(
                node: mote,
                x: CGFloat.random(in: -4...4),
                y: CGFloat.random(in: 5...12),
                duration: Double.random(in: 5.5...8.8),
                delay: Double(index) * 0.14
            )
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        HapticsManager.shared.prepareForTouch()
        var playedPassiveFeedback = false

        for touch in touches {
            let point = touch.location(in: self)

            if activeFoodTouches.isEmpty, consumeShelfReturnTouch(at: point) {
                return
            }

            if let food = topFood(at: point), !isFoodAlreadyBeingDragged(food) {
                activeFoodTouches[touch] = food
                food.beginDrag(at: point)
                HapticsManager.shared.softTap()
                continue
            }

            guard activeFoodTouches.isEmpty, !playedPassiveFeedback else { continue }
            playedPassiveFeedback = true

            if let character = nearestCharacter(to: point), character.mouthDistance(to: point) < character.snapRadius {
                TouchFeedbackAnimator.acknowledge(node: character, profile: .shelfCard)
                TouchFeedbackAnimator.tactileSpark(in: self, at: point, color: WarmShelfPalette.petal, count: 3)
                AudioManager.shared.playSoftTap()
                HapticsManager.shared.softTap()
            } else {
                TouchFeedbackAnimator.emptyTap(in: self, at: point)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let food = activeFoodTouches[touch] else { continue }
            let point = touch.location(in: self)

            // Each dragged food owns its trail distance, including under multitouch.
            if food.shouldEmitTrail(at: point), !AmbientAnimator.reduceMotion {
                spawnFoodTrailMote(at: food.convert(.zero, to: self), color: food.kind.fillColor)
            }

            food.drag(to: point, in: self, bounds: dragBounds(for: food))

            // Snap zone: a clear pulsing signal that the food will land in the right place.
            let foodPoint = food.convert(CGPoint.zero, to: self)
            if food.dragTravel >= FeedServingRules.minimumDragTravel,
               let character = nearestHungryCharacter(to: foodPoint),
               character.mouthDistance(to: foodPoint) < character.snapRadius {
                if food.action(forKey: "snapPulse") == nil {
                    let grow = SKAction.scale(to: 1.16, duration: 0.14); grow.timingMode = .easeOut
                    let shrink = SKAction.scale(to: 1.08, duration: 0.18); shrink.timingMode = .easeInEaseOut
                    food.run(.repeatForever(.sequence([grow, shrink])), withKey: "snapPulse")
                    ParticleManager.softRipple(in: self,
                                               at: food.convert(.zero, to: self),
                                               color: WarmShelfPalette.butter.withAlpha(0.7))
                    HapticsManager.shared.softTap()
                }
            } else {
                if food.action(forKey: "snapPulse") != nil {
                    food.removeAction(forKey: "snapPulse")
                    let restore = SKAction.scale(to: 1.0, duration: 0.12); restore.timingMode = .easeInEaseOut
                    food.run(restore)
                }
            }
        }
    }

    private func spawnFoodTrailMote(at point: CGPoint, color: UIColor) {
        let mote = SKShapeNode(circleOfRadius: CGFloat.random(in: 2.0...3.6))
        mote.fillColor = color.withAlpha(CGFloat.random(in: 0.22...0.38))
        mote.strokeColor = .clear
        mote.position = point
        mote.zPosition = 80
        addChild(mote)
        let drift = SKAction.moveBy(x: CGFloat.random(in: -8...8), y: CGFloat.random(in: 5...16), duration: 0.42)
        let fade = SKAction.fadeOut(withDuration: 0.42)
        drift.timingMode = .easeOut
        mote.run(.sequence([.group([drift, fade]), .removeFromParent()]))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            finishFoodDrag(for: touch)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            finishFoodDrag(for: touch, cancelled: true)
        }
    }

    override func suspendToyForRest() {
        super.suspendToyForRest()
        for food in activeFoodTouches.values { food.settleAtHomeImmediately() }
        activeFoodTouches.removeAll()
    }

    private func isFoodAlreadyBeingDragged(_ food: FoodNode) -> Bool {
        activeFoodTouches.values.contains { $0 === food }
    }

    private func finishFoodDrag(for touch: UITouch, cancelled: Bool = false) {
        guard let food = activeFoodTouches.removeValue(forKey: touch) else { return }
        food.removeAction(forKey: "snapPulse")

        let foodPoint = food.convert(CGPoint.zero, to: self)
        if !cancelled, food.dragTravel >= FeedServingRules.minimumDragTravel,
           let character = nearestHungryCharacter(to: foodPoint),
           let mouthPoint = character.mouthScenePosition,
           character.mouthDistance(to: foodPoint) < character.snapRadius {
            // Every food is warmly accepted. The pictured request remains until matched.
            feed(food, to: character, mouthPoint: mouthPoint)
        } else {
            returnFoodHome(food)
        }
    }

    private func returnFoodHome(_ food: FoodNode) {
        food.endDrag()
        food.removeAllActions()
        let move = SKAction.move(to: food.homePosition, duration: 0.26)
        move.timingMode = .easeInEaseOut
        food.run(.sequence([
            .group([move, .scale(to: 1, duration: 0.20)]),
            .run { [weak self, weak food] in
                guard let self, let food, !food.isDragging else { return }
                self.runIdleFoodMotion(food, index: Int(food.zPosition))
            }
        ]), withKey: "returnHome")
    }

    private func feed(_ food: FoodNode, to character: CharacterNode, mouthPoint: CGPoint) {
        guard !food.isServing, character.mood == .hungry else { return }
        food.beginServing()
        food.zPosition = 96

        // Commit once, before animation: another finger or rotation cannot accept
        // the same bite twice or cancel an accepted bite halfway through its flight.
        let hadRequest = character.hasRemainingDesires
        let matchedWish = character.fulfillDesire(food.kind)
        _ = character.receivedFood(countsTowardRequest: matchedWish || !hadRequest)
        playFeedEffects(at: mouthPoint, for: character, food: food)
        playMouthSound(for: food.kind)
        respawnFood(kind: food.kind)

        let move = SKAction.move(to: mouthPoint, duration: 0.18)
        move.timingMode = .easeOut
        food.run(.sequence([
            .group([move, .scale(to: 0.18, duration: 0.18), .fadeOut(withDuration: 0.18)]),
            .removeFromParent()
        ]), withKey: "serve")

        if character.visitIsComplete {
            if character.wishGranted {
                character.playDesiredFoodDance()
                playWowMoment(for: character)
            }
            satisfyAndReplace(character, after: character.wishGranted ? 1.2 : 2.8)
        } else {
            if matchedWish { character.playDesiredFoodDance() }
            character.inviteAnotherBite(after: 0.92)
            run(.sequence([
                .wait(forDuration: 1.12),
                .run { [weak self] in self?.inviteFirstDesiredFood() }
            ]), withKey: "feed.moreFoodInvite")
        }
    }

    private func playMouthSound(for kind: FoodKind) {
        let isCrunchy = kind == .apple || kind == .carrot || kind == .cookie

        run(.sequence([
            .wait(forDuration: 0.10),
            .run {
                AudioManager.shared.playFeedChew(isCrunchy: isCrunchy)
            }
        ]))
    }

    private func playFeedEffects(at point: CGPoint, for character: CharacterNode, food: FoodNode) {
        ParticleManager.softBurst(in: self, at: point, color: WarmShelfPalette.petal, count: 12)
        ParticleManager.softBurst(in: self, at: point, color: food.kind.fillColor, count: 8)
        TouchFeedbackAnimator.bubblePopRing(
            in: self,
            at: point,
            radius: max(22, min(42, character.headRadius * 0.46)),
            color: WarmShelfPalette.petal
        )

        let sparkleCount = 3
        for index in 0..<sparkleCount {
            let mote = SKShapeNode(circleOfRadius: CGFloat.random(in: 2.5...4.8))
            mote.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.52)
            mote.strokeColor = .clear
            mote.position = point
            mote.zPosition = 92
            addChild(mote)

            let angle = CGFloat(index) / CGFloat(sparkleCount) * .pi * 2 + CGFloat.random(in: -0.30...0.30)
            let move = SKAction.moveBy(
                x: cos(angle) * CGFloat.random(in: 18...34),
                y: sin(angle) * CGFloat.random(in: 16...30) + 16,
                duration: 0.46
            )
            let fade = SKAction.fadeOut(withDuration: 0.46)
            let scale = SKAction.scale(to: 0.25, duration: 0.46)
            move.timingMode = .easeOut
            mote.run(.sequence([.group([move, fade, scale]), .removeFromParent()]))
        }
    }

    private func decline(_ food: FoodNode, by character: CharacterNode, from mouthPoint: CGPoint) {
        character.gentlyDeclineFood()
        food.isDragging = false
        food.removeAllActions()
        food.zPosition = 70

        let current = food.position
        let direction: CGFloat = current.x < character.position.x ? -1 : 1
        let target = CGPoint(
            x: min(max(current.x + direction * food.foodSize.width * 0.70, food.foodSize.width * 0.55), size.width - food.foodSize.width * 0.55),
            y: max(tableTopY - food.foodSize.height * 0.35, current.y - food.foodSize.height * 0.28)
        )
        let move = SKAction.move(to: target, duration: 0.22)
        let rotate = SKAction.rotate(byAngle: direction * 0.20, duration: 0.22)
        let settle = SKAction.scale(to: 1.0, duration: 0.22)
        move.timingMode = .easeOut
        rotate.timingMode = .easeOut
        ParticleManager.softRipple(in: self, at: mouthPoint, color: WarmShelfPalette.sand)
        AudioManager.shared.playFeedDecline()   // haptic fires inside playEmptyTap chain
        food.run(.sequence([
            .group([move, rotate, settle]),
            .run { [weak self, weak food] in
                guard let self, let food else { return }
                self.runIdleFoodMotion(food, index: Int(food.zPosition))
            }
        ]))
    }

    /// The signature "wow" when a friend gets their wish: a sunburst, hearts floating up,
    /// sparkles, and a warm chime. The payoff that makes feeding feel great.
    private func playWowMoment(for character: CharacterNode) {
        let origin = CGPoint(x: character.position.x, y: character.position.y + character.headRadius * 0.5)

        // Expanding sunburst ring.
        let ring = SKShapeNode(circleOfRadius: character.headRadius * 0.7)
        ring.fillColor = .clear; ring.strokeColor = WarmShelfPalette.butter.withAlpha(0.6); ring.lineWidth = 4
        ring.position = origin; ring.zPosition = 90; addChild(ring)
        let grow = SKAction.scale(to: 2.6, duration: 0.6); grow.timingMode = .easeOut
        ring.run(.sequence([.group([grow, .fadeOut(withDuration: 0.6)]), .removeFromParent()]))

        // Hearts floating up.
        for i in 0..<5 {
            let heart = SKShapeNode(path: Self.heartPath(size: CGFloat.random(in: 9...15)))
            heart.fillColor = [WarmShelfPalette.petal, WarmShelfPalette.rhubarb, WarmShelfPalette.butter][i % 3].withAlpha(0.9)
            heart.strokeColor = .clear
            heart.position = CGPoint(x: origin.x + CGFloat.random(in: -30...30), y: origin.y + CGFloat.random(in: -8...8))
            heart.zPosition = 92; heart.setScale(0.2); addChild(heart)
            let rise = SKAction.moveBy(x: CGFloat.random(in: -24...24), y: CGFloat.random(in: 90...150), duration: 1.1)
            rise.timingMode = .easeOut
            let pop = SKAction.scale(to: 1.0, duration: 0.22); pop.timingMode = .easeOut
            heart.run(.sequence([
                .wait(forDuration: Double(i) * 0.05),
                .group([pop, rise, .sequence([.wait(forDuration: 0.6), .fadeOut(withDuration: 0.5)])]),
                .removeFromParent()
            ]))
        }
        ParticleManager.celebrate(in: self, at: origin, intensity: 1.1)
        AudioManager.shared.playFeedSuccess()   // wow moment: richer sequence + celebration haptic
    }

    private static func heartPath(size r: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0, y: -r))
        p.addCurve(to: CGPoint(x: -r, y: r * 0.45), control1: CGPoint(x: -r * 0.6, y: -r * 0.5), control2: CGPoint(x: -r, y: -r * 0.1))
        p.addArc(center: CGPoint(x: -r * 0.5, y: r * 0.5), radius: r * 0.5, startAngle: .pi, endAngle: 0, clockwise: false)
        p.addArc(center: CGPoint(x: r * 0.5, y: r * 0.5), radius: r * 0.5, startAngle: .pi, endAngle: 0, clockwise: false)
        p.addCurve(to: CGPoint(x: 0, y: -r), control1: CGPoint(x: r, y: -r * 0.1), control2: CGPoint(x: r * 0.6, y: -r * 0.5))
        p.closeSubpath()
        return p
    }

    /// The friend got exactly what they wanted: a beat of joy, then they happily leave and
    /// a fresh friend arrives. This is the core one-at-a-time rhythm.
    private func satisfyAndReplace(_ character: CharacterNode, after delay: TimeInterval = 1.2) {
        run(.sequence([
            .wait(forDuration: delay),
            .run { [weak self, weak character] in
                guard let self, let character, character.parent != nil else { return }
                self.departAndReplace(character)
            }
        ]), withKey: "feed.replaceVisitor")
    }

    private func departAndReplace(_ character: CharacterNode) {
        let index = characters.firstIndex(where: { $0 === character }) ?? 0
        let slot = CharacterSlot(position: character.position, zPosition: character.zPosition)

        // A happy little hop, then bob off to one side as the new friend arrives.
        let direction: CGFloat = Bool.random() ? -1 : 1
        let exit = CGPoint(
            x: size.width / 2 + direction * (size.width * 0.5 + character.headRadius * 2.6),
            y: character.position.y
        )
        let hop = SKAction.sequence([
            .moveBy(x: 0, y: 18, duration: 0.16), .moveBy(x: 0, y: -18, duration: 0.2)
        ])
        hop.timingMode = .easeOut
        let bobA = SKAction.rotate(toAngle: -direction * 0.12, duration: 0.26, shortestUnitArc: true)
        let bobB = SKAction.rotate(toAngle: direction * 0.12, duration: 0.30, shortestUnitArc: true)
        let moveOut = SKAction.move(to: exit, duration: 1.1); moveOut.timingMode = .easeIn
        let fadeOut = SKAction.fadeAlpha(to: 0, duration: 0.5)
        character.run(.sequence([
            hop,
            .group([
                moveOut,
                .sequence([bobA, bobB, bobA]),
                .sequence([.wait(forDuration: 0.5), fadeOut])
            ]),
            .run { [weak self, weak character] in
                guard let self else { return }
                if let character {
                    self.removeCharacterShadow(for: character)
                    character.removeFromParent()
                    self.characters.removeAll { node in node === character }
                }
                let scale = self.characterBaseScale
                let newSpec = self.startingCharacterSpecs(scale: scale).first ?? self.randomCharacterSpec()
                let newSlot = self.characterSlots(for: [newSpec.radius]).first ?? slot
                let newCharacter = self.addCharacter(spec: newSpec, in: newSlot, arrivalSide: -direction)
                self.characters.insert(newCharacter, at: min(index, self.characters.count))
                self.arrangeThoughtBubbles()
                self.run(.sequence([
                    .wait(forDuration: 1.1),
                    .run { [weak self] in self?.inviteFirstDesiredFood() }
                ]), withKey: "feed.inviteNewVisitor")
            }
        ]))
    }

    private func respawnFood(kind: FoodKind) {
        let delay = SKAction.wait(forDuration: Double.random(in: 0.6...1.0))
        let appear = SKAction.run { [weak self] in
            guard let self else { return }

            let existingFoods = self.foodLayer.children.compactMap { $0 as? FoodNode }
            guard !existingFoods.contains(where: { $0.kind == kind && !$0.isServing }) else { return }
            let food = self.makeFood(kind: kind, index: existingFoods.count)
            if self.hasCounterArt {
                // The shopkeeper's stock lives under the counter: the fresh food rises
                // from below the near edge straight onto its own plate.
                food.position = CGPoint(x: food.homePosition.x, y: -food.foodSize.height * 0.5)
            } else {
                food.position = CGPoint(
                    x: self.foodSourcePosition.x + CGFloat.random(in: -28...28),
                    y: self.foodSourcePosition.y + food.foodSize.height * 0.10
                )
            }
            food.alpha = 0
            food.setScale(0.78)
            self.foodLayer.addChild(food)
            AudioManager.shared.playFoodPlop()

            let target = food.homePosition
            let move = SKAction.move(to: target, duration: Double.random(in: 0.34...0.50))
            let fade = SKAction.fadeAlpha(to: 1, duration: 0.20)
            let grow = SKAction.scale(to: 1.0, duration: 0.26)
            move.timingMode = .easeOut
            grow.timingMode = .easeOut
            food.run(.sequence([
                .group([move, fade, grow]),
                .run { [weak self, weak food] in
                    guard let self, let food else { return }
                    self.runIdleFoodMotion(food, index: Int(food.zPosition))
                }
            ]))
        }
        run(.sequence([delay, appear]), withKey: "feed.respawn.\(kind.accessibilityName)")
    }

    private func topFood(at point: CGPoint) -> FoodNode? {
        foodLayer.children
            .compactMap { $0 as? FoodNode }
            .filter { !$0.isDragging && $0.containsScenePoint(point) }
            .sorted { $0.zPosition > $1.zPosition }
            .first
    }

    private func nearestHungryCharacter(to point: CGPoint) -> CharacterNode? {
        // Only hungry friends accept food; once a friend is happy, the next clear action is
        // watching them leave and meeting the new visitor.
        characters
            .filter { $0.mood == .hungry && $0.action(forKey: "arrival") == nil }
            .sorted { $0.mouthDistance(to: point) < $1.mouthDistance(to: point) }
            .first
    }

    private func nearestCharacter(to point: CGPoint) -> CharacterNode? {
        characters
            .sorted { $0.mouthDistance(to: point) < $1.mouthDistance(to: point) }
            .first
    }

    private func dragBounds(for food: FoodNode) -> CGRect {
        let highestMouthY = characters
            .compactMap(\.mouthScenePosition)
            .map(\.y)
            .max() ?? tableTopY
        let lowerY = max(24, food.foodSize.height * 0.42)
        let upperY = min(size.height - food.foodSize.height * 0.42, highestMouthY + food.foodSize.height * 0.82)

        return CGRect(
            x: food.foodSize.width * 0.44,
            y: lowerY,
            width: size.width - food.foodSize.width * 0.88,
            height: max(food.foodSize.height, upperY - lowerY)
        )
    }

    override func accessibilityElements(in view: SKView) -> [UIAccessibilityElement] {
        var elements = super.accessibilityElements(in: view)

        elements.append(contentsOf: characters.map { character in
            makeActivatableAccessibilityElement(
                in: view,
                label: character.voiceOverDescription,
                scenePosition: character.position,
                size: CGSize(width: character.headRadius * 2.4, height: character.headRadius * 3.2),
                traits: .button
            ) { [weak character] in
                character?.playDesiredFoodDance()
                HapticsManager.shared.softTap()
            }
        })

        elements.append(contentsOf: foodLayer.children.compactMap { node -> UIAccessibilityElement? in
            guard let food = node as? FoodNode, !food.isServing, !food.isDragging, food.alpha > 0.8 else { return nil }
            return makeActivatableAccessibilityElement(
                in: view,
                label: "Offer \(food.kind.accessibilityName) to the friend",
                scenePosition: food.position,
                size: CGSize(width: food.foodSize.width * 1.5, height: food.foodSize.height * 1.5),
                traits: .button
            ) { [weak self, weak food] in
                guard let self, let food, !food.isServing, !food.isDragging,
                      let character = self.nearestHungryCharacter(to: food.convert(.zero, to: self)),
                      let mouth = character.mouthScenePosition else { return }
                self.feed(food, to: character, mouthPoint: mouth)
            }
        })

        return elements
    }
}

// Keeps physical acceptance independent of art scale and phone/tablet layout.
enum FeedServingRules {
    static let minimumDragTravel: CGFloat = 18

    static func snapRadius(headRadius: CGFloat) -> CGFloat {
        min(60, max(40, headRadius * 0.50))
    }
}
