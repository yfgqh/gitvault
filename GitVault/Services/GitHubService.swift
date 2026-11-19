//
//  GitHubService.swift
//  GitVault
//
//  GitHub REST API v3 封装：
//  - async/await + URLSession
//  - 统一错误映射（GitHubError，中文提示）
//  - 幂等请求自动重试（网络抖动 / 5xx），指数退避
//  - 自动附带 Keychain 中的 Token（有则 5000 次/小时，无则 60 次/小时）
//

import Foundation

enum SearchSort: String {
    case stars, forks, updated
}

protocol GitHubAPI {
    func searchRepositories(query: String,
                            sort: SearchSort,
                            page: Int,
                            perPage: Int) async throws -> RepositorySearchPage
    func trending(days: Int) async throws -> [RepositoryDTO]
    func repository(owner: String, name: String) async throws -> RepositoryDTO
    func languages(owner: String, name: String) async throws -> RepositoryLanguages
    func readme(owner: String, name: String) async throws -> String
    func currentUser() async throws -> GitHubUserDTO
    func searchByCategory(_ category: RepoCategory, page: Int) async throws -> RepositorySearchPage
}

struct GitHubService: GitHubAPI {
    static let shared = GitHubService()

    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 12
            config.timeoutIntervalForResource = 25
            config.urlCache = URLCache.shared
            config.requestCachePolicy = .useProtocolCachePolicy
            config.httpAdditionalHeaders = ["Accept-Language": "zh-CN"]
            self.session = URLSession(configuration: config)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    // MARK: - 搜索

    func searchRepositories(query: String,
                            sort: SearchSort = .stars,
                            page: Int = 1,
                            perPage: Int = AppConfig.perPage) async throws -> RepositorySearchPage {
        let items = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "sort", value: sort.rawValue),
            URLQueryItem(name: "order", value: "desc"),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "per_page", value: "\(perPage)")
        ]
        return try await request(path: "/search/repositories", query: items, as: RepositorySearchPage.self)
    }

    /// 按主题抓取（分类页 / 推荐用）
    func searchByCategory(_ category: RepoCategory, page: Int = 1) async throws -> RepositorySearchPage {
        // 用该主题最相关的 4 个关键词做 OR，再按 star 排序
        let keys = Array(category.keywords.prefix(4))
        let topicQuery = keys.map { "topic:\($0.replacingOccurrences(of: " ", with: "-"))" }
            .joined(separator: " ")
        let query = "\(topicQuery) stars:>200"
        return try await searchRepositories(query: query, sort: .stars, page: page)
    }

    /// 「飙升榜」：GitHub 没有官方 trending 接口，
    /// 这里用「近 N 天有推送 + 星标门槛」近似，指数是公开可解释的。
    func trending(days: Int = 14) async throws -> [RepositoryDTO] {
        let since = DateFormatter.githubDay.string(from: Date().addingTimeInterval(-Double(days) * 86_400))
        let query = "stars:>800 pushed:>\(since)"
        let page = try await searchRepositories(query: query, sort: .stars, page: 1, perPage: 25)
        return page.items
    }

    // MARK: - 详情

    func repository(owner: String, name: String) async throws -> RepositoryDTO {
        try await request(path: "/repos/\(owner)/\(name)", query: [], as: RepositoryDTO.self)
    }

    func languages(owner: String, name: String) async throws -> RepositoryLanguages {
        try await request(path: "/repos/\(owner)/\(name)/languages", query: [], as: RepositoryLanguages.self)
    }

    func readme(owner: String, name: String) async throws -> String {
        let dto: ReadmeDTO = try await request(
            path: "/repos/\(owner)/\(name)/readme",
            query: [],
            as: ReadmeDTO.self
        )
        return dto.decoded ?? ""
    }

    func currentUser() async throws -> GitHubUserDTO {
        try await request(path: "/user", query: [], as: GitHubUserDTO.self)
    }

    // MARK: - 基础设施

    private func request<T: Decodable>(path: String,
                                       query: [URLQueryItem],
                                       as type: T.Type,
                                       retries: Int = 1) async throws -> T {
        guard let url = URL(string: AppConfig.apiBase.absoluteString + path) else {
            throw GitHubError.invalidURL
        }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw GitHubError.invalidURL
        }
        if !query.isEmpty { components.queryItems = query }
        guard let finalURL = components.url else { throw GitHubError.invalidURL }

        var request = URLRequest(url: finalURL)
        request.httpMethod = "GET"
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("GitVault/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue(AppConfig.apiVersion, forHTTPHeaderField: "X-GitHub-Api-Version")
        if let token = Keychain.read(Keychain.tokenKey), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var attempt = 0
        // 最多两次尝试（首次 + 1 次重试），避免网络异常时长时间转圈
        while true {
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw GitHubError.transport("无效的响应")
                }
                guard (200..<300).contains(http.statusCode) else {
                    let resetAt = http.value(forHTTPHeaderField: "x-ratelimit-reset")
                        .flatMap(Double.init)
                        .map { Date(timeIntervalSince1970: $0) }
                    let remaining = http.value(forHTTPHeaderField: "x-ratelimit-remaining")
                    let error: GitHubError = http.statusCode == 403 && remaining == "0"
                        ? .rateLimited(resetAt: resetAt)
                        : .from(statusCode: http.statusCode, resetAt: resetAt)
                    throw error
                }
                do {
                    return try decoder.decode(T.self, from: data)
                } catch {
                    throw GitHubError.decoding(String(describing: error))
                }
            } catch let error as GitHubError {
                if error.isRetryable && attempt < retries {
                    attempt += 1
                    try? await Task.sleep(nanoseconds: UInt64(400_000_000 * attempt))
                    continue
                }
                throw error
            } catch let urlError as URLError {
                let mapped: GitHubError
                switch urlError.code {
                case .notConnectedToInternet, .networkConnectionLost: mapped = .offline
                case .timedOut: mapped = .timeout
                case .cancelled: mapped = .transport("请求已取消")
                default: mapped = .transport(urlError.localizedDescription)
                }
                if mapped.isRetryable && attempt < retries {
                    attempt += 1
                    try? await Task.sleep(nanoseconds: UInt64(400_000_000 * attempt))
                    continue
                }
                throw mapped
            }
        }
    }
}

extension DateFormatter {
    /// GitHub 搜索语法需要 YYYY-MM-DD
    static let githubDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()
}
