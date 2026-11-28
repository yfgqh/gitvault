//
//  GitHubExtrasService.swift
//  GitVault
//
//  补充能力（不挤进 GitHubAPI 主协议，避免影响既有调用）：
//  - 写操作：星标 / 取消星标 / Fork
//  - 代码结构：git/trees + raw 文件内容（raw 不计入 API 额度）
//  - 我的仓库
//  - Releases（在线更新）
//  - zipball 下载地址
//

import Foundation

struct GitHubExtrasService {
    static let shared = GitHubExtrasService()

    private let session: URLSession
    private let decoder: JSONDecoder

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    // MARK: 基础请求

    private func send<T: Decodable>(_ method: String,
                                    path: String,
                                    query: [URLQueryItem] = [],
                                    body: [String: Any]? = nil,
                                    as type: T.Type) async throws -> T {
        let data = try await sendRaw(method, path: path, query: query, body: body)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw GitHubError.decoding("响应解析失败")
        }
    }

    @discardableResult
    private func sendRaw(_ method: String,
                         path: String,
                         query: [URLQueryItem] = [],
                         body: [String: Any]? = nil) async throws -> Data {
        guard var components = URLComponents(string: AppConfig.apiBase.absoluteString + path) else {
            throw GitHubError.invalidURL
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw GitHubError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("GitVault/2.1", forHTTPHeaderField: "User-Agent")
        request.setValue(AppConfig.apiVersion, forHTTPHeaderField: "X-GitHub-Api-Version")
        if let token = Keychain.read(Keychain.tokenKey), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw GitHubError.transport("无效响应")
            }
            guard (200..<300).contains(http.statusCode) else {
                if http.statusCode == 403 {
                    throw GitHubError.forbidden
                }
                throw GitHubError.from(statusCode: http.statusCode)
            }
            return data
        } catch let error as GitHubError {
            throw error
        } catch let urlError as URLError {
            switch urlError.code {
            case .cancelled: throw CancellationError()
            case .timedOut: throw GitHubError.timeout
            case .notConnectedToInternet, .networkConnectionLost: throw GitHubError.offline
            default: throw GitHubError.transport(urlError.localizedDescription)
            }
        }
    }

    // MARK: 星标

    func isStarred(owner: String, repo: String) async -> Bool {
        do {
            _ = try await sendRaw("GET", path: "/user/starred/\(owner)/\(repo)")
            return true
        } catch {
            return false
        }
    }

    func star(owner: String, repo: String) async throws {
        _ = try await sendRaw("PUT", path: "/user/starred/\(owner)/\(repo)",
                              body: ["starred": true])
    }

    func unstar(owner: String, repo: String) async throws {
        _ = try await sendRaw("DELETE", path: "/user/starred/\(owner)/\(repo)")
    }

    // MARK: Fork

    func fork(owner: String, repo: String) async throws -> RepositoryDTO {
        try await send("POST", path: "/repos/\(owner)/\(repo)/forks", as: RepositoryDTO.self)
    }

    // MARK: 代码结构

    struct TreeEntry: Decodable, Identifiable, Hashable {
        let path: String
        let mode: String?
        let type: String
        let sha: String
        let size: Int?

        var id: String { path }
        var isDirectory: Bool { type == "tree" }
        var fileName: String { path.split(separator: "/").last.map(String.init) ?? path }
        var depth: Int { path.filter { $0 == "/" }.count }
    }

    struct TreeResponse: Decodable {
        let sha: String
        let tree: [TreeEntry]
        let truncated: Bool?
    }

    func tree(owner: String, repo: String, branch: String) async throws -> [TreeEntry] {
        let response: TreeResponse = try await send(
            "GET",
            path: "/repos/\(owner)/\(repo)/git/trees/\(branch)",
            query: [URLQueryItem(name: "recursive", value: "1")],
            as: TreeResponse.self
        )
        // 只保留代码/文本类文件，按路径排序
        let allowed = ["swift", "m", "mm", "h", "c", "cpp", "hpp", "js", "ts", "tsx", "jsx",
                       "py", "go", "rs", "java", "kt", "dart", "rb", "php", "sh", "json",
                       "yml", "yaml", "md", "txt", "toml", "gradle", "xml", "html", "css"]
        return response.tree
            .filter { entry in
                guard entry.type == "blob" else { return false }
                let ext = entry.path.split(separator: ".").last.map(String.init)?.lowercased() ?? ""
                return allowed.contains(ext)
            }
            .sorted { $0.path < $1.path }
    }

    /// 走 raw.githubusercontent，不消耗 API 额度
    func rawFile(owner: String, repo: String, branch: String, path: String) async throws -> String {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        guard let url = URL(string: "https://raw.githubusercontent.com/\(owner)/\(repo)/\(branch)/\(encodedPath)") else {
            throw GitHubError.invalidURL
        }
        var request = URLRequest(url: url)
        request.setValue("GitVault/2.1", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GitHubError.notFound
        }
        // 二进制文件直接挡掉
        if data.prefix(1) == Data([0x00]) { throw GitHubError.decoding("该文件不是文本") }
        return String(data: data, encoding: .utf8) ?? "无法以文本方式读取该文件"
    }

    // MARK: 我的仓库

    func myRepositories(page: Int = 1, perPage: Int = 50) async throws -> [RepositoryDTO] {
        try await send(
            "GET",
            path: "/user/repos",
            query: [
                URLQueryItem(name: "sort", value: "updated"),
                URLQueryItem(name: "direction", value: "desc"),
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "per_page", value: "\(perPage)")
            ],
            as: [RepositoryDTO].self
        )
    }

    // MARK: Star 同步

    /// 拉取当前用户 starred（分页，100/页）
    func starredRepositories(page: Int = 1, perPage: Int = 100) async throws -> [RepositoryDTO] {
        try await send(
            "GET",
            path: "/user/starred",
            query: [
                URLQueryItem(name: "per_page", value: "\(perPage)"),
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "sort", value: "created")
            ],
            as: [RepositoryDTO].self
        )
    }

    // MARK: 作者

    /// 某个作者的高星仓库（搜索 user:login 按 star 排序）
    func repositories(by login: String, perPage: Int = 20) async throws -> [RepositoryDTO] {
        let page: SearchPage = try await send(
            "GET",
            path: "/search/repositories",
            query: [
                URLQueryItem(name: "q", value: "user:\(login)"),
                URLQueryItem(name: "sort", value: "stars"),
                URLQueryItem(name: "order", value: "desc"),
                URLQueryItem(name: "per_page", value: "\(perPage)")
            ],
            as: SearchPage.self
        )
        return page.items
    }

    struct SearchPage: Decodable {
        let items: [RepositoryDTO]
    }

    // MARK: Releases（在线更新）

    struct ReleaseAsset: Decodable {
        let name: String
        let size: Int
        let contentType: String?
        let browserDownloadURL: String

        private enum CodingKeys: String, CodingKey {
            case name, size
            case contentType = "content_type"
            case browserDownloadURL = "browser_download_url"
        }
    }

    struct ReleaseInfo: Decodable {
        let tagName: String
        let name: String?
        let body: String?
        let htmlURL: String
        let publishedAt: Date?
        let prerelease: Bool
        let assets: [ReleaseAsset]?

        private enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case name, body, prerelease, assets
            case htmlURL = "html_url"
            case publishedAt = "published_at"
        }
    }

    func repository(owner: String, repo: String) async throws -> RepositoryDTO {
        try await send("GET", path: "/repos/\(owner)/\(repo)", as: RepositoryDTO.self)
    }

    /// 私有仓库需要带 token，因此走 API 而不是公开页面
    func latestRelease(owner: String, repo: String) async throws -> ReleaseInfo {
        try await send("GET", path: "/repos/\(owner)/\(repo)/releases/latest", as: ReleaseInfo.self)
    }

    // MARK: 下载

    func zipballURL(owner: String, repo: String, branch: String) -> URL? {
        // 不指定 ref，GitHub 会用仓库默认分支（master / main 都能命中）
        URL(string: "https://api.github.com/repos/\(owner)/\(repo)/zipball")
    }
}
