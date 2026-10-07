import SpriteKit

enum CharacterMood {
    case hungry
    case eating
    case satisfied
    case resting
}

enum CharacterPersonality {
    case fidgety
    case calm
    case slow
}

enum CharacterAccessory: CaseIterable {
    case none
    case softCap
    case softCrown
    case flowerClip
    case roundGlasses
    case sunglasses
}

enum CharacterHairStyle: CaseIterable {
    case none
    case sprout
    case tufts
    case swoop
}

enum CharacterOutfitStyle: CaseIterable {
    case everyday
    case apron
    case overalls
    case scarf
    case buttonCoat
    case starSweater

    var accessibilityName: String {
        switch self {
        case .everyday:
            return "person"
        case .apron:
            return "person with apron"
        case .overalls:
            return "person with overalls"
        case .scarf:
            return "person with scarf"
        case .buttonCoat:
            return "person with coat"
        case .starSweater:
            return "person with star sweater"
        }
    }
}

final class CharacterNode: SKNode {
    private(set) var mood: CharacterMood = .hungry

    let personality: CharacterPersonality
    let headRadius: CGFloat
    let dislikedFood: FoodKind?
    /// REMAINING wishes, in the order they appear stacked in the bubble. Most visitors
    /// want one food; the sandwich ask (approved delight) gives ~1 in 6 a two-food stack.
    private(set) var desiredFoods: [FoodKind]
    /// The next remaining wish — legacy single-want call sites read this.
    var desiredFood: FoodKind? { desiredFoods.first }
    var hasRemainingDesires: Bool { !desiredFoods.isEmpty }
    /// True once a visitor who HAD wishes has been served every one of them.
    var wishGranted: Bool { grantedWishCount > 0 && desiredFoods.isEmpty }
    private var grantedWishCount = 0
    let hungerBites: Int

    private let baseColor: UIColor
    private let clothingColor: UIColor
    private let accessory: CharacterAccessory
    private let hairStyle: CharacterHairStyle
    private let outfitStyle: CharacterOutfitStyle
    private(set) var bitesRemaining: Int

    /// Warm Clay cast (June 12): when the authored sheets exist, every visitor is one
    /// of the four felt friends — five expression cells each, swapped by mood. The
    /// procedural balloon-head era ends where the art begins.
    // "scarf" is parked: its generation came back a realistic tall adult (small head,
    // ~3.7:1 body) instead of the round chibi friend the others are — off-model in rotation.
    // Revive it once a chibi regen lands (see Docs/ArtAsks.md).
    static let castMembers = ["sprout", "grandmother", "knithat"]
    let castMember: String?
    private var artSprite: SKSpriteNode?
    private static let castFriendlyNames: [String: String] = [
        "sprout": "the little one", "grandmother": "the grandmother",
        "knithat": "the kid in the knit hat", "scarf": "the friend in the scarf"
    ]

    private var bodyNode: SKShapeNode!
    private var headNode: SKShapeNode!
    private var openEyeLayer: SKNode!
    private var closedEyeLayer: SKNode!
    private var leftPupil: SKShapeNode!
    private var rightPupil: SKShapeNode!
    private var hungryMouth: SKShapeNode!
    private var eatingMouth: SKShapeNode!
    private var satisfiedMouth: SKShapeNode!
    private var restingMouth: SKShapeNode!
    private var cheekLeft: SKShapeNode!
    private var cheekRight: SKShapeNode!
    private var warmFlash: SKShapeNode!
    private var thoughtBubble: SKNode?
    private var wantIcons: [(kind: FoodKind, node: FoodNode)] = []
    private var friendshipCounts: [ObjectIdentifier: Int] = [:]

    private var activeMouth: SKShapeNode {
        switch mood {
        case .hungry:
            return hungryMouth
        case .eating:
            return eatingMouth
        case .satisfied:
            return satisfiedMouth
        case .resting:
            return restingMouth
        }
    }

    // Spoken aloud by VoiceOver — reflects who they are, how they feel, and what they want.
    var voiceOverDescription: String {
        let who = outfitStyle.accessibilityName
        switch mood {
        case .hungry:
            let appetite = hungerBites > 1 ? "very hungry " : "hungry "
            if !desiredFoods.isEmpty {
                let wants = desiredFoods.map(\.accessibilityName).joined(separator: " and ")
                return "\(appetite)\(who), wants \(wants)"
            }
            return "\(appetite)\(who)"
        case .eating:
            return "\(who) eating"
        case .satisfied, .resting:
            return "happy \(who)"
        }
    }

