//
//  RepoDownloader.swift
//  GitVault
//
//  仓库下载：GET /repos/{owner}/{repo}/zipball 保存到 Documents/GitVault/Downloads。
//  带进度、可取消；完成后可直接分享。
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

    private var session: URLSession?
    private var task: URLSessionDownloadTask?
    private var destination: URL?

    var isDownloading: Bool {
        if case .downloading = state { return true }
        return false
    }

    func start(owner: String, repo: String, branch: String) {
        guard !isDownloading else { return }
        guard let url = GitHubExtrasService.shared.zipballURL(owner: owner, repo: repo, branch: branch) else {
            state = .failed("下载地址无效")
            return
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 600
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        self.session = session

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("GitVault/2.1", forHTTPHeaderField: "User-Agent")
        if let token = Keychain.read(Keychain.tokenKey), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        currentName = "\(owner)-\(repo).zip"
        state = .downloading(progress: 0)
        Haptics.tap()

        let task = session.downloadTask(with: request)
        self.task = task
        task.resume()
    }

    func cancel() {
        task?.cancel()
        task = nil
        session?.invalidateAndCancel()
        session = nil
        state = .idle
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
        let name = downloadTask.originalRequest?.url?.lastPathComponent ?? "repo.zip"
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = documents.appendingPathComponent("GitVault/Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let destination = dir.appendingPathComponent("\(name).zip")
        try? FileManager.default.removeItem(at: destination)
        do {
            try FileManager.default.copyItem(at: location, to: destination)
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
