//
//  LiquidMotion.swift
//  GitVault
//
//  水滴胶囊：选中指示器的 leading / trailing 分别独立动画，
//  移动过程中先拉长再收拢 —— 像一滴水被吸过去。
//

import SwiftUI

// MARK: - 弹簧参数

enum LiquidSpring {
    /// 前沿：刚度高、回弹快，负责「先到」
    static let lead = Animation.interpolatingSpring(stiffness: 420, damping: 30)
    /// 后沿：刚度低 + 微延迟，负责「跟上」
    static let trail = Animation.interpolatingSpring(stiffness: 250, damping: 24).delay(0.05)
}

// MARK: - 水滴胶囊指示器

/// 收集每个 tab 在自己坐标系里的位置
struct TabFrameKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// 会拉长再收拢的胶囊。leading / trailing 分别独立动画，
/// 于是移动过程中宽度先变大再复原。
struct LiquidIndicator: View {
    var leading: CGFloat
    var trailing: CGFloat
    var height: CGFloat
    var cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(DS.accentGradient)
            .frame(width: max(0, trailing - leading), height: height)
            .offset(x: leading)
            .shadow(color: DS.accent.opacity(0.45), radius: 12, y: 4)
    }
}
