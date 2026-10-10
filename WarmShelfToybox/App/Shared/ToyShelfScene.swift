import SpriteKit
import UIKit
import CoreMotion

final class ToyShelfScene: BaseToyScene {
    var onToySelected: ((String) -> Void)?

    private var contentRoot = SKNode()
    private var isOpeningToy = false
    private var didBloomIntoToy = false
    private var lastBuiltSize = CGSize.zero
    private var hasAnimatedEntrance = false
    private var shelfHost: LullHostNode?    // Wren's node on the shelf
    private var lastHostPeek: TimeInterval = 0
    private weak var hostTouch: UITouch?
    private var hostTouchLastPoint = CGPoint.zero
    private var hostLongPressActive = false
    /// Where Wren is peeking from right now (see `WrenSpot`), and whether he is mid-trip.
    private var wrenSpot: WrenSpot = .home
    private var wrenIsTravelling = false
    private var wrenSpotQueue: [WrenSpot] = []
    private var lastShelfInteractionAt: TimeInterval = 0
    private var nextShelfInvitationAt: TimeInterval = 0
    private var shelfInvitationCursor = 0
    private struct ShelfLayout {
        let usesRow: Bool
        let objectSize: CGSize
        let shelfY: CGFloat
        let spacing: CGFloat
        let columns: Int
        let rowSpacing: CGFloat
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        rebuildShelf()
        resetShelfInvitationClock(delay: 12.0)
        startShelfParallax()
    }

    override func willMove(from view: SKView) {
        super.willMove(from: view)   // BaseToyScene tears down ambient audio + gestures
        stopShelfParallax()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard abs(size.width - lastBuiltSize.width) > 2 ||
            abs(size.height - lastBuiltSize.height) > 2
        else { return }
        rebuildShelf()
    }

    func prepareForShelfInteraction() {
        isOpeningToy = false
        if didBloomIntoToy {
            // The chosen object swelled and the room receded — rebuild restores every
            // alpha, scale and z cleanly, then the shelf exhales its welcome-back.
            didBloomIntoToy = false
            rebuildShelf()
        }
        resetShelfInvitationClock(delay: 12.0)
        playCardReturnSettle()
    }

