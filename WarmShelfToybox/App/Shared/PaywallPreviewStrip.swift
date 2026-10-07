import UIKit
import SpriteKit

/// A small *living* preview of the paid toys, for the parent offer.
///
/// Each toy appears as the same felt object the child sees on the shelf (`shelf-<toy>-v2`),
/// breathing and taking a small turn to say hello, so a grown-up recognizes the toybox
/// before the price. One row on wide screens; two rows of three on phones, where six in a
/// row would shrink each toy to a thumbnail.
final class PaywallPreviewStrip: UIView {
    private let skView = SKView()
    private let toyCount: Int
    private var heightConstraint: NSLayoutConstraint!

    static let rowHeight: CGFloat = 104
    static let minimumCellWidth: CGFloat = 76

    init(toyIDs: [String]) {
        toyCount = max(1, toyIDs.count)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightConstraint = heightAnchor.constraint(equalToConstant: Self.rowHeight + 18)
        heightConstraint.isActive = true

        isAccessibilityElement = true
        accessibilityLabel = "Included in the full toybox: "
            + toyIDs.compactMap { ToyRegistry.toy(id: $0)?.parentName }.joined(separator: ", ")

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

    static func columns(for width: CGFloat, count: Int) -> Int {
        width / CGFloat(count) >= minimumCellWidth ? count : Int((Double(count) / 2).rounded(.up))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 else { return }
        let columns = Self.columns(for: bounds.width, count: toyCount)
        let rows = Int((Double(toyCount) / Double(columns)).rounded(.up))
        let wanted = CGFloat(rows) * Self.rowHeight + 18
        if abs(heightConstraint.constant - wanted) > 0.5 {
            heightConstraint.constant = wanted
        }
    }
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
        let columns = PaywallPreviewStrip.columns(for: size.width, count: count)
        let rows = Int((Double(count) / Double(columns)).rounded(.up))
        let cellW = size.width / CGFloat(columns)
        let cellH = (size.height - 8) / CGFloat(rows)
        let artFit = CGSize(width: min(cellW * 0.82, 104), height: cellH * 0.66)

        for (index, id) in toyIDs.enumerated() {
            let column = index % columns
            let row = index / columns
            let cx = cellW * (CGFloat(column) + 0.5)
            let cellBottom = size.height - CGFloat(row + 1) * cellH
            let labelY = cellBottom + cellH * 0.10
            let floorY = cellBottom + cellH * 0.25

            let cell = SKNode()
            cell.position = CGPoint(x: cx, y: floorY)
            addChild(cell)

            let shadow = SKSpriteNode(texture: ProceduralTexture.softClayShadow(
                size: CGSize(width: artFit.width * 0.7, height: max(8, artFit.height * 0.14))))
            shadow.alpha = 0.55
            shadow.zPosition = -1
            cell.addChild(shadow)

            if let art = toyArt(for: id, fit: artFit) {
                // Bottom-aligned, so every toy stands on the same quiet line.
                art.anchorPoint = CGPoint(x: 0.5, y: 0)
                art.position = CGPoint(x: 0, y: -artFit.height * 0.04)
                cell.addChild(art)
                AmbientAnimator.breathe(node: art, scale: 1.03, duration: 3.6, delay: 0.25 * Double(index))
                // A small hello, one toy at a time, so the strip feels awake without jitter.
                let hello = SKAction.sequence([
                    .wait(forDuration: 2.6 + 0.9 * Double(index)),
                    .rotate(toAngle: 0.05, duration: 0.22),
                    .rotate(toAngle: -0.035, duration: 0.26),
                    .rotate(toAngle: 0, duration: 0.24),
                    .wait(forDuration: 0.9 * Double(count))
                ])
                if !UIAccessibility.isReduceMotionEnabled, !LullDemoState.shared.isReducedMotion {
                    art.run(.repeatForever(hello))
                }
            } else {
                let blob = SKShapeNode(circleOfRadius: min(artFit.width, artFit.height) * 0.36)
                blob.fillColor = ToyRegistry.toy(id: id)?.accentColor ?? WarmShelfPalette.sand
                blob.strokeColor = .clear
                blob.position = CGPoint(x: 0, y: artFit.height * 0.38)
                cell.addChild(blob)
            }

            let label = SKLabelNode(text: shortName(for: id))
            label.fontName = "Georgia"
            label.fontSize = max(10, min(13, cellW * 0.15))
            label.fontColor = WarmShelfPalette.paperHighlight.withAlphaComponent(0.88)
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.position = CGPoint(x: cx, y: labelY)
            addChild(label)

            // A soft staggered entrance so the strip "wakes up" left to right.
            cell.setScale(0.8)
            cell.alpha = 0
            cell.run(.sequence([
                .wait(forDuration: 0.06 * Double(index)),
                .group([.scale(to: 1, duration: 0.32), .fadeIn(withDuration: 0.32)])
            ]))
        }
    }

    private func toyArt(for id: String, fit: CGSize) -> SKSpriteNode? {
        guard let slot = ToyShelfScene.shelfObjectSlot(for: id) else { return nil }
        return ToyShelfScene.shelfObjectArt(slot: slot, fit: fit)
    }

    private func shortName(for id: String) -> String {
        switch id {
        case ToyRegistry.feedThePeopleID: return "Feed"
        case ToyRegistry.mixUpID:         return "Mix-Up"
        default:                          return ToyRegistry.toy(id: id)?.parentName ?? ""
        }
    }
}
