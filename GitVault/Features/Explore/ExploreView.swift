//
//  ExploreView.swift
//  GitVault
//
//  首页：问候 → 今日精选轮播 → 飙升榜 → 按主题浏览 → 为你推荐。
//  iOS 16 兼容：精选轮播用固定宽横向滚动，既不用 iOS17 API，也避免 TabView 嵌 ScrollView 的卡死。
//

import SwiftUI

struct ExploreView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var vault: VaultStore
    @Environment(\.horizontalSizeClass) private var sizeClass

    @StateObject private var vm = ExploreViewModel()
    @State private var showSettings = false

    private var topicColumns: [GridItem] {
        sizeClass == .regular
            ? Array(repeating: GridItem(.flexible(), spacing: DS.Space.s), count: 3)
            : [GridItem(.flexible(), spacing: DS.Space.s),
               GridItem(.flexible(), spacing: DS.Space.s)]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    header
                        .screenPadding()
                        .padding(.top, DS.Space.s)

                    if let message = vm.errorMessage {
                        ErrorBanner(message: vm.isUsingFallback ? "已切换到离线示例：\(message)" : message) {
                            Task { await vm.reload() }
                        }
                        .screenPadding()
                    }

                    heroSection
                    trendingSection
                    topicSection
                    forYouSection

                    Color.clear.frame(height: DS.Space.tabBarInset)
                }
            }
            .scrollIndicators(.hidden)
            .background(DS.bgPrimary)
            .refreshable { await vm.reload() }
            .navigationBarHidden(true)
            .navigationDestination(for: ShowcaseRepo.self) { repo in
                RepoDetailView(repo: repo)
            }
            .navigationDestination(for: CategoryRoute.self) { route in
                CategoryFeedView(category: route.category)
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheetView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .task {
                await vm.loadIfNeeded()
                await env.refreshCategoryCounts()
            }
        }
    }

    // MARK: 顶部问候

    private var header: some View {
        HStack(alignment: .center, spacing: DS.Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greetingText)
                    .font(DS.Typo.caption)
                    .foregroundStyle(DS.textTertiary)
                Text("今天挖点什么")
                    .font(DS.Typo.largeTitle)
                    .foregroundStyle(DS.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 0)

            Button {
                Haptics.tap()
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DS.textSecondary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(DS.bgSecondary))
                    .overlay(Circle().strokeBorder(DS.separator, lineWidth: 1))
            }
            .buttonStyle(.springPressSilent)
            .accessibilityLabel("设置")

            AvatarView(
                url: auth.user?.avatarURL.flatMap { URL(string: $0) },
                size: 38,
                initials: "G"
            )
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<11: return "早上好 👋"
        case 11..<14: return "中午好 👋"
        case 14..<18: return "下午好 👋"
        default: return "晚上好 👋"
        }
    }

    // MARK: 今日精选

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            SectionHeader(
                title: "今日精选",
                subtitle: vm.lastUpdated.map { "更新于 " + $0.formatted(date: .omitted, time: .shortened) }
                    ?? "正在获取最新榜单",
                actionTitle: nil,
                onAction: nil
            )
            .screenPadding()

            if vm.featured.isEmpty {
                SkeletonHero()
                    .screenPadding()
            } else {
                // 固定宽度横向轮播。
                // 不要用 TabView(.page) 嵌在纵向 ScrollView 里：iOS 16 会出现
                // 无限测量循环，表现为整页无响应（本次卡死的主因之一）。
                GeometryReader { geo in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DS.Space.m) {
                            ForEach(vm.featured.indexed) { entry in
                                NavigationLink(value: entry.item) {
                                    HeroRepoCard(
                                        repo: entry.item,
                                        isSaved: vault.isSaved(entry.item.id)
                                    ) {
                                        toggleSave(entry.item)
                                    }
                                    .frame(width: max(geo.size.width - DS.Space.screen * 2, 260))
                                }
                                .buttonStyle(.springPressCard)
                            }
                        }
                        .padding(.horizontal, DS.Space.screen)
                    }
                }
                .frame(height: 248)

                HStack(spacing: 5) {
                    Image(systemName: "hand.draw")
                        .font(.system(size: 10, weight: .semibold))
                    Text("左右滑动查看全部 \(vm.featured.count) 个精选")
                        .font(.system(size: 11))
                }
                .foregroundStyle(DS.textTertiary)
                .screenPadding()
            }
        }
    }

    // MARK: 飙升榜

    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            SectionHeader(
                title: "飙升榜 Trending",
                subtitle: "近 14 天有推送的高星项目",
                actionTitle: nil,
                onAction: nil
            )
            .screenPadding()

            if vm.trending.isEmpty {
                SkeletonList(count: 3).screenPadding()
            } else {
                VStack(spacing: DS.Space.s) {
                    ForEach(Array(vm.trending.prefix(AppConfig.trendingCount)).indexed) { entry in
                        NavigationLink(value: entry.item) {
                            HStack(spacing: DS.Space.m) {
                                Text("\(entry.index + 1)")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(entry.index < 3 ? DS.accent : DS.textTertiary)
                                    .frame(width: 18, alignment: .center)

                                RepoCard(repo: entry.item)
                            }
                        }
                        .buttonStyle(.springPressCard)
                        .staggerAppear(entry.index)
                    }
                }
                .screenPadding()
            }
        }
    }

    // MARK: 按主题浏览

    private var topicSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            SectionHeader(title: "按主题浏览", subtitle: nil, actionTitle: nil, onAction: nil)
                .screenPadding()

            LazyVGrid(columns: topicColumns, spacing: DS.Space.s) {
                ForEach(RepoCategory.allCases.indexed) { entry in
                    NavigationLink(value: CategoryRoute(category: entry.item)) {
                        CategoryShortcut(category: entry.item, count: env.categoryCount(entry.item))
                    }
                    .buttonStyle(.springPress)
                    .staggerAppear(entry.index)
                }
            }
            .screenPadding()
        }
    }

    // MARK: 为你推荐

    private var forYouSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            SectionHeader(title: "为你推荐", subtitle: "AI 与工具链里的高星项目", actionTitle: nil, onAction: nil)
                .screenPadding()

            if vm.forYou.isEmpty {
                SkeletonList(count: 2).screenPadding()
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: DS.Space.m) {
                        ForEach(vm.forYou.indexed) { entry in
                            NavigationLink(value: entry.item) {
                                RepoMiniCard(repo: entry.item)
                            }
                            .buttonStyle(.springPressCard)
                            .staggerAppear(entry.index)
                        }
                    }
                    .padding(.horizontal, DS.Space.screen)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    // MARK: 动作

    private func toggleSave(_ repo: ShowcaseRepo) {
        let saved = vault.toggle(repo)
        env.show(saved ? "已加入收藏：\(repo.name)" : "已从收藏移除：\(repo.name)",
                 kind: saved ? .success : .info)
        if saved { Haptics.success() }
    }
}

/// 分类导航值（首页 → 分类二级页）
struct CategoryRoute: Hashable {
    let category: RepoCategory
}

/// 精选区骨架
struct SkeletonHero: View {
    var body: some View {
        RoundedRectangle(cornerRadius: DS.Radius.cardLarge, style: .continuous)
            .fill(DS.bgSecondary)
            .frame(height: 240)
            .overlay(ProgressView().tint(DS.accent))
            .accessibilityLabel("正在加载今日精选")
    }
}

#Preview("首页") {
    ExploreView()
        .environmentObject(AppEnvironment.live())
        .environmentObject(AuthStore())
        .environmentObject(VaultStore(fileName: "preview-vault.json"))
}
