//
//  SettingsSheetView.swift
//  GitVault
//
//  首页齿轮弹出的快捷设置面板（外观 + 关于）。
//

import SwiftUI

struct SettingsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PreferenceKey.appearance) private var appearanceRaw: String = AppearanceMode.dark.rawValue

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .dark
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    VStack(alignment: .leading, spacing: DS.Space.s) {
                        Text("外观")
                            .font(DS.Typo.headline)
                            .foregroundStyle(DS.textPrimary)

                        HStack(spacing: DS.Space.s) {
                            ForEach(AppearanceMode.allCases) { mode in
                                Button {
                                    Haptics.selection()
                                    withAnimation(DS.Motion.fade) { appearanceRaw = mode.rawValue }
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: mode.symbol)
                                            .font(.system(size: 16, weight: .semibold))
                                        Text(mode.title)
                                            .font(DS.Typo.micro)
                                    }
                                    .foregroundStyle(appearance == mode ? Color.white : DS.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: DS.Radius.chip + 4, style: .continuous)
                                            .fill(appearance == mode
                                                  ? AnyShapeStyle(DS.accentGradient)
                                                  : AnyShapeStyle(DS.bgSecondary))
                                    )
                                }
                                .buttonStyle(.springPressSilent)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: DS.Space.s) {
                        Text("默认偏好")
                            .font(DS.Typo.headline)
                            .foregroundStyle(DS.textPrimary)

                        VStack(spacing: 0) {
                            SettingsRow(symbol: "bell.badge", title: "飙升提醒", detail: "关闭") {}
                            Divider().padding(.leading, 52)
                            SettingsRow(symbol: "textformat.size", title: "字号跟随系统", detail: "已开启") {}
                        }
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                                .fill(DS.bgSecondary)
                        )
                    }
                }
                .padding(DS.Space.l)
            }
            .background(DS.bgPrimary)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.accent)
                }
            }
        }
    }
}

#Preview("设置面板") {
    SettingsSheetView()
}
