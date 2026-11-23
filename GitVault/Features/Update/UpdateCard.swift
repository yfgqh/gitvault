//
//  UpdateCard.swift
//  GitVault
//
//  更新提示卡：显示版本差异与更新说明，直接下载 IPA，不再跳 Telegram。
//

import SwiftUI

struct UpdateCard: View {
    let available: UpdateChecker.Available

    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.openURL) private var openURL
    @StateObject private var installer = UpdateInstaller()
    @State private var exportedURL: URL?
    @State private var showFolderPicker = false
    @State private var pickedFolderName: String?
    @State private var showNotes = false

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
        .sheet(isPresented: $showFolderPicker) {
            FolderPicker { url in
                showFolderPicker = false
                beginDownload(to: url)
            }
        }
        .sheet(item: Binding(
            get: { exportedURL.map { ExportTarget(url: $0) } },
            set: { exportedURL = $0?.url }
        )) { target in
            DocumentExporter(url: target.url)
        }
        .onChange(of: installer.phase) { phase in
            if case .finished(let url) = phase {
                // 落到沙盒（用户目录不可写时的兜底）才需要再弹一次导出
                if url.path.contains("/Documents/") {
                    exportedURL = url
                }
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
                HStack(spacing: 6) {
                    Text(available.tag)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.textPrimary)
                    Text("当前 \(currentVersion)")
                        .font(.system(size: 9))
                        .foregroundStyle(DS.textTertiary)
                }
            }

            Spacer(minLength: 0)

            Button {
                Haptics.tap()
                env.update.dismissBanner()
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
                    Text(showNotes ? "收起" : "展开全部 \(noteLines.count) 行")
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
                    Text("正在下载 \(Int(progress * 100))%")
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
                Text(pickedFolderName.map { "已保存到「\($0)」" } ?? "已保存")
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

                Text("先选择保存位置，下载后用 TrollStore 或自签工具安装")
                    .font(.system(size: 9))
                    .foregroundStyle(DS.textTertiary.opacity(0.8))
            }
        }
    }

    private var downloadTitle: String {
        let size = available.sizeText
        if size.isEmpty { return "下载更新" }
        return "下载更新（\(size)）"
    }

    private func startDownload() {
        Haptics.tap()
        guard Keychain.read(Keychain.tokenKey)?.isEmpty == false else {
            env.show("私有仓库需要先登录 GitHub 才能下载", kind: .warning)
            return
        }
        guard available.downloadURL != nil else {
            env.show("这个版本没有附带 IPA，去发布页看看", kind: .warning)
            if let page = available.url { openURL(page) }
            return
        }
        // 先让用户选保存位置，再开始下载
        showFolderPicker = true
    }

    private func beginDownload(to directory: URL) {
        guard let url = available.downloadURL else { return }
        pickedFolderName = directory.lastPathComponent
        installer.download(from: url,
                           filename: available.assetName ?? "GitVault-\(available.tag).ipa",
                           to: directory)
    }
}
