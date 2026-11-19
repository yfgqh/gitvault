//
//  EmptyStateView.swift
//  GitVault
//
//  空状态：用 SF Symbols 组合出「插画感」，避免引入图片资源。
//

import SwiftUI

struct EmptyStateView: View {
    var symbol: String
    var title: String
    var message: String
    var actionTitle: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: DS.Space.m) {
            ZStack {
                Circle()
                    .fill(DS.accent.opacity(0.10))
                    .frame(width: 128, height: 128)
                    .blur(radius: 2)

                Circle()
                    .strokeBorder(DS.accent.opacity(0.16), lineWidth: 1)
                    .frame(width: 96, height: 96)

                Image(systemName: symbol)
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(DS.accentGradient)
            }
            .frame(height: 140)

            VStack(spacing: 6) {
                Text(title)
                    .font(DS.Typo.cardTitle)
                    .foregroundStyle(DS.textPrimary)

                Text(message)
                    .font(DS.Typo.bodySmall)
                    .foregroundStyle(DS.textTertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, DS.Space.xl)

            if let actionTitle, let onAction {
                Button {
                    Haptics.tap()
                    onAction()
                } label: {
                    Text(actionTitle)
                        .font(DS.Typo.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, DS.Space.l)
                        .padding(.vertical, 11)
                        .background(Capsule().fill(DS.accentGradient))
                }
                .buttonStyle(.springPress)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("空状态") {
    ZStack {
        DS.bgPrimary.ignoresSafeArea()
        EmptyStateView(
            symbol: "magnifyingglass",
            title: "还没搜索过什么",
            message: "试试搜索「SwiftUI」「RAG」或「Rust CLI」"
        )
    }
}
