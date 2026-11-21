//
//  VaultModels.swift
//  GitVault
//
//  收藏库的持久化模型：Codable struct（不再依赖 SwiftData）。
//  这样在 iOS 16 上也能跑，并且彻底消除 schema 迁移 / 容器初始化这两类启动崩溃。
//

import Foundation

struct VaultItem: Codable, Identifiable, Hashable {
    var repoID: String
    var owner: String
    var name: String
    var summary: String
    var language: String
    var stars: Int
    var forks: Int
    var categoryRaw: String
    var markRaw: String
    var licenseRaw: String
    var folderName: String?
    var sortIndex: Int
    var savedAt: Date
    var updatedAt: Date?
    var avatarURL: String?
    var htmlURL: String
    var topics: [String]
    /// 个人笔记：为什么收藏它
    var note: String? = nil
    /// 上次看到的 Release tag（用于判断是否有新版本）
    var latestReleaseTag: String? = nil
    /// 是否有未被查看的新 Release
    var hasNewRelease: Bool? = nil

    var id: String { repoID }

    var category: RepoCategory { RepoCategory(rawValue: categoryRaw) ?? .learning }
    var mark: MyMark { MyMark(rawValue: markRaw) ?? .starred }
    var license: LicenseTag { LicenseTag(rawValue: licenseRaw) ?? .none }

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
        self.topics = topics
    }

    static func make(from repo: ShowcaseRepo, mark: MyMark = .starred, folder: String? = nil) -> VaultItem {
        VaultItem(
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

struct VaultFolderItem: Codable, Identifiable, Hashable {
    var name: String
    var emoji: String
    var sortIndex: Int
    var createdAt: Date

    var id: String { name }
}

/// 落盘文件结构（带版本号，方便以后迁移）
struct VaultFile: Codable {
    var schemaVersion: Int = 1
    var items: [VaultItem] = []
    var folders: [VaultFolderItem] = []
    var savedAt: Date = .now
}
