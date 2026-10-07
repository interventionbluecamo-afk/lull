import SpriteKit
import QuartzCore

/// Drop Dots — a big, warm wooden gravity toy. A toddler grabs a chunky clay token from the tray,
/// drops it into one of five fat column mouths, and watches it fall and stack. When three of a kind
/// line up the board quietly glows; pull the chunky tab and every token tumbles out so you can do it
/// all again. No score, no winning, no opponent — just "put the big dot in, it fell, I made
/// something, again." All motion is authored (no physics), so tokens land in exact, tidy slots.
final class DropDotsScene: BaseToyScene {

    override var firstSessionHintKey: String? { "hint.dropDots" }
    override func firstSessionHintPoint() -> CGPoint { traySlots.first ?? CGPoint(x: size.width / 2, y: size.height * 0.18) }

    // MARK: - Token

    final class DropDotToken: SKNode {
        /// The five felt colours of the board's mouths, lit-side tones. A dot belongs
        /// to the same rainbow as the rings (founder: "why are the dots different from
        /// the hole colours?" — no reason; now they aren't). Colour is an AFFORDANCE,
        /// never a rule: any dot still drops anywhere; matching is discovered, not asked.
        // Lifted ~14% above the rings' lit tones: the cream puck's colorBlend is a
        // multiply, so these land ON the ring colors after the texture takes its cut.
        static let felts: [UIColor] = [
            UIColor(hex: 0xDC6135),   // rust
            UIColor(hex: 0xFFC944),   // butter
            UIColor(hex: 0xA3B65E),   // sage
            UIColor(hex: 0x84BACD),   // water-blue
            UIColor(hex: 0xB494D6)    // lavender
        ]
        static let feltNames = ["rust", "butter", "sage", "blue", "lavender"]

        let feltIndex: Int
        let radius: CGFloat
        /// The blue-moon golden dot (approved delight): butter-gold, hums a fifth
        /// higher, and makes its neighbors shimmer when it lands. ~1 in 40.
        let isGolden: Bool
        private let body = SKShapeNode()
        private let shadow: SKSpriteNode

        static let gold = UIColor(hex: 0xF6CF6E)

        var color: UIColor { DropDotToken.felts[feltIndex % DropDotToken.felts.count] }

        init(feltIndex: Int, radius: CGFloat, isGolden: Bool = false) {
            self.feltIndex = ((feltIndex % 5) + 5) % 5
            self.radius = radius
            self.isGolden = isGolden
            // A lighter contact shadow (founder: the dots read heavy). Was 2.5×1.1 @0.9 —
            // a big dark pad under every dot that piled up dark when they stacked.
            shadow = SKSpriteNode(texture: ProceduralTexture.softClayShadow(size: CGSize(width: radius * 1.9, height: radius * 0.8)))
            super.init()
            shadow.position = CGPoint(x: 0, y: -radius * 0.82)
            shadow.zPosition = -1
            shadow.alpha = 0.42
            addChild(shadow)
            buildBody()
        }
        required init?(coder: NSCoder) { fatalError() }

        /// One authored clay puck (the cream one) wears every felt — the tint system,
        /// same trick that dressed Stack's stones.
        private static func artSprite(radius r: CGFloat) -> SKSpriteNode? {
            ToyArt.sprite("dropdots-token-moon", fit: CGSize(width: r * 2.1, height: r * 2.1))
        }

        private static func mix(_ a: UIColor, _ b: UIColor, _ t: CGFloat) -> UIColor {
            var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
            var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
            a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
            return UIColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t,
                           blue: b1 + (b2 - b1) * t, alpha: a1 + (a2 - a1) * t)
        }

