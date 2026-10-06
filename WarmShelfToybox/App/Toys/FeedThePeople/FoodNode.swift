import SpriteKit

enum FoodKind: CaseIterable, Equatable {
    case apple
    case carrot
    case egg
    case bread
    case berry
    case banana
    case cookie
    case cup

    var baseSize: CGSize {
        switch self {
        case .apple:
            return CGSize(width: 66, height: 70)
        case .carrot:
            return CGSize(width: 54, height: 82)
        case .egg:
            return CGSize(width: 56, height: 66)
        case .bread:
            return CGSize(width: 86, height: 56)
        case .berry:
            return CGSize(width: 56, height: 56)
        case .banana:
            return CGSize(width: 70, height: 44)
        case .cookie:
            return CGSize(width: 52, height: 52)
        case .cup:
            return CGSize(width: 46, height: 58)
        }
    }

    var fillColor: UIColor {
        switch self {
        case .apple:
            return WarmShelfPalette.terracotta
        case .carrot:
            return UIColor(hex: 0xE59A45)
        case .egg:
            return WarmShelfPalette.paperHighlight
        case .bread:
            return WarmShelfPalette.sand
        case .berry:
            return WarmShelfPalette.lavender
        case .banana:
            return WarmShelfPalette.butter
        case .cookie:
            return WarmShelfPalette.sand
        case .cup:
            return WarmShelfPalette.waterBlue
        }
    }

    var accessibilityName: String {
        switch self {
        case .apple: return "apple"
        case .carrot: return "carrot"
        case .egg: return "egg"
        case .bread: return "bread"
        case .berry: return "berry"
        case .banana: return "banana"
        case .cookie: return "cookie"
        case .cup: return "cup"
        }
    }
}

final class FoodNode: SKNode {
    let kind: FoodKind
    let foodSize: CGSize

    var isDragging = false
    private var dragOffset = CGPoint.zero

