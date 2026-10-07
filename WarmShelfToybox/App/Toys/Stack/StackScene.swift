import SpriteKit

final class StackScene: BaseToyScene {
    // A drag has a different meaning from the shared tapping pulse.
    override var firstSessionHintKey: String? { nil }
    override var toyVoice: AudioManager.LullSoundVoice { .stack }
    override func firstSessionHintPoint() -> CGPoint { CGPoint(x: size.width / 2, y: groundLineY + 30) }
    private var worldLayer = SKNode()
    private var pieceLayer = SKNode()
    private var shadowLayer = SKNode()
    private var pieces: [StackPieceNode] = []
    private var shadows: [ObjectIdentifier: SKShapeNode] = [:]
    private var activeTouches: [UITouch: StackPieceNode] = [:]
    private var movingState: [ObjectIdentifier: Bool] = [:]
    private var speedPeak: [ObjectIdentifier: CGFloat] = [:]
    private var awakePiece: StackPieceNode?
    private var hasSignatureHero = false
    private weak var towerWallGlow: SKNode?
    private weak var towerFloorGlow: SKShapeNode?

    /// A radial light pool with true falloff — the staging glow must never show an edge.
    private static let softPoolTexture: SKTexture = {
        let side: CGFloat = 256
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let img = renderer.image { ctx in
            let cg = ctx.cgContext
            let colors = [UIColor.white.withAlphaComponent(0.55).cgColor,
                          UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: colors, locations: [0, 1]) else { return }
            let c = CGPoint(x: side / 2, y: side / 2)
            cg.drawRadialGradient(grad, startCenter: c, startRadius: 0,
                                  endCenter: c, endRadius: side / 2, options: [])
        }
        return SKTexture(image: img)
    }()

    private struct PieceSnapshot {
        let kind: StackPieceKind
        let color: UIColor
        let isSignatureHero: Bool
        let wasAwake: Bool
        let normalizedX: CGFloat
        let heightAboveGround: CGFloat
    }

    private var isFrozen = false
    private var settledTimer: TimeInterval = 0
    private var lastSettleSound: TimeInterval = 0
    private var lastKnockover: TimeInterval = 0
    private var lastWakeCelebration: TimeInterval = -10
    private var stageCelebrationUntil: TimeInterval = -10
    private var replenishAccumulator: TimeInterval = 0
    private var idleAccumulator: TimeInterval = 0
    private var lastUpdate: TimeInterval = 0
    private var lastSpawnTime: TimeInterval = -10
    private var nextSupplySlot = 0
    private weak var supplyTray: SKShapeNode?
    private var dragInvitation: SKNode?
    private var hasTouchedStone = false
    private let dragHintKey = "hint.stack.drag.v2"

    private let maxPieces = 12
    private let pileTarget = 1
    private let supplySlotOffsets: [CGFloat] = [0]

    private let warmColors: [UIColor] = [
        WarmShelfPalette.sand,
        WarmShelfPalette.sage,
        WarmShelfPalette.butter,
        WarmShelfPalette.lavender,
        WarmShelfPalette.petal
    ]

    private var pieceScale: CGFloat {
        (min(size.width, size.height) / 410).clamped(to: 0.82...1.7)
    }

    private var groundLineY: CGFloat {
        groundLineY(for: size)
    }

    private var trayRect: CGRect {
        let w = min(size.width * 0.36, 220)
        let centerX = size.width * 0.76
        return CGRect(x: centerX - w / 2, y: groundLineY, width: w, height: 60 * pieceScale)
    }

    private var wakeThresholdY: CGFloat {
        let landscape = size.width > size.height
        return groundLineY + (landscape ? 166 : 196) * pieceScale
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        ambientMoteInterval = 0.7
        physicsWorld.gravity = CGVector(dx: 0, dy: -5.0)
        rebuildWorld()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        rebuildWorld(preservingPiecesFrom: oldSize)
    }

    private func groundLineY(for canvasSize: CGSize) -> CGFloat {
        let isLandscape = canvasSize.width > canvasSize.height
        let isPhone = min(canvasSize.width, canvasSize.height) < 600
        if isLandscape {
            let floor = canvasSize.height * 0.24
            return max(isPhone ? 92 : 132, min(floor, isPhone ? 126 : 180))
        }
        let floor = canvasSize.height * (isPhone ? 0.245 : 0.23)
        return max(isPhone ? 164 : 190, floor)
    }

    private func rebuildWorld(preservingPiecesFrom oldSize: CGSize? = nil) {
        guard size.width > 160, size.height > 160 else { return }

        let snapshots: [PieceSnapshot]
        if let oldSize, oldSize.width > 0, !pieces.isEmpty {
            let oldGround = groundLineY(for: oldSize)
            snapshots = pieces.map { piece in
                PieceSnapshot(
                    kind: piece.kind,
                    color: piece.baseColor,
                    isSignatureHero: piece.isSignatureHero,
                    wasAwake: piece.isAwake,
                    normalizedX: piece.position.x / oldSize.width,
                    heightAboveGround: piece.position.y - oldGround
                )
            }
        } else {
            snapshots = []
        }

        activeTouches.removeAll()
        movingState.removeAll()
        speedPeak.removeAll()
        shadows.removeAll()
        awakePiece = nil
        hasSignatureHero = false
        nextSupplySlot = 0
        lastSpawnTime = -10
        isFrozen = false
        settledTimer = 0
        if snapshots.isEmpty {
            lastWakeCelebration = -10
            hasTouchedStone = false
        }
        pieces.removeAll()
        removeAction(forKey: "stackDragHint")
        dragInvitation?.removeFromParent()
        dragInvitation = nil
        worldLayer.removeFromParent()

        worldLayer = SKNode()
        worldLayer.zPosition = 8
        addChild(worldLayer)

        addRoom()
        addGround()
        addBarriers()

        shadowLayer = SKNode()
        shadowLayer.zPosition = 10
        worldLayer.addChild(shadowLayer)

        pieceLayer = SKNode()
        pieceLayer.zPosition = 12
        worldLayer.addChild(pieceLayer)

        if snapshots.isEmpty {
            spawnOpeningPile()
        } else {
            restorePieces(from: snapshots)
        }
    }

