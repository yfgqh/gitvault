//
//  ExploreViewModel.swift
//  GitVault
//
//  首页数据编排：今日精选 / 飙升榜 / 为你推荐。
//  接口失败时退回离线示例数据，保证首屏永远不是白屏。
//

import Foundation
import Observation

@Observable
@MainActor
final class ExploreViewModel {
    var featured: [ShowcaseRepo] = []
    var trending: [ShowcaseRepo] = []
    var forYou: [ShowcaseRepo] = []
    var isLoading = false
    var isUsingFallback = false
    var errorMessage: String?
    var lastUpdated: Date?

    private let api: any GitHubAPI
    private var didLoad = false

    init(api: any GitHubAPI = GitHubService.shared) {
        self.api = api
    }

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await reload()
    }

    func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let trendingDTOs = api.trending(days: 14)
            async let aiPage = api.searchByCategory(.ai, page: 1)
            async let toolPage = api.searchByCategory(.tooling, page: 1)

            let trending = try await trendingDTOs
            let ai = try await aiPage
            let tools = try await toolPage

            let mapped = trending.map(ShowcaseRepo.init(dto:))
            self.trending = mapped
            self.featured = Array(mapped.prefix(AppConfig.featuredCount)).map { repo in
                var copy = repo
                copy.isFeatured = true
                return copy
            }
            // 推荐：AI + 工具链里星标最高、且不与精选重复的项目
            let featuredIDs = Set(self.featured.map(\.id))
            self.forYou = (ai.items.map(ShowcaseRepo.init(dto:)) + tools.items.map(ShowcaseRepo.init(dto:)))
                .filter { !featuredIDs.contains($0.id) }
                .sorted { $0.stars > $1.stars }
                .prefix(8)
                .map { $0 }
            self.isUsingFallback = false
            self.lastUpdated = .now
        } catch {
            errorMessage = error.localizedDescription
            if trending.isEmpty {
                // 离线兜底：用内置示例，标注来源，避免误以为是实时数据
                trending = MockData.trending
                featured = Array(MockData.featured)
                forYou = Array(MockData.forYou)
                isUsingFallback = true
            }
        }
    }
}
