import UIKit
import SpriteKit

/// A small *living* preview of the paid toys, for the parent paywall.
///
/// Instead of a row of static name-chips, a grown-up sees each toy as a gently animated
/// emblem — breathing, swaying, blinking — so the value of the unlock is felt, not just
/// read, before the price. Built entirely from stable shared primitives (`WarmShelfPalette`,
/// `CuteFace`, `AmbientAnimator`) so it never reaches into a toy scene's internals and can't
/// break when those evolve.
final class PaywallPreviewStrip: UIView {
    private let skView = SKView()

    init(toyIDs: [String], height: CGFloat = 150) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: height).isActive = true

        skView.translatesAutoresizingMaskIntoConstraints = false
        skView.backgroundColor = .clear
        skView.allowsTransparency = true
        skView.preferredFramesPerSecond = 30   // calm + battery-kind for a settings screen
        addSubview(skView)
        NSLayoutConstraint.activate([
            skView.topAnchor.constraint(equalTo: topAnchor),
            skView.leadingAnchor.constraint(equalTo: leadingAnchor),
            skView.trailingAnchor.constraint(equalTo: trailingAnchor),
            skView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let scene = PaywallPreviewScene(toyIDs: toyIDs)
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
        skView.presentScene(scene)
    }

    required init?(coder: NSCoder) { nil }
}

private final class PaywallPreviewScene: SKScene {
    private let toyIDs: [String]
    private var lastBuilt = CGSize.zero

    init(toyIDs: [String]) {
        self.toyIDs = toyIDs
        super.init(size: CGSize(width: 320, height: 150))
    }

    required init?(coder: NSCoder) { nil }

    override func didMove(to view: SKView) { rebuild() }
    override func didChangeSize(_ oldSize: CGSize) { rebuild() }

    private func rebuild() {
        guard size.width > 40, size.height > 40,
              abs(size.width - lastBuilt.width) > 1 || abs(size.height - lastBuilt.height) > 1 else { return }
        lastBuilt = size
        removeAllChildren()

        let count = max(1, toyIDs.count)
        let cellW = size.width / CGFloat(count)
        let emblemSize = min(cellW * 0.74, size.height * 0.58)

        for (index, id) in toyIDs.enumerated() {
            let cx = cellW * (CGFloat(index) + 0.5)
            let cell = SKNode()
            cell.position = CGPoint(x: cx, y: size.height * 0.58)
            addChild(cell)

            let tile = roundedTile(side: emblemSize * 1.34, color: accent(for: id))
            cell.addChild(tile)

            let art = emblem(for: id, size: emblemSize)
            art.zPosition = 1
            cell.addChild(art)

            let label = SKLabelNode(text: shortName(for: id))
            label.fontName = "Georgia"
            label.fontSize = max(9, min(12, cellW * 0.165))
            label.fontColor = WarmShelfPalette.paperHighlight.withAlphaComponent(0.88)
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.position = CGPoint(x: cx, y: size.height * 0.13)
            addChild(label)

            // A soft staggered entrance so the strip "wakes up" left to right.
            cell.setScale(0.6)
            cell.alpha = 0
            cell.run(.sequence([
                .wait(forDuration: 0.06 * Double(index)),
                .group([.scale(to: 1, duration: 0.32), .fadeIn(withDuration: 0.32)])
            ]))
        }
    }

    // MARK: - Per-toy emblems (bespoke, charming, self-contained)

    private func emblem(for id: String, size: CGFloat) -> SKNode {
        switch id {
        case ToyRegistry.feedThePeopleID: return feedEmblem(size: size)
        case ToyRegistry.stackID:         return stackEmblem(size: size)
        case ToyRegistry.bloomID:         return bloomEmblem(size: size)
        case ToyRegistry.mixUpID:         return mixUpEmblem(size: size)
        case ToyRegistry.humID:           return humEmblem(size: size)
        default:                          return genericEmblem(size: size, color: accent(for: id))
        }
    }

    /// A happy little eater.
    private func feedEmblem(size: CGFloat) -> SKNode {
        let n = SKNode()
        let r = size * 0.42
        let head = SKShapeNode(circleOfRadius: r)
        head.fillColor = WarmShelfPalette.petal
        head.strokeColor = WarmShelfPalette.cocoa.withAlphaComponent(0.05)
        head.lineWidth = 1
        n.addChild(head)
        CuteFace.cheeks(on: n, s: 1, spacing: r * 0.72, y: -r * 0.16, r: r * 0.15)
        CuteFace.eyes(on: n, s: 1, spacing: r * 0.42, y: r * 0.12, r: r * 0.17, style: .round)
        CuteFace.mouth(on: n, s: 1, width: r * 0.34, y: -r * 0.30, style: .openSmile)
        AmbientAnimator.breathe(node: n, scale: 1.05, duration: 2.6)
        n.run(.repeatForever(.sequence([
            .wait(forDuration: 2.0),
            .moveBy(x: 0, y: r * 0.12, duration: 0.16), .moveBy(x: 0, y: -r * 0.12, duration: 0.24)
        ])))
        return n
    }

