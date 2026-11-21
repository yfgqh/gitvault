//
//  VaultHealthView.swift
//  GitVault
//
//  收藏库体检：找出「长期未更新」「issue 积压」「许可缺失」的项目，支持一键归档。
//

import SwiftUI

struct VaultHealthIssue: Identifiable {
    enum Kind {
        case stale, backlog, noLicense, archivedHint

        var title: String {
            switch self {
            case .stale: return "半年未更新"
            case .backlog: return "issue 积压"
            case .noLicense: return "缺少许可证"
            case .archivedHint: return "可能已停更"
            }
        }
        var tint: Color {
            switch self {
            case .stale: return DS.warning
            case .backlog: return DS.danger
            case .noLicense: return DS.accentAlt
            case .archivedHint: return DS.textTertiary
            }
        }
        var symbol: String {
            switch self {
            case .stale: return "clock.badge.exclamationmark"
            case .backlog: return "exclamationmark.bubble"
            case .noLicense: return "doc.questionmark"
            case .archivedHint: return "archivebox"
            }
        }
    }

    let id: String
    let item: VaultItem
    let kind: Kind
    let detail: String
}

enum VaultHealthScanner {
    static func scan(_ items: [VaultItem]) -> [VaultHealthIssue] {
        var issues: [VaultHealthIssue] = []
        let now = Date()

        for item in items {
            if let updated = item.updatedAt {
                let days = Int(now.timeIntervalSince(updated) / 86_400)
                if days >= 365 {
                    issues.append(VaultHealthIssue(
                        id: "\(item.repoID)-archived",
                        item: item,
                        kind: .archivedHint,
                        detail: "已 \(days / 30) 个月没有推送，可能已停止维护"
                    ))
                    continue
                }
                if days >= 180 {
                    issues.append(VaultHealthIssue(
                        id: "\(item.repoID)-stale",
                        item: item,
                        kind: .stale,
                        detail: "最近一次推送在 \(days) 天前"
                    ))
                }
            }


            if item.license == .none {
                issues.append(VaultHealthIssue(
                    id: "\(item.repoID)-license",
                    item: item,
                    kind: .noLicense,
                    detail: "未声明开源许可，商用前需确认"
                ))
            }
        }
        return issues.sorted { lhs, rhs in
            if lhs.item.name == rhs.item.name { return lhs.kind.title < rhs.kind.title }
            return lhs.item.name < rhs.item.name
        }
    }
}

struct VaultHealthView: View {
    @EnvironmentObject private var vault: VaultStore
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var filter: VaultHealthIssue.Kind?

    private var issues: [VaultHealthIssue] {
        let all = VaultHealthScanner.scan(vault.items)
        guard let filter else { return all }
        return all.filter { $0.kind.title == filter.title }
    }

    private var kinds: [VaultHealthIssue.Kind] {
        [.stale, .archivedHint, .noLicense]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    summary

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DS.Space.s) {
                            chip(title: "全部 \(issues.count)", active: filter == nil) { filter = nil }
                            ForEach(Array(kinds.enumerated()), id: \.offset) { _, kind in
                                let count = VaultHealthScanner.scan(vault.items).filter { $0.kind.title == kind.title }.count
                                chip(title: "\(kind.title) \(count)", active: filter?.title == kind.title) {
                                    filter = kind
                                }
                            }
                        }
                        .padding(.horizontal, DS.Space.l)
                    }

                    if issues.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(DS.success)
                            Text("收藏库很健康")
                                .font(DS.Typo.body)
                                .foregroundStyle(DS.textSecondary)
                            Text("没有发现长期停更或许可缺失的项目")
                                .font(.system(size: 11))
                                .foregroundStyle(DS.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Space.l)
                    } else {
                        VStack(spacing: DS.Space.s) {
                            ForEach(issues) { issue in
                                issueRow(issue)
                            }
                        }
                        .padding(.horizontal, DS.Space.l)
                    }
                }
                .padding(.vertical, DS.Space.m)
            }
            .background(DS.bgPrimary)
            .navigationTitle("收藏库体检")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.accent)
                }
            }
        }
    }

    private var summary: some View {
        HStack(spacing: DS.Space.m) {
            ZStack {
                Circle().stroke(DS.bgTertiary, lineWidth: 6)
                Circle()
                    .trim(from: 0, to: healthRatio)
                    .stroke(DS.accentGradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(healthRatio * 100))")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.textPrimary)
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 3) {
                Text("健康度 \(Int(healthRatio * 100)) 分")
                    .font(DS.Typo.headline)
                    .foregroundStyle(DS.textPrimary)
                Text("共 \(vault.items.count) 个收藏，发现 \(VaultHealthScanner.scan(vault.items).count) 处可优化项")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Space.m)
        .glassSurface()
        .padding(.horizontal, DS.Space.l)
    }

    private var healthRatio: Double {
        guard !vault.items.isEmpty else { return 1 }
        let issueCount = VaultHealthScanner.scan(vault.items).count
        return max(0, 1 - Double(issueCount) / Double(max(vault.items.count, 1)))
    }

    private func chip(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            withAnimation(DS.Motion.snappy) { action() }
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(active ? .white : DS.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(active ? AnyShapeStyle(DS.accentGradient) : AnyShapeStyle(DS.bgSecondary))
                )
        }
        .buttonStyle(.springPressSilent)
    }

    private func issueRow(_ issue: VaultHealthIssue) -> some View {
        HStack(spacing: DS.Space.s) {
            Image(systemName: issue.kind.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(issue.kind.tint)
                .frame(width: 30, height: 30)
                .background(Circle().fill(issue.kind.tint.opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                Text(issue.item.name)
                    .font(DS.Typo.body)
                    .foregroundStyle(DS.textPrimary)
                    .lineLimit(1)
                Text(issue.detail)
                    .font(.system(size: 10))
                    .foregroundStyle(DS.textTertiary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Menu {
                Button {
                    vault.setMark(id: issue.item.repoID, to: .archived)
                    env.show("已归档：\(issue.item.name)", kind: .success)
                } label: {
                    Label("标记为归档", systemImage: "archivebox")
                }
                Button(role: .destructive) {
                    vault.remove(id: issue.item.repoID)
                    env.show("已移除：\(issue.item.name)")
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
}
