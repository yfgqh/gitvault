//
//  AppConfig.swift
//  GitVault
//
//  全局配置。Token / ClientID 等敏感信息一律不进代码。
//

import Foundation

enum AppConfig {
    /// GitHub REST API v3 基址
    static let apiBase = URL(string: "https://api.github.com")!

    /// 官方推荐的 API 版本头
    static let apiVersion = "2022-11-28"

    /// 每页条数
    static let perPage = 20

    /// 首页「今日精选」条数
    static let featuredCount = 4

    /// 飙升榜条数
    static let trendingCount = 8

    /// OAuth Device Flow 只需要 client_id，可安全内置/由用户填写；
    /// 这里默认留空，由「我的 → GitHub 登录」引导用户填入自己的 OAuth App Client ID。
    static var oauthClientID: String {
        get { UserDefaults.standard.string(forKey: "gv.oauth.clientID") ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespaces), forKey: "gv.oauth.clientID") }
    }

    /// Device Flow 申请的权限（最小化：只读用户信息 + 公开仓库）
    static let oauthScopes = "read:user"

    /// 搜索历史持久化键
    static let searchHistoryKey = "gv.searchHistory.v1"

    /// 自定义标签持久化键
    static let customLabelsKey = "gv.customLabels.v1"
}
