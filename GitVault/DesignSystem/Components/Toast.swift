//
//  Toast.swift
//  GitVault
//
//  玻璃质感轻提示，挂在页面顶部，自动消失。
//

import SwiftUI

struct ToastHost: ViewModifier {
    @EnvironmentObject private var env: AppEnvironment

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let toast = env.toast {
                HStack(spacing: 8) {
                    Image(systemName: icon(for: toast.kind))
                        .font(.system(size: 12, weight: .bold))
                    Text(toast.text)
                        .font(DS.Typo.caption)
                        .lineLimit(2)
                }
                .foregroundStyle(DS.textPrimary)
                .padding(.horizontal, DS.Space.m)
                .padding(.vertical, 10)
                .glassSurface(radius: 14)
                .dsShadow(.light)
                .padding(.top, DS.Space.s)
                .transition(.move(edge: .top).combined(with: .opacity))
                .id(toast.id)
            }
        }
    }

    private func icon(for kind: ToastMessage.Kind) -> String {
        switch kind {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }
}

extension View {
    func toastHost() -> some View { modifier(ToastHost()) }
}
