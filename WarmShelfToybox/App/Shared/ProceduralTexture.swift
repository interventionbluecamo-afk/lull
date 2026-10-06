import SpriteKit
import UIKit
import CoreImage

/// Drop-in rail for authored "Warm Clay" art (see `Docs/NorthStar.md`). A scene asks for a
/// named art slot; if a matching image has landed in the asset catalog or anywhere in the
/// bundle, it gets the final texture — otherwise nil and the scene keeps its procedural
/// stand-in. Shipping is never blocked on art. Slot names are lowercase-kebab, e.g.
/// "window-trees-day" (catalogs per toy live in `Docs/WindowSlice.md` & co).
enum ToyArt {
    private static var cache: [String: SKTexture?] = [:]

    static func texture(_ slot: String) -> SKTexture? {
        if let hit = cache[slot] { return hit }
        var tex: SKTexture?
        if let image = UIImage(named: slot) {
            tex = SKTexture(image: image)
        } else if let url = Bundle.main.url(forResource: slot, withExtension: "png"),
                  let image = UIImage(contentsOfFile: url.path) {
            tex = SKTexture(image: image)
        }
        cache[slot] = tex
        return tex
    }

    /// A sprite for a slot sized to `fit` (aspect-preserving, fits within), or nil if no art landed.
    static func sprite(_ slot: String, fit: CGSize) -> SKSpriteNode? {
        guard let tex = texture(slot) else { return nil }
        let sprite = SKSpriteNode(texture: tex)
        let ts = tex.size()
        guard ts.width > 0, ts.height > 0 else { return sprite }
        let scale = min(fit.width / ts.width, fit.height / ts.height)
        sprite.size = CGSize(width: ts.width * scale, height: ts.height * scale)
        return sprite
    }
}

enum ProceduralTexture {
    /// A white radial-falloff disc for halos and light pools — tint with sprite color.
    /// Light must never have a findable edge (QA law, June 11).
    static let softRadialGlow: SKTexture = {
        let side: CGFloat = 256
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let img = renderer.image { ctx in
            let cg = ctx.cgContext
            let colors = [UIColor.white.cgColor,
                          UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: colors, locations: [0, 1]) else { return }
            let c = CGPoint(x: side / 2, y: side / 2)
            cg.drawRadialGradient(grad, startCenter: c, startRadius: 0,
                                  endCenter: c, endRadius: side / 2, options: [])
        }
        return SKTexture(image: img)
    }()

    private static var clayTextureCache: [String: SKTexture] = [:]
    private static var softShadowTextureCache: [String: SKTexture] = [:]
    private static let ciContext = CIContext()

