import SpriteKit
import UIKit

enum WarmShelfPalette {
    static let linen = UIColor(hex: 0xF8F3E9)
    static let paperHighlight = UIColor(hex: 0xFFFCF6)
    static let warmCream = UIColor(hex: 0xEEE3D1)
    static let softLine = UIColor(hex: 0xD8CBB8)
    static let clayInk = UIColor(hex: 0x49352A)
    static let contactShadow = UIColor(hex: 0x49352A)
    static let cocoa = UIColor(hex: 0x654B3A)
    static let raisin = UIColor(hex: 0x382C28)
    static let rhubarb = UIColor(hex: 0xA6473C)
    static let terracotta = UIColor(hex: 0xC96F50)
    static let sage = UIColor(hex: 0x829B82)
    static let sand = UIColor(hex: 0xC8A477)
    static let waterBlue = UIColor(hex: 0x83AAB9)
    static let butter = UIColor(hex: 0xD9B452)
    static let lavender = UIColor(hex: 0xA696B3)
    static let petal = UIColor(hex: 0xDD998B)
    static let bubblePearl = UIColor(hex: 0xF7F2D5)
    static let bubbleHighlight = UIColor(hex: 0xE7FAFF)
    static let bubbleRim = UIColor(hex: 0x8ECFE2)
    static let blushIridescence = UIColor(hex: 0xE6AFC1)
    static let cardSurface = UIColor(hex: 0xFFFCF6)
    static let cardBorder = UIColor(hex: 0xDDCEBA)
    static let cardShimmer = UIColor(hex: 0xFFFFFF)
    static let labelInk = UIColor(hex: 0x49352A)
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