    /// Three soft stones; the top one is awake and smiling.
    private func stackEmblem(size: CGFloat) -> SKNode {
        let n = SKNode()
        let colors = [WarmShelfPalette.terracotta, WarmShelfPalette.sand, WarmShelfPalette.butter]
        let widths: [CGFloat] = [0.62, 0.50, 0.40]
        let h = size * 0.20
        var y = -size * 0.32
        var stones: [SKShapeNode] = []
        for i in 0..<3 {
            let stone = SKShapeNode(rectOf: CGSize(width: size * widths[i], height: h), cornerRadius: h * 0.46)
            stone.fillColor = colors[i].withAlphaComponent(0.96)
            stone.strokeColor = WarmShelfPalette.cocoa.withAlphaComponent(0.05)
            stone.lineWidth = 1
            stone.position = CGPoint(x: CGFloat(i - 1) * size * 0.02, y: y)
            n.addChild(stone)
            stones.append(stone)
            y += h * 0.94
        }
        if let top = stones.last {
            CuteFace.eyes(on: top, s: 1, spacing: size * 0.075, y: size * 0.0, r: size * 0.035, style: .round)
            CuteFace.mouth(on: top, s: 1, width: size * 0.06, y: -size * 0.05, style: .smile)
            top.run(.repeatForever(.sequence([
                .wait(forDuration: 2.4),
                .scale(to: 1.06, duration: 0.2), .scale(to: 1.0, duration: 0.28)
            ])))
        }
        AmbientAnimator.breathe(node: n, scale: 1.03, duration: 3.0)
        return n
    }

    /// A flower that nods in a breeze.
    private func bloomEmblem(size: CGFloat) -> SKNode {
        let n = SKNode()
        let stem = SKShapeNode(rect: CGRect(x: -size * 0.03, y: -size * 0.40, width: size * 0.06, height: size * 0.52), cornerRadius: size * 0.03)
        stem.fillColor = WarmShelfPalette.sage
        stem.strokeColor = .clear
        n.addChild(stem)
        let leaf = SKShapeNode(ellipseOf: CGSize(width: size * 0.24, height: size * 0.12))
        leaf.fillColor = WarmShelfPalette.sage.withAlphaComponent(0.9)
        leaf.strokeColor = .clear
        leaf.position = CGPoint(x: size * 0.13, y: -size * 0.14)
        leaf.zRotation = -0.5
        n.addChild(leaf)

        let head = SKNode()
        head.position = CGPoint(x: 0, y: size * 0.14)
        for i in 0..<6 {
            let a = CGFloat(i) / 6 * .pi * 2
            let petal = SKShapeNode(ellipseOf: CGSize(width: size * 0.16, height: size * 0.27))
            petal.fillColor = WarmShelfPalette.petal
            petal.strokeColor = .clear
            petal.position = CGPoint(x: cos(a) * size * 0.16, y: sin(a) * size * 0.16)
            petal.zRotation = a + .pi / 2
            head.addChild(petal)
        }
        let center = SKShapeNode(circleOfRadius: size * 0.10)
        center.fillColor = WarmShelfPalette.butter
        center.strokeColor = .clear
        head.addChild(center)
        n.addChild(head)

        let nod = SKAction.sequence([
            .rotate(toAngle: 0.12, duration: 1.6), .rotate(toAngle: -0.12, duration: 1.6)
        ])
        nod.timingMode = .easeInEaseOut
        head.run(.repeatForever(nod))
        AmbientAnimator.breathe(node: head, scale: 1.04, duration: 2.4)
        return n
    }

    /// A little friend wearing a mismatched outfit, bobbing happily.
    private func mixUpEmblem(size: CGFloat) -> SKNode {
        let n = SKNode()
        for sign in [CGFloat(-1), CGFloat(1)] {
            let leg = SKShapeNode(rect: CGRect(x: sign * size * 0.12 - size * 0.04, y: -size * 0.44, width: size * 0.08, height: size * 0.16), cornerRadius: size * 0.04)
            leg.fillColor = WarmShelfPalette.cocoa.withAlphaComponent(0.55)
            leg.strokeColor = .clear
            n.addChild(leg)
        }
        let body = SKShapeNode(rect: CGRect(x: -size * 0.20, y: -size * 0.32, width: size * 0.40, height: size * 0.40), cornerRadius: size * 0.14)
        body.fillColor = WarmShelfPalette.lavender
        body.strokeColor = .clear
        n.addChild(body)
        let star = SKShapeNode(path: starPath(r: size * 0.10))
        star.fillColor = WarmShelfPalette.butter
        star.strokeColor = .clear
        star.position = CGPoint(x: 0, y: -size * 0.10)
        n.addChild(star)

        let head = SKShapeNode(circleOfRadius: size * 0.24)
        head.fillColor = WarmShelfPalette.sand
        head.strokeColor = .clear
        head.position = CGPoint(x: 0, y: size * 0.18)
        n.addChild(head)
        let r = size * 0.24
        CuteFace.eyes(on: head, s: 1, spacing: r * 0.5, y: r * 0.1, r: r * 0.18, style: .round)
        CuteFace.mouth(on: head, s: 1, width: r * 0.4, y: -r * 0.32, style: .smile)

        let wiggle = SKAction.sequence([
            .wait(forDuration: 1.4),
            .rotate(toAngle: 0.07, duration: 0.5), .rotate(toAngle: -0.07, duration: 0.6), .rotate(toAngle: 0, duration: 0.4)
        ])
        n.run(.repeatForever(wiggle))
        AmbientAnimator.breathe(node: head, scale: 1.06, duration: 2.0)
        return n
    }

