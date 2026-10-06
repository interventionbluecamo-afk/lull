import SpriteKit
import UIKit

enum WarmShelfPalette {
    static let linen = UIColor(hex: 0xF2E8C6)
    static let paperHighlight = UIColor(hex: 0xFAF0D8)
    static let warmCream = UIColor(hex: 0xECDFAF)
    static let softLine = UIColor(hex: 0xD4C89E)
    static let clayInk = UIColor(hex: 0x3D1F0E)
    static let contactShadow = UIColor(hex: 0x3D1F0E)
    static let cocoa = UIColor(hex: 0x5C3320)
    static let raisin = UIColor(hex: 0x2F1A12)
    static let rhubarb = UIColor(hex: 0xA6473C)
    static let terracotta = UIColor(hex: 0xD4583A)
    static let sage = UIColor(hex: 0x6A8B66)
    static let sand = UIColor(hex: 0xCDA96A)
    static let waterBlue = UIColor(hex: 0x85C5CF)
    static let butter = UIColor(hex: 0xE8C045)
    static let lavender = UIColor(hex: 0xA08BBB)
    static let petal = UIColor(hex: 0xEA8E82)
    static let bubblePearl = UIColor(hex: 0xF7F2D5)
    static let bubbleHighlight = UIColor(hex: 0xE7FAFF)
    static let bubbleRim = UIColor(hex: 0x8ECFE2)
    static let blushIridescence = UIColor(hex: 0xE6AFC1)
    static let cardSurface = UIColor(hex: 0xFAF4E0)
    static let cardBorder = UIColor(hex: 0xD4C08A)
    static let cardShimmer = UIColor(hex: 0xFFFBF0)
    static let labelInk = UIColor(hex: 0x4A2D18)
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255.0
        let green = CGFloat((hex >> 8) & 0xFF) / 255.0
        let blue = CGFloat(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    func withAlpha(_ alpha: CGFloat) -> UIColor {
        withAlphaComponent(alpha)
    }
}