    init(
        headRadius: CGFloat,
        baseColor: UIColor,
        clothingColor: UIColor,
        personality: CharacterPersonality,
        dislikedFood: FoodKind? = nil,
        desiredFoods: [FoodKind] = [],
        hungerBites: Int = 1,
        accessory: CharacterAccessory = .none,
        hairStyle: CharacterHairStyle = .none,
        outfitStyle: CharacterOutfitStyle = .everyday,
        castMember: String? = nil
    ) {
        self.headRadius = headRadius
        self.baseColor = baseColor
        self.clothingColor = clothingColor
        self.personality = personality
        self.dislikedFood = dislikedFood
        self.desiredFoods = Array(desiredFoods.prefix(2))
        self.hungerBites = max(1, min(3, hungerBites))
        self.bitesRemaining = max(1, min(3, hungerBites))
        self.accessory = accessory
        self.hairStyle = hairStyle
        self.outfitStyle = outfitStyle
        self.castMember = castMember
        super.init()

        name = "feedCharacter"
        accessibilityLabel = castMember.flatMap { CharacterNode.castFriendlyNames[$0] }
            ?? outfitStyle.accessibilityName
        isAccessibilityElement = true
        isUserInteractionEnabled = false
        buildCharacter()
        updateExpression(animated: false)
        scheduleAmbientLife()
        schedulePersonalityTicks()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var mouthScenePosition: CGPoint? {
        guard let scene else { return nil }
        if let member = castMember, let art = artSprite {
            return art.convert(Self.artMouthPoint(member: member, spriteSize: art.size, anchorPoint: art.anchorPoint), to: scene)
        }
        return convert(CGPoint(x: 0, y: headRadius * 0.08), to: scene)
    }

    var snapRadius: CGFloat {
        FeedServingRules.snapRadius(headRadius: headRadius)
    }

    /// Where a painted friend's head and mouth sit in its runtime art, as fractions of the
    /// exported canvas. Measured on each friend's neutral frame after the six expressions
    /// were registered to it and cropped with one shared box (`Tools/Art/register_cast.py`),
    /// so every expression shares these numbers. headWidth: head (with hair/hat) width over
    /// canvas width. headCentre and mouth: distance from the canvas TOP over canvas height.
    struct CastRig {
        let headWidth: CGFloat
        let headCentre: CGFloat
        let mouth: CGFloat

        static func of(_ member: String) -> CastRig {
            switch member {
            case "grandmother": return CastRig(headWidth: 0.875, headCentre: 0.40, mouth: 0.505)
            case "knithat":     return CastRig(headWidth: 0.933, headCentre: 0.48, mouth: 0.573)
            default:            return CastRig(headWidth: 0.893, headCentre: 0.44, mouth: 0.520)   // sprout
            }
        }
    }

    // Neutral expression mouth centres, from the cast rig above.
    // SpriteKit Y runs upward; the source image fraction runs down from its top.
    static func artMouthPoint(member: String, spriteSize: CGSize, anchorPoint: CGPoint) -> CGPoint {
        let topFraction = CastRig.of(member).mouth
        return CGPoint(x: (0.5 - anchorPoint.x) * spriteSize.width,
                       y: (1 - topFraction - anchorPoint.y) * spriteSize.height)
    }

    var snapshotBaseColor: UIColor { baseColor }
    var snapshotClothingColor: UIColor { clothingColor }
    var snapshotAccessory: CharacterAccessory { accessory }
    var snapshotHairStyle: CharacterHairStyle { hairStyle }
    var snapshotOutfitStyle: CharacterOutfitStyle { outfitStyle }
    var snapshotMood: CharacterMood { mood }
    var snapshotBitesRemaining: Int { bitesRemaining }
    var needsMoreFood: Bool { bitesRemaining > 0 }
    var visitIsComplete: Bool { wishGranted || (!hasRemainingDesires && !needsMoreFood) }

    private var eatingBeatDuration: TimeInterval {
        castMember != nil && artSprite != nil ? Self.chewBeatDuration : WarmShelfMotion.pop
    }

    var nextBiteDelay: TimeInterval {
        FeedServingRules.nextBiteDelay(mood: mood, eatingDuration: eatingBeatDuration)
    }

    var completedVisitDelay: TimeInterval {
        FeedServingRules.completedVisitDelay(mood: mood, wishGranted: wishGranted,
                                            eatingDuration: eatingBeatDuration)
    }

    func mouthDistance(to scenePoint: CGPoint) -> CGFloat {
        guard let mouthScenePosition else { return .greatestFiniteMagnitude }
        return hypot(scenePoint.x - mouthScenePosition.x, scenePoint.y - mouthScenePosition.y)
    }

    @discardableResult
    func receivedFood(countsTowardRequest: Bool = true) -> Bool {
        guard mood != .eating else { return false }
        if countsTowardRequest { bitesRemaining = max(0, bitesRemaining - 1) }
        transitionTo(.eating)
        runHappyShimmy()
        return bitesRemaining == 0
    }

    func accepts(_ food: FoodKind) -> Bool {
        dislikedFood != food
    }

    func gentlyDeclineFood() {
        guard mood == .hungry else { return }

        removeAction(forKey: "decline")
        let left = SKAction.rotate(toAngle: -0.08, duration: 0.12, shortestUnitArc: true)
        let right = SKAction.rotate(toAngle: 0.08, duration: 0.16, shortestUnitArc: true)
        let center = SKAction.rotate(toAngle: 0, duration: 0.18, shortestUnitArc: true)
        [left, right, center].forEach { $0.timingMode = .easeInEaseOut }

        // Procedural mouths only exist without the authored cast (art-mode safety).
        restingMouth?.run(.fadeAlpha(to: 1, duration: 0.10))
        hungryMouth?.run(.fadeAlpha(to: 0, duration: 0.10))
        run(.sequence([
            left,
            right,
            center,
            .wait(forDuration: 0.22),
            .run { [weak self] in self?.updateExpression(animated: true) }
        ]), withKey: "decline")
    }

    func playDesiredFoodDance() {
        removeAction(forKey: "desiredFoodDance")
        thoughtBubble?.run(.sequence([
            .scale(to: 1.12, duration: 0.12),
            .scale(to: 1.0, duration: 0.28)
        ]))

        let left = SKAction.rotate(toAngle: -0.10, duration: 0.12, shortestUnitArc: true)
        let right = SKAction.rotate(toAngle: 0.10, duration: 0.12, shortestUnitArc: true)
        let center = SKAction.rotate(toAngle: 0, duration: 0.18, shortestUnitArc: true)
        let hop = SKAction.moveBy(x: 0, y: headRadius * 0.10, duration: 0.12)
        let settle = hop.reversed()
        [left, right, center, hop, settle].forEach { $0.timingMode = .easeInEaseOut }
        run(.sequence([
            .group([left, hop]),
            .group([right, settle]),
            .group([left, hop]),
            .group([center, settle])
        ]), withKey: "desiredFoodDance")
    }

    func playFullTableSway(delay: TimeInterval) {
        removeAction(forKey: "fullTableSway")
        let wait = SKAction.wait(forDuration: delay)
        let up = SKAction.moveBy(x: 0, y: headRadius * 0.07, duration: 0.16)
        let down = up.reversed()
        let turn = SKAction.rotate(byAngle: CGFloat.random(in: -0.055...0.055), duration: 0.16)
        let back = SKAction.rotate(toAngle: 0, duration: 0.20, shortestUnitArc: true)
        [up, down, turn, back].forEach { $0.timingMode = .easeInEaseOut }
        run(.sequence([wait, .group([up, turn]), .group([down, back])]), withKey: "fullTableSway")
    }

    func recordFeedingWith(_ other: CharacterNode) {
        friendshipCounts[ObjectIdentifier(other), default: 0] += 1
    }

    var hasStrongFriendship: Bool {
        friendshipCounts.values.contains { $0 >= 3 }
    }

    func playFriendshipReaction(force: Bool = false) {
        guard force || hasStrongFriendship else { return }
        guard let scene else { return }

        removeAction(forKey: "friendshipReaction")
        let scenePoint = convert(CGPoint(x: 0, y: headRadius * 0.52), to: scene)
        ParticleManager.softBurst(in: scene, at: scenePoint, color: WarmShelfPalette.petal, count: force ? 9 : 6)

        for index in 0..<(force ? 4 : 3) {
            let heart = SKShapeNode(path: makeHeartPath(size: headRadius * CGFloat.random(in: 0.16...0.22)))
            heart.fillColor = WarmShelfPalette.petal.withAlpha(CGFloat.random(in: 0.46...0.66))
            heart.strokeColor = .clear
            heart.position = scenePoint
            heart.zPosition = 96
            scene.addChild(heart)

            let direction = CGFloat(index) - CGFloat(force ? 1.5 : 1.0)
            let drift = SKAction.moveBy(
                x: direction * headRadius * CGFloat.random(in: 0.18...0.34),
                y: headRadius * CGFloat.random(in: 0.55...0.88),
                duration: Double.random(in: 0.72...0.94)
            )
            let fade = SKAction.fadeOut(withDuration: 0.78)
            let scale = SKAction.scale(to: 0.35, duration: 0.78)
            drift.timingMode = .easeOut
            heart.run(.sequence([.group([drift, fade, scale]), .removeFromParent()]))
        }

        let lift = SKAction.moveBy(x: 0, y: headRadius * 0.08, duration: 0.12)
        let settle = lift.reversed()
        let pulse = SKAction.scale(to: 1.08, duration: 0.12)
        let back = SKAction.scale(to: 1.0, duration: 0.24)
        [lift, settle, pulse, back].forEach { $0.timingMode = .easeInEaseOut }
        run(.sequence([.group([lift, pulse]), .group([settle, back])]), withKey: "friendshipReaction")
    }

    func resetForArrival() {
        removeAction(forKey: "moodCycle")
        removeAction(forKey: "moreFoodInvite")
        bitesRemaining = hungerBites
        mood = .hungry
        updateExpression(animated: false)
    }

    func restoreMood(_ restoredMood: CharacterMood) {
        // A rebuilt visitor must finish its mood cycle, including a bite interrupted
        // by rotation. Replaying the expression never commits another bite or wish.
        transitionTo(restoredMood)
    }

    func restoreWishGranted(_ restoredWishGranted: Bool) {
        grantedWishCount = restoredWishGranted ? 1 : 0
    }

    func restoreBitesRemaining(_ restoredBitesRemaining: Int) {
        bitesRemaining = max(0, min(hungerBites, restoredBitesRemaining))
    }

    func inviteAnotherBite(after delay: TimeInterval) {
        removeAction(forKey: "moreFoodInvite")
        run(.sequence([
            .wait(forDuration: delay),
            .run { [weak self] in
                guard let self, self.parent != nil, self.needsMoreFood || self.hasRemainingDesires else { return }
                self.transitionTo(.hungry)
                self.thoughtBubble?.run(.sequence([
                    .scale(to: 1.14, duration: 0.12),
                    .scale(to: 1.0, duration: 0.36)
                ]))
            }
        ]), withKey: "moreFoodInvite")
    }

    private func buildCharacter() {
        // Authored cast first: one felt friend, five expression cells, no procedural face.
        if let member = castMember, let tex = ToyArt.texture("feed-cast-\(member)-1") {
            buildArtCharacter(member: member, neutral: tex)
            return
        }
        // A chunkier, grounded body so the friend reads as a little body — not a big head floating
        // on a narrow torso. Widened toward the head's width and a touch taller; bottom stays put so
        // feet and clothing keep their alignment.
        let bodySize = CGSize(width: headRadius * 1.56, height: headRadius * 1.2)
        bodyNode = SKShapeNode(
            rect: CGRect(
                x: -bodySize.width / 2,
                y: -headRadius * 1.28,
                width: bodySize.width,
                height: bodySize.height
            ),
            cornerRadius: headRadius * 0.32
        )
        bodyNode.fillColor = clothingColor.withAlpha(0.82)
        bodyNode.strokeColor = WarmShelfPalette.clayInk.withAlpha(0.028)
        bodyNode.lineWidth = max(1, headRadius * 0.018)
        bodyNode.zPosition = 0
        addChild(bodyNode)

        addClothingDetails(bodySize: bodySize)
        addClothingTexture(bodySize: bodySize)

        headNode = SKShapeNode(circleOfRadius: headRadius)
        headNode.fillColor = baseColor
        headNode.strokeColor = WarmShelfPalette.clayInk.withAlpha(0.025)
        headNode.lineWidth = max(1, headRadius * 0.018)
        headNode.zPosition = 3
        ProceduralTexture.applyClayFill(to: headNode, base: baseColor, size: CGSize(width: headRadius * 2, height: headRadius * 2))
        addChild(headNode)
        addSkinTexture()

        warmFlash = SKShapeNode(circleOfRadius: headRadius * 0.98)
        warmFlash.fillColor = WarmShelfPalette.butter.withAlpha(0)
        warmFlash.strokeColor = .clear
        warmFlash.zPosition = 4
        addChild(warmFlash)

        addHair()
        // (procedural body continues below)
        buildProceduralRemainder(bodySize: bodySize)
    }

    /// The authored friend. The sprite is sized so the painted head is exactly
    /// 2 × headRadius wide and anchored on the painted head centre (see CastRig), so
    /// headRadius keeps its meaning and the want bubble, mouth point, warm flash and every
    /// hop land on the face.
    private func buildArtCharacter(member: String, neutral: SKTexture) {
        let rig = CastRig.of(member)
        let ts = neutral.size()
        let w = headRadius * 2.0 / rig.headWidth
        let h = w * ts.height / max(1, ts.width)
        let art = SKSpriteNode(texture: neutral)
        art.size = CGSize(width: w, height: h)
        art.anchorPoint = CGPoint(x: 0.5, y: 1 - rig.headCentre)
        art.zPosition = 3
        addChild(art)
        artSprite = art

        warmFlash = SKShapeNode(circleOfRadius: headRadius * 0.98)
        warmFlash.fillColor = WarmShelfPalette.butter.withAlpha(0)
        warmFlash.strokeColor = .clear
        warmFlash.zPosition = 4
        addChild(warmFlash)

        addThoughtBubbleIfNeeded()
    }

    /// For an authored friend: how far above a counter's far edge this node must stand so
    /// the counter hides exactly the bottom `hiddenFraction` of the painted figure (its
    /// round base and feet). nil for the procedural cast, which keeps its own staging.
    func standHeight(hidingBottom hiddenFraction: CGFloat) -> CGFloat? {
        guard let art = artSprite else { return nil }
        return (art.anchorPoint.y - hiddenFraction) * art.size.height
    }

    /// How far the painted figure reaches above this node's origin (nil for the procedural cast).
    var paintedHeadroom: CGFloat? {
        guard let art = artSprite else { return nil }
        return (1 - art.anchorPoint.y) * art.size.height
    }

    private func buildProceduralRemainder(bodySize: CGSize) {
        addAccessory()
        addThoughtBubbleIfNeeded()

        openEyeLayer = SKNode()
        openEyeLayer.zPosition = 6
        addChild(openEyeLayer)

        closedEyeLayer = SKNode()
        closedEyeLayer.zPosition = 7
        addChild(closedEyeLayer)

        leftPupil = makeEye(x: -headRadius * 0.30)
        rightPupil = makeEye(x: headRadius * 0.30)
        openEyeLayer.addChild(leftPupil)
        openEyeLayer.addChild(rightPupil)

        closedEyeLayer.addChild(makeEyeArc(centerX: -headRadius * 0.30, y: headRadius * 0.25, width: headRadius * 0.25))
        closedEyeLayer.addChild(makeEyeArc(centerX: headRadius * 0.30, y: headRadius * 0.25, width: headRadius * 0.25))

        hungryMouth = makeOpenMouth(size: CGSize(width: headRadius * 0.26, height: headRadius * 0.18), y: -headRadius * 0.08)
        eatingMouth = makeOpenMouth(size: CGSize(width: headRadius * 0.40, height: headRadius * 0.28), y: -headRadius * 0.10)
        satisfiedMouth = makeSmile(width: headRadius * 0.58, y: -headRadius * 0.16)
        restingMouth = makeRestingMouth(width: headRadius * 0.34)

        [hungryMouth, eatingMouth, satisfiedMouth, restingMouth].forEach { mouth in
            guard let mouth else { return }
            mouth.zPosition = 8
            addChild(mouth)
        }

        cheekLeft = makeCheek(x: -headRadius * 0.48)
        cheekRight = makeCheek(x: headRadius * 0.48)
        addChild(cheekLeft)
        addChild(cheekRight)
        addFaceDetails()

        let shirtHighlight = SKShapeNode(
            rect: CGRect(
                x: -bodySize.width * 0.26,
                y: -headRadius * 0.86,
                width: bodySize.width * 0.52,
                height: max(3, headRadius * 0.05)
            ),
            cornerRadius: headRadius * 0.03
        )
        shirtHighlight.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.12)
        shirtHighlight.strokeColor = .clear
        shirtHighlight.zPosition = 2
        addChild(shirtHighlight)
    }

