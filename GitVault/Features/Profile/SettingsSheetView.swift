//
//  SettingsSheetView.swift
//  GitVault
//
//  首页齿轮弹出的快捷设置面板（外观 + 索引说明）。
//

import SwiftUI

struct SettingsSheetView: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var env: AppEnvironment
    @AppStorage(AppPrefs.appearance) private var appearanceRaw: String = AppearanceMode.dark.rawValue

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
                        Text("数据来源")
                            .font(DS.Typo.headline)
                            .foregroundStyle(DS.textPrimary)

                        VStack(spacing: 0) {
                            SettingsRow(
                                symbol: "network",
                                title: "接口额度",
                                detail: auth.isSignedIn ? "5000 次/小时" : "60 次/小时"
                            ) {}
                            Divider().padding(.leading, 52)
                            SettingsRow(
                                symbol: "sparkles",
                                title: "分类方式",
                                detail: env.llmModeTitle
                            ) {}
                        }
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                                .fill(DS.bgSecondary)
                        )
                    }

                    Text("提示：登录 GitHub 后接口额度提升到 5000 次/小时，收藏与标记也能跨设备同步。")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.textTertiary)
                }
                .padding(DS.Space.l)
            }
            .background(DS.bgPrimary)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
        .environmentObject(AppEnvironment.live())
        .environmentObject(AuthStore())
}
