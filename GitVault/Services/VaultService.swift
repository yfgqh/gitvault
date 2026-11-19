//
//  VaultService.swift
//  GitVault
//
//  Repository Pattern 的本地实现：SwiftData 读写全部收敛到这里，
//  视图只调方法，不直接拼 FetchDescriptor。
//

import Foundation
import SwiftData

@MainActor
struct VaultService {
    let context: ModelContext

    // MARK: - 查询

    func allEntries() -> [VaultEntry] {
        let descriptor = FetchDescriptor<VaultEntry>(
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func entry(repoID: String) -> VaultEntry? {
        var descriptor = FetchDescriptor<VaultEntry>(
            predicate: #Predicate<VaultEntry> { entry in entry.repoID == repoID }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    func isSaved(_ repoID: String) -> Bool {
        entry(repoID: repoID) != nil
    }

    // MARK: - 写入

    /// 收藏 / 取消收藏，返回操作后是否处于已收藏状态
    @discardableResult
    func toggle(_ repo: ShowcaseRepo, mark: MyMark = .starred) -> Bool {
        if let existing = entry(repoID: repo.id) {
            context.delete(existing)
            save()
            return false
        }
        let newEntry = VaultEntry.make(from: repo, mark: mark)
        context.insert(newEntry)
        save()
        return true
    }

    func setMark(_ entry: VaultEntry, to mark: MyMark) {
        entry.mark = mark
        save()
    }

    func assign(_ entry: VaultEntry, to folder: String?) {
        entry.folderName = folder
        save()
    }

    func remove(_ entry: VaultEntry) {
        context.delete(entry)
        save()
    }

    func removeAll() {
        for entry in allEntries() { context.delete(entry) }
        save()
    }

    /// 拖拽排序：把传入顺序写回 sortIndex
    func persistOrder(_ entries: [VaultEntry]) {
        for (index, entry) in entries.enumerated() {
            entry.sortIndex = index
        }
        save()
    }

    // MARK: - 文件夹

    func folders() -> [VaultFolder] {
        let descriptor = FetchDescriptor<VaultFolder>(
            sortBy: [SortDescriptor(\.sortIndex)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    @discardableResult
    func createFolder(name: String, emoji: String = "📁") -> VaultFolder? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let folder = VaultFolder(
            name: trimmed,
            emoji: emoji,
            sortIndex: (folders().map(\.sortIndex).max() ?? 0) + 1
        )
        context.insert(folder)
        save()
        return folder
    }

    func deleteFolder(_ folder: VaultFolder) {
        for entry in allEntries() where entry.folderName == folder.name {
            entry.folderName = nil
        }
        context.delete(folder)
        save()
    }

    // MARK: - 导出

    enum ExportFormat: String {
        case json = "json"
        case markdown = "md"
    }

    func export(_ format: ExportFormat) throws -> URL {
        let entries = allEntries()
        let directory = FileManager.default.temporaryDirectory
        let filename = "GitVault-\(DateFormatter.exportStamp.string(from: .now)).\(format.rawValue)"
        let url = directory.appendingPathComponent(filename)

        switch format {
        case .json:
            let payload = entries.map { entry in
                [
                    "repo": entry.repoID,
                    "url": entry.htmlURL,
                    "summary": entry.summary,
                    "language": entry.language,
                    "stars": String(entry.stars),
                    "category": entry.category.title,
                    "mark": entry.mark.title,
                    "license": entry.license.title,
                    "folder": entry.folderName ?? "",
                    "savedAt": ISO8601DateFormatter().string(from: entry.savedAt)
                ]
            }
            let data = try JSONSerialization.data(
                withJSONObject: ["exportedAt": ISO8601DateFormatter().string(from: .now), "items": payload],
                options: [.prettyPrinted, .sortedKeys]
            )
            try data.write(to: url, options: .atomic)
        case .markdown:
            var text = "# GitVault 收藏导出\n\n> 导出时间：\(DateFormatter.exportStamp.string(from: .now))\n\n"
            for group in Dictionary(grouping: entries, by: { $0.category.title }).sorted(by: { $0.key < $1.key }) {
                text += "## \(group.key)\n\n"
                for entry in group.value.sorted(by: { $0.stars > $1.stars }) {
                    text += "- [\(entry.name)](\(entry.htmlURL)) · \(entry.mark.emoji)\(entry.mark.title) · ★\(entry.stars)\n"
                    text += "  - \(entry.summary)\n"
                }
                text += "\n"
            }
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
        return url
    }

    // MARK: - 落盘

    private func save() {
        do {
            try context.save()
        } catch {
            // 落盘失败不阻塞 UI，但要在控制台留痕便于定位
            print("[VaultService] save failed:", error.localizedDescription)
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
