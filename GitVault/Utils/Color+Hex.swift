//
//  Color+Hex.swift
//  GitVault
//
//  十六进制颜色工具：DesignSystem 用它来声明设计规范里的色值。
//

import SwiftUI

extension UIColor {
    /// 用 0xRRGGBB 形式的十六进制快速构造 UIColor
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: alpha
        )
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(uiColor: UIColor(hex: hex, alpha: alpha))
    }
}
