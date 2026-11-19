//
//  ProfileView.swift
//  GitVault
//
//  我的（iOS 16 兼容）：GitHub Device Flow 登录、外观、AI 配置、导出、诊断日志。
//

import SwiftUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var vault: VaultStore
    @Environment(\.openURL) private var openURL

    @AppStorage(AppPrefs.appearance) private var appearanceRaw: String = AppearanceMode.dark.rawValue
    @State private var showAuthSheet = false
    @State private var showAISheet = false

    @State private var exportFile: ExportFile?
    @State private var showAbout = false
    @State private var cacheSizeText = "—"

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .dark
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    accountCard
                        .screenPadding()
                        .padding(.top, DS.Space.s)

                    appearanceSection.screenPadding()
                    aiSection.screenPadding()
                    dataSection.screenPadding()
                    aboutSection.screenPadding()

                    Color.clear.frame(height: DS.Space.tabBarInset)
                }
            }
            .scrollIndicators(.hidden)
            .background(DS.bgPrimary)
            .navigationBarHidden(true)
            .sheet(isPresented: $showAuthSheet) {
                AuthSheetView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showAISheet) {
                AIConfigSheetView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }

            .sheet(item: $exportFile) { file in
                ShareSheet(items: [file.url])
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showAbout) {
                AboutSheetView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .onAppear { updateCacheSize() }
        }
    }

    // MARK: 账号

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            HStack(spacing: DS.Space.m) {
                AvatarView(
                    url: auth.user?.avatarURL.flatMap { URL(string: $0) },
                    size: 64,
                    initials: "G"
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(auth.isSignedIn ? auth.displayName : "未登录")
                        .font(DS.Typo.cardTitle)
                        .foregroundStyle(DS.textPrimary)

                    Text(auth.isSignedIn
                         ? "已连接 GitHub · 每小时 5000 次额度"
                         : "登录后额度提升到每小时 5000 次")
                        .font(DS.Typo.captionRegular)
                        .foregroundStyle(DS.textTertiary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            if auth.isSignedIn {
                HStack(spacing: 0) {
                    StatBlock(value: "\(auth.user?.publicRepos ?? 0)", label: "公开仓库")
                    Divider().frame(height: 26)
                    StatBlock(value: "\(auth.user?.followers ?? 0)", label: "关注者")
                    Divider().frame(height: 26)
                    StatBlock(value: "\(vault.items.count)", label: "我的收藏")
                }

                HStack(spacing: DS.Space.s) {
                    Button {
                        Haptics.tap()
                        if let raw = auth.user?.htmlURL, let url = URL(string: raw) { openURL(url) }
                    } label: {
                        Text("打开主页")
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                                    .fill(DS.accent.opacity(0.12))
                            )
                    }
                    .buttonStyle(.springPressSilent)

                    Button {
                        Haptics.warning()
                        auth.signOut()
                        env.show("已退出 GitHub 账号")
                    } label: {
                        Text("退出登录")
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.danger)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                                    .fill(DS.danger.opacity(0.10))
                            )
                    }
                    .buttonStyle(.springPressSilent)
                }
            } else {
                Button {
                    Haptics.medium()
                    showAuthSheet = true
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
        .padding(DS.Space.m)
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
    }

    // MARK: AI

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Text("AI 摘要")
                .font(DS.Typo.headline)
                .foregroundStyle(DS.textPrimary)

            VStack(spacing: 0) {
                SettingsRow(
                    symbol: "sparkles",
                    title: "大模型分类 / 中文摘要",
                    detail: env.llmModeTitle
                ) {
                    showAISheet = true
                }
            }
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(DS.bgSecondary)
            )

            Text("默认使用内置免费模型（无需 API Key）；也可填入自己的 OpenAI 兼容网关，失败时自动回落到本地规则。")
                .font(.system(size: 11))
                .foregroundStyle(DS.textTertiary)
        }
    }

    // MARK: 数据

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Text("数据")
                .font(DS.Typo.headline)
                .foregroundStyle(DS.textPrimary)

            VStack(spacing: 0) {
                SettingsRow(symbol: "arrow.clockwise", title: "刷新账号资料",
                            detail: auth.isSignedIn ? auth.displayName : "未登录") {
                    Task {
                        await auth.refreshProfile()
                        env.show(auth.isSignedIn ? "资料已刷新" : "请先登录", kind: auth.isSignedIn ? .success : .warning)
                    }
                }
                Divider().padding(.leading, 52)
                SettingsRow(symbol: "square.and.arrow.up", title: "导出收藏", detail: "JSON") {
                    export(.json)
                }
                Divider().padding(.leading, 52)
                SettingsRow(symbol: "square.and.arrow.up", title: "导出收藏", detail: "Markdown") {
                    export(.markdown)
                }
                Divider().padding(.leading, 52)
                SettingsRow(symbol: "photo", title: "清理图片缓存", detail: cacheSizeText) {
                    URLCache.shared.removeAllCachedResponses()
                    updateCacheSize()
                    env.show("图片缓存已清理", kind: .success)
                    Haptics.success()
                }
                Divider().padding(.leading, 52)
                SettingsRow(symbol: "trash", title: "清空收藏库", detail: "不可恢复", tint: DS.danger) {
                    vault.removeAll()
                    env.show("收藏库已清空", kind: .warning)
                }
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
                SettingsRow(symbol: "info.circle", title: "关于 GitVault", detail: versionText) {
                    showAbout = true
                }
                Divider().padding(.leading, 52)
                SettingsRow(symbol: "bubble.left.and.bubble.right", title: "加入 Telegram 群", detail: "反馈 / 交流") {
                    if let url = URL(string: "https://t.me/GitVaultipa") { openURL(url) }
                }
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

    // MARK: 工具

    private var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "3"
        return "v\(version) (\(build))"
    }

    private func updateCacheSize() {
        let bytes = Int(URLCache.shared.currentDiskUsage + URLCache.shared.currentMemoryUsage)
        cacheSizeText = String(format: "%.1f MB", Double(bytes) / 1_048_576)
    }

    private func export(_ format: VaultStore.ExportFormat) {
        do {
            exportFile = ExportFile(url: try vault.export(format), title: "导出 \(format.displayName)")
            Haptics.success()
        } catch {
            env.show("导出失败：\(error.localizedDescription)", kind: .warning)
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

// MARK: - GitHub 登录面板

struct AuthSheetView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case token, oauth
        var id: String { rawValue }
        var title: String { self == .token ? "访问令牌" : "OAuth 授权" }
    }

    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var mode: Mode = .token
    @State private var clientID = AppConfig.oauthClientID
    @State private var tokenInput = ""
    @State private var copied = false
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    header
                    picker

                    if mode == .token {
                        tokenSection
                    } else {
                        oauthSection
                    }

                    statusView

                    Spacer(minLength: 0)

                    primaryButton
                }
                .padding(DS.Space.l)
            }
            .background(DS.bgPrimary)
            .navigationTitle("GitHub 登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.accent)
                }
            }
            .onAppear {
                if auth.isSignedIn { mode = .token }
            }
        }
    }

    // MARK: 头部

    private var header: some View {
        HStack(spacing: DS.Space.m) {
            GBLogoMark(size: 52, glow: false)
            VStack(alignment: .leading, spacing: 2) {
                Text("连接 GitHub")
                    .font(DS.Typo.cardTitle)
                    .foregroundStyle(DS.textPrimary)
                Text(auth.isSignedIn ? "已登录：\(auth.displayName)" : "登录后接口额度提升到 5000 次/小时")
                    .font(DS.Typo.caption)
                    .foregroundStyle(DS.textTertiary)
            }
            Spacer()
        }
    }

    private var picker: some View {
        Picker("登录方式", selection: $mode) {
            ForEach(Mode.allCases) { item in
                Text(item.title).tag(item)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: 令牌

    private var tokenSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Text("个人访问令牌（推荐，最快）")
                .font(DS.Typo.headline)
                .foregroundStyle(DS.textPrimary)

            SecureField("ghp_… 或 github_pat_…", text: $tokenInput)
                .font(DS.Typo.bodySmall)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(DS.Space.m)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                        .fill(DS.bgSecondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                        .strokeBorder(DS.separator, lineWidth: 1)
                )

            Button {
                Haptics.tap()
                if let url = URL(string: "https://github.com/settings/tokens/new?scopes=read:user&description=GitVault") {
                    openURL(url)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "safari")
                    Text("打开 GitHub 生成令牌（勾选 read:user 即可）")
                }
                .font(DS.Typo.caption)
                .foregroundStyle(DS.accent)
            }
            .buttonStyle(.springPressSilent)

            Text("令牌只保存在本机 Keychain，用于提升 API 额度与同步你的资料；随时可在 GitHub 撤销。")
                .font(.system(size: 11))
                .foregroundStyle(DS.textTertiary)
        }
    }

    // MARK: OAuth

    private var oauthSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Text("OAuth App Client ID")
                .font(DS.Typo.caption)
                .foregroundStyle(DS.textSecondary)

            TextField("例如 Ov23li…", text: $clientID)
                .font(DS.Typo.bodySmall)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(DS.Space.m)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                        .fill(DS.bgSecondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                        .strokeBorder(DS.separator, lineWidth: 1)
                )
                .onChange(of: clientID) { newValue in
                    AppConfig.oauthClientID = newValue
                }

            Text("在 GitHub → Settings → Developer settings → OAuth Apps 新建应用，勾选 Enable Device Flow 后填入 Client ID。")
                .font(.system(size: 11))
                .foregroundStyle(DS.textTertiary)

            if auth.status == .waiting {
                waitingCard
            }
        }
    }

    // MARK: 状态

    @ViewBuilder
    private var statusView: some View {
        switch auth.status {
        case .requesting:
            HStack(spacing: 8) {
                ProgressView().tint(DS.accent)
                Text("正在申请验证码…")
                    .font(DS.Typo.caption)
                    .foregroundStyle(DS.textSecondary)
            }
        case .signedIn:
            Label("已登录：\(auth.displayName)", systemImage: "checkmark.seal.fill")
                .font(DS.Typo.bodySmall)
                .foregroundStyle(DS.success)
        case .failed(let message):
            Text(message)
                .font(DS.Typo.caption)
                .foregroundStyle(DS.danger)
                .fixedSize(horizontal: false, vertical: true)
        case .waiting, .idle:
            EmptyView()
        }
    }

    private var waitingCard: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            Text("1. 复制下方验证码")
                .font(DS.Typo.caption)
                .foregroundStyle(DS.textSecondary)

            HStack(spacing: DS.Space.m) {
                Text(auth.userCode ?? "------")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.textPrimary)
                    .tracking(3)

                Spacer()

                Button {
                    UIPasteboard.general.string = auth.userCode
                    copied = true
                    Haptics.success()
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.accent)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(DS.accent.opacity(0.12)))
                }
                .buttonStyle(.springPressSilent)
                .accessibilityLabel("复制验证码")
            }

            Text("2. 打开 GitHub 输入验证码并授权")
                .font(DS.Typo.caption)
                .foregroundStyle(DS.textSecondary)

            Button {
                Haptics.tap()
                if let url = auth.verificationURL { openURL(url) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "safari")
                    Text("打开 GitHub 授权页")
                }
                .font(DS.Typo.caption)
                .foregroundStyle(DS.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                        .fill(DS.accent.opacity(0.12))
                )
            }
            .buttonStyle(.springPressSilent)

            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.6).tint(DS.accent)
                Text("等待授权中，完成后会自动登录")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.textTertiary)
            }
        }
        .padding(DS.Space.m)
        .glassSurface()
    }

    // MARK: 主按钮

    private var primaryButton: some View {
        Group {
            if auth.isSignedIn {
                HStack(spacing: DS.Space.s) {
                    Button {
                        Haptics.warning()
                        auth.signOut()
                        env.show("已退出登录")
                    } label: {
                        Text("退出登录")
                            .font(DS.Typo.body)
                            .foregroundStyle(DS.danger)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                                    .fill(DS.danger.opacity(0.10))
                            )
                    }
                    .buttonStyle(.springPressSilent)

                    Button {
                        Task {
                            await auth.refreshProfile()
                            env.show("资料已刷新", kind: .success)
                        }
                    } label: {
                        Text("刷新资料")
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
            } else if mode == .token {
                Button {
                    Haptics.medium()
                    isSubmitting = true
                    Task {
                        let ok = await auth.signIn(withToken: tokenInput)
                        isSubmitting = false
                        if ok {
                            env.show("登录成功：\(auth.displayName)", kind: .success)
                            dismiss()
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isSubmitting { ProgressView().scaleEffect(0.7).tint(.white) }
                        Text(isSubmitting ? "正在验证…" : "用令牌登录")
                            .font(DS.Typo.body)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                            .fill(DS.accentGradient)
                    )
                }
                .buttonStyle(.springPress)
                .disabled(tokenInput.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
                .opacity(tokenInput.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            } else {
                Button {
                    Haptics.medium()
                    Task { await auth.start() }
                } label: {
                    Text(auth.status == .waiting ? "重新申请验证码" : "开始授权")
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
                .disabled(clientID.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(clientID.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            }
        }
    }
}
// MARK: - 大模型配置

struct AIConfigSheetView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var endpoint = ""
    @State private var model = ""
    @State private var apiKey = ""
    @State private var didLoad = false

    private var isFreeDefault: Bool {
        endpoint.trimmingCharacters(in: .whitespaces) == LLMConfig.freeDefault.endpoint
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    statusCard

                    VStack(alignment: .leading, spacing: DS.Space.s) {
                        Text("接口地址")
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.textSecondary)
                        TextField("https://…/v1/chat/completions", text: $endpoint)
                            .font(DS.Typo.bodySmall)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .padding(DS.Space.m)
                            .background(
                                RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                                    .fill(DS.bgSecondary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                                    .strokeBorder(DS.separator, lineWidth: 1)
                            )

                        Text("模型名称")
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.textSecondary)
                            .padding(.top, 4)
                        TextField("例如 openai / gpt-4o-mini", text: $model)
                            .font(DS.Typo.bodySmall)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(DS.Space.m)
                            .background(
                                RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                                    .fill(DS.bgSecondary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                                    .strokeBorder(DS.separator, lineWidth: 1)
                            )

                        Text("API Key（内置免费模型留空即可）")
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.textSecondary)
                            .padding(.top, 4)
                        SecureField("sk-…（可留空）", text: $apiKey)
                            .font(DS.Typo.bodySmall)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(DS.Space.m)
                            .background(
                                RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                                    .fill(DS.bgSecondary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                                    .strokeBorder(DS.separator, lineWidth: 1)
                            )
                    }

                    VStack(spacing: DS.Space.s) {
                        Button {
                            let config = LLMConfig(
                                endpoint: endpoint.trimmingCharacters(in: .whitespacesAndNewlines),
                                model: model.trimmingCharacters(in: .whitespacesAndNewlines),
                                apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                            env.applyLLM(config)
                            Haptics.success()
                            env.show("已切换到：\(config.displayName)", kind: .success)
                            dismiss()
                        } label: {
                            Text("保存并启用")
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

                        Button {
                            env.resetLLMToFreeDefault()
                            applyState()
                            Haptics.tap()
                            env.show("已恢复内置免费模型", kind: .success)
                        } label: {
                            Text(isFreeDefault ? "当前已是内置免费模型" : "恢复内置免费模型")
                                .font(DS.Typo.caption)
                                .foregroundStyle(isFreeDefault ? DS.textTertiary : DS.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                                        .fill(DS.bgSecondary)
                                )
                        }
                        .buttonStyle(.springPressSilent)
                        .disabled(isFreeDefault)
                    }

                    Text("说明：内置免费模型来自 Pollinations 的 OpenAI 兼容接口，无需注册；它可能限流或偶发不可用，此时详情页会显示本地规则摘要，不影响使用。API Key 存于 Keychain，不写入代码与日志。")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.textTertiary)
                }
                .padding(DS.Space.l)
            }
            .background(DS.bgPrimary)
            .navigationTitle("AI 摘要设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.accent)
                }
            }
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                applyState()
            }
        }
    }

    private var statusCard: some View {
        HStack(spacing: DS.Space.m) {
            ZStack {
                Circle().fill(DS.accent.opacity(0.14)).frame(width: 42, height: 42)
                Image(systemName: isFreeDefault ? "bolt.horizontal.circle.fill" : "slider.horizontal.3")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DS.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(isFreeDefault ? "内置免费模型" : "自定义模型")
                    .font(DS.Typo.headline)
                    .foregroundStyle(DS.textPrimary)
                Text(isFreeDefault
                     ? "无需 API Key · 开箱可用 · 失败自动回落规则"
                     : "请求将直接发往你填写的地址")
                    .font(DS.Typo.caption)
                    .foregroundStyle(DS.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Space.m)
        .glassSurface()
    }

    private func applyState() {
        endpoint = env.config.endpoint
        model = env.config.model
        apiKey = env.config.apiKey
    }
}

// MARK: - 应用简介

struct AboutSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.6.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "7"
        return "版本 \(v) (\(b))"
    }

    private struct AboutHighlight: Identifiable {
        let icon: String
        let title: String
        let detail: String
        var id: String { title }
    }

    private let highlights: [AboutHighlight] = [
        AboutHighlight(icon: "square.grid.2x2.fill",
                       title: "双层分类体系",
                       detail: "六大主题场景 + 二级子分类，配合状态、语言、许可、用途四组智能标签，把「收藏」变成可检索的结构化资料。"),
        AboutHighlight(icon: "text.alignleft",
                       title: "中文优先的阅读体验",
                       detail: "项目简介与 README 先呈现原文，非中文内容自动交由 AI 译为简洁中文；未联网或模型不可用时回落本地规则，始终有内容可读。"),
        AboutHighlight(icon: "bookmark.fill",
                       title: "本地优先的收藏库",
                       detail: "收藏、观察、在用、归档四态标记，自定义文件夹与拖拽排序，数据全部保存在设备本地，随时可导出 JSON / Markdown。"),
        AboutHighlight(icon: "magnifyingglass",
                       title: "为找项目而设计的搜索",
                       detail: "输入即联想，可按主题、语言、星标区间组合筛选，并记住你的搜索历史。"),
        AboutHighlight(icon: "iphone.gen3",
                       title: "原生体验",
                       detail: "SwiftUI 构建，深色为默认外观，支持浅色与跟随系统；iPhone 与 iPad 自适应布局，完整支持动态字体与旁白。"),
        AboutHighlight(icon: "lock.shield.fill",
                       title: "隐私优先",
                       detail: "GitHub 令牌仅存于系统钥匙串，不采集任何个人数据，不上传收藏内容。")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    // 头部
                    HStack(spacing: DS.Space.m) {
                        GBLogoMark(size: 64, glow: false)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("GitVault · GitHub 精选")
                                .font(DS.Typo.cardTitle)
                                .foregroundStyle(DS.textPrimary)
                            Text("为中文开发者打造的开源项目收藏与整理工具")
                                .font(DS.Typo.caption)
                                .foregroundStyle(DS.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }

                    Text("""
                    GitVault 把「逛 GitHub 找好项目」这件碎片化的事，收敛成一条清晰路径：发现、分类、收藏、追踪。

                    它不做资讯聚合，也不做代码托管，只专注解决一个具体问题——让你在 GitHub 上看到的好项目，能被记住、被归类、被再次找到。
                    """)
                    .font(DS.Typo.bodySmall)
                    .foregroundStyle(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                    // 功能
                    VStack(alignment: .leading, spacing: DS.Space.m) {
                        Text("核心能力")
                            .font(DS.Typo.headline)
                            .foregroundStyle(DS.textPrimary)

                        ForEach(highlights) { item in
                            HStack(alignment: .top, spacing: DS.Space.m) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(DS.accent)
                                    .frame(width: 26, height: 26)
                                    .background(Circle().fill(DS.accent.opacity(0.12)))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title)
                                        .font(DS.Typo.body)
                                        .foregroundStyle(DS.textPrimary)
                                    Text(item.detail)
                                        .font(DS.Typo.captionRegular)
                                        .foregroundStyle(DS.textTertiary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }

                    // 优势
                    VStack(alignment: .leading, spacing: DS.Space.s) {
                        Text("为什么用它")
                            .font(DS.Typo.headline)
                            .foregroundStyle(DS.textPrimary)

                        Text("""
                        浏览器书签只记得住链接，笔记软件记不住结构。GitVault 用主题分类代替杂乱文件夹，用标签代替自由文本，并给每个项目配一句中文说明——半年后再打开，你依然知道它是什么、当初为什么收藏。
                        """)
                        .font(DS.Typo.captionRegular)
                        .foregroundStyle(DS.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    // 页脚
                    VStack(alignment: .leading, spacing: DS.Space.s) {
                        Text(version)
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.textTertiary)

                        Text("数据来源 GitHub REST API v3。本应用与 GitHub 官方无隶属关系，所有项目内容版权归原作者所有。")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            Haptics.tap()
                            if let url = URL(string: "https://t.me/GitVaultipa") { openURL(url) }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "paperplane.fill")
                                Text("加入 Telegram 群")
                            }
                            .font(DS.Typo.caption)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                                    .fill(DS.accentGradient)
                            )
                        }
                        .buttonStyle(.springPress)
                        .padding(.top, DS.Space.s)
                    }
                }
                .padding(DS.Space.l)
            }
            .background(DS.bgPrimary)
            .navigationTitle("关于")
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