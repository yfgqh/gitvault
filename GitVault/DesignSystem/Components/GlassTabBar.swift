//
//  GlassTabBar.swift
//  GitVault
//
//  自定义悬浮玻璃 Tab Bar：胶囊高亮块使用 matchedGeometryEffect 做弹性迁移。
//  iOS 16 兼容：不依赖 symbolEffect，用 scale + spring 表达「弹性」。
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
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, DS.Space.s)
        .padding(.vertical, DS.Space.s)
        .background {
            Capsule(style: .continuous).fill(DS.cardGlass)
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        }
        .clipShape(Capsule(style: .continuous))
        .dsShadow(.elevated)
        .padding(.horizontal, DS.Space.l)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("主导航")
    }

    @ViewBuilder
    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selection == tab

        Button {
            guard selection != tab else { return }
            Haptics.selection()
            withAnimation(DS.Motion.tab) {
                selection = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(height: 20)
                    .scaleEffect(isSelected ? 1.12 : 1)
                    .animation(DS.Motion.tab, value: isSelected)

                Text(tab.title)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.white : DS.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(DS.accentGradient)
                        .matchedGeometryEffect(id: "tabPill", in: pill)
                        .shadow(color: DS.accent.opacity(0.45), radius: 12, y: 4)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.springPressSilent)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
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
