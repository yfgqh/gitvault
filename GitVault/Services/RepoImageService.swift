//
//  RepoImageService.swift
//  GitVault
//
//  抓仓库 README 里的第一张图作为「项目介绍图」。
//  未登录时 GitHub API 每小时只有 60 次，所以这里做了三层保护：
//  持久缓存 → 每日额度 → 失败就不再重试。
//

import Foundation
import UIKit

actor RepoImageService {
    static let shared = RepoImageService()

    private var inFlight: [String: Task<URL?, Never>] = [:]
    private let defaults = UserDefaults.standard
    private let cachePrefix = "gv.repoImage."
    private let quotaKey = "gv.repoImage.quota"
    private let quotaDayKey = "gv.repoImage.quotaDay"
    /// 每天最多 40 次 README 请求（60 次/小时的额度留出余量给详情页）
    private let dailyLimit = 40

    /// 已知的「不适合当封面」的图片关键词
    private let skipWords = ["badge", "shields.io", "travis", "codecov", "build-status",
                             "stars.svg", "license.svg", "logo.svg", "action.svg"]

    // MARK: 对外

    func previewImage(owner: String, name: String) async -> URL? {
        let key = "\(owner)/\(name)"
        // 缓存命中不耗额度，必须放在闸门之前，否则已有图也会失效
        if let cached = cachedURL(key: key) {
            return cached
        }
        // 匿名额度只够浏览，README 抓图降级给 CDN 封面（社交卡 / 头像）兜底
        guard Keychain.read(Keychain.tokenKey)?.isEmpty == false else { return nil }
        if let running = inFlight[key] {
            return await running.value
        }

        let task = Task<URL?, Never> { [weak self] in
            await self?.fetch(owner: owner, name: name, key: key) ?? nil
        }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil
        return result
    }

    // MARK: 内部

    private func fetch(owner: String, name: String, key: String) async -> URL? {
        guard consumeQuota() else { return nil }

        guard let api = URL(string: "https://api.github.com/repos/\(owner)/\(name)/readme") else { return nil }
        var request = URLRequest(url: api)
        request.timeoutInterval = 15
        request.setValue("application/vnd.github.html+json", forHTTPHeaderField: "Accept")
        request.setValue("GitVault/\(UpdateChecker.currentVersion)", forHTTPHeaderField: "User-Agent")
        if let token = Keychain.read(Keychain.tokenKey), !token.isEmpty {
            request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  let html = String(data: data, encoding: .utf8) else { return nil }

            guard let raw = firstImageURL(in: html) else {
                store(nil, for: key)
                return nil
            }
            // 相对路径补全到 raw.githubusercontent.com
            let absolute: URL?
            if raw.hasPrefix("http") {
                absolute = URL(string: raw)
            } else if raw.hasPrefix("//") {
                absolute = URL(string: "https:" + raw)
            } else {
                absolute = URL(string: "https://raw.githubusercontent.com/\(owner)/\(name)/HEAD/\(raw.hasPrefix("/") ? String(raw.dropFirst()) : raw)")
            }
            store(absolute, for: key)
            return absolute
        } catch {
            return nil
        }
    }

    /// 从 README HTML 里取第一张可用的图
    private func firstImageURL(in html: String) -> String? {
        let pattern = #"<img[^>]+src="([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex.matches(in: html, options: [], range: range)
        for match in matches {
            guard let srcRange = Range(match.range(at: 1), in: html) else { continue }
            let src = String(html[srcRange])
            let lower = src.lowercased()
            if skipWords.contains(where: { lower.contains($0) }) { continue }
            if lower.hasSuffix(".svg") { continue }
            return src
        }
        return nil
    }

    // MARK: 缓存

    private func cachedURL(key: String) -> URL? {
        let value = defaults.string(forKey: cachePrefix + key)
        if value == "<nil>" { return nil }      // 明确记录过「没有图」
        guard let value, let url = URL(string: value) else { return nil }
        return url
    }

    private func store(_ url: URL?, for key: String) {
        defaults.set(url?.absoluteString ?? "<nil>", forKey: cachePrefix + key)
    }

    // MARK: 额度

    private func consumeQuota() -> Bool {
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
        let savedDay = defaults.string(forKey: quotaDayKey) ?? ""
        var used = defaults.integer(forKey: quotaKey)
        if savedDay != String(today) {
            used = 0
            defaults.set(String(today), forKey: quotaDayKey)
        }
        guard used < dailyLimit else { return false }
        defaults.set(used + 1, forKey: quotaKey)
        return true
    }
}
