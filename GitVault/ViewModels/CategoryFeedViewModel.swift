//
//  CategoryFeedViewModel.swift
//  GitVault
//
//  二级主题页（iOS 16 兼容：ObservableObject）。
//

import Foundation
import Combine

@MainActor
final class CategoryFeedViewModel: ObservableObject {
    enum SortMode: String, CaseIterable, Identifiable {
        case stars, active, language
        var id: String { rawValue }
        var title: String {
            switch self {
            case .stars: return "Star 最多"
            case .active: return "最近活跃"
            case .language: return "按语言"
            }
        }
    }

    let category: RepoCategory

    @Published var items: [ShowcaseRepo] = []
    @Published var totalCount = 0
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?

    @Published var sortMode: SortMode = .stars
    @Published var activeActivity: ActivityTag?
    @Published var activeLanguage: String?

    private var page = 1
    private let api: any GitHubAPI
    private var didLoad = false

    init(category: RepoCategory, api: any GitHubAPI = GitHubService.shared) {
        self.category = category
        self.api = api
    }

    var languages: [String] {
        Array(Set(items.map(\.language))).sorted()
    }

    var displayed: [ShowcaseRepo] {
        var list = items
        if let activeActivity { list = list.filter { $0.activity == activeActivity } }
        if let activeLanguage { list = list.filter { $0.language == activeLanguage } }
        switch sortMode {
        case .stars: list.sort { $0.stars > $1.stars }
        case .active: list.sort { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
        case .language: list.sort { ($0.language, -$0.stars) < ($1.language, -$1.stars) }
        }
        return list
    }

    var canLoadMore: Bool { items.count < totalCount }

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await reload()
    }

    func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        page = 1
        do {
            let result = try await api.searchByCategory(category, page: 1)
            items = result.items.map(ShowcaseRepo.init(dto:))
            totalCount = result.totalCount
        } catch {
            errorMessage = error.localizedDescription
            if items.isEmpty {
                items = MockData.repos(in: category)
                totalCount = items.count
            }
        }
    }

    func loadMore() async {
        guard canLoadMore, !isLoadingMore, !isLoading else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        page += 1
        do {
            let result = try await api.searchByCategory(category, page: page)
            let mapped = result.items.map(ShowcaseRepo.init(dto:))
            let existing = Set(items.map(\.id))
            items.append(contentsOf: mapped.filter { !existing.contains($0.id) })
            totalCount = result.totalCount
        } catch {
            page = max(1, page - 1)
        }
    }
}
