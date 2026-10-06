import Foundation

enum WarmShelfMotion {
    static let instantTouch: TimeInterval = 0.055
    static let touchReturn: TimeInterval = 0.18
    static let pop: TimeInterval = 0.16
    static let emptyTap: TimeInterval = 0.42
    static let settle: TimeInterval = 0.48
    static let shelfTransition: TimeInterval = 0.75

    static let ambientQuick: ClosedRange<TimeInterval> = 2.3...4.8
    static let ambientSlow: ClosedRange<TimeInterval> = 5.0...8.5
    static let bubbleFloat: ClosedRange<TimeInterval> = 8.5...15.5
}

