//
//  RepoDetailView.swift
//  GitVault
//
//  项目详情（iOS 16 兼容）：Hero + 数据卡 + 语言占比 + README 摘要 + 标签 + 底部操作栏 + 相似项目。
//

import SwiftUI

struct RepoDetailView: View {
    let repo: ShowcaseRepo
    var heroNamespace: Namespace.ID? = nil

    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var vault: VaultStore
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    @StateObject private var vm: DetailViewModel
    @State private var readmeExpanded = false

    init(repo: ShowcaseRepo, heroNamespace: Namespace.ID? = nil) {
        self.repo = repo
        self.heroNamespace = heroNamespace
        _vm = StateObject(wrappedValue: DetailViewModel(repo: repo))
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
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(true)
        .safeAreaInset(edge: .bottom) { bottomBar }
        .overlay(alignment: .topLeading) { backButton }
        .task {
            if let item = vault.item(id: repo.id) {
                vm.mark = item.mark
                vm.isSaved = true
            }
            await vm.loadDetailIfNeeded()
            await vm.loadReadmeIfNeeded()
        }
    }

    // MARK: Hero

    @ViewBuilder
    private var heroAvatar: some View {
        let avatar = AvatarView(
            url: vm.repo.avatarURL,
            size: 64,
            initials: vm.repo.initials,
            gradient: vm.repo.gradient
        )
        if let heroNamespace {
            avatar.matchedGeometryEffect(id: "hero-\(repo.id)", in: heroNamespace)
        } else {
            avatar
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: vm.repo.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)

            Circle()
                .fill(.white.opacity(0.20))
                .frame(width: 220, height: 220)
                .blur(radius: 70)
                .offset(x: 130, y: -80)

            HStack(alignment: .bottom, spacing: DS.Space.m) {
                heroAvatar

                VStack(alignment: .leading, spacing: 3) {
                    Text(vm.repo.owner)
                        .font(DS.Typo.caption)
                        .foregroundStyle(.white.opacity(0.75))
                    Text(vm.repo.name)
                        .font(.system(.title2, design: .default).weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
            }
            .padding(DS.Space.screen)
        }
        .frame(height: 252)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.cardLarge, style: .continuous))
        .padding(.horizontal, DS.Space.s)
        .padding(.top, DS.Space.s)
        .dsShadow(.light)
    }

    // MARK: 标题 + 摘要 + 状态标签

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    TagChip(text: vm.repo.category.emoji + " " + vm.repo.category.title,
                            tint: vm.repo.category.tint)
                    TagChip(text: vm.repo.activity.emoji + " " + vm.repo.activity.title,
                            tint: vm.repo.activity.tint, filled: true)
                    TagChip(text: vm.repo.usage.emoji + " " + vm.repo.usage.title,
                            tint: vm.repo.usage.tint)
                    TagChip(text: vm.repo.license.title, tint: vm.repo.license.tint)
                }
            }
            .scrollIndicators(.hidden)

            Text(vm.repo.summary)
                .font(DS.Typo.body)
                .foregroundStyle(DS.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let updated = vm.repo.updatedAt {
                Text("最近推送：" + updated.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundStyle(DS.textTertiary)
            }
        }
    }

    // MARK: 数据卡

    private var statsCard: some View {
        VStack(spacing: DS.Space.m) {
            HStack(spacing: 0) {
                statCell("Star", value: vm.repo.starText, symbol: "star.fill", tint: MyMark.starred.tint)
                Divider().frame(height: 32)
                statCell("Fork", value: vm.repo.forkText, symbol: "arrow.triangle.branch", tint: DS.accent)
                Divider().frame(height: 32)
                statCell("Issue", value: "\(vm.repo.openIssues)", symbol: "exclamationmark.circle", tint: DS.warning)
            }

            if vm.languages.isEmpty {
                HStack(spacing: 6) {
                    LanguageDot(color: LanguagePalette.color(for: vm.repo.language))
                    Text("主语言 \(vm.repo.language)")
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.textSecondary)
                    Spacer()
                    if vm.isLoadingDetail {
                        ProgressView().scaleEffect(0.6).tint(DS.accent)
                    }
                }
            } else {
                LanguageBar(slices: vm.languages)
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

    // MARK: README 摘要

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
                    TagChip(text: vm.readmeSource, tint: DS.accentAlt, compact: true)
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
                .accessibilityLabel(readmeExpanded ? "收起摘要" : "展开摘要")
            }

            if vm.isLoadingReadme && vm.readmeSummary == nil {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7).tint(DS.accent)
                    Text("正在读 README…")
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.textTertiary)
                }
                .frame(height: 44)
            } else {
                Text(vm.readmeSummary ?? "暂无摘要")
                    .font(DS.Typo.bodySmall)
                    .foregroundStyle(DS.textSecondary)
                    .lineLimit(readmeExpanded ? nil : 3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: DS.Space.s) {
                Button {
                    Haptics.tap()
                    Task { await vm.loadReadmeIfNeeded(force: true) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9, weight: .bold))
                        Text("重新生成")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(DS.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(DS.accent.opacity(0.12)))
                }
                .buttonStyle(.springPressSilent)

                Text(env.llm.isConfigured ? "已接入大模型" : "规则摘要 · 可在「我的」里接入大模型")
                    .font(.system(size: 10))
                    .foregroundStyle(DS.textTertiary)
                Spacer()
            }
        }
        .padding(DS.Space.m)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(DS.bgSecondary)
        )
    }

    // MARK: 标签区

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            if !vm.repo.topics.isEmpty {
                VStack(alignment: .leading, spacing: DS.Space.s) {
                    Text("主题标签")
                        .font(DS.Typo.headline)
                        .foregroundStyle(DS.textPrimary)

                    FlowChips(items: Array(vm.repo.topics.prefix(10))) { topic in
                        if let url = URL(string: "https://github.com/topics/\(topic)") {
                            openURL(url)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: DS.Space.s) {
                Text("我的标记")
                    .font(DS.Typo.headline)
                    .foregroundStyle(DS.textPrimary)

                HStack(spacing: 8) {
                    ForEach(MyMark.allCases) { item in
                        Button {
                            apply(mark: item)
                        } label: {
                            TagChip(
                                text: item.title,
                                systemImage: item.symbol,
                                tint: item.tint,
                                filled: vm.mark == item
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
        Group {
            if !vm.similar.isEmpty {
                VStack(alignment: .leading, spacing: DS.Space.m) {
                    SectionHeader(title: "相似项目", subtitle: "同 topic 的高星仓库",
                                  actionTitle: nil, onAction: nil)
                        .screenPadding()

                    ScrollView(.horizontal) {
                        HStack(spacing: DS.Space.m) {
                            ForEach(vm.similar) { item in
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
        }
    }

    // MARK: 底部操作栏

    private var bottomBar: some View {
        HStack(spacing: DS.Space.s) {
            Button {
                toggleSave()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: vm.isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 14, weight: .semibold))
                    Text(vm.isSaved ? "已收藏" : "收藏")
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

            if let url = vm.repo.githubURL {
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(DS.bgSecondary))
                        .overlay(Circle().strokeBorder(DS.separator, lineWidth: 1))
                }
                .buttonStyle(.springPressSilent)
                .accessibilityLabel("分享")
            }

            iconButton("safari", label: "在浏览器打开") {
                if let url = vm.repo.githubURL { openURL(url) }
            }

            iconButton(vm.mark == .inUse ? "hammer.fill" : "hammer", label: "加入在用") {
                apply(mark: .inUse)
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

    // MARK: 返回

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
        .padding(.top, DS.Space.xl)
        .accessibilityLabel("返回")
    }

    // MARK: 动作

    private func toggleSave() {
        if vault.isSaved(repo.id) {
            vault.remove(id: repo.id)
            vm.isSaved = false
            vm.mark = nil
            env.show("已取消收藏：\(repo.name)")
            Haptics.tap()
        } else {
            vault.toggle(vm.repo, mark: .starred)
            vm.isSaved = true
            vm.mark = .starred
            Haptics.success()
            env.show("已收藏：\(repo.name)", kind: .success)
        }
    }

    private func apply(mark: MyMark) {
        if vault.isSaved(repo.id) {
            vault.setMark(id: repo.id, to: mark)
        } else {
            vault.toggle(vm.repo, mark: mark)
            vm.isSaved = true
        }
        vm.mark = mark
        Haptics.medium()
        env.show("已标记为「\(mark.title)」", kind: .success)
    }
}

#Preview("项目详情") {
    NavigationStack {
        RepoDetailView(repo: MockData.repos[0])
    }
    .environmentObject(AppEnvironment.live())
    .environmentObject(AuthStore())
    .environmentObject(VaultStore(fileName: "preview-vault.json"))
}
