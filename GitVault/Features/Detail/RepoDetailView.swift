//
//  RepoDetailView.swift
//  GitVault
//
//  项目详情（iOS 16）。
//  布局刻意避开两个已知卡死源：
//  1) 不用 `.safeAreaInset(edge: .bottom)` + hidden navigation bar 的组合（iOS 16 会反复重排）
//  2) 不在 ScrollView 内部注册 `navigationDestination`（会让导航状态反复重算）
//

import SwiftUI

struct RepoDetailView: View {
    let repo: ShowcaseRepo

    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var vault: VaultStore
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    @StateObject private var vm: DetailViewModel
    @State private var showOriginal = false
    @State private var readmeExpanded = false
    @State private var showCode = false
    @State private var showGraph = false
    @State private var showPro = false
    @State private var showReadmeFull = false
    @State private var showAuthor = false
    @State private var showDownloadOptions = false
    @State private var exportedURL: URL?
    @State private var isStarred = false
    @State private var isBusy = false
    @StateObject private var downloader = RepoDownloader()

    // 吸顶折叠标题
    @State private var scrollOffset: CGFloat = 0
    @State private var collapseSettle: CGFloat = 0
    @State private var settleTask: Task<Void, Never>?

    init(repo: ShowcaseRepo) {
        self.repo = repo
        _vm = StateObject(wrappedValue: DetailViewModel(repo: repo))
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Space.l) {
                        GeometryReader { g in
                            Color.clear.preference(
                                key: DetailScrollKey.self,
                                value: g.frame(in: .named("detailScroll")).minY
                            )
                        }
                        .frame(height: 0)

                        hero
                            // 视差：向上滚动时头图慢半拍（只跟随 35%）
                            .offset(y: min(0, scrollOffset) * 0.35)
                            .scaleEffect(1 - collapseProgress * 0.04, anchor: .bottom)

                        titleBlock
                            .screenPadding()
                            .opacity(Double(1 - collapseProgress))
                            .scaleEffect(1 - collapseProgress * 0.06, anchor: .topLeading)
                            .offset(y: -collapseProgress * 26)
                        statsCard.screenPadding()
                        HealthCard(repo: vm.repo).screenPadding()
                        readmeCard.screenPadding()
                        actionRow.screenPadding()
                        tagsSection.screenPadding()
                        similarSection

                        Color.clear.frame(height: DS.Space.m)
                    }
                    // 关键：把宽度钉死为屏幕宽。垂直 ScrollView 给出的宽度提案
                    // 会让内部 GeometryReader（语言条、进度条）算出超大宽度，
                    // 从而把整页撑到屏幕外（表现为内容错位、文字被裁切）。
                    .frame(width: proxy.size.width, alignment: .leading)
                }
                .scrollIndicators(.hidden)
                .coordinateSpace(name: "detailScroll")
                .onPreferenceChange(DetailScrollKey.self) { value in
                    handleScroll(value)
                }

                bottomBar
                    .frame(width: proxy.size.width)
            }
        }
        .background(DS.bgPrimary.ignoresSafeArea())
        .navigationTitle(vm.repo.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(DS.bgPrimary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            env.isShowingDetail = true
            vault.clearNewRelease(id: repo.id)
        }
        .onDisappear { env.isShowingDetail = false }
        .task {
            vm.llm = env.llm
            if let item = vault.item(id: repo.id) {
                vm.mark = item.mark
                vm.isSaved = true
            }
        }
        .task { await vm.loadDetailIfNeeded() }
        .task { await vm.loadReadmeIfNeeded() }
        .task {
            guard env.auth.isSignedIn else { return }
            isStarred = await GitHubExtrasService.shared.isStarred(owner: vm.repo.owner, repo: vm.repo.name)
        }
        .onChange(of: downloader.notice) { newValue in
            if let newValue {
                env.show(newValue, kind: .info)
                downloader.clearNotice()
            }
        }
        .onChange(of: downloader.state) { newValue in
            if case .finished(let url) = newValue {
                env.show(String(format: NSLocalizedString("已保存：%@", comment: ""), url.lastPathComponent), kind: .success)
                // 下载完成即提供「保存到文件」的选择
                exportedURL = url
            }
            if case .failed(let message) = newValue {
                env.show(message, kind: .warning)
            }
        }
        .confirmationDialog("下载内容", isPresented: $showDownloadOptions, titleVisibility: .visible) {
            Button("下载二进制文件") {
                downloader.start(owner: vm.repo.owner, repo: vm.repo.name, branch: "main")
            }
            Button("下载仓库源码") {
                downloader.startSource(owner: vm.repo.owner, repo: vm.repo.name, branch: "main")
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("二进制文件来自该仓库的 Release 资产；没有资产时会自动改下源码包。")
        }
        .sheet(isPresented: $showAuthor) {
            AuthorView(login: vm.repo.owner)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showReadmeFull) {
            ReadmeFullView(repo: vm.repo, markdown: vm.readmeMarkdown ?? "")
        }
        .sheet(item: Binding(
            get: { exportedURL.map { ExportTarget(url: $0) } },
            set: { exportedURL = $0?.url }
        )) { target in
            DocumentExporter(url: target.url)
        }
        .sheet(isPresented: $downloader.showsAssetPicker) {
            AssetPickerView(downloader: downloader)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCode) {
            CodeBrowserView(repo: vm.repo)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showGraph) {
            RepoGraphView(repo: vm.repo)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPro) {
            ProUnlockView()
                .environmentObject(env)
        }
    }

    // MARK: 折叠进度

    /// 0 = 展开，1 = 完全收进顶栏
    private var collapseProgress: CGFloat {
        let raw = min(max(-scrollOffset / 132, 0), 1)
        return max(raw, collapseSettle)
    }

    /// 滚动停下后判断：停在半途就自己收到底（单向吸附，不强行改滚动位置）
    private func handleScroll(_ value: CGFloat) {
        let previous = scrollOffset
        scrollOffset = value

        // 用户仍在滑动：放弃吸附，交给实时进度
        if abs(value - previous) > 1.5 {
            collapseSettle = 0
        }
        // 回到顶部：复位
        if value > -4 {
            collapseSettle = 0
        }

        settleTask?.cancel()
        guard value < -40 else { return }
        settleTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 260_000_000)
            guard !Task.isCancelled else { return }
            let raw = min(max(-value / 132, 0), 1)
            if raw > 0.35, raw < 0.92 {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                    collapseSettle = 1
                }
            }
        }
    }

    // MARK: Hero

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: vm.repo.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)

            Circle()
                .fill(.white.opacity(0.20))
                .frame(width: 220, height: 220)
                .blur(radius: 70)
                .offset(x: 130, y: -80)

            HStack(alignment: .bottom, spacing: DS.Space.m) {
                AvatarView(
                    url: vm.repo.avatarURL,
                    size: 64,
                    initials: vm.repo.initials,
                    gradient: vm.repo.gradient
                )

                VStack(alignment: .leading, spacing: 3) {
                    Button {
                        Haptics.tap()
                        showAuthor = true
                    } label: {
                        HStack(spacing: 3) {
                            Text(vm.repo.owner)
                                .font(DS.Typo.caption)
                                .foregroundStyle(.white.opacity(0.85))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .buttonStyle(.plain)
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
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.cardLarge, style: .continuous))
        .padding(.horizontal, DS.Space.s)
        .padding(.top, DS.Space.s)
    }

    // MARK: 标题区

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            ScrollView(.horizontal, showsIndicators: false) {
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

            Text(vm.repo.summary)
                .font(DS.Typo.body)
                .foregroundStyle(DS.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let updated = vm.repo.updatedAt {
                HStack(spacing: 5) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 9, weight: .semibold))
                    Text("最近更新：" + updated.formatted(date: .abbreviated, time: .shortened))
                    Text("· " + relativeText(updated))
                }
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
                    Text(String(format: NSLocalizedString("主语言 %@", comment: ""), vm.repo.language))
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

    // MARK: README（原文优先，英文自动翻译）

    private var readmeCard: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DS.accent)
                    Text("README 摘要")
                        .font(DS.Typo.headline)
                        .foregroundStyle(DS.textPrimary)
                    TagChip(text: vm.readmeSource, tint: DS.accentAlt, compact: true)
                }
                Spacer()
                if vm.showingTranslation {
                    Button {
                        Haptics.tap()
                        withAnimation(DS.Motion.snappy) { showOriginal.toggle() }
                    } label: {
                        Text(showOriginal ? "看译文" : "看原文")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(DS.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(DS.accent.opacity(0.12)))
                    }
                    .buttonStyle(.springPressSilent)
                }
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

            Text(currentReadmeText)
                .font(DS.Typo.bodySmall)
                .foregroundStyle(DS.textSecondary)
                .lineLimit(readmeExpanded ? nil : (vm.showingTranslation ? 14 : 8))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                if vm.isTranslating || vm.isLoadingReadme {
                    ProgressView().scaleEffect(0.55).tint(DS.accent)
                }
                Text(vm.readmeHint)
                    .font(.system(size: 10))
                    .foregroundStyle(DS.textTertiary)
                Spacer()
                if vm.needsTranslationRetry {
                    Button {
                        Haptics.tap()
                        Task { await vm.retryTranslation() }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.clockwise.circle")
                                .font(.system(size: 9, weight: .bold))
                            Text("重试翻译")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(DS.warning)
                    }
                    .buttonStyle(.springPressSilent)
                }

                if vm.readmeMarkdown != nil {
                    Button {
                        Haptics.tap()
                        showReadmeFull = true
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "doc.richtext")
                                .font(.system(size: 9, weight: .bold))
                            Text("查看完整 README")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(DS.accent)
                    }
                    .buttonStyle(.springPressSilent)
                }

                Button {
                    Haptics.tap()
                    Task { await vm.loadReadmeIfNeeded(force: true, bypassCache: true) }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9, weight: .bold))
                        Text("重新读取")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(DS.accent)
                }
                .buttonStyle(.springPressSilent)
            }
        }
        .padding(DS.Space.m)
        .glassSurface()
    }

    private var currentReadmeText: String {
        if vm.showingTranslation, showOriginal {
            return vm.readmeOriginal ?? vm.readmeDisplayText
        }
        return vm.readmeDisplayText
    }

    // MARK: 快捷操作（星标 / Fork / 代码 / 下载 / 结构）

    private var actionRow: some View {
        HStack(spacing: DS.Space.s) {
            actionButton(symbol: isStarred ? "star.fill" : "star",
                         title: isStarred ? "已星标" : "星标",
                         tint: MyMark.starred.tint,
                         showsProgress: isBusy && !downloader.isDownloading) {
                toggleStar()
            }

            actionButton(symbol: "arrow.triangle.branch",
                         title: "Fork",
                         tint: DS.accent,
                         showsProgress: false) {
                forkRepo()
            }

            actionButton(symbol: "chevron.left.forwardslash.chevron.right",
                         title: "代码",
                         tint: DS.accentAlt,
                         showsProgress: false) {
                showCode = true
            }

            actionButton(symbol: "square.and.arrow.down",
                         title: downloadTitle,
                         tint: DS.success,
                         showsProgress: downloader.isDownloading) {
                startDownload()
            }

            actionButton(symbol: "point.3.connected.trianglepath.dotted",
                         title: "结构",
                         tint: DS.warning,
                         showsProgress: false) {
                showGraph = true
            }
        }
    }

    private func actionButton(symbol: String,
                              title: String,
                              tint: Color,
                              showsProgress: Bool,
                              action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if showsProgress {
                        ProgressView().scaleEffect(0.6).tint(tint)
                    } else {
                        Image(systemName: symbol)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(tint)
                    }
                }
                .frame(width: 26, height: 20)

                Text(title)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(DS.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                    .fill(DS.bgSecondary)
            )
        }
        .buttonStyle(.springPressSilent)
    }

    // MARK: 写操作

    private func toggleStar() {
        guard env.auth.isSignedIn else {
            env.show("请先在「我的」里登录 GitHub", kind: .warning)
            return
        }
        guard !isBusy else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                if isStarred {
                    try await GitHubExtrasService.shared.unstar(owner: vm.repo.owner, repo: vm.repo.name)
                    isStarred = false
                    env.show("已取消星标")
                } else {
                    try await GitHubExtrasService.shared.star(owner: vm.repo.owner, repo: vm.repo.name)
                    isStarred = true
                    env.show(String(format: NSLocalizedString("已星标 %@", comment: ""), vm.repo.fullName), kind: .success)
                }
                Haptics.success()
            } catch {
                env.show(String(format: NSLocalizedString("操作失败：%@", comment: ""), error.localizedDescription), kind: .warning)
            }
        }
    }

    private func forkRepo() {
        guard env.auth.isSignedIn else {
            env.show("Fork 需要登录 GitHub", kind: .warning)
            return
        }
        guard !isBusy else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                // GitHub 对「无权访问」也返回 404，先取一次仓库确认可达性，
                // 才能把「权限不足」和「仓库真的不存在」区分开
                let target = try await GitHubExtrasService.shared.repository(
                    owner: vm.repo.owner,
                    repo: vm.repo.name
                )
                let forked = try await GitHubExtrasService.shared.fork(
                    owner: target.owner.login,
                    repo: target.name
                )
                env.show(String(format: NSLocalizedString("已 Fork 到 %@", comment: ""), forked.fullName), kind: .success)
                Haptics.success()
            } catch GitHubError.unauthorized {
                env.show("Fork 失败：登录已失效，请重新登录", kind: .warning)
            } catch GitHubError.forbidden {
                env.show("Fork 失败：令牌缺少 public_repo 权限，请到「我的 → GitHub 登录」重新授权", kind: .warning)
            } catch GitHubError.notFound {
                env.show("Fork 失败：仓库不可访问（可能已改名/删除），或令牌缺少 public_repo 权限", kind: .warning)
            } catch {
                env.show("Fork 失败：\(error.localizedDescription)", kind: .warning)
            }
        }
    }

    private var downloadTitle: String {
        if case .downloading(let progress) = downloader.state {
            return "\(Int(progress * 100))%"
        }
        return "下载"
    }

    private func startDownload() {
        showDownloadOptions = true
    }

    private func relativeText(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.localizedString(for: date, relativeTo: .now)
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

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 82, maximum: 140), spacing: 8)],
                          spacing: 8) {
                    ForEach(MyMark.allCases) { item in
                        Button {
                            apply(mark: item)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: item.symbol)
                                    .font(.system(size: 11, weight: .semibold))
                                Text(item.title)
                                    .font(DS.Typo.caption)
                                    .lineLimit(1)
                            }
                            .foregroundStyle(vm.mark == item ? .white : item.tint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                Capsule().fill(vm.mark == item
                                               ? AnyShapeStyle(item.tint)
                                               : AnyShapeStyle(item.tint.opacity(0.12)))
                            )
                        }
                        .buttonStyle(.springPressSilent)
                    }
                }
            }
        }
    }

    // MARK: 相似项目（destination 已由根 NavigationStack 注册）

    /// 优先用远端搜索结果；没有结果时用本地全量库里的同类项目兜底，
    /// 避免「从发现页进来时相似项目整块消失」。
    private var similarItems: [ShowcaseRepo] {
        if !vm.similar.isEmpty { return vm.similar }
        return Array(env.allRepos.items(in: vm.repo.category)
            .filter { $0.id != vm.repo.id }
            .sorted { $0.stars > $1.stars }
            .prefix(6))
    }

    @ViewBuilder
    private var similarSection: some View {
        let items = similarItems
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: DS.Space.m) {
                SectionHeader(title: "相似项目", subtitle: "同主题的高星仓库",
                              actionTitle: nil, onAction: nil)
                    .screenPadding()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Space.m) {
                        ForEach(items) { item in
                            NavigationLink(value: item) {
                                RepoMiniCard(repo: item)
                            }
                            .buttonStyle(.springPressCard)
                        }
                    }
                    .padding(.horizontal, DS.Space.screen)
                }
            }
        }
    }

    // MARK: 底部操作栏（固定在 VStack 底部，不用 safeAreaInset）

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
        .padding(.top, DS.Space.s)
        .padding(.bottom, DS.Space.s)
        .background(DS.bgPrimary)
        .overlay(alignment: .top) {
            Rectangle().fill(DS.separator).frame(height: 1)
        }
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


    // MARK: 动作

    private func toggleSave() {
        if vault.isSaved(repo.id) {
            vault.remove(id: repo.id)
            vm.isSaved = false
            vm.mark = nil
            env.show(String(format: NSLocalizedString("已取消收藏：%@", comment: ""), repo.name))
            Haptics.tap()
        } else {
            vault.toggle(vm.repo, mark: .starred)
            vm.isSaved = true
            vm.mark = .starred
            Haptics.success()
            env.show(String(format: NSLocalizedString("已收藏：%@", comment: ""), repo.name), kind: .success)
        }
    }

    private func apply(mark: MyMark) {
        // 再次点击同一个标记 = 取消：把该项目从收藏库移除
        if vm.mark == mark {
            vault.remove(id: vm.repo.id)
            vm.isSaved = false
            vm.mark = nil
            Haptics.warning()
            env.show(String(format: NSLocalizedString("已取消「%@」", comment: ""), mark.title), kind: .info)
            return
        }

        if vault.isSaved(vm.repo.id) {
            vault.setMark(id: vm.repo.id, to: mark)
        } else {
            vault.toggle(vm.repo, mark: mark)
            vm.isSaved = true
        }
        vm.mark = mark
        Haptics.medium()
        env.show(String(format: NSLocalizedString("已标记为「%@」", comment: ""), mark.title), kind: .success)
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

/// 详情页顶部偏移
struct DetailScrollKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
