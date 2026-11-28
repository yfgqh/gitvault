//
//  HeroRepoCard.swift
//  GitVault
//
//  「今日精选」大卡片：渐变封面 + 玻璃信息层 + 收藏爱心粒子动画。
//

import SwiftUI

struct HeroRepoCard: View {
    let repo: ShowcaseRepo
    var isSaved: Bool = false
    var onToggleSave: () -> Void = {}

    @State private var heartBurst = false
    /// 项目介绍图（README 首图）；拿不到时保留渐变
    @State private var previewURL: URL?

    private var ownerAvatar: some View {
        AvatarView(
            url: repo.avatarURL,
            size: 20,
            initials: repo.initials,
            gradient: repo.gradient
        )
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // 底色：渐变（无图时直接用）
            LinearGradient(
                colors: repo.gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 有项目图就铺满；上面压一层从透明到深的遮罩，保证文字可读
            if let previewURL {
                FilledRemoteImage(url: previewURL, cornerRadius: 0) {
                    LinearGradient(
                        colors: repo.gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .overlay(
                    LinearGradient(
                        colors: [Color.black.opacity(0.10), Color.black.opacity(0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            } else {
                // 装饰性光斑只在纯渐变时出现
                Circle()
                    .fill(Color.white.opacity(0.20))
                    .frame(width: 180, height: 180)
                    .blur(radius: 60)
                    .offset(x: 120, y: -60)
            }

            // 顶部标签
            VStack {
                HStack {
                    TagChip(
                        text: "今日精选",
                        systemImage: "sparkles",
                        tint: .white,
                        filled: false,
                        compact: true
                    )
                    Spacer()
                    saveButton
                }
                Spacer()
            }
            .padding(DS.Space.m)

            // 底部信息层
            VStack(alignment: .leading, spacing: DS.Space.s) {
                HStack(spacing: 8) {
                    ownerAvatar
                    Text(repo.owner)
                        .font(DS.Typo.caption)
                        .foregroundStyle(.white.opacity(0.75))
                    Text("·")
                        .foregroundStyle(.white.opacity(0.4))
                    Label(repo.category.title, systemImage: repo.category.symbol)
                        .font(DS.Typo.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }

                Text(repo.name)
                    .font(.system(.title, design: .default).weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(repo.summary)
                    .font(DS.Typo.bodySmall)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Label(repo.starText, systemImage: "star.fill")
                    Label(repo.forkText, systemImage: "arrow.triangle.branch")
                    if repo.starDeltaToday > 0 {
                        Text("🔥 +\(repo.starDeltaToday)")
                            .font(DS.Typo.micro)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(.white.opacity(0.18)))
                    }
                }
                .font(DS.Typo.caption)
                .foregroundStyle(.white.opacity(0.9))
            }
            .padding(DS.Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.cardLarge, style: .continuous))
        .dsShadow(.elevated)
        .task(id: repo.id) {
            guard previewURL == nil else { return }
            previewURL = await RepoImageService.shared.previewImage(owner: repo.owner, name: repo.name)
        }
    }

    private var saveButton: some View {
        Button {
            Haptics.medium()
            if !isSaved {
                heartBurst = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    heartBurst = false
                }
            }
            onToggleSave()
        } label: {
            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Circle().fill(DS.glassFill))
                .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                .overlay { HeartBurst(active: heartBurst) }
        }
        .buttonStyle(.springPressSilent)
        .accessibilityLabel(isSaved ? String(format: NSLocalizedString("取消收藏 %@", comment: ""), repo.name) : String(format: NSLocalizedString("收藏 %@", comment: ""), repo.name))
    }
}

/// 收藏时的爱心粒子扩散：8 个粒子沿圆周弹开并淡出
struct HeartBurst: View {
    var active: Bool
    private let count = 8

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { index in
                let angle = Double(index) / Double(count) * 2 * .pi
                Image(systemName: "heart.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(DS.accentAlt)
                    .offset(
                        x: active ? CGFloat(cos(angle)) * 26 : 0,
                        y: active ? CGFloat(sin(angle)) * 26 : 0
                    )
                    .opacity(active ? 0 : 1)
                    .scaleEffect(active ? 0.3 : 0.01)
            }
        }
        .animation(.easeOut(duration: 0.6), value: active)
        .allowsHitTesting(false)
    }
}

#Preview("精选大卡") {
    ZStack {
        DS.bgPrimary.ignoresSafeArea()
        HeroRepoCard(repo: MockData.repos[0], isSaved: false)
            .padding()
    }
}
