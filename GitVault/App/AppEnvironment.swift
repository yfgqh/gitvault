//
//  AppEnvironment.swift
//  GitVault
//
//  依赖注入容器：视图通过 @Environment(AppEnvironment.self) 取服务，
//  所有网络 / 鉴权 / 大模型能力都在这里可替换（测试替身、Mock、远端）。
//

import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class AppEnvironment {
    let api: any GitHubAPI
    let auth: AuthStore
    var llm: any LLMClassifierProtocol

    /// 轻提示（保存成功、导出完成、错误）
    var toast: ToastMessage?

    init(api: any GitHubAPI = GitHubService.shared,
         auth: AuthStore = AuthStore(),
         llm: any LLMClassifierProtocol = RuleLLMClassifier()) {
        self.api = api
        self.auth = auth
        self.llm = llm
    }

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

    /// 切换大模型实现：配置了就远端，否则回落规则
    func configureLLM(endpoint: String, apiKey: String, model: String) {
        if let remote = RemoteLLMClassifier(endpointString: endpoint, apiKey: apiKey, model: model) {
            llm = remote
        } else {
            llm = RuleLLMClassifier()
        }
    }
}

struct ToastMessage: Identifiable, Equatable {
    enum Kind { case info, success, warning }
    let id = UUID()
    let text: String
    let kind: Kind
}
