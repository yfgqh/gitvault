//
//  RepoDownloader.swift
//  GitVault
//
//  仓库下载：
//  1) 先查该仓库最新 Release，若带可执行/打包类资产（.ipa/.apk/.zip/.dmg/.exe…）→ 下载资产
//  2) Release 不存在或没有资产 → 提示后下载源码包（zipball）
//

import Foundation
import Combine

/// 一个可下载的 Release 资产
struct AssetChoice: Identifiable, Equatable {
    let id: String
    let name: String
    let size: Int
    let kind: String
    let url: URL
    var recommended: Bool = false

    var sizeText: String {
        if size > 1024 * 1024 { return String(format: "%.1f MB", Double(size) / 1024 / 1024) }
        if size > 1024 { return "\(size / 1024) KB" }
        return "\(size) B"
    }
}

@MainActor
final class RepoDownloader: NSObject, ObservableObject {
    enum State: Equatable {
        case idle
        case downloading(progress: Double)
        case finished(URL)
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var currentName: String = ""
    /// 需要提示给用户的说明（例如「没有二进制文件，改下源码」）
    @Published private(set) var notice: String?

    /// 多个资产时待选择的列表
    @Published private(set) var assetChoices: [AssetChoice] = []
    /// 是否弹出资产选择器
    @Published var showsAssetPicker = false
    /// 没有任何二进制资产时置位：由界面询问「是否下载仓库源码」
    @Published var asksForSource = false
    /// 有二进制资产时置位：交给界面跳转到 Releases 页面
    @Published var releasesPage: URL?

    private var pendingSource: (owner: String, repo: String, branch: String)?

    private var session: URLSession?
    private var task: URLSessionDownloadTask?

    var isDownloading: Bool {
        if case .downloading = state { return true }
        return false
    }

    func clearNotice() {
        notice = nil
    }

    // MARK: 入口

    func start(owner: String, repo: String, branch: String) {
        guard !isDownloading else { return }
        pendingSource = (owner, repo, branch)
        currentName = "\(owner)-\(repo).zip"
        assetChoices = []
        Haptics.tap()

        Task {
            let choices = await resolveAssets(owner: owner, repo: repo)

            switch choices.count {
            case 0:
                // 没有二进制：询问是否下载源码
                state = .idle
                asksForSource = true
            case 1:
                // 只有一个文件：直接下，少一次点击
                if let only = choices.first {
                    notice = "正在下载 " + only.name
                    beginDownload(only.url, fileName: only.name)
                }
            default:
                // 多个文件：列出名字让用户挑
                assetChoices = choices
                state = .idle
                showsAssetPicker = true
            }
        }
    }

    /// 用户在资产选择器里选定后的入口
    func choose(_ asset: AssetChoice) {
        showsAssetPicker = false
        assetChoices = []
        beginDownload(asset.url, fileName: asset.name)
    }

    /// 直接下载源码包（详情页选择「仓库源码」时调用）
    func startSource(owner: String, repo: String, branch: String) {
        guard !isDownloading else { return }
        pendingSource = (owner, repo, branch)
        asksForSource = false
        notice = "正在下载源码包"
        downloadSource()
    }

    /// 选择器里的「下载源码包」
    func chooseSourcePackage() {
        showsAssetPicker = false
        assetChoices = []
        asksForSource = false
        notice = "正在下载源码包"
        downloadSource()
    }

    func dismissPicker() {
        showsAssetPicker = false
        assetChoices = []
        state = .idle
    }

    /// 面板里的次要入口：在浏览器打开发布页
    func openReleasesInBrowser() {
        guard let pendingSource else { return }
        releasesPage = URL(string: "https://github.com/\(pendingSource.owner)/\(pendingSource.repo)/releases")
        showsAssetPicker = false
        assetChoices = []
        state = .idle
    }

    func cancel() {
        task?.cancel()
        task = nil
        session?.invalidateAndCancel()
        session = nil
        state = .idle
    }

    // MARK: 内部

    /// 资产分类：安装包 > 压缩包 > 其他
    private static func kind(of name: String) -> String {
        let lower = name.lowercased()
        let installers = [".ipa", ".apk", ".dmg", ".pkg", ".msix", ".appx",
                          ".exe", ".msi", ".deb", ".rpm", ".apk"]
        let archives = [".zip", ".tar.gz", ".tgz", ".7z", ".tar", ".xz", ".gz"]
        if installers.contains(where: { lower.hasSuffix($0) }) { return "安装包" }
        if archives.contains(where: { lower.hasSuffix($0) }) { return "压缩包" }
        return "其他"
    }

