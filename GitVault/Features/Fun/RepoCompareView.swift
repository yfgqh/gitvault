//
//  RepoCompareView.swift
//  GitVault
//
//  仓库对比：从收藏里挑 2–3 个，并排比较星标、活跃度、许可与健康分。
//

import SwiftUI

struct RepoCompareView: View {
    @EnvironmentObject private var vault: VaultStore
    @Environment(\.dismiss) private var dismiss

    @State private var selected: [String] = []

    private var picked: [VaultItem] {
        selected.compactMap { id in vault.items.first { $0.repoID == id } }
    }

    private let metrics: [(String, (VaultItem) -> String)] = [
        ("星标", { $0.stars >= 1000 ? String(format: "%.1fk", Double($0.stars) / 1000) : "\($0.stars)" }),
        ("Fork", { $0.forks >= 1000 ? String(format: "%.1fk", Double($0.forks) / 1000) : "\($0.forks)" }),
        ("语言", { $0.language }),
        ("许可", { $0.license.title }),
        ("主题", { $0.category.title }),
        ("最近更新", { item in
            guard let date = item.updatedAt else { return "未知" }
            let days = Int(Date().timeIntervalSince(date) / 86_400)
            return days <= 0 ? "今天" : "\(days) 天前"
        }),
        ("健康分", { item in
            "\(RepoHealthCalculator.evaluate(ShowcaseRepo(entry: item)).score)" }
        )
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    if picked.isEmpty {
                        picker
                    } else {
                        comparison
                        picker
                    }
                }
                .padding(DS.Space.l)
            }
            .background(DS.bgPrimary)
            .navigationTitle("仓库对比")
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

    // MARK: 对比表

    private var comparison: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("指标")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.textTertiary)
                    .frame(width: 70, alignment: .leading)

                ForEach(picked) { item in
                    VStack(spacing: 2) {
                        Text(item.name)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(DS.textPrimary)
                            .lineLimit(1)
                        Text(item.owner)
                            .font(.system(size: 9))
                            .foregroundStyle(DS.textTertiary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, DS.Space.s)

            ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                Divider()
                HStack(spacing: 0) {
                    Text(metric.0)
                        .font(.system(size: 11))
                        .foregroundStyle(DS.textTertiary)
                        .frame(width: 70, alignment: .leading)

                    ForEach(picked) { item in
                        Text(metric.1(item))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DS.textSecondary)
                            .frame(maxWidth: .infinity)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .padding(.vertical, 9)
            }
        }
        .padding(.horizontal, DS.Space.s)
        .glassSurface()
    }

    // MARK: 选择器

    private var picker: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Text(picked.isEmpty ? "选择 2–3 个收藏开始对比" : "再选 1–2 个")
                .font(DS.Typo.headline)
                .foregroundStyle(DS.textPrimary)

            if vault.items.isEmpty {
                Text("先去发现页收藏几个项目吧")
                    .font(DS.Typo.caption)
                    .foregroundStyle(DS.textTertiary)
                    .padding(.vertical, DS.Space.l)
            } else {
                VStack(spacing: DS.Space.s) {
                    ForEach(vault.items) { item in
                        row(item)
                    }
                }
            }
        }
    }

    private func row(_ item: VaultItem) -> some View {
        let isOn = selected.contains(item.repoID)
        return Button {
            Haptics.selection()
            withAnimation(DS.Motion.snappy) {
                if isOn {
                    selected.removeAll { $0 == item.repoID }
                } else if selected.count < 3 {
                    selected.append(item.repoID)
                } else {
                    selected.removeFirst()
                    selected.append(item.repoID)
                }
            }
        } label: {
            HStack(spacing: DS.Space.s) {
                AvatarView(url: URL(string: item.avatarURL ?? ""),
                           size: 30,
                           initials: String(item.name.prefix(2)).uppercased(),
                           gradient: item.category.gradient)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(DS.Typo.bodySmall)
                        .foregroundStyle(DS.textPrimary)
                        .lineLimit(1)
                    Text("★ \(item.stars) · \(item.language)")
                        .font(.system(size: 10))
                        .foregroundStyle(DS.textTertiary)
                }

                Spacer(minLength: 0)

                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(isOn ? DS.accent : DS.textTertiary)
            }
            .padding(DS.Space.s)
            .glassSurface(radius: DS.Radius.button)
        }
        .buttonStyle(.springPressSilent)
    }
}
