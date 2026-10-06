import Foundation

enum PhysicsCategory {
    static let block: UInt32 = 1 << 0
    static let surface: UInt32 = 1 << 1
    static let wall: UInt32 = 1 << 2
    static let tray: UInt32 = 1 << 3
    static let softDropPiece: UInt32 = 1 << 4
    static let softDropSurface: UInt32 = 1 << 5
    static let rollwayBall: UInt32 = 1 << 6
    static let rollwayRail: UInt32 = 1 << 7
}
