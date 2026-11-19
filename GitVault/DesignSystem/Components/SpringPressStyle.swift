//
//  SpringPressStyle.swift
//  GitVault
//
//  统一的按压弹性反馈。所有可点击卡片 / 按钮包一层即得「按下回弹」手感。
//

import SwiftUI

struct SpringPressStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    var hapticOnPress: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(DS.Motion.snappy, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed && hapticOnPress {
                    Haptics.tap()
                }
            }
    }
}

extension ButtonStyle where Self == SpringPressStyle {
    /// 默认按压：缩放 0.96 + 轻触觉
    static var springPress: SpringPressStyle { SpringPressStyle() }
    /// 大卡片按压：缩放更明显
    static var springPressCard: SpringPressStyle { SpringPressStyle(scale: 0.975) }
    /// 无触觉（用于内部已自带反馈的组件）
    static var springPressSilent: SpringPressStyle { SpringPressStyle(hapticOnPress: false) }
}
