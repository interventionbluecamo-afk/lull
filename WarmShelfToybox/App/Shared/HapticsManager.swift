import UIKit

final class HapticsManager {
    static let shared = HapticsManager()

    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let softGenerator = UIImpactFeedbackGenerator(style: .soft)
    private let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)

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
        let generator: UIImpactFeedbackGenerator
        switch style {
        case .light:
            generator = lightGenerator
        case .rigid:
            generator = rigidGenerator
        default:
            generator = softGenerator
        }
        generator.impactOccurred(intensity: intensity)
        generator.prepare()
    }
}
