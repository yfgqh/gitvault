//
//  AppLanguage.swift
//  GitVault
//
//  界面语言：跟随系统 / 简体中文 / English。
//  通过写入 AppleLanguages 生效——系统在下次启动时按该语言加载 Localizable.strings。
//

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case chinese
    case english

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return NSLocalizedString("跟随系统", comment: "")
        case .chinese: return "简体中文"
        case .english: return "English"
        }
    }

    /// 写入的 AppleLanguages 值；system 表示清除覆盖
    private var languageCode: [String]? {
        switch self {
        case .system: return nil
        case .chinese: return ["zh-Hans"]
        case .english: return ["en"]
        }
    }

    private static let key = "gv.language"

    static var current: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: key) ?? "system") ?? .system
    }

    static func apply(_ language: AppLanguage) {
        let defaults = UserDefaults.standard
        defaults.set(language.rawValue, forKey: key)
        if let code = language.languageCode {
            defaults.set(code, forKey: "AppleLanguages")
        } else {
            defaults.removeObject(forKey: "AppleLanguages")
        }
        defaults.synchronize()
    }
}
