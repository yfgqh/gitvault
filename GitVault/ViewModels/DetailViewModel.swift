//
//  DetailViewModel.swift
//  GitVault
//
//  详情页编排：仓库详情、语言占比、README 摘要、收藏状态。
//

import Foundation
import Observation

struct LanguageSlice: Identifiable, Equatable {
    let name: String
    let percent: Double
    var id: String { name }
}

@Observable
@MainActor
final class DetailViewModel {
    var repo: ShowcaseRepo
    var languages: [LanguageSlice] = []
    var readmeSummary: String?
    var readmeSource: String = "本地规则"
    var isLoadingDetail = false
    var isLoadingReadme = false
    var errorMessage: String?
    var isSaved = false
    var mark: MyMark?
    /// 相似项目：同 topic 的高星仓库
    var similar: [ShowcaseRepo] = []

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

    /// 用最新数据刷新头部与语言占比
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

    /// 相似项目：拿首个 topic 去搜索，排除自己
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

    /// README 中文摘要：优先大模型，未配置则本地规则
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