    private static func rank(of kind: String) -> Int {
        switch kind {
        case "安装包": return 0
        case "压缩包": return 1
        default: return 2
        }
    }

    /// 拉取 latest release 的资产并排序（安装包优先，同类按体积降序）
    private func resolveAssets(owner: String, repo: String) async -> [AssetChoice] {
        guard let release = try? await GitHubExtrasService.shared.latestRelease(owner: owner, repo: repo) else {
            return []
        }
        let assets = release.assets ?? []
        var list: [AssetChoice] = []
        for asset in assets {
            guard let url = URL(string: asset.browserDownloadURL) else { continue }
            list.append(AssetChoice(
                id: asset.browserDownloadURL,
                name: asset.name,
                size: asset.size,
                kind: RepoDownloader.kind(of: asset.name),
                url: url
            ))
        }
        list.sort { lhs, rhs in
            let l = RepoDownloader.rank(of: lhs.kind)
            let r = RepoDownloader.rank(of: rhs.kind)
            if l != r { return l < r }
            return lhs.size > rhs.size
        }
        if !list.isEmpty {
            list[0].recommended = true
        }
        return list
    }

    /// 下载源码包（zipball）
    private func downloadSource() {
        guard let pendingSource else {
            state = .failed("缺少仓库信息，请重试")
            return
        }
        guard let url = GitHubExtrasService.shared.zipballURL(
            owner: pendingSource.owner,
            repo: pendingSource.repo,
            branch: pendingSource.branch
        ) else {
            state = .failed("下载地址无效")
            return
        }
        beginDownload(url, fileName: "\(pendingSource.owner)-\(pendingSource.repo)-source.zip")
    }

    private func beginDownload(_ url: URL, fileName: String) {
        currentName = fileName
        state = .downloading(progress: 0)
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 1800
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        self.session = session

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("GitVault/2.1", forHTTPHeaderField: "User-Agent")
        if let token = Keychain.read(Keychain.tokenKey), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let task = session.downloadTask(with: request)
        // 目标文件名挂在 task 上：代理方法在非主线程回调，不能直接读 @MainActor 属性
        task.taskDescription = fileName
        self.task = task
        task.resume()
    }

    private func downloadDirectory() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = documents.appendingPathComponent("GitVault/Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}

extension RepoDownloader: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didWriteData bytesWritten: Int64,
                                totalBytesWritten: Int64,
                                totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Task { @MainActor in
            self.state = .downloading(progress: min(max(progress, 0), 1))
        }
    }

    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didFinishDownloadingTo location: URL) {
        // 关键：这个回调一返回，系统就会删除 location 指向的临时文件。
        // 所以必须在这里同步完成搬运，不能丢进 Task 里等主线程调度，
        // 否则会报 "CFNetworkDownload_xxx.tmp ... no such file"。
        // 先校验 HTTP 状态：404 / 限流的 JSON 不能被当成文件保存
        if let response = downloadTask.response as? HTTPURLResponse,
           !(200..<300).contains(response.statusCode) {
            let hint: String
            switch response.statusCode {
            case 404: hint = "文件不存在（可能是私有仓库或已删除）"
            case 403, 429: hint = "接口额度已用完，稍后再试"
            default: hint = "服务器返回 \(response.statusCode)"
            }
            Task { @MainActor in
                self.state = .failed(hint)
            }
            return
        }

        let fallback = downloadTask.originalRequest?.url?.lastPathComponent ?? "repo.zip"
        let described = downloadTask.taskDescription ?? ""
        let name = described.isEmpty ? fallback : described

        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = documents.appendingPathComponent("GitVault/Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let destination = dir.appendingPathComponent(name)

        do {
            try? FileManager.default.removeItem(at: destination)
            do {
                try FileManager.default.moveItem(at: location, to: destination)
            } catch {
                // 跨卷等场景退回复制
                try FileManager.default.copyItem(at: location, to: destination)
            }
            Task { @MainActor in
                self.state = .finished(destination)
                Haptics.success()
            }
        } catch {
            Task { @MainActor in
                self.state = .failed("保存失败：\(error.localizedDescription)")
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession,
                                task: URLSessionTask,
                                didCompleteWithError error: Error?) {
        guard let error else { return }
        if (error as NSError).code == NSURLErrorCancelled { return }
        Task { @MainActor in
            self.state = .failed("下载失败：\(error.localizedDescription)")
        }
    }
}
