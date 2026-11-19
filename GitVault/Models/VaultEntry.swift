//
//  VaultEntry.swift
//  GitVault
//
//  SwiftData 实体：用户收藏库中的一条记录（含阶段 2 新增字段）。
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
    var licenseRaw: String
    /// 用户自定义文件夹名（nil 表示未分组）
    var folderName: String?
    /// 文件夹内排序
    var sortIndex: Int
    var savedAt: Date
    var updatedAt: Date?

    // 阶段 2 新增（带默认值，兼容旧库）
    var avatarURL: String?
    var htmlURL: String
    var topicsJoined: String

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
        license: LicenseTag = .none,
        folderName: String? = nil,
        sortIndex: Int = 0,
        savedAt: Date = .now,
        updatedAt: Date? = nil,
        avatarURL: String? = nil,
        htmlURL: String = "",
        topics: [String] = []
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
        self.licenseRaw = license.rawValue
        self.folderName = folderName
        self.sortIndex = sortIndex
        self.savedAt = savedAt
        self.updatedAt = updatedAt
        self.avatarURL = avatarURL
        self.htmlURL = htmlURL
        self.topicsJoined = topics.joined(separator: ",")
    }

    var category: RepoCategory {
        RepoCategory(rawValue: categoryRaw) ?? .learning
    }

    var mark: MyMark {
        get { MyMark(rawValue: markRaw) ?? .starred }
        set { markRaw = newValue.rawValue }
    }

    var license: LicenseTag {
        get { LicenseTag(rawValue: licenseRaw) ?? .none }
        set { licenseRaw = newValue.rawValue }
    }

    var topics: [String] {
        topicsJoined.isEmpty ? [] : topicsJoined.split(separator: ",").map(String.init)
    }

    /// 从 UI 模型建条目
    static func make(from repo: ShowcaseRepo, mark: MyMark = .starred, folder: String? = nil) -> VaultEntry {
        VaultEntry(
            repoID: repo.id,
            owner: repo.owner,
            name: repo.name,
            summary: repo.summary,
            language: repo.language,
            stars: repo.stars,
            forks: repo.forks,
            category: repo.category,
            mark: mark,
            license: repo.license,
            folderName: folder,
            sortIndex: Int(Date.now.timeIntervalSince1970),
            savedAt: .now,
            updatedAt: repo.updatedAt,
            avatarURL: repo.avatarURL?.absoluteString,
            htmlURL: repo.githubURL?.absoluteString ?? "",
            topics: repo.topics
        )
    }
}

// MARK: - 用户自定义文件夹

@Model
final class VaultFolder {
    @Attribute(.unique) var name: String
    var emoji: String
    var sortIndex: Int
    var createdAt: Date

    init(name: String, emoji: String = "📁", sortIndex: Int = 0, createdAt: Date = .now) {
        self.name = name
        self.emoji = emoji
        self.sortIndex = sortIndex
        self.createdAt = createdAt
    }
}
