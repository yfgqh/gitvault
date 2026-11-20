//
//  AllReposStore.swift
//  GitVault
//
//  「全量」仓库库：按星标区间分桶抓取，逐步补齐到 GitHub 搜索上限。
//
//  为什么分桶：search API 单个查询最多返回 1000 条（10 页 × 100），
//  一个 `stars:>500` 查询会被截断。拆成 5 个区间分别抓，才能覆盖更多仓库。
//

import Foundation
import Combine

@MainActor
final class AllReposStore: ObservableObject {
    /// 星标区间（闭开区间，GitHub 搜索语法）
    static let buckets: [String] = [
        "stars:500..999",
        "stars:1000..1999",
        "stars:2000..4999",
        "stars:5000..19999",
        "stars:20000..10000000"
    ]

    static let pagesPerBucket = 10   // GitHub 硬上限

    @Published private(set) var repos: [ShowcaseRepo] = []
    @Published private(set) var lastRefresh: Date?
    @Published private(set) var isRefreshing = false
    @Published private(set) var coverage: Int = 0

    private let fileURL: URL
    private let stateKey = "gv.allrepos.cursor"
    private var didLoad = false

    init() {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: nil,
                                                create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("GitVault", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("all-repos.json")
    }

    // MARK: 读取

    func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let cached = try? decoder.decode([CachedRepo].self, from: data) {
            repos = cached.map(ShowcaseRepo.init(cached:))
            coverage = repos.count
            CrashReporter.logSync("all-repos: loaded \(repos.count)")
        }
    }

    func items(in category: RepoCategory) -> [ShowcaseRepo] {
        repos.filter { $0.category == category }
    }

    func search(_ keyword: String) -> [ShowcaseRepo] {
        let q = keyword.lowercased()
        guard !q.isEmpty else { return [] }
        return repos.filter {
            $0.name.lowercased().contains(q)
            || $0.owner.lowercased().contains(q)
            || $0.summary.lowercased().contains(q)
            || $0.topics.contains { $0.contains(q) }
        }
    }

    // MARK: 增量抓取（每次只拉一页，轮转推进，避免一次烧光额度）

    func refreshStep(api: any GitHubAPI = GitHubService.shared) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let cursor = UserDefaults.standard.integer(forKey: stateKey)
        let bucketIndex = cursor % AllReposStore.buckets.count
        let page = (cursor / AllReposStore.buckets.count) % AllReposStore.pagesPerBucket + 1

        do {
            let pageResult = try await api.searchRepositories(
                query: AllReposStore.buckets[bucketIndex],
                sort: .stars,
                page: page,
                perPage: 100
            )
            let mapped = pageResult.items.map(ShowcaseRepo.init(dto:))
            merge(mapped)
            UserDefaults.standard.set(cursor + 1, forKey: stateKey)
            CrashReporter.log("all-repos: bucket \(bucketIndex) page \(page) -> +\(mapped.count), total \(repos.count)")
            persist()
        } catch is CancellationError {
            return
        } catch {
            CrashReporter.log("all-repos: step failed \(error.localizedDescription)")
        }
    }

    private func merge(_ incoming: [ShowcaseRepo]) {
        var index: [String: ShowcaseRepo] = [:]
        for repo in repos { index[repo.id] = repo }
        for repo in incoming { index[repo.id] = repo }
        repos = index.values.sorted { $0.stars > $1.stars }
        coverage = repos.count
        lastRefresh = .now
    }

    private func persist() {
        let snapshot = repos.map(CachedRepo.init(repo:))
        let url = fileURL
        DispatchQueue.global(qos: .utility).async {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                try encoder.encode(snapshot).write(to: url, options: .atomic)
            } catch {
                CrashReporter.log("all-repos: persist failed")
            }
        }
    }
}
