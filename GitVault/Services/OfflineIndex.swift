//
//  OfflineIndex.swift
//  GitVault
//
//  离线全文索引：把看过的仓库描述与 README 落到本地，支持无网检索。
//  存储：Documents/offline-index.json（单文件，容量上限约 8MB 文本）
//

import Foundation
import Combine

struct OfflineDoc: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var owner: String
    var summary: String
    var topics: [String]
    var language: String
    var stars: Int
    var readme: String
    var updatedAt: Date

    var displayName: String { "\(owner)/\(name)" }
}

struct OfflineHit: Identifiable {
    let doc: OfflineDoc
    let score: Int
    let matchedIn: String

    var id: String { doc.id }
}

@MainActor
final class OfflineIndex: ObservableObject {
    static let shared = OfflineIndex()

    @Published private(set) var docs: [OfflineDoc] = []
    @Published private(set) var isLoaded = false

    /// README 单条最多存 24K 字符，避免索引过大
    private let readmeLimit = 24_000
    private let maxDocs = 2_000
    private let fileName = "offline-index.json"

    private var url: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent(fileName)
    }

    // MARK: 载入 / 保存

    func loadIfNeeded() {
        guard !isLoaded else { return }
        isLoaded = true
        guard let data = try? Data(contentsOf: url) else { return }
        if let decoded = try? JSONDecoder().decode([OfflineDoc].self, from: data) {
            docs = decoded
        }
    }

    private func persist() {
        // 索引体积可控（单条 README 最多 24K），同步写盘更简单也更稳
        guard let data = try? JSONEncoder().encode(docs) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: 写入

    func upsert(from repo: ShowcaseRepo) {
        loadIfNeeded()
        if let index = docs.firstIndex(where: { $0.id == repo.id }) {
            docs[index].name = repo.name
            docs[index].owner = repo.owner
            docs[index].summary = repo.summary
            docs[index].topics = repo.topics
            docs[index].language = repo.language
            docs[index].stars = repo.stars
            docs[index].updatedAt = repo.updatedAt ?? .now
        } else {
            docs.insert(OfflineDoc(id: repo.id,
                                   name: repo.name,
                                   owner: repo.owner,
                                   summary: repo.summary,
                                   topics: repo.topics,
                                   language: repo.language,
                                   stars: repo.stars,
                                   readme: "",
                                   updatedAt: repo.updatedAt ?? .now),
                        at: 0)
            if docs.count > maxDocs { docs.removeLast(docs.count - maxDocs) }
        }
        persist()
    }

    func upsertReadme(id: String, markdown: String) {
        loadIfNeeded()
        guard let index = docs.firstIndex(where: { $0.id == id }) else { return }
        let plain = SummaryService.readmeExcerpt(markdown, maxChars: readmeLimit)
        guard !plain.isEmpty, plain != docs[index].readme else { return }
        docs[index].readme = plain
        persist()
    }

    func removeAll() {
        docs = []
        persist()
    }

    // MARK: 检索

    /// 空格分隔的多关键词 AND 检索；名称/主题命中权重高于正文
    func search(_ keyword: String) -> [OfflineHit] {
        loadIfNeeded()
        let terms = keyword
            .lowercased()
            .split(whereSeparator: { $0 == " " || $0 == "　" })
            .map(String.init)
            .filter { !$0.isEmpty }
        guard !terms.isEmpty else { return [] }

        var hits: [OfflineHit] = []
        for doc in docs {
            let name = doc.displayName.lowercased()
            let topics = doc.topics.joined(separator: " ").lowercased()
            let summary = doc.summary.lowercased()
            let readme = doc.readme.lowercased()

            var score = 0
            var matchedIn = ""
            var matchedAll = true

            for term in terms {
                var termScore = 0
                if name.contains(term) { termScore += 12; matchedIn = "名称" }
                if topics.contains(term) { termScore += 6; matchedIn = matchedIn.isEmpty ? "主题" : matchedIn }
                if summary.contains(term) { termScore += 4; matchedIn = matchedIn.isEmpty ? "简介" : matchedIn }
                if readme.contains(term) {
                    termScore += 2
                    matchedIn = matchedIn.isEmpty ? "README" : matchedIn
                }
                if termScore == 0 { matchedAll = false; break }
                score += termScore
            }

            if matchedAll, score > 0 {
                // 星标与新鲜度做轻微加权，避免长文堆砌占优
                score += min(doc.stars / 2_000, 6)
                hits.append(OfflineHit(doc: doc, score: score, matchedIn: matchedIn))
            }
        }
        return hits.sorted { $0.score > $1.score }.prefix(60).map { $0 }
    }

    /// README 片段：截取关键词附近的一句话，用于结果预览
    func excerpt(for doc: OfflineDoc, keyword: String) -> String {
        let plain = doc.readme.isEmpty ? doc.summary : doc.readme
        guard !keyword.isEmpty,
              let range = plain.range(of: keyword, options: .caseInsensitive) else {
            return String(plain.prefix(110))
        }
        let start = plain.index(range.lowerBound, offsetBy: -40, limitedBy: plain.startIndex) ?? plain.startIndex
        let end = plain.index(range.upperBound, offsetBy: 70, limitedBy: plain.endIndex) ?? plain.endIndex
        return "…" + plain[start..<end].replacingOccurrences(of: "\n", with: " ") + "…"
    }
}
