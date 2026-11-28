//
//  DocumentOpener.swift
//  GitVault
//
//  下载完成后弹出系统分享面板（含「用…打开」，装了 TrollStore 就能直接装）。
//  关键点：必须在 SwiftUI 状态收尾之后、并且从真正位于最顶层的控制器呈现。
//

import UIKit

@MainActor
final class DocumentOpener: NSObject, UIDocumentInteractionControllerDelegate {
    static let shared = DocumentOpener()

    private var retained: UIActivityViewController?

    /// 弹出分享面板
    func present(_ url: URL) {
        show(url, attempt: 0)
    }

    /// 兼容旧调用：同样是分享面板
    func open(_ url: URL) -> Bool {
        present(url)
        return true
    }

    /// 「另存」也走同一个面板，用户可选「存储到文件」
    func export(_ url: URL) {
        show(url, attempt: 0)
    }

    private func show(_ url: URL, attempt: Int) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + (attempt == 0 ? 0.45 : 0.35)) { [weak self] in
            guard let self else { return }

            guard let window = Self.keyWindow,
                  let root = window.rootViewController,
                  root.presentedViewController == nil || Self.topMost(root) is UIActivityViewController == false else {
                if attempt < 2 { self.show(url, attempt: attempt + 1) }
                return
            }

            let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            controller.modalPresentationStyle = .formSheet
            controller.completionWithItemsHandler = { [weak self] _, _, _, _ in
                self?.retained = nil
            }

            // iPad / 常规尺寸需要锚点
            if let popover = controller.popoverPresentationController {
                popover.sourceView = window
                popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }

            let presenter = Self.topMost(root)
            // 已经在呈现别的东西（例如还在收尾的弹层）：稍后再试
            guard presenter.presentedViewController == nil else {
                if attempt < 2 { self.show(url, attempt: attempt + 1) }
                return
            }

            self.retained = controller
            presenter.present(controller, animated: true)
        }
    }

    private static var keyWindow: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let active = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        return active?.windows.first { $0.isKeyWindow } ?? active?.windows.first
    }

    private static func topMost(_ root: UIViewController) -> UIViewController {
        var top = root
        var guardCount = 0
        while let presented = top.presentedViewController, !presented.isBeingDismissed, guardCount < 8 {
            top = presented
            guardCount += 1
        }
        if let nav = top as? UINavigationController, let visible = nav.visibleViewController {
            return topMost(visible)
        }
        if let tab = top as? UITabBarController, let selected = tab.selectedViewController {
            return topMost(selected)
        }
        return top
    }
}
