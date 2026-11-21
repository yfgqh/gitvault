//
//  Gamification.swift
//  GitVault
//
//  趣味化的纯计算层：项目体检、成就徽章、开发者人格、周报统计。
//  全部本地计算，不发网络请求。
//

import Foundation
import SwiftUI

// MARK: - 项目体检

struct RepoHealth {
    let score: Int
    let activity: Int
    let community: Int
    let maintenance: Int
    let documentation: Int
    let verdict: String
    let level: Level

    enum Level {
        case excellent, good, fair, risky
        var title: String {
            switch self {
            case .excellent: return "状态优秀"
            case .good: return "稳定可用"
            case .fair: return "一般活跃"
            case .risky: return "谨慎选用"
            }
        }
        var tint: Color {
            switch self {
            case .excellent: return DS.success
            case .good: return DS.accent
            case .fair: return DS.warning
            case .risky: return DS.danger
            }
        }
    }
}

enum RepoHealthCalculator {
    static func evaluate(_ repo: ShowcaseRepo) -> RepoHealth {
        // 活跃度 40
        var activity = 0
        if let updated = repo.updatedAt {
            let days = Calendar.current.dateComponents([.day], from: updated, to: .now).day ?? 999
            switch days {
            case ..<30: activity = 40
            case ..<90: activity = 32
            case ..<180: activity = 22
            case ..<365: activity = 12
            default: activity = 4
            }
        }

        // 社区 25
        let starScore = min(Double(repo.stars) / 5000.0, 1.0) * 18
        let forkScore = min(Double(repo.forks) / 800.0, 1.0) * 7
        let community = Int(starScore + forkScore)

        // 维护 20：issue 相对星标越低越好
        let ratio = Double(repo.openIssues) / Double(max(repo.stars, 1))
        var maintenance = 0
        switch ratio {
        case ..<0.02: maintenance = 20
        case ..<0.06: maintenance = 15
        case ..<0.15: maintenance = 9
        default: maintenance = 4
        }

        // 文档 15
        var documentation = 0
        if !repo.topics.isEmpty { documentation += 4 }
        if repo.license != .none { documentation += 5 }
        if repo.summary.count >= 20 { documentation += 4 }
        if repo.summary.count >= 50 { documentation += 2 }

        let total = min(100, activity + community + maintenance + documentation)
        let level: RepoHealth.Level
        switch total {
        case 80...: level = .excellent
        case 60..<80: level = .good
        case 40..<60: level = .fair
        default: level = .risky
        }

        var verdict: String
        switch level {
        case .excellent:
            verdict = "近期有提交、社区活跃、文档齐全，可以放心用在生产环境。"
        case .good:
            verdict = "维护正常，文档基本够用；接入前建议读一遍 issue 区。"
        case .fair:
            verdict = "更新节奏偏慢，使用前确认关键问题是否已有人跟进。"
        case .risky:
            verdict = "长期未更新或 issue 积压明显，引入前建议先评估替代方案。"
        }

        if activity >= 32, maintenance <= 9 {
            verdict = "项目很活跃，但 issue 积压较多，适合能自行排查问题的团队。"
        }
        if activity <= 12 {
            verdict = "超过半年没有推送，作为参考实现阅读比直接依赖更稳妥。"
        }

        return RepoHealth(score: total,
                          activity: activity,
                          community: community,
                          maintenance: maintenance,
                          documentation: documentation,
                          verdict: verdict,
                          level: level)
    }
}

// MARK: - 成就徽章

struct Achievement: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
    let unlocked: Bool
    let progressText: String
}

