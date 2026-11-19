//
//  ProfileView.swift
//  GitVault
//
//  我的：账号态、外观切换、数据操作、关于入口。
//

import SwiftUI

struct ProfileView: View {
    @AppStorage(AppPrefs.appearance) private var appearanceRaw: String = AppearanceMode.dark.rawValue
    @State private var showLoginSheet = false

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .dark
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    profileHeader
                        .screenPadding()
                        .padding(.top, DS.Space.s)

                    statsRow
                        .screenPadding()

                    appearanceSection
                        .screenPadding()

                    dataSection
                        .screenPadding()

                    aboutSection
                        .screenPadding()

                    Color.clear.frame(height: DS.Space.tabBarInset)
                }
            }
            .scrollIndicators(.hidden)
            .background(DS.bgPrimary)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showLoginSheet) {
                LoginSheetView()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: 头部

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            HStack(spacing: DS.Space.m) {
                ZStack {
                    Circle().fill(DS.accentGradient)
                    Image(systemName: "person.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 64, height: 64)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
                .dsShadow(.light)

                VStack(alignment: .leading, spacing: 3) {
                    Text("未登录")
                        .font(DS.Typo.cardTitle)
                        .foregroundStyle(DS.textPrimary)
                    Text("登录后可提升接口额度并同步云端")
                        .font(DS.Typo.captionRegular)
                        .foregroundStyle(DS.textTertiary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            Button {
                Haptics.medium()
                showLoginSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.system(size: 13, weight: .semibold))
                    Text("使用 GitHub 账号登录")
                        .font(DS.Typo.caption)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                        .fill(DS.accentGradient)
                )
                .dsShadow(.light)
            }
            .buttonStyle(.springPress)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            StatBlock(value: "0", label: "收藏")
            Divider().frame(height: 26)
            StatBlock(value: "0", label: "在用")
            Divider().frame(height: 26)
            StatBlock(value: "0", label: "观察")
            Divider().frame(height: 26)
            StatBlock(value: "0", label: "归档")
        }
        .padding(.vertical, DS.Space.m)
        .glassSurface()
    }

    // MARK: 外观

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Text("外观")
                .font(DS.Typo.headline)
                .foregroundStyle(DS.textPrimary)

            HStack(spacing: DS.Space.s) {
                ForEach(AppearanceMode.allCases) { mode in
                    Button {
                        Haptics.selection()
                        withAnimation(DS.Motion.fade) {
                            appearanceRaw = mode.rawValue
                        }
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
    }

    // MARK: 数据

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Text("数据")
                .font(DS.Typo.headline)
                .foregroundStyle(DS.textPrimary)

            VStack(spacing: 0) {
                SettingsRow(symbol: "arrow.triangle.2.circlepath", title: "同步 GitHub 数据", detail: "登录后可开启") {}
                Divider().padding(.leading, 52)
                SettingsRow(symbol: "square.and.arrow.up", title: "导出收藏", detail: "JSON / Markdown") {}
                Divider().padding(.leading, 52)
                SettingsRow(symbol: "trash", title: "清理图片缓存", detail: "0 MB", tint: DS.danger) {}
            }
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(DS.bgSecondary)
            )
        }
    }

    // MARK: 关于

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Text("关于")
                .font(DS.Typo.headline)
                .foregroundStyle(DS.textPrimary)

            VStack(spacing: 0) {
                SettingsRow(symbol: "info.circle", title: "关于 GitVault", detail: "v1.0.0 (1)") {}
                Divider().padding(.leading, 52)
                SettingsRow(symbol: "envelope", title: "反馈问题", detail: nil) {}
                Divider().padding(.leading, 52)
                SettingsRow(symbol: "hand.thumbsup", title: "去 GitHub 点个 Star", detail: nil) {}
            }
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(DS.bgSecondary)
            )

            Text("数据来源 GitHub REST API v3，本应用与 GitHub 官方无隶属关系。")
                .font(.system(size: 11))
                .foregroundStyle(DS.textTertiary)
                .padding(.top, DS.Space.s)
        }
    }
}

// MARK: - 通用设置行

struct SettingsRow: View {
    var symbol: String
    var title: String
    var detail: String?
    var tint: Color = DS.textSecondary
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 24)

                Text(title)
                    .font(DS.Typo.body)
                    .foregroundStyle(DS.textPrimary)

                Spacer(minLength: 4)

                if let detail {
                    Text(detail)
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.textTertiary)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DS.textTertiary)
            }
            .padding(.horizontal, DS.Space.m)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 登录说明（阶段 5 接 OAuth）

struct LoginSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.l) {
            HStack(spacing: DS.Space.m) {
                GBLogoMark(size: 52, glow: false)
                VStack(alignment: .leading, spacing: 2) {
                    Text("连接 GitHub")
                        .font(DS.Typo.cardTitle)
                        .foregroundStyle(DS.textPrimary)
                    Text("只读取公开仓库信息，权限最小化")
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.textTertiary)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: DS.Space.s) {
                benefit("每小时 5000 次接口额度（未登录仅 60 次）")
                benefit("收藏与标记在多设备间同步")
                benefit("根据你的收藏推荐相似项目")
            }

            Spacer(minLength: 0)

            Text("OAuth 流程将在阶段 5 接入，Token 会存入 Keychain，绝不写入代码或日志。")
                .font(.system(size: 11))
                .foregroundStyle(DS.textTertiary)

            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Text("知道了")
                    .font(DS.Typo.body)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                            .fill(DS.accentGradient)
                    )
            }
            .buttonStyle(.springPress)
        }
        .padding(DS.Space.l)
        .background(DS.bgPrimary)
    }

    private func benefit(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(DS.accent)
            Text(text)
                .font(DS.Typo.bodySmall)
                .foregroundStyle(DS.textSecondary)
        }
    }
}

#Preview("我的") {
    ProfileView()
}
