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
    @State private var showDiagnostics = false
    @State private var exportFile: ExportFile?
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
            .sheet(isPresented: $showDiagnostics) {
                DiagnosticsView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $exportFile) { file in
                ShareSheet(items: [file.url])
                    .presentationDetents([.medium, .large])
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
                SettingsRow(symbol: "stethoscope", title: "诊断日志",
                            detail: "\(CrashReporter.lineCount()) 行") {
                    showDiagnostics = true
                }
                Divider().padding(.leading, 52)
                SettingsRow(symbol: "doc.on.doc", title: "复制环境信息", detail: nil) {
                    UIPasteboard.general.string = CrashReporter.environmentSummary()
                    env.show("环境信息已复制", kind: .success)
                }
                Divider().padding(.leading, 52)
                SettingsRow(symbol: "info.circle", title: "关于 GitVault", detail: versionText) {
                    if let url = URL(string: "https://github.com/yfgqh/gitvault") { openURL(url) }
                }
                Divider().padding(.leading, 52)
                SettingsRow(symbol: "envelope", title: "反馈问题", detail: nil) {
                    if let url = URL(string: "https://github.com/yfgqh/gitvault/issues") { openURL(url) }
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
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var clientID = AppConfig.oauthClientID
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    HStack(spacing: DS.Space.m) {
                        GBLogoMark(size: 52, glow: false)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("连接 GitHub")
                                .font(DS.Typo.cardTitle)
                                .foregroundStyle(DS.textPrimary)
                            Text("使用 Device Flow，无需回调地址，Token 存在 Keychain")
                                .font(DS.Typo.caption)
                                .foregroundStyle(DS.textTertiary)
                        }
                        Spacer()
                    }

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
                    }

                    switch auth.status {
                    case .waiting:
                        waitingCard
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
                    case .idle:
                        EmptyView()
                    }

                    Spacer(minLength: 0)

                    if auth.status == .waiting {
                        Button {
                            auth.cancel()
                            Haptics.tap()
                        } label: {
                            Text("取消授权")
                                .font(DS.Typo.body)
                                .foregroundStyle(DS.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                                        .fill(DS.bgSecondary)
                                )
                        }
                        .buttonStyle(.springPressSilent)
                    } else {
                        Button {
                            Haptics.medium()
                            Task { await auth.start() }
                        } label: {
                            Text(auth.isSignedIn ? "重新授权" : "开始授权")
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
// MARK: - 诊断日志

struct DiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DS.Space.s) {
                Text("如果 App 闪退，把这份日志贴到 issue 里就能定位到具体步骤。日志只记录启动阶段与错误摘要，不包含 Token。")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.textTertiary)
                    .padding(.horizontal, DS.Space.m)
                    .padding(.top, DS.Space.s)

                ScrollView {
                    Text(text.isEmpty ? "暂无日志" : text)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(DS.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DS.Space.m)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .fill(DS.bgSecondary)
                )
                .padding(.horizontal, DS.Space.m)
            }
            .background(DS.bgPrimary)
            .navigationTitle("诊断日志")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("清空") {
                        CrashReporter.clear()
                        text = CrashReporter.readLog()
                        Haptics.tap()
                    }
                    .font(DS.Typo.caption)
                    .foregroundStyle(DS.danger)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.accent)
                }
            }
            .onAppear { text = CrashReporter.readLog() }
        }
    }
}

#Preview("我的") {
    ProfileView()
        .environmentObject(AppEnvironment.live())
        .environmentObject(AuthStore())
        .environmentObject(VaultStore(fileName: "preview-vault.json"))
}
