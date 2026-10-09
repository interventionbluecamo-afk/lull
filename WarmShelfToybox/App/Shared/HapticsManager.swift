import UIKit

/// Lull's touch vocabulary. Sound now answers outcomes only, so taps, lifts and presses are
/// carried by these pulses and must be felt.
///
/// Founder, build 5: "I don't even feel haptics". Almost every pulse asked for 6–46% of a
/// generator's strength, mostly from `.soft` (the faintest style); below about half strength those
/// fall under what a hand notices, especially while a finger is moving. The intensities the toys
/// ask for are kept as a relative scale and lifted onto a felt range per style, and pulses that
/// land in the same instant are merged instead of cancelling each other.
final class HapticsManager {
    static let shared = HapticsManager()

    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let softGenerator = UIImpactFeedbackGenerator(style: .soft)
    private let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private var lastPulseTime: CFTimeInterval = 0
    private var lastPulseIntensity: CGFloat = 0

    /// The softest pulse of each style that is still clearly felt on an iPhone; a toy's
    /// requested 0...1 maps onto floor...1, so its relative strengths survive.
    static func deliveredIntensity(style: UIImpactFeedbackGenerator.FeedbackStyle, requested: CGFloat) -> CGFloat {
        let floor: CGFloat
        switch style {
        case .soft: floor = 0.55
        case .rigid: floor = 0.4
        default: floor = 0.45
        }
        let r = max(0, min(1, requested))
        return floor + (1 - floor) * r
    }

    private init() {
        prepareForTouch()
    }

    func prepareForTouch() {
        guard isEnabled else { return }
        lightGenerator.prepare()
        softGenerator.prepare()
        rigidGenerator.prepare()
    }

    var isEnabled: Bool {
        get { LullDemoState.shared.isHapticsEnabled }
        set { LullDemoState.shared.isHapticsEnabled = newValue }
    }

    func bubblePop(size: CGFloat, isRare: Bool) {
        let style: UIImpactFeedbackGenerator.FeedbackStyle = size > 90 || isRare ? .soft : .light
        impact(style: style, intensity: isRare ? 0.42 : min(max(size / 150, 0.28), 0.72))
    }

    func softTap() {
        impact(style: .soft, intensity: 0.22)
    }

    /// A firm clay-button press — used when a shelf toy is pressed in before it opens.
    func cardPress() {
        impact(style: .rigid, intensity: 0.42)
    }

    func emptyTap() {
        impact(style: .soft, intensity: 0.16)
    }

    func blockPickup() {
        impact(style: .light, intensity: 0.30)
    }

    func blockRelease() {
        impact(style: .soft, intensity: 0.34)
    }

    func blockSettle() {
        impact(style: .rigid, intensity: 0.14)
    }

    func blockLand(kind: ClayBlockKind) {
        switch kind {
        case .longPlank, .connector, .king:
            impact(style: .rigid, intensity: 0.20)
        case .plank, .brick, .tall:
            impact(style: .rigid, intensity: 0.16)
        case .cylinder, .smallCylinder:
            impact(style: .soft, intensity: 0.18)
        default:
            impact(style: .soft, intensity: 0.14)
        }
    }

    func mysteryShape() {
        impact(style: .soft, intensity: 0.38)
    }

    /// A double-pulse used for big celebrations: rigid leading edge followed by a soft exhale.
    func celebration() {
        impact(style: .rigid, intensity: 0.46)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.impact(style: .soft, intensity: 0.22)
        }
    }

    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat) {
        guard isEnabled else { return }
        // Pulses inside 60 ms are one touch (a sound helper and its scene both answering, or a
        // chain of pops): keep the first unless the next is clearly stronger. Calm, never a buzz.
        let now = CACurrentMediaTime()
        let delivered = Self.deliveredIntensity(style: style, requested: intensity)
        if now - lastPulseTime < 0.06, delivered <= lastPulseIntensity + 0.1 { return }
        lastPulseTime = now
        lastPulseIntensity = delivered
        let generator: UIImpactFeedbackGenerator
        switch style {
        case .light:
            generator = lightGenerator
        case .rigid:
            generator = rigidGenerator
        default:
            generator = softGenerator
        }
        generator.impactOccurred(intensity: delivered)
        generator.prepare()
    }
}
