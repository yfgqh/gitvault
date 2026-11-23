//
//  BadgesView.swift
//  GitVault
//
//  成就徽章墙：本地计算，解锁状态一目了然。
//

import SwiftUI

struct BadgesView: View {
    @EnvironmentObject private var vault: VaultStore
    @Environment(\.dismiss) private var dismiss

    private var achievements: [Achievement] {
        Gamification.achievements(items: vault.items)
    }

    private var unlockedCount: Int {
        achievements.filter { $0.unlocked }.count
    }

    private let columns = [GridItem(.flexible(), spacing: DS.Space.m),
                           GridItem(.flexible(), spacing: DS.Space.m)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    summary

                    LazyVGrid(columns: columns, spacing: DS.Space.m) {
                        ForEach(achievements) { item in
                            badgeCell(item)
                        }
                    }
                }
                .padding(DS.Space.l)
            }
            .background(DS.bgPrimary)
            .navigationTitle("成就")
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
                    .trim(from: 0, to: CGFloat(unlockedCount) / CGFloat(max(achievements.count, 1)))
                    .stroke(DS.accentGradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(unlockedCount)/\(achievements.count)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.textPrimary)
            }
            .frame(width: 62, height: 62)

            VStack(alignment: .leading, spacing: 3) {
                Text(unlockedCount == 0 ? "还没有解锁徽章" : String(format: NSLocalizedString("已解锁 %d 枚徽章", comment: ""), unlockedCount))
                    .font(DS.Typo.headline)
                    .foregroundStyle(DS.textPrimary)
                Text("收藏越多、主题越广，能解锁的徽章越多")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Space.m)
        .glassSurface()
    }

    private func badgeCell(_ item: Achievement) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            ZStack {
                Circle()
                    .fill(item.unlocked ? item.tint.opacity(0.16) : DS.bgSecondary)
                    .frame(width: 44, height: 44)
                Image(systemName: item.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(item.unlocked ? item.tint : DS.textTertiary)
            }

            Text(item.title)
                .font(DS.Typo.body)
                .foregroundStyle(item.unlocked ? DS.textPrimary : DS.textSecondary)

            Text(item.detail)
                .font(.system(size: 10))
                .foregroundStyle(DS.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                Image(systemName: item.unlocked ? "checkmark.circle.fill" : "circle.dotted")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(item.unlocked ? DS.success : DS.textTertiary)
                Text(item.unlocked ? "已解锁" : item.progressText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(item.unlocked ? DS.success : DS.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 152, alignment: .topLeading)
        .padding(DS.Space.m)
        .glassSurface()
        .opacity(item.unlocked ? 1 : 0.72)
    }
}
