//
//  Logos.swift
//  GitVault
//
//  品牌图形：渐变 Logo 标记 + 项目封面渐变底。
//

import SwiftUI

/// App 品牌标记：墨黑圆角方块 + 渐变环形「保险库」封印
struct GBLogoMark: View {
    var size: CGFloat = 72
    var glow: Bool = true

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(DS.logoBase)

            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [DS.accent, DS.accentAlt, DS.accent, DS.accentAlt],
                        center: .center
                    ),
                    lineWidth: size * 0.10
                )
                .padding(size * 0.20)
                .overlay(
                    Circle()
                        .fill(DS.accentGradient)
                        .frame(width: size * 0.13, height: size * 0.13)
                )
        }
        .frame(width: size, height: size)
        .shadow(
            color: glow ? DS.accent.opacity(0.55) : .clear,
            radius: glow ? size * 0.28 : 0,
            x: 0,
            y: size * 0.10
        )
    }
}

/// 项目封面：品牌渐变 + 右下角柔光 + 首字母水印
struct RepoCover: View {
    let initials: String
    let gradient: [Color]
    var cornerRadius: CGFloat = DS.Radius.cover
    var showsGlyph: Bool = true

    var body: some View {
        ZStack {
            LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)

            // 右下角柔光，让纯渐变不至于死板
            Circle()
                .fill(Color.white.opacity(0.22))
                .frame(width: 90, height: 90)
                .blur(radius: 34)
                .offset(x: 34, y: 34)

            if showsGlyph {
                Text(initials)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

#Preview("品牌标记") {
    ZStack {
        DS.bgPrimary.ignoresSafeArea()
        VStack(spacing: 32) {
            GBLogoMark(size: 96)
            HStack(spacing: 16) {
                RepoCover(initials: "LL", gradient: RepoCategory.ai.gradient, cornerRadius: 18)
                    .frame(width: 64, height: 64)
                RepoCover(initials: "Ru", gradient: RepoCategory.tooling.gradient, cornerRadius: 18)
                    .frame(width: 64, height: 64)
            }
        }
    }
}
