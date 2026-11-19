//
//  RootView.swift
//  GitVault
//
//  根容器：Splash 门禁 → 主框架（内容区 + 悬浮玻璃 Tab Bar）。
//

import SwiftUI

struct RootView: View {
    @State private var showSplash = true
    @State private var tab: AppTab = .explore

    var body: some View {
        ZStack(alignment: .bottom) {
            DS.bgPrimary.ignoresSafeArea()

            // 内容区：Tab 切换淡入 + 轻微放大，避免「硬切」的廉价感
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            GlassTabBar(selection: $tab)
                .padding(.bottom, DS.Space.s)

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .task {
            // Splash 展示时长；后续可换成「首屏数据预热完成」事件
            try? await Task.sleep(nanoseconds: 1_900_000_000)
            withAnimation(.easeInOut(duration: 0.55)) {
                showSplash = false
            }
        }
    }
}

#Preview("根容器") {
    RootView()
}
