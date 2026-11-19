//
//  LLMClassifier.swift
//  GitVault
//
//  「大模型分类接口」抽象层。
//  - LLMClassifierProtocol：任何实现（远端 / 本地模型）都能即插即用
//  - RemoteLLMClassifier：OpenAI 兼容 /v1/chat/completions 的具体实现
//  - 未配置时由 RuleClassifier 兜底，App 永远可用
//

import Foundation

/// 大模型返回的结构化洞察
struct RepoInsight: Equatable {
    var chineseSummary: String
    var category: RepoCategory
    var tags: [String]
}

protocol LLMClassifierProtocol {
    var isConfigured: Bool { get }
    /// 生成中文摘要 + 主题分类 + 标签
    func analyze(repo: RepositoryDTO) async throws -> RepoInsight
}

/// OpenAI 兼容协议的远端实现（可指向任意自建网关）
struct RemoteLLMClassifier: LLMClassifierProtocol {
    let endpoint: URL
    let apiKey: String
    let model: String
    private let session: URLSession

    init?(endpointString: String, apiKey: String, model: String = "gpt-4o-mini") {
        guard let url = URL(string: endpointString), !apiKey.isEmpty else { return nil }
        self.endpoint = url
        self.apiKey = apiKey
        self.model = model
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25
        self.session = URLSession(configuration: config)
    }

    var isConfigured: Bool { !apiKey.isEmpty }

    func analyze(repo: RepositoryDTO) async throws -> RepoInsight {
        let system = """
        你是中文开源项目编辑。阅读仓库信息，输出严格 JSON：
        {"summary":"不超过40字的中文一句话介绍","category":"ai|tooling|frontend|backend|mobile|learning","tags":["中文标签1","中文标签2"]}
        只输出 JSON，不要任何解释。
        """
        let user = """
        仓库：\(repo.fullName)
        描述：\(repo.description ?? "无")
        主语言：\(repo.language ?? "未知")
        topics：\((repo.topics ?? []).joined(separator: ", "))
        星标：\(repo.stargazersCount)
        """

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model,
            "temperature": 0.2,
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GitHubError.transport("大模型接口返回异常")
        }

        struct Completion: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }
        struct Payload: Decodable {
            let summary: String
            let category: String
            let tags: [String]
        }

        let completion = try JSONDecoder().decode(Completion.self, from: data)
        guard let content = completion.choices.first?.message.content,
              let payloadData = content.data(using: .utf8) else {
            throw GitHubError.decoding("大模型返回为空")
        }
        let payload = try JSONDecoder().decode(Payload.self, from: payloadData)

        return RepoInsight(
            chineseSummary: payload.summary,
            category: RepoCategory(rawValue: payload.category) ?? .learning,
            tags: payload.tags
        )
    }
}

/// 规则实现（离线兜底），满足同一协议
struct RuleLLMClassifier: LLMClassifierProtocol {
    var isConfigured: Bool { false }

    func analyze(repo: RepositoryDTO) async throws -> RepoInsight {
        let category = RepoCategory.infer(
            fromTopics: repo.topics ?? [],
            description: repo.description,
            language: repo.language
        )
        return RepoInsight(
            chineseSummary: SummaryService.chineseSummary(for: repo, category: category),
            category: category,
            tags: SummaryService.chineseTopics(repo.topics ?? [], limit: 3)
                .split(separator: "、").map(String.init)
        )
    }
}
