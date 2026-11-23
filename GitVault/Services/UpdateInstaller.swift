//
//  UpdateInstaller.swift
//  GitVault
//
//  应用自更新：先让用户选择保存位置（文件夹选择器），再带 token 下载 Release 里的 IPA。
//  私有仓库的资产地址未登录会 404，所以下载必须带 Authorization。
//

import Foundation
import Combine
import UniformTypeIdentifiers

/// 下载阶段（放在文件级，供非隔离的 URLSession 代理引用）
enum UpdatePhase: Equatable {
    case idle
    case waitingForLocation
    case downloading(Double)
    case finished(URL)
    case failed(String)
}

@MainActor
final class UpdateInstaller: ObservableObject {
    typealias Phase = UpdatePhase

    @Published private(set) var phase: Phase = .idle

    private var session: URLSession?
    private var task: URLSessionDownloadTask?
    private var delegate: DownloadDelegate?
    private var scopedURL: URL?

    var isDownloading: Bool {
        if case .downloading = phase { return true }
        return false
    }

    // MARK: 下载

    /// - Parameters:
    ///   - directory: 用户选定的保存目录；nil 时落到沙盒 Documents/Updates
    func download(from url: URL, filename: String, to directory: URL?) {
        guard !isDownloading else { return }

        // 外部目录需要安全作用域授权，保持到文件搬运完成
        if let directory {
            let granted = directory.startAccessingSecurityScopedResource()
            scopedURL = granted ? directory : nil
        }

        phase = .downloading(0)

        var request = URLRequest(url: url)
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        request.setValue("GitVault/\(UpdateChecker.currentVersion)", forHTTPHeaderField: "User-Agent")
        if let token = Keychain.read(Keychain.tokenKey), !token.isEmpty {
            request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        }

        let delegate = DownloadDelegate(
            destinationName: filename,
            destinationDirectory: directory,
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
        scopedURL?.stopAccessingSecurityScopedResource()
        scopedURL = nil
    }

    // MARK: 目录

    nonisolated static var downloadDirectory: URL {
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
    private let destinationDirectory: URL?
    private let onProgress: (Double) -> Void
    private let onFinish: (UpdatePhase) -> Void
    private var lastTick: Date = .distantPast

    init(destinationName: String,
         destinationDirectory: URL?,
         onProgress: @escaping (Double) -> Void,
         onFinish: @escaping (UpdatePhase) -> Void) {
        self.destinationName = destinationName
        self.destinationDirectory = destinationDirectory
        self.onProgress = onProgress
        self.onFinish = onFinish
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
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
        let directory = destinationDirectory ?? UpdateInstaller.downloadDirectory
        let destination = directory.appendingPathComponent(safeName)

        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)
            onFinish(.finished(destination))
        } catch {
            // 外部目录写入失败时，退回到沙盒保证文件不丢
            do {
                let fallback = UpdateInstaller.downloadDirectory.appendingPathComponent(safeName)
                if FileManager.default.fileExists(atPath: fallback.path) {
                    try FileManager.default.removeItem(at: fallback)
                }
                try FileManager.default.moveItem(at: location, to: fallback)
                onFinish(.finished(fallback))
            } catch {
                onFinish(.failed("保存失败：\(error.localizedDescription)"))
            }
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