    private func restorePieces(from snapshots: [PieceSnapshot]) {
        for (index, snapshot) in snapshots.enumerated() {
            let piece = StackPieceNode(
                kind: snapshot.kind,
                color: snapshot.color,
                scale: pieceScale,
                isSignatureHero: snapshot.isSignatureHero
            )
            piece.physicsBody?.velocity = .zero
            piece.physicsBody?.angularVelocity = 0
            piece.physicsBody?.isDynamic = true

            let halfWidth = piece.bodySize.width / 2
            let halfHeight = piece.bodySize.height / 2
            piece.position = CGPoint(
                x: (snapshot.normalizedX * size.width).clamped(to: halfWidth...(size.width - halfWidth)),
                y: (groundLineY + snapshot.heightAboveGround).clamped(
                    to: (groundLineY + halfHeight + 2)...(size.height - halfHeight)
                )
            )
            pieceLayer.addChild(piece)
            pieces.append(piece)
            addShadow(for: piece)
            hasSignatureHero = hasSignatureHero || piece.isSignatureHero
            if snapshot.wasAwake {
                piece.wake()
                awakePiece = piece
            } else {
                piece.breatheSleepily(delay: Double(index) * 0.08)
            }
        }
        nextSupplySlot = pieces.count % max(1, supplySlotOffsets.count)
    }

