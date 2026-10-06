import SpriteKit

final class LeafNode: SKNode {

    // MARK: - Grid position

    var gridX: Int = 0
    var gridY: Int = 0

    // MARK: - Home Y (scene-space, set when spawned)

    var homeY: CGFloat = 0

    // MARK: - Init

    init(at position: CGPoint) {
        super.init()

        self.position = position
        self.homeY = position.y

        buildLeaf()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        buildLeaf()
    }

    // MARK: - Build

    private func buildLeaf() {
        // Oval body: 28×16pt, sage fill
        let ovalPath = CGMutablePath()
        let halfW: CGFloat = 14
        let halfH: CGFloat = 8
        ovalPath.addEllipse(in: CGRect(x: -halfW, y: -halfH, width: halfW * 2, height: halfH * 2))

        let body = SKShapeNode(path: ovalPath)
        body.fillColor = SKColor(red: 0.62, green: 0.75, blue: 0.60, alpha: 1.0)  // #9EC098
        body.strokeColor = SKColor(red: 0.50, green: 0.62, blue: 0.48, alpha: 0.5)
        body.lineWidth = 0.8
        body.zPosition = 1
        addChild(body)

        // Cream highlight: small inner oval at 12% alpha
        let highlightPath = CGMutablePath()
        highlightPath.addEllipse(in: CGRect(x: -halfW * 0.5 + 1, y: -halfH * 0.45 - 1,
                                             width: halfW * 0.7, height: halfH * 0.55))
        let highlight = SKShapeNode(path: highlightPath)
        highlight.fillColor = SKColor(red: 0.98, green: 0.95, blue: 0.88, alpha: 0.12)
        highlight.strokeColor = .clear
        highlight.zPosition = 2
        addChild(highlight)

        // Subtle midrib line
        let ribPath = CGMutablePath()
        ribPath.move(to: CGPoint(x: -halfW + 2, y: 0))
        ribPath.addLine(to: CGPoint(x: halfW - 2, y: 0))
        let rib = SKShapeNode(path: ribPath)
        rib.strokeColor = SKColor(red: 0.50, green: 0.62, blue: 0.48, alpha: 0.25)
        rib.lineWidth = 0.7
        rib.lineCap = .round
        rib.zPosition = 3
        addChild(rib)

        // Slight random rotation so leaves look naturally placed
        zRotation = CGFloat.random(in: -.pi ... .pi)
    }
}
