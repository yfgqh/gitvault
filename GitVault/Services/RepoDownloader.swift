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
        currentName = "\(owner)-\(repo).zip"
        state = .downloading(progress: 0)
        Haptics.tap()

        Task {
            var target: URL?
            var fileName: String?

            if let release = try? await GitHubExtrasService.shared.latestRelease(owner: owner, repo: repo) {
                let assets = release.assets ?? []
                let binary = assets.first(where: { Self.looksBinary($0.name) })
                let chosen = binary ?? assets.first
                if let asset = chosen, let url = URL(string: asset.browserDownloadURL) {
                    target = url
                    fileName = asset.name
                }
            }

            if target == nil {
                notice = "该仓库没有发布编译好的二进制文件，正在下载源码包"
                target = GitHubExtrasService.shared.zipballURL(owner: owner, repo: repo, branch: branch)
                fileName = "\(owner)-\(repo)-source.zip"
            }

            guard let url = target else {
                state = .failed("下载地址无效")
                return
            }
            if let fileName { currentName = fileName }
            beginDownload(url)
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        session?.invalidateAndCancel()
        session = nil
        state = .idle
    }

    // MARK: 内部

    private static func looksBinary(_ name: String) -> Bool {
        let lower = name.lowercased()
        let suffixes = [".ipa", ".apk", ".dmg", ".pkg", ".zip", ".tar.gz", ".tgz",
                        ".7z", ".exe", ".msi", ".msix", ".appx", ".deb", ".rpm", ".jar"]
        return suffixes.contains { lower.hasSuffix($0) }
    }

    private func beginDownload(_ url: URL) {
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
        task.taskDescription = currentName
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