    private func addSkinTexture() {
        ProceduralTexture.addCircularSpeckles(
            to: self,
            radius: headRadius * 0.82,
            count: Int(max(8, min(18, headRadius / 4.6))),
            lightColor: WarmShelfPalette.paperHighlight,
            darkColor: WarmShelfPalette.cocoa,
            alpha: 0.018...0.056,
            dotRadius: 0.55...1.45,
            zPosition: 4.2
        )
    }

    /// Lets the scene fan out thought bubbles so neighbours never overlap, with the scene
    /// supplying a clamped local Y so bubbles never clip off the top (esp. in landscape).
    func arrangeThoughtBubble(at localPosition: CGPoint) {
        thoughtBubble?.position = localPosition
    }
    var thoughtBubbleHalfHeight: CGFloat { headRadius * 0.78 }
    var defaultThoughtBubbleLocalY: CGFloat { headRadius * 1.7 }

    private func addThoughtBubbleIfNeeded() {
        guard !desiredFoods.isEmpty else { return }
        let isSandwich = desiredFoods.count > 1

        let root = SKNode()
        root.position = CGPoint(x: 0, y: headRadius * 1.7)
        root.zPosition = 18
        root.alpha = 1.0
        root.setScale(1.12)
        addChild(root)
        thoughtBubble = root

        // A two-food sandwich ask needs a taller cloud so the stack reads at a glance.
        let bubbleSize = CGSize(
            width: headRadius * 1.02,
            height: headRadius * (isSandwich ? 1.06 : 0.78)
        )
        let cloud = SKShapeNode(ellipseOf: bubbleSize)
        cloud.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.72)
        cloud.strokeColor = WarmShelfPalette.sand.withAlpha(0.32)
        cloud.lineWidth = max(1.2, headRadius * 0.018)
        cloud.zPosition = 0
        root.addChild(cloud)

