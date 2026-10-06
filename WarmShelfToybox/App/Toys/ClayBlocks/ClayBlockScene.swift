import SpriteKit

final class ClayBlockScene: BaseToyScene {
    private var worldLayer = SKNode()
    private var selectedBlock: ClayBlockNode?
    private var activeBlockTouch: UITouch?
    private var touchOffset = CGPoint.zero
    private var lastTouchPoint = CGPoint.zero
    private var lastTouchTime: TimeInterval = 0
    private var releaseVelocity = CGVector.zero
    private let freshSupplyBlockName = "clayBlock.freshSupply"
    private let inviteBlockName = "clayBlock.invite"
    private let heightMemoryMarkName = "clayBlock.heightMemoryMark"
    private let supplyTrayName = "clayBlock.supplyTray"
    private let maxBlocks = 32
    private var supplyTraySceneRect = CGRect.zero
    private var cameraOffsetY: CGFloat = 0
    private var bestStackHeightAboveSurface: CGFloat = 0
    private var heightMemoryPrimed = false
    private var lastHeightMemoryTime: TimeInterval = 0
    private var lastGloriousTumbleTime: TimeInterval = 0
    private var keepBlocksInPlayFrameCounter = 0
    private var recentSquishTimes: [ObjectIdentifier: TimeInterval] = [:]
    private var lastSceneUpdateTime: TimeInterval = 0
    private let blockColors: [UIColor] = [
        WarmShelfPalette.terracotta,
        WarmShelfPalette.sage,
        WarmShelfPalette.sand,
        WarmShelfPalette.butter,
        WarmShelfPalette.waterBlue.withAlpha(0.82),
        WarmShelfPalette.lavender.withAlpha(0.82),
        UIColor(hex: 0xA87D61)
    ]
    private let blockKinds: [ClayBlockKind] = [
        .brick,
        .cube,
        .plank,
        .brick,
        .smallBrick,
        .cube,
        .longPlank,
        .brick,
        .plank,
        .cylinder,
        .cube
    ]
    private struct BlockSnapshot {
        let kind: ClayBlockKind
        let color: UIColor
        let textureStyle: ClayBlockTextureStyle
        let xRatio: CGFloat
        let yOffsetFromSurface: CGFloat
        let zRotation: CGFloat
        let zPosition: CGFloat
    }

    private var playSurfaceTopY: CGFloat {
        playSurfaceTopY(for: size)
    }

    private var visibleWorldTopY: CGFloat {
        cameraOffsetY + size.height
    }

    private var visibleWorldMidY: CGFloat {
        cameraOffsetY + size.height / 2
    }

