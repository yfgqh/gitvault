//
//  UpdateInstaller.swift
//  GitVault
//
//  应用自更新：带 token 下载 Release 里的 IPA 到沙盒，然后交给系统「存储到文件」。
//  私有仓库的资产地址未登录会 404，所以下载必须带 Authorization。
//

import Foundation
import Combine

@MainActor
final class UpdateInstaller: ObservableObject {
    enum Phase: Equatable {
        case idle
        case downloading(Double)
        case finished(URL)
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle

    private var session: URLSession?
    private var task: URLSessionDownloadTask?
    private var delegate: DownloadDelegate?

    var isDownloading: Bool {
        if case .downloading = phase { return true }
        return false
    }

    // MARK: 下载

    func download(from url: URL, filename: String) {
        guard !isDownloading else { return }
        phase = .downloading(0)

        var request = URLRequest(url: url)
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        request.setValue("GitVault/\(UpdateChecker.currentVersion)", forHTTPHeaderField: "User-Agent")
        if let token = Keychain.read(Keychain.tokenKey), !token.isEmpty {
            request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        }

        let delegate = DownloadDelegate(
            destinationName: filename,
            onProgress: { [weak self] progress in
                Task { @MainActor in
                    guard let self else { return }
                    if case .downloading = self.phase {
                        self.phase = .downloading(progress)
                    }
                }
            },
            onFinish: { [weak self] result in
                Task { @MainActor in
                    guard let self else { return }
                    self.phase = result
                    self.cleanup()
                }
            }
        )
        self.delegate = delegate

        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        self.session = session
        let task = session.downloadTask(with: request)
        self.task = task
        task.resume()
    }

    func cancel() {
        task?.cancel()
        cleanup()
        phase = .idle
    }

    func reset() {
        phase = .idle
    }

    private func cleanup() {
        session?.invalidateAndCancel()
        session = nil
        task = nil
    }

    // MARK: 目录

    static var downloadDirectory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Updates", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
}

// MARK: - 下载代理

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    private let destinationName: String
    private let onProgress: (Double) -> Void
    private let onFinish: (UpdateInstaller.Phase) -> Void
    private var lastTick: Date = .distantPast

    init(destinationName: String,
         onProgress: @escaping (Double) -> Void,
         onFinish: @escaping (UpdateInstaller.Phase) -> Void) {
        self.destinationName = destinationName
        self.onProgress = onProgress
        self.onFinish = onFinish
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        // 0.15 秒节流，避免高频刷新拖慢主线程
        let now = Date()
        guard now.timeIntervalSince(lastTick) > 0.15 else { return }
        lastTick = now
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        onProgress(min(max(progress, 0), 1))
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        // 回调里同步搬走临时文件，否则返回后文件即被删除
        guard let response = downloadTask.response as? HTTPURLResponse else {
            onFinish(.failed("没有拿到服务器响应"))
            return
        }
        guard (200..<300).contains(response.statusCode) else {
            let hint = response.statusCode == 404 ? "资源不存在（未登录或已删除）" : "服务器返回 \(response.statusCode)"
            onFinish(.failed(hint))
            return
        }

        let safeName = destinationName.isEmpty ? "GitVault-Update.ipa" : destinationName
        let destination = UpdateInstaller.downloadDirectory.appendingPathComponent(safeName)
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)
            onFinish(.finished(destination))
        } catch {
            onFinish(.failed("保存失败：\(error.localizedDescription)"))
        }
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        guard let error else { return }
        let nsError = error as NSError
        if nsError.code == NSURLErrorCancelled { return }
        onFinish(.failed(error.localizedDescription))
    }
}
