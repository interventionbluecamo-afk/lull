import SpriteKit
import QuartzCore

/// Sleepy Drop Box — a beloved wooden posting box that likes being fed little treasures. Drop a
/// piece into its matching felt-lined opening and it disappears inside with a muffled thunk;
/// pull the drawer and the same four treasures tumble softly back out. Shape fit is visible
/// through the toy's physical response, with no scores or spoken error messages.
///
/// There is no SpriteKit physics here: every motion is authored, so a treasure can never get
/// stuck, fly offscreen, or rattle out of control.
final class SleepyDropBoxScene: BaseToyScene {

    override var firstSessionHintKey: String? { "hint.sleepyDropBox" }
    override func firstSessionHintPoint() -> CGPoint { treasures.first?.position ?? CGPoint(x: size.width / 2, y: size.height * 0.2) }

    // Layers
    private let boxLayer = SKNode()       // floor, back body (behind everything)
    private let frontLayer = SKNode()     // the body's front: mass, sleepy face, drawer, feet
    private let panelLayer = SKNode()     // the lit play-panel + the 2×2 carved holes (in front of the face)
    private let pieceLayer = SKNode()
    private let drawer = SKNode()

    // Box face
    private let eyeL = SKShapeNode(), eyeR = SKShapeNode()
    private let mouth = SKShapeNode()
    private let blushL = SKShapeNode(), blushR = SKShapeNode()
    private enum BoxMood { case sleepy, curious, happy, surprised }
    private var mood: BoxMood = .sleepy

    // Openings
    private enum HoleShape { case round, triangle, square, star }
    private struct Opening {
        let center: CGPoint
        let size: CGSize
        let felt: UIColor
        let shape: HoleShape
        let accepts: DropTreasureNode.Kind   // physical plausibility — which treasure fits here
        var rim: SKShapeNode?
    }
    private var openings: [Opening] = []

    // Treasures
    private var treasures: [DropTreasureNode] = []
    private var insideKinds: [DropTreasureNode.Kind] = []
    private var playSpots: [CGPoint] = []
    private let pieceKinds: [DropTreasureNode.Kind] = [.berry, .triangle, .cube, .star]
    private var playSlotOrder = [0, 1, 2, 3]
    private var returningDestinations: [DropTreasureNode.Kind: CGPoint] = [:]

    // Touch
    private var dragTouch: UITouch?
    private weak var dragPiece: DropTreasureNode?
    private var dragOffset = CGPoint.zero
    private var dragTarget = CGPoint.zero
    private var hoverOpening: Int?

    private var drawerTouch: UITouch?
    private var drawerClosedY: CGFloat = 0
    private var drawerOpenY: CGFloat = 0
    private var drawerTargetY: CGFloat = 0
    private var drawerKnobLocalY: CGFloat = 0
    private var didTumbleThisPull = false
    private var drawerTouchStartY: CGFloat = 0
    private var drawerDragStartY: CGFloat = 0

    private var lastTone: [String: TimeInterval] = [:]
    private var lastRattle: TimeInterval = 0
    private let woodWarm = UIColor(hex: 0xCFB18A)   // quiet birch bulk
    private let woodTop = UIColor(hex: 0xE5CFAC)    // softly lit front and tray
    private let woodDark = UIColor(hex: 0x866648)   // warm recessed grain

