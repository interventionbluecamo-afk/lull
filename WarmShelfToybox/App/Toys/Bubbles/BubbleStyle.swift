import UIKit

enum BubbleStyle: CaseIterable {
    case pearl
    case water
    case blush
    case lavender
    case butter
    case mother

    static func random() -> BubbleStyle {
        let roll = Int.random(in: 0..<100)

        // Rebalanced toward the coloured families — the old mix was ~42% near-cream pearl, which
        // read as washed-out. Pearl stays the connective tissue; colour carries the scene.
        switch roll {
        case 0..<26:
            return .pearl
        case 26..<56:
            return .water
        case 56..<80:
            return .blush
        case 80..<92:
            return .lavender
        default:
            return .butter
        }
    }

    static func preview(index: Int) -> BubbleStyle {
        switch index % 5 {
        case 1:
            return .water
        case 2:
            return .blush
        case 3:
            return .butter
        case 4:
            return .lavender
        default:
            return .pearl
        }
    }

    var isRare: Bool {
        self == .lavender || self == .butter || self == .mother
    }

    var isMother: Bool {
        self == .mother
    }

    var bodyColor: UIColor {
        switch self {
        case .pearl:
            return WarmShelfPalette.bubblePearl
        case .water:
            return WarmShelfPalette.waterBlue
        case .blush:
            return WarmShelfPalette.blushIridescence
        case .lavender, .mother:
            return WarmShelfPalette.lavender
        case .butter:
            return WarmShelfPalette.butter
        }
    }

    var bodyAlpha: CGFloat {
        switch self {
        case .water:
            return 0.48
        case .blush:
            return 0.42
        case .mother:
            return 0.62
        case .lavender, .butter:
            return 0.54
        default:
            return 0.55   // pearl: body steps back so the rim carries it on cream walls
        }
    }

    var rimColor: UIColor {
        switch self {
        case .blush:
            return WarmShelfPalette.blushIridescence
        case .lavender, .mother:
            return WarmShelfPalette.lavender
        case .butter:
            return WarmShelfPalette.butter
        default:
            return WarmShelfPalette.bubbleRim
        }
    }

    var rimAlpha: CGFloat {
        switch self {
        case .water:
            return 0.78
        case .mother:
            return 0.86
        case .lavender, .butter:
            return 0.78
        default:
            return 0.84   // pearl: the cool rim is the silhouette over the warm room
        }
    }

    var glowColor: UIColor {
        switch self {
        case .blush:
            return WarmShelfPalette.blushIridescence
        case .lavender, .mother:
            return WarmShelfPalette.lavender
        case .butter:
            return WarmShelfPalette.butter
        default:
            return WarmShelfPalette.waterBlue
        }
    }

    var glowAlpha: CGFloat {
        switch self {
        case .mother:
            return 0.20
        case .lavender, .butter:
            return 0.12
        case .water:
            return 0.10
        default:
            return 0.08
        }
    }

    var shimmerAlpha: CGFloat {
        switch self {
        case .blush:
            return 0.30
        case .mother:
            return 0.42
        case .lavender, .butter:
            return 0.34
        default:
            return 0.14
        }
    }

    var popColor: UIColor {
        switch self {
        case .pearl:
            return WarmShelfPalette.waterBlue
        case .water:
            return WarmShelfPalette.bubbleRim
        case .blush:
            return WarmShelfPalette.blushIridescence
        case .lavender, .mother:
            return WarmShelfPalette.lavender
        case .butter:
            return WarmShelfPalette.butter
        }
    }

    var secondaryPopColor: UIColor {
        switch self {
        case .blush:
            return WarmShelfPalette.waterBlue
        case .lavender, .mother:
            return WarmShelfPalette.blushIridescence
        case .butter:
            return WarmShelfPalette.bubbleHighlight
        default:
            return WarmShelfPalette.paperHighlight
        }
    }
}
