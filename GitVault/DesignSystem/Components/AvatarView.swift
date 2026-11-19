//
//  AvatarView.swift
//  GitVault
//
//  GitHub 头像：AsyncImage + 渐变兜底（离线也有体面观感）。
//  底层走 URLCache（GitHubService 的 session 已挂 shared cache），避免重复下载。
//

import SwiftUI

struct AvatarView: View {
    let url: URL?
    var size: CGFloat = 36
    var initials: String = "G"
    var gradient: [Color] = [DS.accent, DS.accentAlt]

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: DS.Motion.fade)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                fallback
            case .empty:
                fallback.overlay(ProgressView().scaleEffect(0.6).tint(.white.opacity(0.7)))
            @unknown default:
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
        .accessibilityHidden(true)
    }

    private var fallback: some View {
        ZStack {
            LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(initials)
                .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

#Preview("头像") {
    ZStack {
        DS.bgPrimary.ignoresSafeArea()
        HStack(spacing: 16) {
            AvatarView(url: nil, size: 56, initials: "LL")
            AvatarView(url: URL(string: "https://avatars.githubusercontent.com/u/1?v=4"), size: 56)
        }
    }
}
