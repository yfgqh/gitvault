//
//  CategoryCache.swift
//  GitVault
//
//  分类内容磁盘缓存：进入分类页先出上次结果，后台再刷新。
//  - 解决「每次都要重新拉、没数据就显示 0」
//  - 接口限流 / 断网时仍可浏览上次抓到的 100 个项目
//

import Foundation

/// 可持久化的仓库快照（ShowcaseRepo 含 Color，不能直接 Codable）
struct CachedRepo: Codable {
    var repoID: String
    var owner: String
    var name: String
    var summary: String
    var language: String
    var stars: Int
    var forks: Int
    var openIssues: Int
    var topics: [String]
    var licenseRaw: String
    var categoryRaw: String
    var activityRaw: String
    var usageRaw: String
    var avatarURL: String?
    var htmlURL: String
    var updatedAt: Date?

    init(repo: ShowcaseRepo) {
        repoID = repo.id
        owner = repo.owner
        name = repo.name
        summary = repo.summary
        language = repo.language
        stars = repo.stars
        forks = repo.forks
        openIssues = repo.openIssues
        topics = repo.topics
        licenseRaw = repo.license.rawValue
        categoryRaw = repo.category.rawValue
        activityRaw = repo.activity.rawValue
        usageRaw = repo.usage.rawValue
        avatarURL = repo.avatarURL?.absoluteString
        htmlURL = repo.githubURL?.absoluteString ?? ""
        updatedAt = repo.updatedAt
    }
}

extension ShowcaseRepo {
    init(cached: CachedRepo) {
        let category = RepoCategory(rawValue: cached.categoryRaw) ?? .learning
        self.init(
            id: cached.repoID,
            owner: cached.owner,
            name: cached.name,
            summary: cached.summary,
            language: cached.language,
            stars: cached.stars,
            starDeltaToday: 0,
            forks: cached.forks,
            openIssues: cached.openIssues,
            category: category,
            activity: ActivityTag(rawValue: cached.activityRaw) ?? .classic,
            usage: UsageTag(rawValue: cached.usageRaw) ?? .readyToUse,
            license: LicenseTag(rawValue: cached.licenseRaw) ?? .none,
            gradient: category.gradient,
            isFeatured: false,
            topics: cached.topics,
            avatarURL: cached.avatarURL.flatMap { URL(string: $0) },
            htmlURL: URL(string: cached.htmlURL),
            updatedAt: cached.updatedAt
        )
    }
}

struct CachedCategory: Codable {
    var total: Int
    var items: [CachedRepo]
    var savedAt: Date
}

final class CategoryCache {
    static let shared = CategoryCache()

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.yfgqh.gitvault.category-cache")
    private var memory: [String: CachedCategory] = [:]

    private init() {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: nil,
                                                create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("GitVault", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("category-cache.json")
        loadFromDisk()
    }

    // MARK: 读取

    func load(_ category: RepoCategory) -> CachedCategory? {
        memory[category.rawValue]
    }

    func savedAt(_ category: RepoCategory) -> Date? {
        memory[category.rawValue]?.savedAt
    }

    // MARK: 写入

    func save(_ category: RepoCategory, total: Int, repos: [ShowcaseRepo]) {
        let snapshot = CachedCategory(
            total: total,
            items: repos.prefix(100).map(CachedRepo.init(repo:)),
            savedAt: .now
        )
        memory[category.rawValue] = snapshot
        let payload = memory
        let url = fileURL
        queue.async {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(payload)
                try data.write(to: url, options: .atomic)
            } catch {
                CrashReporter.log("category-cache: save failed \(error.localizedDescription)")
            }
        }
    }

    // MARK: 磁盘

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode([String: CachedCategory].self, from: data) else {
            CrashReporter.logSync("category-cache: decode failed, ignored")
            return
        }
        memory = decoded
        let summary = decoded.map { "\($0.key)=\($0.value.items.count)" }.joined(separator: ",")
        CrashReporter.logSync("category-cache: loaded [\(summary)]")
    }
}

// MARK: - 离线基线（真实抓取值，作为首次启动 / 限流时的兜底）

extension RepoCategory {
    /// 2026-11 实测：`topic:<代表 topic> stars:>50` 的 total_count
    var baselineCount: Int {
        switch self {
        case .ai: return 8_714
        case .tooling: return 7_152
        case .frontend: return 13_804
        case .backend: return 3_123
        case .mobile: return 7_505
        case .learning: return 3_995
        }
    }
}
