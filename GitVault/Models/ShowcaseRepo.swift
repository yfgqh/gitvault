//
//  ShowcaseRepo.swift
//  GitVault
//
//  阶段 1 的展示模型：UI 先行，字段与阶段 2 的 GitHub DTO 一一对应，
//  换数据源时视图层零改动（Repository Pattern 的第一道防线）。
//

import SwiftUI

struct ShowcaseRepo: Identifiable, Hashable {
    /// fullName，例如 "apple/swift"
    let id: String
    let owner: String
    let name: String
    /// 一句话中文简介（阶段 2 由摘要服务生成，阶段 1 为人工 Mock）
    let summary: String
    let language: String
    let stars: Int
    /// 今日新增 star（Trending 榜单的核心指标）
    let starDeltaToday: Int
    let forks: Int
    let openIssues: Int
    let category: RepoCategory
    let activity: ActivityTag
    let usage: UsageTag
    let license: LicenseTag
    let gradient: [Color]
    /// 是否进入「今日精选」
    let isFeatured: Bool

    var fullName: String { "\(owner)/\(name)" }

    var initials: String {
        let first = owner.first.map(String.init) ?? ""
        let second = name.first.map(String.init) ?? ""
        return (first + second).uppercased()
    }

    var starText: String { Self.compact(stars) }
    var forkText: String { Self.compact(forks) }

    private static func compact(_ value: Int) -> String {
        if value >= 1000 {
            let k = Double(value) / 1000.0
            return String(format: k >= 10 ? "%.0fk" : "%.1fk", k)
        }
        return "\(value)"
    }

    var githubURL: URL? { URL(string: "https://github.com/\(fullName)") }
}
