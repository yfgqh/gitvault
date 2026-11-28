//
//  GlassTabBar.swift
//  GitVault
//
//  自定义悬浮玻璃 Tab Bar。
//  选中胶囊不再是整体平移，而是 leading / trailing 两条弹簧分开跑：
//  前沿先到位、后沿延迟跟上，中途宽度被拉长，视觉上像一滴水流过去。
//

import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case explore
    case categories
    case search
    case vault
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .explore: return "发现"
        case .categories: return "分类"
        case .search: return "搜索"
        case .vault: return "收藏"
        case .profile: return "我的"
        }
    }

    /// 英文环境下走 Localizable.strings；中文环境回退为原文
    var localizedTitle: String { NSLocalizedString(title, comment: "") }

    var symbol: String {
        switch self {
        case .explore: return "sparkles"
        case .categories: return "square.grid.2x2.fill"
        case .search: return "magnifyingglass"
        case .vault: return "bookmark.fill"
        case .profile: return "person.fill"
        }
    }
}

struct GlassTabBar: View {
    @Binding var selection: AppTab

    @State private var frames: [Int: CGRect] = [:]
    @State private var leading: CGFloat = 0
    @State private var trailing: CGFloat = 0
    @State private var ready = false

    private let space = "tabbar"

    private var selectionIndex: Int {
        AppTab.allCases.firstIndex(of: selection) ?? 0
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(AppTab.allCases.enumerated()), id: \.element) { index, tab in
                tabButton(tab, index: index)
            }
        }
        .coordinateSpace(name: space)
        .background(alignment: .topLeading) {
            LiquidIndicator(leading: leading,
                            trailing: trailing,
                            height: frames[selectionIndex]?.height ?? 0,
                            cornerRadius: (frames[selectionIndex]?.height ?? 0) / 2)
                .opacity(ready ? 1 : 0)
        }
        .padding(.horizontal, DS.Space.s)
        .padding(.vertical, DS.Space.s)
        .background {
            Capsule(style: .continuous).fill(DS.glassFill)
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        }
        .clipShape(Capsule(style: .continuous))
        .dsShadow(.elevated)
        .padding(.horizontal, DS.Space.l)
        .onPreferenceChange(TabFrameKey.self) { value in
            frames = value
            // 首次布局：不带动画直接归位
            if !ready, let target = value[selectionIndex], target.width > 0 {
                leading = target.minX
                trailing = target.maxX
                ready = true
            }
        }
        .onChange(of: selection) { _ in
            moveIndicator()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("主导航")
    }

    @ViewBuilder
    private func tabButton(_ tab: AppTab, index: Int) -> some View {
        let isSelected = selection == tab

        Button {
            guard selection != tab else { return }
            Haptics.selection()
            selection = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(height: 20)
                    .scaleEffect(isSelected ? 1.12 : 1)
                    .animation(DS.Motion.tab, value: isSelected)

                Text(tab.localizedTitle)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.white : DS.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background {
                GeometryReader { g in
                    Color.clear.preference(
                        key: TabFrameKey.self,
                        value: [index: g.frame(in: .named(space))]
                    )
                }
            }
        }
        .buttonStyle(.springPressSilent)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    // MARK: 水滴移动

    private func moveIndicator() {
        guard let target = frames[selectionIndex], target.width > 0 else { return }
        guard ready else {
            leading = target.minX
            trailing = target.maxX
            ready = true
            return
        }
        let currentMid = (leading + trailing) / 2
        let movingRight = target.midX > currentMid

        if movingRight {
            // 右边缘（前沿）先冲向目标，左边缘随后跟上 → 拉长
            withAnimation(LiquidSpring.lead) { trailing = target.maxX }
            withAnimation(LiquidSpring.trail) { leading = target.minX }
        } else {
            withAnimation(LiquidSpring.lead) { leading = target.minX }
            withAnimation(LiquidSpring.trail) { trailing = target.maxX }
        }
    }
}

#Preview("悬浮 Tab Bar") {
    ZStack {
        DS.bgPrimary.ignoresSafeArea()
        VStack {
            Spacer()
            GlassTabBar(selection: .constant(.explore))
                .padding(.bottom, 24)
        }
    }
}
