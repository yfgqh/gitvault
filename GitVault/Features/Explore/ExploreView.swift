//
//  ExploreView.swift
//  GitVault
//
//  首页：问候 → 今日精选轮播 → 飙升榜 → 按主题浏览 → 为你推荐。
//

import SwiftUI

struct ExploreView: View {
    @State private var heroID: String?
    @State private var showSettings = false
    @State private var savedIDs: Set<String> = []

    private let featured = MockData.featured
    private let trending = MockData.trending

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    header
                        .screenPadding()
                        .padding(.top, DS.Space.s)

                    heroSection

                    trendingSection

                    topicSection

                    forYouSection

                    Color.clear.frame(height: DS.Space.tabBarInset)
                }
            }
            .scrollIndicators(.hidden)
            .background(DS.bgPrimary)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ShowcaseRepo.self) { repo in
                RepoDetailView(repo: repo)
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheetView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
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
                    .minimumScaleFactor(0.8)
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

            // 头像（阶段 5 接入 GitHub OAuth 后替换为真实头像）
            ZStack {
                Circle().fill(DS.accentGradient)
                Image(systemName: "person.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 38, height: 38)
            .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
            .accessibilityHidden(true)
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

    // MARK: 今日精选轮播

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            SectionHeader(
                title: "今日精选",
                subtitle: "编辑手选的 4 个高质量项目",
                actionTitle: "\(featured.count) 个",
                onAction: nil
            )
            .screenPadding()

            ScrollView(.horizontal) {
                LazyHStack(spacing: DS.Space.m) {
                    ForEach(featured) { repo in
                        NavigationLink(value: repo) {
                            HeroRepoCard(
                                repo: repo,
                                isSaved: savedIDs.contains(repo.id)
                            ) {
                                toggleSave(repo)
                            }
                            .containerRelativeFrame(.horizontal)
                            .padding(.horizontal, DS.Space.screen)
                        }
                        .buttonStyle(.springPressCard)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $heroID)

            // 分页指示器
            HStack(spacing: 6) {
                ForEach(featured) { repo in
                    Capsule()
                        .fill(heroID == repo.id ? AnyShapeStyle(DS.accentGradient) : AnyShapeStyle(DS.bgTertiary))
                        .frame(width: heroID == repo.id ? 18 : 6, height: 6)
                        .animation(DS.Motion.snappy, value: heroID)
                }
            }
            .screenPadding()
        }
        .onAppear {
            if heroID == nil { heroID = featured.first?.id }
        }
    }

    // MARK: 飙升榜

    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            SectionHeader(
                title: "飙升榜 Trending",
                subtitle: "近 24 小时 star 增速排行",
                actionTitle: nil,
                onAction: nil
            )
            .screenPadding()

            VStack(spacing: DS.Space.s) {
                ForEach(Array(trending.prefix(5)).indexed) { entry in
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

    // MARK: 按主题浏览

    private var topicSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            SectionHeader(title: "按主题浏览", subtitle: nil, actionTitle: nil, onAction: nil)
                .screenPadding()

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: DS.Space.s),
                          GridItem(.flexible(), spacing: DS.Space.s)],
                spacing: DS.Space.s
            ) {
                ForEach(RepoCategory.allCases.indexed) { entry in
                    Button {
                        Haptics.tap()
                    } label: {
                        CategoryShortcut(
                            category: entry.item,
                            count: MockData.count(in: entry.item)
                        )
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
            SectionHeader(
                title: "为你推荐",
                subtitle: "基于你的收藏主题",
                actionTitle: nil,
                onAction: nil
            )
            .screenPadding()

            ScrollView(.horizontal) {
                HStack(spacing: DS.Space.m) {
                    ForEach(MockData.forYou.indexed) { entry in
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

    // MARK: 收藏动作（阶段 4 接入 SwiftData 写入）

    private func toggleSave(_ repo: ShowcaseRepo) {
        if savedIDs.contains(repo.id) {
            savedIDs.remove(repo.id)
        } else {
            savedIDs.insert(repo.id)
        }
    }
}

#Preview("首页") {
    ExploreView()
}