    private var isPadLikeCanvas: Bool {
        min(size.width, size.height) >= 700
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        ambientMoteInterval = 0.9
        physicsWorld.gravity = CGVector(dx: 0, dy: -4.8)
        physicsWorld.speed = 1.0
        rebuildWorld()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        let snapshots = snapshotBlocks(oldSize: oldSize)
        rebuildWorld(preserving: snapshots)
    }

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        lastSceneUpdateTime = currentTime
        updateVerticalFollow()
        updateSupplyTrayPlacement()
        keepBlocksInPlayFrameCounter += 1
        if keepBlocksInPlayFrameCounter >= 3 {
            keepBlocksInPlayFrameCounter = 0
            keepBlocksInPlay()
        }
        updateHeightMemory(currentTime: currentTime)
        updateSquishImpacts(currentTime: currentTime)
        updateGloriousTumble(currentTime: currentTime)
    }

    private func rebuildWorld(preserving snapshots: [BlockSnapshot] = []) {
        guard size.width > 160, size.height > 160 else { return }

        selectedBlock = nil
        activeBlockTouch = nil
        bestStackHeightAboveSurface = 0
        heightMemoryPrimed = false
        lastHeightMemoryTime = 0
        lastGloriousTumbleTime = 0
        keepBlocksInPlayFrameCounter = 0
        recentSquishTimes.removeAll()
        lastSceneUpdateTime = 0
        childNode(withName: supplyTrayName)?.removeFromParent()
        worldLayer.removeFromParent()
        worldLayer = SKNode()
        worldLayer.zPosition = 15
        worldLayer.position = CGPoint(x: 0, y: -cameraOffsetY)
        addChild(worldLayer)

        addPlaySurface()
        snapshots.isEmpty ? addBlocks() : addBlocks(from: snapshots)
    }

    private func playSurfaceTopY(for sceneSize: CGSize) -> CGFloat {
        let ratio: CGFloat = sceneSize.width > sceneSize.height ? 0.20 : 0.18
        return max(76, min(sceneSize.height * ratio, sceneSize.height - 142))
    }

    private var blockScale: CGFloat {
        if isPadLikeCanvas {
            return size.width > size.height
                ? min(1.50, max(1.28, size.height / 530))
                : min(1.60, max(1.34, size.width / 640))
        }

        if size.width > size.height {
            return min(1.28, max(1.06, size.height / 340))
        }

        return min(1.42, max(1.16, size.width / 300))
    }

    private func scaledSize(for kind: ClayBlockKind) -> CGSize {
        CGSize(width: kind.size.width * blockScale, height: kind.size.height * blockScale)
    }

    private func snapshotBlocks(oldSize: CGSize) -> [BlockSnapshot] {
        guard oldSize.width > 160, oldSize.height > 160 else { return [] }

        let oldSurfaceTopY = playSurfaceTopY(for: oldSize)
        return worldLayer.children.compactMap { child -> BlockSnapshot? in
            guard let block = child as? ClayBlockNode else { return nil }

            let xRatio = (block.position.x / oldSize.width).clamped(to: 0...1)
            return BlockSnapshot(
                kind: block.kind,
                color: block.blockColor,
                textureStyle: block.textureStyle,
                xRatio: xRatio,
                yOffsetFromSurface: max(0, block.position.y - oldSurfaceTopY),
                zRotation: block.zRotation,
                zPosition: block.zPosition
            )
        }
    }

    private func addPlaySurface() {
        let surfaceTopY = playSurfaceTopY
        let visualWidth = ledgeVisualWidth
        let physicsWidth = size.width + 260

        let surfaceBody = SKNode()
        surfaceBody.name = "clayBlockPlaySurface.body"
        surfaceBody.physicsBody = SKPhysicsBody(
            edgeFrom: CGPoint(x: (size.width - physicsWidth) / 2, y: surfaceTopY),
            to: CGPoint(x: (size.width + physicsWidth) / 2, y: surfaceTopY)
        )
        surfaceBody.physicsBody?.friction = 0.94
        surfaceBody.physicsBody?.restitution = 0.0
        surfaceBody.physicsBody?.categoryBitMask = PhysicsCategory.surface
        surfaceBody.physicsBody?.collisionBitMask = PhysicsCategory.block
        surfaceBody.physicsBody?.contactTestBitMask = PhysicsCategory.block
        worldLayer.addChild(surfaceBody)
        physicsBody = nil

        let ledgeShadow = makeRoundedRect(
            size: CGSize(width: visualWidth * 0.98, height: isPadLikeCanvas ? 42 : 34),
            radius: isPadLikeCanvas ? 21 : 17,
            fill: WarmShelfPalette.cocoa.withAlpha(0.024)
        )
        ledgeShadow.position = CGPoint(x: size.width / 2, y: surfaceTopY - (isPadLikeCanvas ? 22 : 18))
        ledgeShadow.zPosition = -2
        worldLayer.addChild(ledgeShadow)

        let mat = makeRoundedRect(
            size: CGSize(width: visualWidth * 0.96, height: isPadLikeCanvas ? 48 : 38),
            radius: isPadLikeCanvas ? 24 : 19,
            fill: WarmShelfPalette.warmCream.withAlpha(0.13)
        )
        mat.position = CGPoint(x: size.width / 2, y: surfaceTopY - (isPadLikeCanvas ? 30 : 24))
        mat.zPosition = -1
        worldLayer.addChild(mat)

        let topEdge = makeRoundedRect(
            size: CGSize(width: visualWidth, height: isPadLikeCanvas ? 18 : 15),
            radius: isPadLikeCanvas ? 9 : 7.5,
            fill: WarmShelfPalette.sand.withAlpha(0.42)
        )
        topEdge.position = CGPoint(x: size.width / 2, y: surfaceTopY)
        topEdge.zPosition = 0
        worldLayer.addChild(topEdge)

        let highlight = makeRoundedRect(
            size: CGSize(width: visualWidth * 0.94, height: 4),
            radius: 2,
            fill: WarmShelfPalette.paperHighlight.withAlpha(0.20)
        )
        highlight.position = CGPoint(x: size.width / 2, y: surfaceTopY + 6)
        highlight.zPosition = 1
        worldLayer.addChild(highlight)

        for _ in 0..<12 {
            let fleck = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.8...2.1))
            fleck.fillColor = WarmShelfPalette.paperHighlight.withAlpha(CGFloat.random(in: 0.08...0.16))
            fleck.strokeColor = .clear
            fleck.position = CGPoint(
                x: CGFloat.random(in: size.width * 0.12...size.width * 0.88),
                y: CGFloat.random(in: max(14, surfaceTopY - 42)...max(16, surfaceTopY - 14))
            )
            fleck.zPosition = 1
            worldLayer.addChild(fleck)
        }

        AmbientAnimator.idleDrift(node: topEdge, x: 4, y: 1.5, duration: 7.4)
        addSurfaceLife(around: surfaceTopY, width: visualWidth)
        addSupplyTray(at: surfaceTopY)
    }

    private func addSupplyTray(at surfaceTopY: CGFloat) {
        let trayW: CGFloat = isPadLikeCanvas ? 128 : 96
        let trayH: CGFloat = isPadLikeCanvas ? 90 : 70

        childNode(withName: supplyTrayName)?.removeFromParent()

        let trayRoot = SKNode()
        trayRoot.name = supplyTrayName
        trayRoot.position = supplyTrayScreenPosition(trayW: trayW, trayH: trayH, surfaceTopY: surfaceTopY)
        trayRoot.zPosition = 112
        addChild(trayRoot)

        let shadow = makeRoundedRect(
            size: CGSize(width: trayW * 0.92, height: trayH * 0.28),
            radius: trayH * 0.14,
            fill: WarmShelfPalette.cocoa.withAlpha(0.038)
        )
        shadow.position = CGPoint(x: 0, y: -trayH * 0.46)
        shadow.zPosition = 1
        trayRoot.addChild(shadow)

        let tray = makeRoundedRect(
            size: CGSize(width: trayW, height: trayH),
            radius: trayH * 0.20,
            fill: WarmShelfPalette.warmCream.withAlpha(0.52),
            stroke: WarmShelfPalette.sand.withAlpha(0.26)
        )
        tray.lineWidth = max(1.2, trayH * 0.022)
        tray.name = supplyTrayName
        tray.position = .zero
        tray.zPosition = 5
        trayRoot.addChild(tray)

        let miniColors: [UIColor] = [
            WarmShelfPalette.terracotta,
            WarmShelfPalette.sage,
            WarmShelfPalette.butter
        ]
        let miniW = trayW * 0.58
        let miniH = trayH * 0.17
        let miniShapeRoot = SKNode()
        miniShapeRoot.position = .zero
        miniShapeRoot.zPosition = 6
        trayRoot.addChild(miniShapeRoot)

        for i in 0..<3 {
            let mini = makeRoundedRect(
                size: CGSize(width: miniW, height: miniH),
                radius: miniH * 0.38,
                fill: miniColors[i].withAlpha(0.72)
            )
            mini.position = CGPoint(
                x: CGFloat.random(in: -trayW * 0.12...trayW * 0.12),
                y: -trayH * 0.18 + CGFloat(i) * (miniH + 4)
            )
            mini.zPosition = CGFloat(i)
            mini.zRotation = CGFloat.random(in: -0.08...0.08)
            miniShapeRoot.addChild(mini)
        }

        let tilt = SKAction.rotate(toAngle: 0.035, duration: 2.8, shortestUnitArc: true)
        let back = SKAction.rotate(toAngle: -0.02, duration: 2.4, shortestUnitArc: true)
        let center = SKAction.rotate(toAngle: 0, duration: 1.8, shortestUnitArc: true)
        [tilt, back, center].forEach { $0.timingMode = .easeInEaseOut }
        miniShapeRoot.run(.repeatForever(.sequence([tilt, back, center])))

        let shine = makeRoundedRect(
            size: CGSize(width: trayW * 0.62, height: max(3, trayH * 0.055)),
            radius: trayH * 0.028,
            fill: WarmShelfPalette.paperHighlight.withAlpha(0.22)
        )
        shine.position = CGPoint(x: 0, y: trayH * 0.30)
        shine.zPosition = 9
        trayRoot.addChild(shine)

        let frontLip = makeRoundedRect(
            size: CGSize(width: trayW * 0.84, height: max(5, trayH * 0.075)),
            radius: max(2.5, trayH * 0.038),
            fill: WarmShelfPalette.sand.withAlpha(0.18)
        )
        frontLip.position = CGPoint(x: 0, y: -trayH * 0.30)
        frontLip.zPosition = 8
        trayRoot.addChild(frontLip)

        AmbientAnimator.breathe(node: trayRoot, scale: 1.026, duration: 4.8)

        let trayHitW = trayW + 24
        let trayHitH = trayH + 24
        supplyTraySceneRect = CGRect(
            x: trayRoot.position.x - trayHitW / 2,
            y: trayRoot.position.y - trayHitH / 2,
            width: trayHitW,
            height: trayHitH
        )
    }

    private func supplyTrayScreenPosition(trayW: CGFloat, trayH: CGFloat, surfaceTopY: CGFloat) -> CGPoint {
        let x = min(
            max(trayW / 2 + 24, size.width * (size.width > size.height ? 0.13 : 0.18)),
            size.width - trayW / 2 - 24
        )
        let surfaceScreenY = surfaceTopY - cameraOffsetY
        let preferredY = surfaceScreenY + trayH / 2 + 8
        let minimumY = trayH / 2 + 24
        let maximumY = max(minimumY, size.height - trayH / 2 - 86)
        return CGPoint(x: x, y: preferredY.clamped(to: minimumY...maximumY))
    }

    private func updateSupplyTrayPlacement() {
        guard let trayRoot = childNode(withName: supplyTrayName) else { return }
        let trayW: CGFloat = isPadLikeCanvas ? 128 : 96
        let trayH: CGFloat = isPadLikeCanvas ? 90 : 70
        let newPosition = supplyTrayScreenPosition(trayW: trayW, trayH: trayH, surfaceTopY: playSurfaceTopY)
        trayRoot.position = CGPoint(
            x: trayRoot.position.x + (newPosition.x - trayRoot.position.x) * 0.18,
            y: trayRoot.position.y + (newPosition.y - trayRoot.position.y) * 0.18
        )
        supplyTraySceneRect = CGRect(
            x: trayRoot.position.x - (trayW + 24) / 2,
            y: trayRoot.position.y - (trayH + 24) / 2,
            width: trayW + 24,
            height: trayH + 24
        )
    }

    private var ledgeVisualWidth: CGFloat {
        size.width + 180
    }

    private func addBlocks() {
        let surfaceTopY = playSurfaceTopY
        let placements = proceduralStartingLayout()

        for (index, placement) in placements.enumerated() {
            let blockSize = scaledSize(for: placement.kind)
            let block = makeBlock(
                index: index,
                position: CGPoint(
                    x: clamp(
                        size.width * placement.xRatio,
                        min: playMinX(for: blockSize),
                        max: playMaxX(for: blockSize)
                    ),
                    y: surfaceTopY + blockSize.height / 2 + placement.yOffset
                ),
                kind: placement.kind,
                zRotation: placement.rotation
            )
            block.physicsBody?.velocity = CGVector(
                dx: CGFloat.random(in: -5...5),
                dy: CGFloat.random(in: -10...2)
            )
            block.physicsBody?.angularVelocity = CGFloat.random(in: -0.12...0.12)
            worldLayer.addChild(block)

            if index == placements.count - 1 {
                prepareInviteBlock(block)
            }
        }
    }

    private func proceduralStartingLayout() -> [(kind: ClayBlockKind, xRatio: CGFloat, yOffset: CGFloat, rotation: CGFloat)] {
        let centerX = size.width * 0.50
        let scale = blockScale

        let longPlank = scaledSize(for: .longPlank)
        let brick = scaledSize(for: .brick)
        let cube = scaledSize(for: .cube)

        let y0: CGFloat = 4
        let y1 = y0 + longPlank.height + 4
        let y2 = y1 + brick.height + 2
        let y3 = y2 + cube.height + 2
        let y4 = y3 + brick.height + 2

        let count = 5

        let authored: [(kind: ClayBlockKind, x: CGFloat, yOffset: CGFloat, rotation: CGFloat)] = [
            (.longPlank, centerX + scale * 1.0, y0, 0.006),
            (.brick, centerX - scale * 4.0, y1, -0.06),
            (.cube, centerX + scale * 5.0, y2, 0.10),
            (.smallBrick, centerX - scale * 2.0, y3, -0.15),
            (.smallBrick, centerX + scale * 6.0, y4, 0.28)
        ]

        return authored.prefix(count).map { placement in
            let xRatio = clamp(placement.x / size.width, min: 0.18, max: 0.82)
            let yOffset = placement.yOffset + CGFloat.random(in: -1...2)
            let rotation = placement.rotation + CGFloat.random(in: -0.015...0.015)
            return (placement.kind, xRatio, yOffset, rotation)
        }
    }

    private func prepareInviteBlock(_ block: ClayBlockNode) {
        block.name = inviteBlockName
        block.zPosition = 42
        runInviteWiggle(on: block)
    }

    private func runInviteWiggle(on block: ClayBlockNode) {
        let firstWait = SKAction.wait(forDuration: Double.random(in: 0.9...1.4))
        let nudge = SKAction.run { [weak self, weak block] in
            guard let self, let block, block.parent != nil else { return }
            guard block.name == self.inviteBlockName, block !== self.selectedBlock else { return }

            block.physicsBody?.applyImpulse(
                CGVector(
                    dx: CGFloat.random(in: -22...22),
                    dy: CGFloat.random(in: 5...11)
                )
            )
            block.physicsBody?.angularVelocity += CGFloat.random(in: -0.82...0.82)

            let pulseUp = SKAction.scale(to: 1.04, duration: 0.12)
            let pulseDown = SKAction.scale(to: 1.0, duration: 0.28)
            pulseUp.timingMode = .easeOut
            pulseDown.timingMode = .easeInEaseOut
            block.run(.sequence([pulseUp, pulseDown]), withKey: "invitePulse")
        }
        let rest = SKAction.wait(forDuration: Double.random(in: 2.4...3.7))
        block.run(.repeatForever(.sequence([
            firstWait,
            nudge,
            rest
        ])), withKey: "inviteWiggle")
    }

    private func addBlocks(from snapshots: [BlockSnapshot]) {
        let surfaceTopY = playSurfaceTopY

        for (index, snapshot) in snapshots.prefix(maxBlocks).enumerated() {
            let blockSize = scaledSize(for: snapshot.kind)
            let position = CGPoint(
                x: clamp(
                    size.width * snapshot.xRatio,
                    min: blockSize.width / 2 + 26,
                    max: size.width - blockSize.width / 2 - 26
                ),
                y: clamp(
                    surfaceTopY + snapshot.yOffsetFromSurface,
                    min: surfaceTopY + blockSize.height / 2 + 4,
                    max: max(size.height * 2.5, surfaceTopY + snapshot.yOffsetFromSurface + 1)
                )
            )
            let block = makeBlock(
                index: index,
                position: position,
                kind: snapshot.kind,
                color: snapshot.color,
                textureStyle: snapshot.textureStyle,
                zRotation: snapshot.zRotation
            )
            block.zPosition = snapshot.zPosition
            worldLayer.addChild(block)
        }
    }

    private func makeBlock(
        index: Int,
        position: CGPoint,
        kind overrideKind: ClayBlockKind? = nil,
        color overrideColor: UIColor? = nil,
        textureStyle overrideTextureStyle: ClayBlockTextureStyle? = nil,
        zRotation overrideRotation: CGFloat? = nil
    ) -> ClayBlockNode {
        let kind = overrideKind ?? blockKinds[index % blockKinds.count]
        let color = overrideColor ?? blockColors[index % blockColors.count].withAlpha(0.86)
        let textureStyle = overrideTextureStyle ?? ClayBlockTextureStyle.calmRandom()
        let block = ClayBlockNode(kind: kind, color: color, scale: blockScale, textureStyle: textureStyle)
        block.position = position
        block.zRotation = overrideRotation ?? CGFloat.random(in: -0.16...0.16)
        block.zPosition = CGFloat(index + 1)

        return block
    }

    private func addSurfaceLife(around surfaceTopY: CGFloat, width: CGFloat) {
        for index in 0..<7 {
            let seed = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.1...2.4))
            seed.fillColor = (index.isMultiple(of: 2) ? WarmShelfPalette.sand : WarmShelfPalette.paperHighlight)
                .withAlpha(CGFloat.random(in: 0.12...0.22))
            seed.strokeColor = .clear
            seed.position = CGPoint(
                x: size.width / 2 + CGFloat.random(in: -width * 0.43...width * 0.43),
                y: surfaceTopY + CGFloat.random(in: 12...72)
            )
            seed.zPosition = 2
            worldLayer.addChild(seed)

            AmbientAnimator.idleDrift(
                node: seed,
                x: CGFloat.random(in: -5...5),
                y: CGFloat.random(in: 5...12),
                duration: Double.random(in: 5.4...8.0),
                delay: Double(index) * 0.16
            )
        }
    }

    private func offerNewBlock(from point: CGPoint, playsFeedback: Bool = true) -> Bool {
        let currentBlocks = worldLayer.children.compactMap { $0 as? ClayBlockNode }
        guard currentBlocks.count < maxBlocks else { return false }

        let index = currentBlocks.count + Int.random(in: 0..<blockKinds.count)
        let kind = mysteryKind(for: index, playsFeedback: playsFeedback)
        let blockSize = scaledSize(for: kind)
        let spawnX = clamp(
            point.x,
            min: playMinX(for: blockSize),
            max: playMaxX(for: blockSize)
        )
        let highestBlockTop = currentBlocks
            .map { $0.position.y + $0.blockSize.height / 2 }
            .max() ?? playSurfaceTopY
        let visibleTop = visibleWorldTopY
        let spawnY = clamp(
            max(visibleTop + blockSize.height * 0.58, highestBlockTop + blockSize.height * 1.45),
            min: cameraOffsetY + size.height * 0.62,
            max: visibleTop + blockSize.height * 1.1
        )
        let dropX = clamp(
            spawnX + CGFloat.random(in: -16...16),
            min: playMinX(for: blockSize),
            max: playMaxX(for: blockSize)
        )
        let spawnPoint = CGPoint(
            x: dropX,
            y: spawnY
        )
        let block = makeBlock(index: index, position: spawnPoint, kind: kind)
        block.name = freshSupplyBlockName
        block.zRotation = CGFloat.random(in: -0.24...0.24)
        block.setScale(0.72)
        block.alpha = 0
        block.physicsBody?.isDynamic = false
        block.zPosition = 88
        worldLayer.addChild(block)

        let appear = SKAction.group([
            .fadeAlpha(to: 1, duration: 0.18),
            .scale(to: 1, duration: 0.22)
        ])
        appear.timingMode = .easeOut
        block.run(.sequence([
            appear,
            .run { [weak block] in
                block?.physicsBody?.isDynamic = true
                block?.physicsBody?.velocity = CGVector(
                    dx: CGFloat.random(in: -34...34),
                    dy: CGFloat.random(in: -58 ... -24)
                )
                block?.physicsBody?.angularVelocity = CGFloat.random(in: -0.95...0.95)
            },
            .wait(forDuration: 1.9),
            .run { [weak self, weak block] in
                guard let self, block?.name == self.freshSupplyBlockName else { return }
                block?.name = "clayBlock"
            }
        ]))

        TouchFeedbackAnimator.tactileSpark(
            in: self,
            at: worldLayer.convert(spawnPoint, to: self),
            color: kind == .connector || kind == .king ? WarmShelfPalette.butter : WarmShelfPalette.sand,
            count: kind == .connector || kind == .king ? 8 : (playsFeedback ? 5 : 3)
        )
        if playsFeedback {
            audioManager.playMysteryShape()
            HapticsManager.shared.mysteryShape()
        }
        return true
    }

    private func mysteryKind(for index: Int, playsFeedback: Bool) -> ClayBlockKind {
        guard playsFeedback else { return blockKinds[index % blockKinds.count] }
        let roll = Int.random(in: 0..<10)
        if roll == 0 { return .connector }
        if roll == 1 { return .king }
        return blockKinds[index % blockKinds.count]
    }

    private func preferredSupplySpawnPoint() -> CGPoint {
        let blocks = worldLayer.children.compactMap { $0 as? ClayBlockNode }
        let settledBlocks = blocks.filter { $0.name != freshSupplyBlockName }
        let focusX: CGFloat
        if settledBlocks.isEmpty {
            focusX = size.width / 2
        } else {
            let visibleBlocks = settledBlocks.filter { block in
                let scenePoint = worldLayer.convert(block.position, to: self)
                return scenePoint.y > size.height * 0.12 && scenePoint.y < size.height * 0.88
            }
            let sourceBlocks = visibleBlocks.isEmpty ? settledBlocks : visibleBlocks
            focusX = sourceBlocks.map(\.position.x).reduce(0, +) / CGFloat(sourceBlocks.count)
        }

        return CGPoint(
            x: clamp(focusX + CGFloat.random(in: -54...54), min: size.width * 0.22, max: size.width * 0.78),
            y: visibleWorldTopY
        )
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        HapticsManager.shared.prepareForTouch()
        var playedEmptyFeedback = false

        for touch in touches {
            let point = touch.location(in: self)
            let worldPoint = worldLayer.convert(point, from: self)

            if selectedBlock == nil, consumeShelfReturnTouch(at: point) {
                return
            }

            if selectedBlock == nil, supplyTrayHitRect().contains(point), offerNewBlock(from: preferredSupplySpawnPoint()) {
                if let trayNode = childNode(withName: supplyTrayName) {
                    let pop = SKAction.scale(to: 0.90, duration: 0.07)
                    let settle = SKAction.scale(to: 1.0, duration: 0.22)
                    let wiggle = SKAction.rotate(byAngle: CGFloat.random(in: -0.06...0.06), duration: 0.12)
                    let center = SKAction.rotate(toAngle: 0, duration: 0.18, shortestUnitArc: true)
                    [pop, settle, wiggle, center].forEach { $0.timingMode = .easeInEaseOut }
                    trayNode.run(.sequence([.group([pop, wiggle]), .group([settle, center])]))
                }
                return
            }

            if selectedBlock == nil, let block = topBlock(at: point) {
                block.name = "clayBlock"
                selectedBlock = block
                activeBlockTouch = touch
                touchOffset = CGPoint(x: block.position.x - worldPoint.x, y: block.position.y - worldPoint.y)
                lastTouchPoint = worldPoint
                lastTouchTime = touch.timestamp
                releaseVelocity = .zero

                block.removeAllActions()
                block.physicsBody?.isDynamic = false
                block.zPosition = 90
                TouchFeedbackAnimator.acknowledge(node: block, profile: .softDrag)
                runPickupCue(on: block)
                TouchFeedbackAnimator.tactileSpark(in: self, at: point, color: block.blockColor, count: 4)
                audioManager.playBlockPickup()
                HapticsManager.shared.blockPickup()
                return
            }

            guard selectedBlock == nil, !playedEmptyFeedback else { continue }
            playedEmptyFeedback = true

            ParticleManager.softRipple(in: self, at: point, color: WarmShelfPalette.sand)
            audioManager.playEmptyTap()
            HapticsManager.shared.emptyTap()
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeBlockTouch, touches.contains(touch), let block = selectedBlock else { return }

        let point = touch.location(in: self)
        let worldPoint = worldLayer.convert(point, from: self)
        let deltaX = worldPoint.x - lastTouchPoint.x
        let deltaTime = max(touch.timestamp - lastTouchTime, 0.016)
        releaseVelocity = CGVector(
            dx: deltaX / deltaTime,
            dy: (worldPoint.y - lastTouchPoint.y) / deltaTime
        )
        lastTouchPoint = worldPoint
        lastTouchTime = touch.timestamp

        block.position = clampedBlockPosition(
            CGPoint(x: worldPoint.x + touchOffset.x, y: worldPoint.y + touchOffset.y),
            for: block
        )
        block.zRotation += deltaX * 0.0002
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeBlockTouch, touches.contains(touch) else { return }
        releaseSelectedBlock()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeBlockTouch, touches.contains(touch) else { return }
        releaseSelectedBlock()
    }

    private func releaseSelectedBlock() {
        guard let block = selectedBlock else { return }

        selectedBlock = nil
        activeBlockTouch = nil
        block.zPosition = CGFloat.random(in: 10...40)
        block.physicsBody?.isDynamic = true

        let clampedVelocity = ForgivingHitArea.clampedReleaseVelocity(releaseVelocity, profile: .softDrag)
        let throwSpeed = hypot(clampedVelocity.dx, clampedVelocity.dy)
        block.physicsBody?.velocity = CGVector(
            dx: clampedVelocity.dx,
            dy: min(clampedVelocity.dy, -18)
        )
        block.physicsBody?.angularVelocity = CGFloat.random(in: -0.45...0.45)

        TouchFeedbackAnimator.softSettle(node: block, profile: .softDrag)
        TouchFeedbackAnimator.tactileSpark(
            in: self,
            at: worldLayer.convert(block.position, to: self),
            color: block.blockColor,
            count: 5,
            includesRipple: false
        )
        audioManager.playBlockRelease()
        HapticsManager.shared.blockRelease()

        if throwSpeed > 220 {
            run(.sequence([
                .wait(forDuration: 0.38),
                .run { [weak self, weak block] in
                    guard let self, let block else { return }
                    let impactPoint = self.worldLayer.convert(
                        CGPoint(x: block.position.x, y: self.playSurfaceTopY),
                        to: self
                    )
                    self.playTumbleCelebration(at: impactPoint, color: block.blockColor)
                }
            ]))
        }

        run(.sequence([
            .wait(forDuration: 0.24),
            .run { [weak block] in
                AudioManager.shared.playBlockSettle()
                if let block {
                    HapticsManager.shared.blockLand(kind: block.kind)
                } else {
                    HapticsManager.shared.blockSettle()
                }
            }
        ]))
    }

    private func playTumbleCelebration(at point: CGPoint, color: UIColor) {
        let burstCount = 12
        for index in 0..<burstCount {
            let mote = SKShapeNode(circleOfRadius: CGFloat.random(in: 2.2...5.8))
            let isWarm = index.isMultiple(of: 3)
            mote.fillColor = (isWarm ? WarmShelfPalette.butter : color).withAlpha(
                CGFloat.random(in: 0.42...0.72)
            )
            mote.strokeColor = .clear
            mote.position = point
            mote.zPosition = 94
            addChild(mote)

            let angle = CGFloat(index) / CGFloat(burstCount) * .pi * 2 + CGFloat.random(in: -0.25...0.25)
            let distance = CGFloat.random(in: 18...52)
            let rise = CGFloat.random(in: 8...28)
            let drift = SKAction.moveBy(
                x: cos(angle) * distance,
                y: sin(angle) * distance + rise,
                duration: 0.52
            )
            let fade = SKAction.fadeOut(withDuration: 0.52)
            let shrink = SKAction.scale(to: 0.20, duration: 0.52)
            drift.timingMode = .easeOut
            mote.run(.sequence([.group([drift, fade, shrink]), .removeFromParent()]))
        }
        HapticsManager.shared.blockLand(kind: .longPlank)
    }

    private func runPickupCue(on block: ClayBlockNode) {
        block.removeAction(forKey: "pickupCue")
        let scale = SKAction.scale(to: 1.075, duration: 0.12)
        let rotate = SKAction.rotate(byAngle: CGFloat.random(in: -0.035...0.035), duration: 0.12)
        scale.timingMode = .easeOut
        rotate.timingMode = .easeOut
        block.run(.group([scale, rotate]), withKey: "pickupCue")
    }

    private func keepBlocksInPlay() {
        guard size.width > 160, size.height > 160 else { return }

        let blocks = worldLayer.children.compactMap { $0 as? ClayBlockNode }
        if blocks.isEmpty {
            _ = offerNewBlock(from: CGPoint(x: size.width / 2, y: playSurfaceTopY), playsFeedback: false)
            return
        }

        for block in blocks where block !== selectedBlock {
            let minY = playSurfaceTopY + block.blockSize.height / 2 + 2
            let minX = playMinX(for: block.blockSize)
            let maxX = playMaxX(for: block.blockSize)
            var corrected = block.position
            var shouldCorrect = false

            if corrected.y < minY - 10 {
                let impactSpeed = block.physicsBody.map { hypot($0.velocity.dx, $0.velocity.dy) } ?? 0
                corrected.y = minY
                shouldCorrect = true
                if impactSpeed > 150 {
                    triggerSquish(on: block, intensity: min(1.0, impactSpeed / 520), currentTime: lastSceneUpdateTime)
                }
            }

            if corrected.x < minX {
                corrected.x = minX
                shouldCorrect = true
            } else if corrected.x > maxX {
                corrected.x = maxX
                shouldCorrect = true
            }

            guard shouldCorrect else { continue }

            block.position = corrected
            if let body = block.physicsBody {
                body.velocity = CGVector(
                    dx: body.velocity.dx * 0.18,
                    dy: max(0, body.velocity.dy * -0.08)
                )
                body.angularVelocity *= 0.35
            }
        }
    }

    private func updateSquishImpacts(currentTime: TimeInterval) {
        for block in worldLayer.children.compactMap({ $0 as? ClayBlockNode }) where block !== selectedBlock {
            guard let body = block.physicsBody, body.isDynamic else { continue }

            let speed = hypot(body.velocity.dx, body.velocity.dy)
            let isNearSurface = abs(block.position.y - (playSurfaceTopY + block.blockSize.height / 2)) < max(18, block.blockSize.height * 0.22)
            let isStrongMotion = body.velocity.dy < -160 || speed > 260 || abs(body.angularVelocity) > 2.8
            guard isNearSurface, isStrongMotion else { continue }

            triggerSquish(on: block, intensity: min(1.0, speed / 560), currentTime: currentTime)
        }

        recentSquishTimes = recentSquishTimes.filter { currentTime - $0.value < 2.5 }
    }

    private func triggerSquish(on block: ClayBlockNode, intensity: CGFloat, currentTime: TimeInterval) {
        let id = ObjectIdentifier(block)
        guard currentTime - (recentSquishTimes[id] ?? 0) > 0.42 else { return }
        recentSquishTimes[id] = currentTime
        block.applySquishImpact(intensity: intensity)
    }

    private func clampedBlockPosition(_ position: CGPoint, for block: ClayBlockNode) -> CGPoint {
        CGPoint(
            x: clamp(position.x, min: playMinX(for: block.blockSize), max: playMaxX(for: block.blockSize)),
            y: clamp(
                position.y,
                min: playSurfaceTopY + block.blockSize.height / 2 + 2,
                max: visibleWorldTopY - block.blockSize.height / 2 - 64
            )
        )
    }

    private func updateVerticalFollow() {
        let blocks = worldLayer.children.compactMap { $0 as? ClayBlockNode }
        guard !blocks.isEmpty, size.height > 160 else {
            cameraOffsetY = max(0, cameraOffsetY * 0.92)
            worldLayer.position.y = -cameraOffsetY
            return
        }

        let followableBlocks = blocks.filter { block in
            block === selectedBlock || block.name != freshSupplyBlockName
        }
        let cameraBlocks = followableBlocks.isEmpty ? blocks : followableBlocks
        let highestBlockTop = cameraBlocks
            .map { $0.position.y + $0.blockSize.height / 2 }
            .max() ?? playSurfaceTopY
        let selectedTop = selectedBlock.map { $0.position.y + $0.blockSize.height / 2 } ?? highestBlockTop
        let followTop = max(highestBlockTop, selectedTop)
        let currentHeight = currentStackHeightAboveSurface()
        let desiredOffset = selectedBlock == nil && currentHeight < size.height * 0.18
            ? 0
            : max(0, followTop - size.height * 0.72)
        let response: CGFloat = selectedBlock == nil ? 0.026 : 0.058
        let maxStep: CGFloat = selectedBlock == nil ? 5.5 : 10.0
        let delta = ((desiredOffset - cameraOffsetY) * response).clamped(to: -maxStep...maxStep)

        cameraOffsetY += delta
        if abs(cameraOffsetY) < 0.5 {
            cameraOffsetY = 0
        }
        worldLayer.position.y = -cameraOffsetY
    }

    private func updateHeightMemory(currentTime: TimeInterval) {
        let currentHeight = currentStackHeightAboveSurface()
        guard currentHeight > 48 else { return }

        if !heightMemoryPrimed {
            bestStackHeightAboveSurface = currentHeight
            heightMemoryPrimed = true
            drawHeightMemoryMark(at: currentHeight, animated: true, celebrates: false)
            return
        }

        guard currentHeight > bestStackHeightAboveSurface + 28 else { return }
        guard currentTime - lastHeightMemoryTime > 2.8 else { return }

        bestStackHeightAboveSurface = currentHeight
        lastHeightMemoryTime = currentTime
        drawHeightMemoryMark(at: currentHeight, animated: true, celebrates: true)
    }

    private func currentStackHeightAboveSurface() -> CGFloat {
        let highestTop = worldLayer.children
            .compactMap { $0 as? ClayBlockNode }
            .filter { $0.name != freshSupplyBlockName }
            .map { $0.position.y + $0.blockSize.height / 2 }
            .max() ?? playSurfaceTopY

        return max(0, highestTop - playSurfaceTopY)
    }

    private func drawHeightMemoryMark(at height: CGFloat, animated: Bool, celebrates: Bool) {
        worldLayer.childNode(withName: heightMemoryMarkName)?.removeFromParent()

        let mark = SKNode()
        mark.name = heightMemoryMarkName
        mark.position = CGPoint(
            x: min(max(size.width * 0.10, 38), 92),
            y: playSurfaceTopY + height
        )
        mark.zPosition = 3
        mark.alpha = animated ? 0 : 1
        worldLayer.addChild(mark)

        let lineWidth = min(max(size.width * 0.11, 54), 108)
        let line = makeRoundedRect(
            size: CGSize(width: lineWidth, height: 4),
            radius: 2,
            fill: WarmShelfPalette.sand.withAlpha(0.42)
        )
        line.zPosition = 1
        mark.addChild(line)

        let smudge = makeRoundedRect(
            size: CGSize(width: lineWidth * 0.70, height: 10),
            radius: 5,
            fill: WarmShelfPalette.paperHighlight.withAlpha(0.08)
        )
        smudge.position = CGPoint(x: 0, y: -1)
        smudge.zPosition = 0
        mark.addChild(smudge)

        let dot = SKShapeNode(circleOfRadius: 2.2)
        dot.fillColor = WarmShelfPalette.cocoa.withAlpha(0.26)
        dot.strokeColor = .clear
        dot.position = CGPoint(x: -lineWidth / 2 - 7, y: 0)
        dot.zPosition = 2
        mark.addChild(dot)

        if animated {
            let fade = SKAction.fadeAlpha(to: 1, duration: 0.42)
            fade.timingMode = .easeInEaseOut
            mark.run(fade)
        }

        if celebrates {
            runHeightMemorySprinkle(at: mark.position)
        }
    }

    private func runHeightMemorySprinkle(at worldPosition: CGPoint) {
        let scenePoint = worldLayer.convert(worldPosition, to: self)
        for index in 0..<12 {
            let fleck = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.8...4.0))
            fleck.fillColor = (index.isMultiple(of: 2) ? WarmShelfPalette.sand : WarmShelfPalette.paperHighlight)
                .withAlpha(CGFloat.random(in: 0.42...0.70))
            fleck.strokeColor = .clear
            fleck.position = CGPoint(
                x: scenePoint.x + CGFloat.random(in: -12...18),
                y: scenePoint.y + CGFloat.random(in: -4...10)
            )
            fleck.zPosition = 95
            addChild(fleck)

            let drift = SKAction.moveBy(
                x: CGFloat.random(in: -18...24),
                y: CGFloat.random(in: 12...34),
                duration: 0.62
            )
            let fade = SKAction.fadeOut(withDuration: 0.62)
            let scale = SKAction.scale(to: 0.18, duration: 0.62)
            drift.timingMode = .easeOut
            fleck.run(.sequence([.group([drift, fade, scale]), .removeFromParent()]))
        }

        audioManager.playSoftTap()
        HapticsManager.shared.softTap()
    }

    private func updateGloriousTumble(currentTime: TimeInterval) {
        guard currentTime - lastGloriousTumbleTime > 2.2 else { return }
        guard selectedBlock == nil else { return }

        let fallingBlocks = worldLayer.children
            .compactMap { $0 as? ClayBlockNode }
            .filter { block in
                guard block.name != freshSupplyBlockName, let body = block.physicsBody else { return false }
                return body.isDynamic &&
                    body.velocity.dy < -90 &&
                    (abs(body.velocity.dx) > 24 || abs(body.angularVelocity) > 0.9)
            }

        guard fallingBlocks.count >= 4 else { return }
        lastGloriousTumbleTime = currentTime

        let averageX = fallingBlocks.map(\.position.x).reduce(0, +) / CGFloat(fallingBlocks.count)
        let averageY = fallingBlocks.map(\.position.y).reduce(0, +) / CGFloat(fallingBlocks.count)
        let point = worldLayer.convert(CGPoint(x: averageX, y: averageY), to: self)
        let color = fallingBlocks.randomElement()?.blockColor ?? WarmShelfPalette.sand
        playTumbleCelebration(at: point, color: color)

        let nudgeRight = SKAction.moveBy(x: 3.5, y: 0, duration: 0.05)
        let nudgeLeft = SKAction.moveBy(x: -6.0, y: 0, duration: 0.09)
        let settle = SKAction.moveTo(x: 0, duration: 0.12)
        [nudgeRight, nudgeLeft, settle].forEach { $0.timingMode = .easeInEaseOut }
        worldLayer.run(.sequence([nudgeRight, nudgeLeft, settle]), withKey: "tumbleWorldJostle")
    }

    private func playMinX(for blockSize: CGSize) -> CGFloat {
        blockSize.width / 2 + 24
    }

    private func playMaxX(for blockSize: CGSize) -> CGFloat {
        size.width - blockSize.width / 2 - 24
    }

    private func topBlock(at point: CGPoint) -> ClayBlockNode? {
        worldLayer.children
            .compactMap { $0 as? ClayBlockNode }
            .filter { $0.containsScenePoint(point) }
            .sorted { $0.zPosition > $1.zPosition }
            .first
    }

    private func supplyTrayHitRect() -> CGRect {
        supplyTraySceneRect
    }

    override func accessibilityElements(in view: SKView) -> [UIAccessibilityElement] {
        var elements = super.accessibilityElements(in: view)

        let blocks = worldLayer.children
            .compactMap { $0 as? ClayBlockNode }
            .sorted { $0.zPosition > $1.zPosition }
            .prefix(12)

        elements.append(contentsOf: blocks.map { block in
            let scenePoint = worldLayer.convert(block.position, to: self)
            return makeAccessibilityElement(
                in: view,
                label: "clay block",
                scenePosition: scenePoint,
                size: CGSize(width: block.blockSize.width * 1.2, height: block.blockSize.height * 1.2),
                traits: .button
            )
        })

        return elements
    }

    private func clamp(_ value: CGFloat, min lowerBound: CGFloat, max upperBound: CGFloat) -> CGFloat {
        guard lowerBound <= upperBound else {
            return (lowerBound + upperBound) / 2
        }

        return min(max(value, lowerBound), upperBound)
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
