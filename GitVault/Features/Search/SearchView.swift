//
//  SearchView.swift
//  GitVault
//
//  搜索页：300ms 防抖 + 真实 GitHub 搜索 + 主题/语言/star 筛选 + 分页 + 历史持久化。
//

import SwiftUI

struct SearchView: View {
    @State private var vm = SearchViewModel()
    @FocusState private var fieldFocused: Bool
    @Environment(\.horizontalSizeClass) private var sizeClass

    private let starOptions: [StarOption] = [
        StarOption(title: "不限", value: nil),
        StarOption(title: "1k+", value: 1_000),
        StarOption(title: "10k+", value: 10_000),
        StarOption(title: "50k+", value: 50_000)
    ]

    /// 常用语言（GitHub 语言名，用于 language: 限定）
    private let languages = ["Swift", "Python", "TypeScript", "Rust", "Go",
                             "C++", "Java", "Kotlin", "Dart", "JavaScript"]

    private var searchKey: String {
        "\(vm.query)|\(vm.activeCategory?.rawValue ?? "-")|\(vm.activeLanguage ?? "-")|\(vm.minStars ?? 0)|\(vm.sort.rawValue)"
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
            .task(id: searchKey) {
                await vm.perform(debounced: true)
            }
        }
    }

    // MARK: 搜索框

    private var searchField: some View {
        HStack(spacing: DS.Space.s) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DS.textTertiary)

            TextField("搜索开源项目、语言或主题", text: $vm.query)
                .font(DS.Typo.body)
                .foregroundStyle(DS.textPrimary)
                .focused($fieldFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit {
                    vm.record(vm.query)
                    Task { await vm.perform(debounced: false) }
                }

            if !vm.query.isEmpty {
                Button {
                    Haptics.tap()
                    vm.query = ""
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
                FilterChip(title: "全部主题", isActive: vm.activeCategory == nil) {
                    withAnimation(DS.Motion.snappy) { vm.activeCategory = nil }
                }
                ForEach(RepoCategory.allCases) { category in
                    FilterChip(title: category.title, emoji: category.emoji,
                               isActive: vm.activeCategory == category) {
                        withAnimation(DS.Motion.snappy) {
                            vm.activeCategory = (vm.activeCategory == category) ? nil : category
                        }
                    }
                }

                Divider().frame(height: 20)

                ForEach(starOptions) { option in
                    FilterChip(title: "★ " + option.title, isActive: vm.minStars == option.value) {
                        withAnimation(DS.Motion.snappy) { vm.minStars = option.value }
                    }
                }

                Divider().frame(height: 20)

                ForEach(languages, id: \.self) { language in
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

    // MARK: 内容

    @ViewBuilder
    private var content: some View {
        if vm.isBlank {
            discoverySection
        } else if vm.isSearching && vm.results.isEmpty {
            VStack(spacing: DS.Space.s) {
                SkeletonList(count: 3)
                SkeletonList(count: 2)
            }
            .screenPadding()
        } else if let message = vm.errorMessage {
            EmptyStateView(symbol: "exclamationmark.icloud",
                           title: "搜索失败",
                           message: message,
                           actionTitle: "重试") {
                Task { await vm.perform(debounced: false) }
            }
            .padding(.top, DS.Space.l)
        } else if vm.results.isEmpty {
            EmptyStateView(symbol: "magnifyingglass",
                           title: "没有找到「\(vm.query)」",
                           message: "换个关键词，或去掉筛选条件再试试")
            .padding(.top, DS.Space.l)
        } else {
            resultList
        }
    }

    private var resultList: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            HStack {
                Text("找到 \(ShowcaseRepo.compact(vm.totalCount)) 个结果")
                    .font(DS.Typo.caption)
                    .foregroundStyle(DS.textTertiary)
                Spacer()
                Menu {
                    ForEach([SearchSort.stars, .forks, .updated], id: \.rawValue) { sort in
                        Button {
                            Haptics.selection()
                            vm.sort = sort
                            Task { await vm.perform(debounced: false) }
                        } label: {
                            HStack {
                                Text(sortTitle(sort))
                                if vm.sort == sort {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(sortTitle(vm.sort))
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .font(DS.Typo.caption)
                    .foregroundStyle(DS.accent)
                }
            }
            .screenPadding()

            ForEach(vm.results.indexed) { entry in
                NavigationLink(value: entry.item) {
                    RepoCard(repo: entry.item)
                }
                .buttonStyle(.springPressCard)
                .staggerAppear(min(entry.index, 8))
                .screenPadding()
                .task { await vm.loadMoreIfNeeded(current: entry.item) }
            }

            if vm.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView().tint(DS.accent)
                    Spacer()
                }
                .padding(.vertical, DS.Space.m)
            }
        }
    }

    private var discoverySection: some View {
        VStack(alignment: .leading, spacing: DS.Space.l) {
            if !vm.history.isEmpty {
                VStack(alignment: .leading, spacing: DS.Space.s) {
                    HStack {
                        Text("搜索历史")
                            .font(DS.Typo.headline)
                            .foregroundStyle(DS.textPrimary)
                        Spacer()
                        Button {
                            Haptics.tap()
                            withAnimation(DS.Motion.fade) { vm.clearHistory() }
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(DS.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("清空搜索历史")
                    }

                    FlowChips(items: vm.history) { item in
                        vm.query = item
                        Task { await vm.perform(debounced: false) }
                    }
                }
                .screenPadding()
            }

            VStack(alignment: .leading, spacing: DS.Space.s) {
                Text("热门搜索")
                    .font(DS.Typo.headline)
                    .foregroundStyle(DS.textPrimary)

                FlowChips(items: MockData.hotKeywords, showsFlame: true) { item in
                    vm.query = item
                    vm.record(item)
                    Task { await vm.perform(debounced: false) }
                }
            }
            .screenPadding()
        }
    }

    private func sortTitle(_ sort: SearchSort) -> String {
        switch sort {
        case .stars: return "按 Star"
        case .forks: return "按 Fork"
        case .updated: return "按更新"
        }
    }
}

// MARK: - 选项模型

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
        // 防御：ScrollView 里 proposal.width 可能是 nil / 0 / inf，直接参与布局会得到非法尺寸
        let raw = proposal.width ?? 0
        let maxWidth: CGFloat = (raw.isFinite && raw > 1) ? raw : 320
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
        return CGSize(width: max(maxWidth.isFinite ? maxWidth : 320, x), height: max(y + rowHeight, 0))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard bounds.width.isFinite, bounds.height.isFinite else { return }
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
            subview.place(at: CGPoint(x: x, y: y),
                          anchor: .topLeading,
                          proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview("搜索页") {
    SearchView()
}