        let smallDot = SKShapeNode(circleOfRadius: headRadius * 0.11)
        smallDot.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.60)
        smallDot.strokeColor = WarmShelfPalette.sand.withAlpha(0.22)
        smallDot.lineWidth = max(0.8, headRadius * 0.012)
        smallDot.position = CGPoint(x: -headRadius * 0.46, y: -headRadius * 0.54)
        smallDot.zPosition = -1
        root.addChild(smallDot)

        let tinyDot = SKShapeNode(circleOfRadius: headRadius * 0.065)
        tinyDot.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.48)
        tinyDot.strokeColor = .clear
        tinyDot.position = CGPoint(x: -headRadius * 0.64, y: -headRadius * 0.74)
        tinyDot.zPosition = -2
        root.addChild(tinyDot)

        // One want sits centered; a sandwich ask stacks both foods — the picture IS the plan.
        let iconScale = max(0.42, min(0.62, headRadius / 110)) * (isSandwich ? 0.74 : 1.0)
        wantIcons.removeAll()
        for (index, kind) in desiredFoods.enumerated() {
            let foodIcon = FoodNode(kind: kind, scale: iconScale)
            foodIcon.physicsBody = nil
            let y: CGFloat = isSandwich
                ? (index == 0 ? headRadius * 0.18 : -headRadius * 0.22)
                : -headRadius * 0.02
            foodIcon.position = CGPoint(x: 0, y: y)
            foodIcon.zRotation = index == 0 ? -0.08 : 0.07
            foodIcon.zPosition = 2
            root.addChild(foodIcon)
            wantIcons.append((kind, foodIcon))
        }

        AmbientAnimator.idleDrift(
            node: root,
            x: headRadius * 0.028,
            y: headRadius * 0.040,
            duration: 7.2,
            delay: 0.4
        )
        AmbientAnimator.breathe(node: root, scale: 1.026, duration: 6.4)
    }

    /// Consumes a wish: the matching mini-food pops out of the bubble; a remaining
    /// sandwich-half recentres; the cloud itself drifts away once every wish is served.
    /// Returns whether the served food matched an outstanding wish.
    @discardableResult
    func fulfillDesire(_ kind: FoodKind) -> Bool {
        guard let index = desiredFoods.firstIndex(of: kind) else { return false }
        desiredFoods.remove(at: index)
        grantedWishCount += 1

        if let iconIndex = wantIcons.firstIndex(where: { $0.kind == kind }) {
            let icon = wantIcons.remove(at: iconIndex).node
            let pop = SKAction.group([
                .scale(to: 1.3, duration: 0.14),
                .fadeOut(withDuration: 0.18)
            ])
            pop.timingMode = .easeOut
            icon.run(.sequence([pop, .removeFromParent()]))
        }

        if desiredFoods.isEmpty {
            // Remove (not just hide) so mood changes can't resurrect an empty cloud.
            if let bubble = thoughtBubble {
                thoughtBubble = nil
                let drift = SKAction.group([
                    .fadeOut(withDuration: 0.42),
                    .scale(to: 0.8, duration: 0.42),
                    .moveBy(x: 0, y: headRadius * 0.18, duration: 0.42)
                ])
                drift.timingMode = .easeIn
                bubble.run(.sequence([.wait(forDuration: 0.16), drift, .removeFromParent()]))
            }
        } else if let survivor = wantIcons.first?.node {
            let recentre = SKAction.group([
                .move(to: CGPoint(x: 0, y: -headRadius * 0.02), duration: 0.32),
                .scale(to: 1.18, duration: 0.32)
            ])
            recentre.timingMode = .easeInEaseOut
            survivor.run(recentre)
        }
        return true
    }

    private func addClothingDetails(bodySize: CGSize) {
        let collarLeft = SKShapeNode(
            rect: CGRect(
                x: -headRadius * 0.28,
                y: -headRadius * 0.80,
                width: headRadius * 0.24,
                height: headRadius * 0.09
            ),
            cornerRadius: headRadius * 0.04
        )
        collarLeft.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.11)
        collarLeft.strokeColor = .clear
        collarLeft.zRotation = -0.10
        collarLeft.zPosition = 2
        addChild(collarLeft)

        let pocket = SKShapeNode(
            rect: CGRect(
                x: bodySize.width * 0.12,
                y: -headRadius * 1.00,
                width: bodySize.width * 0.18,
                height: bodySize.height * 0.12
            ),
            cornerRadius: headRadius * 0.04
        )
        pocket.fillColor = WarmShelfPalette.clayInk.withAlpha(0.028)
        pocket.strokeColor = .clear
        pocket.zPosition = 2
        addChild(pocket)

        switch outfitStyle {
        case .everyday:
            addTinyClothingButton(x: -bodySize.width * 0.14, y: -headRadius * 0.98)
        case .apron:
            let bib = SKShapeNode(
                rect: CGRect(
                    x: -bodySize.width * 0.28,
                    y: -headRadius * 1.18,
                    width: bodySize.width * 0.56,
                    height: bodySize.height * 0.58
                ),
                cornerRadius: headRadius * 0.09
            )
            bib.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.20)
            bib.strokeColor = WarmShelfPalette.sand.withAlpha(0.16)
            bib.lineWidth = max(0.8, headRadius * 0.012)
            bib.zPosition = 2.2
            addChild(bib)

            let apronPocket = SKShapeNode(
                rect: CGRect(
                    x: -bodySize.width * 0.14,
                    y: -headRadius * 1.02,
                    width: bodySize.width * 0.28,
                    height: bodySize.height * 0.13
                ),
                cornerRadius: headRadius * 0.04
            )
            apronPocket.fillColor = WarmShelfPalette.warmCream.withAlpha(0.24)
            apronPocket.strokeColor = .clear
            apronPocket.zPosition = 2.5
            addChild(apronPocket)
        case .overalls:
            for x in [-bodySize.width * 0.20, bodySize.width * 0.20] {
                let strap = SKShapeNode(
                    rect: CGRect(
                        x: x - bodySize.width * 0.045,
                        y: -headRadius * 1.18,
                        width: bodySize.width * 0.09,
                        height: bodySize.height * 0.62
                    ),
                    cornerRadius: headRadius * 0.025
                )
                strap.fillColor = WarmShelfPalette.clayInk.withAlpha(0.08)
                strap.strokeColor = .clear
                strap.zPosition = 2.3
                addChild(strap)
                addTinyClothingButton(x: x, y: -headRadius * 0.72)
            }

            let pouch = SKShapeNode(
                rect: CGRect(
                    x: -bodySize.width * 0.18,
                    y: -headRadius * 1.08,
                    width: bodySize.width * 0.36,
                    height: bodySize.height * 0.18
                ),
                cornerRadius: headRadius * 0.055
            )
            pouch.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.12)
            pouch.strokeColor = .clear
            pouch.zPosition = 2.5
            addChild(pouch)
        case .scarf:
            let band = SKShapeNode(
                rect: CGRect(
                    x: -bodySize.width * 0.42,
                    y: -headRadius * 0.62,
                    width: bodySize.width * 0.84,
                    height: max(5, headRadius * 0.16)
                ),
                cornerRadius: headRadius * 0.08
            )
            band.fillColor = WarmShelfPalette.petal.withAlpha(0.45)
            band.strokeColor = .clear
            band.zPosition = 3.1
            addChild(band)

            let knot = SKShapeNode(circleOfRadius: headRadius * 0.095)
            knot.fillColor = WarmShelfPalette.petal.withAlpha(0.58)
            knot.strokeColor = .clear
            knot.position = CGPoint(x: bodySize.width * 0.20, y: -headRadius * 0.55)
            knot.zPosition = 3.2
            addChild(knot)

            let tail = SKShapeNode(
                rect: CGRect(
                    x: bodySize.width * 0.14,
                    y: -headRadius * 0.92,
                    width: bodySize.width * 0.16,
                    height: bodySize.height * 0.32
                ),
                cornerRadius: headRadius * 0.045
            )
            tail.fillColor = WarmShelfPalette.petal.withAlpha(0.42)
            tail.strokeColor = .clear
            tail.zRotation = -0.10
            tail.zPosition = 3.0
            addChild(tail)
        case .buttonCoat:
            let placket = SKShapeNode(
                rect: CGRect(
                    x: -bodySize.width * 0.045,
                    y: -headRadius * 1.18,
                    width: bodySize.width * 0.09,
                    height: bodySize.height * 0.62
                ),
                cornerRadius: headRadius * 0.025
            )
            placket.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.14)
            placket.strokeColor = .clear
            placket.zPosition = 2.3
            addChild(placket)

            for offset in [-0.97, -0.85, -0.73] {
                addTinyClothingButton(x: 0, y: headRadius * CGFloat(offset))
            }
        case .starSweater:
            let star = SKShapeNode(path: makeStarPath(radius: headRadius * 0.18))
            star.fillColor = WarmShelfPalette.butter.withAlpha(0.48)
            star.strokeColor = WarmShelfPalette.paperHighlight.withAlpha(0.18)
            star.lineWidth = max(0.7, headRadius * 0.010)
            star.position = CGPoint(x: -bodySize.width * 0.02, y: -headRadius * 0.92)
            star.zPosition = 2.6
            addChild(star)
        }
    }

    private func addTinyClothingButton(x: CGFloat, y: CGFloat) {
        let button = SKShapeNode(circleOfRadius: max(2.0, headRadius * 0.040))
        button.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.38)
        button.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.08)
        button.lineWidth = max(0.5, headRadius * 0.006)
        button.position = CGPoint(x: x, y: y)
        button.zPosition = 2.8
        addChild(button)
    }

    private func addFaceDetails() {
        let nose = SKShapeNode(ellipseOf: CGSize(width: headRadius * 0.16, height: headRadius * 0.11))
        nose.fillColor = WarmShelfPalette.cocoa.withAlpha(0.14)
        nose.strokeColor = .clear
        nose.position = CGPoint(x: 0, y: headRadius * 0.08)
        nose.zPosition = 7.6
        addChild(nose)

        let shouldAddFreckles = hairStyle == .sprout || outfitStyle == .overalls || accessory == .softCrown
        guard shouldAddFreckles else { return }

        for side in [-1, 1] {
            for index in 0..<3 {
                let freckle = SKShapeNode(circleOfRadius: max(1.2, headRadius * 0.018))
                freckle.fillColor = WarmShelfPalette.cocoa.withAlpha(0.13)
                freckle.strokeColor = .clear
                freckle.position = CGPoint(
                    x: CGFloat(side) * headRadius * (0.34 + CGFloat(index) * 0.055),
                    y: -headRadius * (0.02 + CGFloat(index % 2) * 0.035)
                )
                freckle.zPosition = 7.4
                addChild(freckle)
            }
        }
    }

    private func addClothingTexture(bodySize: CGSize) {
        let rect = CGRect(
            x: -bodySize.width * 0.42,
            y: -headRadius * 1.18,
            width: bodySize.width * 0.84,
            height: bodySize.height * 0.72
        )
        ProceduralTexture.addSoftSpeckles(
            to: self,
            in: rect,
            count: 8,
            lightColor: WarmShelfPalette.paperHighlight,
            darkColor: WarmShelfPalette.clayInk,
            alpha: 0.020...0.070,
            radius: 0.55...1.45,
            zPosition: 1.6
        )
        ProceduralTexture.addSoftGrainLines(
            to: self,
            in: rect,
            count: 3,
            color: WarmShelfPalette.paperHighlight,
            alpha: 0.025...0.060,
            zPosition: 1.7
        )
    }

    private func addHair() {
        guard hairStyle != .none else { return }

        let hairColor = WarmShelfPalette.cocoa.withAlpha(0.45)
        switch hairStyle {
        case .none:
            return
        case .sprout:
            for offset in [-0.12, 0.04] {
                let sprout = makeHairStroke(
                    from: CGPoint(x: headRadius * CGFloat(offset), y: headRadius * 0.92),
                    to: CGPoint(x: headRadius * CGFloat(offset + 0.14), y: headRadius * 1.22),
                    control: CGPoint(x: headRadius * CGFloat(offset + 0.02), y: headRadius * 1.16),
                    color: hairColor
                )
                addChild(sprout)
            }
        case .tufts:
            for index in 0..<3 {
                let x = (CGFloat(index) - 1) * headRadius * 0.15
                let tuft = makeHairStroke(
                    from: CGPoint(x: x, y: headRadius * 0.95),
                    to: CGPoint(x: x + CGFloat.random(in: -4...4), y: headRadius * 1.15),
                    control: CGPoint(x: x + CGFloat.random(in: -5...5), y: headRadius * 1.08),
                    color: hairColor
                )
                addChild(tuft)
            }
        case .swoop:
            let swoop = makeHairStroke(
                from: CGPoint(x: -headRadius * 0.32, y: headRadius * 0.78),
                to: CGPoint(x: headRadius * 0.24, y: headRadius * 0.92),
                control: CGPoint(x: -headRadius * 0.12, y: headRadius * 1.12),
                color: hairColor
            )
            swoop.lineWidth = max(4, headRadius * 0.07)
            addChild(swoop)
        }
    }

    private func addAccessory() {
        switch accessory {
        case .none:
            return
        case .softCap:
            let cap = SKShapeNode(ellipseOf: CGSize(width: headRadius * 1.28, height: headRadius * 0.42))
            cap.fillColor = clothingColor.withAlpha(0.90)
            cap.strokeColor = WarmShelfPalette.clayInk.withAlpha(0.035)
            cap.lineWidth = max(1, headRadius * 0.014)
            cap.position = CGPoint(x: 0, y: headRadius * 0.82)
            cap.zPosition = 9
            addChild(cap)

            let brim = SKShapeNode(ellipseOf: CGSize(width: headRadius * 0.72, height: headRadius * 0.20))
            brim.fillColor = clothingColor.withAlpha(0.76)
            brim.strokeColor = .clear
            brim.position = CGPoint(x: headRadius * 0.30, y: headRadius * 0.71)
            brim.zRotation = -0.12
            brim.zPosition = 10
            addChild(brim)
        case .softCrown:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -headRadius * 0.44, y: headRadius * 0.86))
            path.addLine(to: CGPoint(x: -headRadius * 0.30, y: headRadius * 1.12))
            path.addLine(to: CGPoint(x: -headRadius * 0.10, y: headRadius * 0.94))
            path.addLine(to: CGPoint(x: headRadius * 0.08, y: headRadius * 1.17))
            path.addLine(to: CGPoint(x: headRadius * 0.28, y: headRadius * 0.94))
            path.addLine(to: CGPoint(x: headRadius * 0.46, y: headRadius * 1.10))
            path.addLine(to: CGPoint(x: headRadius * 0.42, y: headRadius * 0.80))
            path.closeSubpath()

            let crown = SKShapeNode(path: path)
            crown.fillColor = WarmShelfPalette.butter.withAlpha(0.72)
            crown.strokeColor = WarmShelfPalette.sand.withAlpha(0.22)
            crown.lineWidth = max(1, headRadius * 0.012)
            crown.zPosition = 10
            addChild(crown)
        case .flowerClip:
            let root = SKNode()
            root.position = CGPoint(x: -headRadius * 0.52, y: headRadius * 0.70)
            root.zPosition = 11
            addChild(root)

            for index in 0..<5 {
                let petal = SKShapeNode(ellipseOf: CGSize(width: headRadius * 0.14, height: headRadius * 0.22))
                petal.fillColor = WarmShelfPalette.petal.withAlpha(0.62)
                petal.strokeColor = .clear
                petal.zRotation = CGFloat(index) / 5 * .pi * 2
                petal.position = CGPoint(
                    x: cos(petal.zRotation) * headRadius * 0.075,
                    y: sin(petal.zRotation) * headRadius * 0.075
                )
                root.addChild(petal)
            }
            let center = SKShapeNode(circleOfRadius: headRadius * 0.055)
            center.fillColor = WarmShelfPalette.butter.withAlpha(0.72)
            center.strokeColor = .clear
            root.addChild(center)
        case .roundGlasses:
            addGlasses(fill: .clear, strokeAlpha: 0.38, lensAlpha: 0)
        case .sunglasses:
            addGlasses(fill: WarmShelfPalette.clayInk.withAlpha(0.50), strokeAlpha: 0.24, lensAlpha: 0.40)
        }
    }

    private func addGlasses(fill: UIColor, strokeAlpha: CGFloat, lensAlpha: CGFloat) {
        let leftLens = SKShapeNode(circleOfRadius: headRadius * 0.20)
        let rightLens = SKShapeNode(circleOfRadius: headRadius * 0.20)
        for (index, lens) in [leftLens, rightLens].enumerated() {
            lens.fillColor = lensAlpha == 0 ? fill : fill.withAlpha(lensAlpha)
            lens.strokeColor = WarmShelfPalette.clayInk.withAlpha(strokeAlpha)
            lens.lineWidth = max(1.6, headRadius * 0.024)
            lens.position = CGPoint(x: (index == 0 ? -1 : 1) * headRadius * 0.30, y: headRadius * 0.28)
            lens.zPosition = 10
            addChild(lens)
        }

        let bridge = SKShapeNode(
            rect: CGRect(
                x: -headRadius * 0.12,
                y: headRadius * 0.25,
                width: headRadius * 0.24,
                height: max(2, headRadius * 0.026)
            ),
            cornerRadius: headRadius * 0.012
        )
        bridge.fillColor = WarmShelfPalette.clayInk.withAlpha(strokeAlpha)
        bridge.strokeColor = .clear
        bridge.zPosition = 10
        addChild(bridge)
    }

    private func makeHairStroke(from start: CGPoint, to end: CGPoint, control: CGPoint, color: UIColor) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        let stroke = SKShapeNode(path: path)
        stroke.fillColor = .clear
        stroke.strokeColor = color
        stroke.lineWidth = max(2.4, headRadius * 0.04)
        stroke.lineCap = .round
        stroke.zPosition = 10
        return stroke
    }

    private func makeHeartPath(size: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: -size * 0.32))
        path.addCurve(
            to: CGPoint(x: -size * 0.50, y: size * 0.12),
            control1: CGPoint(x: -size * 0.42, y: -size * 0.02),
            control2: CGPoint(x: -size * 0.58, y: size * 0.08)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: size * 0.48),
            control1: CGPoint(x: -size * 0.44, y: size * 0.42),
            control2: CGPoint(x: -size * 0.12, y: size * 0.48)
        )
        path.addCurve(
            to: CGPoint(x: size * 0.50, y: size * 0.12),
            control1: CGPoint(x: size * 0.12, y: size * 0.48),
            control2: CGPoint(x: size * 0.44, y: size * 0.42)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: -size * 0.32),
            control1: CGPoint(x: size * 0.58, y: size * 0.08),
            control2: CGPoint(x: size * 0.42, y: -size * 0.02)
        )
        path.closeSubpath()
        return path
    }

    private func makeStarPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for index in 0..<10 {
            let angle = CGFloat(index) / 10 * .pi * 2 - .pi / 2
            let pointRadius = index.isMultiple(of: 2) ? radius : radius * 0.45
            let point = CGPoint(x: cos(angle) * pointRadius, y: sin(angle) * pointRadius)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    private func makeEye(x: CGFloat) -> SKShapeNode {
        // Wren-family eye: a soft white with a warm iris, dark pupil, and two glints —
        // big and full of life, so every friend reads as part of the same clay family.
        let r = headRadius
        let white = SKShapeNode(ellipseOf: CGSize(width: r * 0.30, height: r * 0.34))
        white.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.97)
        white.strokeColor = WarmShelfPalette.clayInk.withAlpha(0.10)
        white.lineWidth = max(0.8, r * 0.012)
        white.position = CGPoint(x: x, y: r * 0.34)

        let iris = SKShapeNode(circleOfRadius: r * 0.11)
        iris.fillColor = WarmShelfPalette.cocoa.withAlpha(0.92)
        iris.strokeColor = WarmShelfPalette.clayInk.withAlpha(0.10)
        iris.lineWidth = 0.6
        iris.position = CGPoint(x: 0, y: -r * 0.012)
        white.addChild(iris)

        let pupil = SKShapeNode(circleOfRadius: r * 0.058)
        pupil.fillColor = WarmShelfPalette.clayInk.withAlpha(0.94)
        pupil.strokeColor = .clear
        pupil.position = iris.position
        white.addChild(pupil)

        let bigGlint = SKShapeNode(circleOfRadius: r * 0.032)
        bigGlint.fillColor = .white.withAlpha(0.95)
        bigGlint.strokeColor = .clear
        bigGlint.position = CGPoint(x: -r * 0.05, y: r * 0.058)
        white.addChild(bigGlint)

        let tinyGlint = SKShapeNode(circleOfRadius: r * 0.014)
        tinyGlint.fillColor = .white.withAlpha(0.68)
        tinyGlint.strokeColor = .clear
        tinyGlint.position = CGPoint(x: r * 0.042, y: -r * 0.03)
        white.addChild(tinyGlint)

        return white
    }

    private func makeEyeArc(centerX: CGFloat, y: CGFloat, width: CGFloat) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: centerX - width * 0.5, y: y))
        path.addQuadCurve(
            to: CGPoint(x: centerX + width * 0.5, y: y),
            control: CGPoint(x: centerX, y: y + width * 0.44)
        )
        let arc = SKShapeNode(path: path)
        arc.fillColor = .clear
        arc.strokeColor = WarmShelfPalette.clayInk.withAlpha(0.78)
        arc.lineWidth = max(2.0, headRadius * 0.044)
        arc.lineCap = .round
        return arc
    }

    private func makeOpenMouth(size: CGSize, y: CGFloat) -> SKShapeNode {
        let mouth = SKShapeNode(ellipseOf: size)
        mouth.fillColor = WarmShelfPalette.clayInk.withAlpha(0.72)
        mouth.strokeColor = .clear
        mouth.position = CGPoint(x: 0, y: y)
        return mouth
    }

    private func makeSmile(width: CGFloat, y: CGFloat) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -width * 0.5, y: y))
        path.addQuadCurve(
            to: CGPoint(x: width * 0.5, y: y),
            control: CGPoint(x: 0, y: y - width * 0.28)
        )
        let smile = SKShapeNode(path: path)
        smile.fillColor = .clear
        smile.strokeColor = WarmShelfPalette.clayInk.withAlpha(0.68)
        smile.lineWidth = max(2.2, headRadius * 0.052)
        smile.lineCap = .round
        return smile
    }

    private func makeRestingMouth(width: CGFloat) -> SKShapeNode {
        // A gentle content curve (not a flat line) — calm but quietly happy, like Wren.
        let y = -headRadius * 0.14
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -width * 0.5, y: y))
        path.addQuadCurve(
            to: CGPoint(x: width * 0.5, y: y),
            control: CGPoint(x: 0, y: y - headRadius * 0.085)
        )
        let mouth = SKShapeNode(path: path)
        mouth.fillColor = .clear
        mouth.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.55)
        mouth.lineWidth = max(2.0, headRadius * 0.042)
        mouth.lineCap = .round
        return mouth
    }

    private func makeCheek(x: CGFloat) -> SKShapeNode {
        // Rosy bloom cheeks — clearly warm even on deeper skin tones.
        let cheek = SKShapeNode(circleOfRadius: headRadius * 0.25)
        cheek.fillColor = WarmShelfPalette.petal.withAlpha(0.58)
        cheek.strokeColor = .clear
        cheek.position = CGPoint(x: x, y: -headRadius * 0.05)
        cheek.zPosition = 5
        return cheek
    }

    static let expressionBeatKey = "expressionBeat"
    /// Surprise as the food arrives, then three chews: cheeks puffed (cell 6) on each
    /// squash, closed-mouth neutral between them. Keep in step with chewBeat(member:).
    static let chewBeatDuration: TimeInterval = 0.18 + 3 * (0.15 + 0.1)

    private func chewBeat(member: String) -> SKAction? {
        guard let art = artSprite,
              let surprise = ToyArt.texture("feed-cast-\(member)-5"),
              let chew = ToyArt.texture("feed-cast-\(member)-6") ?? ToyArt.texture("feed-cast-\(member)-3"),
              let rest = ToyArt.texture("feed-cast-\(member)-1") else { return nil }
        let reduce = AmbientAnimator.reduceMotion
        func show(_ tex: SKTexture) -> SKAction { .run { [weak art] in art?.texture = tex } }
        var steps: [SKAction] = [show(surprise), .wait(forDuration: 0.18)]
        for _ in 0..<3 {
            // The squash is about the head-centre anchor, so the cheeks visibly fill.
            let down = SKAction.group([.scaleX(to: reduce ? 1 : 1.03, duration: 0.15),
                                       .scaleY(to: reduce ? 1 : 0.96, duration: 0.15)])
            let up = SKAction.group([.scaleX(to: 1, duration: 0.1), .scaleY(to: 1, duration: 0.1)])
            steps += [show(chew), down, show(rest), up]
        }
        steps.append(show(chew))
        return .sequence(steps)
    }

    private func transitionTo(_ newMood: CharacterMood) {
        removeAction(forKey: "moodCycle")
        mood = newMood
        updateExpression(animated: true)

        switch newMood {
        case .eating:
            // The painted cast gets a real chew beat (surprise, three chews) before the
            // happy face; the procedural cast keeps its quick pop.
            run(.sequence([
                .wait(forDuration: eatingBeatDuration),
                .run { [weak self] in self?.transitionTo(.satisfied) }
            ]), withKey: "moodCycle")
        case .satisfied:
            run(.sequence([
                .wait(forDuration: Double.random(in: 1.8...2.5)),
                .run { [weak self] in self?.transitionTo(.resting) }
            ]), withKey: "moodCycle")
        case .resting:
            run(.sequence([
                .wait(forDuration: Double.random(in: 3.5...6.2)),
                .run { [weak self] in self?.transitionTo(.hungry) }
            ]), withKey: "moodCycle")
        case .hungry:
            break
        }
    }

    private func updateExpression(animated: Bool) {
        // Authored cast: moods are expression cells (1 neutral, 2 happy, 3 laughing,
        // 4 sleepy, 5 surprised). A bite lands as a flash of surprise, then the chew.
        if let member = castMember, let art = artSprite {
            // Expression cells: 1 neutral, 2 happy, 3 laughing, 4 sleepy, 5 surprised,
            // 6 chewing. Every timed swap runs under one key and is cancelled by the next
            // mood, so a late swap can never leave a friend on the wrong face (the old
            // surprise flash outlived the 0.16s eating beat and could land the laugh
            // frame on top of the happy one).
            art.removeAction(forKey: CharacterNode.expressionBeatKey)
            art.setScale(1)
            func cellTexture(_ cell: Int) -> SKTexture? { ToyArt.texture("feed-cast-\(member)-\(cell)") }
            switch mood {
            case .hungry:
                if let tex = cellTexture(1) { art.texture = tex }
            case .resting:
                if let tex = cellTexture(4) { art.texture = tex }
            case .eating:
                if animated, let beat = chewBeat(member: member) {
                    art.run(beat, withKey: CharacterNode.expressionBeatKey)
                } else if let tex = cellTexture(6) ?? cellTexture(3) {
                    art.texture = tex
                }
            case .satisfied:
                // A granted wish laughs first, then settles into the happy face.
                if animated, wishGranted, let laugh = cellTexture(3), let happy = cellTexture(2) {
                    art.texture = laugh
                    art.run(.sequence([.wait(forDuration: FeedServingRules.wishLaughDuration),
                                       .run { [weak art] in art?.texture = happy }]),
                            withKey: CharacterNode.expressionBeatKey)
                } else if let tex = cellTexture(2) {
                    art.texture = tex
                }
            }
            let thoughtAlpha: CGFloat = (mood == .hungry && hasRemainingDesires) ? 1.0 : 0
            thoughtBubble?.run(.fadeAlpha(to: thoughtAlpha, duration: animated ? 0.34 : 0))
            if animated && mood == .eating {
                warmFlash.run(.sequence([
                    .fadeAlpha(to: 0.22, duration: 0.07),
                    .fadeAlpha(to: 0, duration: 0.22)
                ]))
                TouchFeedbackAnimator.acknowledge(node: self, profile: .shelfCard)
                AudioManager.shared.playFeedReceive()
                HapticsManager.shared.softTap()
            }
            if animated && mood == .satisfied {
                AudioManager.shared.playFeedHappy()
                HapticsManager.shared.softTap()
                runHappyShimmy()
            }
            return
        }

        let duration = animated ? 0.12 : 0
        [hungryMouth, eatingMouth, satisfiedMouth, restingMouth].forEach {
            $0?.run(.fadeAlpha(to: 0, duration: duration))
        }
        activeMouth.run(.fadeAlpha(to: 1, duration: duration))

        let closed = mood == .satisfied
        openEyeLayer.run(.fadeAlpha(to: closed ? 0 : 1, duration: duration))
        closedEyeLayer.run(.fadeAlpha(to: closed ? 1 : 0, duration: duration))

        let eyeScale: CGFloat = mood == .eating ? 1.26 : 1.0
        leftPupil.run(.scale(to: eyeScale, duration: duration))
        rightPupil.run(.scale(to: eyeScale, duration: duration))

        let cheekAlpha: CGFloat = (mood == .satisfied || mood == .resting) ? 0.30 : 0.12
        cheekLeft.run(.fadeAlpha(to: cheekAlpha, duration: duration * 2))
        cheekRight.run(.fadeAlpha(to: cheekAlpha, duration: duration * 2))

        let thoughtAlpha: CGFloat = (mood == .hungry && hasRemainingDesires) ? 1.0 : 0
        thoughtBubble?.run(.fadeAlpha(to: thoughtAlpha, duration: animated ? 0.34 : 0))

        if animated && mood == .eating {
            warmFlash.run(.sequence([
                .fadeAlpha(to: 0.22, duration: 0.07),
                .fadeAlpha(to: 0, duration: 0.22)
            ]))
            TouchFeedbackAnimator.acknowledge(node: self, profile: .shelfCard)
            AudioManager.shared.playFeedReceive()
            HapticsManager.shared.softTap()
        }

        if animated && mood == .satisfied {
            AudioManager.shared.playFeedHappy()
            HapticsManager.shared.softTap()
            runHappyShimmy()
        }
    }

    private func runHappyShimmy() {
        removeAction(forKey: "happyShimmy")

        let bounceUp = SKAction.moveBy(x: 0, y: headRadius * 0.22, duration: 0.10)
        let bounceDown = SKAction.moveBy(x: 0, y: -headRadius * 0.22, duration: 0.16)
        let tiltLeft = SKAction.rotate(toAngle: -0.14, duration: 0.10, shortestUnitArc: true)
        let tiltRight = SKAction.rotate(toAngle: 0.14, duration: 0.14, shortestUnitArc: true)
        let tiltLeftAgain = SKAction.rotate(toAngle: -0.09, duration: 0.12, shortestUnitArc: true)
        let center = SKAction.rotate(toAngle: 0, duration: 0.18, shortestUnitArc: true)
        let scaleUp = SKAction.scale(to: 1.08, duration: 0.10)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.22)

        [
            bounceUp,
            bounceDown,
            tiltLeft,
            tiltRight,
            tiltLeftAgain,
            center,
            scaleUp,
            scaleDown
        ].forEach { $0.timingMode = .easeInEaseOut }

        run(.sequence([
            .group([bounceUp, scaleUp, tiltLeft]),
            .group([bounceDown, scaleDown, .sequence([tiltRight, tiltLeftAgain, center])])
        ]), withKey: "happyShimmy")
    }

    private func scheduleAmbientLife() {
        AmbientAnimator.breathe(
            node: self,
            scale: personality == .fidgety ? 1.012 : 1.008,
            duration: personality == .slow ? 7.8 : 5.8,
            delay: Double.random(in: 0...1.2)
        )
    }

    private func schedulePersonalityTicks() {
        let interval: ClosedRange<Double>
        switch personality {
        case .fidgety:
            interval = 2.2...4.0
        case .calm:
            interval = 4.2...7.5
        case .slow:
            interval = 6.0...10.0
        }

        run(.repeatForever(.sequence([
            .wait(forDuration: Double.random(in: interval)),
            .run { [weak self] in self?.playPersonalityBeat() }
        ])), withKey: "personalityTicks")
    }

    private func playPersonalityBeat() {
        guard mood == .hungry || mood == .resting else { return }

        // Authored cast: pupils and head live in the painted cells, so personality
        // becomes whole-body — a little turn, a tiny dip, the slow sway. (Touching
        // the procedural face nodes here was the June 12 parent-area crash: they
        // are nil in art mode.)
        if let art = artSprite {
            switch personality {
            case .fidgety:
                let direction: CGFloat = Bool.random() ? 1 : -1
                let turn = SKAction.rotate(toAngle: direction * 0.05, duration: 0.3, shortestUnitArc: true)
                let back = SKAction.rotate(toAngle: 0, duration: 0.44, shortestUnitArc: true)
                turn.timingMode = .easeInEaseOut
                back.timingMode = .easeInEaseOut
                art.run(.sequence([turn, .wait(forDuration: 0.4), back]))
            case .calm:
                art.run(.sequence([
                    .scaleY(to: 0.985, duration: 0.16),
                    .scaleY(to: 1.0, duration: 0.22)
                ]))
            case .slow:
                let sway = SKAction.rotate(toAngle: 0.045, duration: 1.4, shortestUnitArc: true)
                let back = SKAction.rotate(toAngle: 0, duration: 1.6, shortestUnitArc: true)
                sway.timingMode = .easeInEaseOut
                back.timingMode = .easeInEaseOut
                run(.sequence([sway, back]), withKey: "slowSway")
            }
            return
        }

        switch personality {
        case .fidgety:
            let direction: CGFloat = Bool.random() ? 1 : -1
            let turn = SKAction.rotate(toAngle: direction * 0.16, duration: 0.28, shortestUnitArc: true)
            let back = SKAction.rotate(toAngle: 0, duration: 0.42, shortestUnitArc: true)
            turn.timingMode = .easeInEaseOut
            back.timingMode = .easeInEaseOut
            headNode.run(.sequence([turn, .wait(forDuration: 0.42), back]))
        case .calm:
            let close = SKAction.scaleY(to: 0.08, duration: 0.07)
            let open = SKAction.scaleY(to: 1.0, duration: 0.12)
            leftPupil.run(.sequence([close, open]))
            rightPupil.run(.sequence([close, open]))
        case .slow:
            let sway = SKAction.rotate(toAngle: 0.055, duration: 1.4, shortestUnitArc: true)
            let back = SKAction.rotate(toAngle: 0, duration: 1.6, shortestUnitArc: true)
            sway.timingMode = .easeInEaseOut
            back.timingMode = .easeInEaseOut
            run(.sequence([sway, back]), withKey: "slowSway")
        }
    }
}
