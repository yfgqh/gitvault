//
//  ElasticRefresh.swift
//  GitVault
//
//  弹性下拉刷新：内容带阻尼被拉下，图标随下拉距离旋转，
//  松手后若越过阈值则触发刷新，完成后用弹簧回落。
//

import SwiftUI

struct ScrollPullKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ElasticRefresh<Content: View>: View {
    /// 触发刷新的距离
    var threshold: CGFloat = 68
    /// 子视图正在横向拖动时，临时关闭纵向滚动
    var isScrollDisabled: Bool = false
    var action: () async -> Void
    @ViewBuilder var content: () -> Content

    @State private var pull: CGFloat = 0
    @State private var armed = false
    @State private var isRefreshing = false
    @State private var spin: Double = 0
    @State private var showDone = false

    private let elasticRefreshSpace = "elasticRefresh"

    private var progress: CGFloat {
        min(max(pull / threshold, 0), 1.4)
    }

    var body: some View {
        // 坐标空间必须挂在外层容器：ScrollView 自身不提供随滚动变化的坐标系
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    GeometryReader { g in
                        Color.clear.preference(
                            key: ScrollPullKey.self,
                            value: g.frame(in: .named(elasticRefreshSpace)).minY
                        )
                    }
                    .frame(height: 0)

                    indicator
                        .frame(height: 0)
                        .offset(y: min(pull * 0.55, threshold))

                    content()
                }
            }
            .scrollIndicators(.hidden)
            .scrollDisabled(isScrollDisabled)
        }
        .coordinateSpace(name: elasticRefreshSpace)
        .onPreferenceChange(ScrollPullKey.self) { value in
            handle(value)
        }
    }

    // MARK: 指示器

    private var indicator: some View {
        HStack(spacing: 8) {
            Image(systemName: isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.down")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DS.accent)
                // 下拉时随距离旋转：到底转半圈，松手后自转
                .rotationEffect(.degrees(isRefreshing ? spin : Double(progress) * 220))

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DS.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(DS.bgSecondary)
        )
        .overlay(
            Capsule().strokeBorder(DS.separator, lineWidth: 1)
        )
        .scaleEffect(pull > 0 || isRefreshing ? 1 : 0.6, anchor: .center)
        .opacity(pull > 4 || isRefreshing ? 1 : 0)
        .animation(.spring(response: 0.32, dampingFraction: 0.8), value: pull > 4)
    }

    private var label: String {
        if isRefreshing { return "正在刷新…" }
        if showDone { return "已更新" }
        return progress >= 1 ? "松开刷新" : "下拉刷新"
    }

    // MARK: 手势判定

    private func handle(_ value: CGFloat) {
        pull = max(0, value)

        if pull >= threshold, !isRefreshing {
            armed = true
        }
        // 松手回弹到接近 0 且之前越过阈值 → 触发刷新
        if armed, pull < 14, !isRefreshing {
            armed = false
            trigger()
        }
    }

    private func trigger() {
        isRefreshing = true
        showDone = false
        spin = 0
        withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
            spin = 360
        }
        Task { @MainActor in
            await action()
            // 刷新完成：停转 + 弹簧收回
            withAnimation(.easeOut(duration: 0.2)) { spin = 0 }
            isRefreshing = false
            showDone = true
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            try? await Task.sleep(nanoseconds: 700_000_000)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) {
                showDone = false
            }
        }
    }
}
