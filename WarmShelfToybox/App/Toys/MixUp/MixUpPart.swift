import SpriteKit

enum MixUpZone: CaseIterable {
    case head
    case body
    case legs
}

/// One swappable part — a flat, card-style piece built around its own attach point (0,0).
struct MixUpPart {
    let name: String
    let baseName: String
    let seed: UInt64?
    let isRare: Bool
    let build: (_ scale: CGFloat) -> SKNode

    init(
        name: String,
        baseName: String? = nil,
        seed: UInt64? = nil,
        isRare: Bool = false,
        build: @escaping (_ scale: CGFloat) -> SKNode
    ) {
        self.name = name
        self.baseName = baseName ?? name
        self.seed = seed
        self.isRare = isRare
        self.build = build
    }
}

/// A recognizable, varied library of heads, bodies, and legs in the alphabet-card look.
enum MixUpLibrary {
    private static let primaryHeadName = "mix.primary.head"
    private static let primaryTorsoName = "mix.primary.torso"
    private static let clayWidthKey = "mix.clay.width"
    private static let clayHeightKey = "mix.clay.height"

    static func parts(for zone: MixUpZone) -> [MixUpPart] {
        // Once the authored cast exists it IS the library — the procedural era retires
        // (playtest 2026-06-10: mixed eras read as broken, seams don't agree). The
        // procedural pools remain only as the fallback when no art has landed.
        let art = artCharacterParts(for: zone)
        if !art.isEmpty { return art }
        switch zone {
        case .head: return expandedHeads
        case .body: return expandedBodies
        case .legs: return expandedLegs
        }
    }

    /// The authored cast (Docs/MixUpSlice.md). Every character whose split sheet has
    /// landed joins all three flip pools — their pieces mix with everyone else's,
    /// which is the whole joke. Order here is pool order; newest additions last.
    private static let artCharacterNames = [
        // "wren" sits out: her split bands are a back-view (faceless red blob on
        // stage — founder QA June 12). She returns when a faced sheet lands.
        "bunny", "bear", "king", "queen", "mouse", "songbird", "zebra", "cat",
        "dog", "owl", "duck", "robot", "robot2", "lion", "frog", "mouse2", "bear2",
        "bunny2", "fox",
        // June 11 citizens — the town gets bigger and looks more like the world.
        // (king2 removed June 14 — a second crown read as a duplicate king, founder.)
        "dancer", "firefighter", "officer", "alien", "astronaut"
    ]

    private static func artCharacterParts(for zone: MixUpZone) -> [MixUpPart] {
        artCharacterNames.compactMap { artPart(name: $0, zone: zone) }
    }

    /// Sheet bands are cropped tight, so parts are seam-anchored rather than centred:
    /// the head's chin, the body's shoulders and the legs' top each land on a fixed
    /// line (slot-local), giving every character a few points of overlap at the joins
    /// while feet stay planted on the stage line — any band proportions assemble clean.
    private static func artPart(name: String, zone: MixUpZone) -> MixUpPart? {
        let slot = "\(name)-\(zone == .head ? "head" : zone == .body ? "body" : "legs")"
        guard ToyArt.texture(slot) != nil else { return nil }
        return MixUpPart(name: name) { s in
            let n = SKNode()
            let sprite: SKSpriteNode?
            switch zone {
            case .head:
                sprite = ToyArt.sprite(slot, fit: CGSize(width: 104 * s, height: 170 * s))
                sprite?.position = CGPoint(x: 0, y: -71 * s + (sprite?.size.height ?? 0) / 2)
            case .body:
                sprite = ToyArt.sprite(slot, fit: CGSize(width: 130 * s, height: 100 * s))
                sprite?.position = CGPoint(x: 0, y: 30 * s - (sprite?.size.height ?? 0) / 2)
            case .legs:
                sprite = ToyArt.sprite(slot, fit: CGSize(width: 80 * s, height: 48 * s))
                sprite?.position = CGPoint(x: 0, y: 46 * s - (sprite?.size.height ?? 0) / 2)   // feet kiss the body (QA: cat hover)
            }
            if let sprite { n.addChild(sprite) }
            return n
        }
    }

    // MARK: - Seeded handmade variants

    private static let expandedHeads = expandedParts(heads, zone: .head)
    private static let expandedBodies = expandedParts(bodies, zone: .body)
    private static let expandedLegs = expandedParts(legs, zone: .legs)

    private enum TraitTexture: CaseIterable {
        case claySpeckles, moonDots, stitchMarks, softStripes, confettiBits, petalScales

        var label: String {
            switch self {
            case .claySpeckles: return "speckled"
            case .moonDots: return "moon-dot"
            case .stitchMarks: return "stitched"
            case .softStripes: return "stripey"
            case .confettiBits: return "confetti"
            case .petalScales: return "petal"
            }
        }
    }

    private enum TraitAccessory: CaseIterable {
        case sprout, roundGlasses, tinyBow, bonnet, starPin, pocket, sash, buttons, patches, laces, cuffs, ankleBells

        var label: String {
            switch self {
            case .sprout: return "sprout"
            case .roundGlasses: return "glasses"
            case .tinyBow: return "bow"
            case .bonnet: return "bonnet"
            case .starPin: return "star"
            case .pocket: return "pocket"
            case .sash: return "sash"
            case .buttons: return "button"
            case .patches: return "patch"
            case .laces: return "lace"
            case .cuffs: return "cuff"
            case .ankleBells: return "bell"
            }
        }
    }

    private enum TraitExpression: CaseIterable {
        case curiousBrows, sleepyLashes, starGlints, freckleCheeks, tinyWonder

        var label: String {
            switch self {
            case .curiousBrows: return "curious"
            case .sleepyLashes: return "sleepy"
            case .starGlints: return "sparkle"
            case .freckleCheeks: return "freckle"
            case .tinyWonder: return "wonder"
            }
        }
    }

    private enum TraitSilhouette: CaseIterable {
        case balanced, tall, wide, squishy, jaunty

        var scales: (x: CGFloat, y: CGFloat, rotation: CGFloat) {
            switch self {
            case .balanced: return (1.0, 1.0, 0.0)
            case .tall: return (0.96, 1.07, -0.015)
            case .wide: return (1.08, 0.97, 0.012)
            case .squishy: return (1.05, 0.94, -0.006)
            case .jaunty: return (1.0, 1.0, 0.055)
            }
        }
    }

    private struct TraitRecipe {
        let seed: UInt64
        let palette: CutePalette
        let texture: TraitTexture
        let accessory: TraitAccessory
        let expression: TraitExpression
        let silhouette: TraitSilhouette
        let isRare: Bool

        var displayPrefix: String {
            isRare ? "storybook \(texture.label)" : "\(expression.label) \(texture.label)"
        }
    }

    private static func expandedParts(_ baseParts: [MixUpPart], zone: MixUpZone) -> [MixUpPart] {
        var result = baseParts
        let variantCount = zone == .head ? 6 : 5

        for variantIndex in 0..<variantCount {
            for base in baseParts {
                result.append(traitedPart(base, zone: zone, variantIndex: variantIndex))
            }
        }
        return result
    }

    private static func traitedPart(_ base: MixUpPart, zone: MixUpZone, variantIndex: Int) -> MixUpPart {
        let seed = stableSeed(zone: zone, baseName: base.baseName, variantIndex: variantIndex)
        let recipe = makeRecipe(zone: zone, seed: seed, variantIndex: variantIndex)
        let name = "\(recipe.displayPrefix) \(base.baseName)"

        return MixUpPart(name: name, baseName: base.baseName, seed: seed, isRare: recipe.isRare) { s in
            let root = SKNode()
            root.name = "mix.generated.\(base.baseName).\(seed)"

            let art = base.build(s)
            art.name = "mix.base.\(base.baseName)"
            let silhouette = recipe.silhouette.scales
            art.xScale = silhouette.x
            art.yScale = silhouette.y
            art.zRotation = silhouette.rotation
            tintShapes(
                in: art,
                zone: zone,
                recipe: recipe,
                amount: recognitionTintAmount(for: base.baseName, zone: zone, isRare: recipe.isRare)
            )
            applyGeneratedClayFill(in: art, zone: zone)
            root.addChild(art)

            addGeneratedTexture(to: root, zone: zone, recipe: recipe, s: s)
            addGeneratedAccessory(to: root, zone: zone, recipe: recipe, s: s)
            addGeneratedExpression(to: root, zone: zone, recipe: recipe, s: s)
            addRecognitionAnchor(to: root, baseName: base.baseName, zone: zone, recipe: recipe, s: s)
            if recipe.isRare {
                addRareStorybookAura(to: root, zone: zone, recipe: recipe, s: s)
            }
            return root
        }
    }

    private static func makeRecipe(zone: MixUpZone, seed: UInt64, variantIndex: Int) -> TraitRecipe {
        var rng = SeededGenerator(seed: seed)
        let rareIndex = zone == .head ? 5 : 4
        let isRare = variantIndex == rareIndex
        let palette = isRare ? rarePalette(seed: seed) : CutePalette.random(using: &rng)

        let texture = pick(TraitTexture.allCases, using: &rng)
        let expression = pick(TraitExpression.allCases, using: &rng)
        let silhouette = pick(TraitSilhouette.allCases, using: &rng)
        let accessory: TraitAccessory
        switch zone {
        case .head:
            accessory = pick([.sprout, .roundGlasses, .tinyBow, .bonnet, .starPin], using: &rng)
        case .body:
            accessory = pick([.pocket, .sash, .buttons, .patches, .starPin], using: &rng)
        case .legs:
            accessory = pick([.laces, .cuffs, .patches, .ankleBells], using: &rng)
        }

        return TraitRecipe(
            seed: seed,
            palette: palette,
            texture: texture,
            accessory: accessory,
            expression: expression,
            silhouette: silhouette,
            isRare: isRare
        )
    }

    private static func rarePalette(seed: UInt64) -> CutePalette {
        let rareFamilies = [
            CutePalette(body: WarmShelfPalette.clayInk.withAlpha(0.74), belly: WarmShelfPalette.paperHighlight, cheek: WarmShelfPalette.petal, accent: WarmShelfPalette.butter, ink: WarmShelfPalette.cocoa),
            CutePalette(body: WarmShelfPalette.lavender.withAlpha(0.96), belly: WarmShelfPalette.waterBlue.withAlpha(0.34), cheek: WarmShelfPalette.rhubarb, accent: WarmShelfPalette.butter, ink: WarmShelfPalette.cocoa),
            CutePalette(body: WarmShelfPalette.sage.withAlpha(0.94), belly: WarmShelfPalette.butter.withAlpha(0.72), cheek: WarmShelfPalette.petal, accent: WarmShelfPalette.rhubarb, ink: WarmShelfPalette.cocoa)
        ]
        return rareFamilies[Int(seed % UInt64(rareFamilies.count))]
    }

