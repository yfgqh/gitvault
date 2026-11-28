//
//  CategoriesView.swift
//  GitVault
//
//  分类页（iOS 16 兼容）：6 大主题网格 → 二级主题列表。
//

import SwiftUI

struct CategoriesView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var columns: [GridItem] {
        sizeClass == .regular
            ? Array(repeating: GridItem(.flexible(), spacing: DS.Space.m), count: 3)
            : [GridItem(.flexible(), spacing: DS.Space.m),
               GridItem(.flexible(), spacing: DS.Space.m)]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("6 个主题场景")
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.textTertiary)
                        Text("分类")
                            .font(DS.Typo.largeTitle)
                            .foregroundStyle(DS.textPrimary)
                    }
                    .screenPadding()
                    .padding(.top, DS.Space.s)

                    LazyVGrid(columns: columns, spacing: DS.Space.m) {
                        ForEach(RepoCategory.allCases.indexed) { entry in
                            NavigationLink(value: CategoryRoute(category: entry.item)) {
                                CategoryLargeCard(category: entry.item, count: env.categoryCount(entry.item))
                            }
                            .buttonStyle(.springPressCard)
                            .staggerAppear(entry.index)
                        }
                    }
                    .screenPadding()

                    Color.clear.frame(height: DS.Space.tabBarInset)
                }
            }
            .scrollIndicators(.hidden)
            .background(DS.bgPrimary)
            .navigationBarHidden(true)
            .navigationDestination(for: CategoryRoute.self) { route in
                CategoryFeedView(category: route.category)
            }
            .navigationDestination(for: ShowcaseRepo.self) { repo in
                RepoDetailView(repo: repo)
            }
            .task { await env.refreshCategoryCounts() }
        }
    }
}

// MARK: - 二级主题页

struct CategoryFeedView: View {
    let category: RepoCategory

    @StateObject private var vm: CategoryFeedViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass

    init(category: RepoCategory) {
        self.category = category
        _vm = StateObject(wrappedValue: CategoryFeedViewModel(category: category))
    }

    private var columns: [GridItem] {
        sizeClass == .regular
            ? Array(repeating: GridItem(.flexible(), spacing: DS.Space.m), count: 2)
            : [GridItem(.flexible())]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.m) {
                banner
                if let hint = vm.cacheHint {
                    HStack(spacing: 5) {
                        Image(systemName: "internaldrive")
                            .font(.system(size: 9, weight: .semibold))
                        Text(hint)
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(DS.textTertiary)
                    .screenPadding()
                }
                subcategoryBar
                filterBar
                content
                footer
                Color.clear.frame(height: DS.Space.tabBarInset)
            }
            .padding(.top, DS.Space.s)
        }
        .scrollIndicators(.hidden)
        .background(DS.bgPrimary)
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await vm.reload() }
        .task { await vm.loadIfNeeded() }
    }

    private var banner: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: category.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle()
                .fill(.white.opacity(0.2))
                .frame(width: 140, height: 140)
                .blur(radius: 44)
                .offset(x: 120, y: -60)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                        Image(systemName: category.symbol)
                            .font(.system(size: 13, weight: .semibold))
                        Text(category.title)
                    }
                    .font(DS.Typo.title)
                    .foregroundStyle(.white)
                Text(vm.totalCount > 0
                     ? category.subtitle + " · " + String(format: NSLocalizedString("共 %@ 个", comment: ""), ShowcaseRepo.compact(vm.totalCount))
                     : category.subtitle)
                    .font(DS.Typo.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(DS.Space.m)
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .screenPadding()
    }

    /// 二级子分类：先粗分，再看具体项目
    private var subcategoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Space.s) {
                FilterChip(title: "全部", emoji: "🗂", isActive: vm.activeSub == nil) {
                    Haptics.selection()
                    withAnimation(DS.Motion.snappy) { vm.setSubcategory(nil) }
                }
                ForEach(category.subcategories) { sub in
                    FilterChip(
                        title: "\(sub.title) \(vm.counts(for: sub))",
                        isActive: vm.activeSub?.id == sub.id
                    ) {
                        Haptics.selection()
                        withAnimation(DS.Motion.snappy) {
                            vm.setSubcategory(vm.activeSub?.id == sub.id ? nil : sub)
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Space.screen)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: DS.Space.s) {
                ForEach(CategoryFeedViewModel.SortMode.allCases) { mode in
                    FilterChip(title: mode.title, isActive: vm.sortMode == mode) {
                        withAnimation(DS.Motion.snappy) { vm.sortMode = mode }
                    }
                }

                Divider().frame(height: 20)

                ForEach(ActivityTag.allCases) { tag in
                    FilterChip(title: tag.title, emoji: tag.emoji, isActive: vm.activeActivity == tag) {
                        withAnimation(DS.Motion.snappy) {
                            vm.activeActivity = (vm.activeActivity == tag) ? nil : tag
                        }
                    }
                }

                ForEach(vm.languages, id: \.self) { language in
                    FilterChip(title: language, isActive: vm.activeLanguage == language) {
                        withAnimation(DS.Motion.snappy) {
                            vm.activeLanguage = (vm.activeLanguage == language) ? nil : language
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Space.screen)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.items.isEmpty {
            SkeletonList(count: 4).screenPadding()
        } else if let message = vm.errorMessage, vm.items.isEmpty {
            EmptyStateView(symbol: "exclamationmark.icloud",
                           title: "没能拿到这个主题的数据",
                           message: message,
                           actionTitle: "重试") {
                Task { await vm.reload() }
            }
            .padding(.top, DS.Space.l)
        } else if vm.displayed.isEmpty {
            EmptyStateView(symbol: "tray",
                           title: "这个组合下还没有项目",
                           message: "试试切换筛选条件，或稍后再来看看")
            .padding(.top, DS.Space.l)
        } else {
            LazyVGrid(columns: columns, spacing: DS.Space.s) {
                ForEach(vm.displayed.indexed) { entry in
                    NavigationLink(value: entry.item) {
                        RepoCard(repo: entry.item)
                    }
                    .buttonStyle(.springPressCard)
                    .staggerAppear(min(entry.index, 10))
                }
            }
            .screenPadding()
        }
    }

    @ViewBuilder
    private var footer: some View {
        Group {
            if vm.isLoadingMore {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.7).tint(DS.accent)
                    Text("正在加载更多…")
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Space.m)
            } else if let hint = vm.truncatedHint {
                Text(hint)
                    .font(DS.Typo.caption)
                    .foregroundStyle(DS.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Space.m)
                    .onAppear {
                        // 滚到底部即继续加载：分类不再只显示前 100 名
                        if vm.canLoadMore {
                            Task { await vm.loadMore() }
                        }
                    }
            }
        }
    }
}

#Preview("分类页") {
    CategoriesView()
        .environmentObject(AppEnvironment.live())
}

#Preview("二级主题") {
    NavigationStack {
        CategoryFeedView(category: .ai)
    }
}
