//
//  Haptics.swift
//  GitVault
//
//  触觉反馈统一出口。所有可交互组件只调用这里，方便日后做「触觉强度」设置项。
//

import UIKit

enum Haptics {
    /// 轻点（卡片、Chip）
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// 中等分量（收藏、切换标记）
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// 选择变化（Tab 切换、筛选）
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// 成功（保存、同步完成）
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// 警告（限流、网络异常）
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