    private static func stableSeed(zone: MixUpZone, baseName: String, variantIndex: Int) -> UInt64 {
        let key = "mixup:\(zone.seedKey):\(baseName):\(variantIndex)"
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }

    private static func pick<T>(_ values: [T], using rng: inout SeededGenerator) -> T {
        values[Int(rng.next() % UInt64(values.count))]
    }

    private static func random(_ range: ClosedRange<CGFloat>, using rng: inout SeededGenerator) -> CGFloat {
        let raw = CGFloat(rng.next() % 10_000) / 10_000
        return range.lowerBound + (range.upperBound - range.lowerBound) * raw
    }

    private static func tintShapes(in node: SKNode, zone: MixUpZone, recipe: TraitRecipe, amount: CGFloat) {
        if let shape = node as? SKShapeNode, shape.fillColor.mixUpAlpha > 0.08 {
            let brightness = shape.fillColor.mixUpBrightness
            if brightness > 0.18 && brightness < 0.90 {
                let target: UIColor
                switch zone {
                case .head: target = recipe.palette.body
                case .body: target = recipe.palette.accent
                case .legs: target = recipe.palette.bodyDark
                }
                shape.fillColor = shape.fillColor.mixUpMixed(with: target, amount)
            }
        }
        node.children.forEach { tintShapes(in: $0, zone: zone, recipe: recipe, amount: amount) }
    }

    private static func applyGeneratedClayFill(in node: SKNode, zone: MixUpZone) {
        guard zone == .head || zone == .body else { return }

        if let shape = node as? SKShapeNode {
            let shouldFill = (zone == .head && shape.name == primaryHeadName) ||
                (zone == .body && shape.name == primaryTorsoName)
            if shouldFill {
                ProceduralTexture.applyClayFill(
                    to: shape,
                    base: shape.fillColor.mixUpOpaque,
                    size: clayTextureSize(for: shape)
                )
            }
        }

        node.children.forEach { applyGeneratedClayFill(in: $0, zone: zone) }
    }

    private static func markPrimaryClay(_ shape: SKShapeNode, name: String, size: CGSize) {
        shape.name = name
        let data = shape.userData ?? NSMutableDictionary()
        data[clayWidthKey] = NSNumber(value: Double(size.width))
        data[clayHeightKey] = NSNumber(value: Double(size.height))
        shape.userData = data
    }

    private static func clayTextureSize(for shape: SKShapeNode) -> CGSize {
        if let width = shape.userData?[clayWidthKey] as? NSNumber,
           let height = shape.userData?[clayHeightKey] as? NSNumber {
            return CGSize(width: CGFloat(width.doubleValue), height: CGFloat(height.doubleValue))
        }

        let frame = shape.calculateAccumulatedFrame()
        return CGSize(width: max(8, frame.width), height: max(8, frame.height))
    }

    private static func recognitionTintAmount(for baseName: String, zone: MixUpZone, isRare: Bool) -> CGFloat {
        guard zone == .head else { return isRare ? 0.38 : 0.26 }
        let iconicHeads: Set<String> = [
            "king", "queen", "robot", "bird", "duck", "owl", "penguin",
            "frog", "lion", "cat", "fox", "bunny", "dog", "mouse", "bear", "zebra", "pig"
        ]
        return iconicHeads.contains(baseName) ? (isRare ? 0.24 : 0.16) : (isRare ? 0.34 : 0.22)
    }

    private static func addGeneratedTexture(to root: SKNode, zone: MixUpZone, recipe: TraitRecipe, s: CGFloat) {
        var rng = SeededGenerator(seed: recipe.seed &+ 0xA11CE)
        let bounds = textureBounds(for: zone, s: s)
        let avoid = faceAvoidanceBounds(for: zone, s: s)
        let alphaScale: CGFloat = zone == .head ? 0.58 : 1.0
        let ink = recipe.palette.ink
        let accent = recipe.palette.accent
        let textureRoot = SKNode()
        textureRoot.zPosition = 42
        root.addChild(textureRoot)

        switch recipe.texture {
        case .claySpeckles:
            for _ in 0..<14 {
                let dot = SKShapeNode(circleOfRadius: random(1.2...3.0, using: &rng) * s)
                dot.fillColor = ink.withAlpha(random(0.035...0.075, using: &rng) * alphaScale)
                dot.strokeColor = .clear
                dot.position = randomPoint(in: bounds, avoiding: avoid, using: &rng)
                textureRoot.addChild(dot)
            }
        case .moonDots:
            for _ in 0..<7 {
                let r = random(3.4...6.2, using: &rng) * s
                let moon = SKNode()
                moon.position = randomPoint(in: bounds.insetBy(dx: 8 * s, dy: 8 * s), avoiding: avoid, using: &rng)
                let disc = SKShapeNode(circleOfRadius: r)
                disc.fillColor = accent.withAlpha(0.22 * alphaScale)
                disc.strokeColor = .clear
                moon.addChild(disc)
                let carve = SKShapeNode(circleOfRadius: r * 0.82)
                carve.fillColor = WarmShelfPalette.linen.withAlpha(0.28 * alphaScale)
                carve.strokeColor = .clear
                carve.position = CGPoint(x: r * 0.35, y: r * 0.12)
                moon.addChild(carve)
                textureRoot.addChild(moon)
            }
        case .stitchMarks:
            for index in 0..<10 {
                let stitch = SKShapeNode(rectOf: CGSize(width: 2.4 * s, height: 8 * s), cornerRadius: 1.2 * s)
                stitch.fillColor = ink.withAlpha(0.18 * alphaScale)
                stitch.strokeColor = .clear
                stitch.position = CGPoint(
                    x: bounds.minX + bounds.width * CGFloat(index) / 9,
                    y: bounds.minY + random(8...20, using: &rng) * s
                )
                stitch.zRotation = random(-0.25...0.25, using: &rng)
                textureRoot.addChild(stitch)
            }
        case .softStripes:
            for index in 0..<5 {
                let stripe = SKShapeNode(rectOf: CGSize(width: bounds.width * 0.76, height: 5.0 * s), cornerRadius: 2.5 * s)
                stripe.fillColor = accent.withAlpha(0.16 * alphaScale)
                stripe.strokeColor = .clear
                let yOffset = zone == .head && index == 2 ? bounds.height * 0.10 : 0
                stripe.position = CGPoint(x: bounds.midX, y: bounds.minY + bounds.height * (CGFloat(index) + 0.7) / 5.8 + yOffset)
                stripe.zRotation = random(-0.16...0.16, using: &rng)
                textureRoot.addChild(stripe)
            }
        case .confettiBits:
            for index in 0..<12 {
                let bit = index.isMultiple(of: 2)
                    ? SKShapeNode(circleOfRadius: random(1.8...3.4, using: &rng) * s)
                    : SKShapeNode(rectOf: CGSize(width: 4 * s, height: 7 * s), cornerRadius: 1.5 * s)
                bit.fillColor = (index.isMultiple(of: 3) ? recipe.palette.cheek : accent).withAlpha(0.22 * alphaScale)
                bit.strokeColor = .clear
                bit.position = randomPoint(in: bounds, avoiding: avoid, using: &rng)
                bit.zRotation = random(-0.5...0.5, using: &rng)
                textureRoot.addChild(bit)
            }
        case .petalScales:
            for row in 0..<3 {
                for column in 0..<4 {
                    let petal = SKShapeNode(ellipseOf: CGSize(width: 10 * s, height: 6 * s))
                    petal.fillColor = accent.withAlpha(0.13 * alphaScale)
                    petal.strokeColor = .clear
                    petal.position = CGPoint(
                        x: bounds.minX + bounds.width * (CGFloat(column) + 0.5 + CGFloat(row % 2) * 0.32) / 4.4,
                        y: bounds.minY + bounds.height * (CGFloat(row) + 0.62) / 3.5
                    )
                    petal.zRotation = random(-0.30...0.30, using: &rng)
                    textureRoot.addChild(petal)
                }
            }
        }
    }

