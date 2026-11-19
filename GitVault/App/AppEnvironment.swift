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

    init(api: any GitHubAPI,
         auth: AuthStore,
         config: LLMConfig,
         llm: any LLMClassifierProtocol) {
        self.api = api
        self.auth = auth
        self.config = config
        self.llm = llm
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
