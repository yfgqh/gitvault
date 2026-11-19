//
//  AppearanceMode.swift
//  GitVault
//
//  外观偏好：深色为默认（产品基调），可切浅色 / 跟随系统。
//

import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case dark
    case light
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dark: return "深色"
        case .light: return "浅色"
        case .system: return "跟随系统"
        }
    }

    var symbol: String {
        switch self {
        case .dark: return "moon.stars.fill"
        case .light: return "sun.max.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }

    /// nil = 不干预，跟随系统
    var colorScheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }
}

/// 全局偏好键，集中管理避免各处硬编码字符串
enum AppPrefs {
    static let appearance = "gv.appearance"
    static let hasSeenOnboarding = "gv.hasSeenOnboarding"
    static let searchHistory = "gv.searchHistory"
}