enum Gamification {
    static func achievements(items: [VaultItem]) -> [Achievement] {
        let count = items.count
        let categories = Set(items.map { $0.category })
        let languages = Set(items.map { $0.language.lowercased() }.filter { $0 != "未知" })
        let days = Set(items.map { Calendar.current.startOfDay(for: $0.savedAt) })
        let streak = longestStreak(days)

        return [
            Achievement(id: "collect10", title: "初识", detail: "收藏 10 个项目",
                        symbol: "bookmark", tint: DS.accent,
                        unlocked: count >= 10, progressText: "\(min(count, 10))/10"),
            Achievement(id: "collect50", title: "收藏家", detail: "收藏 50 个项目",
                        symbol: "bookmark.fill", tint: DS.accentAlt,
                        unlocked: count >= 50, progressText: "\(min(count, 50))/50"),
            Achievement(id: "collect100", title: "图书馆", detail: "收藏 100 个项目",
                        symbol: "books.vertical.fill", tint: DS.warning,
                        unlocked: count >= 100, progressText: "\(min(count, 100))/100"),
            Achievement(id: "collect300", title: "档案馆", detail: "收藏 300 个项目",
                        symbol: "archivebox.fill", tint: DS.danger,
                        unlocked: count >= 300, progressText: "\(min(count, 300))/300"),
            Achievement(id: "cats3", title: "跨界", detail: "覆盖 3 个主题场景",
                        symbol: "square.grid.2x2", tint: DS.accent,
                        unlocked: categories.count >= 3, progressText: "\(min(categories.count, 3))/3"),
            Achievement(id: "cats6", title: "全景视角", detail: "覆盖全部 6 个主题",
                        symbol: "circle.hexagongrid.fill", tint: DS.accentAlt,
                        unlocked: categories.count >= 6, progressText: "\(min(categories.count, 6))/6"),
            Achievement(id: "lang3", title: "多语言", detail: "涉及 3 种编程语言",
                        symbol: "chevron.left.forwardslash.chevron.right", tint: DS.success,
                        unlocked: languages.count >= 3, progressText: "\(min(languages.count, 3))/3"),
            Achievement(id: "streak7", title: "七日不断", detail: "连续 7 天有收藏",
                        symbol: "flame.fill", tint: DS.warning,
                        unlocked: streak >= 7, progressText: "\(min(streak, 7))/7")
        ]
    }

