import UIKit

struct HapticBeat {
    let delay: TimeInterval
    let style: UIImpactFeedbackGenerator.FeedbackStyle
    let intensity: CGFloat
}

struct HapticScore {
    let beats: [HapticBeat]

    static let stackKnockover = HapticScore(beats: [
        HapticBeat(delay: 0.00, style: .rigid,  intensity: 0.85), // base impact
        HapticBeat(delay: 0.08, style: .soft,   intensity: 0.55), // first piece
        HapticBeat(delay: 0.14, style: .light,  intensity: 0.40), // cascade
        HapticBeat(delay: 0.20, style: .light,  intensity: 0.30),
        HapticBeat(delay: 0.28, style: .soft,   intensity: 0.20), // dust settling
        HapticBeat(delay: 0.45, style: .light,  intensity: 0.10),
    ])

    static let bloomPlant = HapticScore(beats: [
        HapticBeat(delay: 0.00, style: .soft,   intensity: 0.45), // seed press
        HapticBeat(delay: 0.32, style: .light,  intensity: 0.60), // bloom pop
        HapticBeat(delay: 0.38, style: .light,  intensity: 0.30),
    ])

    // 4Hz pulse for up to 2s while held — caller repeats this
    static let humHold = HapticScore(beats: [
        HapticBeat(delay: 0.00, style: .soft,   intensity: 0.25),
    ])

    static let mixUpCombo = HapticScore(beats: [
        HapticBeat(delay: 0.00, style: .rigid,  intensity: 0.70),
        HapticBeat(delay: 0.12, style: .soft,   intensity: 0.80),
        HapticBeat(delay: 0.24, style: .light,  intensity: 0.50),
    ])

    /// A firm clay knob press, then a soft settle — physical and tactile, not a buzz.
    static let toneSwitch = HapticScore(beats: [
        HapticBeat(delay: 0.00, style: .rigid,  intensity: 0.58),
        HapticBeat(delay: 0.10, style: .soft,   intensity: 0.32),
    ])
}

extension HapticsManager {
    func play(score: HapticScore) {
        for beat in score.beats {
            DispatchQueue.main.asyncAfter(deadline: .now() + beat.delay) { [weak self] in
                self?.impact(style: beat.style, intensity: beat.intensity)
            }
        }
    }
}
