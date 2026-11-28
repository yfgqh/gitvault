//
//  LLMClassifier.swift
//  GitVault
//
//  AI 能力：
//  - 默认内置免费模型（Pollinations，OpenAI 兼容，无需 Key）
//  - 支持用户自定义任意 OpenAI 兼容网关
//  - 提供「分类 + 中文摘要」与「README 翻译」两个能力
//  - 失败一律静默回落本地规则，绝不阻塞 UI
//

import Foundation

struct RepoInsight: Equatable {
    var chineseSummary: String
    var category: RepoCategory
    var tags: [String]
}

// MARK: - 配置

struct LLMConfig: Codable, Equatable {
    var endpoint: String
    var model: String
    var apiKey: String

    /// 内置免费端点：Pollinations 的 OpenAI 兼容接口
    static let freeDefault = LLMConfig(
        endpoint: "https://text.pollinations.ai/openai",
        model: "openai",
        apiKey: ""
    )

    /// 备用免费端点（主端点被限流时轮换）
    static let freeFallbacks: [LLMConfig] = [
        LLMConfig(endpoint: "https://text.pollinations.ai/openai", model: "openai", apiKey: ""),
        LLMConfig(endpoint: "https://text.pollinations.ai/openai", model: "openai-large", apiKey: "")
    ]

    var isFreeDefault: Bool {
        endpoint == LLMConfig.freeDefault.endpoint
    }

    var displayName: String {
        if isFreeDefault { return "内置免费模型" }
        return model.isEmpty ? "自定义模型" : model
    }

    // MARK: 持久化

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

// MARK: - 协议

protocol LLMClassifierProtocol {
    var isConfigured: Bool { get }
    var displayName: String { get }
    func analyze(repo: RepositoryDTO) async throws -> RepoInsight
    /// 把英文 README 片段翻译成简体中文
    func translate(_ text: String) async throws -> String
}

// MARK: - OpenAI 兼容实现

struct RemoteLLMClassifier: LLMClassifierProtocol {
    let config: LLMConfig
    private let session: URLSession

    init(config: LLMConfig) {
        self.config = config
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 18
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: configuration)
    }

    init?(endpointString: String, apiKey: String, model: String = "openai") {
        let trimmed = endpointString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, URL(string: trimmed) != nil else { return nil }
        self.init(config: LLMConfig(endpoint: trimmed, model: model, apiKey: apiKey))
    }

    var isConfigured: Bool { !config.endpoint.isEmpty }
    var displayName: String { config.displayName }

    // MARK: 分类 + 摘要

    func analyze(repo: RepositoryDTO) async throws -> RepoInsight {
        let system = """
        你是中文开源编辑。只输出 JSON：
        {"summary":"40字内中文一句话","category":"ai|tooling|frontend|backend|mobile|learning","tags":["中文标签"]}
        """
        let user = """
        仓库：\(repo.fullName)
        描述：\(repo.description ?? "无")
        语言：\(repo.language ?? "未知")
        topics：\((repo.topics ?? []).joined(separator: ","))
        星标：\(repo.stargazersCount)
        """

        let content = try await chat(system: system, user: user, maxTokens: 300, temperature: 0.2)
        guard let payload = decodeJSONObject(from: content, as: InsightPayload.self) else {
            throw GitHubError.decoding("分类结果不是合法 JSON")
        }
        return RepoInsight(
            chineseSummary: payload.summary,
            category: RepoCategory(rawValue: payload.category) ?? .learning,
            tags: payload.tags ?? []
        )
    }

    // MARK: 翻译

    func translate(_ text: String) async throws -> String {
        let system = """
        你是资深技术译者。把用户给出的 README 片段翻译成简体中文：
        1) 保留代码、命令、URL、包名原样；
        2) 术语用国内开发者习惯说法；
        3) 只输出译文正文，不要加任何解释、标题或引号。
        """

        // 分段翻译：单段不超过 900 字，避免模型截断或输出长度不足
        let chunks = Self.chunk(text, limit: 900)
        var outputs: [String] = []
        var lastError: Error?

        for chunk in chunks {
            do {
                let content = try await chat(system: system, user: chunk, maxTokens: 900, temperature: 0.1)
                let cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty {
                    outputs.append(cleaned)
                }
            } catch {
                // 单段失败不影响其它段落：保留原文片段，继续翻下一段
                lastError = error
                outputs.append(chunk)
            }
        }

        guard !outputs.isEmpty else {
            throw lastError ?? GitHubError.decoding("翻译结果为空")
        }
        return outputs.joined(separator: "\n\n")
    }

