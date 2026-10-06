import SpriteKit

enum ClayBlockTextureStyle: CaseIterable {
    case plain
    case speckled
    case grooved

    static func calmRandom() -> ClayBlockTextureStyle {
        let roll = CGFloat.random(in: 0...1)
        switch roll {
        case ..<0.36:
            return .plain
        case ..<0.76:
            return .speckled
        case ..<1.0:
            return .grooved
        default:
            return .plain
        }
    }
}

final class ClayBlockNode: SKShapeNode {
    let kind: ClayBlockKind
    let blockSize: CGSize
    let blockColor: UIColor
    let textureStyle: ClayBlockTextureStyle

    init(kind: ClayBlockKind, color: UIColor, scale: CGFloat = 1.0, textureStyle: ClayBlockTextureStyle = .calmRandom()) {
        self.kind = kind
        self.blockSize = CGSize(width: kind.size.width * scale, height: kind.size.height * scale)
        self.blockColor = color
        self.textureStyle = textureStyle
        super.init()

        name = "clayBlock"
        isUserInteractionEnabled = false
        buildBlock()
    }

    convenience init(size: CGSize, color: UIColor) {
        self.init(kind: .brick, color: color, scale: size.width / ClayBlockKind.brick.size.width, textureStyle: .plain)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func containsScenePoint(_ point: CGPoint) -> Bool {
        guard let scene else { return false }

        let localPoint = convert(point, from: scene)
        return ForgivingHitArea.contains(localPoint: localPoint, size: blockSize, profile: .softDrag)
    }

    private func buildBlock() {
        let radius = kind.isRound
            ? blockSize.width / 2
            : min(kind.cornerRadius * (blockSize.width / kind.size.width), min(blockSize.width, blockSize.height) * 0.28)
        let rect = CGRect(
            x: -blockSize.width / 2,
            y: -blockSize.height / 2,
            width: blockSize.width,
            height: blockSize.height
        )

        let shadow: SKShapeNode
        if kind.isTriangle {
            shadow = SKShapeNode(path: trianglePath(offset: CGPoint(x: 2, y: -3)))
        } else {
            shadow = SKShapeNode(rect: rect.offsetBy(dx: 2, dy: -3), cornerRadius: radius)
        }
        shadow.fillColor = WarmShelfPalette.clayInk.withAlpha(0.035)
        shadow.strokeColor = .clear
        shadow.zPosition = -1
        addChild(shadow)

        path = kind.isTriangle
            ? trianglePath(offset: .zero)
            : CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        fillColor = blockColor
        strokeColor = WarmShelfPalette.clayInk.withAlpha(0.026)
        lineWidth = max(0.7, min(1.1, blockSize.height * 0.016))
        lineJoin = .round
        applyBaseMaterialTexture()

        if !kind.isRound && !kind.isTriangle {
            let topFace = SKShapeNode(
                rect: CGRect(
                    x: -blockSize.width * 0.40,
                    y: blockSize.height * 0.14,
                    width: blockSize.width * 0.80,
                    height: max(8, blockSize.height * 0.18)
                ),
                cornerRadius: min(radius * 0.55, blockSize.height * 0.08)
            )
            topFace.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.050)
            topFace.strokeColor = .clear
            topFace.zPosition = 0.8
            addChild(topFace)
        }

        let highlight = SKShapeNode(
            rect: CGRect(
                x: -blockSize.width * 0.34,
                y: blockSize.height * 0.14,
                width: blockSize.width * (kind.isRound ? 0.28 : 0.42),
                height: blockSize.height * (kind == .plank ? 0.18 : 0.12)
            ),
            cornerRadius: blockSize.height * 0.055
        )
        highlight.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.18)
        highlight.strokeColor = .clear
        highlight.zPosition = 1
        addChild(highlight)