    init(kind: FoodKind, scale: CGFloat = 1.0) {
        self.kind = kind
        self.foodSize = CGSize(width: kind.baseSize.width * scale, height: kind.baseSize.height * scale)
        super.init()

        name = "feedFood"
        accessibilityLabel = kind.accessibilityName
        isAccessibilityElement = true
        isUserInteractionEnabled = false
        buildFood()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func containsScenePoint(_ point: CGPoint) -> Bool {
        guard let scene else { return false }

        let localPoint = convert(point, from: scene)
        let hitScale: CGFloat = kind == .egg ? 1.42 : 1.20
        let hitSize = CGSize(width: foodSize.width * hitScale, height: foodSize.height * hitScale)
        return ForgivingHitArea.contains(localPoint: localPoint, size: hitSize, profile: .softDrag)
    }

    func beginDrag(at scenePoint: CGPoint) {
        guard let scene else { return }

        let localPoint = parent?.convert(scenePoint, from: scene) ?? scenePoint
        isDragging = true
        dragOffset = CGPoint(x: position.x - localPoint.x, y: position.y - localPoint.y)
        removeAllActions()
        zPosition = 92
        TouchFeedbackAnimator.acknowledge(node: self, profile: .softDrag)
        TouchFeedbackAnimator.tactileSpark(in: scene, at: scenePoint, color: kind.fillColor, count: 4)
        AudioManager.shared.playFoodPickup()
        HapticsManager.shared.blockPickup()
    }

    func drag(to scenePoint: CGPoint, in scene: SKScene, bounds: CGRect) {
        guard isDragging else { return }

        let localPoint = parent?.convert(scenePoint, from: scene) ?? scenePoint
        position = CGPoint(
            x: min(max(localPoint.x + dragOffset.x, bounds.minX), bounds.maxX),
            y: min(max(localPoint.y + dragOffset.y, bounds.minY), bounds.maxY)
        )
    }

    func endDrag() {
        guard isDragging else { return }
        isDragging = false
        zPosition = 45
        TouchFeedbackAnimator.softSettle(node: self, profile: .softDrag)
        if let scene {
            TouchFeedbackAnimator.tactileSpark(
                in: scene,
                at: convert(CGPoint.zero, to: scene),
                color: kind.fillColor,
                count: 3,
                includesRipple: false
            )
        }
        AudioManager.shared.playFoodRelease()
        HapticsManager.shared.blockRelease()
    }

    private static func artSlot(for kind: FoodKind) -> String? {
        switch kind {
        case .apple: return "feed-apple"
        case .carrot: return "feed-carrot"
        case .banana: return "feed-banana"
        case .egg: return "feed-egg"
        case .bread: return "feed-bread"
        case .berry: return "feed-berry"
        case .cookie: return "feed-cookie"
        case .cup: return "feed-cup"
        }
    }

    private func buildFood() {
        let shadowSize = CGSize(width: foodSize.width * 0.98, height: max(12, foodSize.height * 0.24))
        let shadow = SKSpriteNode(texture: ProceduralTexture.softClayShadow(size: shadowSize))
        shadow.size = shadowSize
        shadow.position = CGPoint(x: foodSize.width * 0.03, y: -foodSize.height * 0.49)
        shadow.zPosition = -2
        addChild(shadow)

        // Warm Clay food when its art has landed (Docs/FeedSlice.md).
        if let slot = FoodNode.artSlot(for: kind),
           let art = ToyArt.sprite(slot, fit: CGSize(width: foodSize.width * 1.06, height: foodSize.height * 1.06)) {
            art.zPosition = 0
            addChild(art)
            return
        }

        switch kind {
        case .apple:
            addApple()
        case .carrot:
            addCarrot()
        case .egg:
            addEgg()
        case .bread:
            addBread()
        case .berry:
            addBerry()
        case .banana:
            addBanana()
        case .cookie:
            addCookie()
        case .cup:
            addCup()
        }

        addCuteFace()
    }

    /// Every snack is a tiny member of the clay family: sleepy arc eyes, a content smile,
    /// and rosy cheeks — so the whole table feels like one warm world.
    private func addCuteFace() {
        // Where the face sits, and how big, tuned per food shape. The cup is a drink, not a friend.
        let center: CGPoint
        let faceWidth: CGFloat
        switch kind {
        case .apple:  center = CGPoint(x: 0, y: foodSize.height * 0.04); faceWidth = foodSize.width * 0.50
        case .berry:  center = CGPoint(x: 0, y: -foodSize.height * 0.02); faceWidth = foodSize.width * 0.52
        case .cookie: center = CGPoint(x: 0, y: 0); faceWidth = foodSize.width * 0.50
        case .egg:    center = CGPoint(x: foodSize.width * 0.02, y: -foodSize.height * 0.06); faceWidth = foodSize.width * 0.46
        case .bread:  center = CGPoint(x: 0, y: -foodSize.height * 0.02); faceWidth = foodSize.height * 0.62
        case .carrot: center = CGPoint(x: 0, y: -foodSize.height * 0.04); faceWidth = foodSize.width * 0.40
        case .banana: center = CGPoint(x: 0, y: foodSize.height * 0.10); faceWidth = foodSize.width * 0.34
        case .cup:    return
        }

        let ink = WarmShelfPalette.clayInk.withAlpha(0.62)
        let eyeGap = faceWidth * 0.28
        let eyeW = faceWidth * 0.17
        let eyeY = center.y + faceWidth * 0.07
        let lineW = max(1.3, faceWidth * 0.05)

        for sign in [CGFloat(-1), CGFloat(1)] {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -eyeW * 0.5, y: 0))
            p.addQuadCurve(to: CGPoint(x: eyeW * 0.5, y: 0), control: CGPoint(x: 0, y: faceWidth * 0.11))
            let eye = SKShapeNode(path: p)
            eye.strokeColor = ink
            eye.lineWidth = lineW
            eye.lineCap = .round
            eye.fillColor = .clear
            eye.position = CGPoint(x: center.x + sign * eyeGap, y: eyeY)
            eye.zPosition = 5
            addChild(eye)
        }

