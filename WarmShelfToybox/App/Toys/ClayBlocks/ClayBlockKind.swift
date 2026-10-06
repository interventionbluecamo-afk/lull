import CoreGraphics

enum ClayBlockKind: CaseIterable {
    case cube
    case smallCube
    case plank
    case longPlank
    case tall
    case brick
    case smallBrick
    case cylinder
    case smallCylinder
    case triangle
    case connector
    case king

    var size: CGSize {
        switch self {
        case .cube:
            return CGSize(width: 82, height: 82)
        case .smallCube:
            return CGSize(width: 68, height: 68)
        case .plank:
            return CGSize(width: 146, height: 44)
        case .longPlank:
            return CGSize(width: 178, height: 38)
        case .tall:
            return CGSize(width: 68, height: 116)
        case .brick:
            return CGSize(width: 112, height: 64)
        case .smallBrick:
            return CGSize(width: 92, height: 54)
        case .cylinder:
            return CGSize(width: 78, height: 78)
        case .smallCylinder:
            return CGSize(width: 62, height: 62)
        case .triangle:
            return CGSize(width: 96, height: 82)
        case .connector:
            return CGSize(width: 198, height: 42)
        case .king:
            return CGSize(width: 100, height: 100)
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .cube:
            return 16
        case .smallCube:
            return 15
        case .plank:
            return 15
        case .longPlank:
            return 14
        case .tall:
            return 18
        case .brick:
            return 14
        case .smallBrick:
            return 13
        case .cylinder, .smallCylinder:
            return size.width / 2
        case .triangle:
            return 10
        case .connector:
            return 16
        case .king:
            return 22
        }
    }

    var mass: CGFloat {
        switch self {
        case .longPlank:
            return 0.36
        case .plank:
            return 0.32
        case .tall:
            return 0.28
        case .cylinder:
            return 0.24
        case .smallCylinder:
            return 0.20
        case .smallCube, .smallBrick, .triangle:
            return 0.26
        case .connector:
            return 0.40
        case .king:
            return 0.38
        default:
            return 0.30
        }
    }

    var friction: CGFloat {
        switch self {
        case .cylinder, .smallCylinder:
            return 0.54
        case .plank, .longPlank:
            return 0.94
        case .triangle:
            return 0.80
        case .connector, .king:
            return 0.96
        default:
            return 0.86
        }
    }

    var restitution: CGFloat {
        switch self {
        case .cylinder, .smallCylinder:
            return 0.06
        case .triangle, .connector, .king:
            return 0.025
        default:
            return 0.02
        }
    }

    var isRound: Bool {
        self == .cylinder || self == .smallCylinder
    }

    var isTriangle: Bool {
        self == .triangle
    }
}
