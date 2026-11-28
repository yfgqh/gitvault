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
    /// Release 里的一个资产（ipa / zip / dSYM / 源码包）
    struct Asset: Equatable, Identifiable {
        let name: String
        let size: Int
        let url: URL

        var id: String { name }

        var isIPA: Bool { name.lowercased().hasSuffix(".ipa") }

        var sizeText: String {
            guard size > 0 else { return "" }
            if size >= 1_048_576 {
                return String(format: "%.1f MB", Double(size) / 1_048_576)
            }
            return String(format: "%.0f KB", Double(size) / 1024)
        }

        /// 展示用的类型名
        var kindLabel: String {
            let lower = name.lowercased()
            if lower.hasSuffix(".ipa") { return "IPA" }
            if lower.hasSuffix(".zip") { return "ZIP" }
            if lower.hasSuffix(".dmg") { return "DMG" }
            if lower.hasSuffix(".apk") { return "APK" }
            if lower.hasSuffix(".tar.gz") { return "TGZ" }
            if lower.hasSuffix(".dsym.zip") { return "dSYM" }
            if let dot = name.lastIndex(of: ".") { return String(name[name.index(after: dot)...]).uppercased() }
            return NSLocalizedString("文件", comment: "")
        }
    }

    struct Available: Equatable, Identifiable {
        let tag: String
        let name: String
        let notes: String
        let url: URL?
        /// 全部资产，IPA 排在最前
        var assets: [Asset] = []
        /// 已安装的版本（来自 Bundle）
        var installedVersion: String = UpdateChecker.currentVersion

        var id: String { tag }

        var ipa: Asset? { assets.first(where: { $0.isIPA }) }

        /// 兼容旧调用点
        var assetName: String? { ipa?.name }
        var assetSize: Int? { ipa?.size }
        var downloadURL: URL? { ipa?.url }

        var sizeText: String { ipa?.sizeText ?? "" }

        var hasUpdate: Bool {
            UpdateChecker.compare(UpdateChecker.normalize(tag), UpdateChecker.normalize(installedVersion)) > 0
        }
    }

    @Published private(set) var available: Available?
    /// 启动检查命中新版本时置位，RootView 取走后弹卡
    @Published var pendingLaunchPrompt: Available?
    @Published private(set) var isChecking = false
    @Published private(set) var lastCheckedAt: Date?

    private let lastCheckKey = "gv.update.lastCheck"
    private let dismissedKey = "gv.update.dismissedTag"
    /// 启动检查不做时限节流：每次打开 App 都查一次（单次仅 1 个请求）。
    /// 是否弹卡由「稍后」与「忽略该版本」两个用户选择决定。
    private let ttl: TimeInterval = 0

    nonisolated static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    var currentVersionText: String {
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(UpdateChecker.currentVersion) (\(build))"
    }

    // MARK: 检查

    private let snoozeKey = "gv.update.snoozeUntil"

    /// 取走启动提示（弹过一次就清空）
    func consumeLaunchPrompt() -> Available? {
        let value = pendingLaunchPrompt
        pendingLaunchPrompt = nil
        return value
    }

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
        // 仓库已公开：未登录也能匿名读到 releases/latest，不再要求 token
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
            if !force, UserDefaults.standard.string(forKey: dismissedKey) == release.tagName {
                available = nil
                return
            }
            // 收集全部可下载资产，IPA 优先
            let all = (release.assets ?? []).compactMap { raw -> Asset? in
                guard let url = URL(string: raw.browserDownloadURL) else { return nil }
                return Asset(name: raw.name, size: raw.size, url: url)
            }
            let sorted = all.filter { $0.isIPA } + all.filter { !$0.isIPA }.sorted { $0.size > $1.size }

            let info = Available(
                tag: release.tagName,
                name: release.name ?? release.tagName,
                notes: String((release.body ?? "").prefix(600)),
                url: URL(string: release.htmlURL),
                assets: sorted,
                installedVersion: Self.currentVersion
            )
            available = info
            // 供启动时弹出更新卡
            if !force { pendingLaunchPrompt = info }
            CrashReporter.log("update: \(current) -> \(latest)")
        } catch {
            CrashReporter.log("update: check failed \(error.localizedDescription)")
        }
    }

    // MARK: 版本号工具

    nonisolated static func normalize(_ raw: String) -> [Int] {
        let trimmed = raw.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
        return trimmed.split(separator: ".").map { Int($0.prefix(while: { $0.isNumber })) ?? 0 }
    }

    /// 返回 1 表示 a > b，-1 表示 a < b
    nonisolated static func compare(_ a: [Int], _ b: [Int]) -> Int {
        let count = max(a.count, b.count)
        for index in 0..<count {
            let x = index < a.count ? a[index] : 0
            let y = index < b.count ? b[index] : 0
            if x != y { return x > y ? 1 : -1 }
        }
        return 0
    }
}