        let mw = faceWidth * 0.22
        let my = center.y - faceWidth * 0.10
        let mouthPath = CGMutablePath()
        mouthPath.move(to: CGPoint(x: center.x - mw * 0.5, y: my))
        mouthPath.addQuadCurve(to: CGPoint(x: center.x + mw * 0.5, y: my),
                               control: CGPoint(x: center.x, y: my - faceWidth * 0.10))
        let mouth = SKShapeNode(path: mouthPath)
        mouth.strokeColor = ink
        mouth.lineWidth = lineW * 0.9
        mouth.lineCap = .round
        mouth.fillColor = .clear
        mouth.zPosition = 5
        addChild(mouth)

        for sign in [CGFloat(-1), CGFloat(1)] {
            let cheek = SKShapeNode(circleOfRadius: faceWidth * 0.075)
            cheek.fillColor = WarmShelfPalette.petal.withAlpha(0.42)
            cheek.strokeColor = .clear
            cheek.position = CGPoint(x: center.x + sign * eyeGap * 1.55, y: center.y - faceWidth * 0.02)
            cheek.zPosition = 4.8
            addChild(cheek)
        }
    }

    private func addApple() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: -foodSize.height * 0.42))
        path.addCurve(
            to: CGPoint(x: -foodSize.width * 0.42, y: foodSize.height * 0.06),
            control1: CGPoint(x: -foodSize.width * 0.38, y: -foodSize.height * 0.38),
            control2: CGPoint(x: -foodSize.width * 0.48, y: -foodSize.height * 0.08)
        )
        path.addCurve(
            to: CGPoint(x: -foodSize.width * 0.13, y: foodSize.height * 0.38),
            control1: CGPoint(x: -foodSize.width * 0.44, y: foodSize.height * 0.30),
            control2: CGPoint(x: -foodSize.width * 0.28, y: foodSize.height * 0.42)
        )
        path.addQuadCurve(
            to: CGPoint(x: 0, y: foodSize.height * 0.32),
            control: CGPoint(x: -foodSize.width * 0.06, y: foodSize.height * 0.27)
        )
        path.addQuadCurve(
            to: CGPoint(x: foodSize.width * 0.13, y: foodSize.height * 0.38),
            control: CGPoint(x: foodSize.width * 0.06, y: foodSize.height * 0.27)
        )
        path.addCurve(
            to: CGPoint(x: foodSize.width * 0.42, y: foodSize.height * 0.06),
            control1: CGPoint(x: foodSize.width * 0.28, y: foodSize.height * 0.42),
            control2: CGPoint(x: foodSize.width * 0.44, y: foodSize.height * 0.30)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: -foodSize.height * 0.42),
            control1: CGPoint(x: foodSize.width * 0.48, y: -foodSize.height * 0.08),
            control2: CGPoint(x: foodSize.width * 0.38, y: -foodSize.height * 0.38)
        )
        path.closeSubpath()

        let body = SKShapeNode(path: path)
        body.fillColor = kind.fillColor.withAlpha(0.96)
        body.strokeColor = WarmShelfPalette.clayInk.withAlpha(0.05)
        body.lineWidth = max(1.2, foodSize.width * 0.018)
        body.zPosition = 1
        addChild(body)

        let topDimple = SKShapeNode(ellipseOf: CGSize(width: foodSize.width * 0.24, height: foodSize.height * 0.08))
        topDimple.fillColor = WarmShelfPalette.cocoa.withAlpha(0.07)
        topDimple.strokeColor = .clear
        topDimple.position = CGPoint(x: 0, y: foodSize.height * 0.32)
        topDimple.zPosition = 2.2
        addChild(topDimple)

        let stem = SKShapeNode(
            rect: CGRect(x: -foodSize.width * 0.035, y: foodSize.height * 0.34, width: foodSize.width * 0.07, height: foodSize.height * 0.20),
            cornerRadius: foodSize.width * 0.035
        )
        stem.fillColor = WarmShelfPalette.cocoa.withAlpha(0.56)
        stem.strokeColor = .clear
        stem.zRotation = 0.22
        stem.zPosition = 3.5
        addChild(stem)

        let leaf = SKShapeNode(ellipseOf: CGSize(width: foodSize.width * 0.30, height: foodSize.height * 0.14))
        leaf.fillColor = WarmShelfPalette.sage.withAlpha(0.78)
        leaf.strokeColor = WarmShelfPalette.clayInk.withAlpha(0.035)
        leaf.lineWidth = max(0.7, foodSize.width * 0.010)
        leaf.position = CGPoint(x: foodSize.width * 0.16, y: foodSize.height * 0.43)
        leaf.zRotation = 0.34
        leaf.zPosition = 3.2
        addChild(leaf)

        addHighlight(width: foodSize.width * 0.22, height: foodSize.height * 0.10, x: -foodSize.width * 0.19, y: foodSize.height * 0.13, alpha: 0.26)
        addCurvedSheen(from: CGPoint(x: -foodSize.width * 0.22, y: -foodSize.height * 0.04), to: CGPoint(x: foodSize.width * 0.24, y: -foodSize.height * 0.16), color: WarmShelfPalette.paperHighlight.withAlpha(0.12), lineWidth: max(1.1, foodSize.width * 0.020))
        addFruitSkinTexture(radius: foodSize.width * 0.38, count: 17)
        addTinyFleck(x: foodSize.width * 0.12, y: -foodSize.height * 0.04)
        addTinyFleck(x: -foodSize.width * 0.17, y: -foodSize.height * 0.15)
    }

    private func addCarrot() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: -foodSize.height * 0.48))
        path.addLine(to: CGPoint(x: -foodSize.width * 0.42, y: foodSize.height * 0.28))
        path.addQuadCurve(
            to: CGPoint(x: foodSize.width * 0.42, y: foodSize.height * 0.28),
            control: CGPoint(x: 0, y: foodSize.height * 0.50)
        )
        path.closeSubpath()

        let body = SKShapeNode(path: path)
        body.fillColor = kind.fillColor.withAlpha(0.96)
        body.strokeColor = WarmShelfPalette.clayInk.withAlpha(0.05)
        body.lineWidth = max(1.2, foodSize.width * 0.018)
        body.zPosition = 1
        addChild(body)

        for (index, xOffset) in [-0.18, 0.0, 0.18].enumerated() {
            let leaf = SKShapeNode(ellipseOf: CGSize(width: foodSize.width * 0.22, height: foodSize.height * 0.22))
            leaf.fillColor = WarmShelfPalette.sage.withAlpha(index == 1 ? 0.82 : 0.70)
            leaf.strokeColor = .clear
            leaf.position = CGPoint(x: foodSize.width * CGFloat(xOffset), y: foodSize.height * 0.43)
            leaf.zRotation = CGFloat(index - 1) * 0.46
            leaf.zPosition = 3
            addChild(leaf)
        }

        addHighlight(width: foodSize.width * 0.14, height: foodSize.height * 0.08, x: -foodSize.width * 0.10, y: foodSize.height * 0.12, alpha: 0.20)
        addFoodGrain(
            rect: CGRect(x: -foodSize.width * 0.28, y: -foodSize.height * 0.26, width: foodSize.width * 0.56, height: foodSize.height * 0.52),
            count: 5
        )
        for offset in [-0.24, -0.08, 0.08, 0.22] {
            let groove = SKShapeNode(
                rect: CGRect(
                    x: -foodSize.width * 0.15,
                    y: foodSize.height * CGFloat(offset),
                    width: foodSize.width * 0.30,
                    height: max(2, foodSize.height * 0.028)
                ),
                cornerRadius: foodSize.height * 0.02
            )
            groove.fillColor = WarmShelfPalette.cocoa.withAlpha(0.055)
            groove.strokeColor = .clear
            groove.zRotation = -0.24
            groove.zPosition = 3
            addChild(groove)
        }
        addCurvedSheen(from: CGPoint(x: -foodSize.width * 0.14, y: -foodSize.height * 0.34), to: CGPoint(x: foodSize.width * 0.13, y: foodSize.height * 0.18), color: WarmShelfPalette.paperHighlight.withAlpha(0.10), lineWidth: max(1.0, foodSize.width * 0.026))
    }

    private func addEgg() {
        let egg = SKShapeNode(ellipseOf: CGSize(width: foodSize.width * 0.78, height: foodSize.height))
        egg.fillColor = kind.fillColor.withAlpha(0.98)
        egg.strokeColor = WarmShelfPalette.sand.withAlpha(0.42)
        egg.lineWidth = max(1.8, foodSize.width * 0.026)
        egg.zPosition = 1
        addChild(egg)
        ProceduralTexture.applyClayFill(to: egg, base: kind.fillColor.withAlpha(0.98), size: CGSize(width: foodSize.width * 0.78, height: foodSize.height))

        let warmSpot = SKShapeNode(ellipseOf: CGSize(width: foodSize.width * 0.38, height: foodSize.height * 0.30))
        warmSpot.fillColor = WarmShelfPalette.butter.withAlpha(0.48)
        warmSpot.strokeColor = WarmShelfPalette.sand.withAlpha(0.14)
        warmSpot.lineWidth = max(0.8, foodSize.width * 0.012)
        warmSpot.position = CGPoint(x: foodSize.width * 0.08, y: -foodSize.height * 0.10)
        warmSpot.zPosition = 2
        addChild(warmSpot)

        addHighlight(width: foodSize.width * 0.32, height: foodSize.height * 0.13, x: -foodSize.width * 0.17, y: foodSize.height * 0.15, alpha: 0.24)
        addFruitSkinTexture(radius: foodSize.width * 0.38, count: 10, alpha: 0.022...0.060)
        addTinyFleck(x: foodSize.width * 0.14, y: -foodSize.height * 0.13)
        addTinyFleck(x: -foodSize.width * 0.10, y: -foodSize.height * 0.22)
    }

    private func addBread() {
        let bread = SKShapeNode(
            rect: CGRect(x: -foodSize.width / 2, y: -foodSize.height / 2, width: foodSize.width, height: foodSize.height),
            cornerRadius: foodSize.height * 0.42
        )
        bread.fillColor = kind.fillColor.withAlpha(0.96)
        bread.strokeColor = WarmShelfPalette.clayInk.withAlpha(0.05)
        bread.lineWidth = max(1.2, foodSize.width * 0.015)
        bread.zPosition = 1
        addChild(bread)
        ProceduralTexture.applyClayFill(to: bread, base: kind.fillColor.withAlpha(0.96), size: foodSize)

        let crust = SKShapeNode(
            rect: CGRect(
                x: -foodSize.width * 0.47,
                y: -foodSize.height * 0.42,
                width: foodSize.width * 0.94,
                height: foodSize.height * 0.84
            ),
            cornerRadius: foodSize.height * 0.35
        )
        crust.fillColor = .clear
        crust.strokeColor = UIColor(hex: 0x9C6D43).withAlpha(0.20)
        crust.lineWidth = max(2.4, foodSize.width * 0.040)
        crust.zPosition = 2
        addChild(crust)

        let cutFace = SKShapeNode(
            rect: CGRect(
                x: -foodSize.width * 0.34,
                y: -foodSize.height * 0.30,
                width: foodSize.width * 0.68,
                height: foodSize.height * 0.60
            ),
            cornerRadius: foodSize.height * 0.26
        )
        cutFace.fillColor = WarmShelfPalette.warmCream.withAlpha(0.16)
        cutFace.strokeColor = .clear
        cutFace.zPosition = 2.1
        addChild(cutFace)

        addHighlight(width: foodSize.width * 0.34, height: foodSize.height * 0.10, x: -foodSize.width * 0.11, y: foodSize.height * 0.10, alpha: 0.18)
        addFoodGrain(
            rect: CGRect(x: -foodSize.width * 0.36, y: -foodSize.height * 0.26, width: foodSize.width * 0.72, height: foodSize.height * 0.52),
            count: 12
        )
        for x in [-0.26, -0.10, 0.08, 0.25] {
            let dimple = SKShapeNode(ellipseOf: CGSize(width: foodSize.width * 0.10, height: foodSize.height * 0.09))
            dimple.fillColor = WarmShelfPalette.cocoa.withAlpha(0.055)
            dimple.strokeColor = .clear
            dimple.position = CGPoint(x: foodSize.width * CGFloat(x), y: foodSize.height * CGFloat.random(in: -0.10...0.10))
            dimple.zPosition = 2
            addChild(dimple)
        }
    }

    private func addBerry() {
        let berry = SKShapeNode(circleOfRadius: foodSize.width * 0.45)
        berry.fillColor = kind.fillColor.withAlpha(0.94)
        berry.strokeColor = WarmShelfPalette.clayInk.withAlpha(0.05)
        berry.lineWidth = max(1.2, foodSize.width * 0.018)
        berry.zPosition = 1
        addChild(berry)
        ProceduralTexture.applyClayFill(to: berry, base: kind.fillColor.withAlpha(0.94), size: CGSize(width: foodSize.width * 0.9, height: foodSize.width * 0.9))

        for index in 0..<5 {
            let leaf = SKShapeNode(ellipseOf: CGSize(width: foodSize.width * 0.14, height: foodSize.height * 0.08))
            leaf.fillColor = WarmShelfPalette.sage.withAlpha(0.52)
            leaf.strokeColor = .clear
            leaf.position = CGPoint(x: 0, y: foodSize.height * 0.35)
            leaf.zRotation = CGFloat(index) / 5 * .pi * 2
            leaf.zPosition = 3.1
            addChild(leaf)
        }

        addHighlight(width: foodSize.width * 0.17, height: foodSize.height * 0.09, x: -foodSize.width * 0.14, y: foodSize.height * 0.12, alpha: 0.22)
        addFruitSkinTexture(radius: foodSize.width * 0.40, count: 16)
        addTinyFleck(x: foodSize.width * 0.12, y: foodSize.height * 0.02)
        addTinyFleck(x: -foodSize.width * 0.03, y: -foodSize.height * 0.14)
    }

    private func addBanana() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -foodSize.width * 0.38, y: -foodSize.height * 0.02))
        path.addQuadCurve(
            to: CGPoint(x: foodSize.width * 0.38, y: foodSize.height * 0.02),
            control: CGPoint(x: 0, y: foodSize.height * 0.46)
        )

        let banana = SKShapeNode(path: path)
        banana.fillColor = .clear
        banana.strokeColor = kind.fillColor.withAlpha(0.92)
        banana.lineWidth = max(10, foodSize.height * 0.30)
        banana.lineCap = .round
        banana.zPosition = 1
        addChild(banana)

        let lower = SKShapeNode(path: path)
        lower.fillColor = .clear
        lower.strokeColor = WarmShelfPalette.sand.withAlpha(0.18)
        lower.lineWidth = max(4, foodSize.height * 0.10)
        lower.lineCap = .round
        lower.position = CGPoint(x: 0, y: -foodSize.height * 0.10)
        lower.zPosition = 0.8
        addChild(lower)

        addCurvedSheen(from: CGPoint(x: -foodSize.width * 0.27, y: foodSize.height * 0.02), to: CGPoint(x: foodSize.width * 0.29, y: foodSize.height * 0.04), color: WarmShelfPalette.paperHighlight.withAlpha(0.16), lineWidth: max(2.0, foodSize.height * 0.055))
        addCurvedSheen(from: CGPoint(x: -foodSize.width * 0.18, y: -foodSize.height * 0.09), to: CGPoint(x: foodSize.width * 0.22, y: -foodSize.height * 0.03), color: WarmShelfPalette.sand.withAlpha(0.16), lineWidth: max(1.4, foodSize.height * 0.040))

        for x in [-0.36, 0.36] {
            let tip = SKShapeNode(circleOfRadius: max(3, foodSize.height * 0.07))
            tip.fillColor = WarmShelfPalette.cocoa.withAlpha(0.34)
            tip.strokeColor = .clear
            tip.position = CGPoint(x: foodSize.width * CGFloat(x), y: foodSize.height * 0.02)
            tip.zPosition = 2
            addChild(tip)
        }

        addFoodGrain(
            rect: CGRect(x: -foodSize.width * 0.34, y: -foodSize.height * 0.10, width: foodSize.width * 0.68, height: foodSize.height * 0.34),
            count: 4
        )
    }

    private func addCookie() {
        let disc = SKShapeNode(circleOfRadius: foodSize.width * 0.42)
        disc.fillColor = kind.fillColor.withAlpha(0.92)
        disc.strokeColor = WarmShelfPalette.clayInk.withAlpha(0.05)
        disc.lineWidth = max(1.2, foodSize.width * 0.018)
        disc.zPosition = 1
        addChild(disc)
        ProceduralTexture.applyClayFill(to: disc, base: kind.fillColor.withAlpha(0.92), size: CGSize(width: foodSize.width * 0.84, height: foodSize.width * 0.84))

        let bakedEdge = SKShapeNode(circleOfRadius: foodSize.width * 0.38)
        bakedEdge.fillColor = .clear
        bakedEdge.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.11)
        bakedEdge.lineWidth = max(2, foodSize.width * 0.035)
        bakedEdge.zPosition = 1.6
        addChild(bakedEdge)

        for _ in 0..<5 {
            let chip = SKShapeNode(circleOfRadius: CGFloat.random(in: foodSize.width * 0.035...foodSize.width * 0.060))
            chip.fillColor = WarmShelfPalette.cocoa.withAlpha(0.58)
            chip.strokeColor = .clear
            chip.position = CGPoint(
                x: CGFloat.random(in: -foodSize.width * 0.22...foodSize.width * 0.22),
                y: CGFloat.random(in: -foodSize.height * 0.22...foodSize.height * 0.22)
            )
            chip.zPosition = 2
            addChild(chip)
        }

        for _ in 0..<4 {
            let crumb = SKShapeNode(circleOfRadius: CGFloat.random(in: foodSize.width * 0.018...foodSize.width * 0.035))
            crumb.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.18)
            crumb.strokeColor = .clear
            crumb.position = CGPoint(
                x: CGFloat.random(in: -foodSize.width * 0.24...foodSize.width * 0.24),
                y: CGFloat.random(in: -foodSize.height * 0.24...foodSize.height * 0.24)
            )
            crumb.zPosition = 2.1
            addChild(crumb)
        }

        addHighlight(width: foodSize.width * 0.18, height: foodSize.height * 0.08, x: -foodSize.width * 0.14, y: foodSize.height * 0.15, alpha: 0.16)
        addFruitSkinTexture(radius: foodSize.width * 0.36, count: 12, alpha: 0.020...0.055)
    }

    private func addCup() {
        let body = SKShapeNode(
            rect: CGRect(
                x: -foodSize.width * 0.28,
                y: -foodSize.height * 0.38,
                width: foodSize.width * 0.56,
                height: foodSize.height * 0.76
            ),
            cornerRadius: foodSize.width * 0.10
        )
        body.fillColor = kind.fillColor.withAlpha(0.76)
        body.strokeColor = WarmShelfPalette.clayInk.withAlpha(0.05)
        body.lineWidth = max(1.2, foodSize.width * 0.018)
        body.zPosition = 1
        addChild(body)

        let fill = SKShapeNode(ellipseOf: CGSize(width: foodSize.width * 0.48, height: foodSize.height * 0.11))
        fill.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.24)
        fill.strokeColor = .clear
        fill.position = CGPoint(x: 0, y: foodSize.height * 0.35)
        fill.zPosition = 1.8
        addChild(fill)

        let rim = SKShapeNode(ellipseOf: CGSize(width: foodSize.width * 0.62, height: foodSize.height * 0.18))
        rim.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.42)
        rim.strokeColor = WarmShelfPalette.waterBlue.withAlpha(0.28)
        rim.lineWidth = max(1.0, foodSize.width * 0.014)
        rim.position = CGPoint(x: 0, y: foodSize.height * 0.34)
        rim.zPosition = 2
        addChild(rim)

        let handle = SKShapeNode(ellipseOf: CGSize(width: foodSize.width * 0.28, height: foodSize.height * 0.30))
        handle.fillColor = .clear
        handle.strokeColor = kind.fillColor.withAlpha(0.58)
        handle.lineWidth = max(3, foodSize.width * 0.08)
        handle.position = CGPoint(x: foodSize.width * 0.32, y: foodSize.height * 0.02)
        handle.zPosition = 0.9
        addChild(handle)

        for index in 0..<3 {
            addSteamWisp(
                x: (CGFloat(index) - 1) * foodSize.width * 0.11,
                delay: Double(index) * 0.16
            )
        }

        addHighlight(width: foodSize.width * 0.13, height: foodSize.height * 0.28, x: -foodSize.width * 0.12, y: foodSize.height * 0.04, alpha: 0.18)
    }

    private func addFruitSkinTexture(radius: CGFloat, count: Int, alpha: ClosedRange<CGFloat> = 0.030...0.095) {
        ProceduralTexture.addCircularSpeckles(
            to: self,
            radius: radius,
            count: count,
            alpha: alpha,
            dotRadius: 0.7...2.2,
            zPosition: 2.6
        )
    }

    private func addFoodGrain(rect: CGRect, count: Int) {
        ProceduralTexture.addSoftSpeckles(
            to: self,
            in: rect,
            count: count,
            alpha: 0.028...0.085,
            radius: 0.7...1.8,
            zPosition: 2.6
        )
        ProceduralTexture.addSoftGrainLines(
            to: self,
            in: rect,
            count: max(2, count / 2),
            alpha: 0.035...0.085,
            zPosition: 2.7
        )
    }

    private func addHighlight(width: CGFloat, height: CGFloat, x: CGFloat, y: CGFloat, alpha: CGFloat = 0.18) {
        let highlight = SKShapeNode(ellipseOf: CGSize(width: width, height: height))
        highlight.fillColor = WarmShelfPalette.paperHighlight.withAlpha(alpha)
        highlight.strokeColor = .clear
        highlight.position = CGPoint(x: x, y: y)
        highlight.zRotation = -0.20
        highlight.zPosition = 3
        addChild(highlight)
    }

    private func addTinyFleck(x: CGFloat, y: CGFloat) {
        let fleck = SKShapeNode(circleOfRadius: max(2.2, foodSize.width * 0.038))
        fleck.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.16)
        fleck.strokeColor = .clear
        fleck.position = CGPoint(x: x, y: y)
        fleck.zPosition = 3
        addChild(fleck)
    }

    private func addCurvedSheen(from start: CGPoint, to end: CGPoint, color: UIColor, lineWidth: CGFloat) {
        let path = CGMutablePath()
        path.move(to: start)
        path.addQuadCurve(
            to: end,
            control: CGPoint(x: (start.x + end.x) / 2, y: max(start.y, end.y) + foodSize.height * 0.14)
        )
        let sheen = SKShapeNode(path: path)
        sheen.fillColor = .clear
        sheen.strokeColor = color
        sheen.lineWidth = lineWidth
        sheen.lineCap = .round
        sheen.zPosition = 3.2
        addChild(sheen)
    }

    private func addSteamWisp(x: CGFloat, delay: TimeInterval) {
        let path = CGMutablePath()
        let start = CGPoint(x: x, y: foodSize.height * 0.48)
        path.move(to: start)
        path.addQuadCurve(
            to: CGPoint(x: x + foodSize.width * 0.04, y: foodSize.height * 0.74),
            control: CGPoint(x: x - foodSize.width * 0.08, y: foodSize.height * 0.62)
        )
        let wisp = SKShapeNode(path: path)
        wisp.fillColor = .clear
        wisp.strokeColor = WarmShelfPalette.paperHighlight.withAlpha(0.24)
        wisp.lineWidth = max(1.0, foodSize.width * 0.025)
        wisp.lineCap = .round
        wisp.zPosition = 4
        addChild(wisp)

        let lift = SKAction.moveBy(x: 0, y: foodSize.height * 0.04, duration: 1.3)
        let fadeLow = SKAction.fadeAlpha(to: 0.18, duration: 0.55)
        let fadeHigh = SKAction.fadeAlpha(to: 0.34, duration: 0.55)
        lift.timingMode = .easeInEaseOut
        wisp.run(.repeatForever(.sequence([
            .wait(forDuration: delay),
            .group([lift, fadeLow]),
            .group([lift.reversed(), fadeHigh])
        ])))
    }
}
