//
//  CrashReporter.swift
//  GitVault
//
//  启动期崩溃取证：
//  1) 未捕获的 Objective-C/Swift 异常 → 写日志
//  2) 常见致命信号（SIGABRT/SIGSEGV/...）→ 直接 write(2) 落盘，不分配内存
//  3) 启动关键路径埋点，崩溃后可在「我的 → 诊断日志」里看到停在哪一步
//
//  注意：真机上木有 Xcode 也能拿到线索，这是排查「打开就闪退」的第一手证据。
//

import Foundation
import Darwin
#if canImport(UIKit)
import UIKit
#endif

private var crashFD: Int32 = -1

/// 信号名映射：返回静态 C 字符串，避免可变参数格式化（Swift 不支持 snprintf 变参）
private func signalMarker(_ sig: Int32) -> UnsafePointer<CChar>? {
    switch sig {
    case SIGABRT: return "\n[CrashReporter] fatal SIGABRT\n"
    case SIGSEGV: return "\n[CrashReporter] fatal SIGSEGV\n"
    case SIGBUS: return "\n[CrashReporter] fatal SIGBUS\n"
    case SIGILL: return "\n[CrashReporter] fatal SIGILL\n"
    case SIGFPE: return "\n[CrashReporter] fatal SIGFPE\n"
    case SIGTRAP: return "\n[CrashReporter] fatal SIGTRAP\n"
    default: return "\n[CrashReporter] fatal signal\n"
    }
}

/// 信号处理里只做 async-signal-safe 的事：预打开 fd + write(2)
private func handleFatalSignal(_ sig: Int32) {
    if crashFD >= 0, let marker = signalMarker(sig) {
        _ = write(crashFD, marker, strlen(marker))
    }
    signal(sig, SIG_DFL)
    raise(sig)
}

enum CrashReporter {

    // MARK: 路径

    static var directory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL.temporaryDirectory
        return base.appendingPathComponent("GitVault", isDirectory: true)
    }

    static var logURL: URL { directory.appendingPathComponent("diagnostics.log") }

    private static let queue = DispatchQueue(label: "com.yfgqh.gitvault.diagnostics")

    // MARK: 安装

    static func install() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        crashFD = open(logURL.path, O_WRONLY | O_CREAT | O_APPEND, 0o644)

        NSSetUncaughtExceptionHandler { exception in
            CrashReporter.logSync("""
            [UNCAUGHT] \(exception.name.rawValue): \(exception.reason ?? "-")
            \(exception.callStackSymbols.joined(separator: "\n"))
            """)
        }

        for sig in [SIGABRT, SIGSEGV, SIGBUS, SIGILL, SIGFPE, SIGTRAP] {
            signal(sig, handleFatalSignal)
        }

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        logSync("""

        ======== launch \(Date().formatted(date: .numeric, time: .standard)) ========
        version \(version) (\(build)) · \(deviceSummary)
        """)
    }

    private static var deviceSummary: String {
        #if os(iOS)
        return "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion) · \(UIDevice.current.model)"
        #else
        return "unknown"
        #endif
    }

    // MARK: 写入

    /// 异步写（页面级埋点）
    static func log(_ message: String, file: String = #fileID, line: Int = #line) {
        queue.async {
            append("[\(shortName(file)):\(line)] \(message)")
        }
    }

    /// 同步写（启动关键路径 / 崩溃现场）
    static func logSync(_ message: String, file: String = #fileID, line: Int = #line) {
        append("[\(shortName(file)):\(line)] \(message)")
    }

    private static func shortName(_ file: String) -> String {
        file.split(separator: "/").last.map(String.init) ?? file
    }

    private static func append(_ line: String) {
        let text = line.hasSuffix("\n") ? line : line + "\n"
        guard let data = text.data(using: .utf8) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let handle = try? FileHandle(forWritingTo: logURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: logURL, options: .atomic)
        }
    }

    // MARK: 读取 / 清理

    static func readLog(limit: Int = 24_000) -> String {
        guard let text = try? String(contentsOf: logURL, encoding: .utf8) else {
            return "暂无诊断日志。"
        }
        if text.count <= limit { return text }
        return String(text.suffix(limit))
    }

    static func lineCount() -> Int {
        guard let text = try? String(contentsOf: logURL, encoding: .utf8) else { return 0 }
        return text.split(separator: "\n").count
    }

    static func clear() {
        try? FileManager.default.removeItem(at: logURL)
        logSync("diagnostics cleared")
    }

    /// 环境摘要，用于反馈问题时贴给开发者
    static func environmentSummary() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let bundleID = Bundle.main.bundleIdentifier ?? "?"
        let hasToken = Keychain.read(Keychain.tokenKey)?.isEmpty == false
        return """
        app: GitVault \(version) (\(build))
        bundle: \(bundleID)
        system: \(deviceSummary)
        signedIn: \(hasToken)
        diagnostics: \(logURL.path)
        """
    }
}
