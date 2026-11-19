//
//  RootView.swift
//  GitVault
//
//  根容器（iOS 16 兼容）。
//  iPhone：内容区 + 悬浮玻璃 Tab Bar；iPad / regular 宽度：竖向轨道分栏。
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var showSplash = true
    @State private var tab: AppTab = .explore

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
                    GlassTabBar(selection: $tab)
                        .padding(.bottom, DS.Space.s)
                }
            }

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .toastHost()
        .task {
            await auth.restore()
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            withAnimation(.easeInOut(duration: 0.55)) {
                showSplash = false
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        Group {
            switch tab {
            case .explore: ExploreView()
            case .categories: CategoriesView()
            case .search: SearchView()
            case .vault: VaultView()
            case .profile: ProfileView()
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .center)))
        .animation(DS.Motion.fade, value: tab)
    }
}

#Preview("根容器") {
    RootView()
        .environmentObject(AppEnvironment.live())
        .environmentObject(AuthStore())
        .environmentObject(VaultStore(fileName: "preview-vault.json"))
}
