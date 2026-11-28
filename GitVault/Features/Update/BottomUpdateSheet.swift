//
//  BottomUpdateSheet.swift
//  GitVault
//
//  更新卡专用底部弹层：从屏幕底部升起，点遮罩或下拖关闭。
//  不用系统 sheet，避免它在外层有 NavigationStack / overlay 时表现不一致。
//

import SwiftUI

struct BottomUpdateSheet<Content: View>: View {
    var onClose: () -> Void
    @ViewBuilder var content: () -> Content

    @State private var dragY: CGFloat = 0

    private var dimming: Double {
        let progress = min(max(dragY / 300, 0), 1)
        return 0.45 * (1 - progress * 0.5)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black
                .opacity(dimming)
                .ignoresSafeArea()
                .onTapGesture { close() }

            content()
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 560)
                .background(DS.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.45), radius: 28, y: -10)
                .padding(.horizontal, DS.Space.s)
                .padding(.bottom, 12)
                .offset(y: max(0, dragY))
                .gesture(dragGesture)
        }
        .onAppear {
            dragY = 0
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                let dy = value.translation.height
                // 向下跟手，向上给阻尼，避免整块飞出屏幕
                dragY = dy >= 0 ? dy : dy * 0.22
            }
            .onEnded { value in
                let projected = value.predictedEndTranslation.height
                if projected > 160 || value.translation.height > 110 {
                    close()
                } else {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.8)) { dragY = 0 }
                }
            }
    }

    private func close() {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.9)) {
            dragY = 0
            onClose()
        }
    }
}
