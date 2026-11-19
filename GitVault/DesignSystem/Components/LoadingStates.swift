//
//  LoadingStates.swift
//  GitVault
//
//  骨架屏 + 错误横幅：首屏不闪白、失败可重试。
//

import SwiftUI

/// 仓库卡骨架屏
struct RepoCardSkeleton: View {
    @State private var shimmer = false

    var body: some View {
        HStack(alignment: .top, spacing: DS.Space.m) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DS.bgTertiary)
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 8) {
                bar(width: 120, height: 14)
                bar(width: nil, height: 10)
                bar(width: 200, height: 10)
                HStack(spacing: 8) {
                    bar(width: 44, height: 9)
                    bar(width: 32, height: 9)
                }
            }
        }
        .padding(DS.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(DS.bgSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(shimmer ? 0.05 : 0.015), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                shimmer = true
            }
        }
        .accessibilityHidden(true)
    }

    private func bar(width: CGFloat?, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(DS.bgTertiary)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
}

/// 骨架列表
struct SkeletonList: View {
    var count: Int = 3

    var body: some View {
        VStack(spacing: DS.Space.s) {
            ForEach(0..<count, id: \.self) { _ in
                RepoCardSkeleton()
            }
        }
    }
}

/// 错误横幅（带重试）
struct ErrorBanner: View {
    let message: String
    var onRetry: (() -> Void)?

    var body: some View {
        HStack(spacing: DS.Space.s) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.warning)

            Text(message)
                .font(DS.Typo.caption)
                .foregroundStyle(DS.textSecondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            if let onRetry {
                Button {
                    Haptics.tap()
                    onRetry()
                } label: {
                    Text("重试")
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(DS.accent.opacity(0.14)))
                }
                .buttonStyle(.springPressSilent)
            }
        }
        .padding(DS.Space.m)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                .fill(DS.bgSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                .strokeBorder(DS.warning.opacity(0.28), lineWidth: 1)
        )
    }
}

#Preview("加载与错误") {
    ZStack {
        DS.bgPrimary.ignoresSafeArea()
        VStack(spacing: 16) {
            ErrorBanner(message: "接口额度用完了，约 12 分钟后恢复") {}
            SkeletonList(count: 2)
        }
        .padding()
    }
}