    private var boxCenter = CGPoint.zero
    private var panelCenter = CGPoint.zero
    private var boxW: CGFloat = 0
    private var boxH: CGFloat = 0
    private weak var boxFaceRef: SKNode?   // the front mass (or art body), scaled for body wobble
    private var pieceRadius: CGFloat = 30
    private var faceScale: CGFloat = 1   // the art body's front panel wears a tighter face
    private var faceHeight: CGFloat = 0
    private var usesPlainShell = false

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        AudioManager.shared.prewarm(prefixes: ["sleepy.", "box."])
        ambientMoteInterval = 1.4
        boxLayer.zPosition = 5; addChild(boxLayer)
        frontLayer.zPosition = 8; addChild(frontLayer)
        panelLayer.zPosition = 10; addChild(panelLayer)
        pieceLayer.zPosition = 12; addChild(pieceLayer)
        rebuild()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 160, size.height > 160, boxW > 0 else { return }
        // A rotation keeps posted shapes inside and preserves the child's loose arrangement.
        // Rebuilding the full set also completes a partly animated drawer return safely.
        let savedInside = insideKinds
        let savedOutside = pieceKinds.compactMap { kind -> (kind: DropTreasureNode.Kind, position: CGPoint)? in
            guard !savedInside.contains(kind),
                  let position = returningDestinations[kind] ?? treasures.first(where: { $0.kind == kind })?.position else {
                return nil
            }
            return (kind: kind,
                    position: CGPoint(x: position.x / max(1, oldSize.width),
                                      y: position.y / max(1, oldSize.height)))
        }
        let drawerWasOpen = drawer.position.y < drawerClosedY - (drawerClosedY - drawerOpenY) * 0.65
        rebuild()
        insideKinds = savedInside
        for kind in savedInside {
            if let idx = treasures.firstIndex(where: { $0.kind == kind }) {
                treasures[idx].removeFromParent()
                treasures.remove(at: idx)
            }
        }
        for saved in savedOutside {
            guard let piece = treasures.first(where: { $0.kind == saved.kind }) else { continue }
            let inset = pieceRadius * 1.25
            piece.position = CGPoint(
                x: (saved.position.x * size.width).clamped(to: inset...(size.width - inset)),
                y: (saved.position.y * size.height).clamped(to: inset...(size.height - inset))
            )
        }
        if drawerWasOpen {
            drawer.position.y = drawerOpenY
            drawerTargetY = drawerOpenY
            didTumbleThisPull = true
        }
    }

    // MARK: - Build

    private func rebuild() {
        guard size.width > 160, size.height > 160 else { return }
        removeAction(forKey: "lullaby")
        removeAction(forKey: "box.sleep")
        removeAction(forKey: "drawer.close")
        for kind in pieceKinds { removeAction(forKey: "drawer.return.\(kind)") }
        boxLayer.removeAllChildren(); frontLayer.removeAllChildren(); panelLayer.removeAllChildren(); pieceLayer.removeAllChildren()
        drawer.removeFromParent(); drawer.removeAllActions(); drawer.removeAllChildren()
        treasures.removeAll(); insideKinds.removeAll(); openings.removeAll()
        returningDestinations.removeAll()
        dragTouch = nil; dragPiece = nil; drawerTouch = nil; hoverOpening = nil

        let landscape = size.width > size.height
        // The toy dominates the scene: a big chunky posting box sitting close to the child, with
        // very little empty space above it. Pieces and openings are sized from one shared radius
        // so a treasure always visibly belongs to its hole.
        boxW = min(size.width * (landscape ? 0.62 : 0.90), 680)
        boxH = min(size.height * (landscape ? 0.64 : 0.54), 560)
        boxCenter = CGPoint(x: size.width / 2, y: size.height * (landscape ? 0.60 : 0.605))
        // Remove the generated PNG's transparent margins before any layout calculation.
        let shellTex = ToyArt.texture("sleepybox-v2-shell").map {
            SKTexture(rect: CGRect(x: 128.0 / 1315.0, y: 116.0 / 1196.0,
                                   width: 1065.0 / 1315.0, height: 946.0 / 1196.0), in: $0)
        }
        let bodyTex = ToyArt.texture("sleepybox-body")
        usesPlainShell = shellTex != nil
        if let tex = shellTex ?? bodyTex {
            let artSize = tex.size()
            let scale = min(boxW / max(1, artSize.width), boxH / max(1, artSize.height))
            boxW = artSize.width * scale
            boxH = artSize.height * scale
        }
        pieceRadius = min(min(boxW * 0.105, size.width * 0.10), 50)

        buildContactShadow()
        if let shellTex {
            usesPlainShell = true
            buildPlainShell(shellTex)
        } else if let bodyTex {
            usesPlainShell = false
            // Warm Clay box (Docs/SleepyBoxSlice.md): one authored body carries the holes
            // and drawer slot; the living face and all interactions stay procedural.
            faceScale = 0.78
            buildArtBox(bodyTex)
        } else {
            usesPlainShell = false
            faceScale = 1
            buildBackBody()
            buildFrontFace()
            buildDrawer()
            buildPlayPanel()
            buildOpenings()
        }
        buildPlaySpotsAndTreasures()
        #if DEBUG
        // QA: open the drawer on launch so the pulled state can be screenshot (sim can't drag).
        if ProcessInfo.processInfo.environment["LULL_DEBUG_DROPBOX_OPEN"] == "1" {
            drawerTargetY = drawerOpenY
        }
        #endif
    }

    /// The new material plate contains only the wooden shell. All sockets, the living
    /// face and the single drawer share one measured coordinate system in code.
    private func buildPlainShell(_ tex: SKTexture) {
        let ts = tex.size()
        let scale = min(boxW / max(1, ts.width), boxH / max(1, ts.height))
        let shell = SKSpriteNode(texture: tex)
        shell.size = CGSize(width: ts.width * scale, height: ts.height * scale)
        shell.position = boxCenter
        shell.zPosition = 0
        frontLayer.addChild(shell)
        boxFaceRef = shell

        // Height can constrain the plate in landscape. Use its rendered dimensions
        // rather than the requested bounding box to size every physical part.
        boxW = shell.size.width
        boxH = shell.size.height
        pieceRadius = min(pieceRadius, boxW * 0.105)
        faceScale = 0.78
        panelCenter = CGPoint(x: boxCenter.x, y: boxCenter.y + boxH * 0.16)
        buildOpenings()

        let faceAnchor = SKNode()
        faceAnchor.position = CGPoint(x: boxCenter.x, y: boxCenter.y - boxH * 0.21)
        faceAnchor.zPosition = 0.5
        frontLayer.addChild(faceAnchor)
        buildFace(on: faceAnchor, faceH: boxH * 0.20)
        buildDrawer()
    }

    /// The authored box: openings, face zone and drawer slot are measured fractions of
    /// the art (y measured from the art's top edge — see the keyed `sleepybox-body.png`).
    private func buildArtBox(_ tex: SKTexture) {
        let ts = tex.size()
        let artScale = min(boxW / max(1, ts.width), boxH / max(1, ts.height))
        let sprite = SKSpriteNode(texture: tex)
        sprite.size = CGSize(width: ts.width * artScale, height: ts.height * artScale)
        sprite.position = boxCenter
        sprite.zPosition = 0
        frontLayer.addChild(sprite)
        boxFaceRef = sprite

        let f = sprite.frame
        // The old portrait plate becomes much narrower when height-limited. Treasures
        // still visibly fit its openings in either orientation.
        pieceRadius = min(pieceRadius, f.width * 0.11)
        // Fractions measured from the v2 body art (2026-06-11 Codex regen: upright
        // honey-gold star, frontal square, no blue anywhere).
        let specs: [(fx: CGFloat, fy: CGFloat, felt: UIColor, shape: HoleShape, accepts: DropTreasureNode.Kind)] = [
            (0.267, 0.185, WarmShelfPalette.rhubarb, .round,    .berry),
            (0.709, 0.210, UIColor(hex: 0xE3A93E),   .triangle, .triangle),
            (0.266, 0.486, WarmShelfPalette.sage,    .square,   .cube),
            (0.702, 0.500, UIColor(hex: 0xD9A437),   .star,     .star)
        ]
        let holeSide = f.width * 0.25
        for s in specs {
            let center = CGPoint(x: f.minX + s.fx * f.width, y: f.maxY - s.fy * f.height)
            var opening = Opening(center: center, size: CGSize(width: holeSide, height: holeSide),
                                  felt: s.felt, shape: s.shape, accepts: s.accepts, rim: nil)
            // Only the hover ring is drawn — the carved socket itself is in the art.
            let hover = openingShape(s.shape, size: CGSize(width: holeSide * 1.32, height: holeSide * 1.32))
            hover.fillColor = .clear
            hover.strokeColor = s.felt.withAlpha(0.0)
            hover.lineWidth = max(3, holeSide * 0.1)
            hover.position = center
            hover.zPosition = 0.4
            panelLayer.addChild(hover)
            opening.rim = hover
            openings.append(opening)
        }
        panelCenter = CGPoint(x: f.midX, y: f.maxY - 0.34 * f.height)

        // The sleepy face sits in the blank band below the holes (ends ~0.56) and
        // above the drawer panel (begins ~0.77) on the v2 art.
        let faceAnchor = SKNode()
        faceAnchor.position = CGPoint(x: f.midX, y: f.maxY - 0.665 * f.height)
        faceAnchor.zPosition = 0.5
        frontLayer.addChild(faceAnchor)
        buildFace(on: faceAnchor, faceH: f.height * 0.22)

        // ONE drawer (founder, June 15: the baked body had a drawer face AND the tray slid
        // out below → two drawers). Same model as the procedural box now: a dark cavity
        // sits IN FRONT of the body art, hiding its baked drawer face; the tray rides in
        // front of the cavity as the single front and slides down to reveal it.
        drawerClosedY = f.maxY - 0.87 * f.height
        drawerOpenY = drawerClosedY - boxH * 0.32
        drawerTargetY = drawerClosedY
        // The widths must nest: drawer-front ≥ cavity ≥ the body art's baked slot (~0.63·w),
        // or either the slot edges peek (open) or the cavity peeks (closed). So the cavity
        // covers the baked slot, and the tray is fit wide enough that its visible front
        // (the art has padding) covers the cavity.
        let drawerW = f.width * 0.74, drawerH = f.height * 0.255
        // Paint over the body art's baked drawer slot with matching wood, so its dark
        // recesses can't peek beside our own clean cavity + tray (founder: the two art
        // pieces' slot widths don't match — a code patch until the body art is regenned).
        let patch = SKShapeNode(rect: CGRect(x: -f.width * 0.42, y: -f.height * 0.16, width: f.width * 0.84, height: f.height * 0.30), cornerRadius: f.height * 0.03)
        patch.fillColor = woodWarm; patch.strokeColor = .clear
        patch.position = CGPoint(x: f.midX, y: drawerClosedY + f.height * 0.02)
        patch.zPosition = 0.08
        ProceduralTexture.applyClayFill(to: patch, base: woodWarm, size: CGSize(width: f.width * 0.84, height: f.height * 0.30))
        frontLayer.addChild(patch)
        let cavW = f.width * 0.55, cavH = f.height * 0.19
        let cavity = SKShapeNode(rect: CGRect(x: -cavW / 2, y: -cavH / 2, width: cavW, height: cavH), cornerRadius: cavH * 0.3)
        cavity.fillColor = UIColor(hex: 0x241509).withAlpha(0.94); cavity.strokeColor = .clear
        cavity.position = CGPoint(x: f.midX, y: drawerClosedY)
        cavity.zPosition = 0.12   // in front of the body art → covers its baked drawer face
        frontLayer.addChild(cavity)
        if let art = ToyArt.sprite("sleepybox-drawer", fit: CGSize(width: drawerW, height: drawerH)) {
            art.zPosition = 0
            drawer.addChild(art)
            drawerKnobLocalY = -art.size.height * 0.1
        }
        drawer.position = CGPoint(x: f.midX, y: drawerClosedY)
        drawer.zPosition = 0.4   // the one front, over the cavity; slides down to open
        frontLayer.addChild(drawer)
        idleInviteDrawer()
    }

    private func buildContactShadow() {
        let roomTex = ToyArt.texture("shelfroom-v2-day").map {
            // The lower portion puts the wall/floor seam behind the work area; the
            // uncropped square plate would make the box appear halfway up a wall.
            SKTexture(rect: CGRect(x: 0, y: 0, width: 1, height: 0.46), in: $0)
        }
        if let floorTex = roomTex ?? ToyArt.texture("sleepybox-floor") {
            // The authored playroom floor — over-zoomed so the baked corner furniture
            // crops away, plus a warm hush wash: the floor stays a floor, the box is
            // the show (playtest: background was competing).
            let plate = SKSpriteNode(texture: floorTex)
            let ts = floorTex.size()
            let plateScale = max(size.width / max(1, ts.width), size.height / max(1, ts.height)) * (roomTex == nil ? 1.18 : 1)
            plate.size = CGSize(width: ts.width * plateScale, height: ts.height * plateScale)
            plate.position = CGPoint(x: size.width / 2, y: size.height / 2)
            plate.zPosition = -0.95
            boxLayer.addChild(plate)
            let hush = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            // Founder rounds 2+3 (June 12): still competing — the wash goes nearly
            // opaque so the floor is only a breath of warmth. The box is the show.
            hush.fillColor = WarmShelfPalette.warmCream.withAlpha(roomTex == nil ? 0.84 : 0.10)
            hush.strokeColor = .clear
            hush.zPosition = -0.9
            boxLayer.addChild(hush)
        } else {
            // A soft warm floor plane the toy sits on — grounds it in a little playroom, not a void.
            // It bleeds off the sides so there's no hard oval edge, just a band of warmth under the toy.
            let floor = SKShapeNode(ellipseOf: CGSize(width: size.width * 1.5, height: boxH * 1.5))
            floor.fillColor = WarmShelfPalette.warmCream.withAlpha(0.55)
            floor.strokeColor = .clear
            floor.position = CGPoint(x: boxCenter.x, y: boxCenter.y - boxH * 0.42)
            floor.zPosition = -0.9
            boxLayer.addChild(floor)
            let floorCore = SKShapeNode(ellipseOf: CGSize(width: size.width * 1.1, height: boxH * 0.8))
            floorCore.fillColor = WarmShelfPalette.sand.withAlpha(0.18)
            floorCore.strokeColor = .clear
            floorCore.position = CGPoint(x: boxCenter.x, y: boxCenter.y - boxH * 0.5)
            floorCore.zPosition = -0.85
            boxLayer.addChild(floorCore)
        }

        // The board's own deep contact shadow onto that floor — heavy and soft, so it sits, never floats.
        let shadow = SKSpriteNode(texture: ProceduralTexture.softClayShadow(size: CGSize(width: boxW * 1.18, height: boxH * 0.52)))
        shadow.position = CGPoint(x: boxCenter.x, y: boxCenter.y - boxH * 0.5)
        shadow.zPosition = -0.5
        shadow.alpha = usesPlainShell ? 0.48 : 0.95
        boxLayer.addChild(shadow)
    }

    /// One solid wooden bulk behind the lit top plate and the front — so the box reads as a single
    /// chunky object, never two stacked pillows. Any gap between plates reveals this body, not floor.
    private func buildBackBody() {
        let topY = boxCenter.y + boxH * 0.5
        let botY = boxCenter.y - boxH * 0.5
        let h = topY - botY
        let rect = CGRect(x: -boxW / 2, y: -h / 2, width: boxW, height: h)
        let body = SKShapeNode(rect: rect, cornerRadius: min(boxW, h) * 0.17)
        body.fillColor = woodWarm
        body.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.24)
        body.lineWidth = 2.5
        body.position = CGPoint(x: boxCenter.x, y: (topY + botY) / 2)
        body.zPosition = -0.08
        boxLayer.addChild(body)
        ProceduralTexture.applyClayFill(to: body, base: woodWarm, size: CGSize(width: boxW, height: h))
        ProceduralTexture.addSoftGrainLines(to: body, in: rect.insetBy(dx: boxW * 0.1, dy: h * 0.12),
                                            count: 7, color: WarmShelfPalette.cocoa, alpha: 0.02...0.045, zPosition: 0.05)
        // A soft shaded lower band — the box rolls into shadow toward the floor (gives it bulk).
        let lowerShade = SKShapeNode(rect: CGRect(x: rect.minX, y: rect.minY, width: boxW, height: h * 0.26), cornerRadius: min(boxW, h) * 0.15)
        lowerShade.fillColor = woodDark.withAlpha(0.26); lowerShade.strokeColor = .clear; lowerShade.zPosition = 0.06
        body.addChild(lowerShade)
    }

    private func buildPlayPanel() {
        // The hero surface: a big lit play-panel set into the top of the box, holding the 2×2 grid
        // of large carved holes. A recessed darker frame makes it read as sunk into the wood.
        let panelW = boxW * 0.86, panelH = boxH * 0.52
        let center = CGPoint(x: boxCenter.x, y: boxCenter.y + boxH * 0.19)
        panelCenter = center

        let frame = SKShapeNode(rect: CGRect(x: -panelW / 2 - 7, y: -panelH / 2 - 7, width: panelW + 14, height: panelH + 14), cornerRadius: panelH * 0.22)
        frame.fillColor = woodDark.withAlpha(0.55)
        frame.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.16)
        frame.lineWidth = 2
        frame.position = center
        frame.zPosition = 0
        panelLayer.addChild(frame)

        let rect = CGRect(x: -panelW / 2, y: -panelH / 2, width: panelW, height: panelH)
        let panel = SKShapeNode(rect: rect, cornerRadius: panelH * 0.18)
        panel.fillColor = woodTop
        panel.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.12)
        panel.lineWidth = 1.5
        panel.position = center
        panel.zPosition = 0.05
        panelLayer.addChild(panel)
        ProceduralTexture.applyClayFill(to: panel, base: woodTop, size: CGSize(width: panelW, height: panelH))
        ProceduralTexture.addSoftGrainLines(to: panel, in: rect.insetBy(dx: panelW * 0.08, dy: panelH * 0.12),
                                            count: 6, color: WarmShelfPalette.cocoa, alpha: 0.02...0.045, zPosition: 0.08)
        let hi = SKShapeNode(rect: CGRect(x: rect.minX + panelH * 0.22, y: rect.maxY - panelH * 0.085,
                                          width: panelW - panelH * 0.44, height: panelH * 0.045), cornerRadius: panelH * 0.02)
        hi.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.32)
        hi.strokeColor = .clear; hi.zPosition = 0.1
        panel.addChild(hi)
    }

    private func buildOpenings() {
        let r = pieceRadius
        let dx = boxW * 0.22, dy = boxH * 0.16
        let c = panelCenter
        // The hero: four big carved sockets in a 2×2 grid. Each hole's silhouette and rim colour
        // match its treasure, so "this one goes here" reads instantly. Fit is by shape, never colour.
        // The triangle/star bounding boxes run larger so their pointier silhouettes read as boldly
        // as the round and square — the four holes feel evenly weighted.
        let specs: [(pos: CGPoint, size: CGSize, felt: UIColor, shape: HoleShape, accepts: DropTreasureNode.Kind)] = [
            (CGPoint(x: c.x - dx, y: c.y + dy), CGSize(width: r * 2.24, height: r * 2.24), WarmShelfPalette.rhubarb,   .round,    .berry),
            (CGPoint(x: c.x + dx, y: c.y + dy), CGSize(width: r * 2.40, height: r * 2.20), UIColor(hex: 0xE3A93E),     .triangle, .triangle),
            (CGPoint(x: c.x - dx, y: c.y - dy), CGSize(width: r * 2.12, height: r * 2.12), WarmShelfPalette.sage,      .square,   .cube),
            (CGPoint(x: c.x + dx, y: c.y - dy), CGSize(width: r * 2.30, height: r * 2.30), WarmShelfPalette.waterBlue, .star,     .star)
        ]
        for spec in specs {
            var opening = Opening(center: spec.pos, size: spec.size,
                                  felt: usesPlainShell ? woodDark : spec.felt,
                                  shape: spec.shape, accepts: spec.accepts, rim: nil)
            buildCarvedOpening(&opening)
            openings.append(opening)
        }
    }

    /// One carved toy socket: an outer bevel shadow, a thick colour rim with a lit upper edge, then
    /// a warm-dark recessed cavity with a gathered inner shadow and a faintly lit floor — an
    /// inviting hole with real depth, never a flat black blob.
    private func buildCarvedOpening(_ opening: inout Opening) {
        let s = opening.size, c = opening.center, felt = opening.felt, shape = opening.shape

        // Outer bevel shadow under the rim — seats the socket into the panel.
        let bevelScale: CGFloat = usesPlainShell ? 1.16 : 1.5
        let bevel = openingShape(shape, size: CGSize(width: s.width * bevelScale, height: s.height * bevelScale))
        bevel.fillColor = woodDark.withAlpha(usesPlainShell ? 0.28 : 0.55)
        bevel.strokeColor = .clear
        bevel.position = CGPoint(x: c.x, y: c.y - s.height * 0.06)
        bevel.zPosition = 0.16
        panelLayer.addChild(bevel)

        // Thick colour rim.
        let rimScale: CGFloat = usesPlainShell ? 1.10 : 1.32
        let rimSize = CGSize(width: s.width * rimScale, height: s.height * rimScale)
        let rim = openingShape(shape, size: rimSize)
        rim.fillColor = usesPlainShell ? woodTop : felt
        rim.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.2)
        rim.lineWidth = 1.5
        rim.position = c
        rim.zPosition = 0.2
        panelLayer.addChild(rim)
        ProceduralTexture.applyClayFill(to: rim, base: usesPlainShell ? woodTop : felt, size: rimSize)

        // Lit upper edge of the rim (a soft carved bevel highlight).
        let rimHi = openingShape(shape, size: rimSize)
        rimHi.fillColor = .clear
        rimHi.strokeColor = WarmShelfPalette.paperHighlight.withAlpha(usesPlainShell ? 0.28 : 0.5)
        rimHi.lineWidth = max(2, s.height * (usesPlainShell ? 0.025 : 0.06))
        rimHi.position = CGPoint(x: c.x, y: c.y + s.height * 0.05)
        rimHi.zPosition = 0.22
        panelLayer.addChild(rimHi)

        // A warm brown felt-lined cavity — recessed and soft, never a pure-black cutout.
        let cavity = openingShape(shape, size: s)
        cavity.fillColor = UIColor(hex: 0x47291A)
        cavity.strokeColor = .clear
        cavity.position = c
        cavity.zPosition = 0.3
        panelLayer.addChild(cavity)
        ProceduralTexture.applyClayFill(to: cavity, base: UIColor(hex: 0x47291A), size: s)

        // A shape-matched inner shadow, slightly smaller and centred, so the socket reads as a clean
        // carved recess — no stray oval floating inside the triangle or star. The clay fill on the
        // cavity supplies the rest of the depth.
        let inner = openingShape(shape, size: CGSize(width: s.width * 0.7, height: s.height * 0.7))
        inner.fillColor = UIColor(hex: 0x2A1710).withAlpha(0.45)
        inner.strokeColor = .clear
        inner.position = CGPoint(x: c.x, y: c.y + s.height * 0.05)
        inner.zPosition = 0.31
        if !usesPlainShell { panelLayer.addChild(inner) }
        // A soft top-inner lip of light, the same silhouette, so the upper edge catches the room.
        let lip = openingShape(shape, size: s)
        lip.fillColor = .clear
        lip.strokeColor = WarmShelfPalette.paperHighlight.withAlpha(0.13)
        lip.lineWidth = max(1.5, s.height * 0.05)
        lip.position = CGPoint(x: c.x, y: c.y + s.height * 0.04)
        lip.zPosition = 0.33
        panelLayer.addChild(lip)

        // The hover ring (warms while a matching piece is held over the hole).
        let hover = openingShape(shape, size: rimSize)
        hover.fillColor = .clear
        hover.strokeColor = felt.withAlpha(0.0)
        hover.lineWidth = max(3, s.height * 0.1)
        hover.position = c
        hover.zPosition = 0.4
        panelLayer.addChild(hover)
        opening.rim = hover
    }

    private func openingShape(_ shape: HoleShape, size s: CGSize) -> SKShapeNode {
        switch shape {
        case .round:    return SKShapeNode(ellipseOf: s)
        case .triangle: return SKShapeNode(path: DropTreasureNode.roundedTrianglePath(radius: max(s.width, s.height) * 0.62, corner: max(s.width, s.height) * 0.17))
        case .square:   return SKShapeNode(rectOf: s, cornerRadius: s.width * 0.28)
        case .star:     return SKShapeNode(path: DropTreasureNode.softStarPath(outer: max(s.width, s.height) * 0.58, inner: max(s.width, s.height) * 0.4, points: 5))
        }
    }

    private func buildFrontFace() {
        // The main mass — drawn in front so a posted treasure slides behind it and vanishes.
        let faceCenter = CGPoint(x: boxCenter.x, y: boxCenter.y - boxH * 0.18)
        let faceH = boxH * 0.66
        let rect = CGRect(x: -boxW / 2, y: -faceH / 2, width: boxW, height: faceH)
        let radius = min(boxW, faceH) * 0.26
        // No outline: the front shares the body's wood, so the box stays one mass. The lit top
        // plate above and a soft fold shadow give the only visible top-front edge.
        let face = SKShapeNode(rect: rect, cornerRadius: radius)
        face.strokeColor = .clear
        face.lineWidth = 0
        face.position = faceCenter
        face.zPosition = 0
        frontLayer.addChild(face)
        boxFaceRef = face
        ProceduralTexture.applyClayFill(to: face, base: woodWarm, size: CGSize(width: boxW, height: faceH))
        ProceduralTexture.addSoftGrainLines(to: face, in: rect.insetBy(dx: boxW * 0.08, dy: faceH * 0.12),
                                            count: 8, color: WarmShelfPalette.cocoa, alpha: 0.02...0.05, zPosition: 0.1)
        // A broad lit bevel across the top of the face — the chunky front catches the light.
        let bevel = SKShapeNode(rect: CGRect(x: rect.minX + radius, y: rect.maxY - faceH * 0.2, width: boxW - radius * 2, height: faceH * 0.13), cornerRadius: radius * 0.5)
        bevel.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.3); bevel.strokeColor = .clear; bevel.zPosition = 0.2
        face.addChild(bevel)
        // The front rolls into soft shadow at its base — gives the mass real volume, not a flat panel.
        let baseShade = SKShapeNode(rect: CGRect(x: rect.minX + radius * 0.6, y: rect.minY + faceH * 0.02, width: boxW - radius * 1.2, height: faceH * 0.24), cornerRadius: radius * 0.6)
        baseShade.fillColor = woodDark.withAlpha(0.22); baseShade.strokeColor = .clear; baseShade.zPosition = 0.12
        face.addChild(baseShade)
        // The lit top plate meets the front here — a soft fold shadow is the box's only top edge.
        let fold = SKShapeNode(rect: CGRect(x: rect.minX + radius * 0.4, y: rect.maxY - faceH * 0.055,
                                            width: boxW - radius * 0.8, height: faceH * 0.055), cornerRadius: radius * 0.3)
        fold.fillColor = woodDark.withAlpha(0.28); fold.strokeColor = .clear; fold.zPosition = 0.19
        face.addChild(fold)

        // Peg feet.
        for sx in [-boxW * 0.32, boxW * 0.32] {
            let foot = SKShapeNode(ellipseOf: CGSize(width: boxW * 0.1, height: boxH * 0.1))
            foot.fillColor = woodDark
            foot.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.14)
            foot.lineWidth = 1
            foot.position = CGPoint(x: faceCenter.x + sx, y: faceCenter.y - faceH * 0.5)
            foot.zPosition = -0.5
            frontLayer.addChild(foot)
        }

        buildFace(on: face, faceH: faceH)
    }

    private func buildFace(on face: SKNode, faceH: CGFloat) {
        faceHeight = faceH
        let eyeY = faceH * 0.1
        let eyeDX = boxW * 0.145 * faceScale
        let ink = WarmShelfPalette.cocoa.withAlpha(0.6)
        for (eye, sign) in [(eyeL, CGFloat(-1)), (eyeR, CGFloat(1))] {
            eye.strokeColor = ink
            eye.lineWidth = max(2.4, boxW * 0.012)
            eye.lineCap = .round
            eye.fillColor = .clear
            eye.position = CGPoint(x: sign * eyeDX, y: eyeY)
            eye.zPosition = 0.5
            face.addChild(eye)
        }
        mouth.strokeColor = ink
        mouth.lineWidth = max(2.2, boxW * 0.011)
        mouth.lineCap = .round
        mouth.fillColor = .clear
        mouth.position = CGPoint(x: 0, y: eyeY - faceH * 0.16)
        mouth.zPosition = 0.5
        face.addChild(mouth)

        for (blush, sign) in [(blushL, CGFloat(-1)), (blushR, CGFloat(1))] {
            blush.path = CGPath(ellipseIn: CGRect(x: -boxW * 0.05, y: -boxW * 0.035, width: boxW * 0.1, height: boxW * 0.07), transform: nil)
            blush.fillColor = WarmShelfPalette.petal.withAlpha(0.0)
            blush.strokeColor = .clear
            blush.position = CGPoint(x: sign * boxW * 0.24 * faceScale, y: eyeY - faceH * 0.06)
            blush.zPosition = 0.45
            face.addChild(blush)
        }
        setBoxMood(.sleepy, animated: false)
    }

    private func buildDrawer() {
        let faceCenter = CGPoint(x: boxCenter.x, y: boxCenter.y - boxH * 0.18)
        let faceH = boxH * 0.66
        let drawerW = boxW * (usesPlainShell ? 0.926 : 0.56)
        let drawerH = boxH * (usesPlainShell ? 0.205 : 0.24)
        drawerClosedY = usesPlainShell ? boxCenter.y - boxH * 0.365 : faceCenter.y - faceH * 0.30
        drawerOpenY = drawerClosedY - boxH * (usesPlainShell ? 0.22 : 0.32)
        drawerTargetY = drawerClosedY

        // A soft shadow along the slot the drawer sits in — it reads as set into the body.
        let lipShadow = SKShapeNode(rect: CGRect(x: -drawerW / 2 - 3, y: -drawerH * 0.6, width: drawerW + 6, height: drawerH * 0.5), cornerRadius: drawerH * 0.28)
        lipShadow.fillColor = woodDark.withAlpha(0.34)
        lipShadow.strokeColor = .clear
        lipShadow.position = CGPoint(x: faceCenter.x, y: drawerClosedY + drawerH * 0.52)
        lipShadow.zPosition = 0.04
        if !usesPlainShell { frontLayer.addChild(lipShadow) }

        // Cavity behind the drawer (revealed as it slides down).
        let cavity = SKShapeNode(rect: CGRect(x: -drawerW / 2, y: -drawerH / 2, width: drawerW, height: drawerH), cornerRadius: drawerH * 0.22)
        cavity.fillColor = UIColor(hex: 0x241509).withAlpha(0.92)
        cavity.strokeColor = .clear
        cavity.position = CGPoint(x: faceCenter.x, y: drawerClosedY)
        cavity.zPosition = 0.05
        // The new shell already contains the real cavity. Cover it with one moving
        // drawer front, and reveal that authored recess when the child pulls.
        if !usesPlainShell { frontLayer.addChild(cavity) }

        // The drawer itself — a chunky pullable front.
        let body = SKShapeNode(rect: CGRect(x: -drawerW / 2, y: -drawerH / 2, width: drawerW, height: drawerH), cornerRadius: drawerH * 0.26)
        body.fillColor = woodTop
        body.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.2)
        body.lineWidth = 2
        body.zPosition = 0
        drawer.addChild(body)
        ProceduralTexture.applyClayFill(to: body, base: woodTop, size: CGSize(width: drawerW, height: drawerH))
        let dHi = SKShapeNode(rect: CGRect(x: -drawerW * 0.42, y: drawerH * 0.26, width: drawerW * 0.84, height: max(3, drawerH * 0.05)), cornerRadius: 2)
        dHi.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.32); dHi.strokeColor = .clear; dHi.zPosition = 0.2
        body.addChild(dHi)
        // A recessed felt-lined well sunk into the drawer front, with a shaded bottom and a lit near
        // lip — so the drawer reads as a shallow tray that visibly holds the shapes, not a flat patch.
        let wellRect = CGRect(x: -drawerW * 0.4, y: -drawerH * 0.32, width: drawerW * 0.8, height: drawerH * 0.64)
        let well = SKShapeNode(rect: wellRect, cornerRadius: drawerH * 0.2)
        well.fillColor = UIColor(hex: 0x4A2E1C).withAlpha(0.5); well.strokeColor = woodDark.withAlpha(0.4); well.lineWidth = 1.5; well.zPosition = 0.15
        if !usesPlainShell { body.addChild(well) }
        let wellBottom = SKShapeNode(rect: CGRect(x: wellRect.minX, y: wellRect.minY, width: wellRect.width, height: wellRect.height * 0.34), cornerRadius: drawerH * 0.16)
        wellBottom.fillColor = .black.withAlpha(0.16); wellBottom.strokeColor = .clear; wellBottom.zPosition = 0.16
        if !usesPlainShell { body.addChild(wellBottom) }
        let wellLip = SKShapeNode(rect: CGRect(x: wellRect.minX + 6, y: wellRect.maxY - 4, width: wellRect.width - 12, height: 3), cornerRadius: 1.5)
        wellLip.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.3); wellLip.strokeColor = .clear; wellLip.zPosition = 0.17
        if !usesPlainShell { body.addChild(wellLip) }

        // A big round pull-knob with a soft shadow directly beneath it — an easy, inviting target
        // for small fingers, with no offset blob.
        let knobShadow = SKShapeNode(ellipseOf: CGSize(width: drawerH * 0.72, height: drawerH * 0.42))
        knobShadow.fillColor = woodDark.withAlpha(0.3); knobShadow.strokeColor = .clear
        knobShadow.position = CGPoint(x: 0, y: -drawerH * 0.16); knobShadow.zPosition = 0.9
        drawer.addChild(knobShadow)
        let knob = SKShapeNode(circleOfRadius: drawerH * 0.3)
        knob.fillColor = woodDark
        knob.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.22)
        knob.lineWidth = 1.5
        knob.position = CGPoint(x: 0, y: -drawerH * 0.04)
        knob.zPosition = 1
        drawer.addChild(knob)
        let knobHi = SKShapeNode(ellipseOf: CGSize(width: drawerH * 0.24, height: drawerH * 0.18))
        knobHi.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.36); knobHi.strokeColor = .clear
        knobHi.position = CGPoint(x: -drawerH * 0.07, y: drawerH * 0.05); knobHi.zPosition = 1.1
        knob.addChild(knobHi)
        drawerKnobLocalY = -drawerH * 0.04

        drawer.position = CGPoint(x: faceCenter.x, y: drawerClosedY)
        drawer.zPosition = 1
        frontLayer.addChild(drawer)

        idleInviteDrawer()
    }

    private func buildPlaySpotsAndTreasures() {
        let r = pieceRadius
        let landscape = size.width > size.height
        // The tray sits directly beneath the board — no dead gap between toy and treasures.
        let boardBottom = boxCenter.y - boxH * 0.5
        let trayY = max(size.height * (landscape ? 0.12 : 0.115), boardBottom - r * 1.7)
        let n = 4
        // Equal, generous footprints keep all four silhouettes fully on-screen, including
        // the moment a shape grows slightly on pickup. Completed rounds rearrange which
        // shape occupies each footprint; socket fits stay the same.
        let spread = min(boxW * 0.82, size.width - r * 2.6)

        // A real shallow wooden dish the treasures live in — visible back wall, floor, and a lit
        // front lip, so it reads as a thing that HOLDS the shapes (not a floating shadow).
        let dishW = min(spread + r * 2.3, size.width * 0.96)
        let dishH = r * 2.5
        let dishY = trayY - r * 0.15
        let dishBack = SKShapeNode(rect: CGRect(x: -dishW / 2, y: -dishH * 0.5, width: dishW, height: dishH), cornerRadius: dishH * 0.4)
        dishBack.fillColor = woodWarm
        dishBack.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.2)
        dishBack.lineWidth = 2
        dishBack.position = CGPoint(x: size.width / 2, y: dishY)
        dishBack.zPosition = 0.4
        boxLayer.addChild(dishBack)
        ProceduralTexture.applyClayFill(to: dishBack, base: woodWarm, size: CGSize(width: dishW, height: dishH))
        // The hollow interior floor (darker felt) the pieces actually rest on.
        let dishFloor = SKShapeNode(rect: CGRect(x: -dishW / 2 + 7, y: -dishH * 0.42, width: dishW - 14, height: dishH * 0.74), cornerRadius: dishH * 0.32)
        dishFloor.fillColor = UIColor(hex: 0x8A5A28).withAlpha(0.4)
        dishFloor.strokeColor = .clear
        dishFloor.position = dishBack.position
        dishFloor.zPosition = 0.43
        boxLayer.addChild(dishFloor)
        // A lit front lip — the dish's near edge catches the light.
        let dishLip = SKShapeNode(rect: CGRect(x: -dishW / 2 + 5, y: -dishH * 0.5 + 3, width: dishW - 10, height: dishH * 0.14), cornerRadius: dishH * 0.07)
        dishLip.fillColor = woodTop
        dishLip.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.12)
        dishLip.lineWidth = 1
        dishLip.position = dishBack.position
        dishLip.zPosition = 0.46
        boxLayer.addChild(dishLip)

        playSpots = (0..<n).map { i in
            CGPoint(x: size.width / 2 - spread / 2 + spread * CGFloat(i) / CGFloat(n - 1), y: trayY)
        }
        for (i, kind) in pieceKinds.enumerated() {
            // Quiet recesses communicate "these shapes live here" without adding controls.
            let home = SKShapeNode(ellipseOf: CGSize(width: r * 2.05, height: r * 1.30))
            home.fillColor = woodDark.withAlpha(0.10)
            home.strokeColor = woodDark.withAlpha(0.16)
            home.lineWidth = 1
            home.position = CGPoint(x: playSpots[i].x, y: trayY - r * 0.25)
            home.zPosition = 0.44
            boxLayer.addChild(home)
            let piece = DropTreasureNode(kind: kind, radius: r)
            piece.position = playSpots[playSlotOrder[i]]
            piece.zPosition = 12
            pieceLayer.addChild(piece)
            treasures.append(piece)
        }
    }

    // MARK: - Box face moods

    private func setBoxMood(_ newMood: BoxMood, animated: Bool = true) {
        mood = newMood
        let faceH = faceHeight > 0 ? faceHeight : boxH * 0.66
        let w = boxW * 0.125 * faceScale
        let dur = animated ? 0.18 : 0.0

        func sleepyArc() -> CGPath {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -w, y: 0)); p.addQuadCurve(to: CGPoint(x: w, y: 0), control: CGPoint(x: 0, y: -faceH * 0.06))
            return p
        }
        func openEye() -> CGPath {
            CGPath(ellipseIn: CGRect(x: -w * 0.5, y: -w * 0.5, width: w, height: w), transform: nil)
        }
        func smile(_ depth: CGFloat) -> CGPath {
            let p = CGMutablePath(); let mw = boxW * 0.12 * faceScale
            p.move(to: CGPoint(x: -mw, y: 0)); p.addQuadCurve(to: CGPoint(x: mw, y: 0), control: CGPoint(x: 0, y: -faceH * depth))
            return p
        }
        func tinyO() -> CGPath {
            CGPath(ellipseIn: CGRect(x: -w * 0.45, y: -w * 0.55, width: w * 0.9, height: w * 1.1), transform: nil)
        }

        switch newMood {
        case .sleepy:
            eyeL.path = sleepyArc(); eyeR.path = sleepyArc(); mouth.path = smile(0.085)   // a sweeter, wider smile
            fadeBlush(0.2, dur: dur)   // a soft always-on warmth in the cheeks
        case .curious:
            eyeL.path = openEye(); eyeR.path = sleepyArc(); mouth.path = smile(0.06)
            fadeBlush(0.18, dur: dur)
        case .happy:
            eyeL.path = sleepyArc(); eyeR.path = sleepyArc(); mouth.path = smile(0.13)
            fadeBlush(0.5, dur: dur)
        case .surprised:
            eyeL.path = openEye(); eyeR.path = openEye(); mouth.path = tinyO()
            fadeBlush(0.22, dur: dur)
        }
    }

    private func fadeBlush(_ alpha: CGFloat, dur: TimeInterval) {
        for blush in [blushL, blushR] {
            blush.removeAction(forKey: "blush")
            blush.run(.fadeAlpha(to: alpha, duration: max(0.01, dur)), withKey: "blush")
        }
    }

    private func boxBodyWobble(_ intensity: CGFloat) {
        guard !AmbientAnimator.reduceMotion, let face = boxFaceRef else { return }
        // Scale the front mass in place (it pivots at its own centre) — a soft belly wobble.
        face.removeAction(forKey: "wobble")
        let a = 0.03 * intensity
        face.run(.sequence([
            .scaleX(to: 1 + a, y: 1 - a, duration: 0.07), .scaleX(to: 1, y: 1, duration: 0.24)
        ]), withKey: "wobble")
    }

    private func idleInviteDrawer() {
        guard !AmbientAnimator.reduceMotion else { return }
        drawer.removeAction(forKey: "invite")
        // Only nudge when there are treasures waiting inside — a quiet "pull me".
        let check = SKAction.run { [weak self] in
            guard let self, self.drawerTouch == nil, !self.insideKinds.isEmpty,
                  self.insideKinds.count < self.pieceKinds.count,
                  abs(self.drawer.position.y - self.drawerClosedY) < 1 else { return }
            self.drawer.run(.sequence([.moveBy(x: 0, y: -4, duration: 0.5), .moveBy(x: 0, y: 4, duration: 0.6)]))
        }
        drawer.run(.repeatForever(.sequence([.wait(forDuration: 3.4), check])), withKey: "invite")
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        HapticsManager.shared.prepareForTouch()
        for touch in touches {
            let p = touch.location(in: self)
            if dragTouch == nil, drawerTouch == nil, consumeShelfReturnTouch(at: p) { return }

            // A treasure under the finger ALWAYS wins — so a piece sitting near the drawer (common on
            // iPhone, where everything is closer) is still grabbable and never triggers the drawer.
            if dragTouch == nil, let piece = treasureNear(p) {
                dragTouch = touch
                dragPiece = piece
                dragOffset = CGPoint(x: piece.position.x - p.x, y: piece.position.y - p.y)
                dragTarget = piece.position
                returningDestinations.removeValue(forKey: piece.kind)
                piece.removeAllActions()
                piece.setLifted(true)
                piece.zPosition = 30
                tone("sleepy.lift")
                HapticsManager.shared.impact(style: .light, intensity: 0.16)
                continue
            }

            // The drawer knob — a tighter, knob-sized target so it never swallows a shape or a piece.
            if drawerTouch == nil, hypot(p.x - drawer.position.x, p.y - (drawer.position.y + drawerKnobLocalY)) < boxH * 0.16 {
                removeAction(forKey: "drawer.close")
                drawer.removeAction(forKey: "tremble")
                drawerTouch = touch
                didTumbleThisPull = false
                drawerTouchStartY = p.y
                drawerDragStartY = drawer.position.y
                continue
            }

            TouchFeedbackAnimator.emptyTap(in: self, at: p)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let p = touch.location(in: self)
            if touch == drawerTouch {
                drawerTargetY = (drawerDragStartY + p.y - drawerTouchStartY).clamped(to: drawerOpenY...drawerClosedY)
            } else if touch == dragTouch {
                let inset = pieceRadius * 1.25
                dragTarget = CGPoint(
                    x: (p.x + dragOffset.x).clamped(to: inset...size.width - inset),
                    y: (p.y + dragOffset.y + 6).clamped(to: inset...size.height - inset)
                )
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { endTouch(touch) }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if touch == drawerTouch {
                drawerTouch = nil
                drawerTargetY = drawerClosedY
            }
            if touch == dragTouch {
                dragPiece?.setLifted(false)
                dragPiece?.zPosition = 12
                dragTouch = nil
                dragPiece = nil
                clearHover()
                setBoxMood(.sleepy)
            }
        }
    }

    private func endTouch(_ touch: UITouch) {
        if touch == drawerTouch {
            drawerTouch = nil
            // A quick deliberate pull counts even if the visual drawer was still easing
            // toward the finger. Hold it open briefly so the return has a visible source.
            let pulledFarEnough = drawerTargetY < drawerClosedY - (drawerClosedY - drawerOpenY) * 0.5
            if !didTumbleThisPull, pulledFarEnough {
                didTumbleThisPull = true
                tumbleOut()
            }
            if pulledFarEnough {
                drawerTargetY = drawerOpenY
                run(.sequence([.wait(forDuration: 0.55), .run { [weak self] in
                    guard let self, self.drawerTouch == nil else { return }
                    self.drawerTargetY = self.drawerClosedY
                }]), withKey: "drawer.close")
            } else {
                drawerTargetY = drawerClosedY
            }
            if mood == .surprised { setBoxMood(.sleepy) }
            return
        }
        guard touch == dragTouch, let piece = dragPiece else { return }
        dragTouch = nil; dragPiece = nil
        clearHover()
        // Commit using the last intended center, so a fast drag does not miss merely
        // because the material's authored follow-through trails the finger slightly.
        if let index = openingForDrop(near: dragTarget, kind: piece.kind) {
            dropPiece(piece, into: index)
        } else if let near = nearestOpening(near: dragTarget) {
            bumpAway(piece, from: openings[near].center)   // this piece doesn't go there — softly
        } else {
            piece.setLifted(false)
            piece.zPosition = 12
            piece.squash(0.07)
            setBoxMood(.sleepy)
        }
    }

    /// The piece nudged a hole that doesn't fit it: a soft tilt/squish, then it slides to a free
    /// spot under the child's gaze. No error sound, no sad face, no penalty.
    private func bumpAway(_ piece: DropTreasureNode, from holeCenter: CGPoint) {
        piece.setLifted(false)
        piece.zPosition = 12
        piece.bumpRim()
        tone("sleepy.bump", minInterval: 0.2)
        HapticsManager.shared.impact(style: .light, intensity: 0.1)
        setBoxMood(.sleepy)
        let dest = nearestFreePlaySpot(to: piece.position, excluding: piece)
        let move = SKAction.move(to: dest, duration: 0.34); move.timingMode = .easeOut
        piece.run(.sequence([.wait(forDuration: 0.14), move, .run { [weak piece] in piece?.squash(0.05) }]))
    }

    private func treasureNear(_ p: CGPoint) -> DropTreasureNode? {
        treasures
            .filter { hypot($0.position.x - p.x, $0.position.y - p.y) < $0.radius + 36 }
            .min { hypot($0.position.x - p.x, $0.position.y - p.y) < hypot($1.position.x - p.x, $1.position.y - p.y) }
    }

    /// Pick the opening the child actually approached, then check the shape. Searching
    /// matching shapes first can make a nearby wrong socket silently succeed.
    private func openingForDrop(near p: CGPoint, kind: DropTreasureNode.Kind) -> Int? {
        guard let index = nearestOpening(near: p), openings[index].accepts == kind else { return nil }
        return index
    }

    /// The nearest opening of any shape — used to detect a piece nudging a hole that doesn't fit.
    private func nearestOpening(near p: CGPoint) -> Int? {
        SleepyBoxFitGeometry.nearestOpening(at: p, centers: openings.map(\.center), sizes: openings.map(\.size))
    }

    private func captureRadius(at index: Int) -> CGFloat {
        SleepyBoxFitGeometry.captureRadius(at: index, centers: openings.map(\.center), sizes: openings.map(\.size))
    }

    private func nearestFreePlaySpot(to p: CGPoint, excluding piece: DropTreasureNode) -> CGPoint {
        let occupied = treasures.filter { $0 !== piece }.map { $0.position }
        let free = playSpots.filter { s in !occupied.contains { hypot($0.x - s.x, $0.y - s.y) < pieceRadius } }
        return free.min { hypot($0.x - p.x, $0.y - p.y) < hypot($1.x - p.x, $1.y - p.y) } ?? p
    }

    // MARK: - Drop in

    private func dropPiece(_ piece: DropTreasureNode, into index: Int) {
        guard treasures.contains(where: { $0 === piece }),
              !insideKinds.contains(piece.kind), openings.indices.contains(index) else { return }
        let opening = openings[index]
        insideKinds.append(piece.kind)
        treasures.removeAll { $0 === piece }

        // Approved delight: when the fourth treasure tucks in, the box hums the four
        // drop-notes back in posting order — a tiny lullaby the child composed without
        // knowing it. Every round writes a different one.
        if insideKinds.count == 4 {
            let order = insideKinds
            removeAction(forKey: "lullaby")
            // 0.95s: the last sink (~0.45s) is done and the +0.9s sleepy reset below
            // has already landed — the hum then wakes the smile, not the other way round.
            run(.sequence([.wait(forDuration: 0.95),
                           .run { [weak self] in self?.humLullaby(order) }]),
                withKey: "lullaby")
        }

        piece.setLifted(false)
        piece.zPosition = 13

        // Settle over the hole, then sink into the dark socket: shrink + fade with a little downward
        // slip, so the treasure visibly tucks inside rather than just blinking out.
        let kind = piece.kind
        let align = SKAction.move(to: opening.center, duration: 0.13); align.timingMode = .easeOut
        // v2 body art (June 11): the star hole stands upright now, so the star settles
        // in straight. The tilt plumbing stays — any future art can re-tune it.
        let starHoleTilt: CGFloat = 0
        let alignRot: CGFloat
        switch kind {
        case .berry: alignRot = CGFloat.random(in: -0.16...0.16)
        case .star:  alignRot = starHoleTilt
        default:     alignRot = 0
        }
        var pre: SKAction = .group([align, SKAction.rotate(toAngle: alignRot, duration: 0.13)])
        if kind == .star, !AmbientAnimator.reduceMotion {
            let wiggle = SKAction.sequence([.rotate(toAngle: starHoleTilt + 0.24, duration: 0.06),
                                            .rotate(toAngle: starHoleTilt - 0.14, duration: 0.08),
                                            .rotate(toAngle: starHoleTilt, duration: 0.06)])
            pre = .group([align, wiggle])
        }
        // Into the hole, not away: once the piece sits snug over its socket it is handed to
        // a crop node cut to the socket's own outline, so it can only ever be seen INSIDE
        // the hole. It then slips back and down into the dark while the cavity's shade
        // closes over it — the rim and its lit lip stay in front, so the eye reads
        // "it went in" (object permanence: the drawer gives it back).
        let socket = SKCropNode()
        let mask = openingShape(opening.shape, size: opening.size)
        mask.fillColor = .white
        mask.strokeColor = .clear
        socket.maskNode = mask
        socket.position = opening.center
        socket.zPosition = 0.32          // above cavity + inner shade, below the lit lip and hover ring
        let shade = openingShape(opening.shape, size: opening.size)
        shade.fillColor = UIColor(hex: 0x2A1710)
        shade.strokeColor = .clear
        shade.alpha = 0
        shade.zPosition = 2
        socket.addChild(shade)
        let tuckIn = SKAction.run { [weak self, weak piece] in
            guard let self, let piece, piece.parent != nil else { return }
            self.panelLayer.addChild(socket)
            piece.move(toParent: socket)
            piece.zPosition = 1
        }
        let slip = SKAction.group([
            .moveBy(x: 0, y: -opening.size.height * 0.34, duration: 0.36),
            .scale(to: 0.72, duration: 0.36),
            .sequence([.wait(forDuration: 0.16), .fadeAlpha(to: 0.0, duration: 0.2)])
        ])
        slip.timingMode = .easeIn
        shade.run(.sequence([.wait(forDuration: 0.14), .fadeAlpha(to: 0.85, duration: 0.22)]))
        piece.run(.sequence([pre, .run { [weak self] in self?.playDropSound(kind: kind) }, tuckIn, slip,
                             .run { socket.run(.sequence([.fadeOut(withDuration: 0.12), .removeFromParent()])) },
                             .removeFromParent()]))

        flashRim(index, hot: false)
        setBoxMood(.happy)
        boxBodyWobble(kind == .cube ? 1.25 : 1.0)
        spawnMotes(at: opening.center, color: WarmShelfPalette.paperHighlight, count: 5)   // soft rim light
        spawnMotes(at: opening.center, color: opening.felt, count: 4)                      // a little clay dust
        drawerTremble()
        HapticsManager.shared.impact(style: .soft, intensity: kind == .cube ? 0.3 : 0.24)
        run(.sequence([.wait(forDuration: 0.9), .run { [weak self] in
            guard let self, self.dragPiece == nil else { return }
            self.setBoxMood(.sleepy)
        }]), withKey: "box.sleep")
    }

    private func drawerTremble() {
        guard !AmbientAnimator.reduceMotion, drawerTouch == nil else { return }
        drawer.removeAction(forKey: "tremble")
        drawer.run(.sequence([.moveBy(x: 0, y: -3, duration: 0.05), .moveBy(x: 0, y: 3, duration: 0.08)]), withKey: "tremble")
    }

    private func flashRim(_ index: Int, hot: Bool) {
        guard let rim = openings[index].rim else { return }
        rim.removeAction(forKey: "rim")
        let target = hot ? openings[index].felt.withAlpha(0.7) : openings[index].felt.withAlpha(0.0)
        rim.run(.customAction(withDuration: 0.2) { node, _ in (node as? SKShapeNode)?.strokeColor = target }, withKey: "rim")
    }

    /// A few tiny clay/wood specks — material, never a reward burst. Capped and short-lived.
    private func spawnMotes(at p: CGPoint, color: UIColor, count: Int) {
        guard !AmbientAnimator.reduceMotion else { return }
        for _ in 0..<min(8, count) {
            let mote = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.4...3))
            mote.fillColor = color.withAlpha(.random(in: 0.3...0.55))
            mote.strokeColor = .clear
            mote.position = CGPoint(x: p.x + .random(in: -10...10), y: p.y + .random(in: -5...5))
            mote.zPosition = 5
            panelLayer.addChild(mote)
            let drift = SKAction.moveBy(x: .random(in: -12...12), y: .random(in: 8...24), duration: .random(in: 0.5...0.9))
            drift.timingMode = .easeOut
            mote.run(.sequence([.group([drift, .fadeOut(withDuration: 0.8), .scale(to: 0.4, duration: 0.8)]), .removeFromParent()]))
        }
    }

    // MARK: - Drawer tumble-out

    private func tumbleOut() {
        guard !insideKinds.isEmpty else { return }
        let kinds = insideKinds
        if kinds.count == pieceKinds.count {
            playSlotOrder = SleepyBoxRoundLayout.shuffledSlots(playSlotOrder)
        }
        insideKinds.removeAll()
        setBoxMood(.surprised)
        HapticsManager.shared.impact(style: .rigid, intensity: 0.3)
        AudioManager.shared.playBoxOpen()
        spawnMotes(at: CGPoint(x: drawer.position.x, y: drawer.position.y + boxH * 0.14), color: WarmShelfPalette.sand, count: 6)

        let r = pieceRadius
        // Assign each returning treasure a distinct free spot UP FRONT, so two pieces can never
        // end up stacked on each other (the playtest bug). When a toddler has dragged floor
        // pieces over the named spots, surplus returns fan out along the ledge to genuinely
        // clear ground instead of landing on someone (founder: drawer-return overlap).
        var available = playSpots.filter { s in !treasures.contains { hypot($0.position.x - s.x, $0.position.y - s.y) < r } }
        let ledgeY = playSpots.first?.y ?? (drawerClosedY - r * 3)
        var fan = 1
        while available.count < kinds.count {
            let sign: CGFloat = fan % 2 == 0 ? 1 : -1
            let candidate = CGPoint(x: (size.width / 2 + sign * CGFloat((fan + 1) / 2) * r * 2.3)
                                        .clamped(to: r * 1.2...(size.width - r * 1.2)),
                                    y: ledgeY)
            fan += 1
            if !treasures.contains(where: { hypot($0.position.x - candidate.x, $0.position.y - candidate.y) < r * 1.6 }),
               !available.contains(where: { hypot($0.x - candidate.x, $0.y - candidate.y) < r * 1.6 }) {
                available.append(candidate)
            }
            if fan > 14 { break }   // a full ledge is a full ledge — overlap beats an infinite loop
        }
        for (i, kind) in kinds.enumerated() {
            let homeIndex = pieceKinds.firstIndex(of: kind) ?? i
            let home = playSpots[playSlotOrder[homeIndex % playSlotOrder.count]]
            // A completed round returns the shapes to newly shuffled slots.
            // Partial returns keep this round's places whenever they are clear.
            // If another loose piece occupies it, choose the nearest clear place instead.
            let destinationIndex = available.indices.min { a, b in
                hypot(available[a].x - home.x, available[a].y - home.y)
                    < hypot(available[b].x - home.x, available[b].y - home.y)
            }
            let dest = destinationIndex.map { available.remove(at: $0) } ?? home
            returningDestinations[kind] = dest
            let piece = DropTreasureNode(kind: kind, radius: r)
            // Each treasure emerges already-readable from the dark drawer cavity — spread
            // across the drawer's mouth by index, so returns never pile at one point.
            let spread = (CGFloat(i) - CGFloat(max(1, kinds.count - 1)) / 2) * r * 1.3
            piece.position = CGPoint(x: drawer.position.x + spread, y: drawerClosedY)
            piece.setScale(0.82)
            piece.alpha = 0
            piece.zPosition = 11
            pieceLayer.addChild(piece)
            run(.sequence([.wait(forDuration: Double(i) * 0.09), .run { [weak self] in
                self?.tumblePiece(piece, to: dest)
            }]), withKey: "drawer.return.\(kind)")
        }
    }

    private func tumblePiece(_ piece: DropTreasureNode, to dest: CGPoint) {
        treasures.append(piece)
        let r = piece.radius
        let appear = SKAction.group([.fadeIn(withDuration: 0.08), .scale(to: 1, duration: 0.12)])
        let finishReturn = SKAction.run { [weak self, weak piece] in
            guard let piece else { return }
            self?.returningDestinations.removeValue(forKey: piece.kind)
        }
        if AmbientAnimator.reduceMotion {
            piece.run(.sequence([appear, .move(to: dest, duration: 0.4),
                                 .run { [weak piece] in piece?.squash(0.06) }, finishReturn]))
            return
        }
        // Pour out toward the slot, then drop in with a gravity ease, a puff of dust, and a soft
        // bounce — a satisfying authored tumble that always settles tidy.
        let above = CGPoint(x: dest.x, y: dest.y + r * 1.3)
        let toAbove = SKAction.move(to: above, duration: 0.26); toAbove.timingMode = .easeOut
        let drop = SKAction.move(to: dest, duration: 0.17); drop.timingMode = .easeIn
        let bounce = SKAction.sequence([.moveBy(x: 0, y: r * 0.42, duration: 0.1), .moveBy(x: 0, y: -r * 0.42, duration: 0.13)])
        let tumbleRot = SKAction.sequence([.rotate(toAngle: CGFloat.random(in: -0.5...0.5), duration: 0.3), .rotate(toAngle: 0, duration: 0.23)])
        piece.run(.sequence([
            appear,
            .group([tumbleRot, .sequence([toAbove, drop])]),
            .run { [weak self, weak piece] in
                guard let self, let piece else { return }
                piece.squash(0.13); self.tumbleBump()
                self.spawnMotes(at: piece.position, color: piece.color, count: 3)
            },
            bounce,
            finishReturn
        ]))
    }

    private func freePlaySpot(excluding i: Int) -> CGPoint {
        let occupied = treasures.map { $0.position }
        if let spot = playSpots.first(where: { s in !occupied.contains { hypot($0.x - s.x, $0.y - s.y) < 12 } }) {
            return spot
        }
        return playSpots[i % playSpots.count]
    }

    private static func bezier(_ a: CGFloat, _ c: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        let u = 1 - t
        return u * u * a + 2 * u * t * c + t * t * b
    }

    // MARK: - Update (authored drag lag + magnet + drawer friction)

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        guard boxW > 0 else { return }

        // Dragged treasure follows the finger with a soft lag; magnet-aligns near a hole.
        if let piece = dragPiece {
            var target = dragTarget
            if let index = openingForDrop(near: dragTarget, kind: piece.kind) {
                let o = openings[index]
                let d = hypot(o.center.x - dragTarget.x, o.center.y - dragTarget.y)
                let pull = max(0, 1 - d / captureRadius(at: index)) * 0.24
                target = CGPoint(x: target.x + (o.center.x - target.x) * pull, y: target.y + (o.center.y - target.y) * pull)
                if hoverOpening != index {
                    hoverOpening.map { flashRim($0, hot: false) }
                    flashRim(index, hot: true); hoverOpening = index
                    setBoxMood(.curious)
                    boxBodyWobble(0.4)                                  // a tiny anticipation lean
                    spawnMotes(at: o.center, color: o.felt, count: 3)   // the hole welcomes the piece
                    tone("sleepy.hover", minInterval: 0.3)
                    HapticsManager.shared.impact(style: .light, intensity: 0.08)
                }
            } else if hypot(piece.position.x - boxCenter.x, piece.position.y - boxCenter.y) < boxW * 0.8 {
                if hoverOpening != nil { clearHover() }
                if mood != .curious { setBoxMood(.curious) }          // the box notices the child
            } else {
                if hoverOpening != nil { clearHover() }
                if mood != .sleepy { setBoxMood(.sleepy) }
            }
            let pos = piece.position
            piece.position = CGPoint(x: pos.x + (target.x - pos.x) * 0.4, y: pos.y + (target.y - pos.y) * 0.4)
        }

        // Drawer eases toward its target with soft friction.
        let dy = drawerTargetY - drawer.position.y
        if abs(dy) > 0.3 {
            drawer.position.y += dy * 0.28
            if drawerTouch != nil {
                tone("sleepy.drawer", minInterval: 0.26)
                if !insideKinds.isEmpty { rattle() }
            }
            // Tumble once when pulled far enough.
            if !didTumbleThisPull, drawerTouch != nil,
               drawer.position.y < drawerClosedY - (drawerClosedY - drawerOpenY) * 0.5 {
                didTumbleThisPull = true
                tumbleOut()
            }
        }
    }

    private func clearHover() {
        if let h = hoverOpening { flashRim(h, hot: false) }
        hoverOpening = nil
    }

    private func rattle() {
        let now = CACurrentMediaTime()
        guard now - lastRattle > 0.3 else { return }
        lastRattle = now
        tone("sleepy.tumble")
    }

    private func tumbleBump() {
        tone("sleepy.tumble", minInterval: 0.09)
    }

    // MARK: - Sound

    private func tone(_ cue: String, minInterval: TimeInterval = 0) {
        if minInterval > 0 {
            let now = CACurrentMediaTime()
            if let last = lastTone[cue], now - last < minInterval { return }
            lastTone[cue] = now
        }
        AudioManager.shared.play(cue: cue)
    }

    /// Each shape has its own note (berry, triangle, cube, star climb the pentatonic).
    private func shapeIndex(_ kind: DropTreasureNode.Kind) -> Int {
        DropTreasureNode.Kind.allCases.firstIndex(of: kind) ?? 0
    }

    /// The signature: a hollow wooden-box answer with the shape's own kalimba note, so the
    /// treasure sounds like it is now *inside* the box.
    private func playDropSound(kind: DropTreasureNode.Kind) {
        AudioManager.shared.play(cue: "sleepy.drop.\(shapeIndex(kind))")
    }

    /// All four treasures are tucked in: the box smiles in its sleep and softly hums
    /// them back, in the order they went in.
    private func humLullaby(_ order: [DropTreasureNode.Kind]) {
        guard insideKinds.count == 4 else { return }   // drawer pulled mid-wait — stay asleep
        setBoxMood(.happy)
        let step = 0.55
        // The box hums each shape's own note back, in the order they went in.
        for (i, kind) in order.enumerated() {
            AudioManager.shared.play(cue: "sleepy.hum.\(shapeIndex(kind))", delay: Double(i) * step)
        }
        run(.sequence([.wait(forDuration: step * 3 + 1.0), .run { [weak self] in
            guard let self, self.dragPiece == nil else { return }
            self.setBoxMood(.sleepy)                    // hum done — back to sleep
        }]), withKey: "box.sleep")
    }

    // MARK: - Accessibility

    override func accessibilityElements(in view: SKView) -> [UIAccessibilityElement] {
        var elements = super.accessibilityElements(in: view)
        for (i, piece) in treasures.enumerated() {
            elements.append(makeActivatableAccessibilityElement(
                in: view, label: "Treasure \(i + 1) — drop it into the sleepy box",
                scenePosition: piece.position, size: CGSize(width: piece.radius * 3, height: piece.radius * 3), traits: .button
            ) { [weak self, weak piece] in
                guard let self, let piece,
                      let index = self.openings.firstIndex(where: { $0.accepts == piece.kind }) else { return }
                self.dropPiece(piece, into: index)
            })
        }
        elements.append(makeActivatableAccessibilityElement(
            in: view, label: "Drawer — pull to get the treasures back", scenePosition: CGPoint(x: drawer.position.x, y: drawer.position.y),
            size: CGSize(width: boxW * 0.5, height: boxH * 0.3), traits: .button
        ) { [weak self] in
            self?.tumbleOut()
        })
        return elements
    }
}