    private static func addGeneratedAccessory(to root: SKNode, zone: MixUpZone, recipe: TraitRecipe, s: CGFloat) {
        let accessoryRoot = SKNode()
        accessoryRoot.zPosition = 55
        root.addChild(accessoryRoot)
        let accent = recipe.palette.accent
        let ink = recipe.palette.ink

        switch (zone, recipe.accessory) {
        case (.head, .sprout):
            let stem = SKShapeNode(rect: CGRect(x: -1.5 * s, y: 42 * s, width: 3 * s, height: 18 * s), cornerRadius: 1.5 * s)
            stem.fillColor = WarmShelfPalette.sage
            stem.strokeColor = .clear
            accessoryRoot.addChild(stem)
            for sign in [CGFloat(-1), CGFloat(1)] {
                let leaf = SKShapeNode(ellipseOf: CGSize(width: 14 * s, height: 8 * s))
                leaf.fillColor = WarmShelfPalette.sage.withAlpha(0.88)
                leaf.strokeColor = .clear
                leaf.position = CGPoint(x: sign * 6 * s, y: 57 * s)
                leaf.zRotation = sign * 0.55
                accessoryRoot.addChild(leaf)
            }
        case (.head, .roundGlasses):
            for sign in [CGFloat(-1), CGFloat(1)] {
                let lens = SKShapeNode(circleOfRadius: 14 * s)
                lens.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.12)
                lens.strokeColor = ink.withAlpha(0.52)
                lens.lineWidth = 2 * s
                lens.position = CGPoint(x: sign * 18 * s, y: 7 * s)
                accessoryRoot.addChild(lens)
            }
            let bridge = SKShapeNode(rectOf: CGSize(width: 10 * s, height: 2 * s), cornerRadius: s)
            bridge.fillColor = ink.withAlpha(0.48)
            bridge.strokeColor = .clear
            bridge.position = CGPoint(x: 0, y: 7 * s)
            accessoryRoot.addChild(bridge)
        case (.head, .tinyBow):
            for sign in [CGFloat(-1), CGFloat(1)] {
                let loop = SKShapeNode(ellipseOf: CGSize(width: 18 * s, height: 12 * s))
                loop.fillColor = accent.withAlpha(0.90)
                loop.strokeColor = .clear
                loop.position = CGPoint(x: sign * 9 * s, y: 43 * s)
                loop.zRotation = sign * 0.22
                accessoryRoot.addChild(loop)
            }
            let knot = SKShapeNode(circleOfRadius: 4 * s)
            knot.fillColor = recipe.palette.cheek
            knot.strokeColor = .clear
            knot.position = CGPoint(x: 0, y: 43 * s)
            accessoryRoot.addChild(knot)
        case (.head, .bonnet):
            let brim = SKShapeNode(path: arcPath(radius: 48 * s, start: .pi * 0.10, end: .pi * 0.90))
            brim.strokeColor = accent.withAlpha(0.82)
            brim.lineWidth = 7 * s
            brim.lineCap = .round
            brim.fillColor = .clear
            brim.position = CGPoint(x: 0, y: -4 * s)
            accessoryRoot.addChild(brim)
        case (_, .starPin):
            let star = SKShapeNode(path: starPath(radius: 10 * s))
            star.fillColor = accent
            star.strokeColor = WarmShelfPalette.paperHighlight.withAlpha(0.32)
            star.lineWidth = 1
            star.position = zone == .head ? CGPoint(x: 30 * s, y: 32 * s) : CGPoint(x: 24 * s, y: 8 * s)
            accessoryRoot.addChild(star)
        case (.body, .pocket):
            let pocket = SKShapeNode(rect: CGRect(x: -16 * s, y: -22 * s, width: 32 * s, height: 26 * s), cornerRadius: 8 * s)
            pocket.fillColor = recipe.palette.belly.withAlpha(0.62)
            pocket.strokeColor = ink.withAlpha(0.08)
            pocket.lineWidth = 1
            accessoryRoot.addChild(pocket)
            let peek = SKShapeNode(circleOfRadius: 5 * s)
            peek.fillColor = accent.withAlpha(0.9)
            peek.strokeColor = .clear
            peek.position = CGPoint(x: 7 * s, y: -6 * s)
            accessoryRoot.addChild(peek)
        case (.body, .sash):
            let sash = SKShapeNode(rectOf: CGSize(width: 104 * s, height: 14 * s), cornerRadius: 7 * s)
            sash.fillColor = accent.withAlpha(0.82)
            sash.strokeColor = .clear
            sash.zRotation = -0.45
            accessoryRoot.addChild(sash)
        case (.body, .buttons):
            for y in [-24, 0, 24] as [CGFloat] {
                let button = SKShapeNode(circleOfRadius: 4.2 * s)
                button.fillColor = recipe.palette.belly.withAlpha(0.82)
                button.strokeColor = ink.withAlpha(0.12)
                button.lineWidth = 1
                button.position = CGPoint(x: 0, y: y * s)
                accessoryRoot.addChild(button)
            }
        case (.body, .patches), (.legs, .patches):
            let patch = SKShapeNode(rect: CGRect(x: -14 * s, y: -12 * s, width: 28 * s, height: 24 * s), cornerRadius: 6 * s)
            patch.fillColor = recipe.palette.belly.withAlpha(0.62)
            patch.strokeColor = ink.withAlpha(0.18)
            patch.lineWidth = 1
            patch.position = zone == .legs ? CGPoint(x: -16 * s, y: 18 * s) : CGPoint(x: -23 * s, y: -12 * s)
            patch.zRotation = -0.10
            accessoryRoot.addChild(patch)
        case (.legs, .laces):
            for sign in [CGFloat(-1), CGFloat(1)] {
                for y in [3, 9] as [CGFloat] {
                    let lace = SKShapeNode(rectOf: CGSize(width: 18 * s, height: 2 * s), cornerRadius: s)
                    lace.fillColor = ink.withAlpha(0.30)
                    lace.strokeColor = .clear
                    lace.position = CGPoint(x: sign * 16 * s, y: y * s)
                    lace.zRotation = sign * 0.24
                    accessoryRoot.addChild(lace)
                }
            }
        case (.legs, .cuffs):
            for sign in [CGFloat(-1), CGFloat(1)] {
                let cuff = SKShapeNode(ellipseOf: CGSize(width: 28 * s, height: 11 * s))
                cuff.fillColor = recipe.palette.belly.withAlpha(0.72)
                cuff.strokeColor = .clear
                cuff.position = CGPoint(x: sign * 16 * s, y: 27 * s)
                accessoryRoot.addChild(cuff)
            }
        case (.legs, .ankleBells):
            for sign in [CGFloat(-1), CGFloat(1)] {
                let bell = SKShapeNode(circleOfRadius: 5.2 * s)
                bell.fillColor = accent.withAlpha(0.90)
                bell.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.10)
                bell.lineWidth = 1
                bell.position = CGPoint(x: sign * 25 * s, y: 10 * s)
                accessoryRoot.addChild(bell)
            }
        default:
            break
        }
    }

    private static func addGeneratedExpression(to root: SKNode, zone: MixUpZone, recipe: TraitRecipe, s: CGFloat) {
        guard zone == .head else { return }
        let expressionRoot = SKNode()
        expressionRoot.zPosition = 70
        root.addChild(expressionRoot)
        let ink = recipe.palette.ink

        switch recipe.expression {
        case .curiousBrows:
            for sign in [CGFloat(-1), CGFloat(1)] {
                let brow = SKShapeNode(rectOf: CGSize(width: 17 * s, height: 2.6 * s), cornerRadius: 1.3 * s)
                brow.fillColor = ink.withAlpha(0.42)
                brow.strokeColor = .clear
                brow.position = CGPoint(x: sign * 18 * s, y: 24 * s)
                brow.zRotation = sign * -0.18
                expressionRoot.addChild(brow)
            }
        case .sleepyLashes:
            for sign in [CGFloat(-1), CGFloat(1)] {
                for index in 0..<3 {
                    let lash = SKShapeNode(rectOf: CGSize(width: 1.8 * s, height: 8 * s), cornerRadius: 0.9 * s)
                    lash.fillColor = ink.withAlpha(0.36)
                    lash.strokeColor = .clear
                    lash.position = CGPoint(x: sign * (12 + CGFloat(index) * 4) * s, y: 19 * s)
                    lash.zRotation = sign * (0.45 + CGFloat(index) * 0.12)
                    expressionRoot.addChild(lash)
                }
            }
        case .starGlints:
            for sign in [CGFloat(-1), CGFloat(1)] {
                let star = SKShapeNode(path: starPath(radius: 5.5 * s))
                star.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.86)
                star.strokeColor = .clear
                star.position = CGPoint(x: sign * 25 * s, y: 18 * s)
                expressionRoot.addChild(star)
            }
        case .freckleCheeks:
            for sign in [CGFloat(-1), CGFloat(1)] {
                for index in 0..<3 {
                    let freckle = SKShapeNode(circleOfRadius: 1.5 * s)
                    freckle.fillColor = ink.withAlpha(0.22)
                    freckle.strokeColor = .clear
                    freckle.position = CGPoint(x: sign * (23 + CGFloat(index) * 4) * s, y: (-9 + CGFloat(index % 2) * 4) * s)
                    expressionRoot.addChild(freckle)
                }
            }
        case .tinyWonder:
            let mouth = SKShapeNode(circleOfRadius: 5.0 * s)
            mouth.fillColor = ink.withAlpha(0.30)
            mouth.strokeColor = .clear
            mouth.position = CGPoint(x: 0, y: -15 * s)
            expressionRoot.addChild(mouth)
        }
    }

    private static func addRecognitionAnchor(to root: SKNode, baseName: String, zone: MixUpZone, recipe: TraitRecipe, s: CGFloat) {
        guard zone == .head else { return }
        let anchor = SKNode()
        anchor.zPosition = 84
        root.addChild(anchor)
        let ink = recipe.palette.ink
        let accent = recipe.palette.accent

        switch baseName {
        case "king", "queen":
            let crownPath = CGMutablePath()
            crownPath.move(to: CGPoint(x: -23 * s, y: 36 * s))
            crownPath.addLine(to: CGPoint(x: -11 * s, y: 50 * s))
            crownPath.addLine(to: CGPoint(x: 0, y: 39 * s))
            crownPath.addLine(to: CGPoint(x: 12 * s, y: 51 * s))
            crownPath.addLine(to: CGPoint(x: 23 * s, y: 36 * s))
            let crown = SKShapeNode(path: crownPath)
            crown.strokeColor = WarmShelfPalette.butter.withAlpha(0.92)
            crown.lineWidth = 4 * s
            crown.lineCap = .round
            crown.lineJoin = .round
            crown.fillColor = .clear
            anchor.addChild(crown)
            let gem = SKShapeNode(circleOfRadius: 4 * s)
            gem.fillColor = WarmShelfPalette.rhubarb
            gem.strokeColor = .clear
            gem.position = CGPoint(x: 12 * s, y: 51 * s)
            anchor.addChild(gem)

        case "robot":
            let stem = SKShapeNode(rect: CGRect(x: -1.8 * s, y: 39 * s, width: 3.6 * s, height: 18 * s), cornerRadius: 1.8 * s)
            stem.fillColor = ink.withAlpha(0.46)
            stem.strokeColor = .clear
            anchor.addChild(stem)
            let beacon = SKShapeNode(circleOfRadius: 6.5 * s)
            beacon.fillColor = WarmShelfPalette.rhubarb
            beacon.strokeColor = WarmShelfPalette.paperHighlight.withAlpha(0.28)
            beacon.lineWidth = 1
            beacon.position = CGPoint(x: 0, y: 60 * s)
            anchor.addChild(beacon)
            for sign in [CGFloat(-1), CGFloat(1)] {
                let bolt = SKShapeNode(circleOfRadius: 5 * s)
                bolt.fillColor = WarmShelfPalette.sand.withAlpha(0.95)
                bolt.strokeColor = ink.withAlpha(0.10)
                bolt.lineWidth = 1
                bolt.position = CGPoint(x: sign * 43 * s, y: 0)
                anchor.addChild(bolt)
            }

        case "bird":
            addBeakAnchor(to: anchor, s: s, color: WarmShelfPalette.butter, y: -19, width: 21, height: 16)
            let tuft = SKShapeNode(rect: CGRect(x: -2.5 * s, y: 38 * s, width: 5 * s, height: 14 * s), cornerRadius: 2.5 * s)
            tuft.fillColor = WarmShelfPalette.terracotta
            tuft.strokeColor = .clear
            anchor.addChild(tuft)

        case "duck":
            let beak = SKShapeNode(ellipseOf: CGSize(width: 34 * s, height: 17 * s))
            beak.fillColor = WarmShelfPalette.terracotta.withAlpha(0.95)
            beak.strokeColor = .clear
            beak.position = CGPoint(x: 0, y: -17 * s)
            anchor.addChild(beak)

        case "owl":
            for sign in [CGFloat(-1), CGFloat(1)] {
                let disc = SKShapeNode(circleOfRadius: 17 * s)
                disc.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.26)
                disc.strokeColor = ink.withAlpha(0.18)
                disc.lineWidth = 1.4 * s
                disc.position = CGPoint(x: sign * 18 * s, y: 8 * s)
                anchor.addChild(disc)
            }
            addBeakAnchor(to: anchor, s: s, color: WarmShelfPalette.butter, y: -18, width: 13, height: 12)

        case "penguin":
            let belly = SKShapeNode(ellipseOf: CGSize(width: 48 * s, height: 54 * s))
            belly.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.20)
            belly.strokeColor = .clear
            belly.position = CGPoint(x: 0, y: -8 * s)
            anchor.addChild(belly)
            addBeakAnchor(to: anchor, s: s, color: WarmShelfPalette.butter, y: -22, width: 17, height: 12)

        case "frog":
            for sign in [CGFloat(-1), CGFloat(1)] {
                let eyeBump = SKShapeNode(circleOfRadius: 16 * s)
                eyeBump.fillColor = WarmShelfPalette.sage.withAlpha(0.18)
                eyeBump.strokeColor = WarmShelfPalette.sage.withAlpha(0.28)
                eyeBump.lineWidth = 1
                eyeBump.position = CGPoint(x: sign * 20 * s, y: 38 * s)
                anchor.addChild(eyeBump)
            }

        case "lion":
            for index in 0..<10 {
                let angle = CGFloat(index) / 10 * .pi * 2
                let tuft = SKShapeNode(circleOfRadius: 7.5 * s)
                tuft.fillColor = WarmShelfPalette.terracotta.withAlpha(0.28)
                tuft.strokeColor = .clear
                tuft.position = CGPoint(x: cos(angle) * 48 * s, y: sin(angle) * 48 * s)
                anchor.addChild(tuft)
            }

        case "cat", "fox", "bunny", "mouse", "bear", "dog":
            addEarHighlights(to: anchor, baseName: baseName, s: s, accent: accent)

        case "zebra":
            for index in 0..<3 {
                let stripe = SKShapeNode(rect: CGRect(x: -2.5 * s, y: 0, width: 5 * s, height: 28 * s), cornerRadius: 2.5 * s)
                stripe.fillColor = ink.withAlpha(0.42)
                stripe.strokeColor = .clear
                stripe.position = CGPoint(x: CGFloat(index - 1) * 15 * s, y: 16 * s)
                stripe.zRotation = CGFloat(index - 1) * 0.18
                anchor.addChild(stripe)
            }

        case "pig":
            let snout = SKShapeNode(ellipseOf: CGSize(width: 30 * s, height: 21 * s))
            snout.fillColor = WarmShelfPalette.rhubarb.withAlpha(0.28)
            snout.strokeColor = .clear
            snout.position = CGPoint(x: 0, y: -13 * s)
            anchor.addChild(snout)
            for sign in [CGFloat(-1), CGFloat(1)] {
                let nostril = SKShapeNode(ellipseOf: CGSize(width: 4 * s, height: 7 * s))
                nostril.fillColor = ink.withAlpha(0.30)
                nostril.strokeColor = .clear
                nostril.position = CGPoint(x: sign * 7 * s, y: -13 * s)
                anchor.addChild(nostril)
            }

        default:
            break
        }
    }

    private static func addRareStorybookAura(to root: SKNode, zone: MixUpZone, recipe: TraitRecipe, s: CGFloat) {
        let aura = SKNode()
        aura.zPosition = -4
        root.addChild(aura)
        let bounds = textureBounds(for: zone, s: s).insetBy(dx: -18 * s, dy: -14 * s)
        let glow = SKShapeNode(ellipseOf: CGSize(width: bounds.width, height: bounds.height))
        glow.fillColor = recipe.palette.accent.withAlpha(0.12)
        glow.strokeColor = WarmShelfPalette.paperHighlight.withAlpha(0.22)
        glow.lineWidth = 2 * s
        glow.position = CGPoint(x: bounds.midX, y: bounds.midY)
        aura.addChild(glow)

        var rng = SeededGenerator(seed: recipe.seed &+ 0xB10C)
        for _ in 0..<5 {
            let mote = SKShapeNode(circleOfRadius: random(1.8...3.2, using: &rng) * s)
            mote.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.58)
            mote.strokeColor = .clear
            mote.position = randomPoint(in: bounds, using: &rng)
            aura.addChild(mote)
        }
    }

    private static func textureBounds(for zone: MixUpZone, s: CGFloat) -> CGRect {
        switch zone {
        case .head:
            return CGRect(x: -40 * s, y: -34 * s, width: 80 * s, height: 78 * s)
        case .body:
            return CGRect(x: -44 * s, y: -56 * s, width: 88 * s, height: 108 * s)
        case .legs:
            return CGRect(x: -38 * s, y: -12 * s, width: 76 * s, height: 50 * s)
        }
    }

    private static func faceAvoidanceBounds(for zone: MixUpZone, s: CGFloat) -> CGRect? {
        guard zone == .head else { return nil }
        return CGRect(x: -34 * s, y: -24 * s, width: 68 * s, height: 56 * s)
    }

    private static func randomPoint(in rect: CGRect, avoiding avoided: CGRect? = nil, using rng: inout SeededGenerator) -> CGPoint {
        for _ in 0..<8 {
            let point = CGPoint(x: random(rect.minX...rect.maxX, using: &rng), y: random(rect.minY...rect.maxY, using: &rng))
            if avoided?.contains(point) != true { return point }
        }
        return CGPoint(
            x: random(rect.minX...rect.maxX, using: &rng),
            y: random(rect.minY...min(rect.maxY, rect.minY + rect.height * 0.28), using: &rng)
        )
    }

    private static func arcPath(radius: CGFloat, start: CGFloat, end: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.addArc(center: .zero, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        return path
    }

    private static func addBeakAnchor(to node: SKNode, s: CGFloat, color: UIColor, y: CGFloat, width: CGFloat, height: CGFloat) {
        let beak = SKShapeNode(path: {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -width * 0.5 * s, y: y * s))
            p.addLine(to: CGPoint(x: width * 0.5 * s, y: y * s))
            p.addLine(to: CGPoint(x: 0, y: (y - height) * s))
            p.closeSubpath()
            return p
        }())
        beak.fillColor = color.withAlpha(0.92)
        beak.strokeColor = .clear
        node.addChild(beak)
    }

    private static func addEarHighlights(to node: SKNode, baseName: String, s: CGFloat, accent: UIColor) {
        let specs: [(CGFloat, CGFloat, CGFloat)]
        switch baseName {
        case "bunny":
            specs = [(-17, 57, 0.16), (17, 57, -0.16)]
        case "dog":
            specs = [(-40, 8, -0.18), (40, 8, 0.18)]
        case "mouse", "bear":
            specs = [(-30, 35, 0), (30, 35, 0)]
        default:
            specs = [(-30, 40, -0.16), (30, 40, 0.16)]
        }
        for spec in specs {
            let mark = SKShapeNode(ellipseOf: CGSize(width: 12 * s, height: 8 * s))
            mark.fillColor = accent.withAlpha(0.22)
            mark.strokeColor = .clear
            mark.position = CGPoint(x: spec.0 * s, y: spec.1 * s)
            mark.zRotation = spec.2
            node.addChild(mark)
        }
    }

    // MARK: - Shared face helpers

    // Faces now come from the shared CuteKit so cuteness is identical everywhere.
    private static func eyes(on node: SKNode, s: CGFloat, spacing: CGFloat = 18, y: CGFloat = 6, r: CGFloat = 7) {
        CuteFace.eyes(on: node, s: s, spacing: spacing, y: y, r: r + 1.6, style: .round)
    }

    private static func cheeks(on node: SKNode, s: CGFloat, spacing: CGFloat = 30, y: CGFloat = -6) {
        CuteFace.cheeks(on: node, s: s, spacing: spacing, y: y, r: 6)
    }

    private static func smile(on node: SKNode, s: CGFloat, width: CGFloat = 18, y: CGFloat = -14) {
        CuteFace.mouth(on: node, s: s, width: width * 0.85, y: y, style: .smile)
    }

    private static func headCircle(_ color: UIColor, s: CGFloat, radius: CGFloat = 46) -> SKShapeNode {
        let head = SKShapeNode(circleOfRadius: radius * s)
        head.fillColor = color.mixUpOpaque
        head.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.05)
        head.lineWidth = 1
        markPrimaryClay(head, name: primaryHeadName, size: CGSize(width: radius * 2 * s, height: radius * 2 * s))
        ProceduralTexture.addMatteClayDepth(
            to: head,
            ellipse: CGSize(width: radius * 2 * s, height: radius * 2 * s),
            zPosition: 0.1,
            highlightAlpha: 0.18,
            shadeAlpha: 0.038,
            rimAlpha: 0.026,
            speckleCount: 0
        )
        return head
    }

    // MARK: - Heads

    private static var heads: [MixUpPart] {
        [
            MixUpPart(name: "king") { s in
                let n = SKNode()
                let head = headCircle(WarmShelfPalette.petal.withAlpha(0.95), s: s); n.addChild(head)
                // Zigzag gold crown.
                let crown = SKShapeNode(path: {
                    let p = CGMutablePath(); let w = 56 * s; let b = 30 * s; let h = 26 * s
                    p.move(to: CGPoint(x: -w / 2, y: b))
                    p.addLine(to: CGPoint(x: -w / 2, y: b + h * 0.5))
                    p.addLine(to: CGPoint(x: -w / 4, y: b + h * 0.1))
                    p.addLine(to: CGPoint(x: 0, y: b + h))
                    p.addLine(to: CGPoint(x: w / 4, y: b + h * 0.1))
                    p.addLine(to: CGPoint(x: w / 2, y: b + h * 0.5))
                    p.addLine(to: CGPoint(x: w / 2, y: b)); p.closeSubpath(); return p
                }())
                crown.fillColor = WarmShelfPalette.butter; crown.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.08); crown.lineWidth = 1
                n.addChild(crown)
                eyes(on: n, s: s); cheeks(on: n, s: s); smile(on: n, s: s)
                return n
            },
            MixUpPart(name: "queen") { s in
                let n = SKNode()
                n.addChild(headCircle(WarmShelfPalette.petal.withAlpha(0.95), s: s))
                // Hair tufts on the sides.
                for sign in [CGFloat(-1), CGFloat(1)] {
                    let hair = SKShapeNode(ellipseOf: CGSize(width: 22 * s, height: 40 * s))
                    hair.fillColor = WarmShelfPalette.cocoa.withAlpha(0.5); hair.strokeColor = .clear
                    hair.position = CGPoint(x: sign * 40 * s, y: 0); n.addChild(hair)
                }
                let tiara = SKShapeNode(path: {
                    let p = CGMutablePath(); let w = 40 * s; let b = 30 * s
                    p.move(to: CGPoint(x: -w / 2, y: b)); p.addLine(to: CGPoint(x: 0, y: b + 20 * s)); p.addLine(to: CGPoint(x: w / 2, y: b)); return p
                }())
                tiara.fillColor = .clear; tiara.strokeColor = WarmShelfPalette.butter; tiara.lineWidth = 5 * s; tiara.lineJoin = .round
                n.addChild(tiara)
                let gem = SKShapeNode(circleOfRadius: 4 * s); gem.fillColor = WarmShelfPalette.rhubarb; gem.strokeColor = .clear; gem.position = CGPoint(x: 0, y: 44 * s); n.addChild(gem)
                eyes(on: n, s: s); cheeks(on: n, s: s); smile(on: n, s: s)
                return n
            },
            MixUpPart(name: "bear") { s in
                let n = SKNode()
                for sign in [CGFloat(-1), CGFloat(1)] {
                    let ear = SKShapeNode(circleOfRadius: 16 * s); ear.fillColor = UIColor(hex: 0x9B6B43); ear.strokeColor = .clear
                    ear.position = CGPoint(x: sign * 30 * s, y: 36 * s); n.addChild(ear)
                    let inner = SKShapeNode(circleOfRadius: 8 * s); inner.fillColor = WarmShelfPalette.petal.withAlpha(0.7); inner.strokeColor = .clear; inner.position = ear.position; n.addChild(inner)
                }
                n.addChild(headCircle(UIColor(hex: 0x9B6B43), s: s))
                let muzzle = SKShapeNode(ellipseOf: CGSize(width: 34 * s, height: 26 * s)); muzzle.fillColor = WarmShelfPalette.sand.withAlpha(0.95); muzzle.strokeColor = .clear; muzzle.position = CGPoint(x: 0, y: -10 * s); n.addChild(muzzle)
                let nose = SKShapeNode(ellipseOf: CGSize(width: 12 * s, height: 8 * s)); nose.fillColor = WarmShelfPalette.cocoa.withAlpha(0.8); nose.strokeColor = .clear; nose.position = CGPoint(x: 0, y: -4 * s); n.addChild(nose)
                eyes(on: n, s: s, spacing: 16, y: 10); cheeks(on: n, s: s, spacing: 30, y: -8)
                return n
            },
            MixUpPart(name: "zebra") { s in
                let n = SKNode()
                n.addChild(headCircle(WarmShelfPalette.paperHighlight, s: s, radius: 44))
                // Stripes.
                for i in 0..<3 {
                    let stripe = SKShapeNode(rect: CGRect(x: -3 * s, y: 0, width: 6 * s, height: 30 * s), cornerRadius: 3 * s)
                    stripe.fillColor = WarmShelfPalette.cocoa.withAlpha(0.8); stripe.strokeColor = .clear
                    stripe.position = CGPoint(x: CGFloat(i - 1) * 16 * s, y: 14 * s); stripe.zRotation = CGFloat(i - 1) * 0.2
                    n.addChild(stripe)
                }
                let mane = SKShapeNode(rect: CGRect(x: -4 * s, y: 30 * s, width: 8 * s, height: 22 * s), cornerRadius: 4 * s); mane.fillColor = WarmShelfPalette.cocoa.withAlpha(0.85); mane.strokeColor = .clear; n.addChild(mane)
                let muzzle = SKShapeNode(ellipseOf: CGSize(width: 30 * s, height: 22 * s)); muzzle.fillColor = WarmShelfPalette.terracotta.withAlpha(0.5); muzzle.strokeColor = .clear; muzzle.position = CGPoint(x: 0, y: -16 * s); n.addChild(muzzle)
                eyes(on: n, s: s, spacing: 18, y: 2); cheeks(on: n, s: s, y: -18)
                return n
            },
            MixUpPart(name: "mouse") { s in
                let n = SKNode()
                for sign in [CGFloat(-1), CGFloat(1)] {
                    let ear = SKShapeNode(circleOfRadius: 20 * s); ear.fillColor = UIColor(hex: 0xA9A29B); ear.strokeColor = .clear
                    ear.position = CGPoint(x: sign * 30 * s, y: 34 * s); n.addChild(ear)
                    let inner = SKShapeNode(circleOfRadius: 12 * s); inner.fillColor = WarmShelfPalette.petal.withAlpha(0.8); inner.strokeColor = .clear; inner.position = ear.position; n.addChild(inner)
                }
                n.addChild(headCircle(UIColor(hex: 0xA9A29B), s: s, radius: 42))
                let nose = SKShapeNode(circleOfRadius: 5 * s); nose.fillColor = WarmShelfPalette.petal; nose.strokeColor = .clear; nose.position = CGPoint(x: 0, y: -16 * s); n.addChild(nose)
                eyes(on: n, s: s, spacing: 15, y: 4); cheeks(on: n, s: s, spacing: 28, y: -12)
                return n
            },
            MixUpPart(name: "bird") { s in
                let n = SKNode()
                n.addChild(headCircle(WarmShelfPalette.waterBlue.withAlpha(0.95), s: s, radius: 42))
                let beak = SKShapeNode(path: {
                    let p = CGMutablePath(); p.move(to: CGPoint(x: -10 * s, y: -8 * s)); p.addLine(to: CGPoint(x: 10 * s, y: -8 * s)); p.addLine(to: CGPoint(x: 0, y: -22 * s)); p.closeSubpath(); return p
                }())
                beak.fillColor = WarmShelfPalette.butter; beak.strokeColor = .clear; n.addChild(beak)
                let tuft = SKShapeNode(rect: CGRect(x: -2.5 * s, y: 38 * s, width: 5 * s, height: 14 * s), cornerRadius: 2.5 * s); tuft.fillColor = WarmShelfPalette.terracotta; tuft.strokeColor = .clear; n.addChild(tuft)
                eyes(on: n, s: s, spacing: 16, y: 8); cheeks(on: n, s: s, y: -6)
                return n
            },
            MixUpPart(name: "cat") { s in
                let n = SKNode()
                let fur = WarmShelfPalette.sand
                pointyEars(on: n, s: s, color: fur, spread: 30, baseY: 28, tipY: 60, width: 26)
                n.addChild(headCircle(fur, s: s, radius: 44))
                let nose = SKShapeNode(path: {
                    let p = CGMutablePath(); p.move(to: CGPoint(x: -5 * s, y: -8 * s)); p.addLine(to: CGPoint(x: 5 * s, y: -8 * s)); p.addLine(to: CGPoint(x: 0, y: -15 * s)); p.closeSubpath(); return p
                }())
                nose.fillColor = WarmShelfPalette.petal; nose.strokeColor = .clear; n.addChild(nose)
                for sign in [CGFloat(-1), CGFloat(1)] {
                    let whisk = SKShapeNode(rect: CGRect(x: sign > 0 ? 0 : -26 * s, y: -0.8 * s, width: 26 * s, height: 1.6 * s), cornerRadius: 0.8 * s)
                    whisk.fillColor = WarmShelfPalette.cocoa.withAlpha(0.35); whisk.strokeColor = .clear
                    whisk.position = CGPoint(x: sign * 16 * s, y: -14 * s); n.addChild(whisk)
                }
                eyes(on: n, s: s, spacing: 17, y: 4); cheeks(on: n, s: s, y: -10)
                return n
            },
            MixUpPart(name: "fox") { s in
                let n = SKNode()
                let orange = WarmShelfPalette.terracotta
                pointyEars(on: n, s: s, color: orange, spread: 28, baseY: 30, tipY: 62, width: 24, innerColor: WarmShelfPalette.cocoa.withAlpha(0.5))
                n.addChild(headCircle(orange, s: s, radius: 44))
                // White cheek/snout patch.
                let patch = SKShapeNode(path: {
                    let p = CGMutablePath()
                    p.addEllipse(in: CGRect(x: -28 * s, y: -34 * s, width: 56 * s, height: 40 * s)); return p
                }())
                patch.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.92); patch.strokeColor = .clear; n.addChild(patch)
                let nose = SKShapeNode(circleOfRadius: 5 * s); nose.fillColor = WarmShelfPalette.cocoa.withAlpha(0.85); nose.strokeColor = .clear; nose.position = CGPoint(x: 0, y: -18 * s); n.addChild(nose)
                eyes(on: n, s: s, spacing: 17, y: 8); cheeks(on: n, s: s, y: -6)
                return n
            },
            MixUpPart(name: "frog") { s in
                let n = SKNode()
                let green = WarmShelfPalette.sage
                // Eye bulges on top.
                for sign in [CGFloat(-1), CGFloat(1)] {
                    let bulge = SKShapeNode(circleOfRadius: 17 * s); bulge.fillColor = green; bulge.strokeColor = .clear
                    bulge.position = CGPoint(x: sign * 20 * s, y: 36 * s); n.addChild(bulge)
                }
                n.addChild(headCircle(green, s: s, radius: 44))
                eyes(on: n, s: s, spacing: 20, y: 40, r: 8)
                let mouth = CGMutablePath()
                mouth.move(to: CGPoint(x: -28 * s, y: -8 * s))
                mouth.addQuadCurve(to: CGPoint(x: 28 * s, y: -8 * s), control: CGPoint(x: 0, y: -28 * s))
                let m = SKShapeNode(path: mouth); m.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.55); m.lineWidth = 3 * s; m.lineCap = .round; m.fillColor = .clear; n.addChild(m)
                cheeks(on: n, s: s, spacing: 32, y: -10)
                return n
            },
            MixUpPart(name: "lion") { s in
                let n = SKNode()
                let mane = WarmShelfPalette.terracotta.withAlpha(0.9)
                for i in 0..<12 {
                    let a = CGFloat(i) / 12 * .pi * 2
                    let tuft = SKShapeNode(circleOfRadius: 13 * s); tuft.fillColor = mane; tuft.strokeColor = .clear
                    tuft.position = CGPoint(x: cos(a) * 50 * s, y: sin(a) * 50 * s); n.addChild(tuft)
                }
                n.addChild(headCircle(WarmShelfPalette.butter, s: s, radius: 42))
                let muzzle = SKShapeNode(ellipseOf: CGSize(width: 30 * s, height: 22 * s)); muzzle.fillColor = WarmShelfPalette.sand.withAlpha(0.9); muzzle.strokeColor = .clear; muzzle.position = CGPoint(x: 0, y: -12 * s); n.addChild(muzzle)
                let nose = SKShapeNode(ellipseOf: CGSize(width: 10 * s, height: 7 * s)); nose.fillColor = WarmShelfPalette.cocoa.withAlpha(0.8); nose.strokeColor = .clear; nose.position = CGPoint(x: 0, y: -6 * s); n.addChild(nose)
                eyes(on: n, s: s, spacing: 16, y: 8); cheeks(on: n, s: s, y: -14)
                return n
            },
            MixUpPart(name: "bunny") { s in
                let n = SKNode()
                let fur = WarmShelfPalette.paperHighlight
                for sign in [CGFloat(-1), CGFloat(1)] {
                    let ear = SKShapeNode(ellipseOf: CGSize(width: 18 * s, height: 50 * s)); ear.fillColor = fur; ear.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.06); ear.lineWidth = 1
                    ear.position = CGPoint(x: sign * 16 * s, y: 56 * s); ear.zRotation = sign * 0.12; n.addChild(ear)
                    let inner = SKShapeNode(ellipseOf: CGSize(width: 8 * s, height: 32 * s)); inner.fillColor = WarmShelfPalette.petal.withAlpha(0.7); inner.strokeColor = .clear
                    inner.position = ear.position; inner.zRotation = ear.zRotation; n.addChild(inner)
                }
                n.addChild(headCircle(fur, s: s, radius: 42))
                let nose = SKShapeNode(circleOfRadius: 4 * s); nose.fillColor = WarmShelfPalette.petal; nose.strokeColor = .clear; nose.position = CGPoint(x: 0, y: -12 * s); n.addChild(nose)
                eyes(on: n, s: s, spacing: 16, y: 6); cheeks(on: n, s: s, spacing: 28, y: -12)
                return n
            },
            MixUpPart(name: "robot") { s in
                let n = SKNode()
                let metal = WarmShelfPalette.waterBlue.withAlpha(0.7)
                let antenna = SKShapeNode(rect: CGRect(x: -1.5 * s, y: 30 * s, width: 3 * s, height: 20 * s), cornerRadius: 1.5 * s); antenna.fillColor = WarmShelfPalette.cocoa.withAlpha(0.4); antenna.strokeColor = .clear; n.addChild(antenna)
                let ball = SKShapeNode(circleOfRadius: 6 * s); ball.fillColor = WarmShelfPalette.rhubarb; ball.strokeColor = .clear; ball.position = CGPoint(x: 0, y: 52 * s); n.addChild(ball)
                let headRect = CGRect(x: -42 * s, y: -42 * s, width: 84 * s, height: 84 * s)
                let head = SKShapeNode(rect: headRect, cornerRadius: 22 * s); head.fillColor = metal.mixUpOpaque; head.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.08); head.lineWidth = 1
                markPrimaryClay(head, name: primaryHeadName, size: headRect.size)
                ProceduralTexture.addMatteClayDepth(to: head, in: headRect, cornerRadius: 22 * s, zPosition: 0.1, highlightAlpha: 0.16, shadeAlpha: 0.038, rimAlpha: 0.025, speckleCount: 0)
                n.addChild(head)
                // Side bolts.
                for sign in [CGFloat(-1), CGFloat(1)] {
                    let bolt = SKShapeNode(circleOfRadius: 5 * s); bolt.fillColor = WarmShelfPalette.sand; bolt.strokeColor = .clear; bolt.position = CGPoint(x: sign * 42 * s, y: 0); n.addChild(bolt)
                }
                eyes(on: n, s: s, spacing: 18, y: 8, r: 8)
                let mouth = SKShapeNode(rect: CGRect(x: -18 * s, y: -20 * s, width: 36 * s, height: 7 * s), cornerRadius: 3 * s); mouth.fillColor = WarmShelfPalette.cocoa.withAlpha(0.5); mouth.strokeColor = .clear; n.addChild(mouth)
                return n
            },
            MixUpPart(name: "dog") { s in
                let n = SKNode()
                let fur = UIColor(hex: 0xC79A6B)
                // Floppy ears hang beside the head.
                for sign in [CGFloat(-1), CGFloat(1)] {
                    let ear = SKShapeNode(ellipseOf: CGSize(width: 22 * s, height: 46 * s)); ear.fillColor = UIColor(hex: 0x9B6B43); ear.strokeColor = .clear
                    ear.position = CGPoint(x: sign * 40 * s, y: 6 * s); ear.zRotation = sign * 0.18; n.addChild(ear)
                }
                n.addChild(headCircle(fur, s: s, radius: 44))
                let muzzle = SKShapeNode(ellipseOf: CGSize(width: 34 * s, height: 26 * s)); muzzle.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.92); muzzle.strokeColor = .clear; muzzle.position = CGPoint(x: 0, y: -12 * s); n.addChild(muzzle)
                let nose = SKShapeNode(ellipseOf: CGSize(width: 12 * s, height: 9 * s)); nose.fillColor = WarmShelfPalette.cocoa.withAlpha(0.85); nose.strokeColor = .clear; nose.position = CGPoint(x: 0, y: -6 * s); n.addChild(nose)
                eyes(on: n, s: s, spacing: 16, y: 10); cheeks(on: n, s: s, y: -16)
                return n
            },
            MixUpPart(name: "duck") { s in
                let n = SKNode()
                n.addChild(headCircle(WarmShelfPalette.butter, s: s, radius: 44))
                let beak = SKShapeNode(ellipseOf: CGSize(width: 34 * s, height: 18 * s)); beak.fillColor = WarmShelfPalette.terracotta.withAlpha(0.95); beak.strokeColor = .clear; beak.position = CGPoint(x: 0, y: -16 * s); n.addChild(beak)
                let tuft = SKShapeNode(path: {
                    let p = CGMutablePath(); p.move(to: CGPoint(x: -6 * s, y: 40 * s)); p.addQuadCurve(to: CGPoint(x: 16 * s, y: 54 * s), control: CGPoint(x: 18 * s, y: 40 * s)); p.addQuadCurve(to: CGPoint(x: -6 * s, y: 44 * s), control: CGPoint(x: 6 * s, y: 46 * s)); p.closeSubpath(); return p
                }())
                tuft.fillColor = WarmShelfPalette.butter; tuft.strokeColor = .clear; n.addChild(tuft)
                eyes(on: n, s: s, spacing: 15, y: 8); cheeks(on: n, s: s, spacing: 28, y: -6)
                return n
            },
            MixUpPart(name: "pig") { s in
                let n = SKNode()
                let pink = WarmShelfPalette.petal.withAlpha(0.92)
                for sign in [CGFloat(-1), CGFloat(1)] {
                    let ear = SKShapeNode(path: {
                        let p = CGMutablePath(); p.move(to: CGPoint(x: sign * 22 * s, y: 30 * s)); p.addLine(to: CGPoint(x: sign * 46 * s, y: 52 * s)); p.addLine(to: CGPoint(x: sign * 40 * s, y: 26 * s)); p.closeSubpath(); return p
                    }())
                    ear.fillColor = pink; ear.strokeColor = .clear; n.addChild(ear)
                }
                n.addChild(headCircle(pink, s: s, radius: 44))
                let snout = SKShapeNode(ellipseOf: CGSize(width: 30 * s, height: 22 * s)); snout.fillColor = WarmShelfPalette.rhubarb.withAlpha(0.4); snout.strokeColor = .clear; snout.position = CGPoint(x: 0, y: -12 * s); n.addChild(snout)
                for sign in [CGFloat(-1), CGFloat(1)] {
                    let nostril = SKShapeNode(ellipseOf: CGSize(width: 5 * s, height: 8 * s)); nostril.fillColor = WarmShelfPalette.cocoa.withAlpha(0.55); nostril.strokeColor = .clear; nostril.position = CGPoint(x: sign * 7 * s, y: -12 * s); n.addChild(nostril)
                }
                eyes(on: n, s: s, spacing: 17, y: 8); cheeks(on: n, s: s, y: -4)
                return n
            },
            MixUpPart(name: "owl") { s in
                let n = SKNode()
                let feather = WarmShelfPalette.sand
                for sign in [CGFloat(-1), CGFloat(1)] {
                    let tuft = SKShapeNode(path: {
                        let p = CGMutablePath(); p.move(to: CGPoint(x: sign * 18 * s, y: 36 * s)); p.addLine(to: CGPoint(x: sign * 34 * s, y: 58 * s)); p.addLine(to: CGPoint(x: sign * 34 * s, y: 34 * s)); p.closeSubpath(); return p
                    }())
                    tuft.fillColor = feather; tuft.strokeColor = .clear; n.addChild(tuft)
                }
                n.addChild(headCircle(feather, s: s, radius: 45))
                // Big owl eye discs.
                for sign in [CGFloat(-1), CGFloat(1)] {
                    let disc = SKShapeNode(circleOfRadius: 18 * s); disc.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.9); disc.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.08); disc.lineWidth = 1
                    disc.position = CGPoint(x: sign * 18 * s, y: 8 * s); n.addChild(disc)
                }
                CuteFace.eyes(on: n, s: s, spacing: 18, y: 8, r: 9, style: .round)
                let beak = SKShapeNode(path: {
                    let p = CGMutablePath(); p.move(to: CGPoint(x: -6 * s, y: -6 * s)); p.addLine(to: CGPoint(x: 6 * s, y: -6 * s)); p.addLine(to: CGPoint(x: 0, y: -18 * s)); p.closeSubpath(); return p
                }())
                beak.fillColor = WarmShelfPalette.butter; beak.strokeColor = .clear; n.addChild(beak)
                return n
            },
            MixUpPart(name: "penguin") { s in
                let n = SKNode()
                n.addChild(headCircle(WarmShelfPalette.clayInk.withAlpha(0.78), s: s, radius: 44))
                let face = SKShapeNode(ellipseOf: CGSize(width: 56 * s, height: 60 * s)); face.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.95); face.strokeColor = .clear; face.position = CGPoint(x: 0, y: -2 * s); n.addChild(face)
                let beak = SKShapeNode(path: {
                    let p = CGMutablePath(); p.move(to: CGPoint(x: -9 * s, y: -10 * s)); p.addLine(to: CGPoint(x: 9 * s, y: -10 * s)); p.addLine(to: CGPoint(x: 0, y: -22 * s)); p.closeSubpath(); return p
                }())
                beak.fillColor = WarmShelfPalette.butter; beak.strokeColor = .clear; n.addChild(beak)
                eyes(on: n, s: s, spacing: 14, y: 8); cheeks(on: n, s: s, spacing: 26, y: -4)
                return n
            }
        ]
    }

    /// Two triangular ears, mirrored, used by cat/fox.
    private static func pointyEars(on node: SKNode, s: CGFloat, color: UIColor, spread: CGFloat, baseY: CGFloat, tipY: CGFloat, width: CGFloat, innerColor: UIColor? = nil) {
        for sign in [CGFloat(-1), CGFloat(1)] {
            let ear = SKShapeNode(path: {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: sign * (spread - width / 2) * s, y: baseY * s))
                p.addLine(to: CGPoint(x: sign * (spread + width / 2) * s, y: baseY * s))
                p.addLine(to: CGPoint(x: sign * (spread + width / 4) * s, y: tipY * s))
                p.closeSubpath(); return p
            }())
            ear.fillColor = color; ear.strokeColor = .clear; node.addChild(ear)
            if let inner = innerColor {
                let tip = SKShapeNode(circleOfRadius: 5 * s); tip.fillColor = inner; tip.strokeColor = .clear
                tip.position = CGPoint(x: sign * (spread + width / 4) * s, y: (tipY - 8) * s); node.addChild(tip)
            }
        }
    }

    // MARK: - Bodies

    private static func torso(_ color: UIColor, s: CGFloat) -> SKNode {
        let container = SKNode()
        let baseColor = color.mixUpOpaque
        // Arms (behind the torso) with little round hands.
        for sign in [CGFloat(-1), CGFloat(1)] {
            let armRect = CGRect(x: -10 * s, y: -56 * s, width: 20 * s, height: 70 * s)
            let arm = SKShapeNode(rect: armRect, cornerRadius: 10 * s)
            arm.fillColor = baseColor; arm.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.05); arm.lineWidth = 1
            ProceduralTexture.addMatteClayDepth(to: arm, in: armRect, cornerRadius: 10 * s, zPosition: 0.1, highlightAlpha: 0.10, shadeAlpha: 0.025, rimAlpha: 0.018, speckleCount: 0)
            arm.position = CGPoint(x: sign * 42 * s, y: 8 * s)
            arm.zRotation = sign * -0.14
            arm.zPosition = -3
            container.addChild(arm)
            let hand = SKShapeNode(circleOfRadius: 13 * s)
            hand.fillColor = baseColor; hand.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.06); hand.lineWidth = 1
            hand.position = CGPoint(x: sign * 50 * s, y: -30 * s)
            ProceduralTexture.addMatteClayDepth(to: hand, ellipse: CGSize(width: 26 * s, height: 26 * s), zPosition: 0.1, highlightAlpha: 0.12, shadeAlpha: 0.026, rimAlpha: 0.018, speckleCount: 0)
            hand.zPosition = -2
            container.addChild(hand)
        }
        // Body skirts a little lower so it always overlaps the tops of the legs — no weak
        // seam where the thin legs meet the rounded body.
        let bodyRect = CGRect(x: -42 * s, y: -62 * s, width: 84 * s, height: 114 * s)
        let body = SKShapeNode(rect: bodyRect, cornerRadius: 26 * s)
        body.fillColor = baseColor; body.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.05); body.lineWidth = 1
        markPrimaryClay(body, name: primaryTorsoName, size: bodyRect.size)
        ProceduralTexture.addMatteClayDepth(to: body, in: bodyRect, cornerRadius: 26 * s, zPosition: 0.1, highlightAlpha: 0.16, shadeAlpha: 0.038, rimAlpha: 0.026, speckleCount: 0)
        body.zPosition = 0
        container.addChild(body)
        // A soft hip base centred over the leg join, for a connected silhouette.
        let hip = SKShapeNode(ellipseOf: CGSize(width: 70 * s, height: 34 * s))
        hip.fillColor = baseColor; hip.strokeColor = .clear
        hip.position = CGPoint(x: 0, y: -54 * s)
        ProceduralTexture.addMatteClayDepth(to: hip, ellipse: CGSize(width: 70 * s, height: 34 * s), zPosition: 0.1, highlightAlpha: 0.10, shadeAlpha: 0.022, rimAlpha: 0.014, speckleCount: 0)
        hip.zPosition = 0.4
        container.addChild(hip)
        return container
    }

    private static var bodies: [MixUpPart] {
        [
            MixUpPart(name: "royal robe") { s in
                let n = SKNode(); n.addChild(torso(WarmShelfPalette.rhubarb, s: s))
                for i in 0..<3 {
                    let trim = SKShapeNode(rect: CGRect(x: -8 * s, y: -52 * s, width: 16 * s, height: 104 * s), cornerRadius: 4 * s)
                    trim.fillColor = WarmShelfPalette.butter.withAlpha(0.96); trim.strokeColor = .clear
                    trim.position = CGPoint(x: CGFloat(i - 1) * 22 * s, y: 0); trim.zPosition = 8; n.addChild(trim)
                    for j in 0..<4 {
                        let dot = SKShapeNode(circleOfRadius: 2.5 * s); dot.fillColor = WarmShelfPalette.cocoa.withAlpha(0.68); dot.strokeColor = .clear
                        dot.position = CGPoint(x: CGFloat(i - 1) * 22 * s, y: -36 * s + CGFloat(j) * 24 * s); dot.zPosition = 9; n.addChild(dot)
                    }
                }
                return n
            },
            MixUpPart(name: "striped") { s in
                let n = SKNode(); n.addChild(torso(WarmShelfPalette.paperHighlight, s: s))
                for i in 0..<4 {
                    let stripe = SKShapeNode(rect: CGRect(x: -34 * s, y: -40 * s + CGFloat(i) * 26 * s, width: 68 * s, height: 12 * s), cornerRadius: 6 * s)
                    stripe.fillColor = WarmShelfPalette.cocoa.withAlpha(0.86); stripe.strokeColor = .clear; stripe.zPosition = 8; n.addChild(stripe)
                }
                return n
            },
            MixUpPart(name: "overalls") { s in
                let n = SKNode(); n.addChild(torso(WarmShelfPalette.waterBlue, s: s))
                for sign in [CGFloat(-1), CGFloat(1)] {
                    let strap = SKShapeNode(rect: CGRect(x: sign * 18 * s - 5 * s, y: 0, width: 10 * s, height: 52 * s), cornerRadius: 4 * s)
                    strap.fillColor = WarmShelfPalette.sand.withAlpha(0.98); strap.strokeColor = .clear; strap.zPosition = 8; n.addChild(strap)
                }
                let pocket = SKShapeNode(rect: CGRect(x: -16 * s, y: -20 * s, width: 32 * s, height: 26 * s), cornerRadius: 6 * s); pocket.fillColor = WarmShelfPalette.sand.withAlpha(0.84); pocket.strokeColor = .clear; pocket.zPosition = 9; n.addChild(pocket)
                return n
            },
            MixUpPart(name: "star sweater") { s in
                let n = SKNode(); n.addChild(torso(WarmShelfPalette.sage, s: s))
                let star = SKShapeNode(path: starPath(radius: 22 * s)); star.fillColor = WarmShelfPalette.butter; star.strokeColor = .clear; star.position = CGPoint(x: 0, y: 4 * s); n.addChild(star)
                return n
            },
            MixUpPart(name: "bird belly") { s in
                let n = SKNode(); n.addChild(torso(WarmShelfPalette.waterBlue, s: s))
                let belly = SKShapeNode(ellipseOf: CGSize(width: 48 * s, height: 70 * s)); belly.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.90); belly.strokeColor = .clear; belly.position = CGPoint(x: 0, y: -6 * s); belly.zPosition = 8; n.addChild(belly)
                let wing = SKShapeNode(ellipseOf: CGSize(width: 22 * s, height: 40 * s)); wing.fillColor = WarmShelfPalette.waterBlue.mixUpOpaque; wing.strokeColor = .clear; wing.position = CGPoint(x: -34 * s, y: 2 * s); wing.zPosition = 7; n.addChild(wing)
                return n
            },
            MixUpPart(name: "polka dress") { s in
                let n = SKNode(); n.addChild(torso(WarmShelfPalette.lavender, s: s))
                // A-line skirt flare at the hem.
                let skirt = SKShapeNode(path: {
                    let p = CGMutablePath()
                    p.move(to: CGPoint(x: -42 * s, y: -30 * s))
                    p.addLine(to: CGPoint(x: -58 * s, y: -52 * s))
                    p.addLine(to: CGPoint(x: 58 * s, y: -52 * s))
                    p.addLine(to: CGPoint(x: 42 * s, y: -30 * s)); p.closeSubpath(); return p
                }())
                skirt.fillColor = WarmShelfPalette.lavender.mixUpOpaque; skirt.strokeColor = .clear; skirt.zPosition = -0.6; n.addChild(skirt)
                for i in 0..<10 {
                    let dot = SKShapeNode(circleOfRadius: 4 * s); dot.fillColor = WarmShelfPalette.paperHighlight.withAlpha(0.92); dot.strokeColor = .clear
                    dot.position = CGPoint(x: CGFloat((i % 3) - 1) * 26 * s + (i % 2 == 0 ? 0 : 13 * s), y: -44 * s + CGFloat(i / 3) * 26 * s); dot.zPosition = -0.5; n.addChild(dot)
                }
                return n
            },
            MixUpPart(name: "rainbow") { s in
                let n = SKNode(); n.addChild(torso(WarmShelfPalette.paperHighlight, s: s))
                let bands: [UIColor] = [WarmShelfPalette.rhubarb, WarmShelfPalette.terracotta, WarmShelfPalette.butter, WarmShelfPalette.sage, WarmShelfPalette.waterBlue]
                for (i, c) in bands.enumerated() {
                    let band = SKShapeNode(rect: CGRect(x: -36 * s, y: -48 * s + CGFloat(i) * 20 * s, width: 72 * s, height: 18 * s), cornerRadius: 5 * s)
                    band.fillColor = c.withAlpha(0.96); band.strokeColor = .clear; band.zPosition = 8; n.addChild(band)
                }
                return n
            },
            MixUpPart(name: "spacesuit") { s in
                let n = SKNode(); n.addChild(torso(WarmShelfPalette.paperHighlight, s: s))
                let collar = SKShapeNode(ellipseOf: CGSize(width: 56 * s, height: 18 * s)); collar.fillColor = WarmShelfPalette.waterBlue.withAlpha(0.72); collar.strokeColor = .clear; collar.position = CGPoint(x: 0, y: 44 * s); collar.zPosition = 8; n.addChild(collar)
                let panel = SKShapeNode(rect: CGRect(x: -22 * s, y: -22 * s, width: 44 * s, height: 44 * s), cornerRadius: 10 * s); panel.fillColor = WarmShelfPalette.sand.withAlpha(0.84); panel.strokeColor = .clear; panel.zPosition = 9; n.addChild(panel)
                for (i, c) in [WarmShelfPalette.rhubarb, WarmShelfPalette.butter, WarmShelfPalette.sage].enumerated() {
                    let btn = SKShapeNode(circleOfRadius: 4.5 * s); btn.fillColor = c; btn.strokeColor = .clear
                    btn.position = CGPoint(x: CGFloat(i - 1) * 14 * s, y: 0); btn.zPosition = 10; n.addChild(btn)
                }
                return n
            },
            MixUpPart(name: "knit sweater") { s in
                let n = SKNode(); n.addChild(torso(WarmShelfPalette.terracotta, s: s))
                // Knit V-chevrons for woven texture.
                for row in 0..<4 {
                    let y = -36 * s + CGFloat(row) * 24 * s
                    let v = CGMutablePath()
                    v.move(to: CGPoint(x: -30 * s, y: y + 8 * s))
                    v.addLine(to: CGPoint(x: 0, y: y - 8 * s))
                    v.addLine(to: CGPoint(x: 30 * s, y: y + 8 * s))
                    let chevron = SKShapeNode(path: v); chevron.strokeColor = WarmShelfPalette.sand.withAlpha(0.70); chevron.lineWidth = 2.4 * s; chevron.lineJoin = .round; chevron.fillColor = .clear; chevron.zPosition = 8; n.addChild(chevron)
                }
                return n
            },
            MixUpPart(name: "flower petals") { s in
                let n = SKNode()
                // Petal collar behind the torso.
                for i in 0..<8 {
                    let a = CGFloat(i) / 8 * .pi * 2
                    let petal = SKShapeNode(ellipseOf: CGSize(width: 22 * s, height: 34 * s)); petal.fillColor = WarmShelfPalette.petal.withAlpha(0.94); petal.strokeColor = .clear
                    petal.position = CGPoint(x: cos(a) * 36 * s, y: 30 * s + sin(a) * 36 * s); petal.zRotation = a; petal.zPosition = -1; n.addChild(petal)
                }
                n.addChild(torso(WarmShelfPalette.sage, s: s))
                let center = SKShapeNode(circleOfRadius: 14 * s); center.fillColor = WarmShelfPalette.butter; center.strokeColor = .clear; center.position = CGPoint(x: 0, y: 6 * s); center.zPosition = 9; n.addChild(center)
                return n
            }
        ]
    }

    // MARK: - Legs

    private static var legs: [MixUpPart] {
        [
            MixUpPart(name: "boots") { s in
                let n = SKNode()
                for sign in [CGFloat(-1), CGFloat(1)] {
                    let leg = SKShapeNode(rect: CGRect(x: sign * 16 * s - 9 * s, y: 0, width: 18 * s, height: 34 * s), cornerRadius: 8 * s); leg.fillColor = WarmShelfPalette.cocoa.withAlpha(0.7); leg.strokeColor = .clear; n.addChild(leg)
                    let boot = SKShapeNode(ellipseOf: CGSize(width: 28 * s, height: 16 * s)); boot.fillColor = WarmShelfPalette.terracotta; boot.strokeColor = .clear; boot.position = CGPoint(x: sign * 16 * s + 4 * s, y: 2 * s); n.addChild(boot)
                }
                return n
            },
            MixUpPart(name: "bird legs") { s in
                let n = SKNode()
                for sign in [CGFloat(-1), CGFloat(1)] {
                    let leg = SKShapeNode(rect: CGRect(x: sign * 12 * s - 2 * s, y: 6 * s, width: 4 * s, height: 30 * s), cornerRadius: 2 * s); leg.fillColor = WarmShelfPalette.terracotta.withAlpha(0.9); leg.strokeColor = .clear; n.addChild(leg)
                    let foot = SKShapeNode(path: { let p = CGMutablePath(); p.move(to: CGPoint(x: sign * 12 * s - 10 * s, y: 6 * s)); p.addLine(to: CGPoint(x: sign * 12 * s + 10 * s, y: 6 * s)); p.addLine(to: CGPoint(x: sign * 12 * s, y: 0)); p.closeSubpath(); return p }()); foot.fillColor = WarmShelfPalette.terracotta.withAlpha(0.9); foot.strokeColor = .clear; n.addChild(foot)
                }
                return n
            },
            MixUpPart(name: "paws") { s in
                let n = SKNode()
                for sign in [CGFloat(-1), CGFloat(1)] {
                    let paw = SKShapeNode(ellipseOf: CGSize(width: 26 * s, height: 22 * s)); paw.fillColor = UIColor(hex: 0x9B6B43); paw.strokeColor = .clear; paw.position = CGPoint(x: sign * 16 * s, y: 14 * s); n.addChild(paw)
                    let pad = SKShapeNode(ellipseOf: CGSize(width: 10 * s, height: 8 * s)); pad.fillColor = WarmShelfPalette.petal.withAlpha(0.6); pad.strokeColor = .clear; pad.position = CGPoint(x: sign * 16 * s, y: 12 * s); n.addChild(pad)
                }
                return n
            },
            MixUpPart(name: "striped socks") { s in
                let n = SKNode()
                for sign in [CGFloat(-1), CGFloat(1)] {
                    let leg = SKShapeNode(rect: CGRect(x: sign * 16 * s - 9 * s, y: 0, width: 18 * s, height: 36 * s), cornerRadius: 8 * s); leg.fillColor = WarmShelfPalette.paperHighlight; leg.strokeColor = .clear; n.addChild(leg)
                    for j in 0..<3 {
                        let band = SKShapeNode(rect: CGRect(x: sign * 16 * s - 9 * s, y: 4 * s + CGFloat(j) * 11 * s, width: 18 * s, height: 5 * s), cornerRadius: 2 * s); band.fillColor = WarmShelfPalette.terracotta.withAlpha(0.85); band.strokeColor = .clear; n.addChild(band)
                    }
                }
                return n
            },
            MixUpPart(name: "rain boots") { s in
                let n = SKNode()
                for sign in [CGFloat(-1), CGFloat(1)] {
                    let leg = SKShapeNode(rect: CGRect(x: sign * 16 * s - 8 * s, y: 0, width: 16 * s, height: 24 * s), cornerRadius: 6 * s); leg.fillColor = WarmShelfPalette.cocoa.withAlpha(0.55); leg.strokeColor = .clear; n.addChild(leg)
                    let boot = SKShapeNode(path: {
                        let p = CGMutablePath()
                        p.addRoundedRect(in: CGRect(x: sign * 16 * s - 11 * s, y: -22 * s, width: 22 * s, height: 28 * s), cornerWidth: 9 * s, cornerHeight: 9 * s)
                        p.addEllipse(in: CGRect(x: sign * 16 * s - 14 * s, y: -24 * s, width: 32 * s, height: 16 * s)); return p
                    }())
                    boot.fillColor = WarmShelfPalette.sage; boot.strokeColor = .clear; n.addChild(boot)
                }
                return n
            },
            MixUpPart(name: "sneakers") { s in
                let n = SKNode()
                for sign in [CGFloat(-1), CGFloat(1)] {
                    let leg = SKShapeNode(rect: CGRect(x: sign * 16 * s - 8 * s, y: 0, width: 16 * s, height: 30 * s), cornerRadius: 7 * s); leg.fillColor = WarmShelfPalette.waterBlue.withAlpha(0.8); leg.strokeColor = .clear; n.addChild(leg)
                    let shoe = SKShapeNode(path: {
                        let p = CGMutablePath(); p.addRoundedRect(in: CGRect(x: sign * 16 * s - 16 * s, y: -4 * s, width: 34 * s, height: 16 * s), cornerWidth: 8 * s, cornerHeight: 8 * s); return p
                    }())
                    shoe.fillColor = WarmShelfPalette.paperHighlight; shoe.strokeColor = WarmShelfPalette.cocoa.withAlpha(0.08); shoe.lineWidth = 1; n.addChild(shoe)
                    let sole = SKShapeNode(rect: CGRect(x: sign * 16 * s - 16 * s, y: -6 * s, width: 34 * s, height: 5 * s), cornerRadius: 2.5 * s); sole.fillColor = WarmShelfPalette.rhubarb.withAlpha(0.8); sole.strokeColor = .clear; n.addChild(sole)
                }
                return n
            },
            MixUpPart(name: "frog feet") { s in
                let n = SKNode()
                for sign in [CGFloat(-1), CGFloat(1)] {
                    let leg = SKShapeNode(rect: CGRect(x: sign * 16 * s - 7 * s, y: 4 * s, width: 14 * s, height: 26 * s), cornerRadius: 7 * s); leg.fillColor = WarmShelfPalette.sage; leg.strokeColor = .clear; n.addChild(leg)
                    let foot = SKShapeNode(path: {
                        let p = CGMutablePath()
                        for t in [CGFloat(-1), 0, 1] {
                            p.addEllipse(in: CGRect(x: sign * 16 * s + t * 9 * s - 6 * s, y: -6 * s, width: 12 * s, height: 16 * s))
                        }
                        return p
                    }())
                    foot.fillColor = WarmShelfPalette.sage; foot.strokeColor = .clear; n.addChild(foot)
                }
                return n
            }
        ]
    }

    private static func starPath(radius r: CGFloat) -> CGPath {
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

private extension MixUpZone {
    var seedKey: String {
        switch self {
        case .head: return "head"
        case .body: return "body"
        case .legs: return "legs"
        }
    }
}

private extension UIColor {
    var mixUpAlpha: CGFloat {
        var alpha: CGFloat = 0
        getRed(nil, green: nil, blue: nil, alpha: &alpha)
        return alpha
    }

    var mixUpBrightness: CGFloat {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard getRed(&r, green: &g, blue: &b, alpha: &a) else { return 0.5 }
        return (r * 0.299 + g * 0.587 + b * 0.114)
    }

    var mixUpOpaque: UIColor {
        mixUpWithAlpha(1)
    }

    func mixUpWithAlpha(_ alpha: CGFloat) -> UIColor {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return withAlphaComponent(alpha)
        }
        return UIColor(red: r, green: g, blue: b, alpha: alpha)
    }

    func mixUpMixed(with other: UIColor, _ amount: CGFloat) -> UIColor {
        var r1: CGFloat = 0
        var g1: CGFloat = 0
        var b1: CGFloat = 0
        var a1: CGFloat = 0
        var r2: CGFloat = 0
        var g2: CGFloat = 0
        var b2: CGFloat = 0
        var a2: CGFloat = 0
        guard getRed(&r1, green: &g1, blue: &b1, alpha: &a1),
              other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        else { return self }
        let t = amount.clamped(to: 0...1)
        return UIColor(
            red: r1 + (r2 - r1) * t,
            green: g1 + (g2 - g1) * t,
            blue: b1 + (b2 - b1) * t,
            alpha: a1
        )
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