    /// Four sleepy clay singers, quietly humming as a group.
    private func humEmblem(size: CGFloat) -> SKNode {
        let n = SKNode()
        let specs: [(UIColor, CGSize, CGPoint, CGFloat)] = [
            (WarmShelfPalette.terracotta, CGSize(width: size * 0.34, height: size * 0.29), CGPoint(x: -size * 0.20, y: -size * 0.10), -0.08),
            (WarmShelfPalette.waterBlue, CGSize(width: size * 0.20, height: size * 0.46), CGPoint(x: size * 0.10, y: -size * 0.02), 0.05),
            (WarmShelfPalette.sage, CGSize(width: size * 0.39, height: size * 0.17), CGPoint(x: -size * 0.02, y: size * 0.16), -0.03),
            (WarmShelfPalette.butter, CGSize(width: size * 0.19, height: size * 0.16), CGPoint(x: size * 0.26, y: size * 0.15), 0.16)
        ]
        for (index, spec) in specs.enumerated() {
            let singer = SKNode()
            singer.position = spec.2
            singer.zRotation = spec.3
            let body = SKShapeNode(ellipseOf: spec.1)
            body.fillColor = spec.0.withAlphaComponent(0.92)
            body.strokeColor = WarmShelfPalette.cocoa.withAlphaComponent(0.06)
            body.lineWidth = 1
            singer.addChild(body)

            for x in [-spec.1.width * 0.12, spec.1.width * 0.12] {
                let eyePath = CGMutablePath()
                eyePath.move(to: CGPoint(x: -3.2, y: 0))
                eyePath.addQuadCurve(to: CGPoint(x: 3.2, y: 0), control: CGPoint(x: 0, y: -2.4))
                let eye = SKShapeNode(path: eyePath)
                eye.strokeColor = WarmShelfPalette.cocoa.withAlphaComponent(0.42)
                eye.lineWidth = 1.2
                eye.lineCap = .round
                eye.position = CGPoint(x: x, y: spec.1.height * 0.06)
                singer.addChild(eye)
            }

            n.addChild(singer)
            let delay = Double(index) * 0.18
            singer.run(.repeatForever(.sequence([
                .wait(forDuration: delay),
                .scale(to: 1.04, duration: 0.72),
                .scale(to: 1.0, duration: 0.9),
                .wait(forDuration: 1.4)
            ])))
        }
        return n
    }

    private func genericEmblem(size: CGFloat, color: UIColor) -> SKNode {
        let n = SKNode()
        let blob = SKShapeNode(circleOfRadius: size * 0.4)
        blob.fillColor = color
        blob.strokeColor = .clear
        n.addChild(blob)
        AmbientAnimator.breathe(node: n, scale: 1.05, duration: 2.6)
        return n
    }

    // MARK: - Helpers

    private func roundedTile(side: CGFloat, color: UIColor) -> SKShapeNode {
        let tile = SKShapeNode(rectOf: CGSize(width: side, height: side), cornerRadius: side * 0.26)
        tile.fillColor = WarmShelfPalette.warmCream.withAlphaComponent(0.14)
        tile.strokeColor = color.withAlphaComponent(0.5)
        tile.lineWidth = 1.5
        tile.zPosition = 0
        return tile
    }

    private func accent(for id: String) -> UIColor {
        ToyRegistry.toy(id: id)?.accentColor ?? WarmShelfPalette.sand
    }

    private func shortName(for id: String) -> String {
        switch id {
        case ToyRegistry.feedThePeopleID: return "Feed"
        case ToyRegistry.mixUpID:         return "Mix-Up"
        default:                          return ToyRegistry.toy(id: id)?.parentName ?? ""
        }
    }

    private func starPath(r: CGFloat) -> CGPath {
        let p = CGMutablePath()
        for i in 0..<10 {
            let angle = CGFloat(i) / 10 * .pi * 2 - .pi / 2
            let rad = i.isMultiple(of: 2) ? r : r * 0.45
            let pt = CGPoint(x: cos(angle) * rad, y: sin(angle) * rad)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}
