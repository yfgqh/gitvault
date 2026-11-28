//
//  CardStack.swift
//  GitVault
//
//  封面流（CoverFlow）：中间一张最大，两侧沿 Y 轴旋转立起并向内透视，
//  拖动时整排跟着手指走，松手吸附到最近一张。
//

import SwiftUI

struct CardStack<Item: Identifiable, Card: View>: View {
    let items: [Item]
    let visibleCount: Int
    @ViewBuilder var card: (Item) -> Card
    var onTap: (Item) -> Void

    @State private var index: Int = 0
    @State private var drag: CGFloat = 0
    @State private var isDragging = false

    private var count: Int { items.count }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let cardWidth = width * 0.76
            let step = cardWidth * 0.46
            // 拖动时的连续位置：向右拖（正）露出前一张
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
            .contentShape(Rectangle())
            .gesture(horizontalDrag(step: step))
        }
    }

    private func scale(for delta: CGFloat) -> CGFloat {
        // 中间最大，越远越小（最低 0.68）
        max(0.68, 1 - abs(delta) * 0.16)
    }

    private func opacity(for delta: CGFloat) -> Double {
        Double(max(0.25, 1 - abs(delta) * 0.34))
    }

    private func horizontalDrag(step: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                isDragging = true
                // 两端加阻尼，避免拖出边界太远
                let raw = value.translation.width
                if (index == 0 && raw > 0) || (index == count - 1 && raw < 0) {
                    drag = raw * 0.35
                } else {
                    drag = raw
                }
            }
            .onEnded { value in
                isDragging = false
                let projected = value.predictedEndTranslation.width
                let moved = abs(projected) > step * 0.42 || abs(value.translation.width) > step * 0.34

                var target = index
                if moved {
                    // 左滑（负位移）看下一张
                    target += (projected < 0 || value.translation.width < 0) ? 1 : -1
                }
                target = min(max(target, 0), max(count - 1, 0))

                withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                    index = target
                    drag = 0
                }
                if target != index {
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
    }
}
