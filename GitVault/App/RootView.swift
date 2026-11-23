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

    var body: some View {
        ZStack {
            DS.bgPrimary.ignoresSafeArea()

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

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .toastHost()
        .onChange(of: tab) { newValue in
            mounted.insert(newValue)
        }
        .task {
            await auth.restore()
            // 这两件事不阻塞启动：StoreKit 与 Releases 都可能慢
            Task { await env.pro.bootstrap() }
            Task { await env.update.checkIfNeeded() }
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
