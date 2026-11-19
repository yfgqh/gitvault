//
//  CategoryFeedViewModel.swift
//  GitVault
//
//  二级主题页：分页拉取 + 客户端筛选（状态 / 语言 / 排序）。
//

import Foundation
import Observation

@Observable
@MainActor
final class CategoryFeedViewModel {
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
    var items: [ShowcaseRepo] = []
    var totalCount = 0
    var isLoading = false
    var isLoadingMore = false
    var errorMessage: String?

    var sortMode: SortMode = .stars
    var activeActivity: ActivityTag?
    var activeLanguage: String?

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

    /// 展示用列表：本地筛选 + 排序，避免每换一个 Chip 就打一次接口
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
                // 本地 Mock 兜底，保证页面结构可读
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
