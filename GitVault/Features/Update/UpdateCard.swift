//
//  UpdateCard.swift
//  GitVault
//
//  更新提示卡：显示版本差异与更新说明，直接下载 IPA，不再跳 Telegram。
//

import SwiftUI

struct UpdateCard: View {
    let available: UpdateChecker.Available

    /// 在弹窗里使用时由外部提供：点 × 需要同时关掉包裹它的 sheet。
    /// 声明在其它属性之后，保证 memberwise init 的调用顺序是 (available:onClose:)。
    var onClose: (() -> Void)? = nil

    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.openURL) private var openURL
    @StateObject private var installer = UpdateInstaller()
    @State private var exportedURL: URL?
    @State private var showFolderPicker = false
    @State private var pickedFolderName: String?
    @State private var showNotes = false
    @State private var selectedAsset: UpdateChecker.Asset?

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var noteLines: [String] {
        available.notes
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            header

            if !noteLines.isEmpty {
                notesBlock
            }

            actionArea
        }
        .padding(DS.Space.m)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(DS.bgSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .strokeBorder(DS.accent.opacity(0.35), lineWidth: 1)
        )
        .sheet(item: Binding(
            get: { exportedURL.map { ExportTarget(url: $0) } },
            set: { exportedURL = $0?.url }
        )) { target in
            DocumentExporter(url: target.url)
        }
        .onChange(of: installer.phase) { phase in
            if case .finished(let url) = phase {
                // 下载完成后弹出系统的「存储到文件」，让用户自己选保存位置
                exportedURL = url
                Haptics.success()
            }
            if case .failed(let message) = phase {
                env.show(message, kind: .warning)
            }
        }
    }

    // MARK: 头部

    private var header: some View {
        HStack(alignment: .top, spacing: DS.Space.s) {
            ZStack {
                Circle().fill(DS.accent.opacity(0.14)).frame(width: 38, height: 38)
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DS.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("发现新版本")
                    .font(.system(size: 10))
                    .foregroundStyle(DS.textTertiary)
                HStack(spacing: 5) {
                    Text(currentVersion)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(DS.textTertiary)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(DS.textTertiary)
                    Text(available.tag)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.textPrimary)
                }
            }

            Spacer(minLength: 0)

            Button {
                Haptics.tap()
                env.update.dismissBanner()
                onClose?()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DS.textTertiary)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(DS.bgTertiary))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: 更新说明

    private var notesBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(noteLines.prefix(showNotes ? 30 : 4).enumerated()), id: \.offset) { _, line in
                Text(line.replacingOccurrences(of: "#", with: ""))
                    .font(.system(size: 10))
                    .foregroundStyle(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if noteLines.count > 4 {
                Button {
                    Haptics.tap()
                    withAnimation(DS.Motion.snappy) { showNotes.toggle() }
                } label: {
                    Text(showNotes ? NSLocalizedString("收起", comment: "") : String(format: NSLocalizedString("展开全部 %d 行", comment: ""), noteLines.count))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DS.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Space.s)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                .fill(DS.bgPrimary.opacity(0.5))
        )
    }

    // MARK: 操作区

    @ViewBuilder
    private var actionArea: some View {
        switch installer.phase {
        case .downloading(let progress):
            VStack(spacing: 4) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(DS.accent)
                HStack {
                    Text(String(format: NSLocalizedString("正在下载 %d%% · %@", comment: ""), Int(progress * 100), installer.activeRoute.title))
                        .font(.system(size: 10))
                        .foregroundStyle(DS.textTertiary)
                    Spacer()
                    Button("取消") {
                        installer.cancel()
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DS.danger)
                }
            }
        case .finished:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(DS.success)
                Text(NSLocalizedString("下载完成，请选择保存位置", comment: ""))
                    .font(.system(size: 10))
                    .foregroundStyle(DS.textSecondary)
                Spacer()
                Button("再存一次") {
                    if case .finished(let url) = installer.phase { exportedURL = url }
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DS.accent)
            }
        default:
            VStack(spacing: 6) {
                if available.assets.count > 1 {
                    assetPicker
                }

                Button {
                    startDownload()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 11, weight: .bold))
                        Text(downloadTitle)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(DS.accentGradient))
                }
                .buttonStyle(.springPress)

                HStack(spacing: DS.Space.m) {
                    Button {
                        Haptics.tap()
                        env.update.snooze()
                    } label: {
                        Text("稍后再说")
                            .font(.system(size: 10))
                            .foregroundStyle(DS.textTertiary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        Haptics.tap()
                        if let url = available.url { openURL(url) }
                    } label: {
                        Text("查看发布页")
                            .font(.system(size: 10))
                            .foregroundStyle(DS.textTertiary)
                    }
                    .buttonStyle(.plain)
                }

                Text("下载后请选择保存位置，再用 TrollStore 或自签工具安装")
                    .font(.system(size: 9))
                    .foregroundStyle(DS.textTertiary.opacity(0.8))
            }
        }
    }

    /// 当前选中的资产（默认 IPA）
    private var active: UpdateChecker.Asset? {
        selectedAsset ?? available.ipa ?? available.assets.first
    }

    private var assetPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(available.assets) { asset in
                    let isOn = active?.id == asset.id
                    Button {
                        Haptics.selection()
                        selectedAsset = asset
                    } label: {
                        HStack(spacing: 4) {
                            Text(asset.kindLabel)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(isOn ? .white : DS.textTertiary)
                            Text(asset.sizeText)
                                .font(.system(size: 9))
                                .foregroundStyle(isOn ? .white.opacity(0.85) : DS.textTertiary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(isOn ? DS.accent.opacity(0.85) : DS.bgTertiary)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var downloadTitle: String {
        guard let asset = active else { return NSLocalizedString("下载更新", comment: "") }
        let name = asset.name.count > 26 ? asset.kindLabel : asset.name
        if asset.sizeText.isEmpty { return String(format: NSLocalizedString("下载 %@", comment: ""), name) }
        return String(format: NSLocalizedString("下载 %@（%@）", comment: ""), name, asset.sizeText)
    }

    private func startDownload() {
        Haptics.tap()
        // 仓库已公开，资产可匿名下载；登录用户仍带 token 提升额度
        guard let asset = active else {
            env.show("这个版本没有可下载的资产，去发布页看看", kind: .warning)
            if let page = available.url { openURL(page) }
            return
        }
        // 先下载到沙盒，完成后再让用户选择保存位置；失败会自动换镜像重试
        installer.allowsMirrorFallback = true
        installer.download(from: asset.url,
                           filename: asset.name,
                           to: nil)
    }
}
