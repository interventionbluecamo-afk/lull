#if DEBUG
import SpriteKit
import UIKit

/// A developer-only preview (LULL_DEBUG_TOY=host) for reviewing Wren's clay character: a hero
/// that cycles expressions and poses, plus an expression sheet of all five states. Never shipped.
final class HostPreviewViewController: UIViewController {
    override func loadView() {
        let skView = SKView()
        skView.ignoresSiblingOrder = true
        skView.backgroundColor = WarmShelfPalette.linen
        view = skView
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let skView = view as? SKView, skView.scene == nil, skView.bounds.width > 10 else { return }
        let scene = HostPreviewScene(size: skView.bounds.size)
        scene.scaleMode = .resizeFill
        skView.presentScene(scene)
    }
    override var prefersStatusBarHidden: Bool { true }
}

final class HostPreviewScene: SKScene {
    override func didMove(to view: SKView) {
        backgroundColor = WarmShelfPalette.linen

        let hero = LullHostNode(scale: 1.7)
        hero.position = CGPoint(x: size.width / 2, y: size.height * 0.74)
        addChild(hero)
        hero.setExpression(.smile, animated: false)
        hero.startIdleBlink()
        cycleHero(hero)

        let specs: [(LullHostNode.Expression, String)] = [
            (.neutral, "neutral"), (.smile, "smile"), (.laugh, "laugh"),
            (.sleepy, "sleepy"), (.surprised, "surprised")
        ]
        let cols = 3
        let cellW = size.width / CGFloat(cols)
        let rowY: [CGFloat] = [size.height * 0.42, size.height * 0.18]
        for (index, spec) in specs.enumerated() {
            let row = index / cols, col = index % cols
            let countInRow = min(cols, specs.count - row * cols)
            let startX = size.width / 2 - CGFloat(countInRow - 1) * cellW / 2
            let friend = LullHostNode(scale: 0.72)
            friend.position = CGPoint(x: startX + CGFloat(col) * cellW, y: rowY[min(row, rowY.count - 1)])
            addChild(friend)
            friend.setExpression(spec.0, animated: false)
            if spec.0 != .sleepy { friend.startIdleBlink() }

            let label = SKLabelNode(text: spec.1)
            label.fontName = "AvenirNext-Medium"
            label.fontSize = 13
            label.fontColor = WarmShelfPalette.cocoa
            label.position = CGPoint(x: friend.position.x, y: friend.position.y - 66)
            addChild(label)
        }
    }

    private func cycleHero(_ hero: LullHostNode) {
        run(.repeatForever(.sequence([
            .wait(forDuration: 1.8), .run { hero.setExpression(.laugh) },
            .wait(forDuration: 1.8), .run { hero.setExpression(.surprised) },
            .wait(forDuration: 1.8), .run { hero.setLifted(true) },
            .wait(forDuration: 1.2), .run { hero.setLifted(false); hero.setExpression(.sleepy) },
            .wait(forDuration: 1.8), .run { hero.setExpression(.smile) }
        ])))
    }
}
#endif
