//
//  DetailViewModel.swift
//  GitVault
//
//  详情页编排：
//  - 详情/语言/相似项目并发拉取，避免串行等待造成「像卡住」
//  - README：先展示原文摘录；原文不是中文时再交给 AI 翻译
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
    @Published var similar: [ShowcaseRepo] = []

    /// README 完整原文（Markdown，用于全文渲染）
    @Published var readmeMarkdown: String?
    /// README 原文摘录（默认展示内容）
    @Published var readmeOriginal: String?
    /// AI 翻译后的中文（原文非中文且翻译成功时才有）
    @Published var readmeTranslated: String?
    @Published var readmeSource: String = "原文"
    @Published var isLoadingReadme = false
    /// README 首图 / 演示站点预览
    @Published var previewImageURL: URL?
    @Published var isTranslating = false

    @Published var isLoadingDetail = false
    @Published var errorMessage: String?
    @Published var isSaved = false
    @Published var mark: MyMark?

    var llm: any LLMClassifierProtocol

    private let api: any GitHubAPI
    private var didLoadDetail = false
    private var didLoadReadme = false

    init(repo: ShowcaseRepo,
         api: any GitHubAPI = GitHubService.shared,
         llm: any LLMClassifierProtocol = RuleLLMClassifier()) {
        self.repo = repo
        self.api = api
        self.llm = llm
    }

    // MARK: 展示内容

    /// 卡片里显示的文字：有译文显示译文，否则显示原文
    var readmeDisplayText: String {
        if let translated = readmeTranslated, !translated.isEmpty { return translated }
        if let original = readmeOriginal, !original.isEmpty { return original }
        return "正在读取 README…"
    }

    var showingTranslation: Bool {
        readmeTranslated?.isEmpty == false
    }

    var readmeHint: String {
        if isTranslating { return "原文为英文，正在用 AI 翻译…" }
        if showingTranslation { return "已由 \(llm.displayName) 译为中文" }
        if isLoadingReadme { return "正在读取 README 原文…" }
        return "README 原文摘录"
    }

    // MARK: 详情

    func loadDetailIfNeeded() async {
        guard !didLoadDetail else { return }
        didLoadDetail = true
        isLoadingDetail = true
        defer { isLoadingDetail = false }

        // 三个请求并发，最坏等待时间从 3×12s 降到 1×12s
        async let detailCall = api.repository(owner: repo.owner, name: repo.name)
        async let languageCall = api.languages(owner: repo.owner, name: repo.name)

        let detailDTO = try? await detailCall
        let languageDTO = try? await languageCall

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
        // topic 优先；没有 topic 时退化为语言检索，避免整块空白
        var query: String?
        if let topic = repo.topics.first, !topic.isEmpty {
            query = "topic:\(topic) stars:>300"
        } else if !repo.language.isEmpty, repo.language != "未知" {
            query = "language:\"\(repo.language)\" stars:>1000"
        }
        guard let query else { return }
        guard let page = try? await api.searchRepositories(
            query: query,
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

    // MARK: README（原文优先，非中文再翻译）

    func loadReadmeIfNeeded(force: Bool = false) async {
        guard force || !didLoadReadme else { return }
        didLoadReadme = true
        errorMessage = nil

        // 先用仓库描述兜底，保证卡片一出现就有内容，不留白屏
        if readmeOriginal?.isEmpty ?? true {
            readmeOriginal = repo.rawDescription ?? repo.summary
            readmeSource = "原文"
        }

        isLoadingReadme = true
        defer { isLoadingReadme = false }

        let markdown: String
        do {
            markdown = try await api.readme(owner: repo.owner, name: repo.name)
        } catch {
            readmeSource = "原文"
            return
        }

        readmeMarkdown = markdown
        previewImageURL = SummaryService.firstImageURL(in: markdown)
        let excerpt = SummaryService.readmeExcerpt(markdown, maxChars: 2000)
        guard !excerpt.isEmpty else {
            readmeOriginal = repo.rawDescription ?? repo.summary
            return
        }

        readmeOriginal = excerpt
        readmeSource = "原文"

        // 已是中文就不翻译
        guard !SummaryService.isMostlyChinese(excerpt) else {
            readmeSource = "原文（中文）"
            return
        }
        guard llm.isConfigured else { return }

        isTranslating = true
        defer { isTranslating = false }
        if let translated = try? await llm.translate(excerpt), !translated.isEmpty {
            readmeTranslated = translated
            readmeSource = "AI 翻译"
        }
    }
}
