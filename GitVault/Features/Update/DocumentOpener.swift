//
//  DocumentOpener.swift
//  GitVault
//
//  下载完 IPA 后直接交给系统打开（TrollStore 会出现在「用…打开」列表里），
//  不再强制走「存储到文件」面板。
//

import UIKit

@MainActor
final class DocumentOpener: NSObject, UIDocumentInteractionControllerDelegate {
    static let shared = DocumentOpener()

    private var controller: UIDocumentInteractionController?

    /// 直接打开文件：优先列出能处理该类型的 App（如 TrollStore）。
    /// - Returns: 是否成功弹出选择器
    @discardableResult
    func open(_ url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        guard let window = Self.keyWindow, let root = window.rootViewController else { return false }

        let controller = UIDocumentInteractionController(url: url)
        controller.delegate = self
        self.controller = controller

        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }

        // 只列能打开 IPA 的 App
        let opened = controller.presentOpenInMenu(from: window.bounds, in: window, animated: true)
        if opened { return true }

        // 没有能处理的应用（例如没装 TrollStore）：退回系统分享面板
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        top.present(activity, animated: true)
        return true
    }

    /// 走系统的「存储到文件」
    func export(_ url: URL, from presenter: UIViewController? = nil) {
        guard let window = Self.keyWindow, let root = window.rootViewController else { return }
        let controller = UIDocumentInteractionController(url: url)
        controller.delegate = self
        self.controller = controller
        controller.presentOptionsMenu(from: window.bounds, in: window, animated: true)
        _ = root
        _ = presenter
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}
