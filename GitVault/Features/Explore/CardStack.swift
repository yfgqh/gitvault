//
//  CardStack.swift
//  GitVault
//
//  封面流（CoverFlow）：中间一张最大，两侧沿 Y 轴旋转立起并向内透视。
//  与父级纵向滚动共存：只有横向主导的拖动才接管手势。
//

import SwiftUI

struct CardStack<Item: Identifiable, Card: View>: View {
    let items: [Item]
    let visibleCount: Int
    /// 是否正在横向拖动（供父级关闭纵向滚动）
    var isHorizontalDrag: Binding<Bool> = .constant(false)
    @ViewBuilder var card: (Item) -> Card
    var onTap: (Item) -> Void

    @State private var index: Int = 0
    @State private var drag: CGFloat = 0
    @State private var lockedAxis: Axis? = nil

    private var count: Int { items.count }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let cardWidth = width * 0.76
            let step = cardWidth * 0.46
            let progress = CGFloat(index) - drag / max(step, 1)

            ZStack {
                ForEach(Array(items.enumerated()), id: \.element.id) { offset, item in
                    let delta = CGFloat(offset) - progress

                    if abs(delta) < 2.4 {
                        card(item)
                            .frame(width: cardWidth)
                            .scaleEffect(scale(for: delta))
                            .rotation3DEffect(
                                .degrees(Double(delta) * -42),
                                axis: (x: 0, y: 1, z: 0),
                                anchor: delta < 0 ? .trailing : .leading,
                                perspective: 0.42
                            )
                            .offset(x: delta * step)
                            .opacity(opacity(for: delta))
                            .zIndex(20 - Double(abs(delta)))
                            .allowsHitTesting(abs(delta) < 0.5)
                            .onTapGesture {
                                guard abs(delta) < 0.5 else { return }
                                Haptics.tap()
                                onTap(item)
                            }
                    }
                }
            }
            .frame(width: width, height: geo.size.height)
            .simultaneousGesture(dragGesture(step: step))
        }
    }

    private func scale(for delta: CGFloat) -> CGFloat {
        max(0.68, 1 - abs(delta) * 0.16)
    }

    private func opacity(for delta: CGFloat) -> Double {
        Double(max(0.25, 1 - abs(delta) * 0.34))
    }

    private func dragGesture(step: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let dx = value.translation.width
                let dy = value.translation.height

                // 首次移动时锁定方向：横向才接管，纵向交还给外层 ScrollView
                if lockedAxis == nil {
                    guard abs(dx) > 6 || abs(dy) > 6 else { return }
                    if abs(dx) > abs(dy) * 1.2 {
                        lockedAxis = .horizontal
                        isHorizontalDrag.wrappedValue = true
                    } else {
                        lockedAxis = .vertical
                    }
                }
                guard lockedAxis == .horizontal else { return }

                // 两端加阻尼，避免拖出边界太远
                if (index == 0 && dx > 0) || (index == count - 1 && dx < 0) {
                    drag = dx * 0.32
                } else {
                    drag = dx
                }
            }
            .onEnded { value in
                let wasHorizontal = lockedAxis == .horizontal
                lockedAxis = nil
                isHorizontalDrag.wrappedValue = false

                guard wasHorizontal else { return }

                let projected = value.predictedEndTranslation.width
                let moved = abs(projected) > step * 0.42 || abs(value.translation.width) > step * 0.34

                var target = index
                if moved {
                    target += (projected < 0 || value.translation.width < 0) ? 1 : -1
                }
                target = min(max(target, 0), max(count - 1, 0))

                withAnimation(.interpolatingSpring(stiffness: 260, damping: 30)) {
                    index = target
                    drag = 0
                }
                if target != index {
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
    }
}
