//
//  ReleaseWatcher.swift
//  GitVault
//
//  收藏仓库的版本提醒（前台检查版，无服务端）：
//  - 取收藏中最近更新的 N 个项目，查询各自最新的 Release tag
//  - 与上次记录的 tag 对比，有变化就标记红点并汇总发一条本地通知
//  - 6 小时节流，避免反复请求
//

import Foundation
import UserNotifications
import Combine

@MainActor
final class ReleaseWatcher: ObservableObject {
    @Published private(set) var isChecking = false
    @Published private(set) var lastCheckedAt: Date?
    @Published private(set) var newReleaseCount = 0

    private let lastCheckKey = "gv.release.lastCheck"
    private let throttle: TimeInterval = 6 * 3600
    private let batchLimit = 10

    // MARK: 对外

    func checkIfNeeded(vault: VaultStore, force: Bool = false) async {
        guard !isChecking else { return }
        // 匿名额度只有 60 次/小时，收藏监听优先级最低，留给浏览用
        guard Keychain.read(Keychain.tokenKey)?.isEmpty == false else { return }
        if !force {
            let stamp = UserDefaults.standard.double(forKey: lastCheckKey)
            if stamp > 0, Date().timeIntervalSince1970 - stamp < throttle {
                newReleaseCount = vault.items.filter { $0.hasNewRelease == true }.count
                return
            }
        }

        let candidates = vault.items
            .filter { $0.mark != .archived }
            .sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
            .prefix(batchLimit)

        guard !candidates.isEmpty else {
            newReleaseCount = 0
            return
        }

        isChecking = true
        defer { isChecking = false }

        var flagged = 0
        for item in candidates {
            guard let release = try? await GitHubExtrasService.shared.latestRelease(owner: item.owner, repo: item.name) else {
                continue
            }
            let tag = release.tagName
            if let previous = item.latestReleaseTag {
                if previous != tag {
                    vault.recordRelease(id: item.repoID, tag: tag, flagged: true)
                    flagged += 1
                }
            } else {
                // 第一次记录只作为基线，不打扰用户
                vault.recordRelease(id: item.repoID, tag: tag, flagged: false)
            }
        }

        newReleaseCount = vault.items.filter { $0.hasNewRelease == true }.count
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastCheckKey)
        lastCheckedAt = .now
        CrashReporter.log("release-watcher: checked \(candidates.count), flagged \(flagged)")

        if flagged > 0 {
            await notify(count: flagged)
        }
    }

    func reset() {
        newReleaseCount = 0
        lastCheckedAt = nil
    }

    // MARK: 通知

    private func notify(count: Int) async {
        let center = UNUserNotificationCenter.current()
        let granted: Bool
        do {
            granted = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            CrashReporter.log("release-watcher: auth failed \(error.localizedDescription)")
            return
        }
        guard granted else { return }

        let content = UNMutableNotificationContent()
        content.title = "收藏的仓库有新版本"
        content.body = String(format: NSLocalizedString("%d 个你收藏的仓库刚刚发布了新的 Release，去收藏页看看。", comment: ""), count)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "gv.release.\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        do {
            try await center.add(request)
        } catch {
            CrashReporter.log("release-watcher: notify failed \(error.localizedDescription)")
        }
    }
}
