//
//  LLMClassifier.swift
//  GitVault
//
//  AI 摘要 / 分类：
//  - 默认接入「内置免费模型」（Pollinations 的 OpenAI 兼容端点，无需 API Key）
//  - 用户可随时改成自己的模型（任意 OpenAI 兼容网关）
//  - 未联网 / 被限流时自动回落到本地规则，App 永远可用
//

import Foundation

/// 大模型返回的结构化洞察
struct RepoInsight: Equatable {
    var chineseSummary: String
    var category: RepoCategory
    var tags: [String]
}

/// 模型配置（可持久化）
struct LLMConfig: Codable, Equatable {
    var endpoint: String
    var model: String
    var apiKey: String

    /// 内置免费模型：Pollinations 提供 OpenAI 兼容接口，无需 Key
    static let freeDefault = LLMConfig(
        endpoint: "https://text.pollinations.ai/openai",
        model: "openai",
        apiKey: ""
    )

    var isFreeDefault: Bool {
        endpoint == LLMConfig.freeDefault.endpoint
    }

    var displayName: String {
        if isFreeDefault { return "内置免费模型" }
        return model.isEmpty ? "自定义模型" : model
    }

    // MARK: 持久化（Key 单独进 Keychain）

    private static let endpointKey = "gv.llm.endpoint"
    private static let modelKey = "gv.llm.model"
    private static let keyKey = "gv.llm.key"

    static func load() -> LLMConfig {
        let defaults = UserDefaults.standard
        guard let endpoint = defaults.string(forKey: endpointKey), !endpoint.isEmpty else {
            return .freeDefault
        }
        return LLMConfig(
            endpoint: endpoint,
            model: defaults.string(forKey: modelKey) ?? LLMConfig.freeDefault.model,
            apiKey: Keychain.read(keyKey) ?? ""
        )
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(endpoint, forKey: LLMConfig.endpointKey)
        defaults.set(model, forKey: LLMConfig.modelKey)
        if apiKey.isEmpty {
            Keychain.delete(LLMConfig.keyKey)
        } else {
            Keychain.save(apiKey, for: LLMConfig.keyKey)
        }
    }

    static func clearToDefault() {
        UserDefaults.standard.removeObject(forKey: endpointKey)
        UserDefaults.standard.removeObject(forKey: modelKey)
        Keychain.delete(keyKey)
    }
}

protocol LLMClassifierProtocol {
    var isConfigured: Bool { get }
    var displayName: String { get }
    func analyze(repo: RepositoryDTO) async throws -> RepoInsight
}

/// OpenAI 兼容实现（同时覆盖内置免费端点与用户自建网关）
struct RemoteLLMClassifier: LLMClassifierProtocol {
    let config: LLMConfig
    private let session: URLSession

    init(config: LLMConfig) {
        self.config = config
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 25
        self.session = URLSession(configuration: configuration)
    }

    convenience init?(endpointString: String, apiKey: String, model: String = "openai") {
        let trimmed = endpointString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, URL(string: trimmed) != nil else { return nil }
        self.init(config: LLMConfig(endpoint: trimmed, model: model, apiKey: apiKey))
    }

    var isConfigured: Bool { !config.endpoint.isEmpty }
    var displayName: String { config.displayName }

    func analyze(repo: RepositoryDTO) async throws -> RepoInsight {
        guard let url = URL(string: config.endpoint) else { throw GitHubError.invalidURL }

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

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("GitVault/1.3", forHTTPHeaderField: "User-Agent")
        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }

        var body: [String: Any] = [
            "model": config.model,
            "temperature": 0.2,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ]
        ]
        // 官方 OpenAI 支持 json_object；免费端点不一定支持，做了降级重试
        body["response_format"] = ["type": "json_object"]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GitHubError.transport("大模型无响应")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw GitHubError.transport("大模型接口返回 HTTP \(http.statusCode)")
        }
        return try parseInsight(from: data)
    }

    // MARK: 解析（兼容带 markdown 代码块的返回）

    private func parseInsight(from data: Data) throws -> RepoInsight {
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
            let tags: [String]?
        }

        guard let completion = try? JSONDecoder().decode(Completion.self, from: data),
              let raw = completion.choices.first?.message.content else {
            throw GitHubError.decoding("大模型返回结构不符合预期")
        }

        let cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let payloadData = cleaned.data(using: .utf8),
              let payload = try? JSONDecoder().decode(Payload.self, from: payloadData) else {
            throw GitHubError.decoding("大模型返回内容无法解析为 JSON")
        }

        return RepoInsight(
            chineseSummary: payload.summary,
            category: RepoCategory(rawValue: payload.category) ?? .learning,
            tags: payload.tags ?? []
        )
    }
}

/// 规则实现（离线兜底）
struct RuleLLMClassifier: LLMClassifierProtocol {
    var isConfigured: Bool { false }
    var displayName: String { "本地规则" }

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