    /// A cosy little room: soft wall, a warm window, a rug, and a baseboard — so Stack
    /// feels like a place, not bare sand.
    private func addRoom() {
        // Soft wall above the floor.
        let wall = SKShapeNode(rect: CGRect(x: 0, y: groundLineY, width: size.width, height: size.height - groundLineY))
        wall.fillColor = WarmShelfPalette.warmCream.withAlpha(0.16)
        wall.strokeColor = .clear
        wall.zPosition = -2
        worldLayer.addChild(wall)

        // A quiet pool of warm wall light stages the tower without becoming an effect —
        // radial falloff so the pool has no findable boundary (QA sweep note).
        let towerLight = SKSpriteNode(texture: StackScene.softPoolTexture)
        towerLight.size = CGSize(
            width: min(size.width * 0.86, 620),
            height: min((size.height - groundLineY) * 1.4, 760)
        )
        towerLight.color = WarmShelfPalette.paperHighlight
        towerLight.colorBlendFactor = 1
        towerLight.position = CGPoint(x: size.width * 0.34, y: groundLineY + (size.height - groundLineY) * 0.42)
        towerLight.zPosition = -1.96
        towerLight.alpha = 0.55
        worldLayer.addChild(towerLight)
        towerWallGlow = towerLight

        // Sparse wallpaper texture: enough material, not a competing pattern.
        let dotGap: CGFloat = 104
        var dy = groundLineY + 40
        var rowEven = true
        while dy < size.height - 10 {
            var dx: CGFloat = rowEven ? 30 : 30 + dotGap / 2
            while dx < size.width - 10 {
                let dot = SKShapeNode(circleOfRadius: 2)
                dot.fillColor = WarmShelfPalette.sand.withAlpha(0.085); dot.strokeColor = .clear
                dot.position = CGPoint(x: dx, y: dy); dot.zPosition = -1.9
                worldLayer.addChild(dot)
                dx += dotGap
            }
            dy += dotGap
            rowEven.toggle()
        }

        // A pretty little window onto a soft sky — recognizable (sky! sun! a hill!) and
        // calm. Sits low on the wall so the open space above is the place to build into.
        let winW = min(size.width * 0.22, 148)
        let winH = min(winW * 1.2, (size.height - groundLineY) * 0.58)
        let winX = min(size.width * 0.76, size.width - winW * 0.5 - 22)
        let winY = groundLineY + (size.height - groundLineY) * 0.34
        let corner = winW * 0.16

        let glow = SKShapeNode(rectOf: CGSize(width: winW * 1.5, height: winH * 1.5), cornerRadius: 34)
        glow.fillColor = WarmShelfPalette.butter.withAlpha(0.08); glow.strokeColor = .clear
        glow.position = CGPoint(x: winX, y: winY); glow.zPosition = -1.9
        worldLayer.addChild(glow)

        // Warm wooden frame behind the glass.
        let frame = SKShapeNode(rectOf: CGSize(width: winW + 14, height: winH + 14), cornerRadius: corner + 5)
        frame.fillColor = WarmShelfPalette.sand.withAlpha(0.52); frame.strokeColor = .clear
        frame.position = CGPoint(x: winX, y: winY); frame.zPosition = -1.8
        worldLayer.addChild(frame)

        // The view outside, clipped to the glass: sky, a soft sun, a gentle hill.
        let crop = SKCropNode()
        crop.position = CGPoint(x: winX, y: winY); crop.zPosition = -1.7
        let mask = SKShapeNode(rectOf: CGSize(width: winW, height: winH), cornerRadius: corner)
        mask.fillColor = .white; crop.maskNode = mask
        let sky = SKShapeNode(rectOf: CGSize(width: winW, height: winH))
        sky.fillColor = WarmShelfPalette.waterBlue.withAlpha(0.20); sky.strokeColor = .clear
        crop.addChild(sky)
        let sun = SKShapeNode(circleOfRadius: winW * 0.15)
        sun.fillColor = WarmShelfPalette.butter.withAlpha(0.48); sun.strokeColor = .clear
        sun.position = CGPoint(x: winW * 0.22, y: winH * 0.24); crop.addChild(sun)
        let hill = SKShapeNode(ellipseOf: CGSize(width: winW * 1.5, height: winH * 0.8))
        hill.fillColor = WarmShelfPalette.sage.withAlpha(0.38); hill.strokeColor = .clear
        hill.position = CGPoint(x: -winW * 0.1, y: -winH * 0.52); crop.addChild(hill)
        worldLayer.addChild(crop)

        // Thin inner rim so the glass reads crisp.
        let rim = SKShapeNode(rectOf: CGSize(width: winW, height: winH), cornerRadius: corner)
        rim.fillColor = .clear; rim.strokeColor = WarmShelfPalette.paperHighlight.withAlpha(0.55); rim.lineWidth = 3
        rim.position = CGPoint(x: winX, y: winY); rim.zPosition = -1.6
        worldLayer.addChild(rim)

        // Windowsill so it reads as mounted, not floating.
        let sill = SKShapeNode(rect: CGRect(x: winX - winW * 0.62, y: winY - winH * 0.5 - 13, width: winW * 1.24, height: 9), cornerRadius: 4.5)
        sill.fillColor = WarmShelfPalette.sand.withAlpha(0.6); sill.strokeColor = .clear; sill.zPosition = -1.55
        worldLayer.addChild(sill)
        // A tiny potted plant on the sill for charm.
        let pot = SKShapeNode(path: {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -8, y: 0)); p.addLine(to: CGPoint(x: 8, y: 0))
            p.addLine(to: CGPoint(x: 6, y: -12)); p.addLine(to: CGPoint(x: -6, y: -12)); p.closeSubpath(); return p
        }())
        pot.fillColor = WarmShelfPalette.sand.withAlpha(0.48); pot.strokeColor = .clear
        pot.position = CGPoint(x: winX - winW * 0.34, y: winY - winH * 0.5 - 4); pot.zPosition = -1.5
        worldLayer.addChild(pot)
        for (dx, dy) in [(-6.0, 8.0), (0.0, 13.0), (6.0, 8.0)] {
            let leaf = SKShapeNode(ellipseOf: CGSize(width: 8, height: 14))
            leaf.fillColor = WarmShelfPalette.sage.withAlpha(0.48); leaf.strokeColor = .clear
            leaf.position = CGPoint(x: pot.position.x + dx, y: pot.position.y + dy)
            leaf.zRotation = CGFloat(dx) * 0.05; leaf.zPosition = -1.5
            worldLayer.addChild(leaf)
        }

        // A soft patterned rug right under where the stones rest (sits on the floor line).
        let rugW = min(size.width * 0.82, 520)
        let rugH = min(groundLineY * 0.7, 96)
        // Sit the rug fully on the floor — its top edge meets the floor seam instead of
        // riding up onto the wall.
        let rugCenter = CGPoint(x: size.width / 2, y: groundLineY - rugH * 0.52)
        let rug = SKShapeNode(ellipseOf: CGSize(width: rugW, height: rugH))
        rug.fillColor = WarmShelfPalette.sand.withAlpha(0.18)
        rug.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.07); rug.lineWidth = 3
        rug.position = rugCenter
        rug.zPosition = 0.4
        worldLayer.addChild(rug)
        // Concentric ring pattern.
        for (i, factor) in [CGFloat(0.78), 0.56, 0.34].enumerated() {
            let ring = SKShapeNode(ellipseOf: CGSize(width: rugW * factor, height: rugH * factor))
            ring.fillColor = .clear
            ring.strokeColor = (i.isMultiple(of: 2) ? WarmShelfPalette.butter : WarmShelfPalette.paperHighlight).withAlpha(0.16)
            ring.lineWidth = 2
            ring.position = rugCenter; ring.zPosition = 0.45
            worldLayer.addChild(ring)
        }

        // Baseboard where wall meets floor.
        let baseboard = SKShapeNode(rect: CGRect(x: 0, y: groundLineY - 4, width: size.width, height: 8))
        baseboard.fillColor = WarmShelfPalette.cocoa.withAlpha(0.10); baseboard.strokeColor = .clear
        baseboard.zPosition = 0.5
        worldLayer.addChild(baseboard)
    }

    private func addGround() {
        // A solid warm-wood floor that clearly reads as a different plane than the wall,
        // so the stones rest on something instead of floating in an indistinct field.
        let floorTop = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.width, height: groundLineY))
        floorTop.fillColor = WarmShelfPalette.sand.withAlpha(0.72)
        floorTop.strokeColor = .clear
        floorTop.zPosition = 0
        worldLayer.addChild(floorTop)
        ProceduralTexture.applyClayFill(to: floorTop, base: WarmShelfPalette.sand, size: CGSize(width: size.width, height: max(1, groundLineY)))

        // A warm wall above the floor with a soft glow pooled behind the tower — the stones live
        // in a cozy room now, not a bare paper void (the empty field was the "prototype" feel).
        let wall = SKShapeNode(rect: CGRect(x: 0, y: groundLineY, width: size.width, height: max(1, size.height - groundLineY)))
        wall.fillColor = WarmShelfPalette.warmCream.withAlpha(0.3)
        wall.strokeColor = .clear
        wall.zPosition = 0
        worldLayer.addChild(wall)
        let wallGlow = SKShapeNode(ellipseOf: CGSize(width: size.width * 0.85, height: (size.height - groundLineY) * 0.9))
        wallGlow.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.24)
        wallGlow.strokeColor = .clear
        wallGlow.position = CGPoint(x: size.width / 2, y: groundLineY + (size.height - groundLineY) * 0.34)
        wallGlow.zPosition = 0.05
        worldLayer.addChild(wallGlow)

        // Soft warm-light pool spilling from the floor's centre, grounding the play area.
        let pool = SKShapeNode(ellipseOf: CGSize(width: size.width * 0.9, height: groundLineY * 1.2))
        pool.fillColor = WarmShelfPalette.butter.withAlpha(0.12)
        pool.strokeColor = .clear
        pool.position = CGPoint(x: size.width / 2, y: groundLineY * 0.42)
        pool.zPosition = 0.1
        pool.alpha = 0.62
        worldLayer.addChild(pool)
        towerFloorGlow = pool

        // Faint floorboard seams for Montessori wood texture.
        let plankGap: CGFloat = 70
        var px = plankGap
        while px < size.width {
            let seam = SKShapeNode(rect: CGRect(x: px - 1, y: 0, width: 2, height: groundLineY))
            seam.fillColor = WarmShelfPalette.cocoa.withAlpha(0.05); seam.strokeColor = .clear
            seam.zPosition = 0.15
            worldLayer.addChild(seam)
            px += plankGap
        }

        // Crisp horizon seam where floor meets wall.
        let seam = SKShapeNode(rect: CGRect(x: 0, y: groundLineY - 2, width: size.width, height: 4))
        seam.fillColor = WarmShelfPalette.cocoa.withAlpha(0.14); seam.strokeColor = .clear
        seam.zPosition = 0.9
        worldLayer.addChild(seam)

        let lip = SKShapeNode(rect: CGRect(x: 0, y: groundLineY, width: size.width, height: 3))
        lip.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.45)
        lip.strokeColor = .clear
        lip.zPosition = 1
        worldLayer.addChild(lip)

        // One distinct tray on the right supplies one loose stone at a time.
        // The left-hand base is the clear place to build; nothing falls from nowhere.
        let trayWidth = trayRect.width
        let tray = SKShapeNode(rectOf: CGSize(width: trayWidth, height: 34 * pieceScale),
                               cornerRadius: 12 * pieceScale)
        tray.fillColor = WarmShelfPalette.sand.withAlpha(0.92)
        tray.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.26)
        tray.lineWidth = 2 * pieceScale
        tray.position = CGPoint(x: trayRect.midX, y: groundLineY + 5 * pieceScale)
        tray.zPosition = 1.5
        tray.alpha = 0.78
        worldLayer.addChild(tray)
        supplyTray = tray
        let lipPath = CGMutablePath()
        lipPath.move(to: CGPoint(x: -trayWidth * 0.46, y: -3 * pieceScale))
        lipPath.addQuadCurve(to: CGPoint(x: trayWidth * 0.46, y: -3 * pieceScale),
                             control: CGPoint(x: 0, y: -16 * pieceScale))
        let trayLip = SKShapeNode(path: lipPath)
        trayLip.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.22)
        trayLip.lineWidth = 2 * pieceScale
        trayLip.fillColor = .clear
        tray.addChild(trayLip)

        let floor = SKNode()
        floor.position = CGPoint(x: size.width / 2, y: groundLineY - 30)
        let floorBody = SKPhysicsBody(rectangleOf: CGSize(width: size.width + 80, height: 60))
        floorBody.isDynamic = false
        floorBody.friction = 0.95
        floorBody.restitution = 0.0
        floorBody.categoryBitMask = PhysicsCategory.surface
        floor.physicsBody = floorBody
        worldLayer.addChild(floor)
    }

    private func addBarriers() {
        for x in [CGFloat(-2), size.width + 2] {
            let wall = SKNode()
            let body = SKPhysicsBody(edgeFrom: CGPoint(x: x, y: -120), to: CGPoint(x: x, y: size.height + 400))
            body.categoryBitMask = PhysicsCategory.wall
            body.friction = 0.2
            wall.physicsBody = body
            worldLayer.addChild(wall)
        }
    }

    // MARK: - Opening sequence

    /// A wide base on the left and one loose stone in the supply tray. Starting
    /// with the move still to make lets the child discover stacking immediately.
    private func spawnOpeningPile() {
        let kinds: [StackPieceKind] = [.pebble, .bean]
        let colors: [UIColor] = [WarmShelfPalette.terracotta, WarmShelfPalette.sage]
        for (i, (kind, color)) in zip(kinds, colors).enumerated() {
            let piece = StackPieceNode(kind: kind, color: color.withAlpha(0.96),
                                       scale: pieceScale, isSignatureHero: i == 0)
            if i == 0 { hasSignatureHero = true }
            piece.position = CGPoint(x: i == 0 ? size.width * 0.34 : trayRect.midX,
                                     y: groundLineY + piece.bodySize.height * 0.5 + 4)
            piece.physicsBody?.isDynamic = false
            pieceLayer.addChild(piece)
            pieces.append(piece)
            addShadow(for: piece)
            piece.breatheSleepily(delay: Double(i) * 0.15 + 0.3)
            if AmbientAnimator.reduceMotion {
                piece.physicsBody?.isDynamic = true
            } else {
                piece.alpha = 0
                piece.setScale(0)
                let perk = SKAction.scale(to: 1.06, duration: 0.14)
                perk.timingMode = .easeOut
                let exhale = SKAction.scale(to: 1.0, duration: 0.14)
                exhale.timingMode = .easeInEaseOut
                piece.run(.sequence([
                    .wait(forDuration: Double(i) * 0.15),
                    .group([.fadeIn(withDuration: 0.18), .sequence([perk, exhale])]),
                    .run { [weak piece] in piece?.physicsBody?.isDynamic = true }
                ]), withKey: "appearance")
            }
        }
        run(.sequence([.wait(forDuration: 1.4), .run { [weak self] in
            self?.showDragInvitationIfNeeded()
        }]), withKey: "stackDragHint")
    }

    /// A finger-sized dot demonstrates the first move, then leaves. It never moves
    /// the actual stone, and the child's first touch cancels the demonstration.
    private func showDragInvitationIfNeeded() {
        guard !hasTouchedStone, !LullDemoState.shared.hasSeenHint(dragHintKey),
              let base = pieces.first(where: { $0.isSignatureHero }),
              let loose = pieces.first(where: { !$0.isSignatureHero }) else { return }
        LullDemoState.shared.markHintSeen(dragHintKey)
        let start = loose.position
        let end = CGPoint(x: base.position.x, y: base.topY + loose.bodySize.height / 2 + 2)
        let hint = SKNode()
        hint.zPosition = 100
        addChild(hint)
        dragInvitation = hint

        let target = SKShapeNode(rectOf: loose.bodySize, cornerRadius: loose.bodySize.height * 0.36)
        target.position = end
        target.fillColor = .clear
        target.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.18)
        target.lineWidth = 2
        hint.addChild(target)
        let finger = SKShapeNode(circleOfRadius: 9 * pieceScale)
        finger.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.92)
        finger.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.3)
        finger.lineWidth = 1.5
        finger.position = start
        hint.addChild(finger)

        if AmbientAnimator.reduceMotion {
            // Static trail preserves the instruction when motion is turned off.
            for step in 1...4 {
                let t = CGFloat(step) / 5
                let dot = SKShapeNode(circleOfRadius: 2.5 * pieceScale)
                dot.fillColor = WarmShelfPalette.cocoa.withAlpha(0.16)
                dot.strokeColor = .clear
                dot.position = CGPoint(x: start.x + (end.x - start.x) * t,
                                       y: start.y + (end.y - start.y) * t)
                hint.addChild(dot)
            }
        } else {
            let path = CGMutablePath()
            path.move(to: start)
            path.addQuadCurve(to: end, control: CGPoint(x: start.x, y: end.y + 50 * pieceScale))
            let move = SKAction.follow(path, asOffset: false, orientToPath: false, duration: 1.35)
            move.timingMode = .easeInEaseOut
            finger.run(.sequence([.wait(forDuration: 0.3), move, .fadeOut(withDuration: 0.4)]))
        }
        hint.run(.sequence([.wait(forDuration: 2.5), .fadeOut(withDuration: 0.35), .removeFromParent()]))
    }

    private func dismissDragInvitation() {
        hasTouchedStone = true
        removeAction(forKey: "stackDragHint")
        dragInvitation?.removeFromParent()
        dragInvitation = nil
        LullDemoState.shared.markHintSeen(dragHintKey)
    }

    private func spawnPilePiece(animated: Bool, indexHint: Int = 0) {
        guard pieces.count < maxPieces else { return }
        guard !animated || lastUpdate - lastSpawnTime >= 0.30 else { return }

        let isHero = !hasSignatureHero
        let pieceIndex = pieces.count
        let kindSequence: [StackPieceKind] = [.pebble, .pebble, .bean, .loaf, .pebble, .bean, .stone]
        let kind = isHero ? StackPieceKind.pebble : kindSequence[pieceIndex % kindSequence.count]
        let color = isHero ? WarmShelfPalette.terracotta : warmColors[pieceIndex % warmColors.count]
        let piece = StackPieceNode(
            kind: kind,
            color: color.withAlpha(0.96),
            scale: pieceScale,
            isSignatureHero: isHero
        )

        // New stones always appear inside the basket, so the supply reads clearly.
        let inset = piece.bodySize.width * 0.5 + 6
        let minX = trayRect.minX + inset
        let maxX = max(minX, trayRect.maxX - inset)
        let restY = groundLineY + piece.bodySize.height * 0.5 + 4
        let preferredSlot = animated
            ? nextSupplySlot
            : min(indexHint, supplySlotOffsets.count - 1)
        guard let placement = clearTrayPlacement(
            for: piece,
            restY: restY,
            preferredSlot: preferredSlot,
            minX: minX,
            maxX: maxX
        ) else {
            return
        }
        if animated {
            nextSupplySlot = (placement.slot + 1) % max(1, supplySlotOffsets.count)
            lastSpawnTime = lastUpdate
        }
        hasSignatureHero = hasSignatureHero || isHero

        piece.position = CGPoint(x: placement.x, y: restY)
        pieceLayer.addChild(piece)
        pieces.append(piece)
        addShadow(for: piece)

        if animated {
            // The refill rises from the exact tray the child just emptied.
            if !AmbientAnimator.reduceMotion {
                piece.physicsBody?.isDynamic = false
                piece.position.y -= 12 * pieceScale
                piece.alpha = 0
                piece.setScale(0.8)
                let rise = SKAction.moveTo(y: restY, duration: 0.28)
                rise.timingMode = .easeOut
                let settle = SKAction.scale(to: 1, duration: 0.28)
                settle.timingMode = .easeOut
                piece.run(.sequence([
                    .group([rise, settle, .fadeIn(withDuration: 0.22)]),
                    .run { [weak piece] in piece?.physicsBody?.isDynamic = true }
                ]), withKey: "appearance")
                supplyTray?.run(.sequence([.fadeAlpha(to: 1, duration: 0.1),
                                           .fadeAlpha(to: 0.78, duration: 0.4)]), withKey: "refill")
            }
            piece.breatheSleepily()
            AudioManager.shared.playStackPlace()
            isFrozen = false
            settledTimer = 0
        } else {
            piece.breatheSleepily(delay: Double(indexHint) * 0.3)
        }
    }

    private func clearTrayPlacement(
        for piece: StackPieceNode,
        restY: CGFloat,
        preferredSlot: Int,
        minX: CGFloat,
        maxX: CGFloat
    ) -> (slot: Int, x: CGFloat)? {
        let slotCount = max(1, supplySlotOffsets.count)
        let slots = (0..<slotCount).map { (preferredSlot + $0) % slotCount }

        for slot in slots {
            let x = (trayRect.midX + trayRect.width * supplySlotOffsets[slot]).clamped(to: minX...maxX)
            let candidate = frame(for: piece, at: CGPoint(x: x, y: restY))
            let blocked = pieces.contains { existing in
                frame(for: existing, at: existing.position)
                    .insetBy(dx: -10, dy: -10)
                    .intersects(candidate)
            }
            if !blocked {
                return (slot, x)
            }
        }
        return nil
    }

    private func frame(for piece: StackPieceNode, at position: CGPoint) -> CGRect {
        CGRect(
            x: position.x - piece.bodySize.width / 2,
            y: position.y - piece.bodySize.height / 2,
            width: piece.bodySize.width,
            height: piece.bodySize.height
        )
    }

    private func addShadow(for piece: StackPieceNode) {
        let shadow = SKShapeNode(ellipseOf: CGSize(width: piece.bodySize.width * 0.78, height: max(10, piece.bodySize.height * 0.22)))
        shadow.fillColor = WarmShelfPalette.contactShadow.withAlpha(0.12)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: piece.position.x, y: groundLineY - 4)
        shadowLayer.addChild(shadow)
        shadows[ObjectIdentifier(piece)] = shadow
    }

    private func updateShadows() {
        for piece in pieces {
            guard let shadow = shadows[ObjectIdentifier(piece)] else { continue }
            let restingY = groundLineY + piece.bodySize.height * 0.5
            let height = max(0, piece.position.y - restingY)
            let lift = (height / 320).clamped(to: 0...1)
            shadow.position = CGPoint(x: piece.position.x, y: groundLineY - 4)
            // Shadow shrinks and fades as the piece lifts — physically correct.
            shadow.setScale(max(0.32, 1 - lift * 0.62))
            shadow.alpha = 0.12 * (1 - lift * 0.70)
        }
    }

    private func updatePieceDepth() {
        let restingOrder = pieces
            .filter { piece in activeTouches.values.contains(where: { $0 === piece }) == false }
            .sorted { $0.position.y < $1.position.y }
        for (index, piece) in restingOrder.enumerated() {
            piece.zPosition = CGFloat(20 + index)
        }
        for piece in activeTouches.values {
            piece.zPosition = 80
        }
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        HapticsManager.shared.prepareForTouch()

        for touch in touches {
            let point = touch.location(in: self)
            if activeTouches.isEmpty, consumeShelfReturnTouch(at: point) { return }

            if let piece = topPiece(at: point), !activeTouches.values.contains(where: { $0 === piece }) {
                dismissDragInvitation()
                piece.removeAction(forKey: "appearance")
                piece.alpha = 1
                piece.setScale(1)
                // Bring the whole tower back to life so pulling a low stone can topple the rest.
                unfreezeAll()
                activeTouches[touch] = piece
                if piece === awakePiece { piece.sleep(); awakePiece = nil }
                piece.beginHold()
                piece.zPosition = 60
                AudioManager.shared.playStackLift()   // haptic fires inside
            } else {
                TouchFeedbackAnimator.emptyTap(in: self, at: point)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let piece = activeTouches[touch] else { continue }
            let point = touch.location(in: self)
            let dragLift = min(30, piece.bodySize.height * 0.28)
            let clamped = CGPoint(
                x: point.x.clamped(to: piece.bodySize.width / 2...(size.width - piece.bodySize.width / 2)),
                y: (point.y + dragLift).clamped(
                    to: (groundLineY + piece.bodySize.height / 2 + 2)...(size.height - piece.bodySize.height / 2)
                )
            )
            // It looks the way it's being carried.
            let move = CGVector(dx: clamped.x - piece.position.x, dy: clamped.y - piece.position.y)
            if hypot(move.dx, move.dy) > 0.6 {
                piece.lookToward(move)
                piece.poseForCarry(move)
            }
            piece.position = clamped
            if !trayRect.contains(CGPoint(x: piece.position.x, y: groundLineY + 10))
                || piece.bottomY > groundLineY + piece.bodySize.height * 0.5 {
                replenishPileIfNeeded()
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { releasePiece(for: touch) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { releasePiece(for: touch) }
    }

    private func releasePiece(for touch: UITouch) {
        guard let piece = activeTouches.removeValue(forKey: touch) else { return }
        gentlyAssistPlacement(of: piece)
        piece.endHold()
        HapticsManager.shared.blockRelease()
    }

    private func topPiece(at point: CGPoint) -> StackPieceNode? {
        pieces
            .filter { piece in
                let dx = abs(piece.position.x - point.x)
                let dy = abs(piece.position.y - point.y)
                // Generous beyond the felt art's painted bounds — a toddler's aim is the spec.
                return dx < piece.bodySize.width * 0.7 + 44 && dy < piece.bodySize.height * 0.7 + 44
            }
            .sorted { first, second in
                let firstDistance = hypot(first.position.x - point.x, first.position.y - point.y)
                let secondDistance = hypot(second.position.x - point.x, second.position.y - point.y)
                if abs(firstDistance - secondDistance) > 6 {
                    return firstDistance < secondDistance
                }
                return first.position.y > second.position.y
            }
            .first
    }

    /// If a child releases clearly above a resting stone, quietly help the centers meet.
    /// The stone still falls and settles physically; this only removes precision as a barrier.
    private func gentlyAssistPlacement(of piece: StackPieceNode) {
        let supports = pieces.filter { other in
            guard other !== piece else { return false }
            guard activeTouches.values.contains(where: { $0 === other }) == false else { return false }
            guard other.speed2D < 36 else { return false }
            guard isResting(other) else { return false }

            let verticalGap = piece.bottomY - other.topY
            let closeAbove = verticalGap > -piece.bodySize.height * 0.30
                && verticalGap < piece.bodySize.height * 1.20
            let generousOverlap = abs(piece.position.x - other.position.x)
                < (piece.halfWidth + other.halfWidth) * 0.68
            return closeAbove && generousOverlap
        }

        guard let support = supports.max(by: { $0.topY < $1.topY }) else { return }
        piece.position.x += (support.position.x - piece.position.x) * 0.72
        piece.physicsBody?.velocity = .zero
        piece.physicsBody?.angularVelocity = 0
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        guard size.width > 160 else { return }

        let delta = lastUpdate == 0 ? 0 : currentTime - lastUpdate
        lastUpdate = currentTime

        detectSettles()
        detectKnockover(currentTime: currentTime)
        updateExpressions()
        updateWake()
        updateShadows()
        updatePieceDepth()
        updateStageFocus()
        updateFreeze(delta: delta)

        replenishAccumulator += delta
        if replenishAccumulator > 1.1 {
            replenishAccumulator = 0
            replenishPileIfNeeded()
        }

        // No autonomous resets: when every stone is stacked, the tower simply stands and
        // sleeps. The knockdown is the child's favourite verb — the world never steals it.
        idleAccumulator += delta
        if idleAccumulator > 2.6 {
            idleAccumulator = 0
            sleepyIdleTick()
        }
    }

    private func detectSettles() {
        for piece in pieces {
            guard activeTouches.values.contains(where: { $0 === piece }) == false else { continue }
            let id = ObjectIdentifier(piece)
            let speed = piece.speed2D
            let wasMoving = movingState[id] ?? false

            if speed > 46 {
                movingState[id] = true
                speedPeak[id] = max(speedPeak[id] ?? 0, speed)
            } else if wasMoving, speed < 14 {
                movingState[id] = false
                let impact = speedPeak[id] ?? speed
                speedPeak[id] = 0
                let tumbled = piece.spin > 7 && impact > 120
                if tumbled {
                    piece.dizzy()
                } else {
                    piece.reactLanded(hard: impact > 230)
                }
                // Only a genuine, weighted landing speaks — and softly. Gentle micro-settles
                // and the constant solver-jitter of a resting pile stay silent, so stacking
                // feels like a calm premium toy, not a stream of success chimes.
                if impact > 135, CACurrentMediaTime() - lastSettleSound > 0.5 {
                    lastSettleSound = CACurrentMediaTime()
                    let hardness = Float((impact - 135) / 320).clamped(to: 0...1)
                    AudioManager.shared.playStackSettle(hardness: hardness)   // haptic fires inside
                }
            }
        }
    }

    /// Knocking a tower down is a 2-year-old's favourite move — so reward it. When several
    /// stones tumble at once, they whee with delight (not fear), kick up dust, and clatter.
    private func detectKnockover(currentTime: TimeInterval) {
        guard currentTime - lastKnockover > 0.8 else { return }
        let tumbling = pieces.filter { ($0.speed2D > 150 || $0.spin > 6) && $0.physicsBody?.isDynamic ?? false }
        guard tumbling.count >= 2 else { return }
        lastKnockover = currentTime

        for piece in tumbling {
            piece.reactToKnockover()
        }
        let cx = tumbling.map { $0.position.x }.reduce(0, +) / CGFloat(tumbling.count)
        let dustOrigin = CGPoint(x: cx, y: groundLineY + 6)
        // Double burst — sand + cream — for a satisfying cloud of chaos.
        ParticleManager.softBurst(in: self, at: dustOrigin, color: WarmShelfPalette.sand, count: 14)
        ParticleManager.softBurst(in: self, at: dustOrigin, color: WarmShelfPalette.warmCream, count: 8)
        // Each tumbling piece reacts with glee so every part of the collapse is celebrated.
        for (index, piece) in tumbling.enumerated() {
            piece.playTowerPulse(delay: Double(index) * 0.04, isTop: false)
        }
        AudioManager.shared.playStackKnockover()
        HapticsManager.shared.play(score: .stackKnockover)
    }

    /// Resting stacked bodies jitter as the solver keeps nudging them, so once the whole
    /// tower is genuinely settled we freeze it solid; grabbing any stone wakes it again.
    /// Crucially we only freeze pieces that are *supported* (on the ground or on another
    /// stone) — never a stone that's merely slow in mid-air — so nothing gets stuck floating.
    private func updateFreeze(delta: TimeInterval) {
        guard !pieces.isEmpty else { return }

        if !activeTouches.isEmpty {
            settledTimer = 0
            return
        }

        let allSlow = pieces.allSatisfy { $0.speed2D < 14 && $0.spin < 0.5 }
        let allSupported = pieces.allSatisfy { isResting($0) }
        if allSlow && allSupported {
            settledTimer += delta
            if settledTimer > 0.5, !isFrozen {
                freezeAll()
            }
        } else {
            settledTimer = 0
        }
    }

    /// True if the stone rests on the ground or sits on top of another stone.
    private func isResting(_ piece: StackPieceNode) -> Bool {
        if piece.bottomY <= groundLineY + 14 { return true }
        for other in pieces where other !== piece {
            let horizontallyOverlaps = abs(other.position.x - piece.position.x) < (piece.halfWidth + other.halfWidth) * 0.9
            let sitsOnTop = abs(other.topY - piece.bottomY) < 16
            if horizontallyOverlaps && sitsOnTop { return true }
        }
        return false
    }

    private func freezeAll() {
        for piece in pieces {
            piece.physicsBody?.velocity = .zero
            piece.physicsBody?.angularVelocity = 0
            piece.physicsBody?.isDynamic = false
        }
        isFrozen = true
    }

    private func unfreezeAll() {
        guard isFrozen else { return }
        for piece in pieces where activeTouches.values.contains(where: { $0 === piece }) == false {
            piece.physicsBody?.isDynamic = true
        }
        isFrozen = false
        settledTimer = 0
    }

    private func updateExpressions() {
        for piece in pieces {
            guard activeTouches.values.contains(where: { $0 === piece }) == false else { continue }
            guard piece.physicsBody?.isDynamic ?? false else { continue }
            if piece.velocity.dy < -200 {
                piece.reactFalling()
            }
        }
    }

    private func sleepyIdleTick() {
        let sleepers = pieces.filter { piece in
            !piece.isAwake
            && activeTouches.values.contains(where: { $0 === piece }) == false
            && piece.speed2D < 8
        }
        guard let piece = sleepers.randomElement() else { return }
        if Bool.random() { piece.yawn() } else { piece.blink() }
    }

    private func updateWake() {
        let resting = pieces.filter { piece in
            activeTouches.values.contains(where: { $0 === piece }) == false
            && piece.speed2D < 12
            && isResting(piece)
        }
        let topmost = resting.max(by: { $0.topY < $1.topY })

        for piece in pieces where piece !== topmost && piece !== awakePiece {
            piece.setWakeAnticipation(0)
        }

        guard let top = topmost, top.topY > wakeThresholdY else {
            if let topmost {
                let anticipationStart = wakeThresholdY - 70 * pieceScale
                let progress = (topmost.topY - anticipationStart) / max(1, wakeThresholdY - anticipationStart)
                topmost.setWakeAnticipation(progress)
            }
            if let awake = awakePiece { awake.sleep(); awakePiece = nil }
            return
        }

        if awakePiece !== top {
            awakePiece?.sleep()
            awakePiece = top
            top.wake()
            if lastUpdate - lastWakeCelebration > 2.4 {
                lastWakeCelebration = lastUpdate
                celebrateWake(at: top.position)
            }
        }
    }

    private func celebrateWake(at point: CGPoint) {
        stageCelebrationUntil = lastUpdate + 0.72
        let tower = pieces
            .filter { piece in activeTouches.values.contains(where: { $0 === piece }) == false }
            .sorted { $0.position.y < $1.position.y }
        for (index, piece) in tower.enumerated() {
            let wakeSettleDelay = piece === awakePiece ? 0.34 : 0
            piece.playTowerPulse(delay: Double(index) * 0.045 + wakeSettleDelay, isTop: piece === awakePiece)
        }

        let capstonePoint = CGPoint(x: point.x, y: point.y + 30 * pieceScale)
        TouchFeedbackAnimator.bubblePopRing(in: self, at: capstonePoint, radius: 30 * pieceScale, color: WarmShelfPalette.butter)
        for index in 0..<3 {
            let mote = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...3.6))
            mote.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.7)
            mote.strokeColor = .clear
            mote.position = capstonePoint
            mote.zPosition = 90
            addChild(mote)
            let angle = CGFloat(index) / 3 * .pi * 2
            let move = SKAction.moveBy(x: cos(angle) * 40, y: sin(angle) * 28 + 18, duration: 0.7)
            move.timingMode = .easeOut
            mote.run(.sequence([.group([move, .fadeOut(withDuration: 0.7)]), .removeFromParent()]))
        }
        AudioManager.shared.playStackWake()   // haptic fires inside
    }

    private func updateStageFocus() {
        let resting = pieces.filter { piece in
            activeTouches.values.contains(where: { $0 === piece }) == false
            && isResting(piece)
        }
        guard let top = resting.max(by: { $0.topY < $1.topY }) else { return }
        let progress = ((top.topY - groundLineY) / max(1, wakeThresholdY - groundLineY)).clamped(to: 0...1)
        let celebrating = lastUpdate < stageCelebrationUntil
        towerWallGlow?.alpha = 0.48 + progress * 0.24 + (celebrating ? 0.18 : 0)
        towerWallGlow?.yScale = 0.92 + progress * 0.12
        towerFloorGlow?.alpha = 0.56 + progress * 0.18 + (celebrating ? 0.12 : 0)
        towerFloorGlow?.xScale = 0.96 + progress * 0.08
    }

    private func replenishPileIfNeeded() {
        let inPile = pieces.filter { piece in
            activeTouches.values.contains(where: { $0 === piece }) == false
            && (trayRect.minX...trayRect.maxX).contains(piece.position.x)
            && piece.position.y < groundLineY + piece.bodySize.height * 1.4
            && piece.speed2D < 14
        }
        if inPile.count < pileTarget, pieces.count < maxPieces {
            spawnPilePiece(animated: true)
        }
    }


    override func accessibilityElements(in view: SKView) -> [UIAccessibilityElement] {
        var elements = super.accessibilityElements(in: view)
        elements.append(contentsOf: pieces.prefix(10).map { piece in
            makeActivatableAccessibilityElement(
                in: view,
                label: piece.isSignatureHero
                    ? (piece.isAwake ? "happy sleepy friend" : "sleepy stacking friend")
                    : (piece.isAwake ? "happy stacking stone" : "soft stacking stone"),
                scenePosition: piece.position,
                size: CGSize(width: piece.bodySize.width * 1.3, height: piece.bodySize.height * 1.3),
                traits: .button
            ) { [weak piece] in
                guard let piece else { return }
                piece.wake()
                AudioManager.shared.playStackLift()
            }
        })
        return elements
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