    /// 按段落/句子边界切块，尽量不把一句话切断
    private static func chunk(_ text: String, limit: Int) -> [String] {
        guard text.count > limit else { return [text] }
        var chunks: [String] = []
        var current = ""

        let pieces = text.components(separatedBy: "\n")
        for piece in pieces {
            let line = piece.trimmingCharacters(in: .whitespaces)
            if current.count + line.count + 1 > limit, !current.isEmpty {
                chunks.append(current)
                current = line
            } else {
                current = current.isEmpty ? line : current + "\n" + line
            }
            // 单行本身就超长时，按字符硬切
            while current.count > limit {
                let end = current.index(current.startIndex, offsetBy: limit)
                chunks.append(String(current[..<end]))
                current = String(current[end...])
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks.isEmpty ? [text] : chunks
    }

    // MARK: 请求

    private struct InsightPayload: Decodable {
        let summary: String
        let category: String
        let tags: [String]?
    }

    private func chat(system: String, user: String, maxTokens: Int, temperature: Double) async throws -> String {
        guard let url = URL(string: config.endpoint) else { throw GitHubError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("GitVault/1.4", forHTTPHeaderField: "User-Agent")
        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }

        // 不吃 response_format：免费端点多不支持，带上会直接 400。
        let body: [String: Any] = [
            "model": config.model,
            "temperature": temperature,
            "max_tokens": maxTokens,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        var lastError: Error = GitHubError.transport("大模型无响应")
        for attempt in 0..<2 {
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw GitHubError.transport("大模型无响应")
                }
                if (200..<300).contains(http.statusCode) {
                    return try parseCompletion(data)
                }
                // 429 / 5xx 值得再试一次
                if http.statusCode == 429 || http.statusCode >= 500 {
                    lastError = GitHubError.transport("大模型限流 HTTP \(http.statusCode)")
                    if attempt == 0 {
                        try? await Task.sleep(nanoseconds: 800_000_000)
                        continue
                    }
                }
                throw GitHubError.transport("大模型接口 HTTP \(http.statusCode)")
            } catch {
                lastError = error
                if attempt == 0 {
                    try? await Task.sleep(nanoseconds: 600_000_000)
                    continue
                }
            }
        }
        throw lastError
    }

    private func parseCompletion(_ data: Data) throws -> String {
        struct Completion: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String? }
                let message: Message
                let text: String?
            }
            let choices: [Choice]?
        }
        if let completion = try? JSONDecoder().decode(Completion.self, from: data),
           let first = completion.choices?.first,
           let content = first.message.content ?? first.text,
           !content.isEmpty {
            return content
        }
        // 兼容直接返回纯文本的端点
        if let plain = String(data: data, encoding: .utf8), !plain.isEmpty, !plain.hasPrefix("{") {
            return plain
        }
        throw GitHubError.decoding("大模型返回结构不符合预期")
    }

    /// 从可能带 markdown 代码块 / 前后缀说明的文本里抠出 JSON 对象
    private func decodeJSONObject<T: Decodable>(from text: String, as type: T.Type) -> T? {
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let decoder = JSONDecoder()
        if let data = cleaned.data(using: .utf8), let value = try? decoder.decode(T.self, from: data) {
            return value
        }
        // 截取第一个 { 到最后一个 }
        guard let start = cleaned.firstIndex(of: "{"),
              let end = cleaned.lastIndex(of: "}"),
              start < end else { return nil }
        let slice = String(cleaned[start...end])
        guard let data = slice.data(using: .utf8) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }
}

// MARK: - 本地规则实现（离线兜底）

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

    func translate(_ text: String) async throws -> String {
        throw GitHubError.transport("未配置大模型，无法翻译")
    }
}
