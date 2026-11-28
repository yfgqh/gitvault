//
//  VaultStore.swift
//  GitVault
//
//  收藏库持久化：JSON 文件（Application Support/GitVault/vault.json）。
//  为什么不用 SwiftData：SwiftData 是 iOS 17+，而 TrollStore 用户大量在 iOS 15/16；
//  收藏数据量级（几百条）用 JSON 完全没有性能问题，且没有任何迁移/容器崩溃面。
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class VaultStore: ObservableObject {

    @Published private(set) var items: [VaultItem] = []
    @Published private(set) var folders: [VaultFolderItem] = []

    private let fileURL: URL
    private let ioQueue = DispatchQueue(label: "com.yfgqh.gitvault.vault-io", qos: .utility)

    // MARK: 生命周期

    init(fileName: String = "vault.json") {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: nil,
                                                create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("GitVault", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent(fileName)
        load()
        CrashReporter.logSync("vault: loaded \(items.count) items from \(fileURL.lastPathComponent)")
    }

    // MARK: 查询

    var isEmpty: Bool { items.isEmpty }

    func item(id: String) -> VaultItem? {
        items.first { $0.repoID == id }
    }

    func isSaved(_ id: String) -> Bool {
        items.contains { $0.repoID == id }
    }

    func count(_ mark: MyMark) -> Int {
        items.filter { $0.mark == mark }.count
    }

    func items(inFolder folder: String) -> [VaultItem] {
        items.filter { $0.folderName == folder }
    }

    // MARK: 写入

    /// 返回操作后是否已收藏
    @discardableResult
    func toggle(_ repo: ShowcaseRepo, mark: MyMark = .starred) -> Bool {
        if let index = items.firstIndex(where: { $0.repoID == repo.id }) {
            items.remove(at: index)
            persist()
            return false
        }
        items.insert(VaultItem.make(from: repo, mark: mark), at: 0)
        reindex()
        persist()
        return true
    }

    func setMark(id: String, to mark: MyMark) {
        guard let index = items.firstIndex(where: { $0.repoID == id }) else { return }
        items[index].markRaw = mark.rawValue
        persist()
    }

    // MARK: Star 同步

    /// 导入 star 时使用：已存在则跳过（保留用户分类与笔记）
    func insertIfMissing(_ item: VaultItem) {
        insertIfMissing([item])
    }

    /// 批量版：循环内不落盘，结束后统一 reindex + persist
    /// 单条版每条都全量编码写盘，几百条时会变成 O(N²)
    func insertIfMissing(_ incoming: [VaultItem]) {
        var added = 0
        var existing = Set(items.map { $0.repoID })
        for item in incoming where !existing.contains(item.repoID) {
            items.append(item)
            existing.insert(item.repoID)
            added += 1
        }
        guard added > 0 else { return }
        reindex()
        persist()
    }

    /// 用远端 star 全集对齐本地状态：远程取消的会被标为 false，
    /// 之后的回写阶段就能重新 star 回去。
    func reconcileGithubStarred(remoteIDs: Set<String>) {
        var changed = false
        for index in items.indices {
            let should = remoteIDs.contains(items[index].repoID)
            if items[index].githubStarred != should {
                items[index].githubStarred = should
                changed = true
            }
        }
        if changed { persist() }
    }

    func markGithubStarred(id: String, starred: Bool) {
        markGithubStarred(ids: [id], starred: starred)
    }

    /// 批量版：一次落盘
    func markGithubStarred(ids: [String], starred: Bool) {
        let target = Set(ids)
        var changed = false
        for index in items.indices where target.contains(items[index].repoID) {
            if items[index].githubStarred != starred {
                items[index].githubStarred = starred
                changed = true
            }
        }
        if changed { persist() }
    }

    /// 需要回写到 GitHub 的项目：明确未 star 的，或状态未知的
    func itemsNeedingStarPush() -> [VaultItem] {
        items.filter { $0.mark != .archived && $0.githubStarred != true }
    }

    var githubStarredCount: Int {
        items.filter { $0.githubStarred == true }.count
    }

    // MARK: 版本提醒

    func recordRelease(id: String, tag: String, flagged: Bool) {
        guard let index = items.firstIndex(where: { $0.repoID == id }) else { return }
        items[index].latestReleaseTag = tag
        if flagged { items[index].hasNewRelease = true }
        persist()
    }

    func clearNewRelease(id: String) {
        guard let index = items.firstIndex(where: { $0.repoID == id }) else { return }
        guard items[index].hasNewRelease == true else { return }
        items[index].hasNewRelease = false
        persist()
    }

    var pendingReleaseCount: Int {
        items.filter { $0.hasNewRelease == true }.count
    }

    /// 更新个人笔记
    func updateNote(id: String, note: String?) {
        guard let index = items.firstIndex(where: { $0.repoID == id }) else { return }
        var item = items[index]
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        item.note = (trimmed?.isEmpty ?? true) ? nil : trimmed
        items[index] = item
        persist()
    }

    func assign(id: String, to folder: String?) {
        guard let index = items.firstIndex(where: { $0.repoID == id }) else { return }
        items[index].folderName = folder
        persist()
    }

    func remove(id: String) {
        items.removeAll { $0.repoID == id }
        persist()
    }

    func removeAll() {
        items = []
        persist()
    }

    /// 拖拽排序
    func move(fromOffsets: IndexSet, toOffset: Int, in list: [VaultItem]) {
        var ordered = list
        ordered.move(fromOffsets: fromOffsets, toOffset: toOffset)
        for (index, item) in ordered.enumerated() {
            if let idx = items.firstIndex(where: { $0.repoID == item.repoID }) {
                items[idx].sortIndex = index
            }
        }
        items.sort { $0.sortIndex < $1.sortIndex }
        persist()
    }

    // MARK: 文件夹

    @discardableResult
    func createFolder(name: String, emoji: String = "📁") -> VaultFolderItem? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !folders.contains(where: { $0.name == trimmed }) else { return nil }
        let folder = VaultFolderItem(
            name: trimmed,
            emoji: emoji,
            sortIndex: (folders.map(\.sortIndex).max() ?? 0) + 1,
            createdAt: .now
        )
        folders.append(folder)
        persist()
        return folder
    }

    func deleteFolder(_ folder: VaultFolderItem) {
        for index in items.indices where items[index].folderName == folder.name {
            items[index].folderName = nil
        }
        folders.removeAll { $0.name == folder.name }
        persist()
    }

    // MARK: 导出

    enum ExportFormat: String {
        case json, markdown
        var displayName: String { self == .json ? "JSON" : "Markdown" }
    }

    func export(_ format: ExportFormat) throws -> URL {
        let stamp = DateFormatter.exportStamp.string(from: .now)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitVault-\(stamp).\(format.rawValue)")

        switch format {
        case .json:
            var file = VaultFile()
            file.items = items
            file.folders = folders
            file.savedAt = .now
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(file).write(to: url, options: .atomic)

        case .markdown:
            var text = "# GitVault 收藏导出\n\n> 导出时间：\(stamp)\n\n"
            let grouped = Dictionary(grouping: items, by: { $0.category.title })
            for key in grouped.keys.sorted() {
                text += "## \(key)\n\n"
                for item in (grouped[key] ?? []).sorted(by: { $0.stars > $1.stars }) {
                    text += "- [\(item.name)](\(item.htmlURL)) · \(item.mark.emoji)\(item.mark.title) · ★\(item.stars)\n"
                    text += "  - \(item.summary)\n"
                }
                text += "\n"
            }
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
        return url
    }

    // MARK: 落盘

    private func reindex() {
        // 新收藏排最前
        for index in items.indices {
            items[index].sortIndex = index
        }
    }

    /// 从损坏数据里逐条捞回能解码的条目
    private static func salvageItems(from data: Data, decoder: JSONDecoder) -> (items: [VaultItem], folders: [VaultFolderItem])? {
        struct Partial: Decodable {
            let items: [FailableItem]
            let folders: [VaultFolderItem]?
        }
        struct FailableItem: Decodable {
            let value: VaultItem?
            init(from decoder: Decoder) throws {
                value = try? VaultItem(from: decoder)
            }
        }
        guard let partial = try? decoder.decode(Partial.self, from: data) else { return nil }
        let recovered = partial.items.compactMap(\.value)
        guard !recovered.isEmpty else { return nil }
        return (recovered, partial.folders ?? [])
    }

    private func persist() {
        var file = VaultFile()
        file.items = items
        file.folders = folders
        file.savedAt = .now

        let url = fileURL
        ioQueue.async {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(file)
                try data.write(to: url, options: .atomic)
            } catch {
                CrashReporter.log("vault: persist failed \(error.localizedDescription)")
            }
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // 先尝试整体解码；失败再逐条捞回，避免一条坏数据导致整库丢失
        if let file = try? decoder.decode(VaultFile.self, from: data) {
            items = file.items.sorted { $0.sortIndex < $1.sortIndex }
            folders = file.folders.sorted { $0.sortIndex < $1.sortIndex }
        } else {
            // 旧格式 / 损坏：备份后从空库开始，绝不因为本地数据崩在启动阶段
            // 逐条尝试：能救回来的一条都不丢
            if let salvaged = Self.salvageItems(from: data, decoder: decoder), !salvaged.items.isEmpty {
                // 先留底再覆盖：捞回失败也不能让原文件消失
                let keep = fileURL.appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970))")
                try? FileManager.default.copyItem(at: fileURL, to: keep)
                items = salvaged.items
                folders = salvaged.folders
                reindex()
                persist()
                CrashReporter.logSync("vault: salvaged \(salvaged.items.count) items / \(salvaged.folders.count) folders, backup kept")
                return
            }
            let backup = fileURL.appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970))")
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            CrashReporter.logSync("vault: decode failed, moved to \(backup.lastPathComponent)")
        }
    }
}

extension DateFormatter {
    static let exportStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
