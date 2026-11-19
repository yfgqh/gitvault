//
//  RepoDetailView.swift
//  GitVault
//
//  项目详情（阶段 1 的可运行外壳，阶段 3 打磨 README 摘要 / 语言占比 / Hero 转场）。
//

import SwiftUI

struct RepoDetailView: View {
    let repo: ShowcaseRepo

    @Environment(\.openURL) private var openURL
    @State private var isSaved = false
    @State private var mark: MyMark?
    @State private var readmeExpanded = false

    private var similar: [ShowcaseRepo] {
        MockData.repos
            .filter { $0.category == repo.category && $0.id != repo.id }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.l) {
                hero
                titleBlock.screenPadding()
                statsCard.screenPadding()
                readmeCard.screenPadding()
                tagsSection.screenPadding()
                similarSection

                Color.clear.frame(height: DS.Space.tabBarInset)
            }
        }
        .scrollIndicators(.hidden)
        .background(DS.bgPrimary)
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) { bottomBar }
        .overlay(alignment: .topLeading) { backButton }
    }

    // MARK: Hero

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: repo.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)

            Circle()
                .fill(.white.opacity(0.20))
                .frame(width: 220, height: 220)
                .blur(radius: 70)
                .offset(x: 130, y: -80)

            HStack(alignment: .bottom, spacing: DS.Space.m) {
                RepoCover(initials: repo.initials, gradient: repo.gradient, cornerRadius: 16, showsGlyph: true)
                    .frame(width: 64, height: 64)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(repo.owner)
                        .font(DS.Typo.caption)
                        .foregroundStyle(.white.opacity(0.75))
                    Text(repo.name)
                        .font(.system(.title2, design: .default).weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
            }
            .padding(DS.Space.screen)
        }
        .frame(height: 260)
        .clipShape(
            UnevenRoundedRectangle(
                bottomLeadingRadius: DS.Radius.sheet,
                bottomTrailingRadius: DS.Radius.sheet,
                style: .continuous
            )
        )
    }

    // MARK: 标题区

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            HStack(spacing: 6) {
                TagChip(text: repo.category.emoji + " " + repo.category.title, tint: repo.category.tint)
                TagChip(text: repo.activity.emoji + " " + repo.activity.title, tint: repo.activity.tint, filled: true)
                TagChip(text: repo.usage.emoji + " " + repo.usage.title, tint: repo.usage.tint)
            }

            Text(repo.summary)
                .font(DS.Typo.body)
                .foregroundStyle(DS.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: 数据卡

    private var statsCard: some View {
        VStack(spacing: DS.Space.m) {
            HStack(spacing: 0) {
                statCell("Star", value: repo.starText, symbol: "star.fill", tint: MyMark.starred.tint)
                Divider().frame(height: 32)
                statCell("Fork", value: repo.forkText, symbol: "arrow.triangle.branch", tint: DS.accent)
                Divider().frame(height: 32)
                statCell("Issue", value: "\(repo.openIssues)", symbol: "exclamationmark.circle", tint: DS.warning)
            }

            // 语言占比条（阶段 2 换成 /languages 接口的真实比例）
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(LanguagePalette.color(for: repo.language))
                            .frame(width: geo.size.width * 0.64)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(DS.bgTertiary)
                    }
                }
                .frame(height: 8)

                HStack(spacing: DS.Space.m) {
                    HStack(spacing: 5) {
                        LanguageDot(color: LanguagePalette.color(for: repo.language))
                        Text("\(repo.language) 64%")
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.textSecondary)
                    }
                    HStack(spacing: 5) {
                        LanguageDot(color: DS.textTertiary)
                        Text("其他 36%")
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.textTertiary)
                    }
                }
            }
        }
        .padding(DS.Space.m)
        .glassSurface()
    }

    private func statCell(_ title: String, value: String, symbol: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)
                Text(value)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.textPrimary)
            }
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DS.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: README 中文摘要

    private var readmeCard: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DS.accent)
                    Text("README 中文摘要")
                        .font(DS.Typo.headline)
                        .foregroundStyle(DS.textPrimary)
                    TagChip(text: "AI", tint: DS.accentAlt, compact: true)
                }
                Spacer()
                Button {
                    Haptics.tap()
                    withAnimation(DS.Motion.snappy) { readmeExpanded.toggle() }
                } label: {
                    Image(systemName: readmeExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DS.textTertiary)
                }
                .buttonStyle(.plain)
            }

            Text(readmeSummaryText)
                .font(DS.Typo.bodySmall)
                .foregroundStyle(DS.textSecondary)
                .lineLimit(readmeExpanded ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                Text("由本地规则摘要在阶段 2 生成，阶段 5 可切换大模型")
                    .font(.system(size: 10))
            }
            .foregroundStyle(DS.textTertiary)
        }
        .padding(DS.Space.m)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(DS.bgSecondary)
        )
    }

    private var readmeSummaryText: String {
        """
        \(repo.summary)

        它所属的方向是「\(repo.category.title)」：\(repo.category.subtitle)。
        项目采用 \(repo.license.title) 许可，主要用 \(repo.language) 编写，
        \(repo.usage.title == "可直接用" ? "上手成本低，可以直接接入现有工程" : "需要一定的学习成本，建议先跑通官方示例")。
        当前有 \(repo.starText) star、\(repo.forkText) fork，最近 24 小时新增 \(repo.starDeltaToday) star。
        """
    }

    // MARK: 标签区

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            VStack(alignment: .leading, spacing: DS.Space.s) {
                Text("分类与许可")
                    .font(DS.Typo.headline)
                    .foregroundStyle(DS.textPrimary)

                HStack(spacing: 8) {
                    TagChip(text: repo.category.title, systemImage: "square.grid.2x2", tint: repo.category.tint)
                    TagChip(text: repo.license.title, systemImage: "doc.text", tint: repo.license.tint)
                    TagChip(text: repo.language, systemImage: "chevron.left.forwardslash.chevron.right", tint: LanguagePalette.color(for: repo.language))
                }
            }

            VStack(alignment: .leading, spacing: DS.Space.s) {
                Text("我的标记")
                    .font(DS.Typo.headline)
                    .foregroundStyle(DS.textPrimary)

                HStack(spacing: 8) {
                    ForEach(MyMark.allCases) { item in
                        Button {
                            Haptics.selection()
                            withAnimation(DS.Motion.snappy) {
                                mark = (mark == item) ? nil : item
                            }
                        } label: {
                            TagChip(
                                text: item.title,
                                systemImage: item.symbol,
                                tint: item.tint,
                                filled: mark == item
                            )
                        }
                        .buttonStyle(.springPressSilent)
                    }
                }
            }
        }
    }

    // MARK: 相似项目

    private var similarSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            SectionHeader(title: "相似项目", subtitle: nil, actionTitle: nil, onAction: nil)
                .screenPadding()

            ScrollView(.horizontal) {
                HStack(spacing: DS.Space.m) {
                    ForEach(similar) { item in
                        NavigationLink(value: item) {
                            RepoMiniCard(repo: item)
                        }
                        .buttonStyle(.springPressCard)
                    }
                }
                .padding(.horizontal, DS.Space.screen)
            }
            .scrollIndicators(.hidden)
        }
        .navigationDestination(for: ShowcaseRepo.self) { next in
            RepoDetailView(repo: next)
        }
    }

    // MARK: 底部悬浮操作栏

    private var bottomBar: some View {
        HStack(spacing: DS.Space.s) {
            Button {
                Haptics.medium()
                withAnimation(DS.Motion.snappy) { isSaved.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 14, weight: .semibold))
                    Text(isSaved ? "已收藏" : "收藏")
                        .font(DS.Typo.caption)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                        .fill(DS.accentGradient)
                )
            }
            .buttonStyle(.springPressSilent)

            iconButton("square.and.arrow.up", label: "分享") {
                if let url = repo.githubURL {
                    openURL(url)
                }
            }

            iconButton("safari", label: "在浏览器打开") {
                if let url = repo.githubURL { openURL(url) }
            }

            iconButton("hammer.fill", label: "加入在用") {
                mark = .inUse
            }
        }
        .padding(.horizontal, DS.Space.m)
        .padding(.vertical, DS.Space.s)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.button + 6, style: .continuous)
                .fill(DS.cardGlass)
        }
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.button + 6, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .dsShadow(.elevated)
        .padding(.horizontal, DS.Space.l)
        .padding(.bottom, DS.Space.s)
    }

    private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DS.textPrimary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(DS.bgSecondary))
                .overlay(Circle().strokeBorder(DS.separator, lineWidth: 1))
        }
        .buttonStyle(.springPressSilent)
        .accessibilityLabel(label)
    }

    // MARK: 返回按钮

    private var backButton: some View {
        Button {
            Haptics.tap()
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(DS.textPrimary)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
        }
        .buttonStyle(.springPressSilent)
        .padding(.leading, DS.Space.m)
        .padding(.top, DS.Space.xxl)
        .accessibilityLabel("返回")
    }

    @Environment(\.dismiss) private var dismiss
}

#Preview("项目详情") {
    NavigationStack {
        RepoDetailView(repo: MockData.repos[0])
    }
}
