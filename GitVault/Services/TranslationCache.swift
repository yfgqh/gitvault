//
//  TranslationCache.swift
//  GitVault
//
//  README 译文缓存：同一份内容只调用一次模型，二次进入详情页秒出结果。
//  存储：Documents/translation-cache.json，最多保留 300 条，超出按时间淘汰。
//

import Foundation

@MainActor
final class TranslationCache {
    static let shared = TranslationCache()

    private struct Entry: Codable {
        let key: String
        var text: String
        var at: Date
    }

    private var entries: [String: Entry] = [:]
    private var loaded = false
    private let fileName = "translation-cache.json"
    private let limit = 300

    private var url: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent(fileName)
    }

    // MARK: 读写

    func cached(repoID: String, hash: String) -> String? {
        loadIfNeeded()
        let key = "\(repoID)|\(hash)"
        guard var entry = entries[key] else { return nil }
        entry.at = .now
        entries[key] = entry
        return entry.text
    }

    func store(repoID: String, hash: String, text: String) {
        loadIfNeeded()
        let key = "\(repoID)|\(hash)"
        entries[key] = Entry(key: key, text: text, at: .now)
        trimIfNeeded()
        persist()
    }

    var count: Int {
        loadIfNeeded()
        return entries.count
    }

    func clear() {
        entries = [:]
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: 工具

    /// djb2 哈希：足够区分内容，不需要引入 CryptoKit
    nonisolated static func hash(_ text: String) -> String {
        var value: UInt64 = 5381
        for byte in text.utf8 {
            value = (value &* 33) &+ UInt64(byte)
        }
        return String(value, radix: 16)
    }

    // MARK: 内部

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Entry].self, from: data) else { return }
        entries = Dictionary(uniqueKeysWithValues: decoded.map { ($0.key, $0) })
    }

    private func trimIfNeeded() {
        guard entries.count > limit else { return }
        let sorted = entries.values.sorted { $0.at > $1.at }
        let keep = Set(sorted.prefix(limit).map { $0.key })
        entries = entries.filter { keep.contains($0.key) }
    }

    private func persist() {
        let snapshot = Array(entries.values)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
