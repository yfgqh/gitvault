//
//  LiquidMotion.swift
//  GitVault
//
//  四条手感动效的公共实现：
//  · LiquidTabBar —— 选中胶囊「前沿先到、后沿跟上」，像一滴水流过去
//  · CaterpillarSegmented —— 下划线跟着手指走，先伸长再收尾
//  · LiquidSheet —— 底部弹窗升起时背景后退，可拖着走也能甩着关
//

import SwiftUI

// MARK: - 弹簧参数

enum LiquidSpring {
    /// 前沿：刚度高、回弹快，负责「先到」
    static let lead = Animation.interpolatingSpring(stiffness: 420, damping: 30)
    /// 后沿：刚度低 + 微延迟，负责「跟上」
    static let trail = Animation.interpolatingSpring(stiffness: 250, damping: 24).delay(0.05)
    /// 闭合 / 吸附
    static let settle = Animation.spring(response: 0.42, dampingFraction: 0.86)
    /// 跟手时的即时响应
    static let track = Animation.interactiveSpring(response: 0.18, dampingFraction: 0.9)
}

// MARK: - ① 水滴胶囊指示器

/// 收集每个 tab 在自己坐标系里的位置
struct TabFrameKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// 会拉长再收拢的胶囊。leading / trailing 分别独立动画，
/// 于是移动过程中宽度先变大再复原 —— 视觉上像一滴水被吸过去。
struct LiquidIndicator: View {
    var leading: CGFloat
    var trailing: CGFloat
    var height: CGFloat
    var cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(DS.accentGradient)
            .frame(width: max(0, trailing - leading), height: height)
            .offset(x: leading)
            .shadow(color: DS.accent.opacity(0.45), radius: 12, y: 4)
    }
}

// MARK: - ④ 毛毛虫分段控件

/// 下划线的 leading / trailing 分别由进度驱动：
/// 前半程只动 trailing（伸长），后半程才动 leading（收尾）。
struct CaterpillarSegmented: View {
    let titles: [String]
    @Binding var selection: Int

    @State private var itemFrames: [Int: CGRect] = [:]
    @State private var progress: CGFloat = 0
    @State private var isDragging = false

    private var space: String { "caterpillar" }

    var body: some View {
        GeometryReader { geo in
            let count = max(titles.count, 1)
            let itemWidth = geo.size.width / CGFloat(count)

            ZStack(alignment: .topLeading) {
                // 下划线
                Capsule(style: .continuous)
                    .fill(DS.accentGradient)
                    .frame(width: max(0, underlineTrailing - underlineLeading), height: 3)
                    .offset(x: underlineLeading, y: geo.size.height - 3)
                    .opacity(itemFrames.isEmpty ? 0 : 1)

                HStack(spacing: 0) {
                    ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                        Button {
                            Haptics.selection()
                            withAnimation(LiquidSpring.settle) { progress = CGFloat(index) }
                            selection = index
                        } label: {
                            Text(title)
                                .font(.system(size: 12, weight: selection == index ? .semibold : .regular))
                                .foregroundStyle(selection == index ? DS.textPrimary : DS.textTertiary)
                                .frame(width: itemWidth, height: geo.size.height)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background {
                            GeometryReader { g in
                                Color.clear.preference(
                                    key: CaterpillarFrameKey.self,
                                    value: [index: g.frame(in: .named(space))]
                                )
                            }
                        }
                    }
                }
                .coordinateSpace(name: space)
            }
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        isDragging = true
                        // 手指位置换算成连续索引：划多少跟多少
                        let startX = CGFloat(selection) * itemWidth + itemWidth / 2
                        let x = startX + value.translation.width
                        let raw = (x - itemWidth / 2) / itemWidth
                        progress = min(max(raw, 0), CGFloat(max(titles.count - 1, 0)))
                    }
                    .onEnded { _ in
                        isDragging = false
                        let target = Int(progress.rounded())
                        withAnimation(LiquidSpring.settle) { progress = CGFloat(target) }
                        if target != selection {
                            Haptics.selection()
                            selection = target
                        }
                    }
            )
            .onPreferenceChange(CaterpillarFrameKey.self) { frames in
                itemFrames = frames
            }
            .onAppear { progress = CGFloat(selection) }
            .onChange(of: selection) { newValue in
                guard !isDragging else { return }
                withAnimation(LiquidSpring.settle) { progress = CGFloat(newValue) }
            }
        }
        .frame(height: 34)
    }

    // MARK: 下划线位置

    private var underlineLeading: CGFloat {
        let (a, b, f) = interpolation()
        // 后半程才收尾
        let k = max(0, f * 2 - 1)
        return a.minX + (b.minX - a.minX) * k
    }

    private var underlineTrailing: CGFloat {
        let (a, b, f) = interpolation()
        // 前半程先伸长
        let k = min(1, f * 2)
        return a.maxX + (b.maxX - a.maxX) * k
    }

    /// 返回相邻两项的 frame 与中间进度
    private func interpolation() -> (CGRect, CGRect, CGFloat) {
        let lower = Int(floor(progress))
        let upper = min(lower + 1, titles.count - 1)
        let frac = progress - CGFloat(lower)
        let a = itemFrames[lower] ?? fallbackFrame(lower)
        let b = itemFrames[upper] ?? fallbackFrame(upper)
        return (a, b, frac)
    }

    private func fallbackFrame(_ index: Int) -> CGRect {
        CGRect(x: CGFloat(index) * 80, y: 0, width: 80, height: 34)
    }
}

