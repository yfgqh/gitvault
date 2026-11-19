//
//  AppEnvironment.swift
//  GitVault
//
//  依赖注入容器（iOS 16 兼容：ObservableObject 而非 @Observable）。
//

import Foundation
import SwiftUI

@MainActor
final class AppEnvironment: ObservableObject {
    let api: any GitHubAPI
    let auth: AuthStore

    @Published var llm: any LLMClassifierProtocol
    @Published var toast: ToastMessage?

    init(api: any GitHubAPI, auth: AuthStore, llm: any LLMClassifierProtocol) {
        self.api = api
        self.auth = auth
        self.llm = llm
    }

    /// 生产环境默认装配（在 MainActor 上下文调用）
    static func live() -> AppEnvironment {
        AppEnvironment(api: GitHubService.shared, auth: AuthStore(), llm: RuleLLMClassifier())
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
