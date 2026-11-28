//
//  Shimmer.swift
//  GitVault
//
//  骨架屏公共件：从左到右循环扫光 + 与真实布局一致骨架块。
//

import SwiftUI

// MARK: - 扫光

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1.0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.16),
                            Color.white.opacity(0.28),
                            Color.white.opacity(0.16),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: max(geo.size.width * 0.55, 60))
                    .offset(x: phase * (geo.size.width + 120) - 60)
                }
                .mask(content)
                .allowsHitTesting(false)
            )
            .onAppear {
                phase = -1
                withAnimation(.linear(duration: 1.35).repeatForever(autoreverses: false)) {
                    phase = 1.2
                }
            }
            .accessibilityHidden(true)
    }
}

extension View {
    /// 从左到右循环扫光（用于骨架块）
    func shimmering() -> some View { modifier(ShimmerModifier()) }
}

// MARK: - 骨架块

struct SkeletonBlock: View {
    var width: CGFloat? = nil
    var height: CGFloat = 12
    var radius: CGFloat = 6

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(DS.bgTertiary)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
}

/// 详情页骨架：形状与真实页面一致（大标题 / 指标卡 / 摘要卡），
/// 数据回来后用 ZStack 交叉淡入，布局不发生跳动。
struct DetailSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.l) {
            // 大标题区
            VStack(alignment: .leading, spacing: 10) {
                SkeletonBlock(width: 90, height: 11)
                SkeletonBlock(width: 210, height: 30, radius: 10)
                HStack(spacing: 6) {
                    SkeletonBlock(width: 72, height: 22, radius: 11)
                    SkeletonBlock(width: 64, height: 22, radius: 11)
                    SkeletonBlock(width: 80, height: 22, radius: 11)
                }
                SkeletonBlock(height: 12)
                SkeletonBlock(width: 240, height: 12)
            }
            .screenPadding()
            .shimmering()

            // 指标卡
            HStack(spacing: DS.Space.m) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(spacing: 8) {
                        SkeletonBlock(width: 44, height: 18, radius: 6)
                        SkeletonBlock(width: 30, height: 9)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Space.m)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                            .fill(DS.bgSecondary)
                    )
                }
            }
            .screenPadding()
            .shimmering()

            // 摘要卡
            VStack(alignment: .leading, spacing: 10) {
                SkeletonBlock(width: 100, height: 12)
                ForEach(0..<4, id: \.self) { index in
                    SkeletonBlock(width: index == 3 ? 180 : nil, height: 10)
                }
                SkeletonBlock(width: 120, height: 22, radius: 11)
            }
            .padding(DS.Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(DS.bgSecondary)
            )
            .screenPadding()
            .shimmering()

            Spacer(minLength: 0)
        }
        .padding(.top, DS.Space.s)
    }
}