        private func buildBody() {
            let r = radius
            if let art = DropDotToken.artSprite(radius: r) {
                // Warm Clay token: authored clay body, same sleepy face drawn on top
                // (house pattern — see DropBoxPieces.buildBody). `body` stays the
                // lift/squash container so every feel verb works unchanged.
                addChild(body)
                art.zPosition = 0
                art.color = isGolden ? DropDotToken.gold : color
                art.colorBlendFactor = isGolden ? 0.55 : 0.95   // dots match their rings (founder: 0.72 read dusty)
                body.addChild(art)
                if isGolden {
                    let ring = SKShapeNode(circleOfRadius: r * 0.84)
                    ring.fillColor = .clear
                    ring.strokeColor = DropDotToken.gold.withAlpha(0.9)
                    ring.lineWidth = max(2, r * 0.1)
                    ring.zPosition = 0.45
                    body.addChild(ring)
                }
                buildFace()
                return
            }
            let fill = isGolden ? DropDotToken.mix(color, DropDotToken.gold, 0.55) : color
            body.path = CGPath(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2), transform: nil)
            body.fillColor = fill
            body.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.16)
            body.lineWidth = 1.6
            body.zPosition = 0
            addChild(body)
            ProceduralTexture.applyClayFill(to: body, base: fill, size: CGSize(width: r * 2, height: r * 2))
            if isGolden {
                // A thin warm halo ring so gold never reads as "just another moon".
                let ring = SKShapeNode(circleOfRadius: r * 0.84)
                ring.fillColor = .clear
                ring.strokeColor = DropDotToken.gold.withAlpha(0.9)
                ring.lineWidth = max(2, r * 0.1)
                ring.zPosition = 0.45
                body.addChild(ring)
            }

            // A lit top bevel + a soft shaded base so the puck reads thick and rounded.
            let bevel = SKShapeNode(ellipseOf: CGSize(width: r * 1.7, height: r * 0.7))
            bevel.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.26)
            bevel.strokeColor = .clear
            bevel.position = CGPoint(x: 0, y: r * 0.42); bevel.zPosition = 0.2
            body.addChild(bevel)
            let base = SKShapeNode(ellipseOf: CGSize(width: r * 1.7, height: r * 0.7))
            base.fillColor = WarmShelfPalette.cocoa.withAlpha(0.12)
            base.strokeColor = .clear
            base.position = CGPoint(x: 0, y: -r * 0.46); base.zPosition = 0.18
            body.addChild(base)

            buildFace()

            // A bright specular catch — premium clay gloss.
            let glint = SKShapeNode(ellipseOf: CGSize(width: r * 0.5, height: r * 0.32))
            glint.fillColor = UIColor.white.withAlpha(0.5); glint.strokeColor = .clear
            glint.position = CGPoint(x: -r * 0.32, y: r * 0.4); glint.zRotation = -0.5; glint.zPosition = 0.5
            body.addChild(glint)
        }

        /// The sleepy face — drawn in BOTH branches so authored bodies keep the
        /// house charm (face always procedural on top, like the Sleepy Box treasures).
        private func buildFace() {
            let r = radius
            // Closed-arc eyes + a soft smile, centred — readable from a stroller.
            let ink = WarmShelfPalette.cocoa.withAlpha(0.55)
            for sx in [-r * 0.34, r * 0.34] {
                let eyePath = CGMutablePath()
                eyePath.move(to: CGPoint(x: sx - r * 0.15, y: r * 0.02))
                eyePath.addQuadCurve(to: CGPoint(x: sx + r * 0.15, y: r * 0.02), control: CGPoint(x: sx, y: -r * 0.12))
                let eye = SKShapeNode(path: eyePath)
                eye.strokeColor = ink; eye.lineWidth = max(2, r * 0.08); eye.lineCap = .round; eye.fillColor = .clear
                eye.zPosition = 0.4
                body.addChild(eye)
            }
            let smilePath = CGMutablePath()
            smilePath.move(to: CGPoint(x: -r * 0.18, y: -r * 0.3))
            smilePath.addQuadCurve(to: CGPoint(x: r * 0.18, y: -r * 0.3), control: CGPoint(x: 0, y: -r * 0.44))
            let smile = SKShapeNode(path: smilePath)
            smile.strokeColor = ink; smile.lineWidth = max(2, r * 0.08); smile.lineCap = .round; smile.fillColor = .clear
            smile.zPosition = 0.4
            body.addChild(smile)
            for sx in [-r * 0.56, r * 0.56] {
                let cheek = SKShapeNode(ellipseOf: CGSize(width: r * 0.26, height: r * 0.16))
                cheek.fillColor = WarmShelfPalette.petal.withAlpha(0.35); cheek.strokeColor = .clear
                cheek.position = CGPoint(x: sx, y: -r * 0.16); cheek.zPosition = 0.38
                body.addChild(cheek)
            }
        }


        func setLifted(_ lifted: Bool) {
            removeAction(forKey: "lift")
            shadow.run(.group([
                .move(to: CGPoint(x: 0, y: lifted ? -radius * 1.5 : -radius * 0.92), duration: 0.16),
                .fadeAlpha(to: lifted ? 0.4 : 0.9, duration: 0.16),
                .scale(to: lifted ? 0.7 : 1, duration: 0.16)
            ]))
            body.run(.scale(to: lifted ? 1.14 : 1, duration: 0.16), withKey: "lift")
            if lifted, !AmbientAnimator.reduceMotion {
                body.run(.sequence([.rotate(toAngle: 0.05, duration: 0.14), .rotate(toAngle: -0.04, duration: 0.18), .rotate(toAngle: 0, duration: 0.16)]), withKey: "wob")
            }
        }

        func squash(_ a: CGFloat) {
            body.removeAction(forKey: "squash")
            body.run(.sequence([.scaleX(to: 1 + a, y: 1 - a, duration: 0.06), .scaleX(to: 1, y: 1, duration: 0.2)]), withKey: "squash")
        }

        func bob() {
            guard !AmbientAnimator.reduceMotion else { return }
            run(.sequence([.moveBy(x: 0, y: 4, duration: 0.08), .moveBy(x: 0, y: -4, duration: 0.12)]))
        }

        /// A one-time soft bloom: a glow ring grows and fades while the token gives a gentle pulse —
        /// the magic happens, then the board returns to normal (never a permanent lit state).
        func celebrate() {
            guard !AmbientAnimator.reduceMotion else { return }
            let g = SKShapeNode(circleOfRadius: radius * 1.04)
            g.fillColor = .clear
            g.strokeColor = color.withAlpha(0.95)
            g.lineWidth = radius * 0.22
            g.blendMode = .add
            g.zPosition = 1
            g.alpha = 0
            g.setScale(0.82)
            addChild(g)
            g.run(.sequence([
                .group([.fadeAlpha(to: 0.95, duration: 0.16), .scale(to: 1.4, duration: 0.55)]),
                .fadeOut(withDuration: 0.5),
                .removeFromParent()
            ]))
            body.run(.sequence([.scale(to: 1.15, duration: 0.16), .scale(to: 1, duration: 0.32)]), withKey: "celebrate")
        }
    }

    private struct Cell: Hashable { let c: Int; let r: Int; init(_ c: Int, _ r: Int) { self.c = c; self.r = r } }
    private struct GridSnap { let c: Int; let r: Int; let felt: Int; let golden: Bool }

    // MARK: - Layers
    private let boardLayer = SKNode()
    private let tokenLayer = SKNode()
    private let frontLayer = SKNode()      // top lips the falling token slips behind
    private let particleLayer = SKNode()

    // MARK: - Model
    private let cols = 5, rows = 4
    private var grid: [[DropDotToken?]] = []
    private var traySlots: [CGPoint] = []
    private var trayTokens: [DropDotToken?] = []
    private var glowingCells: Set<Cell> = []
    private var boardWasFull = false
    // The finite set the child can SEE — no hidden reserve (founder, June 15: a hidden
    // stack silently refilling the tray made the count feel endless). All five live in
    // the visible tray; drop them, and tap a settled dot to send it back.
    private let totalTokens = 5
    private var reserveCount = 0

    // MARK: - Geometry
    private var cell: CGFloat = 60
    private var tokenR: CGFloat = 26
    private var frameT: CGFloat = 16
    private var gridOriginX: CGFloat = 0
    private var gridTopY: CGFloat = 0
    private var gridBottomY: CGFloat = 0
    private var mouthY: CGFloat = 0
    private var boardRect = CGRect.zero
    private var resetTabRect = CGRect.zero
    private var columnRimColors: [UIColor] = []
    private weak var resetTab: SKNode?

    // MARK: - Touch
    private weak var dragToken: DropDotToken?
    private var dragTouch: UITouch?
    private var dragFromSlot: Int?
    private var dragOffset = CGPoint.zero
    private var dragTarget = CGPoint.zero
    private var hoverCol: Int?
    private var columnRims: [SKShapeNode] = []
    private var mouthRings: [SKShapeNode] = []

    private var lastTone: [String: TimeInterval] = [:]
    private let woodWarm = UIColor(hex: 0xCB9A52)
    private let woodTop = UIColor(hex: 0xE2B568)
    private let woodDark = UIColor(hex: 0x8A5A28)
    private let felt = UIColor(hex: 0x4A2E1C)

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        ambientMoteInterval = 9999
        boardLayer.zPosition = 1; addChild(boardLayer)
        tokenLayer.zPosition = 2; addChild(tokenLayer)
        frontLayer.zPosition = 3; addChild(frontLayer)
        particleLayer.zPosition = 4; addChild(particleLayer)
        rebuild()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 120, size.height > 120, cell > 1, oldSize != size else { return }
        // Preserve the in-progress board across a rotation — a child must never lose their stack.
        let gridSnap: [GridSnap] = (0..<cols).flatMap { c in
            (0..<rows).compactMap { r in grid[c][r].map { GridSnap(c: c, r: r, felt: $0.feltIndex, golden: $0.isGolden) } }
        }
        let traySnap = trayTokens.map { t in t.map { (felt: $0.feltIndex, golden: $0.isGolden) } }
        rebuild(gridSnap: gridSnap, traySnap: traySnap)
    }

    // MARK: - Build / layout

    private func rebuild(gridSnap: [GridSnap] = [], traySnap: [(felt: Int, golden: Bool)?] = []) {
        guard size.width > 120, size.height > 120 else { return }
        [boardLayer, tokenLayer, frontLayer, particleLayer].forEach { $0.removeAllChildren() }
        columnRims.removeAll(); mouthRings.removeAll(); traySlots.removeAll(); trayTokens.removeAll()
        glowingCells.removeAll(); boardWasFull = false
        dragToken = nil; dragTouch = nil; hoverCol = nil
        grid = Array(repeating: Array(repeating: nil, count: rows), count: cols)

        let play = safePlayRect()
        let landscape = isLandscapeLayout
        // Portrait: tray below the board. Landscape: the tray stands BESIDE the board (a column on
        // the left), so both orientations feel intentionally staged — never a shrunken letterbox.
        // The authored board carries its mouths above the grid and its rail below it, so it
        // stands a little taller than the procedural one — the cell budget makes room.
        let artBoard = ToyArt.texture("dropdots-board") != nil
        let maxCellW = play.width / (CGFloat(cols) + (landscape ? 3.2 : 0.8))
        let maxCellH = play.height / (CGFloat(rows) + (landscape ? (artBoard ? 3.4 : 2.6) : (artBoard ? 5.0 : 4.2)))
        cell = min(maxCellW, maxCellH, isTabletLayout ? 132 : 88)
        tokenR = cell * 0.32   // fit the channel INTERIOR (wood walls are thick) — founder: dots didn't fit
        frameT = cell * 0.26

        let boardInnerW = cell * CGFloat(cols)
        let mouthH = cell * 0.92
        let trayH = cell * 1.35
        let boardW = boardInnerW + frameT * 2
        let gridH = cell * CGFloat(rows)
        let boardH = gridH + mouthH + frameT * 1.8

        let totalH = landscape ? boardH + cell * 0.6 : boardH + trayH + cell * 0.5
        let boardCenterX = landscape ? play.midX + cell * 0.95 : play.midX
        let boardTopY = play.minY + (play.height + totalH) / 2 - cell * 0.1   // toy centred in the play area
        let boardBottomY = boardTopY - boardH

        gridOriginX = boardCenterX - boardInnerW / 2
        gridTopY = boardTopY - frameT - mouthH
        gridBottomY = gridTopY - gridH
        mouthY = gridTopY + mouthH * 0.52
        boardRect = CGRect(x: boardCenterX - boardW / 2, y: boardBottomY, width: boardW, height: boardH)

        // Warm carved-wood funnels, all one honey tone — they belong to the calm clay world, not a
        // row of rainbow coin-slots. (Any token drops into any column; colour isn't a rule.)
        // In art mode each painted felt ring keeps its own sampled colour (used by the front lips).
        columnRimColors = artBoard
            ? [0xC55B2F, 0xF2A935, 0x897E3D, 0x707868, 0x835D59].map { UIColor(hex: $0) }
            : Array(repeating: UIColor(hex: 0xC58A48), count: cols)

        buildBoard(mouthH: mouthH)
        // buildBoard's art branch re-derives boardRect from the painted body, so the
        // tray and tab anchor to what is actually on screen, not the procedural guess.
        if landscape {
            buildTray(centerX: boardRect.minX - cell * 0.95, y: boardRect.midY,
                      width: cell * 1.4, height: min(boardRect.height * (artBoard ? 0.85 : 0.96), play.height * 0.92), vertical: true)
        } else {
            buildTray(centerX: boardCenterX, y: boardRect.minY - cell * 0.6 - trayH / 2,
                      width: boardW * 1.04, height: trayH)
        }
        buildResetTab(centerX: boardCenterX, boardBottomY: boardRect.minY)
        idleInviteTab()
        restoreTray(traySnap)
        restoreGrid(gridSnap)

        // Finite-set accounting: board + tray + reserve always total `totalTokens`.
        let onBoard = grid.flatMap { $0 }.compactMap { $0 }.count
        let inTray = trayTokens.compactMap { $0 }.count
        reserveCount = max(0, totalTokens - onBoard - inTray)

        #if DEBUG
        // LULL_DEBUG_DROPDOTS_DEMO=1 drops four tokens into column 2 (honest-weight
        // thunks 1→4 + the column wave) then one into column 0 — QA without a finger.
        // LULL_DEBUG_DROPDOTS_GOLD=1 makes every spawn golden (visual + fifth check).
        if ProcessInfo.processInfo.environment["LULL_DEBUG_DROPDOTS_DEMO"] == "1", onBoard == 0 {
            var script: [SKAction] = [.wait(forDuration: 1.6)]
            for i in 0..<5 {
                let col = i < 4 ? 2 : 0
                script.append(.run { [weak self] in
                    guard let self else { return }
                    if let slot = self.trayTokens.firstIndex(where: { $0 != nil }),
                       let tok = self.trayTokens[slot] {
                        self.trayTokens[slot] = nil
                        self.dropIntoColumn(tok, col: col, fromSlot: slot)
                    }
                })
                script.append(.wait(forDuration: 1.4))
            }
            run(.sequence(script))
        }
        #endif
    }

    /// Re-seat preserved tokens at the new geometry after a rotation rebuild.
    private func restoreGrid(_ snap: [GridSnap]) {
        guard !snap.isEmpty else { return }
        for s in snap where s.c < cols && s.r < rows {
            let t = DropDotToken(feltIndex: s.felt, radius: tokenR, isGolden: s.golden)
            t.position = CGPoint(x: cellX(s.c), y: cellY(s.r))
            t.zPosition = 5
            tokenLayer.addChild(t)
            grid[s.c][s.r] = t
        }
        detectPatterns(celebrate: false)   // recompute match state silently (no spurious bloom on rotate)
    }

    private func restoreTray(_ snap: [(felt: Int, golden: Bool)?]) {
        guard !snap.isEmpty else { return }
        for (i, item) in snap.enumerated() where i < trayTokens.count {
            trayTokens[i]?.removeFromParent()
            guard let item else { trayTokens[i] = nil; continue }   // empty slots stay empty (finite set)
            let t = DropDotToken(feltIndex: item.felt, radius: tokenR, isGolden: item.golden)
            t.position = traySlots[i]; t.zPosition = 5
            tokenLayer.addChild(t)
            trayTokens[i] = t
        }
    }

    private func cellX(_ c: Int) -> CGFloat { gridOriginX + cell * (CGFloat(c) + 0.5) }
    // Tokens rest on the channel FLOOR and stack up touching (founder: they floated /
    // didn't fit). Row rows-1 is the bottom (first dropped); the rest nestle above it,
    // leaving the upper channel as the drop-zone the dot falls through.
    private func cellY(_ r: Int) -> CGFloat { gridBottomY - tokenR + CGFloat(rows - 1 - r) * (tokenR * 1.95) }
    private func filled(_ c: Int) -> Int { grid[c].compactMap { $0 }.count }
    private func hasSpace(_ c: Int) -> Bool { filled(c) < rows }

    private func buildBoard(mouthH: CGFloat) {
        if let tex = ToyArt.texture("dropdots-board") {
            buildArtBoard(tex)
            return
        }
        // Contact shadow grounds the whole toy.
        let shadow = SKSpriteNode(texture: ProceduralTexture.softClayShadow(size: CGSize(width: boardRect.width * 1.1, height: boardRect.height * 0.3)))
        shadow.position = CGPoint(x: boardRect.midX, y: boardRect.minY - cell * 0.05)
        shadow.zPosition = -0.5
        boardLayer.addChild(shadow)

        // The chunky wooden body.
        let bodyRect = CGRect(x: -boardRect.width / 2, y: -boardRect.height / 2, width: boardRect.width, height: boardRect.height)
        let body = SKShapeNode(rect: bodyRect, cornerRadius: frameT * 1.4)
        body.fillColor = woodWarm
        body.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.24)
        body.lineWidth = 2.5
        body.position = CGPoint(x: boardRect.midX, y: boardRect.midY)
        body.zPosition = 0
        boardLayer.addChild(body)
        ProceduralTexture.applyClayFill(to: body, base: woodWarm, size: boardRect.size)
        ProceduralTexture.addSoftGrainLines(to: body, in: bodyRect.insetBy(dx: boardRect.width * 0.06, dy: boardRect.height * 0.08),
                                            count: 9, color: WarmShelfPalette.cocoa, alpha: 0.02...0.045, zPosition: 0.05)
        // Lit top bevel + shaded base.
        let bevel = SKShapeNode(rect: CGRect(x: bodyRect.minX + frameT, y: bodyRect.maxY - frameT * 0.9, width: boardRect.width - frameT * 2, height: frameT * 0.5), cornerRadius: frameT * 0.25)
        bevel.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.28); bevel.strokeColor = .clear; bevel.zPosition = 0.1
        body.addChild(bevel)
        let baseShade = SKShapeNode(rect: CGRect(x: bodyRect.minX + frameT, y: bodyRect.minY + frameT * 0.4, width: boardRect.width - frameT * 2, height: frameT * 0.8), cornerRadius: frameT * 0.3)
        baseShade.fillColor = woodDark.withAlpha(0.2); baseShade.strokeColor = .clear; baseShade.zPosition = 0.08
        body.addChild(baseShade)

        // Each column: a felt tube the tokens fall through, four wells, and a huge top mouth.
        for c in 0..<cols {
            let x = cellX(c)
            let tubeW = cell * 0.84
            let tubeTop = gridTopY + mouthH * 0.2
            let tubeBottom = gridBottomY
            let tube = SKShapeNode(rect: CGRect(x: x - tubeW / 2, y: tubeBottom, width: tubeW, height: tubeTop - tubeBottom), cornerRadius: tubeW * 0.34)
            tube.fillColor = felt
            tube.strokeColor = woodDark.withAlpha(0.4)
            tube.lineWidth = 1.5
            tube.zPosition = 0.2
            boardLayer.addChild(tube)
            ProceduralTexture.applyClayFill(to: tube, base: felt, size: CGSize(width: tubeW, height: tubeTop - tubeBottom))
            // a soft inner highlight down one side
            let sheen = SKShapeNode(rect: CGRect(x: x - tubeW * 0.36, y: tubeBottom + 6, width: tubeW * 0.16, height: tubeTop - tubeBottom - 12), cornerRadius: tubeW * 0.08)
            sheen.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.05); sheen.strokeColor = .clear; sheen.zPosition = 0.22
            boardLayer.addChild(sheen)

            // Per-cell wells (so empty slots read clearly).
            for r in 0..<rows {
                let well = SKShapeNode(circleOfRadius: tokenR * 0.98)
                well.fillColor = UIColor(hex: 0x35200F).withAlpha(0.55)
                well.strokeColor = .clear
                well.position = CGPoint(x: x, y: cellY(r))
                well.zPosition = 0.24
                boardLayer.addChild(well)
                let wellHi = SKShapeNode(ellipseOf: CGSize(width: tokenR * 1.2, height: tokenR * 0.5))
                wellHi.fillColor = .black.withAlpha(0.22); wellHi.strokeColor = .clear
                wellHi.position = CGPoint(x: x, y: cellY(r) + tokenR * 0.5); wellHi.zPosition = 0.25
                boardLayer.addChild(wellHi)
            }

            // The huge mouth: a lit wooden funnel rim + dark opening, capped by a front lip.
            let rim = columnRimColors[c % columnRimColors.count]
            let mouthW = cell * 0.96
            let mouthBack = SKShapeNode(ellipseOf: CGSize(width: mouthW * 1.04, height: mouthH * 0.66))
            mouthBack.fillColor = woodDark.withAlpha(0.5); mouthBack.strokeColor = .clear
            mouthBack.position = CGPoint(x: x, y: mouthY - mouthH * 0.04); mouthBack.zPosition = 0.3
            boardLayer.addChild(mouthBack)
            let mouthRing = SKShapeNode(ellipseOf: CGSize(width: mouthW, height: mouthH * 0.6))
            mouthRing.fillColor = rim
            mouthRing.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.2)
            mouthRing.lineWidth = 1.5
            mouthRing.position = CGPoint(x: x, y: mouthY); mouthRing.zPosition = 0.32
            boardLayer.addChild(mouthRing)
            ProceduralTexture.applyClayFill(to: mouthRing, base: rim, size: CGSize(width: mouthW, height: mouthH * 0.6))
            mouthRings.append(mouthRing)
            // Sleepy eyes over the opening — each funnel is a little feeder friend, not a coin slot.
            for sx in [-mouthW * 0.2, mouthW * 0.2] {
                let eyePath = CGMutablePath()
                eyePath.move(to: CGPoint(x: sx - mouthW * 0.06, y: mouthH * 0.17))
                eyePath.addQuadCurve(to: CGPoint(x: sx + mouthW * 0.06, y: mouthH * 0.17), control: CGPoint(x: sx, y: mouthH * 0.115))
                let eye = SKShapeNode(path: eyePath)
                eye.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.5)
                eye.lineWidth = max(1.8, mouthW * 0.035)
                eye.lineCap = .round
                eye.fillColor = .clear
                eye.zPosition = 0.1
                mouthRing.addChild(eye)
            }
            let opening = SKShapeNode(ellipseOf: CGSize(width: mouthW * 0.66, height: mouthH * 0.4))
            opening.fillColor = felt; opening.strokeColor = .clear
            opening.position = CGPoint(x: x, y: mouthY); opening.zPosition = 0.34
            boardLayer.addChild(opening)
            // hover rim (warms while a token is held above this column)
            let hover = SKShapeNode(ellipseOf: CGSize(width: mouthW, height: mouthH * 0.6))
            hover.fillColor = .clear; hover.strokeColor = WarmShelfPalette.paperHighlight.withAlpha(0.0)
            hover.lineWidth = max(3, cell * 0.06); hover.position = CGPoint(x: x, y: mouthY); hover.zPosition = 0.36
            boardLayer.addChild(hover)
            columnRims.append(hover)
            // front lip the token slips behind on the way in
            let lip = SKShapeNode(ellipseOf: CGSize(width: mouthW * 0.9, height: mouthH * 0.3))
            lip.fillColor = rim.withAlpha(0.0); lip.strokeColor = .clear
            let lipArc = SKShapeNode(rect: CGRect(x: x - mouthW * 0.45, y: mouthY + mouthH * 0.04, width: mouthW * 0.9, height: mouthH * 0.16), cornerRadius: mouthH * 0.08)
            lipArc.fillColor = rim; lipArc.strokeColor = .clear; lipArc.zPosition = 0
            lip.addChild(lipArc)
            frontLayer.addChild(lip)
            _ = lip
        }
    }

    /// The authored board, fitted to the grid (inverse of Sleepy Box's buildArtBox: gameplay
    /// geometry stays byte-identical; the ART conforms). Measured from the keyed PNG
    /// (x from left, y from TOP, 2026-06-11): five mouth holes at fx 0.107…0.862 on the
    /// fy 0.096 line; rings + channel arcs end by fy 0.22; the bottom rail begins fy 0.88.
    /// The painted channels run longer than 4 rows, so the shaft band is pre-sliced and
    /// compressed (the Hum-frame move) — rings and rail stay perfectly true.
    private enum BoardArt {
        static let mouthFx0: CGFloat = 0.107
        static let mouthFx4: CGFloat = 0.862
        static let mouthFy: CGFloat = 0.096
        static let capTopFy: CGFloat = 0.22
        static let capBotFy: CGFloat = 0.88
        static let ringOuterW: CGFloat = 0.100   // painted ring outer width, fraction of art width
    }

    private func buildArtBoard(_ tex: SKTexture) {
        let nat = tex.size()
        // Width: the four mouth pitches must equal four grid cells exactly.
        let artW = cell * CGFloat(cols - 1) / (BoardArt.mouthFx4 - BoardArt.mouthFx0)
        let natH = nat.height * (artW / max(1, nat.width))
        let capTopH = BoardArt.capTopFy * natH
        let capBotH = (1 - BoardArt.capBotFy) * natH

        // Align: leftmost mouth on cellX(0); the mouth line on mouthY; sprite top above it.
        let artMinX = cellX(0) - BoardArt.mouthFx0 * artW
        let spriteTopY = mouthY + BoardArt.mouthFy * natH
        // The channel's painted floor arc lives just inside the bottom cap — seat it so
        // the bottom row RESTS on it (a gravity toy never floats its first dot).
        let bottomCapTopY = gridBottomY - cell * 0.08
        let midH = max(cell * 0.2, spriteTopY - capTopH - bottomCapTopY)
        let spriteBottomY = bottomCapTopY - capBotH
        let midX = artMinX + artW / 2

        boardRect = CGRect(x: artMinX, y: spriteBottomY, width: artW, height: spriteTopY - spriteBottomY)

        let shadow = SKSpriteNode(texture: ProceduralTexture.softClayShadow(size: CGSize(width: boardRect.width * 1.1, height: boardRect.height * 0.3)))
        shadow.position = CGPoint(x: boardRect.midX, y: boardRect.minY - cell * 0.05)
        shadow.zPosition = -0.5
        boardLayer.addChild(shadow)

        // Three bands from one texture (unit rects, origin bottom-left).
        func band(_ unitRect: CGRect, height: CGFloat, topY: CGFloat, z: CGFloat) {
            let sprite = SKSpriteNode(texture: SKTexture(rect: unitRect, in: tex))
            sprite.size = CGSize(width: artW, height: height)
            sprite.anchorPoint = CGPoint(x: 0.5, y: 1.0)
            sprite.position = CGPoint(x: midX, y: topY)
            sprite.zPosition = z
            boardLayer.addChild(sprite)
        }
        // Shaft first (slightly oversized into both caps so filtering can never open a seam).
        band(CGRect(x: 0, y: 1 - BoardArt.capBotFy, width: 1, height: BoardArt.capBotFy - BoardArt.capTopFy),
             height: midH + 2, topY: spriteTopY - capTopH + 1, z: 0)
        band(CGRect(x: 0, y: 1 - BoardArt.capTopFy, width: 1, height: BoardArt.capTopFy),
             height: capTopH, topY: spriteTopY, z: 0.05)
        band(CGRect(x: 0, y: 0, width: 1, height: 1 - BoardArt.capBotFy),
             height: capBotH, topY: bottomCapTopY, z: 0.05)

        // Live overlays the feel code indexes by column — exactly `cols` of each, in
        // column order (gulp scales mouthRings, hover warms columnRims). The painted
        // rings ARE the face here — no procedural marks on them (founder screenshot:
        // the overlay eyes read as broken hooks inside the holes).
        let ringW = BoardArt.ringOuterW * artW
        for c in 0..<cols {
            let x = cellX(c)
            let ring = SKShapeNode(ellipseOf: CGSize(width: ringW, height: ringW))
            ring.fillColor = .clear
            ring.strokeColor = .clear
            ring.position = CGPoint(x: x, y: mouthY)
            ring.zPosition = 0.32
            boardLayer.addChild(ring)
            mouthRings.append(ring)
            // hover rim (warms while a token is held above this column)
            let hover = SKShapeNode(ellipseOf: CGSize(width: ringW * 1.25, height: ringW * 1.25))
            hover.fillColor = .clear
            hover.strokeColor = WarmShelfPalette.paperHighlight.withAlpha(0.0)
            hover.lineWidth = max(3, cell * 0.06)
            hover.position = CGPoint(x: x, y: mouthY)
            hover.zPosition = 0.36
            boardLayer.addChild(hover)
            columnRims.append(hover)
            // Front lip: a pixel-true CROP of this ring's lower arc, re-rendered in
            // place in the front layer — the falling token slips behind the very
            // pixels that are already there, so it can never read as a painted patch.
            let fx = BoardArt.mouthFx0 + (BoardArt.mouthFx4 - BoardArt.mouthFx0) * CGFloat(c) / CGFloat(cols - 1)
            let lipWFrac = BoardArt.ringOuterW * 1.3
            let lipTopFy = BoardArt.mouthFy + 0.008
            let lipHFrac: CGFloat = 0.042
            let unit = CGRect(x: max(0, fx - lipWFrac / 2),
                              y: 1 - (lipTopFy + lipHFrac),
                              width: min(1, lipWFrac),
                              height: lipHFrac)
            let lip = SKSpriteNode(texture: SKTexture(rect: unit, in: tex))
            lip.size = CGSize(width: lipWFrac * artW, height: lipHFrac * natH)
            lip.position = CGPoint(x: artMinX + (unit.midX) * artW,
                                   y: spriteTopY - (lipTopFy + lipHFrac / 2) * natH)
            frontLayer.addChild(lip)
        }
    }

    private func buildTray(centerX: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, vertical: Bool = false) {
        // A chunky catch tray — a ledge under the board in portrait, a standing rack beside it in landscape.
        let minSide = min(width, height)
        if let art = ToyArt.sprite("dropdots-tray",
                                   fit: vertical ? CGSize(width: height, height: width)
                                                 : CGSize(width: width, height: height)) {
            // Authored felt-lined tray; long art stands up for the landscape rack.
            // (aspect-fit happens BEFORE rotation, hence the swapped fit.)
            if vertical { art.zRotation = .pi / 2 }
            art.position = CGPoint(x: centerX, y: y)
            art.zPosition = 0
            boardLayer.addChild(art)
            let shadow = SKSpriteNode(texture: ProceduralTexture.softClayShadow(
                size: CGSize(width: width * 1.05, height: minSide * 0.5)))
            shadow.position = CGPoint(x: centerX, y: y - height / 2 + minSide * 0.1)
            shadow.zPosition = -0.2
            boardLayer.addChild(shadow)
        } else {
        let trayRect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
        let tray = SKShapeNode(rect: trayRect, cornerRadius: minSide * 0.34)
        tray.fillColor = woodTop
        tray.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.2)
        tray.lineWidth = 2
        tray.position = CGPoint(x: centerX, y: y)
        tray.zPosition = 0
        boardLayer.addChild(tray)
        ProceduralTexture.applyClayFill(to: tray, base: woodTop, size: trayRect.size)
        let hollowDX = vertical ? width * 0.22 : width * 0.03
        let hollowDY = vertical ? height * 0.03 : height * 0.22
        let trayHollow = SKShapeNode(rect: trayRect.insetBy(dx: hollowDX, dy: hollowDY), cornerRadius: minSide * 0.3)
        trayHollow.fillColor = woodDark.withAlpha(0.18); trayHollow.strokeColor = .clear; trayHollow.zPosition = 0.05
        tray.addChild(trayHollow)
        let trayHi = SKShapeNode(rect: CGRect(x: trayRect.minX + 8, y: trayRect.maxY - minSide * 0.16, width: width - 16, height: minSide * 0.06), cornerRadius: 3)
        trayHi.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.3); trayHi.strokeColor = .clear; trayHi.zPosition = 0.06
        tray.addChild(trayHi)
        }

        // Token slots, evenly spread along the tray's long axis.
        let n = 5
        let spread = (vertical ? height : width) * 0.82
        for i in 0..<n {
            let offset = spread * CGFloat(i) / CGFloat(n - 1) - spread / 2
            let slot = vertical ? CGPoint(x: centerX, y: y - offset) : CGPoint(x: centerX + offset, y: y)
            traySlots.append(slot)
            spawnTrayToken(slot: i, at: slot)
        }
    }

    /// Place a fresh token in a tray slot (visual only — reserve accounting lives in replenishSlot).
    private func spawnTrayToken(slot: Int, at position: CGPoint? = nil) {
        // Once in a blue moon the tray holds a golden dot (approved delight).
        var golden = Int.random(in: 0..<40) == 0
        #if DEBUG
        if ProcessInfo.processInfo.environment["LULL_DEBUG_DROPDOTS_GOLD"] == "1" { golden = true }
        #endif
        let token = DropDotToken(feltIndex: Int.random(in: 0..<DropDotToken.felts.count), radius: tokenR,
                                 isGolden: golden)
        token.position = position ?? traySlots[slot]
        token.zPosition = 5
        if position == nil {
            token.alpha = 0
            token.setScale(0.5)
            token.run(.sequence([.wait(forDuration: 0.18), .group([.fadeIn(withDuration: 0.16), .scale(to: 1, duration: 0.2)])]))
        }
        tokenLayer.addChild(token)
        if slot < trayTokens.count { trayTokens[slot] = token } else { trayTokens.append(token) }
    }

    private func buildResetTab(centerX: CGFloat, boardBottomY: CGFloat) {
        // A big chunky wooden pull-tab that hangs off the lower front of the board — obviously grabby.
        let tabW = cell * 2.0, tabH = cell * 0.66
        let cx = centerX, cy = boardBottomY - tabH * 0.1   // sits on the lower front, clear of grid + tray
        resetTabRect = CGRect(x: cx - tabW / 2, y: cy - tabH / 2, width: tabW, height: tabH)
        let tab = SKNode()
        tab.position = CGPoint(x: cx, y: cy)
        tab.zPosition = 0.6
        boardLayer.addChild(tab)
        resetTab = tab

        let shadow = SKSpriteNode(texture: ProceduralTexture.softClayShadow(size: CGSize(width: tabW * 1.05, height: tabH * 0.7)))
        shadow.position = CGPoint(x: 0, y: -tabH * 0.5); shadow.zPosition = -0.2
        tab.addChild(shadow)

        // The flat walnut pull (June 11 Codex run) — wide, front-on, two carved grip
        // hollows. The arch that read wrong is history; procedural stays as fallback.
        if let art = ToyArt.sprite("dropdots-tab", fit: CGSize(width: tabW, height: tabH)) {
            art.zPosition = 0
            tab.addChild(art)
            return
        }
        let plate = SKShapeNode(rect: CGRect(x: -tabW / 2, y: -tabH / 2, width: tabW, height: tabH), cornerRadius: tabH * 0.44)
        plate.fillColor = woodDark
        plate.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.3)
        plate.lineWidth = 2.5
        tab.addChild(plate)
        ProceduralTexture.applyClayFill(to: plate, base: woodDark, size: CGSize(width: tabW, height: tabH))
        let bevel = SKShapeNode(rect: CGRect(x: -tabW * 0.4, y: tabH * 0.2, width: tabW * 0.8, height: tabH * 0.12), cornerRadius: tabH * 0.06)
        bevel.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.32); bevel.strokeColor = .clear; bevel.zPosition = 0.2
        tab.addChild(bevel)
        // Two chunky grip grooves so it reads as a handle to pull.
        for gy in [tabH * 0.02, -tabH * 0.18] {
            let g = SKShapeNode(rect: CGRect(x: -tabW * 0.24, y: gy, width: tabW * 0.48, height: tabH * 0.11), cornerRadius: tabH * 0.055)
            g.fillColor = WarmShelfPalette.cocoa.withAlpha(0.28); g.strokeColor = .clear; g.zPosition = 0.15
            tab.addChild(g)
        }
    }

    private func idleInviteTab() {
        guard !AmbientAnimator.reduceMotion, let tab = resetTab else { return }
        tab.removeAction(forKey: "invite")
        let check = SKAction.run { [weak self] in
            guard let self, self.dragToken == nil, self.grid.flatMap({ $0 }).contains(where: { $0 != nil }) else { return }
            self.resetTab?.run(.sequence([.moveBy(x: 0, y: -4, duration: 0.4), .moveBy(x: 0, y: 4, duration: 0.5)]))
        }
        tab.run(.repeatForever(.sequence([.wait(forDuration: 4), check])), withKey: "invite")
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        HapticsManager.shared.prepareForTouch()
        for touch in touches {
            let p = touch.location(in: self)
            if dragTouch == nil, consumeShelfReturnTouch(at: p) { return }
            if resetTabRect.insetBy(dx: -cell * 0.2, dy: -cell * 0.2).contains(p) {
                if dragToken == nil {
                    triggerReset()
                } else {
                    TouchFeedbackAnimator.emptyTap(in: self, at: p)
                }
                continue
            }
            if dragToken == nil, let slot = traySlotNear(p) {
                let token = trayTokens[slot]!
                // A returning dot is touchable where it actually is. Take ownership
                // immediately so its old pour/fly-home animation cannot fight this drag.
                token.removeAllActions()
                token.alpha = 1
                token.setScale(1)
                dragToken = token; dragTouch = touch; dragFromSlot = slot
                dragOffset = CGPoint(x: token.position.x - p.x, y: token.position.y - p.y)
                dragTarget = token.position
                token.zPosition = 30
                token.setLifted(true)
                tone(.single(8, .clay.with(body: 0.12, amplitude: 0.07, noiseGain: 0.2)), key: "pickup")
                HapticsManager.shared.impact(style: .light, intensity: 0.16)
                continue
            }
            // Tap a settled stack → its top dot flies home to the tray. The same five dots
            // come and go, so the finite set is felt (founder, June 15).
            if dragToken == nil, let col = boardColumnAt(p), filled(col) > 0 {
                returnTopOfColumn(col); continue
            }
            TouchFeedbackAnimator.emptyTap(in: self, at: p)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches where touch == dragTouch {
            let p = touch.location(in: self)
            dragTarget = CGPoint(x: (p.x + dragOffset.x).clamped(to: 24...size.width - 24),
                                 y: (p.y + dragOffset.y + 6).clamped(to: 40...size.height - 40))
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches where touch == dragTouch { endDrag() }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches where touch == dragTouch { cancelDrag() }
    }

    override func suspendToyForRest() {
        cancelDrag()
        super.suspendToyForRest()
    }

    /// An interruption returns the owned dot without posting or consuming it.
    private func cancelDrag() {
        guard let token = dragToken, let slot = dragFromSlot else { return }
        dragTouch = nil; dragToken = nil; dragFromSlot = nil
        clearHover()
        token.removeAllActions()
        token.setLifted(false)
        token.alpha = 1
        token.setScale(1)
        token.zPosition = 5
        if traySlots.indices.contains(slot) { token.position = traySlots[slot] }
    }

    private func endDrag() {
        guard let token = dragToken, let slot = dragFromSlot else { return }
        dragTouch = nil; dragToken = nil; dragFromSlot = nil; clearHover()
        let overBoard = token.position.y > gridBottomY && abs(token.position.x - boardRect.midX) < boardRect.width / 2
        if overBoard {
            let col = nearestColumn(token.position.x)
            if hasSpace(col) {
                dropIntoColumn(token, col: col, fromSlot: slot)
            } else if let open = nearestOpenColumn(from: col) {
                token.bob()
                tone(.single(4, .wood.with(body: 0.14, amplitude: 0.05, noiseGain: 0.2)), key: "full", minInterval: 0.2)
                HapticsManager.shared.impact(style: .light, intensity: 0.12)
                token.run(.sequence([.wait(forDuration: 0.18)])) { [weak self] in
                    self?.dropIntoColumn(token, col: open, fromSlot: slot)
                }
            } else {
                token.bob(); returnToSlot(token, slot: slot)
            }
        } else {
            returnToSlot(token, slot: slot)
        }
    }

    private func returnToSlot(_ token: DropDotToken, slot: Int) {
        token.setLifted(false)
        token.zPosition = 5
        let move = SKAction.move(to: traySlots[slot], duration: 0.28); move.timingMode = .easeOut
        token.run(.sequence([move, .run { [weak token] in token?.squash(0.06) }]))
    }

    // MARK: - Drop / land

    private func dropIntoColumn(_ token: DropDotToken, col: Int, fromSlot slot: Int) {
        token.removeAllActions()
        token.alpha = 1
        token.setScale(1)
        let row = rows - 1 - filled(col)
        grid[col][row] = token
        token.setLifted(false)
        token.zPosition = 5

        let dest = CGPoint(x: cellX(col), y: cellY(row))
        let align = SKAction.move(to: CGPoint(x: cellX(col), y: mouthY), duration: 0.1); align.timingMode = .easeOut
        let dist = mouthY - dest.y
        let dur = 0.16 + Double(dist / cell) * 0.07
        let fall = SKAction.moveTo(y: dest.y, duration: dur); fall.timingMode = .easeIn
        playFallWhoosh()
        token.run(.sequence([align, fall, .run { [weak self] in
            self?.onLanded(token, col: col, row: row, dest: dest)
        }]))

        // Replenish the tray slot the moment the token leaves it.
        replenishSlot(slot)
        flashColumn(col)
        gulpColumn(col)
    }

    private func onLanded(_ token: DropDotToken, col: Int, row: Int, dest: CGPoint) {
        token.squash(0.18)
        let fill = filled(col)   // includes this token — the grid is written before the fall
        playLandThunk(fill: fill, golden: token.isGolden)
        HapticsManager.shared.impact(style: .soft, intensity: 0.22)
        jiggleColumn(col, except: row)
        spawnDust(at: dest, color: token.color)
        if token.isGolden { shimmerNeighbors(of: col) }
        // The column wave — but a full board sings its own song; don't stack arps.
        let boardNowFull = grid.allSatisfy { $0.allSatisfy { $0 != nil } }
        if fill == rows, !boardNowFull { columnWave(col) }
        detectPatterns()
        checkBoardFull()
    }

    /// Approved delight: the column wave. Filling a column to the top runs one soft
    /// arpeggio up its dots, bottom to lid — naturally once, since only a landing
    /// can cross three-to-four.
    private func columnWave(_ col: Int) {
        tone(.arp([2, 5, 7, 9], step: 0.09, .celeste.with(body: 0.7, amplitude: 0.045)),
             key: "colwave", minInterval: 0.5)
        guard !AmbientAnimator.reduceMotion else { return }
        for r in stride(from: rows - 1, through: 0, by: -1) {        // row 3 = bottom
            grid[col][r]?.run(.sequence([
                .wait(forDuration: Double(rows - 1 - r) * 0.09),
                .scale(to: 1.08, duration: 0.12),
                .scale(to: 1.0, duration: 0.18)
            ]))
        }
    }

    /// A golden landing: the neighbors catch the light — gold motes and a soft ripple.
    private func shimmerNeighbors(of col: Int) {
        for nc in [col - 1, col + 1] where (0..<cols).contains(nc) {
            let f = filled(nc)
            let p = f > 0 ? CGPoint(x: cellX(nc), y: cellY(rows - f))   // top occupied cell
                          : CGPoint(x: cellX(nc), y: mouthY)            // empty: the mouth glints
            spawnMotes(at: p, color: DropDotToken.gold, count: 3)
            guard !AmbientAnimator.reduceMotion else { continue }
            for r in 0..<rows {
                grid[nc][r]?.run(.sequence([
                    .wait(forDuration: 0.08),
                    .scale(to: 1.05, duration: 0.12),
                    .scale(to: 1.0, duration: 0.16)
                ]))
            }
        }
    }

    private func jiggleColumn(_ col: Int, except: Int) {
        guard !AmbientAnimator.reduceMotion else { return }
        for r in 0..<rows where r != except {
            grid[col][r]?.run(.sequence([.moveBy(x: 0, y: -3, duration: 0.05), .moveBy(x: 0, y: 3, duration: 0.12)]))
        }
    }

    // MARK: - Patterns

    private func detectPatterns(celebrate: Bool = true) {
        var matched = Set<Cell>()
        let dirs = [(1, 0), (0, 1), (1, 1), (1, -1)]
        for c in 0..<cols {
            for r in 0..<rows {
                guard let k = grid[c][r]?.feltIndex else { continue }
                for (dc, dr) in dirs {
                    var run = [Cell(c, r)]
                    var cc = c + dc, rr = r + dr
                    while cc >= 0, cc < cols, rr >= 0, rr < rows, grid[cc][rr]?.feltIndex == k, run.count < 3 {
                        run.append(Cell(cc, rr)); cc += dc; rr += dr
                    }
                    if run.count >= 3 { run.forEach { matched.insert($0) } }
                }
            }
        }
        let newly = matched.subtracting(glowingCells)
        glowingCells = matched
        guard celebrate, !newly.isEmpty else { return }
        // The board quietly notices: matched tokens bloom + sparkle, then fade back to normal —
        // a transient magic moment, never a permanent lit state.
        tone(.arp([7, 11, 14], step: 0.08, .celeste.with(body: 0.85, amplitude: 0.05)), key: "pattern", minInterval: 0.25)
        HapticsManager.shared.impact(style: .soft, intensity: 0.2)
        for cell in matched {
            grid[cell.c][cell.r]?.celebrate()
            spawnMotes(at: CGPoint(x: cellX(cell.c), y: cellY(cell.r)),
                       color: grid[cell.c][cell.r]?.color ?? WarmShelfPalette.butter, count: 2)
        }
    }

    private func checkBoardFull() {
        let full = grid.allSatisfy { $0.allSatisfy { $0 != nil } }
        guard full, !boardWasFull else { if !full { boardWasFull = false }; return }
        boardWasFull = true
        tone(.arp([0, 4, 7, 11], step: 0.12, .breath.with(body: 0.7, amplitude: 0.04)), key: "boardfull")
        // a warm glow rolls left→right through the grid
        guard !AmbientAnimator.reduceMotion else { return }
        for c in 0..<cols {
            for r in 0..<rows {
                grid[c][r]?.run(.sequence([
                    .wait(forDuration: Double(c) * 0.08),
                    .scale(to: 1.08, duration: 0.16), .scale(to: 1, duration: 0.2)
                ]))
            }
        }
        resetTab?.run(.sequence([.wait(forDuration: 0.5), .moveBy(x: 0, y: -6, duration: 0.12), .moveBy(x: 0, y: 6, duration: 0.16),
                                 .moveBy(x: 0, y: -6, duration: 0.12), .moveBy(x: 0, y: 6, duration: 0.16)]))
    }

    // MARK: - Reset dump

    private func triggerReset() {
        guard dragToken == nil else { return }
        let tokens = grid.flatMap { $0 }.compactMap { $0 }
        resetTab?.run(.sequence([.scale(to: 0.94, duration: 0.08), .moveBy(x: 0, y: -10, duration: 0.12), .moveBy(x: 0, y: 10, duration: 0.18), .scale(to: 1, duration: 0.1)]))
        tone(.single(3, .wood.with(body: 0.4, amplitude: 0.06, noiseGain: 0.3)), key: "lever")
        HapticsManager.shared.impact(style: .rigid, intensity: 0.26)
        guard !tokens.isEmpty else { return }
        AudioManager.shared.playBoxOpen()

        grid = Array(repeating: Array(repeating: nil, count: rows), count: cols)
        glowingCells.removeAll(); boardWasFull = false

        // The pour, HONEST edition (founder: tokens were landing on top of tray tokens
        // and quietly swapping for fresh clones). Now each poured token claims a real
        // empty tray slot and BECOMES that tray token — the very dot you dropped comes
        // back to the very tray you took it from. When the tray is already full, the
        // extras visibly tuck UNDER the tray into the waiting stack (the reserve is a
        // real place, not a fade-to-nowhere).
        var empties = (0..<trayTokens.count).filter { trayTokens[$0] == nil }
        let gateY = boardRect.minY - cell * 0.45
        for (i, token) in tokens.enumerated() {
            token.removeAllActions()
            token.setLifted(false)
            let delay = Double(i) * 0.07
            let drop = SKAction.moveTo(y: gateY, duration: 0.24); drop.timingMode = .easeIn
            token.zPosition = 4
            let exitGate = SKAction.sequence([
                .wait(forDuration: delay),
                .run { [weak self, weak token] in
                    guard let self, let token else { return }
                    self.playTumble(); self.spawnDust(at: token.position, color: token.color)
                }
            ])

            if let slot = empties.first {
                empties.removeFirst()
                trayTokens[slot] = token   // claimed now — nothing can double-fill it
                let target = traySlots[slot]
                let arc = SKAction.move(to: target, duration: 0.32); arc.timingMode = .easeIn
                let bounce = SKAction.sequence([.moveBy(x: 0, y: tokenR * 0.5, duration: 0.09),
                                                .moveBy(x: 0, y: -tokenR * 0.5, duration: 0.12)])
                token.run(.sequence([
                    exitGate,
                    .group([.sequence([drop, arc]),
                            .rotate(toAngle: 0, duration: 0.56, shortestUnitArc: true)]),
                    .run { [weak self, weak token] in
                        guard let self, let token else { return }
                        token.squash(0.16); self.playTumble()
                        self.spawnDust(at: token.position, color: token.color)
                    },
                    bounce,
                    .run { [weak token] in token?.zPosition = 5 }
                ]))
            } else {
                // Tray full: this one slides home under the tray lip, into the stack.
                let trayY = traySlots.first?.y ?? (boardRect.minY - cell)
                let under = CGPoint(x: size.width / 2 + CGFloat.random(in: -cell...cell),
                                    y: trayY - tokenR * 1.1)
                let arc = SKAction.move(to: under, duration: 0.34); arc.timingMode = .easeIn
                token.run(.sequence([
                    exitGate,
                    .group([.sequence([drop, arc]),
                            .rotate(byAngle: CGFloat.random(in: -0.9...0.9), duration: 0.58)]),
                    .run { [weak self, weak token] in
                        guard let self else { return }
                        token?.zPosition = -1.5   // beneath the tray plate (cumulative z)
                        self.playTumble()
                        self.reserveCount += 1
                    },
                    .group([.moveBy(x: 0, y: -tokenR * 0.9, duration: 0.3),
                            .fadeOut(withDuration: 0.3)]),
                    .removeFromParent()
                ]))
            }
        }
    }

    // MARK: - Update (drag lag + column magnet)

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        guard cell > 1, let token = dragToken else { return }
        var target = dragTarget
        if token.position.y > gridBottomY - cell * 0.3 {
            let col = nearestColumn(token.position.x)
            let mx = cellX(col)
            let pull: CGFloat = token.position.y > gridTopY - cell * 0.5 ? 0.5 : 0.28
            target.x += (mx - target.x) * pull
            if hoverCol != col { setHover(col) }
        } else if hoverCol != nil {
            clearHover()
        }
        token.position = CGPoint(x: token.position.x + (target.x - token.position.x) * 0.4,
                                 y: token.position.y + (target.y - token.position.y) * 0.4)
    }

    private func setHover(_ col: Int) {
        hoverCol.map { columnRims[$0].run(.fadeAlpha(to: 0, duration: 0.15)) }
        hoverCol = col
        if hasSpace(col) {
            let rim = columnRims[col]
            rim.strokeColor = WarmShelfPalette.paperHighlight.withAlpha(0.85)
            rim.run(.fadeAlpha(to: 1, duration: 0.15))
            // existing stack jiggles a little
            for r in 0..<rows { grid[col][r]?.run(.sequence([.scale(to: 1.04, duration: 0.1), .scale(to: 1, duration: 0.14)])) }
            spawnMotes(at: CGPoint(x: cellX(col), y: mouthY), color: columnRimColors[col % columnRimColors.count], count: 2)
            tone(.single(6, .felt.with(body: 0.1, amplitude: 0.035, noiseGain: 0.2)), key: "hover", minInterval: 0.3)
        }
    }

    private func clearHover() {
        if let h = hoverCol { columnRims[h].run(.fadeAlpha(to: 0, duration: 0.18)) }
        hoverCol = nil
    }

    /// The funnel visibly GULPS the dot — a squashy little swallow that makes feeding the board
    /// feel alive (the anti-"solitaire-board" move).
    private func gulpColumn(_ col: Int) {
        guard col < mouthRings.count, !AmbientAnimator.reduceMotion else { return }
        let ring = mouthRings[col]
        ring.removeAction(forKey: "gulp")
        ring.run(.sequence([
            .group([.scaleX(to: 1.1, duration: 0.09), .scaleY(to: 0.68, duration: 0.09)]),
            .group([.scaleX(to: 0.97, duration: 0.14), .scaleY(to: 1.1, duration: 0.14)]),
            .group([.scaleX(to: 1.0, duration: 0.18), .scaleY(to: 1.0, duration: 0.18)])
        ]), withKey: "gulp")
    }

    private func flashColumn(_ col: Int) {
        let rim = columnRims[col]
        rim.strokeColor = WarmShelfPalette.paperHighlight.withAlpha(0.9)
        rim.run(.sequence([.fadeAlpha(to: 1, duration: 0.05), .fadeAlpha(to: 0, duration: 0.35)]))
    }

    // MARK: - Tray helpers

    private func traySlotNear(_ p: CGPoint) -> Int? {
        var best: Int?; var bestD = CGFloat.greatestFiniteMagnitude
        for (i, token) in trayTokens.enumerated() {
            guard let token else { continue }
            let d = hypot(token.position.x - p.x, token.position.y - p.y)
            if d < tokenR + 40, d < bestD { best = i; bestD = d }
        }
        return best
    }

    /// FINITE dots, like a real toy: a used slot only refills while the reserve lasts. When the
    /// last dot is played, the tray sits empty and the pull-tab invites — pour them back to go again.
    private func replenishSlot(_ slot: Int) {
        trayTokens[slot] = nil
        guard reserveCount > 0 else {
            if trayTokens.allSatisfy({ $0 == nil }) { inviteTabNow() }
            return
        }
        reserveCount -= 1
        spawnTrayToken(slot: slot)
    }

    private func inviteTabNow() {
        guard !AmbientAnimator.reduceMotion else { return }
        resetTab?.run(.sequence([
            .moveBy(x: 0, y: -6, duration: 0.14), .moveBy(x: 0, y: 6, duration: 0.18),
            .moveBy(x: 0, y: -6, duration: 0.14), .moveBy(x: 0, y: 6, duration: 0.18)
        ]))
    }

    private func nearestColumn(_ x: CGFloat) -> Int {
        Int(((x - gridOriginX) / cell).clamped(to: 0...CGFloat(cols - 1)).rounded(.down)).clamped(to: 0...(cols - 1))
    }

    private func nearestOpenColumn(from col: Int) -> Int? {
        for d in 1..<cols {
            if col - d >= 0, hasSpace(col - d) { return col - d }
            if col + d < cols, hasSpace(col + d) { return col + d }
        }
        return hasSpace(col) ? col : nil
    }

    /// Which board column a tap landed on (in the stacked-dot area), or nil.
    private func boardColumnAt(_ p: CGPoint) -> Int? {
        guard p.x > boardRect.minX, p.x < boardRect.maxX,
              p.y > gridBottomY - tokenR, p.y < mouthY else { return nil }
        return nearestColumn(p.x)
    }

    /// A tap on a column sends its TOP dot back to its tray slot — the child uses the
    /// dots, then returns them; the same finite handful comes and goes (founder, June 15).
    private func returnTopOfColumn(_ col: Int) {
        let f = filled(col)
        guard f > 0 else { return }
        let topRow = rows - f
        guard topRow >= 0, topRow < rows, let token = grid[col][topRow],
              let slot = (0..<trayTokens.count).first(where: { trayTokens[$0] == nil }) else { return }
        grid[col][topRow] = nil
        trayTokens[slot] = token
        token.removeAllActions(); token.setLifted(false); token.zPosition = 20
        let target = traySlots[slot]
        let lift = SKAction.moveBy(x: 0, y: tokenR * 0.7, duration: 0.12); lift.timingMode = .easeOut
        let fly = SKAction.move(to: target, duration: 0.34); fly.timingMode = .easeInEaseOut
        token.run(.sequence([
            lift,
            .group([fly, .rotate(toAngle: 0, duration: 0.34, shortestUnitArc: true)]),
            .run { [weak self, weak token] in
                token?.zPosition = 5; token?.squash(0.14); self?.playTumble()
            }
        ]))
        tone(.single(10, .clay.with(body: 0.14, amplitude: 0.06, noiseGain: 0.2)), key: "return", minInterval: 0.08)
        HapticsManager.shared.impact(style: .light, intensity: 0.18)
    }

    // MARK: - Particles

    private func spawnDust(at p: CGPoint, color: UIColor) {
        guard !AmbientAnimator.reduceMotion else { return }
        let woodDust = Int.random(in: 3...5)
        for _ in 0..<woodDust {
            let m = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.4...3))
            m.fillColor = WarmShelfPalette.sand.withAlpha(.random(in: 0.4...0.7)); m.strokeColor = .clear
            m.position = CGPoint(x: p.x + .random(in: -tokenR * 0.6...tokenR * 0.6), y: p.y - tokenR * 0.4)
            m.zPosition = 1
            particleLayer.addChild(m)
            m.run(.sequence([.group([.moveBy(x: .random(in: -14...14), y: .random(in: -2...10), duration: .random(in: 0.3...0.5)), .fadeOut(withDuration: 0.35), .scale(to: 0.4, duration: 0.35)]), .removeFromParent()])) }
        for _ in 0..<Int.random(in: 2...4) {
            let m = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.6...3))
            m.fillColor = color.withAlpha(.random(in: 0.4...0.7)); m.strokeColor = .clear
            m.position = CGPoint(x: p.x + .random(in: -tokenR * 0.5...tokenR * 0.5), y: p.y)
            m.zPosition = 1
            particleLayer.addChild(m)
            m.run(.sequence([.group([.moveBy(x: .random(in: -12...12), y: .random(in: 6...20), duration: .random(in: 0.3...0.5)), .fadeOut(withDuration: 0.35)]), .removeFromParent()]))
        }
    }

    private func spawnMotes(at p: CGPoint, color: UIColor, count: Int) {
        guard !AmbientAnimator.reduceMotion else { return }
        for _ in 0..<min(12, count) {
            let m = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.6...3.2))
            m.fillColor = color.withAlpha(.random(in: 0.45...0.7)); m.strokeColor = .clear
            m.blendMode = .add
            m.position = CGPoint(x: p.x + .random(in: -tokenR * 0.7...tokenR * 0.7), y: p.y + .random(in: -tokenR * 0.4...tokenR * 0.4))
            m.zPosition = 1
            particleLayer.addChild(m)
            m.run(.sequence([.group([.moveBy(x: .random(in: -10...10), y: .random(in: 14...30), duration: .random(in: 0.7...1.1)), .fadeOut(withDuration: 0.9), .scale(to: 0.4, duration: 0.9)]), .removeFromParent()]))
        }
    }

    // MARK: - Sound

    private func tone(_ spec: LullToneEngine.Spec, key: String, minInterval: TimeInterval = 0) {
        guard AudioManager.shared.isEnabled else { return }
        if minInterval > 0 {
            let now = CACurrentMediaTime()
            if let last = lastTone[key], now - last < minInterval { return }
            lastTone[key] = now
        }
        LullToneEngine.shared.play(spec, cacheKey: "dropdots.\(key)")
    }

    private func playFallWhoosh() {
        tone(.single(9, .breath.with(body: 0.2, amplitude: 0.035, noiseGain: 0.7)), key: "fall", minInterval: 0.05)
    }
    /// Approved delight: honest weight. The more dots already under it, the deeper the
    /// thunk — physical truth in sound, a toddler's first bar chart for the ear.
    /// A golden dot hums a true fifth above (pitch 1.5 — degree math can't reach it).
    private func playLandThunk(fill: Int = 1, golden: Bool = false) {
        guard AudioManager.shared.isEnabled else { return }
        let clayDegree = max(0, 4 - fill)                          // 3,2,1,0 down the pentatonic
        let pitch = golden ? 1.5 : 1.0
        let woodPitch = pitch * (1.0 - Double(fill - 1) * 0.04)    // resonance keeps sinking below degree 0
        // The engine caches rendered buffers by KEY — every fill/golden variant needs its own.
        LullToneEngine.shared.playSequence([
            (spec: .single(clayDegree, .clay.with(body: 0.26 + Double(fill) * 0.03, amplitude: 0.1), pitch: pitch),
             delay: 0, cacheKey: "dropdots.land.t\(fill)\(golden ? ".g" : "")"),
            (spec: .single(0, .wood.with(body: 0.44, amplitude: 0.05), pitch: woodPitch),
             delay: 0.06, cacheKey: "dropdots.land.r\(fill)\(golden ? ".g" : "")")
        ])
    }
    private func playTumble() {
        tone(.single(Int.random(in: 1...5), .clay.with(body: 0.14, amplitude: 0.05)), key: "tumble", minInterval: 0.04)
    }

    // MARK: - Accessibility

    override func accessibilityElements(in view: SKView) -> [UIAccessibilityElement] {
        var elements = super.accessibilityElements(in: view)
        guard cell > 1 else { return elements }
        for (i, slot) in traySlots.enumerated() where trayTokens[i] != nil {
            let name = trayTokens[i].map { DropDotToken.feltNames[$0.feltIndex] } ?? ""
            elements.append(makeActivatableAccessibilityElement(
                in: view, label: "\(name.isEmpty ? "Dot" : name.capitalized + " dot") — drop it into the board", scenePosition: slot,
                size: CGSize(width: tokenR * 3, height: tokenR * 3), traits: .button
            ) { [weak self] in
                guard let self, self.dragToken == nil, let token = self.trayTokens[i] else { return }
                if let col = (0..<self.cols).first(where: { self.hasSpace($0) }) {
                    self.dropIntoColumn(token, col: col, fromSlot: i)
                }
            })
        }
        elements.append(makeActivatableAccessibilityElement(
            in: view, label: "Pull tab — tip all the dots out", scenePosition: CGPoint(x: resetTabRect.midX, y: resetTabRect.midY),
            size: CGSize(width: resetTabRect.width, height: resetTabRect.height), traits: .button
        ) { [weak self] in
            self?.triggerReset()
        })
        return elements
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self { min(max(self, limits.lowerBound), limits.upperBound) }
}
