import SpriteKit
import UIKit

/// A finite practical-care toy: rub a muddy felt vehicle, let its suds settle, then say goodbye.
/// Cleaning lives in WashModel; this scene owns gestures, bounded effects and the quiet pause.
final class WashScene: BaseToyScene {
    override var toyVoice: AudioManager.LullSoundVoice { .none }
    override var firstSessionHintKey: String? { "hint.wash" }
    override func firstSessionHintPoint() -> CGPoint { vehicle?.position ?? CGPoint(x: size.width / 2, y: size.height * 0.55) }

    private enum Phase { case arriving, washing, delighted, leaving, waiting }
    private struct Rub {
        var point: CGPoint
        var timestamp: TimeInterval
        let tool: WashTool
    }
    private struct Drop {
        let node: SKShapeNode
        var lifetime: TimeInterval = 0
        var velocity = CGVector.zero
    }
    private static var cast = WashCastDeck()
    private var kind: WashVehicleKind = .fireTruck
    private var model = WashModel(patches: [])
    private var phase: Phase = .arriving
    private var phaseTime: TimeInterval = 0
    private var sceneTime: TimeInterval = 0
    private var lastFrame: TimeInterval = 0
    private var visualAccumulator: TimeInterval = 0
    private var isResting = false
    private var selectedTool: WashTool = .sponge
    private var rubs: [UITouch: Rub] = [:]
    private var vehicle: WashVehicleNode?
    private var vehicleHome = CGPoint.zero
    private var bodyCanvas = CGSize.zero
    private let bay = SKNode()
    private let world = SKNode()
    private let tools = SKNode()
    private let cursor = SKNode()
    private let dropsLayer = SKNode()
    private let mudCrop = SKCropNode()
    private let foamCrop = SKCropNode()
    private let sparkleCrop = SKCropNode()
    private var mudNodes: [SKSpriteNode] = []
    private var foamNodes: [SKShapeNode] = []
    private var dropPool: [Drop] = []
    private var dropIndex = 0
    private var toolHomes: [WashTool: CGPoint] = [:]
    private var toolHighlights: [WashTool: SKShapeNode] = [:]
    private var lastFoam: TimeInterval = -10
    private var lastRinse: TimeInterval = -10
    private var lastDrop: TimeInterval = -10
    private var lastHaptic: TimeInterval = -10
    private var lastReaction: TimeInterval = -10
    private var lastScrubBlink: TimeInterval = -10
    private var faceAwakeUntil: TimeInterval = 0
    private var didTouchVehicle = false

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        ambientMoteInterval = 60
        bay.zPosition = 1; addChild(bay)
        world.zPosition = 12; addChild(world)
        dropsLayer.zPosition = 24; addChild(dropsLayer)
        tools.zPosition = 30; addChild(tools)
        cursor.zPosition = 50; addChild(cursor)
        kind = Self.cast.next()
        buildLayout()
        startVehicle(playArrival: false)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 160, size.height > 160, vehicle != nil else { return }
        clearHands(); AudioManager.shared.stopWashAudio()
        // Model, cast, tool and phase progress survive. Only the furniture is re-laid.
        buildLayout()
        rebuildVehicle()
        syncPhasePose()
    }

    private func buildLayout() {
        guard size.width > 160, size.height > 160 else { return }
        bay.removeAllChildren(); tools.removeAllChildren(); cursor.removeAllChildren()
        dropsLayer.removeAllChildren(); dropPool.removeAll(); toolHomes.removeAll(); toolHighlights.removeAll()
        let play = safePlayRect()
        let landscape = size.width > size.height
        let trayHeight: CGFloat = min(112, max(74, play.height * 0.18))
        let trayY = play.minY + trayHeight / 2 + 5
        let trayW = landscape ? min(104, play.width * 0.18) : min(play.width * 0.91, 570)
        let traySize = landscape ? CGSize(width: trayW, height: min(play.height * 0.91, 330)) : CGSize(width: trayW, height: trayHeight)
        let trayCenter = landscape ? CGPoint(x: play.maxX - trayW / 2, y: play.midY) : CGPoint(x: play.midX, y: trayY)
        let availableH = landscape ? play.height * 0.96 : max(90, play.maxY - (trayY + trayHeight / 2 + 20))
        let availableW = landscape ? max(100, play.width - trayW - 25) : play.width
        let width = min(availableW * 0.96, availableH * 1.6, landscape ? 830 : 760)
        bodyCanvas = CGSize(width: width, height: width / 1.6)
        vehicleHome = landscape ? CGPoint(x: play.minX + availableW / 2, y: play.midY)
            : CGPoint(x: play.midX, y: trayY + trayHeight / 2 + 18 + availableH * 0.47)
        if !landscape {
            vehicleHome.y = min(play.maxY - bodyCanvas.height / 2, max(trayY + trayHeight / 2 + 12 + bodyCanvas.height / 2, vehicleHome.y))
        }

        if let art = ToyArt.sprite("wash-bay", fit: size) {
            let multiplier = max(size.width / art.size.width, size.height / art.size.height)
            art.size = CGSize(width: art.size.width * multiplier, height: art.size.height * multiplier)
            art.position = CGPoint(x: size.width / 2, y: size.height / 2)
            bay.addChild(art)
        } else {
            let wall = SKSpriteNode(color: WarmShelfPalette.sage.withAlpha(0.14), size: size)
            wall.position = CGPoint(x: size.width / 2, y: size.height / 2); bay.addChild(wall)
            let floorH = max(1, vehicleHome.y - bodyCanvas.height * 0.31)
            let floor = SKSpriteNode(color: WarmShelfPalette.warmCream, size: CGSize(width: size.width, height: floorH))
            floor.position = CGPoint(x: size.width / 2, y: floorH / 2); bay.addChild(floor)
            let mat = SKShapeNode(ellipseOf: CGSize(width: bodyCanvas.width * 0.90, height: bodyCanvas.height * 0.20))
            mat.fillColor = WarmShelfPalette.waterBlue.withAlpha(0.16); mat.strokeColor = .clear
            mat.position = CGPoint(x: vehicleHome.x, y: vehicleHome.y - bodyCanvas.height * 0.35); bay.addChild(mat)
        }
        let tray = SKShapeNode(rectOf: traySize, cornerRadius: min(traySize.width, traySize.height) * 0.25)
        tray.fillColor = WarmShelfPalette.warmCream; tray.strokeColor = WarmShelfPalette.sand.withAlpha(0.35)
        tray.position = trayCenter; tools.addChild(tray)
        let toolSide = min(traySize.width, trayHeight) * 0.76
        for (index, tool) in WashTool.allCases.enumerated() {
            let home = landscape ? CGPoint(x: trayCenter.x, y: trayCenter.y - CGFloat(index - 1) * traySize.height * 0.29)
                : CGPoint(x: play.midX + CGFloat(index - 1) * trayW * 0.29, y: trayY)
            toolHomes[tool] = home
            let highlight = SKShapeNode(ellipseOf: CGSize(width: trayHeight * 0.92, height: trayHeight * 0.82))
            highlight.fillColor = WarmShelfPalette.butter.withAlpha(0.16)
            highlight.strokeColor = WarmShelfPalette.sand.withAlpha(0.50); highlight.lineWidth = 2
            highlight.position = home; tools.addChild(highlight); toolHighlights[tool] = highlight
            let art = makeTool(tool, size: toolSide)
            art.position = home; tools.addChild(art)
        }
        updateToolHighlight()
        cursor.addChild(makeTool(selectedTool, size: min(86, max(58, bodyCanvas.height * 0.25))))
        cursor.alpha = 0
        for _ in 0..<60 {
            let drop = SKShapeNode(ellipseOf: CGSize(width: 3, height: 6))
            drop.fillColor = WarmShelfPalette.waterBlue.withAlpha(0.50); drop.strokeColor = .clear
            drop.alpha = 0; dropsLayer.addChild(drop); dropPool.append(Drop(node: drop))
        }
    }

    private func makeTool(_ tool: WashTool, size side: CGFloat) -> SKNode {
        if let art = ToyArt.sprite("wash-tool-" + tool.rawValue, fit: CGSize(width: side, height: side)) { return art }
        let node = SKNode()
        let color: UIColor = tool == .sponge ? WarmShelfPalette.butter : (tool == .hose ? WarmShelfPalette.terracotta : WarmShelfPalette.waterBlue)
        let shape = SKShapeNode(rectOf: CGSize(width: side * 0.83, height: side * (tool == .hose ? 0.28 : 0.56)), cornerRadius: side * 0.16)
        shape.fillColor = color; shape.strokeColor = color.withAlpha(0.45); shape.lineWidth = 2
        ProceduralTexture.applyClayFill(to: shape, base: color, size: CGSize(width: side, height: side))
        node.addChild(shape)
        if tool == .hose {
            let nozzle = SKShapeNode(rectOf: CGSize(width: side * 0.35, height: side * 0.23), cornerRadius: side * 0.1)
            nozzle.fillColor = WarmShelfPalette.paperHighlight; nozzle.strokeColor = .clear
            nozzle.position = CGPoint(x: side * 0.29, y: side * 0.10); nozzle.zRotation = -0.3; node.addChild(nozzle)
        } else if tool == .towel {
            let stripe = SKShapeNode(rectOf: CGSize(width: side * 0.73, height: side * 0.05), cornerRadius: side * 0.02)
            stripe.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.75); stripe.strokeColor = .clear
            stripe.position.y = side * 0.12; node.addChild(stripe)
        }
        return node
    }

    private func startVehicle(playArrival: Bool) {
        phase = .arriving; phaseTime = 0; didTouchVehicle = false
        rebuildVehicle()
        if let vehicle {
            model = WashModel(patches: vehicle.freshPatches(), canvasAspectRatio: Double(bodyCanvas.width / bodyCanvas.height))
            rebuildSurface()
        }
        syncPhasePose()
        if playArrival { AudioManager.shared.play(cue: "wash.arrive") }
    }

    private func rebuildVehicle() {
        mudCrop.removeFromParent(); foamCrop.removeFromParent(); sparkleCrop.removeFromParent()
        world.removeAllChildren()
        let node = WashVehicleNode(kind: kind, canvas: bodyCanvas)
        vehicle = node; world.addChild(node)
        node.position = vehicleHome
        node.addSurface(mudCrop); node.addSurface(foamCrop); node.addSurface(sparkleCrop)
        mudCrop.zPosition = 5; foamCrop.zPosition = 6; sparkleCrop.zPosition = 7
        mudCrop.maskNode = node.makeMask(); foamCrop.maskNode = node.makeMask(); sparkleCrop.maskNode = node.makeMask()
        rebuildSurface()
    }

    private func rebuildSurface() {
        guard let vehicle else { return }
        mudCrop.removeAllChildren(); foamCrop.removeAllChildren(); sparkleCrop.removeAllChildren()
        mudNodes.removeAll(); foamNodes.removeAll()
        for (index, patch) in model.patches.enumerated() {
            let side = CGFloat(patch.radius) * bodyCanvas.height * 2
            let sprite: SKSpriteNode
            if let art = ToyArt.sprite("wash-mud-\(index % 4 + 1)", fit: CGSize(width: side, height: side)) {
                sprite = art
            } else {
                sprite = SKSpriteNode(texture: Self.mudTexture)
                sprite.size = CGSize(width: side, height: side * (index.isMultiple(of: 3) ? 0.76 : 0.96))
            }
            sprite.position = vehicle.point(patch.center)
            sprite.zRotation = CGFloat(index % 9) * 0.22
            sprite.color = UIColor(hex: index.isMultiple(of: 3) ? 0x75533A : 0x97734E)
            sprite.colorBlendFactor = 0.25
            mudCrop.addChild(sprite); mudNodes.append(sprite)
        }
        // Two bubbles per patch, at most 80, are reused rather than emitted into an endless scene.
        for index in 0..<min(80, model.patches.count * 2) {
            let patch = model.patches[index / 2]
            let radius = max(3, CGFloat(patch.radius) * bodyCanvas.height * (index.isMultiple(of: 2) ? 0.77 : 0.49))
            let bubble = SKShapeNode(circleOfRadius: radius)
            bubble.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.94)
            bubble.strokeColor = WarmShelfPalette.bubblePearl.withAlpha(0.82); bubble.lineWidth = 1.4
            let center = vehicle.point(patch.center)
            bubble.position = CGPoint(x: center.x + (index.isMultiple(of: 2) ? -radius * 0.24 : radius * 0.77),
                                      y: center.y + (index.isMultiple(of: 2) ? radius * 0.13 : -radius * 0.41))
            foamCrop.addChild(bubble); foamNodes.append(bubble)
        }
        syncSurface()
    }

    private func syncSurface() {
        for (index, patch) in model.patches.enumerated() where mudNodes.indices.contains(index) {
            mudNodes[index].alpha = CGFloat(patch.dirt) * 0.94
        }
        for (index, bubble) in foamNodes.enumerated() {
            bubble.alpha = CGFloat(model.patches[index / 2].foam)
        }
    }

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        guard !isResting, vehicle != nil else { lastFrame = 0; return }
        let delta = lastFrame == 0 ? 0 : min(0.06, max(0, currentTime - lastFrame))
        lastFrame = currentTime; sceneTime += delta; phaseTime += delta
        switch phase {
        case .arriving:
            syncPhasePose()
            if phaseTime >= 1.05 { phase = .washing; phaseTime = 0; vehicle?.position = vehicleHome }
        case .washing:
            model.advanceTime(by: delta)
            // A held hose has real contact time; a stationary sponge/towel never farms taps.
            if let rub = rubs.values.first(where: { $0.tool == .hose }) {
                applyStroke(from: rub.point, to: rub.point, strength: delta * 0.75, tool: .hose)
            }
            if model.isComplete && didTouchVehicle { finishVehicle() }
        case .delighted:
            if phaseTime >= 0.95 { phase = .leaving; phaseTime = 0; clearHands() }
        case .leaving:
            syncPhasePose()
            if phaseTime >= 1.05 {
                phase = .waiting; phaseTime = 0; vehicle?.isHidden = true
            }
        case .waiting:
            if phaseTime >= 2 {
                kind = Self.cast.next(); startVehicle(playArrival: true)
            }
        }
        visualAccumulator += delta
        if visualAccumulator >= 1.0 / 24 {
            visualAccumulator = 0
            syncSurface()
            if AmbientAnimator.reduceMotion { resetCursorPose(); vehicle?.resetReaction() }
            let look = rubs.values.first.map { vehicle?.convert($0.point, from: self) ?? .zero }
            vehicle?.setFace(awake: !rubs.isEmpty || sceneTime < faceAwakeUntil,
                             clean: model.cleanFraction, look: look, delighted: phase == .delighted)
        }
        for index in dropPool.indices where dropPool[index].lifetime > 0 {
            dropPool[index].lifetime = max(0, dropPool[index].lifetime - delta)
            let node = dropPool[index].node
            node.position.x += dropPool[index].velocity.dx * delta
            node.position.y += dropPool[index].velocity.dy * delta
            dropPool[index].velocity.dy -= 90 * delta
            node.alpha = CGFloat(min(1, dropPool[index].lifetime / 0.22)) * 0.65
        }
    }

    private func syncPhasePose() {
        guard let vehicle else { return }
        vehicle.isHidden = phase == .waiting
        guard phase == .arriving || phase == .leaving else {
            vehicle.position = vehicleHome; vehicle.alpha = 1; return
        }
        let previousX = vehicle.position.x
        let progress = min(1, max(0, phaseTime / 1.05))
        if AmbientAnimator.reduceMotion {
            vehicle.position = vehicleHome
            vehicle.alpha = phase == .arriving ? CGFloat(min(1, progress * 5)) : (phase == .leaving ? CGFloat(max(0, 1 - progress * 5)) : 1)
        } else {
            let eased = progress * progress * (3 - 2 * progress)
            let distance = size.width * 0.5 + bodyCanvas.width * 0.55
            vehicle.position = CGPoint(x: vehicleHome.x + (phase == .arriving ? -distance * (1 - eased) : distance * eased), y: vehicleHome.y)
            vehicle.alpha = 1
            vehicle.roll(distance: vehicle.position.x - previousX)
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isResting else { return }
        HapticsManager.shared.prepareForTouch()
        for touch in touches {
            let point = touch.location(in: self)
            if consumeShelfReturnTouch(at: point) { continue }
            if let tool = toolAt(point) {
                selectTool(tool)
                rubs[touch] = Rub(point: point, timestamp: touch.timestamp, tool: selectedTool)
                cursor.position = point; cursor.alpha = 0.82
                updateTouchFeedback(from: point, to: point, tool: selectedTool)
            } else if phase == .washing, let vehicle,
                      vehicle.canvasRect.insetBy(dx: -20, dy: -20).contains(vehicle.convert(point, from: self)) {
                rubs[touch] = Rub(point: point, timestamp: touch.timestamp, tool: selectedTool)
                cursor.position = point; cursor.alpha = 0.82
                updateTouchFeedback(from: point, to: point, tool: selectedTool)
                faceAwakeUntil = sceneTime + 0.8
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isResting else { return }
        for touch in touches {
            guard var rub = rubs[touch] else { continue }
            let point = touch.location(in: self)
            cursor.position = point; cursor.alpha = 0.82
            updateTouchFeedback(from: rub.point, to: point, tool: rub.tool)
            let distance = hypot(point.x - rub.point.x, point.y - rub.point.y)
            let elapsed = min(0.08, max(0, touch.timestamp - rub.timestamp))
            if distance >= 0.8, phase == .washing {
                let strength = min(1.25, Double(distance / brushRadius) * 0.38 + elapsed * 0.22)
                applyStroke(from: rub.point, to: point, strength: strength, tool: rub.tool)
                rub.point = point; rub.timestamp = touch.timestamp
            } else if phase != .washing {
                rub.point = point; rub.timestamp = touch.timestamp
            }
            rubs[touch] = rub
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { release(touches) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { release(touches) }

    private func release(_ touches: Set<UITouch>) {
        for touch in touches { rubs.removeValue(forKey: touch) }
        if rubs.isEmpty {
            cursor.alpha = 0
            resetCursorPose()
            vehicle?.settleCarePose()
        }
        if !rubs.values.contains(where: { $0.tool == .hose }) { AudioManager.shared.stopWashRinse() }
    }

    // Touch coordinates stay on the fixed vehicle root; only its art follows the hand.
    private func updateTouchFeedback(from start: CGPoint, to end: CGPoint, tool: WashTool) {
        let drag = CGVector(dx: end.x - start.x, dy: end.y - start.y)
        var contact = false
        if phase == .washing, let vehicle {
            let local = vehicle.convert(end, from: self)
            contact = vehicle.hasContact(at: local)
            if contact {
                let localStart = vehicle.convert(start, from: self)
                vehicle.setCarePose(at: local, drag: CGVector(dx: local.x - localStart.x, dy: local.y - localStart.y), tool: tool)
                if vehicle.nearFace(local), sceneTime - lastScrubBlink > 4 {
                    lastScrubBlink = sceneTime
                    vehicle.blink()
                }
            } else {
                vehicle.settleCarePose()
            }
        }
        guard let art = cursor.children.first else { return }
        guard !AmbientAnimator.reduceMotion else { resetCursorPose(); return }
        let lag = CGPoint(x: min(4, max(-4, -drag.dx * 0.16)), y: min(3, max(-3, -drag.dy * 0.16)))
        let tilt = min(0.20, max(-0.20, drag.dx * 0.015))
        let follow = SKAction.group([.move(to: lag, duration: 0.10), .rotate(toAngle: tilt, duration: 0.10),
                                     .scale(to: contact ? 0.97 : 1, duration: 0.10)])
        let settle = SKAction.group([.move(to: .zero, duration: 0.22), .rotate(toAngle: 0, duration: 0.22)])
        art.run(.sequence([follow, settle]), withKey: "wash.toolPose")
    }

    private func resetCursorPose() {
        guard let art = cursor.children.first else { return }
        art.removeAction(forKey: "wash.toolPose")
        art.position = .zero; art.zRotation = 0; art.setScale(1)
    }

    private var brushRadius: CGFloat { min(104, max(46, bodyCanvas.height * 0.22)) }

    private func applyStroke(from start: CGPoint, to end: CGPoint, strength: Double, tool: WashTool) {
        guard phase == .washing, !isResting, let vehicle, bodyCanvas.height > 0 else { return }
        let distance = hypot(end.x - start.x, end.y - start.y)
        let samples = min(12, max(1, Int(ceil(distance / (brushRadius * 0.40)))))
        let oldFoam = model.foamFraction
        var removed = 0.0; var added = 0.0; var affected = 0
        for sample in 1...samples {
            let t = CGFloat(sample) / CGFloat(samples)
            let worldPoint = CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t)
            let local = vehicle.convert(worldPoint, from: self)
            let result = model.applyStroke(at: vehicle.fraction(local), radius: Double(brushRadius / bodyCanvas.height),
                                           strength: strength / Double(samples), tool: tool)
            removed += result.removedMud; added += result.addedFoam; affected += result.affectedPatches
        }
        guard affected > 0 else { if tool == .hose { AudioManager.shared.stopWashRinse() }; return }
        didTouchVehicle = true; faceAwakeUntil = sceneTime + 1
        if sceneTime - lastHaptic >= 0.18, distance >= 0.8 {
            lastHaptic = sceneTime; HapticsManager.shared.impact(style: .soft, intensity: 0.22)
        }
        if tool == .sponge, added > 0.01, sceneTime - lastFoam >= 0.34 {
            lastFoam = sceneTime; AudioManager.shared.play(cue: "wash.foam")
        }
        if tool == .hose {
            if sceneTime - lastDrop >= 0.10 { lastDrop = sceneTime; emitDrops(at: end) }
            if (removed > 0.0001 || oldFoam > model.foamFraction + 0.0001), sceneTime - lastRinse >= 0.42 {
                lastRinse = sceneTime; AudioManager.shared.play(cue: "wash.rinse")
            }
        }
        let local = vehicle.convert(end, from: self)
        if sceneTime - lastReaction > 5.5, vehicle.nearWheel(local) || vehicle.nearFace(local) && model.foamFraction > 0.16 {
            lastReaction = sceneTime; vehicle.littleReaction(towel: tool == .towel)
        }
    }

    private func emitDrops(at point: CGPoint) {
        guard !AmbientAnimator.reduceMotion, !dropPool.isEmpty else { return }
        for offset in 0..<4 {
            let index = dropIndex % dropPool.count; dropIndex += 1
            dropPool[index].node.position = CGPoint(x: point.x + CGFloat(offset - 2) * 5, y: point.y - 8)
            dropPool[index].node.alpha = 0.65
            dropPool[index].lifetime = 0.36 + Double(offset) * 0.025
            dropPool[index].velocity = CGVector(dx: CGFloat(offset - 2) * 12, dy: -55)
        }
    }

    private func toolAt(_ point: CGPoint) -> WashTool? {
        let nearest = WashTool.allCases.compactMap { tool -> (WashTool, CGFloat)? in
            guard let home = toolHomes[tool] else { return nil }
            return (tool, hypot(point.x - home.x, point.y - home.y))
        }.min { $0.1 < $1.1 }
        guard let nearest, nearest.1 <= min(56, max(40, bodyCanvas.height * 0.16)) else { return nil }
        return nearest.0
    }

    private func selectTool(_ tool: WashTool) {
        clearHands(); selectedTool = tool; updateToolHighlight()
        cursor.removeAllChildren()
        cursor.addChild(makeTool(tool, size: min(86, max(58, bodyCanvas.height * 0.25))))
        HapticsManager.shared.impact(style: .light, intensity: 0.20)
    }

    private func updateToolHighlight() {
        for (tool, node) in toolHighlights { node.alpha = tool == selectedTool ? 1 : 0.14 }
    }

    private func finishVehicle() {
        guard phase == .washing else { return }
        phase = .delighted; phaseTime = 0; clearHands()
        vehicle?.setFace(awake: true, clean: 1, look: nil, delighted: true)
        vehicle?.littleReaction(towel: false)
        HapticsManager.shared.impact(style: .soft, intensity: 0.42)
        AudioManager.shared.play(cue: "wash.sparkle")
        AudioManager.shared.play(cue: "wash.toot." + kind.rawValue)
        showSparkle()
    }

    private func showSparkle() {
        sparkleCrop.removeAllChildren()
        if AmbientAnimator.reduceMotion {
            let glow = SKSpriteNode(color: WarmShelfPalette.paperHighlight.withAlpha(0.25), size: bodyCanvas)
            sparkleCrop.addChild(glow)
            glow.run(.sequence([.fadeOut(withDuration: 0.8), .removeFromParent()]))
        } else {
            let shine = SKSpriteNode(texture: Self.shineTexture)
            shine.size = CGSize(width: bodyCanvas.width * 0.16, height: bodyCanvas.height * 1.2)
            shine.position.x = -bodyCanvas.width * 0.6; shine.zRotation = -0.18
            sparkleCrop.addChild(shine)
            shine.run(.sequence([.moveTo(x: bodyCanvas.width * 0.6, duration: 0.72), .fadeOut(withDuration: 0.14), .removeFromParent()]))
        }
    }

    private func clearHands() {
        rubs.removeAll(); cursor.alpha = 0; resetCursorPose(); vehicle?.settleCarePose()
        AudioManager.shared.stopWashRinse()
    }

    override func teardownToyAudio() {
        clearHands(); AudioManager.shared.stopWashAudio(); super.teardownToyAudio(); lastFrame = 0
    }

    override func suspendToyForRest() {
        isResting = true; clearHands(); lastFrame = 0
        vehicle?.resetReaction()
        super.suspendToyForRest()
    }

    override func resumeToyAfterRest() {
        super.resumeToyAfterRest(); isResting = false; lastFrame = 0
    }

    override func accessibilityElements(in view: SKView) -> [UIAccessibilityElement] {
        var elements = super.accessibilityElements(in: view)
        for tool in WashTool.allCases {
            guard let home = toolHomes[tool] else { continue }
            let name = tool == .sponge ? "Sponge" : (tool == .hose ? "Hose" : "Towel")
            elements.append(makeActivatableAccessibilityElement(in: view, label: name,
                scenePosition: home, size: CGSize(width: 80, height: 80),
                traits: tool == selectedTool ? [.button, .selected] : .button) { [weak self] in self?.selectTool(tool) })
        }
        if phase == .washing {
            elements.append(makeActivatableAccessibilityElement(in: view,
                label: "Muddy \(kind.spokenName). Rub to wash it.", scenePosition: vehicleHome, size: bodyCanvas) { [weak self] in
                guard let self, !self.isResting, self.phase == .washing else { return }
                self.model.cleanQuarter(); self.didTouchVehicle = true; self.faceAwakeUntil = self.sceneTime + 1
                self.syncSurface(); self.vehicle?.littleReaction(towel: true)
                HapticsManager.shared.impact(style: .soft, intensity: 0.25)
                if self.model.isComplete { self.finishVehicle() }
            })
        }
        return elements
    }

    private static let mudTexture: SKTexture = {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 96, height: 96), format: format)
        return SKTexture(image: renderer.image { _ in
            UIColor(hex: 0x8D6B4B).setFill()
            for (x,y,r): (CGFloat,CGFloat,CGFloat) in [(48,48,34),(24,42,15),(60,24,16),(74,57,14),(42,76,13)] {
                UIBezierPath(ovalIn: CGRect(x: x-r, y: y-r, width: r*2, height: r*2)).fill()
            }
            UIColor(hex: 0xB39876).withAlpha(0.13).setFill()
            for i in 0..<42 {
                let x = CGFloat((i * 37) % 66 + 15), y = CGFloat((i * 23) % 62 + 18)
                UIBezierPath(ovalIn: CGRect(x: x, y: y, width: 1.2, height: 0.8)).fill()
            }
        })
    }()
    private static let shineTexture: SKTexture = {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return SKTexture(image: UIGraphicsImageRenderer(size: CGSize(width: 64, height: 128), format: format).image { context in
            let colors = [UIColor.clear.cgColor, UIColor.white.withAlpha(0.32).cgColor, UIColor.clear.cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0,0.5,1]) {
                context.cgContext.drawLinearGradient(gradient, start: CGPoint(x: 0,y: 64), end: CGPoint(x: 64,y: 64), options: [])
            }
        })
    }()
}

/// One live felt friend. Body and separate spinning wheels share a measured fractional rig.
private final class WashVehicleNode: SKNode {
    let kind: WashVehicleKind
    let canvas: CGSize
    let rig: WashVehicleRig
    private let texture: SKTexture
    private let alphaMap: WashAlphaMap
    private let artRoot = SKNode()
    private let face = SKNode()
    private var pupils: [SKShapeNode] = []
    private var eyes: [SKNode] = []
    private var sleepy: [SKShapeNode] = []
    private var cheeks: [SKShapeNode] = []
    private let mouth = SKShapeNode()
    private var wheels: [(node: SKNode, radius: CGFloat)] = []
    private var faceBucket = -1

    var canvasRect: CGRect { CGRect(x: -canvas.width/2, y: -canvas.height/2, width: canvas.width, height: canvas.height) }

    init(kind: WashVehicleKind, canvas: CGSize) {
        self.kind = kind; self.canvas = canvas; self.rig = WashVehicleRig.forVehicle(kind)
        var image = UIImage(named: kind.imageName) ?? Self.fallback(kind, rig: WashVehicleRig.forVehicle(kind))
        var map = WashAlphaMap(image: image)
        if !map.hasOpaqueSamples {
            image = Self.fallback(kind, rig: WashVehicleRig.forVehicle(kind))
            map = WashAlphaMap(image: image)
        }
        texture = SKTexture(image: image)
        alphaMap = map
        super.init()
        addChild(artRoot)
        let body = SKSpriteNode(texture: texture); body.size = canvas; body.zPosition = 3; artRoot.addChild(body)
        for wheel in rig.wheels {
            let radius = CGFloat(wheel.radius) * canvas.height
            let node: SKNode
            if let art = ToyArt.sprite("wash-wheel", fit: CGSize(width: radius*2, height: radius*2)) {
                node = art
            } else {
                let circle = SKShapeNode(circleOfRadius: radius)
                circle.fillColor = WarmShelfPalette.raisin; circle.strokeColor = WarmShelfPalette.cocoa; circle.lineWidth = radius * 0.10
                let hub = SKShapeNode(circleOfRadius: radius * 0.42)
                hub.fillColor = WarmShelfPalette.warmCream; hub.strokeColor = .clear; circle.addChild(hub)
                for angle in [CGFloat(0), .pi * 2 / 3, .pi * 4 / 3] {
                    let stitch = SKShapeNode(rectOf: CGSize(width: radius * 0.08, height: radius * 0.68), cornerRadius: radius * 0.04)
                    stitch.fillColor = WarmShelfPalette.sand; stitch.strokeColor = .clear; stitch.zRotation = angle; circle.addChild(stitch)
                }
                node = circle
            }
            node.position = point(wheel.center); node.zPosition = 2; artRoot.addChild(node); wheels.append((node, radius))
        }
        buildFace()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func point(_ fraction: WashPoint) -> CGPoint {
        CGPoint(x: (CGFloat(fraction.x) - 0.5) * canvas.width,
                y: (0.5 - CGFloat(fraction.y)) * canvas.height)
    }
    func fraction(_ local: CGPoint) -> WashPoint {
        WashPoint(x: Double(local.x / canvas.width + 0.5), y: Double(0.5 - local.y / canvas.height))
    }
    func makeMask() -> SKSpriteNode { let mask = SKSpriteNode(texture: texture); mask.size = canvas; return mask }
    func addSurface(_ node: SKNode) { artRoot.addChild(node) }

    func hasContact(at local: CGPoint) -> Bool {
        alphaMap.opaque(fraction(local)) || rig.wheels.contains {
            hypot(local.x - point($0.center).x, local.y - point($0.center).y) <= CGFloat($0.radius) * canvas.height
        }
    }

    func setCarePose(at local: CGPoint, drag: CGVector, tool: WashTool) {
        guard !AmbientAnimator.reduceMotion else { resetCarePose(); return }
        let pressure: CGFloat = tool == .hose ? 0.003 : (tool == .towel ? 0.006 : 0.009)
        let lean = min(0.016, max(-0.016, -local.x / max(1, canvas.width) * 0.014 + drag.dx / max(1, canvas.width) * 0.12))
        let follow = CGPoint(x: min(3, max(-3, drag.dx * 0.06)), y: -canvas.height * pressure * 0.4)
        artRoot.run(.group([.move(to: follow, duration: 0.12), .rotate(toAngle: lean, duration: 0.12),
                            .scaleX(to: 1 + pressure * 0.35, duration: 0.12),
                            .scaleY(to: 1 - pressure, duration: 0.12)]), withKey: "wash.carePose")
    }

    func settleCarePose() {
        guard !AmbientAnimator.reduceMotion else { resetCarePose(); return }
        artRoot.run(.group([.move(to: .zero, duration: 0.28), .rotate(toAngle: 0, duration: 0.28),
                            .scale(to: 1, duration: 0.28)]), withKey: "wash.carePose")
    }

    private func resetCarePose() {
        artRoot.removeAction(forKey: "wash.carePose")
        artRoot.position = .zero; artRoot.zRotation = 0; artRoot.setScale(1)
    }

    func freshPatches() -> [WashMudPatch] {
        var candidates: [WashPoint] = []
        for row in 0..<10 { for column in 0..<16 {
            let x = (Double(column) + 0.5 + Double((row*13+column*7)%5-2)*0.055) / 16
            let y = (Double(row) + 0.5 + Double((row*3+column*11)%5-2)*0.055) / 10
            let point = WashPoint(x:x,y:y)
            if alphaMap.opaque(point) { candidates.append(point) }
        }}
        if candidates.isEmpty { candidates = alphaMap.opaqueCenters }
        // Opaque centres guarantee that every counted patch is visible/reachable. The GPU
        // alpha mask clips the splat edges; a thin ladder never hides an uncleanable patch.
        candidates.shuffle()
        let low = candidates.filter { $0.y > 0.46 }
        let high = candidates.filter { $0.y <= 0.46 }
        let ordered = Array(low.prefix(27)) + high + Array(low.dropFirst(27))
        let count = min(40, max(30, ordered.count))
        guard !ordered.isEmpty else {
            return (0..<30).map { i in WashMudPatch(center: WashPoint(x:0.18+Double(i%6)*0.12,y:0.47+Double(i/6)*0.045),radius:0.065) }
        }
        return (0..<count).map { index in
            WashMudPatch(center: ordered[index % ordered.count], radius: 0.047 + Double(index % 5) * 0.007)
        }
    }

    private func buildFace() {
        let r = CGFloat(rig.faceRadius) * canvas.height
        face.position = point(rig.faceCenter); face.zPosition = 9; artRoot.addChild(face)
        for side: CGFloat in [-1,1] {
            let eye = SKNode(); eye.position = CGPoint(x: side*r*0.39,y:r*0.16)
            let white = SKShapeNode(ellipseOf: CGSize(width:r*0.35,height:r*0.43))
            white.fillColor = WarmShelfPalette.paperHighlight; white.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.22); white.lineWidth = max(0.5,r*0.035); eye.addChild(white)
            let pupil = SKShapeNode(circleOfRadius:r*0.095)
            pupil.fillColor = WarmShelfPalette.raisin; pupil.strokeColor = .clear; eye.addChild(pupil)
            let glint = SKShapeNode(circleOfRadius:r*0.03)
            glint.fillColor = .white; glint.strokeColor = .clear; glint.position = CGPoint(x:-r*0.026,y:r*0.035); pupil.addChild(glint)
            pupils.append(pupil); eyes.append(eye); face.addChild(eye)
            let closed = SKShapeNode(); closed.position = eye.position
            let path = CGMutablePath(); path.move(to: CGPoint(x:-r*0.18,y:0)); path.addQuadCurve(to:CGPoint(x:r*0.18,y:0),control:CGPoint(x:0,y:-r*0.12))
            closed.path = path; closed.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.65); closed.lineWidth = max(1.3,r*0.07); closed.lineCap = .round; closed.fillColor = .clear
            sleepy.append(closed); face.addChild(closed)
            let cheek = SKShapeNode(ellipseOf:CGSize(width:r*0.26,height:r*0.13))
            cheek.fillColor = WarmShelfPalette.petal; cheek.strokeColor = .clear; cheek.position = CGPoint(x:side*r*0.47,y:-r*0.18)
            cheeks.append(cheek); face.addChild(cheek)
        }
        mouth.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.72); mouth.lineCap = .round
        mouth.lineWidth = max(1.5,r*0.07); mouth.fillColor = .clear; mouth.position.y = -r*0.24; face.addChild(mouth)
        setFace(awake:false,clean:0,look:nil,delighted:false)
    }

    func setFace(awake: Bool, clean: Double, look: CGPoint?, delighted: Bool) {
        let r = CGFloat(rig.faceRadius) * canvas.height
        eyes.forEach { $0.alpha = awake || delighted ? 1 : 0 }; sleepy.forEach { $0.alpha = awake || delighted ? 0 : 1 }
        let gaze = look.map { CGPoint(x: min(r*0.06,max(-r*0.06,($0.x-face.position.x)*0.018)), y:min(r*0.055,max(-r*0.055,($0.y-face.position.y)*0.018))) } ?? .zero
        pupils.forEach { $0.position = AmbientAnimator.reduceMotion ? .zero : gaze }
        cheeks.forEach { $0.alpha = min(0.8,0.15+CGFloat(clean)*0.60) }
        let bucket = delighted ? 10 : Int(min(1,max(0,clean))*7)
        guard bucket != faceBucket else { return }; faceBucket = bucket
        let path = CGMutablePath(); path.move(to:CGPoint(x:-r*0.29,y:0))
        path.addQuadCurve(to:CGPoint(x:r*0.29,y:0),control:CGPoint(x:0,y:-r*(delighted ? 0.49 : 0.12+CGFloat(clean)*0.30)))
        mouth.path = path
    }

    func nearWheel(_ p: CGPoint) -> Bool { rig.wheels.contains { hypot(p.x-point($0.center).x,p.y-point($0.center).y) < CGFloat($0.radius)*canvas.height*1.45 } }
    func nearFace(_ p: CGPoint) -> Bool { let c=point(rig.faceCenter); return hypot(p.x-c.x,p.y-c.y)<CGFloat(rig.faceRadius)*canvas.height*1.6 }
    func blink() {
        guard !AmbientAnimator.reduceMotion else { return }
        for eye in eyes {
            eye.run(.sequence([.scaleY(to: 0.08, duration: 0.07), .scaleY(to: 1, duration: 0.16)]), withKey: "wash.blink")
        }
    }

    func littleReaction(towel: Bool) {
        guard !AmbientAnimator.reduceMotion else { return }
        face.removeAction(forKey:"wash.react")
        let lift = SKAction.group([.rotate(toAngle:towel ? 0.06 : -0.04,duration:0.14),.scale(to:1.07,duration:0.14)])
        let settle = SKAction.group([.rotate(toAngle:0,duration:0.38),.scale(to:1,duration:0.38)])
        face.run(.sequence([lift,settle]),withKey:"wash.react")
    }
    func resetReaction() {
        face.removeAllActions(); face.setScale(1); face.zRotation = 0
        for eye in eyes { eye.removeAction(forKey: "wash.blink"); eye.yScale = 1 }
        resetCarePose()
    }
    func roll(distance: CGFloat) { guard !AmbientAnimator.reduceMotion else { return }; for wheel in wheels { wheel.node.zRotation -= distance / max(1,wheel.radius) } }

    private static func fallback(_ kind: WashVehicleKind, rig: WashVehicleRig) -> UIImage {
        let canvas = CGSize(width:800,height:500)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let palette: UIColor
        switch kind {
        case .fireTruck: palette = WarmShelfPalette.terracotta
        case .policeCar: palette = WarmShelfPalette.waterBlue
        case .tractor: palette = WarmShelfPalette.sage
        case .schoolBus: palette = WarmShelfPalette.butter
        case .digger: palette = UIColor(hex:0xD79B62)
        case .iceCreamVan: palette = WarmShelfPalette.petal
        }
        return UIGraphicsImageRenderer(size:canvas,format:format).image { _ in
            let main=CGRect(x:80,y:232,width:640,height:148)
            palette.setFill(); UIBezierPath(roundedRect:main,cornerRadius:48).fill()
            let face=CGPoint(x:CGFloat(rig.faceCenter.x)*800,y:CGFloat(rig.faceCenter.y)*500)
            let cab=CGRect(x:face.x-86,y:face.y-72,width:172,height:175)
            UIBezierPath(roundedRect:cab,cornerRadius:42).fill()
            WarmShelfPalette.waterBlue.withAlpha(0.82).setFill()
            UIBezierPath(roundedRect:CGRect(x:face.x-63,y:face.y-55,width:126,height:104),cornerRadius:27).fill()
            WarmShelfPalette.paperHighlight.withAlpha(0.63).setFill()
            UIBezierPath(roundedRect:CGRect(x:98,y:310,width:595,height:20),cornerRadius:10).fill()
            if kind == .schoolBus {
                for x:CGFloat in [145,243,341,439] {
                    WarmShelfPalette.waterBlue.withAlpha(0.65).setFill()
                    UIBezierPath(roundedRect:CGRect(x:x,y:185,width:75,height:91),cornerRadius:21).fill()
                }
            }
            if kind == .fireTruck {
                WarmShelfPalette.sand.setFill(); UIBezierPath(roundedRect:CGRect(x:133,y:175,width:327,height:15),cornerRadius:7).fill()
                for x:CGFloat in [145,199,253,307,361,415] { UIBezierPath(roundedRect:CGRect(x:x,y:161,width:9,height:41),cornerRadius:4).fill() }
            }
            if kind == .iceCreamVan {
                WarmShelfPalette.butter.setFill(); UIBezierPath(roundedRect:CGRect(x:212,y:176,width:56,height:44),cornerRadius:13).fill()
                WarmShelfPalette.paperHighlight.setFill(); UIBezierPath(ovalIn:CGRect(x:200,y:144,width:80,height:60)).fill()
            }
            for i in 0..<620 {
                palette.withAlpha(0.16).setFill()
                let x=CGFloat((i*73)%600+96),y=CGFloat((i*43)%124+242)
                UIBezierPath(ovalIn:CGRect(x:x,y:y,width:2.5,height:0.8)).fill()
            }
        }
    }
}

