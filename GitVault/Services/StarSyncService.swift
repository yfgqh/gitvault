//
//  StarSyncService.swift
//  GitVault
//
//  GitHub Star 双向同步：
//  1) 拉取 /user/starred 全部分页，导入成本地收藏（保留已有分类与笔记）
//  2) 把本地收藏但 GitHub 未 star 的项目回写为 star
//

import Foundation
import Combine

struct StarSyncResult: Equatable {
    var imported: Int = 0
    var pushed: Int = 0
    var skipped: Int = 0
    var failed: Int = 0
}

@MainActor
final class StarSyncService: ObservableObject {
    enum Phase: Equatable {
        case idle
        case fetching(page: Int, total: Int)
        case merging
        case pushing(done: Int, total: Int)
        case finished(StarSyncResult)
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var lastSyncAt: Date?

    private let lastSyncKey = "gv.starsync.lastAt"
    private let maxPages = 20          // 单次最多拉 2000 个 star
    private let pushLimit = 40         // 单次最多回写 40 个

    init() {
        let stamp = UserDefaults.standard.double(forKey: lastSyncKey)
        if stamp > 0 { lastSyncAt = Date(timeIntervalSince1970: stamp) }
    }

    var isRunning: Bool {
        switch phase {
        case .idle, .finished, .failed: return false
        default: return true
        }
    }

    // MARK: 同步

    func sync(vault: VaultStore, categorize: (RepositoryDTO) -> RepoCategory) async {
        guard !isRunning else { return }
        guard Keychain.read(Keychain.tokenKey)?.isEmpty == false else {
            phase = .failed("请先登录 GitHub")
            return
        }

        var result = StarSyncResult()

        // ---------- 1. 拉取 ----------
        var remote: [RepositoryDTO] = []
        var page = 1
        var fullyFetched = false
        while page <= maxPages {
            phase = .fetching(page: page, total: remote.count)
            do {
                let batch = try await GitHubExtrasService.shared.starredRepositories(page: page, perPage: 100)
                if batch.isEmpty {
                    fullyFetched = true
                    break
                }
                remote.append(contentsOf: batch)
                if batch.count < 100 {
                    fullyFetched = true
                    break
                }
                page += 1
            } catch {
                // 没登录或额度用完时，用已拿到的部分继续
                if remote.isEmpty {
                    phase = .failed(error.localizedDescription)
                    return
                }
                break
            }
        }

        // ---------- 2. 对齐状态 ----------
        phase = .merging
        // 只有完整拉取才敢对齐：否则会把「没拉到的」误判成未 star
        if fullyFetched {
            let remoteIDs = Set(remote.map { ShowcaseRepo(dto: $0).id })
            vault.reconcileGithubStarred(remoteIDs: remoteIDs)
        }

        // ---------- 3. 导入缺失 ----------
        let existing = Set(vault.items.map { $0.repoID })
        for dto in remote {
            let repo = ShowcaseRepo(dto: dto)
            if existing.contains(repo.id) {
                vault.markGithubStarred(id: repo.id, starred: true)
                result.skipped += 1
                continue
            }
            let category = categorize(dto)
            var item = VaultItem.make(from: repo, mark: .starred)
            item.categoryRaw = category.rawValue
            item.githubStarred = true
            vault.insertIfMissing(item)
            result.imported += 1
        }

        // ---------- 4. 回写（含在 GitHub 上被取消的） ----------
        let pending = Array(vault.itemsNeedingStarPush().prefix(pushLimit))
        for (index, item) in pending.enumerated() {
            phase = .pushing(done: index, total: pending.count)
            do {
                try await GitHubExtrasService.shared.star(owner: item.owner, repo: item.name)
                vault.markGithubStarred(id: item.repoID, starred: true)
                result.pushed += 1
            } catch {
                result.failed += 1
            }
        }

        lastSyncAt = .now
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastSyncKey)
        phase = .finished(result)
        CrashReporter.log("starsync: imported \(result.imported), pushed \(result.pushed), skipped \(result.skipped)")
    }

    func reset() {
        phase = .idle
    }
}
