//
//  AppEnvironment.swift
//  GitVault
//
//  依赖注入容器 + AI 配置中心。
//  默认接入「内置免费模型」（无需 API Key），用户可改成自己的 OpenAI 兼容网关。
//

import Foundation
import SwiftUI

@MainActor
final class AppEnvironment: ObservableObject {
    let api: any GitHubAPI
    let auth: AuthStore

    @Published var config: LLMConfig
    @Published var llm: any LLMClassifierProtocol
    @Published var toast: ToastMessage?

    /// 详情页可见时隐藏悬浮 Tab Bar（避免盖住底部操作栏）
    @Published var isShowingDetail = false

    /// Pro 解锁（StoreKit 2）
    let pro: ProStore
    /// 在线更新检查
    @Published var update: UpdateChecker
    /// 全量仓库库（分桶抓取）
    let allRepos = AllReposStore()

    /// 各分类的真实项目总数（GitHub total_count），带本地缓存
    @Published private(set) var categoryCounts: [RepoCategory: Int] = [:]
    private var countsLoadedAt: Date?

    init(api: any GitHubAPI,
         auth: AuthStore,
         config: LLMConfig,
         llm: any LLMClassifierProtocol,
         pro: ProStore? = nil,
         update: UpdateChecker? = nil) {
        self.api = api
        self.auth = auth
        self.config = config
        self.llm = llm
        self.pro = pro ?? ProStore()
        self.update = update ?? UpdateChecker()
        loadCachedCounts()
    }

    // MARK: 分类统计

    private static let countsKey = "gv.category.counts.v1"
    private static let countsTimeKey = "gv.category.counts.at.v1"
    private let countsTTL: TimeInterval = 6 * 3600

    func categoryCount(_ category: RepoCategory) -> Int {
        categoryCounts[category] ?? 0
    }

    /// 拉取 6 个分类的真实总数；6 小时内复用缓存，避免浪费额度
    func refreshCategoryCounts(force: Bool = false) async {
        if !force,
           let at = countsLoadedAt,
           Date().timeIntervalSince(at) < countsTTL,
           !categoryCounts.isEmpty {
            return
        }

        var result: [RepoCategory: Int] = [:]
        for category in RepoCategory.allCases {
            if let count = try? await api.categoryTotal(category), count > 0 {
                result[category] = count
            }
        }
        guard !result.isEmpty else {
            // 全部失败（限流/断网）：保留已有缓存值，绝不覆盖成 0
            CrashReporter.log("counts: refresh failed, keep cached values")
            return
        }
        // 未取到的分类沿用旧值或基线
        for category in RepoCategory.allCases where result[category] == nil {
            result[category] = categoryCounts[category] ?? category.baselineCount
        }
        categoryCounts = result
        countsLoadedAt = .now
        persistCounts(result)
    }

    private func loadCachedCounts() {
        let defaults = UserDefaults.standard
        guard let raw = defaults.dictionary(forKey: AppEnvironment.countsKey) as? [String: Int] else { return }
        var parsed: [RepoCategory: Int] = [:]
        for (key, value) in raw {
            if let category = RepoCategory(rawValue: key) {
                parsed[category] = value
            }
        }
        categoryCounts = parsed
        let stamp = defaults.double(forKey: AppEnvironment.countsTimeKey)
        if stamp > 0 {
            countsLoadedAt = Date(timeIntervalSince1970: stamp)
        }
        fillMissingWithBaseline(parsed)
    }

    /// 缺值用基线补齐：首启 / 限流时也不会显示 0
    private func fillMissingWithBaseline(_ current: [RepoCategory: Int]) {
        var merged = current
        for category in RepoCategory.allCases where (merged[category] ?? 0) <= 0 {
            merged[category] = category.baselineCount
        }
        categoryCounts = merged
    }

    private func persistCounts(_ counts: [RepoCategory: Int]) {
        var raw: [String: Int] = [:]
        for (category, value) in counts { raw[category.rawValue] = value }
        let defaults = UserDefaults.standard
        defaults.set(raw, forKey: AppEnvironment.countsKey)
        defaults.set(Date().timeIntervalSince1970, forKey: AppEnvironment.countsTimeKey)
    }

    /// 生产环境默认装配：模型配置读本地，缺省即内置免费模型
    static func live() -> AppEnvironment {
        let config = LLMConfig.load()
        return AppEnvironment(
            api: GitHubService.shared,
            auth: AuthStore(),
            config: config,
            llm: RemoteLLMClassifier(config: config)
        )
    }

    // MARK: AI 设置

    /// 保存并立即生效
    func applyLLM(_ config: LLMConfig) {
        config.save()
        self.config = config
        self.llm = RemoteLLMClassifier(config: config)
    }

    /// 恢复内置免费模型
    func resetLLMToFreeDefault() {
        LLMConfig.clearToDefault()
        let config = LLMConfig.freeDefault
        self.config = config
        self.llm = RemoteLLMClassifier(config: config)
    }

    var llmModeTitle: String {
        if config.isFreeDefault { return "内置免费模型" }
        return config.model.isEmpty ? "自定义模型" : config.model
    }

    // MARK: 轻提示

    func show(_ text: String, kind: ToastMessage.Kind = .info) {
        withAnimation(DS.Motion.snappy) {
            toast = ToastMessage(text: text, kind: kind)
        }
        let current = toast
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if toast?.id == current?.id {
                withAnimation(DS.Motion.fade) { toast = nil }
            }
        }
    }
}

struct ToastMessage: Identifiable, Equatable {
    enum Kind { case info, success, warning }
    let id = UUID()
    let text: String
    let kind: Kind
}
