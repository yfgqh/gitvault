//
//  Tags.swift
//  GitVault
//
//  第二层：智能标签体系。状态 / 用途 / 许可 / 我的标记 四组 + 语言。
//

import SwiftUI

// MARK: - 状态标签

enum ActivityTag: String, CaseIterable, Identifiable, Codable {
    case rising      // 🔥 飙升中
    case newStar     // 🌱 新星
    case classic     // 🏆 经典
    case dormant     // 💤 低活跃

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rising: return NSLocalizedString("飙升中", comment: "")
        case .newStar: return NSLocalizedString("新星", comment: "")
        case .classic: return NSLocalizedString("经典", comment: "")
        case .dormant: return NSLocalizedString("低活跃", comment: "")
        }
    }

    var symbol: String {
        switch self {
        case .rising: return "flame.fill"
        case .newStar: return "leaf.fill"
        case .classic: return "trophy.fill"
        case .dormant: return "moon.zzz.fill"
        }
    }

    var emoji: String {
        switch self {
        case .rising: return "🔥"
        case .newStar: return "🌱"
        case .classic: return "🏆"
        case .dormant: return "💤"
        }
    }

    var tint: Color {
        switch self {
        case .rising: return Color(hex: 0xFF7A45)
        case .newStar: return Color(hex: 0x3DDC97)
        case .classic: return Color(hex: 0xFFB020)
        case .dormant: return DS.textTertiary
        }
    }
}

// MARK: - 用途标签

enum UsageTag: String, CaseIterable, Identifiable, Codable {
    case readyToUse   // 可直接用
    case needsLearning // 需学习
    case referenceOnly // 仅供参考

    var id: String { rawValue }

    var title: String {
        switch self {
        case .readyToUse: return NSLocalizedString("可直接用", comment: "")
        case .needsLearning: return NSLocalizedString("需学习", comment: "")
        case .referenceOnly: return NSLocalizedString("仅供参考", comment: "")
        }
    }

    var symbol: String {
        switch self {
        case .readyToUse: return "bolt.fill"
        case .needsLearning: return "graduationcap.fill"
        case .referenceOnly: return "bookmark.fill"
        }
    }

    var emoji: String {
        switch self {
        case .readyToUse: return "⚡️"
        case .needsLearning: return "📚"
        case .referenceOnly: return "🔖"
        }
    }

    var tint: Color {
        switch self {
        case .readyToUse: return Color(hex: 0x3DDC97)
        case .needsLearning: return Color(hex: 0x6E7BFF)
        case .referenceOnly: return DS.textSecondary
        }
    }
}

// MARK: - 许可标签

enum LicenseTag: String, CaseIterable, Identifiable, Codable {
    case mit
    case apache
    case gpl
    case none

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .mit: return "checkmark.seal.fill"
        case .apache: return "checkmark.seal.fill"
        case .gpl: return "exclamationmark.triangle.fill"
        case .none: return "questionmark.circle.fill"
        }
    }

    var title: String {
        switch self {
        case .mit: return "MIT"
        case .apache: return "Apache"
        case .gpl: return "GPL"
        case .none: return NSLocalizedString("无许可", comment: "")
        }
    }

    var tint: Color {
        switch self {
        case .mit: return Color(hex: 0x3DDC97)
        case .apache: return Color(hex: 0x6E7BFF)
        case .gpl: return Color(hex: 0xFFB020)
        case .none: return DS.textTertiary
        }
    }

    static func from(spdxID: String?) -> LicenseTag {
        guard let spdx = spdxID?.uppercased() else { return .none }
        if spdx.contains("MIT") { return .mit }
        if spdx.contains("APACHE") { return .apache }
        if spdx.contains("GPL") { return .gpl }
        return .none
    }
}

// MARK: - 我的标记（用户私有状态）

enum MyMark: String, CaseIterable, Identifiable, Codable {
    case starred   // ⭐ 收藏
    case watching  // 👀 观察
    case inUse     // 🛠 在用
    case archived  // 📦 归档

    var id: String { rawValue }

    var title: String {
        switch self {
        case .starred: return NSLocalizedString("收藏", comment: "")
        case .watching: return NSLocalizedString("观察", comment: "")
        case .inUse: return NSLocalizedString("在用", comment: "")
        case .archived: return NSLocalizedString("归档", comment: "")
        }
    }

    var emoji: String {
        switch self {
        case .starred: return "⭐"
        case .watching: return "👀"
        case .inUse: return "🛠"
        case .archived: return "📦"
        }
    }

    var symbol: String {
        switch self {
        case .starred: return "star.fill"
        case .watching: return "eye.fill"
        case .inUse: return "hammer.fill"
        case .archived: return "archivebox.fill"
        }
    }

    var tint: Color {
        switch self {
        case .starred: return Color(hex: 0xFFC940)
        case .watching: return Color(hex: 0x6EE7FF)
        case .inUse: return DS.accent
        case .archived: return DS.textTertiary
        }
    }
}

// MARK: - 语言色板

enum LanguagePalette {
    /// GitHub 官方语言色（真机观感一致的常用子集）
    static func color(for language: String) -> Color {
        switch language.lowercased() {
        case "swift": return Color(hex: 0xF05138)
        case "python": return Color(hex: 0x3572A5)
        case "typescript": return Color(hex: 0x3178C6)
        case "javascript": return Color(hex: 0xF1E05A)
        case "rust": return Color(hex: 0xDEA584)
        case "go": return Color(hex: 0x00ADD8)
        case "c++", "cpp": return Color(hex: 0xF34B7D)
        case "c": return Color(hex: 0x555555)
        case "java": return Color(hex: 0xB07219)
        case "kotlin": return Color(hex: 0xA97BFF)
        case "dart": return Color(hex: 0x00B4AB)
        case "ruby": return Color(hex: 0x701516)
        case "php": return Color(hex: 0x4F5D95)
        case "c#", "csharp": return Color(hex: 0x178600)
        case "shell": return Color(hex: 0x89E051)
        case "html": return Color(hex: 0xE34C26)
        case "css": return Color(hex: 0x563D7C)
        default: return DS.textSecondary
        }
    }
}
