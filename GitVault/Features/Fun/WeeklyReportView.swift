//
//  WeeklyReportView.swift
//  GitVault
//
//  本周探索报告：新增收藏、主题分布、语言分布、开发者人格。
//  免费可见概览；明细与分享卡为 Pro 权益。
//

import SwiftUI

struct WeeklyReportView: View {
    @EnvironmentObject private var vault: VaultStore
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    private var stats: WeeklyStats { Gamification.weekly(items: vault.items) }
    private var persona: Persona { Gamification.persona(items: vault.items) }
    private var unlocked: Bool { env.pro.hasFullAccess }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    headlineCard
                    personaCard
                    breakdownSection
                    ProHintCard(unlocked: unlocked) {
                        dismiss()
                    }
                }
                .padding(DS.Space.l)
            }
            .background(DS.bgPrimary)
            .navigationTitle("探索报告")
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

    // MARK: 概览

    private var headlineCard: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            Text("最近 7 天")
                .font(DS.Typo.caption)
                .foregroundStyle(DS.textTertiary)

            Text(stats.headline)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(DS.textPrimary)

            HStack(spacing: DS.Space.l) {
                statItem("收藏总数", "\(stats.totalCount)")
                statItem("最活跃", stats.mostActiveDay)
                statItem("涉及主题", "\(stats.categories.count)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Space.m)
        .glassSurface()
    }

    private func statItem(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(DS.textPrimary)
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(DS.textTertiary)
        }
    }

    // MARK: 人格

    private var personaCard: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            HStack(spacing: DS.Space.m) {
                ZStack {
                    Circle().fill(persona.tint.opacity(0.14)).frame(width: 46, height: 46)
                    Image(systemName: persona.symbol)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(persona.tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("你的开发者人格")
                        .font(.system(size: 10))
                        .foregroundStyle(DS.textTertiary)
                    Text(persona.title)
                        .font(DS.Typo.cardTitle)
                        .foregroundStyle(DS.textPrimary)
                }
                Spacer(minLength: 0)
            }

            Text(persona.subtitle)
                .font(DS.Typo.bodySmall)
                .foregroundStyle(DS.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .blur(radius: unlocked ? 0 : 3.5)

            if !unlocked {
                Button {
                    Haptics.tap()
                    dismiss()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "lock.fill").font(.system(size: 9))
                        Text("Pro 解锁完整人格分析")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(DS.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DS.Space.m)
        .glassSurface()
    }

    // MARK: 明细

    @ViewBuilder
    private var breakdownSection: some View {
        if stats.categories.isEmpty {
            Text("本周还没有收藏，去「发现」逛逛吧")
                .font(DS.Typo.bodySmall)
                .foregroundStyle(DS.textTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, DS.Space.l)
        } else {
            VStack(alignment: .leading, spacing: DS.Space.m) {
                Text("主题分布")
                    .font(DS.Typo.headline)
                    .foregroundStyle(DS.textPrimary)

                ForEach(stats.categories) { slice in
                    barRow(title: "\(slice.emoji) \(slice.label)",
                           value: slice.value,
                           total: stats.categories.first?.value ?? 1,
                           tint: DS.accent,
                           locked: false)
                }

                Text("语言分布")
                    .font(DS.Typo.headline)
                    .foregroundStyle(DS.textPrimary)
                    .padding(.top, DS.Space.s)

                ForEach(stats.languages) { slice in
                    barRow(title: slice.label,
                           value: slice.value,
                           total: stats.languages.first?.value ?? 1,
                           tint: DS.accentAlt,
                           locked: !unlocked)
                }
            }
        }
    }

    private func barRow(title: String, value: Int, total: Int, tint: Color, locked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(DS.textSecondary)
                Spacer()
                Text("\(value)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.textTertiary)
            }
            ProgressView(value: Double(value), total: Double(Swift.max(total, 1)))
                .progressViewStyle(.linear)
                .tint(tint)
                .scaleEffect(x: 1, y: 0.7, anchor: .center)
                .blur(radius: locked ? 4 : 0)
        }
    }

    private func maximum(_ a: Int, _ b: Int) -> Int { a > b ? a : b }
}

// MARK: Pro 提示卡

struct ProHintCard: View {
    let unlocked: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            onTap()
        } label: {
            HStack(spacing: DS.Space.m) {
                Image(systemName: unlocked ? "checkmark.seal.fill" : "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(unlocked ? DS.success : DS.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(unlocked ? "Pro 已解锁" : "解锁 Pro · ¥9.9 终身")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DS.textPrimary)
                    Text(unlocked ? "感谢支持，全部功能已开放" : "无限 AI 翻译 · 报告明细 · 批量整理")
                        .font(.system(size: 10))
                        .foregroundStyle(DS.textTertiary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DS.textTertiary)
            }
            .padding(DS.Space.m)
            .glassSurface(radius: DS.Radius.button)
        }
        .buttonStyle(.springPressSilent)
    }
}