        for index in 0..<2 {
            let fleck = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.8...1.8))
            fleck.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.08)
            fleck.strokeColor = .clear
            fleck.position = randomTexturePoint()
            fleck.zPosition = CGFloat(1 + index)
            addChild(fleck)
        }

        applyTextureStyle(radius: radius)
        addSpecialBlockMarks(radius: radius)

        let body = kind.isRound
            ? SKPhysicsBody(circleOfRadius: blockSize.width / 2)
            : kind.isTriangle
                ? SKPhysicsBody(polygonFrom: trianglePath(offset: .zero))
                : SKPhysicsBody(rectangleOf: blockSize)
        body.allowsRotation = true
        body.affectedByGravity = true
        body.mass = kind.mass
        body.friction = kind.friction
        body.restitution = kind.restitution
        body.linearDamping = kind.isRound ? 0.32 : 0.48
        body.angularDamping = kind.isRound ? 0.55 : 1.05
        body.usesPreciseCollisionDetection = true
        body.categoryBitMask = PhysicsCategory.block
        body.collisionBitMask = PhysicsCategory.block | PhysicsCategory.surface | PhysicsCategory.wall
        body.contactTestBitMask = PhysicsCategory.surface | PhysicsCategory.block
        physicsBody = body
    }

    func applySquishImpact(intensity: CGFloat = 1.0) {
        guard action(forKey: "squishImpact") == nil else { return }

        let clamped = min(max(intensity, 0.18), 1.0)
        let originalX = xScale
        let originalY = yScale
        let squishX = originalX * (1.0 + 0.18 * clamped)
        let squishY = originalY * (1.0 - 0.15 * clamped)
        let reboundX = originalX * (1.0 - 0.055 * clamped)
        let reboundY = originalY * (1.0 + 0.070 * clamped)

        let squash = SKAction.group([
            .scaleX(to: squishX, duration: 0.045),
            .scaleY(to: squishY, duration: 0.045)
        ])
        let rebound = SKAction.group([
            .scaleX(to: reboundX, duration: 0.10),
            .scaleY(to: reboundY, duration: 0.10)
        ])
        let settle = SKAction.group([
            .scaleX(to: originalX, duration: 0.20),
            .scaleY(to: originalY, duration: 0.20)
        ])
        squash.timingMode = .easeOut
        rebound.timingMode = .easeInEaseOut
        settle.timingMode = .easeInEaseOut

        run(.sequence([squash, rebound, settle]), withKey: "squishImpact")

        guard clamped > 0.58, let scene else { return }
        TouchFeedbackAnimator.tactileSpark(
            in: scene,
            at: convert(.zero, to: scene),
            color: blockColor,
            count: 5,
            includesRipple: false
        )
    }

    private func trianglePath(offset: CGPoint) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -blockSize.width / 2 + offset.x, y: -blockSize.height / 2 + offset.y))
        path.addLine(to: CGPoint(x: blockSize.width / 2 + offset.x, y: -blockSize.height / 2 + offset.y))
        path.addLine(to: CGPoint(x: 0 + offset.x, y: blockSize.height / 2 + offset.y))
        path.closeSubpath()
        return path
    }

    private func applyTextureStyle(radius: CGFloat) {
        switch textureStyle {
        case .plain:
            return
        case .speckled:
            addSpeckles(count: 8)
        case .grooved:
            addGrooves(radius: radius)
        }
    }

    private func addSpecialBlockMarks(radius: CGFloat) {
        switch kind {
        case .connector:
            let count = 4
            for index in 0..<count {
                let socket = SKShapeNode(circleOfRadius: max(3.0, blockSize.height * 0.095))
                socket.fillColor = WarmShelfPalette.clayInk.withAlpha(0.035)
                socket.strokeColor = WarmShelfPalette.paperHighlight.withAlpha(0.05)
                socket.lineWidth = 0.8
                socket.position = CGPoint(
                    x: -blockSize.width * 0.30 + CGFloat(index) * blockSize.width * 0.20,
                    y: 0
                )
                socket.zPosition = 2.6
                addChild(socket)
            }
        case .king:
            for index in 0..<3 {
                let bead = SKShapeNode(circleOfRadius: max(2.8, blockSize.width * 0.045))
                bead.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.16)
                bead.strokeColor = .clear
                bead.position = CGPoint(
                    x: (CGFloat(index) - 1) * blockSize.width * 0.18,
                    y: blockSize.height * 0.23
                )
                bead.zPosition = 2.7
                addChild(bead)
            }
        default:
            return
        }
    }

    private func applyBaseMaterialTexture() {
        if kind.isRound {
            ProceduralTexture.addCircularSpeckles(
                to: self,
                radius: blockSize.width * 0.48,
                count: 9,
                alpha: 0.030...0.085,
                dotRadius: 0.6...1.7,
                zPosition: 1.4
            )
            return
        }

        let rect = CGRect(
            x: -blockSize.width * 0.42,
            y: -blockSize.height * 0.34,
            width: blockSize.width * 0.84,
            height: blockSize.height * 0.68
        )
        ProceduralTexture.addSoftSpeckles(
            to: self,
            in: rect,
            count: kind.isTriangle ? 5 : 9,
            alpha: 0.026...0.075,
            radius: 0.55...1.55,
            zPosition: 1.35
        )
        ProceduralTexture.addEdgeWobbleDots(
            to: self,
            in: CGRect(x: -blockSize.width / 2, y: -blockSize.height / 2, width: blockSize.width, height: blockSize.height),
            count: kind.isTriangle ? 8 : 12,
            zPosition: 1.2
        )
    }

    private func addSpeckles(count: Int) {
        for index in 0..<count {
            let fleck = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.7...1.9))
            let color = index.isMultiple(of: 3) ? WarmShelfPalette.clayInk : WarmShelfPalette.paperHighlight
            fleck.fillColor = color.withAlpha(index.isMultiple(of: 3) ? 0.035 : 0.10)
            fleck.strokeColor = .clear
            fleck.position = randomTexturePoint()
            fleck.zPosition = 2
            addChild(fleck)
        }
    }

    private func addGrooves(radius: CGFloat) {
        let isVertical = blockSize.height > blockSize.width * 1.18
        let grooveCount = 1

        for _ in 0..<grooveCount {
            let grooveSize = isVertical
                ? CGSize(width: blockSize.width * 0.085, height: blockSize.height * 0.36)
                : CGSize(width: blockSize.width * 0.34, height: blockSize.height * 0.085)
            let groove = SKShapeNode(
                rect: CGRect(
                    x: -grooveSize.width / 2,
                    y: -grooveSize.height / 2,
                    width: grooveSize.width,
                    height: grooveSize.height
                ),
                cornerRadius: min(radius * 0.30, min(grooveSize.width, grooveSize.height) / 2)
            )
            groove.fillColor = WarmShelfPalette.clayInk.withAlpha(0.024)
            groove.strokeColor = .clear
            groove.lineWidth = 0
            groove.position = CGPoint(
                x: isVertical ? CGFloat.random(in: -blockSize.width * 0.08...blockSize.width * 0.12) : CGFloat.random(in: -blockSize.width * 0.04...blockSize.width * 0.04),
                y: isVertical ? CGFloat.random(in: -blockSize.height * 0.04...blockSize.height * 0.06) : CGFloat.random(in: -blockSize.height * 0.04...blockSize.height * 0.08)
            )
            groove.zRotation = CGFloat.random(in: -0.04...0.04)
            groove.zPosition = 2
            addChild(groove)
        }
    }

    private func randomTexturePoint() -> CGPoint {
        if kind.isRound {
            let angle = CGFloat.random(in: 0...(.pi * 2))
            let distance = CGFloat.random(in: 0...(blockSize.width * 0.34))
            return CGPoint(x: cos(angle) * distance, y: sin(angle) * distance)
        }

        if kind.isTriangle {
            return CGPoint(
                x: CGFloat.random(in: -blockSize.width * 0.18...blockSize.width * 0.18),
                y: CGFloat.random(in: -blockSize.height * 0.24...blockSize.height * 0.04)
            )
        }

        return CGPoint(
            x: CGFloat.random(in: -blockSize.width * 0.32...blockSize.width * 0.32),
            y: CGFloat.random(in: -blockSize.height * 0.22...blockSize.height * 0.24)
        )
    }
}
