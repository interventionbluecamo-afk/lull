import SpriteKit
import UIKit

enum DayPhase {
    case dawn
    case midday
    case dusk
    case night
}

/// Single source of truth for the time of day. Obvious, predictable phases so the
/// whole app visibly breathes with the real clock (with a DEBUG hour override).
enum TimeOfDay {
    static var hour: Int {
        #if DEBUG
        if let o = ProcessInfo.processInfo.environment["LULL_DEBUG_HOUR"], let h = Int(o) { return h }
        #endif
        return Calendar.current.component(.hour, from: Date())
    }

    static var phase: DayPhase {
        phaseFor(hour: hour)
    }

    // Dusk and night shift to honour the parent's chosen wind-down time, so the app
    // actually dims at their bedtime, not at a hardcoded 5pm cutoff.
    private static func phaseFor(hour h: Int) -> DayPhase {
        let windDown = LullDemoState.shared.windDownHour
        if h == 5 || h == 6 { return .dawn }
        // Midday runs until 2h before wind-down (minimum from 7am).
        if h < max(7, windDown - 2) { return .midday }
        if h < windDown { return .dusk }
        return .night
    }

    struct SkyPalette {
        let top: UIColor
        let bottom: UIColor
        let orb: UIColor       // sun or moon
        let orbGlow: UIColor
        let isNight: Bool
        let starAlpha: CGFloat // 0 = none
        /// Sun/moon horizontal progress across the sky (0 = left, 1 = right) and height (0 = horizon, 1 = high).
        let orbX: CGFloat
        let orbHeight: CGFloat
        /// A gentle light tint laid over the world to match the sky.
        let lightTint: UIColor
        let lightTintAlpha: CGFloat
    }

    static var sky: SkyPalette {
        switch phase {
        case .dawn:
            return SkyPalette(
                top: UIColor(hex: 0xC9B6D4), bottom: UIColor(hex: 0xF6D9B8),
                orb: UIColor(hex: 0xFBD9A0), orbGlow: UIColor(hex: 0xF7C57E),
                isNight: false, starAlpha: 0,
                orbX: 0.18, orbHeight: 0.22,
                lightTint: WarmShelfPalette.petal, lightTintAlpha: 0.05)
        case .midday:
            return SkyPalette(
                top: UIColor(hex: 0xAFD4E6), bottom: UIColor(hex: 0xF3EACB),
                orb: UIColor(hex: 0xFFF1C2), orbGlow: UIColor(hex: 0xFFE39A),
                isNight: false, starAlpha: 0,
                orbX: 0.5, orbHeight: 0.9,
                lightTint: .clear, lightTintAlpha: 0)
        case .dusk:
            return SkyPalette(
                top: UIColor(hex: 0x8E6E97), bottom: UIColor(hex: 0xF0A86A),
                orb: UIColor(hex: 0xF7944C), orbGlow: UIColor(hex: 0xE8743A),
                isNight: false, starAlpha: 0.18,
                orbX: 0.82, orbHeight: 0.18,
                lightTint: WarmShelfPalette.terracotta, lightTintAlpha: 0.08)
        case .night:
            return SkyPalette(
                top: UIColor(hex: 0x232846), bottom: UIColor(hex: 0x47506E),
                orb: UIColor(hex: 0xF3EFD6), orbGlow: UIColor(hex: 0xD9E2F0),
                isNight: true, starAlpha: 0.9,
                orbX: 0.74, orbHeight: 0.78,
                lightTint: UIColor(hex: 0x2B3358), lightTintAlpha: 0.12)
        }
    }

    /// A soft vertical gradient texture (top → bottom).
    static func gradientTexture(size: CGSize, top: UIColor, bottom: UIColor) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            let colors = [top.cgColor, bottom.cgColor] as CFArray
            guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }
            cg.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
        }
        return SKTexture(image: image)
    }
}
