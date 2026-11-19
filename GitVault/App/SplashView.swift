//
//  SplashView.swift
//  GitVault
//
//  启动页：墨黑底 + 渐变 Logo 微动效 + 中文 Slogan。
//

import SwiftUI

struct SplashView: View {
    @State private var appeared = false
    @State private var pulse = false
    @State private var glow = false

    var body: some View {
        ZStack {
            DS.logoBase.ignoresSafeArea()

            // 背景渐变光晕
            RadialGradient(
                colors: [DS.accent.opacity(glow ? 0.28 : 0.14), .clear],
                center: .center,
                startRadius: 10,
                endRadius: 320
            )
            .ignoresSafeArea()

            VStack(spacing: DS.Space.l) {
                GBLogoMark(size: 108)
                    .scaleEffect(appeared ? (pulse ? 1.03 : 1.0) : 0.72)
                    .rotationEffect(.degrees(appeared ? 0 : -18))
                    .opacity(appeared ? 1 : 0)

                VStack(spacing: DS.Space.s) {
                    Text("GitVault")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("发现值得收藏的开源项目")
                        .font(DS.Typo.body)
                        .foregroundStyle(.white.opacity(0.62))
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.85, dampingFraction: 0.72)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                glow = true
            }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true).delay(0.3)) {
                pulse = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("GitVault，发现值得收藏的开源项目")
    }
}

#Preview("启动页") {
    SplashView()
}
