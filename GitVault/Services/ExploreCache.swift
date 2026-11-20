//
//  ExploreCache.swift
//  GitVault
//
//  发现页缓存：把整页编排结果落盘，冷启动先出内容再后台刷新。
//

import Foundation

struct CachedDiscoveryFeed: Codable {
    var featured: [CachedRepo]
    var rising: [CachedRepo]
    var gems: [CachedRepo]
    var evergreen: [CachedRepo]
    var trending: [CachedRepo]
    var forYou: [CachedRepo]
    var reasons: [String: String]
    var savedAt: Date
}

enum ExploreCache {
    private static let fileName = "explore-feed.json"

    private static var fileURL: URL {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: nil,
                                                create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("GitVault", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName)
    }

    static func save(_ feed: DiscoveryFeed) {
        var reasons: [String: String] = [:]
        for item in feed.rising + feed.gems + feed.evergreen + feed.trending + feed.forYou {
            if !item.reason.isEmpty {
                reasons[item.id] = item.reason
            }
        }
        let cached = CachedDiscoveryFeed(
            featured: feed.featured.map(CachedRepo.init(repo:)),
            rising: feed.rising.map { CachedRepo(repo: $0.repo) },
            gems: feed.gems.map { CachedRepo(repo: $0.repo) },
            evergreen: feed.evergreen.map { CachedRepo(repo: $0.repo) },
            trending: feed.trending.map { CachedRepo(repo: $0.repo) },
            forYou: feed.forYou.map { CachedRepo(repo: $0.repo) },
            reasons: reasons,
            savedAt: feed.savedAt
        )
        let url = fileURL
        DispatchQueue.global(qos: .utility).async {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                try encoder.encode(cached).write(to: url, options: .atomic)
            } catch {
                CrashReporter.log("explore-cache: save failed")
            }
        }
    }

    static func load() -> DiscoveryFeed? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let cached = try? decoder.decode(CachedDiscoveryFeed.self, from: data) else {
            return nil
        }

        func items(_ repos: [CachedRepo]) -> [DiscoveryItem] {
            repos.map { repo in
                let model = ShowcaseRepo(cached: repo)
                return DiscoveryItem(
                    repo: model,
                    score: 0,
                    quality: 0,
                    activity: 0,
                    starsPerDay: 0,
                    reason: cached.reasons[model.id] ?? ""
                )
            }
        }

        var feed = DiscoveryFeed()
        feed.featured = cached.featured.map(ShowcaseRepo.init(cached:))
        feed.rising = items(cached.rising)
        feed.gems = items(cached.gems)
        feed.evergreen = items(cached.evergreen)
        feed.trending = items(cached.trending)
        feed.forYou = items(cached.forYou)
        feed.savedAt = cached.savedAt
        return feed
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
