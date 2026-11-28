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

    @Environment(\.openURL) private var openURL
    @StateObject private var vm = ExploreViewModel()
    @State private var showSettings = false
    /// 精选卡横向拖动中：暂停纵向滚动，避免手势打架
    @State private var isCardDragging = false

    private var topicColumns: [GridItem] {
        sizeClass == .regular
            ? Array(repeating: GridItem(.flexible(), spacing: DS.Space.s), count: 3)
            : [GridItem(.flexible(), spacing: DS.Space.s),
               GridItem(.flexible(), spacing: DS.Space.s)]
    }

    /// 今日考古：从 30 天前的收藏里按日期固定挑一个
    private var archiveItem: (item: VaultItem, days: Int)? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
        let pool = vault.items
            .filter { $0.savedAt <= cutoff }
            .sorted { $0.savedAt < $1.savedAt }
        guard !pool.isEmpty else { return nil }
        let ordinal = Calendar.current.ordinality(of: .day, in: .era, for: .now) ?? 0
        let picked = pool[ordinal % pool.count]
        let days = Calendar.current.dateComponents([.day], from: picked.savedAt, to: .now).day ?? 30
        return (picked, max(days, 0))
    }

    var body: some View {
        NavigationStack {
            ElasticRefresh(isScrollDisabled: isCardDragging, action: { await vm.reload(profile: discoveryProfile) }) {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    header
                        .screenPadding()
                        .padding(.top, DS.Space.s)

                    if let message = vm.errorMessage {
                        ErrorBanner(message: vm.isUsingFallback ? "已切换到离线示例：\(message)" : message) {
                            Task { await vm.reload(profile: discoveryProfile) }
                        }
                        .screenPadding()
                    }

                    if vm.loadedFromCache, let saved = vm.lastUpdated {
                        HStack(spacing: 5) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 10, weight: .semibold))
                            Text("显示缓存（" + saved.formatted(date: .abbreviated, time: .shortened) + "），下拉可刷新")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(DS.textTertiary)
                        .screenPadding()
                    }

                    if let archive = archiveItem {
                        Button { Haptics.tap(); DetailPresenter.shared.open(ShowcaseRepo(entry: archive.item)) } label: {
                            TodayArchiveCard(item: archive.item, daysAgo: archive.days)
                        }
                        .buttonStyle(.springPressCard)
                        .screenPadding()
                    }

                    heroSection
                    risingSection
                    gemsSection
                    hotSection
                    topicSection
                    forYouSection

                    Color.clear.frame(height: DS.Space.tabBarInset)
                }
            }
            .background(DS.bgPrimary)
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
                await vm.loadIfNeeded(profile: discoveryProfile)
                await env.refreshCategoryCounts()
                env.allRepos.loadIfNeeded()
                // 离线全量库是 Pro 能力：免费用户只读本地已有缓存，不再自动抓取
                if env.pro.hasFullAccess {
                    await env.allRepos.refreshStep()
                }
            }
        }
    }

    // MARK: 顶部问候

    private var header: some View {
        HStack(alignment: .center, spacing: DS.Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text("GitHub 精选 · 每日更新")
                    .font(DS.Typo.caption)
                    .foregroundStyle(DS.textTertiary)
                Text("发现")
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

            if vm.feed.featured.isEmpty {
                SkeletonHero()
                    .screenPadding()
            } else {
                // 可拖拽卡片堆叠：拖动按位移旋转，甩出后下一张补位
                CardStack(items: vm.feed.featured,
                          visibleCount: 3,
                          isHorizontalDrag: $isCardDragging) { repo in
                    HeroRepoCard(
                        repo: repo,
                        isSaved: vault.isSaved(repo.id)
                    ) {
                        toggleSave(repo)
                    }
                } onTap: { repo in
                    Haptics.tap()
                    DetailPresenter.shared.open(repo)
                }
                .frame(height: 252)
                .screenPadding()

                HStack(spacing: 5) {
                    Image(systemName: "hand.draw")
                        .font(.system(size: 10, weight: .semibold))
                    Text(String(format: NSLocalizedString("左右拖动切换 · 共 %d 个精选", comment: ""), vm.feed.featured.count))
                        .font(.system(size: 11))
                }
                .foregroundStyle(DS.textTertiary)
                .screenPadding()
            }
        }
    }

    // MARK: 新星（半年内创建，按平均日增排序）

    private var risingSection: some View {
        discoveryRail(
            title: "新星 Rising",
            subtitle: "半年内创建 · 按平均日增排序",
            items: vm.feed.rising,
            emptyHint: "今天还没有新的候选，稍后刷新"
        )
    }

    // MARK: 隐藏宝石（200–3000 星，按质量排序）

    private var gemsSection: some View {
        discoveryRail(
            title: "隐藏宝石",
            subtitle: "200–3000 星里文档与维护都不差的",
            items: vm.feed.gems,
            emptyHint: "这一档暂时没有合适的项目"
        )
    }

    // MARK: 近期热门（综合分，不只看星）

    private var hotSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            SectionHeader(
                title: "近期热门",
                subtitle: "综合热度、活跃度与文档质量",
                actionTitle: nil,
                onAction: nil
            )
            .screenPadding()

            if vm.feed.trending.isEmpty {
                SkeletonList(count: 3).screenPadding()
            } else {
                VStack(spacing: DS.Space.s) {
                    ForEach(Array(vm.feed.trending.prefix(12)).indexed) { entry in
                        Button { Haptics.tap(); DetailPresenter.shared.open(entry.item.repo) } label: {
                            HStack(spacing: DS.Space.m) {
                                Text("\(entry.index + 1)")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(entry.index < 3 ? DS.accent : DS.textTertiary)
                                    .frame(width: 18, alignment: .center)

                                RepoCard(repo: entry.item.repo, reason: entry.item.reason)
                            }
                        }
                        .buttonStyle(.springPressCard)
                        
                    }
                }
                .screenPadding()
            }
        }
    }

    /// 横向卡片流（新星 / 宝石共用）
    private func discoveryRail(title: String,
                               subtitle: String,
                               items: [DiscoveryItem],
                               emptyHint: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            SectionHeader(title: title, subtitle: subtitle, actionTitle: nil, onAction: nil)
                .screenPadding()

            if items.isEmpty {
                Text(emptyHint)
                    .font(DS.Typo.caption)
                    .foregroundStyle(DS.textTertiary)
                    .screenPadding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Space.m) {
                        ForEach(items.indexed) { entry in
                            Button { Haptics.tap(); DetailPresenter.shared.open(entry.item.repo) } label: {
                                RepoMiniCard(repo: entry.item.repo, reason: entry.item.reason)
                            }
                            .buttonStyle(.springPressCard)
                            
                        }
                    }
                    .padding(.horizontal, DS.Space.screen)
                }
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
                    
                }
            }
            .screenPadding()
        }
    }

    // MARK: 为你推荐

    private var forYouSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            SectionHeader(
                title: "为你推荐",
                subtitle: vault.items.isEmpty ? "先收藏几个项目，这里会更准" : "基于你收藏的主题与语言",
                actionTitle: nil,
                onAction: nil
            )
            .screenPadding()

            if vm.feed.forYou.isEmpty {
                SkeletonList(count: 2).screenPadding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Space.m) {
                        ForEach(vm.feed.forYou.indexed) { entry in
                            Button { Haptics.tap(); DetailPresenter.shared.open(entry.item.repo) } label: {
                                RepoMiniCard(repo: entry.item.repo, reason: entry.item.reason)
                            }
                            .buttonStyle(.springPressCard)
                            
                        }
                    }
                    .padding(.horizontal, DS.Space.screen)
                }
            }
        }
    }

    /// 用于个性化的画像：收藏里的 topic 与语言
    private var discoveryProfile: DiscoveryProfile {
        DiscoveryProfile(
            topics: Set(vault.items.flatMap { $0.topics.map { $0.lowercased() } }),
            languages: Set(vault.items.map { $0.language.lowercased() })
        )
    }

    // MARK: 动作

    private func toggleSave(_ repo: ShowcaseRepo) {
        let saved = vault.toggle(repo)
        env.show(saved ? String(format: NSLocalizedString("已加入收藏：%@", comment: ""), repo.name) : String(format: NSLocalizedString("已从收藏移除：%@", comment: ""), repo.name),
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