    static func longestStreak(_ days: Set<Date>) -> Int {
        guard !days.isEmpty else { return 0 }
        let sorted = days.sorted()
        var best = 1
        var current = 1
        for index in 1..<sorted.count {
            let gap = Calendar.current.dateComponents([.day], from: sorted[index - 1], to: sorted[index]).day ?? 0
            if gap == 1 {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
        }
        return best
    }

    // MARK: 开发者人格

    static func persona(items: [VaultItem]) -> Persona {
        guard !items.isEmpty else { return Persona.empty }
        var counter: [RepoCategory: Int] = [:]
        for item in items { counter[item.category, default: 0] += 1 }
        let sorted = counter.sorted { $0.value > $1.value }
        let top = sorted.first?.key ?? .learning
        let second = sorted.dropFirst().first?.key

        switch top {
        case .ai:
            return Persona(title: "AI 观察员",
                           subtitle: "你在追踪模型、Agent 与推理侧的最新动向" + (second.map { "，也会留意\($0.title)" } ?? ""),
                           symbol: "brain.head.profile",
                           tint: DS.accent,
                           topCategories: Array(sorted.prefix(3)).map { $0.key })
        case .tooling:
            return Persona(title: "工具链炼金师",
                           subtitle: "你对效率有近乎偏执的追求，收藏里一半是能省时间的工具",
                           symbol: "wrench.and.screwdriver.fill",
                           tint: DS.accentAlt,
                           topCategories: Array(sorted.prefix(3)).map { $0.key })
        case .frontend:
            return Persona(title: "界面美学派",
                           subtitle: "你在意动效、密度和手感，会为了一个交互细节翻完整个仓库",
                           symbol: "paintbrush.pointed.fill",
                           tint: DS.warning,
                           topCategories: Array(sorted.prefix(3)).map { $0.key })
        case .backend:
            return Persona(title: "基础设施收集者",
                           subtitle: "数据库、中间件、云原生——你收藏的是系统的骨头",
                           symbol: "server.rack",
                           tint: DS.success,
                           topCategories: Array(sorted.prefix(3)).map { $0.key })
        case .mobile:
            return Persona(title: "端上体验官",
                           subtitle: "你关注 iOS、Android 与跨端方案，习惯从一个个 App 里找灵感",
                           symbol: "iphone.gen3",
                           tint: DS.accent,
                           topCategories: Array(sorted.prefix(3)).map { $0.key })
        case .data:
            return Persona(title: "数据炼金师",
                           subtitle: "管道、指标、特征——你擅长把原始数据变成可用的结论",
                           symbol: "chart.bar.xaxis",
                           tint: DS.accent,
                           topCategories: Array(sorted.prefix(3)).map { $0.key })
        case .database:
            return Persona(title: "存储守门人",
                           subtitle: "你对索引、事务和一致性有执念，选型时会先看存储层",
                           symbol: "cylinder.split.1x2",
                           tint: DS.success,
                           topCategories: Array(sorted.prefix(3)).map { $0.key })
        case .systems:
            return Persona(title: "底层潜水员",
                           subtitle: "内核、运行时、编译器——你愿意为了搞清楚机制读汇编",
                           symbol: "cpu",
                           tint: DS.textSecondary,
                           topCategories: Array(sorted.prefix(3)).map { $0.key })
        case .security:
            return Persona(title: "安全哨兵",
                           subtitle: "你在意攻击面、供应链与隐私边界，看到权限申请会多看一眼",
                           symbol: "lock.shield.fill",
                           tint: DS.danger,
                           topCategories: Array(sorted.prefix(3)).map { $0.key })
        case .learning:
            return Persona(title: "知识猎人",
                           subtitle: "清单、教程、面试题——你更在意把知识搬进自己的脑子",
                           symbol: "book.closed.fill",
                           tint: DS.accentAlt,
                           topCategories: Array(sorted.prefix(3)).map { $0.key })
        }
    }

    // MARK: 周报

    static func weekly(items: [VaultItem]) -> WeeklyStats {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let recent = items.filter { $0.savedAt >= weekAgo }

        var categoryCount: [RepoCategory: Int] = [:]
        var languageCount: [String: Int] = [:]
        for item in recent {
            categoryCount[item.category, default: 0] += 1
            languageCount[item.language, default: 0] += 1
        }

        let categories = categoryCount
            .sorted { $0.value > $1.value }
            .map { CountSlice(id: $0.key.rawValue, label: $0.key.title, value: $0.value, emoji: $0.key.emoji) }
        let languages = languageCount
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { CountSlice(id: $0.key, label: $0.key, value: $0.value, emoji: "◆") }

        return WeeklyStats(newCount: recent.count,
                           totalCount: items.count,
                           categories: categories,
                           languages: Array(languages),
                           mostActiveDay: mostActiveDay(recent))
    }

    private static func mostActiveDay(_ items: [VaultItem]) -> String {
        var counter: [Date: Int] = [:]
        for item in items {
            let day = Calendar.current.startOfDay(for: item.savedAt)
            counter[day, default: 0] += 1
        }
        guard let best = counter.max(by: { $0.value < $1.value }) else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "M 月 d 日"
        return formatter.string(from: best.key)
    }
}

struct CountSlice: Identifiable {
    let id: String
    let label: String
    let value: Int
    let emoji: String
}

struct WeeklyStats {
    let newCount: Int
    let totalCount: Int
    let categories: [CountSlice]
    let languages: [CountSlice]
    let mostActiveDay: String

    var headline: String {
        if newCount == 0 { return "本周还没有新增收藏" }
        return "本周新增 \(newCount) 个项目"
    }
}

struct Persona {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let topCategories: [RepoCategory]

    static let empty = Persona(
        title: "尚未成形",
        subtitle: "先收藏几个项目，人格会随你的选择慢慢长出来",
        symbol: "person.crop.circle.dashed",
        tint: DS.textTertiary,
        topCategories: []
    )
}