    /// Quick to wake: the chosen object hops awake, a soft pool of light blooms out of
    /// it, the rest of the room gently recedes — and the toy opens mid-swell. The toy
    /// scene itself does the slow settling on arrival.
    private func playWakeBloom(card: SKNode, toyID: String) {
        didBloomIntoToy = true
        card.zPosition = 200

        let glow = SKShapeNode(circleOfRadius: 12)
        glow.fillColor = WarmShelfPalette.butter.withAlpha(0.45)
        glow.strokeColor = .clear
        glow.blendMode = .add
        glow.position = card.position
        glow.zPosition = 150
        contentRoot.addChild(glow)

        if !AmbientAnimator.reduceMotion {
            for child in contentRoot.children where child !== card && child !== glow {
                let dim = SKAction.fadeAlpha(to: 0.5, duration: 0.4)
                dim.timingMode = .easeOut
                child.run(dim)
            }
            let hopUp = SKAction.moveBy(x: 0, y: 14, duration: 0.12)
            hopUp.timingMode = .easeOut
            let hopDown = SKAction.moveBy(x: 0, y: -14, duration: 0.10)
            hopDown.timingMode = .easeIn
            let swell = SKAction.scale(to: 1.22, duration: 0.34)
            swell.timingMode = .easeIn
            card.run(.sequence([hopUp, hopDown, swell]))
            glow.run(.group([.scale(to: 26, duration: 0.5), .fadeOut(withDuration: 0.5)]))
        }

        run(.sequence([
            // Opening a toy is silent (founder, build 5: moving between toys was "TOO MUCH").
            .wait(forDuration: 0.46),
            .run { [weak self] in self?.onToySelected?(toyID) }
        ]))
    }

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        updateShelfInvitation(currentTime)
        updateShelfParallax()
    }

    // MARK: - Shelf parallax breath (approved delight)
    // Two points of depth on device tilt: the room plates lean away from the hand,
    // the shelf and its toys lean with it — a small held diorama. Applied per-frame
    // against live lookups so it survives rebuildShelf() replacing contentRoot.

    private let motionManager = CMMotionManager()
    private var parallaxTarget = CGPoint.zero    // raw target from device attitude (points)
    private var parallaxOffset = CGPoint.zero    // smoothed value actually applied
    private var parallaxNeutral: (roll: Double, pitch: Double)?

    private func startShelfParallax() {
        guard !AmbientAnimator.reduceMotion,
              motionManager.isDeviceMotionAvailable,
              !motionManager.isDeviceMotionActive else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let m = motion else { return }
            // The first sample defines how the device is being held; parallax is the delta.
            if self.parallaxNeutral == nil {
                self.parallaxNeutral = (m.attitude.roll, m.attitude.pitch)
            }
            guard var neutral = self.parallaxNeutral else { return }
            // Neutral drifts very slowly toward the live attitude, so a new resting
            // posture (couch, floor, lap) becomes the new zero instead of a stuck lean.
            neutral.roll  += (m.attitude.roll  - neutral.roll)  * 0.005
            neutral.pitch += (m.attitude.pitch - neutral.pitch) * 0.005
            self.parallaxNeutral = neutral

            let maxAngle = 0.30   // radians of tilt for full travel
            let dr = max(-maxAngle, min(maxAngle, m.attitude.roll  - neutral.roll))
            let dp = max(-maxAngle, min(maxAngle, m.attitude.pitch - neutral.pitch))
            let travel: CGFloat = 5.0   // max points of room drift — a breath, not a ride
            self.parallaxTarget = CGPoint(
                x: CGFloat(dr / maxAngle) * travel,
                y: CGFloat(-dp / maxAngle) * travel * 0.6   // less vertical: the room stays seated
            )
        }
    }

    private func stopShelfParallax() {
        motionManager.stopDeviceMotionUpdates()
        parallaxNeutral = nil
        parallaxTarget = .zero
        parallaxOffset = .zero
        childNode(withName: "shelfDayNight")?.position = .zero
        contentRoot.position = .zero
    }

    private func updateShelfParallax() {
        guard motionManager.isDeviceMotionActive else { return }
        parallaxOffset.x += (parallaxTarget.x - parallaxOffset.x) * 0.08   // soft smoothing
        parallaxOffset.y += (parallaxTarget.y - parallaxOffset.y) * 0.08
        // Far room counter-shifts, near shelf rides along — two-point depth.
        childNode(withName: "shelfDayNight")?.position = CGPoint(x: -parallaxOffset.x, y: -parallaxOffset.y)
        contentRoot.position = CGPoint(x: parallaxOffset.x * 0.55, y: parallaxOffset.y * 0.55)
    }

    /// A gentle staggered settle so the shelf feels like it exhales when a child returns —
    /// not a full entrance re-animation, just a soft landing acknowledgment.
    private func playCardReturnSettle() {
        guard hasAnimatedEntrance else { return }  // skip if entrance hasn't run yet
        let shelfToys = ToyRegistry.childShelfToys
        for (index, descriptor) in shelfToys.enumerated() {
            guard let card = contentRoot.childNode(withName: "toyCard.\(descriptor.id)") else { continue }
            let up = SKAction.scale(to: 1.028, duration: 0.16); up.timingMode = .easeOut
            let down = SKAction.scale(to: 1.0, duration: 0.30); down.timingMode = .easeInEaseOut
            card.run(.sequence([
                .wait(forDuration: Double(index) * 0.055),
                up,
                down
            ]), withKey: "cardReturn")
        }
    }

    /// Connects the shelf to the app's day/night emotional system: a soft time-of-day tint over the
    /// room (behind the shelves), deepened toward calm at the grown-up's wind-down hour, with faint
    /// stars and a cool veil at night so the shelf feels like a sleepy bedroom — not a static menu.
    private func addDayNightAtmosphere() {
        childNode(withName: "shelfDayNight")?.removeFromParent()
        childNode(withName: "shelfNightVeil")?.removeFromParent()
        let layer = SKNode()
        layer.name = "shelfDayNight"
        layer.zPosition = 5
        addChild(layer)

        if let room = ToyArt.texture("shelfroom-v2-day") {
            let plate = SKSpriteNode(texture: room)
            // This object-free wall/floor plate scales with the room. Interactive
            // furniture and toys retain their own aspect ratios above it.
            plate.size = CGSize(width: size.width + 12, height: size.height + 12)
            plate.position = CGPoint(x: size.width / 2, y: size.height / 2)
            layer.addChild(plate)
        }
        let sky = TimeOfDay.sky
        let hour = TimeOfDay.hour
        let isWindDown = !sky.isNight && (hour >= LullDemoState.shared.windDownHour || hour < 5)
        let grade = SKSpriteNode(color: sky.isNight ? UIColor(hex: 0x354456) : UIColor(hex: 0xD5AC79),
                                 size: CGSize(width: size.width + 12, height: size.height + 12))
        grade.position = CGPoint(x: size.width / 2, y: size.height / 2)
        let gradeAlpha: CGFloat = sky.isNight ? 0.24 : (isWindDown ? 0.12 : 0.025)
        grade.zPosition = 0.2
        layer.addChild(grade)
        if hasAnimatedEntrance || AmbientAnimator.reduceMotion {
            grade.alpha = gradeAlpha
        } else {
            // First appearance continues from the (daylight) launch picture: ease the evening in.
            grade.alpha = 0
            grade.run(.fadeAlpha(to: gradeAlpha, duration: 0.9))
        }
    }

    private func rebuildShelf() {
        guard size.width > 20, size.height > 20 else { return }
        lastBuiltSize = size

        contentRoot.removeFromParent()
        contentRoot = SKNode()
        contentRoot.zPosition = 10
        addChild(contentRoot)

        addDayNightAtmosphere()

        let shelfToys = ToyRegistry.childShelfToys
        let toyCount = max(1, shelfToys.count)
        // Every visible object is an available toy. The free shelf uses the same
        // balanced layout without decorative objects that look selectable.
        let companionSlots: [String] = []
        let displayCount = toyCount + companionSlots.count
        let layout = makeShelfLayout(toyCount: displayCount)

        addShelfMomentBackdrop(layout: layout, toyCount: displayCount)
        addSharedShelf(layout: layout, toyCount: displayCount)

        let animateEntrance = !hasAnimatedEntrance
        for (index, descriptor) in shelfToys.enumerated() {
            let cardPosition = cardPosition(index: index, count: displayCount, layout: layout)
            let card = makeToyCard(descriptor: descriptor, size: layout.objectSize)
            card.position = cardPosition
            card.zPosition = CGFloat(12 + index)
            contentRoot.addChild(card)

            if animateEntrance {
                // Each toy gently rises and settles onto its shelf, one after another.
                // Asymmetric scale: quick perk (0.14s easeOut) → slow exhale (0.30s easeInEaseOut).
                card.alpha = 0
                card.setScale(0.78)
                card.position = CGPoint(x: cardPosition.x, y: cardPosition.y - 26)
                let perk = SKAction.scale(to: 1.06, duration: 0.14); perk.timingMode = .easeOut
                let exhale = SKAction.scale(to: 1.0, duration: 0.30); exhale.timingMode = .easeInEaseOut
                let rise = SKAction.group([
                    .fadeAlpha(to: 1, duration: 0.34),
                    .move(to: cardPosition, duration: 0.42),
                    .sequence([perk, exhale])
                ])
                card.run(.sequence([
                    .wait(forDuration: 0.12 + Double(index) * 0.11),
                    rise
                ]))
            }
        }

        for (slotIndex, slot) in companionSlots.enumerated() {
            guard let companion = ToyArt.sprite(slot, fit: CGSize(
                width: layout.objectSize.width * 0.58,
                height: layout.objectSize.height * 0.64
            )) else { continue }
            let pos = cardPosition(index: toyCount + slotIndex, count: displayCount, layout: layout)
            // Rest its base on the plank where the toys' bases sit.
            companion.position = CGPoint(
                x: pos.x,
                y: pos.y - layout.objectSize.height * 0.5 + companion.size.height * 0.5
            )
            companion.zPosition = 11.5
            companion.name = "shelfCompanion"
            contentRoot.addChild(companion)

            let shadow = SKSpriteNode(texture: ProceduralTexture.softClayShadow(size: CGSize(
                width: companion.size.width * 0.9, height: 16
            )))
            shadow.position = CGPoint(x: pos.x, y: companion.position.y - companion.size.height * 0.48)
            shadow.zPosition = 11.4
            shadow.alpha = 0.7
            contentRoot.addChild(shadow)

            if animateEntrance {
                companion.alpha = 0
                let settle = SKAction.fadeAlpha(to: 1, duration: 0.4)
                settle.timingMode = .easeOut
                companion.run(.sequence([.wait(forDuration: 0.3 + Double(toyCount + slotIndex) * 0.11), settle]))
            }
        }
        hasAnimatedEntrance = true

        addShelfHost()
    }

    // MARK: - Wren — the sleepy host (Lull's soul — see Docs/AlivenessPrinciples.md)

    private func hostScale() -> CGFloat {
        // Wren reads as a real little friend on the shelf, not a speck. Trimmed a touch in
        // landscape where vertical room is tight.
        let base = min(size.width, size.height) / 470
        let landscapeTrim: CGFloat = size.width > size.height ? 0.84 : 1.0
        return max(0.68, min(1.5, base * landscapeTrim))
    }

    private func hostRestingPosition() -> CGPoint {
        let s = hostScale()
        let isLandscape = size.width > size.height
        return CGPoint(
            x: max(size.width * 0.12, 80 * s),
            y: max(size.height * (isLandscape ? 0.065 : 0.085), (isLandscape ? 78 : 92) * s)
        )
    }

    /// Peek-a-boo spots around the screen's edges (founder, build 5: "tap him and he wiggles off
    /// screen and pops up in other spots around the edges"). All of them sit where the shelf
    /// layout never puts a card: the bottom band it reserves for Wren and the top corners beside
    /// the wordmark. The bottom-right spot keeps clear of the grown-up button; the top corners
    /// stay away from the rounded display corners and the Dynamic Island.
    private enum WrenSpot: CaseIterable { case home, bottomMiddle, bottomRight, topLeft, topRight }

    /// Rest position, the unit direction that leads off-screen, and Wren's rotation at a spot.
    /// Away from home he only peeks: his head shows over the edge and his body stays hidden.
    private func wrenPlacement(_ spot: WrenSpot) -> (rest: CGPoint, out: CGVector, rotation: CGFloat) {
        let r = 58 * hostScale()
        let safe = view?.safeAreaInsets ?? .zero
        switch spot {
        case .home:
            return (hostRestingPosition(), CGVector(dx: 0, dy: -1), 0)
        case .bottomMiddle:
            return (CGPoint(x: size.width * 0.5, y: r * 0.2), CGVector(dx: 0, dy: -1), 0)
        case .bottomRight:
            let x = size.width - safe.right - 14 - 44 - 24 - r * 0.8
            return (CGPoint(x: x, y: r * 0.2), CGVector(dx: 0, dy: -1), 0)
        case .topLeft:
            return (CGPoint(x: size.width * 0.22, y: size.height + r * 0.05), CGVector(dx: 0, dy: 1), .pi)
        case .topRight:
            return (CGPoint(x: size.width * 0.78, y: size.height + r * 0.05), CGVector(dx: 0, dy: 1), .pi)
        }
    }

    /// A little further in from the edge: the look-up after a shelf wake or a touch.
    private func wrenAwakePosition() -> CGPoint {
        let placement = wrenPlacement(wrenSpot)
        let lift = 24 * hostScale()
        return CGPoint(x: placement.rest.x - placement.out.dx * lift, y: placement.rest.y - placement.out.dy * lift)
    }

    /// The next spot: every spot once, in a fresh order, before any repeats, never where he is now.
    private func nextWrenSpot() -> WrenSpot {
        if wrenSpotQueue.isEmpty {
            wrenSpotQueue = WrenSpot.allCases.filter { $0 != wrenSpot }.shuffled()
        }
        let next = wrenSpotQueue.removeFirst()
        return next == wrenSpot ? nextWrenSpot() : next
    }

    /// Wren sleeps visibly in the shelf corner, then leans awake after a beautiful
    /// shelf-wake moment. Present, but never narrating or blocking the toys.
    private func addShelfHost() {
        let host = LullHostNode(scale: hostScale())
        host.name = "shelfHost"
        let placement = wrenPlacement(wrenSpot)
        host.position = placement.rest
        host.zRotation = placement.rotation
        host.zPosition = 250
        host.rest()
        contentRoot.addChild(host)
        shelfHost = host
        wrenIsTravelling = false
    }

    /// Peek-a-boo: a happy wiggle, off the nearest edge, a beat of nothing, then in from another
    /// edge with a small overshoot, a look at the child, and back to his sleepy breathing.
    /// Silent (felt as a soft haptic). Reduce Motion fades him out and in instead.
    private func wrenPeekABoo(lookingAt point: CGPoint) {
        guard let host = shelfHost, !wrenIsTravelling else { return }
        wrenIsTravelling = true
        lastHostPeek = CACurrentMediaTime()
        HapticsManager.shared.softTap()
        host.removeAction(forKey: "hostPeek")
        host.removeAction(forKey: "hostPeekHide")

        let from = wrenPlacement(wrenSpot)
        let next = nextWrenSpot()
        let to = wrenPlacement(next)
        let r = 58 * hostScale()
        let away = r * 2.8
        let gone = CGPoint(x: from.rest.x + from.out.dx * away, y: from.rest.y + from.out.dy * away)
        let start = CGPoint(x: to.rest.x + to.out.dx * away, y: to.rest.y + to.out.dy * away)
        let arrive: [SKAction]
        let leave: [SKAction]
        if AmbientAnimator.reduceMotion {
            leave = [.wait(forDuration: 0.15), .fadeOut(withDuration: 0.25)]
            arrive = [.run { [weak host] in host?.position = to.rest }, .fadeIn(withDuration: 0.35)]
        } else {
            let exit = SKAction.move(to: gone, duration: 0.32); exit.timingMode = .easeIn
            let overshoot = CGPoint(x: to.rest.x - to.out.dx * r * 0.14, y: to.rest.y - to.out.dy * r * 0.14)
            let enter = SKAction.move(to: overshoot, duration: 0.42); enter.timingMode = .easeOut
            let settle = SKAction.move(to: to.rest, duration: 0.2); settle.timingMode = .easeInEaseOut
            leave = [.wait(forDuration: 0.42), exit]
            arrive = [.run { [weak host] in host?.position = start }, enter, settle]
        }
        host.wiggle()
        host.run(.sequence(leave + [
            .run { [weak self, weak host] in
                host?.zRotation = to.rotation
                self?.wrenSpot = next
            },
            .wait(forDuration: Double.random(in: 0.8...1.4)),
            .run { [weak host] in host?.notice(toward: point) }   // "I see you" — toward where the child tapped
        ] + arrive + [
            .run { [weak host] in host?.respond() },
            .wait(forDuration: 1.1),
            .run { [weak self, weak host] in
                host?.settle()
                self?.wrenIsTravelling = false
            }
        ]), withKey: "hostPeek")
    }

    // Wren peeks up after a shelf wake — throttled to stay a rare, earned moment.
    private func peekHost() {
        guard let host = shelfHost else { return }
        let now = CACurrentMediaTime()
        guard now - lastHostPeek > 11 else { return }   // keep it a rare, earned moment
        lastHostPeek = now
        guard !wrenIsTravelling else { return }
        let up = SKAction.move(to: wrenAwakePosition(), duration: 0.5); up.timingMode = .easeOut
        let down = SKAction.move(to: wrenPlacement(wrenSpot).rest, duration: 0.95); down.timingMode = .easeInEaseOut
        host.removeAction(forKey: "hostPeek")
        host.run(.sequence([
            up,
            .run { [weak host] in host?.notice() },
            .wait(forDuration: 1.5),
            .run { [weak host] in host?.settle() },
            .wait(forDuration: 0.2),
            down
        ]), withKey: "hostPeek")
    }

    private func presentHostForInteraction() {
        guard let host = shelfHost, !wrenIsTravelling else { return }
        host.removeAction(forKey: "hostPeek")
        host.removeAction(forKey: "hostPeekHide")
        let up = SKAction.move(to: wrenAwakePosition(), duration: 0.20)
        up.timingMode = .easeOut
        host.run(up, withKey: "hostPeek")
    }

    private func hideHost(after delay: TimeInterval) {
        guard let host = shelfHost, !wrenIsTravelling else { return }
        let down = SKAction.move(to: wrenPlacement(wrenSpot).rest, duration: 0.95)
        down.timingMode = .easeInEaseOut
        host.run(.sequence([
            .wait(forDuration: delay),
            .run { [weak self, weak host] in
                guard self?.hostTouch == nil else { return }
                host?.run(down, withKey: "hostPeek")
            },
        ]), withKey: "hostPeekHide")
    }

    private func beginHostTouch(_ touch: UITouch, at point: CGPoint) {
        guard !wrenIsTravelling else { return }   // mid peek-a-boo: let him finish his trip
        hostTouch = touch
        hostTouchLastPoint = point
        hostLongPressActive = false
        lastHostPeek = CACurrentMediaTime()
        presentHostForInteraction()
        shelfHost?.trackEyes(toward: point, strength: 0.92)
        removeAction(forKey: "hostLongPress")
        run(.sequence([
            .wait(forDuration: 0.36),
            .run { [weak self] in
                guard let self, self.hostTouch === touch else { return }
                self.hostLongPressActive = true
                self.shelfHost?.beginLongPress(at: self.hostTouchLastPoint)
            }
        ]), withKey: "hostLongPress")
    }

    private func moveHostTouch(_ touch: UITouch, to point: CGPoint) -> Bool {
        guard hostTouch === touch else { return false }
        hostTouchLastPoint = point
        if hostLongPressActive {
            shelfHost?.continueLongPress(at: point)
        } else {
            shelfHost?.trackEyes(toward: point, strength: 0.95)
        }
        return true
    }

    private func endHostTouch(_ touch: UITouch, cancelled: Bool) -> Bool {
        guard hostTouch === touch else { return false }
        removeAction(forKey: "hostLongPress")
        let point = touch.location(in: self)
        hostTouch = nil

        if hostLongPressActive {
            hostLongPressActive = false
            shelfHost?.endLongPress(at: point)
            hideHost(after: 1.4)
            return true
        }

        guard !cancelled else {
            shelfHost?.settle()
            hideHost(after: 0.7)
            return true
        }

        registerHostTap(at: point)
        return true
    }

    /// A tap is peek-a-boo: Wren wiggles off and pops up somewhere else around the edges.
    private func registerHostTap(at point: CGPoint) {
        wrenPeekABoo(lookingAt: point)
    }

    private func nodeIsHost(_ nodes: [SKNode]) -> Bool {
        guard let host = shelfHost else { return false }
        return nodes.contains { node in
            var current: SKNode? = node
            while let n = current { if n === host { return true }; current = n.parent }
            return false
        }
    }

    /// Responsive, autolayout-style sizing: the shelf grid is fit to the live canvas so it never
    /// overflows, however many toys are on it (a 4-toy free shelf and a 7-toy trial shelf both sit
    /// cleanly, portrait or landscape, on phone or pad). Card size is the *smaller* of what the
    /// columns allow horizontally and what the rows allow vertically, then the whole grid is
    /// centred in a band that keeps the top inset and Wren/floor reserve clear.
    private func makeShelfLayout(toyCount: Int) -> ShelfLayout {
        let isLandscape = size.width > size.height
        let isPhone = min(size.width, size.height) < 600
        let safe = view?.safeAreaInsets ?? .zero
        let useRow = toyCount > 1

        // Keep portrait calm (≤3 across); allow wider rows in landscape. A balanced column count
        // avoids lonely half-empty rows (e.g. 6 toys → 3+3, never 5+1).
        let maxColumns = isLandscape ? (isPhone ? 4 : 5) : 3
        let columns = useRow ? balancedColumns(toyCount: toyCount, maxColumns: maxColumns) : 1
        let rows = Int(ceil(Double(toyCount) / Double(max(1, columns))))

        // The band the grid must fit inside. The bottom reserve always clears Wren in their corner,
        // so the lowest row never collides with him at any size or orientation.
        let topMargin = safe.top + (isLandscape ? 65 : 88)
        let wrenTop = hostRestingPosition().y + 58 * hostScale() + 14
        // Portrait reserve lifted (founder: the lowest shelf sat on the baked rug — a
        // shelf is on a wall, so it must clear the floor rug below it).
        let bottomReserve = max(safe.bottom + size.height * (isLandscape ? 0.10 : 0.16), wrenTop)
        let sideInset = max(safe.left, safe.right) + size.width * (isPhone ? 0.07 : 0.085)
        let availableWidth = max(140, size.width - sideInset * 2)
        let availableHeight = max(140, size.height - topMargin - bottomReserve)

        // Generous gaps so the toys read as separate objects with calm space between them.
        let colGap: CGFloat = isPhone ? (isLandscape ? 20 : 22) : (isLandscape ? 34 : 30)
        let rowGap: CGFloat = isPhone ? (isLandscape ? 30 : 52) : (isLandscape ? 46 : 62)
        let aspect: CGFloat = isLandscape ? 1.08 : 1.10   // card height ÷ width

        // Two-axis fit: the width that satisfies BOTH the row width and the column height.
        let widthByColumns = (availableWidth - colGap * CGFloat(columns - 1)) / CGFloat(columns)
        let heightByRows = (availableHeight - rowGap * CGFloat(max(0, rows - 1))) / CGFloat(rows)
        let widthByRows = heightByRows / aspect
        let maxWidth: CGFloat = isPhone ? (isLandscape ? 210 : 250) : 300
        let objectWidth = max(64, min(widthByColumns, widthByRows, maxWidth))
        let objectHeight = objectWidth * aspect

        let spacing = useRow ? objectWidth + colGap : objectHeight + rowGap
        let rowSpacing = objectHeight + rowGap

        // Centre the whole grid vertically inside the available band.
        let gridHeight = objectHeight * CGFloat(rows) + rowGap * CGFloat(max(0, rows - 1))
        let bandCenterY = bottomReserve + availableHeight / 2
        let topCardCenterY = bandCenterY + gridHeight / 2 - objectHeight / 2
        let shelfY = topCardCenterY - objectHeight * 0.48

        return ShelfLayout(
            usesRow: useRow,
            objectSize: CGSize(width: objectWidth, height: objectHeight),
            shelfY: shelfY,
            spacing: spacing,
            columns: max(1, columns),
            rowSpacing: rowSpacing
        )
    }

    /// Pick a column count (≤ maxColumns) that fills rows as evenly as possible — preferring few
    /// empty trailing cells, then few rows. Avoids lonely last-row cards (6 → 3+3, 5 → 3+2).
    private func balancedColumns(toyCount: Int, maxColumns: Int) -> Int {
        guard toyCount > 1 else { return 1 }
        let upper = max(1, min(toyCount, maxColumns))
        var best = upper
        var bestScore = Int.max
        for cols in stride(from: upper, through: 1, by: -1) {
            let rows = Int(ceil(Double(toyCount) / Double(cols)))
            let empty = rows * cols - toyCount
            let score = empty * 2 + rows * 3   // prefer fewer rows (6 → 3+3, 7 → 3+3+1)
            if score < bestScore { bestScore = score; best = cols }
        }
        return best
    }

    private func addShelfMomentBackdrop(layout: ShelfLayout, toyCount: Int) {
        let safe = view?.safeAreaInsets ?? .zero
        let isPhone = min(size.width, size.height) < 600
        let wordmark = SKLabelNode(text: "lull")
        wordmark.fontName = "Georgia"
        wordmark.fontSize = isPhone ? 27 : 34
        wordmark.fontColor = WarmShelfPalette.clayInk
        wordmark.verticalAlignmentMode = .center
        wordmark.horizontalAlignmentMode = .center
        wordmark.position = CGPoint(x: size.width / 2,
                                    y: size.height - safe.top - (size.width > size.height ? 27 : 38))
        wordmark.zPosition = 6
        contentRoot.addChild(wordmark)
    }

    private func addShelfDustMotes(lowestShelfY: CGFloat, count: Int) {
        guard size.height > 80, size.width > 80 else { return }
        let minY = min(size.height - 48, max(lowestShelfY + 26, size.height * 0.36))
        let maxY = max(minY + 12, min(size.height - 24, size.height * 0.90))
        let colors = [
            WarmShelfPalette.butter,
            WarmShelfPalette.petal,
            WarmShelfPalette.waterBlue,
            WarmShelfPalette.paperHighlight
        ]

        for index in 0..<count {
            let mote = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.2...3.0))
            mote.fillColor = colors[index % colors.count].withAlpha(0.18)
            mote.strokeColor = .clear
            mote.position = CGPoint(
                x: CGFloat.random(in: size.width * 0.10...size.width * 0.90),
                y: CGFloat.random(in: minY...maxY)
            )
            mote.zPosition = 5.2
            contentRoot.addChild(mote)

            AmbientAnimator.idleDrift(
                node: mote,
                x: CGFloat.random(in: -4...4),
                y: CGFloat.random(in: 6...14),
                duration: Double.random(in: 6.0...9.5),
                delay: Double(index) * 0.13
            )
        }
    }

    private func addSharedShelf(layout: ShelfLayout, toyCount: Int) {
        let rows = Int(ceil(Double(toyCount) / Double(max(1, layout.columns))))
        let lowestShelfY = layout.shelfY - CGFloat(max(0, rows - 1)) * layout.rowSpacing

        let floorZone = SKShapeNode(rectOf: CGSize(width: size.width, height: lowestShelfY + layout.objectSize.height * 0.34))
        floorZone.fillColor = WarmShelfPalette.warmCream.withAlpha(0.30)
        floorZone.strokeColor = .clear
        floorZone.position = CGPoint(x: size.width / 2, y: (lowestShelfY + layout.objectSize.height * 0.34) / 2)
        floorZone.zPosition = 6
        if ToyArt.texture("shelfroom-v2-day") == nil { contentRoot.addChild(floorZone) }

        for row in 0..<rows {
            let rowStart = row * layout.columns
            let countInRow = min(layout.columns, max(0, toyCount - rowStart))
            let rowShelfY = layout.shelfY - CGFloat(row) * layout.rowSpacing
            let shelfWidth = min(
                size.width * (countInRow >= 3 ? 0.88 : 0.78),
                layout.spacing * CGFloat(max(0, countInRow - 1)) + layout.objectSize.width * 1.10
            )

            let shadow = makeRoundedRect(
                size: CGSize(width: shelfWidth * 0.94, height: size.width < 600 ? 30 : 38),
                radius: size.width < 600 ? 15 : 19,
                fill: WarmShelfPalette.raisin.withAlpha(0.082)
            )
            shadow.position = CGPoint(x: size.width / 2, y: rowShelfY - (size.width < 600 ? 12 : 15))
            shadow.zPosition = 7 + CGFloat(row) * 0.02
            contentRoot.addChild(shadow)

            let shelfHeight: CGFloat = size.width < 600 ? 22 : 28
            if let artBoard = makeArtShelfBoard(width: shelfWidth, proceduralHeight: shelfHeight) {
                // Authored board (cut from the shelfroom-shelf unit): 3-band slice so the
                // rounded post-cap ends stay true at any width. Top edges align with the
                // procedural board so the toys' feet keep their exact seat.
                artBoard.position = CGPoint(x: size.width / 2, y: rowShelfY)
                artBoard.zPosition = 8 + CGFloat(row) * 0.02
                contentRoot.addChild(artBoard)
                continue   // shadow above is kept; trim/highlight/grain belong to the procedural board
            }
            let shelfRadius: CGFloat = size.width < 600 ? 11 : 14
            let shelf = makeRoundedRect(
                size: CGSize(width: shelfWidth, height: shelfHeight),
                radius: shelfRadius,
                fill: UIColor(hex: 0xDECAA9).withAlpha(0.96)
            )
            shelf.position = CGPoint(x: size.width / 2, y: rowShelfY)
            shelf.zPosition = 8 + CGFloat(row) * 0.02
            contentRoot.addChild(shelf)
            ProceduralTexture.addMatteClayDepth(
                to: shelf,
                in: CGRect(x: -shelfWidth / 2, y: -shelfHeight / 2, width: shelfWidth, height: shelfHeight),
                cornerRadius: shelfRadius,
                zPosition: 0.10,
                highlightAlpha: 0.16,
                shadeAlpha: 0.040,
                rimAlpha: 0.035,
                speckleCount: size.width < 600 ? 3 : 5
            )

            let shelfEdge = makeRoundedRect(
                size: CGSize(width: shelfWidth * 0.98, height: size.width < 600 ? 6 : 8),
                radius: size.width < 600 ? 3 : 4,
                fill: WarmShelfPalette.cocoa.withAlpha(0.13)
            )
            shelfEdge.position = CGPoint(x: size.width / 2, y: rowShelfY - (size.width < 600 ? 12 : 16))
            shelfEdge.zPosition = 9 + CGFloat(row) * 0.02
            contentRoot.addChild(shelfEdge)

            let highlight = makeRoundedRect(
                size: CGSize(width: shelfWidth * 0.88, height: 4),
                radius: 2,
                fill: WarmShelfPalette.paperHighlight.withAlpha(0.52)
            )
            highlight.position = CGPoint(x: size.width / 2, y: rowShelfY + (size.width < 600 ? 7 : 9))
            highlight.zPosition = 10 + CGFloat(row) * 0.02
            contentRoot.addChild(highlight)

            for index in 0..<8 {
                let grainWidth = CGFloat.random(in: shelfWidth * 0.08...shelfWidth * 0.18)
                let grain = makeRoundedRect(
                    size: CGSize(width: grainWidth, height: CGFloat.random(in: 1.4...2.4)),
                    radius: 1.2,
                    fill: WarmShelfPalette.raisin.withAlpha(CGFloat.random(in: 0.016...0.036))
                )
                grain.position = CGPoint(
                    x: size.width / 2 + CGFloat.random(in: -shelfWidth * 0.42...shelfWidth * 0.42),
                    y: rowShelfY + CGFloat.random(in: -3...5)
                )
                grain.zPosition = 10.5 + CGFloat(row) * 0.05 + CGFloat(index) * 0.01
                contentRoot.addChild(grain)
            }

        }
    }

    /// One authored shelf board, sliced into left-cap / shaft / right-cap bands so the
    /// rounded post ends never stretch. Returns nil when the art hasn't landed.
    /// The board is anchored so its TOP face sits exactly where the procedural board's
    /// top sat — toy feet keep their seat even though the authored wood is thicker.
    private func makeArtShelfBoard(width: CGFloat, proceduralHeight: CGFloat) -> SKNode? {
        guard let tex = ToyArt.texture("shelf-board-v2") else { return nil }
        let nat = tex.size()
        guard nat.width > 1, nat.height > 1 else { return nil }
        let capFrac: CGFloat = 0.10
        let naturalH = width * (nat.height / nat.width)
        let scaledH = min(naturalH, proceduralHeight * 2.2)   // never a beam — cap the thickness
        let capW = nat.width * capFrac * (scaledH / nat.height)
        let midW = max(1, width - capW * 2)

        let node = SKNode()
        let yOffset = (scaledH - proceduralHeight) / -2   // top edges align
        func band(_ unitRect: CGRect, w: CGFloat, x: CGFloat) {
            let s = SKSpriteNode(texture: SKTexture(rect: unitRect, in: tex))
            s.size = CGSize(width: w, height: scaledH)
            s.position = CGPoint(x: x, y: yOffset)
            node.addChild(s)
        }
        band(CGRect(x: 0, y: 0, width: capFrac, height: 1), w: capW, x: -width / 2 + capW / 2)
        band(CGRect(x: capFrac, y: 0, width: 1 - capFrac * 2, height: 1), w: midW + 1, x: 0)
        band(CGRect(x: 1 - capFrac, y: 0, width: capFrac, height: 1), w: capW, x: width / 2 - capW / 2)
        return node
    }

    static func shelfObjectSlot(for id: String) -> String? {
        switch id {
        case ToyRegistry.bubblesID: return "shelf-bubbles"
        case ToyRegistry.feedThePeopleID: return "shelf-feed"
        case ToyRegistry.stackID: return "shelf-stack"
        case ToyRegistry.washID: return "shelf-wash"
        case ToyRegistry.sleepyDropBoxID: return "shelf-sleepybox"
        case ToyRegistry.glowWindowID: return "shelf-window"
        case ToyRegistry.dropDotsID: return "shelf-dropdots"
        case ToyRegistry.mixUpID: return "shelf-mixup"
        case ToyRegistry.humID: return "shelf-hum"
        case ToyRegistry.meadowID: return "shelf-meadow"
        default: return nil
        }
    }

    /// Export padding varies between authored objects. Fit their visible silhouettes,
    /// so padding cannot make one toy tiny or make its feet float above the shelf.
    static func shelfObjectArt(slot: String, fit: CGSize) -> SKSpriteNode? {
        var visible: [String: (CGSize, CGRect)] = [
            "shelf-bubbles": (CGSize(width: 1024, height: 1024), CGRect(x: 94, y: 131, width: 854, height: 788)),
            "shelf-stack": (CGSize(width: 1374, height: 1145), CGRect(x: 342, y: 123, width: 693, height: 935)),
            "shelf-sleepybox": (CGSize(width: 1254, height: 1254), CGRect(x: 146, y: 103, width: 962, height: 1056)),
            "shelf-feed": (CGSize(width: 1293, height: 1217), CGRect(x: 184, y: 185, width: 925, height: 943)),
            "shelf-dropdots": (CGSize(width: 1024, height: 936), CGRect(x: 138, y: 89, width: 754, height: 765)),
            "shelf-hum": (CGSize(width: 1536, height: 1024), CGRect(x: 13, y: 148, width: 1512, height: 781)),
            "shelf-window": (CGSize(width: 1312, height: 1199), CGRect(x: 125, y: 118, width: 1062, height: 959)),
            "shelf-mixup": (CGSize(width: 1024, height: 1024), CGRect(x: 19, y: 16, width: 985, height: 989)),
            "shelf-meadow": (CGSize(width: 1536, height: 1024), CGRect(x: 188, y: 318, width: 1180, height: 544))
        ]
        if slot == "shelf-wash", let geometry = washShelfArtGeometry() {
            visible[slot] = (geometry.pixels, geometry.bounds)
        }
        if let texture = ToyArt.texture(slot + "-v2"), let (pixels, bounds) = visible[slot] {
            let rect = CGRect(x: bounds.minX / pixels.width,
                              y: (pixels.height - bounds.maxY) / pixels.height,
                              width: bounds.width / pixels.width,
                              height: bounds.height / pixels.height)
            let sprite = SKSpriteNode(texture: SKTexture(rect: rect, in: texture))
            let scale = min(fit.width / bounds.width, fit.height / bounds.height)
            sprite.size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
            return sprite
        }
        return ToyArt.sprite(slot, fit: fit)
    }

    private func makeToyCard(descriptor: ToyDescriptor, size cardSize: CGSize) -> SKNode {
        let root = SKNode()
        root.name = cardName(for: descriptor.id)

        // The object and its contact shadow carry the invitation. No persistent
        // halo or translucent card competes with its physical silhouette.
        let hit = makeRoundedRect(
            size: cardSize,
            radius: min(30, min(cardSize.width, cardSize.height) * 0.15),
            fill: .clear
        )
        hit.name = cardName(for: descriptor.id)
        hit.zPosition = 12
        root.addChild(hit)

        // Draw the toy art a touch smaller than the card footprint so every toy has clear
        // breathing room around it — the shelf reads calm and uncrowded.
        let artSize = CGSize(width: cardSize.width * 0.9, height: cardSize.height * 0.9)

        // Authored shelf object (Docs/NorthStar.md: the launch UI is tiny physical toys).
        // Bottom-aligned to the shadow line so every object sits on its board.
        if let slot = ToyShelfScene.shelfObjectSlot(for: descriptor.id),
           let art = ToyShelfScene.shelfObjectArt(slot: slot, fit: artSize) {
            art.position = CGPoint(x: 0, y: -cardSize.height * 0.40 + art.size.height / 2)
            art.zPosition = 0
            root.addChild(art)
            if descriptor.id == ToyRegistry.washID,
               let geometry = Self.washShelfArtGeometry(), let window = geometry.window {
                let center = CGPoint(x: (window.midX - geometry.bounds.minX) / geometry.bounds.width - 0.5,
                                     y: 0.5 - (window.midY - geometry.bounds.minY) / geometry.bounds.height)
                let radius = min(window.width / geometry.bounds.width * art.size.width,
                                 window.height / geometry.bounds.height * art.size.height) * 0.30
                addWashShelfFace(to: art, center: CGPoint(x: center.x * art.size.width, y: center.y * art.size.height), radius: radius)
            }
            let shadow = SKSpriteNode(texture: ProceduralTexture.softClayShadow(
                size: CGSize(width: cardSize.width * 0.6, height: max(16, cardSize.height * 0.12))
            ))
            shadow.position = CGPoint(x: 0, y: -cardSize.height * 0.42)
            shadow.zPosition = -1
            shadow.alpha = 0.5
            root.addChild(shadow)
            return root
        }

        switch descriptor.id {
        case ToyRegistry.bubblesID:
            makeBubbleToyObject(in: root, cardSize: artSize)
        case ToyRegistry.clayBlocksID:
            makeBlockToyObject(in: root, cardSize: artSize)
        case ToyRegistry.feedThePeopleID:
            makeFeedToyObject(in: root, cardSize: artSize)
        case ToyRegistry.humID:
            makeHumToyObject(in: root, cardSize: artSize)
        case ToyRegistry.softDropID:
            makeSoftDropToyObject(in: root, cardSize: artSize)
        case ToyRegistry.stackID:
            makeStackToyObject(in: root, cardSize: artSize)
        case ToyRegistry.washID:
            makeWashToyObject(in: root, cardSize: artSize, groundY: -cardSize.height * 0.40)
        case ToyRegistry.bloomID:
            makeBloomToyObject(in: root, cardSize: artSize)
        case ToyRegistry.glowboardID:
            makeGlowboardToyObject(in: root, cardSize: artSize)
        case ToyRegistry.sleepyDropBoxID:
            makeSleepyDropBoxToyObject(in: root, cardSize: artSize)
        case ToyRegistry.glowWindowID:
            makeGlowWindowToyObject(in: root, cardSize: artSize)
        case ToyRegistry.dropDotsID:
            makeDropDotsToyObject(in: root, cardSize: artSize)
        case ToyRegistry.mixUpID:
            makeMixUpToyObject(in: root, cardSize: artSize)
        case ToyRegistry.doughID:
            makeDoughToyObject(in: root, cardSize: artSize)
        case ToyRegistry.currentID:
            makeCurrentToyObject(in: root, cardSize: artSize)
        case ToyRegistry.meadowID:
            makeMeadowToyObject(in: root, cardSize: artSize)
        default:
            break
        }

        // A soft, blurred contact shadow grounds the toy on the shelf — it sits, it never floats.
        let shadow = SKSpriteNode(texture: ProceduralTexture.softClayShadow(
            size: CGSize(width: cardSize.width * 0.6, height: max(16, cardSize.height * 0.12))
        ))
        shadow.position = CGPoint(x: 0, y: -cardSize.height * 0.42)
        shadow.zPosition = 2
        root.addChild(shadow)

        return root
    }

    private func makeBubbleToyObject(in card: SKNode, cardSize: CGSize) {
        let jar = SKShapeNode(circleOfRadius: min(cardSize.width, cardSize.height) * 0.42)
        jar.fillColor = WarmShelfPalette.warmCream.withAlpha(0.16)
        jar.strokeColor = WarmShelfPalette.sand.withAlpha(0.16)
        jar.lineWidth = max(1.0, cardSize.width * 0.010)
        jar.position = CGPoint(x: 0, y: -cardSize.height * 0.03)
        jar.zPosition = 0
        card.addChild(jar)

        let contact = makeRoundedRect(
            size: CGSize(width: cardSize.width * 0.66, height: max(12, cardSize.height * 0.07)),
            radius: max(6, cardSize.height * 0.035),
            fill: WarmShelfPalette.cocoa.withAlpha(0.024)
        )
        contact.position = CGPoint(x: 0, y: -cardSize.height * 0.36)
        contact.zPosition = 1
        card.addChild(contact)

        makePreviewBubbles(in: card, cardSize: cardSize)
    }

    private func makeBlockToyObject(in card: SKNode, cardSize: CGSize) {
        let contact = makeRoundedRect(
            size: CGSize(width: cardSize.width * 0.82, height: max(12, cardSize.height * 0.075)),
            radius: max(6, cardSize.height * 0.038),
            fill: WarmShelfPalette.cocoa.withAlpha(0.024)
        )
        contact.position = CGPoint(x: 0, y: -cardSize.height * 0.36)
        contact.zPosition = 1
        card.addChild(contact)

        makePreviewBlocks(in: card, cardSize: cardSize)
    }

    private func makeFeedToyObject(in card: SKNode, cardSize: CGSize) {
        let nook = makeRoundedRect(
            size: CGSize(width: cardSize.width * 0.84, height: cardSize.height * 0.74),
            radius: min(36, cardSize.height * 0.18),
            fill: WarmShelfPalette.warmCream.withAlpha(0.12),
            stroke: WarmShelfPalette.sand.withAlpha(0.10)
        )
        nook.position = CGPoint(x: 0, y: -cardSize.height * 0.04)
        nook.lineWidth = 1
        nook.zPosition = 0
        card.addChild(nook)

        let contact = makeRoundedRect(
            size: CGSize(width: cardSize.width * 0.76, height: max(12, cardSize.height * 0.075)),
            radius: max(6, cardSize.height * 0.038),
            fill: WarmShelfPalette.cocoa.withAlpha(0.024)
        )
        contact.position = CGPoint(x: 0, y: -cardSize.height * 0.36)
        contact.zPosition = 1
        card.addChild(contact)

        makePreviewPeople(in: card, cardSize: cardSize)
    }

    /// A clean little wooden xylophone — the actual Hum toy: a warm rail with a row of rainbow
    /// bars (tall on the left, short on the right) and a resting mallet. Instantly readable.
    private func makeHumToyObject(in card: SKNode, cardSize: CGSize) {
        let w = cardSize.width, h = cardSize.height
        let frame = SKNode()
        frame.zRotation = -0.04   // a touch of handmade tilt
        card.addChild(frame)

        let railW = w * 0.72
        let railH = h * 0.11
        let railY = -h * 0.2
        let rail = makeRoundedRect(size: CGSize(width: railW, height: railH), radius: railH * 0.45,
                                   fill: UIColor(hex: 0xCBA268), stroke: WarmShelfPalette.cocoa.withAlpha(0.12))
        rail.position = CGPoint(x: 0, y: railY)
        rail.zPosition = 2
        frame.addChild(rail)
        let railHi = makeRoundedRect(size: CGSize(width: railW * 0.9, height: 3), radius: 1.5,
                                     fill: WarmShelfPalette.paperHighlight.withAlpha(0.3))
        railHi.position = CGPoint(x: 0, y: railY + railH * 0.28)
        railHi.zPosition = 2.1
        frame.addChild(railHi)

        let colors = [WarmShelfPalette.terracotta, WarmShelfPalette.butter, WarmShelfPalette.sage,
                      WarmShelfPalette.waterBlue, WarmShelfPalette.lavender]
        let barCount = 5
        let span = railW * 0.84
        let slot = span / CGFloat(barCount)
        let startX = -span / 2 + slot / 2
        let barW = slot * 0.62
        for i in 0..<barCount {
            let t = CGFloat(i) / CGFloat(barCount - 1)
            let barH = h * 0.4 * (1 - 0.34 * t)
            let x = startX + CGFloat(i) * slot
            let bar = makeRoundedRect(size: CGSize(width: barW, height: barH), radius: barW * 0.42,
                                      fill: colors[i % colors.count], stroke: WarmShelfPalette.cocoa.withAlpha(0.08))
            bar.position = CGPoint(x: x, y: railY + railH * 0.18 + barH * 0.5)
            bar.zPosition = CGFloat(3 + i)
            frame.addChild(bar)
            let barHi = makeRoundedRect(size: CGSize(width: barW * 0.46, height: max(2, barH * 0.06)), radius: 1.5,
                                        fill: WarmShelfPalette.paperHighlight.withAlpha(0.3))
            barHi.position = CGPoint(x: x - barW * 0.12, y: bar.position.y + barH * 0.32)
            barHi.zPosition = bar.zPosition + 0.1
            frame.addChild(barHi)
            for pegY in [barH * 0.34, -barH * 0.34] {
                let peg = SKShapeNode(circleOfRadius: max(1, barW * 0.07))
                peg.fillColor = WarmShelfPalette.cocoa.withAlpha(0.18)
                peg.strokeColor = .clear
                peg.position = CGPoint(x: x, y: bar.position.y + pegY)
                peg.zPosition = bar.zPosition + 0.1
                frame.addChild(peg)
            }
        }

        // A little mallet leaning by the bars, so it reads as "music" at a glance.
        let mallet = SKNode()
        let stick = makeRoundedRect(size: CGSize(width: w * 0.035, height: h * 0.3), radius: w * 0.018,
                                    fill: UIColor(hex: 0xCBA268), stroke: WarmShelfPalette.cocoa.withAlpha(0.1))
        stick.zPosition = 6
        mallet.addChild(stick)
        let headNode = SKShapeNode(circleOfRadius: w * 0.05)
        headNode.fillColor = WarmShelfPalette.rhubarb
        headNode.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.1)
        headNode.lineWidth = 1
        headNode.position = CGPoint(x: 0, y: h * 0.15)
        headNode.zPosition = 6.1
        mallet.addChild(headNode)
        mallet.position = CGPoint(x: w * 0.3, y: -h * 0.08)
        mallet.zRotation = 0.5
        mallet.zPosition = 6
        frame.addChild(mallet)

        AmbientAnimator.breathe(node: frame, scale: 1.012, duration: 5.4)
    }

    private func makeSoftDropToyObject(in card: SKNode, cardSize: CGSize) {
        let lane = makeRoundedRect(
            size: CGSize(width: cardSize.width * 0.72, height: cardSize.height * 0.78),
            radius: min(30, cardSize.height * 0.16),
            fill: WarmShelfPalette.warmCream.withAlpha(0.11),
            stroke: WarmShelfPalette.sand.withAlpha(0.10)
        )
        lane.lineWidth = 1
        lane.position = CGPoint(x: 0, y: -cardSize.height * 0.03)
        lane.zPosition = 0
        card.addChild(lane)

        let platformDefs: [(y: CGFloat, angle: CGFloat, color: UIColor)] = [
            (cardSize.height * 0.17, -0.18, WarmShelfPalette.sage),
            (-cardSize.height * 0.02, 0.18, WarmShelfPalette.waterBlue),
            (-cardSize.height * 0.22, -0.14, WarmShelfPalette.sand)
        ]

        for (index, def) in platformDefs.enumerated() {
            let platform = makeRoundedRect(
                size: CGSize(width: cardSize.width * 0.44, height: max(12, cardSize.height * 0.060)),
                radius: max(6, cardSize.height * 0.03),
                fill: def.color.withAlpha(0.70),
                stroke: WarmShelfPalette.cocoa.withAlpha(0.05)
            )
            platform.lineWidth = 1
            platform.position = CGPoint(x: CGFloat(index - 1) * cardSize.width * 0.12, y: def.y)
            platform.zRotation = def.angle
            platform.zPosition = CGFloat(5 + index)
            card.addChild(platform)

            let highlight = makeRoundedRect(
                size: CGSize(width: cardSize.width * 0.18, height: 4),
                radius: 2,
                fill: WarmShelfPalette.paperHighlight.withAlpha(0.20)
            )
            highlight.position = CGPoint(x: -cardSize.width * 0.07, y: 2)
            highlight.zPosition = 1
            platform.addChild(highlight)

            AmbientAnimator.idleDrift(node: platform, x: index.isMultiple(of: 2) ? 3 : -3, y: 2, duration: 4.8 + Double(index) * 0.4)
        }

        let pieceScale = min(0.92, max(0.48, cardSize.width / 270))
        let previewPieces: [(SoftDropPieceKind, UIColor, CGPoint)] = [
            (.bead, WarmShelfPalette.terracotta, CGPoint(x: -cardSize.width * 0.17, y: cardSize.height * 0.29)),
            (.capsule, WarmShelfPalette.butter, CGPoint(x: cardSize.width * 0.09, y: cardSize.height * 0.10)),
            (.pebble, WarmShelfPalette.lavender, CGPoint(x: cardSize.width * 0.02, y: -cardSize.height * 0.11))
        ]

        for (index, item) in previewPieces.enumerated() {
            let piece = SoftDropPieceNode(kind: item.0, color: item.1, scale: pieceScale)
            piece.physicsBody = nil
            piece.position = item.2
            piece.zRotation = CGFloat.random(in: -0.18...0.18)
            piece.zPosition = CGFloat(12 + index)
            card.addChild(piece)
            AmbientAnimator.idleDrift(node: piece, x: CGFloat(index - 1) * 3, y: 4, duration: 5.2 + Double(index) * 0.3)
        }
    }

    private func makeWashToyObject(in card: SKNode, cardSize: CGSize, groundY: CGFloat) {
        let canvas = CGSize(width: cardSize.width * 0.94, height: cardSize.width * 0.94 / 1.6)
        let rig = WashVehicleRig.forVehicle(.fireTruck)
        let truck = SKNode()
        // The delivered six-vehicle rig puts every tyre bottom at 88% of the canvas.
        truck.position.y = groundY + canvas.height * 0.38
        truck.zPosition = 3; card.addChild(truck)
        func point(_ p: WashPoint) -> CGPoint {
            CGPoint(x: (CGFloat(p.x) - 0.5) * canvas.width, y: (0.5 - CGFloat(p.y)) * canvas.height)
        }
        if let body = ToyArt.sprite("wash-fire-truck", fit: canvas) {
            body.size = canvas; truck.addChild(body)
        } else {
            let body = SKShapeNode(rectOf: CGSize(width: canvas.width * 0.82, height: canvas.height * 0.37), cornerRadius: canvas.height * 0.11)
            body.fillColor = WarmShelfPalette.terracotta; body.strokeColor = .clear
            body.position.y = -canvas.height * 0.14
            ProceduralTexture.applyClayFill(to: body, base: WarmShelfPalette.terracotta, size: body.frame.size); truck.addChild(body)
            let cab = SKShapeNode(rectOf: CGSize(width: canvas.width * 0.22, height: canvas.height * 0.31), cornerRadius: canvas.height * 0.08)
            cab.fillColor = WarmShelfPalette.waterBlue; cab.strokeColor = .clear
            cab.position = point(rig.faceCenter); truck.addChild(cab)
            let ladder = SKShapeNode(rectOf: CGSize(width: canvas.width * 0.43, height: canvas.height * 0.05), cornerRadius: canvas.height * 0.02)
            ladder.fillColor = WarmShelfPalette.sand; ladder.strokeColor = .clear
            ladder.position = CGPoint(x: -canvas.width * 0.16, y: canvas.height * 0.10); truck.addChild(ladder)
        }
        for wheel in rig.wheels {
            let radius = CGFloat(wheel.radius) * canvas.height
            let node: SKNode
            if let art = ToyArt.sprite("wash-wheel", fit: CGSize(width: radius * 2,height: radius * 2)) {
                node = art
            } else {
                let circle = SKShapeNode(circleOfRadius: radius)
                circle.fillColor = WarmShelfPalette.raisin; circle.strokeColor = .clear
                let hub = SKShapeNode(circleOfRadius: radius * 0.40)
                hub.fillColor = WarmShelfPalette.warmCream; hub.strokeColor = .clear; circle.addChild(hub); node = circle
            }
            node.position = point(wheel.center); node.zPosition = 2; truck.addChild(node)
        }
        for i in 0..<3 {
            let foam = SKShapeNode(circleOfRadius: canvas.height * (i == 1 ? 0.10 : 0.07))
            foam.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.88); foam.strokeColor = WarmShelfPalette.bubblePearl.withAlpha(0.5)
            foam.position = CGPoint(x: canvas.width * (-0.22 + CGFloat(i) * 0.075), y: -canvas.height * 0.11 + CGFloat(i % 2) * canvas.height * 0.06)
            foam.zPosition = 4; truck.addChild(foam)
        }
        addWashShelfFace(to: truck, center: point(rig.faceCenter), radius: CGFloat(rig.faceRadius) * canvas.height)
    }

    private func addWashShelfFace(to parent: SKNode, center: CGPoint, radius rawRadius: CGFloat) {
        let r = max(3, rawRadius)
        let face = SKNode(); face.name = "washShelf.face"; face.position = center; face.zPosition = 5; parent.addChild(face)
        let sleepy = SKNode(); sleepy.name = "sleepy"; face.addChild(sleepy)
        let awake = SKNode(); awake.name = "awake"; awake.alpha = 0; face.addChild(awake)
        for side: CGFloat in [-1,1] {
            let path = CGMutablePath(); path.move(to: CGPoint(x: -r * 0.18,y: 0))
            path.addQuadCurve(to: CGPoint(x: r * 0.18,y: 0),control: CGPoint(x: 0,y: -r * 0.13))
            let lid = SKShapeNode(path: path); lid.position = CGPoint(x: side * r * 0.38,y: r * 0.14)
            lid.strokeColor = WarmShelfPalette.raisin.withAlpha(0.78); lid.lineWidth = max(0.8,r * 0.085); lid.lineCap = .round; sleepy.addChild(lid)
            let eye = SKShapeNode(ellipseOf: CGSize(width: r * 0.22,height: r * 0.29))
            eye.fillColor = WarmShelfPalette.raisin; eye.strokeColor = .clear; eye.position = lid.position; awake.addChild(eye)
        }
        let smile = CGMutablePath(); smile.move(to: CGPoint(x: -r * 0.25,y: -r * 0.21))
        smile.addQuadCurve(to: CGPoint(x: r * 0.25,y: -r * 0.21),control: CGPoint(x: 0,y: -r * 0.42))
        let mouth = SKShapeNode(path: smile); mouth.strokeColor = WarmShelfPalette.raisin.withAlpha(0.75)
        mouth.lineWidth = max(0.8,r * 0.08); mouth.lineCap = .round; face.addChild(mouth)
    }

    private func animateWashShelfFace(in card: SKNode) {
        guard let face = card.childNode(withName: "//washShelf.face"),
              let sleepy = face.childNode(withName: "sleepy"), let awake = face.childNode(withName: "awake") else { return }
        let duration: TimeInterval = AmbientAnimator.reduceMotion ? 0 : 0.08
        sleepy.removeAction(forKey: "wash.wake"); awake.removeAction(forKey: "wash.wake")
        sleepy.run(.sequence([.fadeAlpha(to: 0,duration: duration),.wait(forDuration: 0.48),.fadeAlpha(to: 1,duration: duration)]),withKey: "wash.wake")
        awake.run(.sequence([.fadeAlpha(to: 1,duration: duration),.wait(forDuration: 0.48),.fadeAlpha(to: 0,duration: duration)]),withKey: "wash.wake")
    }

    private struct WashShelfArtGeometry {
        let pixels: CGSize
        let bounds: CGRect
        let window: CGRect?
    }
    private static var cachedWashShelfGeometry: WashShelfArtGeometry?
    private static func washShelfArtGeometry() -> WashShelfArtGeometry? {
        if let cachedWashShelfGeometry { return cachedWashShelfGeometry }
        guard let image = UIImage(named: "shelf-wash-v2"), let cg = image.cgImage,
              cg.bitsPerComponent == 8, cg.bitsPerPixel == 32,
              let data = cg.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return nil }
        let first = cg.alphaInfo == .first || cg.alphaInfo == .premultipliedFirst
        let little = cg.bitmapInfo.contains(.byteOrder32Little)
        let alpha = little ? (first ? 3 : 0) : (first ? 0 : 3)
        let red = little ? (first ? 2 : 3) : (first ? 1 : 0)
        let green = little ? (first ? 1 : 2) : (first ? 2 : 1)
        let blue = little ? (first ? 0 : 1) : (first ? 3 : 2)
        var minX = cg.width, minY = cg.height, maxX = -1, maxY = -1
        for y in 0..<cg.height { for x in 0..<cg.width {
            let p = y * cg.bytesPerRow + x * 4
            if bytes[p + alpha] > 24 { minX = min(minX,x); minY = min(minY,y); maxX = max(maxX,x); maxY = max(maxY,y) }
        }}
        guard maxX > minX, maxY > minY else { return nil }
        let bounds = CGRect(x: minX,y: minY,width: maxX-minX+1,height: maxY-minY+1)
        // The new shelf truck has one blank pale-blue cab at the upper right. Only add
        // a face when actual blue pixels identify that window; foam remains undecorated.
        var wx0 = cg.width, wy0 = cg.height, wx1 = -1, wy1 = -1, count = 0
        let x0 = minX + Int(bounds.width * 0.52), x1 = min(cg.width-1,minX + Int(bounds.width * 0.94))
        let y0 = minY + Int(bounds.height * 0.08), y1 = min(cg.height-1,minY + Int(bounds.height * 0.56))
        for y in stride(from: y0,through: y1,by: 2) { for x in stride(from: x0,through: x1,by: 2) {
            let p = y * cg.bytesPerRow + x * 4
            let r = Int(bytes[p+red]),g = Int(bytes[p+green]),b = Int(bytes[p+blue])
            if bytes[p+alpha] > 180, g > 80, r * 100 < g * 87, b * 100 > g * 96 {
                wx0 = min(wx0,x); wy0 = min(wy0,y); wx1 = max(wx1,x); wy1 = max(wy1,y); count += 1
            }
        }}
        let window = count >= 20 && wx1-wx0 >= 8 && wy1-wy0 >= 8 ? CGRect(x: wx0,y: wy0,width: wx1-wx0+1,height: wy1-wy0+1) : nil
        let geometry = WashShelfArtGeometry(pixels: CGSize(width: cg.width,height: cg.height),bounds: bounds,window: window)
        cachedWashShelfGeometry = geometry
        return geometry
    }

    private func makeStackToyObject(in card: SKNode, cardSize: CGSize) {
        let contact = makeRoundedRect(
            size: CGSize(width: cardSize.width * 0.66, height: max(10, cardSize.height * 0.055)),
            radius: max(5, cardSize.height * 0.028),
            fill: WarmShelfPalette.cocoa.withAlpha(0.024)
        )
        contact.position = CGPoint(x: 0, y: -cardSize.height * 0.34)
        contact.zPosition = 1
        card.addChild(contact)

        let scale = min(0.62, max(0.40, cardSize.width / 360))
        let kinds: [StackPieceKind] = [.pebble, .loaf, .pebble]
        let colors = [WarmShelfPalette.sage, WarmShelfPalette.butter, WarmShelfPalette.terracotta]
        let stackRoot = SKNode()
        card.addChild(stackRoot)

        var y = -cardSize.height * 0.26
        var hero: StackPieceNode?
        for index in 0..<3 {
            let piece = StackPieceNode(
                kind: kinds[index],
                color: colors[index].withAlpha(0.94),
                scale: scale,
                isSignatureHero: index == 2
            )
            piece.physicsBody = nil
            piece.position = CGPoint(x: CGFloat(index - 1) * 4, y: y)
            piece.zPosition = CGFloat(5 + index)
            stackRoot.addChild(piece)
            y += piece.bodySize.height * 0.82
            if piece.isSignatureHero { hero = piece }
        }
        AmbientAnimator.breathe(node: stackRoot, scale: 1.012, duration: 5.2)
        hero?.performShelfInvitation(delay: 0.86)
    }

    private func makeMixUpToyObject(in card: SKNode, cardSize: CGSize) {
        // Fit the character to the card from BOTH dimensions so it never overflows, and
        // show the recognizable king (the combo kids light up at). Parts stack on one
        // root so they read as a single, connected little friend.
        let scale = min(0.55, max(0.30, min(cardSize.width / 360, cardSize.height / 320)))
        let root = SKNode()
        // Character spans roughly +138 (crown) to -124 (feet) in part units; centre that.
        root.position = CGPoint(x: 0, y: -7 * scale - cardSize.height * 0.02)
        card.addChild(root)

        let legs = MixUpLibrary.parts(for: .legs)[0].build(scale)   // boots
        legs.position = CGPoint(x: 0, y: -88 * scale); legs.zPosition = 1; root.addChild(legs)
        let body = MixUpLibrary.parts(for: .body)[0].build(scale)   // royal robe
        body.position = CGPoint.zero; body.zPosition = 2; root.addChild(body)
        let head = MixUpLibrary.parts(for: .head)[0].build(scale)   // king
        head.position = CGPoint(x: 0, y: 92 * scale); head.zPosition = 3; root.addChild(head)

        // Gentle breathing of the whole figure (connected, not 3 drifting parts).
        AmbientAnimator.breathe(node: root, scale: 1.02, duration: 4.6)
    }

    private func makeBloomToyObject(in card: SKNode, cardSize: CGSize) {
        let canvasSize = CGSize(width: cardSize.width * 0.82, height: cardSize.height * 0.72)
        let canvasRadius = min(28, cardSize.height * 0.14)
        let canvas = makeRoundedRect(
            size: canvasSize,
            radius: canvasRadius,
            fill: WarmShelfPalette.sage.withAlpha(0.07),
            stroke: WarmShelfPalette.sand.withAlpha(0.12)
        )
        canvas.lineWidth = 1
        canvas.position = CGPoint(x: 0, y: -cardSize.height * 0.02)
        canvas.zPosition = 0
        card.addChild(canvas)
        ProceduralTexture.addMatteClayDepth(
            to: canvas,
            in: CGRect(x: -canvasSize.width / 2, y: -canvasSize.height / 2, width: canvasSize.width, height: canvasSize.height),
            cornerRadius: canvasRadius,
            zPosition: 0.10,
            highlightAlpha: 0.10,
            shadeAlpha: 0.024,
            rimAlpha: 0.025,
            speckleCount: 4
        )

        let scale = min(0.92, max(0.5, cardSize.width / 300))
        let specs: [(BloomKind, UIColor, CGPoint)] = [
            (.flower, WarmShelfPalette.petal, CGPoint(x: -cardSize.width * 0.20, y: cardSize.height * 0.12)),
            (.flower, WarmShelfPalette.butter, CGPoint(x: cardSize.width * 0.16, y: cardSize.height * 0.20)),
            (.mushroom, WarmShelfPalette.terracotta, CGPoint(x: -cardSize.width * 0.02, y: -cardSize.height * 0.08)),
            (.tallFlower, WarmShelfPalette.lavender, CGPoint(x: cardSize.width * 0.22, y: -cardSize.height * 0.14)),
            (.berry, WarmShelfPalette.rhubarb, CGPoint(x: -cardSize.width * 0.22, y: -cardSize.height * 0.16))
        ]

        for (index, spec) in specs.enumerated() {
            let bloom = BloomNode(kind: spec.0, color: spec.1, scale: scale)
            bloom.position = spec.2
            bloom.zPosition = CGFloat(4 + index)
            card.addChild(bloom)
            AmbientAnimator.wobble(node: bloom, amount: CGFloat.random(in: 0.05...0.10), duration: Double.random(in: 2.6...3.8))
            AmbientAnimator.idleDrift(node: bloom, x: CGFloat.random(in: -2...2), y: CGFloat.random(in: 2...4), duration: Double.random(in: 5.0...7.0), delay: Double(index) * 0.2)
        }
    }

    /// A tiny wooden bedtime board: a glowing lamp button under a moon and a few stars.
    private func makeGlowboardToyObject(in card: SKNode, cardSize: CGSize) {
        let w = cardSize.width, h = cardSize.height

        let sky = makeRoundedRect(
            size: CGSize(width: w * 0.84, height: h * 0.74),
            radius: min(26, h * 0.13),
            fill: UIColor(red: 0.10, green: 0.09, blue: 0.20, alpha: 0.16),
            stroke: WarmShelfPalette.sand.withAlpha(0.12)
        )
        sky.lineWidth = 1
        sky.position = CGPoint(x: 0, y: -h * 0.02)
        sky.zPosition = 0
        card.addChild(sky)

        let moonGlow = SKShapeNode(circleOfRadius: w * 0.15)
        moonGlow.fillColor = UIColor(hex: 0xCFE0F2).withAlpha(0.26)
        moonGlow.strokeColor = .clear
        moonGlow.blendMode = .add
        moonGlow.position = CGPoint(x: w * 0.23, y: h * 0.20)
        moonGlow.zPosition = 1
        card.addChild(moonGlow)
        AmbientAnimator.breathe(node: moonGlow, scale: 1.08, duration: 5.0)

        let moon = SKShapeNode(circleOfRadius: w * 0.07)
        moon.fillColor = UIColor(hex: 0xF4EFD6)
        moon.strokeColor = WarmShelfPalette.sand.withAlpha(0.20)
        moon.lineWidth = 1
        moon.position = moonGlow.position
        moon.zPosition = 2
        card.addChild(moon)

        for p in [CGPoint(x: -w * 0.26, y: h * 0.20), CGPoint(x: -w * 0.05, y: h * 0.28), CGPoint(x: w * 0.02, y: h * 0.07)] {
            let star = SKShapeNode(circleOfRadius: max(1.6, w * 0.013))
            star.fillColor = UIColor(hex: 0xFBF4DA)
            star.strokeColor = .clear
            star.blendMode = .add
            star.position = p
            star.zPosition = 2
            card.addChild(star)
            AmbientAnimator.breathe(node: star, scale: 1.4, duration: Double.random(in: 2.4...3.8))
        }

        let board = makeRoundedRect(
            size: CGSize(width: w * 0.64, height: h * 0.34),
            radius: min(18, h * 0.09),
            fill: UIColor(hex: 0xBE955C),
            stroke: WarmShelfPalette.cocoa.withAlpha(0.16)
        )
        board.lineWidth = 1.5
        board.position = CGPoint(x: 0, y: -h * 0.22)
        board.zPosition = 3
        card.addChild(board)

        let lampGlow = SKShapeNode(circleOfRadius: w * 0.17)
        lampGlow.fillColor = WarmShelfPalette.butter.withAlpha(0.5)
        lampGlow.strokeColor = .clear
        lampGlow.blendMode = .add
        lampGlow.position = board.position
        lampGlow.zPosition = 3.5
        card.addChild(lampGlow)
        AmbientAnimator.breathe(node: lampGlow, scale: 1.14, duration: 3.2)

        let button = SKShapeNode(circleOfRadius: w * 0.075)
        button.fillColor = WarmShelfPalette.sand
        button.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.16)
        button.lineWidth = 1.5
        button.position = board.position
        button.zPosition = 4
        card.addChild(button)

        let lens = SKShapeNode(circleOfRadius: w * 0.04)
        lens.fillColor = WarmShelfPalette.butter
        lens.strokeColor = .clear
        lens.blendMode = .add
        lens.position = board.position
        lens.zPosition = 4.1
        card.addChild(lens)

        // A small knob and a dimmer thumb flanking the lamp, so the board reads as a real console.
        let knob = SKShapeNode(circleOfRadius: w * 0.045)
        knob.fillColor = WarmShelfPalette.sand
        knob.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.14)
        knob.lineWidth = 1
        knob.position = CGPoint(x: board.position.x + w * 0.21, y: board.position.y + h * 0.02)
        knob.zPosition = 4
        card.addChild(knob)

        let thumb = SKShapeNode(circleOfRadius: w * 0.035)
        thumb.fillColor = WarmShelfPalette.terracotta
        thumb.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.12)
        thumb.lineWidth = 1
        thumb.position = CGPoint(x: board.position.x - w * 0.16, y: board.position.y - h * 0.10)
        thumb.zPosition = 4
        card.addChild(thumb)
    }

    /// A tiny sleepy wooden box: a treasure bobbing toward a hole on top, a carved sleepy face,
    /// and a drawer below — reads as "put in / get out".
    private func makeSleepyDropBoxToyObject(in card: SKNode, cardSize: CGSize) {
        let w = cardSize.width, h = cardSize.height
        let wood = UIColor(hex: 0xCBA268), woodTop = UIColor(hex: 0xD8B074), woodDark = UIColor(hex: 0x9A7438)
        let ink = WarmShelfPalette.cocoa.withAlpha(0.55)

        let top = makeRoundedRect(size: CGSize(width: w * 0.56, height: h * 0.2), radius: h * 0.08,
                                  fill: woodTop, stroke: WarmShelfPalette.cocoa.withAlpha(0.14))
        top.position = CGPoint(x: 0, y: h * 0.1)
        top.zPosition = 1
        card.addChild(top)

        let felt = SKShapeNode(circleOfRadius: w * 0.08)
        felt.fillColor = WarmShelfPalette.rhubarb
        felt.strokeColor = .clear
        felt.position = CGPoint(x: 0, y: h * 0.1)
        felt.zPosition = 1.1
        card.addChild(felt)
        let hole = SKShapeNode(circleOfRadius: w * 0.055)
        hole.fillColor = UIColor(hex: 0x2A1A10).withAlpha(0.92)
        hole.strokeColor = .clear
        hole.position = CGPoint(x: 0, y: h * 0.1)
        hole.zPosition = 1.2
        card.addChild(hole)

        let treasure = SKShapeNode(circleOfRadius: w * 0.05)
        treasure.fillColor = WarmShelfPalette.terracotta
        treasure.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.1)
        treasure.lineWidth = 1
        treasure.position = CGPoint(x: 0, y: h * 0.27)
        treasure.zPosition = 3
        card.addChild(treasure)
        AmbientAnimator.idleDrift(node: treasure, x: 0, y: -4, duration: 2.2)

        let box = makeRoundedRect(size: CGSize(width: w * 0.6, height: h * 0.34), radius: min(18, h * 0.09),
                                  fill: wood, stroke: WarmShelfPalette.cocoa.withAlpha(0.16))
        box.position = CGPoint(x: 0, y: -h * 0.08)
        box.zPosition = 2
        card.addChild(box)

        for sign in [CGFloat(-1), CGFloat(1)] {
            let eye = SKShapeNode()
            let p = CGMutablePath()
            let ew = w * 0.05
            p.move(to: CGPoint(x: -ew, y: 0)); p.addQuadCurve(to: CGPoint(x: ew, y: 0), control: CGPoint(x: 0, y: -h * 0.02))
            eye.path = p
            eye.strokeColor = ink; eye.lineWidth = 2.4; eye.lineCap = .round; eye.fillColor = .clear
            eye.position = CGPoint(x: sign * w * 0.1, y: -h * 0.04)
            eye.zPosition = 3
            card.addChild(eye)
        }
        let mouth = SKShapeNode()
        let mp = CGMutablePath()
        let mw = w * 0.06
        mp.move(to: CGPoint(x: -mw, y: 0)); mp.addQuadCurve(to: CGPoint(x: mw, y: 0), control: CGPoint(x: 0, y: -h * 0.03))
        mouth.path = mp
        mouth.strokeColor = ink; mouth.lineWidth = 2.2; mouth.lineCap = .round; mouth.fillColor = .clear
        mouth.position = CGPoint(x: 0, y: -h * 0.1)
        mouth.zPosition = 3
        card.addChild(mouth)

        let drawer = makeRoundedRect(size: CGSize(width: w * 0.4, height: h * 0.1), radius: h * 0.04,
                                     fill: woodTop, stroke: WarmShelfPalette.cocoa.withAlpha(0.14))
        drawer.position = CGPoint(x: 0, y: -h * 0.2)
        drawer.zPosition = 3
        card.addChild(drawer)
        let knob = SKShapeNode(circleOfRadius: w * 0.03)
        knob.fillColor = woodDark
        knob.strokeColor = .clear
        knob.position = CGPoint(x: 0, y: -h * 0.21)
        knob.zPosition = 3.1
        card.addChild(knob)
    }

    /// A little window with a sun in a warm sky and a curtain — reads as "a room that glows".
    private func makeGlowWindowToyObject(in card: SKNode, cardSize: CGSize) {
        let w = cardSize.width, h = cardSize.height
        let winW = w * 0.6, winH = h * 0.66
        let pos = CGPoint(x: 0, y: h * 0.02)
        let rect = CGRect(x: -winW / 2, y: -winH / 2, width: winW, height: winH)

        let sky = SKShapeNode(rect: rect, cornerRadius: winW * 0.16)
        sky.fillColor = UIColor(hex: 0x9CC9EA); sky.strokeColor = .clear; sky.position = pos; sky.zPosition = 1
        card.addChild(sky)
        let lower = SKShapeNode(rect: CGRect(x: rect.minX, y: rect.minY, width: winW, height: winH * 0.46), cornerRadius: winW * 0.16)
        lower.fillColor = UIColor(hex: 0xFFE0B0).withAlpha(0.85); lower.strokeColor = .clear; lower.position = pos; lower.zPosition = 1.1
        card.addChild(lower)
        let sun = SKShapeNode(circleOfRadius: winW * 0.17)
        sun.fillColor = UIColor(hex: 0xFFD15A); sun.strokeColor = .clear
        sun.position = CGPoint(x: -winW * 0.15, y: pos.y + winH * 0.16); sun.zPosition = 1.2
        card.addChild(sun)
        let frame = SKShapeNode(rect: rect, cornerRadius: winW * 0.16)
        frame.fillColor = .clear; frame.strokeColor = UIColor(hex: 0xC79A57); frame.lineWidth = max(6, winW * 0.1)
        frame.position = pos; frame.zPosition = 1.5
        card.addChild(frame)
        let vbar = SKShapeNode(rect: CGRect(x: -winW * 0.03, y: rect.minY, width: winW * 0.06, height: winH), cornerRadius: winW * 0.03)
        vbar.fillColor = UIColor(hex: 0xC79A57); vbar.strokeColor = .clear; vbar.position = pos; vbar.zPosition = 1.6
        card.addChild(vbar)
        let hbar = SKShapeNode(rect: CGRect(x: rect.minX, y: -winH * 0.03, width: winW, height: winH * 0.06), cornerRadius: winW * 0.03)
        hbar.fillColor = UIColor(hex: 0xC79A57); hbar.strokeColor = .clear; hbar.position = pos; hbar.zPosition = 1.6
        card.addChild(hbar)
        let curtain = SKShapeNode(rect: CGRect(x: rect.minX - winW * 0.06, y: rect.minY, width: winW * 0.22, height: winH), cornerRadius: winW * 0.06)
        curtain.fillColor = WarmShelfPalette.terracotta; curtain.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.2); curtain.lineWidth = 1
        curtain.position = pos; curtain.zPosition = 2
        card.addChild(curtain)
    }

    /// A little wooden drop board with colorful dots stacked in felt columns — "drop the dots in".
    private func makeDropDotsToyObject(in card: SKNode, cardSize: CGSize) {
        let w = cardSize.width, h = cardSize.height
        let boardW = w * 0.68, boardH = h * 0.6
        let by = h * 0.05
        let board = SKShapeNode(rect: CGRect(x: -boardW / 2, y: by - boardH / 2, width: boardW, height: boardH), cornerRadius: boardW * 0.1)
        board.fillColor = UIColor(hex: 0xCB9A52); board.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.2); board.lineWidth = 1.5
        board.zPosition = 1
        card.addChild(board)
        let cols = 4
        let cellW = boardW * 0.84 / CGFloat(cols)
        let colors = [UIColor(hex: 0xD24B3E), UIColor(hex: 0xF2C24C), UIColor(hex: 0x84A94E), WarmShelfPalette.waterBlue]
        let dotR = cellW * 0.3
        let boardBottom = by - boardH / 2
        let boardTop = by + boardH / 2
        let stacks = [2, 1, 3, 1]
        for i in 0..<cols {
            let cx = -boardW * 0.42 + cellW * (CGFloat(i) + 0.5)
            let tube = SKShapeNode(rect: CGRect(x: cx - cellW * 0.32, y: boardBottom + boardH * 0.1, width: cellW * 0.64, height: boardH * 0.66), cornerRadius: cellW * 0.28)
            tube.fillColor = UIColor(hex: 0x4A2E1C); tube.strokeColor = .clear; tube.zPosition = 1.1
            card.addChild(tube)
            for s in 0..<stacks[i] {
                let dot = SKShapeNode(circleOfRadius: dotR)
                dot.fillColor = colors[(i + s) % colors.count]; dot.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.14); dot.lineWidth = 1
                dot.position = CGPoint(x: cx, y: boardBottom + boardH * 0.16 + CGFloat(s) * dotR * 2.1)
                dot.zPosition = 1.2
                card.addChild(dot)
                let hi = SKShapeNode(ellipseOf: CGSize(width: dotR * 0.9, height: dotR * 0.4))
                hi.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.3); hi.strokeColor = .clear
                hi.position = CGPoint(x: cx - dotR * 0.2, y: dot.position.y + dotR * 0.4); hi.zPosition = 1.21
                card.addChild(hi)
            }
            let mouth = SKShapeNode(ellipseOf: CGSize(width: cellW * 0.7, height: cellW * 0.36))
            mouth.fillColor = colors[i % colors.count]; mouth.strokeColor = .clear
            mouth.position = CGPoint(x: cx, y: boardTop - boardH * 0.07); mouth.zPosition = 1.3
            card.addChild(mouth)
        }
    }

    private func makeDoughToyObject(in card: SKNode, cardSize: CGSize) {
        let s = min(cardSize.width, cardSize.height) * 0.5

        // A soft, slightly lumpy lump of clay dough.
        let lumpPath = CGMutablePath()
        let n = 18
        var pts: [CGPoint] = []
        for i in 0..<n {
            let a = CGFloat(i) / CGFloat(n) * .pi * 2
            let lump = 1 + 0.06 * sin(a * 3 + 0.6) + 0.04 * cos(a * 2)
            pts.append(CGPoint(x: cos(a) * s * 0.5 * lump, y: sin(a) * s * 0.42 * lump))
        }
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        lumpPath.move(to: mid(pts[n - 1], pts[0]))
        for i in 0..<n {
            lumpPath.addQuadCurve(to: mid(pts[i], pts[(i + 1) % n]), control: pts[i])
        }
        lumpPath.closeSubpath()

        let dough = SKShapeNode(path: lumpPath)
        dough.fillColor = WarmShelfPalette.terracotta
        dough.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.07)
        dough.lineWidth = max(1.2, cardSize.width * 0.006)
        dough.position = CGPoint(x: 0, y: -cardSize.height * 0.02)
        dough.zPosition = 4
        card.addChild(dough)

        let highlight = SKShapeNode(ellipseOf: CGSize(width: s * 0.42, height: s * 0.26))
        highlight.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.62)
        highlight.strokeColor = .clear
        highlight.position = CGPoint(x: -s * 0.18, y: s * 0.16)
        highlight.zRotation = -0.32
        highlight.zPosition = 5
        dough.addChild(highlight)

        for pt in [CGPoint(x: 0.22, y: 0.1), CGPoint(x: -0.24, y: -0.14), CGPoint(x: 0.28, y: -0.18)] {
            let dimple = SKShapeNode(circleOfRadius: s * 0.04)
            dimple.fillColor = WarmShelfPalette.cocoa.withAlpha(0.06)
            dimple.strokeColor = .clear
            dimple.position = CGPoint(x: pt.x * s, y: pt.y * s)
            dimple.zPosition = 6
            dough.addChild(dimple)
        }

        AmbientAnimator.breathe(node: dough, scale: 1.016, duration: 5.6)
    }

    private func makeCurrentToyObject(in card: SKNode, cardSize: CGSize) {
        let center = CGPoint(x: 0, y: -cardSize.height * 0.02)
        // Warm sage-teal to match the warmed water and its clay jelly creatures.
        let ripple = UIColor(red: 0.45, green: 0.69, blue: 0.63, alpha: 1.0)
        let colors: [UIColor] = [
            ripple,
            ripple.withAlpha(0.55),
            ripple.withAlpha(0.28)
        ]
        let radii: [CGFloat] = [
            min(cardSize.width, cardSize.height) * 0.18,
            min(cardSize.width, cardSize.height) * 0.30,
            min(cardSize.width, cardSize.height) * 0.42
        ]
        for (index, radius) in radii.enumerated() {
            let ring = SKShapeNode(circleOfRadius: radius)
            ring.fillColor = .clear
            ring.strokeColor = colors[index]
            ring.lineWidth = max(1.2, (3 - CGFloat(index)) * cardSize.width * 0.008)
            ring.position = center
            ring.zPosition = CGFloat(6 - index)
            card.addChild(ring)
            let pulse = SKAction.sequence([
                .wait(forDuration: Double(index) * 0.4),
                .repeatForever(.sequence([
                    .group([
                        .scale(to: 1.06, duration: 1.2),
                        .fadeAlpha(to: 0.55, duration: 1.2)
                    ]),
                    .group([
                        .scale(to: 1.0, duration: 1.4),
                        .fadeAlpha(to: 1.0, duration: 1.4)
                    ])
                ]))
            ])
            ring.run(pulse)
        }

        let dot = SKShapeNode(circleOfRadius: min(cardSize.width, cardSize.height) * 0.07)
        dot.fillColor = ripple
        dot.strokeColor = .clear
        dot.position = center
        dot.zPosition = 8
        card.addChild(dot)
        AmbientAnimator.breathe(node: dot, scale: 1.10, duration: 2.2)
    }

    private func makePreviewBubbles(in card: SKNode, cardSize: CGSize) {
        let count = cardSize.width < 190 ? 7 : 9
        for index in 0..<count {
            let radius = CGFloat.random(in: max(18, cardSize.width * 0.10)...max(32, min(76, cardSize.width * 0.22)))
            let bubble = BubbleNode(radius: radius, style: BubbleStyle.preview(index: index))
            bubble.position = CGPoint(
                x: CGFloat.random(in: -cardSize.width * 0.25...cardSize.width * 0.25),
                y: CGFloat.random(in: -cardSize.height * 0.18...cardSize.height * 0.26)
            )
            bubble.zPosition = 3
            bubble.isUserInteractionEnabled = false
            card.addChild(bubble)

            AmbientAnimator.idleDrift(
                node: bubble,
                x: CGFloat.random(in: -10...10),
                y: CGFloat.random(in: 12...24),
                duration: .random(in: 3.6...6.8),
                delay: Double(index) * 0.19
            )
            AmbientAnimator.wobble(node: bubble, amount: CGFloat.random(in: 0.025...0.07), duration: .random(in: 3.2...5.4))

            if index == 0 {
                runPreviewBubblePulse(bubble, delay: 2.4)
            }
        }
    }

    private func makePreviewBlocks(in card: SKNode, cardSize: CGSize) {
        let colors = [
            WarmShelfPalette.terracotta,
            WarmShelfPalette.sage,
            WarmShelfPalette.sand,
            WarmShelfPalette.butter,
            WarmShelfPalette.lavender
        ]
        let kinds: [ClayBlockKind] = [.brick, .cube, .plank, .tall, .cylinder]
        let positions = [
            CGPoint(x: -cardSize.width * 0.22, y: -cardSize.height * 0.28),
            CGPoint(x: -cardSize.width * 0.03, y: -cardSize.height * 0.27),
            CGPoint(x: cardSize.width * 0.16, y: -cardSize.height * 0.13),
            CGPoint(x: cardSize.width * 0.02, y: cardSize.height * 0.08),
            CGPoint(x: -cardSize.width * 0.22, y: -cardSize.height * 0.03)
        ]

        for index in 0..<kinds.count {
            let scale = min(1.36, max(0.88, cardSize.width / 300))
            let block = ClayBlockNode(
                kind: kinds[index],
                color: colors[index].withAlpha(0.86),
                scale: scale
            )
            block.physicsBody = nil
            block.position = positions[index]
            block.zRotation = CGFloat.random(in: -0.16...0.16)
            block.zPosition = CGFloat(4 + index)
            card.addChild(block)

            AmbientAnimator.idleDrift(
                node: block,
                x: CGFloat.random(in: -4...4),
                y: CGFloat.random(in: 4...9),
                duration: Double.random(in: 4.8...7.2),
                delay: Double(index) * 0.2
            )
        }
    }

    private func makePreviewPeople(in card: SKNode, cardSize: CGSize) {
        let scale = min(1.24, max(0.78, cardSize.width / 250))
        // Just two friends — a calm pair — so the card reads clearly as "feed the people"
        // instead of a crowded little group.
        let specs: [(UIColor, UIColor, CharacterPersonality, CGFloat, CGPoint)] = [
            (UIColor(hex: 0xB78E62).withAlpha(0.9), WarmShelfPalette.sage, .calm, 34 * scale, CGPoint(x: -cardSize.width * 0.15, y: cardSize.height * 0.0)),
            (WarmShelfPalette.petal.withAlpha(0.9), WarmShelfPalette.butter, .fidgety, 27 * scale, CGPoint(x: cardSize.width * 0.21, y: -cardSize.height * 0.07))
        ]
        let looks: [(CharacterAccessory, CharacterHairStyle, CharacterOutfitStyle)] = [
            (.softCrown, .swoop, .starSweater),
            (.flowerClip, .sprout, .apron)
        ]

        for (index, spec) in specs.enumerated() {
            let person = CharacterNode(
                headRadius: spec.3,
                baseColor: spec.0,
                clothingColor: spec.1,
                personality: spec.2,
                accessory: looks[index].0,
                hairStyle: looks[index].1,
                outfitStyle: looks[index].2
            )
            person.position = spec.4
            person.zPosition = CGFloat(5 + index)
            card.addChild(person)
        }

        let foodKinds: [FoodKind] = [.apple, .berry]
        for index in 0..<foodKinds.count {
            let food = FoodNode(kind: foodKinds[index], scale: scale * 0.72)
            food.position = CGPoint(
                x: (index == 0 ? -1 : 1) * cardSize.width * 0.16,
                y: -cardSize.height * 0.30 + CGFloat(index.isMultiple(of: 2) ? 3 : -2)
            )
            food.zPosition = CGFloat(10 + index)
            food.physicsBody = nil
            card.addChild(food)
            AmbientAnimator.idleDrift(
                node: food,
                x: CGFloat.random(in: -2...2),
                y: CGFloat.random(in: 2...4),
                duration: Double.random(in: 4.6...6.6),
                delay: Double(index) * 0.2
            )
        }
    }

    private func runPreviewBubblePulse(_ bubble: BubbleNode, delay: TimeInterval) {
        let wait = SKAction.wait(forDuration: delay)
        let pulse = SKAction.scale(to: 1.08, duration: 0.38)
        let settle = SKAction.scale(to: 1.0, duration: 0.54)
        pulse.timingMode = .easeInEaseOut
        settle.timingMode = .easeInEaseOut
        bubble.run(.repeatForever(.sequence([wait, pulse, settle])))
    }

    private func resetShelfInvitationClock(delay: TimeInterval) {
        let now = CACurrentMediaTime()
        lastShelfInteractionAt = now
        nextShelfInvitationAt = now + delay
    }

    private func updateShelfInvitation(_ currentTime: TimeInterval) {
        guard hasAnimatedEntrance, !isOpeningToy, !AmbientAnimator.reduceMotion else { return }
        if nextShelfInvitationAt == 0 { resetShelfInvitationClock(delay: 12.0) }
        guard currentTime >= nextShelfInvitationAt, currentTime - lastShelfInteractionAt > 11.5 else { return }
        playShelfInvitation()
        nextShelfInvitationAt = currentTime + 30.0
    }

    private func playShelfInvitation() {
        let shelfToys = weightedShelfInvitationToys()
        guard !shelfToys.isEmpty else { return }
        let descriptor = shelfToys[shelfInvitationCursor % shelfToys.count]
        shelfInvitationCursor += 1
        guard let card = cardRoot(for: descriptor.id) else { return }

        playInvitationHalo(around: card, color: descriptor.accentColor)

        let perk = SKAction.scale(to: 1.025, duration: 0.16)
        let settle = SKAction.scale(to: 1.0, duration: 0.56)
        perk.timingMode = .easeOut
        settle.timingMode = .easeInEaseOut
        card.run(.sequence([perk, settle]), withKey: "shelfInvitationPerk")

        switch descriptor.id {
        case ToyRegistry.bubblesID:
            if let bubble = descendants(of: card, as: BubbleNode.self).max(by: { $0.radius < $1.radius }) {
                let open = SKAction.scale(to: 1.08, duration: 0.24)
                let rest = SKAction.scale(to: 1.0, duration: 0.62)
                open.timingMode = .easeOut
                rest.timingMode = .easeInEaseOut
                bubble.run(.sequence([open, rest]), withKey: "shelfInvitationBubble")
            }
        case ToyRegistry.feedThePeopleID:
            descendants(of: card, as: CharacterNode.self).first?.playFriendshipReaction(force: true)
        case ToyRegistry.washID:
            animateWashShelfFace(in: card)
        case ToyRegistry.stackID:
            descendants(of: card, as: StackPieceNode.self)
                .max(by: { $0.position.y < $1.position.y })?
                .performShelfInvitation(delay: 0)
        case ToyRegistry.bloomID:
            descendants(of: card, as: BloomNode.self).first?.cheer()
        case ToyRegistry.mixUpID:
            card.run(.sequence([
                .rotate(byAngle: 0.018, duration: 0.16),
                .rotate(byAngle: -0.030, duration: 0.22),
                .rotate(toAngle: 0, duration: 0.30)
            ]), withKey: "shelfInvitationMix")
        case ToyRegistry.humID:
            descendants(of: card, as: HumObjectNode.self).first?.strum()
        default:
            break
        }
    }

    private func weightedShelfInvitationToys() -> [ToyDescriptor] {
        // Each launched toy gets one quiet invitation; parked Stack keeps its code paths.
        ToyRegistry.childShelfToys
    }

    private func playInvitationHalo(around card: SKNode, color: UIColor) {
        let frame = card.calculateAccumulatedFrame()
        let halo = SKShapeNode(ellipseOf: CGSize(
            width: max(72, frame.width * 0.64),
            height: max(64, frame.height * 0.46)
        ))
        halo.fillColor = color.withAlpha(0.055)
        halo.strokeColor = color.withAlpha(0.18)
        halo.lineWidth = 2
        halo.position = card.position
        halo.zPosition = card.zPosition - 0.25
        halo.setScale(0.84)
        contentRoot.addChild(halo)

        let bloom = SKAction.group([
            .scale(to: 1.08, duration: 0.78),
            .fadeOut(withDuration: 0.78)
        ])
        bloom.timingMode = .easeOut
        halo.run(.sequence([bloom, .removeFromParent()]), withKey: "shelfInvitationHalo")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isOpeningToy else { return }
        HapticsManager.shared.prepareForTouch()
        resetShelfInvitationClock(delay: 6.0)

        for touch in touches {
            let point = touch.location(in: self)
            let nodesAtPoint = nodes(at: point)

            if nodeIsHost(nodesAtPoint) {
                beginHostTouch(touch, at: point)
                continue
            }

            guard let toyID = toyID(for: nodesAtPoint), let card = cardRoot(for: nodesAtPoint) else {
                triggerShelfWakeUp(at: point)
                HapticsManager.shared.emptyTap()
                continue
            }

            isOpeningToy = true
            TouchFeedbackAnimator.acknowledge(node: card, profile: .shelfCard)
            reactToToyTap(toyID: toyID, card: card)
            HapticsManager.shared.cardPress()   // a firm, physical clay-button press, felt not heard
            playWakeBloom(card: card, toyID: toyID)
            return
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if moveHostTouch(touch, to: touch.location(in: self)) {
                continue
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if endHostTouch(touch, cancelled: false) {
                continue
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if endHostTouch(touch, cancelled: true) {
                continue
            }
        }
    }

    private func cardPosition(index: Int, count: Int, layout: ShelfLayout) -> CGPoint {
        if layout.usesRow {
            let row = index / layout.columns
            let column = index % layout.columns
            let rowStart = row * layout.columns
            let countInRow = min(layout.columns, count - rowStart)
            let firstX = size.width / 2 - CGFloat(countInRow - 1) * layout.spacing / 2
            return CGPoint(
                x: firstX + CGFloat(column) * layout.spacing,
                y: layout.shelfY - CGFloat(row) * layout.rowSpacing + layout.objectSize.height * 0.48
            )
        }

        let firstY = layout.shelfY + layout.objectSize.height * 0.48 + CGFloat(count - 1) * layout.spacing / 2
        return CGPoint(x: size.width / 2, y: firstY - CGFloat(index) * layout.spacing)
    }

    private func cardName(for toyID: String) -> String {
        "toyCard.\(toyID)"
    }

    /// Meadow's shelf object: a tiny dozing snail beside two wildflowers (authored
    /// `shelf-meadow` art replaces it the moment it lands).
    private func makeMeadowToyObject(in root: SKNode, cardSize: CGSize) {
        if let art = ToyArt.sprite("shelf-meadow", fit: cardSize) {
            root.addChild(art)
            return
        }
        let s = cardSize.width * 0.16
        for (dx, color) in [(CGFloat(-0.27), WarmShelfPalette.petal), (CGFloat(0.31), WarmShelfPalette.lavender)] {
            let stem = SKShapeNode(rect: CGRect(x: -1, y: 0, width: 2, height: s * 0.9), cornerRadius: 1)
            stem.fillColor = UIColor(hex: 0x6E9355)
            stem.strokeColor = .clear
            stem.position = CGPoint(x: cardSize.width * dx, y: -cardSize.height * 0.30)
            root.addChild(stem)
            let head = SKShapeNode(circleOfRadius: s * 0.3)
            head.fillColor = color
            head.strokeColor = .clear
            head.position = CGPoint(x: stem.position.x, y: stem.position.y + s * 0.95)
            root.addChild(head)
        }
        let body = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: -s * 1.1, y: -s * 0.45, width: s * 2.2, height: s * 0.85),
            cornerWidth: s * 0.42, cornerHeight: s * 0.42, transform: nil))
        body.fillColor = UIColor(hex: 0xD9C7A4)
        body.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.14)
        body.lineWidth = 1
        body.position = CGPoint(x: 0, y: -cardSize.height * 0.30)
        root.addChild(body)
        let shell = SKShapeNode(circleOfRadius: s * 0.62)
        shell.fillColor = WarmShelfPalette.terracotta
        shell.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.16)
        shell.lineWidth = 1
        shell.position = CGPoint(x: -s * 0.25, y: body.position.y + s * 0.5)
        root.addChild(shell)
        let inner = SKShapeNode(circleOfRadius: s * 0.34)
        inner.fillColor = WarmShelfPalette.terracotta.withAlpha(0.7)
        inner.strokeColor = .clear
        inner.position = shell.position
        root.addChild(inner)
        AmbientAnimator.breathe(node: root, scale: 1.015, duration: 5.4)
    }

    private func reactToToyTap(toyID: String, card: SKNode) {
        switch toyID {
        case ToyRegistry.bubblesID:
            if let bubble = descendants(of: card, as: BubbleNode.self).max(by: { $0.radius < $1.radius }) {
                ParticleManager.bubblePop(
                    in: self,
                    at: bubble.convert(CGPoint.zero, to: self),
                    radius: bubble.radius,
                    primaryColor: bubble.style.popColor,
                    secondaryColor: bubble.style.secondaryPopColor,
                    isRare: bubble.isRare
                )
                bubble.removeFromParent()
            }
        case ToyRegistry.clayBlocksID:
            for block in descendants(of: card, as: ClayBlockNode.self) {
                let nudge = SKAction.sequence([
                    .rotate(byAngle: CGFloat.random(in: -0.08...0.08), duration: 0.08),
                    .moveBy(x: CGFloat.random(in: -3...3), y: CGFloat.random(in: 3...8), duration: 0.12),
                    .moveBy(x: CGFloat.random(in: -2...2), y: CGFloat.random(in: -5 ... -2), duration: 0.18)
                ])
                nudge.timingMode = .easeInEaseOut
                block.run(nudge)
            }
        case ToyRegistry.feedThePeopleID:
            for person in descendants(of: card, as: CharacterNode.self) {
                TouchFeedbackAnimator.acknowledge(node: person, profile: .shelfCard)
            }
            if let food = descendants(of: card, as: FoodNode.self).first {
                let move = SKAction.moveBy(x: 0, y: 8, duration: 0.12)
                let settle = SKAction.moveBy(x: 0, y: -8, duration: 0.22)
                move.timingMode = .easeOut
                settle.timingMode = .easeInEaseOut
                food.run(.sequence([move, settle]))
            }
        case ToyRegistry.humID:
            for (index, object) in descendants(of: card, as: HumObjectNode.self).enumerated() {
                object.run(.sequence([
                    .wait(forDuration: Double(index) * 0.07),
                    .run {
                        object.noticeAndHold()
                        object.startShimmer()
                    },
                    .wait(forDuration: 0.42),
                    .run {
                        object.stopShimmer()
                        object.settleHome()
                    }
                ]), withKey: "shelfHumTap")
            }
        case ToyRegistry.softDropID:
            for piece in descendants(of: card, as: SoftDropPieceNode.self) {
                let drop = SKAction.moveBy(x: CGFloat.random(in: -4...4), y: -12, duration: 0.16)
                let lift = SKAction.moveBy(x: CGFloat.random(in: -3...3), y: 12, duration: 0.26)
                drop.timingMode = .easeIn
                lift.timingMode = .easeOut
                piece.run(.sequence([drop, lift]))
                TouchFeedbackAnimator.tactileSpark(
                    in: self,
                    at: piece.convert(.zero, to: self),
                    color: piece.pieceColor,
                    count: 2,
                    includesRipple: false
                )
            }
        case ToyRegistry.washID:
            animateWashShelfFace(in: card)
        case ToyRegistry.stackID:
            let stack = descendants(of: card, as: StackPieceNode.self).sorted { $0.position.y < $1.position.y }
            for (index, piece) in stack.enumerated() {
                piece.playTowerPulse(delay: Double(index) * 0.045, isTop: index == stack.count - 1)
            }
        case ToyRegistry.bloomID:
            for bloom in descendants(of: card, as: BloomNode.self) {
                bloom.cheer()
            }
        default:
            break
        }
    }

    private func triggerShelfWakeUp(at point: CGPoint) {
        TouchFeedbackAnimator.tactileSpark(in: self, at: point, color: WarmShelfPalette.sand, count: 8)
        ParticleManager.softRipple(in: self, at: point, color: WarmShelfPalette.sand)

        // After the toys wake, the sleepy host peeks up to share the child's delight, then
        // exhales back to sleep — throttled so it stays a rare, earned little moment.
        run(.sequence([.wait(forDuration: 0.55), .run { [weak self] in self?.peekHost() }]))

        if let card = cardRoot(for: ToyRegistry.bubblesID) {
            for (index, bubble) in descendants(of: card, as: BubbleNode.self).enumerated() {
                let rise = SKAction.moveBy(x: CGFloat.random(in: -4...4), y: CGFloat.random(in: 12...26), duration: 0.34 + Double(index) * 0.015)
                let settle = SKAction.moveBy(x: CGFloat.random(in: -3...3), y: CGFloat.random(in: -8 ... -3), duration: 0.42)
                rise.timingMode = .easeOut
                settle.timingMode = .easeInEaseOut
                bubble.run(.sequence([rise, settle]), withKey: "shelfWake")
            }
        }

        if let card = cardRoot(for: ToyRegistry.clayBlocksID) {
            let blocks = descendants(of: card, as: ClayBlockNode.self)
            for (index, block) in blocks.enumerated() {
                block.applySquishImpact(intensity: index.isMultiple(of: 2) ? 0.55 : 0.38)
                let rotate = SKAction.rotate(byAngle: CGFloat.random(in: -0.10...0.10), duration: 0.12)
                let back = SKAction.rotate(byAngle: CGFloat.random(in: -0.06...0.06), duration: 0.20)
                rotate.timingMode = .easeOut
                back.timingMode = .easeInEaseOut
                block.run(.sequence([rotate, back]), withKey: "shelfWakeRotate")
            }

            blocks.max(by: { $0.position.y < $1.position.y })?.run(.sequence([
                .rotate(byAngle: CGFloat.random(in: 0.16...0.24), duration: 0.22),
                .rotate(byAngle: CGFloat.random(in: -0.10 ... -0.04), duration: 0.32)
            ]), withKey: "shelfWakeTopple")
        }

        if let card = cardRoot(for: ToyRegistry.feedThePeopleID) {
            for (index, person) in descendants(of: card, as: CharacterNode.self).enumerated() {
                person.playFullTableSway(delay: Double(index) * 0.06)
                if index == 0 {
                    person.playFriendshipReaction(force: true)
                }
            }
            descendants(of: card, as: FoodNode.self).first?.run(.sequence([
                .moveBy(x: 0, y: 10, duration: 0.12),
                .moveBy(x: 0, y: -10, duration: 0.22)
            ]), withKey: "shelfWakeFood")
        }

        if let card = cardRoot(for: ToyRegistry.humID) {
            for (index, object) in descendants(of: card, as: HumObjectNode.self).enumerated() {
                object.run(.sequence([
                    .wait(forDuration: Double(index) * 0.04),
                    .run {
                        object.noticeAndHold()
                        object.startShimmer()
                    },
                    .wait(forDuration: 0.54),
                    .run {
                        object.stopShimmer()
                        object.settleHome()
                    }
                ]), withKey: "shelfWakeHum")
            }
        }

        if let card = cardRoot(for: ToyRegistry.softDropID) {
            for piece in descendants(of: card, as: SoftDropPieceNode.self) {
                piece.wake()
            }
        }

        if let card = cardRoot(for: ToyRegistry.stackID) {
            let stack = descendants(of: card, as: StackPieceNode.self).sorted { $0.position.y < $1.position.y }
            for (index, piece) in stack.enumerated() {
                piece.playTowerPulse(delay: Double(index) * 0.05, isTop: index == stack.count - 1)
            }
        }

        if let card = cardRoot(for: ToyRegistry.bloomID) {
            for (index, bloom) in descendants(of: card, as: BloomNode.self).enumerated() {
                bloom.run(.sequence([
                    .wait(forDuration: Double(index) * 0.04),
                    .run { bloom.cheer() }
                ]), withKey: "shelfWakeBloom")
            }
        }
    }

    private func descendants<T: SKNode>(of node: SKNode, as type: T.Type) -> [T] {
        var matches: [T] = []
        for child in node.children {
            if let match = child as? T {
                matches.append(match)
            }
            matches.append(contentsOf: descendants(of: child, as: type))
        }
        return matches
    }

    private func toyID(for nodes: [SKNode]) -> String? {
        for node in nodes {
            var current: SKNode? = node
            while let unwrapped = current {
                if let name = unwrapped.name, name.hasPrefix("toyCard.") {
                    return String(name.dropFirst("toyCard.".count))
                }
                current = unwrapped.parent
            }
        }
        return nil
    }

    private func cardRoot(for nodes: [SKNode]) -> SKNode? {
        for node in nodes {
            var current: SKNode? = node
            while let unwrapped = current {
                if let name = unwrapped.name, name.hasPrefix("toyCard.") {
                    return unwrapped
                }
                current = unwrapped.parent
            }
        }
        return nil
    }

    private func cardRoot(for toyID: String) -> SKNode? {
        contentRoot.childNode(withName: cardName(for: toyID))
    }

    override func accessibilityElements(in view: SKView) -> [UIAccessibilityElement] {
        let shelfToys = ToyRegistry.childShelfToys
        let toyCount = max(1, shelfToys.count)
        let layout = makeShelfLayout(toyCount: toyCount)

        return shelfToys.enumerated().map { index, descriptor in
            return makeActivatableAccessibilityElement(
                in: view,
                label: descriptor.parentName,
                scenePosition: cardPosition(index: index, count: toyCount, layout: layout),
                size: layout.objectSize,
                traits: .button
            ) { [weak self] in
                guard let self, !self.isOpeningToy,
                      ToyRegistry.childShelfToys.contains(where: { $0.id == descriptor.id }),
                      let card = self.cardRoot(for: descriptor.id) else { return }
                self.isOpeningToy = true
                self.resetShelfInvitationClock(delay: 6.0)
                TouchFeedbackAnimator.acknowledge(node: card, profile: .shelfCard)
                self.reactToToyTap(toyID: descriptor.id, card: card)
                HapticsManager.shared.cardPress()
                self.playWakeBloom(card: card, toyID: descriptor.id)
            }
        }
    }
}
