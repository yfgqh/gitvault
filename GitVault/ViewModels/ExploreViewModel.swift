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

            let featuredIDs = Set(self.featured.map(\.id))
            self.forYou = (ai.items.map(ShowcaseRepo.init(dto:)) + tools.items.map(ShowcaseRepo.init(dto:)))
                .filter { !featuredIDs.contains($0.id) }
                .sorted { $0.stars > $1.stars }
                .prefix(8)
                .map { $0 }
            self.isUsingFallback = false
            self.lastUpdated = .now
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
