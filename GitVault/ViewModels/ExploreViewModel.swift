//
//  ExploreViewModel.swift
//  GitVault
//
//  首页数据编排（iOS 16 兼容：ObservableObject）。
//

import Foundation
import Combine

@MainActor
final class ExploreViewModel: ObservableObject {
    @Published var featured: [ShowcaseRepo] = []
    @Published var trending: [ShowcaseRepo] = []
    @Published var forYou: [ShowcaseRepo] = []
    @Published var isLoading = false
    @Published var isUsingFallback = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?

    private let api: any GitHubAPI
    private var didLoad = false
    private var lastLoadedAt: Date?
    /// 冷却时间：避免切换 Tab / 反复上下拉时堆叠请求（未登录只有 60 次/小时）
    private let cooldown: TimeInterval = 90

    init(api: any GitHubAPI = GitHubService.shared) {
        self.api = api
    }

    func loadIfNeeded() async {
        if didLoad, let last = lastLoadedAt, Date().timeIntervalSince(last) < cooldown {
            return
        }
        didLoad = true
        await reload()
    }

    func reload() async {
        // 防重入：正在加载时直接返回，避免同一时刻并发抓三次接口
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let trendingDTOs = api.trending(days: 14)
            async let aiItems = api.fetchCategory(.ai, limit: 12)
            async let toolItems = api.fetchCategory(.tooling, limit: 12)

            let trending = try await trendingDTOs
            let ai = try await aiItems
            let tools = try await toolItems

            let mapped = trending.map(ShowcaseRepo.init(dto:))
            self.trending = mapped
            self.featured = Array(mapped.prefix(AppConfig.featuredCount)).map { repo in
                var copy = repo
                copy.isFeatured = true
                return copy
            }

            let featuredIDs = Set(self.featured.map(\.id))
            self.forYou = (ai.map(ShowcaseRepo.init(dto:)) + tools.map(ShowcaseRepo.init(dto:)))
                .filter { !featuredIDs.contains($0.id) }
                .sorted { $0.stars > $1.stars }
                .prefix(8)
                .map { $0 }
            self.isUsingFallback = false
            self.lastUpdated = .now
            self.lastLoadedAt = .now
            CrashReporter.log("explore: loaded \(mapped.count) trending / \(self.forYou.count) for-you")
        } catch {
            errorMessage = error.localizedDescription
            CrashReporter.log("explore: load failed \(error.localizedDescription)")
            if trending.isEmpty {
                trending = MockData.trending
                featured = Array(MockData.featured)
                forYou = Array(MockData.forYou)
                isUsingFallback = true
            }
        }
    }
}
