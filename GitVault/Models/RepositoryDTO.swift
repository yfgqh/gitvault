//
//  RepositoryDTO.swift
//  GitVault
//
//  GitHub REST API v3 的原始响应模型（只取用到的字段）。
//  原则：网络层只产出 DTO，UI 模型在 MainActor 上映射，避免把 Color 等 UI 类型带进网络层。
//

import Foundation

/// search/repositories 的单条仓库
struct RepositoryDTO: Decodable, Sendable, Identifiable {
    let id: Int
    let name: String
    let fullName: String
    let owner: Owner
    let description: String?
    let language: String?
    let stargazersCount: Int
    let forksCount: Int
    let openIssuesCount: Int
    let topics: [String]?
    let license: License?
    let htmlURL: String
    let homepage: String?
    let createdAt: Date?
    let updatedAt: Date?
    let pushedAt: Date?
    let defaultBranch: String?

    struct Owner: Decodable, Sendable {
        let login: String
        let avatarURL: String?

        private enum CodingKeys: String, CodingKey {
            case login
            case avatarURL = "avatar_url"
        }
    }

    struct License: Decodable, Sendable {
        let spdxID: String?

        private enum CodingKeys: String, CodingKey {
            case spdxID = "spdx_id"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, owner, description, language, topics, license, homepage
        case fullName = "full_name"
        case stargazersCount = "stargazers_count"
        case forksCount = "forks_count"
        case openIssuesCount = "open_issues_count"
        case htmlURL = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case pushedAt = "pushed_at"
        case defaultBranch = "default_branch"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        fullName = try c.decode(String.self, forKey: .fullName)
        owner = try c.decode(Owner.self, forKey: .owner)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        language = try c.decodeIfPresent(String.self, forKey: .language)
        stargazersCount = try c.decodeIfPresent(Int.self, forKey: .stargazersCount) ?? 0
        forksCount = try c.decodeIfPresent(Int.self, forKey: .forksCount) ?? 0
        openIssuesCount = try c.decodeIfPresent(Int.self, forKey: .openIssuesCount) ?? 0
        topics = try c.decodeIfPresent([String].self, forKey: .topics)
        license = try c.decodeIfPresent(License.self, forKey: .license)
        htmlURL = try c.decodeIfPresent(String.self, forKey: .htmlURL) ?? ""
        homepage = try c.decodeIfPresent(String.self, forKey: .homepage)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
        pushedAt = try c.decodeIfPresent(Date.self, forKey: .pushedAt)
        defaultBranch = try c.decodeIfPresent(String.self, forKey: .defaultBranch)
    }
}

/// search/repositories 的整页响应
struct RepositorySearchPage: Decodable, Sendable {
    let totalCount: Int
    let incompleteResults: Bool
    let items: [RepositoryDTO]

    private enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case incompleteResults = "incomplete_results"
        case items
    }
}

/// /repos/{owner}/{repo}/languages 的响应：{"Swift": 12345, "C": 678}
/// 说明：内部用元组数组保存观测顺序，故不标 Sendable（仅在 MainActor 上消费）。
struct RepositoryLanguages: Decodable {
    let values: [(name: String, bytes: Int)]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode([String: Int].self)
        values = raw.map { (name: $0.key, bytes: $0.value) }
            .sorted { $0.bytes > $1.bytes }
    }

    /// 转成百分比（保留一位小数）
    var percentages: [(name: String, percent: Double)] {
        let total = values.reduce(0) { $0 + $1.bytes }
        guard total > 0 else { return [] }
        return values.map { ($0.name, Double($0.bytes) / Double(total) * 100) }
    }
}

/// /repos/{owner}/{repo}/readme 的响应（base64 内容）
struct ReadmeDTO: Decodable, Sendable {
    let content: String
    let encoding: String

    var decoded: String? {
        guard encoding == "base64" else { return nil }
        let cleaned = content.replacingOccurrences(of: "\n", with: "")
        guard let data = Data(base64Encoded: cleaned) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

/// /user 的响应
struct GitHubUserDTO: Decodable, Sendable {
    let login: String
    let name: String?
    let avatarURL: String?
    let publicRepos: Int
    let followers: Int
    let htmlURL: String

    private enum CodingKeys: String, CodingKey {
        case login, name, followers
        case avatarURL = "avatar_url"
        case publicRepos = "public_repos"
        case htmlURL = "html_url"
    }
}

/// Device Flow 第一步响应
struct DeviceCodeResponse: Decodable, Sendable {
    let deviceCode: String
    let userCode: String
    let verificationURI: String
    let expiresIn: Int
    let interval: Int

    private enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationURI = "verification_uri"
        case expiresIn = "expires_in"
        case interval
    }
}

/// Device Flow 轮询响应（成功与失败共用一个结构）
struct AccessTokenResponse: Decodable, Sendable {
    let accessToken: String?
    let tokenType: String?
    let scope: String?
    let error: String?
    let errorDescription: String?

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope, error
        case errorDescription = "error_description"
    }
}
