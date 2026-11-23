//
//  StarSyncView.swift
//  GitVault
//
//  Star 双向同步面板：从 GitHub 导入 starred，并把本地收藏回写为 star。
//

import SwiftUI

struct StarSyncView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var vault: VaultStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @StateObject private var sync = StarSyncService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    header
                    stats
                    actionArea
                    explanation
                }
                .padding(DS.Space.l)
            }
            .background(DS.bgPrimary)
            .navigationTitle("Star 同步")
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(MyMark.starred.tint)
                Text("与 GitHub 双向同步")
                    .font(DS.Typo.cardTitle)
                    .foregroundStyle(DS.textPrimary)
            }
            Text(lastSyncText)
                .font(.system(size: 11))
                .foregroundStyle(DS.textTertiary)
        }
        .padding(DS.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface()
    }

    private var lastSyncText: String {
        guard let last = sync.lastSyncAt else { return "还没有同步过" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return "上次同步：" + formatter.localizedString(for: last, relativeTo: .now)
    }

    private var stats: some View {
        HStack(spacing: 0) {
            stat(value: "\(vault.items.count)", title: "本地收藏")
            Divider().frame(height: 26)
            stat(value: "\(vault.githubStarredCount)", title: "已同步 star")
            Divider().frame(height: 26)
            stat(value: "\(vault.itemsNeedingStarPush().count)", title: "待回写")
        }
        .padding(.vertical, DS.Space.m)
        .glassSurface()
    }

    private func stat(value: String, title: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(DS.textPrimary)
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(DS.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var actionArea: some View {
        switch sync.phase {
        case .fetching(let page, let total):
            progressBox("正在读取 GitHub star：第 \(page) 页，已取 \(total) 个")
        case .merging:
            progressBox("正在合并到本地收藏…")
        case .pushing(let done, let total):
            progressBox("正在回写 star：\(done)/\(total)")
        case .finished(let result):
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DS.success)
                    Text("同步完成")
                        .font(DS.Typo.headline)
                        .foregroundStyle(DS.textPrimary)
                }
                Text("导入 \(result.imported) 个 · 回写 \(result.pushed) 个 · 已存在 \(result.skipped) 个 · 失败 \(result.failed) 个")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    sync.reset()
                } label: {
                    Text("再同步一次")
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(DS.Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface()
        case .failed(let message):
            VStack(alignment: .leading, spacing: 6) {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(DS.warning)
                Button {
                    sync.reset()
                } label: {
                    Text("重试")
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(DS.Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface()
        case .idle:
            Button {
                Haptics.tap()
                Task {
                    await sync.sync(vault: vault) { dto in
                        RepoCategory.infer(fromTopics: dto.topics ?? [],
                                           description: dto.description,
                                           language: dto.language)
                    }
                    env.show("Star 同步已结束", kind: .success)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12, weight: .bold))
                    Text("开始同步")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Capsule().fill(DS.accentGradient))
            }
            .buttonStyle(.springPress)
        }
    }

    private func progressBox(_ text: String) -> some View {
        HStack(spacing: 8) {
            ProgressView().scaleEffect(0.7).tint(DS.accent)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(DS.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(DS.Space.m)
        .glassSurface()
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("说明")
                .font(DS.Typo.caption)
                .foregroundStyle(DS.textSecondary)
            Text("· 导入时保留你已有的分类、标记与笔记，不会覆盖")
                .font(.system(size: 10))
                .foregroundStyle(DS.textTertiary)
            Text("· 本地收藏但 GitHub 上没 star 的，会自动补上 star")
                .font(.system(size: 10))
                .foregroundStyle(DS.textTertiary)
            Text("· 单次最多读取 2000 个 star、回写 40 个，避免触发限流")
                .font(.system(size: 10))
                .foregroundStyle(DS.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