/// A new complete round keeps one of each shape while changing their loose tray order.
enum SleepyBoxRoundLayout {
    static func shuffledSlots(_ current: [Int]) -> [Int] {
        guard current.count > 1 else { return current }
        var next = current.shuffled()
        // A completed round always visibly changes, even if random happens to repeat.
        if next == current { next.append(next.removeFirst()) }
        return next
    }
}

/// Fit geometry is independent of artwork and touch pickup halos. Release regions never
/// overlap, so the socket under a shape remains the source of the toy's feedback.
enum SleepyBoxFitGeometry {
    static func captureRadius(at index: Int, centers: [CGPoint], sizes: [CGSize]) -> CGFloat {
        guard centers.indices.contains(index), sizes.indices.contains(index) else { return 0 }
        let center = centers[index]
        let neighborDistance = centers.enumerated()
            .filter { $0.offset != index }
            .map { hypot($0.element.x - center.x, $0.element.y - center.y) }
            .min() ?? .greatestFiniteMagnitude
        let visualRadius = max(sizes[index].width, sizes[index].height) * 0.55 + 8
        return min(visualRadius, neighborDistance * 0.44)
    }

    static func nearestOpening(at point: CGPoint, centers: [CGPoint], sizes: [CGSize]) -> Int? {
        guard centers.count == sizes.count,
              let nearest = centers.indices.min(by: { a, b in
                  hypot(centers[a].x - point.x, centers[a].y - point.y)
                    < hypot(centers[b].x - point.x, centers[b].y - point.y)
              }) else { return nil }
        let distance = hypot(centers[nearest].x - point.x, centers[nearest].y - point.y)
        return distance <= captureRadius(at: nearest, centers: centers, sizes: sizes) ? nearest : nil
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
