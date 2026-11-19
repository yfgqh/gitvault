//
//  CategoryFeedViewModel.swift
//  GitVault
//
//  二级主题页：先按「子分类」筛，再按状态 / 语言 / 排序筛选。
//  抓取走 GitHubService.fetchCategory（逐 topic 查询合并，不再出现 0 结果）。
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
    @Published var errorMessage: String?

    @Published var activeSub: RepoSubcategory?
    @Published var sortMode: SortMode = .stars
    @Published var activeActivity: ActivityTag?
    @Published var activeLanguage: String?

    private let api: any GitHubAPI
    private var didLoad = false
    private let fetchLimit = 100

    init(category: RepoCategory, api: any GitHubAPI = GitHubService.shared) {
        self.category = category
        self.api = api
    }

    // MARK: 展示

    var languages: [String] {
        Array(Set(items.map(\.language))).sorted()
    }

    /// 子分类各自命中的数量，用于 chip 上的角标
    func counts(for sub: RepoSubcategory) -> Int {
        items.filter { sub.matches($0) }.count
    }

    var displayed: [ShowcaseRepo] {
        var list = items
        if let activeSub {
            list = list.filter { activeSub.matches($0) }
        }
        if let activeActivity { list = list.filter { $0.activity == activeActivity } }
        if let activeLanguage { list = list.filter { $0.language == activeLanguage } }
        switch sortMode {
        case .stars: list.sort { $0.stars > $1.stars }
        case .active: list.sort { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
        case .language: list.sort { ($0.language, -$0.stars) < ($1.language, -$1.stars) }
        }
        return list
    }

    var truncatedHint: String? {
        guard totalCount > 0 else { return nil }
        if activeSub != nil {
            return "该子分类命中 \(displayed.count) 个（本次抓取前 \(fetchLimit) 名内）"
        }
        return totalCount > items.count ? "共 \(totalCount) 个，已展示前 \(items.count) 名" : nil
    }

    // MARK: 加载

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await reload()
    }

    func reload() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let fetchedCall = api.fetchCategory(category, limit: fetchLimit)
            async let totalCall = api.categoryTotal(category)

            let fetched = try await fetchedCall
            let total = (try? await totalCall) ?? fetched.count

            items = fetched.map(ShowcaseRepo.init(dto:))
            totalCount = max(total, items.count)
            CrashReporter.log("category \(category.rawValue): \(items.count) items / total \(totalCount)")
        } catch {
            errorMessage = error.localizedDescription
            if items.isEmpty {
                items = MockData.repos(in: category)
                totalCount = items.count
            }
        }
    }

    func setSubcategory(_ sub: RepoSubcategory?) {
        activeSub = sub
    }
}
