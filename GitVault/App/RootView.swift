//
//  RootView.swift
//  GitVault
//
//  根容器（iOS 16 兼容）。
//  页面用 ZStack + opacity 保活：切换 Tab 不重建页面、不重复请求，避免「切两次就卡住」。
//  iPhone：悬浮玻璃 Tab Bar；iPad / regular：竖向轨道分栏。
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var vault: VaultStore
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var showSplash = true
    @State private var tab: AppTab = .explore
    /// 已经挂载过的页面（首次进入才构建，之后保活）
    @State private var mounted: Set<AppTab> = [.explore]
    @StateObject private var releaseWatcher = ReleaseWatcher()
    @StateObject private var healthMonitor = RepoHealthMonitor()
    @State private var launchUpdate: UpdateChecker.Available?
    @StateObject private var presenter = DetailPresenter.shared

    // 边缘右滑返回
    @State private var backDrag: CGFloat = 0
    @State private var backArmed = false
    @State private var backTracking = false

    private var screenWidth: CGFloat { UIScreen.main.bounds.width }

    private var backProgress: CGFloat {
        min(max(backDrag / max(screenWidth, 1), 0), 1)
    }

    /// 底层页面以 1/3 速度跟入
    private var backParallax: CGFloat {
        presenter.top == nil ? 0 : -screenWidth / 3 + backDrag / 3
    }

    private var backDim: Double {
        presenter.top == nil ? 0 : Double(backProgress) * 0.28
    }

    var body: some View {
        ZStack {
            DS.bgPrimary.ignoresSafeArea()

            Group {
                if sizeClass == .regular {
                    HStack(spacing: 0) {
                        SideRail(selection: $tab)
                        content
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    ZStack(alignment: .bottom) {
                        content
                        if !env.isShowingDetail {
                            GlassTabBar(selection: $tab)
                                .padding(.bottom, DS.Space.s)
                                .transition(.opacity)
                        }
                    }
                    .animation(DS.Motion.fade, value: env.isShowingDetail)
                }
            }
            .offset(x: backParallax)
            .overlay(
                Color.black
                    .opacity(backDim)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            )

            // 详情页：overlay 呈现，支持视差返回
            if let repo = presenter.top {
                NavigationStack {
                    RepoDetailView(repo: repo)
                }
                .offset(x: backDrag)
                .gesture(backGesture)
                .zIndex(5)
            }

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .toastHost()
        .sheet(item: $launchUpdate) { update in
            ScrollView {
                UpdateCard(available: update, onClose: {
                    withAnimation(DS.Motion.snappy) { launchUpdate = nil }
                })
                .padding(DS.Space.l)
            }
            .background(DS.bgPrimary)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: env.update.available) { newValue in
            if newValue == nil { launchUpdate = nil }
        }
        .onChange(of: tab) { newValue in
            mounted.insert(newValue)
        }
        .task {
            await auth.restore()
            // 这两件事不阻塞启动：StoreKit 与 Releases 都可能慢
            Task { await env.pro.bootstrap() }
            Task {
                await env.update.checkIfNeeded()
                // 有新版：稍等一下再弹，避开启动动画；无新版：什么都不做
                if let update = env.update.consumeLaunchPrompt() {
                    // 等启动页淡出完成，再从底部弹出更新卡，避免两层动画打架
                    try? await Task.sleep(nanoseconds: 1_900_000_000)
                    withAnimation(DS.Motion.snappy) { launchUpdate = update }
                }
            }
            env.allRepos.loadIfNeeded()
            // 收藏仓库的新版本检查（Pro 能力，6 小时节流）
            OfflineIndex.shared.loadIfNeeded()
            if env.pro.hasFullAccess {
                await releaseWatcher.checkIfNeeded(vault: vault)
                await healthMonitor.scanIfNeeded(vault: vault)
            }
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            withAnimation(.easeInOut(duration: 0.55)) {
                showSplash = false
            }
        }
    }

    private var backGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if !backTracking {
                    // 只允许从左边缘开始，且方向必须是向右
                    guard value.startLocation.x < 32, value.translation.width > 0 else { return }
                    backTracking = true
                    backArmed = true
                }
                guard backArmed else { return }
                backDrag = max(0, value.translation.width)
            }
            .onEnded { value in
                guard backArmed else { return }
                let projected = value.predictedEndTranslation.width
                let shouldClose = projected > screenWidth * 0.36
                    || value.translation.width > screenWidth * 0.3

                if shouldClose {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
                        backDrag = screenWidth
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        presenter.close()
                        backDrag = 0
                        backTracking = false
                        backArmed = false
                    }
                } else {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) { backDrag = 0 }
                    backTracking = false
                    backArmed = false
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            ForEach(AppTab.allCases) { item in
                if mounted.contains(item) {
                    page(for: item)
                        .opacity(tab == item ? 1 : 0)
                        .allowsHitTesting(tab == item)
                        .zIndex(tab == item ? 1 : 0)
                }
            }
        }
        // 不再对整棵树做 opacity 动画：那会让 5 个页面同时重绘，
        // 切 Tab 时表现为整屏闪烁（iOS 16 上尤其明显）。
    }

    @ViewBuilder
    private func page(for item: AppTab) -> some View {
        switch item {
        case .explore: ExploreView()
        case .categories: CategoriesView()
        case .search: SearchView()
        case .vault: VaultView()
        case .profile: ProfileView()
        }
    }
}

#Preview("根容器") {
    RootView()
        .environmentObject(AppEnvironment.live())
        .environmentObject(AuthStore())
        .environmentObject(VaultStore(fileName: "preview-vault.json"))
}
