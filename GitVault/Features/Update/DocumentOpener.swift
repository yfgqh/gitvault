//
//  DocumentOpener.swift
//  GitVault
//
//  下载完 IPA 后直接交给系统打开（TrollStore 会出现在「用…打开」列表里）。
//  注意：必须在 SwiftUI 状态更新与弹层动画结束之后再 present，
//  否则 UIDocumentInteractionController 的菜单会被系统静默丢弃。
//

import UIKit

@MainActor
final class DocumentOpener: NSObject, UIDocumentInteractionControllerDelegate {
    static let shared = DocumentOpener()

    private var controller: UIDocumentInteractionController?

    /// 直接打开文件：优先列出能处理该类型的 App（如 TrollStore）。
    @discardableResult
    func open(_ url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }

        // 延后一拍再弹：此刻上层可能还有「正在下载」的界面在收尾
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.present(url)
        }
        return true
    }

    private func present(_ url: URL) {
        guard let window = Self.keyWindow, window.isHidden == false else {
            // 窗口还没就绪，再等一拍
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.present(url)
            }
            return
        }

        let controller = UIDocumentInteractionController(url: url)
        controller.delegate = self
        self.controller = controller

        // 从 window 弹出（列表里只会出现能处理 IPA 的应用）
        let showed = controller.presentOpenInMenu(from: window.bounds, in: window, animated: true)
        if showed { return }

        // 没有能处理的应用：退回分享面板，至少能「存储到文件」
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activity.modalPresentationStyle = .formSheet
        if let top = Self.topViewController(from: window.rootViewController) {
            top.present(activity, animated: true)
        }
    }

    /// 走系统的「存储到文件」
    func export(_ url: URL) {
        guard let window = Self.keyWindow else { return }
        let controller = UIDocumentInteractionController(url: url)
        controller.delegate = self
        self.controller = controller
        controller.presentOptionsMenu(from: window.bounds, in: window, animated: true)
    }

    private static var keyWindow: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let active = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        return active?.windows.first { $0.isKeyWindow } ?? active?.windows.first
    }

    private static func topViewController(from root: UIViewController?) -> UIViewController? {
        guard var top = root else { return nil }
        while let presented = top.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        if let nav = top as? UINavigationController { return topViewController(from: nav.visibleViewController) ?? top }
        if let tab = top as? UITabBarController { return topViewController(from: tab.selectedViewController) ?? top }
        return top
    }
}
