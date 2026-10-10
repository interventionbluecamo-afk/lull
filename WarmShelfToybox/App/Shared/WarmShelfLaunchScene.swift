import SpriteKit
import UIKit

final class WarmShelfLaunchScene: SKScene {
    var onComplete: (() -> Void)?

    private var hasStarted = false

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = WarmShelfPalette.linen
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        scaleMode = .resizeFill
        backgroundColor = WarmShelfPalette.linen
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        guard !hasStarted else { return }
        hasStarted = true
        buildPaper()
        runOpeningMoment()
    }

    private func buildPaper() {
        let count = Int(max(20, min(70, (size.width * size.height) / 20_000)))
        for _ in 0..<count {
            let dot = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.6...2.2))
            dot.fillColor = WarmShelfPalette.sand.withAlpha(.random(in: 0.06...0.14))
            dot.strokeColor = .clear
            dot.position = CGPoint(x: .random(in: 0...size.width), y: .random(in: 0...size.height))
            dot.zPosition = -1
            addChild(dot)
        }
    }

    private func runOpeningMoment() {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let shelfY = center.y - size.height * 0.02
        let shelfWidth = min(size.width * 0.62, 420)
        let isPhone = min(size.width, size.height) < 600

        let bloom = SKShapeNode(circleOfRadius: min(size.width, size.height) * 0.20)
        bloom.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.13)
        bloom.strokeColor = .clear
        bloom.position = CGPoint(x: center.x, y: shelfY + size.height * 0.04)
        bloom.alpha = 0
        bloom.zPosition = -0.5
        addChild(bloom)
        bloom.run(.group([
            .fadeAlpha(to: 1, duration: 0.66),
            .scale(to: 1.18, duration: 1.20)
        ]))

        // The shelf plank settles in first — this is Lull's signature object.
        let shelf = makeShelfPlank(width: shelfWidth, isPhone: isPhone)
        shelf.position = CGPoint(x: center.x, y: shelfY - 34)
        shelf.alpha = 0
        shelf.zPosition = 5
        addChild(shelf)

        let slideUp = SKAction.moveTo(y: shelfY, duration: 0.50)
        slideUp.timingMode = .easeOut
        let overshoot = SKAction.sequence([
            .moveBy(x: 0, y: 5, duration: 0.16),
            .moveBy(x: 0, y: -5, duration: 0.22)
        ])
        overshoot.timingMode = .easeInEaseOut
        shelf.run(.group([
            .fadeIn(withDuration: 0.30),
            .sequence([slideUp, overshoot])
        ]))

        // The free child shelf is the promise: bubbles frame the signature Stack friend.
        // One visual hero is more memorable than three equal app-menu icons.
        let icons = [
            makeBubbleIcon(
                bodyColor: WarmShelfPalette.waterBlue,
                rimColor: WarmShelfPalette.bubbleRim,
                radiusScale: 1.0
            ),
            makeWashIcon(),
            makeBubbleIcon(
                bodyColor: WarmShelfPalette.blushIridescence,
                rimColor: WarmShelfPalette.lavender,
                radiusScale: 0.82
            )
        ]
        let spacing = min(shelfWidth * 0.30, 96)
        let totalWidth = spacing * CGFloat(icons.count - 1)
        let restY = shelfY + (isPhone ? 22 : 28)

        for (index, icon) in icons.enumerated() {
            let x = center.x - totalWidth / 2 + CGFloat(index) * spacing
            icon.position = CGPoint(x: x, y: restY + 56)
            icon.alpha = 0
            icon.setScale(1.18)
            icon.zPosition = 8
            addChild(icon)

            let drop = SKAction.moveTo(y: restY, duration: 0.34)
            drop.timingMode = .easeIn
            let squash = SKAction.sequence([
                .scaleX(to: 1.30, y: 0.84, duration: 0.10),
                .scale(to: 1.22, duration: 0.18)
            ])
            squash.timingMode = .easeOut
            icon.run(.sequence([
                .wait(forDuration: 0.40 + Double(index) * 0.12),
                .group([.fadeIn(withDuration: 0.20), drop]),
                squash,
                .run { [weak self] in
                    guard let self else { return }
                    self.landingPuff(at: CGPoint(x: x, y: restY - (isPhone ? 14 : 18)))
                }
            ]))
        }

        for index in 0..<7 {
            let mote = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.5...3.0))
            mote.fillColor = (index.isMultiple(of: 2) ? WarmShelfPalette.sand : WarmShelfPalette.butter)
                .withAlpha(CGFloat.random(in: 0.14...0.24))
            mote.strokeColor = .clear
            mote.position = CGPoint(
                x: center.x + CGFloat.random(in: -totalWidth * 0.76...totalWidth * 0.76),
                y: restY + CGFloat.random(in: -10...44)
            )
            mote.alpha = 0
            mote.zPosition = 2
            addChild(mote)

            let drift = SKAction.moveBy(
                x: CGFloat.random(in: -16...16),
                y: CGFloat.random(in: 18...44),
                duration: 1.0
            )
            drift.timingMode = .easeOut
            mote.run(.sequence([
                .wait(forDuration: 0.40 + Double(index) * 0.06),
                .group([.fadeAlpha(to: 0.7, duration: 0.26), drift]),
                .fadeOut(withDuration: 0.30),
                .removeFromParent()
            ]))
        }

        run(.sequence([
            .wait(forDuration: 1.46),
            .fadeOut(withDuration: 0.26),
            .run { [weak self] in self?.onComplete?() }
        ]))
    }

    private func makeShelfPlank(width: CGFloat, isPhone: Bool) -> SKNode {
        let root = SKNode()
        let plankHeight: CGFloat = isPhone ? 22 : 28
        let radius: CGFloat = isPhone ? 11 : 14

        let shadow = makeRoundedRect(
            width: width * 0.94,
            height: isPhone ? 30 : 38,
            radius: isPhone ? 15 : 19,
            fill: WarmShelfPalette.raisin.withAlpha(0.085)
        )
        shadow.position = CGPoint(x: 0, y: isPhone ? -13 : -16)
        shadow.zPosition = 0
        root.addChild(shadow)

        let plank = makeRoundedRect(width: width, height: plankHeight, radius: radius, fill: WarmShelfPalette.sand.withAlpha(0.70))
        plank.zPosition = 1
        root.addChild(plank)

        let edge = makeRoundedRect(
            width: width * 0.98,
            height: isPhone ? 6 : 8,
            radius: isPhone ? 3 : 4,
            fill: WarmShelfPalette.cocoa.withAlpha(0.13)
        )
        edge.position = CGPoint(x: 0, y: isPhone ? -12 : -16)
        edge.zPosition = 2
        root.addChild(edge)

        let highlight = makeRoundedRect(
            width: width * 0.88,
            height: 4,
            radius: 2,
            fill: WarmShelfPalette.paperHighlight.withAlpha(0.52)
        )
        highlight.position = CGPoint(x: 0, y: isPhone ? 7 : 9)
        highlight.zPosition = 3
        root.addChild(highlight)

        return root
    }

    private func landingPuff(at point: CGPoint) {
        let puff = SKShapeNode(ellipseOf: CGSize(width: 30, height: 8))
        puff.fillColor = WarmShelfPalette.sand.withAlpha(0.0)
        puff.strokeColor = WarmShelfPalette.paperHighlight.withAlpha(0.34)
        puff.lineWidth = 1.4
        puff.position = point
        puff.zPosition = 6
        addChild(puff)
        puff.run(.sequence([
            .group([
                .scale(to: 1.9, duration: 0.34),
                .fadeOut(withDuration: 0.34)
            ]),
            .removeFromParent()
        ]))
    }

    private func makeBubbleIcon(bodyColor: UIColor, rimColor: UIColor, radiusScale: CGFloat) -> SKNode {
        let root = SKNode()
        let radius = min(22, size.width * 0.048) * radiusScale

        let bubble = SKShapeNode(circleOfRadius: radius)
        bubble.fillColor = bodyColor.withAlpha(0.42)
        bubble.strokeColor = rimColor.withAlpha(0.50)
        bubble.lineWidth = 1.3
        root.addChild(bubble)

        let shine = SKShapeNode(circleOfRadius: radius * 0.28)
        shine.fillColor = WarmShelfPalette.bubbleHighlight.withAlpha(0.66)
        shine.strokeColor = .clear
        shine.position = CGPoint(x: -radius * 0.32, y: radius * 0.30)
        root.addChild(shine)

        return root
    }

    private func makeFeedIcon() -> SKNode {
        let root = SKNode()
        let radius = min(18, size.width * 0.038)

        let body = makeRoundedRect(
            width: radius * 1.65,
            height: radius * 1.12,
            radius: 5,
            fill: WarmShelfPalette.sage.withAlpha(0.72)
        )
        body.position = CGPoint(x: 0, y: -radius * 0.72)
        root.addChild(body)

        let head = SKShapeNode(circleOfRadius: radius)
        head.fillColor = WarmShelfPalette.petal.withAlpha(0.88)
        head.strokeColor = WarmShelfPalette.clayInk.withAlpha(0.05)
        head.lineWidth = 1
        head.position = CGPoint(x: 0, y: radius * 0.45)
        root.addChild(head)

        let hair = SKShapeNode(ellipseOf: CGSize(width: radius * 1.25, height: radius * 0.58))
        hair.fillColor = WarmShelfPalette.cocoa.withAlpha(0.42)
        hair.strokeColor = .clear
        hair.position = CGPoint(x: -radius * 0.05, y: radius * 1.06)
        hair.zPosition = 2
        root.addChild(hair)

        for x in [-0.32, 0.32] {
            let eye = SKShapeNode(circleOfRadius: max(1.4, radius * 0.08))
            eye.fillColor = WarmShelfPalette.clayInk.withAlpha(0.70)
            eye.strokeColor = .clear
            eye.position = CGPoint(x: radius * CGFloat(x), y: radius * 0.52)
            eye.zPosition = 3
            root.addChild(eye)
        }

        let apron = makeRoundedRect(
            width: radius * 0.88,
            height: radius * 0.64,
            radius: 3,
            fill: WarmShelfPalette.paperHighlight.withAlpha(0.46)
        )
        apron.position = CGPoint(x: 0, y: -radius * 0.76)
        apron.zPosition = 2
        root.addChild(apron)

        let apple = SKShapeNode(circleOfRadius: radius * 0.22)
        apple.fillColor = WarmShelfPalette.terracotta.withAlpha(0.90)
        apple.strokeColor = .clear
        apple.position = CGPoint(x: radius * 1.02, y: -radius * 0.18)
        apple.zPosition = 3
        root.addChild(apple)

        AmbientAnimator.idleDrift(node: root, x: 0, y: 3, duration: 2.0, delay: 0)
        return root
    }

    private func makeWashIcon() -> SKNode {
        let root = SKNode()
        if let truck = ToyArt.sprite("wash-fire-truck", fit: CGSize(width: 82, height: 58)) {
            truck.position = CGPoint(x: 0, y: 8)
            root.addChild(truck)
        } else {
            let body = makeRoundedRect(width: 74, height: 37, radius: 11,
                                       fill: WarmShelfPalette.terracotta)
            body.position.y = 11
            root.addChild(body)
            let window = makeRoundedRect(width: 22, height: 19, radius: 7,
                                         fill: WarmShelfPalette.warmCream)
            window.position = CGPoint(x: 17, y: 15)
            root.addChild(window)
            for x in [CGFloat(-23), CGFloat(23)] {
                let wheel = SKShapeNode(circleOfRadius: 8)
                wheel.fillColor = WarmShelfPalette.cocoa
                wheel.strokeColor = .clear
                wheel.position = CGPoint(x: x, y: -6)
                root.addChild(wheel)
            }
            for x in [CGFloat(12), CGFloat(21)] {
                let eye = SKShapeNode(circleOfRadius: 1.8)
                eye.fillColor = WarmShelfPalette.cocoa
                eye.strokeColor = .clear
                eye.position = CGPoint(x: x, y: 17)
                root.addChild(eye)
            }
        }
        return root
    }

    private func makeRoundedRect(width: CGFloat, height: CGFloat, radius: CGFloat, fill: UIColor) -> SKShapeNode {
        let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
        let node = SKShapeNode(rect: rect, cornerRadius: radius)
        node.fillColor = fill
        node.strokeColor = .clear
        return node
    }
}
