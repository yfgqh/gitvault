//
//  GitVaultApp.swift
//  GitVault
//
//  应用入口。iOS 16 兼容版本：
//  - 不再依赖 SwiftData（iOS 17+），收藏走 VaultStore 的 JSON 持久化
//  - 启动只做两件事：装模拟器/真机取证、构建内存对象图，任何一步失败都不会崩
//

import SwiftUI
import UserNotifications

@main
struct GitVaultApp: App {
    @AppStorage(AppPrefs.appearance) private var appearanceRaw: String = AppearanceMode.dark.rawValue

    @StateObject private var environment: AppEnvironment
    @StateObject private var vault: VaultStore

    init() {
        CrashReporter.install()
        // 图片与接口响应的内存/磁盘缓存：没有它，列表滚动会反复请求头像
        URLCache.shared = URLCache(
            memoryCapacity: 32 * 1024 * 1024,
            diskCapacity: 256 * 1024 * 1024,
            diskPath: "gv-http-cache"
        )
        CrashReporter.logSync("app init: building object graph")
        let env = AppEnvironment.live()
        _environment = StateObject(wrappedValue: env)
        _vault = StateObject(wrappedValue: VaultStore())
        CrashReporter.logSync("app init: ready")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(environment)
                .environmentObject(environment.auth)
                .environmentObject(vault)
                .preferredColorScheme(
                    (AppearanceMode(rawValue: appearanceRaw) ?? .dark).colorScheme
                )
                .tint(DS.accent)
                .onAppear {
                    // 接管前台通知：否则 App 打开时系统不显示横幅
                    UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
                    CrashReporter.log("root view appeared")
                }
        }
    }

// MARK: - 通知代理

/// 默认情况下 App 在前台时系统不展示通知；这里接管，让「收藏有新版本」在应用内也能看到
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
}