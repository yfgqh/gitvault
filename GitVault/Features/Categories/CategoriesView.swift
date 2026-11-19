//
//  CategoriesView.swift
//  GitVault
//
//  分类页：6 大主题网格 → 二级主题列表（筛选 Chip 栏）。
//

import SwiftUI

struct CategoriesView: View {
    private let columns = [
        GridItem(.flexible(), spacing: DS.Space.m),
        GridItem(.flexible(), spacing: DS.Space.m)
    ]

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
                            NavigationLink(value: entry.item) {
                                CategoryLargeCard(
                                    category: entry.item,
                                    count: MockData.count(in: entry.item)
                                )
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
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: RepoCategory.self) { category in
                CategoryFeedView(category: category)
            }
            .navigationDestination(for: ShowcaseRepo.self) { repo in
                RepoDetailView(repo: repo)
            }
        }
    }
}

// MARK: - 二级页面

struct CategoryFeedView: View {
    let category: RepoCategory

    @State private var sortMode: SortMode = .stars
    @State private var activeActivity: ActivityTag?
    @State private var activeLanguage: String?

    enum SortMode: String, CaseIterable, Identifiable {
        case stars, updated, language
        var id: String { rawValue }
        var title: String {
            switch self {
            case .stars: return "Star 最多"
            case .updated: return "最近更新"
            case .language: return "按语言"
            }
        }
    }

    private var base: [ShowcaseRepo] { MockData.repos(in: category) }

    private var languages: [String] {
        Array(Set(base.map(\.language))).sorted()
    }

    private var filtered: [ShowcaseRepo] {
        var list = base
        if let activeActivity {
            list = list.filter { $0.activity == activeActivity }
        }
        if let activeLanguage {
            list = list.filter { $0.language == activeLanguage }
        }
        switch sortMode {
        case .stars: list.sort { $0.stars > $1.stars }
        case .updated: list.sort { $0.starDeltaToday > $1.starDeltaToday }
        case .language: list.sort { $0.language < $1.language }
        }
        return list
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.m) {
                // 主题头图
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(colors: category.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 140, height: 140)
                        .blur(radius: 44)
                        .offset(x: 120, y: -60)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.emoji + " " + category.title)
                            .font(DS.Typo.title)
                            .foregroundStyle(.white)
                        Text(category.subtitle)
                            .font(DS.Typo.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(DS.Space.m)
                }
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
                .screenPadding()

                // 横向筛选 Chip 栏
                ScrollView(.horizontal) {
                    HStack(spacing: DS.Space.s) {
                        ForEach(SortMode.allCases) { mode in
                            FilterChip(title: mode.title, isActive: sortMode == mode) {
                                withAnimation(DS.Motion.snappy) { sortMode = mode }
                            }
                        }

                        Divider().frame(height: 20)

                        ForEach(ActivityTag.allCases) { tag in
                            FilterChip(
                                title: tag.title,
                                emoji: tag.emoji,
                                isActive: activeActivity == tag
                            ) {
                                withAnimation(DS.Motion.snappy) {
                                    activeActivity = (activeActivity == tag) ? nil : tag
                                }
                            }
                        }

                        ForEach(languages, id: \.self) { language in
                            FilterChip(
                                title: language,
                                isActive: activeLanguage == language
                            ) {
                                withAnimation(DS.Motion.snappy) {
                                    activeLanguage = (activeLanguage == language) ? nil : language
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DS.Space.screen)
                }
                .scrollIndicators(.hidden)

                // 结果列表
                if filtered.isEmpty {
                    EmptyStateView(
                        symbol: "tray",
                        title: "这个组合下还没有项目",
                        message: "试试切换筛选条件，或稍后再来看看"
                    )
                    .padding(.top, DS.Space.xl)
                } else {
                    VStack(spacing: DS.Space.s) {
                        ForEach(filtered.indexed) { entry in
                            NavigationLink(value: entry.item) {
                                RepoCard(repo: entry.item)
                            }
                            .buttonStyle(.springPressCard)
                            .staggerAppear(entry.index)
                        }
                    }
                    .screenPadding()
                }

                Color.clear.frame(height: DS.Space.tabBarInset)
            }
            .padding(.top, DS.Space.s)
        }
        .scrollIndicators(.hidden)
        .background(DS.bgPrimary)
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("分类页") {
    CategoriesView()
}

#Preview("二级主题") {
    NavigationStack {
        CategoryFeedView(category: .ai)
    }
}