    /// A baked radial clay gradient: warm key light from the upper-left fading to a
    /// slightly darker rim — the continuous tonal falloff a stack of flat alpha ellipses
    /// can't produce. Apply via `SKShapeNode.fillTexture` so it reads through any silhouette.
    /// Cached by colour + size bucket so we never bake the same texture twice (or per frame).
    static func radialClayTexture(
        base: UIColor,
        size: CGSize,
        highlightMix: CGFloat = 0.20,
        rimMix: CGFloat = 0.26
    ) -> SKTexture {
        // Bucket the size so a handful of textures serve every piece.
        let bucket: CGFloat = 8
        let w = max(bucket, (size.width / bucket).rounded() * bucket)
        let h = max(bucket, (size.height / bucket).rounded() * bucket)

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        _ = base.getRed(&r, green: &g, blue: &b, alpha: &a)
        let key = String(format: "clay-%.0fx%.0f-%.3f-%.3f-%.3f-%.2f-%.2f", w, h, r, g, b, highlightMix, rimMix)
        if let cached = clayTextureCache[key] { return cached }

        let center = clayMix(r, g, b, toward: WarmShelfPalette.paperHighlight, highlightMix)
        let mid = UIColor(red: r, green: g, blue: b, alpha: 1)
        let edge = clayMix(r, g, b, toward: WarmShelfPalette.cocoa, rimMix)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            let colors = [center.cgColor, mid.cgColor, edge.cgColor] as CFArray
            let locations: [CGFloat] = [0.0, 0.55, 1.0]
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: locations
            ) else {
                mid.setFill()
                cg.fill(CGRect(x: 0, y: 0, width: w, height: h))
                return
            }
            // Key light high and to the left, matching the icon's lighting.
            let lightCenter = CGPoint(x: w * 0.36, y: h * 0.32)
            let endCenter = CGPoint(x: w * 0.5, y: h * 0.52)
            cg.drawRadialGradient(
                gradient,
                startCenter: lightCenter, startRadius: 0,
                endCenter: endCenter, endRadius: max(w, h) * 0.78,
                options: [.drawsAfterEndLocation]
            )
        }

        let texture = SKTexture(image: image)
        clayTextureCache[key] = texture
        return texture
    }

    /// Fill an SKShapeNode body with the baked clay gradient while keeping its original
    /// translucency. fillColor stays neutral (white·alpha) so the texture's colour shows.
    static func applyClayFill(to node: SKShapeNode, base: UIColor, size: CGSize) {
        var a: CGFloat = 1
        _ = base.getRed(nil, green: nil, blue: nil, alpha: &a)
        node.fillColor = UIColor(white: 1, alpha: a)
        node.fillTexture = radialClayTexture(base: base, size: size)
    }

    /// A cached, baked soft contact shadow: one blurred clay ellipse per size bucket.
    /// Use as a sibling of deforming art so the shadow stays grounded while clay squashes.
    static func softClayShadow(size: CGSize) -> SKTexture {
        let bucket: CGFloat = 4
        let w = max(bucket, (size.width / bucket).rounded(.up) * bucket)
        let h = max(bucket, (size.height / bucket).rounded(.up) * bucket)
        let blur = max(1, h * 0.14)
        let key = String(format: "soft-shadow-%.0fx%.0f-%.2f", w, h, blur)
        if let cached = softShadowTextureCache[key] { return cached }

        let renderSize = CGSize(width: w, height: h)
        let insetX = max(2, blur * 2.8)
        let insetY = max(1.2, blur * 2.0)
        let renderer = UIGraphicsImageRenderer(size: renderSize)
        let source = renderer.image { _ in
            WarmShelfPalette.contactShadow.withAlpha(0.16).setFill()
            UIBezierPath(ovalIn: CGRect(
                x: insetX,
                y: insetY,
                width: max(1, w - insetX * 2),
                height: max(1, h - insetY * 2)
            )).fill()
        }

        let outputImage: UIImage
        if let input = CIImage(image: source),
           let filter = CIFilter(name: "CIGaussianBlur") {
            filter.setValue(input, forKey: kCIInputImageKey)
            filter.setValue(blur, forKey: kCIInputRadiusKey)
            if let output = filter.outputImage?.cropped(to: input.extent),
               let cg = ciContext.createCGImage(output, from: input.extent) {
                outputImage = UIImage(cgImage: cg, scale: source.scale, orientation: .up)
            } else {
                outputImage = source
            }
        } else {
            outputImage = source
        }

        let texture = SKTexture(image: outputImage)
        texture.filteringMode = .linear
        softShadowTextureCache[key] = texture
        return texture
    }

    private static func clayMix(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, toward: UIColor, _ t: CGFloat) -> UIColor {
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        _ = toward.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r + (r2 - r) * t, green: g + (g2 - g) * t, blue: b + (b2 - b) * t, alpha: 1)
    }

    static func addMatteClayDepth(
        to parent: SKNode,
        in rect: CGRect,
        cornerRadius: CGFloat,
        zPosition: CGFloat = 0.2,
        highlightAlpha: CGFloat = 0.22,
        shadeAlpha: CGFloat = 0.055,
        rimAlpha: CGFloat = 0.040,
        speckleCount: Int = 3
    ) {
        guard rect.width > 0, rect.height > 0 else { return }

        let lowerShade = SKShapeNode(
            rect: CGRect(
                x: rect.minX + rect.width * 0.07,
                y: rect.minY + rect.height * 0.06,
                width: rect.width * 0.82,
                height: rect.height * 0.22
            ),
            cornerRadius: max(1, cornerRadius * 0.62)
        )
        lowerShade.fillColor = WarmShelfPalette.cocoa.withAlpha(shadeAlpha)
        lowerShade.strokeColor = .clear
        lowerShade.zPosition = zPosition
        parent.addChild(lowerShade)

        let highlight = SKShapeNode(ellipseOf: CGSize(width: rect.width * 0.42, height: rect.height * 0.24))
        highlight.fillColor = WarmShelfPalette.paperHighlight.withAlpha(highlightAlpha)
        highlight.strokeColor = .clear
        highlight.position = CGPoint(x: rect.minX + rect.width * 0.34, y: rect.minY + rect.height * 0.72)
        highlight.zRotation = -0.25
        highlight.zPosition = zPosition + 0.02
        parent.addChild(highlight)

        let rim = SKShapeNode(rect: rect.insetBy(dx: rect.width * 0.035, dy: rect.height * 0.045), cornerRadius: max(1, cornerRadius * 0.86))
        rim.fillColor = .clear
        rim.strokeColor = WarmShelfPalette.paperHighlight.withAlpha(rimAlpha)
        rim.lineWidth = max(0.7, min(rect.width, rect.height) * 0.012)
        rim.zPosition = zPosition + 0.03
        parent.addChild(rim)

        if speckleCount > 0 {
            addSoftSpeckles(
                to: parent,
                in: rect.insetBy(dx: rect.width * 0.14, dy: rect.height * 0.16),
                count: speckleCount,
                alpha: 0.018...0.046,
                radius: 0.45...1.25,
                zPosition: zPosition + 0.04
            )
        }
    }

    static func addMatteClayDepth(
        to parent: SKNode,
        ellipse size: CGSize,
        zPosition: CGFloat = 0.2,
        highlightAlpha: CGFloat = 0.22,
        shadeAlpha: CGFloat = 0.055,
        rimAlpha: CGFloat = 0.040,
        speckleCount: Int = 3
    ) {
        guard size.width > 0, size.height > 0 else { return }

        let lowerShade = SKShapeNode(ellipseOf: CGSize(width: size.width * 0.70, height: size.height * 0.24))
        lowerShade.fillColor = WarmShelfPalette.cocoa.withAlpha(shadeAlpha)
        lowerShade.strokeColor = .clear
        lowerShade.position = CGPoint(x: size.width * 0.03, y: -size.height * 0.27)
        lowerShade.zPosition = zPosition
        parent.addChild(lowerShade)

        let highlight = SKShapeNode(ellipseOf: CGSize(width: size.width * 0.38, height: size.height * 0.24))
        highlight.fillColor = WarmShelfPalette.paperHighlight.withAlpha(highlightAlpha)
        highlight.strokeColor = .clear
        highlight.position = CGPoint(x: -size.width * 0.18, y: size.height * 0.24)
        highlight.zRotation = -0.28
        highlight.zPosition = zPosition + 0.02
        parent.addChild(highlight)

        let rim = SKShapeNode(ellipseOf: CGSize(width: size.width * 0.88, height: size.height * 0.86))
        rim.fillColor = .clear
        rim.strokeColor = WarmShelfPalette.paperHighlight.withAlpha(rimAlpha)
        rim.lineWidth = max(0.7, min(size.width, size.height) * 0.014)
        rim.zPosition = zPosition + 0.03
        parent.addChild(rim)

        if speckleCount > 0 {
            addSoftSpeckles(
                to: parent,
                in: CGRect(x: -size.width * 0.34, y: -size.height * 0.34, width: size.width * 0.68, height: size.height * 0.68),
                count: speckleCount,
                alpha: 0.018...0.046,
                radius: 0.45...1.20,
                zPosition: zPosition + 0.04
            )
        }
    }

    static func addSoftSpeckles(
        to parent: SKNode,
        in rect: CGRect,
        count: Int,
        lightColor: UIColor = WarmShelfPalette.paperHighlight,
        darkColor: UIColor = WarmShelfPalette.clayInk,
        alpha: ClosedRange<CGFloat> = 0.035...0.11,
        radius: ClosedRange<CGFloat> = 0.8...2.1,
        zPosition: CGFloat = 4
    ) {
        guard rect.width > 0, rect.height > 0, count > 0 else { return }

        for index in 0..<count {
            let dot = SKShapeNode(circleOfRadius: CGFloat.random(in: radius))
            let usesDark = index.isMultiple(of: 5)
            dot.fillColor = (usesDark ? darkColor : lightColor).withAlpha(CGFloat.random(in: alpha) * (usesDark ? 0.55 : 1.0))
            dot.strokeColor = .clear
            dot.position = CGPoint(
                x: CGFloat.random(in: rect.minX...rect.maxX),
                y: CGFloat.random(in: rect.minY...rect.maxY)
            )
            dot.zPosition = zPosition
            parent.addChild(dot)
        }
    }

    static func addCircularSpeckles(
        to parent: SKNode,
        radius: CGFloat,
        count: Int,
        lightColor: UIColor = WarmShelfPalette.paperHighlight,
        darkColor: UIColor = WarmShelfPalette.clayInk,
        alpha: ClosedRange<CGFloat> = 0.035...0.10,
        dotRadius: ClosedRange<CGFloat> = 0.8...2.0,
        zPosition: CGFloat = 4
    ) {
        guard radius > 0, count > 0 else { return }

        for index in 0..<count {
            let angle = CGFloat.random(in: 0...(.pi * 2))
            let distance = sqrt(CGFloat.random(in: 0...1)) * radius * 0.86
            let dot = SKShapeNode(circleOfRadius: CGFloat.random(in: dotRadius))
            let usesDark = index.isMultiple(of: 6)
            dot.fillColor = (usesDark ? darkColor : lightColor).withAlpha(CGFloat.random(in: alpha) * (usesDark ? 0.52 : 1.0))
            dot.strokeColor = .clear
            dot.position = CGPoint(x: cos(angle) * distance, y: sin(angle) * distance)
            dot.zPosition = zPosition
            parent.addChild(dot)
        }
    }

    static func addSoftGrainLines(
        to parent: SKNode,
        in rect: CGRect,
        count: Int,
        color: UIColor = WarmShelfPalette.paperHighlight,
        alpha: ClosedRange<CGFloat> = 0.035...0.09,
        zPosition: CGFloat = 4
    ) {
        guard rect.width > 0, rect.height > 0, count > 0 else { return }

        for _ in 0..<count {
            let width = CGFloat.random(in: rect.width * 0.10...rect.width * 0.34)
            let height = max(1.4, rect.height * CGFloat.random(in: 0.018...0.044))
            let line = SKShapeNode(
                rect: CGRect(x: -width / 2, y: -height / 2, width: width, height: height),
                cornerRadius: height / 2
            )
            line.fillColor = color.withAlpha(CGFloat.random(in: alpha))
            line.strokeColor = .clear
            line.position = CGPoint(
                x: CGFloat.random(in: rect.minX + width * 0.4...rect.maxX - width * 0.4),
                y: CGFloat.random(in: rect.minY...rect.maxY)
            )
            line.zRotation = CGFloat.random(in: -0.12...0.12)
            line.zPosition = zPosition
            parent.addChild(line)
        }
    }

    static func addEdgeWobbleDots(
        to parent: SKNode,
        in rect: CGRect,
        count: Int,
        color: UIColor = WarmShelfPalette.clayInk,
        zPosition: CGFloat = 4
    ) {
        guard rect.width > 0, rect.height > 0, count > 0 else { return }

        for index in 0..<count {
            let side = index % 4
            let point: CGPoint
            switch side {
            case 0:
                point = CGPoint(x: CGFloat.random(in: rect.minX...rect.maxX), y: rect.maxY - CGFloat.random(in: 0...4))
            case 1:
                point = CGPoint(x: CGFloat.random(in: rect.minX...rect.maxX), y: rect.minY + CGFloat.random(in: 0...4))
            case 2:
                point = CGPoint(x: rect.minX + CGFloat.random(in: 0...4), y: CGFloat.random(in: rect.minY...rect.maxY))
            default:
                point = CGPoint(x: rect.maxX - CGFloat.random(in: 0...4), y: CGFloat.random(in: rect.minY...rect.maxY))
            }

            let dot = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.45...1.1))
            dot.fillColor = color.withAlpha(CGFloat.random(in: 0.015...0.034))
            dot.strokeColor = .clear
            dot.position = point
            dot.zPosition = zPosition
            parent.addChild(dot)
        }
    }
}
