//
//  RepoHealthMonitor.swift
//  GitVault
//
//  仓库死亡信号：定期扫描收藏项目，发现归档、长期停更、issue 积压。
//  无后台常驻任务：每周首次打开 App 时扫描一次，并对高危项发一条本地通知。
//

import Foundation
import UserNotifications
import Combine

struct HealthFinding: Identifiable, Codable, Equatable {
    let id: String
    let repoID: String
    let name: String
    let owner: String
    /// 3 = 致命，2 = 高，1 = 中
    let severity: Int
    let reason: String

    var displayName: String { "\(owner)/\(name)" }

    var severityText: String {
        switch severity {
        case 3: return "致命"
        case 2: return "高"
        default: return "中"
        }
    }
}

@MainActor
final class RepoHealthMonitor: ObservableObject {
    @Published private(set) var findings: [HealthFinding] = []
    @Published private(set) var lastScanAt: Date?
    @Published private(set) var isScanning = false
    @Published private(set) var scannedCount = 0

    private let findingsKey = "gv.health.findings"
    private let lastScanKey = "gv.health.lastScan"
    private let weekInterval: TimeInterval = 7 * 86_400
    private let batchLimit = 25

    init() {
        if let data = UserDefaults.standard.data(forKey: findingsKey),
           let decoded = try? JSONDecoder().decode([HealthFinding].self, from: data) {
            findings = decoded
        }
        let stamp = UserDefaults.standard.double(forKey: lastScanKey)
        if stamp > 0 { lastScanAt = Date(timeIntervalSince1970: stamp) }
    }

    var highRiskCount: Int {
        findings.filter { $0.severity >= 2 }.count
    }

    var isFresh: Bool {
        guard let last = lastScanAt else { return false }
        return Date().timeIntervalSince(last) < weekInterval
    }

    // MARK: 扫描

    func scanIfNeeded(vault: VaultStore, force: Bool = false) async {
        guard !isScanning else { return }
        if !force, isFresh { return }
        guard Keychain.read(Keychain.tokenKey)?.isEmpty == false else { return }

        isScanning = true
        defer { isScanning = false }

        let targets = vault.items
            .filter { $0.mark != .archived }
            .sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
            .prefix(batchLimit)

        var collected: [HealthFinding] = []
        scannedCount = 0

        for item in targets {
            scannedCount += 1
            guard let dto = try? await GitHubService.shared.repository(owner: item.owner, name: item.name) else { continue }

            if dto.archived == true {
                collected.append(HealthFinding(id: "\(item.repoID)-archived",
                                               repoID: item.repoID,
                                               name: item.name,
                                               owner: item.owner,
                                               severity: 3,
                                               reason: "仓库已归档，作者不再维护"))
                continue
            }

            if let pushed = dto.pushedAt {
                let days = Int(Date().timeIntervalSince(pushed) / 86_400)
                if days >= 365 {
                    collected.append(HealthFinding(id: "\(item.repoID)-stale12",
                                                   repoID: item.repoID,
                                                   name: item.name,
                                                   owner: item.owner,
                                                   severity: 3,
                                                   reason: "已 \(days / 30) 个月没有提交"))
                    continue
                }
                if days >= 180 {
                    collected.append(HealthFinding(id: "\(item.repoID)-stale6",
                                                   repoID: item.repoID,
                                                   name: item.name,
                                                   owner: item.owner,
                                                   severity: 2,
                                                   reason: "最近一次提交在 \(days) 天前"))
                }
            }

            if dto.openIssuesCount >= 300 {
                collected.append(HealthFinding(id: "\(item.repoID)-issues",
                                               repoID: item.repoID,
                                               name: item.name,
                                               owner: item.owner,
                                               severity: 1,
                                               reason: "\(dto.openIssuesCount) 个 issue 未关闭"))
            }
        }

        findings = collected.sorted { $0.severity > $1.severity }
        lastScanAt = .now
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastScanKey)
        if let data = try? JSONEncoder().encode(findings) {
            UserDefaults.standard.set(data, forKey: findingsKey)
        }
        CrashReporter.log("health: scanned \(scannedCount), findings \(findings.count)")

        if highRiskCount > 0 {
            await notify(count: highRiskCount)
        }
    }

    func clear() {
        findings = []
        UserDefaults.standard.removeObject(forKey: findingsKey)
        UserDefaults.standard.removeObject(forKey: lastScanKey)
        lastScanAt = nil
    }

    private func notify(count: Int) async {
        let center = UNUserNotificationCenter.current()
        let granted: Bool
        do {
            granted = try await center.requestAuthorization(options: [.alert, .sound])
        } catch { return }
        guard granted else { return }

        let content = UNMutableNotificationContent()
        content.title = "收藏项目健康周报"
        content.body = "\(count) 个项目出现停更或归档信号，建议检查是否仍在使用。"
        content.sound = .default
        let request = UNNotificationRequest(identifier: "gv.health.weekly",
                                            content: content,
                                            trigger: nil)
        try? await center.add(request)
    }
}
