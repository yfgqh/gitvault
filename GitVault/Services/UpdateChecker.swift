//
//  UpdateChecker.swift
//  GitVault
//
//  在线更新：比对 GitHub Releases 的最新 tag 与本地版本。
//  私有仓库需要 token，因此走 API；未登录时静默跳过。
//

import Foundation
import Combine

@MainActor
final class UpdateChecker: ObservableObject {
    struct Available: Equatable {
        let tag: String
        let name: String
        let notes: String
        let url: URL?
        /// Release 里 .ipa 资产的名称 / 体积 / 下载地址（私有仓库需带 token）
        var assetName: String?
        var assetSize: Int?
        var downloadURL: URL?

        var sizeText: String {
            guard let size = assetSize, size > 0 else { return "" }
            return String(format: "%.1f MB", Double(size) / 1_048_576)
        }
    }

    @Published private(set) var available: Available?
    @Published private(set) var isChecking = false
    @Published private(set) var lastCheckedAt: Date?

    private let lastCheckKey = "gv.update.lastCheck"
    private let dismissedKey = "gv.update.dismissedTag"
    private let ttl: TimeInterval = 6 * 3600

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    var currentVersionText: String {
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(UpdateChecker.currentVersion) (\(build))"
    }

    // MARK: 检查

    private let snoozeKey = "gv.update.snoozeUntil"

    /// 24 小时内不再提醒
    func snooze() {
        UserDefaults.standard.set(Date().timeIntervalSince1970 + 24 * 3600, forKey: snoozeKey)
        available = nil
    }

    var isSnoozed: Bool {
        UserDefaults.standard.double(forKey: snoozeKey) > Date().timeIntervalSince1970
    }

    /// 忽略某个版本（横幅不再出现）
    func dismissBanner() {
        if let tag = available?.tag {
            UserDefaults.standard.set(tag, forKey: dismissedKey)
        }
        available = nil
    }

    func checkIfNeeded(force: Bool = false) async {
        if !force {
            let stamp = UserDefaults.standard.double(forKey: lastCheckKey)
            if stamp > 0, Date().timeIntervalSince1970 - stamp < ttl { return }
        }
        guard Keychain.read(Keychain.tokenKey)?.isEmpty == false else {
            CrashReporter.log("update: skipped (no token, private repo)")
            return
        }
        if !force, isSnoozed { return }

        isChecking = true
        defer { isChecking = false }

        do {
            let release = try await GitHubExtrasService.shared.latestRelease(owner: "yfgqh", repo: "gitvault")
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastCheckKey)
            lastCheckedAt = .now

            let latest = Self.normalize(release.tagName)
            let current = Self.normalize(UpdateChecker.currentVersion)
            guard Self.compare(latest, current) > 0 else {
                available = nil
                return
            }
            if UserDefaults.standard.string(forKey: dismissedKey) == release.tagName {
                available = nil
                return
            }
            let ipa = (release.assets ?? []).first { $0.name.lowercased().hasSuffix(".ipa") }
            available = Available(
                tag: release.tagName,
                name: release.name ?? release.tagName,
                notes: String((release.body ?? "").prefix(600)),
                url: URL(string: release.htmlURL),
                assetName: ipa?.name,
                assetSize: ipa?.size,
                downloadURL: ipa.flatMap { URL(string: $0.browserDownloadURL) }
            )
            CrashReporter.log("update: \(current) -> \(latest)")
        } catch {
            CrashReporter.log("update: check failed \(error.localizedDescription)")
        }
    }

    // MARK: 版本号工具

    static func normalize(_ raw: String) -> [Int] {
        let trimmed = raw.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
        return trimmed.split(separator: ".").map { Int($0.prefix(while: { $0.isNumber })) ?? 0 }
    }

    /// 返回 1 表示 a > b，-1 表示 a < b
    static func compare(_ a: [Int], _ b: [Int]) -> Int {
        let count = max(a.count, b.count)
        for index in 0..<count {
            let x = index < a.count ? a[index] : 0
            let y = index < b.count ? b[index] : 0
            if x != y { return x > y ? 1 : -1 }
        }
        return 0
    }
}
