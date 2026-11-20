//
//  DiscoveryEngine.swift
//  GitVault
//
//  发现页的分发引擎：五维评分 + 分区编排 + 去重与多样性约束。
//
//  设计要点：
//  - 热度取 log10 归一，避免 10 万星项目直接碾压一切
//  - 分区各自排序（新星看日增、宝石看质量、常青看活跃、热门看综合）
//  - 编排层强制：同一仓库不跨区、同 owner 全页最多 1 个、同分类每区最多 3 个
//

import Foundation

struct DiscoveryProfile {
    var topics: Set<String> = []
    var languages: Set<String> = []
    var isEmpty: Bool { topics.isEmpty && languages.isEmpty }
}

struct DiscoveryItem: Identifiable {
    let repo: ShowcaseRepo
    let score: Double
    let quality: Double
    let activity: Double
    let starsPerDay: Double
    let reason: String

    var id: String { repo.id }
}

struct DiscoveryFeed {
    var featured: [ShowcaseRepo] = []
    var rising: [DiscoveryItem] = []
    var gems: [DiscoveryItem] = []
    var evergreen: [DiscoveryItem] = []
    var trending: [DiscoveryItem] = []
    var forYou: [DiscoveryItem] = []
    var savedAt: Date = .now

    var isEmpty: Bool {
        featured.isEmpty && rising.isEmpty && gems.isEmpty
            && evergreen.isEmpty && trending.isEmpty && forYou.isEmpty
    }
}

/// 四个来源池（都是 GitHub 搜索结果，已映射成 UI 模型）
struct DiscoveryPools {
    var rising: [ShowcaseRepo] = []
    var gems: [ShowcaseRepo] = []
    var evergreen: [ShowcaseRepo] = []
    var trending: [ShowcaseRepo] = []
}

enum DiscoveryEngine {

    // MARK: 评分

    static func evaluate(_ repo: ShowcaseRepo,
                         profile: DiscoveryProfile,
                         now: Date = .now) -> DiscoveryItem {
        let ageDays = max(daysBetween(repo.createdAt ?? repo.updatedAt, and: now), 1)

        // 热度 30
        let heat = min(log10(Double(max(repo.stars, 1))) / log10(100_000), 1.0) * 30

        // 新鲜度 20
        var freshness = 0.0
        if let created = repo.createdAt {
            let days = ageDays
            if days <= 90 {
                freshness = 20
            } else if days < 180 {
                freshness = 20 - (days - 90) * 0.222
            }
        }

        // 活跃度 20
        var activity = 0.0
        if let pushed = repo.updatedAt {
            let days = daysBetween(pushed, and: now)
            switch days {
            case ..<7: activity = 20
            case ..<30: activity = 15
            case ..<90: activity = 8
            case ..<180: activity = 3
            default: activity = 0
            }
        }

        // 质量 20
        var quality = 0.0
        if repo.topics.count >= 3 { quality += 5 }
        if repo.license != .none { quality += 5 }
        if repo.summary.count >= 20 { quality += 5 }
        if repo.homepageURL != nil { quality += 3 }
        if repo.stars > 0, Double(repo.openIssues) / Double(repo.stars) < 0.02 { quality += 2 }

        // 个人相关 10
        var relevance = 0.0
        if !profile.topics.isEmpty,
           repo.topics.contains(where: { profile.topics.contains($0.lowercased()) }) {
            relevance += 6
        }
        if !profile.languages.isEmpty,
           profile.languages.contains(repo.language.lowercased()) {
            relevance += 4
        }

        let starsPerDay = Double(repo.stars) / ageDays
        let score = heat + freshness + activity + quality + relevance

        // 推荐理由：最多两条，按信息量排序
        var tags: [String] = []
        if ageDays <= 180, repo.stars >= 300 {
            tags.append("新项目 · \(Int(ageDays / 30)) 个月")
        }
        if starsPerDay >= 5 {
            tags.append("日增 \(Int(starsPerDay)) 星")
        }
        if (200...3000).contains(repo.stars), quality >= 15 {
            tags.append("隐藏宝石")
        }
        if quality >= 15, repo.topics.count >= 3, repo.license != .none {
            tags.append("文档齐全")
        }
        if relevance >= 6 {
            tags.append("契合你的收藏")
        }
        if activity >= 15, repo.stars >= 5000 {
            tags.append("持续维护")
        }
        let reason = tags.prefix(2).joined(separator: " · ")

        return DiscoveryItem(repo: repo,
                             score: score,
                             quality: quality,
                             activity: activity,
                             starsPerDay: starsPerDay,
                             reason: reason)
    }

    // MARK: 编排

