import SpriteKit
import UIKit

final class SoftDropScene: BaseToyScene {
    private var worldLayer = SKNode()
    private var platformLayer = SKNode()
    private var pieces: [SoftDropPieceNode] = []
    private var platforms: [SwitchPlatform] = []
    private var waitingPiece: SoftDropPieceNode?
    private var spawnIndex = 0
    private let maxPieces = 20
    private let platformNamePrefix = "softDrop.platform."

    private struct SwitchPlatform {
        let root: SKNode
        let surface: SKShapeNode
        let index: Int
        let bodySize: CGSize
        var leaningRight: Bool
    }

    private struct PieceSnapshot {
        let kind: SoftDropPieceKind
        let color: UIColor
        let xRatio: CGFloat
        let yRatio: CGFloat
        let zRotation: CGFloat
        let zPosition: CGFloat
        let velocity: CGVector
        let angularVelocity: CGFloat
    }

    private var pieceScale: CGFloat {
        if min(size.width, size.height) >= 700 {
            return size.width > size.height ? 1.34 : 1.46
        }
        return size.width > size.height ? 1.06 : 1.18
    }

    private var floorY: CGFloat {
        max(68, size.height * (size.width > size.height ? 0.17 : 0.14))
    }

    private let pieceColors: [UIColor] = [
        WarmShelfPalette.terracotta,
        WarmShelfPalette.sage,
        WarmShelfPalette.butter,
        WarmShelfPalette.waterBlue,
        WarmShelfPalette.lavender,
        WarmShelfPalette.sand
    ]

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        showsShelfReturnHandle = true
        ambientMoteInterval = 0.9
        physicsWorld.gravity = CGVector(dx: 0, dy: -5.4)
        physicsWorld.speed = 0.92
        rebuildWorld()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        let snapshots = snapshotPieces(oldSize: oldSize)
        let platformLeaning = platforms.map(\.leaningRight)
        rebuildWorld(preservingPieces: snapshots, platformLeaning: platformLeaning)
    }

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        keepPiecesGentle()
    }

    private func rebuildWorld(
        preservingPieces snapshots: [PieceSnapshot] = [],
        platformLeaning: [Bool] = []
    ) {
        guard size.width > 160, size.height > 160 else { return }

        worldLayer.removeFromParent()
        worldLayer = SKNode()
        worldLayer.zPosition = 15
        addChild(worldLayer)

        platformLayer.removeFromParent()
        platformLayer = SKNode()
        platformLayer.zPosition = 18
        worldLayer.addChild(platformLayer)

        pieces.removeAll()
        platforms.removeAll()
        waitingPiece = nil

        addFloor()
        addPlatforms(platformLeaning: platformLeaning)
        addWaitingPiece()
        if snapshots.isEmpty {
            seedOpeningPieces()
        } else {
            snapshots.forEach(restorePiece)
            prunePiecesIfNeeded()
        }
    }

    private func snapshotPieces(oldSize: CGSize) -> [PieceSnapshot] {
        guard oldSize.width > 160, oldSize.height > 160 else { return [] }

        return pieces.compactMap { piece in
            guard piece.parent != nil, piece !== waitingPiece else { return nil }
            return PieceSnapshot(
                kind: piece.kind,
                color: piece.pieceColor,
                xRatio: (piece.position.x / oldSize.width).clamped(to: -0.2...1.2),
                yRatio: (piece.position.y / oldSize.height).clamped(to: -0.2...1.4),
                zRotation: piece.zRotation,
                zPosition: piece.zPosition,
                velocity: piece.physicsBody?.velocity ?? .zero,
                angularVelocity: piece.physicsBody?.angularVelocity ?? 0
            )
        }
    }

    private func addFloor() {
        let body = SKNode()
        body.name = "softDrop.floor.body"
        body.physicsBody = SKPhysicsBody(
            edgeFrom: CGPoint(x: -120, y: floorY),
            to: CGPoint(x: size.width + 120, y: floorY)
        )
        body.physicsBody?.friction = 0.96
        body.physicsBody?.restitution = 0.04
        body.physicsBody?.categoryBitMask = PhysicsCategory.softDropSurface
        body.physicsBody?.collisionBitMask = PhysicsCategory.softDropPiece
        worldLayer.addChild(body)

        let leftGuard = SKNode()
        leftGuard.physicsBody = SKPhysicsBody(
            edgeFrom: CGPoint(x: -88, y: floorY - 40),
            to: CGPoint(x: -88, y: size.height + 120)
        )
        leftGuard.physicsBody?.friction = 0.9
        leftGuard.physicsBody?.categoryBitMask = PhysicsCategory.wall
        leftGuard.physicsBody?.collisionBitMask = PhysicsCategory.softDropPiece
        worldLayer.addChild(leftGuard)

        let rightGuard = SKNode()
        rightGuard.physicsBody = SKPhysicsBody(
            edgeFrom: CGPoint(x: size.width + 88, y: floorY - 40),
            to: CGPoint(x: size.width + 88, y: size.height + 120)
        )
        rightGuard.physicsBody?.friction = 0.9
        rightGuard.physicsBody?.categoryBitMask = PhysicsCategory.wall
        rightGuard.physicsBody?.collisionBitMask = PhysicsCategory.softDropPiece
        worldLayer.addChild(rightGuard)

        let zone = SKShapeNode(rectOf: CGSize(width: size.width, height: floorY + 18))
        zone.fillColor = WarmShelfPalette.warmCream.withAlpha(0.14)
        zone.strokeColor = .clear
        zone.position = CGPoint(x: size.width / 2, y: (floorY + 18) / 2)
        zone.zPosition = -4
        worldLayer.addChild(zone)

        let shadow = makeRoundedRect(
            size: CGSize(width: size.width * 0.84, height: min(42, size.height * 0.035)),
            radius: 18,
            fill: WarmShelfPalette.contactShadow.withAlpha(0.026)
        )
        shadow.position = CGPoint(x: size.width / 2, y: floorY - 16)
        shadow.zPosition = -2
        worldLayer.addChild(shadow)

        let ledge = makeRoundedRect(
            size: CGSize(width: size.width + 90, height: min(24, size.height * 0.026)),
            radius: 12,
            fill: WarmShelfPalette.sand.withAlpha(0.34)
        )
        ledge.position = CGPoint(x: size.width / 2, y: floorY)
        ledge.zPosition = -1
        worldLayer.addChild(ledge)
    }

    private func addPlatforms(platformLeaning: [Bool] = []) {
        let count = size.width > size.height ? 4 : 3
        let top = size.height * (size.width > size.height ? 0.72 : 0.66)
        let bottom = floorY + size.height * 0.16
        let gap = count == 1 ? 0 : (top - bottom) / CGFloat(count - 1)

        for index in 0..<count {
            let y = bottom + CGFloat(index) * gap
            let xBase = size.width * (index.isMultiple(of: 2) ? 0.34 : 0.66)
            let x = size.width > size.height
                ? size.width * (0.24 + CGFloat(index) * 0.17)
                : xBase
            addPlatform(
                index: index,
                at: CGPoint(x: x, y: y),
                leaningRight: platformLeaning.indices.contains(index) ? platformLeaning[index] : index.isMultiple(of: 2)
            )
        }
    }

    private func addPlatform(index: Int, at position: CGPoint, leaningRight: Bool) {
        let root = SKNode()
        root.name = "\(platformNamePrefix)\(index)"
        root.position = position
        root.zPosition = CGFloat(10 + index)
        platformLayer.addChild(root)

        let width = min(size.width * (size.width > size.height ? 0.18 : 0.44), min(size.height * 0.34, 260))
        let height = max(18, width * 0.13)

        let shadow = makeRoundedRect(
            size: CGSize(width: width * 0.92, height: height * 0.76),
            radius: height * 0.38,
            fill: WarmShelfPalette.contactShadow.withAlpha(0.08)
        )
        shadow.position = CGPoint(x: 5, y: -height * 0.58)
        shadow.zPosition = -2
        root.addChild(shadow)

        let surface = makeRoundedRect(
            size: CGSize(width: width, height: height),
            radius: height / 2,
            fill: platformColor(index: index).withAlpha(0.76),
            stroke: WarmShelfPalette.cocoa.withAlpha(0.05)
        )
        surface.name = "\(platformNamePrefix)\(index).surface"
        surface.lineWidth = 1
        surface.zPosition = 0
        root.addChild(surface)

        let highlight = makeRoundedRect(
            size: CGSize(width: width * 0.46, height: max(4, height * 0.18)),
            radius: max(2, height * 0.09),
            fill: WarmShelfPalette.paperHighlight.withAlpha(0.24)
        )
        highlight.position = CGPoint(x: -width * 0.16, y: height * 0.13)
        highlight.zPosition = 1
        root.addChild(highlight)

        let hit = SKShapeNode(rectOf: CGSize(width: width * 1.42, height: height * 4.0), cornerRadius: height * 1.4)
        hit.name = "\(platformNamePrefix)\(index).hit"
        hit.fillColor = .clear
        hit.strokeColor = .clear
        hit.zPosition = 3
        root.addChild(hit)

        root.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: width, height: height))
        root.physicsBody?.isDynamic = false
        root.physicsBody?.friction = 0.88
        root.physicsBody?.restitution = 0.22
        root.physicsBody?.categoryBitMask = PhysicsCategory.softDropSurface
        root.physicsBody?.collisionBitMask = PhysicsCategory.softDropPiece
        root.zRotation = platformAngle(leaningRight: leaningRight)

        platforms.append(SwitchPlatform(
            root: root,
            surface: surface,
            index: index,
            bodySize: CGSize(width: width, height: height),
            leaningRight: leaningRight
        ))
        AmbientAnimator.idleDrift(node: root, x: index.isMultiple(of: 2) ? 5 : -5, y: 3, duration: 5.8 + Double(index) * 0.5)
        runPlatformInvite(on: root, leaningRight: leaningRight, delay: Double(index) * 0.4)
    }

    private func platformColor(index: Int) -> UIColor {
        switch index % 4 {
        case 0: return WarmShelfPalette.sage
        case 1: return WarmShelfPalette.sand
        case 2: return WarmShelfPalette.waterBlue
        default: return WarmShelfPalette.petal
        }
    }

    private func platformAngle(leaningRight: Bool) -> CGFloat {
        leaningRight ? -0.16 : 0.16
    }

    private func addWaitingPiece() {
        let piece = makePiece()
        piece.name = "softDrop.waitingPiece"
        piece.physicsBody = nil
        piece.position = CGPoint(x: size.width / 2, y: size.height * 0.82)
        piece.zPosition = 30
        worldLayer.addChild(piece)
        waitingPiece = piece

        let rotateLeft = SKAction.rotate(toAngle: -0.12, duration: 0.72, shortestUnitArc: true)
        let rotateRight = SKAction.rotate(toAngle: 0.12, duration: 0.86, shortestUnitArc: true)
        let lift = SKAction.moveBy(x: 0, y: 7, duration: 0.72)
        let settle = SKAction.moveBy(x: 0, y: -7, duration: 0.86)
        [rotateLeft, rotateRight, lift, settle].forEach { $0.timingMode = .easeInEaseOut }
        let inviteDown = SKAction.moveBy(x: 0, y: -22, duration: 0.24)
        let inviteBack = SKAction.moveBy(x: 0, y: 22, duration: 0.46)
        inviteDown.timingMode = .easeIn
        inviteBack.timingMode = .easeOut
        piece.run(.repeatForever(.sequence([
            .group([rotateLeft, lift]),
            .group([rotateRight, settle]),
            .wait(forDuration: 1.8),
            .group([inviteDown, .scale(to: 0.96, duration: 0.24)]),
            .group([inviteBack, .scale(to: 1.0, duration: 0.46)]),
            .wait(forDuration: 1.2)
        ])), withKey: "waitingWobble")
    }

    private func seedOpeningPieces() {
        let seedCount = size.width > size.height ? 2 : 1
        for i in 0..<seedCount {
            let x = size.width * (seedCount == 1 ? 0.50 : (0.42 + CGFloat(i) * 0.16))
            spawnPiece(atX: x, fromY: size.height * (0.72 + CGFloat(i) * 0.05), initialImpulse: CGVector(dx: CGFloat.random(in: -0.2...0.2), dy: 0))
        }
    }

    private func makePiece() -> SoftDropPieceNode {
        let kind = SoftDropPieceKind.allCases[spawnIndex % SoftDropPieceKind.allCases.count]
        let color = pieceColors[spawnIndex % pieceColors.count]
        spawnIndex += 1
        return SoftDropPieceNode(kind: kind, color: color, scale: pieceScale)
    }

    private func spawnPiece(atX x: CGFloat, fromY y: CGFloat? = nil, initialImpulse: CGVector? = nil) {
        let piece = makePiece()
        let radius = max(piece.pieceSize.width, piece.pieceSize.height) / 2
        let clampedX = x.clamped(to: radius + 18...(size.width - radius - 18))
        piece.position = CGPoint(x: clampedX, y: y ?? min(size.height - radius - 28, max(size.height * 0.72, floorY + 260)))
        piece.zRotation = CGFloat.random(in: -0.18...0.18)
        worldLayer.addChild(piece)
        pieces.append(piece)
        piece.wake()

        let impulse = initialImpulse ?? CGVector(dx: CGFloat.random(in: -0.35...0.35), dy: CGFloat.random(in: -0.12...0.06))
        piece.physicsBody?.applyImpulse(impulse)
        piece.physicsBody?.applyAngularImpulse(CGFloat.random(in: -0.018...0.018))

        TouchFeedbackAnimator.tactileSpark(
            in: self,
            at: CGPoint(x: clampedX, y: piece.position.y),
            color: piece.pieceColor,
            count: 4,
            includesRipple: true
        )
        audioManager.playSoftTap()
        HapticsManager.shared.softTap()
        prunePiecesIfNeeded()
        refreshWaitingPiece()
    }

    private func restorePiece(_ snapshot: PieceSnapshot) {
        let piece = SoftDropPieceNode(kind: snapshot.kind, color: snapshot.color, scale: pieceScale)
        let radius = max(piece.pieceSize.width, piece.pieceSize.height) / 2
        piece.position = CGPoint(
            x: (size.width * snapshot.xRatio).clamped(to: radius + 18...(size.width - radius - 18)),
            y: (size.height * snapshot.yRatio).clamped(to: floorY + radius...(size.height + radius * 2))
        )
        piece.zRotation = snapshot.zRotation
        piece.zPosition = snapshot.zPosition
        worldLayer.addChild(piece)
        pieces.append(piece)
        piece.physicsBody?.velocity = snapshot.velocity
        piece.physicsBody?.angularVelocity = snapshot.angularVelocity
    }

    private func refreshWaitingPiece() {
        waitingPiece?.removeFromParent()
        addWaitingPiece()
    }

    private func prunePiecesIfNeeded() {
        while pieces.count > maxPieces {
            let old = pieces.removeFirst()
            old.physicsBody = nil
            let fade = SKAction.fadeOut(withDuration: 0.25)
            let shrink = SKAction.scale(to: 0.75, duration: 0.25)
            old.run(.sequence([.group([fade, shrink]), .removeFromParent()]))
        }
    }

    private func keepPiecesGentle() {
        for piece in pieces where piece.parent != nil {
            if piece.position.y < floorY - 80 {
                piece.position.y = floorY + piece.pieceSize.height / 2 + 8
                piece.physicsBody?.velocity = CGVector(dx: CGFloat.random(in: -16...16), dy: 18)
            }

            let maxVelocity: CGFloat = 520
            if let body = piece.physicsBody {
                body.velocity.dx = body.velocity.dx.clamped(to: -maxVelocity...maxVelocity)
                body.velocity.dy = body.velocity.dy.clamped(to: -maxVelocity...maxVelocity)
            }
        }
    }

    private func togglePlatform(at point: CGPoint) -> Bool {
        guard let index = platformIndex(at: point), platforms.indices.contains(index) else { return false }
        platforms[index].leaningRight.toggle()
        let platform = platforms[index]
        let angle = platformAngle(leaningRight: platform.leaningRight)

        platform.root.removeAction(forKey: "toggle")
        platform.root.removeAction(forKey: "platformInvite")
        let turn = SKAction.rotate(toAngle: angle, duration: 0.22, shortestUnitArc: true)
        let squash = SKAction.scaleY(to: 0.94, duration: 0.08)
        let unsquash = SKAction.scaleY(to: 1.0, duration: 0.20)
        [turn, squash, unsquash].forEach { $0.timingMode = .easeInEaseOut }
        let refreshBody = SKAction.run { [weak root = platform.root] in
            guard let root else { return }
            let body = SKPhysicsBody(rectangleOf: platform.bodySize)
            body.isDynamic = false
            body.friction = 0.88
            body.restitution = 0.22
            body.categoryBitMask = PhysicsCategory.softDropSurface
            body.collisionBitMask = PhysicsCategory.softDropPiece
            root.physicsBody = body
        }
        platform.root.run(.sequence([
            .group([turn, .sequence([squash, unsquash])]),
            refreshBody
        ]), withKey: "toggle")

        for piece in pieces where piece.parent != nil {
            let dx = piece.position.x - platform.root.position.x
            let dy = abs(piece.position.y - platform.root.position.y)
            guard abs(dx) < size.width * 0.30, dy < size.height * 0.20 else { continue }
            piece.physicsBody?.applyImpulse(CGVector(dx: platform.leaningRight ? 1.2 : -1.2, dy: 0.9))
            piece.wake()
        }

        TouchFeedbackAnimator.tactileSpark(
            in: self,
            at: platform.root.position,
            color: platformColor(index: index),
            count: 5,
            includesRipple: true
        )
        audioManager.playSoftTap()
        HapticsManager.shared.blockSettle()
        runPlatformInvite(on: platform.root, leaningRight: platform.leaningRight, delay: 2.0)
        return true
    }

    private func runPlatformInvite(on root: SKNode, leaningRight: Bool, delay: TimeInterval) {
        root.removeAction(forKey: "platformInvite")
        let baseAngle = platformAngle(leaningRight: leaningRight)
        let tipA = SKAction.rotate(toAngle: baseAngle + (leaningRight ? -0.045 : 0.045), duration: 0.42, shortestUnitArc: true)
        let tipB = SKAction.rotate(toAngle: baseAngle, duration: 0.58, shortestUnitArc: true)
        [tipA, tipB].forEach { $0.timingMode = .easeInEaseOut }
        root.run(.repeatForever(.sequence([
            .wait(forDuration: delay),
            tipA,
            tipB,
            .wait(forDuration: 3.0)
        ])), withKey: "platformInvite")
    }

    private func platformIndex(at point: CGPoint) -> Int? {
        for node in nodes(at: point) {
            var current: SKNode? = node
            while let unwrapped = current {
                if let name = unwrapped.name, name.hasPrefix(platformNamePrefix) {
                    let remainder = name.dropFirst(platformNamePrefix.count)
                    let indexText = remainder.split(separator: ".").first.map(String.init) ?? ""
                    return Int(indexText)
                }
                current = unwrapped.parent
            }
        }
        return nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self)
            if consumeShelfReturnTouch(at: point) {
                continue
            }
            if togglePlatform(at: point) {
                continue
            }
            spawnPiece(atX: point.x)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {}

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {}

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {}

    override func accessibilityElements(in view: SKView) -> [UIAccessibilityElement] {
        var elements = super.accessibilityElements(in: view)
        elements.append(makeAccessibilityElement(
            in: view,
            label: "Drop a soft piece",
            scenePosition: CGPoint(x: size.width / 2, y: size.height * 0.62),
            size: CGSize(width: size.width, height: size.height * 0.72),
            traits: .button
        ))
        return elements
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
