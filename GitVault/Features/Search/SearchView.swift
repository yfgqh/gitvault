//
//  SearchView.swift
//  GitVault
//
//  搜索页：300ms 防抖联想 + 分类/语言/star 区间筛选 + 空状态引导。
//

import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @State private var results: [ShowcaseRepo] = []
    @State private var isSearching = false
    @State private var history: [String] = MockData.defaultSearchHistory
    @State private var activeCategory: RepoCategory?
    @State private var activeLanguage: String?
    @State private var minStars: Int?
    @FocusState private var fieldFocused: Bool

    private let starOptions: [StarOption] = [
        StarOption(title: "不限", value: nil),
        StarOption(title: "1k+", value: 1_000),
        StarOption(title: "50k+", value: 50_000),
        StarOption(title: "100k+", value: 100_000)
    ]

    private var languages: [String] {
        Array(Set(MockData.repos.map(\.language))).sorted()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    searchField
                        .screenPadding()
                        .padding(.top, DS.Space.s)

                    filterBar

                    content

                    Color.clear.frame(height: DS.Space.tabBarInset)
                }
            }
            .scrollIndicators(.hidden)
            .background(DS.bgPrimary)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ShowcaseRepo.self) { repo in
                RepoDetailView(repo: repo)
            }
            // 300ms 防抖：query 变化后重新排一次任务，旧任务自动取消
            .task(id: query) {
                await performSearch(debounced: true)
            }
        }
    }

    // MARK: 搜索框

    private var searchField: some View {
        HStack(spacing: DS.Space.s) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DS.textTertiary)

            TextField("搜索开源项目、语言或主题", text: $query)
                .font(DS.Typo.body)
                .foregroundStyle(DS.textPrimary)
                .focused($fieldFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit {
                    commitToHistory(query)
                    Task { await performSearch(debounced: false) }
                }

            if !query.isEmpty {
                Button {
                    Haptics.tap()
                    query = ""
                    results = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(DS.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清空搜索")
            }
        }
        .padding(.horizontal, DS.Space.m)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                .fill(DS.bgSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                .strokeBorder(fieldFocused ? DS.accent.opacity(0.7) : DS.separator, lineWidth: 1)
        )
        .animation(DS.Motion.fade, value: fieldFocused)
    }

    // MARK: 筛选栏

    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: DS.Space.s) {
                FilterChip(title: "全部主题", isActive: activeCategory == nil) {
                    withAnimation(DS.Motion.snappy) { activeCategory = nil }
                }
                ForEach(RepoCategory.allCases) { category in
                    FilterChip(
                        title: category.title,
                        emoji: category.emoji,
                        isActive: activeCategory == category
                    ) {
                        withAnimation(DS.Motion.snappy) {
                            activeCategory = (activeCategory == category) ? nil : category
                        }
                    }
                }

                Divider().frame(height: 20)

                ForEach(starOptions) { option in
                    FilterChip(title: "★ " + option.title, isActive: minStars == option.value) {
                        withAnimation(DS.Motion.snappy) { minStars = option.value }
                    }
                }

                Divider().frame(height: 20)

                ForEach(languages, id: \.self) { language in
                    FilterChip(title: language, isActive: activeLanguage == language) {
                        withAnimation(DS.Motion.snappy) {
                            activeLanguage = (activeLanguage == language) ? nil : language
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Space.screen)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: 内容区

    @ViewBuilder
    private var content: some View {
        if query.isEmpty {
            discoverySection
        } else if isSearching {
            HStack {
                Spacer()
                ProgressView()
                    .tint(DS.accent)
                Spacer()
            }
            .padding(.top, DS.Space.xxl)
        } else if results.isEmpty {
            EmptyStateView(
                symbol: "magnifyingglass",
                title: "没有找到「\(query)」",
                message: "换个关键词，或去掉筛选条件再试试"
            )
            .padding(.top, DS.Space.l)
        } else {
            VStack(alignment: .leading, spacing: DS.Space.s) {
                Text("找到 \(results.count) 个结果")
                    .font(DS.Typo.caption)
                    .foregroundStyle(DS.textTertiary)
                    .screenPadding()

                ForEach(results.indexed) { entry in
                    NavigationLink(value: entry.item) {
                        RepoCard(repo: entry.item)
                    }
                    .buttonStyle(.springPressCard)
                    .staggerAppear(entry.index)
                    .screenPadding()
                }
            }
        }
    }

    private var discoverySection: some View {
        VStack(alignment: .leading, spacing: DS.Space.l) {
            if !history.isEmpty {
                VStack(alignment: .leading, spacing: DS.Space.s) {
                    HStack {
                        Text("搜索历史")
                            .font(DS.Typo.headline)
                            .foregroundStyle(DS.textPrimary)
                        Spacer()
                        Button {
                            Haptics.tap()
                            withAnimation(DS.Motion.fade) { history.removeAll() }
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(DS.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("清空搜索历史")
                    }

                    FlowChips(items: history) { item in
                        query = item
                        commitToHistory(item)
                    }
                }
                .screenPadding()
            }

            VStack(alignment: .leading, spacing: DS.Space.s) {
                Text("热门搜索")
                    .font(DS.Typo.headline)
                    .foregroundStyle(DS.textPrimary)

                FlowChips(items: MockData.hotKeywords, showsFlame: true) { item in
                    query = item
                    commitToHistory(item)
                }
            }
            .screenPadding()
        }
    }

    // MARK: 搜索执行

    /// - Parameter debounced: 键入触发时走 300ms 防抖；回车触发立即执行
    @MainActor
    private func performSearch(debounced: Bool) async {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            results = []
            isSearching = false
            return
        }

        isSearching = true

        if debounced {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
        }

        // 阶段 2：此处替换为 GitHubService.search(keyword:)
        let matched = MockData.repos.filter { repo in
            let hit = repo.fullName.lowercased().contains(keyword.lowercased())
                || repo.summary.contains(keyword)
                || repo.language.lowercased().contains(keyword.lowercased())
                || repo.category.title.contains(keyword)
            guard hit else { return false }
            if let activeCategory, repo.category != activeCategory { return false }
            if let activeLanguage, repo.language != activeLanguage { return false }
            if let minStars, repo.stars < minStars { return false }
            return true
        }
        .sorted { $0.stars > $1.stars }

        results = matched
        isSearching = false
    }

    private func commitToHistory(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        history.removeAll { $0 == trimmed }
        history.insert(trimmed, at: 0)
        if history.count > 8 { history = Array(history.prefix(8)) }
    }
}

// MARK: - 排序 / star 区间选项

struct StarOption: Identifiable, Hashable {
    var id: String { title }
    let title: String
    let value: Int?
}

// MARK: - 自适应流式 Chip 布局

struct FlowChips: View {
    let items: [String]
    var showsFlame: Bool = false
    var onTap: (String) -> Void

    var body: some View {
        // 用 Layout 协议手写换行，避免依赖第三方流式布局
        FlowLayout(spacing: DS.Space.s) {
            ForEach(items, id: \.self) { item in
                Button {
                    Haptics.tap()
                    onTap(item)
                } label: {
                    HStack(spacing: 4) {
                        if showsFlame {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(ActivityTag.rising.tint)
                        }
                        Text(item)
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(DS.bgSecondary))
                    .overlay(Capsule().strokeBorder(DS.separator, lineWidth: 1))
                }
                .buttonStyle(.springPressSilent)
            }
        }
    }
}

/// 简易流式布局：按可用宽度自动换行
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview("搜索页") {
    SearchView()
}