    static func arrange(pools: DiscoveryPools,
                        profile: DiscoveryProfile,
                        now: Date = .now) -> DiscoveryFeed {
        let risingScored = pools.rising
            .filter { $0.stars >= 300 }
            .map { evaluate($0, profile: profile, now: now) }
            .sorted { $0.starsPerDay > $1.starsPerDay }

        let gemScored = pools.gems
            .filter { (200...3000).contains($0.stars) }
            .map { evaluate($0, profile: profile, now: now) }
            .sorted { ($0.quality, $0.score) > ($1.quality, $1.score) }

        let evergreenScored = pools.evergreen
            .filter { $0.stars >= 5000 }
            .map { evaluate($0, profile: profile, now: now) }
            .sorted { ($0.activity, $0.score) > ($1.activity, $1.score) }

        let trendingScored = pools.trending
            .map { evaluate($0, profile: profile, now: now) }
            .sorted { $0.score > $1.score }

        let allScored = (risingScored + gemScored + evergreenScored + trendingScored)
            .reduce(into: [String: DiscoveryItem]()) { dict, item in
                if let existing = dict[item.id], existing.score >= item.score { return }
                dict[item.id] = item
            }
            .values
            .sorted { $0.score > $1.score }

        var selection = Selection()
        var feed = DiscoveryFeed()
        feed.savedAt = now

        feed.rising = pick(risingScored, limit: 6, maxPerCategory: 2, selection: &selection)
        feed.gems = pick(gemScored, limit: 6, maxPerCategory: 2, selection: &selection)
        feed.evergreen = pick(evergreenScored, limit: 6, maxPerCategory: 2, selection: &selection)
        feed.trending = pick(trendingScored, limit: 12, maxPerCategory: 3, selection: &selection)

        // 为你：有画像才出，否则退化成「新星补充」
        if profile.isEmpty {
            feed.forYou = pick(allScored.filter { $0.repo.stars >= 1000 },
                               limit: 6, maxPerCategory: 2, selection: &selection)
        } else {
            let relevant = allScored
                .filter { item in
                    item.repo.topics.contains { profile.topics.contains($0.lowercased()) }
                        || profile.languages.contains(item.repo.language.lowercased())
                }
                .sorted { $0.score > $1.score }
            feed.forYou = pick(relevant, limit: 6, maxPerCategory: 2, selection: &selection)
            if feed.forYou.isEmpty {
                feed.forYou = pick(allScored, limit: 6, maxPerCategory: 2, selection: &selection)
            }
        }

        feed.featured = featured(from: allScored, now: now)
        return feed
    }

    // MARK: 精选（按日期轮换，六类各一）

    private static func featured(from scored: [DiscoveryItem], now: Date) -> [ShowcaseRepo] {
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: now) ?? 1

        var perCategory: [RepoCategory: [DiscoveryItem]] = [:]
        for item in scored {
            perCategory[item.repo.category, default: []].append(item)
        }

        var picks: [ShowcaseRepo] = []
        for category in RepoCategory.allCases {
            guard let list = perCategory[category], !list.isEmpty else { continue }
            let offset = dayOfYear % list.count
            picks.append(list[offset].repo)
        }

        if picks.count < 4 {
            picks = Array(scored.prefix(4)).map(\.repo)
        }
        let rotate = picks.count > 4 ? dayOfYear % picks.count : 0
        let rotated = Array(picks[rotate...]) + Array(picks[..<rotate])
        return Array(rotated.prefix(4))
    }

    // MARK: 选择器

    private struct Selection {
        var usedIDs = Set<String>()
        var usedOwners = Set<String>()
        var categoryCount: [String: Int] = [:]
    }

    private static func pick(_ pool: [DiscoveryItem],
                             limit: Int,
                             maxPerCategory: Int,
                             selection: inout Selection) -> [DiscoveryItem] {
        var result: [DiscoveryItem] = []

        // 第一轮：严格去重（同仓库 / 同 owner / 同分类上限）
        for item in pool {
            if result.count >= limit { break }
            if selection.usedIDs.contains(item.id) { continue }
            if selection.usedOwners.contains(item.repo.owner) { continue }
            let category = item.repo.category.rawValue
            if (selection.categoryCount[category] ?? 0) >= maxPerCategory { continue }
            accept(item, into: &result, selection: &selection)
        }

        // 第二轮：放宽 owner 限制，保证区块不至于太空
        if result.count < limit {
            for item in pool {
                if result.count >= limit { break }
                if selection.usedIDs.contains(item.id) { continue }
                let category = item.repo.category.rawValue
                if (selection.categoryCount[category] ?? 0) >= maxPerCategory + 1 { continue }
                accept(item, into: &result, selection: &selection)
            }
        }

        return result
    }

    private static func accept(_ item: DiscoveryItem,
                               into result: inout [DiscoveryItem],
                               selection: inout Selection) {
        selection.usedIDs.insert(item.id)
        selection.usedOwners.insert(item.repo.owner)
        selection.categoryCount[item.repo.category.rawValue, default: 0] += 1
        result.append(item)
    }

    // MARK: 工具

    static func daysBetween(_ date: Date?, and now: Date) -> Double {
        guard let date else { return 365 }
        return max(now.timeIntervalSince(date) / 86_400, 0)
    }
}

