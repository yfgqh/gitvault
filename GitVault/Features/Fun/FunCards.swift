//
//  FunCards.swift
//  GitVault
//
//  趣味模块的展示组件：今日考古、项目体检、更新横幅。
//

import SwiftUI

// MARK: 今日考古

struct TodayArchiveCard: View {
    let item: VaultItem
    let daysAgo: Int

    var body: some View {
        content
    }

    private var content: some View {
            HStack(spacing: DS.Space.m) {
                AvatarView(url: URL(string: item.avatarURL ?? ""),
                           size: 42,
                           initials: String(item.name.prefix(2)).uppercased(),
                           gradient: item.category.gradient)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(DS.accent)
                        Text(daysAgo <= 0 ? NSLocalizedString("今天收藏的", comment: "") : String(format: NSLocalizedString("%d 天前收藏的", comment: ""), daysAgo))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DS.accent)
                    }
                    Text(item.name)
                        .font(DS.Typo.body)
                        .foregroundStyle(DS.textPrimary)
                        .lineLimit(1)
                    Text(item.summary)
                        .font(.system(size: 11))
                        .foregroundStyle(DS.textTertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DS.textTertiary)
            }
            .padding(DS.Space.m)
            .glassSurface(radius: DS.Radius.card)
    }
}

// MARK: 项目体检

struct HealthCard: View {
    let repo: ShowcaseRepo

    private var health: RepoHealth { RepoHealthCalculator.evaluate(repo) }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            HStack(spacing: DS.Space.s) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(health.level.tint)
                Text("项目体检")
                    .font(DS.Typo.headline)
                    .foregroundStyle(DS.textPrimary)
                Spacer()
                Text(health.level.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(health.level.tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(health.level.tint.opacity(0.14)))
            }

            HStack(spacing: DS.Space.m) {
                ScoreDial(score: health.score, tint: health.level.tint)
                    .frame(width: 62, height: 62)

                VStack(alignment: .leading, spacing: 6) {
                    metricRow("活跃度", health.activity, total: 40, tint: DS.accent)
                    metricRow("社区", health.community, total: 25, tint: DS.accentAlt)
                    metricRow("维护", health.maintenance, total: 20, tint: DS.warning)
                    metricRow("文档", health.documentation, total: 15, tint: DS.success)
                }
            }

            Text(health.verdict)
                .font(.system(size: 11))
                .foregroundStyle(DS.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Space.m)
        .glassSurface()
    }

    private func metricRow(_ title: String, _ value: Int, total: Int, tint: Color) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(DS.textTertiary)
                .frame(width: 34, alignment: .leading)
            ProgressView(value: Double(value), total: Double(Swift.max(total, 1)))
                .progressViewStyle(.linear)
                .tint(tint)
                .scaleEffect(x: 1, y: 0.55, anchor: .center)
            Text("\(value)")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(DS.textSecondary)
                .frame(width: 16, alignment: .trailing)
        }
    }
}

struct ScoreDial: View {
    let score: Int
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(DS.bgTertiary, lineWidth: 6)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(score, 0), 100)) / 100)
                .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.textPrimary)
                Text("分")
                    .font(.system(size: 8))
                    .foregroundStyle(DS.textTertiary)
            }
        }
    }
}

// MARK: 更新横幅

struct UpdateBanner: View {
    let available: UpdateChecker.Available
    let onOpen: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: DS.Space.s) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DS.accent)

            VStack(alignment: .leading, spacing: 1) {
                Text(String(format: NSLocalizedString("发现新版本 %@", comment: ""), available.tag))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.textPrimary)
                Text("点此查看更新说明")
                    .font(.system(size: 10))
                    .foregroundStyle(DS.textTertiary)
            }

            Spacer(minLength: 0)

            Button {
                Haptics.tap()
                onOpen()
            } label: {
                Text("去看看")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(DS.accent))
            }
            .buttonStyle(.springPressSilent)

            Button {
                Haptics.tap()
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DS.textTertiary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DS.Space.m)
        .padding(.vertical, DS.Space.s)
        .glassSurface(radius: DS.Radius.button)
        .screenPadding()
    }
}

// MARK: 远程图片（复用自建缓存，避免 AsyncImage 闪烁）

struct RemoteImage: View {
    let url: URL?
    var height: CGFloat = 160
    var cornerRadius: CGFloat = DS.Radius.card

    @StateObject private var loader = RemoteImageLoader()

    var body: some View {
        ZStack {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    DS.bgSecondary
                    Image(systemName: "photo")
                        .font(.system(size: 20))
                        .foregroundStyle(DS.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear { loader.load(url) }
        .onChange(of: url) { newValue in loader.load(newValue) }
    }
}