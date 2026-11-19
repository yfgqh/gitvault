//
//  SearchViewModel.swift
//  GitVault
//
//  搜索编排（iOS 16 兼容：ObservableObject）。
//

import Foundation
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var sort: SearchSort = .stars
    @Published var activeCategory: RepoCategory?
    @Published var activeLanguage: String?
    @Published var minStars: Int?

    @Published var results: [ShowcaseRepo] = []
    @Published var totalCount = 0
    @Published var isSearching = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var history: [String] = []

    private var page = 1
    private let api: any GitHubAPI

    init(api: any GitHubAPI = GitHubService.shared) {
        self.api = api
        loadHistory()
    }

    var hasFilters: Bool {
        activeCategory != nil || activeLanguage != nil || minStars != nil
    }

    var isBlank: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !hasFilters
    }

    var canLoadMore: Bool { results.count < totalCount }

    // MARK: 搜索

    func perform(debounced: Bool) async {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty || hasFilters else {
            results = []
            totalCount = 0
            return
        }

        isSearching = true
        errorMessage = nil

        if debounced {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
        }

        page = 1
        do {
            let pageResult = try await api.searchRepositories(
                query: buildQuery(keyword),
                sort: sort,
                page: 1,
                perPage: AppConfig.perPage
            )
            results = pageResult.items.map(ShowcaseRepo.init(dto:))
            totalCount = pageResult.totalCount
        } catch {
            if Task.isCancelled { return }
            results = []
            totalCount = 0
            errorMessage = error.localizedDescription
        }
        isSearching = false
    }

    func loadMoreIfNeeded(current repo: ShowcaseRepo) async {
        guard repo.id == results.last?.id, canLoadMore, !isLoadingMore, !isSearching else { return }
        await loadMore()
    }

    func loadMore() async {
        guard canLoadMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        page += 1
        do {
            let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let pageResult = try await api.searchRepositories(
                query: buildQuery(keyword),
                sort: sort,
                page: page,
                perPage: AppConfig.perPage
            )
            let mapped = pageResult.items.map(ShowcaseRepo.init(dto:))
            let existing = Set(results.map(\.id))
            results.append(contentsOf: mapped.filter { !existing.contains($0.id) })
            totalCount = pageResult.totalCount
        } catch {
            errorMessage = error.localizedDescription
            page = max(1, page - 1)
        }
    }

    private func buildQuery(_ keyword: String) -> String {
        var parts: [String] = []
        if !keyword.isEmpty { parts.append(keyword) }
        if let activeLanguage { parts.append("language:\(activeLanguage)") }
        if let minStars { parts.append("stars:>=\(minStars)") }
        if let activeCategory, let topic = activeCategory.keywords.first {
            parts.append("topic:\(topic.replacingOccurrences(of: " ", with: "-"))")
        }
        if parts.isEmpty { parts.append("stars:>1000") }
        return parts.joined(separator: " ")
    }

    // MARK: 历史

    func record(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        history.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        history.insert(trimmed, at: 0)
        if history.count > 10 { history = Array(history.prefix(10)) }
        persistHistory()
    }

    func removeHistory(_ text: String) {
        history.removeAll { $0 == text }
        persistHistory()
    }

    func clearHistory() {
        history = []
        persistHistory()
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: AppConfig.searchHistoryKey),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            history = MockData.defaultSearchHistory
            return
        }
        history = decoded
    }

    private func persistHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: AppConfig.searchHistoryKey)
    }
}
