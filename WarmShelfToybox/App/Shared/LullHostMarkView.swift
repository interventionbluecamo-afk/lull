import UIKit
import SpriteKit

/// A small live "mark" of the capstone host — the app-icon character, *alive* and breathing —
/// for onboarding and parent areas. Tap it for a gentle wake. Reuses `LullHostNode` so the
/// soul looks identical everywhere. See `Docs/AlivenessPrinciples.md`.
final class LullHostMarkView: UIView {
    private let skView = SKView()
    private var host: LullHostNode?
    private var pauseWorkItem: DispatchWorkItem?

    private var isReduceMotionEnabled: Bool {
        UIAccessibility.isReduceMotionEnabled || LullDemoState.shared.isReducedMotion
    }

    /// - Parameters:
    ///   - side: square size in points.
    ///   - showsTile: warm rounded backdrop, so it reads as "the app icon, but living."
    init(side: CGFloat, showsTile: Bool = true) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: side),
            heightAnchor.constraint(equalToConstant: side)
        ])

        skView.translatesAutoresizingMaskIntoConstraints = false
        skView.backgroundColor = .clear
        skView.allowsTransparency = true
        skView.preferredFramesPerSecond = 30
        addSubview(skView)
        NSLayoutConstraint.activate([
            skView.topAnchor.constraint(equalTo: topAnchor),
            skView.leadingAnchor.constraint(equalTo: leadingAnchor),
            skView.trailingAnchor.constraint(equalTo: trailingAnchor),
            skView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let scene = SKScene(size: CGSize(width: side, height: side))
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear

        if showsTile {
            let tile = SKShapeNode(rectOf: CGSize(width: side * 0.96, height: side * 0.96), cornerRadius: side * 0.24)
            tile.fillColor = WarmShelfPalette.paperHighlight
            tile.strokeColor = WarmShelfPalette.sand.withAlpha(0.4)
            tile.lineWidth = 1.5
            tile.position = CGPoint(x: side / 2, y: side / 2)
            tile.zPosition = -2
            scene.addChild(tile)

            let glow = SKShapeNode(ellipseOf: CGSize(width: side * 0.74, height: side * 0.66))
            glow.fillColor = WarmShelfPalette.butter.withAlpha(0.26)
            glow.strokeColor = .clear
            glow.position = CGPoint(x: side / 2, y: side * 0.5)
            glow.zPosition = -1
            scene.addChild(glow)
        }

        let host = LullHostNode(scale: side / 210)
        host.position = CGPoint(x: side / 2, y: side * 0.46)
        host.rest()
        scene.addChild(host)
        self.host = host

        skView.presentScene(scene)

        // Respect Reduce Motion: render one resting frame then hold still.
        // Use async (not asyncAfter) so the scene is fully presented before pausing —
        // avoiding a race where a rapid first tap un-pauses before the initial pause fires.
        if isReduceMotionEnabled {
            DispatchQueue.main.async { [weak self] in self?.skView.isPaused = true }
        }

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
        isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) { nil }

    @objc private func handleTap() {
        // Cancel any pending re-pause so rapid taps don't freeze mid-animation.
        pauseWorkItem?.cancel()
        skView.isPaused = false
        host?.tapped()

        guard isReduceMotionEnabled else { return }
        // Re-pause after the full tapped() sequence completes:
        // notice(0.20s) + respond(0.75s) + settle(~0.95s) ≈ 2.7s; add margin.
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.isReduceMotionEnabled else { return }
            self.skView.isPaused = true
        }
        pauseWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8, execute: item)
    }
}
