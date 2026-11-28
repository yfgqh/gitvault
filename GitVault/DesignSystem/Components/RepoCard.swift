//
//  RepoCard.swift
//  GitVault
//
//  仓库卡片（列表态 / 紧凑态），全 App 复用率最高的组件。
//

import SwiftUI

struct RepoCard: View {
    let repo: ShowcaseRepo
    var showsStarDelta: Bool = true
    var compact: Bool = false
    /// 发现页的推荐理由，例如「新项目 · 4 个月 · 日增 12 星」
    var reason: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: DS.Space.m) {
            AvatarView(
                url: repo.avatarURL,
                size: compact ? 44 : 56,
                initials: repo.initials,
                gradient: repo.gradient
            )

            VStack(alignment: .leading, spacing: 6) {
                // 标题行
                HStack(spacing: 6) {
                    Text(repo.name)
                        .font(compact ? DS.Typo.headline : DS.Typo.cardTitle)
                        .foregroundStyle(DS.textPrimary)
                        .lineLimit(1)

                    if showsStarDelta, repo.starDeltaToday > 0 {
                        Text("🔥+\(repo.starDeltaToday)")
                            .font(DS.Typo.micro)
                            .foregroundStyle(ActivityTag.rising.tint)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(ActivityTag.rising.tint.opacity(0.14))
                            )
                    }
                    Spacer(minLength: 0)
                }

                // 中文简介
                Text(repo.summary)
                    .font(compact ? DS.Typo.captionRegular : DS.Typo.bodySmall)
                    .foregroundStyle(DS.textSecondary)
                    .lineLimit(compact ? 1 : 2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                // 英文原描述：小一号、更淡，与中文摘要分开，避免中英混排
                if !compact,
                   let raw = repo.rawDescription,
                   !raw.isEmpty,
                   !SummaryService.containsCJK(raw) {
                    Text(raw)
                        .font(.system(size: 10))
                        .foregroundStyle(DS.textTertiary)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                }

                // 元信息行
                HStack(spacing: 10) {
                    if let reason, !reason.isEmpty {
                        Text(reason)
                            .font(DS.Typo.micro)
                            .foregroundStyle(DS.accent)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(DS.accent.opacity(0.12)))
                    }

                    HStack(spacing: 4) {
                        LanguageDot(color: LanguagePalette.color(for: repo.language))
                        Text(repo.language)
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.textSecondary)
                    }

                    Label(repo.starText, systemImage: "star.fill")
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.textTertiary)
                        .labelStyle(.titleAndIcon)

                    if !compact {
                        Label(repo.forkText, systemImage: "arrow.triangle.branch")
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.textTertiary)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(compact ? 12 : DS.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(DS.bgSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .strokeBorder(DS.separator, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
    }
}

/// 小尺寸卡片：用于「相似项目」「为你推荐」横向滑动
struct RepoMiniCard: View {
    let repo: ShowcaseRepo
    var reason: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            // 封面：优先用仓库图片（GitHub 社交卡），失败回退首字母灰底
            RemoteImage(url: RepoImageSource.openGraph(owner: repo.owner, name: repo.name)) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(DS.bgTertiary)
                    Text(repo.initials)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(DS.textSecondary)
                }
            }
            .frame(height: 84)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
            // 图片底部压一层暗色，保证分类角标始终可读
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.35)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(height: 34)
                .allowsHitTesting(false)
            }
            .overlay(alignment: .topTrailing) {
                Image(systemName: repo.category.symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(5)
                    .background(Circle().fill(Color.black.opacity(0.35)))
                    .padding(7)
            }

            Text(repo.name)
                .font(DS.Typo.headline)
                .foregroundStyle(DS.textPrimary)
                .lineLimit(1)

            Text(repo.summary)
                .font(DS.Typo.captionRegular)
                .foregroundStyle(DS.textSecondary)
                .lineLimit(2)
                .frame(height: 32, alignment: .top)

            if let reason, !reason.isEmpty {
                Text(reason)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(DS.accent)
                    .lineLimit(1)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(DS.accent.opacity(0.12)))
            }

            HStack(spacing: 6) {
                LanguageDot(color: LanguagePalette.color(for: repo.language))
                Text(repo.language)
                    .font(DS.Typo.micro)
                    .foregroundStyle(DS.textTertiary)
                Spacer(minLength: 0)
                Image(systemName: "star.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(DS.textTertiary)
                Text(repo.starText)
                    .font(DS.Typo.micro)
                    .foregroundStyle(DS.textTertiary)
            }
        }
        .padding(12)
        .frame(width: 176)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(DS.bgSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .strokeBorder(DS.separator, lineWidth: 1)
        )
    }
}

#Preview("仓库卡片") {
    ZStack {
        DS.bgPrimary.ignoresSafeArea()
        VStack(spacing: 16) {
            RepoCard(repo: MockData.repos[0])
            RepoCard(repo: MockData.repos[5], compact: true)
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    RepoMiniCard(repo: MockData.repos[3])
                    RepoMiniCard(repo: MockData.repos[9])
                }
            }
        }
        .padding()
    }
}
