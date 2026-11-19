//
//  DetailViewModel.swift
//  GitVault
//
//  详情页编排（iOS 16 兼容：ObservableObject）。
//

import Foundation
import Combine

struct LanguageSlice: Identifiable, Equatable {
    let name: String
    let percent: Double
    var id: String { name }
}

@MainActor
final class DetailViewModel: ObservableObject {
    @Published var repo: ShowcaseRepo
    @Published var languages: [LanguageSlice] = []
    @Published var readmeSummary: String?
    @Published var readmeSource: String = "本地规则"
    @Published var isLoadingDetail = false
    @Published var isLoadingReadme = false
    @Published var errorMessage: String?
    @Published var isSaved = false
    @Published var mark: MyMark?
    @Published var similar: [ShowcaseRepo] = []

    private let api: any GitHubAPI
    private let llm: any LLMClassifierProtocol
    private var didLoadDetail = false
    private var didLoadReadme = false

    init(repo: ShowcaseRepo,
         api: any GitHubAPI = GitHubService.shared,
         llm: any LLMClassifierProtocol = RuleLLMClassifier()) {
        self.repo = repo
        self.api = api
        self.llm = llm
    }

    func loadDetailIfNeeded() async {
        guard !didLoadDetail else { return }
        didLoadDetail = true
        isLoadingDetail = true
        defer { isLoadingDetail = false }

        let detailDTO = try? await api.repository(owner: repo.owner, name: repo.name)
        let languageDTO = try? await api.languages(owner: repo.owner, name: repo.name)

        if let dto = detailDTO {
            var mapped = ShowcaseRepo(dto: dto)
            mapped.isFeatured = repo.isFeatured
            repo = mapped
        }
        if let languages = languageDTO {
            self.languages = languages.percentages
                .map { LanguageSlice(name: $0.name, percent: $0.percent) }
        }

        await loadSimilar()
    }

    private func loadSimilar() async {
        guard let topic = repo.topics.first, !topic.isEmpty else { return }
        guard let page = try? await api.searchRepositories(
            query: "topic:\(topic) stars:>300",
            sort: .stars,
            page: 1,
            perPage: 12
        ) else { return }
        similar = page.items
            .map(ShowcaseRepo.init(dto:))
            .filter { $0.id != repo.id }
            .prefix(6)
            .map { $0 }
    }

    func loadReadmeIfNeeded(force: Bool = false) async {
        guard force || !didLoadReadme else { return }
        didLoadReadme = true
        isLoadingReadme = true
        errorMessage = nil
        defer { isLoadingReadme = false }

        do {
            let markdown = try await api.readme(owner: repo.owner, name: repo.name)
            guard !markdown.isEmpty else {
                readmeSummary = "这个仓库没有 README，建议直接打开仓库查看源码结构。"
                readmeSource = "本地规则"
                return
            }
            if llm.isConfigured,
               let dto = try? await api.repository(owner: repo.owner, name: repo.name),
               let insight = try? await llm.analyze(repo: dto) {
                readmeSummary = insight.chineseSummary
                readmeSource = "大模型"
            } else {
                readmeSummary = SummaryService.summarizeReadme(markdown)
                readmeSource = "本地规则"
            }
        } catch {
            if readmeSummary == nil {
                readmeSummary = "README 读取失败：\(error.localizedDescription)"
                readmeSource = "错误"
            }
        }
    }
}
