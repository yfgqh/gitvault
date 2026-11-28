//
//  CardStack.swift
//  GitVault
//
//  可拖拽的卡片堆叠：拖动时按位移旋转，甩出后下一张缩放补位。
//

import SwiftUI

struct CardStack<Item: Identifiable, Card: View>: View {
    let items: [Item]
    let visibleCount: Int
    @ViewBuilder var card: (Item) -> Card
    var onTap: (Item) -> Void

    @State private var index: Int = 0
    @State private var drag: CGSize = .zero
    @State private var isFlyingOut = false

    private var window: [Item] {
        guard !items.isEmpty else { return [] }
        let start = min(index, max(items.count - 1, 0))
        return Array(items[start...].prefix(3))
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack {
                ForEach(Array(window.enumerated().reversed()), id: \.element.id) { offset, item in
                    let isTop = offset == 0

                    card(item)
                        .frame(width: width)
                        // 越靠后越小、越靠下，形成堆叠
                        .scaleEffect(isTop ? 1 : 1 - CGFloat(offset) * 0.045, anchor: .top)
                        .offset(y: isTop ? 0 : CGFloat(offset) * 10)
                        .offset(x: isTop ? drag.width : 0, y: isTop ? drag.height * 0.35 : 0)
                        .rotationEffect(.degrees(isTop ? Double(drag.width / 20) : 0), anchor: .bottom)
                        .opacity(isTop ? 1 : (offset == 1 ? 0.75 : 0.45))
                        .zIndex(isTop ? 10 : Double(10 - offset))
                        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: index)
                        .gesture(isTop ? dragGesture(width: width) : nil)
                        .onTapGesture { if isTop { onTap(item) } }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard !isFlyingOut else { return }
                drag = value.translation
            }
            .onEnded { value in
                guard !isFlyingOut else { return }
                let projected = value.predictedEndTranslation.width
                let shouldFly = abs(projected) > width * 0.42 || abs(value.translation.width) > width * 0.34

                if shouldFly {
                    flyOut(direction: (projected >= 0 ? 1 : -1), width: width)
                } else {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.7)) { drag = .zero }
                }
            }
    }

    private func flyOut(direction: CGFloat, width: CGFloat) {
        isFlyingOut = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeOut(duration: 0.32)) {
            drag = CGSize(width: direction * width * 1.6, height: 40)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            // 复位并把「补位」交给 index 变化触发
            drag = .zero
            isFlyingOut = false
            if !items.isEmpty {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
                    index = (index + 1) % items.count
                }
            }
        }
    }
}
