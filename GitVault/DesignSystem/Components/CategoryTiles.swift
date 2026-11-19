//
//  CategoryTiles.swift
//  GitVault
//
//  分类的两种形态：首页胶囊快捷入口 + 分类页大卡片。
//

import SwiftUI

/// 首页「按主题浏览」胶囊入口
struct CategoryShortcut: View {
    let category: RepoCategory
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Text(category.emoji)
                .font(.system(size: 15))
            VStack(alignment: .leading, spacing: 0) {
                Text(category.title)
                    .font(DS.Typo.caption)
                    .foregroundStyle(DS.textPrimary)
                    .lineLimit(1)
                Text(count > 0 ? "\(count) 个项目" : "浏览 →")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(DS.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.chip + 4, style: .continuous)
                .fill(DS.bgSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.chip + 4, style: .continuous)
                .strokeBorder(DS.separator, lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(colors: category.gradient, startPoint: .top, endPoint: .bottom))
                .frame(width: 3)
                .padding(.vertical, 10)
                .padding(.leading, 1)
        }
    }
}

/// 分类页大卡片（2 列网格）
struct CategoryLargeCard: View {
    let category: RepoCategory
    let count: Int

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: category.gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.white.opacity(0.22))
                .frame(width: 110, height: 110)
                .blur(radius: 40)
                .offset(x: 60, y: -50)

            Image(systemName: category.symbol)
                .font(.system(size: 68, weight: .bold))
                .foregroundStyle(.white.opacity(0.12))
                .rotationEffect(.degrees(-12))
                .offset(x: 62, y: -18)

            VStack(alignment: .leading, spacing: 4) {
                Text(category.emoji)
                    .font(.system(size: 20))

                Text(category.title)
                    .font(DS.Typo.cardTitle)
                    .foregroundStyle(.white)

                Text(category.subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 0)

                Text("\(count) 个项目")
                    .font(DS.Typo.micro)
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.white.opacity(0.20)))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 172)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .dsShadow(.light)
    }
}

#Preview("分类形态") {
    ZStack {
        DS.bgPrimary.ignoresSafeArea()
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                CategoryShortcut(category: .ai, count: 3)
                CategoryShortcut(category: .frontend, count: 3)
            }
            HStack(spacing: 12) {
                CategoryLargeCard(category: .ai, count: 3)
                CategoryLargeCard(category: .backend, count: 2)
            }
        }
        .padding()
    }
}
