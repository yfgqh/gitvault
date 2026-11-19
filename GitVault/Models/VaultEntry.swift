//
//  VaultEntry.swift
//  GitVault
//
//  SwiftData 实体。
//  重要：每个存储属性都必须有默认值或为可选 —— 否则 SwiftData 无法做轻量迁移，
//  旧版本升级上来会在打开容器 / @Query 时崩溃（真机闪退的经典成因）。
//

import Foundation
import SwiftData

@Model
final class VaultEntry {
    /// GitHub fullName，作为唯一键，避免重复收藏
    @Attribute(.unique) var repoID: String = ""
    var owner: String = ""
    var name: String = ""
    var summary: String = ""
    var language: String = ""
    var stars: Int = 0
    var forks: Int = 0
    var categoryRaw: String = RepoCategory.learning.rawValue
    var markRaw: String = MyMark.starred.rawValue
    var licenseRaw: String = LicenseTag.none.rawValue
    /// 用户自定义文件夹名（nil 表示未分组）
    var folderName: String? = nil
    var sortIndex: Int = 0
    var savedAt: Date = Date(timeIntervalSince1970: 0)
    var updatedAt: Date? = nil

    // 阶段 2 新增字段：全部带默认值，兼容任意旧库
    var avatarURL: String? = nil
    var htmlURL: String = ""
    var topicsJoined: String = ""

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
        get {
            let raw = markRaw
            return MyMark(rawValue: raw) ?? .starred
        }
        set { markRaw = newValue.rawValue }
    }

    var license: LicenseTag {
        get {
            let raw = licenseRaw
            return LicenseTag(rawValue: raw) ?? .none
        }
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
    @Attribute(.unique) var name: String = ""
    var emoji: String = "📁"
    var sortIndex: Int = 0
    var createdAt: Date = Date(timeIntervalSince1970: 0)

    init(name: String, emoji: String = "📁", sortIndex: Int = 0, createdAt: Date = .now) {
        self.name = name
        self.emoji = emoji
        self.sortIndex = sortIndex
        self.createdAt = createdAt
    }
}
