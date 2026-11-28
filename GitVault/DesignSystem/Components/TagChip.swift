//
//  TagChip.swift
//  GitVault
//
//  标签胶囊：状态 / 语言 / 用途 / 许可 / 我的标记 共用一套视觉。
//

import SwiftUI

struct TagChip: View {
    var text: String
    var systemImage: String? = nil
    var tint: Color = DS.textSecondary
    var filled: Bool = false
    var compact: Bool = false

    var body: some View {
        HStack(spacing: DS.Space.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: compact ? 9 : 10, weight: .bold))
            }
            Text(text)
                .font(compact ? DS.Typo.micro : DS.Typo.caption)
                .lineLimit(1)
        }
        .foregroundStyle(filled ? Color.white : tint)
        .padding(.horizontal, compact ? DS.Space.s : 10)
        .padding(.vertical, compact ? 3 : 5)
        .background {
            if filled {
                Capsule().fill(tint)
            } else {
                Capsule().fill(tint.opacity(0.12))
            }
        }
        .overlay(
            Capsule().strokeBorder(tint.opacity(filled ? 0 : 0.18), lineWidth: 1)
        )
    }
}

/// 可点击的筛选 Chip（搜索页、分类页顶部筛选栏）
struct FilterChip: View {
    var title: String
    var emoji: String? = nil
    var systemImage: String? = nil
    var isActive: Bool
    var action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.selection()
            action()
        }) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .semibold))
                } else if let emoji {
                    Text(emoji).font(.system(size: 12))
                }
                Text(title)
                    .font(DS.Typo.caption)
            }
            .foregroundStyle(isActive ? Color.white : DS.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                if isActive {
                    Capsule().fill(DS.accentSolid)
                } else {
                    Capsule().fill(DS.bgTertiary)
                }
            }
            .overlay(
                Capsule().strokeBorder(
                    isActive ? Color.clear : DS.separator,
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.springPressSilent)
        .animation(DS.Motion.snappy, value: isActive)
    }
}

/// 语言小圆点
struct LanguageDot: View {
    var color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
    }
}

#Preview("标签") {
    ZStack {
        DS.bgPrimary.ignoresSafeArea()
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                TagChip(text: "🔥 飙升中", tint: .orange)
                TagChip(text: "Swift", systemImage: "swift", tint: DS.accent)
                TagChip(text: "MIT", tint: DS.success)
                TagChip(text: "⭐ 收藏", tint: DS.accentAlt, filled: true)
            }
            HStack(spacing: 8) {
                FilterChip(title: "全部", isActive: true) {}
                FilterChip(title: "Swift", emoji: "🦅", isActive: false) {}
                FilterChip(title: "Rust", emoji: "🦀", isActive: false) {}
            }
        }
        .padding()
    }
}
