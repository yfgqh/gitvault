//
//  ShowcaseRepo.swift
//  GitVault
//
//  UI 层统一使用的仓库模型。
//  它既可由 GitHub DTO 映射而来，也可由 Mock 手工构造：
//  - 由 DTO 映射时：竞态在 MainActor 上完成，分类 / 摘要走规则分类器；
//  - 由 Mock 构造时：保留完整参数，方便 #Preview。
//

import SwiftUI

struct ShowcaseRepo: Identifiable, Hashable {
    /// fullName，例如 "apple/swift"
    let id: String
    let owner: String
    let name: String
    /// 一句话中文简介
    let summary: String
    let language: String
    let stars: Int
    /// 今日新增 star（真实接口不提供该指标，Mock 才有；为 0 时 UI 不显示角标）
    let starDeltaToday: Int
    let forks: Int
    let openIssues: Int
    let category: RepoCategory
    let activity: ActivityTag
    let usage: UsageTag
    let license: LicenseTag
    let gradient: [Color]
    var isFeatured: Bool

    // MARK: 阶段 2 新增（对老代码全部有默认值，不破坏既有调用）

    /// 仓库 topics（GitHub 已小写）
    var topics: [String] = []
    /// 作者头像
    var avatarURL: URL? = nil
    /// 仓库主页
    var htmlURL: URL? = nil
    /// 最近推送时间
    var updatedAt: Date? = nil
    /// 原始英文描述（摘要卡里作为「原文」展示）
    var rawDescription: String? = nil

    var fullName: String { "\(owner)/\(name)" }

    var initials: String {
        let first = owner.first.map(String.init) ?? ""
        let second = name.first.map(String.init) ?? ""
        return (first + second).uppercased()
    }

    var starText: String { Self.compact(stars) }
    var forkText: String { Self.compact(forks) }

    var githubURL: URL? { htmlURL ?? URL(string: "https://github.com/\(fullName)") }

    static func compact(_ value: Int) -> String {
        if value >= 1000 {
            let k = Double(value) / 1000.0
            return String(format: k >= 10 ? "%.0fk" : "%.1fk", k)
        }
        return "\(value)"
    }

    // MARK: Mock 用全参构造（顺序与原版一致，保证阶段 1 的 Mock 数据零改动）

    init(
        id: String,
        owner: String,
        name: String,
        summary: String,
        language: String,
        stars: Int,
        starDeltaToday: Int,
        forks: Int,
        openIssues: Int,
        category: RepoCategory,
        activity: ActivityTag,
        usage: UsageTag,
        license: LicenseTag,
        gradient: [Color],
        isFeatured: Bool,
        topics: [String] = [],
        avatarURL: URL? = nil,
        htmlURL: URL? = nil,
        updatedAt: Date? = nil,
        rawDescription: String? = nil
    ) {
        self.id = id
        self.owner = owner
        self.name = name
        self.summary = summary
        self.language = language
        self.stars = stars
        self.starDeltaToday = starDeltaToday
        self.forks = forks
        self.openIssues = openIssues
        self.category = category
        self.activity = activity
        self.usage = usage
        self.license = license
        self.gradient = gradient
        self.isFeatured = isFeatured
        self.topics = topics
        self.avatarURL = avatarURL
        self.htmlURL = htmlURL
        self.updatedAt = updatedAt
        self.rawDescription = rawDescription
    }

    // MARK: DTO → UI 模型（规则分类 + 规则中文摘要）

    init(dto: RepositoryDTO) {
        let topics = dto.topics ?? []
        let category = RepoCategory.infer(
            fromTopics: topics,
            description: dto.description,
            language: dto.language
        )
        let activity = RuleClassifier.activity(
            stars: dto.stargazersCount,
            pushedAt: dto.pushedAt
        )
        let usage = RuleClassifier.usage(name: dto.name, topics: topics, stars: dto.stargazersCount)
        let license = LicenseTag.from(spdxID: dto.license?.spdxID)

        self.id = dto.fullName
        self.owner = dto.owner.login
        self.name = dto.name
        self.summary = SummaryService.chineseSummary(for: dto, category: category)
        self.language = dto.language ?? "未知"
        self.stars = dto.stargazersCount
        self.starDeltaToday = 0
        self.forks = dto.forksCount
        self.openIssues = dto.openIssuesCount
        self.category = category
        self.activity = activity
        self.usage = usage
        self.license = license
        self.gradient = category.gradient
        self.isFeatured = false
        self.topics = topics
        self.avatarURL = dto.owner.avatarURL.flatMap(URL.init(string:))
        self.htmlURL = URL(string: dto.htmlURL)
        self.updatedAt = dto.pushedAt ?? dto.updatedAt
        self.rawDescription = dto.description
    }
}

// MARK: - 由收藏记录反构造（离线展示用）

extension ShowcaseRepo {
    init(entry: VaultEntry) {
        self.init(
            id: entry.repoID,
            owner: entry.owner,
            name: entry.name,
            summary: entry.summary,
            language: entry.language,
            stars: entry.stars,
            starDeltaToday: 0,
            forks: entry.forks,
            openIssues: 0,
            category: entry.category,
            activity: .classic,
            usage: .readyToUse,
            license: entry.license,
            gradient: entry.category.gradient,
            isFeatured: false,
            topics: entry.topics,
            avatarURL: entry.avatarURL.flatMap(URL.init(string:)),
            htmlURL: URL(string: entry.htmlURL),
            updatedAt: entry.updatedAt
        )
    }
}
