//
//  RepoHealthView.swift
//  GitVault
//
//  仓库健康周报：归档、长期停更、issue 积压的集中清单。
//

import SwiftUI

struct RepoHealthView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var vault: VaultStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var monitor = RepoHealthMonitor()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    summary

                    if monitor.findings.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: DS.Space.s) {
                            ForEach(monitor.findings) { finding in
                                row(finding)
                            }
                        }
                    }
                }
                .padding(DS.Space.l)
            }
            .background(DS.bgPrimary)
            .navigationTitle("仓库健康")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if monitor.isScanning {
                        HStack(spacing: 4) {
                            ProgressView().scaleEffect(0.6).tint(DS.accent)
                            Text("\(monitor.scannedCount)")
                                .font(.system(size: 10))
                                .foregroundStyle(DS.textTertiary)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.accent)
                }
            }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 18))
                    .foregroundStyle(monitor.highRiskCount > 0 ? DS.warning : DS.success)
                Text(monitor.highRiskCount > 0 ? String(format: NSLocalizedString("%d 个高危项目", comment: ""), monitor.highRiskCount) : NSLocalizedString("暂无高危项目", comment: ""))
                    .font(DS.Typo.cardTitle)
                    .foregroundStyle(DS.textPrimary)
                Spacer(minLength: 0)
            }

            Text(lastScanText)
                .font(.system(size: 11))
                .foregroundStyle(DS.textTertiary)

            HStack(spacing: DS.Space.m) {
                Button {
                    Haptics.tap()
                    Task { await monitor.scanIfNeeded(vault: vault, force: true) }
                } label: {
                    HStack(spacing: 5) {
                        if monitor.isScanning {
                            ProgressView().scaleEffect(0.55).tint(.white)
                        }
                        Text(monitor.isScanning ? "扫描中…" : "立即扫描")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(DS.accent))
                }
                .buttonStyle(.springPress)
                .disabled(monitor.isScanning)

                if !monitor.findings.isEmpty {
                    Button {
                        monitor.clear()
                        env.show("已清空健康记录", kind: .info)
                    } label: {
                        Text("清空记录")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(DS.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface()
    }

    private var lastScanText: String {
        guard let last = monitor.lastScanAt else {
            return "还没扫描过。每周首次打开 App 会自动检查一次。"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return "上次扫描：" + formatter.localizedString(for: last, relativeTo: .now)
            + " · 最多检查最近更新的 \(25) 个收藏"
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 28))
                .foregroundStyle(DS.success)
            Text(monitor.lastScanAt == nil ? "等待第一次扫描" : "收藏项目都很健康")
                .font(DS.Typo.bodySmall)
                .foregroundStyle(DS.textSecondary)
            Text("扫描会检查是否已归档、最近提交时间与未关闭 issue 数量。")
                .font(.system(size: 10))
                .foregroundStyle(DS.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Space.l)
    }

    private func row(_ finding: HealthFinding) -> some View {
        HStack(spacing: DS.Space.s) {
            Text(finding.severityText)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(tint(for: finding.severity)))

            VStack(alignment: .leading, spacing: 2) {
                Text(finding.displayName)
                    .font(DS.Typo.bodySmall)
                    .foregroundStyle(DS.textPrimary)
                    .lineLimit(1)
                Text(finding.reason)
                    .font(.system(size: 10))
                    .foregroundStyle(DS.textTertiary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Menu {
                Button {
                    vault.setMark(id: finding.repoID, to: .archived)
                    env.show("已标记归档", kind: .success)
                } label: {
                    Label("标记为归档", systemImage: "archivebox")
                }
                Button(role: .destructive) {
                    vault.remove(id: finding.repoID)
                    env.show("已从收藏移除", kind: .warning)
                } label: {
                    Label("从收藏移除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(DS.textTertiary)
                    .frame(width: 30, height: 30)
            }
        }
        .padding(DS.Space.m)
        .glassSurface(radius: DS.Radius.button)
    }

    private func tint(for severity: Int) -> Color {
        switch severity {
        case 3: return DS.danger
        case 2: return DS.warning
        default: return DS.textTertiary
        }
    }
}
