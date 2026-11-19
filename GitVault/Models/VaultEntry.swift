//
//  VaultEntry.swift
//  GitVault
//
//  SwiftData 实体：用户收藏库中的一条记录。
//  阶段 1 只落地最小字段集，保证 ModelContainer 真实可用；
//  阶段 2 会补充 readmeSummary / topics / lastFetchedAt 等字段。
//

import Foundation
import SwiftData

@Model
final class VaultEntry {
    /// GitHub fullName，作为唯一键，避免重复收藏
    @Attribute(.unique) var repoID: String
    var owner: String
    var name: String
    var summary: String
    var language: String
    var stars: Int
    var forks: Int
    var categoryRaw: String
    var markRaw: String
    /// 用户自定义文件夹名（nil 表示未分组）
    var folder: String?
    var savedAt: Date

    init(
        repoID: String,
        owner: String,
        name: String,
        summary: String,
        language: String,
        stars: Int,
        forks: Int,
        category: RepoCategory,
        mark: MyMark = .starred,
        folder: String? = nil,
        savedAt: Date = .now
    ) {
        self.repoID = repoID
        self.owner = owner
        self.name = name
        self.summary = summary
        self.language = language
        self.stars = stars
        self.forks = forks
        self.categoryRaw = category.rawValue
        self.markRaw = mark.rawValue
        self.folder = folder
        self.savedAt = savedAt
    }

    var category: RepoCategory {
        RepoCategory(rawValue: categoryRaw) ?? .learning
    }

    var mark: MyMark {
        get { MyMark(rawValue: markRaw) ?? .starred }
        set { markRaw = newValue.rawValue }
    }
}