/// Read the delivered alpha once, then retain only a tiny sampled map for visible mud centres.
/// Image rows run from the top, matching WashPoint and the measured rigs.
private struct WashAlphaMap {
    private let width = 96
    private let height = 60
    private var samples: [UInt8]
    init(image: UIImage) {
        samples = Array(repeating:0,count:96*60)
        guard let cg = image.cgImage, let data = cg.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data), cg.bitsPerComponent == 8 else { return }
        let stride = cg.bitsPerPixel / 8
        let first = cg.alphaInfo == .first || cg.alphaInfo == .premultipliedFirst
        let last = cg.alphaInfo == .last || cg.alphaInfo == .premultipliedLast
        let only = cg.alphaInfo == .alphaOnly
        let little = cg.bitmapInfo.contains(.byteOrder32Little)
        let offset = only ? 0 : (little ? (first ? stride-1 : 0) : (first ? 0 : stride-1))
        for y in 0..<height { for x in 0..<width {
            let px = min(cg.width-1,x*cg.width/width), py = min(cg.height-1,y*cg.height/height)
            samples[y*width+x] = first || last || only ? bytes[py*cg.bytesPerRow+px*stride+offset] : 255
        }}
    }
    var hasOpaqueSamples: Bool { samples.contains { $0 > 72 } }
    var opaqueCenters: [WashPoint] {
        samples.indices.filter { samples[$0] > 72 }.map {
            WashPoint(x: (Double($0 % width) + 0.5) / Double(width),
                      y: (Double($0 / width) + 0.5) / Double(height))
        }
    }
    func opaque(_ point: WashPoint) -> Bool {
        guard point.x>=0,point.x<=1,point.y>=0,point.y<=1 else { return false }
        let x=min(width-1,max(0,Int(point.x*Double(width)))),y=min(height-1,max(0,Int(point.y*Double(height))))
        return samples[y*width+x] > 72
    }
}
