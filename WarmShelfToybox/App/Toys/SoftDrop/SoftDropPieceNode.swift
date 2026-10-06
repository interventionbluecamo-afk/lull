import SpriteKit
import UIKit

enum SoftDropPieceKind: CaseIterable {
    case bead
    case pebble
    case capsule
    case button

    var baseSize: CGSize {
        switch self {
        case .bead:
            return CGSize(width: 58, height: 58)
        case .pebble:
            return CGSize(width: 72, height: 54)
        case .capsule:
            return CGSize(width: 84, height: 42)
        case .button:
            return CGSize(width: 64, height: 64)
        }
    }

    var accessibilityName: String {
        switch self {
        case .bead: return "soft bead"
        case .pebble: return "soft pebble"
        case .capsule: return "soft capsule"
        case .button: return "soft button"
        }
    }
}

final class SoftDropPieceNode: SKNode {
    let kind: SoftDropPieceKind
    let pieceColor: UIColor
    let pieceSize: CGSize

    init(kind: SoftDropPieceKind, color: UIColor, scale: CGFloat) {
        self.kind = kind
        self.pieceColor = color
        self.pieceSize = CGSize(
            width: kind.baseSize.width * scale,
            height: kind.baseSize.height * scale
        )
        super.init()

        name = "softDrop.piece"
        zPosition = 24
        buildVisuals()
        configurePhysics()
        accessibilityLabel = kind.accessibilityName
        isAccessibilityElement = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func wake() {
        let up = SKAction.scale(to: 1.035, duration: 0.12)
        let down = SKAction.scale(to: 1.0, duration: 0.24)
        up.timingMode = .easeOut
        down.timingMode = .easeInEaseOut
        run(.sequence([up, down]))
    }

    private func buildVisuals() {
        let shadow = SKShapeNode(ellipseOf: CGSize(width: pieceSize.width * 0.92, height: max(9, pieceSize.height * 0.22)))
        shadow.fillColor = WarmShelfPalette.contactShadow.withAlpha(0.045)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 4, y: -pieceSize.height * 0.48)
        shadow.zPosition = -2
        addChild(shadow)

        let body: SKShapeNode
        switch kind {
        case .bead, .button:
            body = SKShapeNode(circleOfRadius: pieceSize.width / 2)
        case .pebble, .capsule:
            body = SKShapeNode(
                rect: CGRect(x: -pieceSize.width / 2, y: -pieceSize.height / 2, width: pieceSize.width, height: pieceSize.height),
                cornerRadius: pieceSize.height * 0.45
            )
        }

        body.fillColor = pieceColor
        body.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.07)
        body.lineWidth = max(1.2, pieceSize.width * 0.018)
        body.zPosition = 0
        addChild(body)

        let inset = SKShapeNode(
            rect: CGRect(
                x: -pieceSize.width * 0.23,
                y: pieceSize.height * 0.16,
                width: pieceSize.width * 0.42,
                height: max(7, pieceSize.height * 0.13)
            ),
            cornerRadius: max(4, pieceSize.height * 0.07)
        )
        inset.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.22)
        inset.strokeColor = .clear
        inset.zPosition = 2
        inset.zRotation = kind == .bead ? -0.20 : 0
        addChild(inset)

        if kind == .button {
            let inner = SKShapeNode(circleOfRadius: pieceSize.width * 0.21)
            inner.fillColor = WarmShelfPalette.warmCream.withAlpha(0.08)
            inner.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.06)
            inner.lineWidth = max(1, pieceSize.width * 0.016)
            inner.zPosition = 1
            addChild(inner)
        }

        for _ in 0..<5 {
            let fleck = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.8...1.8))
            fleck.fillColor = WarmShelfPalette.paperHighlight.withAlpha(CGFloat.random(in: 0.08...0.16))
            fleck.strokeColor = .clear
            fleck.position = CGPoint(
                x: CGFloat.random(in: -pieceSize.width * 0.26...pieceSize.width * 0.26),
                y: CGFloat.random(in: -pieceSize.height * 0.22...pieceSize.height * 0.24)
            )
            fleck.zPosition = 3
            addChild(fleck)
        }
    }

    private func configurePhysics() {
        switch kind {
        case .bead, .button:
            physicsBody = SKPhysicsBody(circleOfRadius: pieceSize.width * 0.49)
        case .pebble, .capsule:
            physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: pieceSize.width * 0.92, height: pieceSize.height * 0.88))
        }

        physicsBody?.allowsRotation = true
        physicsBody?.mass = kind == .capsule ? 0.36 : 0.28
        physicsBody?.friction = 0.88
        physicsBody?.restitution = 0.18
        physicsBody?.linearDamping = 0.28
        physicsBody?.angularDamping = 0.45
        physicsBody?.categoryBitMask = PhysicsCategory.softDropPiece
        physicsBody?.collisionBitMask = PhysicsCategory.softDropPiece | PhysicsCategory.softDropSurface | PhysicsCategory.wall
        physicsBody?.contactTestBitMask = PhysicsCategory.softDropSurface
    }
}