struct CaterpillarFrameKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - ② 背后后退的底部弹窗

extension View {
    /// 自定义底部弹窗：背景随弹窗升起而缩小后退，支持拖拽与甩动关闭。
    func liquidSheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        modifier(LiquidSheetModifier(isPresented: isPresented, sheetContent: content))
    }
}

struct LiquidSheetModifier<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    @ViewBuilder var sheetContent: () -> SheetContent

    @State private var dragY: CGFloat = 0
    @GestureState private var isDragging = false

    private let backdropScale: CGFloat = 0.93
    private let backdropCorner: CGFloat = 22

    func body(content: Content) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // 背后的页面：缩放 + 圆角 + 轻微下沉
                content
                    .scaleEffect(isPresented ? backdropScale : 1, anchor: .top)
                    .offset(y: isPresented ? 10 : 0)
                    .clipShape(
                        RoundedRectangle(cornerRadius: isPresented ? backdropCorner : 0, style: .continuous)
                    )
                    .brightness(isPresented ? -0.05 : 0)
                    .allowsHitTesting(!isPresented)
                    .animation(LiquidSpring.settle, value: isPresented)

                if isPresented {
                    Color.black
                        .opacity(0.42 * backdropDimming)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture { close() }

                    sheetContent()
                        .frame(maxHeight: geo.size.height * 0.88)
                        .padding(.horizontal, DS.Space.s)
                        .padding(.bottom, max(geo.safeAreaInsets.bottom, 12))
                        .background(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .fill(DS.bgSecondary)
                                .shadow(color: .black.opacity(0.35), radius: 24, y: -6)
                                .padding(.horizontal, DS.Space.s)
                                .padding(.bottom, max(geo.safeAreaInsets.bottom, 12))
                        )
                        .offset(y: max(0, dragY))
                        .gesture(dragGesture)
                        .transition(.move(edge: .bottom))
                }
            }
            .animation(LiquidSpring.settle, value: isPresented)
        }
    }

    /// 拖动越多，背景越亮（恢复），形成「托着走」的手感
    private var backdropDimming: CGFloat {
        let progress = min(max(dragY / 320, 0), 1)
        return 1 - progress * 0.45
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                // 上滑时给一点阻尼，避免整块被顶出屏幕
                let translation = value.translation.height
                dragY = translation >= 0 ? translation : translation * 0.25
            }
            .onEnded { value in
                let projected = value.predictedEndTranslation.height
                let shouldClose = projected > 160 || value.translation.height > 120
                if shouldClose {
                    withAnimation(LiquidSpring.settle) { isPresented = false }
                    dragY = 0
                } else {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { dragY = 0 }
                }
            }
    }

    private func close() {
        withAnimation(LiquidSpring.settle) { isPresented = false }
    }
}
