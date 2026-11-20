//
//  ExploreViewModel.swift
//  GitVault
//
//  首页编排：四个来源池 → DiscoveryEngine 评分与去重 → 六个区块。
//  每天 08:00 重新拉取；冷启动先出磁盘缓存。
//

import Foundation
import Combine

@MainActor
final class ExploreViewModel: ObservableObject {
    @Published var feed = DiscoveryFeed()
    @Published var isLoading = false
    @Published var isUsingFallback = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?
    @Published private(set) var loadedFromCache = false

    private let api: any GitHubAPI
    private var didLoad = false
    private var lastLoadedAt: Date?

    /// 每天 08:00 是「今日精选」的刷新点
    static func todayRefreshPoint(_ now: Date = .now) -> Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .hour, value: 8, to: start) ?? start
    }

    init(api: any GitHubAPI = GitHubService.shared) {
        self.api = api
    }

    // MARK: 对外

    func loadIfNeeded(profile: DiscoveryProfile) async {
        loadCacheIfNeeded()
        if didLoad, let last = lastLoadedAt, last >= ExploreViewModel.todayRefreshPoint() {
            return
        }
        didLoad = true
        await reload(profile: profile)
    }

    func reload(profile: DiscoveryProfile) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let pools = try await fetchPools()
            let arranged = DiscoveryEngine.arrange(pools: pools, profile: profile)
            guard !arranged.isEmpty else { throw GitHubError.decoding("没有可展示的项目") }
            feed = arranged
            lastUpdated = .now
            lastLoadedAt = .now
            loadedFromCache = false
            isUsingFallback = false
            ExploreCache.save(arranged)
            CrashReporter.log("explore: rising \(arranged.rising.count) / gems \(arranged.gems.count) / hot \(arranged.trending.count)")
        } catch is CancellationError {
            return
        } catch {
            if Task.isCancelled { return }
            errorMessage = error.localizedDescription
            CrashReporter.log("explore: load failed \(error.localizedDescription)")
            if feed.isEmpty {
                feed = Self.fallbackFeed()
                isUsingFallback = true
            }
        }
    }

    private func loadCacheIfNeeded() {
        guard feed.isEmpty, let cached = ExploreCache.load(), !cached.isEmpty else { return }
        feed = cached
        lastUpdated = cached.savedAt
        loadedFromCache = true
    }

    // MARK: 拉取

    private func fetchPools() async throws -> DiscoveryPools {
        let calendar = Calendar.current
        let now = Date()
        let halfYear = calendar.date(byAdding: .day, value: -180, to: now) ?? now
        let month = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        let quarter = calendar.date(byAdding: .day, value: -90, to: now) ?? now
        let twoWeeks = calendar.date(byAdding: .day, value: -14, to: now) ?? now

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        let risingQuery = "created:>\(formatter.string(from: halfYear)) stars:>=300"
        let gemQuery = "stars:200..3000 pushed:>\(formatter.string(from: month))"
        let evergreenQuery = "stars:>=5000 pushed:>\(formatter.string(from: quarter))"
        let trendingQuery = "created:>\(formatter.string(from: twoWeeks)) stars:>=500"

        async let risingCall = api.searchRepositories(query: risingQuery, sort: .stars, page: 1, perPage: 50)
        async let gemCall = api.searchRepositories(query: gemQuery, sort: .stars, page: 1, perPage: 50)
        async let evergreenCall = api.searchRepositories(query: evergreenQuery, sort: .stars, page: 1, perPage: 30)
        async let trendingCall = api.searchRepositories(query: trendingQuery, sort: .stars, page: 1, perPage: 50)

        let rising = try await risingCall
        let gems = try await gemCall
        let evergreen = try await evergreenCall
        let trending = try await trendingCall

        return DiscoveryPools(
            rising: rising.items.map(ShowcaseRepo.init(dto:)),
            gems: gems.items.map(ShowcaseRepo.init(dto:)),
            evergreen: evergreen.items.map(ShowcaseRepo.init(dto:)),
            trending: trending.items.map(ShowcaseRepo.init(dto:))
        )
    }

    // MARK: 兜底

    private static func fallbackFeed() -> DiscoveryFeed {
        let repos = MockData.repos
        var feed = DiscoveryFeed()
        feed.featured = Array(repos.prefix(4))
        feed.rising = repos.map { DiscoveryItem(repo: $0, score: 0, quality: 0, activity: 0, starsPerDay: 0, reason: "离线示例") }
        return feed
    }
}
