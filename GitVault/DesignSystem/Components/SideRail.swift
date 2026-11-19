//
//  SideRail.swift
//  GitVault
//
//  iPad / 横屏分栏用的竖向导航轨道（与 iPhone 的悬浮 Tab Bar 共用同一套状态）。
//

import SwiftUI

struct SideRail: View {
    @Binding var selection: AppTab
    @Namespace private var pill
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        VStack(spacing: DS.Space.s) {
            GBLogoMark(size: 40, glow: false)
                .padding(.bottom, DS.Space.m)

            ForEach(AppTab.allCases) { tab in
                Button {
                    guard selection != tab else { return }
                    Haptics.selection()
                    withAnimation(DS.Motion.tab) { selection = tab }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 18, weight: .semibold))
                            .symbolEffect(.bounce, value: selection == tab)
                        Text(tab.title)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(selection == tab ? Color.white : DS.textTertiary)
                    .frame(width: 64, height: 56)
                    .background {
                        if selection == tab {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(DS.accentGradient)
                                .matchedGeometryEffect(id: "railPill", in: pill)
                                .shadow(color: DS.accent.opacity(0.4), radius: 12, y: 4)
                        }
                    }
                }
                .buttonStyle(.springPressSilent)
                .accessibilityLabel(tab.title)
            }

            Spacer()

            // 登录态小指示
            AvatarView(
                url: env.auth.user?.avatarURL.flatMap(URL.init(string:)),
                size: 36,
                initials: "G"
            )
            .padding(.bottom, DS.Space.s)
        }
        .padding(.vertical, DS.Space.l)
        .frame(width: 92)
        .background(DS.bgSecondary.opacity(0.55))
        .overlay(alignment: .trailing) {
            Rectangle().fill(DS.separator).frame(width: 1)
        }
    }
}
